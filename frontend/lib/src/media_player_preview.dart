import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'learning_page.dart';
import 'lesson_media_viewer.dart';
import 'media_player_samples.dart';
import 'teacher_ui.dart';

Future<void> openMediaPlayerPreview(
  BuildContext context, {
  LessonMediaBuilder? surfaceBuilder,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => MediaPlayerPreviewPage(surfaceBuilder: surfaceBuilder),
  ),
);

class MediaPlayerPreviewButton extends StatelessWidget {
  const MediaPlayerPreviewButton({super.key, this.surfaceBuilder});
  final LessonMediaBuilder? surfaceBuilder;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () =>
        openMediaPlayerPreview(context, surfaceBuilder: surfaceBuilder),
    icon: const Icon(Icons.play_circle_outline),
    label: const Text('Try media player'),
  );
}

class _LeavePreviewFocusIntent extends Intent {
  const _LeavePreviewFocusIntent();
}

/// Bundled examples only. This page has no school API or progress callbacks.
class MediaPlayerPreviewPage extends StatefulWidget {
  const MediaPlayerPreviewPage({super.key, this.surfaceBuilder});
  final LessonMediaBuilder? surfaceBuilder;

  @override
  State<MediaPlayerPreviewPage> createState() => _MediaPlayerPreviewPageState();
}

class _MediaPlayerPreviewPageState extends State<MediaPlayerPreviewPage> {
  MediaPlayerSample sample = MediaPlayerSample.video;
  bool focusView = false;
  final playerKey = GlobalKey();
  final playerFocus = FocusNode(debugLabel: 'Preview player');

  @override
  void dispose() {
    playerFocus.dispose();
    super.dispose();
  }

  void revealPlayer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = playerKey.currentContext;
      if (!mounted || target == null) return;
      playerFocus.requestFocus();
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
      );
    });
  }

  void select(MediaPlayerSample value) {
    if (sample == value) return;
    setState(() => sample = value);
    revealPlayer();
  }

  void toggleFocus() {
    setState(() => focusView = !focusView);
    revealPlayer();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !focusView,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && focusView) toggleFocus();
    },
    child: Shortcuts(
      shortcuts: {
        if (focusView)
          const SingleActivator(LogicalKeyboardKey.escape):
              const _LeavePreviewFocusIntent(),
      },
      child: Actions(
        actions: {
          _LeavePreviewFocusIntent: CallbackAction<_LeavePreviewFocusIntent>(
            onInvoke: (_) {
              if (focusView) toggleFocus();
              return null;
            },
          ),
        },
        child: LearningPage(
          title: 'Media player preview',
          backLabel: focusView ? 'Back to preview' : 'Back to workspace',
          onBack: focusView ? toggleFocus : () => Navigator.pop(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: TeacherTag('SAMPLE PREVIEW', color: gold),
              ),
              const SizedBox(height: 12),
              if (!focusView) ...[
                const Text(
                  'Make yourself at home with the player',
                  style: TextStyle(
                    color: ink,
                    fontSize: 28,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No video uploaded yet? Explore these built-in samples. They use the same controls as your lessons, without changing any learning records.',
                  style: TextStyle(color: muted, height: 1.6),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final value in MediaPlayerSample.values)
                      ChoiceChip(
                        key: ValueKey('preview-${value.name}'),
                        selected: sample == value,
                        avatar: Icon(lessonResourceIcon(value.kind), size: 19),
                        label: Text(value.label),
                        showCheckmark: false,
                        onSelected: (_) => select(value),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              Focus(
                key: playerKey,
                focusNode: playerFocus,
                child: LessonMediaViewer.preview(
                  key: ValueKey(sample),
                  sample: sample,
                  surfaceBuilder: widget.surfaceBuilder,
                  focusView: focusView,
                  onToggleFocus: toggleFocus,
                  position: sample.index + 1,
                  total: MediaPlayerSample.values.length,
                  onPrevious: sample.index == 0
                      ? null
                      : () =>
                            select(MediaPlayerSample.values[sample.index - 1]),
                  onNext: sample.index == MediaPlayerSample.values.length - 1
                      ? null
                      : () =>
                            select(MediaPlayerSample.values[sample.index + 1]),
                ),
              ),
              if (!focusView) ...[
                const SizedBox(height: 20),
                SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PanelHeading('Try it for yourself'),
                      Text(
                        sample.instructions,
                        style: const TextStyle(color: muted, height: 1.6),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nothing starts playing automatically. You can switch samples, reload or return to your work at any time.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
