import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/azure_models.dart';
import 'package:gitsnap_flutter/models/commit_search_models.dart';
import 'package:gitsnap_flutter/providers/app_state.dart';
import 'package:gitsnap_flutter/screens/home_screen.dart';
import 'package:gitsnap_flutter/services/cast_session.dart';
import 'package:gitsnap_flutter/services/update_service.dart';
import 'package:gitsnap_flutter/widgets/pull_requests_tab.dart';
import 'package:gitsnap_flutter/widgets/results_dashboard.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SearchState extends AppState {
  int searches = 0;
  @override
  List<Repository> get repositories => [
        Repository(id: 'repo-one', name: 'Repository one'),
        Repository(id: 'repo-two', name: 'Repository two'),
      ];
  @override
  List<DiffResult> get diffResults => [
        DiffResult(
          repoId: 'repo-one',
          repoName: 'Repository one',
          status: DiffStatus.divergent,
          commits: [
            Commit(commitId: 'abcdef123', comment: 'Comparison message'),
          ],
        ),
      ];
  @override
  Future<void> loadPullRequests() async {}
  @override
  Future<void> searchCommits({
    required String text,
    required Set<String> repositoryIds,
    required Set<String> branchNames,
    required Set<String> branchPrefixes,
    required String? branchPattern,
    required bool allBranches,
    required DateTime from,
    required DateTime to,
  }) async {
    searches++;
    expect(text, 'Second message');
    expect(repositoryIds, {'repo-two'});
  }
}

void main() {
  testWidgets('comparison opens search with the message and repository',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _SearchState();
    addTearDown(state.dispose);

    Widget app(CommitSearchRequest request) =>
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(body: PullRequestsTab(searchRequest: request)),
          ),
        );

    await tester.pumpWidget(app(const CommitSearchRequest(
      repositoryId: 'repo-one',
      message: 'First message',
    )));
    await tester.pumpAndSettle();
    expect(find.text('First message'), findsOneWidget);
    expect(state.searches, 0);

    await tester.pumpWidget(app(const CommitSearchRequest(
      repositoryId: 'repo-two',
      message: 'Second message',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Second message'), findsOneWidget);
    expect(state.searches, 0);
    await tester.tap(find.text('Cerca'));
    await tester.pumpAndSettle();
    expect(state.searches, 1);
  });

  testWidgets('dashboard button navigates to the prefilled search',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _SearchState();
    final cast = CastSession();
    final updates = UpdateService(enabled: false);
    addTearDown(state.dispose);
    addTearDown(cast.dispose);
    addTearDown(updates.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider<CastSession>.value(value: cast),
        ChangeNotifierProvider<UpdateService>.value(value: updates),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();
    final repo = find
        .descendant(
          of: find.byType(ResultsDashboard),
          matching: find.text('Repository one'),
        )
        .first;
    await tester.ensureVisible(repo);
    await tester.tap(repo);
    await tester.pumpAndSettle();
    final list = find.textContaining('Commit in SOURCE');
    await tester.ensureVisible(list);
    await tester.tap(list);
    await tester.pumpAndSettle();
    final search = find.byTooltip('Cerca commit');
    await tester.ensureVisible(search);
    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(find.text('Comparison message'), findsOneWidget);
    expect(state.searches, 0);
  });
}
