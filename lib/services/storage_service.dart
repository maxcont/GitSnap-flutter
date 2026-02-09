import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/azure_models.dart';

class StorageService {
  static const String _configFileName = 'config.json';
  static const String _projectsFileName = 'projects.json';

  Future<Directory> _getDataDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dataDir = Directory('${appDir.path}/GitSnap/data');
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return dataDir;
  }

  /// Load configuration
  Future<Map<String, dynamic>> loadConfig() async {
    try {
      final dataDir = await _getDataDirectory();
      final file = File('${dataDir.path}/$_configFileName');
      
      if (!await file.exists()) {
        return {};
      }

      final contents = await file.readAsString();
      return json.decode(contents) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading config: $e');
      return {};
    }
  }

  /// Save configuration (without PAT)
  Future<void> saveConfig(Map<String, dynamic> config) async {
    try {
      // Remove PAT before saving
      final configToSave = Map<String, dynamic>.from(config);
      configToSave.remove('pat');
      configToSave.remove('PAT');

      final dataDir = await _getDataDirectory();
      final file = File('${dataDir.path}/$_configFileName');
      
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(configToSave),
      );
    } catch (e) {
      print('Error saving config: $e');
    }
  }

  /// Load projects
  Future<List<ProjectConfig>> loadProjects() async {
    try {
      final dataDir = await _getDataDirectory();
      final file = File('${dataDir.path}/$_projectsFileName');
      
      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      final data = json.decode(contents);
      
      List<dynamic> projectsList;
      if (data is Map && data.containsKey('projects')) {
        projectsList = data['projects'] as List;
      } else if (data is List) {
        projectsList = data;
      } else {
        return [];
      }

      return projectsList
          .map((p) => ProjectConfig.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading projects: $e');
      return [];
    }
  }

  /// Save projects
  Future<void> saveProjects(List<ProjectConfig> projects) async {
    try {
      final dataDir = await _getDataDirectory();
      final file = File('${dataDir.path}/$_projectsFileName');
      
      final data = {
        'projects': projects.map((p) => p.toJson()).toList(),
      };

      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
    } catch (e) {
      print('Error saving projects: $e');
    }
  }
}
