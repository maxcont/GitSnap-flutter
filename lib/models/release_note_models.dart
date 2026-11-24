import 'azure_models.dart';
import 'pull_request_models.dart';

enum ReleaseNoteCategory { ok, outOfScope, toVerify }

extension ReleaseNoteCategoryLabel on ReleaseNoteCategory {
  String get label => switch (this) {
        ReleaseNoteCategory.ok => 'OK',
        ReleaseNoteCategory.outOfScope => 'Fuori perimetro',
        ReleaseNoteCategory.toVerify => 'Da verificare',
      };
}

enum ReleaseNoteItemKind { pullRequest, directCommit }

/// Completed PR with the fields needed by the check that
/// [PullRequestSummary] does not expose.
class ReleaseNotePullRequest {
  final PullRequestSummary summary;
  final String? description;
  final String? lastMergeCommitId;

  const ReleaseNotePullRequest({
    required this.summary,
    this.description,
    this.lastMergeCommitId,
  });

  factory ReleaseNotePullRequest.fromJson(Map<String, dynamic> json) {
    final description = json['description'];
    final lastMergeCommit = json['lastMergeCommit'];
    final mergeId =
        lastMergeCommit is Map ? lastMergeCommit['commitId'] : null;
    return ReleaseNotePullRequest(
      summary: PullRequestSummary.fromJson(json),
      description: description is String ? description : null,
      lastMergeCommitId: mergeId is String && mergeId.isNotEmpty ? mergeId : null,
    );
  }
}

class ReleaseNotePullRequestData {
  final ReleaseNotePullRequest pullRequest;
  final List<Commit> commits;

  const ReleaseNotePullRequestData({
    required this.pullRequest,
    required this.commits,
  });
}

/// Everything loaded for one reference branch of one repository.
class ReleaseNoteBranchData {
  final String repositoryId;
  final String repositoryName;
  final String? repositoryUrl;
  final String branch;
  final List<ReleaseNotePullRequestData> pullRequests;
  final List<Commit> branchCommits;

  const ReleaseNoteBranchData({
    required this.repositoryId,
    required this.repositoryName,
    this.repositoryUrl,
    required this.branch,
    required this.pullRequests,
    required this.branchCommits,
  });
}

class ReleaseNoteItem {
  final String key;
  final ReleaseNoteItemKind kind;
  final String repositoryId;
  final String repositoryName;
  final String branch;
  final ReleaseNotePullRequest? pullRequest;

  /// PR commits for a PR item, the single commit for a direct commit.
  final List<Commit> commits;
  final String? webUrl;
  final Set<String> matchedEntries;
  final ReleaseNoteCategory automaticCategory;

  const ReleaseNoteItem({
    required this.key,
    required this.kind,
    required this.repositoryId,
    required this.repositoryName,
    required this.branch,
    this.pullRequest,
    required this.commits,
    this.webUrl,
    required this.matchedEntries,
    required this.automaticCategory,
  });

  String get title {
    final pr = pullRequest;
    if (pr != null) return 'PR ${pr.summary.id} · ${pr.summary.title}';
    return (commits.first.comment ?? '').split('\n').first;
  }

  String get author =>
      pullRequest?.summary.author.displayName ??
      commits.first.author?.name ??
      '';

  DateTime? get date {
    final pr = pullRequest;
    if (pr != null) return pr.summary.closedAt;
    final raw = commits.first.date;
    return raw == null ? null : DateTime.tryParse(raw);
  }
}

class ReleaseNoteCheckResult {
  final List<String> entries;
  final List<ReleaseNoteItem> items;
  final List<String> missingEntries;
  final List<String> uninvolvedRepositories;
  final List<String> warnings;

  const ReleaseNoteCheckResult({
    required this.entries,
    required this.items,
    required this.missingEntries,
    this.uninvolvedRepositories = const [],
    this.warnings = const [],
  });
}
