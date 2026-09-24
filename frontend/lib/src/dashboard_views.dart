import 'package:flutter/material.dart';

import 'foundation_ui.dart';

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : const {};

num _number(dynamic value) => num.tryParse(value?.toString() ?? '') ?? 0;

String _display(dynamic value) => value?.toString() ?? '—';

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.role,
    required this.data,
    required this.onOpenSection,
  });

  final String role;
  final dynamic data;
  final ValueChanged<int> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final report = _map(data);
    return switch (role) {
      'ADMIN' => _AdminHome(report: report, onOpen: onOpenSection),
      'ACCOUNTANT' => _FinanceHome(report: report, onOpen: onOpenSection),
      'TEACHER' => _TeacherHome(report: report, onOpen: onOpenSection),
      'PARENT' => _ParentHome(report: report, onOpen: onOpenSection),
      'LEARNER' => _LearnerHome(report: report, onOpen: onOpenSection),
      _ => const SurfacePanel(child: Text('This workspace is unavailable.')),
    };
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics(this.items);

  final List<DashboardMetric> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000
            ? 4
            : width >= 350
            ? 2
            : 1;
        final itemWidth = (width - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items
              .map((item) => SizedBox(width: itemWidth, child: item))
              .toList(),
        );
      },
    );
  }
}

class _PanelPair extends StatelessWidget {
  const _PanelPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 740) {
          return Column(children: [first, const SizedBox(height: 14), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 14),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 13)),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.items, required this.onOpen});

  final List<(int, String, IconData)> items;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle('Go to a page', 'Continue with a specific task.'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((item) {
              return OutlinedButton.icon(
                onPressed: () => onOpen(item.$1),
                icon: Icon(item.$3, size: 19),
                label: Text(item.$2),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  side: const BorderSide(color: line),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome({required this.report, required this.onOpen});

  final Map<String, dynamic> report;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final students = _map(report['students']);
    final attendance = _map(report['attendance']);
    final finance = _map(report['finance']);
    final invoices = _map(finance['invoices']);
    final hifdh = _map(report['hifdh']);
    final totalStudents = _number(students['total']);
    final totalAttendance = _number(attendance['totalRecords']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Metrics([
          DashboardMetric(
            label: 'Students',
            value: _display(students['total']),
            icon: Icons.groups_rounded,
            accent: blue,
          ),
          DashboardMetric(
            label: 'Attendance rate',
            value: '${_display(attendance['attendanceRate'])}%',
            icon: Icons.event_available_rounded,
            accent: gold,
            note: 'Across recorded attendance',
          ),
          DashboardMetric(
            label: 'Hifdh assessments',
            value: _display(hifdh['totalAssessments']),
            icon: Icons.auto_stories_rounded,
            accent: forest,
          ),
          DashboardMetric(
            label: 'Outstanding balance',
            value: _display(invoices['outstandingBalance']),
            icon: Icons.account_balance_wallet_outlined,
            accent: lavender,
          ),
        ]),
        const SizedBox(height: 18),
        _PanelPair(
          first: SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelTitle(
                  'Student status',
                  'How enrolled students are recorded.',
                ),
                DataBar(
                  label: 'Active',
                  value: _number(students['active']),
                  maximum: totalStudents,
                  color: forest,
                ),
                DataBar(
                  label: 'Inactive',
                  value: _number(students['inactive']),
                  maximum: totalStudents,
                  color: blue,
                ),
                DataBar(
                  label: 'Suspended',
                  value: _number(students['suspended']),
                  maximum: totalStudents,
                  color: gold,
                ),
                DataBar(
                  label: 'Graduated',
                  value: _number(students['graduated']),
                  maximum: totalStudents,
                  color: lavender,
                ),
              ],
            ),
          ),
          second: SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelTitle(
                  'Attendance records',
                  'Breakdown of saved records.',
                ),
                DataBar(
                  label: 'Present',
                  value: _number(attendance['present']),
                  maximum: totalAttendance,
                  color: forest,
                ),
                DataBar(
                  label: 'Absent',
                  value: _number(attendance['absent']),
                  maximum: totalAttendance,
                  color: const Color(0xFFBB5B51),
                ),
                DataBar(
                  label: 'Late',
                  value: _number(attendance['late']),
                  maximum: totalAttendance,
                  color: gold,
                ),
                DataBar(
                  label: 'Excused',
                  value: _number(attendance['excused']),
                  maximum: totalAttendance,
                  color: blue,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _QuickLinks(
          items: const [
            (1, 'Students', Icons.groups_outlined),
            (2, 'Classes', Icons.menu_book_outlined),
            (3, 'Attendance', Icons.event_available_outlined),
            (5, 'Courses', Icons.auto_stories_outlined),
          ],
          onOpen: onOpen,
        ),
      ],
    );
  }
}

