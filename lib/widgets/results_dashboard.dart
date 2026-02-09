import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/azure_models.dart';
import '../providers/app_state.dart';

class ResultsDashboard extends StatefulWidget {
  const ResultsDashboard({super.key});

  @override
  State<ResultsDashboard> createState() => _ResultsDashboardState();
}

class _ResultsDashboardState extends State<ResultsDashboard> {
  bool _showOnlyDivergent = false;

  String _getStatusIcon(DiffStatus status) {
    switch (status) {
      case DiffStatus.aligned:
        return 'ALLINEATO';
      case DiffStatus.divergent:
        return 'DIVERGENTE';
      case DiffStatus.error:
        return 'ERRORE';
    }
  }

  Color _getStatusColor(DiffStatus status, BuildContext context) {
    switch (status) {
      case DiffStatus.aligned:
        return Colors.green;
      case DiffStatus.divergent:
        return Colors.orange;
      case DiffStatus.error:
        return Colors.red;
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (e) {
      return isoDate.substring(0, isoDate.length > 19 ? 19 : isoDate.length);
    }
  }

  IconData _getStatusIconData(DiffStatus status) {
    switch (status) {
      case DiffStatus.aligned:
        return Icons.check_circle;
      case DiffStatus.divergent:
        return Icons.warning;
      case DiffStatus.error:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        var results = appState.diffResults;
        
        if (_showOnlyDivergent) {
          results = results
              .where((r) => r.status == DiffStatus.divergent)
              .toList();
        }

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
                      'Dashboard Risultati',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        const Text('Mostra solo divergenti'),
                        Switch(
                          value: _showOnlyDivergent,
                          onChanged: (value) {
                            setState(() {
                              _showOnlyDivergent = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Results list
                ...results.map((result) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: _getStatusColor(result.status, context)
                        .withOpacity(0.1),
                    child: ExpansionTile(
                      leading: Icon(
                        _getStatusIconData(result.status),
                        color: _getStatusColor(result.status, context),
                      ),
                      title: Text(
                        result.repoName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_getStatusIcon(result.status)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status info
                              Row(
                                children: [
                                  _InfoChip(
                                    label: 'Commit diff: ${result.commitCount}',
                                    icon: Icons.commit,
                                  ),
                                  const SizedBox(width: 8),
                                  _InfoChip(
                                    label: 'File diff: ${result.fileCount}',
                                    icon: Icons.insert_drive_file,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Source and Target comparison
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // SOURCE
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SOURCE',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (result.sourceRef != null)
                                          Text(
                                            'Ref: ${result.sourceRef}',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (result.sourceCommit != null)
                                          Text(
                                            'Commit: ${result.sourceCommit!.substring(0, 7)}',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (result.sourceCommitAuthor != null)
                                          Text(
                                            result.sourceCommitAuthor!,
                                            style: const TextStyle(
                                              fontStyle: FontStyle.italic,
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (result.sourceCommitDate != null)
                                          Text(
                                            'Data: ${_formatDate(result.sourceCommitDate)}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        const SizedBox(height: 8),
                                        Text(
                                          result.sourceCommitMessage ??
                                              '(nessun messaggio)',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // TARGET
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TARGET',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .secondary,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (result.targetRef != null)
                                          Text(
                                            'Ref: ${result.targetRef}',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (result.targetCommit != null)
                                          Text(
                                            'Commit: ${result.targetCommit!.substring(0, 7)}',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (result.targetCommitAuthor != null)
                                          Text(
                                            result.targetCommitAuthor!,
                                            style: const TextStyle(
                                              fontStyle: FontStyle.italic,
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (result.targetCommitDate != null)
                                          Text(
                                            'Data: ${_formatDate(result.targetCommitDate)}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        const SizedBox(height: 8),
                                        Text(
                                          result.targetCommitMessage ??
                                              '(nessun messaggio)',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              if (result.note != null) ...[
                                const Divider(height: 24),
                                Text(
                                  result.note!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ],
                              
                              // Commits list
                              if (result.commits != null &&
                                  result.commits!.isNotEmpty) ...[
                                const Divider(height: 24),
                                ExpansionTile(
                                  title: Text(
                                    'Commit (SOURCE non in TARGET) (${result.commits!.length})',
                                  ),
                                  children: [
                                    Container(
                                      constraints:
                                          const BoxConstraints(maxHeight: 300),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: result.commits!.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(),
                                        itemBuilder: (context, index) {
                                          final commit = result.commits![index];
                                          return ListTile(
                                            dense: true,
                                            title: Text(
                                              commit.comment ?? '(nessun messaggio)',
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                            subtitle: Text(
                                              '${commit.commitId.substring(0, 7)} - '
                                              '${commit.author?.name ?? ""} - '
                                              '${_formatDate(commit.date)}',
                                              style:
                                                  const TextStyle(fontSize: 11),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              
                              // Files list
                              if (result.files != null &&
                                  result.files!.isNotEmpty) ...[
                                const Divider(height: 24),
                                ExpansionTile(
                                  title: Text(
                                    'File modificati (${result.files!.length})',
                                  ),
                                  children: [
                                    Container(
                                      constraints:
                                          const BoxConstraints(maxHeight: 200),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: result.files!.length > 100
                                            ? 100
                                            : result.files!.length,
                                        itemBuilder: (context, index) {
                                          return ListTile(
                                            dense: true,
                                            leading:
                                                const Icon(Icons.insert_drive_file,
                                                    size: 16),
                                            title: Text(
                                              result.files![index],
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                
                // Summary table
                const Divider(height: 32),
                Text(
                  'Riepilogo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Repo')),
                      DataColumn(label: Text('Stato')),
                      DataColumn(label: Text('Commit')),
                      DataColumn(label: Text('File')),
                      DataColumn(label: Text('SourceRef')),
                      DataColumn(label: Text('TargetRef')),
                    ],
                    rows: results.map((r) {
                      return DataRow(cells: [
                        DataCell(Text(r.repoName)),
                        DataCell(Text(_getStatusIcon(r.status))),
                        DataCell(Text('${r.commitCount}')),
                        DataCell(Text('${r.fileCount}')),
                        DataCell(Text(r.sourceRef ?? '')),
                        DataCell(Text(r.targetRef ?? '')),
                      ]);
                    }).toList(),
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

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}