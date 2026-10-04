import 'lesson_media_delivery.dart';

enum MediaPlayerSample {
  video(
    'VIDEO',
    'Video',
    'A moment to explore',
    'assets/media-preview/video.mp4',
    'A 40-second animated sample. Try play, pause, the timeline, 10-second jumps and playback speed. It has no sound.',
  ),
  audio(
    'AUDIO',
    'Audio',
    'Listening practice controls',
    'assets/media-preview/audio.m4a',
    'A 40-second sample of soft tones, not a lesson recording. Start with a comfortable volume, then try seeking and playback speed.',
  ),
  image(
    'IMAGE',
    'Image',
    'Explore an illustration',
    'assets/learning-hero.png',
    'An illustrative image, not a student record. Pinch or scroll to zoom, drag to move, then use Reset zoom.',
  ),
  pdf(
    'PDF',
    'PDF',
    'Your player guide',
    'assets/media-preview/guide.pdf',
    'A two-page sample guide. Try the page arrows, scrolling and zoom controls without leaving the app.',
  ),
  text(
    'TEXT',
    'Text',
    'A practice checklist',
    'assets/media-preview/checklist.txt',
    'Read and select this sample text inside the viewer. No course or upload is needed.',
  );

  const MediaPlayerSample(
    this.kind,
    this.label,
    this.title,
    this.assetPath,
    this.instructions,
  );
  final String kind, label, title, assetPath, instructions;

  LessonMediaDelivery get delivery => LessonMediaDelivery(
    uri: Uri(scheme: 'asset', path: assetPath),
    assetPath: assetPath,
    kind: kind,
    title: title,
    expiresAt: null,
    downloadAllowed: false,
  );
}
