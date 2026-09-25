import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';

class TeacherOverviewPage extends StatelessWidget {
  const TeacherOverviewPage({
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
                                OutlinedButton.icon(
                                  onPressed: () => onOpen(
                                    2,
                                    classId: '${recordMap(s['class'])['id']}',
                                  ),
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    size: 17,
                                  ),
                                  label: const Text('Open class'),
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
                        trailing: const Icon(Icons.chevron_right, size: 18),
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
                        trailing: const Icon(Icons.chevron_right, size: 18),
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                                Icon(
                                  Icons.co_present_outlined,
                                  color: [blue, forest, gold][index % 3],
                                  size: 30,
                                ),
                                const TeacherTag('Assigned', color: muted),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '${c['name']}',
                              style: const TextStyle(
                                fontSize: 24,
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
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  size: 18,
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
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      onOpen(2, classId: '${c['id']}'),
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    size: 17,
                                  ),
                                  label: const Text('View class'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      onOpen(4, classId: '${c['id']}'),
                                  child: const Text('Attendance'),
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
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PanelHeading(
                  'My weekly schedule',
                  subtitle: 'Current teaching period | Tanzania time',
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
                                        borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 18),
          const TeacherNotice(
            'Classes and teaching assignments are managed by your school office. You can view and update learning records for your assigned students.',
          ),
        ],
      );
    },
  );
}
