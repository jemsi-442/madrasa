import 'design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'learning_page.dart';
import 'lesson_media_viewer.dart';
import 'lesson_contents.dart';
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
    this.outline = const [],
  });
  final String id, apiBaseUrl;
  final PageLoader load;
  final PageSubmitter submit;
  final LessonMediaBuilder? surfaceBuilder;
  final List<Map<String, dynamic>> outline;
  @override
  State<LearnerLessonReader> createState() => _LearnerLessonReaderState();
}

class _LearnerLessonReaderState extends State<LearnerLessonReader> {
  late String lessonId = widget.id;
  late Future<dynamic> current = requestLesson(lessonId);
  final lessonAnchor = GlobalKey();
  final lessonFocus = FocusNode(debugLabel: 'Current lesson');
  final mediaAnchor = GlobalKey();
  final notesAnchor = GlobalKey();
  final mediaFocus = FocusNode(debugLabel: 'Lesson resource');
  final notesFocus = FocusNode(debugLabel: 'Lesson notes');
  final contentsScroll = ScrollController();
  bool saving = false, focusView = false;
  Map<String, dynamic>? savedProgress, selectedAsset;
  String? error;
  String resourceFilter = 'ALL';
  double readingSize = 16;
  final progressByLesson = <String, Map<String, dynamic>>{};

  Future<dynamic> requestLesson(String id) {
    final request = Future.sync(() => widget.load('/api/learner/lessons/$id'));
    // Handle fast failures before the next frame attaches PageResult. The
    // original future still delivers the error to the lesson's retry UI.
    request.ignore();
    return request;
  }

  @override
  void dispose() {
    lessonFocus.dispose();
    mediaFocus.dispose();
    notesFocus.dispose();
    contentsScroll.dispose();
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
        '/api/learner/lessons/$lessonId/progress',
        {'progressPercent': 100, 'markCompleted': true},
      );
      if (mounted) {
        setState(() {
          savedProgress = recordMap(result);
          progressByLesson[lessonId] = savedProgress!;
        });
      }
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

  bool lessonAvailable(Map<String, dynamic> lesson) =>
      ['OPEN', 'PREVIEW'].contains(lesson['accessState']);