class _FinanceHome extends StatelessWidget {
  const _FinanceHome({required this.report, required this.onOpen});

  final Map<String, dynamic> report;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final finance = _map(report['finance']);
    final invoices = _map(finance['invoices']);
    final collections = _map(finance['collections']);
    final expenses = _map(finance['expenses']);
    final invoicedAmount = _number(invoices['amountDue']);
    final collectedAmount = _number(collections['collectedAmount']);
    final expenseAmount = _number(expenses['amount']);
    final maximum = [
      invoicedAmount,
      collectedAmount,
      expenseAmount,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Metrics([
          DashboardMetric(
            label: 'Invoices',
            value: _display(invoices['total']),
            icon: Icons.receipt_long_outlined,
            accent: blue,
          ),
          DashboardMetric(
            label: 'Collected',
            value: _display(collections['collectedAmount']),
            icon: Icons.payments_outlined,
            accent: forest,
          ),
          DashboardMetric(
            label: 'Outstanding',
            value: _display(invoices['outstandingBalance']),
            icon: Icons.account_balance_wallet_outlined,
            accent: gold,
          ),
          DashboardMetric(
            label: 'Expenses',
            value: _display(expenses['amount']),
            icon: Icons.stacked_line_chart_outlined,
            accent: lavender,
          ),
        ]),
        const SizedBox(height: 18),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitle(
                'Financial picture',
                'Amounts from the current report.',
              ),
              DataBar(
                label: 'Invoiced',
                value: invoicedAmount,
                maximum: maximum,
                displayValue: _display(invoices['amountDue']),
                color: blue,
              ),
              DataBar(
                label: 'Collected',
                value: collectedAmount,
                maximum: maximum,
                displayValue: _display(collections['collectedAmount']),
                color: forest,
              ),
              DataBar(
                label: 'Expenses',
                value: expenseAmount,
                maximum: maximum,
                displayValue: _display(expenses['amount']),
                color: gold,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _QuickLinks(
          items: const [
            (1, 'Invoices', Icons.receipt_long_outlined),
            (2, 'Payments', Icons.payments_outlined),
            (3, 'Course access', Icons.verified_user_outlined),
          ],
          onOpen: onOpen,
        ),
      ],
    );
  }
}

class _TeacherHome extends StatelessWidget {
  const _TeacherHome({required this.report, required this.onOpen});

  final Map<String, dynamic> report;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final summary = _map(report['summary']);
    final classes = report['classes'] is List
        ? report['classes'] as List
        : const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Metrics([
          DashboardMetric(
            label: 'My classes',
            value: _display(summary['assignedClasses']),
            icon: Icons.menu_book_outlined,
            accent: blue,
          ),
          DashboardMetric(
            label: 'My students',
            value: _display(summary['assignedStudents']),
            icon: Icons.groups_rounded,
            accent: forest,
          ),
          DashboardMetric(
            label: 'Attendance marked',
            value: _display(summary['attendanceMarkedToday']),
            icon: Icons.event_available_outlined,
            accent: gold,
            note: 'Today',
          ),
          DashboardMetric(
            label: 'Hifdh assessments',
            value: _display(summary['hifdhAssessmentsThisWeek']),
            icon: Icons.auto_stories_outlined,
            accent: lavender,
            note: 'This week',
          ),
        ]),
        const SizedBox(height: 18),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitle(
                'Today in your classes',
                'Attendance saved against your roster.',
              ),
              if (classes.isEmpty)
                const Text(
                  'No classes are assigned yet.',
                  style: TextStyle(color: muted),
                ),
              ...classes.whereType<Map<String, dynamic>>().map((item) {
                final stats = _map(item['stats']);
                return DataBar(
                  label: _display(item['name']),
                  value: _number(stats['attendanceMarkedToday']),
                  maximum: _number(stats['currentStudents']),
                  displayValue:
                      "${_display(stats['attendanceMarkedToday'])}/${_display(stats['currentStudents'])}",
                  color: forest,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _QuickLinks(
          items: const [
            (1, 'My classes', Icons.menu_book_outlined),
            (2, 'My courses', Icons.auto_stories_outlined),
            (3, 'School updates', Icons.campaign_outlined),
          ],
          onOpen: onOpen,
        ),
      ],
    );
  }
}

class _ParentHome extends StatelessWidget {
  const _ParentHome({required this.report, required this.onOpen});

