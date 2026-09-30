import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'learner_lesson_reader.dart';
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
    this.openResource,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final String apiBaseUrl;
  final int refreshToken;
  final LessonResourceOpener? openResource;
  @override
  State<LearnerCoursesPage> createState() => _LearnerCoursesPageState();
}

class _LearnerCoursesPageState extends State<LearnerCoursesPage> {
  String search = '', subject = 'all', access = 'all';
  bool grid = true;
  int changes = 0;

  Future<void> openCourse(Map<String, dynamic> course) async {
    await showDialog<void>(
      context: context,
      builder: (context) => CourseCurriculumDialog(
        id: recordText(course['id']),
        load: widget.load,
        submit: widget.submit,
        apiBaseUrl: widget.apiBaseUrl,
        openResource: widget.openResource,
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: forest.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_stories_outlined,
                color: forest,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                recordText(recordMap(course['subject'])['name']),
                style: const TextStyle(color: muted),
              ),
            ),
          ],
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
  Widget build(BuildContext context) => TeacherData(
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SurfacePanel(
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

class CourseCurriculumDialog extends StatefulWidget {
  const CourseCurriculumDialog({
    super.key,
    required this.id,
    required this.load,
    required this.submit,
    required this.apiBaseUrl,
    this.openResource,
  });
  final String id, apiBaseUrl;
  final PageLoader load;
  final PageSubmitter submit;
  final LessonResourceOpener? openResource;
  @override
  State<CourseCurriculumDialog> createState() => _CourseCurriculumDialogState();
}

class _CourseCurriculumDialogState extends State<CourseCurriculumDialog> {
  int refresh = 0;
  Future<void> lesson(String id) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => LearnerLessonReader(
        id: id,
        load: widget.load,
        submit: widget.submit,
        apiBaseUrl: widget.apiBaseUrl,
        openResource: widget.openResource,
      ),
    );
    if (mounted) setState(() => refresh++);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.all(16),
    child: SizedBox(
      width: 1000,
      height: MediaQuery.sizeOf(context).height * .88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Course curriculum',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close course',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: TeacherData(
                load: widget.load,
                path: '/api/learner/courses/${widget.id}',
                refreshToken: refresh,
                builder: (raw) {
                  final course = recordMap(recordMap(raw)['course']),
                      modules = recordList(course['modules']);
                  final lessons = modules
                      .expand((m) => recordList(m['lessons']))
                      .toList();
                  final next = lessons
                      .where(
                        (l) =>
                            courseIsAvailable(l['accessState']) &&
                            recordNumber(
                                  recordMap(l['progress'])['progressPercent'],
                                ) <
                                100,
                      )
                      .firstOrNull;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        recordText(course['title']),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
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
                          child: SelectableText(
                            recordText(course['description']),
                          ),
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
                              onPressed: () => lesson(recordText(next['id'])),
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
                        const EmptyRecords(
                          'No published lessons in this course yet.',
                        ),
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Wrap(
                                      spacing: 14,
                                      runSpacing: 10,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Icon(
                                          recordNumber(
                                                    recordMap(
                                                      row['progress'],
                                                    )['progressPercent'],
                                                  ) >=
                                                  100
                                              ? Icons.check_circle
                                              : courseIsAvailable(
                                                  row['accessState'],
                                                )
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
                                        TeacherTag(
                                          courseAccessLabel(row['accessState']),
                                        ),
                                        if (row['estimatedMinutes'] != null)
                                          Text(
                                            '${row['estimatedMinutes']} min',
                                            style: const TextStyle(
                                              color: muted,
                                            ),
                                          ),
                                        OutlinedButton(
                                          onPressed:
                                              courseIsAvailable(
                                                row['accessState'],
                                              )
                                              ? () => lesson(
                                                  recordText(row['id']),
                                                )
                                              : null,
                                          child: Text(
                                            courseIsAvailable(
                                                  row['accessState'],
                                                )
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
            ),
          ),
        ],
      ),
    ),
  );
}
