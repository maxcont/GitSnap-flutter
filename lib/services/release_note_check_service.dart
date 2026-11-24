class ReleaseNoteCheckService {
  static List<String> parseEntries(String text) {
    final seen = <String>{};
    final entries = <String>[];
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final entry = line.trim();
      if (entry.isNotEmpty && seen.add(entry.toLowerCase())) {
        entries.add(entry);
      }
    }
    return entries;
  }

  /// [entry] must not be glued to a letter or digit, so `INC376` does not
  /// match `INC3761`.
  static bool matches(String entry, String text) => RegExp(
        '(?<![A-Za-z0-9])${RegExp.escape(entry)}(?![A-Za-z0-9])',
        caseSensitive: false,
      ).hasMatch(text);

  static List<String> parseBranchPatterns(String text) => text
      .split(RegExp(r'[,;\r\n]'))
      .map((pattern) => pattern.trim())
      .where((pattern) => pattern.isNotEmpty)
      .toSet()
      .toList();

  static bool matchesBranchPattern(String pattern, String branch) {
    final normalized = pattern.trim().replaceFirst('refs/heads/', '');
    if (normalized.isEmpty) return false;
    final regex = RegExp(
      '^${RegExp.escape(normalized).replaceAll(r'\*', '.*')}\$',
      caseSensitive: false,
    );
    return regex.hasMatch(branch.replaceFirst('refs/heads/', ''));
  }
}
