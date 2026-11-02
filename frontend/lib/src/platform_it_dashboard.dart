import 'dart:async';
import 'package:flutter/material.dart';
import 'it_workspace_visuals.dart';
import 'design_tokens.dart';
import 'workspace_chrome.dart';
import 'status_badge.dart';

class PlatformItDashboard extends StatefulWidget {
  const PlatformItDashboard({
    super.key,
    required this.busy,
    required this.error,
    required this.onRefresh,
    required this.onHealth,
    required this.onIncidents,
    this.onIncident,
    required this.onAccounts,
    required this.onAudit,
    required this.onSessions,
    this.now,
    this.snapshot,
  });
  final bool busy;
  final ValueChanged<String>? onIncident;
  final String? error;
  final VoidCallback onRefresh,
      onHealth,
      onIncidents,
      onAccounts,
      onAudit,
      onSessions;
  final DateTime Function()? now;

  final Map<String, dynamic>? snapshot;
  @override
  State<PlatformItDashboard> createState() => _PlatformItDashboardState();
}

class _PlatformItDashboardState extends State<PlatformItDashboard> {
  Timer? timer;
  bool get busy => widget.busy;
  String? get error => widget.error;
  VoidCallback get onHealth => widget.onHealth;
  VoidCallback get onAccounts => widget.onAccounts;
  VoidCallback get onAudit => widget.onAudit;
  VoidCallback get onSessions => widget.onSessions;
  VoidCallback get onRefresh => widget.onRefresh;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget panel(String title, Widget child) =>
      ItSectionPanel(title: title, child: child);

