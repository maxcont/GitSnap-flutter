import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/config_panel.dart';
import '../widgets/repository_selector.dart';
import '../widgets/ref_config_panel.dart';
import '../widgets/results_dashboard.dart';
import '../widgets/projects_sidebar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🔄 GitSnap – Confronto Ambienti'),
            const SizedBox(width: 16),
            Text(
              '· by Massimo Contursi',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Progetti',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ProjectsSidebar(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Salva configurazione',
            onPressed: () async {
              final appState = context.read<AppState>();
              await appState.saveConfiguration();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Configurazione salvata'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subtitle
                Text(
                  'Confronta SOURCE vs TARGET su più repository tramite Azure DevOps REST API.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
                const SizedBox(height: 24),

                // Error message
                if (appState.errorMessage != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              appState.errorMessage!,
                              style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: appState.clearError,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (appState.errorMessage != null) const SizedBox(height: 16),

                // Configuration panel
                const ConfigPanel(),
                const SizedBox(height: 24),

                // Repository selector
                if (appState.repositories.isNotEmpty) ...[
                  const RepositorySelector(),
                  const SizedBox(height: 24),
                ],

                // Reference configuration
                if (appState.selectedRepoIds.isNotEmpty) ...[
                  const RefConfigPanel(),
                  const SizedBox(height: 24),
                ],

                // Results dashboard
                if (appState.diffResults.isNotEmpty) ...[
                  const ResultsDashboard(),
                ],

                // Loading indicator
                if (appState.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),

                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'GitSnap · by Massimo Contursi',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4),
                        ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
