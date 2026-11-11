import 'package:flutter/material.dart';
import 'dashboard_components.dart';
import 'design_tokens.dart';
import 'teacher_course_modules.dart';

class TeacherCourseCard extends StatefulWidget {
  const TeacherCourseCard({
    super.key,
    required this.course,
    required this.load,
    required this.onOpen,
    required this.onModule,
    required this.refreshToken,
  });
  final Map<String, dynamic> course;
  final PageLoader load;
  final VoidCallback onOpen;
  final ValueChanged<Map<String, dynamic>> onModule;
  final int refreshToken;

  @override
  State<TeacherCourseCard> createState() => _TeacherCourseCardState();
}

class _TeacherCourseCardState extends State<TeacherCourseCard> {
  late Future<dynamic> modules = fetch();
  Future<dynamic> fetch() => widget.load(
    '/api/courses/${Uri.encodeComponent('${widget.course['id']}')}/modules',
  );

  @override
  void didUpdateWidget(covariant TeacherCourseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.course['id'] != widget.course['id']) {
      modules = fetch();
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 24),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFDDE5ED)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final cover = ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  'assets/home/digital-learning.jpg',
                  fit: BoxFit.cover,
                  semanticLabel: 'Digital learning',
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: AfaqDesign.ink,
                    child: Center(
                      child: Icon(
                        Icons.menu_book,
                        size: 64,
                        color: Color(0xFFE5B64C),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ASSIGNED COURSE',
                  style: TextStyle(
                    color: AfaqDesign.actionGold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  recordText(widget.course['title']),
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                if (recordText(widget.course['summary'], '').isNotEmpty)
                  Text(
                    recordText(widget.course['summary']),
                    style: const TextStyle(fontSize: 17, height: 1.6),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: ValueKey('teacher-course-item-${widget.course['id']}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AfaqDesign.actionGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                  ),
                  onPressed: widget.onOpen,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Open course'),
                ),
              ],
            );
            if (box.maxWidth < 800) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cover, const SizedBox(height: 20), details],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: cover),
                const SizedBox(width: 28),
                Expanded(flex: 7, child: details),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 24),
        PageResult(
          future: modules,
          onRetry: () => setState(() => modules = fetch()),
          builder: (data) {
            final rows = recordList(data);
            if (rows.isEmpty) {
              return const Text('No modules have been added yet.');
            }
            return TeacherCourseModules(
              course: const {},
              modules: rows,
              onOpen: widget.onModule,
            );
          },
        ),
      ],
    ),
  );
}
