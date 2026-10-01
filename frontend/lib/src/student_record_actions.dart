import 'package:flutter/material.dart';

import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';

class StudentRecordActions extends StatefulWidget {
  const StudentRecordActions({
    super.key,
    required this.student,
    required this.load,
    required this.submit,
    required this.onChanged,
  });

  final Map<String, dynamic> student;
  final PageLoader load;
  final PageSubmitter submit;
  final VoidCallback onChanged;

  @override
  State<StudentRecordActions> createState() => _StudentRecordActionsState();
}

class _StudentRecordActionsState extends State<StudentRecordActions> {
  bool busy = false;
  bool loading = false;

  Future<void> open(String action) async {
    if (busy) return;
    setState(() {
      busy = true;
      loading = true;
    });
    try {
      final path = '/api/admin/students/${widget.student['id']}';
      final record = recordMap(await widget.load('$path/record'));
      if (!mounted) return;
      setState(() => loading = false);
      if (action == 'history') {
        await showDialog<void>(
          context: context,
          builder: (_) => _StudentHistory(record: record),
        );
        return;
      }
      final editing = action == 'edit';
      final archiving = action == 'archive';
      final title = editing
          ? 'Edit student'
          : archiving
          ? 'Remove student'
          : 'Restore student';
      String? date(String key) {
        final value = record[key]?.toString();
        return value?.split('T').first;
      }

      final saved = await showAdminForm(
        context,
        title: title,
        saveLabel: editing ? 'Save changes' : title,
        conflictMessage:
            'The record may have changed, or the admission number is already in use. Check the number; otherwise close this form and reopen the student record.',
        note: editing
            ? 'Update ${recordText(record['fullName'])}\'s personal details. Class placement and guardian links are managed separately.'
            : archiving
            ? '${recordText(record['fullName'])} will be removed from active student and teaching lists, not permanently deleted. Learning and payment history will be kept. Find the student under Inactive to restore them.'
            : '${recordText(record['fullName'])} will become active again with their existing class and history. Check their class placement after restoring.',
        fields: [
          if (editing) ...[
            AdminField('fullName', 'Full name', initial: record['fullName']),
            AdminField(
              'admissionNo',
              'Admission number',
              initial: record['admissionNo'],
            ),
            AdminField(
              'gender',
              'Gender',
              initial: record['gender'] ?? 'unspecified',
              options: const {
                'unspecified': 'Not recorded',
                'male': 'Male',
                'female': 'Female',
              },
            ),
            AdminField(
              'dob',
              'Date of birth (YYYY-MM-DD)',
              required: false,
              initial: date('dob'),
            ),
            AdminField(
              'joinedOn',
              'Joining date (YYYY-MM-DD)',
              required: false,
              initial: date('joinedOn'),
            ),
            AdminField(
              'notes',
              'Notes',
              required: false,
              initial: record['notes'],
            ),
          ],
          const AdminField('reason', 'Reason for this change'),
        ],
        onSave: (values) async {
          await widget.submit('$path/$action', {
            'revision': record['revision'],
            'reason': values['reason'],
            if (editing) ...{
              'fullName': values['fullName'],
              'admissionNo': values['admissionNo'],
              'gender': values['gender'] == 'unspecified'
                  ? null
                  : values['gender'],
              'dob': values['dob'],
              'joinedOn': values['joinedOn'],
              'notes': values['notes'],
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
                  ? 'Student details updated.'
                  : archiving
                  ? 'Student removed from the active list. History has been kept.'
                  : 'Student restored.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We could not open this student record. Refresh the list and try again.',
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
    tooltip: 'Manage ${widget.student['fullName']}',
    enabled: !busy,
    icon: loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.more_vert, size: 20),
    onSelected: open,
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'edit', child: Text('Edit student')),
      const PopupMenuItem(value: 'history', child: Text('Change history')),
      if (widget.student['programCategory'] == 'MADRASA_CHILD') ...[
        if (widget.student['status'] == 'ACTIVE')
          const PopupMenuItem(
            value: 'archive',
            child: Row(
              children: [
                Icon(Icons.person_remove_outlined, size: 18),
                SizedBox(width: 10),
                Text('Remove student'),
              ],
            ),
          ),
        if (widget.student['status'] == 'INACTIVE')
          const PopupMenuItem(value: 'restore', child: Text('Restore student')),
      ],
    ],
  );
}

class _StudentHistory extends StatelessWidget {
  const _StudentHistory({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final history = recordList(record['history']);
    return AlertDialog(
      title: Text('Change history: ${recordText(record['fullName'])}'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          primary: true,
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
                Text(switch (entry['action']) {
                  'student.admin_archive' => 'Student archived',
                  'student.admin_restore' => 'Student restored',
                  _ => 'Student details updated',
                }, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  '${recordText(recordMap(entry['actorUser'])['fullName'], 'School office')} | ${_time(entry['createdAt'])}',
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

  String _time(dynamic value) {
    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'Date not available';
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  List<Widget> _changes(Map<String, dynamic> entry) {
    final metadata = recordMap(entry['metadata']);
    final before = recordMap(metadata['before']);
    final after = recordMap(metadata['after']);
    const labels = {
      'fullName': 'Name',
      'admissionNo': 'Admission number',
      'gender': 'Gender',
      'dob': 'Date of birth',
      'joinedOn': 'Joining date',
      'notes': 'Notes',
      'status': 'Status',
    };
    String display(String key, dynamic value) {
      if (value == null || value == '') return 'Not recorded';
      if (key == 'status' || key == 'gender') return friendlyStatus(value);
      if (key == 'dob' || key == 'joinedOn') {
        return value.toString().split('T').first;
      }
      return value.toString();
    }

    return [
      for (final field in labels.entries)
        if (before[field.key] != after[field.key])
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${field.value}: ${display(field.key, before[field.key])} to ${display(field.key, after[field.key])}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
    ];
  }
}
