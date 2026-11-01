import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'foundation_ui.dart' show DashboardMetric;
import 'it_workspace_visuals.dart';

class PlatformUpdatesPage extends StatelessWidget {
  const PlatformUpdatesPage({
    super.key,
    required this.onAudit,
    required this.onIncidents,
  });
  final VoidCallback onAudit;
  final VoidCallback onIncidents;

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
      final findings = panel(
        'Findings & remediation',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (width >= 1100) ...[
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xfff5f7f8),
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: Text('Finding')),
                    Expanded(child: Text('Severity')),
                    Expanded(child: Text('Component')),
                    Expanded(child: Text('State')),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Icon(
              Icons.bug_report_outlined,
              size: 44,
              color: AfaqDesign.muted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan results are not connected',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'No scanner results have been loaded into this workspace. This does not mean there are no vulnerabilities.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AfaqDesign.muted, height: 1.5),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onAudit,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review audit logs'),
                ),
                OutlinedButton.icon(
                  onPressed: onIncidents,
                  icon: const Icon(Icons.warning_amber_outlined),
                  label: const Text('Open incidents'),
                ),
              ],
            ),
          ],
        ),
      );
      final release = panel(
        'Controlled deployment',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'RELEASE READINESS',
              style: TextStyle(
                color: AfaqDesign.gold,
                letterSpacing: 1.5,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No release candidate connected',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Checks below require evidence linked to a specific version and environment.',
              style: TextStyle(color: AfaqDesign.muted, height: 1.5),
            ),
            const SizedBox(height: 24),
            for (final label in [
              'Automated checks',
              'Madrasa isolation tests',
              'Offline sync regression tests',
              'Rollback plan',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.radio_button_unchecked,
                      color: AfaqDesign.muted,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Evidence not connected',
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
            const Divider(height: 32),
            const ItRecordDetails(
              values: {
                'Production approval': 'Not connected',
                'Planned window': 'Not scheduled',
              },
            ),
            const SizedBox(height: 20),
            const Tooltip(
              message: 'Release approval workflow is not connected',
              child: FilledButton(
                onPressed: null,
                child: Text('Request approval'),
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
              title: 'Vulnerabilities & Updates',
              description:
                  'Review findings, test fixes and track maintenance safely.',
            ),
            const Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: 'Scanner integration is not connected',
                child: OutlinedButton(
                  onPressed: null,
                  child: Text('Review scan results'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final item in [
                  ('Open findings', Icons.bug_report_outlined, AfaqDesign.gold),
                  ('Critical findings', Icons.shield_outlined, AfaqDesign.blue),
                  ('Last staging scan', Icons.schedule, AfaqDesign.blue),
                  ('Pending release', Icons.dns_outlined, AfaqDesign.gold),
                ])
                  SizedBox(
                    width: (width - padding * 2 - (columns - 1) * 16) / columns,
                    child: DashboardMetric(
                      label: item.$1,
                      value: 'Not connected',
                      icon: item.$2,
                      accent: item.$3,
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
                  Expanded(flex: 7, child: findings),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: release),
                ],
              )
            else ...[
              findings,
              const SizedBox(height: 24),
              release,
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xffeaf1fc),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Scan results cover only the checks performed. This page does not run scans, approve changes or deploy to production.',
              ),
            ),
          ],
        ),
      );
    },
  );
}
