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

    // Tag name without refs/tags/ prefix
    String tagNameFromRef(String name) {
      if (name.startsWith('refs/tags/')) {
        return name.substring('refs/tags/'.length);
      }
      return name;
    }

    // Find tags matching pattern (fnmatch-style like Streamlit: * = any)
    final matchingTags = tags.where((t) {
      final name = t['name'] as String? ?? '';
      final tagName = tagNameFromRef(name);
      if (pattern.contains('*') || pattern.contains('?')) {
        // Escape regex specials but keep * and ? for wildcards (* -> .*, ? -> .)
        final escaped = pattern
            .replaceAll(r'\', r'\\')
            .replaceAll('.', r'\.')
            .replaceAll('*', '\x00')
            .replaceAll('?', '\x01');
        final regexPattern =
            '^${escaped.replaceAll('\x00', '.*').replaceAll('\x01', '.')}\$';
        final regex = RegExp(regexPattern, caseSensitive: false);
        return regex.hasMatch(tagName);
      }
      return tagName.toLowerCase() == pattern.toLowerCase();
    }).toList();

    if (matchingTags.isEmpty) {
      return ResolvedRef(
        repoId: repo.id,
        error: 'No tags match pattern: $pattern',
      );
    }

    // Extract date from commit map (committer.date or author.date, like Streamlit)
    String dateFromCommit(Map<String, dynamic>? c) {
      if (c == null) return '';
      final committer = c['committer'];
      final author = c['author'];
      if (committer is Map) {
        final d = committer['date'];
        if (d is String && d.isNotEmpty) return d;
      }
      if (author is Map) {
        final d = author['date'];
        if (d is String && d.isNotEmpty) return d;
      }
      return '';
    }

    // Resolve each matching tag to (tagName, commitId, date) - like Streamlit
    // Annotated tags: objectId is the tag object; we need commits API to get commit.
    final List<({String tagName, String commitId, String date})> tagCommits = [];
    for (final t in matchingTags) {
      final name = t['name'] as String? ?? '';
      final tagName = tagNameFromRef(name);
      final objectId = t['objectId'] as String?;
      if (objectId == null || objectId.isEmpty) continue;

      String? commitId;
      String date = '';

      final commit = await client.getCommitByTag(repo.id, tagName);
      if (commit != null) {
        final cid = commit['commitId'] as String?;
        if (cid != null && cid.isNotEmpty) {
          commitId = cid;
          date = dateFromCommit(commit);
        }
      }
      // If commits API didn't return (e.g. on-prem), try peeledObjectId from refs (annotated tag → commit)
      if (commitId == null) {
        final peeled = t['peeledObjectId'] as String?;
        if (peeled != null && peeled.isNotEmpty) {
          commitId = peeled;
          try {
            final commitById = await client.getCommit(repo.id, peeled);
            date = dateFromCommit(commitById);
          } catch (_) {}
        }
      }
      // Lightweight tag: objectId is the commit
      if (commitId == null) commitId = objectId;
      if (commitId == null) continue;
      if (date.isEmpty) {
        try {
          final commitById = await client.getCommit(repo.id, commitId);
          date = dateFromCommit(commitById);
        } catch (_) {}
      }
      tagCommits.add((tagName: tagName, commitId: commitId!, date: date));
    }

    if (tagCommits.isEmpty) {
      return ResolvedRef(
        repoId: repo.id,
        error: 'No resolvable tags for pattern: $pattern',
      );
    }

    // Sort exactly like Streamlit: by date descending (most recent first); empty date = "0000" so sorts last
    tagCommits.sort((a, b) {
      final da = a.date.isEmpty ? '0000' : a.date;
      final db = b.date.isEmpty ? '0000' : b.date;
      final cmp = db.compareTo(da);
      if (cmp != 0) return cmp;
      return a.tagName.compareTo(b.tagName); // tie-break deterministic
    });
    final chosen = tagCommits.first;

    return ResolvedRef(
      repoId: repo.id,
      commitId: chosen.commitId,
      refName: chosen.tagName,
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
