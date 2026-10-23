import '../models/azure_models.dart';
import 'azure_devops_client.dart';
import 'ref_resolver.dart';

class DiffService {
  final AzureDevOpsClient client;

  DiffService(this.client);

  static const int defaultConcurrency = 5;

  /// Get diff results for multiple repositories (sequential)
  Future<List<DiffResult>> getDiffsForRepos(
    List<Repository> repos,
    Map<String, ResolvedRef> sourceRefs,
    Map<String, ResolvedRef> targetRefs,
    RefType sourceRefType,
    RefType targetRefType,
  ) async {
    return getDiffsForReposParallel(
      repos,
      sourceRefs,
      targetRefs,
      sourceRefType,
      targetRefType,
      concurrency: 1,
    );
  }

  /// Get diff results for multiple repositories in parallel (max [concurrency] at a time)
  Future<List<DiffResult>> getDiffsForReposParallel(
    List<Repository> repos,
    Map<String, ResolvedRef> sourceRefs,
    Map<String, ResolvedRef> targetRefs,
    RefType sourceRefType,
    RefType targetRefType, {
    int concurrency = defaultConcurrency,
  }) async {
    final results = <DiffResult>[];

    for (var i = 0; i < repos.length; i += concurrency) {
      final chunk = repos.sublist(
        i,
        i + concurrency > repos.length ? repos.length : i + concurrency,
      );
      final chunkResults = await Future.wait(
        chunk.map((repo) async {
          final sourceRef = sourceRefs[repo.id];
          final targetRef = targetRefs[repo.id];

          if (sourceRef == null || targetRef == null) {
            return DiffResult(
              repoId: repo.id,
              repoName: repo.name,
              status: DiffStatus.error,
              note: 'Missing ref resolution',
            );
          }

          if (sourceRef.error != null || targetRef.error != null) {
            return DiffResult(
              repoId: repo.id,
              repoName: repo.name,
              status: DiffStatus.error,
              note: sourceRef.error ?? targetRef.error,
            );
          }

          return _getDiffForRepo(repo, sourceRef, targetRef);
        }),
      );
      results.addAll(chunkResults);
    }

    return results;
  }

