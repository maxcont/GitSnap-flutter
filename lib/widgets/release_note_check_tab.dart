import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../providers/app_state.dart';
import '../services/release_note_check_service.dart';
import 'release_note_results_view.dart';

class ReleaseNoteCheckTab extends StatefulWidget {
  final AppState state;

  const ReleaseNoteCheckTab({super.key, required this.state});

  @override
  State<ReleaseNoteCheckTab> createState() => _ReleaseNoteCheckTabState();
}

class _ReleaseNoteCheckTabState extends State<ReleaseNoteCheckTab> {
  final _branchesController = TextEditingController();
  final _entriesController = TextEditingController();
  late DateTime _from;
  late DateTime _to;
  Set<String> _repositoryIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = DateTime(now.year, now.month - 1, now.day);
    _entriesController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _branchesController.dispose();
    _entriesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool from) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => from ? _from = selected : _to = selected);
  }

  Future<void> _selectRepositories() async {
    final selection = {..._repositoryIds};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Repository da analizzare'),
          content: SizedBox(
            width: 400,
            child: ListView(shrinkWrap: true, children: [
              for (final repo in widget.state.repositories)
                CheckboxListTile(
                  value: selection.contains(repo.id),
                  title: Text(repo.name),
                  onChanged: (checked) => setDialogState(() => checked == true
                      ? selection.add(repo.id)
                      : selection.remove(repo.id)),
                ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, <String>{}),
              child: const Text('Tutti'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selection),
              child: const Text('Conferma'),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _repositoryIds = result);
  }

  void _run() => widget.state.runReleaseNoteCheck(
        entriesText: _entriesController.text,
        branchPatternsText: _branchesController.text,
        repositoryIds: _repositoryIds,
        from: _from,
        to: DateTime(_to.year, _to.month, _to.day, 23, 59, 59),
      );

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final entryCount =
        ReleaseNoteCheckService.parseEntries(_entriesController.text).length;
    final result = state.releaseNoteResult;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Verifica Release Note',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text(
            'Confronta le pull request completate e i commit diretti entrati '
            'nelle branch indicate con le stringhe della Release Note.'),
        const SizedBox(height: 4),
        Text(
          'Le PR sono filtrate per data di completamento, i commit diretti '
          'per data del commit.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _branchesController,
                        decoration: const InputDecoration(
                          labelText: 'Branch (es. release/2026.11 o release/*)',
                          helperText: 'Più branch separate da virgola',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder_outlined),
                      label: Text(_repositoryIds.isEmpty
                          ? 'Tutti i repository'
                          : '${_repositoryIds.length} repository'),
                      onPressed: _selectRepositories,
                    ),
                    OutlinedButton(
                      onPressed: () => _pickDate(true),
                      child: Text('Da ${dateFormat.format(_from)}'),
                    ),
                    OutlinedButton(
                      onPressed: () => _pickDate(false),
                      child: Text('A ${dateFormat.format(_to)}'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _entriesController,
                  minLines: 4,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: 'Release Note: una stringa per riga',
                    helperText: '$entryCount stringhe da cercare',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: state.isCheckingReleaseNote ? null : _run,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Verifica'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (state.isCheckingReleaseNote) ...[
          Text(state.releaseNoteTotal == 0
              ? state.releaseNotePhase
              : '${state.releaseNotePhase} '
                  '(${state.releaseNoteCompleted}/${state.releaseNoteTotal})'),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: state.releaseNoteTotal == 0
                ? null
                : state.releaseNoteCompleted / state.releaseNoteTotal,
          ),
        ] else ...[
          if (state.releaseNoteError != null)
            Text(state.releaseNoteError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (result != null)
            ReleaseNoteResultsView(
              result: result,
              categoryOf: state.releaseNoteCategoryOf,
              onMove: state.moveReleaseNoteItem,
            ),
        ],
      ]),
    );
  }
}
