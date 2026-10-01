import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'accountant_components.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'finance_presentation.dart';
import 'finance_monthly_chart.dart';
import 'platform/finance_export_native.dart'
    if (dart.library.js_interop) 'platform/finance_export_web.dart'
    as platform;

typedef FinanceCsvLoader = Future<String> Function(String path);
typedef FinanceCsvSaver =
    Future<bool> Function(String filename, String content);

class FinanceReportsPage extends StatefulWidget {
  const FinanceReportsPage({
    super.key,
    required this.load,
    required this.exportCsv,
    this.saveCsv,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final FinanceCsvLoader exportCsv;
  final FinanceCsvSaver? saveCsv;
  final int refreshToken;
  @override
  State<FinanceReportsPage> createState() => _FinanceReportsPageState();
}

class _FinanceReportsPageState extends State<FinanceReportsPage> {
  int year = DateTime.now().year.clamp(2000, 2100);
  bool exporting = false;
  late Future<dynamic> result = fetch();
  Future<dynamic> fetch() => financeRequest(
    widget.load,
    '/api/reports/finance/monthly-summary?year=$year',
  );
  void reload() => setState(() {
    result = fetch();
  });

  @override
  void didUpdateWidget(FinanceReportsPage old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) result = fetch();
  }

  Future<void> export({bool preview = false}) async {
    if (exporting) return;
    setState(() => exporting = true);
    final selectedYear = year;
    try {
      final csv = await widget.exportCsv(
        '/api/reports/finance/monthly-summary/export?year=$selectedYear',
      );
      if (!mounted) return;
      if (preview) {
        await showFinanceDetail(
          context,
          title: 'CSV report: $selectedYear',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FinanceNotice(
                'This export contains financial data. Only share it with authorized recipients.',
              ),
              const SizedBox(height: 16),
              SelectableText(
                csv,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  String message;
                  try {
                    await Clipboard.setData(ClipboardData(text: csv));
                    message = 'CSV copied to clipboard.';
                  } catch (_) {
                    message = 'The CSV could not be copied. Please try again.';
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy CSV'),
              ),
            ],
          ),
        );
      } else {
        final saved = await (widget.saveCsv ?? platform.saveFinanceCsv)(
          'finance-monthly-summary-$selectedYear.csv',
          csv,
        );
        if (!mounted || !saved) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'CSV download requested.'
                  : 'CSV saved to your chosen location.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The CSV export could not be completed. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FinanceSectionHeading(
              'Financial reports',
              eyebrow: 'Year in review',
              icon: Icons.assessment_outlined,
              accent: blue,
              subtitle:
                  'Review the year month by month, then export the school report.',
            ),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int>(
                    initialValue: year,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Report year'),
                    items: [
                      for (var y = 2100; y >= 2000; y--)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: exporting
                        ? null
                        : (value) => setState(() {
                            year = value!;
                            result = fetch();
                          }),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: exporting ? null : () => export(preview: true),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('View CSV'),
                ),
                if (widget.saveCsv != null ||
                    platform.financeDownloadsSupported)
                  FilledButton.icon(
                    onPressed: exporting ? null : export,
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(exporting ? 'Preparing...' : 'Save CSV'),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      PageResult(
        future: result,
        onRetry: reload,
        builder: (data) {
          final report = recordMap(data),
              totals = recordMap(recordMap(data)['totals']);
          final months = recordList(report['months']);
          if (totals.isEmpty) {
            return const SurfacePanel(
              child: EmptyRecords(
                'No financial report is available for this year.',
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final count = box.maxWidth >= 1100
                      ? 4
                      : box.maxWidth >= 650
                      ? 2
                      : 1;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final (label, field, icon, color) in [
                        (
                          'Invoiced',
                          'invoicedAmount',
                          Icons.receipt_long_outlined,
                          blue,
                        ),
                        (
                          'Collected',
                          'collectedAmount',
                          Icons.task_alt_outlined,
                          forest,
                        ),
                        (
                          'Expenses',
                          'expenseAmount',
                          Icons.account_balance_outlined,
                          gold,
                        ),
                        ('Net cash flow', 'netCashFlow', Icons.swap_vert, ink),
                      ])
                        SizedBox(
                          width: (box.maxWidth - (count - 1) * 14) / count,
                          child: SurfacePanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, color: color),
                                const SizedBox(height: 12),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  financeMoney(totals[field]),
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w700,
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
              const SizedBox(height: 18),
              const FinanceNotice(
                'Amounts are reported without currency by this endpoint. Payments are grouped by paid date, invoices by issue date, and expenses by expense date (UTC). Invoiced less collected is a period difference, not a debtor balance.',
              ),
              const SizedBox(height: 18),
              if (months.isNotEmpty) ...[
                FinanceMonthlyChart(
                  key: ValueKey('finance-chart-$year'),
                  months: months,
                ),
                const SizedBox(height: 18),
              ],
              SurfacePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PanelHeading(
                      'Monthly breakdown',
                      subtitle:
                          '${recordText(report['year'])} | ${recordText(totals['paymentsCollected'])} completed payments | ${recordText(totals['expensesRecorded'])} expense records',
                    ),
                    if (months.isEmpty)
                      const EmptyRecords('No monthly records were returned.')
                    else
                      LayoutBuilder(
                        builder: (context, box) {
                          if (box.maxWidth >= 840 &&
                              MediaQuery.textScalerOf(context).scale(14) <=
                                  20) {
                            return RecordTable(
                              minWidth: 840,
                              columns: const [
                                'Month',
                                'Invoiced',
                                'Collected',
                                'Expenses',
                                'Net cash flow',
                              ],
                              rows: [
                                for (final m in months)
                                  DataRow(
                                    cells: [
                                      DataCell(Text(recordText(m['label']))),
                                      for (final field in [
                                        'invoicedAmount',
                                        'collectedAmount',
                                        'expenseAmount',
                                        'netCashFlow',
                                      ])
                                        DataCell(Text(financeMoney(m[field]))),
                                    ],
                                  ),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              for (final m in months)
                                ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: Text(
                                    recordText(m['label']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Net cash flow: ${financeMoney(m['netCashFlow'])}',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  children: [
                                    FinanceFacts([
                                      (
                                        'Invoiced',
                                        financeMoney(m['invoicedAmount']),
                                      ),
                                      (
                                        'Collected',
                                        financeMoney(m['collectedAmount']),
                                      ),
                                      (
                                        'Expenses',
                                        financeMoney(m['expenseAmount']),
                                      ),
                                      (
                                        'Completed payments',
                                        recordText(m['paymentsCollected']),
                                      ),
                                    ]),
                                  ],
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}
