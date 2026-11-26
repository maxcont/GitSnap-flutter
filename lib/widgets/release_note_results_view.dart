import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/release_note_models.dart';
import '../services/release_note_check_service.dart';
import 'external_link.dart';

class ReleaseNoteResultsView extends StatefulWidget {
  final ReleaseNoteCheckResult result;
  final ReleaseNoteCategory Function(ReleaseNoteItem item) categoryOf;
  final void Function(ReleaseNoteItem item, ReleaseNoteCategory category)
      onMove;

  const ReleaseNoteResultsView({
    super.key,
    required this.result,
    required this.categoryOf,
    required this.onMove,
  });

  @override
  State<ReleaseNoteResultsView> createState() => _ReleaseNoteResultsViewState();
}

class _ReleaseNoteResultsViewState extends State<ReleaseNoteResultsView> {
  late Set<String> selectedRepositories;
  final Set<ReleaseNoteCategory> selectedCategories =
      ReleaseNoteCategory.values.toSet();

  @override
  void initState() {
    super.initState();
    selectedRepositories = widget.result.repositories.keys.toSet();
  }

  @override
  void didUpdateWidget(covariant ReleaseNoteResultsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.result, widget.result)) {
      selectedRepositories = widget.result.repositories.keys.toSet();
      selectedCategories
        ..clear()
        ..addAll(ReleaseNoteCategory.values);
    }
  }

  void _showRepositories(
      List<MapEntry<String, String>> repositories, Map<String, Color> colors) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Chiudi filtri repository',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 8,
            child: SizedBox(
              width: 420,
              height: double.infinity,
              child: SafeArea(
                child: StatefulBuilder(
                  builder: (context, updatePanel) {
                    void changeSelection(void Function() change) {
                      if (!mounted) return;
                      setState(change);
                      updatePanel(() {});
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                          child: Row(children: [
                            Expanded(
                              child: Text('Filtri repository',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                            ),
                            IconButton(
                              tooltip: 'Chiudi filtri repository',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Wrap(children: [
                            TextButton(
                              onPressed: () => changeSelection(() {
                                selectedRepositories
                                  ..clear()
                                  ..addAll(
                                      repositories.map((repo) => repo.key));
                              }),
                              child: const Text('Seleziona tutto'),
                            ),
                            TextButton(
                              onPressed: () => changeSelection(
                                  () => selectedRepositories.clear()),
                              child: const Text('Deseleziona tutto'),
                            ),
                          ]),
                        ),
                        const Divider(),
                        Expanded(
                          child: ListView.builder(
                            key: const ValueKey('release-note-repositories'),
                            itemCount: repositories.length,
                            itemBuilder: (context, index) {
                              final repo = repositories[index];
                              final count = widget.result.items
                                  .where(
                                      (item) => item.repositoryId == repo.key)
                                  .length;
                              return CheckboxListTile(
                                value: selectedRepositories.contains(repo.key),
                                onChanged: (selected) => changeSelection(() {
                                  if (selected == true) {
                                    selectedRepositories.add(repo.key);
                                  } else {
                                    selectedRepositories.remove(repo.key);
                                  }
                                }),
                                secondary: Icon(Icons.circle,
                                    size: 16, color: colors[repo.key]),
                                title: Text('${repo.value} ($count)'),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final repositories = result.repositories.entries.toList()
      ..sort((a, b) {
        final byName = a.value.compareTo(b.value);
        return byName != 0 ? byName : a.key.compareTo(b.key);
      });
    final colors = <String, Color>{
      for (var i = 0; i < repositories.length; i++)
        repositories[i].key: HSLColor.fromAHSL(
          1,
          (i * 137.508) % 360,
          0.75,
          Theme.of(context).brightness == Brightness.dark ? 0.7 : 0.35,
        ).toColor(),
    };
    final globalGroups = {
      for (final category in ReleaseNoteCategory.values)
        category: <ReleaseNoteItem>[],
    };
    final grouped = {
      for (final category in ReleaseNoteCategory.values)
        category: <ReleaseNoteItem>[],
    };
    for (final item in result.items) {
      final category = widget.categoryOf(item);
      globalGroups[category]!.add(item);
      if (selectedRepositories.contains(item.repositoryId)) {
        grouped[category]!.add(item);
      }
    }
    final visibleItems = result.items
        .where((item) => selectedRepositories.contains(item.repositoryId));
    final visibleEntries =
        visibleItems.expand((item) => item.matchedEntries).toSet();
    final missingVisible = result.entries
        .where((entry) => !visibleEntries.contains(entry))
        .toList();
    final globalEntries =
        result.items.expand((item) => item.matchedEntries).toSet();
    final foundElsewhere =
        missingVisible.where(globalEntries.contains).toList();
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.warnings.isNotEmpty)
          Text('Verifica incompleta per: ${result.warnings.join(' · ')}',
              style: TextStyle(color: errorColor)),
        if (result.uninvolvedRepositories.isNotEmpty)
          Text('Repository non coinvolti (branch assente): '
              '${result.uninvolvedRepositories.join(', ')}'),
        const SizedBox(height: 12),
        Text('Riepilogo generale',
            style: Theme.of(context).textTheme.titleMedium),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(label: Text('Repository coinvolti: ${repositories.length}')),
          Chip(label: Text('Elementi: ${result.items.length}')),
          Chip(
              label:
                  Text('Generale · Mancanti: ${result.missingEntries.length}')),
          for (final category in ReleaseNoteCategory.values)
            Chip(
                label: Text(
                    'Generale · ${category.label}: ${globalGroups[category]!.length}')),
        ]),
        ExpansionTile(
          title: const Text('Mancanti globali'),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final entry in result.missingEntries)
                  Chip(label: Text(entry)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showRepositories(repositories, colors),
          icon: const Icon(Icons.filter_list),
          label: Text(
              'Repository ${selectedRepositories.length}/${repositories.length}'),
        ),
        const SizedBox(height: 12),
        Text('Repository selezionati',
            style: Theme.of(context).textTheme.titleMedium),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(
            avatar: const Icon(Icons.report_outlined, size: 18),
            label: Text('Mancanti nei selezionati: ${missingVisible.length}'),
          ),
          Chip(
              label:
                  Text('Trovate solo negli altri: ${foundElsewhere.length}')),
          for (final category in ReleaseNoteCategory.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: selectedCategories.contains(category)
                      ? 'Nascondi ${category.label}'
                      : 'Mostra ${category.label}',
                  child: FilterChip(
                    avatar: Icon(_icon(category), size: 18),
                    selected: selectedCategories.contains(category),
                    label:
                        Text('${category.label}: ${grouped[category]!.length}'),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        selectedCategories.add(category);
                      } else {
                        selectedCategories.remove(category);
                      }
                    }),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    selectedCategories
                      ..clear()
                      ..add(category);
                  }),
                  child: Tooltip(
                    message: 'Solo ${category.label}',
                    child: const Text('Solo'),
                  ),
                ),
              ],
            ),
        ]),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            initiallyExpanded: missingVisible.isNotEmpty,
            leading: const Icon(Icons.report_outlined),
            title: const Text('Mancanti nei repository selezionati'),
            subtitle: const Text(
                'Stringhe non trovate nelle PR o nei commit visibili'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final entry in missingVisible) Chip(label: Text(entry)),
                ]),
              ),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            initiallyExpanded: foundElsewhere.isNotEmpty,
            title: const Text('Trovate solo negli altri repository'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final entry in foundElsewhere) Chip(label: Text(entry)),
                ]),
              ),
            ],
          ),
        ),
        for (final category in ReleaseNoteCategory.values)
          if (selectedCategories.contains(category))
            Card(
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: Icon(_icon(category)),
                title: Text(category.label),
                children: [
                  for (final item in grouped[category]!)
                    _ItemTile(
                      item: item,
                      category: category,
                      color: colors[item.repositoryId]!,
                      onMove: (target) => widget.onMove(item, target),
                    ),
                ],
              ),
            ),
      ],
    );
  }

  static IconData _icon(ReleaseNoteCategory category) => switch (category) {
        ReleaseNoteCategory.ok => Icons.check_circle_outline,
        ReleaseNoteCategory.outOfScope => Icons.block,
        ReleaseNoteCategory.toVerify => Icons.help_outline,
      };
}

