import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'madrasa_location_fields.dart';
import 'workspace_details_dialog.dart';

class MadrasaReviewSummary extends StatelessWidget {
  const MadrasaReviewSummary({
    super.key,
    required this.record,
    required this.approving,
  });
  final Map<String, dynamic> record;
  final bool approving;

  @override
  Widget build(BuildContext context) {
    final location = record['location'];
    final color = approving ? AfaqDesign.green : const Color(0xffa53e42);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkspaceDetailsSection(
          title: 'Madrasa & administrator',
          icon: Icons.account_balance_outlined,
          child: WorkspaceRecordDetails(
            fields: [
              ('Madrasa', '${record['schoolName'] ?? 'Not recorded'}'),
              ('Afaq code', '${record['requestedCode'] ?? 'Not recorded'}'),
              (
                'Proposed administrator email',
                '${record['adminEmail'] ?? 'Not recorded'}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        WorkspaceDetailsSection(
          title: 'Location',
          icon: Icons.location_on_outlined,
          child: location is Map
              ? WorkspaceRecordDetails(
                  fields: [
                    for (final entry in madrasaLocationLabels.entries)
                      if ([
                            'country',
                            'region',
                            'district',
                            'ward',
                          ].contains(entry.key) ||
                          '${location[entry.key] ?? ''}'.trim().isNotEmpty)
                        (
                          entry.value,
                          '${location[entry.key] ?? 'Not recorded'}',
                        ),
                  ],
                )
              : const Text('Location has not been recorded.'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                approving ? Icons.fact_check_outlined : Icons.info_outline,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      approving
                          ? 'Approve registration'
                          : 'Decline registration',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      approving
                          ? 'Approval allows registration to continue. It does not activate the madrasa or create administrator accounts.'
                          : 'Declining closes this request. Existing madrasa data and accounts are not deleted.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This decision cannot be edited after confirmation.',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
