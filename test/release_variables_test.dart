import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/release_models.dart';
import 'package:gitsnap_flutter/services/azure_devops_client.dart';

void main() {
  test('parseVariablesFromDefinition keeps same name in different scopes', () {
    final vars = AzureDevOpsClient.parseVariablesFromDefinition({
      'variables': {
        'Ambiente': {'value': 'Collaudo', 'isSecret': false},
      },
      'environments': [
        {
          'name': 'Deploy Openshift Intranet',
          'variables': {
            'invioMailReportOre': {'value': '-', 'isSecret': false},
          },
        },
        {
          'name': 'Deploy Openshift ZAC',
          'variables': {
            'invioMailReportOre': {'value': '-', 'isSecret': false},
          },
        },
      ],
    });

    expect(vars.length, 3);
    expect(
      vars.values
          .where((v) => v.name == 'invioMailReportOre')
          .map((v) => v.scope)
          .toSet(),
      {
        'Deploy Openshift Intranet',
        'Deploy Openshift ZAC',
      },
    );
    expect(
      vars.values.singleWhere((v) => v.name == 'Ambiente').scope,
      ReleaseVariable.releaseScope,
    );
  });

  test('parseVariablesFromDefinition supports TFS fps wrapper payload', () {
    final vars = AzureDevOpsClient.parseVariablesFromDefinition({
      'fps': {
        'dataProviders': {
          'data': {
            'ms.vss-releaseManagement-web.cdworkflow.webpage.data-provider': {
              'releaseDefinition': {
                'id': 18,
                'name': 'Documentale-BE Collaudo',
                'variables': {
                  'UriBrokerBatch': {
                    'value':
                        'http://eacs-broker-be\$(OCEnvironmentType)-batch:8080',
                    'isSecret': false,
                  },
                },
                'environments': [
                  {
                    'name': 'Deploy Openshift Intranet',
                    'variables': {
                      'uriNotify': {
                        'value':
                            'http://eacs-notify-be\$(OCEnvironmentType).eacs',
                      },
                    },
                  },
                ],
              },
            },
          },
        },
      },
    });

    expect(vars.values.any((v) => v.name == 'UriBrokerBatch'), isTrue);
    expect(
      vars.values.any(
        (v) => v.name == 'uriNotify' && v.scope == 'Deploy Openshift Intranet',
      ),
      isTrue,
    );
  });
}
