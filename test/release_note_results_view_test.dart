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
  testWidgets('repository side panel supports bulk selection', (tester) async {
    await tester.pumpWidget(const _Host());
    expect(find.text('Repo1 (2)'), findsNothing);
    await tester.tap(find.text('Repository 1/1'));
    await tester.pumpAndSettle();
    expect(find.text('Repo1 (2)'), findsOneWidget);
    await tester.tap(find.text('Deseleziona tutto'));
    await tester.pumpAndSettle();
    expect(find.text('Repository 0/1'), findsOneWidget);
    expect(find.text('OK: 0'), findsOneWidget);
    await tester.tap(find.text('Seleziona tutto'));
    await tester.pumpAndSettle();
    expect(find.text('Repository 1/1'), findsOneWidget);
    expect(find.text('OK: 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Chiudi filtri repository'));
    await tester.pumpAndSettle();
    expect(find.text('Repo1 (2)'), findsNothing);
  });

  testWidgets('repository panel scrolls on a narrow window', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = ReleaseNoteCheckService.check(
      entries: const [],
      branches: [
        for (var i = 0; i < 50; i++)
          ReleaseNoteBranchData(
            repositoryId: 'r$i',
            repositoryName: 'Repo${i.toString().padLeft(2, '0')}',
            branch: 'release',
            pullRequests: const [],
            branchCommits: const [],
          ),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReleaseNoteResultsView(
            result: result,
            categoryOf: (item) => item.automaticCategory,
            onMove: (_, __) {},
          ),
        ),
      ),
    ));
    await tester.ensureVisible(find.text('Repository 50/50'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repository 50/50'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Repo49 (0)'),
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('release-note-repositories')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Repo49 (0)'), findsOneWidget);
    await tester.tap(find.text('Repo49 (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Repository 49/50'), findsOneWidget);
  });

  testWidgets('filters categories without changing summary counts',
      (tester) async {
    await tester.pumpWidget(const _Host());
    expect(find.text('PR 1 · INC1 login', findRichText: true), findsWidgets);
    expect(find.text('hotfix', findRichText: true), findsWidgets);
    await tester.ensureVisible(find.byTooltip('Solo OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Solo OK'));
    await tester.pumpAndSettle();
    expect(find.text('PR 1 · INC1 login', findRichText: true), findsWidgets);
    expect(find.text('hotfix', findRichText: true), findsNothing);
    expect(find.text('Da verificare: 1'), findsOneWidget);
    expect(find.text('Generale · Da verificare: 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Mostra Da verificare'));
    await tester.pumpAndSettle();
    expect(find.text('hotfix', findRichText: true), findsWidgets);
  });

  testWidgets('highlights matched text in PR fields and full commit messages',
      (tester) async {
    final result = ReleaseNoteCheckService.check(
      entries: ['INC1', 'INC1-fix'],
      branches: [
        ReleaseNoteBranchData(
          repositoryId: 'r1',
          repositoryName: 'Repo1',
          branch: 'release',
          pullRequests: [
            ReleaseNotePullRequestData(
              pullRequest: ReleaseNotePullRequest.fromJson({
                'pullRequestId': 10,
                'title': 'Fix inc1, not INC12; INC1',
                'description': 'Description INC1',
                'status': 'completed',
                'closedDate': '2026-11-10T10:00:00Z',
                'repository': {'id': 'r1', 'name': 'Repo1'},
                'sourceRefName': 'refs/heads/feature/INC1-fix',
                'targetRefName': 'refs/heads/release',
                'createdBy': {'id': 'u', 'displayName': 'User'},
              }),
              commits: [
                Commit(commitId: 'pr', comment: 'First line\nsecond INC1'),
              ],
            ),
          ],
          branchCommits: [
            Commit(commitId: 'direct', comment: 'Hotfix INC1'),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReleaseNoteResultsView(
            result: result,
            categoryOf: (item) => item.automaticCategory,
            onMove: (_, __) {},
          ),
        ),
      ),
    ));

    List<String> highlighted(String text) {
      final widgets = tester.widgetList<Text>(find.byType(Text)).where(
            (widget) => widget.textSpan?.toPlainText() == text,
          );
      final spans = <String>[];
      void visit(InlineSpan span) {
        if (span is TextSpan) {
          if (span.style?.backgroundColor != null && span.text != null) {
            spans.add(span.text!);
          }
          for (final child in span.children ?? <InlineSpan>[]) {
            visit(child);
          }
        }
      }

      for (final widget in widgets) {
        visit(widget.textSpan!);
      }
      return spans;
    }

    expect(highlighted('PR 10 · Fix inc1, not INC12; INC1'), ['inc1', 'INC1']);
    expect(
        highlighted('Repo1 · feature/INC1-fix → release · User · '
            '10/11/2026 · INC1, INC1-fix'),
        ['INC1-fix']);
    expect(highlighted('Hotfix INC1'), ['INC1']);
    final prTitle =
        find.text('PR 10 · Fix inc1, not INC12; INC1', findRichText: true);
    await tester.ensureVisible(prTitle.first);
    await tester.pumpAndSettle();
    await tester.tap(prTitle.first);
    await tester.pumpAndSettle();
    expect(highlighted('Description INC1'), ['INC1']);
    expect(highlighted('First line\nsecond INC1'), ['INC1']);
  });

  testWidgets('filters repositories without changing the global summary',
      (tester) async {
    ReleaseNoteCheckResult result() => ReleaseNoteCheckService.check(
          entries: ['INC1', 'INC2', 'INC9'],
          branches: [
            ReleaseNoteBranchData(
              repositoryId: 'r1',
              repositoryName: 'Repo1',
              branch: 'release',
              pullRequests: const [],
              branchCommits: [Commit(commitId: 'a', comment: 'INC1')],
            ),
            ReleaseNoteBranchData(
              repositoryId: 'r2',
              repositoryName: 'Repo2',
              branch: 'release',
              pullRequests: const [],
              branchCommits: [Commit(commitId: 'b', comment: 'INC2')],
            ),
            const ReleaseNoteBranchData(
              repositoryId: 'r3',
              repositoryName: 'Repo3',
              branch: 'release',
              pullRequests: [],
              branchCommits: [],
            ),
          ],
        );
    Widget host(ReleaseNoteCheckResult value) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReleaseNoteResultsView(
                result: value,
                categoryOf: (item) => item.automaticCategory,
                onMove: (_, __) {},
              ),
            ),
          ),
        );
    final first = result();
    await tester.pumpWidget(host(first));
    expect(find.text('Repository coinvolti: 3'), findsOneWidget);
    expect(find.text('Generale · OK: 2'), findsOneWidget);
    await tester.tap(find.text('Mancanti globali'));
    await tester.pumpAndSettle();
    expect(find.text('INC9'), findsWidgets);
    expect(find.text('Mancanti nei selezionati: 1'), findsOneWidget);

    await tester.tap(find.text('Repository 3/3'));
    await tester.pumpAndSettle();
    expect(find.text('Repo3 (0)'), findsOneWidget);
    await tester.tap(find.text('Repo2 (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chiudi filtri repository'));
    await tester.pumpAndSettle();
    expect(find.text('Generale · OK: 2'), findsOneWidget);
    expect(find.text('OK: 1'), findsOneWidget);
    expect(find.text('Mancanti nei selezionati: 2'), findsOneWidget);
    expect(find.text('Trovate solo negli altri: 1'), findsOneWidget);
    expect(find.text('INC2'), findsWidgets);

    await tester.tap(find.text('Repository 2/3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repo1 (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chiudi filtri repository'));
    await tester.pumpAndSettle();
    expect(find.text('Mancanti nei selezionati: 3'), findsOneWidget);
    expect(find.text('Trovate solo negli altri: 2'), findsOneWidget);

    await tester.pumpWidget(host(result()));
    await tester.pumpAndSettle();
    expect(find.text('Mancanti nei selezionati: 1'), findsOneWidget);
    expect(find.text('OK: 2'), findsOneWidget);
  });

  testWidgets('shows counters, missing entries and moves items',
      (tester) async {
    await tester.pumpWidget(const _Host());

    expect(find.text('Mancanti nei selezionati: 1'), findsOneWidget);
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
    expect(find.text('Generale · Fuori perimetro: 1'), findsOneWidget);
    expect(find.byTooltip('Spostato manualmente'), findsOneWidget);

    await tester.ensureVisible(find.text('Repository 1/1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repository 1/1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repo1 (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chiudi filtri repository'));
    await tester.pumpAndSettle();
    expect(find.text('Generale · Fuori perimetro: 1'), findsOneWidget);
    expect(find.text('Fuori perimetro: 0'), findsOneWidget);
    await tester.tap(find.text('Repository 0/1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repo1 (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chiudi filtri repository'));
    await tester.pumpAndSettle();
    expect(find.text('Fuori perimetro: 1'), findsOneWidget);
    expect(find.byTooltip('Spostato manualmente'), findsOneWidget);
  });
}
