import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/release_models.dart';
import '../providers/app_state.dart';
import '../services/azure_devops_client.dart';

class PipelineVariablesTab extends StatefulWidget {
  const PipelineVariablesTab({super.key});

  @override
  State<PipelineVariablesTab> createState() => _PipelineVariablesTabState();
}

class _PipelineVariablesTabState extends State<PipelineVariablesTab> {
  List<ReleaseDefinitionInfo> _definitions = [];
  Map<String, ReleaseVariable> _variablesA = {};
  Map<String, ReleaseVariable> _variablesB = {};
  bool _loadingDefs = false;
  bool _loadingVars = false;
  String? _error;
  bool _useLatestA = true;
  bool _useLatestB = true;
  int? _revisionA;
  int? _revisionB;
  String? _folderPath;
  final TextEditingController _patternController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';
  bool _expandCarica = true;
  bool _expandVariabiliA = true;
  bool _expandVariabiliB = true;
  bool _expandConfronto = true;
  bool _varsPanelAFullHeight = false;
  bool _varsPanelBFullHeight = false;
  static const double _varsPanelFixedHeight = 500;

  /// "Tutte" = carica Sviluppo + Collaudo + Esercizio e unisci
  Future<void> _loadDefinitions(AppState appState, {String? path}) async {
    if (appState.client == null) {
      setState(() => _error = 'Carica prima i repository (configura e connetti).');
      return;
    }
    setState(() {
      _loadingDefs = true;
      _error = null;
      _definitions = [];
      _selectedDefA = null;
      _selectedDefB = null;
      _revisionsA = [];
      _revisionsB = [];
      _selectedRevA = null;
      _selectedRevB = null;
      _variablesA = {};
      _variablesB = {};
    });
    try {
      List<ReleaseDefinitionInfo> list;
      if (path == null || path.isEmpty) {
        final futures = [
          appState.client!.getReleaseDefinitions(path: r'\Sviluppo'),
          appState.client!.getReleaseDefinitions(path: r'\Collaudo'),
          appState.client!.getReleaseDefinitions(path: r'\Esercizio'),
        ];
        final results = await Future.wait(futures);
        list = results.expand((l) => l).toList();
        list.sort((a, b) {
          final c = a.name.compareTo(b.name);
          if (c != 0) return c;
          return (a.path ?? '').compareTo(b.path ?? '');
        });
      } else {
        list = await appState.client!.getReleaseDefinitions(path: path);
      }
      final pattern = _patternController.text.trim();
      if (pattern.isNotEmpty) {
        list = list.where((d) => _matchesNamePattern(d.name, d.path ?? '', d.id, pattern)).toList();
      }
      setState(() {
        _definitions = list;
        _loadingDefs = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingDefs = false;
      });
    }
  }

  ReleaseDefinitionInfo? _selectedDefA;
  ReleaseDefinitionInfo? _selectedDefB;
  List<int> _revisionsA = [];
  List<int> _revisionsB = [];
  int? _selectedRevA;
  int? _selectedRevB;

