import 'dart:math';
import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'it_workspace_visuals.dart';
import 'platform_offline_sync_page.dart';
import 'automatic_data_updates.dart';
import 'api_client.dart';
import 'live_data.dart';

class PlatformSyncRegister extends StatefulWidget {
  const PlatformSyncRegister({
    super.key,
    required this.request,
    required this.onAudit,
    required this.onIncidents,
    this.onInvestigate,
  });
  final Future<dynamic> Function(String) request;
  final VoidCallback onAudit, onIncidents;
  final ValueChanged<String>? onInvestigate;
  @override
  State<PlatformSyncRegister> createState() => _PlatformSyncRegisterState();
}

class _PlatformSyncRegisterState extends State<PlatformSyncRegister> {
  List<dynamic> items = [];
  int page = 1, total = 0;
  bool busy = false;
  String? error, capturedAt;
  bool accessDenied = false;
  late final AutomaticDataUpdates updates;
  @override
  void initState() {
    super.initState();
    updates = AutomaticDataUpdates(
      canUpdate: () =>
          mounted &&
          !busy &&
          !accessDenied &&
          !dataWriteInProgress &&
          ModalRoute.of(context)?.isCurrent != false,
      update: load,
    );
    load();
  }

  @override
  void dispose() {
    updates.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
    });
    try {
      final data = await widget.request('/sync/received?page=$page');
      if (mounted) {
        setState(() {
          items = data['items'] as List;
          total = data['total'] as int;
          capturedAt = data['capturedAt'] as String;
          error = null;
          accessDenied = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiException && [401, 403, 409].contains(e.statusCode)) {
            accessDenied = true;
            items = [];
            total = 0;
            capturedAt = null;
            error =
                'Access could not be verified. Sign in again or check your permissions.';
          } else {
            error =
                'Updates could not be checked. Previously loaded records may be out of date.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void changePage(int next) {
    page = next;
    items = [];
    capturedAt = null;
    load();
  }

  @override
  Widget build(BuildContext context) => PlatformOfflineSyncPage(
    onAudit: widget.onAudit,
    onIncidents: widget.onIncidents,
    receivedUpdates: ItSectionPanel(
      title: 'Received learning updates',
      accent: AfaqDesign.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Accepted teaching events, not device-sync counts.',
            style: TextStyle(color: AfaqDesign.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (capturedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.schedule, size: 20, color: AfaqDesign.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last checked (UTC)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AfaqDesign.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          itTimestamp(capturedAt),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (!busy && error == null && items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 36, color: AfaqDesign.blue),
                  SizedBox(height: 12),
                  Text(
                    'No received teaching events on this page.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, height: 1.5),
                  ),
                ],
              ),
            ),
          for (final item in items) ...[
            const Divider(height: 28),
            ItRecordDetails(
              values: {
                'Receipt': '${item['receiptId']}',
                'Madrasa reference': '${item['madrasaId']}',
                'Received (UTC)': itTimestamp(item['receivedAt']),
                'Outcome': 'Accepted',
              },
            ),
            if (widget.onInvestigate != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Investigate receipt'),
                  onPressed: busy || accessDenied
                      ? null
                      : () => widget.onInvestigate!(
                          'Received teaching event for investigation. This does not establish a sync failure.\n'
                          'Receipt: ${item['receiptId']}\nMadrasa reference: ${item['madrasaId']}\n'
                          'Received (UTC): ${itTimestamp(item['receivedAt'])}\n\n'
                          'Investigation reason: ',
                        ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            '$total received events',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Page $page of ${max(1, (total / 20).ceil())}'),
              TextButton(
                onPressed: busy || page <= 1
                    ? null
                    : () => changePage(page - 1),
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: busy || page * 20 >= total
                    ? null
                    : () => changePage(page + 1),
                child: const Text('Next'),
              ),
              TextButton(
                onPressed: busy ? null : load,
                child: const Text('Check updates'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Online and offline origins are not distinguished.',
            style: TextStyle(
              color: AfaqDesign.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onAudit,
              icon: const Icon(Icons.policy_outlined),
              label: const Text('Review audit logs'),
            ),
          ),
        ],
      ),
    ),
  );
}
