import 'package:flutter/material.dart';

import 'admin_forms.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';

class ClassRecordActions extends StatefulWidget {
  const ClassRecordActions({
    super.key,
    required this.schoolClass,
    required this.load,
    required this.submit,
    required this.onChanged,
  });

  final Map<String, dynamic> schoolClass;
  final PageLoader load;
  final PageSubmitter submit;
  final VoidCallback onChanged;

  @override
  State<ClassRecordActions> createState() => _ClassRecordActionsState();
}

class _ClassRecordActionsState extends State<ClassRecordActions> {
  bool busy = false;
  bool loading = false;

  Future<void> open(String action) async {
    if (busy) return;
    setState(() {
      busy = true;
      loading = true;
    });
    try {
      final path = '/api/admin/classes/${widget.schoolClass['id']}';
      final record = recordMap(await widget.load('$path/record'));
      if (!mounted) return;
      setState(() => loading = false);
      if (action == 'history') {
        await showDialog<void>(
          context: context,
          builder: (_) => _ClassHistory(record: record),
        );
        return;
      }
      if (action == 'remove' && record['canRemove'] != true) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('This class cannot be removed'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${recordText(record['name'])} has linked records. Its history must be kept.',
                  ),
                  const SizedBox(height: 16),
                  for (final entry in recordMap(record['_count']).entries)
                    if (recordNumber(entry.value) > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${_dependencyLabels[entry.key] ?? entry.key}: ${entry.value}',
                        ),
                      ),
                  const Text(
                    'Only classes with no students or linked records can be permanently removed.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }
      final editing = action == 'edit';
      final teacherOptions = <String, String>{
        'none': 'Not assigned',
        if (record['teacherId'] != null)
          '${record['teacherId']}': recordText(
            recordMap(record['teacher'])['fullName'],
            'Current teacher',
          ),
        for (final teacher in recordList(record['teacherOptions']))
          '${teacher['id']}': recordText(teacher['fullName']),
      };
      final saved = await showAdminForm(
        context,
        title: editing ? 'Edit class' : 'Remove class',
        saveLabel: editing ? 'Save changes' : 'Permanently remove class',
        errorMessage: (error) =>
            error is ApiException && [409, 403].contains(error.statusCode)
            ? error.message
            : null,
        note: editing
            ? 'Update ${recordText(record['name'])}. The campus cannot change here. A class with linked records must keep its academic year. Cancel current and future timetable entries before changing the teacher.'
            : '${recordText(record['name'])} has no linked records. This permanently deletes the class and cannot be undone. The reason and administrator will remain in the audit log.',
        fields: [
          if (editing) ...[
            AdminField('name', 'Class name', initial: record['name']),
            AdminField('level', 'Level', initial: record['level']),
            AdminField(
              'academicYear',
              'Academic year',
              initial: record['academicYear'],
            ),
            AdminField(
              'teacherId',
              'Teacher',
              initial: record['teacherId']?.toString() ?? 'none',
              options: teacherOptions,
            ),
            AdminField(
              'capacity',
              'Capacity',
              kind: 'integer',
              required: false,
              initial: record['capacity']?.toString(),
            ),
          ],
          const AdminField('reason', 'Reason for this change'),
        ],
        onSave: (values) async {
          await widget.submit('$path/$action', {
            'revision': record['revision'],
            'reason': values['reason'],
            if (editing) ...{
              'name': values['name'],
              'level': values['level'],
              'academicYear': values['academicYear'],
              'teacherId': values['teacherId'] == 'none'
                  ? null
                  : values['teacherId'],
              'capacity': values['capacity'] == null
                  ? null
                  : int.parse(values['capacity'] as String),
            },
          });
        },
      );
      if (saved && mounted) {
        widget.onChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editing
                  ? 'Class details updated.'
                  : 'Empty class permanently removed.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We could not open this class record. Refresh the list and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Manage ${widget.schoolClass['name']}',
    enabled: !busy,
    onSelected: open,
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'edit', child: Text('Edit class')),
      PopupMenuItem(value: 'history', child: Text('Change history')),
      PopupMenuItem(value: 'remove', child: Text('Remove class')),
    ],
    icon: loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.more_vert, size: 20),
  );
}

const _dependencyLabels = {
  'currentStudents': 'Assigned students',
  'enrollments': 'Enrollment records',
  'attendance': 'Attendance records',
  'feeStructures': 'Fee structures',
  'timetable': 'Timetable records',
  'quranSessions': "Qur'an sessions",
  'supportNotes': 'Learning support notes',
};

class _ClassHistory extends StatelessWidget {
  const _ClassHistory({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final history = recordList(record['history']);
    return AlertDialog(
      title: Text('Change history: ${recordText(record['name'])}'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                history.isEmpty
                    ? 'No recorded changes yet.'
                    : 'Latest ${history.length} recorded changes',
              ),
              for (final entry in history) ...[
                const Divider(height: 28),
                const Text(
                  'Class details updated',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${recordText(recordMap(entry['actorUser'])['fullName'], 'School office')} | ${shortDate(entry['createdAt'])}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(recordText(recordMap(entry['metadata'])['reason'])),
                ..._changes(entry),
              ],
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

  List<Widget> _changes(Map<String, dynamic> entry) {
    final metadata = recordMap(entry['metadata']);
    final before = recordMap(metadata['before']),
        after = recordMap(metadata['after']);
    const labels = {
      'name': 'Name',
      'level': 'Level',
      'academicYear': 'Academic year',
      'teacherId': 'Teacher',
      'capacity': 'Capacity',
    };
    String display(Map<String, dynamic> value, String key) => key == 'teacherId'
        ? recordText(recordMap(value['teacher'])['fullName'], 'Not assigned')
        : recordText(value[key], 'Not set');
    return [
      for (final field in labels.entries)
        if (before[field.key] != after[field.key])
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${field.value}: ${display(before, field.key)} to ${display(after, field.key)}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
    ];
  }
}
