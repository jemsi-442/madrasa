import 'class_timetable_dialog.dart';
import 'class_record_actions.dart';
import 'package:flutter/material.dart';

import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'admin_forms.dart';
import 'academic_actions.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({
    super.key,
    required this.load,
    this.refreshToken = 0,
    this.submit,
  });
  final PageLoader load;
  final PageSubmitter? submit;
  final int refreshToken;

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  late Future<dynamic> result = widget.load('/api/classes');
  String query = '';
  String level = '';

  void reload() => setState(() {
    result = widget.load('/api/classes');
  });

  @override
  void didUpdateWidget(covariant ClassesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      result = widget.load('/api/classes');
    }
  }

  @override
  Widget build(BuildContext context) => PageResult(
    future: result,
    onRetry: reload,
    builder: (data) {
      final classes = recordList(data);
      final levels = <String, int>{};
      final studentsByLevel = <String, int>{};
      for (final item in classes) {
        final name = recordText(item['level'], 'Other');
        levels[name] = (levels[name] ?? 0) + 1;
        studentsByLevel[name] =
            (studentsByLevel[name] ?? 0) +
            recordNumber(recordMap(item['stats'])['currentStudents']).toInt();
      }
      final totalStudents = studentsByLevel.values.fold(0, (a, b) => a + b);
      const colors = [gold, blue, forest, lavender, ink];
      final visible = classes
          .where(
            (item) =>
                (level.isEmpty || item['level'] == level) &&
                '${item['name']} ${recordMap(item['teacher'])['fullName']} ${item['academicYear']}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.submit != null) ...[
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Create class'),
                onPressed: () async {
                  final saved = await createClassForm(
                    context,
                    widget.load,
                    widget.submit!,
                  );
                  if (saved && mounted) reload();
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          MetricRow(
            children: [
              DashboardMetric(
                label: 'Classes',
                value: '${classes.length}',
                icon: Icons.menu_book_outlined,
                accent: blue,
              ),
              DashboardMetric(
                label: 'Assigned students',
                value: '$totalStudents',
                icon: Icons.groups_outlined,
                accent: forest,
              ),
              DashboardMetric(
                label: 'Assigned teachers',
                value:
                    '${classes.map((c) => c['teacherId']).where((id) => id != null).toSet().length}',
                icon: Icons.person_outline,
                accent: gold,
              ),
              DashboardMetric(
                label: 'Learning levels',
                value: '${levels.length}',
                icon: Icons.layers_outlined,
                accent: lavender,
              ),
            ],
          ),
          const SizedBox(height: 18),
          PanelColumns(
            first: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PanelHeading(
                    'Classes by level',
                    subtitle: 'All classes available to your account.',
                  ),
                  ColumnChart(
                    items: [
                      for (var i = 0; i < levels.length; i++)
                        ChartDatum(
                          levels.keys.elementAt(i),
                          levels.values.elementAt(i),
                          colors[i % colors.length],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            second: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PanelHeading(
                    'Student distribution',
                    subtitle: 'Current class assignments by level.',
                  ),
                  RingChart(
                    center: '$totalStudents',
                    caption: 'Students',
                    items: [
                      for (var i = 0; i < studentsByLevel.length; i++)
                        ChartDatum(
                          studentsByLevel.keys.elementAt(i),
                          studentsByLevel.values.elementAt(i),
                          colors[i % colors.length],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PanelHeading(
                  'Class directory',
                  subtitle:
                      'Teachers, campuses and class sizes. Open a class for contact details.',
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 340,
                      child: TextField(
                        key: const ValueKey('class-search'),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search classes or teachers',
                        ),
                        onChanged: (value) => setState(() => query = value),
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<String>(
                        initialValue: levels.containsKey(level) ? level : '',
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Level'),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('All levels'),
                          ),
                          for (final name in levels.keys)
                            DropdownMenuItem(
                              value: name,
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => level = value ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (visible.isEmpty)
                  const EmptyRecords('No classes match your search.')
                else
                  RecordTable(
                    columns: const [
                      'Class',
                      'Level',
                      'Teacher',
                      'Campus',
                      'Students',
                      'Year',
                      '',
                    ],
                    rows: [
                      for (final item in visible)
                        DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  recordText(item['name']),
                                  maxLines: 2,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(recordText(item['level']))),
                            DataCell(
                              SizedBox(
                                width: 140,
                                child: Text(
                                  recordText(
                                    recordMap(item['teacher'])['fullName'],
                                    'Not assigned',
                                  ),
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 120,
                                child: Text(
                                  recordText(recordMap(item['branch'])['name']),
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${recordNumber(recordMap(item['stats'])['currentStudents'])}',
                              ),
                            ),
                            DataCell(Text(recordText(item['academicYear']))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.submit != null)
                                    ClassRecordActions(
                                      schoolClass: item,
                                      load: widget.load,
                                      submit: widget.submit!,
                                      onChanged: reload,
                                    ),
                                  if (widget.submit != null)
                                    IconButton(
                                      tooltip: 'Manage timetable',
                                      icon: const Icon(
                                        Icons.calendar_month_outlined,
                                        size: 19,
                                      ),
                                      onPressed: () => showClassTimetable(
                                        context,
                                        item,
                                        widget.load,
                                        widget.submit!,
                                      ),
                                    ),
                                  IconButton(
                                    tooltip: 'View ${item['name']}',
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 19,
                                    ),
                                    onPressed: () => showRecordDetails(
                                      context,
                                      title: recordText(item['name']),
                                      fields: {
                                        'Level': recordText(item['level']),
                                        'Academic year': recordText(
                                          item['academicYear'],
                                        ),
                                        'Campus': recordText(
                                          recordMap(item['branch'])['name'],
                                        ),
                                        'Teacher': recordText(
                                          recordMap(
                                            item['teacher'],
                                          )['fullName'],
                                        ),
                                        'Teacher phone': recordText(
                                          recordMap(item['teacher'])['phone'],
                                        ),
                                        'Teacher email': recordText(
                                          recordMap(item['teacher'])['email'],
                                        ),
                                        'Current students':
                                            '${recordNumber(recordMap(item['stats'])['currentStudents'])}',
                                        'Capacity': recordText(
                                          item['capacity'],
                                          'Not set',
                                        ),
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                Text(
                  '${visible.length} of ${classes.length} classes',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
