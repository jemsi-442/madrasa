import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'madrasa_location_fields.dart';

Future<bool> editGuardianResidence(
  BuildContext context,
  String studentId,
  PageLoader load,
  PageSubmitter submit,
) async {
  final path =
      '/api/students/${Uri.encodeComponent(studentId)}/guardian-residence';
  Map<String, dynamic> record;
  try {
    record = recordMap(await load(path));
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (error) {
            ApiException(statusCode: 403) =>
              'You cannot edit this guardian residence. Contact the school-wide administrator.',
            ApiException(statusCode: 409) =>
              'Link a primary guardian before editing their residence.',
            _ => 'Could not load guardian residence. Refresh and try again.',
          }),
        ),
      );
    }
    return false;
  }
  if (!context.mounted) return false;
  final location = recordMap(record['location']);
  return showAdminForm(
    context,
    title: 'Residence: ${recordText(record['fullName'])}',
    load: load,
    saveLabel: 'Save residence',
    note:
        'This updates the guardian record shared by linked students, not their individual homes. '
        'Clearing the fields removes only the structured residence.'
        '${record['legacyAddress'] == null ? '' : '\nPrevious address retained: ${record['legacyAddress']}'}',
    conflictMessage:
        'The guardian or linked record changed. Close and reopen this form before saving.',
    fields: [
      AdminField(
        'location',
        'Guardian residence',
        kind: 'location',
        required: false,
        initialLocation: {
          for (final key in madrasaLocationLabels.keys)
            if (location[key] is String) key: location[key] as String,
        },
      ),
      const AdminField(
        'reason',
        'Reason for this change (at least 10 characters)',
        minLength: 10,
      ),
    ],
    onSave: (values) async {
      await submit(path, {
        'guardianId': record['guardianId'],
        'revision': record['revision'],
        'location': values['location'],
        'reason': values['reason'],
      });
    },
  );
}
