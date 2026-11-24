import 'package:flutter/material.dart';

/// Consistent section labels within the course authoring workspace.
class CourseSectionHeading extends StatelessWidget {
  const CourseSectionHeading(
    this.title, {
    super.key,
    required this.icon,
    this.action,
  });

  final String title;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xffedf1f9), Color(0xfffafbfe)],
      ),
      border: Border.all(color: const Color(0xffd5e1ef)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 480;
        final heading = Row(
          children: [
            Container(width: 4, height: 28, color: const Color(0xffc49329)),
            const SizedBox(width: 12),
            Icon(icon, size: 24, color: const Color(0xff997018)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff092b48),
                  height: 1.25,
                ),
              ),
            ),
            if (action != null && !stacked) ...[
              const SizedBox(width: 12),
              action!,
            ],
          ],
        );
        if (!stacked || action == null) return heading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [action!]),
          ],
        );
      },
    ),
  );
}
