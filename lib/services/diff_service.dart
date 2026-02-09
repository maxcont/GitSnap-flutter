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

      // Single call to diffs/commits (like Streamlit): gives aheadCount (commit diff) and file list from same response
      final diffData = await client.getDiffsCommits(
        repo.id,
        targetCommitId,
        sourceCommitId,
      );
      final aheadCount = AzureDevOpsClient.aheadCountFromDiff(diffData);
      final fileCount = AzureDevOpsClient.totalChangesFromDiff(diffData);
      final files = AzureDevOpsClient.filePathsFromDiff(diffData);

      // Status from same source as Streamlit: aheadCount and file count from diffs/commits
      final status = (aheadCount == 0 && fileCount == 0)
          ? DiffStatus.aligned
          : DiffStatus.divergent;

      // List of commit details for the expandable section (optional; may be empty on some servers)
      List<Commit> commits = [];
      if (aheadCount > 0) {
        try {
          commits = await client.getCommitsBetween(
            repo.id,
            targetCommitId,
            sourceCommitId,
          );
        } catch (_) {}
      }

      final sourceCommit = await client.getCommit(repo.id, sourceCommitId);
      final targetCommit = await client.getCommit(repo.id, targetCommitId);

      return DiffResult(
        repoId: repo.id,
        repoName: repo.name,
        status: status,
        commitCount: aheadCount,
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
        commits: commits,
        files: files,
        note: status == DiffStatus.aligned
            ? 'Nessuna differenza'
            : '$aheadCount commit in SOURCE non in TARGET, $fileCount file modificati',
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
