import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/commit_search_models.dart';
import '../models/pull_request_models.dart';

class CommitSearchTile extends StatelessWidget {
  final CommitSearchResult result;
  final Future<List<PullRequestSummary>> Function() loadHistory;

  const CommitSearchTile({
    super.key,
    required this.result,
    required this.loadHistory,
  });

  @override
  Widget build(BuildContext context) {
    final groups = _BranchGroups(result.branches);
    final shortId = result.commitId.length > 8
        ? result.commitId.substring(0, 8)
        : result.commitId;
    final metadata = '${result.author} · ${_formatDate(result.date)}';
    final branches = [
      ...groups.principals,
      ...groups.features,
      ...groups.bugfixes,
      ...groups.others,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HashBadge(shortId),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                LayoutBuilder(builder: (context, constraints) {
                  final branchList = _InlineBranches(
                    key: ValueKey('${result.repositoryId}:${result.commitId}'),
                    branches: branches,
                    principals: groups.principals.toSet(),
                  );
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(metadata,
                            style: Theme.of(context).textTheme.bodySmall),
                        branchList,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: constraints.maxWidth * .4),
                        child: Text(metadata,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: branchList),
                    ],
                  );
                }),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dettagli commit',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _CommitDetails(
                result: result,
                groups: groups,
                loadHistory: loadHistory,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Apri commit',
            icon: const Icon(Icons.open_in_new),
            onPressed: result.webUrl.isEmpty
                ? null
                : () => _openUrl(context, result.webUrl),
          ),
        ],
      ),
    );
  }
}

class _HashBadge extends StatelessWidget {
  final String hash;

  const _HashBadge(this.hash);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        hash,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontFamily: 'monospace',
            ),
      ),
    );
  }
}

class _InlineBranches extends StatefulWidget {
  final List<String> branches;
  final Set<String> principals;

  const _InlineBranches({
    super.key,
    required this.branches,
    required this.principals,
  });

  @override
  State<_InlineBranches> createState() => _InlineBranchesState();
}

class _InlineBranchesState extends State<_InlineBranches> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.branches.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodySmall!;
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 6.0;
      final buttonText = TextPainter(
        text: TextSpan(
          text: '+${widget.branches.length}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final buttonWidth = buttonText.width + 8 + gap;
      buttonText.dispose();
      final widths = widget.branches.map((name) {
        final painter = TextPainter(
          text: TextSpan(text: name, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final width = painter.width + 16;
        painter.dispose();
        return width;
      }).toList();
      final total =
          widths.fold<double>(0, (a, b) => a + b) + gap * (widths.length - 1);
      var visible = widget.branches.length;
      if (total > constraints.maxWidth) {
        visible = 0;
        var used = 0.0;
        final available =
            (constraints.maxWidth - buttonWidth).clamp(0.0, double.infinity);
        for (final width in widths) {
          final next = used + (visible == 0 ? 0 : gap) + width;
          if (next > available) break;
          used = next;
          visible++;
        }
      }
      final overflow = visible < widget.branches.length;
      final shown = _expanded ? widget.branches : widget.branches.take(visible);
      return Wrap(
        spacing: gap,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final branch in shown)
            Tooltip(
              message: branch,
              child: Container(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.principals.contains(branch)
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(branch,
                    style: style, overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
            ),
          if (overflow || _expanded)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Tooltip(
                message:
                    _expanded ? 'Comprimi branch' : 'Mostra tutti i branch',
                child: Text(_expanded
                    ? 'Meno'
                    : '+${widget.branches.length - visible}'),
              ),
            ),
        ],
      );
    });
  }
}

String _formatDate(DateTime? date) => date == null
    ? 'Data non disponibile'
    : DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final opened =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossibile aprire il collegamento.')),
    );
  }
}

class _BranchGroups {
  final List<String> principals = [];
  final List<String> features = [];
  final List<String> bugfixes = [];
  final List<String> others = [];

  _BranchGroups(Set<String> branches) {
    final sorted = branches.toList()..sort();
    for (final branch in sorted) {
      final name = branch.toLowerCase();
      if (name == 'master' || name == 'develop') {
        principals.add(branch);
      } else if (name.startsWith('feature')) {
        features.add(branch);
      } else if (name.startsWith('bugfix')) {
        bugfixes.add(branch);
      } else {
        others.add(branch);
      }
    }
  }
}

class _CommitDetails extends StatefulWidget {
  final CommitSearchResult result;
  final _BranchGroups groups;
  final Future<List<PullRequestSummary>> Function() loadHistory;

