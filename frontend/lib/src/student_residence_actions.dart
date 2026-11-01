import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'madrasa_location_fields.dart';
import 'workspace_form_dialog.dart';

Future<bool> editStudentResidence(
  BuildContext context,
  String id,
  PageLoader load,
  PageSubmitter submit,
) async {
  final path = '/api/students/${Uri.encodeComponent(id)}/residence';
  Map<String, dynamic> data;
  try {
    data = recordMap(await load(path));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load student residence. Check access and try again.',
          ),
        ),
      );
    }
    return false;
  }
  if (!context.mounted) return false;
  final residence = recordMap(data['residence']);
  final guardian = recordMap(data['guardian']);
  var mode = data['needsReview'] == true
      ? 'UNKNOWN'
      : '${residence['mode'] ?? 'UNKNOWN'}';
  final chosen = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => WorkspaceFormDialog(
        title: const Text('Student residence'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(recordText(data['fullName'])),
                const SizedBox(height: 16),
                if (data['needsReview'] == true)
                  const WorkspaceFormNotice(
                    message:
                        'The primary guardian changed. Confirm where the student lives again.',
                  ),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Living arrangement',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'UNKNOWN',
                      child: Text('Not recorded'),
                    ),
                    if (guardian.isNotEmpty)
                      const DropdownMenuItem(
                        value: 'GUARDIAN',
                        child: Text('Lives with primary guardian'),
                      ),
                    const DropdownMenuItem(
                      value: 'SEPARATE',
                      child: Text('Lives at a different address'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => mode = value ?? 'UNKNOWN'),
                ),
                const SizedBox(height: 16),
                if (mode == 'GUARDIAN') ...[
                  Text('Guardian: ${recordText(guardian['fullName'])}'),
                  Text(
                    locationSummary(
                      guardian['location'],
                      fallback: recordText(
                        guardian['legacyAddress'],
                        'Guardian address not recorded',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Uses the linked guardian address without copying it. This does not change the guardian record.',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, mode),
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
  if (chosen == null || !context.mounted) return false;
  final initial = recordMap(residence['location']);
  return showAdminForm(
    context,
    title: 'Residence: ${recordText(data['fullName'])}',
    load: load,
    saveLabel: 'Save residence',
    note: chosen == 'GUARDIAN'
        ? 'Confirm that this student lives with ${recordText(guardian['fullName'])}.'
        : chosen == 'UNKNOWN'
        ? 'Remove the recorded living arrangement. Guardian details will not change.'
        : 'Enter at least one address field for this student. Guardian details will not change.',
    conflictMessage: 'Student or guardian changed. Close and reopen this form.',
    fields: [
      if (chosen == 'SEPARATE')
        AdminField(
          'location',
          'Student address',
          kind: 'location',
          required: false,
          initialLocation: {
            for (final key in madrasaLocationLabels.keys)
              if (initial[key] is String) key: initial[key] as String,
          },
        ),
      const AdminField('reason', 'Reason for this change', minLength: 10),
    ],
    onSave: (values) async {
      await submit(path, {
        'revision': data['revision'],
        'reason': values['reason'],
        'residence': {
          'mode': chosen,
          if (chosen == 'GUARDIAN') 'guardianId': guardian['id'],
          if (chosen == 'SEPARATE')
            'location': values['location'] ?? <String, dynamic>{},
        },
      });
    },
  );
}
