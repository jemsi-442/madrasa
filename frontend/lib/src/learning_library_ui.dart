import 'package:flutter/material.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';

(IconData, Color) subjectStyle(String name) {
  final text = name.toLowerCase();
  if (text.contains('qur') || text.contains('hif')) {
    return (Icons.menu_book_outlined, forest);
  }
  if (text.contains('arab') || text.contains('language')) {
    return (Icons.translate, blue);
  }
  if (text.contains('math')) return (Icons.functions, gold);
  if (text.contains('science') || text.contains('biology')) {
    return (Icons.science_outlined, forest);
  }
  if (text.contains('fiqh') || text.contains('islam')) {
    return (Icons.mosque_outlined, gold);
  }
  return (Icons.auto_stories_outlined, blue);
}

/// Illustrated covers do not imply that a course has an uploaded thumbnail.
class CourseCover extends StatelessWidget {
  const CourseCover({super.key, required this.subject, this.lessons});
  final String subject;
  final int? lessons;

  @override
  Widget build(BuildContext context) {
    final (icon, accent) = subjectStyle(subject);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 140),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: .2),
              accent.withValues(alpha: .05),
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Positioned(
              right: -24,
              top: -28,
              child: ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 200,
                  color: accent.withValues(alpha: .08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: accent, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (lessons != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '$lessons lessons',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LearningWelcome extends StatelessWidget {
  const LearningWelcome({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title, subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(colors: [ink, Color(0xFF164F61)]),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR LEARNING SPACE',
              style: TextStyle(
                color: Color(0xFFE5C986),
                fontSize: 11,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFFD5E5EC), height: 1.6),
            ),
          ],
        );
        if (box.maxWidth < 620 ||
            MediaQuery.textScalerOf(context).scale(16) > 24) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: copy),
            const SizedBox(width: 28),
            action ??
                const ExcludeSemantics(
                  child: Icon(
                    Icons.auto_stories_outlined,
                    size: 70,
                    color: Color(0xFFE5C986),
                  ),
                ),
          ],
        );
      },
    ),
  );
}

Map<String, dynamic>? courseToResume(List<Map<String, dynamic>> courses) {
  final available = courses.where(
    (course) =>
        recordText(recordMap(course['resumeLesson'])['id'], '').isNotEmpty,
  );
  return available
          .where(
            (course) =>
                recordNumber(
                  recordMap(course['progress'])['completedLessons'],
                ) >
                0,
          )
          .firstOrNull ??
      available.firstOrNull;
}

class ContinueCourseCard extends StatelessWidget {
  const ContinueCourseCard({
    super.key,
    required this.course,
    required this.onResume,
  });
  final Map<String, dynamic> course;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final progress = recordMap(course['progress']);
    final started = recordNumber(progress['completedLessons']) > 0;
    return Container(
      key: const ValueKey('continue-course-card'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        border: Border.all(color: forest.withValues(alpha: .15)),
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [forest.withValues(alpha: .1), Colors.white],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                started ? 'CONTINUE LEARNING' : 'READY WHEN YOU ARE',
                style: const TextStyle(
                  color: forest,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                recordText(course['title']),
                style: const TextStyle(
                  color: ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Next: ${recordText(recordMap(course['resumeLesson'])['title'])}',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: (recordNumber(progress['progressPercent']) / 100).clamp(
                  0,
                  1,
                ),
                color: forest,
                backgroundColor: line,
                minHeight: 5,
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 6),
              Text(
                '${recordNumber(progress['completedLessons']).toInt()} of ${recordNumber(progress['totalLessons']).toInt()} lessons completed',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          );
          final action = FilledButton.icon(
            key: const ValueKey('resume-course'),
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow),
            label: Text(started ? 'Resume lesson' : 'Start learning'),
          );
          if (box.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 18), action],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 32),
              action,
            ],
          );
        },
      ),
    );
  }
}
