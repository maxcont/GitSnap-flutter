import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/pull_request_models.dart';
import 'package:gitsnap_flutter/services/pull_request_filter_service.dart';

PullRequestSummary _pullRequest(PullRequestStatus status, DateTime updatedAt) {
  return PullRequestSummary(
    id: 1,
    title: 'PR',
    status: status,
    repositoryId: 'repo',
    repositoryName: 'Repo',
    author: const PullRequestIdentity(id: 'user', displayName: 'User'),
    reviewers: const [],
    sourceBranch: 'feature',
    targetBranch: 'develop',
    createdAt: updatedAt,
    updatedAt: updatedAt,
    webUrl: '',
  );
}

void main() {
  test('keeps active pull requests regardless of the selected date range', () {
    final result = PullRequestFilterService.filter(
      pullRequests: [
        _pullRequest(PullRequestStatus.active, DateTime(2024, 1, 1)),
      ],
      filter: PullRequestFilter.defaults(now: DateTime(2026, 9, 2)),
      currentUser: null,
    );

    expect(result, hasLength(1));
  });
}
