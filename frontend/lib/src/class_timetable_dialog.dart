import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';

Future<void> showClassTimetable(
  BuildContext context,
  Map<String, dynamic> schoolClass,
  PageLoader load,
  PageSubmitter submit,
) => showDialog<void>(
  context: context,
  builder: (_) =>
      _ClassTimetable(schoolClass: schoolClass, load: load, submit: submit),
);

class _ClassTimetable extends StatefulWidget {
  const _ClassTimetable({
    required this.schoolClass,
    required this.load,
    required this.submit,
  });
  final Map<String, dynamic> schoolClass;
  final PageLoader load;
  final PageSubmitter submit;
  @override
  State<_ClassTimetable> createState() => _ClassTimetableState();
}

class _ClassTimetableState extends State<_ClassTimetable> {
  String get path =>
      '/api/class-timetable/${widget.schoolClass['id']}/timetable';
  late Future<dynamic> future = widget.load(path);
  void reload() => setState(() {
    future = widget.load(path);
  });
  Future<void> add() async {
    final saved = await showAdminForm(
      context,
      title: 'Add teaching time',
      note:
          'Times use Tanzania time. Choose the dates this weekly lesson runs. The class and its teacher must be free at this time.',
      fields: [
        AdminField(
          'weekday',
          'Teaching day',
          options: {
            for (var day = 1; day <= 7; day++) '$day': teachingDays[day - 1],
          },
        ),
        const AdminField('startsAt', 'Starts at (08:00)'),
        const AdminField('endsAt', 'Ends at (08:45)'),
        const AdminField('subject', 'Subject'),
        const AdminField('focus', 'Teaching focus', required: false),
        const AdminField('room', 'Room', required: false),
        const AdminField('validFrom', 'First teaching date', kind: 'date'),
        const AdminField('validUntil', 'Last teaching date', kind: 'date'),
      ],
      onSave: (values) async {
        await widget.submit(path, {
          ...values,
          'weekday': int.parse('${values['weekday']}'),
        });
      },
    );
    if (saved && mounted) reload();
  }

  Future<void> cancel(Map<String, dynamic> slot) async {
    final saved = await showAdminForm(
      context,
      title: 'Cancel this teaching time?',
      note:
          'The cancelled entry stays in history. Add a new time if the lesson has moved.',
      saveLabel: 'Cancel teaching time',
      fields: const [AdminField('reason', 'Reason')],
      onSave: (values) async {
        await widget.submit('$path/${slot['id']}/cancel', values);
      },
    );
    if (saved && mounted) reload();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.schoolClass['name']} timetable'),
    content: SizedBox(
      width: 900,
      height: MediaQuery.sizeOf(context).height * .65,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TeacherNotice(
              'Weekly teaching times are shown to the assigned teacher during their selected teaching period.',
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: add,
                icon: const Icon(Icons.add),
                label: const Text('Add teaching time'),
              ),
            ),
            const SizedBox(height: 20),
            PageResult(
              future: future,
              onRetry: reload,
              builder: (value) {
                final slots = recordList(value);
                if (slots.isEmpty) {
                  return const EmptyRecords('No teaching times added yet.');
                }
                return RecordTable(
                  minWidth: 820,
                  columns: const [
                    'Day & time',
                    'Subject',
                    'Room',
                    'Teaching period',
                    'Status',
                    '',
                  ],
                  rows: [
                    for (final slot in slots)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '${teachingDays[recordNumber(slot['weekday']).toInt() - 1]}\n${slot['startsAt']} - ${slot['endsAt']}',
                            ),
                          ),
                          DataCell(Text('${slot['subject']}')),
                          DataCell(Text(recordText(slot['room'], '-'))),
                          DataCell(
                            Text(
                              '${shortDate(slot['validFrom'])}\n${shortDate(slot['validUntil'])}',
                            ),
                          ),
                          DataCell(
                            TeacherTag(
                              slot['cancelledAt'] == null
                                  ? 'Scheduled'
                                  : 'Cancelled',
                              color: slot['cancelledAt'] == null
                                  ? forest
                                  : muted,
                            ),
                          ),
                          DataCell(
                            slot['cancelledAt'] != null
                                ? const SizedBox.shrink()
                                : TextButton(
                                    onPressed: () => cancel(slot),
                                    child: const Text('Cancel'),
                                  ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
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
