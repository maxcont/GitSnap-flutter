import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/azure_models.dart';
import 'package:gitsnap_flutter/services/azure_devops_client.dart';
import 'package:gitsnap_flutter/services/ref_suggestion_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _refs(List<String> names) => http.Response(
    jsonEncode({
      'value': [
        for (final name in names) {'name': name}
      ]
    }),
    200);

RefSuggestions _suggestions(Map<String, Set<String>> refs, {int? total}) =>
    RefSuggestions(
      refsByRepository: refs,
      failedRepositories: const [],
      repositoryCount: total ?? refs.length,
    );

void main() {
  final repositories = [
    Repository(id: 'r1', name: 'Repo1'),
    Repository(id: 'r2', name: 'Repo2'),
    Repository(id: 'r3', name: 'Repo3'),
  ];

  Future<RefSuggestions> load(RefType type) => http.runWithClient(
        () => RefSuggestionService.load(
          AzureDevOpsClient(organization: 'o', project: 'p', pat: 'x'),
          repositories,
          type,
        ),
        () => MockClient((request) async {
          final path = request.url.path;
          if (path.contains('/r3/')) return http.Response('boom', 500);
          final tags = request.url.queryParameters['filter'] == 'tags/';
          if (tags) {
            return _refs(path.contains('/r1/')
                ? ['refs/tags/v1.0', 'refs/tags/v1.1']
                : ['refs/tags/v1.0']);
          }
          return _refs(path.contains('/r1/')
              ? ['refs/heads/master', 'refs/heads/feature/a']
              : ['refs/heads/master']);
        }),
      );

  test('aggregates branches across repositories and reports failures',
      () async {
    final result = await load(RefType.branch);

    expect(result.repositoryCount, 3);
    expect(result.failedRepositories, ['Repo3']);
    expect(result.counts, {'master': 2, 'feature/a': 1});
  });

  test('loads tags without the refs/tags/ prefix', () async {
    final result = await load(RefType.tagPattern);

    expect(result.counts, {'v1.0': 2, 'v1.1': 1});
  });

  test('filters case-insensitively, sorts by coverage then name, limits',
      () {
    final suggestions = _suggestions({
      'r1': {'Feature/B', 'feature/a', 'master'},
      'r2': {'feature/a', 'master'},
    });

    expect(
      RefSuggestionService.filter(suggestions, 'FEAT')
          .map((s) => '${s.name}:${s.repositoryCount}'),
      ['feature/a:2', 'Feature/B:1'],
    );
    expect(RefSuggestionService.filter(suggestions, '', limit: 2).length, 2);
  });

  test('tag pattern preview counts distinct matching tags and repositories',
      () {
    final suggestions = _suggestions({
      'r1': {'v1.0', 'v1.1', 'v2.0'},
      'r2': {'v1.0'},
      'r3': {'v2.0'},
    });

    final preview = RefSuggestionService.tagPatternPreview(suggestions, 'v1.*');

    expect(preview.matchingTags, 2);
    expect(preview.matchingRepositories, 2);
  });
}
