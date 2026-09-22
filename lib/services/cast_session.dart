import 'package:flutter/foundation.dart';
import 'package:webview_windows/webview_windows.dart';

/// Long-lived, app-wide session that owns the single WebView2 controller
/// used to authenticate against the CAST portal (Windows/NTLM auth) and to
/// show a small floating "login"/"re-login" panel.
///
/// This is provided once at the root of the app (see `main.dart`), so it
/// survives switching between tabs: once the user is logged into CAST, the
/// same WebView2 instance (and its session cookies) is reused for every
/// subsequent check, and the panel can also be re-opened directly from the
/// configuration screen if a fresh login is ever needed (e.g. after the
/// Windows session/NTLM ticket expires).
class CastSession extends ChangeNotifier {
  final WebviewController controller = WebviewController();
  bool ready = false;
  bool panelVisible = false;
  bool panelMinimized = false;
  bool panelMaximized = false;

  Future<void>? _initializing;

  /// Lazily initializes the shared WebView2 controller the first time it's
  /// actually needed (e.g. "Verifica CAST" or "Rilogga CAST"), rather than
  /// eagerly at app startup: the underlying native WebView2 host isn't
  /// available in every context (e.g. widget tests), and there's no reason
  /// to pay its startup cost before the user asks for a CAST check.
  Future<void> initialize() {
    if (ready) return Future.value();
    return _initializing ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    try {
      // The CAST portal is often on-premises with a certificate not trusted
      // by the public PKI: without this flag WebView2 blocks the page with
      // NET::ERR_CERT_AUTHORITY_INVALID.
      await WebviewController.initializeEnvironment(
        additionalArguments: '--ignore-certificate-errors',
      );
    } catch (_) {
      // The WebView2 environment may already have been initialized
      // elsewhere (e.g. hot reload): safe to ignore.
    }
    await controller.initialize();
    ready = true;
    notifyListeners();
  }

  void showPanel({bool minimized = false}) {
    panelVisible = true;
    panelMinimized = minimized;
    notifyListeners();
  }

  void hidePanel() {
    panelVisible = false;
    panelMaximized = false;
    notifyListeners();
  }

  void toggleMinimized() {
    panelMinimized = !panelMinimized;
    if (panelMinimized) panelMaximized = false;
    notifyListeners();
  }

  void toggleMaximized() {
    panelMaximized = !panelMaximized;
    notifyListeners();
  }

  /// Opens the CAST home page for [baseUrl] in the shared WebView and shows
  /// the floating panel, so the user can (re-)authenticate on demand, e.g.
  /// from the configuration screen, without needing to run a build search
  /// first.
  Future<void> openLoginPage(String baseUrl) async {
    await initialize();
    final trimmed = baseUrl.trim().replaceFirst(RegExp(r'\/+$'), '');
    if (trimmed.isEmpty) return;
    showPanel();
    await controller.loadUrl('$trimmed/cast');
  }

  @override
  void dispose() {
    // Only tear down the native WebView2 host if it was actually created;
    // otherwise `WebviewController.dispose()` accesses a `late` field that
    // was never assigned (it's only set inside `WebviewController.
    // initialize()`), which throws a LateInitializationError.
    if (ready) {
      controller.dispose();
    }
    super.dispose();
  }
}
