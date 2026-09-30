import 'package:flutter/material.dart';
import '../lesson_media_delivery.dart';

const inlineLessonMediaSupported = false;

class LessonMediaSurface extends StatelessWidget {
  const LessonMediaSurface({
    super.key,
    required this.delivery,
    required this.onReady,
    required this.onError,
  });
  final LessonMediaDelivery delivery;
  final VoidCallback onReady, onError;
  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Inline playback is available in the web portal. Use Open in browser on this device.',
    ),
  );
}
