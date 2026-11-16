import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/release_models.dart';
import 'package:gitsnap_flutter/providers/app_state.dart';
import 'package:gitsnap_flutter/services/azure_devops_client.dart';
import 'package:gitsnap_flutter/widgets/pipeline_variables_tab.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ReleaseClient extends AzureDevOpsClient {
  _ReleaseClient() : super(organization: 'org', project: 'project', pat: '');

  @override
  Future<List<ReleaseDefinitionInfo>> getReleaseDefinitions(
          {String? path, int top = 100}) async =>
      [ReleaseDefinitionInfo(id: 1, name: 'Pipeline')];

  @override
  Future<List<int>> getReleaseDefinitionRevisions(int definitionId) async => [];

  @override
  Future<Map<String, ReleaseVariable>> getLatestVariables(
      int definitionId) async {
    final variables = [
      for (var i = 0; i < 12; i++)
        ReleaseVariable(name: 'name$i', value: 'value$i', scope: 'scope$i'),
      ReleaseVariable(name: 'secret', value: 'hidden', isSecret: true),
    ];
    return {for (final variable in variables) variable.mapKey: variable};
  }
}

class _PipelineState extends AppState {
  final _ReleaseClient releaseClient = _ReleaseClient();

  @override
  AzureDevOpsClient get client => releaseClient;
}

void main() {
  testWidgets('variable tables allow selection and open at full height',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(2200, 2500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _PipelineState();
    addTearDown(state.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(
        home: Scaffold(body: PipelineVariablesTab()),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carica pipeline'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'A'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carica A (ultime)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carica B (ultime)'));
    await tester.pumpAndSettle();

    Finder selectableCell(String value) => find.descendant(
          of: find.byType(DataTable),
          matching: find.widgetWithText(SelectableText, value),
        );
    expect(selectableCell('name0'), findsNWidgets(2));
    expect(selectableCell('value0'), findsNWidgets(2));
    expect(selectableCell('scope0'), findsNWidgets(2));
    expect(selectableCell('********'), findsNWidgets(2));
    expect(selectableCell('hidden'), findsNothing);
    expect(find.byTooltip('Riduci altezza'), findsNWidgets(2));
    expect(find.byTooltip("Espandi a tutta l'altezza"), findsNothing);
    final fixedHeightPanels = find.ancestor(
      of: find.byType(DataTable),
      matching: find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 500,
      ),
    );
    expect(fixedHeightPanels, findsNothing);
    expect(
      tester.getSize(find.byType(DataTable).first).height,
      greaterThan(500),
    );

    await tester.tap(find.byTooltip('Riduci altezza').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Riduci altezza'), findsOneWidget);
    expect(find.byTooltip("Espandi a tutta l'altezza"), findsOneWidget);
    expect(fixedHeightPanels, findsOneWidget);
    await tester.tap(find.byTooltip("Espandi a tutta l'altezza"));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Riduci altezza'), findsNWidgets(2));
    expect(fixedHeightPanels, findsNothing);
  });
}
