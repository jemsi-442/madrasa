import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'foundation_ui.dart' show DashboardMetric;
import 'it_workspace_visuals.dart';

class PlatformIncidentsPage extends StatelessWidget {
  const PlatformIncidentsPage({
    super.key,
    required this.onAudit,
    required this.onHealth,
  });
  final VoidCallback onAudit;
  final VoidCallback onHealth;

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
    builder: (context, size) {
      final padding = size.maxWidth < 600 ? 16.0 : 28.0;
      final columns = size.maxWidth >= 1100
          ? 4
          : size.maxWidth >= 650
          ? 2
          : 1;
      final register = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          panel(
            'Incident register',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 44,
                  color: AfaqDesign.muted,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Incident records are not connected',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Recording, ownership and resolution history need a persistent incident service. No incident counts are available yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AfaqDesign.muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onAudit,
                      icon: const Icon(Icons.policy_outlined),
                      label: const Text('Review audit logs'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onHealth,
                      icon: const Icon(Icons.monitor_heart_outlined),
                      label: const Text('Check service health'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          panel(
            'Response responsibilities',
            const Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.security, color: AfaqDesign.blue),
                  title: Text('IT & Security'),
                  subtitle: Text(
                    'Investigate technical signals and coordinate response within authorised access.',
                  ),
                ),
                Divider(height: 28),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.business_center_outlined,
                    color: AfaqDesign.gold,
                  ),
                  title: Text('Institution leadership'),
                  subtitle: Text(
                    'Coordinate major disruption and external communication under institutional policy.',
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      final response = panel(
        'Response guide',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'No incident selected',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'The steps below are guidance, not evidence that an incident has been investigated or resolved.',
              style: TextStyle(color: AfaqDesign.muted, height: 1.5),
            ),
            const SizedBox(height: 24),
            for (final step in [
              (
                '1',
                'Triage',
                'Review the event sequence and affected account. An alert alone does not establish a breach.',
              ),
              (
                '2',
                'Contain',
                'Use authorised controls only. Do not change classroom or payment records.',
              ),
              (
                '3',
                'Confirm & recover',
                'Verify the situation with the responsible owner and preserve evidence.',
              ),
              (
                '4',
                'Close & learn',
                'Record the outcome and follow-up actions when incident recording is connected.',
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
      return SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ItPageHeading(
              title: 'Security Incidents',
              description:
                  'Investigate signals, coordinate response and preserve the outcome.',
            ),
            const Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: 'Incident recording is not connected yet',
                child: FilledButton(
                  onPressed: null,
                  child: Text('Record incident'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final metric in [
                  ('Open incidents', Icons.warning_amber_outlined),
                  ('High priority', Icons.shield_outlined),
                  ('Resolved this month', Icons.check_circle_outline),
                  ('Response owners', Icons.people_outline),
                ])
                  SizedBox(
                    width:
                        (size.maxWidth - padding * 2 - (columns - 1) * 16) /
                        columns,
                    child: DashboardMetric(
                      label: metric.$1,
                      value: 'Not connected',
                      icon: metric.$2,
                      accent: AfaqDesign.gold,
                      dense: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (size.maxWidth >= 1100)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: register),
                  const SizedBox(width: 24),
                  Expanded(child: response),
                ],
              )
            else ...[
              register,
              const SizedBox(height: 24),
              response,
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xffeaf1fc),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'An alert is a signal to investigate, not proof of a breach. Child-related concerns follow the institution\'s safeguarding process.',
              ),
            ),
          ],
        ),
      );
    },
  );
}
