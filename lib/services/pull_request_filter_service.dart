import '../models/pull_request_models.dart';

class PullRequestFilter {
  final Set<PullRequestStatus> statuses;
  final bool personalOnly;
  final Set<String> repositoryIds;
  final String? authorUniqueName;
  final String? targetBranch;
  final String query;
  final DateTime startDate;
  final DateTime endDate;

  PullRequestFilter({
    required Set<PullRequestStatus> statuses,
    this.personalOnly = false,
    Set<String> repositoryIds = const {},
    this.authorUniqueName,
    this.targetBranch,
    this.query = '',
    required this.startDate,
    required this.endDate,
  })  : statuses = Set.unmodifiable(statuses),
        repositoryIds = Set.unmodifiable(repositoryIds);

  factory PullRequestFilter.defaults({DateTime? now}) {
    final today = now ?? DateTime.now();
    final endDate = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return PullRequestFilter(
      statuses: const {PullRequestStatus.active, PullRequestStatus.draft},
      startDate: endDate.subtract(const Duration(days: 29)),
      endDate: endDate,
    );
  }

  PullRequestFilter copyWith({
    Set<PullRequestStatus>? statuses,
    bool? personalOnly,
    Set<String>? repositoryIds,
    String? authorUniqueName,
    bool clearAuthor = false,
    String? targetBranch,
    bool clearTargetBranch = false,
    String? query,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return PullRequestFilter(
      statuses: statuses ?? this.statuses,
      personalOnly: personalOnly ?? this.personalOnly,
      repositoryIds: repositoryIds ?? this.repositoryIds,
      authorUniqueName:
          clearAuthor ? null : authorUniqueName ?? this.authorUniqueName,
      targetBranch:
          clearTargetBranch ? null : targetBranch ?? this.targetBranch,
      query: query ?? this.query,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

class PullRequestFilterService {
  static List<PullRequestSummary> filter({
    required Iterable<PullRequestSummary> pullRequests,
    required PullRequestFilter filter,
    PullRequestIdentity? currentUser,
  }) {
    final filtered = pullRequests.where((pullRequest) {
      if (!filter.statuses.contains(pullRequest.status) ||
          !_matchesNonStatusFilters(pullRequest, filter, currentUser)) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort(
        (left, right) => _activityDate(right).compareTo(_activityDate(left)));
    return filtered;
  }

  static Map<PullRequestStatus, int> statusCounts({
    required Iterable<PullRequestSummary> pullRequests,
    required PullRequestFilter filter,
    PullRequestIdentity? currentUser,
  }) {
    final counts = {for (final status in PullRequestStatus.values) status: 0};
    for (final pullRequest in pullRequests) {
      if (_matchesNonStatusFilters(pullRequest, filter, currentUser)) {
        counts[pullRequest.status] = counts[pullRequest.status]! + 1;
      }
    }
    return counts;
  }

  static bool _matchesNonStatusFilters(
    PullRequestSummary pullRequest,
    PullRequestFilter filter,
    PullRequestIdentity? currentUser,
  ) {
    if (filter.personalOnly &&
        (currentUser == null || !_isPersonal(pullRequest, currentUser))) {
      return false;
    }
    if (filter.repositoryIds.isNotEmpty &&
        !filter.repositoryIds.contains(pullRequest.repositoryId)) {
      return false;
    }
    if (filter.authorUniqueName != null &&
        !_equals(pullRequest.author.uniqueName, filter.authorUniqueName)) {
      return false;
    }
    if (filter.targetBranch != null &&
        !_equals(pullRequest.targetBranch, filter.targetBranch)) {
      return false;
    }
    final query = filter.query.trim().toLowerCase();
    if (query.isNotEmpty &&
        !pullRequest.id.toString().contains(query) &&
        !pullRequest.title.toLowerCase().contains(query)) {
      return false;
    }
    if (pullRequest.status == PullRequestStatus.active ||
        pullRequest.status == PullRequestStatus.draft) {
      return true;
    }
    final activity = _activityDate(pullRequest).toLocal();
    final start = DateTime(
        filter.startDate.year, filter.startDate.month, filter.startDate.day);
    final end = DateTime(filter.endDate.year, filter.endDate.month,
        filter.endDate.day, 23, 59, 59, 999);
    return !activity.isBefore(start) && !activity.isAfter(end);
  }

  static bool _isPersonal(
      PullRequestSummary pullRequest, PullRequestIdentity user) {
    return _equals(pullRequest.author.uniqueName, user.uniqueName) ||
        _equals(pullRequest.author.id, user.id) ||
        pullRequest.reviewers.any(
          (reviewer) =>
              _equals(reviewer.uniqueName, user.uniqueName) ||
              _equals(reviewer.id, user.id),
        );
  }

  static bool _equals(String? left, String? right) =>
      left != null &&
      right != null &&
      left.toLowerCase() == right.toLowerCase();

  static DateTime _activityDate(PullRequestSummary pullRequest) =>
      pullRequest.updatedAt ?? pullRequest.createdAt;
}
