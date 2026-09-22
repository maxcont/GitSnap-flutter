/// A single row from the CAST component history table: a build/version
/// number and its assigned Quality Rating (A/B/C/D/F).
class CastBuildRating {
  final String build;
  final String rating;

  CastBuildRating({required this.build, required this.rating});
}

/// Raised when the CAST page cannot be loaded or read (network error,
/// timeout, or an unexpected page response).
class CastClientError implements Exception {
  final String message;
  CastClientError(this.message);

  @override
  String toString() => 'CastClientError: $message';
}
