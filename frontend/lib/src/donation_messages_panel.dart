import 'package:flutter/material.dart';
import 'api_client.dart';
import 'design_tokens.dart';

class DonationMessagesPanel extends StatefulWidget {
  const DonationMessagesPanel({
    super.key,
    required this.load,
    required this.onSessionExpired,
  });
  final Future<dynamic> Function(String) load;
  final VoidCallback onSessionExpired;
  @override
  State<DonationMessagesPanel> createState() => _MessagesState();
}

class _MessagesState extends State<DonationMessagesPanel> {
  Map? data;
  bool busy = false;
  bool failed = false;
  bool preview = false;
  bool loaded = false;
  static const demoItems = [
    {
      'reference': 'DEMO-RECEIPT-001',
      'status': 'ACCEPTED',
      'updatedAt': '2026-10-31T09:30:00Z',
    },
    {
      'reference': 'DEMO-RECEIPT-002',
      'status': 'PENDING',
      'updatedAt': '2026-10-31T09:35:00Z',
    },
    {
      'reference': 'DEMO-RECEIPT-003',
      'status': 'UNKNOWN',
      'reason': 'NETWORK_UNCERTAIN',
      'updatedAt': '2026-10-31T09:40:00Z',
    },
  ];
  List get items => preview ? demoItems : (data?['items'] as List? ?? []);
  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
      data = null;
    });
    try {
      final result = await widget.load('/funds/messages');
      if (mounted) {
        setState(() {
          data = result as Map;
          if (!loaded) preview = data!['enabled'] != true;
          loaded = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) widget.onSessionExpired();
      setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xffe1e7eb)),
    ),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xffedf3fb),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.sms_outlined, color: AfaqDesign.ink),
      ),
      title: const Text(
        'Messages & reminders',
        style: TextStyle(fontWeight: FontWeight.w700, color: AfaqDesign.ink),
      ),
      subtitle: const Text('Donation receipts via Meseji'),
      onExpansionChanged: (open) {
        if (open && data == null) refresh();
      },
      childrenPadding: const EdgeInsets.all(20),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy) const LinearProgressIndicator(),
        if (failed)
          _notice(
            Icons.cloud_off_outlined,
            'Status unavailable',
            'Message status could not be loaded. Please retry.',
            const Color(0xfffff2ef),
          ),
        if (data != null) ...[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(
                  preview ? Icons.visibility_outlined : Icons.sensors,
                  size: 18,
                ),
                label: Text(preview ? 'Demo preview' : 'Live status'),
                side: BorderSide.none,
                backgroundColor: const Color(0xffedf3fb),
              ),
              TextButton(
                onPressed: () => setState(() => preview = !preview),
                child: Text(
                  preview ? 'View live status' : 'Preview enabled view',
                ),
              ),
            ],
          ),
          if (preview)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Sample activity only. No SMS will be sent.',
                style: TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
            ),
          LayoutBuilder(
            builder: (context, bounds) {
              final receipts = _notice(
                Icons.receipt_long_outlined,
                'Automatic thank-you',
                preview || data!['enabled'] == true
                    ? 'Donation recorded → thank-you queued → Meseji accepts the message.'
                    : 'Setup required before receipt messages can be sent.',
                const Color(0xffedf3fb),
              );
              final reminders = _notice(
                Icons.notifications_none_outlined,
                'Pledge reminders',
                preview
                    ? 'Example schedule: 3 days before the pledge date, then 7 days overdue. Only opted-in donors with an unpaid balance.'
                    : 'Setup required: donor consent and reminder scheduling.',
                const Color(0xfffaf3e1),
              );
              if (bounds.maxWidth < 700) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [receipts, const SizedBox(height: 12), reminders],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: receipts),
                  const SizedBox(width: 16),
                  Expanded(child: reminders),
                ],
              );
            },
          ),
          const Divider(height: 28),
          if (preview) ...[
            _notice(
              Icons.chat_bubble_outline,
              'Thank-you message preview',
              'Afaq: Asante kwa mchango wako wa TZS 50,000.00. Kumbukumbu: DEMO-RECEIPT-001.',
              const Color(0xfff6f8fa),
            ),
            const SizedBox(height: 20),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in [
                ('ACCEPTED', 'Accepted'),
                ('PENDING', 'Queued'),
                ('UNKNOWN', 'Needs review'),
              ])
                Chip(
                  label: Text(
                    '${items.where((row) => row['status'] == entry.$1).length} ${entry.$2}',
                  ),
                  side: BorderSide.none,
                  backgroundColor: const Color(0xfff6f8fa),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            preview
                ? 'Sample receipt activity'
                : 'Latest 20 receipt notifications',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _notice(
              Icons.mark_email_read_outlined,
              'No notification records to show.',
              'Receipt notifications will appear here once the service is enabled and new donations are recorded.',
              const Color(0xfff6f8fa),
            ),
          for (final row in items) _record(row as Map),
          const SizedBox(height: 16),
          const Text(
            'Accepted by Meseji means queued by the provider, not confirmed phone delivery.',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey, height: 1.5),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh messages'),
          ),
        ),
      ],
    ),
  );

  Widget _notice(
    IconData icon,
    String title,
    String description,
    Color color,
  ) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AfaqDesign.ink),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AfaqDesign.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(color: Colors.blueGrey, height: 1.5),
        ),
      ],
    ),
  );

  Widget _record(Map row) {
    final (label, color) = switch (row['status']) {
      'ACCEPTED' => ('Accepted by Meseji', const Color(0xff26764b)),
      'PENDING' => ('Queued', const Color(0xff3567a0)),
      'SENDING' => ('Sending', const Color(0xff3567a0)),
      'SKIPPED' => ('Skipped', const Color(0xff667984)),
      'FAILED' => ('Rejected by provider', const Color(0xffa33c35)),
      _ => ('Needs delivery check', const Color(0xff906c21)),
    };
    final timestamp = DateTime.tryParse('${row['updatedAt']}')?.toLocal();
    final date = timestamp == null
        ? 'Update time unavailable'
        : '${MaterialLocalizations.of(context).formatShortDate(timestamp)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(timestamp))}';
    final reason = switch (row['reason']) {
      'DONATION_VOIDED' => 'Donation is no longer recorded as received.',
      'MADRASA_INACTIVE' => 'Madrasa is not active.',
      'PHONE_UNAVAILABLE' => 'A valid donor phone number is needed.',
      'STALE_NOTIFICATION' => 'Notification is older than the sending window.',
      'HTTP_401' ||
      'HTTP_403' => 'Check Meseji credentials and sender permissions.',
      'HTTP_429' => 'Provider request limit reached.',
      'NETWORK_UNCERTAIN' ||
      'WORKER_INTERRUPTED' ||
      'PROVIDER_UNCERTAIN' ||
      'UNEXPECTED_RESPONSE' =>
        'Check provider history before attempting another send.',
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffe8edf1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${row['reference']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AfaqDesign.ink,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
          if (reason != null) ...[
            const SizedBox(height: 8),
            Text(
              reason,
              style: const TextStyle(
                color: Colors.blueGrey,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
