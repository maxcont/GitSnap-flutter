import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/azure_models.dart';
import '../providers/app_state.dart';

class RefConfigPanel extends StatefulWidget {
  const RefConfigPanel({super.key});

  @override
  State<RefConfigPanel> createState() => _RefConfigPanelState();
}

class _RefConfigPanelState extends State<RefConfigPanel> {
  late TextEditingController _sourceValueController;
  late TextEditingController _targetValueController;
  late RefType _sourceType;
  late RefType _targetType;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _sourceType = appState.sourceRef.type;
    _targetType = appState.targetRef.type;
    _sourceValueController = TextEditingController(text: appState.sourceRef.value);
    _targetValueController = TextEditingController(text: appState.targetRef.value);
  }

  @override
  void dispose() {
    _sourceValueController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  String _getRefTypeLabel(RefType type) {
    switch (type) {
      case RefType.branch:
        return 'Branch';
      case RefType.tagPattern:
        return 'Tag pattern';
      case RefType.commit:
        return 'Commit SHA';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Definizione ambienti SOURCE e TARGET',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // SOURCE
            Text(
              'SOURCE',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<RefType>(
                    value: _sourceType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo SOURCE',
                      border: OutlineInputBorder(),
                    ),
                    items: RefType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getRefTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sourceType = value;
                        });
                        context.read<AppState>().setSourceRef(
                              RefConfig(
                                type: value,
                                value: _sourceValueController.text,
                              ),
                            );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _sourceValueController,
                    decoration: const InputDecoration(
                      labelText: 'Valore SOURCE',
                      hintText: 'branch, tag pattern, o SHA',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      context.read<AppState>().setSourceRef(
                            RefConfig(type: _sourceType, value: value),
                          );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // TARGET
            Text(
              'TARGET',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<RefType>(
                    value: _targetType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo TARGET',
                      border: OutlineInputBorder(),
                    ),
                    items: RefType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getRefTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _targetType = value;
                        });
                        context.read<AppState>().setTargetRef(
                              RefConfig(
                                type: value,
                                value: _targetValueController.text,
                              ),
                            );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _targetValueController,
                    decoration: const InputDecoration(
                      labelText: 'Valore TARGET',
                      hintText: 'branch, tag pattern, o SHA',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      context.read<AppState>().setTargetRef(
                            RefConfig(type: _targetType, value: value),
                          );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<AppState>().runComparison();
              },
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Esegui confronto'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
