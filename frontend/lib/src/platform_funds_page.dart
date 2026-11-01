import 'package:flutter/material.dart';
import 'date_selection.dart';
import 'design_tokens.dart';
import 'api_client.dart';
import 'automatic_data_updates.dart';
import 'donor_messaging_workspace.dart';
import 'report_preview.dart';
import 'platform/finance_export_native.dart'
    if (dart.library.js_interop) 'platform/finance_export_web.dart'
    as downloads;

// Group decimal strings without converting financial values to floating point.
String formatFundAmount(dynamic value) {
  final text = value?.toString() ?? '0.00';
  final match = RegExp(r'^(-?)(\d+)(\.\d+)?$').firstMatch(text);
  if (match == null) return text;
  final grouped = match
      .group(2)!
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${match.group(1)}$grouped${match.group(3) ?? '.00'}';
}

String fundsSnapshotLabel(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toUtc();
  if (date == null) return 'Snapshot time unavailable';
  return 'Updated ${dateValue(date)} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} UTC';
}

class PlatformFundsPage extends StatefulWidget {
  const PlatformFundsPage({
    super.key,
    required this.load,
    required this.onSessionExpired,
    this.saveCsv,
    this.post,
  });
  final Future<dynamic> Function(String) load;
  final VoidCallback onSessionExpired;
  final Future<dynamic> Function(String, Map<String, dynamic>)? post;
  final Future<bool> Function(String, String)? saveCsv;
  @override
  State<PlatformFundsPage> createState() => _FundsState();
}

class _FundsState extends State<PlatformFundsPage> {
  late final AutomaticDataUpdates updates;
  int generation = 0;
  bool stale = false, accessLost = false;
  DateTime month = DateTime.now();
  String currency = 'TZS';
  int page = 1;
  bool busy = true;
  bool exporting = false;
  String? error;
  Map<String, dynamic>? data;
  @override
  void initState() {
    super.initState();
    updates = AutomaticDataUpdates(
      canUpdate: () =>
          mounted &&
          !busy &&
          !exporting &&
          !accessLost &&
          ModalRoute.of(context)?.isCurrent != false,
      update: () => refresh(quiet: true),
    );
    refresh();
  }

  @override
  void dispose() {
    updates.dispose();
    super.dispose();
  }

  Future<void> refresh({bool quiet = false}) async {
    final ticket = ++generation;
    if (!quiet) {
      setState(() {
        accessLost = false;
        busy = true;
        error = null;
        data = null;
      });
    }
    try {
      final result = await widget.load(
        '/funds?month=${monthValue(month)}&currency=$currency&page=$page',
      );
      if (mounted && ticket == generation) {
        setState(() {
          data = Map<String, dynamic>.from(result as Map);
          stale = false;
          error = null;
        });
      }
    } catch (e) {
      if (!mounted || ticket != generation) return;
      final denied =
          e is ApiException && (e.statusCode == 401 || e.statusCode == 403);
      if (quiet && !denied) {
        setState(() => stale = true);
        return;
      }
      if (denied) {
        setState(() {
          accessLost = true;
          data = null;
        });
      }
      if (e is ApiException && e.statusCode == 401) widget.onSessionExpired();
      setState(
        () => error = e is ApiException && e.statusCode == 403
            ? 'Your account does not have access to donor oversight.'
            : e is ApiException && e.statusCode == 401
            ? 'Your session has expired. Sign in again.'
            : 'Unable to load funds. Please retry.',
      );
    } finally {
      if (mounted && ticket == generation && !quiet) {
        setState(() => busy = false);
      }
    }
  }

