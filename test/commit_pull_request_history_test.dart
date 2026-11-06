import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/pull_request_models.dart';
import 'package:gitsnap_flutter/services/azure_devops_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _sha = '0123456789abcdef0123456789abcdef01234567';

Map<String, dynamic> _pr(int id, {String status = 'completed'}) => {
      'pullRequestId': id,
      'title': 'PR $id',
      'status': status,
      'repository': {'id': 'repo', 'name': 'Repository'},
      'creationDate': '2026-01-01T10:00:00Z',
      'closedDate': '2026-01-02T10:00:00Z',
      'sourceRefName': 'refs/heads/feature',
      'targetRefName': 'refs/heads/main',
      'createdBy': {'id': 'author', 'displayName': 'Author'},
    };

Future<List<PullRequestSummary>> _query(
  Object? body, {
  int status = 200,
  Map<String, String> headers = const {},
  String? baseUrl,
  void Function(http.Request)? inspect,
}) =>
    http.runWithClient(
      () => AzureDevOpsClient(
        organization: 'org',
        project: 'project',
        pat: 'secret',
        baseUrl: baseUrl,
      ).getCommitPullRequests('repo', _sha),
      () => MockClient((request) async {
        inspect?.call(request);
        return http.Response(jsonEncode(body), status, headers: headers);
      }),
    );

Map<String, dynamic> _response(List<Object?> first,
        [List<Object?> second = const []]) =>
    {
      'results': [
        {_sha: first},
        {_sha: second},
      ],
    };

