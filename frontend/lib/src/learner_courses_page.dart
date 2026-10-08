import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'learner_lesson_reader.dart';
import 'learning_page.dart';
import 'learning_library_ui.dart';
import 'lesson_media_viewer.dart';
import 'media_player_preview.dart';
import 'teacher_ui.dart';

bool courseIsAvailable(dynamic state) => state == 'OPEN' || state == 'PREVIEW';
String courseAccessLabel(dynamic state) => switch (state) {
  'OPEN' => 'Available',
  'PREVIEW' => 'Preview',
  'PAYWALL' => 'Access required',
  _ => 'Locked',
};

class LearnerCoursesPage extends StatefulWidget {
  const LearnerCoursesPage({
    super.key,
    required this.load,
    required this.submit,
    required this.apiBaseUrl,
    this.refreshToken = 0,
    this.surfaceBuilder,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final String apiBaseUrl;
  final int refreshToken;
  final LessonMediaBuilder? surfaceBuilder;
  @override
  State<LearnerCoursesPage> createState() => _LearnerCoursesPageState();
}

class _LearnerCoursesPageState extends State<LearnerCoursesPage> {
  String search = '', subject = 'all', access = 'all';
  bool grid = true;
  int changes = 0;

  Future<void> openCourse(
    Map<String, dynamic> course, {
    bool resume = false,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CourseCurriculumPage(
          id: recordText(course['id']),
          load: widget.load,
          submit: widget.submit,
          apiBaseUrl: widget.apiBaseUrl,
          surfaceBuilder: widget.surfaceBuilder,
          resumeLessonId: resume
              ? recordMap(course['resumeLesson'])['id'] as String?
              : null,
        ),
      ),
    );
    if (mounted) setState(() => changes++);
  }

  Widget progress(Map<String, dynamic> course) {
    final value = recordMap(course['progress']);
    final total = recordNumber(value['totalLessons']).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: total == 0
              ? 0
              : (recordNumber(value['progressPercent']) / 100).clamp(0, 1),
          backgroundColor: line,
          color: forest,
          minHeight: 6,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 8),
        Text(
          total == 0
              ? 'No published lessons yet'
              : '${value['completedLessons']} / $total lessons complete',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget card(Map<String, dynamic> course) => SurfacePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CourseCover(
          subject: recordText(recordMap(course['subject'])['name']),
          lessons: recordNumber(
            recordMap(course['progress'])['totalLessons'],
          ).toInt(),
        ),
        const SizedBox(height: 16),
        Text(
          recordText(course['title']),
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          recordText(course['summary']),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 14),
        Text(
          recordText(
            recordMap(course['primaryInstructor'])['fullName'],
            'Instructor not assigned',
          ),
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TeacherTag(
              courseAccessLabel(course['accessState']),
              color: courseIsAvailable(course['accessState']) ? forest : gold,
            ),
            if (course['level'] != null)
              TeacherTag(recordText(course['level'])),
            if (course['accessState'] == 'PAYWALL' &&
                course['priceAmount'] != null)
              TeacherTag(
                '${course['currency']} ${course['priceAmount']}',
                color: gold,
              ),
          ],
        ),
        const SizedBox(height: 20),
        progress(course),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => openCourse(course),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('View lessons'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      catalogue(),
      const SizedBox(height: 18),
      Align(
        alignment: Alignment.centerLeft,
        child: MediaPlayerPreviewButton(surfaceBuilder: widget.surfaceBuilder),
      ),
    ],
  );

