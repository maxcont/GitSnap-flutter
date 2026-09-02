import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/pull_request_models.dart';

void main() {
  group('PullRequestIdentity.fromJson', () {
    test('uses Azure avatar link when imageUrl is absent', () {
      final identity = PullRequestIdentity.fromJson({
        'displayName': 'Ada',
        'uniqueName': 'ada@example.test',
        '_links': {
          'avatar': {
            'href':
                'https://dev.azure.com/org/_apis/GraphProfile/MemberAvatars/user-1',
          },
        },
      });

      expect(identity.displayName, 'Ada');
      expect(
        identity.imageUrl,
        'https://dev.azure.com/org/_apis/GraphProfile/MemberAvatars/user-1',
      );
    });
  });

  group('PullRequestSummary.fromJson', () {
    test('parses summary, prefers draft status and derives browser URL', () {
      final pullRequest = PullRequestSummary.fromJson({
        'pullRequestId': 42,
        'title': 'Improve dashboard',
        'status': 'active',
        'isDraft': true,
        'creationDate': '2026-09-01T09:00:00Z',
        'closedDate': null,
        'repository': {
          'id': 'repo-1',
          'name': 'Portal',
        },
        'createdBy': {
          'id': 'user-1',
          'displayName': 'Ada',
          'uniqueName': 'ada@example.test',
        },
        'reviewers': [
          {
            'id': 'user-2',
            'displayName': 'Grace',
            'uniqueName': 'grace@example.test',
            'vote': 10,
            'isRequired': true,
          },
        ],
        'sourceRefName': 'refs/heads/feature/dashboard',
        'targetRefName': 'refs/heads/main',
        'url':
            'https://dev.azure.com/org/project/_apis/git/repositories/repo-1/pullRequests/42',
      });

      expect(pullRequest.id, 42);
      expect(pullRequest.title, 'Improve dashboard');
      expect(pullRequest.status, PullRequestStatus.draft);
      expect(pullRequest.repositoryId, 'repo-1');
      expect(pullRequest.repositoryName, 'Portal');
      expect(pullRequest.author.displayName, 'Ada');
      expect(pullRequest.reviewers, hasLength(1));
      expect(pullRequest.reviewers.single.vote, 10);
      expect(pullRequest.reviewers.single.isRequired, isTrue);
      expect(pullRequest.sourceBranch, 'feature/dashboard');
      expect(pullRequest.targetBranch, 'main');
      expect(pullRequest.createdAt, DateTime.parse('2026-09-01T09:00:00Z'));
      expect(
        pullRequest.webUrl,
        'https://dev.azure.com/org/project/_git/Portal/pullrequest/42',
      );
    });

    test('keeps a provided Azure web URL when present', () {
      final pullRequest = PullRequestSummary.fromJson({
        'pullRequestId': 7,
        'title': 'Ship release',
        'status': 'completed',
        'creationDate': '2026-08-31T18:00:00Z',
        'repository': {
          'id': 'repo-2',
          'name': 'Mobile App',
        },
        'createdBy': {
          'displayName': 'Linus',
        },
        'sourceRefName': 'release/1.0.0',
        'targetRefName': 'refs/heads/main',
        '_links': {
          'web': {
            'href':
                'https://dev.azure.com/org/project/_git/Mobile%20App/pullrequest/7',
          },
        },
      });

      expect(pullRequest.status, PullRequestStatus.completed);
      expect(
        pullRequest.webUrl,
        'https://dev.azure.com/org/project/_git/Mobile%20App/pullrequest/7',
      );
    });
  });

  group('PullRequestMetrics.fromJson', () {
    test('parses commit file thread and comment counts from realistic maps',
        () {
      final metrics = PullRequestMetrics.fromJson({
        'commits': {
          'count': '5',
        },
        'files': {
          'count': 4,
        },
        'threads': {
          'count': 2,
          'value': [
            {
              'comments': [{}, {}],
            },
            {
              'comments': [{}],
            },
          ],
        },
      });

      expect(metrics.commitCount, 5);
      expect(metrics.changedFileCount, 4);
      expect(metrics.threadCount, 2);
      expect(metrics.commentCount, 3);
    });
  });

  group('PullRequestDetails.fromJson', () {
    test('parses description, merge and policy fields with nested metrics', () {
      final details = PullRequestDetails.fromJson({
        'pullRequestId': '99',
        'title': 'Improve validation',
        'status': 'abandoned',
        'creationDate': '2026-08-20T10:00:00Z',
        'closedDate': '2026-08-22T11:30:00Z',
        'lastUpdatedDate': '2026-08-22T12:00:00Z',
        'description': 'Adds validation to pull request filters.',
        'mergeStatus': 'rejectedByPolicy',
        'mergeFailureType': 'unknown',
        'mergeFailureMessage': 'A required policy has not been satisfied.',
        'policyStatus': 'notApproved',
        'completionQueueTime': '2026-08-22T12:10:00Z',
        'supportsIterations': true,
        'repository': {
          'id': 'repo-3',
          'name': 'API',
          'remoteUrl': 'https://dev.azure.com/org/project/_git/API',
        },
        'createdBy': {
          'id': 'user-3',
          'displayName': 'Margaret',
          'uniqueName': 'margaret@example.test',
        },
        'autoCompleteSetBy': {
          'id': 'user-4',
          'displayName': 'Alan',
        },
        'reviewers': [
          {
            'id': 'user-5',
            'displayName': 'Required Reviewer',
            'vote': -5,
            'isRequired': true,
            'hasDeclined': false,
            'isFlagged': true,
          },
        ],
        'sourceRefName': 'refs/heads/feature/validation',
        'targetRefName': 'refs/heads/develop',
        'metrics': {
          'commits': {
            'value': [{}, {}, {}],
          },
          'changes': {
            'changes': [{}, {}],
          },
          'threads': {
            'value': [
              {
                'comments': [{}, {}],
              },
              {
                'comments': [{}],
              },
            ],
          },
        },
      });

      expect(details.id, 99);
      expect(details.status, PullRequestStatus.abandoned);
      expect(details.description, 'Adds validation to pull request filters.');
      expect(details.mergeStatus, 'rejectedByPolicy');
      expect(details.mergeFailureType, 'unknown');
      expect(
        details.mergeFailureMessage,
        'A required policy has not been satisfied.',
      );
      expect(details.policyStatus, 'notApproved');
      expect(details.supportsIterations, isTrue);
      expect(details.autoCompleteSetBy?.displayName, 'Alan');
      expect(details.reviewers.single.vote, -5);
      expect(details.reviewers.single.isFlagged, isTrue);
      expect(details.metrics?.commitCount, 3);
      expect(details.metrics?.changedFileCount, 2);
      expect(details.metrics?.threadCount, 2);
      expect(details.metrics?.commentCount, 3);
      expect(
        details.webUrl,
        'https://dev.azure.com/org/project/_git/API/pullrequest/99',
      );
    });
  });
}
