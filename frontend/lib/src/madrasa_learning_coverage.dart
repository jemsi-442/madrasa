import 'package:flutter/material.dart';
import 'live_data.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'api_client.dart';
import 'design_tokens.dart';
import 'dashboard_components.dart' show StatusPill;
import 'status_badge.dart';
import 'workspace_form_dialog.dart';

class MadrasaLearningCoverage extends StatefulWidget {
  const MadrasaLearningCoverage({
    super.key,
    required this.load,
    required this.filters,
    required this.onSessionExpired,
    this.followupsOnly = false,
  });
  final Future<dynamic> Function(String) load;
  final Map<String, String> filters;
  final VoidCallback onSessionExpired;
  final bool followupsOnly;
  @override
  State<MadrasaLearningCoverage> createState() =>
      _MadrasaLearningCoverageState();
}

class _MadrasaLearningCoverageState extends State<MadrasaLearningCoverage> {
  int page = 1;
  bool denied = false;
  int generation = 0;
  late Future<dynamic> result = fetch();
  @override
  void didUpdateWidget(covariant MadrasaLearningCoverage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.filters, widget.filters)) {
      page = 1;
      result = fetch();
    }
  }

  Future<dynamic> fetch() async {
    final request = ++generation;
    denied = false;
    try {
      return await widget.load(
        '/curriculum/oversight/madrasas?${Uri(queryParameters: {
          for (final key in ['madrasa', 'status', 'quranMonth'])
            if (widget.filters.containsKey(key)) key: widget.filters[key]!,
          'page': '$page',
        }).query}',
      );
    } on ApiException catch (error) {
      if (!mounted || request != generation) return null;
      if (error.statusCode == 401) widget.onSessionExpired();
      denied = error.statusCode == 401 || error.statusCode == 403;
      return null;
    } catch (_) {
      return null;
    }
  }

  void reload(int target) => setState(() {
    page = target;
    result = fetch();
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: AfaqDesign.panelDecoration(),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                'Learning record coverage',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AfaqDesign.ink,
                ),
              ),
              Text(
                'Not an attainment ranking',
                style: TextStyle(color: AfaqDesign.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        LiveDataBuilder(
          future: result,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.data == null) {
              return Column(
                children: [
                  Text(
                    denied
                        ? 'Access to madrasa learning coverage is unavailable.'
                        : 'Could not load madrasa coverage. Existing records have not been deleted.',
                  ),
                  if (!denied)
                    TextButton(
                      onPressed: () => reload(page),
                      child: const Text('Retry madrasa coverage'),
                    ),
                  if (!denied && page > 1)
                    TextButton(
                      onPressed: () => reload(1),
                      child: const Text('Back to first madrasa page'),
                    ),
                ],
              );
            }
            final data = snapshot.data as Map;
            final rows = data['items'] as List;
            final visibleRows = widget.followupsOnly
                ? rows
                      .where(
                        (item) =>
                            (item['eligible'] as num? ?? 0) > 0 &&
                            ((item['unrecorded'] as num? ?? 0) > 0 ||
                                (item['needingSupport'] as num? ?? 0) > 0),
                      )
                      .toList()
                : rows;
            final generatedAt = DateTime.tryParse('${data['generatedAt']}');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rows.isEmpty)
                  const Text(
                    'No madrasas on this page. Try fewer filters or return to the previous page.',
                  ),
                if (widget.followupsOnly)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Text(
                      visibleRows.isEmpty
                          ? 'No follow-ups on this page. Check other pages for more madrasas.'
                          : '${visibleRows.length} madrasas to follow up on this page. Missing records are not evidence of absence or failure.',
                      style: const TextStyle(
                        color: AfaqDesign.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                _MadrasaTable(
                  rows: visibleRows,
                  period: widget.filters['quranMonth'] ?? 'All time',
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => reload(page),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text(
                      'Refresh madrasas',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Previous madrasas',
                      onPressed: page > 1 ? () => reload(page - 1) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('Madrasa page $page'),
                    IconButton(
                      tooltip: 'Next madrasas',
                      onPressed: data['hasMore'] == true
                          ? () => reload(page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Text(
                    generatedAt == null
                        ? 'Madrasa snapshot time unavailable.'
                        : 'Madrasa snapshot: ${generatedAt.toUtc().toIso8601String()} (UTC)',
                    style: const TextStyle(
                      color: AfaqDesign.muted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _MadrasaTable extends StatelessWidget {
  const _MadrasaTable({required this.rows, required this.period});
  final List rows;
  final String period;
  int count(Map row, String key) => (row[key] as num?)?.toInt() ?? 0;

  void details(BuildContext context, Map row) => showDialog<void>(
    context: context,
    builder: (context) {
      final width = (MediaQuery.sizeOf(context).width - 80).clamp(240.0, 620.0);
      final cardWidth = width < 460 ? width : (width - 12) / 2;
      return WorkspaceFormDialog(
        eyebrow: 'LEARNING OVERSIGHT / MADRASA',
        icon: Icons.account_balance_outlined,
        title: Text(
          '${row['name']}',
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: AfaqDesign.ink,
          ),
        ),
        content: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill('${row['status']}'),
                    Text(
                      'Reporting period: $period',
                      style: const TextStyle(
                        color: AfaqDesign.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AfaqDesign.canvas,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LEARNING RECORD COVERAGE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.1,
                          color: AfaqDesign.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${count(row, 'recorded')} / ${count(row, 'eligible')}',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AfaqDesign.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Active learners with Quran records',
                        style: TextStyle(color: AfaqDesign.muted),
                      ),
                      const SizedBox(height: 16),
                      coverage(row),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DetailMetric(
                      width: cardWidth,
                      value: count(row, 'unrecorded'),
                      label: 'Without records',
                      description: 'No Quran record in this period',
                      icon: Icons.description_outlined,
                      color: AfaqDesign.actionGold,
                    ),
                    _DetailMetric(
                      width: cardWidth,
                      value: count(row, 'needingSupport'),
                      label: 'Support observed',
                      description: 'Recorded by the teacher',
                      icon: Icons.support_agent_outlined,
                      color: AfaqDesign.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AfaqDesign.blue.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 22,
                        color: AfaqDesign.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Follow-up',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AfaqDesign.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Follow up with the madrasa administrator or responsible teacher. Assessments cannot be changed here.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: AfaqDesign.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const ExpansionTile(
                  title: Text(
                    'How these counts are calculated',
                    style: TextStyle(fontSize: 13),
                  ),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Each active learner is counted once. Voided records are excluded. Support is an observation in this period, not an unresolved task; missing records do not mean absence or failure.',
                        style: TextStyle(
                          color: AfaqDesign.muted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: AfaqDesign.ink),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );

  Widget coverage(Map row) {
    final eligible = count(row, 'eligible');
    final recorded = count(row, 'recorded');
    if (eligible == 0) {
      return const Text(
        'Not applicable: no eligible learners',
        style: TextStyle(fontSize: 12, color: AfaqDesign.muted),
      );
    }
    final ratio = (recorded / eligible).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            color: const Color(0xFF385E7E),
            backgroundColor: AfaqDesign.tableHeader,
            borderRadius: BorderRadius.circular(6),
            semanticsLabel: 'Learners with Quran records',
            semanticsValue: '$recorded of $eligible',
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(ratio * 100).round()}%',
          style: const TextStyle(
            fontSize: 12,
            color: AfaqDesign.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: constraints.maxWidth < 740 ? 740 : constraints.maxWidth,
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.1),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.6),
            3: FlexColumnWidth(1.7),
            4: FixedColumnWidth(76),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(
            horizontalInside: BorderSide(color: AfaqDesign.border),
          ),
          children: [
            const TableRow(
              decoration: BoxDecoration(color: AfaqDesign.tableHeader),
              children: [
                _CoverageCell('Madrasa', heading: true),
                _CoverageCell('Learners recorded', heading: true),
                _CoverageCell('Coverage', heading: true),
                _CoverageCell('Status', heading: true),
                _CoverageCell('', heading: true),
              ],
            ),
            for (final item in rows)
              TableRow(
                children: [
                  _CoverageCell('${item['name']}', strong: true),
                  _CoverageCell('${item['recorded']} / ${item['eligible']}'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: coverage(item as Map),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AfaqStatusBadge(
                        label: count(item, 'eligible') == 0
                            ? 'No learners'
                            : count(item, 'needingSupport') > 0 ||
                                  count(item, 'unrecorded') > 0
                            ? 'Needs follow-up'
                            : 'Records available',
                        color: count(item, 'eligible') == 0
                            ? AfaqDesign.muted
                            : count(item, 'needingSupport') > 0 ||
                                  count(item, 'unrecorded') > 0
                            ? AfaqDesign.actionGold
                            : AfaqDesign.green,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => details(context, item),
                    child: const Text('View →', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.width,
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
  final double width;
  final int value;
  final String label, description;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: AfaqDesign.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 12),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AfaqDesign.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: AfaqDesign.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _CoverageCell extends StatelessWidget {
  const _CoverageCell(this.text, {this.heading = false, this.strong = false});
  final String text;
  final bool heading, strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: heading ? 16 : 22),
    child: Text(
      text,
      style: TextStyle(
        fontSize: heading ? 12 : 14,
        color: heading ? AfaqDesign.muted : AfaqDesign.ink,
        fontWeight: heading || strong ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
  );
}
