/// A retained form must be reopened rather than retrying its old version token.
class CurriculumSaveConflict implements Exception {
  const CurriculumSaveConflict(this.message);

  final String message;
}
