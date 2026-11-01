import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'foundation_ui.dart' show DashboardMetric;
import 'it_workspace_visuals.dart';

class PlatformBackupsPage extends StatelessWidget {
  const PlatformBackupsPage({
    super.key,
    required this.onAudit,
    this.onRequest,
    this.requests,
  });
  final VoidCallback onAudit;
  final VoidCallback? onRequest;
  final Widget? requests;
  Widget panel(String title, Widget body) => Container(
    decoration: AfaqDesign.panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(22),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AfaqDesign.ink,
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.all(22), child: body),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final padding = width < 600 ? 16.0 : 28.0;
      final columns = width >= 1100
          ? 4
          : width >= 650
          ? 2
          : 1;
      final history = panel(
        'Backup history',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (width >= 1100) ...[
              Container(
                color: const Color(0xfff5f7f8),
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    Expanded(child: Text('Snapshot')),
                    Expanded(child: Text('Created')),
                    Expanded(child: Text('Scope')),
                    Expanded(child: Text('State')),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Icon(
              Icons.backup_outlined,
              size: 44,
              color: AfaqDesign.muted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Backup records are not connected',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Snapshot dates, sizes, encryption and madrasa coverage have not been verified in this workspace.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AfaqDesign.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                onPressed: onAudit,
                icon: const Icon(Icons.policy_outlined),
                label: const Text('Review audit logs'),
              ),
            ),
          ],
        ),
      );
      final workflow = panel(
        'Restore workflow',
        Column(
          children: [
            for (final step in [
              (
                '1',
                'Select & scope',
                'Identify the snapshot and define what needs recovery.',
              ),
              (
                '2',
                'Review & approve',
                'Record the reason, review access and approve an isolated test plan.',
              ),
              (
                '3',
                'Restore & verify',
                'Test recovery separately, validate results and retain evidence.',
              ),
            ])
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xffdfe5eb)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: const Color(0xfff8f0dc),
                      foregroundColor: AfaqDesign.gold,
                      child: Text(step.$1),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.$2,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            step.$3,
                            style: const TextStyle(
                              color: AfaqDesign.muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
      final verification = panel(
        'Restore verification',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'RECOVERY EVIDENCE',
              style: TextStyle(
                color: AfaqDesign.gold,
                letterSpacing: 1.5,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No verified restore result',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'A readiness checklist does not prove that a snapshot can be restored. Each check needs evidence from an isolated recovery test.',
              style: TextStyle(color: AfaqDesign.muted, height: 1.5),
            ),
            const SizedBox(height: 24),
            for (final check in [
              'Snapshot integrity',
              'Record counts',
              'Madrasa access separation',
              'Saved test results',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.radio_button_unchecked,
                      size: 22,
                      color: AfaqDesign.muted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            check,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Not verified',
                            style: TextStyle(
                              color: AfaqDesign.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 28),
            const ItRecordDetails(
              values: {
                'Test duration': 'Not recorded',
                'Test environment': 'Not connected',
              },
            ),
            const SizedBox(height: 20),
            const Tooltip(
              message: 'Restore-test evidence has not been connected',
              child: OutlinedButton(
                onPressed: null,
                child: Text('View test evidence'),
              ),
            ),
          ],
        ),
      );
      return SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ItPageHeading(
              title: 'Backups & Recovery',
              description:
                  'Check backup coverage and verify that recovery works.',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message:
                    'Record an isolated test request; no restore is executed',
                child: FilledButton(
                  onPressed: onRequest,
                  child: const Text('Request restore test'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final item in [
                  ('Latest backup', Icons.backup_outlined),
                  ('Latest restore test', Icons.shield_outlined),
                  ('Backup coverage', Icons.domain_outlined),
                  ('Recovery review', Icons.fact_check_outlined),
                ])
                  SizedBox(
                    width: (width - padding * 2 - (columns - 1) * 16) / columns,
                    child: DashboardMetric(
                      label: item.$1,
                      value: 'Not verified',
                      icon: item.$2,
                      accent: AfaqDesign.blue,
                      dense: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (width >= 1100)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [history, const SizedBox(height: 24), workflow],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: verification),
                ],
              )
            else ...[
              history,
              const SizedBox(height: 24),
              verification,
              const SizedBox(height: 24),
              workflow,
            ],
            const SizedBox(height: 24),
            if (requests != null) ...[requests!, const SizedBox(height: 24)],
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xfff8f0dc),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'A successful backup does not prove that recovery works. This page does not run restores or change production data. Production recovery requires explicit approval and a plan for records created after the snapshot.',
              ),
            ),
          ],
        ),
      );
    },
  );
}
