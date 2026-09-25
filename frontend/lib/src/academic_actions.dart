import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';

Future<Map<String, String>?> _branches(
  BuildContext context,
  PageLoader load,
) async {
  try {
    final profile = recordMap(await load('/api/organizations/me'));
    return {
      for (final branch in recordList(profile['branches']))
        '${branch['id']}': recordText(branch['name']),
    };
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not load the school branches. Please try again.',
          ),
        ),
      );
    }
    return null;
  }
}

Future<bool> createClassForm(
  BuildContext context,
  PageLoader load,
  PageSubmitter submit,
) async {
  final branches = await _branches(context, load);
  if (branches == null || !context.mounted) return false;
  return showAdminForm(
    context,
    title: 'Create class',
    load: load,
    fields: [
      const AdminField('name', 'Class name'),
      const AdminField('level', 'Level'),
      AdminField(
        'academicYear',
        'Academic year',
        initial: '${DateTime.now().year}',
      ),
      AdminField('branchId', 'Branch', options: branches),
      const AdminField(
        'teacherId',
        'Teacher',
        required: false,
        lookupPath: '/api/admin/teachers',
      ),
      const AdminField(
        'capacity',
        'Capacity',
        required: false,
        kind: 'integer',
      ),
    ],
    onSave: (body) async {
      await submit('/api/classes', {
        ...body,
        if (body['capacity'] != null)
          'capacity': int.parse(body['capacity'] as String),
      });
    },
  );
}

Future<bool> createStudentForm(
  BuildContext context,
  PageLoader load,
  PageSubmitter submit,
) async {
  final existing = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add student'),
      content: const Text(
        'Has the parent or guardian already been registered with the school?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('New guardian'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Existing guardian'),
        ),
      ],
    ),
  );
  if (existing == null || !context.mounted) return false;
  final branches = await _branches(context, load);
  if (branches == null || !context.mounted) return false;
  return showAdminForm(
    context,
    title: 'Student admission',
    load: load,
    saveLabel: 'Register student',
    fields: [
      const AdminField('fullName', 'Student name'),
      const AdminField('admissionNo', 'Admission number'),
      const AdminField(
        'gender',
        'Gender',
        options: {'male': 'Male', 'female': 'Female'},
      ),
      const AdminField('dob', 'Date of birth', kind: 'date', required: false),
      AdminField('branchId', 'Branch', options: branches),
      if (existing)
        const AdminField(
          'primaryGuardianId',
          'Guardian',
          lookupPath: '/api/admin/guardians',
        )
      else ...[
        const AdminField('guardianName', 'Guardian name'),
        const AdminField('guardianPhone', 'Guardian phone number'),
        const AdminField(
          'relationship',
          'Relationship',
          options: {
            'Father': 'Father',
            'Mother': 'Mother',
            'Guardian': 'Guardian',
          },
        ),
      ],
    ],
    onSave: (values) async {
      final body = Map<String, dynamic>.from(values);
      if (!existing) {
        body['guardian'] = {
          'fullName': body.remove('guardianName'),
          'phone': body.remove('guardianPhone'),
          'relationship': body.remove('relationship'),
        };
      }
      await submit('/api/students', body);
    },
  );
}