  void changeLesson(Map<String, dynamic> lesson) {
    final id = recordText(lesson['id'], '');
    if (saving || !lessonAvailable(lesson) || id.isEmpty || id == lessonId) {
      return;
    }
    setState(() {
      lessonId = id;
      selectedAsset = null;
      savedProgress = null;
      error = null;
      focusView = false;
      resourceFilter = 'ALL';
      // The outline is navigation context, not authorization. Load each lesson
      // again so revoked access and updated progress are checked by the server.
      current = requestLesson(lessonId);
    });
    reveal(lessonAnchor, lessonFocus);
  }

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
    setState(() {
      selectedAsset = asset;
    });
    reveal(mediaAnchor, mediaFocus);
  }

  void toggleFocus() {
    if (saving) return;
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
        if (assets.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const {
                'ALL': 'All resources',
                'VIDEO': 'Video',
                'AUDIO': 'Audio',
                'TEXT': 'Text',
                'IMAGE': 'Images',
                'PDF': 'PDF',
                'EMBED': 'Embedded video',
              }.entries)
                if (entry.key == 'ALL' ||
                    assets.any((a) => a['assetType'] == entry.key))
                  ChoiceChip(
                    key: ValueKey('resource-filter-${entry.key}'),
                    selected: resourceFilter == entry.key,
                    avatar: Icon(
                      entry.key == 'ALL'
                          ? Icons.grid_view_outlined
                          : lessonResourceIcon(entry.key),
                      size: 20,
                    ),
                    label: Text(
                      '${entry.value} (${entry.key == 'ALL' ? assets.length : assets.where((a) => a['assetType'] == entry.key).length})',
                    ),
                    onSelected: (_) =>
                        setState(() => resourceFilter = entry.key),
                  ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 1080
                ? 4
                : box.maxWidth >= 760
                ? 3
                : box.maxWidth >= 500
                ? 2
                : 1;
            final width = (box.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final asset in assets.where(
                  (a) =>
                      resourceFilter == 'ALL' ||
                      a['assetType'] == resourceFilter,
                ))
                  SizedBox(
                    width: width,
                    child: DecoratedBox(
                      key: ValueKey('resource-${asset['id']}'),
                      decoration: BoxDecoration(
                        color: selectedAsset?['id'] == asset['id']
                            ? gold.withValues(alpha: .09)
                            : paper,
                        border: Border.all(
                          color: selectedAsset?['id'] == asset['id']
                              ? gold
                              : line,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  lessonResourceIcon(
                                    recordText(asset['assetType']),
                                  ),
                                  color: gold,
                                  size: 28,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    recordText(
                                      asset['title'],
                                      'Lesson resource',
                                    ),
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
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
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
                                size: AfaqDesign.iconSmall,
                              ),
                              label: Text(
                                ![
                                      'OPEN',
                                      'PREVIEW',
                                    ].contains(asset['accessState'])
                                    ? 'Access required'
                                    : asset['sourceReady'] != true
                                    ? 'Not connected'
                                    : selectedAsset?['id'] == asset['id']
                                    ? 'Viewing now'
                                    : [
                                        'VIDEO',
                                        'AUDIO',
                                      ].contains(asset['assetType'])
                                    ? 'Play in app'
                                    : 'View in app',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
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
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                Icons.text_fields,
                size: AfaqDesign.iconSmall,
                color: muted,
              ),
              Text(
                '${readingSize.toInt()}px',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              IconButton(
                tooltip: 'Smaller lesson text',
                onPressed: readingSize <= 14
                    ? null
                    : () => setState(() => readingSize -= 2),
                icon: const Icon(Icons.remove, size: AfaqDesign.iconSmall),
              ),
              IconButton(
                tooltip: 'Larger lesson text',
                onPressed: readingSize >= 24
                    ? null
                    : () => setState(() => readingSize += 2),
                icon: const Icon(Icons.add, size: AfaqDesign.iconSmall),
              ),
              TextButton(
                onPressed: () => setState(() => readingSize = 16),
                child: const Text('Reset text size'),
              ),
            ],
          ),
          const Divider(height: 24),
          SelectableText(
            lesson['contentText'] == null ||
                    recordText(lesson['contentText']).trim().isEmpty
                ? 'This lesson has no reading text. Explore its resources to continue learning.'
                : recordText(lesson['contentText']),
            style: TextStyle(fontSize: readingSize, height: 1.8, color: ink),
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

  Widget adjacentLesson(Map<String, dynamic>? lesson, {required bool next}) {
    final available = lesson != null && lessonAvailable(lesson);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          lesson == null
              ? next
                    ? 'End of published lessons'
                    : 'You are at the first lesson'
              : recordText(lesson['title']),
          style: const TextStyle(color: ink, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          lesson == null
              ? next
                    ? 'Review the curriculum for anything you still need to finish.'
                    : 'Work through the course at your own pace.'
              : '${recordText(lesson['moduleTitle'])}${available ? '' : ' / Access required'}',
          style: const TextStyle(color: muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 12),
        if (next && lesson != null)
          FilledButton.icon(
            key: const ValueKey('next-lesson'),
            onPressed: !saving && available ? () => changeLesson(lesson) : null,
            icon: Icon(available ? Icons.arrow_forward : Icons.lock_outline),
            label: const Text('Next lesson'),
          )
        else if (!next)
          OutlinedButton.icon(
            key: const ValueKey('previous-lesson'),
            onPressed: !saving && available ? () => changeLesson(lesson) : null,
            icon: Icon(
              lesson != null && !available
                  ? Icons.lock_outline
                  : Icons.arrow_back,
            ),
            label: const Text('Previous lesson'),
          ),
      ],
    );
  }

  Widget contents(Map<String, dynamic> progress, {required bool compact}) {
    final content = Scrollbar(
      key: const ValueKey('course-contents-scrollbar'),
      controller: contentsScroll,
      thumbVisibility: true,
      interactive: true,
      child: SingleChildScrollView(
        key: const ValueKey('course-contents-scroll'),
        controller: contentsScroll,
        primary: false,
        padding: const EdgeInsets.only(right: 8),
        child: LessonContents(
          lessons: widget.outline,
          currentId: lessonId,
          progress: {...progressByLesson, lessonId: progress},
          onSelect: saving ? null : changeLesson,
        ),
      ),
    );
    return SurfacePanel(
      padding: EdgeInsets.zero,
      child: compact
          ? ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              key: ValueKey('mobile-contents-$lessonId'),
              leading: const Icon(Icons.format_list_bulleted, color: gold),
              title: const Text(
                'Course contents',
                style: TextStyle(color: ink, fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${widget.outline.length} lessons'),
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (MediaQuery.sizeOf(context).height * .4).clamp(
                      180,
                      360,
                    ),
                  ),
                  child: content,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Text(
                    'Course contents',
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (MediaQuery.sizeOf(context).height * .55).clamp(
                      280,
                      600,
                    ),
                  ),
                  child: content,
                ),
              ],
            ),
    );
  }

  Widget courseProgress(Map<String, dynamic> progress) {
    final completed = widget.outline.where((item) {
      final id = recordText(item['id']);
      final state = id == lessonId
          ? progress
          : progressByLesson[id] ?? recordMap(item['progress']);
      return recordNumber(state['progressPercent']) >= 100;
    }).length;
    final total = widget.outline.length;
    final fraction = total == 0 ? 0.0 : completed / total;
    return SurfacePanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Course progress',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${(fraction * 100).round()}%',
                style: const TextStyle(
                  color: ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            color: gold,
            backgroundColor: line,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 10),
          Text(
            '$completed / $total lessons completed',
            style: const TextStyle(color: muted),
          ),
        ],
      ),
    );
  }

  Widget courseNavigation(int index) {
    final previous = index > 0 ? widget.outline[index - 1] : null;
    final next = index + 1 < widget.outline.length
        ? widget.outline[index + 1]
        : null;
    final locked = [
      previous,
      next,
    ].any((lesson) => lesson != null && !lessonAvailable(lesson));
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeading(
            'Continue your course',
            subtitle: 'Moving between lessons does not mark them complete.',
          ),
          LayoutBuilder(
            builder: (context, box) {
              final before = adjacentLesson(previous, next: false);
              final after = adjacentLesson(next, next: true);
              if (box.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [before, const Divider(height: 32), after],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: before),
                  const SizedBox(width: 32),
                  Expanded(child: after),
                ],
              );
            },
          ),
          if (locked) ...[
            const SizedBox(height: 18),
            const TeacherNotice(
              'A neighbouring lesson requires access. Return to the curriculum to see available previews or contact the school.',
              warning: true,
            ),
          ],
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('course-outline'),
              onPressed: saving ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.view_list_outlined),
              label: const Text('Return to curriculum'),
            ),
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
          child: Focus(
            key: lessonAnchor,
            focusNode: lessonFocus,
            child: PageResult(
              key: ValueKey(lessonId),
              future: current,
              onRetry: () => setState(() {
                current = requestLesson(lessonId);
                error = null;
              }),
              builder: (raw) {
                final lesson = recordMap(recordMap(raw)['lesson']);
                final lessonIndex = widget.outline.indexWhere(
                  (item) => recordText(item['id']) == lessonId,
                );
                final assets = recordList(lesson['assets']);
                final available = assets.where(canOpen).toList();
                final playback = available
                    .where(
                      (asset) =>
                          ['VIDEO', 'EMBED'].contains(asset['assetType']),
                    )
                    .firstOrNull;
                final selectedIndex = available.indexWhere(
                  (asset) => asset['id'] == selectedAsset?['id'],
                );
                final progress = savedProgress ?? recordMap(lesson['progress']);
                final stage = Focus(
                  key: mediaAnchor,
                  focusNode: mediaFocus,
                  child: selectedAsset == null
                      ? playback == null
                            ? const SizedBox.shrink()
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  key: const ValueKey('load-lesson-player'),
                                  onPressed: saving
                                      ? null
                                      : () => play(playback),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: ink,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 56),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.play_circle_outline,
                                    size: 28,
                                  ),
                                  label: Text(
                                    'Watch video: ${recordText(playback['title'], 'Lesson video')}',
                                  ),
                                ),
                              )
                      : LessonMediaViewer(
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
                          position: selectedIndex < 0
                              ? null
                              : selectedIndex + 1,
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
                    LayoutBuilder(
                      builder: (context, box) {
                        final name = Text(
                          recordText(recordMap(lesson['course'])['title']),
                          style: const TextStyle(
                            color: blue,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                        if (focusView || widget.outline.isEmpty) return name;
                        if (box.maxWidth < 760) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              name,
                              const SizedBox(height: 12),
                              courseProgress(progress),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: name),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: 350,
                              child: courseProgress(progress),
                            ),
                          ],
                        );
                      },
                    ),
                    if (lessonIndex >= 0) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TeacherTag(
                            'Lesson ${lessonIndex + 1} of ${widget.outline.length}',
                            color: gold,
                          ),
                          Text(
                            key: const ValueKey('current-module'),
                            recordText(
                              widget.outline[lessonIndex]['moduleTitle'],
                            ),
                            style: const TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
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
                    if (focusView) stage,
                    if (!focusView)
                      LayoutBuilder(
                        builder: (context, box) {
                          if (box.maxWidth >= 980 &&
                              widget.outline.isNotEmpty) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      stage,
                                      const SizedBox(height: 20),
                                      reading(lesson),
                                      const SizedBox(height: 20),
                                      completion(progress),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                SizedBox(
                                  width: 350,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (widget.outline.isNotEmpty) ...[
                                        contents(progress, compact: false),
                                        const SizedBox(height: 18),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              stage,
                              const SizedBox(height: 20),
                              if (widget.outline.isNotEmpty) ...[
                                contents(progress, compact: true),
                                const SizedBox(height: 18),
                              ],
                              reading(lesson),
                              const SizedBox(height: 20),
                              completion(progress),
                            ],
                          );
                        },
                      ),
                    if (!focusView) ...[
                      const SizedBox(height: 24),
                      resources(assets),
                    ],
                    if (!focusView && lessonIndex >= 0) ...[
                      const SizedBox(height: 20),
                      courseNavigation(lessonIndex),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
