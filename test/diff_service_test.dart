import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/azure_models.dart';
import 'package:gitsnap_flutter/services/azure_devops_client.dart';
import 'package:gitsnap_flutter/services/diff_service.dart';
import 'package:gitsnap_flutter/services/ref_resolver.dart';

class _FakeClient extends AzureDevOpsClient {
  final Map<String, Map<String, dynamic>> commits;
  final Map<String, dynamic> diff;
  int diffCalls = 0;

  _FakeClient(this.commits, this.diff)
      : super(organization: 'o', project: 'p', pat: 'x');

  @override
  Future<Map<String, dynamic>> getCommit(String repoId, String commitId) async =>
      commits[commitId]!;

  @override
  Future<Map<String, dynamic>> getDiffsCommits(
    String repoId,
    String baseCommit,
    String targetCommit,
  ) async {
    diffCalls++;
    return diff;
  }

  @override
  Future<List<Commit>> getCommitsBetween(
    String repoId,
    String baseCommit,
    String tipCommit,
  ) async =>
      [];
}

Future<DiffResult> _run(_FakeClient client) async {
  final repo = Repository(id: 'r', name: 'repo');
  final results = await DiffService(client).getDiffsForRepos(
    [repo],
    {'r': ResolvedRef(repoId: 'r', refName: 'feature', commitId: 'aaa')},
    {'r': ResolvedRef(repoId: 'r', refName: 'main', commitId: 'bbb')},
    RefType.branch,
    RefType.branch,
  );
  return results.single;
}

void main() {
  final divergentDiff = {
    'aheadCount': 2,
    'behindCount': 1,
    'changes': [
      {
        'item': {'path': '/a.txt'}
      }
    ],
  };

  test('same tree, different commits (squash) is aligned', () async {
    final client = _FakeClient({
      'aaa': {'treeId': 't1', 'comment': 'f'},
      'bbb': {'treeId': 't1', 'comment': 's'},
    }, divergentDiff);

    final result = await _run(client);

    expect(result.status, DiffStatus.aligned);
    expect(client.diffCalls, 0);
  });

  test('different tree is divergent', () async {
    final client = _FakeClient({
      'aaa': {'treeId': 't1', 'comment': 'f'},
      'bbb': {'treeId': 't2', 'comment': 's'},
    }, divergentDiff);

    final result = await _run(client);

    expect(result.status, DiffStatus.divergent);
    expect(result.files, ['/a.txt']);
    expect(result.sourceOnlyCommitCount, 2);
    expect(result.targetOnlyCommitCount, 1);
  });
}
