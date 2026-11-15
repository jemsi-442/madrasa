import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Written content stays separate from media and teaching records.
class TeacherLessonReading extends StatelessWidget {
  const TeacherLessonReading({
    super.key,
    required this.text,
    this.summary = '',
  });

  final String text;
  final String summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 18 : 24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFF8E9), Color(0xFFFFFDF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFECE2CD)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6E7BC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.article_outlined,
                color: AfaqDesign.actionGold,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Lesson notes',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: AfaqDesign.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.trim().isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.6,
                        color: AfaqDesign.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (text.trim().isNotEmpty)
                  SelectableText(
                    text,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.8,
                      color: AfaqDesign.ink,
                    ),
                  )
                else
                  const Text(
                    'No written lesson content has been added yet.',
                    style: TextStyle(fontSize: 16, height: 1.6),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
