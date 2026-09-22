import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/cast_models.dart';
import 'package:gitsnap_flutter/services/cast_client.dart';

const _sampleHistoryHtml = '''
<table class="table table-condensed table-cast">
    <thead>
        <tr>
            <th scope="col" width="15%">Build</th>
            <th>Branch</th>
            <th scope="col" width="15%">Data</th>
            <th scope="col" width="15%">Quality Rating</th>
            <th scope="col" width="15%">Durata</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td class="text-center">2.0.25048.01</td>
            <td>master</td>
            <td class="text-center"><a title="Vai al dettaglio" class="btn-show-loading" href="/cast/scans/2025/2/17">17/02/2025</a></td>
            <td class="text-center">A</td>
            <td class="text-center">--:--:--</td>
        </tr>
        <tr>
            <td class="text-center">2.0.24345.01</td>
            <td>master</td>
            <td class="text-center"><a title="Vai al dettaglio" class="btn-show-loading" href="/cast/scans/2024/12/10">10/12/2024</a></td>
            <td class="text-center">F</td>
            <td class="text-center">--:--:--</td>
        </tr>
        <tr>
            <td class="text-center">2.0.24344.01</td>
            <td>master</td>
            <td class="text-center"><a title="Vai al dettaglio" class="btn-show-loading" href="/cast/scans/2024/12/9">09/12/2024</a></td>
            <td class="text-center">C</td>
            <td class="text-center">--:--:--</td>
        </tr>
    </tbody>
</table>
''';

void main() {
  group('castComponentName', () {
    test('removes hyphens', () {
      expect(CastClient.castComponentName('AppSorv-BE'), 'AppSorvBE');
    });

    test('removes multiple hyphens', () {
      expect(CastClient.castComponentName('ProgConf-FE-ZAC'), 'ProgConfFEZAC');
    });

    test('removes spaces', () {
      expect(CastClient.castComponentName('Api Gateway'), 'ApiGateway');
    });

    test('leaves already-clean names untouched', () {
      expect(CastClient.castComponentName('GISUtilBackend'), 'GISUtilBackend');
    });
  });

  group('parseHistoryTable', () {
    test('extracts build and rating pairs from the CAST history table', () {
      final rows = CastClient.parseHistoryTable(_sampleHistoryHtml);

      expect(rows, hasLength(3));
      expect(rows[0].build, '2.0.25048.01');
      expect(rows[0].rating, 'A');
      expect(rows[1].build, '2.0.24345.01');
      expect(rows[1].rating, 'F');
      expect(rows[2].build, '2.0.24344.01');
      expect(rows[2].rating, 'C');
    });

    test('returns an empty list when there is no history table', () {
      final rows = CastClient.parseHistoryTable('<html><body>Not found</body></html>');
      expect(rows, isEmpty);
    });
  });

  group('findExactBuild', () {
    final rows = [
      CastBuildRating(build: '2.0.25048.01', rating: 'A'),
      CastBuildRating(build: '2.0.24345.01', rating: 'F'),
    ];

    test('finds the row with an exact build match', () {
      final match = CastClient.findExactBuild(rows, '2.0.24345.01');
      expect(match?.rating, 'F');
    });

    test('trims whitespace before comparing', () {
      final match = CastClient.findExactBuild(rows, '  2.0.25048.01  ');
      expect(match?.rating, 'A');
    });

    test('returns null when the build is not present', () {
      final match = CastClient.findExactBuild(rows, '9.9.99999.99');
      expect(match, isNull);
    });
  });
}
