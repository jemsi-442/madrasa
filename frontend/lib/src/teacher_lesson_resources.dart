import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'lesson_upload.dart';
import 'dashboard_components.dart';
import 'lesson_media_viewer.dart';
import 'lesson_text_editor.dart';
import 'lesson_upload_editor.dart';

class TeacherLessonResources extends StatefulWidget {
  const TeacherLessonResources({
    super.key,
    required this.lessonId,
    required this.load,
    required this.apiBaseUrl,
    this.openFirst = false,
    this.submit,
    this.upload,
  });
  final String lessonId, apiBaseUrl;
  final PageLoader load;
  final bool openFirst;
  final Future<dynamic> Function(String, Map<String, dynamic>)? submit;
  final LessonUploader? upload;

  @override
  State<TeacherLessonResources> createState() => _TeacherLessonResourcesState();
}

class _TeacherLessonResourcesState extends State<TeacherLessonResources> {
  late Future<dynamic> future = fetch();
  String? selected;
  String? filter;
  bool revealInitialResource = false;
  List<Map<String, dynamic>> currentRows = [];

  void resourceAdded(dynamic result) {
    final resource = Map<String, dynamic>.from(result as Map);
    setState(() {
      // Keep the resource list mounted; opening a platform viewer during the
      // upload dialog's exit transition can obscure the underlying workspace.
      selected = null;
      filter = null;
      revealInitialResource = false;
      currentRows = [
        ...currentRows.where((row) => '${row['id']}' != '${resource['id']}'),
        resource,
      ];
      future = SynchronousFuture<dynamic>(currentRows);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resource['visibility'] == 'LOCKED'
              ? 'Resource saved and locked for learners. You can preview it below.'
              : 'Resource saved. Select it below to open.',
        ),
      ),
    );
  }

  String resourceKind(Map<String, dynamic> row) {
    if (row['assetType'] == 'EMBED') return 'VIDEO';
    if (row['assetType'] == 'ATTACHMENT' &&
        const ['image/png', 'image/jpeg'].contains(row['mimeType'])) {
      return 'IMAGE';
    }
    return recordText(row['assetType']);
  }

  final playerAnchor = GlobalKey();
  final resourcesAnchor = GlobalKey();

  Future<void> addText() async {
    final lesson = widget.lessonId;
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          LessonTextEditor(lessonId: lesson, submit: widget.submit!),
    );
    if (!mounted || result == null || lesson != widget.lessonId) return;
    resourceAdded(result);
  }

  Widget addButton() => Align(
    alignment: Alignment.centerRight,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (widget.upload != null)
            FilledButton.icon(
              onPressed: addFile,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Upload file'),
            ),
          if (widget.submit != null)
            OutlinedButton.icon(
              onPressed: addText,
              icon: const Icon(Icons.add),
              label: const Text('Add text resource'),
            ),
        ],
      ),
    ),
  );

  Future<void> addFile() async {
    final lesson = widget.lessonId;
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          LessonUploadEditor(lessonId: lesson, upload: widget.upload!),
    );
    if (!mounted || result == null || lesson != widget.lessonId) return;
    resourceAdded(result);
  }

  void openResource(String id) {
    setState(() => selected = id);
    reveal(playerAnchor);
  }

  void reveal(GlobalKey anchor) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || anchor.currentContext == null) return;
      Scrollable.ensureVisible(
        anchor.currentContext!,
        alignment: 0.05,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<dynamic> fetch() async {
    final lesson = widget.lessonId;
    final data = await widget.load(
      '/api/courses/lessons/${Uri.encodeComponent(widget.lessonId)}/assets',
    );
    if (mounted && lesson == widget.lessonId && widget.openFirst) {
      final rows = recordList(data);
      final videos = rows.where((row) => resourceKind(row) == 'VIDEO');
      if (rows.isNotEmpty && !rows.any((row) => '${row['id']}' == selected)) {
        selected = '${(videos.isNotEmpty ? videos.first : rows.first)['id']}';
        revealInitialResource = true;
      }
    }
    return data;
  }

  @override
  void didUpdateWidget(covariant TeacherLessonResources oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessonId != widget.lessonId) {
      selected = null;
      filter = null;
      revealInitialResource = false;
      currentRows = [];
      future = fetch();
    }
  }

  @override
  Widget build(BuildContext context) => SelectionContainer.disabled(
    child: PageResult(
      future: future,
      onRetry: () => setState(() {
        future = fetch();
      }),
      builder: (data) {
        final rows = recordList(data);
        currentRows = rows;
        final counts = <String, int>{};
        for (final row in rows) {
          final kind = resourceKind(row);
          counts[kind] = (counts[kind] ?? 0) + 1;
        }
        final activeFilter = counts.containsKey(filter) ? filter : null;
        final index = rows.indexWhere((row) => '${row['id']}' == selected);
        if (index >= 0 && revealInitialResource) {
          // Wait for the loaded player layout, not the earlier loading placeholder.
          revealInitialResource = false;
          reveal(playerAnchor);
        }
        final inlineVideo =
            widget.openFirst &&
            index >= 0 &&
            resourceKind(rows[index]) == 'VIDEO';
        if (rows.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.submit != null || widget.upload != null) addButton(),
              const EmptyRecords(
                'No media resources have been added to this lesson.',
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.submit != null || widget.upload != null) addButton(),
            SizedBox(key: playerAnchor),
            if (index >= 0) ...[
              if (inlineVideo)
                Row(
                  children: [
                    const Icon(Icons.play_circle_outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recordText(rows[index]['title'], 'Video lesson'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close video',
                      onPressed: () => setState(() => selected = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: inlineVideo ? 960 : double.infinity,
                  ),
                  child: LessonMediaViewer(
                    key: ValueKey('teacher-resource-$selected'),
                    compactVideo: inlineVideo,
                    assetId: selected!,
                    load: widget.load,
                    apiBaseUrl: widget.apiBaseUrl,
                    teacherResource: true,
                    title: recordText(rows[index]['title'], 'Lesson resource'),
                    position: index + 1,
                    total: rows.length,
                    onPrevious: index > 0
                        ? () => openResource('${rows[index - 1]['id']}')
                        : null,
                    onNext: index + 1 < rows.length
                        ? () => openResource('${rows[index + 1]['id']}')
                        : null,
                    onClose: () {
                      setState(() => selected = null);
                      reveal(resourcesAnchor);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            SizedBox(key: resourcesAnchor),
            const PanelHeading(
              'Lesson resources',
              subtitle:
                  'Preview the resources for this lesson without recording learner progress.',
            ),
            if (counts.length > 1) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('All (${rows.length})'),
                    selected: activeFilter == null,
                    onSelected: (_) => setState(() => filter = null),
                  ),
                  for (final entry in const {
                    'VIDEO': 'Video',
                    'AUDIO': 'Audio',
                    'IMAGE': 'Images',
                    'PDF': 'PDF',
                    'TEXT': 'Text',
                  }.entries)
                    if (counts.containsKey(entry.key))
                      ChoiceChip(
                        avatar: Icon(lessonResourceIcon(entry.key), size: 20),
                        label: Text('${entry.value} (${counts[entry.key]})'),
                        selected: activeFilter == entry.key,
                        onSelected: (_) => setState(() => filter = entry.key),
                      ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale =
                    MediaQuery.textScalerOf(context).scale(16) / 16;
                final visibleCount = rows
                    .where(
                      (row) =>
                          activeFilter == null ||
                          resourceKind(row) == activeFilter,
                    )
                    .length;
                final columns = (constraints.maxWidth / (360 * textScale))
                    .floor()
                    .clamp(1, visibleCount.clamp(1, 3));
                final width =
                    (constraints.maxWidth - 16 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final row in rows)
                      if (activeFilter == null ||
                          resourceKind(row) == activeFilter)
                        SizedBox(
                          key: ValueKey('resource-card-${row['id']}'),
                          width: width,
                          child: resourceCard(row),
                        ),
                  ],
                );
              },
            ),
          ],
        );
      },
    ),
  );

  Widget resourceCard(Map<String, dynamic> row) {
    final kind = resourceKind(row);
    final (action, color) = switch (kind) {
      'VIDEO' || 'EMBED' => ('Watch video', const Color(0xFF1763B5)),
      'AUDIO' => ('Play audio', const Color(0xFF7545AF)),
      'IMAGE' => ('View image', const Color(0xFF187A62)),
      'PDF' => ('Open PDF', const Color(0xFFB13A47)),
      'TEXT' => ('Read text', const Color(0xFF956A12)),
      _ => ('Open resource', const Color(0xFF40576A)),
    };
    final active = selected == '${row['id']}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withValues(alpha: active ? .14 : .065),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: active ? color : color.withValues(alpha: .18),
            width: active ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          selected: active,
          child: InkWell(
            onTap: () => openResource('${row['id']}'),
            hoverColor: color.withValues(alpha: .08),
            focusColor: color.withValues(alpha: .14),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          lessonResourceIcon(kind),
                          color: color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          recordText(row['title']),
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (row['visibility'] == 'LOCKED' ||
                      row['visibility'] == 'FREE')
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            row['visibility'] == 'LOCKED'
                                ? Icons.lock_outline
                                : Icons.verified_user_outlined,
                            size: 20,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              row['visibility'] == 'LOCKED'
                                  ? 'Locked for learners. Teacher preview only.'
                                  : 'Learner access requires a published course and lesson, and course permission.',
                              style: TextStyle(color: color, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      height: 1,
                      color: color.withValues(alpha: .16),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          active ? '$action - Selected' : action,
                          style: TextStyle(
                            color: color,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        active
                            ? Icons.check_circle_outline
                            : Icons.arrow_forward,
                        color: color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
