import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'it_workspace_visuals.dart';
import 'automatic_data_updates.dart';
import 'api_client.dart';
import 'live_data.dart';

class PlatformIntegrationsPage extends StatefulWidget {
  const PlatformIntegrationsPage({
    super.key,
    required this.onAudit,
    required this.onHealth,
    this.request,
  });
  final VoidCallback onAudit, onHealth;
  final Future<dynamic> Function()? request;
  @override
  State<PlatformIntegrationsPage> createState() =>
      _PlatformIntegrationsPageState();
}

class _PlatformIntegrationsPageState extends State<PlatformIntegrationsPage> {
  int tab = 0;
  String service = 'Authentication';
  Map<String, dynamic>? snapshot;
  bool loading = false;
  bool accessDenied = false;
  late final AutomaticDataUpdates updates;
  String? error;
  @override
  void initState() {
    super.initState();
    updates = AutomaticDataUpdates(
      canUpdate: () =>
          mounted &&
          widget.request != null &&
          !loading &&
          !accessDenied &&
          !dataWriteInProgress &&
          ModalRoute.of(context)?.isCurrent != false,
      update: load,
    );
    if (widget.request != null) load();
  }

  @override
  void dispose() {
    updates.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
      snapshot = null;
    });
    try {
      final data = await widget.request!();
      if (mounted) {
        setState(() {
          accessDenied = false;
          snapshot = Map<String, dynamic>.from(data as Map);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          snapshot = null;
          accessDenied =
              e is ApiException && [401, 403, 409].contains(e.statusCode);
          error = accessDenied
              ? 'Access could not be verified. Sign in again or check your permissions.'
              : 'Configuration status could not be loaded. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String status(String name) =>
      snapshot?['services']?[name]?.toString() ?? 'Status not verified';
  static const services = [
    'Authentication',
    'Email & SMS gateway',
    'Payment connection',
    'Backup storage',
    'Quran content',
  ];
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
  Widget note(String text) =>
      Text(text, style: const TextStyle(color: AfaqDesign.muted, height: 1.5));
  Widget configurationChecks() {
    final groups = snapshot?['configurationChecks'];
    final checks = groups is Map ? groups[service] : null;
    if (checks is! List || checks.isEmpty) {
      return note(
        loading
            ? 'Checking configuration...'
            : 'Configuration checklist unavailable.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Configuration checklist',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final check in checks.whereType<Map>())
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  check['ready'] == true
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  color: check['ready'] == true
                      ? AfaqDesign.blue
                      : AfaqDesign.gold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('${check['label']}')),
                const SizedBox(width: 10),
                Text(
                  check['ready'] == true ? 'Ready' : 'Not ready',
                  style: const TextStyle(color: AfaqDesign.muted),
                ),
              ],
            ),
          ),
        note(
          'Configuration only. Provider connectivity and delivery have not been tested.',
        ),
      ],
    );
  }

  Widget credentials() => panel(
    'Credential handling',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(service),
          initialValue: service,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Selected service'),
          items: services
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (s) => setState(() => service = s!),
        ),
        const SizedBox(height: 24),
        ItRecordDetails(
          values: {
            'Service': service,
            'Configuration status': status(service),
            'Secret values': 'Never returned by this page',
          },
        ),
        const SizedBox(height: 20),
        configurationChecks(),
        const SizedBox(height: 20),
        const Tooltip(
          message: 'Credential rotation requests are not connected yet',
          child: OutlinedButton(
            onPressed: null,
            child: Text('Request credential rotation'),
          ),
        ),
        const SizedBox(height: 12),
        note(
          'Configure secrets through the approved server configuration process. Do not paste passwords or API keys into audit notes.',
        ),
      ],
    ),
  );
  Widget configuration() => panel(
    'Local configuration',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ItRecordDetails(
          values: {
            'Server time zone':
                snapshot?['timezone']?.toString() ?? 'Not verified',
            'Staff language policy': 'Not connected',
            'Session timeout policy': 'Not connected',
            'Retention policy': 'Not connected',
          },
        ),
        const SizedBox(height: 18),
        note(
          'These are platform policies, not device preferences. No settings are changed from this page.',
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1100;
      final connected = panel(
        'Connected services',
        Column(
          children: [
            for (var i = 0; i < services.length; i++) ...[
              if (i > 0) const Divider(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xffeaf1ff),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      [
                        Icons.shield_outlined,
                        Icons.mail_outline,
                        Icons.power_outlined,
                        Icons.backup_outlined,
                        Icons.menu_book_outlined,
                      ][i],
                      color: AfaqDesign.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          services[i],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        note(
                          [
                            'Staff sign-in and MFA',
                            'Notification providers and delivery',
                            'Payment provider configuration',
                            'Snapshot storage and recovery',
                            'Verified Quran content provider',
                          ][i],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          status(services[i]),
                          style: const TextStyle(
                            color: AfaqDesign.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          key: ValueKey('configuration-${services[i]}'),
                          onPressed: () => setState(() {
                            service = services[i];
                            tab = 1;
                          }),
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('View configuration'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: widget.onHealth,
              icon: const Icon(Icons.monitor_heart_outlined),
              label: const Text('Open system health'),
            ),
          ],
        ),
      );
      final safeguards = panel(
        'Platform safeguards',
        Column(
          children: [
            for (final item in [
              (
                'Privileged MFA policy',
                snapshot?['mfaPolicy']?.toString() ??
                    'Enrollment and enforcement status are not available here.',
              ),
              (
                'Madrasa-scoped access',
                'Permissions are checked by server endpoints, not toggled from this page.',
              ),
              (
                'Secret handling',
                'This page does not fetch or display passwords, tokens or private keys.',
              ),
              (
                'Production change control',
                'No production configuration changes or approvals are performed here.',
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          note(item.$2),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.lock_outline, color: AfaqDesign.muted),
                  ],
                ),
              ),
          ],
        ),
      );
      return SingleChildScrollView(
        padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ItPageHeading(
              title: 'Integrations & Security Settings',
              description:
                  'Review connections and platform safeguards without exposing secrets.',
            ),
            const SizedBox(height: 16),
            if (widget.request != null) ...[
              if (loading) const LinearProgressIndicator(),
              if (error != null) Text(error!),
              if (snapshot != null)
                note(
                  'Configuration snapshot (UTC): ${itTimestamp(snapshot!['checkedAt'])}. Provider connections have not been tested.',
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: loading ? null : load,
                  child: const Text('Check configuration'),
                ),
              ),
            ],
            const Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: 'Configuration change requests are not connected yet',
                child: FilledButton(
                  onPressed: null,
                  child: Text('Review change request'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    InkWell(
                      onTap: () => setState(() => tab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: tab == i
                                  ? AfaqDesign.gold
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          [
                            'Connections & safeguards',
                            'Credentials',
                            'Retention & privacy',
                            'Change history',
                          ][i],
                          style: TextStyle(
                            color: tab == i
                                ? AfaqDesign.gold
                                : AfaqDesign.muted,
                            fontWeight: tab == i
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 24),
            if (tab == 0 && wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        connected,
                        const SizedBox(height: 24),
                        credentials(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        safeguards,
                        const SizedBox(height: 24),
                        configuration(),
                      ],
                    ),
                  ),
                ],
              )
            else if (tab == 0) ...[
              connected,
              const SizedBox(height: 24),
              safeguards,
              const SizedBox(height: 24),
              credentials(),
              const SizedBox(height: 24),
              configuration(),
            ] else if (tab == 1)
              credentials()
            else if (tab == 2) ...[
              configuration(),
              const SizedBox(height: 24),
              panel(
                'Retention & privacy',
                note(
                  'Retention periods and deletion rules need an approved institutional policy. This page does not delete records, change retention or expose learner data.',
                ),
              ),
            ] else
              panel(
                'Change history',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    note(
                      'Review existing platform audit records. A dedicated configuration-change history is not connected yet.',
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: widget.onAudit,
                      icon: const Icon(Icons.policy_outlined),
                      label: const Text('Open audit logs'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xffeaf1ff),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'IT manages technical connections. Financial approvals, educational records and institutional policy decisions remain with their authorised owners.',
                style: TextStyle(color: AfaqDesign.blue, height: 1.5),
              ),
            ),
          ],
        ),
      );
    },
  );
}
