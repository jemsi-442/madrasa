import 'dart:async';
import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'foundation_ui.dart' show DashboardMetric;
import 'it_workspace_visuals.dart';
import 'status_badge.dart';
import 'workspace_chrome.dart';

class PlatformSystemHealthPage extends StatefulWidget {
  const PlatformSystemHealthPage({
    super.key,
    required this.snapshot,
    required this.busy,
    required this.error,
    required this.onRefresh,
    this.onInvestigate,
    this.now,
  });
  final Map<String, dynamic>? snapshot;
  final bool busy;
  final String? error;
  final VoidCallback onRefresh;
  final ValueChanged<String>? onInvestigate;
  final DateTime Function()? now;
  @override
  State<PlatformSystemHealthPage> createState() =>
      _PlatformSystemHealthPageState();
}

class _PlatformSystemHealthPageState extends State<PlatformSystemHealthPage> {
  Timer? timer;
  bool isFresh(DateTime? checked) {
    if (checked == null) return false;
    final age = (widget.now ?? DateTime.now)().toUtc().difference(
      checked.toUtc(),
    );
    return !age.isNegative && age < const Duration(seconds: 60);
  }

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
  Widget build(BuildContext context) {
    final checks = (widget.snapshot?['checks'] as List? ?? [])
        .whereType<Map>()
        .where((row) => ['database', 'redis'].contains(row['name']))
        .where((row) => ['available', 'unavailable'].contains(row['status']))
        .toList();
    final checked = DateTime.tryParse('${widget.snapshot?['checkedAt']}');
    final fresh = isFresh(checked);
    final failed = checks.where((row) => row['status'] != 'available').toList();
    final metrics = [
      (
        'Healthy checked services',
        fresh && checks.isNotEmpty
            ? '${checks.length - failed.length} / ${checks.length}'
            : 'Not current',
        Icons.dns_outlined,
        const Color(0xff278457),
      ),
      (
        'API response time',
        'Not measured',
        Icons.schedule,
        const Color(0xff346bb0),
      ),
      ('Failed requests', 'Not measured', Icons.bar_chart, AfaqDesign.gold),
      (
        'Storage capacity',
        'Not measured',
        Icons.storage_outlined,
        const Color(0xff7663af),
      ),
    ];
    final services = <(String, String, Map?)>[
      ('Web portal', 'Frontend', null),
      ('Application API', 'API service', null),
      (
        'Database',
        'Records',
        checks.where((c) => c['name'] == 'database').firstOrNull,
      ),
      (
        'Redis',
        'Login protection',
        checks.where((c) => c['name'] == 'redis').firstOrNull,
      ),
      ('Background jobs', 'Queue', null),
      ('File storage', 'Documents', null),
      ('Notifications', 'SMS / email', null),
    ];
    String status(Map? check) => check == null
        ? 'Not measured'
        : !fresh
        ? 'Not current'
        : check['status'] == 'available'
        ? 'Available'
        : 'Unavailable';
    final table = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll(Color(0xfff5f7f8)),
        columnSpacing: 24,
        dataRowMinHeight: 64,
        dataRowMaxHeight: 76,
        columns: [
          for (final text in [
            'Service',
            'Component',
            'Health',
            'Probe time',
            '',
          ])
            DataColumn(label: Text(text)),
        ],
        rows: [
          for (final service in services)
            DataRow(
              cells: [
                DataCell(Text(service.$1)),
                DataCell(Text(service.$2)),
                DataCell(
                  AfaqStatusBadge(
                    label: status(service.$3),
                    color: service.$3 == null || !fresh
                        ? AfaqDesign.muted
                        : service.$3!['status'] == 'available'
                        ? const Color(0xff278457)
                        : AfaqDesign.gold,
                  ),
                ),
                DataCell(
                  Text(
                    service.$3?['latencyMs'] is num
                        ? '${service.$3!['latencyMs']} ms'
                        : 'Not measured',
                  ),
                ),
                DataCell(
                  TextButton(
                    onPressed: widget.busy
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(service.$1),
                              content: SizedBox(
                                width: 520,
                                child: SingleChildScrollView(
                                  child: ItRecordDetails(
                                    values: {
                                      'Component': service.$2,
                                      'Status at opening': status(service.$3),
                                      'Last checked (UTC)': service.$3 == null
                                          ? null
                                          : widget.snapshot?['checkedAt'],
                                      'Measurement': service.$3 == null
                                          ? 'No monitoring integration for this service.'
                                          : 'Single connectivity probe, not API response-time percentile or an uptime guarantee.',
                                    },
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
                          ),
                    child: const Text('Details'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panel(
          'Shared services',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 600) return table;
                  return Column(
                    children: [
                      for (final service in services)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xfff5f7f8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                service.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                service.$2,
                                style: const TextStyle(color: AfaqDesign.muted),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: AfaqStatusBadge(
                                  label: status(service.$3),
                                  color: service.$3 == null || !fresh
                                      ? AfaqDesign.muted
                                      : service.$3!['status'] == 'available'
                                      ? const Color(0xff278457)
                                      : AfaqDesign.gold,
                                ),
                              ),
                              if (service.$3 != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Last checked: ${itTimestamp(widget.snapshot?['checkedAt'])}',
                                  style: const TextStyle(
                                    color: AfaqDesign.muted,
                                  ),
                                ),
                                if (service.$3?['latencyMs'] is num)
                                  Text(
                                    'Probe time: ${service.$3!['latencyMs']} ms',
                                  ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Last checked: ${itTimestamp(widget.snapshot?['checkedAt'])}',
                style: const TextStyle(color: AfaqDesign.muted),
              ),
              const SizedBox(height: 8),
              const Text(
                'Only database and Redis connectivity are measured. Probe times are not API response times.',
                style: TextStyle(color: AfaqDesign.muted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        panel(
          'API response time',
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.show_chart, size: 40, color: AfaqDesign.muted),
                SizedBox(height: 14),
                Text(
                  'Response-time history is not connected.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'A chart will require recorded API measurements.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AfaqDesign.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panel(
          'Service attention',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!fresh)
                const Text(
                  'Current availability is unknown. Refresh status to check again.',
                  style: TextStyle(fontWeight: FontWeight.w600, height: 1.5),
                ),
              if (fresh && checks.isEmpty)
                const Text(
                  'No connectivity checks were returned. Availability has not been verified.',
                  style: TextStyle(fontWeight: FontWeight.w600, height: 1.5),
                ),
              if (fresh && checks.isNotEmpty && failed.isEmpty)
                const Text(
                  'No failed connectivity checks.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              for (final row in failed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '${row['name'] == 'database' ? 'Database' : 'Redis'}: unavailable ${fresh ? 'at the latest check' : 'in the previous snapshot'}.',
                    style: const TextStyle(color: AfaqDesign.gold, height: 1.5),
                  ),
                ),
              const Divider(height: 32),
              const Text(
                'A failed probe is not a confirmed security incident. Review the evidence before recording an investigation.',
                style: TextStyle(color: AfaqDesign.muted, height: 1.5),
              ),
              if (widget.onInvestigate != null && failed.isNotEmpty) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: widget.busy || widget.error != null || !fresh
                      ? null
                      : () {
                          // The snapshot may expire between rendering and clicking.
                          if (!isFresh(checked)) {
                            setState(() {});
                            return;
                          }
                          widget.onInvestigate!(
                            'Connectivity checks for investigation. This does not establish a security breach.\n'
                            'Checked (UTC): ${checked!.toUtc().toIso8601String()}\n'
                            'Unavailable services: ${failed.map((row) => row['name'] == 'database' ? 'Database' : 'Redis').join(', ')}\n\n'
                            'Investigation reason:',
                          );
                        },
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Investigate failed checks'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        panel(
          'Maintenance',
          const Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.dns_outlined, color: AfaqDesign.blue),
                title: Text('Staging environment'),
                subtitle: Text('Readiness has not been verified.'),
              ),
              Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.schedule, color: AfaqDesign.gold),
                title: Text('Next maintenance window'),
                subtitle: Text('Schedule is not connected.'),
              ),
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, size) {
        final padding = size.maxWidth < 600 ? 16.0 : 28.0;
        final columns = size.maxWidth >= 1100
            ? 4
            : size.maxWidth >= 600
            ? 2
            : 1;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ItPageHeading(
                title: 'System Health',
                description:
                    'Monitor shared services and operational interruptions.',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: WorkspaceRefreshButton(
                  onRefresh: widget.onRefresh,
                  loading: widget.busy,
                  label: 'Refresh status',
                ),
              ),
              if (widget.busy) const LinearProgressIndicator(),
              if (widget.error != null)
                Text(widget.error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width:
                          (size.maxWidth - padding * 2 - (columns - 1) * 16) /
                          columns,
                      child: DashboardMetric(
                        label: metric.$1,
                        value: metric.$2,
                        icon: metric.$3,
                        accent: metric.$4,
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
                    Expanded(flex: 7, child: left),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: right),
                  ],
                )
              else ...[
                left,
                const SizedBox(height: 24),
                right,
              ],
            ],
          ),
        );
      },
    );
  }
}
