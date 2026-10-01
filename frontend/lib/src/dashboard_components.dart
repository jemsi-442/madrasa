import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'foundation_ui.dart';

typedef PageLoader = Future<dynamic> Function(String path);

Map<String, dynamic> recordMap(dynamic value) =>
    value is Map<String, dynamic> ? value : const {};

List<Map<String, dynamic>> recordList(dynamic value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];

num recordNumber(dynamic value) => num.tryParse('$value') ?? 0;

String recordText(dynamic value, [String fallback = 'Not provided']) =>
    value == null || value.toString().isEmpty ? fallback : value.toString();

String friendlyStatus(dynamic value) {
  final text = recordText(value, 'Unknown').toLowerCase().replaceAll('_', ' ');
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 960
          ? 4
          : constraints.maxWidth >= 340
          ? 2
          : 1;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children)
            SizedBox(
              width: (constraints.maxWidth - (columns - 1) * 16) / columns,
              child: child,
            ),
        ],
      );
    },
  );
}

class PanelHeading extends StatelessWidget {
  const PanelHeading(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: muted,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    ),
  );
}

class PanelColumns extends StatelessWidget {
  const PanelColumns({
    super.key,
    required this.first,
    required this.second,
    this.firstFlex = 1,
  });
  final Widget first;
  final Widget second;
  final int firstFlex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 800
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 18), second],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: firstFlex, child: first),
              const SizedBox(width: 18),
              Expanded(child: second),
            ],
          ),
  );
}

class PageResult extends StatelessWidget {
  const PageResult({
    super.key,
    required this.future,
    required this.onRetry,
    required this.builder,
  });
  final Future<dynamic> future;
  final VoidCallback onRetry;
  final Widget Function(dynamic data) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(60),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off_outlined, color: gold),
              const SizedBox(height: 12),
              const Text('We could not load this page. Please try again.'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        );
      }
      return builder(snapshot.data);
    },
  );
}

class EmptyRecords extends StatelessWidget {
  const EmptyRecords(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
    child: Center(
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 32, color: muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
        ],
      ),
    ),
  );
}

class RecordTable extends StatelessWidget {
  const RecordTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth = 850,
  });
  final List<String> columns;
  final List<DataRow> rows;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: math.max(minWidth, constraints.maxWidth),
        ),
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF3F5F7)),
          headingTextStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          dataTextStyle: const TextStyle(fontSize: 13, color: ink),
          headingRowHeight: 44,
          dataRowMinHeight: 64,
          dataRowMaxHeight: 80,
          horizontalMargin: 14,
          columnSpacing: 20,
          dividerThickness: 0.6,
          showCheckboxColumn: false,
          columns: [
            for (final column in columns) DataColumn(label: Text(column)),
          ],
          rows: rows,
        ),
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toUpperCase()) {
      'ACTIVE' || 'PRESENT' => forest,
      'INACTIVE' || 'ABSENT' || 'SUSPENDED' => const Color(0xFFBD414F),
      'LATE' => gold,
      _ => blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        friendlyStatus(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class ChartDatum {
  const ChartDatum(this.label, this.value, this.color);
  final String label;
  final num value;
  final Color color;
}

class RingChart extends StatelessWidget {
  const RingChart({
    super.key,
    required this.items,
    required this.center,
    required this.caption,
    this.percentageDigits = 0,
  });
  final List<ChartDatum> items;
  final String center;
  final String caption;
  final int percentageDigits;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<num>(
      0,
      (sum, item) => sum + math.max(0, item.value),
    );
    final ring = SizedBox.square(
      dimension: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(painter: _RingPainter(items)),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 130,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    center,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(caption, style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
    final legend = Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${item.value}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  total == 0
                      ? '-'
                      : '${(item.value / total * 100).toStringAsFixed(percentageDigits)}%',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 390
          ? Row(
              children: [
                ring,
                const SizedBox(width: 24),
                Expanded(child: legend),
              ],
            )
          : Column(children: [ring, const SizedBox(height: 18), legend]),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.items);
  final List<ChartDatum> items;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(13);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 23;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = line);
    final total = items.fold<num>(
      0,
      (sum, item) => sum + math.max(0, item.value),
    );
    if (total == 0) return;
    var angle = -math.pi / 2;
    for (final item in items) {
      final sweep = math.max(0, item.value) / total * 2 * math.pi;
      canvas.drawArc(rect, angle, sweep, false, paint..color = item.color);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.items != items;
}

class ColumnChart extends StatelessWidget {
  const ColumnChart({
    super.key,
    required this.items,
    this.maximum,
    this.height = 220,
  });
  final List<ChartDatum> items;
  final num? maximum;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyRecords('No records for this chart yet.');
    }
    final maxValue = math.max(
      1,
      maximum ?? items.map((e) => e.value).reduce(math.max),
    );
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(constraints.maxWidth, items.length * 52.0),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '0 - $maxValue',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final item in items)
                      Expanded(
                        child: Semantics(
                          label: '${item.label}: ${item.value}',
                          child: ExcludeSemantics(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${item.value}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Flexible(
                                    child: Container(
                                      height:
                                          (height - 65).clamp(
                                            0,
                                            double.infinity,
                                          ) *
                                          (item.value / maxValue).clamp(0, 1),
                                      constraints: const BoxConstraints(
                                        maxWidth: 56,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(5),
                                            ),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            item.color,
                                            item.color.withValues(alpha: 0.68),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(height: 1, color: line),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 34,
                                    child: Text(
                                      item.label,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: muted,
                                      ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showRecordDetails(
  BuildContext context, {
  required String title,
  required Map<String, String> fields,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        primary: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final field in fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.key,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      field.value,
                      style: const TextStyle(color: ink, fontSize: 15),
                    ),
                  ],
                ),
              ),
          ],
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
);
