import '../models/azure_models.dart';
import 'azure_devops_client.dart';
import 'ref_resolver.dart';

class RefSuggestion {
  final String name;
  final int repositoryCount;

  const RefSuggestion(this.name, this.repositoryCount);
}

/// Branch or tag names available across a set of repositories.
class RefSuggestions {
  /// Ref names (without `refs/heads/` / `refs/tags/`) per repository id.
  final Map<String, Set<String>> refsByRepository;
  final List<String> failedRepositories;
  final int repositoryCount;

  RefSuggestions({
    required this.refsByRepository,
    required this.failedRepositories,
    required this.repositoryCount,
  });

  Map<String, int> get counts {
    final result = <String, int>{};
    for (final refs in refsByRepository.values) {
      for (final ref in refs) {
        result[ref] = (result[ref] ?? 0) + 1;
      }
    }
    return result;
  }
}

class TagPatternPreview {
  final int matchingTags;
  final int matchingRepositories;

  const TagPatternPreview(this.matchingTags, this.matchingRepositories);
}

class RefSuggestionService {
  static const int _concurrency = 5;

  static Future<RefSuggestions> load(
    AzureDevOpsClient client,
    List<Repository> repositories,
    RefType type,
  ) async {
    final prefix = type == RefType.tagPattern ? 'refs/tags/' : 'refs/heads/';
    final refsByRepository = <String, Set<String>>{};
    final failed = <String>[];
    for (var index = 0; index < repositories.length; index += _concurrency) {
      final results = await Future.wait(
          repositories.skip(index).take(_concurrency).map((repo) async {
        try {
          final refs = type == RefType.tagPattern
              ? await client.getTags(repo.id)
              : await client.getBranches(repo.id);
          return (repo: repo, refs: refs, failed: false);
        } catch (_) {
          return (repo: repo, refs: <Map<String, dynamic>>[], failed: true);
        }
      }));
      for (final result in results) {
        if (result.failed) {
          failed.add(result.repo.name);
          continue;
        }
        refsByRepository[result.repo.id] = result.refs
            .map((ref) => (ref['name'] as String? ?? '').replaceFirst(prefix, ''))
            .where((name) => name.isNotEmpty)
            .toSet();
      }
    }
    return RefSuggestions(
      refsByRepository: refsByRepository,
      failedRepositories: failed,
      repositoryCount: repositories.length,
    );
  }

  /// Case-insensitive `contains` filter; refs present in more repositories
  /// come first, then alphabetical.
  static List<RefSuggestion> filter(
    RefSuggestions suggestions,
    String query, {
    int limit = 50,
  }) {
    final normalized = query.trim().toLowerCase();
    final matches = suggestions.counts.entries
        .where((entry) => entry.key.toLowerCase().contains(normalized))
        .map((entry) => RefSuggestion(entry.key, entry.value))
        .toList()
      ..sort((a, b) {
        final byCount = b.repositoryCount.compareTo(a.repositoryCount);
        if (byCount != 0) return byCount;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return matches.take(limit).toList();
  }

  static TagPatternPreview tagPatternPreview(
    RefSuggestions suggestions,
    String pattern,
  ) {
    final trimmed = pattern.trim();
    final tags = <String>{};
    var repositories = 0;
    for (final refs in suggestions.refsByRepository.values) {
      final matching =
          refs.where((tag) => RefResolver.matchesTagPattern(tag, trimmed));
      if (matching.isNotEmpty) repositories++;
      tags.addAll(matching);
    }
    return TagPatternPreview(tags.length, repositories);
  }
}
