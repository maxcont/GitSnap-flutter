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

/// Single variable (name, value, secret flag)
class ReleaseVariable {
  final String name;
  final String value;
  final bool isSecret;

  ReleaseVariable({
    required this.name,
    required this.value,
    this.isSecret = false,
  });

  String get displayValue => isSecret ? '********' : value;
}

/// Two variable sets diff for comparison
class VariableDiffEntry {
  final String name;
  final String? valueA;
  final String? valueB;
  final bool onlyInA;
  final bool onlyInB;
  final bool different;

  VariableDiffEntry({
    required this.name,
    this.valueA,
    this.valueB,
    this.onlyInA = false,
    this.onlyInB = false,
    this.different = false,
  });
}
