import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/azure_models.dart';
import 'package:gitsnap_flutter/providers/app_state.dart';
import 'package:gitsnap_flutter/widgets/results_dashboard.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ComparisonState extends AppState {
  final String server;
  final String repoName;
  final String? sourceMessage;

  _ComparisonState({
    this.server = '',
    this.repoName = 'Repository',
    this.sourceMessage = 'Source message',
  });

  @override
  String get baseUrl => server;
  @override
  String get organization => 'Collection';
  @override
  String get project => 'Project';
  @override
  List<DiffResult> get diffResults => [
        DiffResult(
          repoId: 'repository-id',
          repoName: repoName,
          status: DiffStatus.divergent,
          commits: [
            Commit(commitId: '1234567890', comment: sourceMessage),
          ],
          targetCommits: [
            Commit(commitId: 'abcdef0123', comment: 'Target message'),
          ],
        ),
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final launched = <Uri>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch') {
        launched.add(Uri.parse(call.arguments['url'] as String));
      }
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> openLists(
    WidgetTester tester, {
    void Function(String, String)? onSearchCommit,
    _ComparisonState? providedState,
  }) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = providedState ?? _ComparisonState();
    addTearDown(state.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultsDashboard(onSearchCommit: onSearchCommit),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(state.repoName).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Commit in SOURCE'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Commit in TARGET'));
    await tester.pumpAndSettle();
  }

  testWidgets('commit messages and metadata are selectable in both lists',
      (tester) async {
    await openLists(tester);
    expect(
        find.widgetWithText(SelectableText, 'Source message'), findsOneWidget);
    expect(
        find.widgetWithText(SelectableText, 'Target message'), findsOneWidget);
    expect(find.byType(SelectableText), findsNWidgets(4));
  });

  testWidgets('opens the selected commit in Azure DevOps', (tester) async {
    await openLists(tester);
    expect(find.byTooltip('Apri commit'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Apri commit').first);
    await tester.pumpAndSettle();
    expect(launched.single.pathSegments, [
      'Collection',
      'Project',
      '_git',
      'Repository',
      'commit',
      '1234567890'
    ]);
  });

  testWidgets('search action forwards target commit message and repository',
      (tester) async {
    String? repository;
    String? message;
    await openLists(tester, onSearchCommit: (repo, text) {
      repository = repo;
      message = text;
    });
    await tester.tap(find.byTooltip('Cerca commit').last);
    expect(repository, 'repository-id');
    expect(message, 'Target message');
  });

  testWidgets('shows an error when the commit cannot be opened',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);
    await openLists(tester);
    await tester.tap(find.byTooltip('Apri commit').first);
    await tester.pumpAndSettle();
    expect(find.text('Impossibile aprire il collegamento.'), findsOneWidget);
  });

  testWidgets('on-premises commit link encodes the repository name',
      (tester) async {
    await openLists(
      tester,
      providedState: _ComparisonState(
        server: ' http://localhost:8080/tfs/ ',
        repoName: 'Repo #1',
      ),
    );
    await tester.tap(find.byTooltip('Apri commit').first);
    await tester.pumpAndSettle();
    expect(launched.single.origin, 'http://localhost:8080');
    expect(launched.single.pathSegments, [
      'tfs',
      'Collection',
      'Project',
      '_git',
      'Repo #1',
      'commit',
      '1234567890'
    ]);
  });

  testWidgets('a commit without a message cannot open message search',
      (tester) async {
    await openLists(
      tester,
      providedState: _ComparisonState(sourceMessage: null),
      onSearchCommit: (_, __) => fail('Search must be disabled'),
    );
    final search = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Cerca commit',
      ).first,
    );
    expect(search.onPressed, isNull);
  });
}
