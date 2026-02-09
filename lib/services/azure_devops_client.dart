import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/azure_models.dart';

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

  /// Get all repositories
  Future<List<Repository>> getRepositories() async {
    final url = Uri.parse('$_apiBase/git/repositories?api-version=7.0');
    
    try {
      final response = await http.get(url, headers: _headers);
      
      if (response.statusCode != 200) {
        throw AzureDevOpsClientError(
          'Failed to fetch repositories: ${response.statusCode} ${response.body}',
        );
      }

      final data = json.decode(response.body);
      final repoList = data['value'] as List;
      
      return repoList.map((r) => Repository.fromJson(r)).toList();
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

  /// Get tags for a repository
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
      return List<Map<String, dynamic>>.from(data['value']);
    } catch (e) {
      throw AzureDevOpsClientError('Error fetching tags: $e');
    }
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

  /// Get commits between two commits
  Future<List<Commit>> getCommitsBetween(
    String repoId,
    String baseCommit,
    String targetCommit,
  ) async {
    final url = Uri.parse(
      '$_apiBase/git/repositories/$repoId/commitsBatch?api-version=7.0',
    );

    final body = json.encode({
      'itemVersion': {
        'versionType': 'commit',
        'version': targetCommit,
      },
      'compareVersion': {
        'versionType': 'commit',
        'version': baseCommit,
      },
    });

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: body,
      );

      if (response.statusCode != 200) {
        throw AzureDevOpsClientError(
          'Failed to fetch commits: ${response.statusCode}',
        );
      }

      final data = json.decode(response.body);
      final commitList = data['value'] as List;
      
      return commitList.map((c) => Commit.fromJson(c)).toList();
    } catch (e) {
      throw AzureDevOpsClientError('Error fetching commits: $e');
    }
  }

  /// Get changed files between two commits
  Future<List<String>> getChangedFiles(
    String repoId,
    String baseCommit,
    String targetCommit,
  ) async {
    final url = Uri.parse(
      '$_apiBase/git/repositories/$repoId/diffs/commits?'
      'baseVersion=$baseCommit&targetVersion=$targetCommit&api-version=7.0',
    );

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body);
      final changes = data['changes'] as List?;
      
      if (changes == null) return [];

      return changes
          .map((c) => c['item']?['path'] as String?)
          .where((p) => p != null)
          .cast<String>()
          .toList();
    } catch (e) {
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
}
