import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'attendance_register_editor.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';

const attendanceKinds = [
  ('PRESENT', 'Present', forest, Icons.check_circle_outline),
  ('ABSENT', 'Absent', Color(0xFFBD414F), Icons.person_off_outlined),
  ('LATE', 'Late', gold, Icons.schedule),
  ('EXCUSED', 'Excused', blue, Icons.description_outlined),
];

String attendanceSavedAt(dynamic value) {
  final date = DateTime.tryParse(
    '$value',
  )?.toUtc().add(const Duration(hours: 3));
  if (date == null) return 'Date unavailable';
  return '${shortDate(attendanceDay(date))} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String attendanceDay(DateTime date) => date.toIso8601String().substring(0, 10);
DateTime schoolToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 3));
  return DateTime(now.year, now.month, now.day);
}

class AttendanceRegisterPage extends StatefulWidget {
  const AttendanceRegisterPage({
    super.key,
    required this.load,
    required this.submit,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final int refreshToken;
  @override
  State<AttendanceRegisterPage> createState() => _AttendanceRegisterPageState();
}

class _AttendanceRegisterPageState extends State<AttendanceRegisterPage> {
  DateTime date = schoolToday();
  String classId = '', search = '', status = '';
  int page = 1;
  late Future<dynamic> classesFuture = widget.load('/api/classes');
  Future<dynamic>? registerFuture;

  String get query => Uri(
    queryParameters: {'classId': classId, 'date': attendanceDay(date)},
  ).query;

  void reload() => setState(() {
    registerFuture = widget.load('/api/attendance/register?$query');
  });

  @override
  void didUpdateWidget(covariant AttendanceRegisterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      classesFuture = widget.load('/api/classes');
      if (classId.isNotEmpty) {
        registerFuture = widget.load('/api/attendance/register?$query');
      }
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: schoolToday(),
    );
    if (picked == null || !mounted) return;
    date = picked;
    page = 1;
    if (classId.isNotEmpty) {
      reload();
    } else {
      setState(() {});
    }
  }

  Future<void> edit(Map<String, dynamic> data) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AttendanceRegisterEditor(
        data: data,
        submit: widget.submit,
        reload: () => widget.load('/api/attendance/register?$query'),
      ),
    );
    if (saved == true && mounted) {
      reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attendance saved.')));
    }
  }

  Future<void> history(Map<String, dynamic> data) async {
    final students = {
      for (final item in recordList(data['items']))
        '${item['id']}': recordText(item['fullName']),
    };
    await showDialog<void>(
      context: context,
      builder: (context) => _AttendanceHistory(
        load: () => widget.load('/api/attendance/register/history?$query'),
        students: students,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SurfacePanel(
        child: PageResult(
          future: classesFuture,
          onRetry: () => setState(() {
            classesFuture = widget.load('/api/classes');
          }),
          builder: (data) {
            final classes = recordList(data);
            return Wrap(
              spacing: 16,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 210,
                  child: OutlinedButton.icon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(shortDate(attendanceDay(date))),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('register-class-$classId'),
                    initialValue: classes.any((c) => '${c['id']}' == classId)
                        ? classId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Class'),
                    hint: const Text('Choose a class'),
                    items: [
                      for (final c in classes)
                        DropdownMenuItem(
                          value: '${c['id']}',
                          child: Text(
                            '${c['name']} - ${c['academicYear']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      classId = value ?? '';
                      page = 1;
                      reload();
                    },
                  ),
                ),
                if (classes.isEmpty)
                  const Text('Create a class before taking attendance.'),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 18),
      if (registerFuture == null)
        const SurfacePanel(
          child: EmptyRecords('Choose a class to open its daily register.'),
        )
      else
        PageResult(future: registerFuture!, onRetry: reload, builder: register),
    ],
  );

  Widget register(dynamic value) {
    final data = recordMap(value), summary = recordMap(data['summary']);
    final group = recordMap(data['class']);
    final all = recordList(data['items']);
    final items = all.where((s) {
      final rowStatus = s['recordedElsewhere'] == true
          ? 'ELSEWHERE'
          : recordMap(s['attendance'])['status'] ?? 'UNMARKED';
      return (status.isEmpty || rowStatus == status) &&
          '${s['fullName']} ${s['admissionNo']}'.toLowerCase().contains(
            search.toLowerCase(),
          );
    }).toList();
    final pages = (items.length / 10).ceil();
    final currentPage = page.clamp(1, pages == 0 ? 1 : pages);
    final visible = items.skip((currentPage - 1) * 10).take(10);
    final total = recordNumber(summary['total']);
    final present = recordNumber(summary['present']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricRow(
          children: [
            for (final (key, label, color, icon) in attendanceKinds)
              DashboardMetric(
                label: label,
                value: '${recordNumber(summary[key.toLowerCase()])}',
                icon: icon,
                accent: color,
                dense: true,
                note: 'On selected date',
              ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${recordText(group['name'])} | ${recordText(recordMap(group['teacher'])['fullName'], 'No teacher assigned')}',
              style: const TextStyle(color: muted),
            ),
            FilledButton.icon(
              onPressed: all.any((s) => s['editable'] == true)
                  ? () => edit(data)
                  : null,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text(total == 0 ? 'Take attendance' : 'Update attendance'),
            ),
            OutlinedButton.icon(
              onPressed: () => history(data),
              icon: const Icon(Icons.history),
              label: const Text('View history'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        PanelColumns(
          firstFlex: 2,
          first: SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PanelHeading(
                  'Student attendance',
                  subtitle:
                      '${all.length} students | ${recordNumber(summary['unmarked'])} not yet marked',
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextFormField(
                        initialValue: search,
                        decoration: const InputDecoration(
                          hintText: 'Search name or admission number',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() {
                          search = v;
                          page = 1;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<String>(
                        initialValue: status,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('All students'),
                          ),
                          const DropdownMenuItem(
                            value: 'UNMARKED',
                            child: Text('Not marked'),
                          ),
                          for (final (key, label, _, _) in attendanceKinds)
                            DropdownMenuItem(value: key, child: Text(label)),
                        ],
                        onChanged: (v) => setState(() {
                          status = v ?? '';
                          page = 1;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  EmptyRecords(
                    all.isEmpty
                        ? 'No students are assigned to this register.'
                        : 'No students match your search.',
                  )
                else
                  RecordTable(
                    minWidth: 780,
                    columns: const [
                      'Student',
                      'Status',
                      'Check-in',
                      'Notes',
                      'Recorded by',
                    ],
                    rows: [
                      for (final s in visible)
                        DataRow(
                          cells: [
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recordText(s['fullName']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${s['admissionNo']}${s['current'] == true ? '' : ' | Previous class member'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              AttendanceStatus(
                                status: s['recordedElsewhere'] == true
                                    ? 'ELSEWHERE'
                                    : recordMap(s['attendance'])['status']
                                          as String?,
                              ),
                            ),
                            DataCell(
                              Text(
                                recordText(
                                  recordMap(s['attendance'])['checkInTime'],
                                  '-',
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 180,
                                child: Text(
                                  recordText(
                                    recordMap(s['attendance'])['reason'],
                                    '-',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                recordText(
                                  recordMap(
                                    recordMap(s['attendance'])['markedBy'],
                                  )['fullName'],
                                  '-',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                DirectoryPager(
                  meta: {
                    'page': currentPage,
                    'totalPages': pages,
                    'totalItems': items.length,
                  },
                  onPage: (v) => setState(() => page = v),
                ),
              ],
            ),
          ),
          second: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SurfacePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PanelHeading(
                      'Attendance trend',
                      subtitle: 'Present among saved records | Last 7 days',
                    ),
                    AttendanceTrend(days: recordList(data['timeline'])),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SurfacePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PanelHeading(
                      'Attendance summary',
                      subtitle: 'Selected class and date',
                    ),
                    RingChart(
                      center: total == 0
                          ? '-'
                          : '${(present / total * 100).round()}%',
                      caption: total == 0 ? 'No records' : 'Present',
                      items: [
                        for (final (key, label, color, _) in attendanceKinds)
                          ChartDatum(
                            label,
                            recordNumber(summary[key.toLowerCase()]),
                            color,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${recordNumber(summary['unmarked'])} students not yet marked',
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
  }
}

class AttendanceStatus extends StatelessWidget {
  const AttendanceStatus({super.key, this.status});
  final String? status;
  @override
  Widget build(BuildContext context) {
    final entry = attendanceKinds.where((k) => k.$1 == status).firstOrNull;
    final color = entry?.$3 ?? muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        entry?.$2 ??
            (status == 'ELSEWHERE'
                ? 'Recorded in another class'
                : 'Not marked'),
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AttendanceTrend extends StatelessWidget {
  const AttendanceTrend({super.key, required this.days});
  final List<Map<String, dynamic>> days;
  @override
  Widget build(BuildContext context) {
    final values = [
      for (final day in days)
        recordNumber(day['total']) == 0
            ? null
            : recordNumber(day['present']) / recordNumber(day['total']) * 100,
    ];
    if (values.every((v) => v == null)) {
      return const EmptyRecords('No attendance recorded in these seven days.');
    }
    return Column(
      children: [
        Semantics(
          label: [
            for (var i = 0; i < days.length; i++)
              '${days[i]['date']}: ${values[i] == null ? 'No records' : '${values[i]!.round()} percent present'}',
          ].join(', '),
          child: SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(painter: _TrendPainter(values)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: Tooltip(
                  message:
                      '${days[i]['date']}: ${values[i] == null ? 'No records' : '${values[i]!.round()}% present'}',
                  child: Text(
                    recordText(days[i]['date']).substring(8),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Gaps mean no records, not absence.',
          style: TextStyle(fontSize: 11, color: muted),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values);
  final List<num?> values;
  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(32, 12, size.width - 42, size.height - 24);
    for (final tick in [0, 25, 50, 75, 100]) {
      final y = area.bottom - area.height * tick / 100;
      canvas.drawLine(
        Offset(area.left, y),
        Offset(area.right, y),
        Paint()..color = ink.withValues(alpha: .08),
      );
      final label = TextPainter(
        text: TextSpan(
          text: '$tick',
          style: const TextStyle(fontSize: 10, color: muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y - label.height / 2));
    }
    Offset? previous;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        previous = null;
        continue;
      }
      final point = Offset(
        area.left +
            area.width * i / (values.length > 1 ? values.length - 1 : 1),
        area.bottom - area.height * value / 100,
      );
      if (previous != null) {
        final fill = Path()
          ..moveTo(previous.dx, area.bottom)
          ..lineTo(previous.dx, previous.dy)
          ..lineTo(point.dx, point.dy)
          ..lineTo(point.dx, area.bottom)
          ..close();
        canvas.drawPath(fill, Paint()..color = gold.withValues(alpha: .09));
        canvas.drawLine(
          previous,
          point,
          Paint()
            ..color = gold
            ..strokeWidth = 2,
        );
      }
      canvas.drawCircle(point, 4, Paint()..color = gold);
      previous = point;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _AttendanceHistory extends StatefulWidget {
  const _AttendanceHistory({required this.load, required this.students});
  final Future<dynamic> Function() load;
  final Map<String, String> students;
  @override
  State<_AttendanceHistory> createState() => _AttendanceHistoryState();
}

class _AttendanceHistoryState extends State<_AttendanceHistory> {
  late Future<dynamic> future = widget.load();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Attendance history'),
    content: SizedBox(
      width: 700,
      child: SingleChildScrollView(
        child: PageResult(
          future: future,
          onRetry: () => setState(() => future = widget.load()),
          builder: (data) {
            final items = recordList(data);
            if (items.isEmpty) {
              return const EmptyRecords('No recorded changes for this date.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Latest 50 saves. Earlier records may predate change history.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                for (final entry in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          recordText(
                            recordMap(entry['actorUser'])['fullName'],
                            'School office',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          attendanceSavedAt(entry['createdAt']),
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        if (recordMap(entry['metadata'])['correctionReason'] !=
                            null)
                          Text(
                            recordText(
                              recordMap(entry['metadata'])['correctionReason'],
                            ),
                          ),
                        for (final change in recordList(
                          recordMap(entry['metadata'])['changes'],
                        ))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${widget.students['${change['studentId']}'] ?? 'Student ${change['studentId']}'}: '
                              '${change['before'] == null ? 'Not marked' : friendlyStatus(recordMap(change['before'])['status'])}'
                              ' to ${friendlyStatus(recordMap(change['after'])['status'])}'
                              '${recordMap(change['after'])['checkInTime'] == null ? '' : ' at ${recordMap(change['after'])['checkInTime']}'}'
                              '${recordMap(change['after'])['reason'] == null ? '' : ' | ${recordMap(change['after'])['reason']}'}',
                            ),
                          ),
                        const Divider(),
                      ],
                    ),
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
