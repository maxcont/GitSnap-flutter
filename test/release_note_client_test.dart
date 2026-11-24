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
