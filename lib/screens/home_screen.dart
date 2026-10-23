import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/config_panel.dart';
import '../widgets/repository_selector.dart';
import '../widgets/ref_config_panel.dart';
import '../widgets/results_dashboard.dart';
import '../widgets/projects_sidebar.dart';
import '../widgets/pipeline_variables_tab.dart';
import '../widgets/pull_requests_tab.dart';
import '../widgets/build_environment_tab.dart';
import '../widgets/cast_login_panel.dart';
import '../widgets/update_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // The CAST login badge/panel is only relevant on the tabs that actually
  // interact with CAST: "Confronto repository" (index 0, hosts the
  // "Rilogga CAST" button) and "Verifica build" (index 3, hosts "Verifica
  // CAST"). Showing it while browsing the other, unrelated tabs would just
  // be visual clutter.
  static const _tabsWithCastPanel = {0, 3};

  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CastLoginOverlay(
      showPanel: _tabsWithCastPanel.contains(_currentTabIndex),
      child: Scaffold(
        appBar: AppBar(
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Image.asset(
                  'assets/ico/ico_white.png',
                  width: 40,
                  height: 40,
                  semanticLabel: 'GitSnap',
                ),
                const SizedBox(width: 12),
                const Text('GitSnap – Confronto Ambienti'),
                const SizedBox(width: 16),
                Text(
                  '·  M.Contursi',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
              ],
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                  text: 'Confronto repository',
                  icon: Icon(Icons.compare_arrows)),
              Tab(text: 'Utility pipeline', icon: Icon(Icons.build)),
              Tab(text: 'Pull request', icon: Icon(Icons.call_split)),
              Tab(text: 'Verifica build', icon: Icon(Icons.rocket_launch)),
            ],
          ),
          actions: [
            const UpdateButton(),
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
        body: TabBarView(
          controller: _tabController,
          children: [
            _ComparisonTab(),
            const PipelineVariablesTab(),
            const PullRequestsTab(),
            const BuildEnvironmentTab(),
          ],
        ),
      ),
    );
  }
}

class _ComparisonTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
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
              const ConfigPanel(),
              const SizedBox(height: 24),
              if (appState.repositories.isNotEmpty) ...[
                const RepositorySelector(),
                const SizedBox(height: 24),
              ],
              if (appState.selectedRepoIds.isNotEmpty) ...[
                const RefConfigPanel(),
                const SizedBox(height: 24),
              ],
              if (appState.diffResults.isNotEmpty) ...[
                const ResultsDashboard(),
              ],
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
                  'GitSnap · by M.Contursi',
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
    );
  }
}
