import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/azure_models.dart';
import 'package:gitsnap_flutter/models/release_note_models.dart';
import 'package:gitsnap_flutter/services/release_note_check_service.dart';

Commit _commit(String id, String message, {String author = 'Dev'}) => Commit(
      commitId: id,
      comment: message,
      author: CommitAuthor(name: author),
      date: '2026-11-10T10:00:00Z',
    );

ReleaseNotePullRequestData _pr(
  int id,
  String title, {
  String source = 'feature/x',
  String? description,
  String? mergeCommit,
  List<Commit> commits = const [],
}) =>
    ReleaseNotePullRequestData(
      pullRequest: ReleaseNotePullRequest.fromJson({
        'pullRequestId': id,
        'title': title,
        'status': 'completed',
        if (description != null) 'description': description,
        if (mergeCommit != null) 'lastMergeCommit': {'commitId': mergeCommit},
        'repository': {'id': 'r1', 'name': 'Repo'},
        'creationDate': '2026-11-01T10:00:00Z',
        'closedDate': '2026-11-0${id % 9 + 1}T10:00:00Z',
        'sourceRefName': 'refs/heads/$source',
        'targetRefName': 'refs/heads/release/1',
        'createdBy': {'id': 'u', 'displayName': 'User'},
      }),
      commits: commits,
    );

ReleaseNoteBranchData _branch({
  String repositoryId = 'r1',
  String repositoryName = 'Repo',
  List<ReleaseNotePullRequestData> pullRequests = const [],
  List<Commit> branchCommits = const [],
}) =>
    ReleaseNoteBranchData(
      repositoryId: repositoryId,
      repositoryName: repositoryName,
      repositoryUrl: 'https://host/$repositoryName',
      branch: 'release/1',
      pullRequests: pullRequests,
      branchCommits: branchCommits,
    );