  Future<void> _loadRevisionsFor(AppState appState, int defId, bool forA) async {
    if (appState.client == null) return;
    setState(() => _error = null);
    try {
      final revs = await appState.client!.getReleaseDefinitionRevisions(defId);
      setState(() {
        if (forA) {
          _revisionsA = revs;
          _selectedRevA = revs.isNotEmpty ? revs.first : null;
        } else {
          _revisionsB = revs;
          _selectedRevB = revs.isNotEmpty ? revs.first : null;
        }
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _loadVariablesA(AppState appState, {bool latest = true, int? revision}) async {
    final def = _selectedDefA;
    if (def == null || appState.client == null) return;
    setState(() => _loadingVars = true);
    try {
      final vars = latest
          ? await appState.client!.getLatestVariables(def.id)
          : await appState.client!.getVariablesAtRevision(def.id, revision!);
      setState(() {
        _variablesA = vars;
        _useLatestA = latest;
        _revisionA = revision;
        _loadingVars = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingVars = false;
      });
    }
  }

  Future<void> _loadVariablesB(AppState appState, {bool latest = true, int? revision}) async {
    final def = _selectedDefB;
    if (def == null || appState.client == null) return;
    setState(() => _loadingVars = true);
    try {
      final vars = latest
          ? await appState.client!.getLatestVariables(def.id)
          : await appState.client!.getVariablesAtRevision(def.id, revision!);
      setState(() {
        _variablesB = vars;
        _useLatestB = latest;
        _revisionB = revision;
        _loadingVars = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingVars = false;
      });
    }
  }

  @override
  void dispose() {
    _patternController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  /// Match name/path/id against pattern; * = any characters (es. prog* = inizia con prog).
  static bool _matchesNamePattern(String name, String path, int id, String pattern) {
    final p = pattern.trim().toLowerCase();
    if (p.isEmpty) return true;
    final nameL = name.toLowerCase();
    final pathL = path.toLowerCase();
    final idStr = id.toString();
    if (!p.contains('*')) {
      return nameL.contains(p) || pathL.contains(p) || idStr.contains(p);
    }
    final regexStr = p
        .split('*')
        .map((s) => RegExp.escape(s))
        .join('.*');
    final regex = RegExp('^$regexStr\$', caseSensitive: false);
    return regex.hasMatch(nameL) || regex.hasMatch(pathL) || regex.hasMatch(idStr);
  }

  static Widget _pad(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: child,
    );
  }

  Widget _collapsibleCard({
    required BuildContext context,
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ],
      ),
    );
  }

  List<ReleaseDefinitionInfo> get _filteredDefinitions {
    if (_filterQuery.trim().isEmpty) return _definitions;
    final q = _filterQuery.trim().toLowerCase();
    return _definitions.where((d) {
      return d.name.toLowerCase().contains(q) ||
          (d.path ?? '').toLowerCase().contains(q) ||
          d.id.toString().contains(q);
    }).toList();
  }

  static List<VariableDiffEntry> _computeDiff(
    Map<String, ReleaseVariable> a,
    Map<String, ReleaseVariable> b,
  ) {
    final names = <String>{...a.keys, ...b.keys};
    return names.map((name) {
      final va = a[name];
      final vb = b[name];
      if (va == null) {
        return VariableDiffEntry(name: name, valueB: vb?.value, onlyInB: true);
      }
      if (vb == null) {
        return VariableDiffEntry(name: name, valueA: va.value, onlyInA: true);
      }
      return VariableDiffEntry(
        name: name,
        valueA: va.value,
        valueB: vb.value,
        different: va.value != vb.value,
      );
    }).toList()
      ..sort((x, y) => x.name.compareTo(y.name));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final hasClient = appState.client != null;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Utility pipeline – variabili di rilascio',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Carica le definizioni (Sviluppo, Collaudo, Esercizio o Tutte). Scegli Pipeline A e Pipeline B, carica le variabili e confrontale (es. ProgConf Sviluppo vs ProgConf Collaudo).',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _error = null),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _collapsibleCard(
                context: context,
                title: '1. Carica pipeline',
                expanded: _expandCarica,
                onToggle: () => setState(() => _expandCarica = !_expandCarica),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        DropdownButton<String?>(
                            value: _folderPath,
                            hint: const Text('Cartella'),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Tutte (Sviluppo + Collaudo + Esercizio)')),
                              DropdownMenuItem(value: r'\Sviluppo', child: Text('Sviluppo')),
                              DropdownMenuItem(value: r'\Collaudo', child: Text('Collaudo')),
                              DropdownMenuItem(value: r'\Esercizio', child: Text('Esercizio')),
                            ],
                            onChanged: hasClient
                                ? (v) {
                                    setState(() => _folderPath = v);
                                    _loadDefinitions(appState, path: v);
                                  }
                                : null,
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 180,
                            child: TextField(
                              controller: _patternController,
                              decoration: const InputDecoration(
                                hintText: 'Pattern (es. prog*)',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onSubmitted: (_) {
                                if (hasClient && !_loadingDefs) _loadDefinitions(appState, path: _folderPath);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: hasClient && !_loadingDefs
                                ? () => _loadDefinitions(appState, path: _folderPath)
                                : null,
                            icon: _loadingDefs
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh),
                            label: Text(_loadingDefs ? 'Caricamento…' : 'Carica pipeline'),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Pattern: usa * come jolly (prog* = nome che inizia con prog, *prog* = contiene prog). Lascia vuoto per tutte.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                              ),
                        ),
                      ),
                      if (_definitions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Pipeline caricate (${_definitions.length})',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _filterController,
                                decoration: InputDecoration(
                                  hintText: 'Filtra per nome, cartella o ID…',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onChanged: (v) => setState(() => _filterQuery = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final filtered = _filteredDefinitions;
                            final crossAxisCount = (constraints.maxWidth / 240).floor().clamp(2, 5);
                            return filtered.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child: Text(
                                        _filterQuery.trim().isEmpty
                                            ? 'Nessuna pipeline'
                                            : 'Nessun risultato per "$_filterQuery"',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                            ),
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      mainAxisExtent: 56,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 6,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, i) {
                                      final d = filtered[i];
                                      final isA = _selectedDefA?.id == d.id;
                                      final isB = _selectedDefB?.id == d.id;
                                      return Material(
                                        color: (isA || isB)
                                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35)
                                            : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      d.name,
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                    ),
                                                    Text(
                                                      '${d.path ?? "—"} · #${d.id}',
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              FilterChip(
                                                label: const Text('A'),
                                                selected: isA,
                                                onSelected: (v) {
                                                  setState(() {
                                                    _selectedDefA = v ? d : null;
                                                    _revisionsA = [];
                                                    _variablesA = {};
                                                  });
                                                  if (v) _loadRevisionsFor(appState, d.id, true);
                                                },
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              const SizedBox(width: 2),
                                              FilterChip(
                                                label: const Text('B'),
                                                selected: isB,
                                                onSelected: (v) {
                                                  setState(() {
                                                    _selectedDefB = v ? d : null;
                                                    _revisionsB = [];
                                                    _variablesB = {};
                                                  });
                                                  if (v) _loadRevisionsFor(appState, d.id, false);
                                                },
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              if (_selectedDefA != null || _selectedDefB != null) ...[
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final sideBySide = constraints.maxWidth >= 700;
                    final panelA = _collapsibleCard(
                      context: context,
                      title: '2. Variabili A${_selectedDefA != null ? " · ${_selectedDefA!.name} (${_selectedDefA!.path ?? ""})" : ""}',
                      expanded: _expandVariabiliA,
                      onToggle: () => setState(() => _expandVariabiliA = !_expandVariabiliA),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedDefA == null)
                            Text('Seleziona una pipeline come A dalla lista sopra.', style: Theme.of(context).textTheme.bodySmall),
                          if (_selectedDefA != null) ...[
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: hasClient && !_loadingVars ? () => _loadVariablesA(appState, latest: true) : null,
                                  icon: _loadingVars ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
                                  label: const Text('Carica A (ultime)'),
                                ),
                                if (_revisionsA.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  DropdownButton<int>(
                                    value: _selectedRevA,
                                    hint: const Text('Revisione A'),
                                    items: _revisionsA.take(30).map((r) => DropdownMenuItem(value: r, child: Text('$r'))).toList(),
                                    onChanged: (r) => setState(() => _selectedRevA = r),
                                  ),
                                  TextButton.icon(
                                    onPressed: hasClient && !_loadingVars && _selectedRevA != null
                                        ? () => _loadVariablesA(appState, latest: false, revision: _selectedRevA)
                                        : null,
                                    icon: const Icon(Icons.history),
                                    label: const Text('Carica revisione A'),
                                  ),
                                ],
                              ],
                            ),
                          if (_variablesA.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('Variabili A (${_variablesA.length})', style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: Icon(_varsPanelAFullHeight ? Icons.fullscreen_exit : Icons.fullscreen),
                                  tooltip: _varsPanelAFullHeight ? 'Riduci altezza' : 'Espandi a tutta l\'altezza',
                                  onPressed: () => setState(() => _varsPanelAFullHeight = !_varsPanelAFullHeight),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _varsPanelAFullHeight
                                ? Scrollbar(
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('Nome')),
                                            DataColumn(label: Text('Valore')),
                                            DataColumn(label: Text('Secret')),
                                          ],
                                          rows: _variablesA.entries.map((e) {
                                            return DataRow(
                                              cells: [
                                                DataCell(Text(e.key, style: const TextStyle(fontFamily: 'monospace'))),
                                                DataCell(SelectableText(e.value.displayValue)),
                                                DataCell(Text(e.value.isSecret ? 'Sì' : '')),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    height: _varsPanelFixedHeight,
                                    child: Scrollbar(
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columns: const [
                                              DataColumn(label: Text('Nome')),
                                              DataColumn(label: Text('Valore')),
                                              DataColumn(label: Text('Secret')),
                                            ],
                                            rows: _variablesA.entries.map((e) {
                                              return DataRow(
                                                cells: [
                                                  DataCell(Text(e.key, style: const TextStyle(fontFamily: 'monospace'))),
                                                  DataCell(SelectableText(e.value.displayValue)),
                                                  DataCell(Text(e.value.isSecret ? 'Sì' : '')),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ],
                        ],
                      ),
                    );
                    final panelB = _collapsibleCard(
                      context: context,
                      title: '3. Variabili B${_selectedDefB != null ? " · ${_selectedDefB!.name} (${_selectedDefB!.path ?? ""})" : ""}',
                      expanded: _expandVariabiliB,
                      onToggle: () => setState(() => _expandVariabiliB = !_expandVariabiliB),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedDefB == null)
                            Text('Seleziona una pipeline come B dalla lista sopra.', style: Theme.of(context).textTheme.bodySmall),
                          if (_selectedDefB != null) ...[
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: hasClient && !_loadingVars ? () => _loadVariablesB(appState, latest: true) : null,
                                  icon: _loadingVars ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
                                  label: const Text('Carica B (ultime)'),
                                ),
                                if (_revisionsB.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  DropdownButton<int>(
                                    value: _selectedRevB,
                                    hint: const Text('Revisione B'),
                                    items: _revisionsB.take(30).map((r) => DropdownMenuItem(value: r, child: Text('$r'))).toList(),
                                    onChanged: (r) => setState(() => _selectedRevB = r),
                                  ),
                                  TextButton.icon(
                                    onPressed: hasClient && !_loadingVars && _selectedRevB != null
                                        ? () => _loadVariablesB(appState, latest: false, revision: _selectedRevB)
                                        : null,
                                    icon: const Icon(Icons.history),
                                    label: const Text('Carica revisione B'),
                                  ),
                                ],
                              ],
                            ),
                          if (_variablesB.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('Variabili B (${_variablesB.length})', style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: Icon(_varsPanelBFullHeight ? Icons.fullscreen_exit : Icons.fullscreen),
                                  tooltip: _varsPanelBFullHeight ? 'Riduci altezza' : 'Espandi a tutta l\'altezza',
                                  onPressed: () => setState(() => _varsPanelBFullHeight = !_varsPanelBFullHeight),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _varsPanelBFullHeight
                                ? Scrollbar(
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('Nome')),
                                            DataColumn(label: Text('Valore')),
                                            DataColumn(label: Text('Secret')),
                                          ],
                                          rows: _variablesB.entries.map((e) {
                                            return DataRow(
                                              cells: [
                                                DataCell(Text(e.key, style: const TextStyle(fontFamily: 'monospace'))),
                                                DataCell(SelectableText(e.value.displayValue)),
                                                DataCell(Text(e.value.isSecret ? 'Sì' : '')),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    height: _varsPanelFixedHeight,
                                    child: Scrollbar(
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columns: const [
                                              DataColumn(label: Text('Nome')),
                                              DataColumn(label: Text('Valore')),
                                              DataColumn(label: Text('Secret')),
                                            ],
                                            rows: _variablesB.entries.map((e) {
                                              return DataRow(
                                                cells: [
                                                  DataCell(Text(e.key, style: const TextStyle(fontFamily: 'monospace'))),
                                                  DataCell(SelectableText(e.value.displayValue)),
                                                  DataCell(Text(e.value.isSecret ? 'Sì' : '')),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ],
                        ],
                      ),
                    );
                    if (sideBySide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: panelA),
                          const SizedBox(width: 16),
                          Expanded(child: panelB),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        panelA,
                        const SizedBox(height: 16),
                        panelB,
                      ],
                    );
                  },
                ),
              ],
              if (_variablesA.isNotEmpty && _variablesB.isNotEmpty) ...[
                const SizedBox(height: 16),
                _collapsibleCard(
                  context: context,
                  title: '4. Confronto A vs B',
                  expanded: _expandConfronto,
                  onToggle: () => setState(() => _expandConfronto = !_expandConfronto),
                  child: Builder(
                            builder: (context) {
                              final diff = _computeDiff(_variablesA, _variablesB);
                              final onlyA = diff.where((e) => e.onlyInA).length;
                              final onlyB = diff.where((e) => e.onlyInB).length;
                              final different = diff.where((e) => e.different).length;
                              final screenWidth = MediaQuery.of(context).size.width;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 16,
                                    children: [
                                      Chip(label: Text('Solo in A: $onlyA'), backgroundColor: Colors.blue.withOpacity(0.2)),
                                      Chip(label: Text('Solo in B: $onlyB'), backgroundColor: Colors.orange.withOpacity(0.2)),
                                      Chip(label: Text('Valori diversi: $different'), backgroundColor: Colors.amber.withOpacity(0.2)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        // Usa tutta la larghezza disponibile del pannello,
                                        // ma consenti comunque di allargare con lo scroll orizzontale se serve.
                                        minWidth: screenWidth - 96, // 16 padding esterno + 16 interno card * 2 circa
                                      ),
                                      child: Table(
                                      columnWidths: const <int, TableColumnWidth>{
                                        0: FlexColumnWidth(1),
                                        1: FlexColumnWidth(2),
                                        2: FlexColumnWidth(2),
                                        3: FlexColumnWidth(1),
                                      },
                                      border: TableBorder.all(
                                        color: Theme.of(context).dividerColor,
                                        width: 0.5,
                                      ),
                                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          ),
                                          children: [
                                            _pad(const Text('Nome', style: TextStyle(fontWeight: FontWeight.w600))),
                                            _pad(const Text('Valore A', style: TextStyle(fontWeight: FontWeight.w600))),
                                            _pad(const Text('Valore B', style: TextStyle(fontWeight: FontWeight.w600))),
                                            _pad(const Text('Stato', style: TextStyle(fontWeight: FontWeight.w600))),
                                          ],
                                        ),
                                        ...diff.map((e) {
                                          Color? rowColor;
                                          String state = '';
                                          if (e.onlyInA) {
                                            rowColor = Colors.blue.withOpacity(0.1);
                                            state = 'Solo A';
                                          } else if (e.onlyInB) {
                                            rowColor = Colors.orange.withOpacity(0.1);
                                            state = 'Solo B';
                                          } else if (e.different) {
                                            rowColor = Colors.amber.withOpacity(0.1);
                                            state = 'Diverso';
                                          } else {
                                            state = 'Uguale';
                                          }
                                          return TableRow(
                                            decoration: BoxDecoration(color: rowColor),
                                            children: [
                                              _pad(SelectableText(
                                                e.name,
                                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                                maxLines: 3,
                                              )),
                                              _pad(SelectableText(
                                                e.valueA ?? '—',
                                                maxLines: 4,
                                                style: const TextStyle(fontSize: 12),
                                              )),
                                              _pad(SelectableText(
                                                e.valueB ?? '—',
                                                maxLines: 4,
                                                style: const TextStyle(fontSize: 12),
                                              )),
                                              _pad(Text(state, style: const TextStyle(fontSize: 12))),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                  ),
                                ],
                              );
                            },
                          ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
