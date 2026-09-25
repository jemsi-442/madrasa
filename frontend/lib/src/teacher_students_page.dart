import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';

class TeacherStudentsPage extends StatefulWidget {
  const TeacherStudentsPage({
    super.key,
    required this.load,
    required this.submit,
    required this.onOpen,
    this.initialClassId,
    this.initialStudent,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final TeacherNavigate onOpen;
  final String? initialClassId;
  final Map<String, dynamic>? initialStudent;
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
  Future<dynamic> fetch() => widget.load(
    '/api/teacher-workspace/students?${Uri(queryParameters: {if (classId.isNotEmpty) 'classId': classId, 'search': search, 'support': support, 'page': '$page'}).query}',
  );
  void reload() => setState(() {
    future = fetch();
  });
  @override
  void initState() {
    super.initState();
    if (widget.initialStudent != null) {
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
                                icon: const Icon(Icons.chevron_right, size: 18),
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
  late Future<dynamic> future = fetch();
  Future<dynamic> fetch() =>
      widget.load('/api/teacher-workspace/students/${widget.studentId}');
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
    if (saved && mounted) reload();
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Student learning profile'),
    content: SizedBox(
      width: 880,
      height: MediaQuery.sizeOf(context).height * .68,
      child: SingleChildScrollView(
        child: PageResult(
          future: future,
          onRetry: reload,
          builder: (value) {
            final data = recordMap(value), student = recordMap(data['student']);
            final notes = recordList(data['supportNotes']);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StudentIdentity(
                  student,
                  subtitle:
                      '${recordMap(student['currentClass'])['name']} | ${student['admissionNo']}',
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context, student),
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
                const SizedBox(height: 26),
                const PanelHeading(
                  'Learning support',
                  subtitle:
                      'Most recent 50 notes. Open follow-ups appear first.',
                ),
                if (notes.isEmpty)
                  const EmptyRecords('No support notes recorded.'),
                for (final n in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SurfacePanel(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${n['note']}',
                            style: const TextStyle(color: ink, height: 1.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${recordMap(n['createdBy'])['fullName']} | ${shortDate(n['createdAt'])}',
                            style: const TextStyle(color: muted, fontSize: 11),
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
                const SizedBox(height: 24),
                const PanelHeading(
                  "Recent Qur'an sessions",
                  subtitle: 'Latest 20 sessions across all surahs.',
                ),
                for (final s in recordList(data['sessions']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      passageLabel(s),
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      '${learningActivities[s['activity']]} | ${shortDate(s['learnedOn'])}\n${recordText(s['note'], '')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: TeacherTag(
                      s['voidedAt'] == null
                          ? learningObservations[s['observation']] ?? 'Recorded'
                          : 'Voided',
                      color: s['voidedAt'] == null ? forest : muted,
                    ),
                  ),
                if (recordList(data['sessions']).isEmpty)
                  const EmptyRecords('No learning sessions recorded yet.'),
              ],
            );
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
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
