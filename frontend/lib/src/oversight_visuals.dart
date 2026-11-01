import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'status_badge.dart';

class OversightMetrics extends StatelessWidget {
  const OversightMetrics({super.key, required this.data});
  final Map data;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 1000
          ? 4
          : box.maxWidth >= 560
          ? 2
          : 1;
      final width = (box.maxWidth - (columns - 1) * 16) / columns;
      final metrics = [
        (
          'Learners with records',
          '${data['recorded'] ?? 0} / ${data['eligible'] ?? 0}',
          'At least one Quran record in this period',
          Icons.people_outline,
          AfaqDesign.blue,
        ),
        (
          'Madrasas',
          '${data['madrasas'] ?? 0}',
          'Matching the selected madrasa scope',
          Icons.account_balance_outlined,
          AfaqDesign.green,
        ),
        (
          'Without Quran records',
          '${data['unrecorded'] ?? 0}',
          'Active learners without a recorded session',
          Icons.schedule_outlined,
          AfaqDesign.actionGold,
        ),
        (
          'Support observed',
          '${data['needingSupport'] ?? 0}',
          'Learners with a support observation',
          Icons.menu_book_outlined,
          AfaqDesign.purple,
        ),
      ];
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final m in metrics)
            SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: AfaqDesign.panelDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.$1,
                                style: const TextStyle(
                                  color: AfaqDesign.muted,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                m.$2,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: AfaqDesign.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: m.$5.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(m.$4, color: m.$5, size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      m.$3,
                      style: const TextStyle(
                        color: AfaqDesign.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class OversightQuranPanel extends StatefulWidget {
  const OversightQuranPanel({super.key, required this.data});
  final Map? data;
  @override
  State<OversightQuranPanel> createState() => _OversightQuranPanelState();
}

class _OversightQuranPanelState extends State<OversightQuranPanel> {
  String activity = 'READING';
  @override
  Widget build(BuildContext context) {
    final rows = (widget.data?['activities'] as List? ?? []).whereType<Map>();
    final selected = rows.where((r) => r['activity'] == activity);
    final row = selected.isEmpty ? <dynamic, dynamic>{} : selected.first;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AfaqDesign.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Qur'an learning oversight",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AfaqDesign.ink,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const {
                'READING': 'Recitation',
                'MEMORIZATION': 'Hifz',
                'REVISION': 'Revision',
                'TAJWEED': 'Tajweed',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: activity == entry.key,
                  showCheckmark: false,
                  selectedColor: AfaqDesign.ink,
                  labelStyle: TextStyle(
                    color: activity == entry.key
                        ? Colors.white
                        : AfaqDesign.muted,
                  ),
                  onSelected: (_) => setState(() => activity = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            widget.data == null ? 'Unavailable' : '${row['sessions'] ?? 0}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AfaqDesign.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Teacher-recorded sessions',
            style: TextStyle(color: AfaqDesign.muted),
          ),
          const SizedBox(height: 22),
          for (final metric in const {
            'independent': 'Independent',
            'withSupport': 'With support',
            'needsPractice': 'Needs practice',
          }.entries)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AfaqDesign.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      metric.value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  AfaqStatusBadge(
                    label: widget.data == null
                        ? 'Unavailable'
                        : '${row[metric.key] ?? 0}',
                    color: metric.key == 'independent'
                        ? AfaqDesign.green
                        : AfaqDesign.actionGold,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AfaqDesign.canvas,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.data == null
                  ? 'Quran session data could not be loaded.'
                  : '${widget.data!['classScopes'] ?? 0} adopted classes on this assignment page. Sessions can repeat learners and passages; they are not mastery or ayah coverage.',
              style: const TextStyle(
                color: AfaqDesign.muted,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