  Widget panel(Widget child) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xffe1e7eb)),
    ),
    padding: const EdgeInsets.all(24),
    child: child,
  );
  Widget heading(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AfaqDesign.ink,
    ),
  );
  Widget note(String text, {bool gold = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: gold ? const Color(0xfff8f0da) : const Color(0xffeaf1fe),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(
        height: 1.5,
        color: gold ? const Color(0xff906c21) : const Color(0xff3567a0),
      ),
    ),
  );
  String money(dynamic value) => '$currency ${formatFundAmount(value)}';
  Future<void> exportSummary() async {
    if (data == null || exporting) return;
    setState(() => exporting = true);
    final snapshot = data!;
    final summary = snapshot['summary'] as Map;
    final csv = [
      'Metric,Value',
      'Scope,Registered madrasas - donation summary only',
      'Month,${snapshot['month']}',
      'Currency,${snapshot['currency']}',
      'Generated at,${snapshot['generatedAt']}',
      'Donors with pledges,${summary['donors']}',
      'Pledges due,${summary['pledged']}',
      'Receipts during month,${summary['received']}',
      'Pledges outstanding at month end,${summary['outstanding']}',
      'Institution expenditure,Not connected',
      'Available balance,Not available',
    ].join('\r\n');
    try {
      final saved = await (widget.saveCsv ?? downloads.saveFinanceCsv)(
        'donation-summary-${snapshot['month']}-${snapshot['currency']}.csv',
        csv,
      );
      if (mounted && saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Summary CSV export requested.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final summary = data?['summary'] as Map?;
      final items = (data?['items'] as List?) ?? [];
      final cards = [
        (
          'Monthly donors',
          '${summary?['donors'] ?? "—"}',
          'Donors with pledges due this month',
          Icons.favorite_border,
          const Color(0xff3269b2),
        ),
        (
          'Monthly commitments',
          summary == null ? '—' : money(summary['pledged']),
          'Pledges due in the selected month',
          Icons.calendar_today_outlined,
          AfaqDesign.actionGold,
        ),
        (
          'Recorded receipts',
          summary == null ? '—' : money(summary['received']),
          'Non-voided receipts during the month',
          Icons.account_balance_wallet_outlined,
          const Color(0xff278458),
        ),
        (
          'Outstanding pledges',
          summary == null ? '—' : money(summary['outstanding']),
          'Unpaid at the end of this month',
          Icons.schedule,
          const Color(0xff7964b3),
        ),
      ];
      final directory = panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading('Monthly donor commitments'),
            const SizedBox(height: 8),
            const Text(
              'Across registered madrasas',
              style: TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 20),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('No pledges found for this month and currency.'),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(
                    Color(0xfff6f8fa),
                  ),
                  columnSpacing: 26,
                  columns: [
                    for (final label in [
                      'Donor / Madrasa',
                      'Fund',
                      'Pledged ($currency)',
                      'Received to month-end',
                      'Status',
                    ])
                      DataColumn(
                        label: Text(label),
                        numeric:
                            label.startsWith('Pledged') ||
                            label.startsWith('Received'),
                      ),
                  ],
                  rows: [
                    for (final row in items)
                      DataRow(
                        cells: [
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${row['donorReference']}'),
                                Text(
                                  '${row['madrasa']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text('${row['fund']}')),
                          DataCell(Text(formatFundAmount(row['pledged']))),
                          DataCell(Text(formatFundAmount(row['received']))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: row['status'] == 'Received'
                                    ? const Color(0xffe7f3ec)
                                    : const Color(0xfff8f0da),
                              ),
                              child: Text(
                                '${row['status']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: row['status'] == 'Received'
                                      ? const Color(0xff26764b)
                                      : const Color(0xff906c21),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            const Divider(height: 28),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${data?['total'] ?? 0} commitments · Page $page'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Previous page',
                      onPressed: busy || page == 1
                          ? null
                          : () {
                              page--;
                              refresh();
                            },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Next page',
                      onPressed:
                          busy || page * 10 >= (data?['total'] as int? ?? 0)
                          ? null
                          : () {
                              page++;
                              refresh();
                            },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      final position = panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading('Financial position'),
            const SizedBox(height: 8),
            Text(
              '${MaterialLocalizations.of(context).formatMonthYear(month)} · $currency',
              style: const TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recorded donation receipts',
              style: TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 8),
            Text(
              money(summary?['received']),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AfaqDesign.ink,
              ),
            ),
            const Divider(height: 32),
            const Text(
              'Institution expenditure and available balance',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Not connected to an institution ledger. Donation receipts alone do not establish available funds.',
              style: TextStyle(height: 1.5, color: Colors.blueGrey),
            ),
            const SizedBox(height: 24),
            note(
              'Pledges are not received money. Campaign allocations retain their designated purpose.',
              gold: true,
            ),
          ],
        ),
      );
      return ColoredBox(
        color: const Color(0xfff8f7f2),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(bounds.maxWidth < 600 ? 16 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'AFAQ · INSTITUTION WORKSPACE',
                style: TextStyle(
                  color: AfaqDesign.actionGold,
                  letterSpacing: 1.5,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Donors & Funds',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AfaqDesign.ink,
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final picked = await showAfaqMonthPicker(
                                  context,
                                  initialDate: month,
                                  lastYear: 2099,
                                );
                                if (picked != null && mounted) {
                                  month = picked;
                                  page = 1;
                                  refresh();
                                }
                              },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMonthYear(month),
                        ),
                      ),
                      DropdownButton<String>(
                        value: currency,
                        items: [
                          for (final code in ['TZS', 'KES', 'USD'])
                            DropdownMenuItem(value: code, child: Text(code)),
                        ],
                        onChanged: busy
                            ? null
                            : (value) {
                                currency = value!;
                                page = 1;
                                refresh();
                              },
                      ),
                      FilledButton.icon(
                        onPressed: busy || exporting || data == null
                            ? null
                            : exportSummary,
                        icon: const Icon(Icons.download_outlined),
                        label: Text(
                          exporting ? 'Exporting...' : 'Financial summary CSV',
                        ),
                      ),
                      ReportPdfButton(
                        load: widget.load,
                        path:
                            '/funds/pdf?month=${month.year}-${month.month.toString().padLeft(2, '0')}&currency=$currency&page=$page',
                        enabled: !busy && data != null,
                      ),
                      IconButton(
                        tooltip: 'Refresh funds',
                        onPressed: busy ? null : refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Oversee donor commitments and recorded collections across madrasas.',
                style: TextStyle(color: Colors.blueGrey),
              ),
              const SizedBox(height: 24),
              if (stale && !accessLost)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: note(
                    'Showing the last loaded data. Reconnecting automatically.',
                    gold: true,
                  ),
                ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                panel(
                  Column(
                    children: [
                      Text(error!),
                      TextButton(
                        onPressed: refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (data != null) ...[
                LayoutBuilder(
                  builder: (context, space) {
                    final columns = space.maxWidth >= 1200
                        ? 4
                        : space.maxWidth >= 600
                        ? 2
                        : 1;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final card in cards)
                          SizedBox(
                            width:
                                (space.maxWidth - (columns - 1) * 16) / columns,
                            child: panel(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          card.$1,
                                          style: const TextStyle(
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                      Icon(card.$4, color: card.$5),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    card.$2,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: AfaqDesign.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    card.$3,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                if (bounds.maxWidth >= 1150)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 18, child: directory),
                      const SizedBox(width: 24),
                      Expanded(flex: 10, child: position),
                    ],
                  )
                else ...[
                  directory,
                  const SizedBox(height: 24),
                  position,
                ],
                const SizedBox(height: 24),
                note(
                  'Read-only oversight. Financial records remain managed in each madrasa; this page does not alter receipts.',
                ),
                const SizedBox(height: 16),
                DonorMessagingWorkspace(
                  load: widget.load,
                  post: widget.post,
                  onSessionExpired: widget.onSessionExpired,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      fundsSnapshotLabel(data?['generatedAt']),
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      'Snapshot only. Refresh for updated records.',
                      style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
