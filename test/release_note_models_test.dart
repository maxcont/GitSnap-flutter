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
