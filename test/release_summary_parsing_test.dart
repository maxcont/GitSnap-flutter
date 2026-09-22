import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/services/azure_devops_client.dart';

void main() {
  test('parseReleasesFromResponse extracts artifact version, date and success',
      () {
    final releases = AzureDevOpsClient.parseReleasesFromResponse({
      'value': [
        {
          'id': 160,
          'name': 'Release-160',
          'createdOn': '2026-09-18T16:46:23.000Z',
          'artifacts': [
            {
              'definitionReference': {
                'version': {'id': '1', 'name': '2.0.26261.02'},
              },
            },
          ],
          'environments': [
            {'name': 'Deploy Openshift Intranet', 'status': 'succeeded'},
            {'name': 'Deploy Openshift ZAC', 'status': 'notStarted'},
          ],
        },
        {
          'id': 159,
          'name': 'Release-159',
          'createdOn': '2026-09-18T12:15:26.000Z',
          'artifacts': [
            {
              'definitionReference': {
                'version': {'id': '1', 'name': '2.0.26261.01'},
              },
            },
          ],
          'environments': [
            {'name': 'Deploy Openshift Intranet', 'status': 'rejected'},
          ],
        },
      ],
    });

    expect(releases, hasLength(2));

    final r160 = releases.firstWhere((r) => r.id == 160);
    expect(r160.name, 'Release-160');
    expect(r160.artifactVersion, '2.0.26261.02');
    expect(r160.succeeded, isTrue);
    expect(r160.createdOn, DateTime.parse('2026-09-18T16:46:23.000Z'));

    final r159 = releases.firstWhere((r) => r.id == 159);
    expect(r159.succeeded, isFalse);
  });

  test('parseReleasesFromResponse handles missing artifacts/environments',
      () {
    final releases = AzureDevOpsClient.parseReleasesFromResponse({
      'value': [
        {'id': 1, 'name': 'Release-1', 'createdOn': null},
      ],
    });

    expect(releases, hasLength(1));
    expect(releases.single.artifactVersion, '');
    expect(releases.single.succeeded, isFalse);
    expect(releases.single.createdOn, isNull);
  });

  test('parseReleasesFromResponse returns empty list when value is missing',
      () {
    expect(AzureDevOpsClient.parseReleasesFromResponse({}), isEmpty);
  });
}