  Widget catalogue() => TeacherData(
    load: widget.load,
    path: '/api/learner/courses',
    refreshToken: widget.refreshToken + changes,
    builder: (raw) {
      final courses = recordList(raw), subjects = <String, String>{};
      for (final course in courses) {
        final row = recordMap(course['subject']);
        subjects[recordText(row['id'])] = recordText(row['name']);
      }
      final selectedSubject = subjects.containsKey(subject) ? subject : 'all';
      final rows = courses.where((course) {
        final query =
            '${course['title']} ${course['summary']} ${recordMap(course['subject'])['name']} ${recordMap(course['primaryInstructor'])['fullName']}'
                .toLowerCase();
        return query.contains(search.trim().toLowerCase()) &&
            (selectedSubject == 'all' ||
                '${recordMap(course['subject'])['id']}' == selectedSubject) &&
            (access == 'all' ||
                (access == 'available'
                    ? courseIsAvailable(course['accessState'])
                    : !courseIsAvailable(course['accessState'])));
      }).toList();
      final resume = courseToResume(rows);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (resume != null) ...[
            ContinueCourseCard(
              course: resume,
              onResume: () => openCourse(resume, resume: true),
            ),
            const SizedBox(height: 22),
          ],
          if (subjects.isNotEmpty) ...[
            const PanelHeading(
              'Browse by subject',
              subtitle: 'Choose a subject to filter your learning library.',
            ),
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 900
                    ? 4
                    : box.maxWidth >= 540
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final entry in subjects.entries)
                      SizedBox(
                        width: (box.maxWidth - (columns - 1) * 12) / columns,
                        child: Semantics(
                          selected: selectedSubject == entry.key,
                          child: Material(
                            color: selectedSubject == entry.key
                                ? ink
                                : subjectStyle(
                                    entry.value,
                                  ).$2.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              key: ValueKey('subject-filter-${entry.key}'),
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => setState(
                                () => subject = selectedSubject == entry.key
                                    ? 'all'
                                    : entry.key,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  children: [
                                    Icon(
                                      subjectStyle(entry.value).$1,
                                      color: selectedSubject == entry.key
                                          ? Colors.white
                                          : subjectStyle(entry.value).$2,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        entry.value,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: selectedSubject == entry.key
                                              ? Colors.white
                                              : ink,
                                        ),
                                      ),
                                    ),
                                    if (selectedSubject == entry.key)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
          ],
          SurfacePanel(
            // Keep input state when filtering inserts or removes the resume card.
            key: const ValueKey('learner-course-filters'),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 330,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search subjects or courses',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => search = v),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(selectedSubject),
                    initialValue: selectedSubject,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All subjects'),
                      ),
                      for (final entry in subjects.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => subject = v ?? 'all'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: access,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Access'),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All courses'),
                      ),
                      DropdownMenuItem(
                        value: 'available',
                        child: Text('Available / preview'),
                      ),
                      DropdownMenuItem(
                        value: 'restricted',
                        child: Text('Access required'),
                      ),
                    ],
                    onChanged: (v) => setState(() => access = v ?? 'all'),
                  ),
                ),
                ChoiceChip(
                  label: const Text('Grid'),
                  avatar: const Icon(Icons.grid_view, size: 18),
                  selected: grid,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => grid = true),
                ),
                ChoiceChip(
                  label: const Text('List'),
                  avatar: const Icon(Icons.view_list_outlined, size: 18),
                  selected: !grid,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => grid = false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PanelHeading(
            'My Subjects & Courses',
            subtitle:
                '${rows.length} of ${courses.length} published courses in your learning programme',
          ),
          if (rows.isEmpty)
            SurfacePanel(
              child: EmptyRecords(
                courses.isEmpty
                    ? 'No courses have been published for your programme yet.'
                    : 'No courses match these filters.',
              ),
            )
          else if (grid)
            LayoutBuilder(
              builder: (context, size) {
                final columns = size.maxWidth >= 1100
                    ? 3
                    : size.maxWidth >= 660
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    for (final course in rows)
                      SizedBox(
                        width: (size.maxWidth - (columns - 1) * 18) / columns,
                        child: card(course),
                      ),
                  ],
                );
              },
            )
          else
            SurfacePanel(
              child: RecordTable(
                columns: const ['Course', 'Subject', 'Access', 'Progress', ''],
                rows: [
                  for (final course in rows)
                    DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              recordText(course['title']),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            recordText(recordMap(course['subject'])['name']),
                          ),
                        ),
                        DataCell(
                          TeacherTag(courseAccessLabel(course['accessState'])),
                        ),
                        DataCell(SizedBox(width: 180, child: progress(course))),
                        DataCell(
                          OutlinedButton(
                            onPressed: () => openCourse(course),
                            child: const Text('View lessons'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          const TeacherNotice(
            'Completion reflects the lessons you have marked complete. Your teacher records assessment results and Qur\'an memorisation separately.',
          ),
        ],
      );
    },
  );
}

