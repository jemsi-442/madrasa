import 'package:flutter/material.dart';

/// Consistent section labels within the course authoring workspace.
class CourseSectionHeading extends StatelessWidget {
  const CourseSectionHeading(this.title, {super.key, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xfff5f7fb),
      border: Border.all(color: const Color(0xffd5e1ef)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: const Color(0xff997018)),
        const SizedBox(width: 12),
        Flexible(
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
      ],
    ),
  );
}
