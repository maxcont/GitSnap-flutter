import '../models/azure_models.dart';
import '../models/release_note_models.dart';
import 'azure_devops_client.dart';
import 'release_note_check_service.dart';

typedef ReleaseNoteProgress = void Function(
    String phase, int completed, int total);

class ReleaseNoteLoadResult {
  final List<ReleaseNoteBranchData> branches;
  final Map<String, String> involvedRepositories;
  final List<String> uninvolvedRepositories;
  final List<String> warnings;

  const ReleaseNoteLoadResult({
    required this.branches,
    required this.involvedRepositories,
    required this.uninvolvedRepositories,
    required this.warnings,
  });
}

class ReleaseNoteDataLoader {
  final AzureDevOpsClient client;
  final int concurrency;

  ReleaseNoteDataLoader(this.client, {this.concurrency = 5});

  Future<ReleaseNoteLoadResult> load({
    required List<Repository> repositories,
    required List<String> branchPatterns,
    required DateTime from,
    required DateTime to,
    ReleaseNoteProgress? onProgress,
  }) async {
    final warnings = <String>[];
    final uninvolved = <String>[];

    final targets = <({Repository repo, String branch})>[];
    await _inChunks<Repository>(
      repositories,
      'Lettura branch dei repository',
      onProgress,
      (repo) async {
        try {
          final branches = (await client.getBranches(repo.id))
              .map((b) =>
                  (b['name'] as String? ?? '').replaceFirst('refs/heads/', ''))
              .where((name) =>
                  name.isNotEmpty &&
                  branchPatterns.any((pattern) =>
                      ReleaseNoteCheckService.matchesBranchPattern(
                          pattern, name)))
              .toList()
            ..sort();
          if (branches.isEmpty) {
            uninvolved.add(repo.name);
          } else {
            targets.addAll(branches.map((b) => (repo: repo, branch: b)));
          }
        } catch (error) {
          warnings.add('${repo.name}: impossibile leggere le branch ($error)');
        }
      },
    );

    final loaded = <({
      Repository repo,
      String branch,
      List<ReleaseNotePullRequest> pullRequests,
      List<ReleaseNotePullRequest> excludedPullRequests,
      List<Commit> branchCommits,
    })>[];
    await _inChunks<({Repository repo, String branch})>(
      targets,
      'Lettura pull request e commit delle branch',
      onProgress,
      (target) async {
        try {
          final results = await Future.wait([
            client.getCompletedPullRequests(target.repo.id, target.branch),
            client.getCommitsForBranch(target.repo.id, target.branch,
                from: from, to: to),
          ]);
          final pullRequests = <ReleaseNotePullRequest>[];
          final excludedPullRequests = <ReleaseNotePullRequest>[];
          for (final pr in results[0] as List<ReleaseNotePullRequest>) {
            final closedAt = pr.summary.closedAt;
            if (closedAt == null || closedAt.isBefore(from)) continue;
            // Commits of PRs completed later can be dated within the period.
            (closedAt.isAfter(to) ? excludedPullRequests : pullRequests)
                .add(pr);
          }
          loaded.add((
            repo: target.repo,
            branch: target.branch,
            pullRequests: pullRequests,
            excludedPullRequests: excludedPullRequests,
            branchCommits: results[1] as List<Commit>,
          ));
        } catch (error) {
          warnings.add('${target.repo.name}/${target.branch}: $error');
        }
      },
    );

    final prCommits = <String, List<Commit>>{};
    final prRequests = [
      for (final entry in loaded)
        for (final pr in [
          ...entry.pullRequests,
          ...entry.excludedPullRequests,
        ])
          (repo: entry.repo, pr: pr),
    ];
    await _inChunks<({Repository repo, ReleaseNotePullRequest pr})>(
      prRequests,
      'Lettura commit delle pull request',
      onProgress,
      (request) async {
        final id = request.pr.summary.id;
        try {
          prCommits['${request.repo.id}:$id'] =
              await client.getPullRequestCommits(request.repo.id, id);
        } catch (error) {
          warnings
              .add('${request.repo.name} PR $id: commit non letti ($error)');
        }
      },
    );

    ReleaseNotePullRequestData withCommits(
            Repository repo, ReleaseNotePullRequest pr) =>
        ReleaseNotePullRequestData(
          pullRequest: pr,
          commits: prCommits['${repo.id}:${pr.summary.id}'] ?? const [],
        );

    final branches = [
      for (final entry in loaded)
        ReleaseNoteBranchData(
          repositoryId: entry.repo.id,
          repositoryName: entry.repo.name,
          repositoryUrl: entry.repo.remoteUrl,
          branch: entry.branch,
          pullRequests: [
            for (final pr in entry.pullRequests) withCommits(entry.repo, pr),
          ],
          excludedPullRequests: [
            for (final pr in entry.excludedPullRequests)
              withCommits(entry.repo, pr),
          ],
          branchCommits: entry.branchCommits,
        ),
    ]..sort((a, b) => '${a.repositoryName}/${a.branch}'
        .compareTo('${b.repositoryName}/${b.branch}'));
    uninvolved.sort();
    return ReleaseNoteLoadResult(
      branches: branches,
      involvedRepositories: {
        for (final target in targets) target.repo.id: target.repo.name,
      },
      uninvolvedRepositories: uninvolved,
      warnings: warnings,
    );
  }

  Future<void> _inChunks<T>(
    List<T> items,
    String phase,
    ReleaseNoteProgress? onProgress,
    Future<void> Function(T item) action,
  ) async {
    var completed = 0;
    onProgress?.call(phase, completed, items.length);
    for (var index = 0; index < items.length; index += concurrency) {
      final chunk = items.skip(index).take(concurrency);
      await Future.wait(chunk.map(action));
      completed += chunk.length;
      onProgress?.call(phase, completed, items.length);
    }
  }
}