  const _CommitDetails({
    required this.result,
    required this.groups,
    required this.loadHistory,
  });

  @override
  State<_CommitDetails> createState() => _CommitDetailsState();
}

class _CommitDetailsState extends State<_CommitDetails> {
  List<PullRequestSummary>? _history;
  Object? _historyError;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final groups = widget.groups;
    return AlertDialog(
      title: const Text('Dettaglio commit'),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.message,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.commit,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      result.commitId,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copia hash',
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    onPressed: () async {
                      try {
                        await Clipboard.setData(
                            ClipboardData(text: result.commitId));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hash copiato')),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Impossibile copiare l’hash: $error')),
                        );
                      }
                    },
                  ),
                ],
              ),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _DetailMetadata(Icons.person_outline, result.author),
                  _DetailMetadata(Icons.schedule,
                      'Data autore: ${_formatDate(result.date)}'),
                ],
              ),
              const SizedBox(height: 16),
              _DetailSection(
                icon: Icons.call_split,
                title: 'Branch analizzati',
                children: [
                  const Text('Origine non determinabile'),
                  if (_history != null &&
                      _history!.isNotEmpty &&
                      _history!.first.closedAt != null) ...[
                    const SizedBox(height: 8),
                    if (_firstSources.length == 1)
                      Text(
                        'Sorgente della prima PR trovata: ${_firstSources.single}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      )
                    else
                      const Text(
                        'Più PR trovate alla stessa data: sorgente non univoca.',
                      ),
                    const Text(
                      'La prima PR trovata non prova il branch di origine del commit.',
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Presente nei branch analizzati. La ricerca può essere parziale: '
                    'dipende dai filtri, dagli errori e dal limite dei risultati.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  _branchSection('Principali', groups.principals),
                  _branchSection('Feature', groups.features),
                  _branchSection('Bugfix', groups.bugfixes),
                  _branchSection('Altri', groups.others),
                ],
              ),
              const SizedBox(height: 12),
              _DetailSection(
                icon: Icons.timeline,
                title: 'Percorso',
                children: [
                  Text(
                    'La cronologia può essere incompleta: push diretti, squash, '
                    'rebase o cherry-pick possono non essere riconosciuti.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    )
                  else if (_historyError != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Impossibile ricostruire il percorso: $_historyError',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                        TextButton(
                          onPressed: _loadHistory,
                          child: const Text('Riprova'),
                        ),
                      ],
                    )
                  else if (_history == null)
                    FilledButton.icon(
                      onPressed: _loadHistory,
                      icon: const Icon(Icons.manage_search),
                      label: const Text('Ricostruisci percorso'),
                    )
                  else if (_history!.isEmpty)
                    const Text('Nessuna pull request collegata trovata.')
                  else
                    ..._history!.map(
                      (event) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.merge,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text('#${event.id} ${event.title}'),
                        subtitle: Text(
                          '${event.sourceBranch} → ${event.targetBranch}\n'
                          'Completata: ${_formatDate(event.closedAt)}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Apri pull request',
                          icon: const Icon(Icons.open_in_new),
                          onPressed: event.webUrl.isEmpty
                              ? null
                              : () => _openUrl(context, event.webUrl),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (result.webUrl.isNotEmpty)
          TextButton(
            onPressed: () => _openUrl(context, result.webUrl),
            child: const Text('Apri commit'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
      ],
    );
  }

  Set<String> get _firstSources {
    final events = _history!;
    final firstDate = events.first.closedAt!;
    return events
        .where((event) => event.closedAt == firstDate)
        .map((event) => event.sourceBranch)
        .toSet();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _historyError = null;
    });
    try {
      final events = [...await widget.loadHistory()];
      events.sort((a, b) {
        if (a.closedAt == null) return b.closedAt == null ? 0 : 1;
        if (b.closedAt == null) return -1;
        return a.closedAt!.compareTo(b.closedAt!);
      });
      if (!mounted) return;
      setState(() => _history = events);
    } catch (error) {
      if (!mounted) return;
      setState(() => _historyError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _branchSection(String label, List<String> branches) {
    if (branches.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      title: Text('$label (${branches.length})'),
      children: [
        for (final branch in branches)
          ListTile(
            dense: true,
            title: Text(branch),
          ),
      ],
    );
  }
}

class _DetailMetadata extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailMetadata(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: style?.color),
        const SizedBox(width: 5),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _DetailSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child:
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
