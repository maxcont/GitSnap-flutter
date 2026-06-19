import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/azure_models.dart';
import '../models/release_models.dart';

class AzureDevOpsClientError implements Exception {
  final String message;
  AzureDevOpsClientError(this.message);

  @override
  String toString() => 'AzureDevOpsClientError: $message';
}

class AzureDevOpsClient {
  final String organization;
  final String project;
  final String pat;
  final String? username;
  final String? baseUrl;

  late final String _apiBase;
  late final Map<String, String> _headers;

  AzureDevOpsClient({
    required this.organization,
    required this.project,
    required this.pat,
    this.username,
    this.baseUrl,
  }) {
    if (baseUrl != null && baseUrl!.isNotEmpty) {
      // On-premises
      _apiBase = '${baseUrl!.trim()}/$organization/$project/_apis';
    } else {
      // Cloud
      _apiBase = 'https://dev.azure.com/$organization/$project/_apis';
    }

    final auth = base64Encode(utf8.encode('${username ?? ""}:$pat'));
    _headers = {
      'Authorization': 'Basic $auth',
      'Content-Type': 'application/json',
    };
  }

  static String _messageForStatus(int statusCode, String body) {
    if (statusCode == 401) {
      return '401 Non autorizzato. Verifica che il PAT (Personal Access Token) sia corretto, non scaduto, '
          'e che l\'utente abbia accesso al progetto. Su Azure DevOps Server usa come username vuoto e PAT come password (Basic Auth).';
    }
    if (statusCode == 403) {
      return '403 Accesso negato. Il PAT non ha i permessi necessari per questo progetto.';
    }
    if (body.length > 500 || body.trim().startsWith('<!')) {
      return 'Errore HTTP $statusCode. Verifica connessione e credenziali.';
    }
    return body;
  }

  /// Get all repositories
  Future<List<Repository>> getRepositories() async {
    final url = Uri.parse('$_apiBase/git/repositories?api-version=7.0');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode != 200) {
        throw AzureDevOpsClientError(
          'Failed to fetch repositories: ${response.statusCode}. ${_messageForStatus(response.statusCode, response.body)}',
        );
      }

      final data = json.decode(response.body);
      final repoList = data['value'] as List;

