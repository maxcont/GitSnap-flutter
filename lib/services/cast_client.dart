import 'dart:async';

import 'package:webview_windows/webview_windows.dart';

import '../models/cast_models.dart';

/// Fetches and parses the CAST ("DevOps Reports") component quality
/// history for a repository, to check the Quality Rating of a specific
/// build.
///
/// Authentication against the CAST portal uses Windows Integrated Auth
/// (NTLM), which this class does not implement directly: navigation and
/// authentication are delegated to a WebView2-backed `WebviewController`
/// supplied by the caller (see `fetchComponentPage`). The parsing/matching
/// logic below has no network dependency and is unit-tested directly.
class CastClient {
  final WebviewController controller;
  final String baseUrl;

  CastClient({
    required this.controller,
    required this.baseUrl,
  });

  Future<List<CastBuildRating>> fetchComponentHistory(
    String repositoryName,
  ) async {
    final trimmedBaseUrl = baseUrl.trim().replaceFirst(RegExp(r'\/+$'), '');
    if (trimmedBaseUrl.isEmpty) {
      throw CastClientError(
          'Configurare il Base URL CAST prima della ricerca.');
    }

    final component = castComponentName(repositoryName);
    final uri = Uri.parse(
      '$trimmedBaseUrl/cast/EACS/$component',
    );
    try {
      await controller.loadUrl(uri.toString());
      await controller.loadingState
          .firstWhere((state) => state == LoadingState.navigationCompleted)
          .timeout(const Duration(seconds: 30));

      // The "Ultime scansioni" table on the CAST page can be populated by
      // JavaScript shortly after navigation completes, so a single snapshot
      // right after navigationCompleted may still be empty. Poll a few
      // times, giving the page a little time to finish rendering, and stop
      // as soon as we find at least one row.
      var html = '';
      var rows = <CastBuildRating>[];
      for (var attempt = 0; attempt < 8; attempt++) {
        if (attempt > 0) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
        final result = await controller.executeScript(
          'document.documentElement.outerHTML',
        );
        if (result is! String || result.trim().isEmpty) {
          continue;
        }
        html = result;
        rows = parseHistoryTable(html);
        if (rows.isNotEmpty) break;
      }
      if (html.trim().isEmpty) {
        throw CastClientError('CAST ha restituito una pagina vuota.');
      }
      if (!looksAuthenticated(html)) {
        throw CastClientError(
          'Non risulta autenticato su CAST. Vai su Configurazione e premi '
          '"Rilogga CAST", poi riprova.',
        );
      }
      return rows;
    } on CastClientError {
      rethrow;
    } on TimeoutException {
      throw CastClientError(
          'Timeout durante il caricamento della pagina CAST.');
    } catch (error) {
      throw CastClientError('Impossibile caricare CAST: $error');
    }
  }

  Future<CastBuildRating?> findBuildRating(
    String repositoryName,
    String buildVersion,
  ) async {
    final rows = await fetchComponentHistory(repositoryName);
    return findExactBuild(rows, buildVersion);
  }

  /// Derives the CAST component name from a GitSnap repository name by
  /// stripping hyphens and spaces (e.g. "AppSorv-BE" -> "AppSorvBE",
  /// "ProgConf-FE-ZAC" -> "ProgConfFEZAC").
  static String castComponentName(String repositoryName) =>
      repositoryName.replaceAll(RegExp(r'[-\s]'), '');

  /// Returns whether [html] looks like an actual, authenticated CAST
  /// component page, rather than a login/SSO page or an access-denied
  /// response.
  ///
  /// When the WebView2 session isn't authenticated (e.g. the NTLM/Windows
  /// Integrated Auth ticket expired, or the user hasn't logged in yet), the
  /// portal serves a different page instead of the component report, which
  /// would otherwise be silently misread as "build not found". Both the
  /// "CAST: <component>" page title and the `table-cast` history table are
  /// always present on a real component page (even with zero scans, the
  /// table skeleton with its headers is still rendered), so their absence
  /// is a reliable signal that we're not actually logged in.
  static bool looksAuthenticated(String html) =>
      html.contains('table-cast') || html.contains('class="page-title"');

  /// Parses the CAST component history HTML table
  /// (`table.table-cast`/`table-condensed`) into a list of
  /// (build, rating) rows, in the order they appear in the page (most
  /// recent scan first, matching the CAST portal's own ordering).
  ///
  /// Cell contents are extracted generically (via a `<tr>`/`<td>` scan) and
  /// stripped of any nested tags (e.g. the "Data" column contains a link),
  /// so it doesn't matter whether a specific cell wraps its text in extra
  /// markup.
  static List<CastBuildRating> parseHistoryTable(String html) {
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
    final cellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
    final rows = <CastBuildRating>[];
    for (final rowMatch in rowPattern.allMatches(html)) {
      final cells = cellPattern
          .allMatches(rowMatch.group(1)!)
          .map((m) => _cellText(m.group(1)!))
          .toList();
      if (cells.length < 4) continue;
      final build = cells[0];
      if (build.isEmpty) continue;
      rows.add(CastBuildRating(build: build, rating: cells[3]));
    }
    return rows;
  }

  /// Strips nested HTML tags and unescapes common HTML entities from a
  /// single table cell's inner HTML, returning trimmed plain text.
  static String _cellText(String cellHtml) {
    final withoutTags = cellHtml.replaceAll(RegExp(r'<[^>]*>'), '');
    final unescaped = withoutTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return unescaped.trim();
  }

  /// Finds the row in [rows] whose build matches [exactBuildVersion]
  /// exactly (after trimming whitespace), or null if not present.
  static CastBuildRating? findExactBuild(
    List<CastBuildRating> rows,
    String exactBuildVersion,
  ) {
    final needle = exactBuildVersion.trim();
    for (final row in rows) {
      if (row.build == needle) return row;
    }
    return null;
  }
}
