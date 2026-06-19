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
      vars.values.where((v) => v.name == 'invioMailReportOre').map((v) => v.scope).toSet(),
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
}
