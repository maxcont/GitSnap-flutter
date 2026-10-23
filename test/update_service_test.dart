import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.leanflutter.plugins/auto_updater');
  const events = MethodChannel('dev.leanflutter.plugins/auto_updater_event');
  final calls = <MethodCall>[];
  var failInitialization = false;

  setUp(() {
    calls.clear();
    failInitialization = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (failInitialization && call.method == 'setFeedURL') {
        throw PlatformException(code: 'unavailable', message: 'Test failure');
      }
      return true;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  test('disabled builds never initialize or check the native updater',
      () async {
    final service = UpdateService(enabled: false);
    addTearDown(service.dispose);
    await service.initialize();
    await service.checkForUpdates();
    expect(calls, isEmpty);
    expect(service.enabled, isFalse);
  });

  test('startup configures HTTPS feed and checks in background once', () async {
    final service = UpdateService(enabled: true);
    addTearDown(service.dispose);
    await Future.wait([service.initialize(), service.initialize()]);
    expect(calls.map((call) => call.method), [
      'setFeedURL',
      'setScheduledCheckInterval',
      'checkForUpdates',
    ]);
    expect(calls.first.arguments['feedURL'],
        'https://github.com/maxcont/GitSnap-flutter/releases/latest/download/appcast.xml');
    expect(calls.last.arguments['inBackground'], isTrue);
    expect(service.initialized, isTrue);
  });

  test('manual check requests the native interactive dialog', () async {
    final service = UpdateService(enabled: true);
    addTearDown(service.dispose);
    await service.initialize();
    await service.checkForUpdates();
    expect(calls.last.method, 'checkForUpdates');
    expect(calls.last.arguments['inBackground'], isFalse);
  });

  test('initialization failures are visible and can be retried', () async {
    final service = UpdateService(enabled: true);
    addTearDown(service.dispose);
    failInitialization = true;
    await service.initialize();
    expect(service.initialized, isFalse);
    expect(service.errorMessage, contains('Test failure'));
    failInitialization = false;
    await service.checkForUpdates();
    expect(service.initialized, isTrue);
    expect(service.errorMessage, isNull);
    expect(calls.last.arguments['inBackground'], isFalse);
  });

  test('native asynchronous errors are exposed even without error details', () {
    final service = UpdateService(enabled: true);
    addTearDown(service.dispose);
    service.onUpdaterError(null);
    expect(service.errorMessage, contains('aggiornamenti'));
    service.onUpdaterError(UpdaterError('Download failed'));
    expect(service.errorMessage, contains('Download failed'));
  });

  test('the app closes only after the native install confirmation', () async {
    final service = UpdateService(enabled: true);
    addTearDown(service.dispose);
    final platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    service.onUpdaterUpdateAvailable(null);
    service.onUpdaterUpdateDownloaded(null);
    expect(platformCalls, isEmpty);
    service.onUpdaterBeforeQuitForUpdate(null);
    await Future<void>.delayed(Duration.zero);
    expect(platformCalls.single.method, 'SystemNavigator.pop');
  });

  test('callbacks after disposal do not notify a dead service', () {
    final service = UpdateService(enabled: true);
    service.dispose();
    expect(() => service.onUpdaterError(null), returnsNormally);
  });
}
