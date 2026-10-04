import 'package:flutter/material.dart';
import 'lesson_playback_tools.dart';
import 'media_player_samples.dart';

/// The lesson's player remains visible before a stream has been loaded.
class LessonPlayerEntry extends StatelessWidget {
  const LessonPlayerEntry({
    super.key,
    this.resourceTitle,
    this.audio = false,
    this.onOpen,
    this.onSample,
    this.onFocus,
    this.focusView = false,
  });

  final String? resourceTitle;
  final bool audio, focusView;
  final VoidCallback? onOpen, onFocus;
  final ValueChanged<MediaPlayerSample>? onSample;

  @override
  Widget build(BuildContext context) {
    final hasMedia = resourceTitle != null;
    final open = hasMedia
        ? onOpen
        : onSample == null
        ? null
        : () => onSample!(MediaPlayerSample.video);
    return Material(
      key: const ValueKey('lesson-player-entry'),
      color: playbackPanel,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.play_circle_outline, color: playbackAccent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lesson player',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: BoxConstraints(minHeight: focusView ? 340 : 220),
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.4,
                colors: [Color(0xFF292C31), Color(0xFF0D0E10)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  audio ? Icons.headphones_outlined : Icons.ondemand_video,
                  color: playbackAccent,
                  size: 44,
                ),
                const SizedBox(height: 14),
                Text(
                  resourceTitle ?? 'Your lesson player is ready',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasMedia
                      ? 'Load this lesson resource here, then press Play.'
                      : 'No playable video or audio is available yet. Try the controls here with a sample, or read the lesson notes below.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: playbackMuted, height: 1.6),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('load-lesson-player'),
                      onPressed: open,
                      style: FilledButton.styleFrom(
                        backgroundColor: playbackAccent,
                        foregroundColor: const Color(0xFF191919),
                        disabledBackgroundColor: Colors.white12,
                        disabledForegroundColor: Colors.white38,
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        hasMedia
                            ? audio
                                  ? 'Load lesson audio'
                                  : 'Load lesson video'
                            : 'Load sample video',
                      ),
                    ),
                    if (!hasMedia)
                      OutlinedButton.icon(
                        key: const ValueKey('load-lesson-sample-audio'),
                        onPressed: onSample == null
                            ? null
                            : () => onSample!(MediaPlayerSample.audio),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: playbackAccent,
                          disabledForegroundColor: Colors.white38,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        icon: const Icon(Icons.headphones_outlined),
                        label: const Text('Load sample audio'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          LessonPlaybackTools(
            speed: 1,
            onPlay: open,
            onFocus: onFocus,
            focusView: focusView,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            child: Text(
              hasMedia
                  ? 'Media plays inside this lesson. Your notes and other resources stay here.'
                  : 'Samples are not lesson content and do not save learning progress.',
              style: const TextStyle(color: playbackMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
