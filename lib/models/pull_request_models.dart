enum PullRequestStatus {
  active,
  draft,
  completed,
  abandoned,
}

class PullRequestIdentity {
  final String id;
  final String displayName;
  final String? uniqueName;
  final String? url;
  final String? imageUrl;

  const PullRequestIdentity({
    required this.id,
    required this.displayName,
    this.uniqueName,
    this.url,
    this.imageUrl,
  });

  factory PullRequestIdentity.fromJson(Map<String, dynamic> json) {
    final links = _asMap(json['_links']);
    final uniqueName =
        _stringOrNull(json['uniqueName']) ?? _stringOrNull(json['email']);
    final displayName = _stringOrNull(json['displayName']) ??
        _stringOrNull(json['name']) ??
        uniqueName ??
        'Unknown';

    return PullRequestIdentity(
      id: _stringOrNull(json['id']) ?? uniqueName ?? displayName,
      displayName: displayName,
      uniqueName: uniqueName,
      url: _stringOrNull(json['url']),
      imageUrl: _stringOrNull(json['imageUrl']) ??
          _stringOrNull(_asMap(links['avatar'])['href']),
    );
  }
}

class PullRequestReviewer extends PullRequestIdentity {
  final int vote;
  final bool isRequired;
  final bool hasDeclined;
  final bool isFlagged;

  const PullRequestReviewer({
    required super.id,
    required super.displayName,
    super.uniqueName,
    super.url,
    super.imageUrl,
    this.vote = 0,
    this.isRequired = false,
    this.hasDeclined = false,
    this.isFlagged = false,
  });

  factory PullRequestReviewer.fromJson(Map<String, dynamic> json) {
    final identity = PullRequestIdentity.fromJson(json);

    return PullRequestReviewer(
      id: identity.id,
      displayName: identity.displayName,
      uniqueName: identity.uniqueName,
      url: identity.url,
      imageUrl: identity.imageUrl,
      vote: _parseInt(json['vote']) ?? 0,
      isRequired: _parseBool(json['isRequired']) ?? false,
      hasDeclined: _parseBool(json['hasDeclined']) ?? false,
      isFlagged: _parseBool(json['isFlagged']) ?? false,
    );
  }
}

class PullRequestSummary {
  final int id;
  final String title;
  final PullRequestStatus status;
  final String repositoryId;
  final String repositoryName;
  final PullRequestIdentity author;
  final List<PullRequestReviewer> reviewers;
  final String sourceBranch;
  final String targetBranch;
  final DateTime createdAt;
  final DateTime? closedAt;
  final DateTime? updatedAt;
  final String webUrl;

  PullRequestSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.repositoryId,
    required this.repositoryName,
    required this.author,
    required List<PullRequestReviewer> reviewers,
    required this.sourceBranch,
    required this.targetBranch,
    required this.createdAt,
    this.closedAt,
    this.updatedAt,
    required this.webUrl,
  }) : reviewers = List.unmodifiable(reviewers);

  factory PullRequestSummary.fromJson(Map<String, dynamic> json) {
    final repository = _asMap(json['repository']);
    final createdAt = _parseDateTime(json['creationDate']) ??
        _parseDateTime(json['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final closedAt =
        _parseDateTime(json['closedDate']) ?? _parseDateTime(json['closedAt']);

    return PullRequestSummary(
      id: _parseInt(json['pullRequestId']) ??
          _parseInt(json['codeReviewId']) ??
          0,
      title: _stringOrNull(json['title']) ?? '',
      status: _parseStatus(json),
      repositoryId: _stringOrNull(repository['id']) ?? '',
      repositoryName: _stringOrNull(repository['name']) ??
          _stringOrNull(repository['id']) ??
          '',
      author: PullRequestIdentity.fromJson(_asMap(json['createdBy'])),
      reviewers: _asList(json['reviewers'])
          .map(_asMap)
          .where((reviewer) => reviewer.isNotEmpty)
          .map(PullRequestReviewer.fromJson)
          .toList(),
      sourceBranch: _displayBranch(
        _stringOrNull(json['sourceRefName']) ??
            _stringOrNull(json['sourceBranch']) ??
            '',
      ),
      targetBranch: _displayBranch(
        _stringOrNull(json['targetRefName']) ??
            _stringOrNull(json['targetBranch']) ??
            '',
      ),
      createdAt: createdAt,
      closedAt: closedAt,
      updatedAt: _parseDateTime(json['lastUpdatedDate']) ??
          _parseDateTime(json['updatedAt']) ??
          closedAt ??
          createdAt,
      webUrl: _resolveWebUrl(
        json,
        repositoryId: _stringOrNull(repository['id']) ?? '',
        repositoryName: _stringOrNull(repository['name']) ??
            _stringOrNull(repository['id']) ??
            '',
        pullRequestId: _parseInt(json['pullRequestId']) ??
            _parseInt(json['codeReviewId']) ??
            0,
      ),
    );
  }
}

class PullRequestDetails extends PullRequestSummary {
  final String? description;
  final String mergeStatus;
  final String? mergeFailureType;
  final String? mergeFailureMessage;
  final String? policyStatus;
  final DateTime? completionQueueTime;
  final bool supportsIterations;
  final PullRequestIdentity? autoCompleteSetBy;
  final PullRequestMetrics? metrics;

  PullRequestDetails({
    required super.id,
    required super.title,
    required super.status,
    required super.repositoryId,
    required super.repositoryName,
    required super.author,
    required super.reviewers,
    required super.sourceBranch,
    required super.targetBranch,
    required super.createdAt,
    super.closedAt,
    super.updatedAt,
    required super.webUrl,
    this.description,
    this.mergeStatus = 'notSet',
    this.mergeFailureType,
    this.mergeFailureMessage,
    this.policyStatus,
    this.completionQueueTime,
    this.supportsIterations = false,
    this.autoCompleteSetBy,
    this.metrics,
  });

  factory PullRequestDetails.fromJson(Map<String, dynamic> json) {
    final summary = PullRequestSummary.fromJson(json);
    final metricsJson = _asMap(json['metrics']);
    final autoCompleteSetByJson = _asMap(json['autoCompleteSetBy']);

    return PullRequestDetails(
      id: summary.id,
      title: summary.title,
      status: summary.status,
      repositoryId: summary.repositoryId,
      repositoryName: summary.repositoryName,
      author: summary.author,
      reviewers: summary.reviewers,
      sourceBranch: summary.sourceBranch,
      targetBranch: summary.targetBranch,
      createdAt: summary.createdAt,
      closedAt: summary.closedAt,
      updatedAt: summary.updatedAt,
      webUrl: summary.webUrl,
      description: _stringOrNull(json['description']),
      mergeStatus: _stringOrNull(json['mergeStatus']) ?? 'notSet',
      mergeFailureType: _stringOrNull(json['mergeFailureType']),
      mergeFailureMessage: _stringOrNull(json['mergeFailureMessage']),
      policyStatus: _stringOrNull(json['policyStatus']) ??
          _stringOrNull(json['policyEvaluationStatus']) ??
          _stringOrNull(_asMap(json['completionOptions'])['policyStatus']),
      completionQueueTime: _parseDateTime(json['completionQueueTime']),
      supportsIterations: _parseBool(json['supportsIterations']) ?? false,
      autoCompleteSetBy: autoCompleteSetByJson.isEmpty
          ? null
          : PullRequestIdentity.fromJson(autoCompleteSetByJson),
      metrics:
          metricsJson.isEmpty ? null : PullRequestMetrics.fromJson(metricsJson),
    );
  }

  PullRequestDetails copyWith({
    String? description,
    String? mergeStatus,
    String? mergeFailureType,
    String? mergeFailureMessage,
    String? policyStatus,
    DateTime? completionQueueTime,
    bool? supportsIterations,
    PullRequestIdentity? autoCompleteSetBy,
    PullRequestMetrics? metrics,
  }) {
    return PullRequestDetails(
      id: id,
      title: title,
      status: status,
      repositoryId: repositoryId,
      repositoryName: repositoryName,
      author: author,
      reviewers: reviewers,
      sourceBranch: sourceBranch,
      targetBranch: targetBranch,
      createdAt: createdAt,
      closedAt: closedAt,
      updatedAt: updatedAt,
      webUrl: webUrl,
      description: description ?? this.description,
      mergeStatus: mergeStatus ?? this.mergeStatus,
      mergeFailureType: mergeFailureType ?? this.mergeFailureType,
      mergeFailureMessage: mergeFailureMessage ?? this.mergeFailureMessage,
      policyStatus: policyStatus ?? this.policyStatus,
      completionQueueTime: completionQueueTime ?? this.completionQueueTime,
      supportsIterations: supportsIterations ?? this.supportsIterations,
      autoCompleteSetBy: autoCompleteSetBy ?? this.autoCompleteSetBy,
      metrics: metrics ?? this.metrics,
    );
  }
}

class PullRequestMetrics {
  final int commitCount;
  final int changedFileCount;
  final int threadCount;
  final int commentCount;

  const PullRequestMetrics({
    this.commitCount = 0,
    this.changedFileCount = 0,
    this.threadCount = 0,
    this.commentCount = 0,
  });

  factory PullRequestMetrics.fromJson(Map<String, dynamic> json) {
    return PullRequestMetrics(
      commitCount: _parseInt(json['commitCount']) ??
          _extractCollectionCount(json['commits']) ??
          0,
      changedFileCount: _parseInt(json['changedFileCount']) ??
          _extractCollectionCount(json['files']) ??
          _extractCollectionCount(json['changes']) ??
          0,
      threadCount: _parseInt(json['threadCount']) ??
          _extractCollectionCount(json['threads']) ??
          0,
      commentCount: _parseInt(json['commentCount']) ??
          _extractCommentCount(json['threads']) ??
          _extractCollectionCount(json['comments']) ??
          0,
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map(
      (key, entryValue) => MapEntry(key.toString(), entryValue),
    );
  }

  return const <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  if (value is List) {
    return value;
  }

  return const <dynamic>[];
}

String? _stringOrNull(dynamic value) {
  if (value == null) {
    return null;
  }

  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

int? _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  final normalized = _stringOrNull(value);
  if (normalized == null) {
    return null;
  }

  return int.tryParse(normalized) ?? double.tryParse(normalized)?.toInt();
}

bool? _parseBool(dynamic value) {
  if (value is bool) {
    return value;
  }

  final normalized = _stringOrNull(value)?.toLowerCase();
  if (normalized == 'true') {
    return true;
  }
  if (normalized == 'false') {
    return false;
  }

  return null;
}

DateTime? _parseDateTime(dynamic value) {
  final normalized = _stringOrNull(value);
  if (normalized == null) {
    return null;
  }

  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) {
    return null;
  }

  return parsed.isUtc ? parsed : parsed.toUtc();
}

PullRequestStatus _parseStatus(Map<String, dynamic> json) {
  if ((_stringOrNull(json['status']) ?? '').toLowerCase() == 'active' &&
      _parseBool(json['isDraft']) == true) {
    return PullRequestStatus.draft;
  }

  switch ((_stringOrNull(json['status']) ?? '').toLowerCase()) {
    case 'draft':
      return PullRequestStatus.draft;
    case 'completed':
      return PullRequestStatus.completed;
    case 'abandoned':
      return PullRequestStatus.abandoned;
    case 'active':
    default:
      return PullRequestStatus.active;
  }
}

String _displayBranch(String branchName) {
  return branchName.replaceFirst(RegExp(r'^refs/heads/'), '');
}

String _resolveWebUrl(
  Map<String, dynamic> json, {
  required String repositoryId,
  required String repositoryName,
  required int pullRequestId,
}) {
  final links = _asMap(json['_links']);
  final repository = _asMap(json['repository']);
  final pullRequestIdText = '$pullRequestId';

  final providedWebUrl = _normalizeWebUrl(
    _stringOrNull(_asMap(links['web'])['href']) ??
        _stringOrNull(json['webUrl']),
    repositoryId: repositoryId,
    repositoryName: repositoryName,
    pullRequestId: pullRequestIdText,
  );
  if (providedWebUrl != null) {
    return providedWebUrl;
  }

  final remoteUrl = _stringOrNull(repository['remoteUrl']) ??
      _stringOrNull(json['remoteUrl']);
  if (remoteUrl != null) {
    return '${remoteUrl.replaceFirst(RegExp(r'/$'), '')}/pullrequest/$pullRequestIdText';
  }

  final apiUrl = _stringOrNull(json['url']) ??
      _stringOrNull(_asMap(links['self'])['href']) ??
      _stringOrNull(repository['url']);

  return _normalizeWebUrl(
        apiUrl,
        repositoryId: repositoryId,
        repositoryName: repositoryName,
        pullRequestId: pullRequestIdText,
      ) ??
      apiUrl ??
      '';
}

String? _normalizeWebUrl(
  String? value, {
  required String repositoryId,
  required String repositoryName,
  required String pullRequestId,
}) {
  if (value == null) {
    return null;
  }

  if (!value.contains('/_apis/')) {
    if (value.contains('/pullrequest/')) {
      return value;
    }

    if (value.contains('/_git/')) {
      return '${value.replaceFirst(RegExp(r'/$'), '')}/pullrequest/$pullRequestId';
    }

    return value;
  }

  final uri = Uri.tryParse(value);
  if (uri == null) {
    return value;
  }

  final apiIndex = uri.pathSegments.indexOf('_apis');
  if (apiIndex == -1) {
    return value;
  }

  final projectSegments = uri.pathSegments.take(apiIndex).toList();
  final repositorySegment =
      repositoryName.isNotEmpty ? repositoryName : repositoryId;

  return uri.replace(
    pathSegments: <String>[
      ...projectSegments,
      '_git',
      repositorySegment,
      'pullrequest',
      pullRequestId,
    ],
    query: null,
    fragment: null,
  ).toString();
}

int? _extractCollectionCount(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is List) {
    return value.length;
  }

  final map = _asMap(value);

  final directCount = _parseInt(map['count']);
  if (directCount != null) {
    return directCount;
  }

  for (final key in const [
    'value',
    'changes',
    'commits',
    'threads',
    'comments'
  ]) {
    final nested = map[key];
    if (nested is List) {
      return nested.length;
    }
  }

  return null;
}

int? _extractCommentCount(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is List) {
    return value.fold<int>(0, (total, item) {
      final comments = _asList(_asMap(item)['comments']);
      return total + comments.length;
    });
  }

  final map = _asMap(value);
  final directComments = map['comments'];
  if (directComments is List) {
    return directComments.length;
  }

  if (map['value'] is List) {
    return _extractCommentCount(map['value']);
  }

  if (map['threads'] is List) {
    return _extractCommentCount(map['threads']);
  }

  return null;
}
