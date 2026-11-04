import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/azure_models.dart';
import 'package:gitsnap_flutter/providers/app_state.dart';
import 'package:gitsnap_flutter/widgets/results_dashboard.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CompareState extends AppState {
  final DiffResult result;
  final String server;

  _CompareState(this.result, {this.server = ''});

  @override
  String get baseUrl => server;
  @override
  String get organization => 'Default Collection';
  @override
  String get project => 'Project & Tools';
  @override
  List<DiffResult> get diffResults => [result];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final launchedUrls = <Uri>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    launchedUrls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch') {
        launchedUrls.add(Uri.parse(call.arguments['url'] as String));
      }
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> openCompare(
    WidgetTester tester,
    DiffResult result, {
    String server = '',
  }) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _CompareState(result, server: server);
    addTearDown(state.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ResultsDashboard()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(result.repoName).first);
    await tester.pumpAndSettle();
    final link = find.text('Apri Compare in Azure DevOps');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
  }

  testWidgets('on-prem compare uses typed branches and encoded path segments',
      (tester) async {
    await openCompare(
      tester,
      DiffResult(
        repoId: 'repo',
        repoName: 'Repo #1',
        status: DiffStatus.divergent,
        sourceRef: 'refs/heads/feature/fix & test',
        targetRef: 'refs/heads/master',
        sourceCommit: 'aaaaaaaa',
        targetCommit: 'bbbbbbbb',
      ),
      server: ' http://localhost:8080/tfs/ ',
    );

    final uri = launchedUrls.single;
    expect(uri.scheme, 'http');
    expect(uri.host, 'localhost');
    expect(uri.port, 8080);
    expect(uri.pathSegments, [
      'tfs',
      'Default Collection',
      'Project & Tools',
      '_git',
      'Repo #1',
      'branchCompare',
    ]);
    expect(uri.queryParameters, {
      'baseVersion': 'GBmaster',
      'targetVersion': 'GBfeature/fix & test',
      '_a': 'commits',
    });
  });

  testWidgets('tags and commit refs compare their resolved commits in cloud',
      (tester) async {
    await openCompare(
      tester,
      DiffResult(
        repoId: 'repo',
        repoName: 'Repo',
        status: DiffStatus.divergent,
        sourceRef: 'release-1.0',
        targetRef: 'bbb',
        sourceCommit: 'aaaaaaaa',
        targetCommit: 'bbbbbbbb',
      ),
    );

    final uri = launchedUrls.single;
    expect(uri.origin, 'https://dev.azure.com');
    expect(uri.queryParameters['baseVersion'], 'GCbbbbbbbb');
    expect(uri.queryParameters['targetVersion'], 'GCaaaaaaaa');
  });

  testWidgets('unresolved refs do not offer a broken compare link',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _CompareState(DiffResult(
      repoId: 'repo',
      repoName: 'Repo',
      status: DiffStatus.error,
      note: 'Branch not found',
    ));
    addTearDown(state.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ResultsDashboard()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repo').first);
    await tester.pumpAndSettle();
    expect(find.text('Apri Compare in Azure DevOps'), findsNothing);
    expect(launchedUrls, isEmpty);
  });
}
