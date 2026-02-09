import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class RepositorySelector extends StatelessWidget {
  const RepositorySelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selezione Repository',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: appState.selectAllRepos,
                          icon: const Icon(Icons.check_box),
                          label: const Text('Seleziona tutto'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: appState.deselectAllRepos,
                          icon: const Icon(Icons.check_box_outline_blank),
                          label: const Text('Deseleziona tutto'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Trovati ${appState.repositories.length} repository | '
                  'Selezionati: ${appState.selectedRepoIds.length}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: appState.repositories.length,
                    itemBuilder: (context, index) {
                      final repo = appState.repositories[index];
                      final isSelected = appState.selectedRepoIds.contains(repo.id);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          appState.toggleRepoSelection(repo.id);
                        },
                        title: Text(repo.name),
                        subtitle: repo.defaultBranch != null
                            ? Text('Default: ${repo.defaultBranch}')
                            : null,
                        secondary: const Icon(Icons.folder_outlined),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
