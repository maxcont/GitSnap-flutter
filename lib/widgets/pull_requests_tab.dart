import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/azure_models.dart';
import '../models/commit_search_models.dart';
import '../models/pull_request_models.dart';
import '../providers/app_state.dart';
import '../services/pull_request_filter_service.dart';

class PullRequestsTab extends StatefulWidget {
  const PullRequestsTab({super.key});

  @override
  State<PullRequestsTab> createState() => _PullRequestsTabState();
}

class _PullRequestsTabState extends State<PullRequestsTab> {
  final _queryController = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final state = context.read<AppState>();
        if (!state.isLoadingPullRequests && state.allPullRequests.isEmpty) {
          state.loadPullRequests();
        }
      });
    }
  }

  void _update(PullRequestFilter filter) =>
      context.read<AppState>().setPullRequestFilter(filter);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final filter = state.pullRequestFilter;
        final pullRequests = state.filteredPullRequests;
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Panoramica PR'),
                  Tab(text: 'Ricerca commit'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pull request',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text(
                            'Panoramica delle pull request in tutti i repository del progetto configurato.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          _FilterPanel(
                            filter: filter,
                            state: state,
                            queryController: _queryController,
                            onChanged: _update,
                          ),
                          const SizedBox(height: 16),
                          _StatusCards(
                            filter: filter,
                            counts: state.pullRequestStatusCounts,
                            onToggle: (status) {
                              final statuses = {...filter.statuses};
                              statuses.contains(status)
                                  ? statuses.remove(status)
                                  : statuses.add(status);
                              _update(filter.copyWith(statuses: statuses));
                            },
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final summary = _RepositorySummary(
                                pullRequests: state.allPullRequests,
                                filter: filter,
                                currentUser: state.currentPullRequestUser,
                                onSelect: (repositoryId) => _update(filter
                                    .copyWith(repositoryIds: {repositoryId})),
                              );
                              final activity = _RecentPullRequestActivity(
                                pullRequests: state.allPullRequests,
                              );
                              if (constraints.maxWidth < 1050) {
                                return Column(
                                  children: [
                                    summary,
                                    const SizedBox(height: 16),
                                    activity,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 6, child: summary),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 4, child: activity),
                                ],
                              );
                            },
                          ),
                          if (state.pullRequestRepositoryErrors.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _RepositoryWarning(
                                errors: state.pullRequestRepositoryErrors),
                          ],
                          const SizedBox(height: 16),
                          if (state.isLoadingPullRequests)
                            const Center(
                                child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ))
                          else if (state.errorMessage != null &&
                              state.allPullRequests.isEmpty)
                            _LoadError(message: state.errorMessage!)
                          else
                            _PullRequestTable(pullRequests: pullRequests),
                        ],
                      ),
                    ),
                    _CommitSearchView(state: state),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final PullRequestFilter filter;
  final AppState state;
  final TextEditingController queryController;
  final ValueChanged<PullRequestFilter> onChanged;

  const _FilterPanel({
    required this.filter,
    required this.state,
    required this.queryController,
    required this.onChanged,
  });

  Future<void> _selectDate(BuildContext context, bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? filter.startDate : filter.endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected == null) return;
    onChanged(start
        ? filter.copyWith(startDate: selected)
        : filter.copyWith(endDate: selected));
  }

  @override
  Widget build(BuildContext context) {
    final repos = state.repositories;
    final authors = state.allPullRequests
        .map((item) => item.author)
        .where((author) => author.uniqueName != null)
        .fold<Map<String, PullRequestIdentity>>({}, (result, author) {
          result[author.uniqueName!] = author;
          return result;
        })
        .values
        .toList();
    final branches = state.allPullRequests
        .map((item) => item.targetBranch)
        .toSet()
        .toList()
      ..sort();
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              label: const Text('Personali'),
              selected: filter.personalOnly,
              onSelected: (value) {
                if (value && state.currentPullRequestUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Impossibile identificare l’utente autenticato.'),
                    ),
                  );
                  return;
                }
                onChanged(filter.copyWith(personalOnly: value));
              },
            ),
            DropdownButton<String>(
              value: filter.authorUniqueName,
              hint: const Text('Autore'),
              items: [
                const DropdownMenuItem(
                    value: '', child: Text('Tutti gli autori')),
                ...authors.map((author) => DropdownMenuItem(
                      value: author.uniqueName,
                      child: Text(author.displayName),
                    )),
              ],
              onChanged: (value) => onChanged(
                value == null || value.isEmpty
                    ? filter.copyWith(clearAuthor: true)
                    : filter.copyWith(authorUniqueName: value),
              ),
            ),
            DropdownButton<String>(
              value: filter.targetBranch,
              hint: const Text('Branch destinazione'),
              items: [
                const DropdownMenuItem(
                    value: '', child: Text('Tutti i branch')),
                ...branches.map((branch) =>
                    DropdownMenuItem(value: branch, child: Text(branch))),
              ],
              onChanged: (value) => onChanged(
                value == null || value.isEmpty
                    ? filter.copyWith(clearTargetBranch: true)
                    : filter.copyWith(targetBranch: value),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text('Da ${dateFormat.format(filter.startDate)}'),
              onPressed: () => _selectDate(context, true),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text('A ${dateFormat.format(filter.endDate)}'),
              onPressed: () => _selectDate(context, false),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: queryController,
                decoration: const InputDecoration(
                  labelText: 'Cerca ID o titolo',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => onChanged(filter.copyWith(query: value)),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_outlined),
              label: Text(filter.repositoryIds.isEmpty
                  ? 'Tutti i repository'
                  : '${filter.repositoryIds.length} repository'),
              onPressed: () async {
                final selected = await _selectRepositories(
                  context,
                  repos,
                  filter.repositoryIds,
                );
                if (selected != null) {
                  onChanged(filter.copyWith(repositoryIds: selected));
                }
              },
            ),
            TextButton(
              onPressed: () {
                queryController.clear();
                onChanged(PullRequestFilter.defaults());
              },
              child: const Text('Reimposta'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Aggiorna'),
              onPressed:
                  state.isLoadingPullRequests ? null : state.loadPullRequests,
            ),
          ],
        ),
      ),
    );
  }

  Future<Set<String>?> _selectRepositories(
    BuildContext context,
    List<Repository> repositories,
    Set<String> currentSelection,
  ) {
    return showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        var selected = {...currentSelection};
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Seleziona repository'),
            content: SizedBox(
              width: 440,
              child: ListView(
                shrinkWrap: true,
                children: repositories
                    .map(
                      (repository) => CheckboxListTile(
                        value: selected.contains(repository.id),
                        title: Text(repository.name),
                        onChanged: (checked) => setDialogState(() {
                          if (checked == true) {
                            selected.add(repository.id);
                          } else {
                            selected.remove(repository.id);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => setDialogState(selected.clear),
                child: const Text('Tutti'),
              ),
              TextButton(
                onPressed: () => setDialogState(
                  () => selected =
                      repositories.map((repository) => repository.id).toSet(),
                ),
                child: const Text('Seleziona tutti'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const Text('Applica'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RepositorySummary extends StatelessWidget {
  final List<PullRequestSummary> pullRequests;
  final PullRequestFilter filter;
  final PullRequestIdentity? currentUser;
  final ValueChanged<String> onSelect;

  const _RepositorySummary({
    required this.pullRequests,
    required this.filter,
    required this.currentUser,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final repositoryNames = <String, String>{
      for (final pullRequest in pullRequests)
        pullRequest.repositoryId: pullRequest.repositoryName,
    };
    if (repositoryNames.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Riepilogo per repository',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Repository')),
                  DataColumn(numeric: true, label: Text('Aperte')),
                  DataColumn(numeric: true, label: Text('Bozze')),
                  DataColumn(numeric: true, label: Text('Completate')),
                  DataColumn(numeric: true, label: Text('Abbandonate')),
                  DataColumn(numeric: true, label: Text('Totale')),
                ],
                rows: repositoryNames.entries.map((entry) {
                  final counts = PullRequestFilterService.statusCounts(
                    pullRequests: pullRequests,
                    filter: filter.copyWith(repositoryIds: {entry.key}),
                    currentUser: currentUser,
                  );
                  final total =
                      counts.values.fold<int>(0, (sum, count) => sum + count);
                  final hasActiveWork =
                      (counts[PullRequestStatus.active] ?? 0) > 0 ||
                          (counts[PullRequestStatus.draft] ?? 0) > 0;
                  return DataRow(
                    color: WidgetStatePropertyAll(
                      hasActiveWork
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                    ),
                    cells: [
                      DataCell(TextButton(
                        onPressed: () => onSelect(entry.key),
                        child: Text(entry.value),
                      )),
                      DataCell(_countText(counts[PullRequestStatus.active] ?? 0,
                          emphasize: true)),
                      DataCell(_countText(counts[PullRequestStatus.draft] ?? 0,
                          emphasize: true)),
                      DataCell(
                          _countText(counts[PullRequestStatus.completed] ?? 0)),
                      DataCell(
                          _countText(counts[PullRequestStatus.abandoned] ?? 0)),
                      DataCell(_countText(total)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countText(int count, {bool emphasize = false}) {
    return Text(
      '$count',
      style: TextStyle(
        color: emphasize && count > 0 ? Colors.lightBlueAccent : null,
        fontWeight:
            emphasize && count > 0 ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _RecentPullRequestActivity extends StatelessWidget {
  final List<PullRequestSummary> pullRequests;

  const _RecentPullRequestActivity({required this.pullRequests});

  @override
  Widget build(BuildContext context) {
    final recent = [...pullRequests]..sort((left, right) {
        final leftDate = left.closedAt ?? left.updatedAt ?? left.createdAt;
        final rightDate = right.closedAt ?? right.updatedAt ?? right.createdAt;
        return rightDate.compareTo(leftDate);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ultime attività',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Ultimi aggiornamenti in tutti i repository',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nessuna attività disponibile.'),
              )
            else
              ...recent.take(6).map((pullRequest) {
                final event = _activityFor(pullRequest);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    child: Icon(event.icon, size: 18),
                  ),
                  title: Text(
                    '#${pullRequest.id} ${pullRequest.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${event.label} · ${pullRequest.repositoryName} · '
                    '${DateFormat('dd/MM HH:mm').format(event.date.toLocal())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  _PullRequestActivity _activityFor(PullRequestSummary pullRequest) {
    if (pullRequest.closedAt != null) {
      return _PullRequestActivity(
        label: pullRequest.status == PullRequestStatus.completed
            ? 'PR completata'
            : 'PR abbandonata',
        date: pullRequest.closedAt!,
        icon: pullRequest.status == PullRequestStatus.completed
            ? Icons.task_alt
            : Icons.cancel_outlined,
      );
    }
    final updatedAt = pullRequest.updatedAt;
    if (updatedAt == null ||
        updatedAt.isAtSameMomentAs(pullRequest.createdAt)) {
      return _PullRequestActivity(
        label: 'PR aperta',
        date: pullRequest.createdAt,
        icon: Icons.add_circle_outline,
      );
    }
    return _PullRequestActivity(
      label: 'PR aggiornata',
      date: updatedAt,
      icon: Icons.update,
    );
  }
}

class _PullRequestActivity {
  final String label;
  final DateTime date;
  final IconData icon;

  const _PullRequestActivity({
    required this.label,
    required this.date,
    required this.icon,
  });
}

class _StatusCards extends StatelessWidget {
  final PullRequestFilter filter;
  final Map<PullRequestStatus, int> counts;
  final ValueChanged<PullRequestStatus> onToggle;

  const _StatusCards(
      {required this.filter, required this.counts, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: PullRequestStatus.values.map((status) {
        final selected = filter.statuses.contains(status);
        return InkWell(
          onTap: () => onToggle(status),
          borderRadius: BorderRadius.circular(12),
          child: Card(
            color: selected
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
            child: SizedBox(
              width: 160,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_statusLabel(status)),
                      const SizedBox(height: 8),
                      Text('${counts[status] ?? 0}',
                          style: Theme.of(context).textTheme.headlineMedium),
                    ]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PullRequestTable extends StatefulWidget {
  final List<PullRequestSummary> pullRequests;

  const _PullRequestTable({required this.pullRequests});

  @override
  State<_PullRequestTable> createState() => _PullRequestTableState();
}

class _PullRequestTableState extends State<_PullRequestTable> {
  int _sortColumnIndex = 6;
  bool _sortAscending = false;

  void _sort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  List<PullRequestSummary> get _sortedPullRequests {
    final pullRequests = [...widget.pullRequests];
    final selectors = <Comparable<dynamic> Function(PullRequestSummary)>[
      (item) => _statusLabel(item.status),
      (item) => item.id,
      (item) => item.repositoryName.toLowerCase(),
      (item) => '${item.sourceBranch} ${item.targetBranch}'.toLowerCase(),
      (item) => item.author.displayName.toLowerCase(),
      (item) => item.createdAt,
      (item) => item.updatedAt ?? item.createdAt,
      (item) => item.closedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    ];
    final selector = selectors[_sortColumnIndex];
    pullRequests.sort((left, right) {
      final result = selector(left).compareTo(selector(right));
      return _sortAscending ? result : -result;
    });
    return pullRequests;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pullRequests.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('Nessuna pull request corrisponde ai filtri selezionati.'),
      ));
    }
    final format = DateFormat('dd/MM/yyyy HH:mm');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
        columns: [
          DataColumn(
              label: const Text('Stato'), onSort: (index, _) => _sort(index)),
          DataColumn(
              numeric: true,
              label: const Text('PR'),
              onSort: (index, _) => _sort(index)),
          DataColumn(
              label: const Text('Repository'),
              onSort: (index, _) => _sort(index)),
          DataColumn(
              label: const Text('Branch'), onSort: (index, _) => _sort(index)),
          DataColumn(
              label: const Text('Autore'), onSort: (index, _) => _sort(index)),
          DataColumn(
              label: const Text('Creata'), onSort: (index, _) => _sort(index)),
          DataColumn(
              label: const Text('Aggiornata'),
              onSort: (index, _) => _sort(index)),
          DataColumn(
              label: const Text('Completata'),
              onSort: (index, _) => _sort(index)),
          const DataColumn(label: Text('')),
        ],
        rows: _sortedPullRequests
            .map((pullRequest) => DataRow(
                  cells: [
                    DataCell(_StatusBadge(status: pullRequest.status)),
                    DataCell(SizedBox(
                      width: 260,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => _showDetails(context, pullRequest),
                        child: Text(
                          '#${pullRequest.id} ${pullRequest.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )),
                    DataCell(Text(pullRequest.repositoryName)),
                    DataCell(Text(
                        '${pullRequest.sourceBranch} → ${pullRequest.targetBranch}')),
                    DataCell(Text(pullRequest.author.displayName)),
                    DataCell(
                        Text(format.format(pullRequest.createdAt.toLocal()))),
                    DataCell(Text(format.format(
                        (pullRequest.updatedAt ?? pullRequest.createdAt)
                            .toLocal()))),
                    DataCell(Text(pullRequest.closedAt == null
                        ? '—'
                        : format.format(pullRequest.closedAt!.toLocal()))),
                    DataCell(IconButton(
                      tooltip: 'Apri in Azure DevOps',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openLink(context, pullRequest),
                    )),
                  ],
                ))
            .toList(),
      ),
    );
  }

  static Future<void> _openLink(
      BuildContext context, PullRequestSummary pullRequest) async {
    final launched = pullRequest.webUrl.isNotEmpty &&
        await launchUrl(Uri.parse(pullRequest.webUrl),
            mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Impossibile aprire la pull request #${pullRequest.id}.')),
      );
    }
  }

  static Future<void> _showDetails(
      BuildContext context, PullRequestSummary pullRequest) {
    return showDialog<void>(
      context: context,
      builder: (_) => _PullRequestDetailsDialog(pullRequest: pullRequest),
    );
  }
}

class _PullRequestDetailsDialog extends StatelessWidget {
  final PullRequestSummary pullRequest;
  const _PullRequestDetailsDialog({required this.pullRequest});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('#${pullRequest.id} ${pullRequest.title}'),
      content: SizedBox(
        width: 720,
        child: FutureBuilder<PullRequestDetails>(
          future: context.read<AppState>().loadPullRequestDetails(pullRequest),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Text(
                  'Impossibile caricare il dettaglio: ${snapshot.error}');
            }
            final detail = snapshot.requireData;
            final metrics = detail.metrics ?? const PullRequestMetrics();
            final reviewers = detail.reviewers
                .map((item) => '${item.displayName} (${item.vote})')
                .join(', ');
            return SingleChildScrollView(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail.description?.isNotEmpty == true
                    ? detail.description!
                    : 'Nessuna descrizione.'),
                const SizedBox(height: 16),
                Text('${detail.sourceBranch} → ${detail.targetBranch}'),
                Text(
                    'Merge: ${detail.mergeStatus}${detail.policyStatus == null ? '' : ' · Policy: ${detail.policyStatus}'}'),
                const SizedBox(height: 12),
                Text('Reviewer: ${reviewers.isEmpty ? 'Nessuno' : reviewers}'),
                const Divider(),
                Wrap(spacing: 20, runSpacing: 8, children: [
                  Text('Commit: ${metrics.commitCount}'),
                  Text('File modificati: ${metrics.changedFileCount}'),
                  Text('Discussioni: ${metrics.threadCount}'),
                  Text('Commenti: ${metrics.commentCount}'),
                ]),
              ],
            ));
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi')),
        FilledButton.icon(
          onPressed: () =>
              _PullRequestTableState._openLink(context, pullRequest),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Apri in Azure DevOps'),
        ),
      ],
    );
  }
}

class _RepositoryWarning extends StatelessWidget {
  final Map<String, String> errors;
  const _RepositoryWarning({required this.errors});
  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
              'Impossibile caricare ${errors.length} repository: ${errors.keys.join(', ')}.'),
        ),
      );
}

class _LoadError extends StatelessWidget {
  final String message;
  const _LoadError({required this.message});
  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message),
      ));
}

String _statusLabel(PullRequestStatus status) {
  switch (status) {
    case PullRequestStatus.active:
      return 'PR aperte';
    case PullRequestStatus.draft:
      return 'Bozze';
    case PullRequestStatus.completed:
      return 'Completate';
    case PullRequestStatus.abandoned:
      return 'Abbandonate';
  }
}

class _StatusBadge extends StatelessWidget {
  final PullRequestStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (status) {
      PullRequestStatus.active => (Icons.radio_button_checked, Colors.green),
      PullRequestStatus.draft => (Icons.edit_note, Colors.lightBlue),
      PullRequestStatus.completed => (Icons.task_alt, Colors.teal),
      PullRequestStatus.abandoned => (Icons.cancel_outlined, scheme.error),
    };
    return Chip(
      avatar: Icon(icon, size: 17, color: color),
      label: Text(_statusLabel(status)),
      side: BorderSide(color: color.withValues(alpha: 0.65)),
      backgroundColor: color.withValues(alpha: 0.13),
    );
  }
}

class _CommitSearchView extends StatefulWidget {
  final AppState state;

  const _CommitSearchView({required this.state});

  @override
  State<_CommitSearchView> createState() => _CommitSearchViewState();
}

class _CommitSearchViewState extends State<_CommitSearchView> {
  final _controller = TextEditingController();
  late DateTime _from;
  late DateTime _to;
  Set<String> _branches = {'develop', 'master'};
  Set<String> _branchPrefixes = {};
  String? _customBranchPattern;
  Set<String> _repositoryIds = {};
  bool _allBranches = false;
  bool _showAdvanced = false;
  bool _expandFirstResult = true;
  int _resultPanelStateVersion = 0;

  @override
  void initState() {
    super.initState();
    _to = DateTime.now();
    _from = DateTime(_to.year - 1, _to.month, _to.day);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final grouped = <String, List<CommitSearchResult>>{};
    for (final result in state.commitSearchResults) {
      grouped.putIfAbsent(result.repositoryName, () => []).add(result);
    }
    final selectedRepositoryCount = _repositoryIds.isEmpty
        ? state.repositories.length
        : _repositoryIds.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ricerca commit',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text(
            'Cerca una RF, un incidente o una stringa nei messaggi di commit.'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'RF333, INC12345 o testo commit',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  FilterChip(
                    label: const Text('develop'),
                    selected: _branches.contains('develop'),
                    onSelected: _allBranches
                        ? null
                        : (selected) => setState(() {
                              selected
                                  ? _branches.add('develop')
                                  : _branches.remove('develop');
                            }),
                  ),
                  FilterChip(
                    label: const Text('master'),
                    selected: _branches.contains('master'),
                    onSelected: _allBranches
                        ? null
                        : (selected) => setState(() {
                              selected
                                  ? _branches.add('master')
                                  : _branches.remove('master');
                            }),
                  ),
                  FilterChip(
                    label: const Text('bugfix*'),
                    selected: _branchPrefixes.contains('bugfix'),
                    onSelected: _allBranches
                        ? null
                        : (selected) => setState(() {
                              selected
                                  ? _branchPrefixes.add('bugfix')
                                  : _branchPrefixes.remove('bugfix');
                            }),
                  ),
                  FilterChip(
                    label: const Text('feature*'),
                    selected: _branchPrefixes.contains('feature'),
                    onSelected: _allBranches
                        ? null
                        : (selected) => setState(() {
                              selected
                                  ? _branchPrefixes.add('feature')
                                  : _branchPrefixes.remove('feature');
                            }),
                  ),
                  InputChip(
                    label:
                        Text(_customBranchPattern ?? 'Branch personalizzata'),
                    selected: _customBranchPattern != null,
                    onPressed: _allBranches ? null : _editCustomBranchPattern,
                    onDeleted: _customBranchPattern == null
                        ? null
                        : () => setState(() => _customBranchPattern = null),
                  ),
                  FilterChip(
                    label: const Text('Tutte le branch'),
                    selected: _allBranches,
                    onSelected: (selected) =>
                        setState(() => _allBranches = selected),
                  ),
                  OutlinedButton(
                    onPressed: () => _pickDate(true),
                    child: Text('Da ${DateFormat('dd/MM/yyyy').format(_from)}'),
                  ),
                  OutlinedButton(
                    onPressed: () => _pickDate(false),
                    child: Text('A ${DateFormat('dd/MM/yyyy').format(_to)}'),
                  ),
                  FilledButton.icon(
                    onPressed: state.isSearchingCommits ? null : _search,
                    icon: const Icon(Icons.search),
                    label: const Text('Cerca'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _showAdvanced = !_showAdvanced),
                    icon: Icon(
                      _showAdvanced ? Icons.expand_less : Icons.tune_outlined,
                    ),
                    label: Text(_showAdvanced
                        ? 'Nascondi dettagli'
                        : 'Dettagli avanzati'),
                  ),
                  if (_showAdvanced)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder_outlined),
                      label: Text(_repositoryIds.isEmpty
                          ? 'Tutti i repository'
                          : '$selectedRepositoryCount repository'),
                      onPressed: () async {
                        final selection = await _selectSearchRepositories(
                          state.repositories,
                        );
                        if (selection != null) {
                          setState(() => _repositoryIds = selection);
                        }
                      },
                    ),
                ]),
          ),
        ),
        const SizedBox(height: 16),
        if (state.isSearchingCommits)
          _CommitSearchProgress(
            phase: state.commitSearchPhase,
            completed: state.commitSearchCompleted,
            total: state.commitSearchTotal,
          )
        else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SearchMetricCard('Repository selezionati',
                  selectedRepositoryCount, Icons.folder_outlined),
              _SearchMetricCard('Repository analizzati',
                  selectedRepositoryCount, Icons.manage_search),
              _SearchMetricCard('Repository con match', grouped.length,
                  Icons.rule_folder_outlined),
              _SearchMetricCard('Commit trovati',
                  state.commitSearchResults.length, Icons.commit),
            ],
          ),
          if (state.commitSearchError != null) ...[
            const SizedBox(height: 12),
            Text(state.commitSearchError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          if (grouped.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _expandFirstResult = false;
                  _resultPanelStateVersion++;
                }),
                icon: const Icon(Icons.unfold_less),
                label: const Text('Comprimi tutti'),
              ),
            ),
          if (grouped.isNotEmpty) const SizedBox(height: 8),
          ...grouped.entries.toList().asMap().entries.map((groupEntry) {
            final index = groupEntry.key;
            final entry = groupEntry.value;
            return Card(
              child: ExpansionTile(
                key: ValueKey(
                  '${entry.key}-$_resultPanelStateVersion',
                ),
                initiallyExpanded: _expandFirstResult && index == 0,
                title: Text(
                  '${entry.key} · ${entry.value.length} commit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                children: entry.value
                    .map(
                      (item) => ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(
                          '${item.commitId.substring(0, item.commitId.length > 8 ? 8 : item.commitId.length)} · ${item.message}',
                        ),
                        subtitle: Text(
                          '${item.author} · ${item.date == null ? 'Data non disponibile' : DateFormat('dd/MM/yyyy HH:mm').format(item.date!.toLocal())} · ${item.branches.join(', ')}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: item.webUrl.isEmpty
                              ? null
                              : () => launchUrl(Uri.parse(item.webUrl),
                                  mode: LaunchMode.externalApplication),
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          }),
        ],
      ]),
    );
  }

  Future<void> _pickDate(bool from) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null)
      setState(() => from ? _from = selected : _to = selected);
  }

  Future<Set<String>?> _selectSearchRepositories(
      List<Repository> repositories) {
    return showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        var selected = {..._repositoryIds};
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Repository da analizzare'),
            content: SizedBox(
              width: 440,
              child: ListView(
                shrinkWrap: true,
                children: repositories
                    .map((repository) => CheckboxListTile(
                          value: selected.contains(repository.id),
                          title: Text(repository.name),
                          onChanged: (checked) => setDialogState(() {
                            checked == true
                                ? selected.add(repository.id)
                                : selected.remove(repository.id);
                          }),
                        ))
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => setDialogState(selected.clear),
                child: const Text('Tutti'),
              ),
              TextButton(
                onPressed: () => setDialogState(
                  () => selected =
                      repositories.map((repository) => repository.id).toSet(),
                ),
                child: const Text('Seleziona tutti'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const Text('Applica'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _search() {
    setState(() {
      _expandFirstResult = true;
      _resultPanelStateVersion++;
    });
    widget.state.searchCommits(
      text: _controller.text,
      repositoryIds: _repositoryIds,
      branchNames: _branches,
      branchPrefixes: _branchPrefixes,
      branchPattern: _customBranchPattern,
      allBranches: _allBranches,
      from: _from,
      to: _to,
    );
  }

  Future<void> _editCustomBranchPattern() async {
    final controller = TextEditingController(text: _customBranchPattern);
    final pattern = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Branch personalizzata'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Pattern branch',
            hintText: '*testolibero*',
            helperText: 'Usa * come carattere jolly.',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Applica'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pattern == null) return;
    final trimmedPattern = pattern.trim();
    setState(() {
      _customBranchPattern = trimmedPattern.isEmpty ? null : trimmedPattern;
    });
  }
}

class _CommitSearchProgress extends StatelessWidget {
  final String phase;
  final int completed;
  final int total;

  const _CommitSearchProgress({
    required this.phase,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final hasTotal = total > 0;
    final progress = hasTotal ? completed / total : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    phase,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              hasTotal
                  ? '$completed di $total ${phase.startsWith('Lettura') ? 'repository' : 'branch'} analizzati'
                  : 'Preparazione delle richieste verso Azure DevOps...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchMetricCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _SearchMetricCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 175,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text('$value', style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
