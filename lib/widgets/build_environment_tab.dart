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
                        child:
                            Text(repo.name, overflow: TextOverflow.ellipsis),
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
              Expanded(
                  child: Text(text, style: const TextStyle(fontSize: 12))),
            ],
          ),
        ],
      ),
    );
  }
}
