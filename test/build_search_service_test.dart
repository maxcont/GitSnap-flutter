import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/release_models.dart';
import 'package:gitsnap_flutter/services/build_search_service.dart';

void main() {
  group('selectDefinitionForRepo', () {
    test('picks the definition whose name contains the repo name', () {
      final defs = [
        ReleaseDefinitionInfo(id: 1, name: 'ApiGateway-ZAC Collaudo'),
        ReleaseDefinitionInfo(id: 2, name: 'ApiGateway Collaudo'),
      ];
      final picked = BuildSearchService.selectDefinitionForRepo(
          defs, 'ApiGateway');
      expect(picked?.id, 2, reason: 'shortest/narrowest match should win');
    });

    test('is case-insensitive', () {
      final defs = [
        ReleaseDefinitionInfo(id: 1, name: 'appsorv-be collaudo'),
      ];
      final picked =
          BuildSearchService.selectDefinitionForRepo(defs, 'AppSorv-BE');
      expect(picked?.id, 1);
    });

    test('returns null when no definition matches', () {
      final defs = [ReleaseDefinitionInfo(id: 1, name: 'Broker-BE Collaudo')];
      final picked =
          BuildSearchService.selectDefinitionForRepo(defs, 'AppSorv-BE');
      expect(picked, isNull);
    });
  });

  group('buildMatches', () {
    test('matches substring case-insensitively', () {
      expect(BuildSearchService.buildMatches('2.0.26261.02', '26261'), isTrue);
      expect(
          BuildSearchService.buildMatches('2.0.26261.02', '2.0.26261.02'),
          isTrue);
      expect(BuildSearchService.buildMatches('2.0.26261.02', '99999'),
          isFalse);
    });

    test('empty search text never matches', () {
      expect(BuildSearchService.buildMatches('2.0.26261.02', ''), isFalse);
      expect(BuildSearchService.buildMatches('2.0.26261.02', '   '), isFalse);
    });
  });

  group('findMatchingRelease', () {
    test('ignores non-succeeded releases', () {
      final releases = [
        ReleaseSummary(
          id: 1,
          name: 'Release-1',
          createdOn: DateTime(2026, 1, 1),
          artifactVersion: '2.0.26261.02',
          succeeded: false,
        ),
      ];
      expect(
          BuildSearchService.findMatchingRelease(releases, '26261'), isNull);
    });

    test('returns the most recent matching succeeded release', () {
      final older = ReleaseSummary(
        id: 1,
        name: 'Release-159',
        createdOn: DateTime(2026, 9, 18, 12),
        artifactVersion: '2.0.26261.01',
        succeeded: true,
      );
      final newer = ReleaseSummary(
        id: 2,
        name: 'Release-160',
        createdOn: DateTime(2026, 9, 18, 16),
        artifactVersion: '2.0.26261.02',
        succeeded: true,
      );
      final result = BuildSearchService.findMatchingRelease(
          [older, newer], '2.0.26261');
      expect(result?.id, 2);
    });

    test('returns null when nothing matches', () {
      final releases = [
        ReleaseSummary(
          id: 1,
          name: 'Release-1',
          createdOn: DateTime(2026, 1, 1),
          artifactVersion: '2.0.99999.01',
          succeeded: true,
        ),
      ];
      expect(
          BuildSearchService.findMatchingRelease(releases, '26261'), isNull);
    });
  });
}
