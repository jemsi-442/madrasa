import 'package:flutter/material.dart';
import 'dashboard_components.dart';
import 'lesson_media_viewer.dart';

class TeacherLessonResources extends StatefulWidget {
  const TeacherLessonResources({
    super.key,
    required this.lessonId,
    required this.load,
    required this.apiBaseUrl,
    this.openFirst = false,
  });
  final String lessonId, apiBaseUrl;
  final PageLoader load;
  final bool openFirst;

  @override
  State<TeacherLessonResources> createState() => _TeacherLessonResourcesState();
}

class _TeacherLessonResourcesState extends State<TeacherLessonResources> {
  late Future<dynamic> future = fetch();
  String? selected;
  String? filter;
  String resourceKind(Map<String, dynamic> row) =>
      row['assetType'] == 'EMBED' ? 'VIDEO' : recordText(row['assetType']);
  final playerAnchor = GlobalKey();
  final resourcesAnchor = GlobalKey();

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
      if (rows.isNotEmpty) {
        selected = '${(videos.isNotEmpty ? videos.first : rows.first)['id']}';
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
      future = fetch();
    }
  }

  @override
  Widget build(BuildContext context) => PageResult(
    future: future,
    onRetry: () => setState(() {
      future = fetch();
    }),
    builder: (data) {
      final rows = recordList(data);
      final counts = <String, int>{};
      for (final row in rows) {
        final kind = resourceKind(row);
        counts[kind] = (counts[kind] ?? 0) + 1;
      }
      final activeFilter = counts.containsKey(filter) ? filter : null;
      final index = rows.indexWhere((row) => '${row['id']}' == selected);
      if (rows.isEmpty) {
        return const EmptyRecords(
          'No media resources have been added to this lesson.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(key: playerAnchor),
          if (index >= 0) ...[
            LessonMediaViewer(
              key: ValueKey('teacher-resource-$selected'),
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
              final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              final columns = (constraints.maxWidth / (360 * textScale))
                  .floor()
                  .clamp(1, 3);
              final width =
                  (constraints.maxWidth - 16 * (columns - 1)) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 6,
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
  );

  Widget resourceCard(Map<String, dynamic> row) {
    final kind = recordText(row['assetType']);
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
        color: color.withValues(alpha: active ? .10 : .035),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: active ? color : color.withValues(alpha: .18),
            width: active ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(lessonResourceIcon(kind), color: color, size: 28),
          ),
          title: Text(
            recordText(row['title']),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              active ? '$action - Selected' : action,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          trailing: Icon(Icons.arrow_forward, color: color),
          selected: active,
          onTap: () => openResource('${row['id']}'),
        ),
      ),
    );
  }
}
