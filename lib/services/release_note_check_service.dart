import '../models/azure_models.dart';
import '../models/release_note_models.dart';

class ReleaseNoteCheckService {
  static List<String> parseEntries(String text) {
    final seen = <String>{};
    final entries = <String>[];
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final entry = line.trim();
      if (entry.isNotEmpty && seen.add(entry.toLowerCase())) {
        entries.add(entry);
      }
    }
    return entries;
  }

  /// [entry] must not be glued to a letter or digit, so `INC376` does not
  /// match `INC3761`.
  static bool matches(String entry, String text) => RegExp(
        '(?<![A-Za-z0-9])${RegExp.escape(entry)}(?![A-Za-z0-9])',
        caseSensitive: false,
      ).hasMatch(text);

  static List<String> parseBranchPatterns(String text) => text
      .split(RegExp(r'[,;\r\n]'))
      .map((pattern) => pattern.trim())
      .where((pattern) => pattern.isNotEmpty)
      .toSet()
      .toList();

  static bool matchesBranchPattern(String pattern, String branch) {
    final normalized = pattern.trim().replaceFirst('refs/heads/', '');
    if (normalized.isEmpty) return false;
    final regex = RegExp(
      '^${RegExp.escape(normalized).replaceAll(r'\*', '.*')}\$',
      caseSensitive: false,
    );
    return regex.hasMatch(branch.replaceFirst('refs/heads/', ''));
  }

  static List<Commit> findDirectCommits(ReleaseNoteBranchData data) {
    final pullRequestCommitIds = <String>{};
    final pullRequestSignatures = <String>{};
    for (final pullRequest in [
      ...data.pullRequests,
      ...data.excludedPullRequests,
    ]) {
      final mergeCommitId = pullRequest.pullRequest.lastMergeCommitId;
      if (mergeCommitId != null) {
        pullRequestCommitIds.add(mergeCommitId.toLowerCase());
      }
      for (final commit in pullRequest.commits) {
        pullRequestCommitIds.add(commit.commitId.toLowerCase());
        final signature = _signature(commit);
        if (signature != null) pullRequestSignatures.add(signature);
      }
    }
    return data.branchCommits
        .where((commit) =>
            !pullRequestCommitIds.contains(commit.commitId.toLowerCase()) &&
            !pullRequestSignatures.contains(_signature(commit)))
        .toList();
  }

  /// Rebase merges rewrite SHAs: message and author identify the copy.
  static String? _signature(Commit commit) {
    final message = (commit.comment ?? '').trim();
    if (message.isEmpty) return null;
    final author = (commit.author?.name ?? '').trim().toLowerCase();
    return '$author\x00$message';
  }

  static ReleaseNoteCheckResult check({
    required List<String> entries,
    required List<ReleaseNoteBranchData> branches,
    List<String> uninvolvedRepositories = const [],
    List<String> warnings = const [],
  }) {
    final items = <ReleaseNoteItem>[];
    for (final data in branches) {
      for (final pullRequest in data.pullRequests) {
        final summary = pullRequest.pullRequest.summary;
        final text = [
          summary.title,
          summary.sourceBranch,
          pullRequest.pullRequest.description ?? '',
          ...pullRequest.commits.map((commit) => commit.comment ?? ''),
        ].join('\n');
        items.add(_item(
          key: 'pr:${data.repositoryId}:${summary.id}',
          kind: ReleaseNoteItemKind.pullRequest,
          data: data,
          pullRequest: pullRequest.pullRequest,
          commits: pullRequest.commits,
          webUrl: summary.webUrl,
          text: text,
          entries: entries,
        ));
      }
      for (final commit in findDirectCommits(data)) {
        items.add(_item(
          key: 'commit:${data.repositoryId}:${data.branch}:${commit.commitId}',
          kind: ReleaseNoteItemKind.directCommit,
          data: data,
          commits: [commit],
          webUrl: data.repositoryUrl == null
              ? null
              : '${data.repositoryUrl}/commit/${commit.commitId}',
          text: commit.comment ?? '',
          entries: entries,
        ));
      }
    }
    items.sort((left, right) =>
        (right.date ?? DateTime(1970)).compareTo(left.date ?? DateTime(1970)));
    final matched = items.expand((item) => item.matchedEntries).toSet();
    return ReleaseNoteCheckResult(
      entries: entries,
      items: items,
      missingEntries:
          entries.where((entry) => !matched.contains(entry)).toList(),
      uninvolvedRepositories: uninvolvedRepositories,
      warnings: warnings,
    );
  }

  static ReleaseNoteItem _item({
    required String key,
    required ReleaseNoteItemKind kind,
    required ReleaseNoteBranchData data,
    ReleaseNotePullRequest? pullRequest,
    required List<Commit> commits,
    required String? webUrl,
    required String text,
    required List<String> entries,
  }) {
    final matchedEntries =
        entries.where((entry) => matches(entry, text)).toSet();
    return ReleaseNoteItem(
      key: key,
      kind: kind,
      repositoryId: data.repositoryId,
      repositoryName: data.repositoryName,
      branch: data.branch,
      pullRequest: pullRequest,
      commits: commits,
      webUrl: webUrl,
      matchedEntries: matchedEntries,
      automaticCategory: matchedEntries.isEmpty
          ? ReleaseNoteCategory.toVerify
          : ReleaseNoteCategory.ok,
    );
  }
}
