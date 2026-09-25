import 'package:flutter/material.dart';

import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'admin_forms.dart';
import 'academic_actions.dart';

class StudentRegistryPage extends StatefulWidget {
  const StudentRegistryPage({
    super.key,
    required this.load,
    this.refreshToken = 0,
    this.submit,
  });
  final PageLoader load;
  final PageSubmitter? submit;
  final int refreshToken;

  @override
  State<StudentRegistryPage> createState() => _StudentRegistryPageState();
}

class _StudentRegistryPageState extends State<StudentRegistryPage> {
  final search = TextEditingController();
  String query = '';
  String status = '';
  String classId = '';
  String sort = 'createdAt';
  int page = 1;
  late Future<dynamic> result = fetch();

  Future<dynamic> fetch() async {
    final path = Uri(
      path: '/api/students',
      queryParameters: {
        'page': '$page',
        'pageSize': '10',
        'sortBy': sort,
        'sortDir': sort == 'createdAt' ? 'desc' : 'asc',
        if (query.isNotEmpty) 'search': query,
        if (status.isNotEmpty) 'status': status,
        if (classId.isNotEmpty) 'classId': classId,
      },
    ).toString();
    final roster = await widget.load(path);
    final classes = await widget.load('/api/classes');
    final summary = widget.submit == null
        ? null
        : await widget.load('/api/admin/students/summary');
    return {'roster': roster, 'classes': classes, 'summary': summary};
  }

  void reload({bool resetPage = false}) => setState(() {
    if (resetPage) page = 1;
    result = fetch();
  });

