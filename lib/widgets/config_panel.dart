import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/cast_session.dart';

class ConfigPanel extends StatefulWidget {
  const ConfigPanel({super.key});

  @override
  State<ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends State<ConfigPanel> {
  late TextEditingController _baseUrlController;
  late TextEditingController _orgController;
  late TextEditingController _projectController;
  late TextEditingController _usernameController;
  late TextEditingController _patController;
  late TextEditingController _castBaseUrlController;
  String? _lastSyncedProjectId;

  void _syncFromAppState(AppState appState) {
    if (appState.currentProjectId == _lastSyncedProjectId) return;
    _lastSyncedProjectId = appState.currentProjectId;
    _baseUrlController.text = appState.baseUrl;
    _orgController.text = appState.organization;
    _projectController.text = appState.project;
    _usernameController.text = appState.username;
    _patController.text = appState.pat;
    _castBaseUrlController.text = appState.castBaseUrl;
  }

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _baseUrlController = TextEditingController(text: appState.baseUrl);
    _orgController = TextEditingController(text: appState.organization);
    _projectController = TextEditingController(text: appState.project);
    _usernameController = TextEditingController(text: appState.username);
    _patController = TextEditingController(text: appState.pat);
    _castBaseUrlController = TextEditingController(text: appState.castBaseUrl);
    _lastSyncedProjectId = appState.currentProjectId;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _orgController.dispose();
    _projectController.dispose();
    _usernameController.dispose();
    _patController.dispose();
    _castBaseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    _syncFromAppState(appState);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurazione Azure DevOps',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Base URL (opzionale)',
                      hintText: 'Lascia vuoto per cloud Azure DevOps',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      context.read<AppState>().setBaseUrl(value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _orgController,
                    decoration: const InputDecoration(
                      labelText: 'Organization *',
                      hintText: 'es. DefaultCollection',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      context.read<AppState>().setOrganization(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _projectController,
                    decoration: const InputDecoration(
                      labelText: 'Project *',
                      hintText: 'es. EACS',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      context.read<AppState>().setProject(value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username (opzionale)',
                      hintText: 'Per autenticazione on-premises',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      context.read<AppState>().setUsername(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _patController,
              decoration: const InputDecoration(
                labelText: 'Personal Access Token (PAT) *',
                hintText: 'Non viene salvato nel file di configurazione',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              onChanged: (value) {
                context.read<AppState>().setPat(value);
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _castBaseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'CAST Base URL (opzionale)',
                      hintText: 'es. https://server:9091',
                      helperText:
                          'Usato per verificare il Quality Rating delle build.',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      context.read<AppState>().setCastBaseUrl(value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final castBaseUrl = context.read<AppState>().castBaseUrl;
                      if (castBaseUrl.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Compila prima il CAST Base URL.'),
                          ),
                        );
                        return;
                      }
                      context.read<CastSession>().openLoginPage(castBaseUrl);
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Rilogga CAST'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.read<AppState>().loadRepositories();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Carica repository del progetto'),
            ),
          ],
        ),
      ),
    );
  }
}