  final Map<String, dynamic> report;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final guardian = _map(report['guardian']);
    final students = report['students'] is List
        ? report['students'] as List
        : const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Metrics([
          DashboardMetric(
            label: 'Your children',
            value: students.length.toString(),
            icon: Icons.family_restroom_rounded,
            accent: blue,
          ),
          DashboardMetric(
            label: 'Parent',
            value: _display(guardian['fullName']),
            icon: Icons.person_outline_rounded,
            accent: gold,
          ),
        ]),
        const SizedBox(height: 18),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitle(
                'Your children',
                'Students linked to your account.',
              ),
              if (students.isEmpty)
                const Text(
                  'No children are linked yet. Please contact the office.',
                  style: TextStyle(color: muted),
                ),
              ...students.whereType<Map<String, dynamic>>().map(
                (student) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: blue.withValues(alpha: 0.12),
                        child: const Icon(Icons.school_outlined, color: blue),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _display(student['fullName']),
                              style: const TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _display(student['admissionNo']),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
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
          ),
        ),
        const SizedBox(height: 18),
        _QuickLinks(
          items: const [
            (1, 'My children', Icons.school_outlined),
            (2, 'School updates', Icons.campaign_outlined),
          ],
          onOpen: onOpen,
        ),
      ],
    );
  }
}

class _LearnerHome extends StatelessWidget {
  const _LearnerHome({required this.report, required this.onOpen});

  final Map<String, dynamic> report;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final student = _map(report['student']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Metrics([
          DashboardMetric(
            label: 'Your name',
            value: _display(student['fullName']),
            icon: Icons.person_outline_rounded,
            accent: blue,
          ),
          DashboardMetric(
            label: 'Admission number',
            value: _display(student['admissionNo']),
            icon: Icons.badge_outlined,
            accent: gold,
          ),
          DashboardMetric(
            label: 'Learning path',
            value: _display(student['programCategory']).replaceAll('_', ' '),
            icon: Icons.auto_stories_outlined,
            accent: forest,
          ),
        ]),
        const SizedBox(height: 18),
        _QuickLinks(
          items: const [
            (1, 'My courses', Icons.auto_stories_outlined),
            (2, 'My progress', Icons.trending_up_outlined),
            (3, 'My billing', Icons.receipt_long_outlined),
          ],
          onOpen: onOpen,
        ),
      ],
    );
  }
}

class AttendanceSummaryView extends StatelessWidget {
  const AttendanceSummaryView({super.key, required this.data});

  final dynamic data;

  @override
  Widget build(BuildContext context) {
    final report = _map(data);
    final totals = _map(report['totals']);
    final timeline = report['timeline'] is List
        ? report['timeline'] as List
        : const [];
    final total = _number(totals['totalRecords']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Metrics([
          DashboardMetric(
            label: 'Records',
            value: _display(totals['totalRecords']),
            icon: Icons.event_note_outlined,
            accent: blue,
          ),
          DashboardMetric(
            label: 'Attendance rate',
            value: '${_display(totals['attendanceRate'])}%',
            icon: Icons.event_available_outlined,
            accent: forest,
          ),
          DashboardMetric(
            label: 'Present',
            value: _display(totals['present']),
            icon: Icons.check_circle_outline_rounded,
            accent: forest,
          ),
          DashboardMetric(
            label: 'Absent',
            value: _display(totals['absent']),
            icon: Icons.person_off_outlined,
            accent: gold,
          ),
        ]),
        const SizedBox(height: 18),
        _PanelPair(
          first: SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelTitle(
                  'By attendance status',
                  'Share of saved records.',
                ),
                DataBar(
                  label: 'Present',
                  value: _number(totals['present']),
                  maximum: total,
                  color: forest,
                ),
                DataBar(
                  label: 'Absent',
                  value: _number(totals['absent']),
                  maximum: total,
                  color: const Color(0xFFBB5B51),
                ),
                DataBar(
                  label: 'Late',
                  value: _number(totals['late']),
                  maximum: total,
                  color: gold,
                ),
                DataBar(
                  label: 'Excused',
                  value: _number(totals['excused']),
                  maximum: total,
                  color: blue,
                ),
              ],
            ),
          ),
          second: SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelTitle(
                  'Recent days',
                  'Present students among saved records.',
                ),
                if (timeline.isEmpty)
                  const Text(
                    'No attendance has been recorded for this period.',
                    style: TextStyle(color: muted),
                  ),
                ...timeline
                    .whereType<Map<String, dynamic>>()
                    .toList()
                    .reversed
                    .take(7)
                    .map(
                      (day) => DataBar(
                        label: _display(day['date']),
                        value: _number(day['present']),
                        maximum: _number(day['totalRecords']),
                        displayValue:
                            "${_display(day['present'])}/${_display(day['totalRecords'])}",
                        color: forest,
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
