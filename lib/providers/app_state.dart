import 'package:flutter/foundation.dart';
import '../models/azure_models.dart';
import '../services/azure_devops_client.dart';
import '../services/ref_resolver.dart';
import '../services/diff_service.dart';
import '../services/storage_service.dart';

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
    if (_organization.isEmpty || _project.isEmpty || _pat.isEmpty) {
      _errorMessage = 'Please fill in all required fields';
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
      final selectedRepos = _repositories
          .where((r) => _selectedRepoIds.contains(r.id))
          .toList();

      final resolver = RefResolver(_client!);
      
      // Resolve refs
      final sourceResolved = await resolver.resolveRefsForRepos(
        selectedRepos,
        _sourceRef.type,
        _sourceRef.value,
      );
      
      final targetResolved = await resolver.resolveRefsForRepos(
        selectedRepos,
        _targetRef.type,
        _targetRef.value,
      );

      // Get diffs
      final diffService = DiffService(_client!);
      _diffResults = await diffService.getDiffsForRepos(
        selectedRepos,
        sourceResolved,
        targetResolved,
        _sourceRef.type,
        _targetRef.type,
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
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
