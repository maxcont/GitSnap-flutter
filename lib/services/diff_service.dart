import '../models/azure_models.dart';
import 'azure_devops_client.dart';
import 'ref_resolver.dart';

class DiffService {
  final AzureDevOpsClient client;

  DiffService(this.client);

  /// Get diff results for multiple repositories
  Future<List<DiffResult>> getDiffsForRepos(
    List<Repository> repos,
    Map<String, ResolvedRef> sourceRefs,
    Map<String, ResolvedRef> targetRefs,
    RefType sourceRefType,
    RefType targetRefType,
  ) async {
    final results = <DiffResult>[];

    for (final repo in repos) {
      final sourceRef = sourceRefs[repo.id];
      final targetRef = targetRefs[repo.id];

      if (sourceRef == null || targetRef == null) {
        results.add(DiffResult(
          repoId: repo.id,
          repoName: repo.name,
          status: DiffStatus.error,
          note: 'Missing ref resolution',
        ));
        continue;
      }

      if (sourceRef.error != null || targetRef.error != null) {
        results.add(DiffResult(
          repoId: repo.id,
          repoName: repo.name,
          status: DiffStatus.error,
          note: sourceRef.error ?? targetRef.error,
        ));
        continue;
      }

      final result = await _getDiffForRepo(
        repo,
        sourceRef,
        targetRef,
      );
      results.add(result);
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

      // Get commits between target and source
      final commits = await client.getCommitsBetween(
        repo.id,
        targetCommitId,
        sourceCommitId,
      );

      // Get changed files
      final files = await client.getChangedFiles(
        repo.id,
        targetCommitId,
        sourceCommitId,
      );

      // Get commit details
      final sourceCommit = await client.getCommit(repo.id, sourceCommitId);
      final targetCommit = await client.getCommit(repo.id, targetCommitId);

      final status = commits.isEmpty ? DiffStatus.aligned : DiffStatus.divergent;

      return DiffResult(
        repoId: repo.id,
        repoName: repo.name,
        status: status,
        commitCount: commits.length,
        fileCount: files.length,
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
        commits: commits,
        files: files,
        note: status == DiffStatus.aligned
            ? 'No differences'
            : '${commits.length} commits ahead',
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
