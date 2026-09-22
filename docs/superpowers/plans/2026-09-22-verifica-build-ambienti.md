# Tab "Verifica build" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aggiungere un quarto tab "Verifica build" che, per una o più combinazioni repository+numero build inserite dall'utente, mostra in quali dei 4 ambienti (Sviluppo, Collaudo, Pre-Esercizio, Esercizio) quella build è stata rilasciata con successo.

**Architecture:** Riuso delle API Release già presenti in `AzureDevOpsClient` (`getReleaseDefinitions`) più un nuovo metodo `getReleases` che interroga `GET .../release/releases`. La logica pura di matching (repo↔release definition, build↔artifact version, scelta della release più recente) vive in un nuovo `BuildSearchService`, testabile senza rete, seguendo lo stesso pattern di `PullRequestFilterService`. La UI (`BuildEnvironmentTab`) gestisce righe multiple repo+build con `FutureBuilder` per-ambiente così i risultati si popolano in modo indipendente e parallelo.

**Tech Stack:** Flutter/Dart, `package:http`, `provider` (AppState esistente), `intl` per date, `flutter_test` per gli unit test.

---

## Task 1: Modello `ReleaseSummary` e parsing releases

**Files:**
- Modify: `lib/models/release_models.dart`
- Test: `test/release_summary_parsing_test.dart`

- [ ] **Step 1: Scrivere il modello `ReleaseSummary` in `release_models.dart`**

Aggiungi in fondo al file `lib/models/release_models.dart`:

```dart

/// Summary of a single release (rilascio) returned by the Release API,
/// used to check whether a given build was deployed to an environment.
class ReleaseSummary {
  final int id;
  final String name;
  final DateTime? createdOn;
  final String artifactVersion;
  final bool succeeded;

  ReleaseSummary({
    required this.id,
    required this.name,
    required this.createdOn,
    required this.artifactVersion,
    required this.succeeded,
  });
}
```

- [ ] **Step 2: Scrivere il test di parsing (failing)**

Crea `test/release_summary_parsing_test.dart`:

```dart
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
```

- [ ] **Step 3: Eseguire il test e verificare che fallisca**

Run: `flutter test test/release_summary_parsing_test.dart`
Expected: FAIL — `parseReleasesFromResponse` non esiste ancora su `AzureDevOpsClient`.

- [ ] **Step 4: Implementare `parseReleasesFromResponse` in `azure_devops_client.dart`**

