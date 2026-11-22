import 'package:flutter/material.dart';
import 'lesson_upload.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_lesson_resources.dart';
import 'teacher_lesson_access.dart';
import 'teacher_ui.dart';
import 'workspace_form_dialog.dart';
import 'design_tokens.dart';
import 'teacher_course_modules.dart';
import 'teacher_lesson_reading.dart';
import 'teacher_course_catalogue.dart';
import 'teacher_course_workspace.dart';

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
    this.submit,
    this.update,
    this.upload,
  });
  final PageLoader load;
  final Future<dynamic> Function(String, Map<String, dynamic>)? submit;
  final Future<dynamic> Function(String, Map<String, dynamic>)? update;
  final LessonUploader? upload;
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
    if (course == null) {
      return TeacherCourseCatalogue(
        update: widget.update,
        upload: widget.upload,
        submit: widget.submit,
        courses: rows,
        load: widget.load,
        apiBaseUrl: widget.apiBaseUrl,
        refreshToken: widget.refreshToken,
        onOpen: (selected) => setState(() {
          course = selected;
          future = fetch();
        }),
        onModule: (selected, selectedModule) => setState(() {
          course = selected;
          module = selectedModule;
          future = fetch();
        }),
      );
    }
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
        if (lesson == null)
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
            'This lesson is no longer available in this module. Select the module above to choose another lesson.',
          )
        else if (lesson != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8BC59),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu_book_outlined,
                        color: Color(0xFF102E43),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lesson ${index + 1} of ${rows.length}',
                            style: const TextStyle(
                              color: Color(0xFF8D681C),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Semantics(
                            header: true,
                            child: Text(
                              recordText(lesson['title']),
                              style: const TextStyle(
                                fontSize: 30,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F6F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.groups_outlined, size: 20, color: muted),
                      const SizedBox(width: 10),
                      Expanded(child: classContext()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TeacherLessonReading(
            summary: recordText(lesson['summary'], ''),
            text: recordText(lesson['contentText'], ''),
          ),
          const SizedBox(height: 24),
          TeacherLessonAccess(
            key: ValueKey('access-$lessonId'),
            lesson: lesson,
            course: course,
            update: widget.update,
          ),
          const SizedBox(height: 16),
          TeacherLessonResources(
            update: widget.update,
            upload: widget.upload,
            submit: widget.submit,
            key: ValueKey('teacher-lesson-resources-$lessonId'),
            lessonId: lessonId!,
            load: widget.load,
            apiBaseUrl: widget.apiBaseUrl,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F6F9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDDE7ED)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: index > 0
                          ? () => openLesson('${rows[index - 1]['id']}')
                          : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous lesson'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      key: const ValueKey('teacher-next-lesson'),
                      onPressed: index + 1 < rows.length
                          ? () => openLesson('${rows[index + 1]['id']}')
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next lesson'),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: Color(0xFFDDE7ED)),
                ),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: muted),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Reading a lesson does not record teaching or learner achievement.',
                        style: TextStyle(color: muted, height: 1.5),
                      ),
                    ),
                  ],
                ),
                if (widget.onRecordLearning != null) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: chooseRecord,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Record lesson results'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else if (rows.isEmpty)
          EmptyRecords(
            module != null
                ? 'This module has no lessons yet.'
                : course != null
                ? 'This course has no modules yet.'
                : 'No courses are assigned to you yet. Ask your madrasa administrator to assign a course.',
          )
        else if (course != null && module == null)
          TeacherCourseModules(
            course: course!,
            modules: rows,
            onOpen: (row) => setState(() {
              module = row;
              future = fetch();
            }),
          )
        else
          for (final (lessonIndex, row) in rows.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFDDE5ED)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Semantics(
                  container: true,
                  child: ListTile(
                    key: ValueKey('teacher-course-item-${row['id']}'),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3D7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${lessonIndex + 1}'.padLeft(2, '0'),
                        style: const TextStyle(
                          color: AfaqDesign.actionGold,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      recordText(row['title']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        height: 1.35,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (recordText(
                            row['summary'],
                            '',
                          ).trim().isNotEmpty) ...[
                            Text(
                              recordText(row['summary']),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (row['estimatedMinutes'] is num &&
                                  (row['estimatedMinutes'] as num) > 0)
                                Text(
                                  '${TeacherCourseModules.duration(row['estimatedMinutes'] as num)} estimated',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: muted,
                                  ),
                                ),
                              const Text(
                                'Read lesson',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openLesson('${row['id']}'),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) =>
      course == null && widget.submit != null && widget.update != null
      ? TeacherCourseWorkspace(
          load: widget.load,
          submit: widget.submit!,
          update: widget.update!,
          upload: widget.upload,
          apiBaseUrl: widget.apiBaseUrl,
          onPreview: (selectedCourse, selectedModule, selectedLesson) {
            setState(() {
              course = selectedCourse;
              module = selectedModule;
              lessonId = '${selectedLesson['id']}';
              future = fetch();
            });
          },
        )
      : SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (course != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: backToCourses,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('All my courses'),
                    ),
                    if (module != null)
                      const Icon(Icons.chevron_right, size: 18, color: muted),
                    if (module != null)
                      TextButton(
                        key: const ValueKey('teacher-course-breadcrumb'),
                        onPressed: backToModules,
                        child: Text(
                          recordText(course?['title'], 'Course modules'),
                        ),
                      ),
                    if (lessonId != null)
                      const Icon(Icons.chevron_right, size: 18, color: muted),
                    if (lessonId != null)
                      TextButton(
                        key: const ValueKey('teacher-module-breadcrumb'),
                        onPressed: () => setState(() => lessonId = null),
                        child: Text(
                          recordText(module?['title'], 'Module lessons'),
                        ),
                      ),
                  ],
                ),
              if (course != null) const SizedBox(height: 16),
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
