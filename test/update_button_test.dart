import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/services/update_service.dart';
import 'package:gitsnap_flutter/widgets/update_button.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.leanflutter.plugins/auto_updater');
  const events = MethodChannel('dev.leanflutter.plugins/auto_updater_event');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  Widget app(UpdateService service) => ChangeNotifierProvider.value(
        value: service,
        child: const MaterialApp(
          home: Scaffold(appBar: null, body: UpdateButton()),
        ),
      );

  testWidgets('development builds show no updater and make no network checks',
      (tester) async {
    final service = UpdateService(enabled: false);
    addTearDown(service.dispose);
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.system_update_alt), findsNothing);
    expect(calls, isEmpty);
  });

  testWidgets('startup is background and button opens an interactive check',
      (tester) async {
    final service = UpdateService(enabled: true);
    addTearDown(service.dispose);
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    expect(calls.last.arguments['inBackground'], isTrue);
    await tester.tap(find.byIcon(Icons.system_update_alt));
    await tester.pumpAndSettle();
    expect(calls.last.arguments['inBackground'], isFalse);
  });

  testWidgets(
      'asynchronous updater failure is visible without blocking the app',
      (tester) async {
    final service = UpdateService(enabled: true);
    addTearDown(service.dispose);
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    service.onUpdaterError(null);
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Impossibile verificare'), findsOneWidget);
  });
}
