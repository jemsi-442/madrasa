import 'package:flutter/material.dart';

import 'dashboard_components.dart';
import 'foundation_ui.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, required this.load, this.refreshToken = 0});
  final PageLoader load;
  final int refreshToken;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  int days = 7;
  String classId = '';
  late Future<dynamic> result = fetch();

  Future<dynamic> fetch() async {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(Duration(days: days - 1));
    final path = Uri(
      path: '/api/reports/attendance/summary',
      queryParameters: {
        'dateFrom': start.toIso8601String().substring(0, 10),
        'dateTo': end.toIso8601String().substring(0, 10),
        if (classId.isNotEmpty) 'classId': classId,
      },
    ).toString();
    final report = await widget.load(path);
    final classes = await widget.load('/api/classes');
    return {'report': report, 'classes': classes};
  }

  void reload() => setState(() {
    result = fetch();
  });

  @override
  void didUpdateWidget(covariant AttendancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) result = fetch();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SurfacePanel(
        child: Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.date_range_outlined, color: gold),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<int>(
                key: const ValueKey('attendance-period'),
                initialValue: days,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Period'),
                items: const [
                  DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                  DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                  DropdownMenuItem(value: 90, child: Text('Last 90 days')),
                ],
                onChanged: (value) {
                  days = value ?? 7;
                  reload();
                },
              ),
            ),
            const Text(
              'Review attendance saved by teachers.',
              style: TextStyle(color: muted, fontSize: 13),
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
          final report = recordMap(bundle['report']);
          final totals = recordMap(report['totals']);
          final timeline = recordList(report['timeline']);
          final classes = recordList(bundle['classes']);
          final total = recordNumber(totals['totalRecords']);
          final rate = total == 0
              ? '-'
              : '${recordText(totals['attendanceRate'], '0')}%';
          const statuses = [
            ('Present', 'present', forest, Icons.check_circle_outline),
            ('Absent', 'absent', Color(0xFFBD414F), Icons.person_off_outlined),
            ('Late', 'late', gold, Icons.schedule),
            ('Excused', 'excused', blue, Icons.description_outlined),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MetricRow(
                children: [
                  for (final (label, field, color, icon) in statuses)
                    DashboardMetric(
                      label: label,
                      value: '${recordNumber(totals[field])}',
                      icon: icon,
                      accent: color,
                      note: 'In selected period',
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SurfacePanel(
                child: SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('attendance-class-$classId'),
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
                      reload();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              PanelColumns(
                firstFlex: 2,
                first: SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PanelHeading(
                        'Attendance by day',
                        subtitle:
                            'Present as a percentage of saved records. Days without records are not plotted.',
                      ),
                      ColumnChart(
                        maximum: 100,
                        items: [
                          for (final day in timeline)
                            ChartDatum(
                              recordText(day['date']).substring(5),
                              recordNumber(day['totalRecords']) == 0
                                  ? 0
                                  : (recordNumber(day['present']) /
                                            recordNumber(day['totalRecords']) *
                                            100)
                                        .round(),
                              gold,
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
                        'Attendance summary',
                        subtitle: 'Selected period and class.',
                      ),
                      RingChart(
                        center: rate,
                        caption: total == 0 ? 'No records' : 'Present',
                        items: [
                          for (final (label, field, color, _) in statuses)
                            ChartDatum(
                              label,
                              recordNumber(totals[field]),
                              color,
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
                    PanelHeading(
                      'Daily register',
                      subtitle:
                          '${recordText(recordMap(report['filters'])['dateFrom'])} to ${recordText(recordMap(report['filters'])['dateTo'])}',
                    ),
                    if (timeline.isEmpty)
                      const EmptyRecords(
                        'No attendance has been recorded in this period.',
                      )
                    else
                      RecordTable(
                        minWidth: 640,
                        columns: const [
                          'Date',
                          'Present',
                          'Absent',
                          'Late',
                          'Excused',
                          'Records',
                        ],
                        rows: [
                          for (final day in timeline.reversed)
                            DataRow(
                              cells: [
                                DataCell(Text(recordText(day['date']))),
                                for (final (_, field, _, _) in statuses)
                                  DataCell(Text('${recordNumber(day[field])}')),
                                DataCell(
                                  Text('${recordNumber(day['totalRecords'])}'),
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
