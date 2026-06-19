import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            appState.clearDiffResults();
                          },
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text('Ripristina'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                          ),
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
                              
                              // Commits only in SOURCE
                              if (result.commits != null &&
                                  result.commits!.isNotEmpty) ...[
                                const Divider(height: 24),
                                _CommitsExpansionTile(
                                  title:
                                      'Commit in SOURCE non in TARGET (${result.sourceOnlyCommitCount})',
                                  commits: result.commits!,
                                  formatDate: _formatDate,
                                  accentColor: Theme.of(context).colorScheme.primary,
                                  icon: Icons.north_east,
                                ),
                              ],

                              // Commits only in TARGET
                              if (result.targetCommits != null &&
                                  result.targetCommits!.isNotEmpty) ...[
                                const Divider(height: 24),
                                _CommitsExpansionTile(
                                  title:
                                      'Commit in TARGET non in SOURCE (${result.targetOnlyCommitCount})',
                                  commits: result.targetCommits!,
                                  formatDate: _formatDate,
                                  accentColor: Theme.of(context).colorScheme.secondary,
                                  icon: Icons.south_west,
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
                              
                              // Link Apri Compare in Azure DevOps (come in Streamlit)
                              if (result.repoId.isNotEmpty &&
                                  appState.organization.isNotEmpty &&
                                  appState.project.isNotEmpty) ...[
                                const Divider(height: 24),
                                _CompareLink(
                                  baseUrl: appState.baseUrl,
                                  organization: appState.organization,
                                  project: appState.project,
                                  repoName: result.repoName,
                                  sourceRef: result.sourceRef,
                                  targetRef: result.targetRef,
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
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 48,
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 52,
                      columnSpacing: 24,
                      horizontalMargin: 20,
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                      ),
                      columns: [
                        DataColumn(
                          label: Text(
                            'Repo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Stato',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Commit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'File',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'SourceRef',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'TargetRef',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Note',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                      rows: results.asMap().entries.map((entry) {
                        final index = entry.key;
                        final r = entry.value;
                        final isEven = index.isEven;
                        return DataRow(
                          color: WidgetStateProperty.all(
                            isEven
                                ? Theme.of(context).colorScheme.surface
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                          ),
                          cells: [
                            DataCell(Text(
                              r.repoName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIconData(r.status),
                                  size: 18,
                                  color: _getStatusColor(r.status, context),
                                ),
                                const SizedBox(width: 6),
                                Text(_getStatusIcon(r.status)),
                              ],
                            )),
                            DataCell(Text('${r.commitCount}')),
                            DataCell(Text('${r.fileCount}')),
                            DataCell(Text(
                              r.sourceRef ?? '—',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                              ),
                            )),
                            DataCell(Text(
                              r.targetRef ?? '—',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                              ),
                            )),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                r.note ?? '—',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                                ),
                              ),
                            )),
                          ],
                        );
                      }).toList(),
                    ),
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

class _CommitsExpansionTile extends StatelessWidget {
  final String title;
  final List<Commit> commits;
  final String Function(String?) formatDate;
  final Color accentColor;
  final IconData icon;

  const _CommitsExpansionTile({
    required this.title,
    required this.commits,
    required this.formatDate,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: EdgeInsets.zero,
        backgroundColor: accentColor.withOpacity(0.08),
        collapsedBackgroundColor: accentColor.withOpacity(0.16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: accentColor, size: 20),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.65),
              border: Border(
                top: BorderSide(color: accentColor.withOpacity(0.25)),
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: commits.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: theme.colorScheme.outline.withOpacity(0.15),
                ),
                itemBuilder: (context, index) {
                  final commit = commits[index];
                  final shortId = commit.commitId.length >= 7
                      ? commit.commitId.substring(0, 7)
                      : commit.commitId;
                  final author = commit.author?.name ?? '';
                  final dateStr = formatDate(commit.date);
                  final caption = [
                    shortId,
                    if (author.isNotEmpty) '— $author',
                    if (dateStr.isNotEmpty) '· $dateStr',
                  ].join(' ');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          caption,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(0.55),
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          commit.comment ?? '(nessun messaggio)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: theme.colorScheme.onSurface.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
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

/// Link "Apri Compare in Azure DevOps" come nella versione Streamlit
class _CompareLink extends StatelessWidget {
  final String baseUrl;
  final String organization;
  final String project;
  final String repoName;
  final String? sourceRef;
  final String? targetRef;

  const _CompareLink({
    required this.baseUrl,
    required this.organization,
    required this.project,
    required this.repoName,
    this.sourceRef,
    this.targetRef,
  });

  String get _compareUrl {
    final webBase = baseUrl.trim().isEmpty
        ? 'https://dev.azure.com'
        : baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final tRef = Uri.encodeComponent(targetRef ?? '');
    final sRef = Uri.encodeComponent(sourceRef ?? '');
    return '$webBase/$organization/$project/_git/${Uri.encodeComponent(repoName)}/branchCompare?baseVersion=$tRef&targetVersion=$sRef&_a=commits';
  }

  Future<void> _openCompare(BuildContext context) async {
    final uri = Uri.parse(_compareUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile aprire: $_compareUrl')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openCompare(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.open_in_new,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Apri Compare in Azure DevOps',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}