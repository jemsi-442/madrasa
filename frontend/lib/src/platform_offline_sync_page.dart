import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'foundation_ui.dart' show DashboardMetric;
import 'it_workspace_visuals.dart';

class PlatformOfflineSyncPage extends StatelessWidget {
  const PlatformOfflineSyncPage({
    super.key,
    required this.onAudit,
    required this.onIncidents,
    this.receivedUpdates,
  });
  final VoidCallback onAudit;
  final VoidCallback onIncidents;
  final Widget? receivedUpdates;

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
        'Last reported sync status',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (width >= 1100)
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xfff5f7f8),
                child: const Row(
                  children: [
                    Expanded(child: Text('Device')),
                    Expanded(child: Text('Madrasa')),
                    Expanded(child: Text('Last contact')),
                    Expanded(child: Text('Known pending')),
                    Expanded(child: Text('State')),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            const Icon(Icons.sync_outlined, size: 44, color: AfaqDesign.muted),
            const SizedBox(height: 16),
            const Text(
              'Device sync reporting is not connected',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Device identities, last-contact times and pending update counts are not available to this workspace yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AfaqDesign.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            Align(
              child: OutlinedButton.icon(
                onPressed: onAudit,
                icon: const Icon(Icons.policy_outlined),
                label: const Text('Review audit logs'),
              ),
            ),
          ],
        ),
      );
      final review = ItSectionPanel(
        title: 'Conflict review',
        accent: AfaqDesign.gold,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                Icons.sync_problem_outlined,
                size: 32,
                color: AfaqDesign.gold,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Conflict records are not connected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The review queue is unavailable. This does not confirm that there are no conflicts.',
              style: TextStyle(color: AfaqDesign.muted, height: 1.5),
            ),
            const Divider(height: 32),
            const Text(
              'IT checks technical metadata. Teachers or madrasa administrators review learning records; no records are changed here.',
              style: TextStyle(color: AfaqDesign.muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onIncidents,
              child: const Text('Open security incidents'),
            ),
          ],
        ),
      );
      final safeguards = [
        (
          'Duplicate protection',
          Icons.copy_outlined,
          'Learning events use client event IDs. This is not a device-sync success indicator.',
        ),
        (
          'Madrasa isolation',
          Icons.lock_outline,
          'Learning writes must pass server-side school, class and teacher permission checks.',
        ),
        (
          'Record review',
          Icons.history_outlined,
          'This workspace does not overwrite learning records or resolve educator decisions.',
        ),
      ];
      return SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ItPageHeading(
              title: 'Offline Sync',
              description:
                  'Inspect received updates and protect records during reconnection.',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final item in [
                  ('Reporting devices', Icons.devices_outlined),
                  ('Up to date', Icons.check_circle_outline),
                  ('Awaiting reconnection', Icons.schedule_outlined),
                  ('Conflicts held', Icons.sync_problem_outlined),
                ])
                  SizedBox(
                    width: (width - padding * 2 - (columns - 1) * 16) / columns,
                    child: DashboardMetric(
                      label: item.$1,
                      value: 'Not available',
                      icon: item.$2,
                      accent: AfaqDesign.blue,
                      dense: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xffeaf1ff),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AfaqDesign.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Device status reflects its last contact. Work created offline is not visible to the server until the device reconnects.',
                      style: TextStyle(color: AfaqDesign.blue, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (width >= 1100)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: receivedUpdates ?? history),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: review),
                ],
              )
            else ...[
              receivedUpdates ?? history,
              const SizedBox(height: 24),
              review,
            ],
            const SizedBox(height: 24),
            panel(
              'Synchronization safeguards',
              LayoutBuilder(
                builder: (context, inner) {
                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      for (final item in safeguards)
                        SizedBox(
                          width: width >= 1100
                              ? (inner.maxWidth - 48) / 3
                              : inner.maxWidth,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(item.$2, color: AfaqDesign.blue),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.$1,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      item.$3,
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
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
