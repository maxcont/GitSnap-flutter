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
  bool _singlePanelFullWidth = false;
  Set<String> _selectedScopesA = {};
  Set<String> _selectedScopesB = {};
  static const double _varsPanelFixedHeight = 500;

  /// Cartelle frequenti nel menu (filtri rapidi, non limitano "Tutte").
  static const _suggestedReleaseFolders = [
    r'\Sviluppo',
    r'\Collaudo',
    r'\Pre-Esercizio',
    r'\Esercizio',
  ];

  /// "Tutte" = tutte le pipeline del progetto, senza filtro cartella.
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
      _selectedScopesA = {};
      _selectedScopesB = {};
      _singlePanelFullWidth = false;
    });
    try {
      List<ReleaseDefinitionInfo> list;
      list = await appState.client!.getAllReleaseDefinitions(
        path: (path == null || path.isEmpty) ? null : path,
      );
      list.sort((a, b) {
        final c = a.name.compareTo(b.name);
        if (c != 0) return c;
        return (a.path ?? '').compareTo(b.path ?? '');
      });
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
        _selectedScopesA = vars.values.map((v) => v.scope).toSet();
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
        _selectedScopesB = vars.values.map((v) => v.scope).toSet();
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

  static List<String> _sortedScopesFor(Map<String, ReleaseVariable> vars) {
    final scopes = vars.values.map((v) => v.scope).toSet().toList()
      ..sort((a, b) {
        if (a == ReleaseVariable.releaseScope) return -1;
        if (b == ReleaseVariable.releaseScope) return 1;
        return a.compareTo(b);
      });
    return scopes;
  }

  List<ReleaseVariable> _filteredVariables(
    Map<String, ReleaseVariable> vars,
    Set<String> selectedScopes,
  ) {
    final sorted = _sortedVariables(vars);
    final allScopes = _sortedScopesFor(vars);
    if (allScopes.isEmpty) return sorted;
    if (selectedScopes.length >= allScopes.length) return sorted;
    if (selectedScopes.isEmpty) return [];
    return sorted.where((v) => selectedScopes.contains(v.scope)).toList();
  }

  List<VariableDiffEntry> _filteredDiffForComparison(List<VariableDiffEntry> diff) {
    final scopesA = _sortedScopesFor(_variablesA).toSet();
    final scopesB = _sortedScopesFor(_variablesB).toSet();
    final visibleA = _selectedScopesA.length >= scopesA.length ? scopesA : _selectedScopesA;
    final visibleB = _selectedScopesB.length >= scopesB.length ? scopesB : _selectedScopesB;
    final visibleScopes = {...visibleA, ...visibleB};
    if (visibleScopes.isEmpty) return [];
    return diff.where((e) => visibleScopes.contains(e.scope)).toList();
  }

  String _scopeSelectorSummary(List<String> scopes, Set<String> selected) {
    if (scopes.isEmpty) return '—';
    if (selected.length >= scopes.length) return 'Tutti (${scopes.length})';
    if (selected.isEmpty) return 'Nessuno selezionato';
    if (selected.length == 1) return selected.first;
    return '${selected.length} di ${scopes.length} selezionati';
  }

  Future<void> _openScopeSelector({
    required BuildContext context,
    required List<String> scopes,
    required Set<String> selectedScopes,
    required ValueChanged<Set<String>> onChanged,
  }) async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _ScopeSelectDialog(
        scopes: scopes,
        initialSelected: selectedScopes.isEmpty ? scopes.toSet() : selectedScopes,
      ),
    );
    if (result != null) onChanged(result);
  }

  Widget _scopeMultiSelect({
    required BuildContext context,
    required List<String> scopes,
    required Set<String> selectedScopes,
    required ValueChanged<Set<String>> onChanged,
  }) {
    if (scopes.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Filtra per ambito',
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: InkWell(
          onTap: () => _openScopeSelector(
            context: context,
            scopes: scopes,
            selectedScopes: selectedScopes,
            onChanged: onChanged,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _scopeSelectorSummary(scopes, selectedScopes),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  bool get _isSinglePipelineView =>
      (_selectedDefA != null) != (_selectedDefB != null);

  Widget _variablesToolbar(
    BuildContext context, {
    required String countLabel,
    required bool fullHeight,
    required VoidCallback onToggleHeight,
    bool showWidthToggle = false,
    bool fullWidth = false,
    VoidCallback? onToggleWidth,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(countLabel, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (showWidthToggle && onToggleWidth != null)
          IconButton(
            icon: Icon(fullWidth ? Icons.view_column : Icons.width_wide),
            tooltip: fullWidth ? 'Ripristina larghezza' : 'Espandi in larghezza',
            onPressed: onToggleWidth,
          ),
        IconButton(
          icon: Icon(fullHeight ? Icons.fullscreen_exit : Icons.fullscreen),
          tooltip: fullHeight ? 'Riduci altezza' : 'Espandi a tutta l\'altezza',
          onPressed: onToggleHeight,
        ),
      ],
    );
  }

  static List<DataColumn> _variableTableColumnsFor(double? width) {
    if (width == null) {
      return const [
        DataColumn(label: Text('Nome')),
        DataColumn(label: Text('Valore')),
        DataColumn(label: Text('Ambito')),
      ];
    }
    return [
      DataColumn(
        label: const Text('Nome'),
        columnWidth: FixedColumnWidth(width * 0.20),
      ),
      DataColumn(
        label: const Text('Valore'),
        columnWidth: FixedColumnWidth(width * 0.55),
      ),
      DataColumn(
        label: const Text('Ambito'),
        columnWidth: FixedColumnWidth(width * 0.25),
      ),
    ];
  }

  Widget _variablesTable(
    List<ReleaseVariable> variables, {
    required bool fullHeight,
    bool fullWidth = false,
  }) {
    Widget buildTable(double? width) {
      final table = DataTable(
        columnSpacing: fullWidth ? 20 : 56,
        horizontalMargin: fullWidth ? 12 : 24,
        columns: _variableTableColumnsFor(width),
        rows: _variableRows(variables),
      );
      if (width != null) {
        return ConstrainedBox(
          constraints: BoxConstraints(minWidth: width),
          child: table,
        );
      }
      return table;
    }

    Widget buildScroller(Widget table) {
      return _ScrolledVariablesTable(
        fullHeight: fullHeight,
        height: _varsPanelFixedHeight,
        child: table,
      );
    }

    if (fullWidth) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite ? constraints.maxWidth : null;
          return buildScroller(buildTable(width));
        },
      );
    }
    return buildScroller(buildTable(null));
  }

  static List<ReleaseVariable> _sortedVariables(Map<String, ReleaseVariable> vars) {
    final list = vars.values.toList()
      ..sort((a, b) {
        final byName = a.name.compareTo(b.name);
        if (byName != 0) return byName;
        return a.scope.compareTo(b.scope);
      });
    return list;
  }

  static List<VariableDiffEntry> _computeDiff(
    Map<String, ReleaseVariable> a,
    Map<String, ReleaseVariable> b,
  ) {
    final keys = <String>{...a.keys, ...b.keys};
    return keys.map((key) {
      final va = a[key];
      final vb = b[key];
      final name = va?.name ?? vb!.name;
      final scope = va?.scope ?? vb!.scope;
      if (va == null) {
        return VariableDiffEntry(name: name, scope: scope, valueB: vb?.value, onlyInB: true);
      }
      if (vb == null) {
        return VariableDiffEntry(name: name, scope: scope, valueA: va.value, onlyInA: true);
      }
      return VariableDiffEntry(
        name: name,
        scope: scope,
        valueA: va.value,
        valueB: vb.value,
        different: va.value != vb.value,
      );
    }).toList()
      ..sort((x, y) {
        final byName = x.name.compareTo(y.name);
        if (byName != 0) return byName;
        return x.scope.compareTo(y.scope);
      });
  }

  String _variablesCountLabel(
    String label,
    Map<String, ReleaseVariable> vars,
    Set<String> selectedScopes,
  ) {
    final filtered = _filteredVariables(vars, selectedScopes).length;
    final total = vars.length;
    final allScopes = _sortedScopesFor(vars);
    if (selectedScopes.length >= allScopes.length || filtered == total) {
      return '$label ($total)';
    }
    return '$label ($filtered di $total)';
  }

  static List<DataRow> _variableRows(List<ReleaseVariable> variables) {
    return variables.map((v) {
      return DataRow(
        cells: [
          DataCell(Text(v.name, style: const TextStyle(fontFamily: 'monospace'))),
          DataCell(SelectableText(v.displayValue)),
          DataCell(Text(v.scope)),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final hasClient = appState.client != null;
        final wideSinglePanel = _isSinglePipelineView && _singlePanelFullWidth;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            wideSinglePanel ? 8 : 16,
            16,
            wideSinglePanel ? 8 : 16,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Utility pipeline – variabili di rilascio',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Carica le pipeline di release. "Tutte le cartelle" include ogni cartella del progetto; le voci Sviluppo/Collaudo/… sono filtri rapidi. Scegli A e B e confronta le variabili.',
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
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Tutte le cartelle'),
                              ),
                              ..._suggestedReleaseFolders.map(
                                (folder) => DropdownMenuItem(
                                  value: folder,
                                  child: Text(folder.replaceFirst(r'\', '')),
                                ),
                              ),
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
                                                    _selectedScopesA = {};
                                                    if (!_isSinglePipelineView) _singlePanelFullWidth = false;
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
                                                    _selectedScopesB = {};
                                                    if (!_isSinglePipelineView) _singlePanelFullWidth = false;
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
                            _scopeMultiSelect(
                              context: context,
                              scopes: _sortedScopesFor(_variablesA),
                              selectedScopes: _selectedScopesA,
                              onChanged: (scopes) => setState(() => _selectedScopesA = scopes),
                            ),
                            const SizedBox(height: 12),
                            _variablesToolbar(
                              context,
                              countLabel: _variablesCountLabel('Variabili A', _variablesA, _selectedScopesA),
                              fullHeight: _varsPanelAFullHeight,
                              onToggleHeight: () => setState(() => _varsPanelAFullHeight = !_varsPanelAFullHeight),
                              showWidthToggle: _isSinglePipelineView && _selectedDefA != null,
                              fullWidth: _singlePanelFullWidth,
                              onToggleWidth: () => setState(() => _singlePanelFullWidth = !_singlePanelFullWidth),
                            ),
                            const SizedBox(height: 6),
                            _variablesTable(
                              _filteredVariables(_variablesA, _selectedScopesA),
                              fullHeight: _varsPanelAFullHeight,
                              fullWidth: _isSinglePipelineView && _singlePanelFullWidth,
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
                            _scopeMultiSelect(
                              context: context,
                              scopes: _sortedScopesFor(_variablesB),
                              selectedScopes: _selectedScopesB,
                              onChanged: (scopes) => setState(() => _selectedScopesB = scopes),
                            ),
                            const SizedBox(height: 12),
                            _variablesToolbar(
                              context,
                              countLabel: _variablesCountLabel('Variabili B', _variablesB, _selectedScopesB),
                              fullHeight: _varsPanelBFullHeight,
                              onToggleHeight: () => setState(() => _varsPanelBFullHeight = !_varsPanelBFullHeight),
                              showWidthToggle: _isSinglePipelineView && _selectedDefB != null,
                              fullWidth: _singlePanelFullWidth,
                              onToggleWidth: () => setState(() => _singlePanelFullWidth = !_singlePanelFullWidth),
                            ),
                            const SizedBox(height: 6),
                            _variablesTable(
                              _filteredVariables(_variablesB, _selectedScopesB),
                              fullHeight: _varsPanelBFullHeight,
                              fullWidth: _isSinglePipelineView && _singlePanelFullWidth,
                            ),
                            ],
                          ],
                        ],
                      ),
                    );
                    final onlyA = _selectedDefA != null && _selectedDefB == null;
                    final onlyB = _selectedDefB != null && _selectedDefA == null;
                    if (onlyA) {
                      return panelA;
                    }
                    if (onlyB) {
                      return panelB;
                    }
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
                              final diff = _filteredDiffForComparison(_computeDiff(_variablesA, _variablesB));
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
                                        3: FlexColumnWidth(1.5),
                                        4: FlexColumnWidth(1),
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
                                            _pad(const Text('Ambito', style: TextStyle(fontWeight: FontWeight.w600))),
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
                                              _pad(SelectableText(
                                                e.scope,
                                                maxLines: 3,
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

class _ScrolledVariablesTable extends StatefulWidget {
  const _ScrolledVariablesTable({
    required this.child,
    required this.fullHeight,
    required this.height,
  });

  final Widget child;
  final bool fullHeight;
  final double height;

  @override
  State<_ScrolledVariablesTable> createState() => _ScrolledVariablesTableState();
}

class _ScrolledVariablesTableState extends State<_ScrolledVariablesTable> {
  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _verticalController = ScrollController();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Widget _horizontalScroll() {
    return SingleChildScrollView(
      controller: _horizontalController,
      scrollDirection: Axis.horizontal,
      child: widget.child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullHeight) {
      return Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        child: _horizontalScroll(),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalController,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
            child: _horizontalScroll(),
          ),
        ),
      ),
    );
  }
}

class _ScopeSelectDialog extends StatefulWidget {
  const _ScopeSelectDialog({
    required this.scopes,
    required this.initialSelected,
  });

  final List<String> scopes;
  final Set<String> initialSelected;

  @override
  State<_ScopeSelectDialog> createState() => _ScopeSelectDialogState();
}

class _ScopeSelectDialogState extends State<_ScopeSelectDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelected};
  }

  void _toggleAll(bool selectAll) {
    setState(() {
      _selected = selectAll ? widget.scopes.toSet() : {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.length >= widget.scopes.length;
    final noneSelected = _selected.isEmpty;
    final bool? selectAllValue = allSelected
        ? true
        : noneSelected
            ? false
            : null;
    final listHeight = (widget.scopes.length * 48.0).clamp(96.0, 320.0);

    return AlertDialog(
      title: const Text('Seleziona ambiti'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Seleziona tutti', style: TextStyle(fontWeight: FontWeight.w600)),
              value: selectAllValue,
              tristate: true,
              onChanged: (value) {
                if (value == true) {
                  _toggleAll(true);
                } else {
                  _toggleAll(false);
                }
              },
            ),
            const Divider(height: 1),
            SizedBox(
              height: listHeight,
              child: ListView(
                children: widget.scopes.map((scope) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(scope),
                    value: _selected.contains(scope),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selected.add(scope);
                        } else {
                          _selected.remove(scope);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Applica'),
        ),
      ],
    );
  }
}
