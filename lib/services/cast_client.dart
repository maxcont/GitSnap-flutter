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
  /// Derives the CAST component name from a GitSnap repository name by
  /// stripping hyphens and spaces (e.g. "AppSorv-BE" -> "AppSorvBE",
  /// "ProgConf-FE-ZAC" -> "ProgConfFEZAC").
  static String castComponentName(String repositoryName) =>
      repositoryName.replaceAll(RegExp(r'[-\s]'), '');

  /// Parses the CAST component history HTML table
  /// (`table.table-cast`/`table-condensed`) into a list of
  /// (build, rating) rows, in the order they appear in the page (most
  /// recent scan first, matching the CAST portal's own ordering).
  static List<CastBuildRating> parseHistoryTable(String html) {
    final rowPattern = RegExp(
      r'<tr>\s*<td[^>]*>([^<]*)</td>\s*<td[^>]*>[^<]*</td>\s*<td[^>]*>.*?</td>\s*<td[^>]*>([^<]*)</td>',
      dotAll: true,
    );
    return rowPattern.allMatches(html).map((m) {
      return CastBuildRating(
        build: m.group(1)!.trim(),
        rating: m.group(2)!.trim(),
      );
    }).toList();
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
