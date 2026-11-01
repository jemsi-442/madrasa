import 'package:flutter/material.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_lesson_resources.dart';
import 'teacher_ui.dart';
import 'workspace_form_dialog.dart';

enum TeacherLearningDestination { quran, assessments }

class TeacherCourseLocation {
  const TeacherCourseLocation({
    required this.course,
    required this.module,
    required this.lessonId,
  });
  final Map<String, dynamic> course, module;
  final String lessonId;
}

/// Assigned course browsing stays inside the teacher workspace.
class TeacherCoursesPage extends StatefulWidget {
  const TeacherCoursesPage({
    super.key,
    required this.load,
    this.apiBaseUrl = '',
    this.refreshToken = 0,
    this.initialLocation,
    this.onRecordLearning,
    this.classId,
  });
  final PageLoader load;
  final String apiBaseUrl;
  final int refreshToken;
  final String? classId;
  final TeacherCourseLocation? initialLocation;
  final void Function(TeacherCourseLocation, TeacherLearningDestination)?
  onRecordLearning;

  @override
  State<TeacherCoursesPage> createState() => _TeacherCoursesPageState();
}

class _TeacherCoursesPageState extends State<TeacherCoursesPage> {
  late Map<String, dynamic>? course = widget.initialLocation?.course;
  late Map<String, dynamic>? module = widget.initialLocation?.module;
  late String? lessonId = widget.initialLocation?.lessonId;
  final lessonAnchor = GlobalKey();
  late bool revealRestoredLesson = widget.initialLocation != null;
  late Future<dynamic> future = fetch();

