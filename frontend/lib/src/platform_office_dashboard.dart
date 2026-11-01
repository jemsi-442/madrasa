import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'workspace_chrome.dart';
import 'foundation_ui.dart' show DashboardMetric;

class PlatformOfficeDashboard extends StatelessWidget {
  const PlatformOfficeDashboard({
    super.key,
    required this.name,
    required this.snapshot,
    required this.busy,
    required this.error,
    required this.onRefresh,
    required this.onApplications,
    this.onAccounts,
    this.onHistory,
    this.onReview,
    this.onApproved,
    this.onLearning,
    this.onFunds,
    this.onReports,
  });
  final String name;
  final Map<String, dynamic>? snapshot;
  final bool busy;
  final String? error;
  final VoidCallback onRefresh, onApplications;
  final VoidCallback? onAccounts,
      onHistory,
      onReview,
      onApproved,
      onLearning,
      onFunds,
      onReports;

  Widget link(String text, VoidCallback? action) =>
      TextButton(onPressed: busy ? null : action, child: Text(text));

  Widget panel(String title, Widget child, {Widget? action}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: AfaqDesign.panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AfaqDesign.ink,
              ),
            ),
            if (action != null) action,
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );

  Widget statLine(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(
          value == null ? 'Not available' : '$value',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget money(List? rows) => rows == null
      ? const Text('Not available')
      : rows.isEmpty
      ? const Text(
          'None recorded this month',
          style: TextStyle(color: AfaqDesign.muted),
        )
      : Column(
          children: [
            for (final row in rows.whereType<Map>())
              statLine('${row['currency']}', row['amount']),
          ],
        );

  @override
  Widget build(BuildContext context) {
    final data = snapshot?['institution'] as Map?;
    final summary = data?['summary'] as Map?;
    final rows = data?['madrasas'] as List?;
    final onboarding = snapshot?['onboarding'] as Map?;
    final metrics = [
      (
        'Madrasas',
        summary?['madrasas'],
        Icons.account_balance_outlined,
        const Color(0xff346bb0),
      ),
      (
        'Learners',
        summary?['learners'],
        Icons.people_outline,
        const Color(0xff278457),
      ),
      (
        'Teachers',
        summary?['teachers'],
        Icons.menu_book_outlined,
        AfaqDesign.gold,
      ),
      (
        'Madrasas with records',
        summary == null
            ? null
            : '${summary['withLearningRecords']} / ${summary['madrasas']}',
        Icons.description_outlined,
        const Color(0xff7663af),
      ),
    ];
    return LayoutBuilder(
      builder: (context, bounds) {
        final wide = bounds.maxWidth >= 1000;
        final padding = bounds.maxWidth < 600 ? 16.0 : 28.0;
        final columns = wide
            ? 4
            : bounds.maxWidth >= 600
            ? 2
            : 1;
        Widget pair(Widget left, Widget right) => wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: left),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: right),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 20), right],
              );
        final table = rows == null
            ? const Text('Madrasa data is unavailable.')
            : rows.isEmpty
            ? const Text('No registered madrasas yet.')
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(
                    Color(0xfff5f7f8),
                  ),
                  columnSpacing: 24,
                  dataRowMinHeight: 66,
                  dataRowMaxHeight: 78,
                  columns: [
                    for (final label in [
                      'Madrasa',
                      'Learners',
                      'Teachers',
                      'Learning records',
                    ])
                      DataColumn(label: Text(label)),
                  ],
                  rows: [
                    for (final row in rows.whereType<Map>())
                      DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 185,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${row['name']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${row['code']}',
                                    style: const TextStyle(
                                      color: AfaqDesign.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(Text('${row['learners']}')),
                          DataCell(Text('${row['teachers']}')),
                          DataCell(
                            Text(
                              row['hasLearningRecords'] == true
                                  ? 'Records available'
                                  : 'No records',
                              style: TextStyle(
                                color: row['hasLearningRecords'] == true
                                    ? const Color(0xff278457)
                                    : AfaqDesign.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'AFAQ / INSTITUTION WORKSPACE',
                style: TextStyle(
                  color: AfaqDesign.gold,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
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
                    'Institution Overview',
                    style: TextStyle(
                      fontSize: 30,
                      color: AfaqDesign.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (data?['month'] != null)
                        Text(
                          'Month: ${data!['month']} (UTC)',
                          style: const TextStyle(color: AfaqDesign.muted),
                        ),
                      link('Institution report', onReports),
                      WorkspaceRefreshButton(
                        tooltip: 'Refresh overview',
                        onRefresh: onRefresh,
                        loading: busy,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Learning, reporting and support across your madrasas.',
                style: TextStyle(color: AfaqDesign.muted, height: 1.5),
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
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
                      child: DashboardMetric(
                        label: metric.$1,
                        value: metric.$2 == null
                            ? 'Not available'
                            : '${metric.$2}',
                        icon: metric.$3,
                        accent: metric.$4,
                        dense: true,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              pair(
                panel(
                  'Madrasa overview',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      table,
                      const SizedBox(height: 12),
                      Text(
                        rows == null
                            ? 'No totals estimated.'
                            : 'Showing ${rows.length} of ${summary?['madrasas'] ?? "?"} registered madrasas',
                        style: const TextStyle(color: AfaqDesign.muted),
                      ),
                    ],
                  ),
                  action: link('View all madrasas', onApplications),
                ),
                panel(
                  'Needs attention',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      statLine(
                        'Requests awaiting your review',
                        snapshot?['awaitingYourReview'],
                      ),
                      link('Review madrasa requests', onReview),
                      const Divider(),
                      statLine('Awaiting setup', onboarding?['awaitingSetup']),
                      statLine(
                        'Awaiting activation',
                        onboarding?['pendingActivation'],
                      ),
                      link('View onboarding', onApproved),
                      const Divider(),
                      statLine(
                        'Open support notes',
                        summary?['openSupportNotes'],
                      ),
                      link('Learning follow-ups', onLearning),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              pair(
                panel(
                  'Learning records this month',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      statLine('Lessons taught', summary?['lessonsTaught']),
                      statLine(
                        "Qur'an observations",
                        summary?['quranObservations'],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Record counts, not unique learners or attainment. No records does not mean no activity.',
                        style: TextStyle(color: AfaqDesign.muted, height: 1.5),
                      ),
                    ],
                  ),
                  action: link('View learning', onLearning),
                ),
                panel(
                  'Donor collections',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Confirmed receipts',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      money(data?['receipts'] as List?),
                      const Divider(height: 24),
                      const Text(
                        'Commitments due this month',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      money(data?['pledges'] as List?),
                      const SizedBox(height: 12),
                      const Text(
                        'Commitments are not received money.',
                        style: TextStyle(color: AfaqDesign.muted),
                      ),
                    ],
                  ),
                  action: link('View funds', onFunds),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Learning data availability is not monthly report submission.',
                style: TextStyle(color: AfaqDesign.muted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
