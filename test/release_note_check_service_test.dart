import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/services/release_note_check_service.dart';

void main() {
  group('parseEntries', () {
    test('trims, drops blanks and case-insensitive duplicates', () {
      expect(
        ReleaseNoteCheckService.parseEntries(' INC376 \r\n\ninc376\nCR_12\n'),
        ['INC376', 'CR_12'],
      );
    });
  });

  group('matches', () {
    test('is case-insensitive and respects word boundaries', () {
      expect(ReleaseNoteCheckService.matches('INC376', 'fix inc376: login'),
          isTrue);
      expect(ReleaseNoteCheckService.matches('INC376', '[INC376]'), isTrue);
      expect(
          ReleaseNoteCheckService.matches('INC376', 'feature/INC376-login'),
          isTrue);
      expect(ReleaseNoteCheckService.matches('INC376', 'INC3761'), isFalse);
      expect(ReleaseNoteCheckService.matches('INC376', 'XINC376'), isFalse);
    });

    test('treats regex characters literally', () {
      expect(ReleaseNoteCheckService.matches('RF(1)', 'done RF(1) ok'), isTrue);
      expect(ReleaseNoteCheckService.matches('a.b', 'axb'), isFalse);
    });
  });

  group('branch patterns', () {
    test('parses comma, semicolon and newline separated patterns', () {
      expect(
        ReleaseNoteCheckService.parseBranchPatterns(
            'release/1, release/2;\nrelease/1'),
        ['release/1', 'release/2'],
      );
    });

    test('supports exact names, wildcards and refs/heads prefix', () {
      expect(ReleaseNoteCheckService.matchesBranchPattern(
          'release/*', 'release/2026.11'), isTrue);
      expect(ReleaseNoteCheckService.matchesBranchPattern(
          'refs/heads/main', 'main'), isTrue);
      expect(ReleaseNoteCheckService.matchesBranchPattern(
          'release/1', 'release/10'), isFalse);
    });
  });
}
