import '../models/build_environment_result.dart';
import '../models/release_models.dart';
import 'azure_devops_client.dart';

/// Looks up, for a given repository and build/version number, in which
/// environments (Sviluppo / Collaudo / Pre-Esercizio / Esercizio) that
/// build was successfully deployed.
class BuildSearchService {
  /// Azure DevOps release folder path per environment, in display order.
  static const Map<String, String> environmentFolders = {
    'Sviluppo': r'\Sviluppo',
    'Collaudo': r'\Collaudo',
    'Pre-Esercizio': r'\Pre-Esercizio',
    'Esercizio': r'\Esercizio',
  };

  final AzureDevOpsClient client;

  BuildSearchService(this.client);

  /// Checks one environment for the given repository/build combination.
  Future<BuildEnvironmentResult> checkEnvironment({
    required String folder,
    required String repositoryName,
    required String buildQuery,
    DateTime? minCreatedTime,
    DateTime? maxCreatedTime,
  }) async {
    final definitions = await client.getReleaseDefinitions(path: folder);
    final definition = selectDefinitionForRepo(definitions, repositoryName);
    if (definition == null) {
      return const BuildEnvironmentResult.pipelineMissing();
    }

    final releases = await client.getReleases(
      definition.id,
      minCreatedTime: minCreatedTime,
      maxCreatedTime: maxCreatedTime,
    );
    final match = findMatchingRelease(releases, buildQuery);
    if (match == null) {
      return const BuildEnvironmentResult.notFound();
    }
    return BuildEnvironmentResult.found(match);
  }

  /// Picks the release definition in [definitions] whose name best matches
  /// [repositoryName]: any definition whose name contains the repository
  /// name (case-insensitive), preferring the shortest (narrowest) name.
  static ReleaseDefinitionInfo? selectDefinitionForRepo(
    List<ReleaseDefinitionInfo> definitions,
    String repositoryName,
  ) {
    final needle = repositoryName.trim().toLowerCase();
    if (needle.isEmpty) return null;
    final matches = definitions
        .where((d) => d.name.toLowerCase().contains(needle))
        .toList()
      ..sort((a, b) => a.name.length.compareTo(b.name.length));
    return matches.isEmpty ? null : matches.first;
  }

  /// Case-insensitive "contains" match between an artifact version and the
  /// user-provided search text. An empty search text never matches.
  static bool buildMatches(String artifactVersion, String searchText) {
    final needle = searchText.trim().toLowerCase();
    if (needle.isEmpty) return false;
    return artifactVersion.toLowerCase().contains(needle);
  }

  /// Among succeeded [releases] whose artifact version matches
  /// [searchText], returns the most recently created one, or null if none
  /// match.
  static ReleaseSummary? findMatchingRelease(
    List<ReleaseSummary> releases,
    String searchText,
  ) {
    final matches = releases
        .where((r) =>
            r.succeeded && buildMatches(r.artifactVersion, searchText))
        .toList()
      ..sort((a, b) {
        final aDate = a.createdOn;
        final bDate = b.createdOn;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    return matches.isEmpty ? null : matches.first;
  }
}
