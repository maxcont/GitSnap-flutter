/// Release definition (pipeline) summary
class ReleaseDefinitionInfo {
  final int id;
  final String name;
  final String? path;

  ReleaseDefinitionInfo({
    required this.id,
    required this.name,
    this.path,
  });
}

/// Single variable (name, value, secret flag, scope/ambito)
class ReleaseVariable {
  /// Azure UI label for pipeline-level variables (root `variables` block).
  static const releaseScope = 'Versione';

  final String name;
  final String value;
  final bool isSecret;
  final String scope;

  ReleaseVariable({
    required this.name,
    required this.value,
    this.isSecret = false,
    this.scope = releaseScope,
  });

  String get displayValue => isSecret ? '********' : value;

  /// Unique key when the same name exists in different scopes.
  String get mapKey => releaseVariableKey(scope, name);

  static String releaseVariableKey(String scope, String name) => '$scope\x00$name';
}

/// Two variable sets diff for comparison
class VariableDiffEntry {
  final String name;
  final String scope;
  final String? valueA;
  final String? valueB;
  final bool onlyInA;
  final bool onlyInB;
  final bool different;

  VariableDiffEntry({
    required this.name,
    required this.scope,
    this.valueA,
    this.valueB,
    this.onlyInA = false,
    this.onlyInB = false,
    this.different = false,
  });
}

/// Summary of a single release (rilascio) returned by the Release API,
/// used to check whether a given build was deployed to an environment.
class ReleaseSummary {
  final int id;
  final String name;
  final DateTime? createdOn;
  final String artifactVersion;
  final bool succeeded;

  ReleaseSummary({
    required this.id,
    required this.name,
    required this.createdOn,
    required this.artifactVersion,
    required this.succeeded,
  });
}
