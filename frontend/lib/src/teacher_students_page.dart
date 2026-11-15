import 'design_tokens.dart';
import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';
import 'student_course_progress.dart';

class TeacherStudentsPage extends StatefulWidget {
  const TeacherStudentsPage({
    super.key,
    required this.load,
    required this.submit,
    required this.onOpen,
    this.initialClassId,
    this.initialStudent,
    this.openInitialProfile = true,
    this.onClassChanged,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final TeacherNavigate onOpen;
  final String? initialClassId;
  final ValueChanged<String>? onClassChanged;
  final Map<String, dynamic>? initialStudent;
  final bool openInitialProfile;
  final int refreshToken;
  @override
  State<TeacherStudentsPage> createState() => _TeacherStudentsPageState();
}

class _TeacherStudentsPageState extends State<TeacherStudentsPage> {
  late String classId = widget.initialClassId ?? '';
  String search = '', support = 'all';
  int page = 1;
  late Future<dynamic> future = fetch();
  late Future<dynamic> classes = widget.load('/api/teacher-workspace/classes');
  Future<dynamic> fetch() {
    final request = widget.load(
      '/api/teacher-workspace/students?${Uri(queryParameters: {if (classId.isNotEmpty) 'classId': classId, 'search': search, 'support': support, 'page': '$page'}).query}',
    );
    // Reloads can fail before the next frame attaches PageResult's listener.
    request.ignore();
    return request;
  }

  void reload() => setState(() {
    future = fetch();
  });
  @override
  void initState() {
    super.initState();
    if (widget.openInitialProfile && widget.initialStudent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) profile(widget.initialStudent!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant TeacherStudentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      future = fetch();
      classes = widget.load('/api/teacher-workspace/classes');
    }
  }

  Future<void> profile(Map<String, dynamic> student) async {
    final record = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TeacherStudentProfile(
        studentId: '${student['id']}',
        load: widget.load,
        submit: widget.submit,
      ),
    );
    if (!mounted) return;
    if (record != null) {
      widget.onOpen(3, classId: '${record['classId']}', student: record);
    } else {
      reload();
    }
  }

  @override
  Widget build(BuildContext context) => PageResult(
    future: future,
    onRetry: reload,
    builder: (value) {
      final data = recordMap(value), summary = recordMap(data['summary']);
      final students = recordList(data['items']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MetricRow(
            children: [
              TeacherMetric(
                'Assigned students',
                '${summary['assignedStudents']}',
                'Only your current classes',
                Icons.people_outline,
                blue,
              ),
              TeacherMetric(
                'My classes',
                '${summary['classes']}',
                'Current assignments',
                Icons.co_present_outlined,
                forest,
              ),
              TeacherMetric(
                'Need follow-up',
                '${summary['followUps']}',
                'Open support notes',
                Icons.menu_book_outlined,
                gold,
              ),
              TeacherMetric(
                'Learning records',
                '${summary['withLearningRecords']}',
                "Students with Qur'an sessions",
                Icons.description_outlined,
                lavender,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PanelHeading(
                  'My student list',
                  subtitle:
                      'Student enrolment is managed by the school office.',
                ),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: 340,
                      child: TextFormField(
                        initialValue: search,
                        decoration: const InputDecoration(
                          labelText: 'Search name or student number',
                          prefixIcon: Icon(Icons.search),
                          suffixIcon: Icon(Icons.keyboard_return),
                        ),
                        textInputAction: TextInputAction.search,
                        onFieldSubmitted: (v) {
                          search = v.trim();
                          page = 1;
                          reload();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: PageResult(
                        future: classes,
                        onRetry: () => setState(() {
                          classes = widget.load(
                            '/api/teacher-workspace/classes',
                          );
                        }),
                        builder: (value) => DropdownButtonFormField<String>(
                          initialValue:
                              recordList(
                                value,
                              ).any((c) => '${c['id']}' == classId)
                              ? classId
                              : '',
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Class'),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All my classes'),
                            ),
                            for (final c in recordList(value))
                              DropdownMenuItem(
                                value: '${c['id']}',
                                child: Text('${c['name']}'),
                              ),
                          ],
                          onChanged: (v) {
                            classId = v ?? '';
                            widget.onClassChanged?.call(classId);
                            page = 1;
                            reload();
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: support,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Learning support',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All students'),
                          ),
                          DropdownMenuItem(
                            value: 'open',
                            child: Text('Needs follow-up'),
                          ),
                        ],
                        onChanged: (v) {
                          support = v ?? 'all';
                          page = 1;
                          reload();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (students.isEmpty)
                  const EmptyRecords('No students match these filters.')
                else
                  RecordTable(
                    minWidth: 940,
                    columns: const [
                      'Student',
                      'Class',
                      "Last Qur'an record",
                      'Learning support',
                      'Status',
                      '',
                    ],
                    rows: [
                      for (final s in students)
                        DataRow(
                          cells: [
                            DataCell(
                              SizedBox(width: 210, child: StudentIdentity(s)),
                            ),
                            DataCell(
                              Text(
                                recordText(
                                  recordMap(s['currentClass'])['name'],
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                recordList(s['quranSessions']).isEmpty
                                    ? 'Not recorded'
                                    : passageLabel(
                                        recordList(s['quranSessions']).first,
                                      ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 180,
                                child: Text(
                                  recordList(s['supportNotes']).isEmpty
                                      ? 'No open follow-up'
                                      : '${recordList(s['supportNotes']).first['note']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const DataCell(TeacherTag('Active')),
                            DataCell(
                              OutlinedButton.icon(
                                onPressed: () => profile(s),
                                icon: const Icon(
                                  Icons.chevron_right,
                                  size: AfaqDesign.iconSmall,
                                ),
                                label: const Text('View profile'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                DirectoryPager(
                  meta: recordMap(data['meta']),
                  onPage: (v) {
                    page = v;
                    reload();
                  },
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class TeacherStudentProfile extends StatefulWidget {
  const TeacherStudentProfile({
    super.key,
    required this.studentId,
    required this.load,
    required this.submit,
  });
  final String studentId;
  final PageLoader load;
  final PageSubmitter submit;
  @override
  State<TeacherStudentProfile> createState() => _TeacherStudentProfileState();
}

class _TeacherStudentProfileState extends State<TeacherStudentProfile> {
  int section = 0;
  String noteFilter = 'Open';
  late Future<dynamic> future = fetch();
  Future<dynamic> fetch() {
    final request = widget.load(
      '/api/teacher-workspace/students/${widget.studentId}',
    );
    // A save-triggered reload may fail before the next frame subscribes.
    request.ignore();
    return request;
  }

  void reload() => setState(() {
    future = fetch();
  });
  Future<void> addNote(Map<String, dynamic> student) async {
    final id = submissionId();
    final saved = await showAdminForm(
      context,
      title: 'Add learning follow-up',
      note:
          'Describe the support this student needs. This note is for school staff.',
      fields: const [AdminField('note', 'Support needed')],
      onSave: (values) async {
        await widget.submit('/api/teacher-workspace/support', {
          ...values,
          'clientId': id,
          'studentId': widget.studentId,
          'classId': '${student['classId']}',
        });
      },
    );
    if (saved && mounted) {
      section = 0;
      noteFilter = 'Open';
      reload();
    }
  }

  Future<void> resolve(Map<String, dynamic> note) async {
    final saved = await showAdminForm(
      context,
      title: 'Complete this follow-up?',
      note: '${note['note']}\n\nThe note stays in the student history.',
      fields: const [],
      saveLabel: 'Mark completed',
      onSave: (_) async {
        await widget.submit(
          '/api/teacher-workspace/support/${note['id']}/resolve',
          {},
        );
      },
    );
    if (saved && mounted) reload();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    clipBehavior: Clip.antiAlias,
    backgroundColor: const Color(0xFFF8FAFC),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: SizedBox(
      width: 1060,
      height: MediaQuery.sizeOf(context).height * .9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
            child: Row(
              children: [
                const Icon(Icons.school_outlined, color: gold, size: 30),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Student learning profile',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close profile',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: PageResult(
                future: future,
                onRetry: reload,
                builder: (value) {
                  final data = recordMap(value),
                      student = recordMap(data['student']);
                  final notes = recordList(data['supportNotes']);
                  final sessions = recordList(data['sessions']);
                  final openNotes = notes
                      .where((n) => n['resolvedAt'] == null)
                      .length;
                  final visibleNotes = notes
                      .where(
                        (n) =>
                            noteFilter == 'All' ||
                            (noteFilter == 'Open'
                                ? n['resolvedAt'] == null
                                : n['resolvedAt'] != null),
                      )
                      .toList();
                  final progress = recordMap(data['courseProgress']);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SurfacePanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              recordText(student['fullName'], 'Student'),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                TeacherTag(
                                  recordText(
                                    recordMap(student['currentClass'])['name'],
                                    'Class not recorded',
                                  ),
                                  color: blue,
                                ),
                                TeacherTag(
                                  recordText(
                                    student['admissionNo'],
                                    'Student number not recorded',
                                  ),
                                  color: muted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: () =>
                                      Navigator.pop(context, student),
                                  icon: const Icon(Icons.menu_book_outlined),
                                  label: const Text("Record Qur'an"),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => addNote(student),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add follow-up'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Review learning records and organise the next support action.',
                              style: TextStyle(color: muted, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, box) {
                          final columns =
                              box.maxWidth /
                                      (MediaQuery.textScalerOf(
                                            context,
                                          ).scale(16) /
                                          16) >=
                                  720
                              ? 3
                              : 1;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final item in [
                                (
                                  0,
                                  Icons.assignment_outlined,
                                  'Learning support',
                                  '$openNotes open',
                                  gold,
                                ),
                                (
                                  1,
                                  Icons.menu_book_outlined,
                                  "Qur'an sessions",
                                  '${sessions.length} recent records',
                                  forest,
                                ),
                                (
                                  2,
                                  Icons.play_circle_outline,
                                  'Course activity',
                                  progress.isEmpty
                                      ? 'Unavailable'
                                      : progress['linked'] == true
                                      ? 'Learner-reported'
                                      : 'No linked login',
                                  blue,
                                ),
                              ])
                                SizedBox(
                                  width:
                                      (box.maxWidth - (columns - 1) * 12) /
                                      columns,
                                  child: Semantics(
                                    selected: section == item.$1,
                                    button: true,
                                    child: Material(
                                      color: item.$5.withValues(
                                        alpha: section == item.$1 ? .12 : .04,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: item.$5.withValues(
                                            alpha: section == item.$1
                                                ? .7
                                                : .18,
                                          ),
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () =>
                                            setState(() => section = item.$1),
                                        child: Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: Row(
                                            children: [
                                              Icon(
                                                item.$2,
                                                color: item.$5,
                                                size: 30,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.$3,
                                                      style: const TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: ink,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      item.$4,
                                                      style: const TextStyle(
                                                        color: muted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (section == item.$1)
                                                Icon(
                                                  Icons.check_circle,
                                                  size: 20,
                                                  color: item.$5,
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
                      const SizedBox(height: 24),
                      if (section == 2) StudentCourseProgress(data: progress),
                      if (section == 0) ...[
                        const PanelHeading(
                          'Learning support',
                          subtitle:
                              'Latest 50 notes. Completed follow-ups remain in the history.',
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final filter in ['Open', 'Completed', 'All'])
                              ChoiceChip(
                                label: Text(
                                  '$filter (${filter == 'Open'
                                      ? openNotes
                                      : filter == 'Completed'
                                      ? notes.length - openNotes
                                      : notes.length})',
                                ),
                                selected: noteFilter == filter,
                                onSelected: (_) =>
                                    setState(() => noteFilter = filter),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (visibleNotes.isEmpty)
                          _profileEmpty(
                            Icons.task_alt,
                            'No ${noteFilter == 'All' ? '' : '${noteFilter.toLowerCase()} '}follow-ups',
                            noteFilter == 'Open'
                                ? 'Use Add follow-up when this student needs learning support.'
                                : 'Follow-up notes will appear here when recorded.',
                          ),
                        for (final n in visibleNotes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SurfacePanel(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TeacherTag(
                                    n['resolvedAt'] == null
                                        ? 'Open follow-up'
                                        : 'Completed',
                                    color: n['resolvedAt'] == null
                                        ? gold
                                        : forest,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${n['note']}',
                                    style: const TextStyle(
                                      color: ink,
                                      height: 1.6,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${recordText(recordMap(n['createdBy'])['fullName'], 'School staff')} | ${shortDate(n['createdAt'])}',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (n['resolvedAt'] == null)
                                    TextButton(
                                      onPressed: () => resolve(n),
                                      child: const Text('Mark completed'),
                                    )
                                  else
                                    TeacherTag(
                                      'Completed ${shortDate(n['resolvedAt'])}',
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      if (section == 1) ...[
                        const PanelHeading(
                          "Recent Qur'an sessions",
                          subtitle: 'Latest 20 sessions across all surahs.',
                        ),
                        for (final s in sessions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SurfacePanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      Text(
                                        passageLabel(s),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                        ),
                                      ),
                                      TeacherTag(
                                        s['voidedAt'] == null
                                            ? learningObservations[s['observation']] ??
                                                  'Recorded'
                                            : 'Voided',
                                        color: s['voidedAt'] == null
                                            ? forest
                                            : muted,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${learningActivities[s['activity']] ?? 'Learning session'} | ${shortDate(s['learnedOn'])}',
                                    style: const TextStyle(color: muted),
                                  ),
                                  if (recordText(s['note'], '').isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      recordText(s['note'], ''),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        if (sessions.isEmpty)
                          _profileEmpty(
                            Icons.menu_book_outlined,
                            'No learning sessions recorded yet.',
                            "Use Record Qur'an to add a teacher observation for this student.",
                          ),
                      ],
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

  Widget _profileEmpty(IconData icon, String title, String detail) =>
      SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(detail, style: const TextStyle(color: muted, height: 1.5)),
          ],
        ),
      );
}

Future<Map<String, dynamic>?> pickTeacherStudent(
  BuildContext context,
  PageLoader load,
  String classId,
) => showDialog<Map<String, dynamic>>(
  context: context,
  builder: (_) => _StudentPicker(load: load, classId: classId),
);

class _StudentPicker extends StatefulWidget {
  const _StudentPicker({required this.load, required this.classId});
  final PageLoader load;
  final String classId;
  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  String search = '';
  int page = 1;
  late Future<dynamic> future = fetch();
  Future<dynamic> fetch() => widget.load(
    '/api/teacher-workspace/students?${Uri(queryParameters: {'classId': widget.classId, 'search': search, 'page': '$page'}).query}',
  );
  void reload() => setState(() {
    future = fetch();
  });
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose a student'),
    content: SizedBox(
      width: 540,
      height: MediaQuery.sizeOf(context).height * .6,
      child: Column(
        children: [
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Search name or student number',
              prefixIcon: Icon(Icons.search),
            ),
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (v) {
              search = v.trim();
              page = 1;
              reload();
            },
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              primary: true,
              child: PageResult(
                future: future,
                onRetry: reload,
                builder: (value) {
                  final data = recordMap(value),
                      items = recordList(data['items']);
                  return Column(
                    children: [
                      if (items.isEmpty)
                        const EmptyRecords('No students found in this class.'),
                      for (final s in items)
                        ListTile(
                          title: Text('${s['fullName']}'),
                          subtitle: Text('${s['admissionNo']}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, s),
                        ),
                      DirectoryPager(
                        meta: recordMap(data['meta']),
                        onPage: (v) {
                          page = v;
                          reload();
                        },
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
