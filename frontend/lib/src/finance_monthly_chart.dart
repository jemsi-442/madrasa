import 'package:flutter/material.dart';

import 'accountant_components.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';

class FinanceMonthlyChart extends StatefulWidget {
  const FinanceMonthlyChart({super.key, required this.months});
  final List<Map<String, dynamic>> months;

  @override
  State<FinanceMonthlyChart> createState() => _FinanceMonthlyChartState();
}

class _FinanceMonthlyChartState extends State<FinanceMonthlyChart> {
  int selected = 0;

  @override
  void didUpdateWidget(FinanceMonthlyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (selected >= widget.months.length) selected = 0;
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    if (months.isEmpty) return const SizedBox.shrink();
    var peak = BigInt.zero;
    var negative = false;
    for (final month in months) {
      for (final field in ['collectedAmount', 'expenseAmount']) {
        final amount = financeMinorUnits(month[field]);
        if (amount == null) continue;
        if (amount.abs() > peak) peak = amount.abs();
        negative = negative || amount.isNegative;
      }
    }
    final current = months[selected];
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeading(
            'Collections and expenses',
            subtitle:
                'Choose a month to inspect its reported amounts. Both series use the same scale.',
          ),
          const Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [_Legend('Collected', forest), _Legend('Expenses', gold)],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, box) {
              final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
              final minWidth = 62.0 * scale.clamp(1, 2);
              final width = (box.maxWidth / months.length).clamp(
                minWidth,
                180.0,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < months.length; i++)
                      SizedBox(
                        width: width,
                        child: Tooltip(
                          message:
                              '${recordText(months[i]['label'])}\nCollected: ${financeMoney(months[i]['collectedAmount'])}\nExpenses: ${financeMoney(months[i]['expenseAmount'])}',
                          child: Semantics(
                            label:
                                '${recordText(months[i]['label'])}. Collected: ${financeMoney(months[i]['collectedAmount'])}. Expenses: ${financeMoney(months[i]['expenseAmount'])}.',
                            selected: selected == i,
                            button: true,
                            onTap: () => setState(() => selected = i),
                            excludeSemantics: true,
                            child: TextButton(
                              key: ValueKey('finance-chart-month-$i'),
                              onPressed: () => setState(() => selected = i),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                backgroundColor: selected == i
                                    ? const Color(0xFFF4F6F8)
                                    : Colors.transparent,
                              ),
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 140,
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: negative ? 64 : 0,
                                          child: const Divider(
                                            height: 1,
                                            color: line,
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              _Bar(
                                                amount: financeMinorUnits(
                                                  months[i]['collectedAmount'],
                                                ),
                                                peak: peak,
                                                negative: negative,
                                                color: forest,
                                              ),
                                              const SizedBox(width: 5),
                                              _Bar(
                                                amount: financeMinorUnits(
                                                  months[i]['expenseAmount'],
                                                ),
                                                peak: peak,
                                                negative: negative,
                                                color: gold,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _shortLabel(months[i]),
                                    style: TextStyle(
                                      color: selected == i ? ink : muted,
                                      fontSize: 12,
                                      fontWeight: selected == i
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: line),
            ),
            child: Wrap(
              spacing: 28,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  recordText(current['label']),
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                for (final (label, field, color) in [
                  ('Collected', 'collectedAmount', forest),
                  ('Expenses', 'expenseAmount', gold),
                ])
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        financeMoney(current[field]),
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Reported amounts; currency is not supplied by the report. A dash means data is unavailable, not zero.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _shortLabel(Map<String, dynamic> month) {
    final name = recordText(month['label'], '?');
    return name.length > 3 ? name.substring(0, 3) : name;
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(label, style: const TextStyle(color: muted, fontSize: 12)),
      ),
    ],
  );
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.amount,
    required this.peak,
    required this.negative,
    required this.color,
  });
  final BigInt? amount;
  final BigInt peak;
  final bool negative;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = amount;
    final baseline = negative ? 64.0 : 0.0;
    if (value == null) {
      return SizedBox(
        width: 12,
        child: Align(
          alignment: negative ? Alignment.center : Alignment.bottomCenter,
          child: const Text('-', style: TextStyle(color: muted)),
        ),
      );
    }
    // Only geometry is approximate; labels retain fixed-point API precision.
    final fraction = peak == BigInt.zero
        ? 0.0
        : (value.abs() * BigInt.from(10000) ~/ peak).toDouble() / 10000;
    final height = fraction * (negative ? 64.0 : 128.0);
    return SizedBox(
      width: 12,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: value.isNegative ? baseline - height : baseline,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
