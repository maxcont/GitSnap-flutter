# Verifica Release Note Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Verifica Release Note" view that lists everything merged into
one or more release branches (completed PRs plus direct commits) across
repositories and compares it with a list of Release Note strings.

**Architecture:** Azure DevOps calls live in `AzureDevOpsClient` (new paginated
methods) and are orchestrated by `ReleaseNoteDataLoader`. All matching and
classification is pure Dart in `ReleaseNoteCheckService`. `AppState` holds the
result and manual moves; `ReleaseNoteCheckTab` (filters) and
`ReleaseNoteResultsView` (results, testable without `AppState`) render it as a
third nested tab of *PR e commit*.

**Tech Stack:** Flutter, Dart, `provider`, `http` (+ `http/testing.dart`
`MockClient` with `http.runWithClient` in tests), `intl`.

**Spec:** `docs/superpowers/specs/2026-11-24-release-note-check-design.md`

**Branch:** `feature/release-note-check`

---

## File structure

| File | Responsibility |
|---|---|
| Create `lib/models/release_note_models.dart` | Categories, PR wrapper with description/merge commit, loader input data, result items |
| Create `lib/services/release_note_check_service.dart` | Pure logic: parse entries and branch patterns, match, find direct commits, classify |
| Modify `lib/services/azure_devops_client.dart` | `getCompletedPullRequests`, `getPullRequestCommits`, pagination in `getCommitsForBranch` |
| Create `lib/services/release_note_data_loader.dart` | Per repository/branch calls with concurrency, progress, warnings |
| Modify `lib/providers/app_state.dart` | Check state, `runReleaseNoteCheck`, manual moves |
| Create `lib/widgets/release_note_results_view.dart` | Results: warnings, counters, missing entries, three lists, "Sposta in…" |
| Create `lib/widgets/release_note_check_tab.dart` | Filters and RN input; hosts the results view |
| Modify `lib/widgets/pull_requests_tab.dart` | Third nested tab |
| Modify `README.md` | Feature description |
| Tests in `test/` | One file per unit (see tasks) |

Commands are run from the repository root
`C:\Users\mcontursi\Documents\progetti\personal\gitsnap_flutter\gitsnap_flutter`.

---

### Task 1: Models

**Files:**
- Create: `lib/models/release_note_models.dart`
- Test: `test/release_note_models_test.dart`

- [ ] **Step 1: Write the failing test**

`test/release_note_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/release_note_models.dart';

void main() {
  test('parses description and last merge commit from PR json', () {
    final pr = ReleaseNotePullRequest.fromJson({
      'pullRequestId': 7,
      'title': 'INC376 login',
      'status': 'completed',
      'description': 'Fix INC376',
      'lastMergeCommit': {'commitId': 'abc'},
      'repository': {'id': 'r1', 'name': 'Repo'},
      'creationDate': '2026-11-01T10:00:00Z',
      'closedDate': '2026-11-02T10:00:00Z',
      'sourceRefName': 'refs/heads/feature/INC376',
      'targetRefName': 'refs/heads/release/1',
      'createdBy': {'id': 'u', 'displayName': 'User'},
    });

    expect(pr.summary.id, 7);
    expect(pr.summary.sourceBranch, 'feature/INC376');
    expect(pr.description, 'Fix INC376');
    expect(pr.lastMergeCommitId, 'abc');
  });

  test('tolerates missing description and merge commit', () {
    final pr = ReleaseNotePullRequest.fromJson({
      'pullRequestId': 8,
      'title': 'x',
      'status': 'completed',
      'repository': {'id': 'r1', 'name': 'Repo'},
      'createdBy': {'id': 'u', 'displayName': 'User'},
    });

    expect(pr.description, isNull);
    expect(pr.lastMergeCommitId, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/release_note_models_test.dart`
Expected: FAIL, `release_note_models.dart` not found.

- [ ] **Step 3: Write the models**

`lib/models/release_note_models.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/release_note_models_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```powershell
git add lib/models/release_note_models.dart test/release_note_models_test.dart
git commit -m "feat: add release note check models"
```

---

### Task 2: Parsing and matching

**Files:**
- Create: `lib/services/release_note_check_service.dart`
- Test: `test/release_note_check_service_test.dart`

- [ ] **Step 1: Write the failing tests**

`test/release_note_check_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/services/release_note_check_service.dart';