  @override
  void didUpdateWidget(covariant StudentRegistryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) result = fetch();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.submit != null) ...[
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Add student'),
            onPressed: () async {
              final saved = await createStudentForm(
                context,
                widget.load,
                widget.submit!,
              );
              if (saved && mounted) reload(resetPage: true);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
      SurfacePanel(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 370,
              child: TextField(
                key: const ValueKey('student-search'),
                controller: search,
                maxLength: 100,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Name, admission number or guardian',
                  counterText: '',
                ),
                onSubmitted: (_) {
                  query = search.text.trim();
                  reload(resetPage: true);
                },
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                query = search.text.trim();
                reload(resetPage: true);
              },
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search'),
            ),
            SizedBox(
              width: 175,
              child: DropdownButtonFormField<String>(
                key: ValueKey('student-status-$status'),
                initialValue: status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All statuses'),
                  ),
                  for (final value in [
                    'ACTIVE',
                    'INACTIVE',
                    'SUSPENDED',
                    'GRADUATED',
                  ])
                    DropdownMenuItem(
                      value: value,
                      child: Text(friendlyStatus(value)),
                    ),
                ],
                onChanged: (value) {
                  status = value ?? '';
                  reload(resetPage: true);
                },
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: sort,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sort by'),
                items: const [
                  DropdownMenuItem(
                    value: 'createdAt',
                    child: Text('Newest first'),
                  ),
                  DropdownMenuItem(
                    value: 'fullName',
                    child: Text('Student name'),
                  ),
                  DropdownMenuItem(
                    value: 'admissionNo',
                    child: Text('Admission no.'),
                  ),
                ],
                onChanged: (value) {
                  sort = value ?? 'createdAt';
                  reload(resetPage: true);
                },
              ),
            ),
            if (query.isNotEmpty || status.isNotEmpty || classId.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  search.clear();
                  query = '';
                  status = '';
                  classId = '';
                  reload(resetPage: true);
                },
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
              ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      PageResult(
        future: result,
        onRetry: reload,
        builder: (data) {
          final bundle = recordMap(data);
          final roster = recordMap(bundle['roster']);
          final students = recordList(roster['items']);
          final meta = recordMap(roster['meta']);
          final classes = recordList(bundle['classes']);
          final total = recordNumber(meta['totalItems']).toInt();
          final pages = recordNumber(meta['totalPages']).toInt();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.submit != null)
                _DemographicCards(
                  summary: recordMap(recordMap(data)['summary']),
                )
              else
                MetricRow(
                  children: [
                    DashboardMetric(
                      label: 'Matching students',
                      value: '$total',
                      icon: Icons.groups_outlined,
                      accent: blue,
                      note: 'Across all result pages',
                    ),
                    DashboardMetric(
                      label: 'Students shown',
                      value: '${students.length}',
                      icon: Icons.badge_outlined,
                      accent: forest,
                      note: 'On this page',
                    ),
                    DashboardMetric(
                      label: 'Class assigned',
                      value:
                          '${students.where((s) => s['currentClass'] != null).length}',
                      icon: Icons.menu_book_outlined,
                      accent: gold,
                      note: 'On this page',
                    ),
                    DashboardMetric(
                      label: 'Guardian linked',
                      value:
                          '${students.where((s) => s['primaryGuardian'] != null).length}',
                      icon: Icons.family_restroom_outlined,
                      accent: lavender,
                      note: 'On this page',
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              SurfacePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PanelHeading(
                      'Student directory',
                      subtitle:
                          'Open a student record to view their details and guardian contacts.',
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 250,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('student-class-$classId'),
                          initialValue:
                              classes.any((item) => '${item['id']}' == classId)
                              ? classId
                              : '',
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Class'),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All classes'),
                            ),
                            for (final item in classes)
                              DropdownMenuItem(
                                value: '${item['id']}',
                                child: Text(
                                  recordText(item['name']),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            classId = value ?? '';
                            reload(resetPage: true);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (students.isEmpty)
                      const EmptyRecords('No students match these filters.')
                    else
                      RecordTable(
                        columns: const [
                          'Student',
                          'Admission no.',
                          'Class',
                          'Guardian',
                          'Status',
                          '',
                        ],
                        rows: [
                          for (final student in students)
                            DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 190,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 17,
                                          backgroundColor: blue.withValues(
                                            alpha: 0.1,
                                          ),
                                          child: Text(
                                            recordText(
                                              student['fullName'],
                                              '?',
                                            )[0],
                                            style: const TextStyle(
                                              color: blue,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            recordText(student['fullName']),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(recordText(student['admissionNo'])),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 130,
                                    child: Text(
                                      recordText(
                                        recordMap(
                                          student['currentClass'],
                                        )['name'],
                                        'Not assigned',
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 145,
                                    child: Text(
                                      recordText(
                                        recordMap(
                                          student['primaryGuardian'],
                                        )['fullName'],
                                        'Not linked',
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  StatusPill(recordText(student['status'])),
                                ),
                                DataCell(
                                  IconButton(
                                    tooltip: 'View ${student['fullName']}',
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 19,
                                    ),
                                    onPressed: () => showRecordDetails(
                                      context,
                                      title: recordText(student['fullName']),
                                      fields: {
                                        'Admission number': recordText(
                                          student['admissionNo'],
                                        ),
                                        'Status': friendlyStatus(
                                          student['status'],
                                        ),
                                        'Class': recordText(
                                          recordMap(
                                            student['currentClass'],
                                          )['name'],
                                        ),
                                        'Campus': recordText(
                                          recordMap(student['branch'])['name'],
                                        ),
                                        'Gender': friendlyStatus(
                                          student['gender'],
                                        ),
                                        'Date of birth': recordText(
                                          student['dob'],
                                        ),
                                        'Joined': recordText(
                                          student['joinedOn'],
                                        ),
                                        'Guardian': recordText(
                                          recordMap(
                                            student['primaryGuardian'],
                                          )['fullName'],
                                        ),
                                        'Guardian phone': recordText(
                                          recordMap(
                                            student['primaryGuardian'],
                                          )['phone'],
                                        ),
                                        'Guardian email': recordText(
                                          recordMap(
                                            student['primaryGuardian'],
                                          )['email'],
                                        ),
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 10,
                      children: [
                        Text(
                          total == 0
                              ? '0 students'
                              : 'Showing ${(page - 1) * 10 + 1}-${(page - 1) * 10 + students.length} of $total students',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Previous page',
                              onPressed: page > 1
                                  ? () {
                                      page--;
                                      reload();
                                    }
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text(
                              'Page $page of ${pages < 1 ? 1 : pages}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            IconButton(
                              tooltip: 'Next page',
                              onPressed: page < pages
                                  ? () {
                                      page++;
                                      reload();
                                    }
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _DemographicCards extends StatelessWidget {
  const _DemographicCards({required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) => MetricRow(
    children: [
      DashboardMetric(
        label: 'Total students',
        value: recordText(summary['total'], '0'),
        icon: Icons.groups_outlined,
        accent: blue,
      ),
      DashboardMetric(
        label: 'New admissions',
        value: recordText(summary['newAdmissions'], '0'),
        icon: Icons.school_outlined,
        accent: forest,
        note: 'This month',
      ),
      DashboardMetric(
        label: 'Male students',
        value: recordText(summary['male'], '0'),
        icon: Icons.person_outline,
        accent: gold,
      ),
      DashboardMetric(
        label: 'Female students',
        value: recordText(summary['female'], '0'),
        icon: Icons.person_outline,
        accent: const Color(0xFFBE4A5C),
      ),
    ],
  );
}
