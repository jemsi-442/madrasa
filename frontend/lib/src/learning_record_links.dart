import 'package:flutter/material.dart';

import 'foundation_ui.dart';
import 'teacher_ui.dart';

enum LearningRecordPage { attendance, quran, assessments, reports }

typedef OpenLearningRecord =
    void Function(LearningRecordPage page, String classId);

bool learningClassAvailable(List<Map<String, dynamic>> classes, String id) =>
    id.isEmpty || classes.any((row) => '${row['id']}' == id);

class UnavailableLearningClass extends StatelessWidget {
  const UnavailableLearningClass({super.key, required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const TeacherNotice(
        'The selected class is no longer available in this workspace. Choose an available class to continue. Your saved records have not been changed.',
        warning: true,
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: onClear,
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: const Text('Show available classes'),
      ),
    ],
  );
}

class LearningRecordLinks extends StatelessWidget {
  const LearningRecordLinks({
    super.key,
    required this.classId,
    required this.className,
    required this.current,
    required this.admin,
    required this.onOpen,
  });
  final String classId, className;
  final LearningRecordPage current;
  final bool admin;
  final OpenLearningRecord? onOpen;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('learning-record-links'),
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F6F5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Working with $className',
          style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Open the source records or reports for this class. Reports use recorded attendance, Qur\'an sessions and published assessments for the chosen period.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (page, label, icon) in [
              (
                LearningRecordPage.attendance,
                'Attendance',
                Icons.event_available_outlined,
              ),
              if (!admin)
                (
                  LearningRecordPage.quran,
                  "Qur'an records",
                  Icons.menu_book_outlined,
                ),
              (
                LearningRecordPage.assessments,
                'Assessments',
                Icons.fact_check_outlined,
              ),
              (
                LearningRecordPage.reports,
                'Reports',
                Icons.description_outlined,
              ),
            ])
              OutlinedButton.icon(
                key: ValueKey('learning-link-${page.name}'),
                onPressed: current == page || onOpen == null
                    ? null
                    : () => onOpen!(page, classId),
                icon: Icon(
                  current == page ? Icons.check_circle_outline : icon,
                  size: 18,
                ),
                label: Text(current == page ? '$label (current)' : label),
              ),
          ],
        ),
      ],
    ),
  );
}
