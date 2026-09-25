import 'package:flutter/material.dart';

import 'dashboard_components.dart';
import 'foundation_ui.dart';

class AdminOverview extends StatelessWidget {
  const AdminOverview({super.key, required this.report, required this.onOpen});
  final Map<String, dynamic> report;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final students = recordMap(report['students']);
    final attendance = recordMap(report['attendance']);
    final hifdh = recordMap(report['hifdh']);
    final invoices = recordMap(recordMap(report['finance'])['invoices']);
    final totalAttendance = recordNumber(attendance['totalRecords']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricRow(
          children: [
            DashboardMetric(
              label: 'Students',
              value: recordText(students['total'], '-'),
              icon: Icons.groups_outlined,
              accent: blue,
              note: 'Registered students',
            ),
            DashboardMetric(
              label: 'Attendance rate',
              value: totalAttendance == 0
                  ? '-'
                  : '${recordText(attendance['attendanceRate'])}%',
              icon: Icons.event_available_outlined,
              accent: forest,
              note: totalAttendance == 0
                  ? 'No records yet'
                  : 'Across saved records',
            ),
            DashboardMetric(
              label: 'Hifdh assessments',
              value: recordText(hifdh['totalAssessments'], '-'),
              icon: Icons.auto_stories_outlined,
              accent: gold,
              note: 'Recorded by teachers',
            ),
            DashboardMetric(
              label: 'Outstanding balance',
              value: recordText(invoices['outstandingBalance'], '-'),
              icon: Icons.account_balance_wallet_outlined,
              accent: lavender,
              note: 'Across issued invoices',
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
                  'Student status',
                  subtitle: 'Students grouped by their current status.',
                ),
                ColumnChart(
                  items: [
                    ChartDatum(
                      'Active',
                      recordNumber(students['active']),
                      forest,
                    ),
                    ChartDatum(
                      'Inactive',
                      recordNumber(students['inactive']),
                      blue,
                    ),
                    ChartDatum(
                      'Suspended',
                      recordNumber(students['suspended']),
                      gold,
                    ),
                    ChartDatum(
                      'Graduated',
                      recordNumber(students['graduated']),
                      lavender,
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
                  subtitle: 'All saved attendance records.',
                ),
                RingChart(
                  center: '$totalAttendance',
                  caption: 'Records',
                  items: [
                    ChartDatum(
                      'Present',
                      recordNumber(attendance['present']),
                      forest,
                    ),
                    ChartDatum(
                      'Absent',
                      recordNumber(attendance['absent']),
                      const Color(0xFFBD414F),
                    ),
                    ChartDatum('Late', recordNumber(attendance['late']), gold),
                    ChartDatum(
                      'Excused',
                      recordNumber(attendance['excused']),
                      blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        PanelColumns(
          first: SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PanelHeading(
                  "Qur'an assessments",
                  subtitle: 'Average teacher assessment scores, out of 100.',
                ),
                if (recordNumber(hifdh['totalAssessments']) == 0)
                  const EmptyRecords('No assessments have been recorded yet.')
                else ...[
                  DataBar(
                    label: 'Memorization',
                    value: recordNumber(hifdh['averageMemorizationScore']),
                    maximum: 100,
                    color: forest,
                    displayValue: recordText(
                      hifdh['averageMemorizationScore'],
                      '-',
                    ),
                  ),
                  DataBar(
                    label: 'Revision',
                    value: recordNumber(hifdh['averageRevisionScore']),
                    maximum: 100,
                    color: gold,
                    displayValue: recordText(
                      hifdh['averageRevisionScore'],
                      '-',
                    ),
                  ),
                ],
              ],
            ),
          ),
          second: SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PanelHeading(
                  'Quick access',
                  subtitle: 'Continue in the page for your task.',
                ),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final (index, title, subtitle, icon, color)
                          in const [
                            (
                              1,
                              'Students',
                              'Student and guardian details',
                              Icons.groups_outlined,
                              blue,
                            ),
                            (
                              2,
                              'Classes',
                              'Teachers and class sizes',
                              Icons.menu_book_outlined,
                              forest,
                            ),
                            (
                              3,
                              'Attendance',
                              'Review daily records',
                              Icons.event_available_outlined,
                              gold,
                            ),
                            (
                              5,
                              'Courses',
                              'Online learning catalog',
                              Icons.auto_stories_outlined,
                              lavender,
                            ),
                          ])
                        SizedBox(
                          width: constraints.maxWidth < 330
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2,
                          child: Material(
                            color: color.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(9),
                            child: InkWell(
                              onTap: () => onOpen(index),
                              borderRadius: BorderRadius.circular(9),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(icon, color: color),
                                    const SizedBox(height: 10),
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
  }
}
