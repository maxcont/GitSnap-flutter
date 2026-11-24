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
              jsonEncode({
                'value': [
                  for (final n in names) {'name': n}
                ]
              }),
              200);
        }
        if (path.endsWith('/pullrequests')) {
          return http.Response(
              jsonEncode({
                'value': [
                  _pr(1, '2026-11-10T10:00:00Z'),
                  _pr(2, '2026-10-10T10:00:00Z'),
                  _pr(3, '2026-12-05T10:00:00Z'),
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
        if (path.endsWith('/pullRequests/3/commits')) {
          return http.Response(
              jsonEncode({
                'value': [
                  {'commitId': 'c3', 'comment': 'INC3'}
                ]
              }),
              200);
        }
        if (path.contains('/pullRequests/2/')) {
          return http.Response('unexpected', 500);
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
    expect(branch.excludedPullRequests.single.pullRequest.summary.id, 3);
    expect(branch.excludedPullRequests.single.commits.single.commitId, 'c3');
    expect(branch.branchCommits.single.commitId, 'd1');
    expect(result.uninvolvedRepositories, ['Repo2']);
    expect(result.warnings.single, startsWith('Repo3'));
  });
}
