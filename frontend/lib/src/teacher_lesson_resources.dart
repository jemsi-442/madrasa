import 'package:flutter/material.dart';
import 'dashboard_components.dart';
import 'lesson_media_viewer.dart';

class TeacherLessonResources extends StatefulWidget {
  const TeacherLessonResources({
    super.key,
    required this.lessonId,
    required this.load,
    required this.apiBaseUrl,
  });
  final String lessonId, apiBaseUrl;
  final PageLoader load;

  @override
  State<TeacherLessonResources> createState() => _TeacherLessonResourcesState();
}

class _TeacherLessonResourcesState extends State<TeacherLessonResources> {
  late Future<dynamic> future = fetch();
  String? selected;
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

  Future<dynamic> fetch() {
    final request = widget.load(
      '/api/courses/lessons/${Uri.encodeComponent(widget.lessonId)}/assets',
    );
    request.ignore();
    return request;
  }

  @override
  void didUpdateWidget(covariant TeacherLessonResources oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessonId != widget.lessonId) {
      selected = null;
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
      final index = rows.indexWhere((row) => '${row['id']}' == selected);
      if (rows.isEmpty) {
        return const EmptyRecords(
          'No media resources have been added to this lesson.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(key: resourcesAnchor),
          const PanelHeading(
            'Lesson resources',
            subtitle:
                'Preview the resources for this lesson without recording learner progress.',
          ),
          for (final row in rows)
            ListTile(
              leading: Icon(lessonResourceIcon(recordText(row['assetType']))),
              title: Text(recordText(row['title'])),
              trailing: const Icon(Icons.play_circle_outline),
              selected: selected == '${row['id']}',
              onTap: () => openResource('${row['id']}'),
            ),
          SizedBox(key: playerAnchor),
          if (index >= 0)
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
        ],
      );
    },
  );
}
