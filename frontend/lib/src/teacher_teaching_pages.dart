import 'design_tokens.dart';
import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';
import 'teacher_classes_components.dart';

class TeacherOverviewPage extends StatelessWidget {
  const TeacherOverviewPage({
    super.key,
    required this.load,
    required this.onOpen,
    this.refreshToken = 0,
    this.onOpenPeriod,
  });
  final PageLoader load;
  final TeacherNavigate onOpen;
  final int refreshToken;
  final void Function(Map<String, dynamic> period)? onOpenPeriod;
  @override
  Widget build(BuildContext context) => TeacherData(
    load: load,
    path: '/api/teacher-workspace/overview',
    refreshToken: refreshToken,
    builder: (value) {
      final data = recordMap(value), classes = recordList(data['classes']);
      final day = DateTime.tryParse('${data['date']}')?.weekday;
      final today = [
        for (final c in classes)
          for (final s in recordList(c['timetable']))
            if (recordNumber(s['weekday']) == day) {...s, 'class': c},
      ]..sort((a, b) => '${a['startsAt']}'.compareTo('${b['startsAt']}'));
      final followUps = recordList(data['followUps']);
      final recent = recordList(data['recentSessions']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (MediaQuery.sizeOf(context).width < 1000) ...[
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => onOpen(4),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Take attendance'),
              ),
            ),
            const SizedBox(height: 20),
          ],
          MetricRow(
            children: [
              TeacherMetric(
                'My classes',
                '${classes.length}',
                'Currently assigned',
                Icons.co_present_outlined,
                blue,
              ),
              TeacherMetric(
                'My students',
                '${data['students']}',
                'Across your classes',
                Icons.people_outline,
                forest,
              ),
              TeacherMetric(
                'Need follow-up',
                '${data['followUpCount']}',
                'Open learning support notes',
                Icons.assignment_outlined,
                gold,
              ),
              TeacherMetric(
                "Qur'an sessions",
                '${data['sessionsToday']}',
                'Recorded by you today',
                Icons.menu_book_outlined,
                lavender,
              ),
            ],
          ),
          const SizedBox(height: 24),
          PanelColumns(
            firstFlex: 2,
            first: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PanelHeading(
                    "Today's teaching",
                    subtitle: shortDate(data['date']),
                  ),
                  if (today.isEmpty)
                    const EmptyRecords(
                      'No teaching times are scheduled for today. Your assigned classes are available in My Classes.',
                    )
                  else
                    RecordTable(
                      minWidth: 620,
                      columns: const [
                        'Time',
                        'Class & subject',
                        "Today's focus",
                        '',
                      ],
                      rows: [
                        for (final s in today)
                          DataRow(
                            cells: [
                              DataCell(
                                Text('${s['startsAt']} - ${s['endsAt']}'),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${recordMap(s['class'])['name']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${s['subject']}',
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 150,
                                  child: Text(
                                    recordText(s['focus'], 'Not set'),
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => onOpen(
                                        2,
                                        classId:
                                            '${recordMap(s['class'])['id']}',
                                      ),
                                      icon: const Icon(
                                        Icons.chevron_right,
                                        size: AfaqDesign.iconSmall,
                                      ),
                                      label: const Text('Open class'),
                                    ),
                                    if (onOpenPeriod != null)
                                      OutlinedButton.icon(
                                        key: ValueKey(
                                          'record-period-${s['id']}',
                                        ),
                                        onPressed: () => onOpenPeriod!({
                                          ...s,
                                          'classId':
                                              '${recordMap(s['class'])['id']}',
                                          'learnedOn': '${data['date']}',
                                        }),
                                        icon: const Icon(
                                          Icons.menu_book_outlined,
                                        ),
                                        label: const Text("Record Qur'an"),
                                      ),
                                  ],
                                ),
                              ),
                            ],
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
                  const PanelHeading('Quick actions'),
                  for (final (title, subtitle, icon, color, page) in [
                    (
                      'Take attendance',
                      'Open your class register',
                      Icons.calendar_month_outlined,
                      blue,
                      4,
                    ),
                    (
                      "Record Qur'an",
                      'Choose surah and ayahs',
                      Icons.menu_book_outlined,
                      forest,
                      3,
                    ),
                    (
                      'Follow up a learner',
                      'Record the support they need',
                      Icons.people_outline,
                      gold,
                      2,
                    ),
                    (
                      'My timetable',
                      'See your teaching week',
                      Icons.co_present_outlined,
                      lavender,
                      1,
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: line),
                        ),
                        leading: Icon(icon, color: color),
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          subtitle,
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          size: AfaqDesign.iconSmall,
                        ),
                        onTap: () => onOpen(page),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          PanelColumns(
            first: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PanelHeading(
                    'Learners to follow up',
                    action: TextButton(
                      onPressed: () => onOpen(2),
                      child: const Text('View students'),
                    ),
                  ),
                  if (followUps.isEmpty)
                    const EmptyRecords(
                      'No open follow-ups. Add a support note from a student profile when help is needed.',
                    ),
                  for (final s in followUps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: StudentIdentity(
                              s,
                              subtitle: recordList(
                                s['supportNotes'],
                              ).map((n) => '${n['note']}').join(),
                            ),
                          ),
                          TextButton(
                            onPressed: () => onOpen(
                              2,
                              classId: '${s['classId']}',
                              student: s,
                            ),
                            child: const Text('View'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            second: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PanelHeading('Recent learning updates'),
                  if (recent.isEmpty)
                    const EmptyRecords(
                      'Saved learning sessions will appear here.',
                    ),
                  for (final s in recent)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.menu_book_outlined,
                          color: forest,
                        ),
                        title: Text(
                          '${recordMap(s['student'])['fullName']}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${learningActivities[s['activity']]} | ${passageLabel(s)}\n${shortDate(s['learnedOn'])}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: muted,
                            height: 1.7,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          size: AfaqDesign.iconSmall,
                        ),
                        onTap: () => onOpen(
                          3,
                          classId: '${recordMap(s['student'])['classId']}',
                          student: recordMap(s['student']),
                        ),
                      ),
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

class TeacherClassesPage extends StatelessWidget {
  const TeacherClassesPage({
    super.key,
    required this.load,
    required this.onOpen,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final TeacherNavigate onOpen;
  final int refreshToken;
  @override
  Widget build(BuildContext context) => TeacherData(
    load: load,
    path: '/api/teacher-workspace/classes',
    refreshToken: refreshToken,
    builder: (value) {
      final classes = recordList(value);
      final slots = [
        for (final c in classes)
          for (final s in recordList(c['timetable'])) {...s, 'class': c},
      ];
      final times = slots.map((s) => '${s['startsAt']}').toSet().toList()
        ..sort();
      final subjects = slots
          .map((s) => recordText(s['subject'], '').trim())
          .where((s) => s.isNotEmpty)
          .toSet();
      final learners = classes.fold<int>(
        0,
        (total, c) =>
            total +
            recordNumber(recordMap(c['_count'])['currentStudents']).toInt(),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TeacherClassesBanner(),
          const SizedBox(height: 24),
          MetricRow(
            children: [
              TeacherMetric(
                'Total classes',
                '${classes.length}',
                'Currently assigned',
                Icons.groups_outlined,
                blue,
              ),
              TeacherMetric(
                'Total learners',
                '$learners',
                'In your assigned classes',
                Icons.school_outlined,
                forest,
              ),
              TeacherMetric(
                'Timetabled subjects',
                '${subjects.length}',
                'Distinct subjects in the timetable',
                Icons.menu_book_outlined,
                gold,
              ),
              TeacherMetric(
                'Weekly periods',
                '${slots.length}',
                'Scheduled periods, not completed lessons',
                Icons.calendar_month_outlined,
                lavender,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (classes.isEmpty)
            const SurfacePanel(
              child: EmptyRecords(
                'No classes assigned yet. The school office will assign your teaching classes.',
              ),
            ),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 1050
                  ? 3
                  : box.maxWidth >= 650
                  ? 2
                  : 1;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (final (index, c) in classes.indexed)
                    SizedBox(
                      width: (box.maxWidth - (columns - 1) * 20) / columns,
                      child: SurfacePanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: [
                                      blue,
                                      forest,
                                      gold,
                                    ][index % 3].withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.co_present_outlined,
                                    color: [blue, forest, gold][index % 3],
                                    size: 32,
                                  ),
                                ),
                                const TeacherTag('Assigned', color: forest),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${c['name']}',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${c['level']} | ${c['academicYear']}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  size: AfaqDesign.iconSmall,
                                  color: muted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${recordMap(c['_count'])['currentStudents']} learners',
                                  style: const TextStyle(color: muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              recordList(c['timetable']).isEmpty
                                  ? 'No timetable set'
                                  : recordList(c['timetable'])
                                        .map((s) => '${s['subject']}')
                                        .toSet()
                                        .join(' / '),
                              style: const TextStyle(color: ink, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            const Divider(height: 1),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: () =>
                                      onOpen(2, classId: '${c['id']}'),
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    size: AfaqDesign.iconSmall,
                                  ),
                                  label: const Text('View class'),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      onOpen(5, classId: '${c['id']}'),
                                  icon: const Icon(Icons.menu_book_outlined),
                                  label: const Text('My courses'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      onOpen(4, classId: '${c['id']}'),
                                  child: const Text('Attendance'),
                                ),
                              ],
                            ),
                            ExpansionTile(
                              key: PageStorageKey('class-records-${c['id']}'),
                              tilePadding: EdgeInsets.zero,
                              title: const Text(
                                'Learning & reports',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    for (final (page, label) in [
                                      (3, "Qur'an"),
                                      (8, 'Assessments'),
                                      (9, 'Reports'),
                                    ])
                                      TextButton(
                                        key: ValueKey(
                                          'class-${c['id']}-record-$page',
                                        ),
                                        onPressed: () =>
                                            onOpen(page, classId: '${c['id']}'),
                                        child: Text(label),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              recordText(recordMap(c['branch'])['name']),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
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
          const SizedBox(height: 24),
          PanelColumns(
            firstFlex: 3,
            second: TeacherClassQuickActions(onOpen: onOpen),
            first: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PanelHeading(
                    'My weekly schedule',
                    subtitle: 'Recurring timetable | Tanzania time (EAT)',
                  ),
                  if (slots.isEmpty)
                    const EmptyRecords(
                      'Your weekly schedule will appear when the school office adds teaching times.',
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 1080,
                        child: Table(
                          columnWidths: const {0: FixedColumnWidth(72)},
                          children: [
                            TableRow(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    'Time',
                                    style: TextStyle(color: muted),
                                  ),
                                ),
                                for (final day in teachingDays)
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      day,
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            for (final time in times)
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 20,
                                      left: 10,
                                    ),
                                    child: Text(
                                      time,
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  for (var day = 1; day <= 7; day++)
                                    Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minHeight: 90,
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color:
                                              slots.any(
                                                (s) =>
                                                    s['weekday'] == day &&
                                                    s['startsAt'] == time,
                                              )
                                              ? const Color(0xFFEAF2FC)
                                              : const Color(0xFFF6F7F9),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            for (final s in slots.where(
                                              (s) =>
                                                  s['weekday'] == day &&
                                                  s['startsAt'] == time,
                                            ))
                                              InkWell(
                                                onTap: () => onOpen(
                                                  2,
                                                  classId:
                                                      '${recordMap(s['class'])['id']}',
                                                ),
                                                child: Text(
                                                  '${recordMap(s['class'])['name']}\n${s['subject']}\n${s['startsAt']} - ${s['endsAt']}\n${recordText(s['room'], '')}',
                                                  style: const TextStyle(
                                                    color: blue,
                                                    fontSize: 11,
                                                    height: 1.7,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const TeacherNotice(
            'Classes and teaching assignments are managed by your school office. You can view and update learning records for your assigned students.',
          ),
        ],
      );
    },
  );
}
