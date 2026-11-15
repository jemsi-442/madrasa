import 'dart:typed_data';

const lessonUploadLimit = 50 * 1024 * 1024;

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