      return repoList.map((r) => Repository.fromJson(r)).toList();
    } on AzureDevOpsClientError {
      rethrow;
    } catch (e) {
      throw AzureDevOpsClientError('Error fetching repositories: $e');
    }
  }

  /// Get branches for a repository
  Future<List<Map<String, dynamic>>> getBranches(String repoId) async {
    final url = Uri.parse(
      '$_apiBase/git/repositories/$repoId/refs?filter=heads/&api-version=7.0',
    );

    try {
      final response = await http.get(url, headers: _headers);
      
      if (response.statusCode != 200) {
        throw AzureDevOpsClientError(
          'Failed to fetch branches: ${response.statusCode}',
        );
      }

      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['value']);
    } catch (e) {
      throw AzureDevOpsClientError('Error fetching branches: $e');
    }
  }

  /// Get tags for a repository (refs with filter=tags/)
  Future<List<Map<String, dynamic>>> getTags(String repoId) async {
    final url = Uri.parse(
      '$_apiBase/git/repositories/$repoId/refs?filter=tags/&api-version=7.0',
    );

    try {
      final response = await http.get(url, headers: _headers);
      
      if (response.statusCode != 200) {
        throw AzureDevOpsClientError(
          'Failed to fetch tags: ${response.statusCode}',
        );
      }

      final data = json.decode(response.body);
      final value = data['value'] ?? data['refs'];
      if (value == null) return [];
      return List<Map<String, dynamic>>.from(value);
    } catch (e) {
      throw AzureDevOpsClientError('Error fetching tags: $e');
    }
  }

  /// Resolve a tag name to the commit it points to (for annotated tags the ref objectId is not the commit).
  /// Returns commit map with commitId and date, or null if not found.
  /// Tries api-version 7.0, 6.0, 5.0 for on-prem compatibility (like Streamlit).
  Future<Map<String, dynamic>?> getCommitByTag(String repoId, String tagName) async {
    const versions = ['7.0', '6.0', '5.0'];
    for (final apiVersion in versions) {
      final url = Uri.parse('$_apiBase/git/repositories/$repoId/commits').replace(
        queryParameters: {
          'api-version': apiVersion,
          r'$top': '1',
          'searchCriteria.itemVersion.version': tagName,
          'searchCriteria.itemVersion.versionType': 'tag',
        },
      );
      try {
        final response = await http.get(url, headers: _headers);
        if (response.statusCode != 200) continue;
        final data = json.decode(response.body);
        final list = data['value'] as List?;
        if (list == null || list.isEmpty) continue;
        return Map<String, dynamic>.from(list[0]);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Get commit details
  Future<Map<String, dynamic>> getCommit(String repoId, String commitId) async {
    final url = Uri.parse(
      '$_apiBase/git/repositories/$repoId/commits/$commitId?api-version=7.0',
    );

    try {
      final response = await http.get(url, headers: _headers);
      
      if (response.statusCode != 200) {
        throw AzureDevOpsClientError(
          'Failed to fetch commit: ${response.statusCode}',
        );
      }

      return json.decode(response.body);
    } catch (e) {
      throw AzureDevOpsClientError('Error fetching commit: $e');
    }
  }

  /// Commits reachable from [tipCommit] that are not in [baseCommit].
  Future<List<Commit>> getCommitsBetween(
    String repoId,
    String baseCommit,
    String tipCommit,
  ) async {
    // Azure returns commits in compareVersion not in itemVersion.
    final url = Uri.parse('$_apiBase/git/repositories/$repoId/commits').replace(
      queryParameters: {
        'api-version': '7.0',
        r'$top': '250',
        'searchCriteria.itemVersion.version': baseCommit,
        'searchCriteria.itemVersion.versionType': 'commit',
        'searchCriteria.compareVersion.version': tipCommit,
        'searchCriteria.compareVersion.versionType': 'commit',
      },
    );

    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) {
        throw AzureDevOpsClientError(
          'Failed to fetch commits: ${response.statusCode}',
        );
      }
      final data = json.decode(response.body);
      final commitList = data['value'] as List?;
      if (commitList == null) return [];
      return commitList.map((c) => Commit.fromJson(c)).toList();
    } catch (e) {
      throw AzureDevOpsClientError('Error fetching commits: $e');
    }
  }

  /// Result of diffs/commits API: commit count (aheadCount) and file list from the same response (like Streamlit).
  static int aheadCountFromDiff(Map<String, dynamic> data) {
    final v = data['aheadCount'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// Commits in baseVersion not in targetVersion (inverse of [aheadCountFromDiff]).
  static int behindCountFromDiff(Map<String, dynamic> data) {
    final v = data['behindCount'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// File count = number of entries in changes (one per file). Using changeCounts sum can double-count on some APIs.
  static int totalChangesFromDiff(Map<String, dynamic> data) {
    final changes = data['changes'] as List?;
    if (changes != null && changes.isNotEmpty) {
      return changes.length;
    }
    final changeCounts = data['changeCounts'];
    if (changeCounts is Map) {
      var sum = 0;
      for (final v in changeCounts.values) {
        if (v is int) sum += v;
        if (v is num) sum += v.toInt();
      }
      return sum;
    }
    return 0;
  }

  static List<String> filePathsFromDiff(Map<String, dynamic> data) {
    final changes = data['changes'] as List?;
    if (changes == null) return [];
    return changes
        .map((c) {
          final item = c is Map ? c['item'] : null;
          final path = item is Map ? (item['path'] ?? item['originalPath']) : null;
          final p = path ?? (c is Map ? c['path'] : null);
          return p is String ? p : null;
        })
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toList();
  }

  /// Single call to diffs/commits (base=TARGET, target=SOURCE). Returns full response so we use aheadCount for commit diff and status.
  Future<Map<String, dynamic>> getDiffsCommits(
    String repoId,
    String baseCommit,
    String targetCommit,
  ) async {
    final url = Uri.parse('$_apiBase/git/repositories/$repoId/diffs/commits').replace(
      queryParameters: {
        'api-version': '7.0',
        'baseVersion': baseCommit,
        'targetVersion': targetCommit,
        'baseVersionType': 'commit',
        'targetVersionType': 'commit',
        r'$top': '500',
      },
    );
    final response = await http.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw AzureDevOpsClientError('Diffs/commits failed: ${response.statusCode}');
    }
    final data = json.decode(response.body);
    return Map<String, dynamic>.from(data);
  }

  /// Get changed files between two commits (base=TARGET, target=SOURCE). Kept for compatibility.
  Future<List<String>> getChangedFiles(
    String repoId,
    String baseCommit,
    String targetCommit,
  ) async {
    try {
      final data = await getDiffsCommits(repoId, baseCommit, targetCommit);
      return AzureDevOpsClient.filePathsFromDiff(data);
    } catch (_) {
      return [];
    }
  }

  /// Test connection
  Future<bool> testConnection() async {
    try {
      await getRepositories();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Release / Pipeline APIs ─────────────────────────────────────────────

  String get _releaseBase => '$_apiBase/release';

  /// List release definitions (pipelines), optionally filtered by folder path (e.g. "\\Esercizio")
  Future<List<ReleaseDefinitionInfo>> getReleaseDefinitions({
    String? path,
    int top = 100,
  }) async {
    final q = <String, String>{
      'api-version': '7.0',
      r'$top': '$top',
    };
    if (path != null && path.isNotEmpty) q['path'] = path;
    final url = Uri.parse('$_releaseBase/definitions').replace(queryParameters: q);
    final response = await http.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw AzureDevOpsClientError('Release definitions: ${response.statusCode}');
    }
    final data = json.decode(response.body);
    final list = data['value'] as List?;
    if (list == null) return [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e);
      return ReleaseDefinitionInfo(
        id: (m['id'] as num).toInt(),
        name: m['name'] as String? ?? '',
        path: m['path'] as String?,
      );
    }).toList();
  }

  /// Revisions of a release definition (returns list of revision numbers)
  Future<List<int>> getReleaseDefinitionRevisions(int definitionId) async {
    final url = Uri.parse('$_releaseBase/definitions/$definitionId/revisions').replace(
      queryParameters: {'api-version': '7.0'},
    );
    final response = await http.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw AzureDevOpsClientError('Revisions: ${response.statusCode}');
    }
    final data = json.decode(response.body);
    final list = data['value'] as List?;
    if (list == null) return [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e);
      final n = m['revision'];
      return n is int ? n : (n as num).toInt();
    }).toList()..sort((a, b) => b.compareTo(a));
  }

  /// Get release definition at a specific revision (includes variables)
  Future<Map<String, ReleaseVariable>> getVariablesAtRevision(
    int definitionId,
    int revision,
  ) async {
    final url = Uri.parse('$_releaseBase/definitions/$definitionId').replace(
      queryParameters: {'api-version': '7.0', 'revision': '$revision'},
    );
    final response = await http.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw AzureDevOpsClientError('Definition revision: ${response.statusCode}');
    }
    final data = json.decode(response.body);
    return _parseVariablesFromDefinition(data);
  }

  /// Latest variables via project _releaseDefinition endpoint (on-prem style)
  Future<Map<String, ReleaseVariable>> getLatestVariables(int definitionId) async {
    final base = baseUrl != null && baseUrl!.isNotEmpty
        ? '${baseUrl!.trim()}/$organization/$project'
        : 'https://dev.azure.com/$organization/$project';
    final url = Uri.parse('$base/_releaseDefinition').replace(
      queryParameters: {
        'definitionId': '$definitionId',
        '__rt': 'fps',
        '__ver': '2',
      },
    );
    final response = await http.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw AzureDevOpsClientError('Latest variables: ${response.statusCode}');
    }
    final data = json.decode(response.body);
    if (data is! Map<String, dynamic>) return {};
    return _parseVariablesFromDefinition(data);
  }

  /// Flatten variables from definition JSON (environments[].variables or root variables).
  /// Keys include scope so the same name in different environments is preserved.
  static Map<String, ReleaseVariable> parseVariablesFromDefinition(Map<String, dynamic> data) {
    final out = <String, ReleaseVariable>{};
    final envs = data['environments'] as List?;
    if (envs != null) {
      for (final e in envs) {
        final env = e is Map ? e as Map<String, dynamic> : null;
        if (env == null) continue;
        final scope = env['name'] as String? ?? 'Environment';
        final vars = env['variables'] as Map?;
        if (vars != null) _addVarsFromMap(vars, out, scope: scope);
      }
    }
    final rootVars = data['variables'] as Map?;
    if (rootVars != null) {
      _addVarsFromMap(rootVars, out, scope: ReleaseVariable.releaseScope);
    }
    return out;
  }

  static Map<String, ReleaseVariable> _parseVariablesFromDefinition(Map<String, dynamic> data) =>
      parseVariablesFromDefinition(data);

  static void _addVarsFromMap(
    dynamic vars,
    Map<String, ReleaseVariable> out, {
    required String scope,
  }) {
    final m = vars is Map ? vars as Map<String, dynamic> : null;
    if (m == null) return;
    for (final e in m.entries) {
      final name = e.key as String;
      dynamic v = e.value;
      final ReleaseVariable variable;
      if (v is Map) {
        final val = v['value']?.toString() ?? '';
        final secret = v['isSecret'] == true;
        variable = ReleaseVariable(name: name, value: val, isSecret: secret, scope: scope);
      } else {
        variable = ReleaseVariable(name: name, value: v?.toString() ?? '', scope: scope);
      }
      out[variable.mapKey] = variable;
    }
  }
}
