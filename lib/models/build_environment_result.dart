import 'release_models.dart';

enum BuildEnvironmentStatus { found, notFound, pipelineMissing }

/// Result of checking whether a given build was successfully deployed to
/// one environment (Sviluppo / Collaudo / Pre-Esercizio / Esercizio).
class BuildEnvironmentResult {
  final BuildEnvironmentStatus status;
  final ReleaseSummary? release;

  const BuildEnvironmentResult.found(ReleaseSummary release)
      : status = BuildEnvironmentStatus.found,
        release = release;

  const BuildEnvironmentResult.notFound()
      : status = BuildEnvironmentStatus.notFound,
        release = null;

  const BuildEnvironmentResult.pipelineMissing()
      : status = BuildEnvironmentStatus.pipelineMissing,
        release = null;
}
