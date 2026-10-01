import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({
    super.key,
    required this.load,
    required this.submit,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final int refreshToken;
  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  String search = '', status = '';
  int page = 1;
  late Future<dynamic> future = fetch();
  Future<dynamic> fetch() => widget.load(
    '/api/admin/teachers?${Uri(queryParameters: {'page': '$page', 'search': search, if (status.isNotEmpty) 'status': status}).query}',
  );
  void reload() {
    setState(() {
      future = fetch();
    });
  }

  @override
  void didUpdateWidget(covariant TeachersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) future = fetch();
  }

  Future<void> addTeacher() async {
    final saved = await showAdminForm(
      context,
      title: 'Add teacher',
      saveLabel: 'Create account',
      fields: const [
        AdminField('fullName', 'Full name'),
        AdminField('email', 'Email address', kind: 'email'),
        AdminField('phone', 'Phone number', required: false),
        AdminField('password', 'Initial password', kind: 'password'),
      ],
      onSave: (body) async {
        await widget.submit('/api/users', {...body, 'role': 'TEACHER'});
      },
    );
    if (saved && mounted) reload();
  }

  @override
  Widget build(BuildContext context) => PageResult(
    future: future,
    onRetry: reload,
    builder: (data) {
      final report = recordMap(data),
          summary = recordMap(report['summary']),
          items = recordList(report['items']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: addTeacher,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add teacher'),
            ),
          ),
          const SizedBox(height: 16),
          MetricRow(
            children: [
              DashboardMetric(
                label: 'Total teachers',
                value: recordText(summary['total'], '0'),
                icon: Icons.groups_outlined,
                accent: blue,
              ),
              DashboardMetric(
                label: 'Active accounts',
                value: recordText(summary['active'], '0'),
                icon: Icons.person_outline,
                accent: forest,
              ),
              DashboardMetric(
                label: 'Assigned teachers',
                value: recordText(summary['assigned'], '0'),
                icon: Icons.assignment_ind_outlined,
                accent: gold,
              ),
              DashboardMetric(
                label: 'Subjects covered',
                value: recordText(summary['subjects'], '0'),
                icon: Icons.auto_stories_outlined,
                accent: lavender,
                note: 'Through assigned online courses',
              ),
            ],
          ),
          const SizedBox(height: 18),
          PanelColumns(
            firstFlex: 3,
            first: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PanelHeading(
                    'All teachers',
                    subtitle:
                        'Accounts, teaching assignments and contact details',
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 330,
                        child: TextFormField(
                          initialValue: search,
                          decoration: const InputDecoration(
                            hintText: 'Search teachers',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onFieldSubmitted: (v) {
                            search = v.trim();
                            page = 1;
                            reload();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: status,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Account status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: '',
                              child: Text('All accounts'),
                            ),
                            DropdownMenuItem(
                              value: 'ACTIVE',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'DISABLED',
                              child: Text('Disabled'),
                            ),
                          ],
                          onChanged: (v) {
                            status = v ?? '';
                            page = 1;
                            reload();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (items.isEmpty)
                    const EmptyRecords('No teachers match this search.')
                  else
                    RecordTable(
                      minWidth: 800,
                      columns: const [
                        'Teacher',
                        'Subjects',
                        'Classes',
                        'Contact',
                        'Account',
                        'Details',
                      ],
                      rows: [
                        for (final teacher in items)
                          DataRow(
                            cells: [
                              DataCell(
                                _PersonName(
                                  name: recordText(teacher['fullName']),
                                  detail: 'Teacher ${teacher['id']}',
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 150,
                                  child: Text(
                                    recordList(teacher['teachingCourses'])
                                        .map(
                                          (c) => recordText(
                                            recordMap(c['subject'])['name'],
                                          ),
                                        )
                                        .toSet()
                                        .join(', '),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${recordList(teacher['taughtClasses']).length} classes',
                                ),
                              ),
                              DataCell(
                                Text(
                                  recordText(
                                    teacher['phone'],
                                    recordText(teacher['email'], '-'),
                                  ),
                                ),
                              ),
                              DataCell(StatusPill('${teacher['status']}')),
                              DataCell(
                                IconButton(
                                  tooltip: 'View teacher',
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        recordText(teacher['fullName']),
                                      ),
                                      content: SizedBox(
                                        width: 460,
                                        child: SingleChildScrollView(
                                          primary: true,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                recordText(
                                                  teacher['email'],
                                                  'No email address',
                                                ),
                                              ),
                                              Text(
                                                recordText(
                                                  teacher['phone'],
                                                  'No phone number',
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              const Text(
                                                'Assigned classes',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (recordList(
                                                teacher['taughtClasses'],
                                              ).isEmpty)
                                                const Text(
                                                  'No class assignments yet.',
                                                ),
                                              for (final c in recordList(
                                                teacher['taughtClasses'],
                                              ))
                                                ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  leading: const Icon(
                                                    Icons.menu_book_outlined,
                                                  ),
                                                  title: Text('${c['name']}'),
                                                  subtitle: Text(
                                                    '${c['academicYear']} | ${recordMap(c['_count'])['currentStudents']} students',
                                                  ),
                                                ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Online courses',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (recordList(
                                                teacher['teachingCourses'],
                                              ).isEmpty)
                                                const Text(
                                                  'No course assignments yet.',
                                                ),
                                              for (final c in recordList(
                                                teacher['teachingCourses'],
                                              ))
                                                ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text('${c['title']}'),
                                                  subtitle: Text(
                                                    recordText(
                                                      recordMap(
                                                        c['subject'],
                                                      )['name'],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  DirectoryPager(
                    meta: recordMap(report['meta']),
                    onPage: (p) {
                      page = p;
                      reload();
                    },
                  ),
                ],
              ),
            ),
            second: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PanelHeading(
                    'Class workload',
                    subtitle: 'Assignments for teachers on this page',
                  ),
                  if (items.isEmpty)
                    const EmptyRecords('No assignments to show.'),
                  for (final teacher in items.take(6))
                    DataBar(
                      label: recordText(teacher['fullName']),
                      value: recordList(teacher['taughtClasses']).length,
                      maximum: items
                          .map((t) => recordList(t['taughtClasses']).length)
                          .fold<int>(1, (a, b) => a > b ? a : b),
                      color: blue,
                      displayValue:
                          '${recordList(teacher['taughtClasses']).length} classes',
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class SubjectsPage extends StatefulWidget {
  const SubjectsPage({
    super.key,
    required this.load,
    required this.submit,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final int refreshToken;
  @override
  State<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage> {
  int page = 1;
  String search = '';
  late Future<dynamic> future = fetch();
  Future<dynamic> fetch() => widget.load(
    '/api/admin/subjects?${Uri(queryParameters: {'page': '$page', 'search': search}).query}',
  );
  void reload() {
    setState(() {
      future = fetch();
    });
  }

  @override
  void didUpdateWidget(covariant SubjectsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) future = fetch();
  }

  Future<void> addSubject() async {
    final saved = await showAdminForm(
      context,
      title: 'Add subject',
      fields: const [
        AdminField('name', 'Subject name'),
        AdminField('code', 'Subject code'),
        AdminField(
          'category',
          'Category',
          options: {
            'RELIGIOUS': 'Religious studies',
            'LANGUAGE': 'Languages',
            'TECHNICAL': 'Technology',
            'BUSINESS': 'Business',
            'GENERAL': 'General studies',
            'VOCATIONAL': 'Vocational skills',
          },
        ),
        AdminField('summary', 'Description', kind: 'notes', required: false),
      ],
      onSave: (body) async {
        await widget.submit('/api/subjects', {
          ...body,
          'slug': '${body['code']}'.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]+'),
            '-',
          ),
        });
      },
    );
    if (saved && mounted) reload();
  }

  Future<void> curriculum(Map<String, dynamic> subject) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SubjectCourses(subject: subject, load: widget.load),
    );
  }

  @override
  Widget build(BuildContext context) => PageResult(
    future: future,
    onRetry: reload,
    builder: (data) {
      final report = recordMap(data),
          summary = recordMap(report['summary']),
          items = recordList(report['items']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: addSubject,
              icon: const Icon(Icons.add),
              label: const Text('Add subject'),
            ),
          ),
          const SizedBox(height: 16),
          MetricRow(
            children: [
              DashboardMetric(
                label: 'Total subjects',
                value: recordText(summary['total'], '0'),
                icon: Icons.layers_outlined,
                accent: blue,
              ),
              DashboardMetric(
                label: 'Active subjects',
                value: recordText(summary['active'], '0'),
                icon: Icons.menu_book_outlined,
                accent: forest,
              ),
              DashboardMetric(
                label: 'Online courses',
                value: recordText(summary['courses'], '0'),
                icon: Icons.school_outlined,
                accent: gold,
              ),
              DashboardMetric(
                label: 'Course lessons',
                value: recordText(summary['lessons'], '0'),
                icon: Icons.description_outlined,
                accent: lavender,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PanelHeading(
                  'Subjects overview',
                  subtitle: 'Your subject catalog and linked online courses',
                ),
                TextFormField(
                  initialValue: search,
                  decoration: const InputDecoration(
                    hintText: 'Search subjects',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onFieldSubmitted: (v) {
                    search = v.trim();
                    page = 1;
                    reload();
                  },
                ),
                const SizedBox(height: 18),
                if (items.isEmpty)
                  const EmptyRecords('No subjects match this search.')
                else
                  RecordTable(
                    minWidth: 900,
                    columns: const [
                      'Subject',
                      'Description',
                      'Category',
                      'Courses',
                      'Status',
                      'Action',
                    ],
                    rows: [
                      for (final subject in items)
                        DataRow(
                          cells: [
                            DataCell(
                              _PersonName(
                                name: recordText(subject['name']),
                                detail: recordText(subject['code']),
                                icon: Icons.menu_book_outlined,
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 240,
                                child: Text(
                                  recordText(subject['summary'], '-'),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(friendlyStatus(subject['category']))),
                            DataCell(
                              Text(
                                recordText(
                                  recordMap(subject['_count'])['courses'],
                                  '0',
                                ),
                              ),
                            ),
                            DataCell(
                              StatusPill(
                                subject['isActive'] == true
                                    ? 'ACTIVE'
                                    : 'INACTIVE',
                              ),
                            ),
                            DataCell(
                              OutlinedButton(
                                onPressed: () => curriculum(subject),
                                child: const Text('View courses'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                DirectoryPager(
                  meta: recordMap(report['meta']),
                  onPage: (p) {
                    page = p;
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

class _SubjectCourses extends StatefulWidget {
  const _SubjectCourses({required this.subject, required this.load});
  final Map<String, dynamic> subject;
  final PageLoader load;
  @override
  State<_SubjectCourses> createState() => _SubjectCoursesState();
}

class _SubjectCoursesState extends State<_SubjectCourses> {
  late Future<dynamic> future = fetch();
  Future<dynamic> fetch() =>
      widget.load('/api/courses?subjectId=${widget.subject['id']}');
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.subject['name']} courses'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        primary: true,
        child: PageResult(
          future: future,
          onRetry: () {
            setState(() {
              future = fetch();
            });
          },
          builder: (data) {
            final rows = recordList(data);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rows.isEmpty)
                  const EmptyRecords(
                    'No courses have been added for this subject.',
                  ),
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_stories_outlined),
                    title: Text(recordText(row['title'])),
                    subtitle: Text(recordText(row['summary'], '')),
                    trailing: StatusPill('${row['publicationStatus']}'),
                  ),
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

class _PersonName extends StatelessWidget {
  const _PersonName({required this.name, required this.detail, this.icon});
  final String name, detail;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 19,
        backgroundColor: blue.withValues(alpha: .1),
        child: icon != null
            ? Icon(icon, color: blue, size: 20)
            : Text(
                name
                    .split(' ')
                    .where((p) => p.isNotEmpty)
                    .take(2)
                    .map((p) => p[0])
                    .join(),
                style: const TextStyle(color: blue, fontSize: 12),
              ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 160,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(detail, style: const TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      ),
    ],
  );
}
