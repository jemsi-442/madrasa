import 'dart:typed_data';

const lessonUploadLimit = 50 * 1024 * 1024;
const lessonVideoUploadLimit = 250 * 1024 * 1024;

int lessonUploadLimitFor(String? format) =>
    format == 'mp4' ? lessonVideoUploadLimit : lessonUploadLimit;

typedef LessonUploader =
    Future<dynamic> Function(
      String lessonId,
      String title,
      String format,
      String visibility,
      Uint8List bytes,
    );

String? lessonFileFormat(String name) {
  final extension = name.split('.').last.toLowerCase();
  if (extension == 'jpeg') return 'jpg';
  return const ['pdf', 'png', 'jpg', 'mp4', 'mp3', 'wav'].contains(extension)
      ? extension
      : null;
}