void main() {
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
      expect(
          ReleaseNoteCheckService.matches('INC376', 'feature/INC376-login'),
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
      expect(ReleaseNoteCheckService.matchesBranchPattern(
          'release/*', 'release/2026.11'), isTrue);
      expect(ReleaseNoteCheckService.matchesBranchPattern(
          'refs/heads/main', 'main'), isTrue);
      expect(ReleaseNoteCheckService.matchesBranchPattern(
          'release/1', 'release/10'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/release_note_check_service_test.dart`
Expected: FAIL, `release_note_check_service.dart` not found.

- [ ] **Step 3: Implement**

`lib/services/release_note_check_service.dart`:

```dart
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
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/release_note_check_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/services/release_note_check_service.dart test/release_note_check_service_test.dart
git commit -m "feat: add release note entry parsing and matching"
```

---

### Task 3: Direct commits and classification

**Files:**
- Modify: `lib/services/release_note_check_service.dart`
- Test: `test/release_note_check_service_test.dart`

- [ ] **Step 1: Write the failing tests**

Add these imports at the top of `test/release_note_check_service_test.dart`:

```dart
import 'package:gitsnap_flutter/models/azure_models.dart';
import 'package:gitsnap_flutter/models/release_note_models.dart';
```

Add these helpers above `void main()`:

```dart
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
```

Add these groups inside `main()`:

```dart
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
        ReleaseNoteCheckService.findDirectCommits(data)
            .map((c) => c.commitId),
        ['d1'],
      );
    });

    test('does not treat empty messages as rebased copies', () {
      final data = _branch(
        pullRequests: [_pr(1, 'PR', commits: [_commit('a1', '')])],
        branchCommits: [_commit('d1', '')],
      );

      expect(ReleaseNoteCheckService.findDirectCommits(data), hasLength(1));
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
      expect(byKey['pr:r1:5']!.automaticCategory,
          ReleaseNoteCategory.toVerify);
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/release_note_check_service_test.dart`
Expected: FAIL, `findDirectCommits` and `check` are not defined.

- [ ] **Step 3: Implement**

In `lib/services/release_note_check_service.dart` add at the top:

```dart
import '../models/azure_models.dart';
import '../models/release_note_models.dart';
```

and add inside `ReleaseNoteCheckService`:

```dart
  static List<Commit> findDirectCommits(ReleaseNoteBranchData data) {
    final pullRequestCommitIds = <String>{};
    final pullRequestSignatures = <String>{};
    for (final pullRequest in data.pullRequests) {
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
    items.sort((left, right) => (right.date ?? DateTime(1970))
        .compareTo(left.date ?? DateTime(1970)));
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/release_note_check_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/services/release_note_check_service.dart test/release_note_check_service_test.dart
git commit -m "feat: classify merged pull requests and direct commits"
```

---

### Task 4: Paginated Azure DevOps calls

**Files:**
- Modify: `lib/services/azure_devops_client.dart` (add import; replace
  `getCommitsForBranch`; add two methods after it)
- Test: `test/release_note_client_test.dart`

- [ ] **Step 1: Write the failing tests**

`test/release_note_client_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/services/azure_devops_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

AzureDevOpsClient _client() =>
    AzureDevOpsClient(organization: 'org', project: 'project', pat: 'secret');

Map<String, dynamic> _commitJson(String id) => {
      'commitId': id,
      'comment': 'msg $id',
      'author': {'name': 'Dev', 'date': '2026-11-10T10:00:00Z'},
    };

Map<String, dynamic> _prJson(int id) => {
      'pullRequestId': id,
      'title': 'PR $id',
      'status': 'completed',
      'repository': {'id': 'repo', 'name': 'Repo'},
      'createdBy': {'id': 'u', 'displayName': 'User'},
    };

void main() {
  test('getCommitsForBranch follows \$skip pages', () async {
    final skips = <String?>[];
    final commits = await http.runWithClient(
      () => _client().getCommitsForBranch('repo', 'release/1',
          from: DateTime.utc(2026, 11, 1), to: DateTime.utc(2026, 11, 30),
          pageSize: 2),
      () => MockClient((request) async {
        final skip = request.url.queryParameters[r'$skip'];
        skips.add(skip);
        final page = switch (skip) {
          '0' => [_commitJson('a'), _commitJson('b')],
          '2' => [_commitJson('c')],
          _ => <Map<String, dynamic>>[],
        };
        return http.Response(jsonEncode({'value': page}), 200);
      }),
    );

    expect(commits.map((c) => c.commitId), ['a', 'b', 'c']);
    expect(skips, ['0', '2']);
  });

  test('getCommitsForBranch stops when the server ignores \$skip', () async {
    final commits = await http.runWithClient(
      () => _client().getCommitsForBranch('repo', 'release/1',
          from: DateTime.utc(2026, 11, 1), to: DateTime.utc(2026, 11, 30),
          pageSize: 2),
      () => MockClient((_) async => http.Response(
          jsonEncode({'value': [_commitJson('a'), _commitJson('b')]}), 200)),
    );

    expect(commits.map((c) => c.commitId), ['a', 'b']);
  });

  test('getCompletedPullRequests filters by status and target and pages',
      () async {
    final requests = <Uri>[];
    final pullRequests = await http.runWithClient(
      () => _client().getCompletedPullRequests('repo', 'release/1',
          pageSize: 1),
      () => MockClient((request) async {
        requests.add(request.url);
        final skip = request.url.queryParameters[r'$skip'];
        final page = skip == '0' ? [_prJson(1)] : <Map<String, dynamic>>[];
        return http.Response(jsonEncode({'value': page}), 200);
      }),
    );

    expect(pullRequests.single.summary.id, 1);
    expect(requests.first.queryParameters['searchCriteria.status'],
        'completed');
    expect(requests.first.queryParameters['searchCriteria.targetRefName'],
        'refs/heads/release/1');
  });

  test('getPullRequestCommits follows continuation tokens', () async {
    final commits = await http.runWithClient(
      () => _client().getPullRequestCommits('repo', 5),
      () => MockClient((request) async {
        expect(request.url.path, endsWith('/pullRequests/5/commits'));
        final token = request.url.queryParameters['continuationToken'];
        return token == null
            ? http.Response(jsonEncode({'value': [_commitJson('a')]}), 200,
                headers: {'x-ms-continuationtoken': 't1'})
            : http.Response(jsonEncode({'value': [_commitJson('b')]}), 200);
      }),
    );

    expect(commits.map((c) => c.commitId), ['a', 'b']);
  });

  test('getPullRequestCommits throws on HTTP errors', () async {
    await expectLater(
      http.runWithClient(
        () => _client().getPullRequestCommits('repo', 5),
        () => MockClient((_) async => http.Response('boom', 500)),
      ),
      throwsA(isA<AzureDevOpsClientError>()),
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/release_note_client_test.dart`
Expected: FAIL to compile (`pageSize`, `getCompletedPullRequests`,
`getPullRequestCommits` undefined).

- [ ] **Step 3: Implement**

Add to the imports of `lib/services/azure_devops_client.dart`:

```dart
import '../models/release_note_models.dart';
```

Replace the whole existing `getCommitsForBranch` method with:

```dart
  Future<List<Commit>> getCommitsForBranch(
    String repositoryId,
    String branchName, {
    required DateTime from,
    required DateTime to,
    int pageSize = 2000,
  }) async {
    final commits = <Commit>[];
    final seen = <String>{};
    for (var skip = 0;; skip += pageSize) {
      final url = Uri.parse('$_apiBase/git/repositories/$repositoryId/commits')
          .replace(queryParameters: {
        'api-version': '7.0',
        r'$top': '$pageSize',
        r'$skip': '$skip',
        'searchCriteria.itemVersion.version': branchName,
        'searchCriteria.itemVersion.versionType': 'branch',
        'searchCriteria.fromDate': from.toUtc().toIso8601String(),
        'searchCriteria.toDate': to.toUtc().toIso8601String(),
      });
      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) {
        throw AzureDevOpsClientError(
          'Failed to fetch commits: ${response.statusCode}. '
          '${_messageForStatus(response.statusCode, response.body)}',
        );
      }
      final data = json.decode(response.body) as Map<String, dynamic>;
      final page = (data['value'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => Commit.fromJson(Map<String, dynamic>.from(value)))
          .toList();
      final before = seen.length;
      for (final commit in page) {
        if (seen.add(commit.commitId)) commits.add(commit);
      }
      // A server ignoring $skip would return the same page forever.
      if (page.length < pageSize || seen.length == before) return commits;
    }
  }

  Future<List<ReleaseNotePullRequest>> getCompletedPullRequests(
    String repositoryId,
    String targetBranch, {
    int pageSize = 500,
  }) async {
    final targetRef = targetBranch.startsWith('refs/heads/')
        ? targetBranch
        : 'refs/heads/$targetBranch';
    final pullRequests = <ReleaseNotePullRequest>[];
    final seen = <int>{};
    for (var skip = 0;; skip += pageSize) {
      final url =
          Uri.parse('$_apiBase/git/repositories/$repositoryId/pullrequests')
              .replace(queryParameters: {
        'api-version': '7.0',
        'searchCriteria.status': 'completed',
        'searchCriteria.targetRefName': targetRef,
        r'$top': '$pageSize',
        r'$skip': '$skip',
      });
      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) {
        throw AzureDevOpsClientError(
          'Failed to fetch pull requests: ${response.statusCode}. '
          '${_messageForStatus(response.statusCode, response.body)}',
        );
      }
      final data = json.decode(response.body) as Map<String, dynamic>;
      final page = (data['value'] as List? ?? const [])
          .whereType<Map>()
          .map((value) =>
              ReleaseNotePullRequest.fromJson(Map<String, dynamic>.from(value)))
          .toList();
      final before = seen.length;
      for (final pullRequest in page) {
        if (seen.add(pullRequest.summary.id)) pullRequests.add(pullRequest);
      }
      if (page.length < pageSize || seen.length == before) {
        return pullRequests;
      }
    }
  }

  Future<List<Commit>> getPullRequestCommits(
    String repositoryId,
    int pullRequestId,
  ) async {
    final commits = <Commit>[];
    String? token;
    final usedTokens = <String>{};
    do {
      final url = Uri.parse(
              '$_apiBase/git/repositories/$repositoryId/pullRequests/$pullRequestId/commits')
          .replace(queryParameters: {
        'api-version': '7.0',
        r'$top': '500',
        if (token != null) 'continuationToken': token,
      });
      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) {
        throw AzureDevOpsClientError(
          'Failed to fetch pull request commits: ${response.statusCode}. '
          '${_messageForStatus(response.statusCode, response.body)}',
        );
      }
      final data = json.decode(response.body) as Map<String, dynamic>;
      commits.addAll((data['value'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => Commit.fromJson(Map<String, dynamic>.from(value))));
      token = response.headers['x-ms-continuationtoken'];
    } while (token != null && token.isNotEmpty && usedTokens.add(token));
    return commits;
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/release_note_client_test.dart test/commit_pull_request_history_test.dart`
Expected: PASS (new tests and existing client tests).

- [ ] **Step 5: Commit**

```powershell
git add lib/services/azure_devops_client.dart test/release_note_client_test.dart
git commit -m "feat: add paginated pull request and commit queries"
```

---

### Task 5: Data loader

**Files:**
- Create: `lib/services/release_note_data_loader.dart`
- Test: `test/release_note_data_loader_test.dart`

- [ ] **Step 1: Write the failing test**

`test/release_note_data_loader_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/azure_models.dart';
import 'package:gitsnap_flutter/services/azure_devops_client.dart';
import 'package:gitsnap_flutter/services/release_note_data_loader.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _pr(int id, String closed) => {
      'pullRequestId': id,
      'title': 'PR $id',
      'status': 'completed',
      'closedDate': closed,
      'repository': {'id': 'r1', 'name': 'Repo1'},
      'createdBy': {'id': 'u', 'displayName': 'User'},
    };

void main() {
  test('loads matching branches, filters PRs by period, reports others',
      () async {
    final result = await http.runWithClient(
      () => ReleaseNoteDataLoader(AzureDevOpsClient(
              organization: 'org', project: 'project', pat: 'secret'))
          .load(
        repositories: [
          Repository(id: 'r1', name: 'Repo1', remoteUrl: 'https://h/r1'),
          Repository(id: 'r2', name: 'Repo2'),
          Repository(id: 'r3', name: 'Repo3'),
        ],
        branchPatterns: ['release/*'],
        from: DateTime.utc(2026, 11, 1),
        to: DateTime.utc(2026, 11, 30, 23, 59, 59),
      ),
      () => MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/r3/')) return http.Response('boom', 500);
        if (path.endsWith('/refs')) {
          final names = path.contains('/r1/')
              ? ['refs/heads/release/1', 'refs/heads/main']
              : ['refs/heads/main'];
          return http.Response(
              jsonEncode({'value': [for (final n in names) {'name': n}]}),
              200);
        }
        if (path.endsWith('/pullrequests')) {
          return http.Response(
              jsonEncode({
                'value': [
                  _pr(1, '2026-11-10T10:00:00Z'),
                  _pr(2, '2026-10-10T10:00:00Z'),
                ]
              }),
              200);
        }
        if (path.endsWith('/pullRequests/1/commits')) {
          return http.Response(
              jsonEncode({
                'value': [
                  {'commitId': 'c1', 'comment': 'INC1'}
                ]
              }),
              200);
        }
        if (path.endsWith('/commits')) {
          return http.Response(
              jsonEncode({
                'value': [
                  {'commitId': 'd1', 'comment': 'hotfix'}
                ]
              }),
              200);
        }
        return http.Response('not found', 404);
      }),
    );

    final branch = result.branches.single;
    expect(branch.repositoryName, 'Repo1');
    expect(branch.branch, 'release/1');
    expect(branch.repositoryUrl, 'https://h/r1');
    expect(branch.pullRequests.single.pullRequest.summary.id, 1);
    expect(branch.pullRequests.single.commits.single.commitId, 'c1');
    expect(branch.branchCommits.single.commitId, 'd1');
    expect(result.uninvolvedRepositories, ['Repo2']);
    expect(result.warnings.single, startsWith('Repo3'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/release_note_data_loader_test.dart`
Expected: FAIL, `release_note_data_loader.dart` not found.

- [ ] **Step 3: Implement**

`lib/services/release_note_data_loader.dart`:

```dart
import '../models/azure_models.dart';
import '../models/release_note_models.dart';
import 'azure_devops_client.dart';
import 'release_note_check_service.dart';

typedef ReleaseNoteProgress = void Function(
    String phase, int completed, int total);

class ReleaseNoteLoadResult {
  final List<ReleaseNoteBranchData> branches;
  final List<String> uninvolvedRepositories;
  final List<String> warnings;

  const ReleaseNoteLoadResult({
    required this.branches,
    required this.uninvolvedRepositories,
    required this.warnings,
  });
}

class ReleaseNoteDataLoader {
  final AzureDevOpsClient client;
  final int concurrency;

  ReleaseNoteDataLoader(this.client, {this.concurrency = 5});

  Future<ReleaseNoteLoadResult> load({
    required List<Repository> repositories,
    required List<String> branchPatterns,
    required DateTime from,
    required DateTime to,
    ReleaseNoteProgress? onProgress,
  }) async {
    final warnings = <String>[];
    final uninvolved = <String>[];

    final targets = <({Repository repo, String branch})>[];
    await _inChunks<Repository>(
      repositories,
      'Lettura branch dei repository',
      onProgress,
      (repo) async {
        try {
          final branches = (await client.getBranches(repo.id))
              .map((b) => (b['name'] as String? ?? '')
                  .replaceFirst('refs/heads/', ''))
              .where((name) =>
                  name.isNotEmpty &&
                  branchPatterns.any((pattern) => ReleaseNoteCheckService
                      .matchesBranchPattern(pattern, name)))
              .toList()
            ..sort();
          if (branches.isEmpty) {
            uninvolved.add(repo.name);
          } else {
            targets.addAll(branches.map((b) => (repo: repo, branch: b)));
          }
        } catch (error) {
          warnings.add('${repo.name}: impossibile leggere le branch ($error)');
        }
      },
    );

    final loaded = <({
      Repository repo,
      String branch,
      List<ReleaseNotePullRequest> pullRequests,
      List<Commit> branchCommits,
    })>[];
    await _inChunks<({Repository repo, String branch})>(
      targets,
      'Lettura pull request e commit delle branch',
      onProgress,
      (target) async {
        try {
          final results = await Future.wait([
            client.getCompletedPullRequests(target.repo.id, target.branch),
            client.getCommitsForBranch(target.repo.id, target.branch,
                from: from, to: to),
          ]);
          final pullRequests = (results[0] as List<ReleaseNotePullRequest>)
              .where((pr) {
            final closedAt = pr.summary.closedAt;
            return closedAt != null &&
                !closedAt.isBefore(from) &&
                !closedAt.isAfter(to);
          }).toList();
          loaded.add((
            repo: target.repo,
            branch: target.branch,
            pullRequests: pullRequests,
            branchCommits: results[1] as List<Commit>,
          ));
        } catch (error) {
          warnings.add('${target.repo.name}/${target.branch}: $error');
        }
      },
    );

    final prCommits = <String, List<Commit>>{};
    final prRequests = [
      for (final entry in loaded)
        for (final pr in entry.pullRequests) (repo: entry.repo, pr: pr),
    ];
    await _inChunks<({Repository repo, ReleaseNotePullRequest pr})>(
      prRequests,
      'Lettura commit delle pull request',
      onProgress,
      (request) async {
        final id = request.pr.summary.id;
        try {
          prCommits['${request.repo.id}:$id'] =
              await client.getPullRequestCommits(request.repo.id, id);
        } catch (error) {
          warnings.add('${request.repo.name} PR $id: commit non letti ($error)');
        }
      },
    );

    final branches = [
      for (final entry in loaded)
        ReleaseNoteBranchData(
          repositoryId: entry.repo.id,
          repositoryName: entry.repo.name,
          repositoryUrl: entry.repo.remoteUrl,
          branch: entry.branch,
          pullRequests: [
            for (final pr in entry.pullRequests)
              ReleaseNotePullRequestData(
                pullRequest: pr,
                commits:
                    prCommits['${entry.repo.id}:${pr.summary.id}'] ?? const [],
              ),
          ],
          branchCommits: entry.branchCommits,
        ),
    ]..sort((a, b) => '${a.repositoryName}/${a.branch}'
        .compareTo('${b.repositoryName}/${b.branch}'));
    uninvolved.sort();
    return ReleaseNoteLoadResult(
      branches: branches,
      uninvolvedRepositories: uninvolved,
      warnings: warnings,
    );
  }

  Future<void> _inChunks<T>(
    List<T> items,
    String phase,
    ReleaseNoteProgress? onProgress,
    Future<void> Function(T item) action,
  ) async {
    var completed = 0;
    onProgress?.call(phase, completed, items.length);
    for (var index = 0; index < items.length; index += concurrency) {
      final chunk = items.skip(index).take(concurrency);
      await Future.wait(chunk.map(action));
      completed += chunk.length;
      onProgress?.call(phase, completed, items.length);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/release_note_data_loader_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/services/release_note_data_loader.dart test/release_note_data_loader_test.dart
git commit -m "feat: load merged pull requests and branch commits for release check"
```

---

### Task 6: AppState

**Files:**
- Modify: `lib/providers/app_state.dart` (imports, fields after the commit
  search fields, getters after `commitSearchTotal`, methods before
  `// Run comparison`)

No dedicated test: `AppState` requires storage and network; behavior is
covered by the service, loader and widget tests. Verify with analysis.

- [ ] **Step 1: Add imports**

```dart
import '../models/release_note_models.dart';
import '../services/release_note_check_service.dart';
import '../services/release_note_data_loader.dart';
```

- [ ] **Step 2: Add fields** (after `int _commitSearchTotal = 0;`)

```dart
  ReleaseNoteCheckResult? _releaseNoteResult;
  Map<String, ReleaseNoteCategory> _releaseNoteMoves = {};
  bool _isCheckingReleaseNote = false;
  String? _releaseNoteError;
  String _releaseNotePhase = '';
  int _releaseNoteCompleted = 0;
  int _releaseNoteTotal = 0;
```

- [ ] **Step 3: Add getters** (after `int get commitSearchTotal => ...;`)

```dart
  ReleaseNoteCheckResult? get releaseNoteResult => _releaseNoteResult;
  bool get isCheckingReleaseNote => _isCheckingReleaseNote;
  String? get releaseNoteError => _releaseNoteError;
  String get releaseNotePhase => _releaseNotePhase;
  int get releaseNoteCompleted => _releaseNoteCompleted;
  int get releaseNoteTotal => _releaseNoteTotal;

  ReleaseNoteCategory releaseNoteCategoryOf(ReleaseNoteItem item) =>
      _releaseNoteMoves[item.key] ?? item.automaticCategory;
```

- [ ] **Step 4: Add methods** (before `// Run comparison`)

```dart
  Future<void> runReleaseNoteCheck({
    required String entriesText,
    required String branchPatternsText,
    required Set<String> repositoryIds,
    required DateTime from,
    required DateTime to,
  }) async {
    final entries = ReleaseNoteCheckService.parseEntries(entriesText);
    final branchPatterns =
        ReleaseNoteCheckService.parseBranchPatterns(branchPatternsText);
    if (_client == null) {
      _releaseNoteError = 'Carica prima i repository.';
      notifyListeners();
      return;
    }
    if (entries.isEmpty || branchPatterns.isEmpty) {
      _releaseNoteError =
          'Inserisci almeno una branch e una stringa della Release Note.';
      notifyListeners();
      return;
    }
    _isCheckingReleaseNote = true;
    _releaseNoteError = null;
    _releaseNoteResult = null;
    _releaseNoteMoves = {};
    _releaseNotePhase = 'Preparazione della verifica';
    _releaseNoteCompleted = 0;
    _releaseNoteTotal = 0;
    notifyListeners();
    try {
      final repositories = _repositories
          .where((repo) =>
              repositoryIds.isEmpty || repositoryIds.contains(repo.id))
          .toList();
      final loaded = await ReleaseNoteDataLoader(_client!).load(
        repositories: repositories,
        branchPatterns: branchPatterns,
        from: from,
        to: to,
        onProgress: (phase, completed, total) {
          _releaseNotePhase = phase;
          _releaseNoteCompleted = completed;
          _releaseNoteTotal = total;
          notifyListeners();
        },
      );
      _releaseNoteResult = ReleaseNoteCheckService.check(
        entries: entries,
        branches: loaded.branches,
        uninvolvedRepositories: loaded.uninvolvedRepositories,
        warnings: loaded.warnings,
      );
    } catch (error) {
      _releaseNoteError = 'Errore durante la verifica: $error';
    } finally {
      _isCheckingReleaseNote = false;
      notifyListeners();
    }
  }

  void moveReleaseNoteItem(ReleaseNoteItem item, ReleaseNoteCategory category) {
    if (category == item.automaticCategory) {
      _releaseNoteMoves.remove(item.key);
    } else {
      _releaseNoteMoves[item.key] = category;
    }
    notifyListeners();
  }
```

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/providers/app_state.dart`
Expected: `No issues found!` (or only issues already present on `main`).

- [ ] **Step 6: Commit**

```powershell
git add lib/providers/app_state.dart
git commit -m "feat: hold release note check state in AppState"
```

---

### Task 7: Results view

**Files:**
- Create: `lib/widgets/release_note_results_view.dart`
- Test: `test/release_note_results_view_test.dart`

- [ ] **Step 1: Write the failing widget test**

`test/release_note_results_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/azure_models.dart';
import 'package:gitsnap_flutter/models/release_note_models.dart';
import 'package:gitsnap_flutter/services/release_note_check_service.dart';
import 'package:gitsnap_flutter/widgets/release_note_results_view.dart';

ReleaseNoteCheckResult _result() => ReleaseNoteCheckService.check(
      entries: ['INC1', 'INC9'],
      branches: [
        ReleaseNoteBranchData(
          repositoryId: 'r1',
          repositoryName: 'Repo1',
          branch: 'release/1',
          pullRequests: [
            ReleaseNotePullRequestData(
              pullRequest: ReleaseNotePullRequest.fromJson({
                'pullRequestId': 1,
                'title': 'INC1 login',
                'status': 'completed',
                'closedDate': '2026-11-10T10:00:00Z',
                'repository': {'id': 'r1', 'name': 'Repo1'},
                'sourceRefName': 'refs/heads/feature/a',
                'targetRefName': 'refs/heads/release/1',
                'createdBy': {'id': 'u', 'displayName': 'User'},
              }),
              commits: [Commit(commitId: 'c1abcdef', comment: 'INC1 work')],
            ),
          ],
          branchCommits: [Commit(commitId: 'd1abcdef', comment: 'hotfix')],
        ),
      ],
      uninvolvedRepositories: ['Repo2'],
      warnings: ['Repo3: errore'],
    );

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final result = _result();
  final moves = <String, ReleaseNoteCategory>{};

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReleaseNoteResultsView(
              result: result,
              categoryOf: (item) => moves[item.key] ?? item.automaticCategory,
              onMove: (item, category) =>
                  setState(() => moves[item.key] = category),
            ),
          ),
        ),
      );
}

void main() {
  testWidgets('shows counters, missing entries and moves items',
      (tester) async {
    await tester.pumpWidget(const _Host());

    expect(find.text('Mancanti: 1'), findsOneWidget);
    expect(find.text('OK: 1'), findsOneWidget);
    expect(find.text('Da verificare: 1'), findsOneWidget);
    expect(find.text('Fuori perimetro: 0'), findsOneWidget);
    expect(find.text('INC9'), findsOneWidget);
    expect(find.textContaining('Repo2'), findsOneWidget);
    expect(find.textContaining('Repo3: errore'), findsOneWidget);
    expect(find.text('Commit diretto'), findsOneWidget);

    await tester.tap(find.byTooltip('Sposta in…').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fuori perimetro').last);
    await tester.pumpAndSettle();

    expect(find.text('Da verificare: 0'), findsOneWidget);
    expect(find.text('Fuori perimetro: 1'), findsOneWidget);
    expect(find.byTooltip('Spostato manualmente'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/release_note_results_view_test.dart`
Expected: FAIL, `release_note_results_view.dart` not found.

- [ ] **Step 3: Implement**

`lib/widgets/release_note_results_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/release_note_models.dart';
import 'external_link.dart';

class ReleaseNoteResultsView extends StatelessWidget {
  final ReleaseNoteCheckResult result;
  final ReleaseNoteCategory Function(ReleaseNoteItem item) categoryOf;
  final void Function(ReleaseNoteItem item, ReleaseNoteCategory category)
      onMove;

  const ReleaseNoteResultsView({
    super.key,
    required this.result,
    required this.categoryOf,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = {
      for (final category in ReleaseNoteCategory.values)
        category: <ReleaseNoteItem>[],
    };
    for (final item in result.items) {
      grouped[categoryOf(item)]!.add(item);
    }
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.warnings.isNotEmpty)
          Text('Verifica incompleta per: ${result.warnings.join(' · ')}',
              style: TextStyle(color: errorColor)),
        if (result.uninvolvedRepositories.isNotEmpty)
          Text(
              'Repository non coinvolti (branch assente): '
              '${result.uninvolvedRepositories.join(', ')}'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(
            avatar: const Icon(Icons.report_outlined, size: 18),
            label: Text('Mancanti: ${result.missingEntries.length}'),
          ),
          for (final category in ReleaseNoteCategory.values)
            Chip(
              avatar: Icon(_icon(category), size: 18),
              label: Text('${category.label}: ${grouped[category]!.length}'),
            ),
        ]),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            initiallyExpanded: result.missingEntries.isNotEmpty,
            leading: const Icon(Icons.report_outlined),
            title: const Text('Mancanti'),
            subtitle: const Text(
                'Stringhe della Release Note non trovate in nessuna PR o commit'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final entry in result.missingEntries)
                    Chip(label: Text(entry)),
                ]),
              ),
            ],
          ),
        ),
        for (final category in ReleaseNoteCategory.values)
          Card(
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: Icon(_icon(category)),
              title: Text(category.label),
              children: [
                for (final item in grouped[category]!)
                  _ItemTile(
                    item: item,
                    category: category,
                    onMove: (target) => onMove(item, target),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static IconData _icon(ReleaseNoteCategory category) => switch (category) {
        ReleaseNoteCategory.ok => Icons.check_circle_outline,
        ReleaseNoteCategory.outOfScope => Icons.block,
        ReleaseNoteCategory.toVerify => Icons.help_outline,
      };
}

class _ItemTile extends StatelessWidget {
  final ReleaseNoteItem item;
  final ReleaseNoteCategory category;
  final ValueChanged<ReleaseNoteCategory> onMove;

  const _ItemTile({
    required this.item,
    required this.category,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final date = item.date;
    final pullRequest = item.pullRequest;
    final details = [
      item.repositoryName,
      if (pullRequest != null)
        '${pullRequest.summary.sourceBranch} → ${item.branch}'
      else
        item.branch,
      if (item.author.isNotEmpty) item.author,
      if (date != null) DateFormat('dd/MM/yyyy').format(date.toLocal()),
      if (item.matchedEntries.isNotEmpty) item.matchedEntries.join(', '),
    ].join(' · ');
    final webUrl = item.webUrl;
    return ExpansionTile(
      title: Row(children: [
        if (item.kind == ReleaseNoteItemKind.directCommit) ...[
          const Chip(
            label: Text('Commit diretto'),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(item.title)),
      ]),
      subtitle: Text(details),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (category != item.automaticCategory)
          const Tooltip(
            message: 'Spostato manualmente',
            child: Icon(Icons.edit_note),
          ),
        if (webUrl != null)
          IconButton(
            tooltip: 'Apri in Azure DevOps',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openExternalLink(context, webUrl),
          ),
        PopupMenuButton<ReleaseNoteCategory>(
          tooltip: 'Sposta in…',
          icon: const Icon(Icons.drive_file_move_outline),
          onSelected: onMove,
          itemBuilder: (_) => [
            for (final target in ReleaseNoteCategory.values)
              if (target != category)
                PopupMenuItem(value: target, child: Text(target.label)),
          ],
        ),
      ]),
      children: [
        for (final commit in item.commits)
          ListTile(
            dense: true,
            leading: const Icon(Icons.commit, size: 18),
            title: Text((commit.comment ?? '').split('\n').first),
            subtitle: Text([
              commit.commitId.length > 8
                  ? commit.commitId.substring(0, 8)
                  : commit.commitId,
              if (commit.author?.name != null) commit.author!.name,
            ].join(' · ')),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/release_note_results_view_test.dart`
Expected: PASS. If the popup item tap is ambiguous, keep
`find.text('Fuori perimetro').last` (the menu entry is the last match).

- [ ] **Step 5: Commit**

```powershell
git add lib/widgets/release_note_results_view.dart test/release_note_results_view_test.dart
git commit -m "feat: show release note check results with manual moves"
```

---

### Task 8: Tab and integration

**Files:**
- Create: `lib/widgets/release_note_check_tab.dart`
- Modify: `lib/widgets/pull_requests_tab.dart:57-67` and `:174-178`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

Add to `test/widget_test.dart` inside `main()`:

```dart
  testWidgets('PR and commit tab exposes the release note check',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GitSnapApp());
    await tester.pump();
    await tester.tap(find.text('PR e commit'));
    // Avoid pumpAndSettle: the PR overview may show an endless spinner.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Verifica Release Note'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL, `Verifica Release Note` not found.

- [ ] **Step 3: Create the tab**

`lib/widgets/release_note_check_tab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../providers/app_state.dart';
import '../services/release_note_check_service.dart';
import 'release_note_results_view.dart';

class ReleaseNoteCheckTab extends StatefulWidget {
  final AppState state;

  const ReleaseNoteCheckTab({super.key, required this.state});

  @override
  State<ReleaseNoteCheckTab> createState() => _ReleaseNoteCheckTabState();
}

class _ReleaseNoteCheckTabState extends State<ReleaseNoteCheckTab> {
  final _branchesController = TextEditingController();
  final _entriesController = TextEditingController();
  late DateTime _from;
  late DateTime _to;
  Set<String> _repositoryIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = DateTime(now.year, now.month - 1, now.day);
    _entriesController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _branchesController.dispose();
    _entriesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool from) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => from ? _from = selected : _to = selected);
  }

  Future<void> _selectRepositories() async {
    final selection = {..._repositoryIds};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Repository da analizzare'),
          content: SizedBox(
            width: 400,
            child: ListView(shrinkWrap: true, children: [
              for (final repo in widget.state.repositories)
                CheckboxListTile(
                  value: selection.contains(repo.id),
                  title: Text(repo.name),
                  onChanged: (checked) => setDialogState(() => checked == true
                      ? selection.add(repo.id)
                      : selection.remove(repo.id)),
                ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, <String>{}),
              child: const Text('Tutti'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selection),
              child: const Text('Conferma'),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _repositoryIds = result);
  }

  void _run() => widget.state.runReleaseNoteCheck(
        entriesText: _entriesController.text,
        branchPatternsText: _branchesController.text,
        repositoryIds: _repositoryIds,
        from: _from,
        to: DateTime(_to.year, _to.month, _to.day, 23, 59, 59),
      );

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final entryCount =
        ReleaseNoteCheckService.parseEntries(_entriesController.text).length;
    final result = state.releaseNoteResult;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Verifica Release Note',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text(
            'Confronta le pull request completate e i commit diretti entrati '
            'nelle branch indicate con le stringhe della Release Note.'),
        const SizedBox(height: 4),
        Text(
          'Le PR sono filtrate per data di completamento, i commit diretti '
          'per data del commit.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _branchesController,
                        decoration: const InputDecoration(
                          labelText: 'Branch (es. release/2026.11 o release/*)',
                          helperText: 'Più branch separate da virgola',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder_outlined),
                      label: Text(_repositoryIds.isEmpty
                          ? 'Tutti i repository'
                          : '${_repositoryIds.length} repository'),
                      onPressed: _selectRepositories,
                    ),
                    OutlinedButton(
                      onPressed: () => _pickDate(true),
                      child: Text('Da ${dateFormat.format(_from)}'),
                    ),
                    OutlinedButton(
                      onPressed: () => _pickDate(false),
                      child: Text('A ${dateFormat.format(_to)}'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _entriesController,
                  minLines: 4,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: 'Release Note: una stringa per riga',
                    helperText: '$entryCount stringhe da cercare',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: state.isCheckingReleaseNote ? null : _run,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Verifica'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (state.isCheckingReleaseNote) ...[
          Text(state.releaseNoteTotal == 0
              ? state.releaseNotePhase
              : '${state.releaseNotePhase} '
                  '(${state.releaseNoteCompleted}/${state.releaseNoteTotal})'),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: state.releaseNoteTotal == 0
                ? null
                : state.releaseNoteCompleted / state.releaseNoteTotal,
          ),
        ] else ...[
          if (state.releaseNoteError != null)
            Text(state.releaseNoteError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (result != null)
            ReleaseNoteResultsView(
              result: result,
              categoryOf: state.releaseNoteCategoryOf,
              onMove: state.moveReleaseNoteItem,
            ),
        ],
      ]),
    );
  }
}
```

- [ ] **Step 4: Mount it in `PullRequestsTab`**

In `lib/widgets/pull_requests_tab.dart`:

Add the import:

```dart
import 'release_note_check_tab.dart';
```

Change `length: 2,` to `length: 3,`.

Change the tabs to:

```dart
                tabs: [
                  Tab(text: 'Panoramica PR'),
                  Tab(text: 'Ricerca commit'),
                  Tab(text: 'Verifica Release Note'),
                ],
```

Change the end of the `TabBarView` children to:

```dart
                    _CommitSearchView(
                      state: state,
                      searchRequest: widget.searchRequest,
                    ),
                    ReleaseNoteCheckTab(state: state),
                  ],
```

- [ ] **Step 5: Run tests and analysis**

Run: `flutter test test/widget_test.dart`
Expected: PASS.

Run: `flutter analyze`
Expected: no new issues compared with `main`.

- [ ] **Step 6: Commit**

```powershell
git add lib/widgets/release_note_check_tab.dart lib/widgets/pull_requests_tab.dart test/widget_test.dart
git commit -m "feat: add release note check tab"
```

---

### Task 9: Documentation and full verification

**Files:**
- Modify: `README.md` (after the "Panoramica Pull Request" bullet and the PR
  paragraph)

- [ ] **Step 1: Update README**

Add the bullet after
`- 🔀 **Panoramica Pull Request**: ...`:

```markdown
- 📋 **Verifica Release Note**: Confronta tutto ciò che è entrato in una branch di release con le stringhe della Release Note
```

Add this paragraph after the "Utility pipeline" paragraph:

```markdown
Nella scheda **PR e commit → Verifica Release Note** si indicano una o più
branch (anche `release/*`), il periodo, i repository e le stringhe della
Release Note, una per riga. Il tool legge le pull request completate verso
quelle branch (per data di completamento), i loro commit e i commit diretti
senza PR. Ogni stringa viene cercata senza distinzione di maiuscole e a parola
intera in titolo, branch sorgente, descrizione e commit delle PR. Il risultato
mostra le stringhe **Mancanti** e gli elementi **OK** o **Da verificare**;
ogni elemento può essere spostato manualmente anche in **Fuori perimetro**.
```

- [ ] **Step 2: Full verification**

Run: `flutter analyze`
Expected: no new issues.

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 3: Commit**

```powershell
git add README.md
git commit -m "docs: describe release note check"
```
