// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'azure_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProjectConfig _$ProjectConfigFromJson(Map<String, dynamic> json) =>
    ProjectConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      organization: json['organization'] as String,
      project: json['project'] as String,
      baseUrl: json['baseUrl'] as String?,
      username: json['username'] as String?,
      pat: json['pat'] as String?,
    );

Map<String, dynamic> _$ProjectConfigToJson(ProjectConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'organization': instance.organization,
      'project': instance.project,
      'baseUrl': instance.baseUrl,
      'username': instance.username,
      'pat': instance.pat,
    };

Repository _$RepositoryFromJson(Map<String, dynamic> json) => Repository(
      id: json['id'] as String,
      name: json['name'] as String,
      defaultBranch: json['defaultBranch'] as String?,
      remoteUrl: json['remoteUrl'] as String?,
    );

Map<String, dynamic> _$RepositoryToJson(Repository instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'defaultBranch': instance.defaultBranch,
      'remoteUrl': instance.remoteUrl,
    };

Commit _$CommitFromJson(Map<String, dynamic> json) => Commit(
      commitId: json['commitId'] as String,
      comment: json['comment'] as String?,
      author: json['author'] == null
          ? null
          : CommitAuthor.fromJson(json['author'] as Map<String, dynamic>),
      date: json['date'] as String?,
    );

Map<String, dynamic> _$CommitToJson(Commit instance) => <String, dynamic>{
      'commitId': instance.commitId,
      'comment': instance.comment,
      'author': instance.author,
      'date': instance.date,
    };

CommitAuthor _$CommitAuthorFromJson(Map<String, dynamic> json) => CommitAuthor(
      name: json['name'] as String,
      email: json['email'] as String?,
    );

Map<String, dynamic> _$CommitAuthorToJson(CommitAuthor instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
    };

DiffResult _$DiffResultFromJson(Map<String, dynamic> json) => DiffResult(
      repoId: json['repoId'] as String,
      repoName: json['repoName'] as String,
      status: $enumDecode(_$DiffStatusEnumMap, json['status']),
      commitCount: json['commitCount'] as int? ?? 0,
      sourceOnlyCommitCount: json['sourceOnlyCommitCount'] as int? ?? 0,
      targetOnlyCommitCount: json['targetOnlyCommitCount'] as int? ?? 0,
      fileCount: json['fileCount'] as int? ?? 0,
      sourceRef: json['sourceRef'] as String?,
      targetRef: json['targetRef'] as String?,
      sourceCommit: json['sourceCommit'] as String?,
      targetCommit: json['targetCommit'] as String?,
      sourceCommitMessage: json['sourceCommitMessage'] as String?,
      targetCommitMessage: json['targetCommitMessage'] as String?,
      sourceCommitAuthor: json['sourceCommitAuthor'] as String?,
      targetCommitAuthor: json['targetCommitAuthor'] as String?,
      sourceCommitDate: json['sourceCommitDate'] as String?,
      targetCommitDate: json['targetCommitDate'] as String?,
      commits: (json['commits'] as List<dynamic>?)
          ?.map((e) => Commit.fromJson(e as Map<String, dynamic>))
          .toList(),
      targetCommits: (json['targetCommits'] as List<dynamic>?)
          ?.map((e) => Commit.fromJson(e as Map<String, dynamic>))
          .toList(),
      files:
          (json['files'] as List<dynamic>?)?.map((e) => e as String).toList(),
      note: json['note'] as String?,
    );

Map<String, dynamic> _$DiffResultToJson(DiffResult instance) =>
    <String, dynamic>{
      'repoId': instance.repoId,
      'repoName': instance.repoName,
      'status': _$DiffStatusEnumMap[instance.status]!,
      'commitCount': instance.commitCount,
      'sourceOnlyCommitCount': instance.sourceOnlyCommitCount,
      'targetOnlyCommitCount': instance.targetOnlyCommitCount,
      'fileCount': instance.fileCount,
      'sourceRef': instance.sourceRef,
      'targetRef': instance.targetRef,
      'sourceCommit': instance.sourceCommit,
      'targetCommit': instance.targetCommit,
      'sourceCommitMessage': instance.sourceCommitMessage,
      'targetCommitMessage': instance.targetCommitMessage,
      'sourceCommitAuthor': instance.sourceCommitAuthor,
      'targetCommitAuthor': instance.targetCommitAuthor,
      'sourceCommitDate': instance.sourceCommitDate,
      'targetCommitDate': instance.targetCommitDate,
      'commits': instance.commits,
      'targetCommits': instance.targetCommits,
      'files': instance.files,
      'note': instance.note,
    };

const _$DiffStatusEnumMap = {
  DiffStatus.aligned: 'aligned',
  DiffStatus.divergent: 'divergent',
  DiffStatus.error: 'error',
};

K $enumDecode<K, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, enumValues.values.first);
    },
  ).key;
}
