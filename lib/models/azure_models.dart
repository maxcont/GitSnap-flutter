import 'package:json_annotation/json_annotation.dart';

part 'azure_models.g.dart';

/// Project configuration
@JsonSerializable()
class ProjectConfig {
  final String id;
  final String name;
  final String organization;
  final String project;
  final String? baseUrl;
  final String? username;
  final String? pat;

  ProjectConfig({
    required this.id,
    required this.name,
    required this.organization,
    required this.project,
    this.baseUrl,
    this.username,
    this.pat,
  });

  factory ProjectConfig.fromJson(Map<String, dynamic> json) =>
      _$ProjectConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ProjectConfigToJson(this);

  ProjectConfig copyWith({
    String? id,
    String? name,
    String? organization,
    String? project,
    String? baseUrl,
    String? username,
    String? pat,
  }) {
    return ProjectConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      organization: organization ?? this.organization,
      project: project ?? this.project,
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      pat: pat ?? this.pat,
    );
  }
}

/// Repository model
@JsonSerializable()
class Repository {
  final String id;
  final String name;
  final String? defaultBranch;
  final String? remoteUrl;

  Repository({
    required this.id,
    required this.name,
    this.defaultBranch,
    this.remoteUrl,
  });

  factory Repository.fromJson(Map<String, dynamic> json) =>
      _$RepositoryFromJson(json);
  Map<String, dynamic> toJson() => _$RepositoryToJson(this);
}

/// Commit model
@JsonSerializable()
class Commit {
  final String commitId;
  final String? comment;
  final CommitAuthor? author;
  final String? date;

  Commit({
    required this.commitId,
    this.comment,
    this.author,
    this.date,
  });

  factory Commit.fromJson(Map<String, dynamic> json) => _$CommitFromJson(json);
  Map<String, dynamic> toJson() => _$CommitToJson(this);
}

@JsonSerializable()
class CommitAuthor {
  final String name;
  final String? email;

  CommitAuthor({required this.name, this.email});

  factory CommitAuthor.fromJson(Map<String, dynamic> json) =>
      _$CommitAuthorFromJson(json);
  Map<String, dynamic> toJson() => _$CommitAuthorToJson(this);
}

/// Reference types
enum RefType {
  branch,
  tagPattern,
  commit,
}

/// Reference configuration
class RefConfig {
  final RefType type;
  final String value;

  RefConfig({required this.type, required this.value});

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'value': value,
      };

  factory RefConfig.fromJson(Map<String, dynamic> json) {
    return RefConfig(
      type: RefType.values[json['type'] as int],
      value: json['value'] as String,
    );
  }
}

/// Diff result status
enum DiffStatus {
  aligned,
  divergent,
  error,
}

/// Diff result model
@JsonSerializable()
class DiffResult {
  final String repoId;
  final String repoName;
  final DiffStatus status;
  final int commitCount;
  final int sourceOnlyCommitCount;
  final int targetOnlyCommitCount;
  final int fileCount;
  final String? sourceRef;
  final String? targetRef;
  final String? sourceCommit;
  final String? targetCommit;
  final String? sourceCommitMessage;
  final String? targetCommitMessage;
  final String? sourceCommitAuthor;
  final String? targetCommitAuthor;
  final String? sourceCommitDate;
  final String? targetCommitDate;
  final List<Commit>? commits;
  final List<Commit>? targetCommits;
  final List<String>? files;
  final String? note;

  DiffResult({
    required this.repoId,
    required this.repoName,
    required this.status,
    this.commitCount = 0,
    this.sourceOnlyCommitCount = 0,
    this.targetOnlyCommitCount = 0,
    this.fileCount = 0,
    this.sourceRef,
    this.targetRef,
    this.sourceCommit,
    this.targetCommit,
    this.sourceCommitMessage,
    this.targetCommitMessage,
    this.sourceCommitAuthor,
    this.targetCommitAuthor,
    this.sourceCommitDate,
    this.targetCommitDate,
    this.commits,
    this.targetCommits,
    this.files,
    this.note,
  });

  factory DiffResult.fromJson(Map<String, dynamic> json) =>
      _$DiffResultFromJson(json);
  Map<String, dynamic> toJson() => _$DiffResultToJson(this);
}
