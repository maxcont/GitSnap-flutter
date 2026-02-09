import '../models/azure_models.dart';
import 'azure_devops_client.dart';

class ResolvedRef {
  final String repoId;
  final String? commitId;
  final String? refName;
  final String? error;

  ResolvedRef({
    required this.repoId,
    this.commitId,
    this.refName,
    this.error,
  });
}

class RefResolver {
  final AzureDevOpsClient client;

  RefResolver(this.client);

  /// Resolve reference for a single repository
  Future<ResolvedRef> resolveRef(
    Repository repo,
    RefType refType,
    String refValue,
  ) async {
    try {
      switch (refType) {
        case RefType.branch:
          return await _resolveBranch(repo, refValue);
        case RefType.tagPattern:
          return await _resolveTagPattern(repo, refValue);
        case RefType.commit:
          return await _resolveCommit(repo, refValue);
      }
    } catch (e) {
      return ResolvedRef(
        repoId: repo.id,
        error: 'Error resolving ref: $e',
      );
    }
  }

  Future<ResolvedRef> _resolveBranch(Repository repo, String branchName) async {
    final branches = await client.getBranches(repo.id);
    final fullName = branchName.startsWith('refs/heads/')
        ? branchName
        : 'refs/heads/$branchName';

    final branch = branches.firstWhere(
      (b) => b['name'] == fullName,
      orElse: () => {},
    );

    if (branch.isEmpty) {
      return ResolvedRef(
        repoId: repo.id,
        error: 'Branch not found: $branchName',
      );
    }

    return ResolvedRef(
      repoId: repo.id,
      commitId: branch['objectId'],
      refName: fullName,
    );
  }

  Future<ResolvedRef> _resolveTagPattern(
    Repository repo,
    String pattern,
  ) async {
    final tags = await client.getTags(repo.id);
    
    if (tags.isEmpty) {
      return ResolvedRef(
        repoId: repo.id,
        error: 'No tags found',
      );
    }

    // Find tags matching pattern (simple wildcard support)
    final matchingTags = tags.where((t) {
      final name = t['name'] as String;
      final tagName = name.replaceFirst('refs/tags/', '');
      
      if (pattern.contains('*')) {
        final regex = RegExp(
          '^${pattern.replaceAll('*', '.*')}\$',
          caseSensitive: false,
        );
        return regex.hasMatch(tagName);
      }
      
      return tagName == pattern;
    }).toList();

    if (matchingTags.isEmpty) {
      return ResolvedRef(
        repoId: repo.id,
        error: 'No tags match pattern: $pattern',
      );
    }

    // Get most recent tag (last in list)
    final tag = matchingTags.last;

    return ResolvedRef(
      repoId: repo.id,
      commitId: tag['objectId'],
      refName: tag['name'],
    );
  }

  Future<ResolvedRef> _resolveCommit(Repository repo, String commitId) async {
    try {
      final commit = await client.getCommit(repo.id, commitId);
      return ResolvedRef(
        repoId: repo.id,
        commitId: commit['commitId'],
        refName: commitId,
      );
    } catch (e) {
      return ResolvedRef(
        repoId: repo.id,
        error: 'Commit not found: $commitId',
      );
    }
  }

  /// Resolve references for multiple repositories
  Future<Map<String, ResolvedRef>> resolveRefsForRepos(
    List<Repository> repos,
    RefType refType,
    String refValue,
  ) async {
    final results = <String, ResolvedRef>{};

    for (final repo in repos) {
      final resolved = await resolveRef(repo, refType, refValue);
      results[repo.id] = resolved;
    }

    return results;
  }
}
