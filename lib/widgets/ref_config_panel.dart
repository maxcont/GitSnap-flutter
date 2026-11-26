import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/azure_models.dart';
import '../providers/app_state.dart';
import '../services/ref_suggestion_service.dart';

class RefConfigPanel extends StatefulWidget {
  const RefConfigPanel({super.key});

  @override
  State<RefConfigPanel> createState() => _RefConfigPanelState();
}

class _RefConfigPanelState extends State<RefConfigPanel> {
  late TextEditingController _sourceValueController;
  late TextEditingController _targetValueController;
  final FocusNode _sourceFocusNode = FocusNode();
  final FocusNode _targetFocusNode = FocusNode();
  late RefType _sourceType;
  late RefType _targetType;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _sourceType = appState.sourceRef.type;
    _targetType = appState.targetRef.type;
    _sourceValueController = TextEditingController(text: appState.sourceRef.value)
      ..addListener(() => _onValueChanged(isSource: true));
    _targetValueController = TextEditingController(text: appState.targetRef.value)
      ..addListener(() => _onValueChanged(isSource: false));
    _sourceFocusNode.addListener(() => _onFocusChanged(isSource: true));
    _targetFocusNode.addListener(() => _onFocusChanged(isSource: false));
  }

  @override
  void dispose() {
    _sourceValueController.dispose();
    _targetValueController.dispose();
    _sourceFocusNode.dispose();
    _targetFocusNode.dispose();
    super.dispose();
  }

  // Covers both typing and picking a suggestion.
  void _onValueChanged({required bool isSource}) {
    final appState = context.read<AppState>();
    final text =
        (isSource ? _sourceValueController : _targetValueController).text;
    if (isSource && text != appState.sourceRef.value) {
      appState.setSourceRef(RefConfig(type: _sourceType, value: text));
    } else if (!isSource && text != appState.targetRef.value) {
      appState.setTargetRef(RefConfig(type: _targetType, value: text));
    }
  }

  void _onFocusChanged({required bool isSource}) {
    final focusNode = isSource ? _sourceFocusNode : _targetFocusNode;
    if (!focusNode.hasFocus) return;
    final appState = context.read<AppState>();
    final type = isSource ? _sourceType : _targetType;
    if (appState.refSuggestionsEnabled && _supportsSuggestions(type)) {
      appState.ensureRefSuggestions(type);
    }
  }

  static bool _supportsSuggestions(RefType type) =>
      type == RefType.branch || type == RefType.tagPattern;

  String _getRefTypeLabel(RefType type) {
    switch (type) {
      case RefType.branch:
        return 'Branch';
      case RefType.tagPattern:
        return 'Tag pattern';
      case RefType.commit:
        return 'Commit SHA';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Definizione ambienti SOURCE e TARGET',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Text('Suggerimenti branch/tag'),
                const SizedBox(width: 8),
                Switch(
                  value: appState.refSuggestionsEnabled,
                  onChanged: appState.setRefSuggestionsEnabled,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRefSection(appState, isSource: true),
            const SizedBox(height: 24),
            _buildRefSection(appState, isSource: false),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed:
                      appState.isLoading ? null : appState.runComparison,
                  icon: appState.isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.compare_arrows),
                  label: Text(
                    appState.isLoading
                        ? 'Confronto in corso...'
                        : 'Esegui confronto',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefSection(AppState appState, {required bool isSource}) {
    final label = isSource ? 'SOURCE' : 'TARGET';
    final colorScheme = Theme.of(context).colorScheme;
    final type = isSource ? _sourceType : _targetType;
    final controller =
        isSource ? _sourceValueController : _targetValueController;
    final focusNode = isSource ? _sourceFocusNode : _targetFocusNode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSource ? colorScheme.primary : colorScheme.secondary,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<RefType>(
                value: type,
                decoration: InputDecoration(
                  labelText: 'Tipo $label',
                  border: const OutlineInputBorder(),
                ),
                items: RefType.values.map((value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(_getRefTypeLabel(value)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    if (isSource) {
                      _sourceType = value;
                    } else {
                      _targetType = value;
                    }
                  });
                  final ref = RefConfig(type: value, value: controller.text);
                  if (isSource) {
                    appState.setSourceRef(ref);
                  } else {
                    appState.setTargetRef(ref);
                  }
                  if (focusNode.hasFocus) _onFocusChanged(isSource: isSource);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: appState.refSuggestionsEnabled &&
                      _supportsSuggestions(type)
                  ? _buildSuggestionField(
                      appState,
                      label: label,
                      type: type,
                      controller: controller,
                      focusNode: focusNode,
                    )
                  : TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Valore $label',
                        hintText: 'branch, tag pattern, o SHA',
                        border: const OutlineInputBorder(),
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuggestionField(
    AppState appState, {
    required String label,
    required RefType type,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    final suggestions = appState.refSuggestions(type);
    final isLoading = appState.isLoadingRefSuggestions(type);
    final entries = _entriesFor(type, suggestions);
    return DropdownMenu<String>(
      // Recreated only on manual refresh, so a stale selected index can't
      // rewrite the text; the first load must keep focus in the field.
      key: ValueKey('$label-$type-${_refreshCounts[type] ?? 0}'),
      controller: controller,
      focusNode: focusNode,
      expandedInsets: EdgeInsets.zero,
      requestFocusOnTap: true,
      enableFilter: true,
      menuHeight: 320,
      label: Text('Valore $label'),
      hintText: type == RefType.branch
          ? 'Cerca branch…'
          : 'Tag pattern, es. v1.*',
      helperText: _helperText(appState, type, suggestions, controller.text),
      errorText: appState.refSuggestionError(type),
      leadingIcon: IconButton(
        tooltip: 'Ricarica ${type == RefType.branch ? 'branch' : 'tag'}',
        onPressed: isLoading
            ? null
            : () {
                setState(() =>
                    _refreshCounts[type] = (_refreshCounts[type] ?? 0) + 1);
                appState.ensureRefSuggestions(type, force: true);
              },
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
      ),
      // Results never exceed the default entries length (both capped at
      // _maxVisibleSuggestions), which DropdownMenu relies on for its keys.
      filterCallback: (_, filter) {
        if (suggestions == null) return const [];
        return RefSuggestionService.filter(suggestions, filter,
                limit: _maxVisibleSuggestions)
            .map((suggestion) => entries.byName[suggestion.name]!)
            .toList();
      },
      dropdownMenuEntries: entries.initial,
    );
  }

  static const int _maxVisibleSuggestions = 50;
  final Map<RefType, int> _refreshCounts = {};
  final Map<RefType, _EntriesCache> _entriesCache = {};

  _EntriesCache _entriesFor(RefType type, RefSuggestions? suggestions) {
    final cached = _entriesCache[type];
    if (cached != null && identical(cached.suggestions, suggestions)) {
      return cached;
    }
    final all = suggestions == null
        ? const <RefSuggestion>[]
        : RefSuggestionService.filter(suggestions, '', limit: 1 << 30);
    final byName = {
      for (final suggestion in all)
        suggestion.name: _buildEntry(suggestion, suggestions!.repositoryCount),
    };
    return _entriesCache[type] = _EntriesCache(
      suggestions: suggestions,
      byName: byName,
      initial: byName.values.take(_maxVisibleSuggestions).toList(),
    );
  }

  DropdownMenuEntry<String> _buildEntry(
    RefSuggestion suggestion,
    int repositoryCount,
  ) {
    final complete = suggestion.repositoryCount == repositoryCount;
    return DropdownMenuEntry(
      value: suggestion.name,
      label: suggestion.name,
      trailingIcon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: complete ? Colors.green : Colors.amber,
          ),
        ),
        child: Text(
          '${suggestion.repositoryCount}/$repositoryCount repo',
          style: TextStyle(
            fontSize: 12,
            color: complete ? Colors.green : Colors.amber,
          ),
        ),
      ),
    );
  }

  String? _helperText(
    AppState appState,
    RefType type,
    RefSuggestions? suggestions,
    String value,
  ) {
    if (appState.isLoadingRefSuggestions(type)) {
      return 'Caricamento ${type == RefType.branch ? 'branch' : 'tag'}…';
    }
    if (suggestions == null) return 'Clicca nel campo per caricare i suggerimenti';
    final parts = <String>[];
    if (type == RefType.tagPattern && value.trim().isNotEmpty) {
      final preview = RefSuggestionService.tagPatternPreview(suggestions, value);
      parts.add('Il pattern trova ${preview.matchingTags} tag in '
          '${preview.matchingRepositories}/${suggestions.repositoryCount} repo');
    }
    if (suggestions.failedRepositories.isNotEmpty) {
      parts.add('${suggestions.failedRepositories.length} repo non letti: '
          '${suggestions.failedRepositories.join(', ')}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _EntriesCache {
  final RefSuggestions? suggestions;
  final Map<String, DropdownMenuEntry<String>> byName;
  final List<DropdownMenuEntry<String>> initial;

  _EntriesCache({
    required this.suggestions,
    required this.byName,
    required this.initial,
  });
}
