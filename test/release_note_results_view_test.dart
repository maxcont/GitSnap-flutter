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

    await tester.ensureVisible(find.byTooltip('Sposta in…').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sposta in…').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fuori perimetro').last);
    await tester.pumpAndSettle();

    expect(find.text('Da verificare: 0'), findsOneWidget);
    expect(find.text('Fuori perimetro: 1'), findsOneWidget);
    expect(find.byTooltip('Spostato manualmente'), findsOneWidget);
  });
}
