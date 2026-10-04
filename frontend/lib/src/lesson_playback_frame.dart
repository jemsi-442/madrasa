import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lesson_playback_tools.dart';

/// Dark playback stage shared by the browser and the mobile media engine.
class LessonPlaybackFrame extends StatefulWidget {
  const LessonPlaybackFrame({
    super.key,
    required this.child,
    required this.controls,
    required this.ready,
    required this.failed,
    this.audio = false,
    this.buffering = false,
    this.playing = false,
    this.onPlay,
    this.onBackward,
    this.onForward,
    this.onMute,
  });
  final Widget child, controls;
  final bool ready, failed, audio, buffering, playing;
  final VoidCallback? onPlay, onBackward, onForward, onMute;
  @override
  State<LessonPlaybackFrame> createState() => _LessonPlaybackFrameState();
}

class _LessonPlaybackFrameState extends State<LessonPlaybackFrame> {
  final keyboard = FocusNode(debugLabel: 'Media playback shortcuts');
  @override
  void dispose() {
    keyboard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: keyboard,
    onKeyEvent: (node, event) {
      // Sliders and buttons keep their own keyboard interaction.
      if (!node.hasPrimaryFocus ||
          event is! KeyDownEvent ||
          HardwareKeyboard.instance.isAltPressed ||
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed ||
          !widget.ready ||
          widget.failed) {
        return KeyEventResult.ignored;
      }
      final action = switch (event.logicalKey) {
        LogicalKeyboardKey.space => widget.onPlay,
        LogicalKeyboardKey.arrowLeft => widget.onBackward,
        LogicalKeyboardKey.arrowRight => widget.onForward,
        LogicalKeyboardKey.keyM => widget.onMute,
        _ => null,
      };
      if (action == null) return KeyEventResult.ignored;
      action();
      return KeyEventResult.handled;
    },
    child: ColoredBox(
      color: const Color(0xFF0D0E10),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              key: const ValueKey('playback-screen'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                keyboard.requestFocus();
                if (widget.ready && !widget.failed) widget.onPlay?.call();
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.child,
                  if (widget.failed || !widget.ready || widget.audio)
                    ColoredBox(
                      color: const Color(0xFF0D0E10),
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.failed
                                    ? Icons.videocam_off_outlined
                                    : widget.audio
                                    ? Icons.graphic_eq
                                    : Icons.play_circle_outline,
                                size: 48,
                                color: playbackAccent,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.failed
                                    ? 'Unable to play this media'
                                    : !widget.ready
                                    ? 'Opening media...'
                                    : 'Audio lesson',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.failed
                                    ? 'Check your connection or the file format, then use Reload player.'
                                    : !widget.ready
                                    ? 'The controls will be ready shortly.'
                                    : widget.playing
                                    ? 'Now playing'
                                    : 'Press Play to listen',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: playbackMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (widget.ready &&
                      !widget.failed &&
                      !widget.audio &&
                      !widget.playing)
                    Center(
                      child: IconButton.filled(
                        tooltip: 'Play video',
                        onPressed: widget.onPlay,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: .72),
                          foregroundColor: playbackAccent,
                          padding: const EdgeInsets.all(18),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 40),
                      ),
                    ),
                  if (widget.buffering && !widget.failed)
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: LinearProgressIndicator(
                        color: playbackAccent,
                        backgroundColor: playbackPanel,
                        minHeight: 2,
                      ),
                    ),
                ],
              ),
            ),
          ),
          widget.controls,
        ],
      ),
    ),
  );
}