  Widget task(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback action,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xfff7f0dc),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AfaqDesign.gold, size: 26),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AfaqDesign.ink,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          subtitle,
          style: const TextStyle(color: AfaqDesign.muted, height: 1.5),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 22),
      onTap: busy ? null : action,
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide = bounds.maxWidth >= 1050;
      final checks = (widget.snapshot?['checks'] as List? ?? [])
          .whereType<Map>()
          .where((row) => ['database', 'redis'].contains(row['name']))
          .where((row) => ['available', 'unavailable'].contains(row['status']))
          .toList();
      final checked = DateTime.tryParse('${widget.snapshot?['checkedAt']}');
      final age = checked == null
          ? null
          : (widget.now ?? DateTime.now)().toUtc().difference(checked.toUtc());
      final fresh =
          error == null &&
          age != null &&
          !age.isNegative &&
          age < const Duration(seconds: 60);
      final available = checks.where((c) => c['status'] == 'available').length;
      final failed = checks.where((c) => c['status'] != 'available').toList();
      final incidents = widget.snapshot?['incidents'];
      final incidentChecked = DateTime.tryParse(
        '${incidents is Map ? incidents['checkedAt'] : null}',
      );
      final incidentAge = incidentChecked == null
          ? null
          : (widget.now ?? DateTime.now)().toUtc().difference(
              incidentChecked.toUtc(),
            );
      final incidentFresh =
          incidentAge != null &&
          !incidentAge.isNegative &&
          incidentAge < const Duration(seconds: 60);
      final openCount = incidents is Map ? incidents['open'] : null;
      final highCount = incidents is Map ? incidents['high'] : null;
      final validCounts =
          openCount is int &&
          openCount >= 0 &&
          highCount is int &&
          highCount >= 0 &&
          highCount <= openCount;
      final incidentsReady = error == null && incidentFresh && validCounts;
      final needsAction =
          (fresh && failed.isNotEmpty) || (incidentsReady && openCount > 0);
      final statusKnown = fresh && checks.length == 2 && incidentsReady;
      final operations = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ItSectionPanel(
            accent: statusKnown && !needsAction
                ? const Color(0xff278457)
                : AfaqDesign.gold,
            title: 'Needs attention',
            child: Column(
              children: [
                if (!fresh || checks.isEmpty)
                  task(
                    'Check current service status',
                    'The latest service state is not verified.',
                    Icons.schedule,
                    onHealth,
                  ),
                for (final check in failed)
                  task(
                    'Review ${check['name'] == 'database' ? 'database' : 'Redis'} connectivity',
                    fresh
                        ? 'Unavailable at the latest check.'
                        : 'Unavailable in the previous snapshot.',
                    Icons.warning_amber_outlined,
                    onHealth,
                  ),
                if (fresh && checks.isNotEmpty && failed.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No failed connectivity checks. This is not a security incident assessment.',
                      style: TextStyle(color: AfaqDesign.muted, height: 1.5),
                    ),
                  ),
                const Divider(),
                if (incidentsReady && widget.onIncident != null)
                  for (final incident
                      in (incidents['recentOpen'] as List? ?? [])
                          .whereType<Map>())
                    if (incident['id'] is String && incident['title'] is String)
                      task(
                        incident['title'] as String,
                        '${incident['priority']} priority / Open investigation',
                        Icons.warning_amber_outlined,
                        () => widget.onIncident!(incident['id'] as String),
                      ),
                task(
                  'Security incidents',
                  incidentsReady
                      ? '$openCount open / $highCount high priority. Review the incident register.'
                      : 'Current incident counts are unavailable. Open the register to investigate.',
                  incidentsReady && openCount == 0
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  widget.onIncidents,
                ),
                task(
                  'Audit trail',
                  'Inspect recorded platform activity.',
                  Icons.policy_outlined,
                  onAudit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          panel(
            'Access boundaries',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final text in [
                  'Operational metadata and technical checks',
                  'No direct editing of student assessments',
                  'No approval or alteration of payments',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: AfaqDesign.ink,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(height: 1.5),
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
      final services = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          panel(
            'Platform services',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: busy ? null : onHealth,
                    child: const Text('View health →'),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, size) {
                    final table = size.maxWidth >= 620;
                    Widget label(String text) => Text(
                      text,
                      style: const TextStyle(
                        color: AfaqDesign.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (table)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            color: const Color(0xfff5f7f8),
                            child: Row(
                              children: [
                                Expanded(flex: 4, child: label('Service')),
                                Expanded(flex: 3, child: label('Status')),
                                Expanded(flex: 4, child: label('Last checked')),
                              ],
                            ),
                          ),
                        if (checks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text('No service checks available.'),
                          ),
                        for (final check in checks)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                            child: Builder(
                              builder: (context) {
                                final name = Text(
                                  check['name'] == 'database'
                                      ? 'Database'
                                      : 'Redis / login protection',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AfaqDesign.ink,
                                  ),
                                );
                                final badge = AfaqStatusBadge(
                                  label: !fresh
                                      ? 'Not current'
                                      : check['status'] == 'available'
                                      ? 'Available'
                                      : 'Unavailable',
                                  color: !fresh
                                      ? AfaqDesign.muted
                                      : check['status'] == 'available'
                                      ? const Color(0xff278457)
                                      : const Color(0xffa86412),
                                );
                                final time = Text(
                                  itTimestamp(widget.snapshot?['checkedAt']),
                                  style: const TextStyle(
                                    color: AfaqDesign.muted,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                );
                                if (table) {
                                  return Row(
                                    children: [
                                      Expanded(flex: 4, child: name),
                                      Expanded(
                                        flex: 3,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: badge,
                                        ),
                                      ),
                                      Expanded(flex: 4, child: time),
                                    ],
                                  );
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    name,
                                    const SizedBox(height: 10),
                                    badge,
                                    const SizedBox(height: 12),
                                    label('Last checked'),
                                    const SizedBox(height: 4),
                                    time,
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Web portal, notifications and external integrations are not checked by this endpoint.',
                  style: TextStyle(color: AfaqDesign.muted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ItSectionPanel(
            accent: const Color(0xff346bb0),
            title: 'Investigate access',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                task(
                  'Company accounts',
                  'Identify the account, role and permitted scope.',
                  Icons.badge_outlined,
                  onAccounts,
                ),
                const Divider(),
                task(
                  'Sessions',
                  'Search platform and madrasa sessions by account, role or IP.',
                  Icons.devices_outlined,
                  onSessions,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use the audit trail to trace activity, then record an incident when investigation is needed. An IP address alone is not proof of misuse.',
                  style: TextStyle(color: AfaqDesign.muted, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      );
      final padding = bounds.maxWidth < 600 ? 16.0 : 28.0;
      final columns = wide
          ? 4
          : bounds.maxWidth >= 600
          ? 2
          : 1;
      final metrics = [
        (
          'Failed service checks',
          checks.isEmpty || !fresh ? 'Not current' : '${failed.length}',
          Icons.report_problem_outlined,
          const Color(0xff346bb0),
        ),
        (
          'Service health',
          checks.isEmpty || !fresh
              ? 'Not current'
              : '$available / ${checks.length}',
          Icons.dns_outlined,
          const Color(0xff278457),
        ),
        (
          'Open incidents',
          incidentsReady ? '$openCount' : 'Not current',
          Icons.warning_amber_outlined,
          AfaqDesign.gold,
        ),
        (
          'High-priority incidents',
          incidentsReady ? '$highCount' : 'Not current',
          Icons.shield_outlined,
          const Color(0xff7663af),
        ),
      ];
      return SingleChildScrollView(
        padding: EdgeInsets.all(bounds.maxWidth < 600 ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'AFAQ / IT WORKSPACE',
              style: TextStyle(
                color: AfaqDesign.gold,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                const Text(
                  'IT & Security Overview',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AfaqDesign.ink,
                  ),
                ),
                WorkspaceRefreshButton(
                  onRefresh: onRefresh,
                  loading: busy,
                  tooltip: 'Refresh overview',
                  label: 'Check services',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Check service availability, prioritise incidents and investigate account access.',
              style: TextStyle(color: AfaqDesign.muted, height: 1.5),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            ItSectionPanel(
              accent: needsAction
                  ? AfaqDesign.gold
                  : statusKnown
                  ? const Color(0xff278457)
                  : const Color(0xff346bb0),
              title: needsAction
                  ? 'Action required'
                  : statusKnown
                  ? 'No open issues in current checks'
                  : 'Status needs verification',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    needsAction
                        ? 'Start with failed services and open incidents below.'
                        : statusKnown
                        ? 'Database and Redis checks passed; no open incidents were reported.'
                        : 'Some checks are missing, stale or unavailable. Do not treat this as an all-clear.',
                    style: const TextStyle(color: AfaqDesign.ink, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Service snapshot: ${itTimestamp(widget.snapshot?['checkedAt'])}',
                    style: const TextStyle(
                      color: AfaqDesign.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width:
                        (bounds.maxWidth - padding * 2 - (columns - 1) * 16) /
                        columns,
                    child: ItMetricCard(
                      label: metric.$1,
                      value: metric.$2,
                      icon: metric.$3,
                      accent: metric.$4,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: services),
                  const SizedBox(width: 24),
                  Expanded(child: operations),
                ],
              )
            else ...[
              operations,
              const SizedBox(height: 24),
              services,
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xffeaf1fc),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Status is based on the latest available checks, not live monitoring or a guarantee that no threats exist.',
                style: TextStyle(color: AfaqDesign.ink, height: 1.5),
              ),
            ),
          ],
        ),
      );
    },
  );
}