  Future<void> chooseRecord() async {
    final location = TeacherCourseLocation(
      course: Map.of(course!),
      module: Map.of(module!),
      lessonId: lessonId!,
    );
    final target = await showDialog<TeacherLearningDestination>(
      context: context,
      builder: (dialogContext) => WorkspaceFormDialog(
        title: const Text('Record lesson results'),
        icon: Icons.fact_check_outlined,
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('What did you assess?'),
                const SizedBox(height: 16),
                for (final target in TeacherLearningDestination.values) ...[
                  OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(target),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Text(
                            target == TeacherLearningDestination.quran
                                ? "Qur'an practice"
                                : 'Other subject results',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            target == TeacherLearningDestination.quran
                                ? 'Recitation, memorisation or revision'
                                : 'Scores and feedback in Assessments',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Confirm the class and learner on the next screen. Nothing is saved yet.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (mounted && target != null) {
      widget.onRecordLearning?.call(location, target);
    }
  }

  Widget classContext() {
    if (widget.classId == null || widget.classId!.isEmpty) {
      return const Text(
        'No class selected. Choose a class when recording results.',
        style: TextStyle(color: muted),
      );
    }
    return TeacherData(
      key: ValueKey('course-class-${widget.classId}'),
      load: widget.load,
      path: '/api/teacher-workspace/classes',
      refreshToken: widget.refreshToken,
      builder: (data) {
        final matches = recordList(
          data,
        ).where((row) => '${row['id']}' == widget.classId);
        return Text(
          matches.isEmpty
              ? 'Selected class is unavailable. Confirm your class before recording results.'
              : 'Selected class: ${recordText(matches.first['name'])}',
          style: const TextStyle(color: muted),
        );
      },
    );
  }

  void openLesson(String id) {
    setState(() => lessonId = id);
    revealLessonHeading();
  }

  void revealLessonHeading() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || lessonAnchor.currentContext == null) return;
      Scrollable.ensureVisible(
        lessonAnchor.currentContext!,
        alignment: 0.05,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<dynamic> fetch() {
    final request = widget.load(
      module != null
          ? '/api/courses/modules/${Uri.encodeComponent('${module!['id']}')}/lessons'
          : course != null
          ? '/api/courses/${Uri.encodeComponent('${course!['id']}')}/modules'
          : '/api/teaching/courses',
    );
    request.ignore();
    return request;
  }

  void reload() => setState(() {
    future = fetch();
  });

  @override
  void didUpdateWidget(covariant TeacherCoursesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) future = fetch();
  }

  void backToCourses() => setState(() {
    course = null;
    module = null;
    lessonId = null;
    future = fetch();
  });

  void backToModules() => setState(() {
    module = null;
    lessonId = null;
    future = fetch();
  });

  Widget content(List<Map<String, dynamic>> rows) {
    final index = lessonId == null
        ? -1
        : rows.indexWhere((row) => '${row['id']}' == lessonId);
    final lesson = index < 0 ? null : rows[index];
    if (revealRestoredLesson && lesson != null) {
      revealRestoredLesson = false;
      revealLessonHeading();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(key: lessonAnchor),
        Semantics(
          container: true,
          header: true,
          child: PanelHeading(
            recordText(
              lesson?['title'] ?? module?['title'] ?? course?['title'],
              'My assigned courses',
            ),
            subtitle: lessonId != null
                ? 'Lesson content'
                : module != null
                ? 'Choose a lesson in this module.'
                : course != null
                ? 'Choose a module to see its lessons.'
                : 'Open a course to continue with its modules and lessons.',
          ),
        ),
        if (lessonId != null && lesson == null)
          const EmptyRecords(
            'This lesson is no longer available in this module. Return to Module lessons to choose another.',
          )
        else if (lesson != null) ...[
          Text(
            '${recordText(course?['title'])} / ${recordText(module?['title'])}',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 12),
          classContext(),
          const SizedBox(height: 12),
          Text(
            'Lesson ${index + 1} of ${rows.length}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (recordText(lesson['summary'], '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(recordText(lesson['summary'])),
            ),
          if (recordText(lesson['contentText'], '').isNotEmpty)
            SelectableText(
              recordText(lesson['contentText']),
              style: const TextStyle(height: 1.6),
            )
          else
            const EmptyRecords('No written lesson content has been added yet.'),
          const SizedBox(height: 24),
          TeacherLessonResources(
            key: ValueKey('teacher-lesson-resources-$lessonId'),
            lessonId: lessonId!,
            load: widget.load,
            apiBaseUrl: widget.apiBaseUrl,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: index > 0
                    ? () => openLesson('${rows[index - 1]['id']}')
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous lesson'),
              ),
              FilledButton.icon(
                key: const ValueKey('teacher-next-lesson'),
                onPressed: index + 1 < rows.length
                    ? () => openLesson('${rows[index + 1]['id']}')
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next lesson'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Reading a lesson does not record teaching or learner achievement.',
            style: TextStyle(color: muted),
          ),
          if (widget.onRecordLearning != null) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: chooseRecord,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Record lesson results'),
              ),
            ),
          ],
        ] else if (rows.isEmpty)
          EmptyRecords(
            module != null
                ? 'This module has no lessons yet.'
                : course != null
                ? 'This course has no modules yet.'
                : 'No courses are assigned to you yet. Ask your madrasa administrator to assign a course.',
          )
        else
          for (final row in rows)
            Semantics(
              container: true,
              child: ListTile(
                key: ValueKey('teacher-course-item-${row['id']}'),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 4,
                ),
                leading: Icon(
                  module != null
                      ? Icons.article_outlined
                      : Icons.menu_book_outlined,
                  color: blue,
                ),
                title: Text(
                  recordText(row['title']),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  module != null
                      ? 'Read lesson'
                      : course != null
                      ? 'View lessons'
                      : 'Open course',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (module != null) {
                    openLesson('${row['id']}');
                  } else {
                    setState(() {
                      if (course != null) {
                        module = row;
                      } else {
                        course = row;
                      }
                      future = fetch();
                    });
                  }
                },
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SurfacePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (course != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: backToCourses,
                icon: const Icon(Icons.arrow_back),
                label: const Text('All my courses'),
              ),
              if (module != null)
                TextButton(
                  onPressed: backToModules,
                  child: const Text('Course modules'),
                ),
              if (lessonId != null)
                TextButton(
                  onPressed: () => setState(() => lessonId = null),
                  child: const Text('Module lessons'),
                ),
            ],
          ),
        // Re-check the current module on refresh; never retain old lesson text
        // when the request fails or the lesson has been removed.
        PageResult(
          future: future,
          onRetry: reload,
          builder: (data) => content(recordList(data)),
        ),
      ],
    ),
  );
}
