import 'package:flutter/material.dart';

import 'foundation_ui.dart';

class FinanceSectionHeading extends StatelessWidget {
  const FinanceSectionHeading(
    this.title, {
    super.key,
    required this.subtitle,
    required this.eyebrow,
    required this.icon,
    this.accent = gold,
    this.action,
  });

  final String title, subtitle, eyebrow;
  final IconData icon;
  final Color accent;
  final Widget? action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide =
          box.maxWidth >= 700 &&
          MediaQuery.textScalerOf(context).scale(14) <= 20;
      final heading = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (box.maxWidth >= 400) ...[
            ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(
                children: [
                  Expanded(child: heading),
                  if (action != null) ...[const SizedBox(width: 24), action!],
                ],
              )
            else ...[
              heading,
              if (action != null) ...[
                const SizedBox(height: 18),
                Align(alignment: Alignment.centerLeft, child: action!),
              ],
            ],
            const SizedBox(height: 20),
            const Divider(height: 1, color: line),
          ],
        ),
      );
    },
  );
}

class FinanceFilterSummary extends StatelessWidget {
  const FinanceFilterSummary({
    super.key,
    required this.count,
    this.filters = const [],
  });
  final String count;
  final List<String> filters;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (filters.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in filters)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F1E8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        filter,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ink,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class FinanceEmptyState extends StatelessWidget {
  const FinanceEmptyState(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FA),
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        const Icon(Icons.folder_open_outlined, color: gold, size: 32),
        const SizedBox(height: 12),
        const Text(
          'No records to display',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, color: ink),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
        ),
      ],
    ),
  );
}