/// The home shelf shares the same authorized course-to-lesson flow as the library.
class LearnerLearningHome extends StatefulWidget {
  const LearnerLearningHome({
    super.key,
    required this.load,
    required this.submit,
    required this.apiBaseUrl,
    required this.onBrowse,
    this.refreshToken = 0,
    this.surfaceBuilder,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final String apiBaseUrl;
  final VoidCallback onBrowse;
  final int refreshToken;
  final LessonMediaBuilder? surfaceBuilder;
  @override
  State<LearnerLearningHome> createState() => _LearnerLearningHomeState();
}

class _LearnerLearningHomeState extends State<LearnerLearningHome> {
  int changes = 0;
  Future<void> open(Map<String, dynamic> course, {bool resume = false}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CourseCurriculumPage(
          backLabel: 'Back to home',
          id: recordText(course['id']),
          load: widget.load,
          submit: widget.submit,
          apiBaseUrl: widget.apiBaseUrl,
          surfaceBuilder: widget.surfaceBuilder,
          resumeLessonId: resume
              ? recordText(recordMap(course['resumeLesson'])['id'], '')
              : null,
        ),
      ),
    );
    if (mounted) setState(() => changes++);
  }

  @override
  Widget build(BuildContext context) => TeacherData(
    load: widget.load,
    path: '/api/learner/courses',
    refreshToken: widget.refreshToken + changes,
    builder: (raw) {
      final courses = recordList(raw), resume = courseToResume(recordList(raw));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LearningWelcome(
            title: 'Make room for discovery.',
            subtitle:
                'Your subjects, lessons and next steps, all in one place.',
          ),
          const SizedBox(height: 18),
          if (resume != null) ...[
            ContinueCourseCard(
              course: resume,
              onResume: () => open(resume, resume: true),
            ),
            const SizedBox(height: 18),
          ],
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Your learning library',
                  style: TextStyle(
                    fontSize: 20,
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onBrowse,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('All courses'),
                ),
              ],
            ),
          ),
          if (courses.isEmpty)
            const EmptyRecords(
              'Published courses will appear here when your school makes them available.',
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 540 ? 2 : 1;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final course in courses.take(4))
                      SizedBox(
                        width: (box.maxWidth - (columns - 1) * 12) / columns,
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            key: ValueKey('home-course-${course['id']}'),
                            onTap: () => open(course),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  CourseCover(
                                    subject: recordText(
                                      recordMap(course['subject'])['name'],
                                    ),
                                    lessons: recordNumber(
                                      recordMap(
                                        course['progress'],
                                      )['totalLessons'],
                                    ).toInt(),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      12,
                                      4,
                                      6,
                                    ),
                                    child: Text(
                                      recordText(course['title']),
                                      style: const TextStyle(
                                        color: ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Text(
                                      courseAccessLabel(course['accessState']),
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      );
    },
  );
}

class CourseCurriculumPage extends StatefulWidget {
  const CourseCurriculumPage({
    super.key,
    required this.id,
    required this.load,
    required this.submit,
    required this.apiBaseUrl,
    this.surfaceBuilder,
    this.resumeLessonId,
    this.backLabel = 'Back to courses',
  });
  final String id, apiBaseUrl;
  final PageLoader load;
  final PageSubmitter submit;
  final LessonMediaBuilder? surfaceBuilder;
  final String? resumeLessonId;
  final String backLabel;
  @override
  State<CourseCurriculumPage> createState() => _CourseCurriculumPageState();
}

