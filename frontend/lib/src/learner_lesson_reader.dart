import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'learning_page.dart';
import 'lesson_media_viewer.dart';
import 'teacher_ui.dart';

class _ExitMediaFocusIntent extends Intent {
  const _ExitMediaFocusIntent();
}

class LearnerLessonReader extends StatefulWidget {
  const LearnerLessonReader({
    super.key,
    required this.id,
    required this.load,
    required this.submit,
    required this.apiBaseUrl,
    this.surfaceBuilder,
  });
  final String id, apiBaseUrl;
  final PageLoader load;
  final PageSubmitter submit;
  final LessonMediaBuilder? surfaceBuilder;
  @override
  State<LearnerLessonReader> createState() => _LearnerLessonReaderState();
}

class _LearnerLessonReaderState extends State<LearnerLessonReader> {
  late Future<dynamic> current = widget.load(
    '/api/learner/lessons/${widget.id}',
  );
  final mediaAnchor = GlobalKey();
  final notesAnchor = GlobalKey();
  final mediaFocus = FocusNode(debugLabel: 'Lesson resource');
  final notesFocus = FocusNode(debugLabel: 'Lesson notes');
  bool saving = false, focusView = false;
  Map<String, dynamic>? savedProgress, selectedAsset;
  String? error;

  @override
  void dispose() {
    mediaFocus.dispose();
    notesFocus.dispose();
    super.dispose();
  }

  Future<void> complete() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.submit(
        '/api/learner/lessons/${widget.id}/progress',
        {'progressPercent': 100, 'markCompleted': true},
      );
      if (mounted) setState(() => savedProgress = recordMap(result));
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'Progress could not be saved. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  bool canOpen(Map<String, dynamic> asset) =>
      ['OPEN', 'PREVIEW'].contains(asset['accessState']) &&
      asset['sourceReady'] == true;

