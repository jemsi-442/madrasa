import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';

class FamilyApplicationsPanel extends StatefulWidget {
  const FamilyApplicationsPanel({
    super.key,
    required this.load,
    required this.submit,
    required this.onApproved,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final VoidCallback onApproved;
  @override
  State<FamilyApplicationsPanel> createState() =>
      _FamilyApplicationsPanelState();
}

class _FamilyApplicationsPanelState extends State<FamilyApplicationsPanel> {
  int page = 1, refresh = 0;
  bool busy = false;
  String status = 'PENDING';
  Future<void> review(Map<String, dynamic> row, bool approve) async {
    if (busy) return;
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Verify this family' : 'Reject this request?'),
        content: Text(
          approve
              ? 'Confirm that the office has independently verified ${row['fullName']} and their authority to access the linked children. Matching names or admission numbers alone is not proof.'
              : 'This request will be closed and its stored password removed. No account will be created. Contact the family privately about the outcome.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Identity verified' : 'Continue'),
          ),
        ],
      ),
    );
    if (verified != true || !mounted) return;
    setState(() => busy = true);
    try {
      Map<String, dynamic>? result;
      final saved = await showAdminForm(
        context,
        title: approve ? 'Approve family request' : 'Confirm rejection',
        saveLabel: approve ? 'Approve and issue number' : 'Reject request',
        load: widget.load,
        note:
            'Applicant: ${row['fullName']}\nEmail: ${row['email']}\nPhone: ${row['phone']}\nChildren supplied by applicant: ${row['childReference']}\nNo email is sent automatically.',
        fields: approve
            ? const [
                AdminField(
                  'guardianId',
                  'Verified guardian',
                  lookupPath: '/api/users/family-guardians',
                  lookupLabel: 'contactLabel',
                  lookupSubtitle: 'childrenSummary',
                ),
                AdminField('regionCode', 'Region code (for example DSM)'),
                AdminField(
                  'receipt',
                  'Receipt supplied privately by applicant',
                ),
              ]
            : const [],
        onSave: (body) async {
          result = recordMap(
            await widget.submit(
              '/api/users/family-applications/${row['id']}/review',
              {
                ...body,
                'decision': approve ? 'APPROVE' : 'REJECT',
                'verified': true,
              },
            ),
          );
        },
      );
      if (!mounted || !saved) return;
      setState(() => refresh++);
      widget.onApproved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Approved. Family number: ${result?['familyLoginId']}. Share privately; the password chosen during registration is unchanged.'
                : 'Request rejected. No account created.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PanelHeading(
        'Family registration requests',
        subtitle:
            'Verify identity through the office before linking any child.',
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final entry in {
            'PENDING': 'Pending',
            'APPROVED': 'Approved',
            'REJECTED': 'Rejected',
          }.entries)
            ChoiceChip(
              label: Text(entry.value),
              selected: status == entry.key,
              onSelected: busy
                  ? null
                  : (_) => setState(() {
                      status = entry.key;
                      page = 1;
                    }),
            ),
          IconButton(
            tooltip: 'Refresh requests',
            onPressed: busy ? null : () => setState(() => refresh++),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      TeacherData(
        key: ValueKey('$status-$page'),
        load: widget.load,
        path: '/api/users/family-applications?status=$status&page=$page',
        refreshToken: refresh,
        builder: (raw) {
          final data = recordMap(raw), rows = recordList(data['items']);
          final total = recordNumber(
            recordMap(data['meta'])['totalItems'],
          ).toInt();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows.isEmpty)
                const EmptyRecords('No requests in this category.'),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SurfacePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recordText(row['fullName']),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text('${row['email']} | ${row['phone']}'),
                        const SizedBox(height: 8),
                        Text(
                          'Applicant-provided children: ${row['childReference']}',
                        ),
                        Text('Submitted: ${shortDate(row['createdAt'])}'),
                        if (status == 'PENDING')
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => review(row, true),
                                child: const Text('Verify and approve'),
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => review(row, false),
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(child: Text('$total requests | Page $page')),
                  IconButton(
                    tooltip: 'Previous requests',
                    onPressed: busy || page == 1
                        ? null
                        : () => setState(() => page--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next requests',
                    onPressed: busy || page * 20 >= total
                        ? null
                        : () => setState(() => page++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ],
  );
}