class _CourseCurriculumPageState extends State<CourseCurriculumPage> {
  int refresh = 0;
  bool resumeHandled = false;
  String? resumeNotice;
  Future<void> lesson(String id, List<Map<String, dynamic>> outline) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => LearnerLessonReader(
          id: id,
          load: widget.load,
          submit: widget.submit,
          apiBaseUrl: widget.apiBaseUrl,
          surfaceBuilder: widget.surfaceBuilder,
          outline: outline,
        ),
      ),
    );
    if (mounted) setState(() => refresh++);
  }

  @override
  Widget build(BuildContext context) => LearningPage(
    title: 'Course curriculum',
    backLabel: widget.backLabel,
    onBack: () => Navigator.pop(context),
    child: TeacherData(
      load: widget.load,
      path: '/api/learner/courses/${widget.id}',
      refreshToken: refresh,
      builder: (raw) {
        final course = recordMap(recordMap(raw)['course']),
            modules = recordList(course['modules']);
        final lessons = [
          for (final module in modules)
            for (final row in recordList(module['lessons']))
              {
                ...row,
                'moduleTitle': recordText(module['title']),
                'moduleId': module['id'],
              },
        ];
        final next = lessons
            .where(
              (l) =>
                  courseIsAvailable(l['accessState']) &&
                  recordNumber(recordMap(l['progress'])['progressPercent']) <
                      100,
            )
            .firstOrNull;
        if (!resumeHandled && widget.resumeLessonId != null) {
          resumeHandled = true;
          final target = lessons
              .where(
                (row) =>
                    recordText(row['id']) == widget.resumeLessonId &&
                    courseIsAvailable(row['accessState']),
              )
              .firstOrNull;
          if (target == null) {
            resumeNotice =
                'That lesson is no longer available. Choose an available lesson below.';
          } else {
            // A resume hint is not authorization. Use the freshly loaded outline.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) lesson(recordText(target['id']), lessons);
            });
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (resumeNotice != null) ...[
              TeacherNotice(resumeNotice!, warning: true),
              const SizedBox(height: 16),
            ],
            CourseCover(
              subject: recordText(
                recordMap(course['subject'])['name'],
                'Course curriculum',
              ),
              lessons: lessons.length,
            ),
            const SizedBox(height: 20),
            Text(
              recordText(course['title']),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              recordText(course['summary']),
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 14),
            if (course['description'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SelectableText(recordText(course['description'])),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TeacherTag(
                  courseAccessLabel(course['accessState']),
                  color: gold,
                ),
                Text(
                  '${recordMap(course['progress'])['completedLessons']} / ${recordMap(course['progress'])['totalLessons']} lessons complete',
                ),
                if (next != null)
                  FilledButton.icon(
                    onPressed: () => lesson(recordText(next['id']), lessons),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continue learning'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (!courseIsAvailable(course['accessState']))
              const Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: TeacherNotice(
                  'Some lessons require school-approved access. Available previews can be opened below. Contact the school about enrolment or payment.',
                  warning: true,
                ),
              ),
            if (modules.isEmpty)
              const EmptyRecords('No published lessons in this course yet.'),
            for (final module in modules)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PanelHeading(
                        recordText(module['title']),
                        subtitle: module['summary'] as String?,
                      ),
                      for (final row in recordList(module['lessons']))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Wrap(
                            spacing: 14,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                recordNumber(
                                          recordMap(
                                            row['progress'],
                                          )['progressPercent'],
                                        ) >=
                                        100
                                    ? Icons.check_circle
                                    : courseIsAvailable(row['accessState'])
                                    ? Icons.menu_book_outlined
                                    : Icons.lock_outline,
                                color:
                                    recordNumber(
                                          recordMap(
                                            row['progress'],
                                          )['progressPercent'],
                                        ) >=
                                        100
                                    ? forest
                                    : muted,
                              ),
                              SizedBox(
                                width: 210,
                                child: Text(
                                  recordText(row['title']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TeacherTag(courseAccessLabel(row['accessState'])),
                              if (row['estimatedMinutes'] != null)
                                Text(
                                  '${row['estimatedMinutes']} min',
                                  style: const TextStyle(color: muted),
                                ),
                              OutlinedButton(
                                onPressed: courseIsAvailable(row['accessState'])
                                    ? () =>
                                          lesson(recordText(row['id']), lessons)
                                    : null,
                                child: Text(
                                  courseIsAvailable(row['accessState'])
                                      ? 'Open lesson'
                                      : 'Locked',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
