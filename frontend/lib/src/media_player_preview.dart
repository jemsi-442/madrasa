import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Widget build(BuildContext context) => Container(
    key: const ValueKey('media-player-launcher'),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF102C43), Color(0xFF214A61)],
      ),
      border: Border.all(color: const Color(0xFF365B70)),
    ),
    padding: const EdgeInsets.all(24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 900 ||
            MediaQuery.textScalerOf(context).scale(16) > 24;
        final stackedIntro =
            constraints.maxWidth < 420 ||
            MediaQuery.textScalerOf(context).scale(16) > 24;
        final emblem = Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFE0B351),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3D88E)),
          ),
          child: const Icon(Icons.play_circle_outline, size: 36, color: ink),
        );
        final copy = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'PREVIEW',
                style: TextStyle(
                  color: Color(0xFFF3D88E),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              header: true,
              child: const Text(
                'Media player',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preview sample media before starting a lesson.',
              style: TextStyle(
                color: Color(0xFFD2E0E9),
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        );
        final introduction = stackedIntro
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [emblem, const SizedBox(height: 16), copy],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  emblem,
                  const SizedBox(width: 20),
                  Expanded(child: copy),
                ],
              );
        final action = FilledButton.icon(
          key: const ValueKey('open-media-player-preview'),
          onPressed: () =>
              openMediaPlayerPreview(context, surfaceBuilder: surfaceBuilder),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE0B351),
            foregroundColor: ink,
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          icon: const Icon(Icons.play_arrow_rounded, size: 28),
          label: const Text('Try media player'),
        );
        if (compact) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [introduction, const SizedBox(height: 20), action],
          );
        }
        return Row(
          children: [
            Expanded(child: introduction),
            const SizedBox(width: 32),
            action,
          ],
        );
      },
    ),
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
                  'Explore the media viewer',
                  style: TextStyle(
                    color: ink,
                    fontSize: 28,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Choose a sample to try the controls. Your learning records stay unchanged.',
                  style: TextStyle(color: muted, fontSize: 16, height: 1.6),
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
                        selectedColor: ink,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        labelStyle: TextStyle(
                          color: sample == value ? Colors.white : ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        avatar: Icon(
                          lessonResourceIcon(value.kind),
                          size: 24,
                          color: sample == value ? Colors.white : ink,
                        ),
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
            ],
          ),
        ),
      ),
    ),
  );
}
