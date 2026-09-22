import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_windows/webview_windows.dart';

import '../services/cast_session.dart';

/// Floating panel showing the shared CAST WebView, used to let the user
/// (re-)authenticate against the CAST portal (Windows/NTLM). It can be
/// minimized to just its header, or enlarged to almost fill the screen, and
/// is shown/hidden through the app-wide [CastSession].
class CastLoginPanel extends StatelessWidget {
  const CastLoginPanel({super.key});

  Widget _headerButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white70, size: 18),
      iconSize: 18,
      splashRadius: 16,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CastSession>();

    if (session.panelMinimized) {
      return _minimizedBadge(session);
    }

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Login CAST',
              style: TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _headerButton(
            icon: session.panelMaximized
                ? Icons.close_fullscreen
                : Icons.open_in_full,
            tooltip: session.panelMaximized ? 'Ripristina' : 'Ingrandisci',
            onPressed: session.toggleMaximized,
          ),
          _headerButton(
            icon: Icons.remove,
            tooltip: 'Riduci a icona',
            onPressed: session.toggleMinimized,
          ),
          _headerButton(
            icon: Icons.close,
            tooltip: 'Chiudi',
            onPressed: session.hidePanel,
          ),
        ],
      ),
    );

    final webview = session.ready
        ? Webview(session.controller)
        : const Center(child: CircularProgressIndicator());

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: Colors.grey.shade900,
      child: Container(
        width: session.panelMaximized ? double.infinity : 340,
        height: session.panelMaximized ? double.infinity : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade700),
        ),
        child: Column(
          mainAxisSize:
              session.panelMaximized ? MainAxisSize.max : MainAxisSize.min,
          children: [
            header,
            session.panelMaximized
                ? Expanded(child: webview)
                : SizedBox(width: 340, height: 400, child: webview),
          ],
        ),
      ),
    );
  }

  /// Small floating badge shown instead of the full panel when minimized,
  /// so it stays out of the way of the results below it (previously the
  /// minimized state still kept the full-width header bar, which was too
  /// intrusive).
  Widget _minimizedBadge(CastSession session) {
    return Material(
      elevation: 8,
      color: Colors.grey.shade900,
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white24),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: session.toggleMinimized,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.verified_outlined, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

/// Wraps [child] so the [CastLoginPanel] floats above it (bottom-right, or
/// almost full-screen when maximized) whenever `CastSession.panelVisible`
/// is true. Place this once near the root of the widget tree (e.g. in
/// `HomeScreen`) so the panel persists across tab switches.
///
/// [showPanel] lets the caller further restrict *where* the floating panel
/// is actually displayed (e.g. only on the tabs that interact with CAST):
/// when false, the panel is hidden regardless of `CastSession.panelVisible`,
/// without touching the underlying WebView2 session/controller.
class CastLoginOverlay extends StatelessWidget {
  final Widget child;
  final bool showPanel;

  const CastLoginOverlay({
    super.key,
    required this.child,
    this.showPanel = true,
  });

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CastSession>();
    return Stack(
      children: [
        child,
        if (showPanel && session.panelVisible)
          session.panelMaximized
              ? const Positioned(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: 24,
                  child: CastLoginPanel(),
                )
              : const Positioned(
                  right: 16,
                  bottom: 16,
                  child: CastLoginPanel(),
                ),
      ],
    );
  }
}