  void reveal(GlobalKey anchor, FocusNode focus) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = anchor.currentContext;
      if (!mounted || target == null) return;
      focus.requestFocus();
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
      );
    });
  }

  void play(Map<String, dynamic> asset) {
    if (saving || !canOpen(asset)) return;
    setState(() => selectedAsset = asset);
    reveal(mediaAnchor, mediaFocus);
  }

  void toggleFocus() {
    if (saving || selectedAsset == null) return;
    setState(() => focusView = !focusView);
    reveal(mediaAnchor, mediaFocus);
  }

  void returnToNotes() {
    setState(() {
      focusView = false;
      selectedAsset = null;
    });
    reveal(notesAnchor, notesFocus);
  }

  Widget resources(List<Map<String, dynamic>> assets) => SurfacePanel(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeading(
          'Lesson resources',
          subtitle: '${assets.length} resources in this lesson',
        ),
        if (assets.isEmpty)
          const EmptyRecords('No resources attached to this lesson.'),
        for (final (index, asset) in assets.indexed) ...[
          if (index > 0) const Divider(height: 28, color: line),
          DecoratedBox(
            key: ValueKey('resource-${asset['id']}'),
            decoration: BoxDecoration(
              color: selectedAsset?['id'] == asset['id']
                  ? gold.withValues(alpha: .09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        lessonResourceIcon(recordText(asset['assetType'])),
                        color: gold,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          recordText(asset['title'], 'Lesson resource'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedAsset?['id'] == asset['id']
                        ? 'Selected resource'
                        : recordText(asset['assetType']),
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    key: ValueKey('open-resource-${asset['id']}'),
                    onPressed: !saving && canOpen(asset)
                        ? () => play(asset)
                        : null,
                    icon: Icon(
                      selectedAsset?['id'] == asset['id']
                          ? Icons.check_circle_outline
                          : Icons.arrow_forward,
                      size: 17,
                    ),
                    label: Text(
                      !['OPEN', 'PREVIEW'].contains(asset['accessState'])
                          ? 'Access required'
                          : asset['sourceReady'] != true
                          ? 'Not connected'
                          : selectedAsset?['id'] == asset['id']
                          ? 'Viewing now'
                          : ['VIDEO', 'AUDIO'].contains(asset['assetType'])
                          ? 'Play in app'
                          : 'View in app',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget reading(Map<String, dynamic> lesson) => Focus(
    key: notesAnchor,
    focusNode: notesFocus,
    child: SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeading('Lesson notes'),
          SelectableText(
            lesson['contentText'] == null ||
                    recordText(lesson['contentText']).trim().isEmpty
                ? 'This lesson has no reading text. Explore its resources to continue learning.'
                : recordText(lesson['contentText']),
            style: const TextStyle(fontSize: 16, height: 1.8, color: ink),
          ),
        ],
      ),
    ),
  );

  Widget completion(Map<String, dynamic> progress) {
    final completed = recordNumber(progress['progressPercent']) >= 100;
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TeacherTag(
                completed
                    ? 'Completed'
                    : '${progress['progressPercent'] ?? 0}% recorded',
                color: forest,
              ),
              FilledButton.icon(
                onPressed: saving || completed ? null : complete,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  saving
                      ? 'Saving...'
                      : completed
                      ? 'Lesson completed'
                      : 'Mark complete',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Mark complete when you finish this lesson. Opening a resource does not save completion.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.6),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TeacherNotice(error!, warning: true),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !focusView,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && focusView && !saving) toggleFocus();
    },
    child: Shortcuts(
      shortcuts: {
        if (focusView)
          const SingleActivator(LogicalKeyboardKey.escape):
              const _ExitMediaFocusIntent(),
      },
      child: Actions(
        actions: {
          _ExitMediaFocusIntent: CallbackAction<_ExitMediaFocusIntent>(
            onInvoke: (_) {
              if (focusView) toggleFocus();
              return null;
            },
          ),
        },
        child: LearningPage(
          title: 'Lesson reader',
          backLabel: focusView ? 'Back to lesson' : 'Back to course',
          onBack: saving
              ? null
              : focusView
              ? toggleFocus
              : () => Navigator.pop(context),
          child: PageResult(
            future: current,
            onRetry: () => setState(() {
              current = widget.load('/api/learner/lessons/${widget.id}');
              error = null;
            }),
            builder: (raw) {
              final lesson = recordMap(recordMap(raw)['lesson']);
              final assets = recordList(lesson['assets']);
              final available = assets.where(canOpen).toList();
              final selectedIndex = available.indexWhere(
                (asset) => asset['id'] == selectedAsset?['id'],
              );
              final progress = savedProgress ?? recordMap(lesson['progress']);
              final stage = selectedAsset == null
                  ? null
                  : Focus(
                      key: mediaAnchor,
                      focusNode: mediaFocus,
                      child: LessonMediaViewer(
                        key: ValueKey(selectedAsset!['id']),
                        assetId: recordText(selectedAsset!['id']),
                        title: recordText(
                          selectedAsset!['title'],
                          'Lesson resource',
                        ),
                        load: widget.load,
                        apiBaseUrl: widget.apiBaseUrl,
                        surfaceBuilder: widget.surfaceBuilder,
                        onClose: returnToNotes,
                        focusView: focusView,
                        onToggleFocus: saving ? null : toggleFocus,
                        position: selectedIndex < 0 ? null : selectedIndex + 1,
                        total: selectedIndex < 0 ? null : available.length,
                        onPrevious: saving || selectedIndex <= 0
                            ? null
                            : () => play(available[selectedIndex - 1]),
                        onNext:
                            saving ||
                                selectedIndex < 0 ||
                                selectedIndex >= available.length - 1
                            ? null
                            : () => play(available[selectedIndex + 1]),
                      ),
                    );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    recordText(recordMap(lesson['course'])['title']),
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recordText(lesson['title']),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: ink,
                      height: 1.2,
                    ),
                  ),
                  if (lesson['summary'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        recordText(lesson['summary']),
                        style: const TextStyle(color: muted, height: 1.6),
                      ),
                    ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, box) {
                      if (focusView && stage != null) return stage;
                      if (box.maxWidth >= 980) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (stage != null) ...[
                                    stage,
                                    const SizedBox(height: 20),
                                  ],
                                  reading(lesson),
                                  const SizedBox(height: 20),
                                  completion(progress),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            SizedBox(width: 300, child: resources(assets)),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (stage != null) ...[
                            stage,
                            const SizedBox(height: 20),
                          ],
                          if (stage == null) ...[
                            reading(lesson),
                            const SizedBox(height: 20),
                          ],
                          resources(assets),
                          const SizedBox(height: 20),
                          if (stage != null) ...[
                            reading(lesson),
                            const SizedBox(height: 20),
                          ],
                          completion(progress),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
