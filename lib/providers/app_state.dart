import 'package:flutter/foundation.dart';
import '../models/azure_models.dart';
import '../models/commit_search_models.dart';
import '../models/pull_request_models.dart';
import '../services/azure_devops_client.dart';
import '../services/ref_resolver.dart';
import '../services/diff_service.dart';
import '../services/storage_service.dart';
import '../services/pull_request_filter_service.dart';

class AppState extends ChangeNotifier {
  final StorageService _storage = StorageService();

  // Configuration
  String _baseUrl = '';
  String _organization = '';
  String _project = '';
  String _username = '';
  String _pat = '';

  // Client
  AzureDevOpsClient? _client;

  // Repositories
  List<Repository> _repositories = [];
  Set<String> _selectedRepoIds = {};

  // References
  RefConfig _sourceRef = RefConfig(type: RefType.branch, value: 'develop');
  RefConfig _targetRef = RefConfig(type: RefType.branch, value: 'master');

  // Results
  List<DiffResult> _diffResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  List<PullRequestSummary> _allPullRequests = [];
  PullRequestFilter _pullRequestFilter = PullRequestFilter.defaults();
  bool _isLoadingPullRequests = false;
  Map<String, String> _pullRequestRepositoryErrors = {};
  PullRequestIdentity? _currentPullRequestUser;
  List<CommitSearchResult> _commitSearchResults = [];
  bool _isSearchingCommits = false;
  String? _commitSearchError;
  String _commitSearchPhase = '';
  int _commitSearchCompleted = 0;
  int _commitSearchTotal = 0;

  // Projects
  List<ProjectConfig> _projects = [];
  String? _currentProjectId;

  // Getters
  String get baseUrl => _baseUrl;
  String get organization => _organization;
  String get project => _project;
  String get username => _username;
  String get pat => _pat;
  AzureDevOpsClient? get client => _client;
  List<Repository> get repositories => _repositories;
  Set<String> get selectedRepoIds => _selectedRepoIds;
  RefConfig get sourceRef => _sourceRef;
  RefConfig get targetRef => _targetRef;
  List<DiffResult> get diffResults => _diffResults;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ProjectConfig> get projects => _projects;
  String? get currentProjectId => _currentProjectId;
  List<PullRequestSummary> get allPullRequests =>
      List.unmodifiable(_allPullRequests);
  PullRequestFilter get pullRequestFilter => _pullRequestFilter;
  bool get isLoadingPullRequests => _isLoadingPullRequests;
  Map<String, String> get pullRequestRepositoryErrors =>
      Map.unmodifiable(_pullRequestRepositoryErrors);
  PullRequestIdentity? get currentPullRequestUser => _currentPullRequestUser;
  List<CommitSearchResult> get commitSearchResults =>
      List.unmodifiable(_commitSearchResults);
  bool get isSearchingCommits => _isSearchingCommits;
  String? get commitSearchError => _commitSearchError;
  String get commitSearchPhase => _commitSearchPhase;
  int get commitSearchCompleted => _commitSearchCompleted;
  int get commitSearchTotal => _commitSearchTotal;
  List<PullRequestSummary> get filteredPullRequests =>
      PullRequestFilterService.filter(
        pullRequests: _allPullRequests,
        filter: _pullRequestFilter,
        currentUser: _currentPullRequestUser,
      );
  Map<PullRequestStatus, int> get pullRequestStatusCounts =>
      PullRequestFilterService.statusCounts(
        pullRequests: _allPullRequests,
        filter: _pullRequestFilter,
        currentUser: _currentPullRequestUser,
      );

  AppState() {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _projects = await _storage.loadProjects();
    final config = await _storage.loadConfig();

    if (config.isNotEmpty) {
      _baseUrl = config['base_url'] ?? '';
      _organization = config['organization'] ?? '';
      _project = config['project'] ?? '';
      _username = config['username'] ?? '';

      if (config['selected_repo_ids'] != null) {
        _selectedRepoIds = Set<String>.from(config['selected_repo_ids']);
      }

      if (config['source'] != null) {
        _sourceRef = RefConfig.fromJson(config['source']);
      }

      if (config['target'] != null) {
        _targetRef = RefConfig.fromJson(config['target']);
      }
    }

    notifyListeners();
  }

