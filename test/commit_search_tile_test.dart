import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/commit_search_models.dart';
import 'package:gitsnap_flutter/models/pull_request_models.dart';
import 'package:gitsnap_flutter/widgets/commit_search_tile.dart';

void main() {
  testWidgets('presents commit identity with separate visual hierarchy',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommitSearchTile(
          result: CommitSearchResult(
            repositoryId: 'repo',
            repositoryName: 'Portal',
            commitId: '1234567890',
            message: 'Improve dashboard',
            author: 'Ada',
            date: DateTime.utc(2026, 3, 12),
            branches: {'develop'},
            webUrl: '',
          ),
          loadHistory: () async => [],
        ),
      ),
    ));
    expect(find.text('12345678'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Improve dashboard'));
    expect(title.style?.fontWeight, FontWeight.w600);
    await tester.tap(find.byTooltip('Dettagli commit'));
    await tester.pumpAndSettle();
    expect(find.text('Branch analizzati'), findsOneWidget);
    expect(find.text('Percorso'), findsOneWidget);
    await tester.tap(find.byTooltip('Copia hash'));
    await tester.pump();
    expect(copied, '1234567890');
  });

  testWidgets('shows overflowing branches only after expansion',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 500,
          child: CommitSearchTile(
            result: CommitSearchResult(
              repositoryId: 'repo',
              repositoryName: 'Portal',
              commitId: '123',
              message: 'Fix',
              author: 'Ada',
              date: null,
              branches: {
                'develop',
                'feature/alpha',
                'feature/beta',
                'feature/gamma',
                'feature/delta',
              },
              webUrl: '',
            ),
            loadHistory: () async => [],
          ),
        ),
      ),
    ));
    expect(find.text('feature/gamma'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Mostra tutti i branch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mostra tutti i branch'));
    await tester.pumpAndSettle();
    expect(find.text('feature/gamma'), findsOneWidget);
    await tester.tap(find.byTooltip('Comprimi branch'));
    await tester.pumpAndSettle();
    expect(find.text('feature/gamma'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits narrow layouts and large text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 320,
              child: CommitSearchTile(
                result: CommitSearchResult(
                  repositoryId: 'repo',
                  repositoryName: 'Portal',
                  commitId: '123',
                  message: 'A very long commit message',
                  author: 'A very long author name',
                  date: null,
                  branches: {
                    'develop',
                    'feature/a-very-long-branch-name-that-will-not-fit',
                  },
                  webUrl: '',
                ),
                loadHistory: () async => [],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.ensureVisible(find.byTooltip('Mostra tutti i branch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mostra tutti i branch'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byTooltip('feature/a-very-long-branch-name-that-will-not-fit'),
      findsOneWidget,
    );
  });

  testWidgets('details remain usable on a narrow screen with larger text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Scaffold(
          body: SingleChildScrollView(
              child: CommitSearchTile(
            result: CommitSearchResult(
              repositoryId: 'repo',
              repositoryName: 'Portal',
              commitId: '1234567890123456789012345678901234567890',
              message: 'A very long commit message to verify the detail layout',
              author: 'A very long author name',
              date: null,
              branches: {'develop', 'feature/long-feature-name'},
              webUrl: '',
            ),
            loadHistory: () async => [],
          )),
        ),
      ),
    ));
    await tester.tap(find.byTooltip('Dettagli commit'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Ricostruisci percorso'));
    await tester.tap(find.text('Ricostruisci percorso'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nessuna pull request'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups branches and only loads history when requested',
      (tester) async {
    var requests = 0;
    final result = CommitSearchResult(
      repositoryId: 'repo',
      repositoryName: 'Portal',
      commitId: '123456789',
      message: 'Fix',
      author: 'Ada',
      date: DateTime.utc(2026, 3, 12),
      branches: {
        'master',
        'develop',
        'feature/one',
        'feature_two',
        'bugfix_123',
        'release',
      },
      webUrl: '',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommitSearchTile(
          result: result,
          loadHistory: () async {
            requests++;
            return [];
          },
        ),
      ),
    ));

    expect(find.text('develop'), findsOneWidget);
    expect(find.text('master'), findsOneWidget);
    expect(find.byTooltip('Dettagli commit'), findsOneWidget);
    expect(
      (tester.getCenter(find.textContaining('Ada ·')).dy -
              tester.getCenter(find.text('develop')).dy)
          .abs(),
      lessThan(8),
    );
    await tester.tap(find.byTooltip('Dettagli commit'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.text('Origine non determinabile'), findsOneWidget);
    expect(find.textContaining('branch analizzati'), findsOneWidget);
    await tester.tap(find.text('Feature (2)'));
    await tester.pumpAndSettle();
    expect(find.text('feature/one'), findsOneWidget);
    expect(find.text('feature_two'), findsOneWidget);
    await tester.ensureVisible(find.text('Bugfix (1)'));
    await tester.tap(find.text('Bugfix (1)'));
    await tester.pumpAndSettle();
    expect(find.text('bugfix_123'), findsOneWidget);
    await tester.ensureVisible(find.text('Ricostruisci percorso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ricostruisci percorso'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.textContaining('Nessuna pull request'), findsOneWidget);
  });

  testWidgets('shows history errors and retries on request', (tester) async {
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommitSearchTile(
          result: CommitSearchResult(
            repositoryId: 'repo',
            repositoryName: 'Portal',
            commitId: '123',
            message: 'Fix',
            author: 'Ada',
            date: null,
            branches: {'develop'},
            webUrl: '',
          ),
          loadHistory: () async {
            requests++;
            if (requests == 1) throw StateError('Server non disponibile');
            return [];
          },
        ),
      ),
    ));
    await tester.tap(find.byTooltip('Dettagli commit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ricostruisci percorso'));
    await tester.tap(find.text('Ricostruisci percorso'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Server non disponibile'), findsOneWidget);
    await tester.ensureVisible(find.text('Riprova'));
    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.textContaining('Nessuna pull request'), findsOneWidget);
  });

  testWidgets('shows linked pull requests chronologically', (tester) async {
    PullRequestSummary event(int id, String date) =>
        PullRequestSummary.fromJson({
          'pullRequestId': id,
          'title': 'Integrazione $id',
          'status': 'completed',
          'creationDate': '2026-03-01T10:00:00Z',
          'closedDate': date,
          'sourceRefName': 'refs/heads/feature/one',
          'targetRefName': 'refs/heads/develop',
        });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommitSearchTile(
          result: CommitSearchResult(
            repositoryId: 'repo',
            repositoryName: 'Portal',
            commitId: '123',
            message: 'Fix',
            author: 'Ada',
            date: null,
            branches: {},
            webUrl: '',
          ),
          loadHistory: () async => [
            event(2, '2026-03-15T10:00:00Z'),
            event(1, '2026-03-12T10:00:00Z'),
          ],
        ),
      ),
    ));
    await tester.tap(find.byTooltip('Dettagli commit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ricostruisci percorso'));
    await tester.tap(find.text('Ricostruisci percorso'));
    await tester.pumpAndSettle();
    expect(find.textContaining('feature/one → develop'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('#1 Integrazione 1')).dy,
      lessThan(tester.getTopLeft(find.text('#2 Integrazione 2')).dy),
    );
    expect(
      find.text('Sorgente della prima PR trovata: feature/one'),
      findsOneWidget,
    );
    expect(
        find.textContaining('non prova il branch di origine'), findsOneWidget);
  });

  testWidgets('does not select an arbitrary source for tied first PRs',
      (tester) async {
    PullRequestSummary event(int id, String branch) =>
        PullRequestSummary.fromJson({
          'pullRequestId': id,
          'title': 'Integrazione $id',
          'status': 'completed',
          'creationDate': '2026-03-01T10:00:00Z',
          'closedDate': '2026-03-12T10:00:00Z',
          'sourceRefName': 'refs/heads/$branch',
          'targetRefName': 'refs/heads/develop',
        });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommitSearchTile(
          result: CommitSearchResult(
            repositoryId: 'repo',
            repositoryName: 'Portal',
            commitId: '123',
            message: 'Fix',
            author: 'Ada',
            date: null,
            branches: {'develop'},
            webUrl: '',
          ),
          loadHistory: () async => [
            event(1, 'feature/one'),
            event(2, 'feature/two'),
          ],
        ),
      ),
    ));
    await tester.tap(find.byTooltip('Dettagli commit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ricostruisci percorso'));
    await tester.tap(find.text('Ricostruisci percorso'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Sorgente della prima PR trovata:'), findsNothing);
    expect(
        find.textContaining('Più PR trovate alla stessa data'), findsOneWidget);
  });
}