void main() {
  group('findDirectCommits', () {
    test('excludes PR commits, merge commits and rebased copies', () {
      final data = _branch(
        pullRequests: [
          _pr(1, 'PR', mergeCommit: 'm1', commits: [
            _commit('a1', 'INC1 work'),
            _commit('a2', 'INC1 tests'),
          ]),
        ],
        branchCommits: [
          _commit('m1', 'Merged PR 1: PR'),
          _commit('a1', 'INC1 work'),
          _commit('zz', 'INC1 tests'), // rebased copy of a2
          _commit('d1', 'hotfix config'),
        ],
      );

      expect(
        ReleaseNoteCheckService.findDirectCommits(data).map((c) => c.commitId),
        ['d1'],
      );
    });

    test('does not treat empty messages as rebased copies', () {
      final data = _branch(
        pullRequests: [
          _pr(1, 'PR', commits: [_commit('a1', '')])
        ],
        branchCommits: [_commit('d1', '')],
      );

      expect(ReleaseNoteCheckService.findDirectCommits(data), hasLength(1));
    });

    test('excludes commits of PRs completed outside the period', () {
      final data = ReleaseNoteBranchData(
        repositoryId: 'r1',
        repositoryName: 'Repo',
        branch: 'release/1',
        pullRequests: const [],
        excludedPullRequests: [
          _pr(9, 'Later PR', mergeCommit: 'm9', commits: [
            _commit('l1', 'INC9 work'),
          ]),
        ],
        branchCommits: [_commit('l1', 'INC9 work'), _commit('d1', 'hotfix')],
      );

      expect(
        ReleaseNoteCheckService.findDirectCommits(data).map((c) => c.commitId),
        ['d1'],
      );
      final result =
          ReleaseNoteCheckService.check(entries: ['INC9'], branches: [data]);
      expect(result.items.map((item) => item.key), ['commit:r1:release/1:d1']);
      expect(result.missingEntries, ['INC9']);
    });
  });

  group('check', () {
    test('classifies PRs and direct commits and reports missing entries', () {
      final result = ReleaseNoteCheckService.check(
        entries: ['INC1', 'INC2', 'INC3', 'INC4'],
        branches: [
          _branch(
            pullRequests: [
              _pr(1, 'INC1 login'),
              _pr(2, 'Refactor', source: 'feature/INC2-x'),
              _pr(3, 'Other', description: 'Covers inc3'),
              _pr(4, 'No code', commits: [_commit('c4', 'INC4 detail')]),
              _pr(5, 'Logger'),
            ],
            branchCommits: [_commit('d1', 'hotfix config')],
          ),
        ],
      );

      final byKey = {for (final item in result.items) item.key: item};
      expect(byKey['pr:r1:1']!.automaticCategory, ReleaseNoteCategory.ok);
      expect(byKey['pr:r1:2']!.matchedEntries, {'INC2'});
      expect(byKey['pr:r1:3']!.automaticCategory, ReleaseNoteCategory.ok);
      expect(byKey['pr:r1:4']!.matchedEntries, {'INC4'});
      expect(byKey['pr:r1:5']!.automaticCategory, ReleaseNoteCategory.toVerify);
      expect(byKey['commit:r1:release/1:d1']!.kind,
          ReleaseNoteItemKind.directCommit);
      expect(byKey['commit:r1:release/1:d1']!.automaticCategory,
          ReleaseNoteCategory.toVerify);
      expect(result.missingEntries, isEmpty);
    });

    test('aggregates repositories and lists missing entries in input order',
        () {
      final result = ReleaseNoteCheckService.check(
        entries: ['INC9', 'INC1', 'INC8'],
        branches: [
          _branch(pullRequests: [_pr(1, 'INC1')]),
          _branch(
            repositoryId: 'r2',
            repositoryName: 'Repo2',
            branchCommits: [_commit('x', 'INC1 direct')],
          ),
        ],
        uninvolvedRepositories: ['Repo3'],
        warnings: ['w'],
      );

      expect(result.items, hasLength(2));
      expect(result.missingEntries, ['INC9', 'INC8']);
      expect(result.uninvolvedRepositories, ['Repo3']);
      expect(result.warnings, ['w']);
    });
  });

  group('parseEntries', () {
    test('trims, drops blanks and case-insensitive duplicates', () {
      expect(
        ReleaseNoteCheckService.parseEntries(' INC376 \r\n\ninc376\nCR_12\n'),
        ['INC376', 'CR_12'],
      );
    });
  });

  group('matches', () {
    test('is case-insensitive and respects word boundaries', () {
      expect(ReleaseNoteCheckService.matches('INC376', 'fix inc376: login'),
          isTrue);
      expect(ReleaseNoteCheckService.matches('INC376', '[INC376]'), isTrue);
      expect(ReleaseNoteCheckService.matches('INC376', 'feature/INC376-login'),
          isTrue);
      expect(ReleaseNoteCheckService.matches('INC376', 'INC3761'), isFalse);
      expect(ReleaseNoteCheckService.matches('INC376', 'XINC376'), isFalse);
    });

    test('treats regex characters literally', () {
      expect(ReleaseNoteCheckService.matches('RF(1)', 'done RF(1) ok'), isTrue);
      expect(ReleaseNoteCheckService.matches('a.b', 'axb'), isFalse);
    });
  });

  group('branch patterns', () {
    test('parses comma, semicolon and newline separated patterns', () {
      expect(
        ReleaseNoteCheckService.parseBranchPatterns(
            'release/1, release/2;\nrelease/1'),
        ['release/1', 'release/2'],
      );
    });

    test('supports exact names, wildcards and refs/heads prefix', () {
      expect(
          ReleaseNoteCheckService.matchesBranchPattern(
              'release/*', 'release/2026.11'),
          isTrue);
      expect(
          ReleaseNoteCheckService.matchesBranchPattern(
              'refs/heads/main', 'main'),
          isTrue);
      expect(
          ReleaseNoteCheckService.matchesBranchPattern(
              'release/1', 'release/10'),
          isFalse);
    });
  });
}
