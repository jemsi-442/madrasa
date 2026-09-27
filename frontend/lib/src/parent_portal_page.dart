import 'package:flutter/material.dart';
import 'admin_forms.dart' show shortDate;
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';

typedef FamilyNavigate = void Function(int page, {String? childId});

/// Parent views consume scoped, read-only records; enrolment stays with the office.
class ParentPortalPage extends StatefulWidget {
  const ParentPortalPage({
    super.key,
    required this.load,
    required this.page,
    required this.onOpen,
    required this.onChildSelected,
    this.childId,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final int page, refreshToken;
  final String? childId;
  final FamilyNavigate onOpen;
  final ValueChanged<String> onChildSelected;
  @override
  State<ParentPortalPage> createState() => _ParentPortalPageState();
}

class _ParentPortalPageState extends State<ParentPortalPage> {
  static const base = '/api/parent-portal/workspace';
  String? profileId;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int sessionPage = 1;
  bool bySurah = false;
  String get monthKey =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  Widget data(String path, Widget Function(Map<String, dynamic>) builder) =>
      TeacherData(
        key: ValueKey(path),
        load: widget.load,
        path: path,
        refreshToken: widget.refreshToken,
        builder: (value) => builder(recordMap(value)),
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

  Widget panel(String title, Widget child, {String? subtitle}) => SurfacePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeading(title, subtitle: subtitle),
        child,
      ],
    ),
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

  void officeHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Contact the school office'),
      content: const SelectableText(
        'To add a child or correct a profile, contact the office. '
        'Staff must verify the guardian relationship before linking a child.\n\n'
        '+255 715 735 335\n+255 683 186 987\n\nNo child records are changed by this request.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => data('$base/overview', (overview) {
    final children = recordList(overview['children']);
    final matches = children.where((c) => '${c['id']}' == widget.childId);
    final selected = matches.isNotEmpty ? matches.first : children.firstOrNull;
    return stack([
      Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (children.isNotEmpty)
            SizedBox(
              width: 270,
              child: DropdownButtonFormField<String>(
                key: ValueKey('child-${selected?['id']}'),
                initialValue: '${selected!['id']}',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Selected child',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: children
                    .map(
                      (c) => DropdownMenuItem(
                        value: '${c['id']}',
                        child: Text(
                          recordText(c['fullName']),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    profileId = null;
                    sessionPage = 1;
                  });
                  widget.onChildSelected(id);
                },
              ),
            ),
          OutlinedButton.icon(
            onPressed: officeHelp,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Request child link'),
          ),
        ],
      ),
      if (widget.page == 6)
        support(recordMap(overview['guardian']))
      else if (widget.page == 4)
        TeacherData(
          load: widget.load,
          path: '/api/parent-portal/announcements',
          refreshToken: widget.refreshToken,
          builder: (rows) => announcements(recordList(rows)),
        )
      else if (children.isEmpty)
        const EmptyRecords(
          'No children are linked yet. Please contact the school office.',
        )
      else if (widget.page == 0)
        dashboard(overview, selected!)
      else if (widget.page == 1)
        profileId == null ? childCards(children) : profile(profileId!)
      else if (widget.page == 2)
        attendance('${selected!['id']}')
      else if (widget.page == 3)
        quran('${selected!['id']}')
      else if (widget.page == 5)
        payments('${selected!['id']}'),
      const _FamilyBanner(),
    ]);
  });

  Widget dashboard(Map<String, dynamic> overview, Map<String, dynamic> child) {
    final attendance = recordMap(child['attendance']),
        quran = recordMap(child['quran']);
    return stack([
      MetricRow(
        children: [
          metric(
            'Attendance',
            attendance['rate'] == null
                ? 'No records'
                : '${attendance['rate']}%',
            Icons.calendar_month_outlined,
            blue,
            'Recorded days in ${overview['month']}',
          ),
          metric(
            "Qur'an memorised",
            '${quran['percent']}%',
            Icons.menu_book_outlined,
            forest,
            '${quran['memorisedAyahs']} of ${quran['totalAyahs']} ayahs',
          ),
          metric(
            'Current class',
            recordMap(child['currentClass'])['name'] ?? 'Unassigned',
            Icons.school_outlined,
            gold,
            recordText(recordMap(child['branch'])['name']),
          ),
          metric(
            'Student status',
            friendlyStatus(child['status']),
            Icons.verified_user_outlined,
            blue,
            recordText(child['admissionNo']),
          ),
        ],
      ),
      PanelColumns(
        first: panel(
          'Learning overview',
          stack([
            StudentIdentity(
              child,
              subtitle: 'Independent memorisation recorded by the teacher',
            ),
            RingChart(
              percentageDigits: 1,
              items: [
                ChartDatum(
                  'Memorised',
                  recordNumber(quran['memorisedAyahs']),
                  forest,
                ),
                ChartDatum(
                  'No independent record',
                  recordNumber(quran['totalAyahs']) -
                      recordNumber(quran['memorisedAyahs']),
                  line,
                ),
              ],
              center: '${quran['percent']}%',
              caption: 'of the whole Qur\'an',
            ),
            OutlinedButton(
              onPressed: () => widget.onOpen(3, childId: '${child['id']}'),
              child: const Text("View Qur'an progress"),
            ),
          ]),
        ),
        second: announcements(recordList(overview['announcements'])),
      ),
      PanelColumns(
        first: panel(
          'Your child at a glance',
          stack([
            detail(
              'Class teacher',
              recordMap(
                recordMap(child['currentClass'])['teacher'],
              )['fullName'],
            ),
            detail(
              'Academic year',
              recordMap(child['currentClass'])['academicYear'],
            ),
            detail('Joined', shortDate(child['joinedOn'])),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => widget.onOpen(1, childId: '${child['id']}'),
                  child: const Text('My children'),
                ),
                OutlinedButton(
                  onPressed: () => widget.onOpen(2, childId: '${child['id']}'),
                  child: const Text('Attendance records'),
                ),
                OutlinedButton(
                  onPressed: () => widget.onOpen(5, childId: '${child['id']}'),
                  child: const Text('Invoices & payments'),
                ),
              ],
            ),
          ]),
        ),
        second: panel(
          'Academic reports',
          const TeacherNotice(
            'Academic grades and downloadable reports are not yet available in this portal. Please contact the school for an official report.',
          ),
        ),
      ),
    ]);
  }

  Widget childCards(List<Map<String, dynamic>> children) => stack([
    for (final child in children)
      panel(
        recordText(child['fullName']),
        stack([
          StudentIdentity(
            child,
            subtitle:
                '${recordText(recordMap(child['currentClass'])['name'], 'No class assigned')} | ${recordText(recordMap(child['branch'])['name'])}',
          ),
          TeacherTag(friendlyStatus(child['status'])),
          MetricRow(
            children: [
              metric(
                'Attendance',
                recordMap(child['attendance'])['rate'] == null
                    ? 'No records'
                    : '${recordMap(child['attendance'])['rate']}%',
                Icons.calendar_month_outlined,
                blue,
                'This month',
              ),
              metric(
                "Qur'an memorised",
                '${recordMap(child['quran'])['percent']}%',
                Icons.menu_book_outlined,
                forest,
                'Independent ayahs recorded',
              ),
              metric(
                'Academic year',
                recordMap(child['currentClass'])['academicYear'] ??
                    'Unassigned',
                Icons.school_outlined,
                gold,
                'Current enrolment',
              ),
              metric(
                'Student number',
                child['admissionNo'],
                Icons.badge_outlined,
                blue,
                'School-issued identifier',
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () {
                  widget.onChildSelected('${child['id']}');
                  setState(() => profileId = '${child['id']}');
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('View profile'),
              ),
              OutlinedButton(
                onPressed: () => widget.onOpen(3, childId: '${child['id']}'),
                child: const Text("Qur'an progress"),
              ),
              OutlinedButton(
                onPressed: () => widget.onOpen(2, childId: '${child['id']}'),
                child: const Text('Attendance'),
              ),
              OutlinedButton(
                onPressed: () => widget.onOpen(5, childId: '${child['id']}'),
                child: const Text('Payments'),
              ),
            ],
          ),
        ]),
      ),
  ]);

  Widget detail(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: muted)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(recordText(value), style: const TextStyle(color: ink)),
        ),
      ],
    ),
  );

  Widget profile(String id) => data('$base/children/$id/profile', (result) {
    final child = recordMap(result['student']),
        guardian = recordMap(result['guardian']);
    final classInfo = recordMap(child['currentClass']);
    return stack([
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => profileId = null),
          icon: const Icon(Icons.arrow_back),
          label: const Text('All children'),
        ),
      ),
      panel(
        'Child profile',
        StudentIdentity(
          child,
          subtitle:
              '${recordText(classInfo['name'])} | ${friendlyStatus(child['status'])}',
        ),
      ),
      PanelColumns(
        first: panel(
          'Profile summary',
          stack([
            detail('Full name', child['fullName']),
            detail('Date of birth', shortDate(child['dob'])),
            detail('Gender', friendlyStatus(child['gender'])),
            detail('Student number', child['admissionNo']),
            detail('Joined', shortDate(child['joinedOn'])),
            detail('Campus', recordMap(child['branch'])['name']),
            OutlinedButton(
              onPressed: officeHelp,
              child: const Text('Request a correction'),
            ),
          ]),
        ),
        second: panel(
          'Enrolment & guardian',
          stack([
            detail('Class', classInfo['name']),
            detail('Academic year', classInfo['academicYear']),
            detail(
              'Class teacher',
              recordMap(classInfo['teacher'])['fullName'],
            ),
            detail('Guardian', guardian['fullName']),
            detail('Relationship', guardian['relationship']),
            detail('Your email', guardian['email']),
            detail('Your phone', guardian['phone']),
          ]),
        ),
      ),
      panel(
        'Current timetable',
        recordList(result['timetable']).isEmpty
            ? const EmptyRecords(
                'No current timetable has been published for this class.',
              )
            : RecordTable(
                columns: const ['Day', 'Time', 'Subject', 'Room'],
                rows: [
                  for (final slot in recordList(result['timetable']))
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            teachingDays[(recordNumber(
                                      slot['weekday'],
                                    ).toInt() -
                                    1)
                                .clamp(0, 6)],
                          ),
                        ),
                        DataCell(
                          Text('${slot['startsAt']} - ${slot['endsAt']}'),
                        ),
                        DataCell(Text(recordText(slot['subject']))),
                        DataCell(Text(recordText(slot['room']))),
                      ],
                    ),
                ],
              ),
      ),
    ]);
  });

  Widget announcements(List<Map<String, dynamic>> rows) => panel(
    'School updates',
    rows.isEmpty
        ? const EmptyRecords('No published notices for your family.')
        : stack([
            for (final row in rows)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recordText(row['title']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    recordText(row['message']),
                    style: const TextStyle(color: muted, height: 1.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    shortDate(row['publishAt']),
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                  const Divider(color: line),
                ],
              ),
          ]),
  );

  Widget attendance(String id) => stack([
    Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: month.year <= 2000 && month.month == 1
              ? null
              : () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          MaterialLocalizations.of(context).formatMonthYear(month),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: month.year >= 2100 && month.month == 12
              ? null
              : () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
          icon: const Icon(Icons.chevron_right),
        ),
        TextButton(
          onPressed: () => setState(
            () => month = DateTime(DateTime.now().year, DateTime.now().month),
          ),
          child: const Text('This month'),
        ),
      ],
    ),
    data('$base/children/$id/attendance?month=$monthKey', (result) {
      final summary = recordMap(result['summary']),
          rows = recordList(result['records']);
      return stack([
        MetricRow(
          children: [
            metric(
              'Present',
              summary['PRESENT'],
              Icons.groups_outlined,
              forest,
              'On-time records',
            ),
            metric(
              'Absent',
              summary['ABSENT'],
              Icons.close,
              const Color(0xFFC44C68),
              'Recorded absences',
            ),
            metric(
              'Late',
              summary['LATE'],
              Icons.schedule,
              gold,
              'Included as attended',
            ),
            metric(
              'Excused',
              summary['EXCUSED'],
              Icons.event_available_outlined,
              blue,
              'Excluded from attendance rate',
            ),
          ],
        ),
        PanelColumns(
          first: panel(
            'Attendance calendar',
            FamilyAttendanceCalendar(month: month, records: rows),
          ),
          second: panel(
            'Recent attendance & notes',
            rows.isEmpty
                ? const EmptyRecords('No attendance recorded this month.')
                : stack([
                    for (final row in rows)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text(shortDate(row['date'])),
                              TeacherTag(
                                friendlyStatus(row['status']),
                                color: attendanceColor(row['status']),
                              ),
                            ],
                          ),
                          if (row['reason'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(recordText(row['reason'])),
                            ),
                          if (row['checkInTime'] != null)
                            Text('Arrival: ${row['checkInTime']}'),
                          const Divider(color: line),
                        ],
                      ),
                  ]),
          ),
        ),
        const TeacherNotice(
          'Unmarked dates mean no record, not absence or a school holiday. Late counts as attended; excused days are excluded from the attendance rate. Contact the office about corrections.',
        ),
      ]);
    }),
  ]);

  Widget quran(
    String id,
  ) => data('$base/children/$id/quran?page=$sessionPage', (result) {
    final latest = recordMap(result['latestSession']),
        chapters = recordList(result['chapters']);
    String chapterName(dynamic chapterId) => recordText(
      chapters.where((c) => '${c['id']}' == '$chapterId').firstOrNull?['name'],
      'Surah $chapterId',
    );
    return stack([
      MetricRow(
        children: [
          metric(
            'Memorised ayahs',
            result['memorisedAyahs'],
            Icons.menu_book_outlined,
            forest,
            'Independent, unique ayahs',
          ),
          metric(
            'Whole Qur\'an progress',
            '${result['percent']}%',
            Icons.bar_chart,
            gold,
            'Out of ${result['totalAyahs']} ayahs',
          ),
          metric(
            'Learning sessions',
            recordMap(result['meta'])['totalItems'],
            Icons.history,
            blue,
            'Reading, memorisation and revision',
          ),
          metric(
            'Last recorded',
            latest.isEmpty ? 'No sessions' : shortDate(latest['learnedOn']),
            Icons.event_outlined,
            forest,
            'Teacher-confirmed learning',
          ),
        ],
      ),
      PanelColumns(
        firstFlex: 2,
        first: panel(
          'Surah & Juz progress',
          stack([
            Wrap(
              spacing: 12,
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
              builder: (context, constraints) {
                final items = bySurah ? chapters : recordList(result['juzs']);
                final count = bySurah
                    ? (constraints.maxWidth > 500 ? 3 : 2)
                    : (constraints.maxWidth > 500 ? 10 : 5);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: (constraints.maxWidth - (count - 1) * 8) / count,
                        child: Tooltip(
                          message:
                              '${item['memorisedAyahs']} / ${item['ayahCount'] ?? item['totalAyahs']} ayahs independently memorised',
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 65),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: recordNumber(item['memorisedAyahs']) > 0
                                  ? forest.withValues(alpha: .09)
                                  : const Color(0xFFF2F4F7),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: line),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  bySurah
                                      ? '${item['id']}. ${item['name']}'
                                      : '${item['number']}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Icon(
                                  recordNumber(item['memorisedAyahs']) ==
                                          recordNumber(
                                            item['ayahCount'] ??
                                                item['totalAyahs'],
                                          )
                                      ? Icons.check_circle
                                      : recordNumber(item['memorisedAyahs']) > 0
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
                  ],
                );
              },
            ),
            const Text(
              'Green: recorded memorisation. A check marks a complete surah or juz. Grey: no independent memorisation record.',
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
                    chapterName(latest['surahId']),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: ink,
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
                    'Reading and revision are recorded separately. Only independent memorisation contributes to this tracker.',
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
                for (final s in recordList(result['sessions']))
                  DataRow(
                    cells: [
                      DataCell(Text(shortDate(s['learnedOn']))),
                      DataCell(
                        Text(
                          '${chapterName(s['surahId'])} | ${s['ayahFrom']}-${s['ayahTo']}',
                        ),
                      ),
                      DataCell(
                        Text(recordText(learningActivities[s['activity']])),
                      ),
                      DataCell(
                        Text(
                          recordText(learningObservations[s['observation']]),
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
                onPressed:
                    sessionPage <
                        recordNumber(recordMap(result['meta'])['totalPages'])
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

  Widget payments(String id) => TeacherData(
    key: ValueKey('finance-$id'),
    load: widget.load,
    path: '/api/parent-portal/students/$id/finance',
    refreshToken: widget.refreshToken,
    builder: (value) => panel(
      'Invoices & payment history',
      recordList(value).isEmpty
          ? const EmptyRecords('No invoices issued for this child.')
          : stack([
              const TeacherNotice(
                'These are server-confirmed invoice and payment records. A pending payment is not a receipt. Contact the office for payment assistance.',
              ),
              for (final invoice in recordList(value))
                SurfacePanel(
                  child: stack([
                    PanelHeading(
                      recordText(invoice['invoiceNo']),
                      subtitle: 'Due ${shortDate(invoice['dueDate'])}',
                    ),
                    TeacherTag(friendlyStatus(invoice['status'])),
                    detail(
                      'Invoice amount',
                      '${invoice['currency']} ${invoice['amountDue']}',
                    ),
                    detail(
                      'Paid',
                      '${invoice['currency']} ${invoice['amountPaid']}',
                    ),
                    detail(
                      'Remaining',
                      '${invoice['currency']} ${invoice['balanceRemaining']}',
                    ),
                    if (recordList(invoice['payments']).isEmpty)
                      const Text(
                        'No payment records yet.',
                        style: TextStyle(color: muted),
                      ),
                    for (final payment in recordList(invoice['payments']))
                      detail(
                        '${friendlyStatus(payment['status'])} | ${recordText(payment['reference'])}',
                        '${payment['currency']} ${payment['amount']}',
                      ),
                  ]),
                ),
            ]),
    ),
  );

  Widget support(Map<String, dynamic> guardian) => PanelColumns(
    firstFlex: 2,
    first: panel(
      'Help center',
      stack([
        for (final faq in const [
          (
            'How do I add my child?',
            'Contact the school office. Staff verify your guardian relationship before linking an existing student record.',
          ),
          (
            'Can I mark attendance?',
            'Attendance is recorded by authorised school staff. Contact the office to explain an absence or request a correction.',
          ),
          (
            'How is Qur\'an progress calculated?',
            'It counts unique ayahs recorded as independently memorised. Reading, supported practice and revision are separate learning activities.',
          ),
          (
            'Where are academic reports and messages?',
            'Published academic reports and private teacher messaging are not yet available in this portal. Contact the school directly.',
          ),
        ])
          ExpansionTile(
            title: Text(faq.$1),
            childrenPadding: const EdgeInsets.all(16),
            children: [Text(faq.$2)],
          ),
      ]),
    ),
    second: stack([
      panel(
        'Your guardian profile',
        stack([
          detail('Name', guardian['fullName']),
          detail('Email', guardian['email']),
          detail('Phone', guardian['phone']),
          OutlinedButton(
            onPressed: officeHelp,
            child: const Text('Request profile update'),
          ),
        ]),
      ),
      panel(
        'Contact support',
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'School office',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12),
            SelectableText('+255 715 735 335\n+255 683 186 987'),
            SizedBox(height: 16),
            Text(
              'For urgent matters, call the office directly. Never share your password.',
              style: TextStyle(color: muted, height: 1.6),
            ),
          ],
        ),
      ),
    ]),
  );
}

Color attendanceColor(dynamic status) => switch (status) {
  'PRESENT' => forest,
  'LATE' => gold,
  'ABSENT' => const Color(0xFFC44C68),
  'EXCUSED' => blue,
  _ => muted,
};

class FamilyAttendanceCalendar extends StatelessWidget {
  const FamilyAttendanceCalendar({
    super.key,
    required this.month,
    required this.records,
  });
  final DateTime month;
  final List<Map<String, dynamic>> records;
  @override
  Widget build(BuildContext context) {
    final offset = DateTime(month.year, month.month).weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final statuses = {
      for (final row in records)
        recordText(row['date']).split('T').first: row['status'],
    };
    return Column(
      children: [
        Row(
          children: [
            for (final day in const [
              'Sun',
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
            ])
              Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (var week = 0; week < ((days + offset) / 7).ceil(); week++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final day = week * 7 + col - offset + 1;
                      if (day < 1 || day > days) {
                        return const SizedBox(height: 44);
                      }
                      final key =
                          '${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                      final status = statuses[key];
                      final label = status == null
                          ? 'No record'
                          : friendlyStatus(status);
                      return Semantics(
                        label: '$key: $label',
                        child: Tooltip(
                          message: label,
                          child: Container(
                            height: 38,
                            margin: const EdgeInsets.all(3),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: status == null
                                  ? Colors.transparent
                                  : attendanceColor(
                                      status,
                                    ).withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: status == null
                                    ? muted
                                    : attendanceColor(status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final status in const ['PRESENT', 'ABSENT', 'LATE', 'EXCUSED'])
              TeacherTag(
                friendlyStatus(status),
                color: attendanceColor(status),
              ),
            const Text(
              'Unmarked: no record',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _FamilyBanner extends StatelessWidget {
  const _FamilyBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(
        colors: [Color(0xFFF8EFDD), Color(0xFFFFFCF6)],
      ),
    ),
    child: const Wrap(
      spacing: 20,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.menu_book_outlined, color: gold, size: 32),
        Text(
          'Knowledge. Character. Brighter lives.',
          style: TextStyle(
            fontFamily: 'NotoSerifDisplay',
            color: ink,
            fontSize: 18,
          ),
        ),
        Text(
          'Together, supporting your child\'s learning.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
  );
}