class _ItemTile extends StatelessWidget {
  final ReleaseNoteItem item;
  final ReleaseNoteCategory category;
  final Color color;
  final ValueChanged<ReleaseNoteCategory> onMove;

  const _ItemTile({
    required this.item,
    required this.category,
    required this.color,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final date = item.date;
    final pullRequest = item.pullRequest;
    final otherDetails = [
      if (item.author.isNotEmpty) item.author,
      if (date != null) DateFormat('dd/MM/yyyy').format(date.toLocal()),
      if (item.matchedEntries.isNotEmpty) item.matchedEntries.join(', '),
    ];
    final scheme = Theme.of(context).colorScheme;
    final highlightStyle = TextStyle(
      color: scheme.onSecondaryContainer,
      backgroundColor: scheme.secondaryContainer,
      fontWeight: FontWeight.bold,
    );
    List<InlineSpan> highlight(String text) =>
        _highlight(text, item.matchedEntries, highlightStyle);
    final webUrl = item.webUrl;
    return ExpansionTile(
      leading: Icon(Icons.circle, size: 16, color: color),
      title: Row(children: [
        if (item.kind == ReleaseNoteItemKind.directCommit) ...[
          const Chip(
            label: Text('Commit diretto'),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text.rich(TextSpan(children: [
            if (pullRequest != null)
              TextSpan(text: 'PR ${pullRequest.summary.id} · '),
            ...highlight(pullRequest?.summary.title ?? item.title),
          ])),
        ),
      ]),
      subtitle: Text.rich(TextSpan(children: [
        TextSpan(text: '${item.repositoryName} · '),
        if (pullRequest != null) ...[
          ...highlight(pullRequest.summary.sourceBranch),
          TextSpan(text: ' → ${item.branch}'),
        ] else
          TextSpan(text: item.branch),
        if (otherDetails.isNotEmpty)
          TextSpan(text: ' · ${otherDetails.join(' · ')}'),
      ])),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (category != item.automaticCategory)
          const Tooltip(
            message: 'Spostato manualmente',
            child: Icon(Icons.edit_note),
          ),
        if (webUrl != null)
          IconButton(
            tooltip: 'Apri in Azure DevOps',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openExternalLink(context, webUrl),
          ),
        PopupMenuButton<ReleaseNoteCategory>(
          tooltip: 'Sposta in…',
          icon: const Icon(Icons.drive_file_move_outline),
          onSelected: onMove,
          itemBuilder: (_) => [
            for (final target in ReleaseNoteCategory.values)
              if (target != category)
                PopupMenuItem(value: target, child: Text(target.label)),
          ],
        ),
      ]),
      children: [
        if (pullRequest?.description?.isNotEmpty == true)
          ListTile(
            dense: true,
            leading: const Icon(Icons.description_outlined, size: 18),
            title: Text.rich(
                TextSpan(children: highlight(pullRequest!.description!))),
          ),
        for (final commit in item.commits)
          ListTile(
            dense: true,
            leading: const Icon(Icons.commit, size: 18),
            title:
                Text.rich(TextSpan(children: highlight(commit.comment ?? ''))),
            subtitle: Text([
              commit.commitId.length > 8
                  ? commit.commitId.substring(0, 8)
                  : commit.commitId,
              if (commit.author?.name != null) commit.author!.name,
            ].join(' · ')),
          ),
      ],
    );
  }
}

List<InlineSpan> _highlight(
    String text, Set<String> entries, TextStyle highlightStyle) {
  final matches = [
    for (final entry in entries)
      ...ReleaseNoteCheckService.entryPattern(entry).allMatches(text),
  ]..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.end.compareTo(b.end);
    });
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (var i = 0; i < matches.length; i++) {
    final start = matches[i].start;
    var end = matches[i].end;
    while (i + 1 < matches.length && matches[i + 1].start <= end) {
      i++;
      if (matches[i].end > end) end = matches[i].end;
    }
    if (start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, start)));
    }
    spans
        .add(TextSpan(text: text.substring(start, end), style: highlightStyle));
    cursor = end;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return spans;
}