Aggiungi in `lib/services/azure_devops_client.dart`, subito prima della chiusura della classe (dopo il metodo `_addVarsFromMap`, prima dell'ultima `}` di classe):

```dart

  /// Parse the JSON body of `GET .../release/releases` (with
  /// `$expand=artifacts,environments`) into a list of [ReleaseSummary].
  static List<ReleaseSummary> parseReleasesFromResponse(
      Map<String, dynamic> data) {
    final list = data['value'] as List?;
    if (list == null) return [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);

      var artifactVersion = '';
      final artifacts = m['artifacts'] as List?;
      if (artifacts != null && artifacts.isNotEmpty) {
        final firstArtifact = Map<String, dynamic>.from(
            artifacts.first as Map);
        final defRef = firstArtifact['definitionReference'];
        if (defRef is Map) {
          final version = defRef['version'];
          if (version is Map) {
            artifactVersion = version['name']?.toString() ?? '';
          }
        }
      }

      var succeeded = false;
      final environments = m['environments'] as List?;
      if (environments != null) {
        succeeded = environments.any((env) {
          if (env is! Map) return false;
          final status = env['status']?.toString().toLowerCase();
          return status == 'succeeded';
        });
      }

      DateTime? createdOn;
      final createdOnRaw = m['createdOn']?.toString();
      if (createdOnRaw != null) {
        createdOn = DateTime.tryParse(createdOnRaw);
      }

      return ReleaseSummary(
        id: (m['id'] as num).toInt(),
        name: m['name'] as String? ?? '',
        createdOn: createdOn,
        artifactVersion: artifactVersion,
        succeeded: succeeded,
      );
    }).toList();
  }
```

- [ ] **Step 5: Eseguire il test e verificare che passi**

Run: `flutter test test/release_summary_parsing_test.dart`
Expected: PASS (3 test).

- [ ] **Step 6: Commit**

```bash
git add lib/models/release_models.dart lib/services/azure_devops_client.dart test/release_summary_parsing_test.dart
git commit -m "feat: add ReleaseSummary model and release parsing

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 2: Metodo `getReleases` in `AzureDevOpsClient`

**Files:**
- Modify: `lib/services/azure_devops_client.dart:490` (area "Release / Pipeline APIs")

- [ ] **Step 1: Implementare `getReleases`**

Aggiungi in `lib/services/azure_devops_client.dart`, subito dopo il metodo `getReleaseDefinitionRevisions` (prima di `getVariablesAtRevision`):

```dart

  /// List releases for a release definition, optionally restricted to a
  /// creation date range. Includes artifacts and environments so callers
  /// can determine the deployed build version and its outcome.
  Future<List<ReleaseSummary>> getReleases(
    int definitionId, {
    DateTime? minCreatedTime,
    DateTime? maxCreatedTime,
    int top = 50,
  }) async {
    final q = <String, String>{
      'definitionId': '$definitionId',
      r'$expand': 'artifacts,environments',
      'queryOrder': 'descending',
      r'$top': '$top',
      'api-version': '7.0',
    };
    if (minCreatedTime != null) {
      q['minCreatedTime'] = minCreatedTime.toUtc().toIso8601String();
    }
    if (maxCreatedTime != null) {
      q['maxCreatedTime'] = maxCreatedTime.toUtc().toIso8601String();
    }
    final url =
        Uri.parse('$_releaseBase/releases').replace(queryParameters: q);
    final response = await http.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw AzureDevOpsClientError('Releases: ${response.statusCode}');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    return parseReleasesFromResponse(data);
  }
```

- [ ] **Step 2: Verificare che il progetto compili**

Run: `flutter analyze lib/services/azure_devops_client.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/azure_devops_client.dart
git commit -m "feat: add getReleases to AzureDevOpsClient

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 3: `BuildSearchService` (logica pura + orchestrazione)

**Files:**
- Create: `lib/services/build_search_service.dart`
- Create: `lib/models/build_environment_result.dart`
- Test: `test/build_search_service_test.dart`

- [ ] **Step 1: Creare il modello di risultato per ambiente**

Crea `lib/models/build_environment_result.dart`:

```dart
import 'release_models.dart';

enum BuildEnvironmentStatus { found, notFound, pipelineMissing }

/// Result of checking whether a given build was successfully deployed to
/// one environment (Sviluppo / Collaudo / Pre-Esercizio / Esercizio).
class BuildEnvironmentResult {
  final BuildEnvironmentStatus status;
  final ReleaseSummary? release;

  const BuildEnvironmentResult.found(ReleaseSummary release)
      : status = BuildEnvironmentStatus.found,
        release = release;

  const BuildEnvironmentResult.notFound()
      : status = BuildEnvironmentStatus.notFound,
        release = null;

  const BuildEnvironmentResult.pipelineMissing()
      : status = BuildEnvironmentStatus.pipelineMissing,
        release = null;
}
```

- [ ] **Step 2: Scrivere i test di logica pura (failing)**

Crea `test/build_search_service_test.dart`:

```dart
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
```

- [ ] **Step 3: Eseguire il test e verificare che fallisca**

Run: `flutter test test/build_search_service_test.dart`
Expected: FAIL — non esiste ancora `lib/services/build_search_service.dart`.

- [ ] **Step 4: Implementare `BuildSearchService`**

Crea `lib/services/build_search_service.dart`:

```dart
import '../models/build_environment_result.dart';
import '../models/release_models.dart';
import 'azure_devops_client.dart';

/// Looks up, for a given repository and build/version number, in which
/// environments (Sviluppo / Collaudo / Pre-Esercizio / Esercizio) that
/// build was successfully deployed.
class BuildSearchService {
  /// Azure DevOps release folder path per environment, in display order.
  static const Map<String, String> environmentFolders = {
    'Sviluppo': r'\Sviluppo',
    'Collaudo': r'\Collaudo',
    'Pre-Esercizio': r'\Pre-Esercizio',
    'Esercizio': r'\Esercizio',
  };

  final AzureDevOpsClient client;

  BuildSearchService(this.client);

  /// Checks one environment for the given repository/build combination.
  Future<BuildEnvironmentResult> checkEnvironment({
    required String folder,
    required String repositoryName,
    required String buildQuery,
    DateTime? minCreatedTime,
    DateTime? maxCreatedTime,
  }) async {
    final definitions = await client.getReleaseDefinitions(path: folder);
    final definition = selectDefinitionForRepo(definitions, repositoryName);
    if (definition == null) {
      return const BuildEnvironmentResult.pipelineMissing();
    }

    final releases = await client.getReleases(
      definition.id,
      minCreatedTime: minCreatedTime,
      maxCreatedTime: maxCreatedTime,
    );
    final match = findMatchingRelease(releases, buildQuery);
    if (match == null) {
      return const BuildEnvironmentResult.notFound();
    }
    return BuildEnvironmentResult.found(match);
  }

  /// Picks the release definition in [definitions] whose name best matches
  /// [repositoryName]: any definition whose name contains the repository
  /// name (case-insensitive), preferring the shortest (narrowest) name.
  static ReleaseDefinitionInfo? selectDefinitionForRepo(
    List<ReleaseDefinitionInfo> definitions,
    String repositoryName,
  ) {
    final needle = repositoryName.trim().toLowerCase();
    if (needle.isEmpty) return null;
    final matches = definitions
        .where((d) => d.name.toLowerCase().contains(needle))
        .toList()
      ..sort((a, b) => a.name.length.compareTo(b.name.length));
    return matches.isEmpty ? null : matches.first;
  }

  /// Case-insensitive "contains" match between an artifact version and the
  /// user-provided search text. An empty search text never matches.
  static bool buildMatches(String artifactVersion, String searchText) {
    final needle = searchText.trim().toLowerCase();
    if (needle.isEmpty) return false;
    return artifactVersion.toLowerCase().contains(needle);
  }

  /// Among succeeded [releases] whose artifact version matches
  /// [searchText], returns the most recently created one, or null if none
  /// match.
  static ReleaseSummary? findMatchingRelease(
    List<ReleaseSummary> releases,
    String searchText,
  ) {
    final matches = releases
        .where((r) => r.succeeded && buildMatches(r.artifactVersion, searchText))
        .toList()
      ..sort((a, b) {
        final aDate = a.createdOn;
        final bDate = b.createdOn;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    return matches.isEmpty ? null : matches.first;
  }
}
```

- [ ] **Step 5: Eseguire il test e verificare che passi**

Run: `flutter test test/build_search_service_test.dart`
Expected: PASS (8 test).

- [ ] **Step 6: Commit**

```bash
git add lib/models/build_environment_result.dart lib/services/build_search_service.dart test/build_search_service_test.dart
git commit -m "feat: add BuildSearchService with pure matching logic

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 4: Widget `BuildEnvironmentTab`

**Files:**
- Create: `lib/widgets/build_environment_tab.dart`

- [ ] **Step 1: Creare il widget con righe multiple, filtro data e risultati**

Crea `lib/widgets/build_environment_tab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/azure_models.dart';
import '../models/build_environment_result.dart';
import '../providers/app_state.dart';
import '../services/build_search_service.dart';

class BuildEnvironmentTab extends StatefulWidget {
  const BuildEnvironmentTab({super.key});

  @override
  State<BuildEnvironmentTab> createState() => _BuildEnvironmentTabState();
}

class _QueryRow {
  Repository? repository;
  final TextEditingController buildController = TextEditingController();

  void dispose() => buildController.dispose();
}

class _ComboSearch {
  final Repository repository;
  final String buildQuery;
  final Map<String, Future<BuildEnvironmentResult>> environmentFutures;

  _ComboSearch({
    required this.repository,
    required this.buildQuery,
    required this.environmentFutures,
  });
}

class _BuildEnvironmentTabState extends State<BuildEnvironmentTab> {
  final List<_QueryRow> _rows = [_QueryRow()];
  DateTime? _fromDate;
  DateTime? _toDate;
  List<_ComboSearch> _results = [];
  String? _error;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_QueryRow()));

  void _removeRow(_QueryRow row) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows.remove(row);
      row.dispose();
    });
  }

  Future<void> _pickDate(bool from) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: (from ? _fromDate : _toDate) ?? now,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (selected == null) return;
    setState(() => from ? _fromDate = selected : _toDate = selected);
  }

  void _search(AppState appState) {
    final client = appState.client;
    if (client == null) {
      setState(
          () => _error = 'Carica prima i repository (configura e connetti).');
      return;
    }
    final service = BuildSearchService(client);
    final combos = <_ComboSearch>[];
    for (final row in _rows) {
      final repo = row.repository;
      final build = row.buildController.text.trim();
      if (repo == null || build.isEmpty) continue;
      final environmentFutures = <String, Future<BuildEnvironmentResult>>{};
      for (final entry in BuildSearchService.environmentFolders.entries) {
        environmentFutures[entry.key] = service.checkEnvironment(
          folder: entry.value,
          repositoryName: repo.name,
          buildQuery: build,
          minCreatedTime: _fromDate,
          maxCreatedTime: _toDate,
        );
      }
      combos.add(_ComboSearch(
        repository: repo,
        buildQuery: build,
        environmentFutures: environmentFutures,
      ));
    }
    setState(() {
      _error = combos.isEmpty
          ? 'Compila almeno una riga con repository e numero build.'
          : null;
      _results = combos;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final dateFormat = DateFormat('dd/MM/yyyy');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verifica in quali ambienti (Sviluppo, Collaudo, Pre-Esercizio, '
            'Esercizio) è stata rilasciata una determinata build, per uno o '
            'più repository contemporaneamente.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Combinazioni da verificare',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final row in _rows) _buildRow(row, appState.repositories),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi combinazione'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => _pickDate(true),
                        child: Text(_fromDate == null
                            ? 'Da (opzionale)'
                            : 'Da ${dateFormat.format(_fromDate!)}'),
                      ),
                      OutlinedButton(
                        onPressed: () => _pickDate(false),
                        child: Text(_toDate == null
                            ? 'A (opzionale)'
                            : 'A ${dateFormat.format(_toDate!)}'),
                      ),
                      if (_fromDate != null || _toDate != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _fromDate = null;
                            _toDate = null;
                          }),
                          child: const Text('Rimuovi filtro data'),
                        ),
                      FilledButton.icon(
                        onPressed: () => _search(appState),
                        icon: const Icon(Icons.search),
                        label: const Text('Cerca tutto'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 24),
            for (final combo in _results) _buildResultCard(combo),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(_QueryRow row, List<Repository> repositories) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<Repository>(
              decoration: const InputDecoration(labelText: 'Repository'),
              value: row.repository,
              isExpanded: true,
              items: repositories
                  .map((repo) => DropdownMenuItem(
                        value: repo,
                        child: Text(repo.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => row.repository = value),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.buildController,
              decoration: const InputDecoration(
                labelText: 'Numero build/versione',
                hintText: 'es. 2.0.26261.02',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _rows.length <= 1 ? null : () => _removeRow(row),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(_ComboSearch combo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${combo.repository.name} · ${combo.buildQuery}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: BuildSearchService.environmentFolders.keys
                  .map((label) => _environmentTile(label, combo))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _environmentTile(String label, _ComboSearch combo) {
    return SizedBox(
      width: 220,
      child: FutureBuilder<BuildEnvironmentResult>(
        future: combo.environmentFutures[label],
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _tileCard(
              label: label,
              color: Colors.grey.shade200,
              icon: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              text: 'Verifica in corso…',
            );
          }
          if (snapshot.hasError) {
            return _tileCard(
              label: label,
              color: Colors.red.shade100,
              icon: const Icon(Icons.error_outline, color: Colors.red),
              text: snapshot.error.toString().replaceFirst('Exception: ', ''),
            );
          }
          final result = snapshot.data!;
          switch (result.status) {
            case BuildEnvironmentStatus.found:
              final release = result.release!;
              final dateText = release.createdOn == null
                  ? ''
                  : ' · ${DateFormat('dd/MM/yyyy HH:mm').format(release.createdOn!.toLocal())}';
              return _tileCard(
                label: label,
                color: Colors.green.shade100,
                icon: const Icon(Icons.check_circle, color: Colors.green),
                text: 'Installata · ${release.name}$dateText',
              );
            case BuildEnvironmentStatus.notFound:
              return _tileCard(
                label: label,
                color: Colors.grey.shade200,
                icon: const Icon(Icons.remove_circle_outline),
                text: 'Non trovata',
              );
            case BuildEnvironmentStatus.pipelineMissing:
              return _tileCard(
                label: label,
                color: Colors.amber.shade100,
                icon: const Icon(Icons.warning_amber, color: Colors.amber),
                text: 'Pipeline non trovata',
              );
          }
        },
      ),
    );
  }

  Widget _tileCard({
    required String label,
    required Color color,
    required Widget icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              icon,
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verificare che il progetto compili**

Run: `flutter analyze lib/widgets/build_environment_tab.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/build_environment_tab.dart
git commit -m "feat: add BuildEnvironmentTab widget

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 5: Integrare il nuovo tab in `HomeScreen`

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Aggiungere import, `length: 4`, `Tab` e `TabBarView`**

In `lib/screens/home_screen.dart`, aggiungi l'import:

```dart
import '../widgets/build_environment_tab.dart';
```

subito dopo:
```dart
import '../widgets/pull_requests_tab.dart';
```

Poi cambia:
```dart
    return DefaultTabController(
      length: 3,
```
in:
```dart
    return DefaultTabController(
      length: 4,
```

Poi cambia il blocco `TabBar`:
```dart
          bottom: const TabBar(
            tabs: [
              Tab(
                  text: 'Confronto repository',
                  icon: Icon(Icons.compare_arrows)),
              Tab(text: 'Utility pipeline', icon: Icon(Icons.build)),
              Tab(text: 'Pull request', icon: Icon(Icons.call_split)),
            ],
          ),
```
in:
```dart
          bottom: const TabBar(
            tabs: [
              Tab(
                  text: 'Confronto repository',
                  icon: Icon(Icons.compare_arrows)),
              Tab(text: 'Utility pipeline', icon: Icon(Icons.build)),
              Tab(text: 'Pull request', icon: Icon(Icons.call_split)),
              Tab(text: 'Verifica build', icon: Icon(Icons.rocket_launch)),
            ],
          ),
```

Poi cambia il blocco `TabBarView`:
```dart
        body: TabBarView(
          children: [
            _ComparisonTab(),
            const PipelineVariablesTab(),
            const PullRequestsTab(),
          ],
        ),
```
in:
```dart
        body: TabBarView(
          children: [
            _ComparisonTab(),
            const PipelineVariablesTab(),
            const PullRequestsTab(),
            const BuildEnvironmentTab(),
          ],
        ),
```

- [ ] **Step 2: Verificare che il progetto compili**

Run: `flutter analyze lib/screens/home_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Eseguire l'intera suite di test**

Run: `flutter test`
Expected: tutti i test PASS, incluse le nuove suite create nei Task 1 e 3.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: wire Verifica build tab into HomeScreen

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 6: Verifica manuale finale

- [ ] **Step 1: Avviare l'app**

Run: `flutter run -d windows` (o piattaforma disponibile nell'ambiente di sviluppo)

- [ ] **Step 2: Verificare il nuovo tab**

Nell'app: aprire il tab "Verifica build", configurare la connessione (se non già fatto negli altri tab), selezionare un repository esistente, inserire un numero di build reale visibile in Azure DevOps (colonna "Versioni" della release), premere "Cerca tutto" e verificare che compaiano le 4 card ambiente con stato coerente (✅/⚪/⚠️) rispetto a quanto visibile manualmente nel portale Azure DevOps.

- [ ] **Step 3: Verificare le combinazioni multiple**

Premere "Aggiungi combinazione", compilare una seconda riga con un altro repository/build, premere "Cerca tutto" e verificare che vengano mostrate due card risultato distinte, aggiornate in modo indipendente.
