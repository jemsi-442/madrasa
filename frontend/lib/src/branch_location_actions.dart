import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'madrasa_location_fields.dart';
import 'workspace_form_dialog.dart';

Future<void> editBranchLocation(
  BuildContext context,
  PageLoader load,
  PageSubmitter submit,
) async {
  List<Map<String, dynamic>> branches;
  try {
    branches = recordList(await load('/api/organizations/branches'));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load branch locations. Please try again.'),
        ),
      );
    }
    return;
  }
  if (!context.mounted) return;
  final branch = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => WorkspaceFormDialog(
      title: const Text('Branch locations'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (branches.isEmpty)
                const Text('No branches available for your account.'),
              for (final branch in branches)
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(recordText(branch['name'])),
                  subtitle: Text(
                    locationSummary(
                      branch['structuredLocation'],
                      fallback: recordText(branch['location']),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, branch),
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
    ),
  );
  if (branch == null || !context.mounted) return;
  final initial = recordMap(branch['structuredLocation']);
  final saved = await showAdminForm(
    context,
    title: 'Location: ${recordText(branch['name'])}',
    load: load,
    note: branch['location'] == null
        ? null
        : 'Previous address: ${branch['location']}',
    conflictMessage:
        'This branch changed. Close and reopen Branch locations before saving.',
    fields: [
      AdminField(
        'location',
        'Branch location',
        kind: 'location',
        initialLocation: {
          for (final key in madrasaLocationLabels.keys)
            if (initial[key] is String) key: initial[key] as String,
        },
      ),
    ],
    onSave: (body) async {
      await submit('/api/organizations/branches/${branch['id']}/location', {
        ...body,
        'revision': branch['revision'],
      });
    },
  );
  if (saved && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Branch location saved.')));
  }
}
