import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/azure_models.dart';
import '../providers/app_state.dart';

class ProjectsSidebar extends StatefulWidget {
  const ProjectsSidebar({super.key});

  @override
  State<ProjectsSidebar> createState() => _ProjectsSidebarState();
}

class _ProjectsSidebarState extends State<ProjectsSidebar> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _orgController = TextEditingController();
  final _projectController = TextEditingController();
  final _usernameController = TextEditingController();
  final _patController = TextEditingController();
  bool _showAddForm = false;

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _orgController.dispose();
    _projectController.dispose();
    _usernameController.dispose();
    _patController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _baseUrlController.clear();
    _orgController.clear();
    _projectController.clear();
    _usernameController.clear();
    _patController.clear();
  }

  void _addProject(AppState appState) {
    if (_formKey.currentState!.validate()) {
      final uuid = const Uuid();
      final project = ProjectConfig(
        id: uuid.v4().substring(0, 8),
        name: _nameController.text.isNotEmpty
            ? _nameController.text
            : '${_orgController.text}/${_projectController.text}',
        organization: _orgController.text,
        project: _projectController.text,
        baseUrl: _baseUrlController.text.isNotEmpty
            ? _baseUrlController.text
            : null,
        username: _usernameController.text.isNotEmpty
            ? _usernameController.text
            : null,
        pat: _patController.text.isNotEmpty ? _patController.text : null,
      );

      appState.addProject(project);
      _clearForm();
      setState(() {
        _showAddForm = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progetto salvato')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.folder),
                          const SizedBox(width: 8),
                          Text(
                            'Progetti',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Projects list
                Expanded(
                  child: appState.projects.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Nessun progetto salvato.\nAggiungine uno qui sotto.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: appState.projects.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final project = appState.projects[index];
                            final isSelected =
                                appState.currentProjectId == project.id;

                            return ListTile(
                              selected: isSelected,
                              leading: const Icon(Icons.work_outline),
                              title: Text(project.name),
                              subtitle: Text(
                                '${project.organization}/${project.project}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.launch),
                                    tooltip: 'Carica progetto',
                                    onPressed: () {
                                      appState.loadProject(project);
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Progetto "${project.name}" caricato',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    tooltip: 'Elimina progetto',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Elimina progetto'),
                                          content: Text(
                                            'Sei sicuro di voler eliminare "${project.name}"?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: const Text('Annulla'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                appState
                                                    .deleteProject(project.id);
                                                Navigator.of(context).pop();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Progetto eliminato',
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: const Text('Elimina'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                const Divider(height: 1),

                // Add project button
                if (!_showAddForm)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAddForm = true;
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi progetto'),
                    ),
                  ),

                // Add project form
                if (_showAddForm)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surface.withOpacity(0.5),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nome progetto',
                              hintText: 'es. EACS Produzione',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _baseUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Base URL (opzionale)',
                              hintText: 'vuoto = cloud',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _orgController,
                                  decoration: const InputDecoration(
                                    labelText: 'Organization *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Campo obbligatorio';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _projectController,
                                  decoration: const InputDecoration(
                                    labelText: 'Project *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Campo obbligatorio';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username (opzionale)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _patController,
                            decoration: const InputDecoration(
                              labelText: 'PAT (opzionale, salvato nel file)',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  _clearForm();
                                  setState(() {
                                    _showAddForm = false;
                                  });
                                },
                                child: const Text('Annulla'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _addProject(appState),
                                child: const Text('Salva progetto'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