  Future<DiffResult> _getDiffForRepo(
    Repository repo,
    ResolvedRef sourceRef,
    ResolvedRef targetRef,
  ) async {
    try {
      final sourceCommitId = sourceRef.commitId!;
      final targetCommitId = targetRef.commitId!;

      // Check if commits are the same
      if (sourceCommitId == targetCommitId) {
        return DiffResult(
          repoId: repo.id,
          repoName: repo.name,
          status: DiffStatus.aligned,
          sourceRef: sourceRef.refName,
          targetRef: targetRef.refName,
          sourceCommit: sourceCommitId,
          targetCommit: targetCommitId,
          note: 'Same commit',
        );
      }

      final commitDetails = await Future.wait([
        client.getCommit(repo.id, sourceCommitId),
        client.getCommit(repo.id, targetCommitId),
      ]);
      final sourceCommit = commitDetails[0];
      final targetCommit = commitDetails[1];

      // Same tree = identical content, even if history differs (e.g. squash merge).
      final sourceTreeId = sourceCommit['treeId'];
      final targetTreeId = targetCommit['treeId'];
      if (sourceTreeId is String &&
          sourceTreeId.isNotEmpty &&
          sourceTreeId == targetTreeId) {
        return DiffResult(
          repoId: repo.id,
          repoName: repo.name,
          status: DiffStatus.aligned,
          sourceRef: sourceRef.refName,
          targetRef: targetRef.refName,
          sourceCommit: sourceCommitId,
          targetCommit: targetCommitId,
          sourceCommitMessage: sourceCommit['comment'],
          targetCommitMessage: targetCommit['comment'],
          sourceCommitAuthor: sourceCommit['author']?['name'],
          targetCommitAuthor: targetCommit['author']?['name'],
          sourceCommitDate: sourceCommit['author']?['date'],
          targetCommitDate: targetCommit['author']?['date'],
          note: 'Contenuto identico (commit diversi, probabile squash merge)',
        );
      }

      // base=TARGET, target=SOURCE → aheadCount: SOURCE not in TARGET, behindCount: TARGET not in SOURCE
      final diffSourceNotInTarget = await client.getDiffsCommits(
        repo.id,
        targetCommitId,
        sourceCommitId,
      );
      final diffTargetNotInSource = targetCommitId != sourceCommitId
          ? await client.getDiffsCommits(
              repo.id,
              sourceCommitId,
              targetCommitId,
            )
          : diffSourceNotInTarget;

      final sourceAheadCount =
          AzureDevOpsClient.aheadCountFromDiff(diffSourceNotInTarget);
      final targetAheadCount =
          AzureDevOpsClient.behindCountFromDiff(diffSourceNotInTarget);

      final fileCountA =
          AzureDevOpsClient.totalChangesFromDiff(diffSourceNotInTarget);
      final fileCountB =
          AzureDevOpsClient.totalChangesFromDiff(diffTargetNotInSource);
      final fileCount = fileCountA > fileCountB ? fileCountA : fileCountB;

      final filesA = AzureDevOpsClient.filePathsFromDiff(diffSourceNotInTarget);
      final filesB = AzureDevOpsClient.filePathsFromDiff(diffTargetNotInSource);
      final files = {...filesA, ...filesB}.toList()..sort();

      final status = (sourceAheadCount == 0 &&
              targetAheadCount == 0 &&
              fileCount == 0)
          ? DiffStatus.aligned
          : DiffStatus.divergent;

      List<Commit> commitsOnlyInSource = [];
      List<Commit> commitsOnlyInTarget = [];
      try {
        final commitFetches = <Future<void>>[];
        if (sourceAheadCount > 0) {
          commitFetches.add(
            client
                .getCommitsBetween(repo.id, targetCommitId, sourceCommitId)
                .then((list) => commitsOnlyInSource = list),
          );
        }
        if (targetAheadCount > 0) {
          commitFetches.add(
            client
                .getCommitsBetween(repo.id, sourceCommitId, targetCommitId)
                .then((list) => commitsOnlyInTarget = list),
          );
        }
        if (commitFetches.isNotEmpty) {
          await Future.wait(commitFetches);
        }
      } catch (_) {
        // optional details: ignore
      }

      final totalCommitDiff = sourceAheadCount + targetAheadCount;
      return DiffResult(
        repoId: repo.id,
        repoName: repo.name,
        status: status,
        commitCount: totalCommitDiff,
        sourceOnlyCommitCount: sourceAheadCount,
        targetOnlyCommitCount: targetAheadCount,
        fileCount: fileCount,
        sourceRef: sourceRef.refName,
        targetRef: targetRef.refName,
        sourceCommit: sourceCommitId,
        targetCommit: targetCommitId,
        sourceCommitMessage: sourceCommit['comment'],
        targetCommitMessage: targetCommit['comment'],
        sourceCommitAuthor: sourceCommit['author']?['name'],
        targetCommitAuthor: targetCommit['author']?['name'],
        sourceCommitDate: sourceCommit['author']?['date'],
        targetCommitDate: targetCommit['author']?['date'],
        commits: commitsOnlyInSource.isEmpty ? null : commitsOnlyInSource,
        targetCommits: commitsOnlyInTarget.isEmpty ? null : commitsOnlyInTarget,
        files: files,
        note: status == DiffStatus.aligned
            ? 'Nessuna differenza'
            : 'SOURCE→TARGET: $sourceAheadCount commit, TARGET→SOURCE: $targetAheadCount commit, $fileCount file modificati',
      );
    } catch (e) {
      return DiffResult(
        repoId: repo.id,
        repoName: repo.name,
        status: DiffStatus.error,
        note: 'Error computing diff: $e',
      );
    }
  }
}
