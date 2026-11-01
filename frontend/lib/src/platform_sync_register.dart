import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'it_workspace_visuals.dart';
import 'platform_offline_sync_page.dart';

class PlatformSyncRegister extends StatefulWidget {
  const PlatformSyncRegister({
    super.key,
    required this.request,
    required this.onAudit,
    required this.onIncidents,
  });
  final Future<dynamic> Function(String) request;
  final VoidCallback onAudit, onIncidents;
  @override
  State<PlatformSyncRegister> createState() => _PlatformSyncRegisterState();
}

class _PlatformSyncRegisterState extends State<PlatformSyncRegister> {
  List<dynamic> items = [];
  int page = 1, total = 0;
  bool busy = false;
  String? error, capturedAt;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        load();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
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
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Updates could not be checked. Previously loaded records may be out of date.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void changePage(int next) {
    page = next;
    items = [];
    load();
  }

  @override
  Widget build(BuildContext context) => PlatformOfflineSyncPage(
    onAudit: widget.onAudit,
    onIncidents: widget.onIncidents,
    receivedUpdates: Container(
      decoration: AfaqDesign.panelDecoration(),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Received learning updates',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Accepted teaching events only. Online and offline origins are not distinguished; these are not device-sync counts.',
            style: TextStyle(color: AfaqDesign.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (capturedAt != null)
            Text(
              'Last checked (UTC): ${itTimestamp(capturedAt)}',
              style: const TextStyle(color: AfaqDesign.muted),
            ),
          if (!busy && error == null && items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No received teaching events on this page.'),
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
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$total received events / Page $page of ${max(1, (total / 20).ceil())}',
              ),
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
          TextButton(
            onPressed: widget.onAudit,
            child: const Text('Review audit logs'),
          ),
        ],
      ),
    ),
  );
}
