import 'package:flutter/material.dart';

/// Publication is separate from uploading and from learner permissions.
class TeacherLessonAccess extends StatelessWidget {
  const TeacherLessonAccess({super.key, required this.lesson});

  final Map<String, dynamic> lesson;

  @override
  Widget build(BuildContext context) {
    final status = lesson['publicationStatus'];
    final locked = lesson['visibility'] == 'LOCKED';
    final (title, description, icon, color) = switch (status) {
      'DRAFT' => (
        'Draft lesson',
        'Learners cannot see this lesson yet. Ask your madrasa administrator to publish the course and lesson when ready.',
        Icons.edit_note_outlined,
        const Color(0xFF956B18),
      ),
      'ARCHIVED' => (
        'Archived lesson',
        'This lesson is not available to learners. Uploaded resources remain available for teacher preview.',
        Icons.inventory_2_outlined,
        const Color(0xFF64748B),
      ),
      'PUBLISHED' when locked => (
        'Published, but locked',
        'Learners cannot open this lesson while it is locked. Ask your madrasa administrator to review lesson access.',
        Icons.lock_outline,
        const Color(0xFF956B18),
      ),
      'PUBLISHED' => (
        'Lesson published',
        'Learners still need course access. Locked resources remain teacher-preview only.',
        Icons.check_circle_outline,
        const Color(0xFF23735C),
      ),
      _ => (
        'Publication status unavailable',
        'Learner access cannot be confirmed from this view.',
        Icons.info_outline,
        const Color(0xFF64748B),
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
