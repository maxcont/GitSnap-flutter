class CommitSearchResult {
  final String repositoryId;
  final String repositoryName;
  final String commitId;
  final String message;
  final String author;
  final DateTime? date;
  final Set<String> branches;
  final String webUrl;

  CommitSearchResult({
    required this.repositoryId,
    required this.repositoryName,
    required this.commitId,
    required this.message,
    required this.author,
    required this.date,
    required Set<String> branches,
    required this.webUrl,
  }) : branches = Set.unmodifiable(branches);

  CommitSearchResult addBranch(String branch) => CommitSearchResult(
        repositoryId: repositoryId,
        repositoryName: repositoryName,
        commitId: commitId,
        message: message,
        author: author,
        date: date,
        branches: {...branches, branch},
        webUrl: webUrl,
      );
}
