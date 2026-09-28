import 'package:flutter/material.dart';
import 'admin_forms.dart' show shortDate;
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'parent_academics.dart';
import 'parent_reports.dart';
import 'parent_portal_page.dart' show FamilyAttendanceCalendar, attendanceColor;
import 'report_preview.dart';
import 'teacher_ui.dart';

/// Self-only school records. Existing course/progress/billing routes stay intact.
class LearnerPortalPage extends StatefulWidget {
  const LearnerPortalPage({
    super.key,
    required this.load,
    required this.page,
    required this.onOpen,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final int page, refreshToken;
  final ValueChanged<int> onOpen;
  @override
  State<LearnerPortalPage> createState() => _LearnerPortalPageState();
}

class _LearnerPortalPageState extends State<LearnerPortalPage> {
  static const base = '/api/learner/workspace';
  static DateTime schoolToday() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateTime(now.year, now.month, now.day);
  }

  DateTime selectedDate = schoolToday();
  int sessionPage = 1;
  bool bySurah = false, listView = false;
  String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  Widget data(String path, Widget Function(Map<String, dynamic>) builder) =>
      TeacherData(
        key: ValueKey(path),
        load: widget.load,
        path: path,
        refreshToken: widget.refreshToken,
        builder: (raw) => builder(recordMap(raw)),
      );
  Widget stack(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 18),
        children[i],
      ],
    ],
  );
  Widget panel(
    String title,
    Widget child, {
    String? subtitle,
    Widget? action,
  }) => SurfacePanel(
    child: stack([
      PanelHeading(title, subtitle: subtitle, action: action),
      child,
    ]),
  );
  Widget link(String label, int index) => TextButton.icon(
    onPressed: () => widget.onOpen(index),
    icon: const Icon(Icons.arrow_forward, size: 17),
    label: Text(label),
  );
  Widget metric(
    String label,
    dynamic value,
    IconData icon,
    Color color,
    String note,
  ) => DashboardMetric(
    label: label,
    value: '$value',
    icon: icon,
    accent: color,
    note: note,
    dense: true,
  );
  String percent(dynamic value) => value == null ? 'Not available' : '$value%';
  Widget detail(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: muted)),
        ),
        Expanded(
          child: Text(
            recordText(value),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => switch (widget.page) {
    5 => classes(),
    6 => attendance(),
    7 => quran(),
    8 => ParentAcademics.learner(
      load: widget.load,
      refreshToken: widget.refreshToken,
    ),
    9 => ParentReports.learner(
      load: widget.load,
      refreshToken: widget.refreshToken,
    ),
    _ => dashboard(),
  };

  Widget dashboard() => data('$base/overview', (result) {
    final student = recordMap(result['student']),
        register = recordMap(result['attendance']);
    final quran = recordMap(result['quran']),
        academics = recordMap(result['academics']);
    final report = recordMap(result['latestReport']),
        subjects = recordList(academics['subjects']);
    final notices = recordList(result['announcements']);
    return stack([
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          TeacherTag(
            recordText(
              recordMap(student['currentClass'])['name'],
              'Independent learner',
            ),
          ),
          Text(
            recordText(student['admissionNo']),
            style: const TextStyle(color: muted),
          ),
          Text(
            recordText(recordMap(student['branch'])['name']),
            style: const TextStyle(color: muted),
          ),
        ],
      ),
      MetricRow(
        children: [
          metric(
            'Attendance',
            percent(register['rate']),
            Icons.event_available_outlined,
            blue,
            '${result['month']} - recorded days only',
          ),
          metric(
            "Qur'an progress",
            percent(quran['percent']),
            Icons.menu_book_outlined,
            forest,
            '${quran['memorisedAyahs']} independently memorised ayahs',
          ),
          metric(
            'Assessment average',
            percent(academics['average']),
            Icons.bar_chart_outlined,
            gold,
            'Published results in ${academics['year']}',
          ),
          metric(
            'Latest report',
            report.isEmpty ? 'Not published' : 'Ready to view',
            Icons.description_outlined,
            blue,
            report.isEmpty
                ? 'Published reports appear here'
                : recordText(
                    recordMap(recordMap(report['snapshot'])['period'])['name'],
                  ),
          ),
        ],
      ),
      PanelColumns(
        firstFlex: 2,

        first: panel(
          'Your learning',
          stack([
            const Text(
              'Continue your courses, revisit lessons and follow your recorded progress.',
              style: TextStyle(color: muted),
            ),
            LayoutBuilder(
              builder: (context, size) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in const [
                    (
                      1,
                      'My courses',
                      'Subjects and available lessons',
                      Icons.auto_stories_outlined,
                      forest,
                    ),
                    (
                      2,
                      'Course progress',
                      'Continue your learning journey',
                      Icons.trending_up,
                      blue,
                    ),
                    (
                      7,
                      "Qur'an tracker",
                      'Memorisation and learning history',
                      Icons.menu_book_outlined,
                      gold,
                    ),
                    (
                      8,
                      'Academic results',
                      'Published scores and feedback',
                      Icons.school_outlined,
                      blue,
                    ),
                  ])
                    SizedBox(
                      width: size.maxWidth >= 440
                          ? (size.maxWidth - 12) / 2
                          : size.maxWidth,
                      child: Material(
                        color: item.$5.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => widget.onOpen(item.$1),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Icon(item.$4, color: item.$5, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.$2,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        item.$3,
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ),
        second: panel(
          "Today's classes",
          sessionList(recordList(result['sessions'])),
          subtitle: shortDate(result['today']),
          action: link('Timetable', 5),
        ),
      ),
      PanelColumns(
        first: panel(
          'Subject results',
          subjects.isEmpty
              ? const EmptyRecords('No published assessment results yet.')
              : stack([
                  for (final subject in subjects.take(5))
                    detail(
                      recordText(subject['name']),
                      '${subject['average']}%',
                    ),
                ]),
          subtitle: 'Published assessments, not a term grade or class rank.',
          action: link('View results', 8),
        ),
        second: panel(
          'Recent announcements',
          notices.isEmpty
              ? const EmptyRecords('No school announcements yet.')
              : stack([
                  for (final row in notices.take(3))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recordText(row['title']),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          recordText(row['message']),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted),
                        ),
                        Text(
                          shortDate(row['publishAt']),
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                ]),
          action: link('All updates', 4),
        ),
      ),
      panel(
        'Latest learning report',
        report.isEmpty
            ? const EmptyRecords(
                'Your report will appear after the school publishes it.',
              )
            : Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.description_outlined, color: gold, size: 32),
                  Text(
                    recordText(
                      recordMap(
                        recordMap(report['snapshot'])['period'],
                      )['name'],
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  FilledButton.icon(
                    onPressed: () => showPublishedReport(
                      context,
                      report,
                      widget.load,
                      '$base/reports/${report['id']}/pdf',
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View report'),
                  ),
                  ReportPdfButton(
                    load: widget.load,
                    path: '$base/reports/${report['id']}/pdf',
                  ),
                ],
              ),
        action: link('All reports', 9),
      ),
    ]);
  });

  Widget sessionList(List<Map<String, dynamic>> rows) => rows.isEmpty
      ? const EmptyRecords('No scheduled classes for this day.')
      : Column(
          children: [
            for (final row in rows)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: line)),
                ),
                child: Row(
                  children: [
                    Text(
                      recordText(row['startsAt']),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.menu_book_outlined, color: forest),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recordText(row['subject']),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${recordText(row['room'], 'Room not set')} | Until ${row['endsAt']}',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

  Widget dateControls({required bool weekly}) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      IconButton(
        tooltip: weekly ? 'Previous week' : 'Previous month',
        onPressed: selectedDate.year <= 2000 && selectedDate.month == 1
            ? null
            : () => setState(
                () => selectedDate = weekly
                    ? selectedDate.subtract(const Duration(days: 7))
                    : DateTime(selectedDate.year, selectedDate.month - 1),
              ),
        icon: const Icon(Icons.chevron_left),
      ),
      Text(
        weekly
            ? 'Week of ${dayKey(selectedDate.subtract(Duration(days: selectedDate.weekday - 1)))}'
            : MaterialLocalizations.of(context).formatMonthYear(selectedDate),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      IconButton(
        tooltip: weekly ? 'Next week' : 'Next month',
        onPressed: selectedDate.year >= 2099 && selectedDate.month == 12
            ? null
            : () => setState(
                () => selectedDate = weekly
                    ? selectedDate.add(const Duration(days: 7))
                    : DateTime(selectedDate.year, selectedDate.month + 1),
              ),
        icon: const Icon(Icons.chevron_right),
      ),
      TextButton(
        onPressed: () => setState(() => selectedDate = schoolToday()),
        child: Text(weekly ? 'This week' : 'This month'),
      ),
    ],
  );

  Widget classes() => stack([
    SurfacePanel(
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          dateControls(weekly: true),
          ChoiceChip(
            label: const Text('Week view'),
            selected: !listView,
            onSelected: (_) => setState(() => listView = false),
          ),
          ChoiceChip(
            label: const Text('List view'),
            selected: listView,
            onSelected: (_) => setState(() => listView = true),
          ),
        ],
      ),
    ),
    data('$base/classes?date=${dayKey(selectedDate)}', (result) {
      final student = recordMap(result['student']),
          rows = recordList(result['sessions']);
      final start = DateTime.parse(recordText(result['weekStart']));
      return stack([
        if (student['currentClass'] == null)
          const TeacherNotice(
            'No school class is assigned to your account. Your online courses are still available from My courses.',
          ),
        panel(
          recordText(
            recordMap(student['currentClass'])['name'],
            'My timetable',
          ),
          rows.isEmpty
              ? const EmptyRecords('No scheduled classes in this week.')
              : listView
              ? RecordTable(
                  columns: const ['Date', 'Time', 'Subject', 'Room'],
                  rows: [
                    for (final row in rows)
                      DataRow(
                        cells: [
                          DataCell(Text(shortDate(row['date']))),
                          DataCell(
                            Text('${row['startsAt']} - ${row['endsAt']}'),
                          ),
                          DataCell(Text(recordText(row['subject']))),
                          DataCell(Text(recordText(row['room'], 'Not set'))),
                        ],
                      ),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, size) {
                    final days = [
                      for (var i = 0; i < 7; i++) start.add(Duration(days: i)),
                    ];
                    final columns = size.maxWidth >= 1000
                        ? 7
                        : size.maxWidth >= 650
                        ? 3
                        : 1;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 12,
                      children: [
                        for (final day in days)
                          SizedBox(
                            width:
                                (size.maxWidth - (columns - 1) * 10) / columns,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(minHeight: 140),
                              decoration: BoxDecoration(
                                color: dayKey(day) == result['today']
                                    ? gold.withValues(alpha: .08)
                                    : const Color(0xFFF8FAFC),
                                border: Border.all(color: line),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    const [
                                      'Mon',
                                      'Tue',
                                      'Wed',
                                      'Thu',
                                      'Fri',
                                      'Sat',
                                      'Sun',
                                    ][day.weekday - 1],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    shortDate(dayKey(day)),
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (!rows.any(
                                    (r) => r['date'] == dayKey(day),
                                  ))
                                    const Text(
                                      'No classes',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  for (final row in rows.where(
                                    (r) => r['date'] == dayKey(day),
                                  ))
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: forest.withValues(alpha: .08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            recordText(row['subject']),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '${row['startsAt']} - ${row['endsAt']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            recordText(
                                              row['room'],
                                              'Room not set',
                                            ),
                                            style: const TextStyle(
                                              color: muted,
                                              fontSize: 11,
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
          subtitle: '${result['weekStart']} to ${result['weekEnd']}',
        ),
        const TeacherNotice(
          'This timetable shows your current assigned class. Cancelled or out-of-period lessons are not shown. Contact the school about timetable changes.',
        ),
      ]);
    }),
  ]);

  Widget attendance() => stack([
    dateControls(weekly: false),
    data('$base/attendance?month=${dayKey(selectedDate).substring(0, 7)}', (
      result,
    ) {
      final summary = recordMap(result['summary']),
          rows = recordList(result['records']);
      return stack([
        MetricRow(
          children: [
            metric(
              'Present days',
              summary['PRESENT'],
              Icons.event_available_outlined,
              forest,
              'On-time attendance',
            ),
            metric(
              'Absent days',
              summary['ABSENT'],
              Icons.event_busy_outlined,
              const Color(0xFFBD3554),
              'Recorded absences only',
            ),
            metric(
              'Late days',
              summary['LATE'],
              Icons.schedule,
              gold,
              'Included as attended',
            ),
            metric(
              'Attendance rate',
              percent(summary['rate']),
              Icons.bar_chart_outlined,
              blue,
              '${summary['EXCUSED']} excused days excluded',
            ),
          ],
        ),
        PanelColumns(
          firstFlex: 2,

          first: panel(
            'Attendance calendar',
            FamilyAttendanceCalendar(month: selectedDate, records: rows),
          ),
          second: panel(
            'Your attendance',
            stack([
              Center(
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: summary['rate'] == null
                              ? 0
                              : recordNumber(summary['rate']) / 100,
                          strokeWidth: 12,
                          backgroundColor: line,
                          color: forest,
                        ),
                      ),
                      Text(
                        summary['rate'] == null
                            ? 'No records'
                            : '${summary['rate']}%',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              detail('Marked days', summary['markedDays']),
              detail('Excused', summary['EXCUSED']),
              const Text(
                'Unmarked dates mean no record. They are not counted as absent or assumed to be holidays.',
                style: TextStyle(color: muted),
              ),
            ]),
          ),
        ),
        panel(
          'Attendance log',
          rows.isEmpty
              ? const EmptyRecords('No attendance recorded this month.')
              : RecordTable(
                  columns: const ['Date', 'Status', 'Arrival', 'Class', 'Note'],
                  rows: [
                    for (final row in rows)
                      DataRow(
                        cells: [
                          DataCell(Text(shortDate(row['date']))),
                          DataCell(
                            TeacherTag(
                              friendlyStatus(row['status']),
                              color: attendanceColor(row['status']),
                            ),
                          ),
                          DataCell(Text(recordText(row['checkInTime']))),
                          DataCell(
                            Text(recordText(recordMap(row['class'])['name'])),
                          ),
                          DataCell(
                            SizedBox(
                              width: 220,
                              child: Text(
                                recordText(row['reason']),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        const TeacherNotice(
          'Late counts as attended. Excused days are excluded from the rate. Only school staff can change attendance; contact the office if a record needs correction.',
        ),
      ]);
    }),
  ]);

  Widget quran() => data('$base/quran?page=$sessionPage', (result) {
    final chapters = recordList(result['chapters']),
        latest = recordMap(result['latestSession']);
    final meta = recordMap(result['meta']);
    String name(dynamic id) => recordText(
      chapters.where((c) => '${c['id']}' == '$id').firstOrNull?['name'],
      'Surah $id',
    );
    return stack([
      MetricRow(
        children: [
          metric(
            'Memorised ayahs',
            result['memorisedAyahs'],
            Icons.menu_book_outlined,
            forest,
            'Distinct, independently demonstrated',
          ),
          metric(
            "Whole Qur'an progress",
            '${result['percent']}%',
            Icons.bar_chart_outlined,
            gold,
            'Out of ${result['totalAyahs']} ayahs',
          ),
          metric(
            'Learning sessions',
            meta['totalItems'],
            Icons.history,
            blue,
            'Reading, revision, memorisation, tajweed',
          ),
          metric(
            'Last recorded',
            latest.isEmpty ? 'No sessions' : shortDate(latest['learnedOn']),
            Icons.event_outlined,
            forest,
            'Teacher-recorded learning',
          ),
        ],
      ),
      PanelColumns(
        firstFlex: 2,

        first: panel(
          'Surah / Juz tracker',
          stack([
            Wrap(
              spacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('By Juz'),
                  selected: !bySurah,
                  onSelected: (_) => setState(() => bySurah = false),
                ),
                ChoiceChip(
                  label: const Text('By Surah'),
                  selected: bySurah,
                  onSelected: (_) => setState(() => bySurah = true),
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, size) {
                final items = bySurah ? chapters : recordList(result['juzs']);
                final columns = bySurah
                    ? (size.maxWidth > 500 ? 3 : 2)
                    : (size.maxWidth > 500 ? 10 : 5);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: (size.maxWidth - (columns - 1) * 8) / columns,
                        child: Semantics(
                          label:
                              '${bySurah ? item['name'] : 'Juz ${item['number']}'}: ${item['memorisedAyahs']} of ${item['ayahCount'] ?? item['totalAyahs']} ayahs memorised',
                          child: Tooltip(
                            message:
                                '${item['memorisedAyahs']} / ${item['ayahCount'] ?? item['totalAyahs']} ayahs',
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              constraints: const BoxConstraints(minHeight: 65),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: line),
                                color: recordNumber(item['memorisedAyahs']) > 0
                                    ? forest.withValues(alpha: .1)
                                    : const Color(0xFFF2F4F7),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    bySurah
                                        ? '${item['id']}. ${item['name']}'
                                        : '${item['number']}',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 5),
                                  Icon(
                                    recordNumber(item['memorisedAyahs']) ==
                                            recordNumber(
                                              item['ayahCount'] ??
                                                  item['totalAyahs'],
                                            )
                                        ? Icons.check_circle
                                        : recordNumber(item['memorisedAyahs']) >
                                              0
                                        ? Icons.timelapse
                                        : Icons.remove,
                                    size: 16,
                                    color:
                                        recordNumber(item['memorisedAyahs']) > 0
                                        ? forest
                                        : muted,
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
            const Text(
              'Check: complete. Clock: some ayahs recorded. Grey: no independent memorisation record.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ]),
        ),
        second: panel(
          'Latest learning session',
          latest.isEmpty
              ? const EmptyRecords('No learning sessions recorded yet.')
              : stack([
                  Text(
                    name(latest['surahId']),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  detail(
                    'Ayahs',
                    '${latest['ayahFrom']} - ${latest['ayahTo']}',
                  ),
                  detail('Activity', learningActivities[latest['activity']]),
                  detail(
                    'Observation',
                    learningObservations[latest['observation']],
                  ),
                  detail('Teacher', recordMap(latest['teacher'])['fullName']),
                  const TeacherNotice(
                    'Reading and revision are separate activities. Only independent memorisation contributes to the tracker.',
                  ),
                ]),
        ),
      ),
      panel(
        'Learning history',
        stack([
          if (recordList(result['sessions']).isEmpty)
            const EmptyRecords('No learning sessions on this page.')
          else
            RecordTable(
              columns: const [
                'Date',
                'Surah / ayahs',
                'Activity',
                'Observation',
              ],
              rows: [
                for (final row in recordList(result['sessions']))
                  DataRow(
                    cells: [
                      DataCell(Text(shortDate(row['learnedOn']))),
                      DataCell(
                        Text(
                          '${name(row['surahId'])} | ${row['ayahFrom']}-${row['ayahTo']}',
                        ),
                      ),
                      DataCell(
                        Text(recordText(learningActivities[row['activity']])),
                      ),
                      DataCell(
                        Text(
                          recordText(learningObservations[row['observation']]),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: sessionPage > 1
                    ? () => setState(() => sessionPage--)
                    : null,
                child: const Text('Previous'),
              ),
              Text('Page $sessionPage'),
              OutlinedButton(
                onPressed: sessionPage < recordNumber(meta['totalPages'])
                    ? () => setState(() => sessionPage++)
                    : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ]),
      ),
    ]);
  });
}
