import 'package:flutter/material.dart';
import 'dashboard_components.dart';
import 'teacher_lesson_reading.dart';
import 'teacher_lesson_resources.dart';

/// Browse and open authorized lessons without leaving the course catalogue.
class TeacherCourseInlineLesson extends StatefulWidget {
  const TeacherCourseInlineLesson({
    super.key,
    required this.modules,
    required this.load,
    required this.apiBaseUrl,
    required this.onClose,
  });
  final List<Map<String, dynamic>> modules;
  final PageLoader load;
  final String apiBaseUrl;
  final VoidCallback onClose;

  @override
  State<TeacherCourseInlineLesson> createState() =>
      _TeacherCourseInlineLessonState();
}

class _TeacherCourseInlineLessonState extends State<TeacherCourseInlineLesson> {
  int moduleIndex = 0;
  String? lessonId;
  late Future<dynamic> future = loadInitial();

  Future<dynamic> loadModule(int index) => widget.load(
    '/api/courses/modules/${Uri.encodeComponent('${widget.modules[index]['id']}')}/lessons',
  );

  Future<dynamic> loadInitial() async {
    for (var i = 0; i < widget.modules.length; i++) {
      final data = await loadModule(i);
      if (!mounted) return data;
      if (recordList(data).isNotEmpty) {
        moduleIndex = i;
        return data;
      }
    }
    return <dynamic>[];
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Course lesson',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Close lesson',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      const SizedBox(height: 12),
      PageResult(
        future: future,
        onRetry: () => setState(() => future = loadModule(moduleIndex)),
        builder: (data) {
          final lessons = recordList(data);
          final matches = lessons.where((row) => '${row['id']}' == lessonId);
          final lesson = lessons.isEmpty
              ? null
              : matches.isEmpty
              ? lessons.first
              : matches.first;
          final moduleSelector = DropdownButtonFormField<int>(
            key: ValueKey('inline-module-$moduleIndex'),
            initialValue: moduleIndex,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Module'),
            items: [
              for (var i = 0; i < widget.modules.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    recordText(widget.modules[i]['title']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value == null || value == moduleIndex) return;
              setState(() {
                moduleIndex = value;
                lessonId = null;
                future = loadModule(value);
              });
            },
          );
          final lessonSelector = lesson == null
              ? null
              : DropdownButtonFormField<String>(
                  key: ValueKey('inline-lesson-${lesson['id']}'),
                  initialValue: '${lesson['id']}',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lesson'),
                  items: [
                    for (final row in lessons)
                      DropdownMenuItem(
                        value: '${row['id']}',
                        child: Text(
                          recordText(row['title']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => lessonId = value),
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (lessonSelector == null) return moduleSelector;
                  if (constraints.maxWidth >= 640 &&
                      MediaQuery.textScalerOf(context).scale(16) <= 24) {
                    return Row(
                      key: const ValueKey('inline-lesson-selectors-row'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: moduleSelector),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: lessonSelector),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      moduleSelector,
                      const SizedBox(height: 16),
                      lessonSelector,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              if (lesson == null)
                const EmptyRecords('No lessons are available in this module.')
              else ...[
                TeacherLessonResources(
                  key: ValueKey('inline-resources-${lesson['id']}'),
                  lessonId: '${lesson['id']}',
                  load: widget.load,
                  apiBaseUrl: widget.apiBaseUrl,
                  openFirst: true,
                ),
                if (recordText(lesson['contentText'], '').isNotEmpty ||
                    recordText(lesson['summary'], '').isNotEmpty) ...[
                  const SizedBox(height: 20),
                  TeacherLessonReading(
                    text: recordText(lesson['contentText'], ''),
                    summary: recordText(lesson['summary'], ''),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    ],
  );
}