  // Setters
  void setBaseUrl(String value) {
    _baseUrl = value;
    notifyListeners();
  }

  void setOrganization(String value) {
    _organization = value;
    notifyListeners();
  }

  void setProject(String value) {
    _project = value;
    notifyListeners();
  }

  void setUsername(String value) {
    _username = value;
    notifyListeners();
  }

  void setPat(String value) {
    _pat = value;
    notifyListeners();
  }

  void setSourceRef(RefConfig ref) {
    _sourceRef = ref;
    notifyListeners();
  }

  void setTargetRef(RefConfig ref) {
    _targetRef = ref;
    notifyListeners();
  }

  void toggleRepoSelection(String repoId) {
    if (_selectedRepoIds.contains(repoId)) {
      _selectedRepoIds.remove(repoId);
    } else {
      _selectedRepoIds.add(repoId);
    }
    notifyListeners();
  }

  void selectAllRepos() {
    _selectedRepoIds = _repositories.map((r) => r.id).toSet();
    notifyListeners();
  }

  void deselectAllRepos() {
    _selectedRepoIds.clear();
    notifyListeners();
  }

  // Load repositories
  Future<void> loadRepositories() async {
    if (_organization.isEmpty || _project.isEmpty) {
      _errorMessage = 'Inserisci organizzazione e progetto.';
      notifyListeners();
      return;
    }

    if (_pat.isEmpty) {
      _errorMessage =
          'Inserisci il PAT (Personal Access Token) per autenticarti ad Azure DevOps.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _client = AzureDevOpsClient(
        organization: _organization,
        project: _project,
        pat: _pat,
        username: _username.isEmpty ? null : _username,
        baseUrl: _baseUrl.isEmpty ? null : _baseUrl,
      );

      _repositories = await _client!.getRepositories();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error loading repositories: $e';
      _repositories = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setPullRequestFilter(PullRequestFilter filter) {
    _pullRequestFilter = filter;
    notifyListeners();
  }

  Future<void> loadPullRequests() async {
    if (_organization.isEmpty || _project.isEmpty || _pat.isEmpty) {
      _errorMessage =
          'Configura organizzazione, progetto e PAT per caricare le pull request.';
      notifyListeners();
      return;
    }
    _isLoadingPullRequests = true;
    _errorMessage = null;
    _allPullRequests = [];
    _pullRequestRepositoryErrors = {};
    notifyListeners();
    try {
      _client ??= AzureDevOpsClient(
        organization: _organization,
        project: _project,
        pat: _pat,
        username: _username.isEmpty ? null : _username,
        baseUrl: _baseUrl.isEmpty ? null : _baseUrl,
      );
      try {
        _currentPullRequestUser = await _client!.getCurrentUser();
      } catch (error) {
        _pullRequestRepositoryErrors['Utente autenticato'] = error.toString();
      }
      _repositories = _repositories.isEmpty
          ? await _client!.getRepositories()
          : _repositories;
      const concurrency = 5;
      for (var index = 0; index < _repositories.length; index += concurrency) {
        final results = await Future.wait(
            _repositories.skip(index).take(concurrency).map((repository) async {
          try {
            return (repository, await _client!.getPullRequests(repository.id));
          } catch (error) {
            _pullRequestRepositoryErrors[repository.name] = error.toString();
            return (repository, <PullRequestSummary>[]);
          }
        }));
        for (final result in results) {
          _allPullRequests.addAll(result.$2);
        }
        notifyListeners();
      }
    } catch (error) {
      _errorMessage = 'Errore nel caricamento delle pull request: $error';
    } finally {
      _isLoadingPullRequests = false;
      notifyListeners();
    }
  }

  Future<PullRequestDetails> loadPullRequestDetails(
      PullRequestSummary pullRequest) async {
    if (_client == null) throw StateError('Carica prima le pull request.');
    final detail = await _client!
        .getPullRequestDetails(pullRequest.repositoryId, pullRequest.id);
    final metrics = await _client!
        .getPullRequestMetrics(pullRequest.repositoryId, pullRequest.id);
    return detail.copyWith(metrics: metrics);
  }

  Future<void> searchCommits({
    required String text,
    required Set<String> repositoryIds,
    required Set<String> branchNames,
    required Set<String> branchPrefixes,
    required String? branchPattern,
    required bool allBranches,
    required DateTime from,
    required DateTime to,
  }) async {
    if (_client == null || text.trim().isEmpty) return;
    _isSearchingCommits = true;
    _commitSearchError = null;
    _commitSearchResults = [];
    _commitSearchPhase = 'Preparazione della ricerca';
    _commitSearchCompleted = 0;
    _commitSearchTotal = 0;
    notifyListeners();
    try {
      final repos = _repositories
          .where((repo) =>
              repositoryIds.isEmpty || repositoryIds.contains(repo.id))
          .toList();
      final matches = <String, CommitSearchResult>{};
      final skippedBranches = <String>[];
      final searchErrors = <String>[];
      final availableBranchesByRepository = <String, Set<String>>{};
      const concurrency = 5;
      _commitSearchPhase = 'Lettura branch dei repository';
      _commitSearchCompleted = 0;
      _commitSearchTotal = repos.length;
      notifyListeners();

      for (var index = 0; index < repos.length; index += concurrency) {
        final chunk = repos.skip(index).take(concurrency);
        final results = await Future.wait(chunk.map((repo) async {
          try {
            final branches = (await _client!.getBranches(repo.id))
                .map((branch) => (branch['name'] as String? ?? '')
                    .replaceFirst('refs/heads/', ''))
                .where((branch) => branch.isNotEmpty)
                .toSet();
            return (repo: repo, branches: branches, error: null as Object?);
          } catch (error) {
            return (repo: repo, branches: <String>{}, error: error);
          }
        }));
        for (final result in results) {
          if (result.error != null) {
            searchErrors.add(
                '${result.repo.name}: impossibile leggere le branch (${result.error})');
          } else {
            availableBranchesByRepository[result.repo.id] = result.branches;
          }
        }
        _commitSearchCompleted += results.length;
        notifyListeners();
      }

      final normalizedBranchPattern = branchPattern?.trim();
      final branchPatternRegex =
          normalizedBranchPattern == null || normalizedBranchPattern.isEmpty
              ? null
              : RegExp(
                  '^${RegExp.escape(normalizedBranchPattern).replaceAll(r'\*', '.*')}\$',
                  caseSensitive: false,
                );
      final requests = <({Repository repo, String branch})>[];
      for (final repo in repos) {
        final availableBranches = availableBranchesByRepository[repo.id];
        if (availableBranches == null) continue;
        final branches = allBranches
            ? availableBranches
            : availableBranches
                .where((branch) =>
                    branchNames.contains(branch) ||
                    branchPrefixes.any(branch.startsWith) ||
                    branchPatternRegex?.hasMatch(branch) == true)
                .toSet();
        final missingBranches = branchNames.difference(availableBranches);
        if (!allBranches && missingBranches.isNotEmpty) {
          skippedBranches.add('${repo.name}: ${missingBranches.join(', ')}');
        }
        for (final branch in branches) {
          requests.add((repo: repo, branch: branch));
        }
      }

      final normalizedText = text.toLowerCase();
      _commitSearchPhase = 'Ricerca nei messaggi dei commit';
      _commitSearchCompleted = 0;
      _commitSearchTotal = requests.length;
      notifyListeners();
      for (var index = 0; index < requests.length; index += concurrency) {
        final chunk = requests.skip(index).take(concurrency);
        final results = await Future.wait(chunk.map((request) async {
          try {
            final commits = await _client!.getCommitsForBranch(
              request.repo.id,
              request.branch,
              from: from,
              to: to,
            );
            return (request: request, commits: commits, error: null as Object?);
          } catch (error) {
            return (request: request, commits: <Commit>[], error: error);
          }
        }));
        for (final result in results) {
          if (result.error != null) {
            searchErrors.add(
              '${result.request.repo.name}/${result.request.branch}: ${result.error}',
            );
            continue;
          }
          for (final commit in result.commits.where((commit) =>
              commit.comment?.toLowerCase().contains(normalizedText) ??
              false)) {
            final repo = result.request.repo;
            final branch = result.request.branch;
            final key = '${repo.id}:${commit.commitId}';
            final existing = matches[key];
            matches[key] = existing?.addBranch(branch) ??
                CommitSearchResult(
                  repositoryId: repo.id,
                  repositoryName: repo.name,
                  commitId: commit.commitId,
                  message: commit.comment ?? '',
                  author: commit.author?.name ?? '',
                  date: commit.date == null
                      ? null
                      : DateTime.tryParse(commit.date!),
                  branches: {branch},
                  webUrl: '${repo.remoteUrl ?? ''}/commit/${commit.commitId}',
                );
          }
        }
        _commitSearchCompleted += results.length;
        notifyListeners();
      }
      _commitSearchResults = matches.values.toList()
        ..sort((left, right) => (right.date ?? DateTime(1970))
            .compareTo(left.date ?? DateTime(1970)));
      final warnings = <String>[
        if (skippedBranches.isNotEmpty)
          'Branch non presenti e ignorate: ${skippedBranches.join(' · ')}',
        if (searchErrors.isNotEmpty)
          'Problemi durante l' 'analisi: ${searchErrors.join(' · ')}',
      ];
      if (warnings.isNotEmpty) {
        _commitSearchError = warnings.join('\n');
      }
    } catch (error) {
      _commitSearchError = 'Errore durante la ricerca commit: $error';
    } finally {
      _isSearchingCommits = false;
      notifyListeners();
    }
  }

  // Run comparison
  Future<void> runComparison() async {
    if (_client == null) {
      _errorMessage = 'Please load repositories first';
      notifyListeners();
      return;
    }

    if (_selectedRepoIds.isEmpty) {
      _errorMessage = 'Please select at least one repository';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final selectedRepos =
          _repositories.where((r) => _selectedRepoIds.contains(r.id)).toList();

      const parallelLimit = 5;
      final resolver = RefResolver(_client!);

      // Resolve refs in parallel (max 5 at a time)
      final sourceResolved = await resolver.resolveRefsForReposParallel(
        selectedRepos,
        _sourceRef.type,
        _sourceRef.value,
        concurrency: parallelLimit,
      );

      final targetResolved = await resolver.resolveRefsForReposParallel(
        selectedRepos,
        _targetRef.type,
        _targetRef.value,
        concurrency: parallelLimit,
      );

      // Get diffs in parallel (max 5 at a time)
      final diffService = DiffService(_client!);
      _diffResults = await diffService.getDiffsForReposParallel(
        selectedRepos,
        sourceResolved,
        targetResolved,
        _sourceRef.type,
        _targetRef.type,
        concurrency: parallelLimit,
      );

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error running comparison: $e';
      _diffResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save configuration
  Future<void> saveConfiguration() async {
    await _storage.saveConfig({
      'base_url': _baseUrl,
      'organization': _organization,
      'project': _project,
      'username': _username,
      'selected_repo_ids': _selectedRepoIds.toList(),
      'source': _sourceRef.toJson(),
      'target': _targetRef.toJson(),
    });
  }

  // Project management
  Future<void> addProject(ProjectConfig project) async {
    _projects.add(project);
    await _storage.saveProjects(_projects);
    notifyListeners();
  }

  Future<void> updateProject(ProjectConfig project) async {
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      _projects[index] = project;
      await _storage.saveProjects(_projects);
      notifyListeners();
    }
  }

  Future<void> deleteProject(String projectId) async {
    _projects.removeWhere((p) => p.id == projectId);
    await _storage.saveProjects(_projects);
    if (_currentProjectId == projectId) {
      _currentProjectId = null;
    }
    notifyListeners();
  }

  void loadProject(ProjectConfig project) {
    _baseUrl = project.baseUrl ?? '';
    _organization = project.organization;
    _project = project.project;
    _username = project.username ?? '';
    _pat = project.pat ?? '';
    _currentProjectId = project.id;
    _repositories = [];
    _selectedRepoIds.clear();
    _diffResults = [];
    _client = null;
    _allPullRequests = [];
    _pullRequestRepositoryErrors = {};
    _currentPullRequestUser = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Svuota i risultati del confronto (ripristina: non vedere nulla).
  void clearDiffResults() {
    _diffResults = [];
    notifyListeners();
  }
}
