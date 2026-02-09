import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/azure_models.dart';
import '../providers/app_state.dart';

enum _RepoSortOrder { aToZ, zToA }

class RepositorySelector extends StatefulWidget {
  const RepositorySelector({super.key});

  @override
  State<RepositorySelector> createState() => _RepositorySelectorState();
}

class _RepositorySelectorState extends State<RepositorySelector> {
  bool _expanded = true;
  _RepoSortOrder _sortOrder = _RepoSortOrder.aToZ;

  List<Repository> _sortedRepositories(List<Repository> repos) {
    final list = List<Repository>.from(repos);
    list.sort((a, b) => _sortOrder == _RepoSortOrder.aToZ
        ? a.name.compareTo(b.name)
        : b.name.compareTo(a.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final sorted = _sortedRepositories(appState.repositories);

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                      const SizedBox(width: 8),
                      Text(
                        'Selezione Repository',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Text(
                        '${appState.repositories.length} repository · ${appState.selectedRepoIds.length} selezionati',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _sortOrder == _RepoSortOrder.aToZ ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _sortOrder = _sortOrder == _RepoSortOrder.aToZ
                                    ? _RepoSortOrder.zToA
                                    : _RepoSortOrder.aToZ;
                              });
                            },
                            tooltip: _sortOrder == _RepoSortOrder.aToZ ? 'Ordine A→Z (clic per Z→A)' : 'Ordine Z→A (clic per A→Z)',
                          ),
                          Text(
                            _sortOrder == _RepoSortOrder.aToZ ? 'Ordine A → Z' : 'Ordine Z → A',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: appState.selectAllRepos,
                            icon: const Icon(Icons.check_box, size: 20),
                            label: const Text('Seleziona tutto'),
                          ),
                          TextButton.icon(
                            onPressed: appState.deselectAllRepos,
                            icon: const Icon(Icons.check_box_outline_blank, size: 20),
                            label: const Text('Deseleziona tutto'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = (constraints.maxWidth / 260).floor().clamp(2, 5);
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisExtent: 52,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: sorted.length,
                            itemBuilder: (context, index) {
                              final repo = sorted[index];
                              final isSelected = appState.selectedRepoIds.contains(repo.id);

                              return Material(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
                                    : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: () => appState.toggleRepoSelection(repo.id),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (value) => appState.toggleRepoSelection(repo.id),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        const Icon(Icons.folder_outlined, size: 18),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                repo.name,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                              if (repo.defaultBranch != null)
                                                Text(
                                                  'Default: ${repo.defaultBranch}',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
