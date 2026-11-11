import 'package:flutter/material.dart';
import 'admin_forms.dart' show shortDate;
import 'dashboard_components.dart';
import 'foundation_ui.dart';

/// A read-only view of learner-reported activity, not assessed achievement.
class StudentCourseProgress extends StatelessWidget {
  const StudentCourseProgress({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final tracked = recordNumber(data['trackedLessons']).toInt();
    final completed = recordNumber(data['completedLessons']).toInt();
    final recent = (data['recent'] as List? ?? []).map(recordMap).toList();
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Course activity',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          if (data['linked'] == true) ...[
            const Text(
              'All time | Current learner account',
              style: TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
          ],
          const Text(
            'Learner-reported progress, not teacher-assessed achievement. Counts cover recorded lessons in published courses only.',
            style: TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          if (data.isEmpty)
            const Text('Course activity is unavailable.')
          else if (data['linked'] != true)
            const Text('No learner login is linked to this student yet.')
          else if (tracked == 0)
            const Text(
              'No course activity recorded yet. Classroom learning is tracked separately.',
            )
          else ...[
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                for (final metric in [
                  ('Tracked lessons', tracked, blue),
                  ('Marked complete', completed, forest),
                  (
                    'In progress',
                    (tracked - completed).clamp(0, tracked),
                    gold,
                  ),
                ])
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${metric.$2}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: metric.$3,
                        ),
                      ),
                      Text(metric.$1, style: const TextStyle(color: muted)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Recent lesson activity',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Latest ${recent.length} of $tracked recorded lessons',
              style: const TextStyle(color: muted),
            ),
            for (final row in recent) ...[
              const Divider(height: 28),
              Text(
                recordText(recordMap(row['lesson'])['title']),
                style: const TextStyle(fontWeight: FontWeight.w600, color: ink),
              ),
              const SizedBox(height: 6),
              Text(
                recordText(recordMap(row['course'])['title']),
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (recordNumber(row['progressPercent']) / 100).clamp(
                  0.0,
                  1.0,
                ),
                color: gold,
                backgroundColor: gold.withValues(alpha: 0.12),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  Text(
                    row['completedAt'] != null ||
                            recordNumber(row['progressPercent']) >= 100
                        ? 'Marked complete by learner'
                        : '${recordNumber(row['progressPercent']).toInt()}% reported',
                  ),
                  Text(
                    'Updated ${shortDate(row['updatedAt'])}',
                    style: const TextStyle(color: muted),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
