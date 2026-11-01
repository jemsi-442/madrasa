import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'workspace_details_dialog.dart';

class MadrasaAdministration extends StatelessWidget {
  const MadrasaAdministration({super.key, required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final accounts = record['adminAccounts'] as List?;
    final invitation = record['invitationStatus'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (accounts == null)
          const Text(
            'Administrator account details are unavailable. Refresh the directory.',
          )
        else if (accounts.isEmpty)
          const Text('No administrator account assigned.')
        else
          for (final account in accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WorkspaceRecordDetails(
                fields: [
                  ('Administrator', '${account['fullName']}'),
                  ('Account status', '${account['status']}'),
                ],
                statusFields: const {'Account status'},
              ),
            ),
        const SizedBox(height: 12),
        Text(switch (invitation) {
          'NOT_ISSUED' => 'No invitation recorded.',
          'AWAITING_ACCEPTANCE' =>
            'Invitation awaiting acceptance. Email delivery is not confirmed here.',
          'AWAITING_ACTIVATION' =>
            'Invitation accepted. Administrator is waiting for activation.',
          'ACCEPTED' => 'Invitation accepted.',
          'EXPIRED' => 'Invitation expired. A new invitation is needed.',
          'REVIEW_REQUIRED' =>
            'Invitation and administrator records need review.',
          _ => 'Invitation details unavailable.',
        }, style: const TextStyle(color: AfaqDesign.muted, height: 1.5)),
        if (record['status'] == 'SUSPENDED') ...[
          const SizedBox(height: 12),
          const Text(
            'Madrasa access is suspended, even for active accounts.',
            style: TextStyle(
              color: Color(0xffa53e42),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
