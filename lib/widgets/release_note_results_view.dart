import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/release_note_models.dart';
import 'external_link.dart';

class ReleaseNoteResultsView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final grouped = {
      for (final category in ReleaseNoteCategory.values)
        category: <ReleaseNoteItem>[],
    };
    for (final item in result.items) {
      grouped[categoryOf(item)]!.add(item);
    }
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.warnings.isNotEmpty)
          Text('Verifica incompleta per: ${result.warnings.join(' · ')}',
              style: TextStyle(color: errorColor)),
        if (result.uninvolvedRepositories.isNotEmpty)
          Text(
              'Repository non coinvolti (branch assente): '
              '${result.uninvolvedRepositories.join(', ')}'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(
            avatar: const Icon(Icons.report_outlined, size: 18),
            label: Text('Mancanti: ${result.missingEntries.length}'),
          ),
          for (final category in ReleaseNoteCategory.values)
            Chip(
              avatar: Icon(_icon(category), size: 18),
              label: Text('${category.label}: ${grouped[category]!.length}'),
            ),
        ]),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            initiallyExpanded: result.missingEntries.isNotEmpty,
            leading: const Icon(Icons.report_outlined),
            title: const Text('Mancanti'),
            subtitle: const Text(
                'Stringhe della Release Note non trovate in nessuna PR o commit'),
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
        ),
        for (final category in ReleaseNoteCategory.values)
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
                    onMove: (target) => onMove(item, target),
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
  final ValueChanged<ReleaseNoteCategory> onMove;

  const _ItemTile({
    required this.item,
    required this.category,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final date = item.date;
    final pullRequest = item.pullRequest;
    final details = [
      item.repositoryName,
      if (pullRequest != null)
        '${pullRequest.summary.sourceBranch} → ${item.branch}'
      else
        item.branch,
      if (item.author.isNotEmpty) item.author,
      if (date != null) DateFormat('dd/MM/yyyy').format(date.toLocal()),
      if (item.matchedEntries.isNotEmpty) item.matchedEntries.join(', '),
    ].join(' · ');
    final webUrl = item.webUrl;
    return ExpansionTile(
      title: Row(children: [
        if (item.kind == ReleaseNoteItemKind.directCommit) ...[
          const Chip(
            label: Text('Commit diretto'),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(item.title)),
      ]),
      subtitle: Text(details),
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
        for (final commit in item.commits)
          ListTile(
            dense: true,
            leading: const Icon(Icons.commit, size: 18),
            title: Text((commit.comment ?? '').split('\n').first),
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