void main() {
  test('accepts a valid query response returned with HTTP 201', () async {
    final result = await _query(_response([_pr(1)]), status: 201);
    expect(result.single.id, 1);
  });

  test('rejects malformed HTTP 201 response data', () async {
    await expectLater(
      _query({'message': 'unexpected'}, status: 201),
      throwsA(isA<AzureDevOpsClientError>()
          .having((error) => error.message, 'message', contains('Invalid'))),
    );
  });

  test('constructing the client does not eagerly request history', () async {
    var requests = 0;
    await http.runWithClient(
      () async {
        AzureDevOpsClient(
            organization: 'org', project: 'project', pat: 'secret');
        await Future<void>.delayed(Duration.zero);
        expect(requests, 0);
      },
      () => MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
  });

  test('invalid input fails explicitly without making a request', () async {
    for (final input in [
      ['', _sha],
      ['repo', ''],
      ['repo', 'not-a-commit'],
    ]) {
      await http.runWithClient(
        () async {
          await expectLater(
            AzureDevOpsClient(
                    organization: 'org', project: 'project', pat: 'secret')
                .getCommitPullRequests(input[0], input[1]),
            throwsA(isA<AzureDevOpsClientError>()),
          );
        },
        () => MockClient((_) async {
          fail('Invalid input must not reach the server');
        }),
      );
    }
  });

  test('posts both commit query types only when explicitly invoked', () async {
    final result = await _query(
      _response([_pr(1)]),
      inspect: (request) {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://dev.azure.com/org/project/_apis/git/repositories/repo/'
          'pullrequestquery?api-version=7.0',
        );
        expect(request.headers['Authorization'],
            'Basic ${base64Encode(utf8.encode(':secret'))}');
        expect(request.headers['Content-Type'], 'application/json');
        expect(jsonDecode(request.body), {
          'queries': [
            {
              'type': 'commit',
              'items': [_sha],
            },
            {
              'type': 'lastMergeCommit',
              'items': [_sha],
            },
          ],
        });
      },
    );
    final pr = result.single;
    expect(pr.status, PullRequestStatus.completed);
    expect(pr.createdAt, DateTime.utc(2026, 1, 1, 10));
    expect(pr.closedAt, DateTime.utc(2026, 1, 2, 10));
    expect(pr.sourceBranch, 'feature');
    expect(pr.targetBranch, 'main');
    expect(
        pr.webUrl, 'https://dev.azure.com/org/project/_git/repo/pullrequest/1');
  });

  test('deduplicates query overlap and returns latest completed PR first',
      () async {
    final newer = _pr(2)..['closedDate'] = '2026-02-01T11:00:00+01:00';
    final result = await _query(_response(
      [_pr(1), _pr(3, status: 'active'), _pr(4, status: 'abandoned')],
      [_pr(1), newer],
    ));
    expect(result.map((pr) => pr.id), [2, 1]);
    expect(result.first.closedAt, DateTime.utc(2026, 2, 1, 10));
  });

  test('empty dictionaries mean no reported PR associations', () async {
    expect(
        await _query({
          'results': [{}, {}]
        }),
        isEmpty);
    expect(await _query(_response([])), isEmpty);
  });

  test('uses the configured server collection for PR links', () async {
    final result = await _query(
      _response([_pr(1)]),
      baseUrl: 'https://server/tfs',
    );
    expect(result.single.webUrl,
        'https://server/tfs/org/project/_git/repo/pullrequest/1');
  });

  test('accepts case-insensitive SHA keys and retains supplied PR web links',
      () async {
    final result = await _query({
      'results': [
        {
          _sha.toUpperCase(): [
            _pr(1)
              ..['_links'] = {
                'web': {'href': 'https://server/custom/pullrequest/1'},
              },
          ],
        },
        {},
      ],
    });
    expect(result.single.webUrl, 'https://server/custom/pullrequest/1');
  });

  for (final body in <Object?>[
    null,
    [],
    {},
    {'results': []},
    {
      'results': [{}, {}, {}]
    },
    {
      'results': [{}, null]
    },
    {
      'results': [
        {_sha: null},
        {}
      ]
    },
    {
      'results': [
        {'different-sha': []},
        {}
      ]
    },
    _response([null]),
    _response([
      {'pullRequestId': 1}
    ]),
    _response([_pr(1)..remove('creationDate')]),
    _response([_pr(1)..remove('closedDate')]),
    _response([_pr(1)..['closedDate'] = 'yesterday']),
    _response([_pr(1)..['closedDate'] = '2026-02-30T10:00:00Z']),
    _response([_pr(1)..['creationDate'] = '2026-01-01T10:00:00']),
    _response([_pr(1)..['closedDate'] = '2025-01-01T10:00:00Z']),
    _response([_pr(1)..remove('sourceRefName')]),
    _response([_pr(1)..remove('targetRefName')]),
    _response([_pr(1)..['pullRequestId'] = 0]),
    _response([
      _pr(1)..['repository'] = {'id': 'different'}
    ]),
    _response([_pr(1)..['status'] = 'unknown']),
  ]) {
    test('rejects malformed or incomplete history: ${jsonEncode(body)}',
        () async {
      await expectLater(_query(body), throwsA(isA<AzureDevOpsClientError>()));
    });
  }

  test('reports server-provided continuation as incomplete history', () async {
    await expectLater(
      _query(_response([_pr(1)]), headers: {'x-ms-continuationtoken': 'next'}),
      throwsA(isA<AzureDevOpsClientError>()),
    );
  });

  for (final status in [401, 403, 404, 500]) {
    test('surfaces HTTP $status instead of an empty history', () async {
      await expectLater(
        _query({'message': 'Failure'}, status: status),
        throwsA(isA<AzureDevOpsClientError>()
            .having((error) => error.message, 'message', contains('$status'))),
      );
    });
  }

  test('surfaces invalid JSON and network failures', () async {
    for (final client in [
      MockClient((_) async => http.Response('not JSON', 200)),
      MockClient((_) async => throw http.ClientException('offline')),
    ]) {
      await expectLater(
        http.runWithClient(
          () => AzureDevOpsClient(
                  organization: 'org', project: 'project', pat: 'secret')
              .getCommitPullRequests('repo', _sha),
          () => client,
        ),
        throwsA(isA<AzureDevOpsClientError>()),
      );
    }
  });
}
