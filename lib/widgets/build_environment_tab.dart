import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/azure_models.dart';
import '../models/build_environment_result.dart';
import '../models/cast_models.dart';
import '../providers/app_state.dart';
import '../services/build_search_service.dart';
import '../services/cast_client.dart';
import '../services/cast_session.dart';

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

class _BuildEnvironmentTabState extends State<BuildEnvironmentTab>
    with AutomaticKeepAliveClientMixin<BuildEnvironmentTab> {
  final List<_QueryRow> _rows = [_QueryRow()];
  DateTime? _fromDate;
  DateTime? _toDate;
  List<_ComboSearch> _results = [];
  String? _error;
  bool _castChecking = false;
  final Map<String, CastBuildRating?> _castRatings = {};
  final Map<String, String> _castErrors = {};
  final Set<String> _castLoading = {};

  // Without this, switching to a tab several positions away (e.g. from
  // "Verifica build" to "Confronto repository") can make Flutter's
  // TabBarView dispose this tab's state entirely once it's outside the
  // page cache extent, silently clearing the rows/results/CAST ratings the
  // user had already set up. Keeping it alive preserves everything across
  // tab switches.
  @override
  bool get wantKeepAlive => true;

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
      _castRatings.clear();
      _castErrors.clear();
    });
  }

  String _castKey(_ComboSearch combo, String label) =>
      '${combo.repository.id}|${combo.buildQuery}|$label';

  Future<void> _verifyCast(AppState appState) async {
    final castSession = context.read<CastSession>();
    await castSession.initialize();
    if (!castSession.ready) {
      setState(() => _error = 'WebView CAST non ancora pronta.');
      return;
    }
    if (appState.castBaseUrl.trim().isEmpty) {
      setState(
          () => _error = 'Configura il CAST Base URL prima della verifica.');
      return;
    }
    setState(() {
      _castChecking = true;
      _error = null;
      _castRatings.clear();
      _castErrors.clear();
    });
    // Keep the panel minimized by default: when a Windows/NTLM session is
    // already valid the CAST pages load silently with no visible login
    // form, so there's nothing useful to show. The user can still expand
    // the small badge manually if a check gets stuck (e.g. a real login
    // prompt appears).
    castSession.showPanel(minimized: true);
    final client = CastClient(
      controller: castSession.controller,
      baseUrl: appState.castBaseUrl,
    );
    try {
      for (final combo in _results) {
        for (final label in BuildSearchService.environmentFolders.keys) {
          final key = _castKey(combo, label);
          final environment = await combo.environmentFutures[label]!;
          if (environment.status != BuildEnvironmentStatus.found) continue;
          setState(() => _castLoading.add(key));
          try {
            final rating = await client.findBuildRating(
              combo.repository.name,
              environment.release!.artifactVersion,
            );
            if (mounted) {
              setState(() {
                _castRatings[key] = rating;
                _castLoading.remove(key);
              });
            }
          } on CastClientError catch (error) {
            if (mounted) {
              setState(() {
                _castErrors[key] = error.message;
                _castLoading.remove(key);
              });
            }
          }
        }
      }
    } finally {
      if (mounted) setState(() => _castChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appState = context.watch<AppState>();
    return _buildMainContent(context, appState);
  }

  Widget _buildMainContent(BuildContext context, AppState appState) {
    final castSession = context.watch<CastSession>();
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
                  for (final row in _rows)
                    _buildRow(row, appState.repositories),
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
                      if (_results.isNotEmpty)
                        FilledButton.icon(
                          onPressed: _castChecking
                              ? null
                              : () => _verifyCast(appState),
                          icon: const Icon(Icons.verified_outlined),
                          label: Text(_castChecking
                              ? 'CAST in corso…'
                              : 'Verifica CAST'),
                        ),
                      if (!castSession.panelVisible &&
                          (_castChecking || _castRatings.isNotEmpty))
                        OutlinedButton.icon(
                          onPressed: castSession.showPanel,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Mostra login CAST'),
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
      key: ValueKey(row),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Autocomplete<Repository>(
              displayStringForOption: (repo) => repo.name,
              initialValue: TextEditingValue(text: row.repository?.name ?? ''),
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim().toLowerCase();
                if (query.isEmpty) return repositories;
                return repositories
                    .where((repo) => repo.name.toLowerCase().contains(query));
              },
              onSelected: (repo) => setState(() => row.repository = repo),
              fieldViewBuilder:
                  (context, textController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Repository',
                    hintText: 'Cerca repository…',
                  ),
                  onChanged: (text) {
                    // Clear the selected repository if the user edits the
                    // text away from a previously selected option, so a
                    // stale repository can't be searched by mistake.
                    if (row.repository != null &&
                        text != row.repository!.name) {
                      setState(() => row.repository = null);
                    }
                  },
                );
              },
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
              children: [
                ...BuildSearchService.environmentFolders.keys
                    .map((label) => _environmentTile(label, combo)),
                _castCard(combo),
              ],
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
    // Tile backgrounds are always light (green/amber/grey/red shade100-200),
    // so text/icon colors are fixed to dark regardless of the app theme to
    // guarantee readable contrast (see dark theme readability fix).
    const textColor = Colors.black87;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                const TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              icon,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 12, color: textColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Separate "CAST" tile shown alongside the four environment tiles: it
  /// lists, per environment where a matching build was actually found, the
  /// CAST Quality Rating of that build (A/B/C/D/F), instead of being nested
  /// inside the environment tile itself.
  Widget _castCard(_ComboSearch combo) {
    const textColor = Colors.black87;
    final lines = <Widget>[];
    for (final label in BuildSearchService.environmentFolders.keys) {
      final key = _castKey(combo, label);
      if (_castLoading.contains(key)) {
        lines.add(const Text('Verifica in corso…',
            style: TextStyle(fontSize: 12, color: textColor)));
      } else if (_castErrors.containsKey(key)) {
        lines.add(Text('Errore · ${_castErrors[key]}',
            style: const TextStyle(fontSize: 12, color: Colors.red)));
      } else if (_castRatings.containsKey(key)) {
        final rating = _castRatings[key];
        if (rating == null) {
          lines.add(const Text('Build non trovata su CAST',
              style: TextStyle(fontSize: 12, color: textColor)));
        } else {
          final normalized = rating.rating.toUpperCase();
          final color =
              normalized == 'A' ? Colors.green.shade800 : Colors.deepOrange;
          lines.add(Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '$label: $normalized',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ));
        }
      }
    }

    final body = lines.isEmpty
        ? Text(
            _castChecking
                ? 'Verifica in corso…'
                : 'Premi "Verifica CAST" per il rating qualità.',
            style: const TextStyle(fontSize: 12, color: textColor),
          )
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines);

    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_outlined, color: textColor, size: 18),
                SizedBox(width: 8),
                Text(
                  'CAST',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }
}
