import 'dart:async';
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UpdateService extends ChangeNotifier with UpdaterListener {
  UpdateService({bool? enabled})
      : enabled = enabled ??
            (Platform.isWindows &&
                kReleaseMode &&
                const bool.fromEnvironment('GITSNAP_ENABLE_UPDATES'));

  static const version =
      String.fromEnvironment('GITSNAP_VERSION', defaultValue: 'sviluppo');
  static const _feedUrl = String.fromEnvironment(
    'GITSNAP_UPDATE_FEED_URL',
    defaultValue:
        'https://github.com/maxcont/GitSnap-flutter/releases/latest/download/appcast.xml',
  );

  final bool enabled;
  bool _initialized = false;
  bool _listening = false;
  bool _disposed = false;
  Future<void>? _initializing;
  String? _errorMessage;

  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (!enabled || _disposed || _initialized) return;
    await (_initializing ??= _initialize());
    _initializing = null;
  }

  Future<void> _initialize() async {
    try {
      final uri = Uri.parse(_feedUrl);
      if (uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('Il feed aggiornamenti deve usare HTTPS.');
      }
      if (!_listening) {
        autoUpdater.addListener(this);
        _listening = true;
      }
      await autoUpdater.setFeedURL(_feedUrl);
      await autoUpdater.setScheduledCheckInterval(86400);
      _initialized = true;
      _setError(null);
      if (!_disposed) {
        await autoUpdater.checkForUpdates(inBackground: true);
      }
    } on Exception catch (error, stack) {
      _initialized = false;
      _reportError(error, stack);
    }
  }

  Future<void> checkForUpdates() async {
    if (!enabled || _disposed) return;
    await initialize();
    if (!_initialized || _disposed) return;
    _setError(null);
    try {
      await autoUpdater.checkForUpdates(inBackground: false);
    } on Exception catch (error, stack) {
      _reportError(error, stack);
    }
  }

  void _reportError(Object error, [StackTrace? stack]) {
    debugPrint('GitSnap updater: $error');
    if (stack != null) debugPrintStack(stackTrace: stack);
    _setError(
      'Impossibile verificare o installare gli aggiornamenti. '
      'Puoi riprovare da "Controlla aggiornamenti". Dettagli: $error',
    );
  }

  void _setError(String? message) {
    if (_disposed || _errorMessage == message) return;
    _errorMessage = message;
    notifyListeners();
  }

  @override
  void onUpdaterError(UpdaterError? error) {
    _reportError(error ?? 'Errore del componente di aggiornamento Windows.');
  }

  @override
  void onUpdaterBeforeQuitForUpdate(AppcastItem? appcastItem) {
    if (!_disposed) unawaited(_closeForUpdate());
  }

  Future<void> _closeForUpdate() async {
    try {
      await SystemNavigator.pop();
    } on Exception catch (error, stack) {
      _reportError(error, stack);
    }
  }

  @override
  void onUpdaterCheckingForUpdate(Appcast? appcast) {}

  @override
  void onUpdaterUpdateAvailable(AppcastItem? appcastItem) {}

  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) {
    if (error != null) onUpdaterError(error);
  }

  @override
  void onUpdaterUpdateDownloaded(AppcastItem? appcastItem) {}

  @override
  void dispose() {
    _disposed = true;
    if (_listening) autoUpdater.removeListener(this);
    super.dispose();
  }
}
