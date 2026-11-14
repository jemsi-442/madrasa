import 'package:flutter/material.dart';
import 'dashboard_components.dart';
import 'design_tokens.dart';
import 'teacher_course_modules.dart';
import 'teacher_course_inline_lesson.dart';

class TeacherCourseCard extends StatefulWidget {
  const TeacherCourseCard({
    super.key,
    required this.course,
    required this.load,
    required this.onOpen,
    required this.onModule,
    required this.refreshToken,
    this.apiBaseUrl = '',
  });
  final Map<String, dynamic> course;
  final PageLoader load;
  final String apiBaseUrl;
  final VoidCallback onOpen;
  final ValueChanged<Map<String, dynamic>> onModule;
  final int refreshToken;

  @override
  State<TeacherCourseCard> createState() => _TeacherCourseCardState();
}

class _TeacherCourseCardState extends State<TeacherCourseCard> {
  late Future<dynamic> modules = fetch();
  bool playing = false;
  final playbackAnchor = GlobalKey();

  void play() {
    setState(() => playing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || playbackAnchor.currentContext == null) return;
      Scrollable.ensureVisible(
        playbackAnchor.currentContext!,
        alignment: .05,
        duration: const Duration(milliseconds: 250),
      );
    });
  }

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
            final openAction = FilledButton.icon(
              key: ValueKey('teacher-course-item-${widget.course['id']}'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AfaqDesign.ink,
                side: const BorderSide(color: Color(0xFFAAB6C7)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
              ),
              onPressed: widget.onOpen,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Open course'),
            );
            final action = FutureBuilder<dynamic>(
              future: modules,
              builder: (context, snapshot) {
                final rows = snapshot.hasData
                    ? recordList(snapshot.data)
                    : <Map<String, dynamic>>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (rows.isNotEmpty) ...[
                      FilledButton.icon(
                        onPressed: play,
                        style: FilledButton.styleFrom(
                          backgroundColor: AfaqDesign.actionGold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 20,
                          ),
                        ),
                        icon: const Icon(Icons.play_circle_outline),
                        label: Text(
                          playing ? 'Return to lesson' : 'Play lesson',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    openAction,
                  ],
                );
              },
            );
            final cover = ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/home/teacher-media.png',
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
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
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AfaqDesign.actionGold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Course',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: IconButton.filled(
                        tooltip: 'Play lesson',
                        onPressed: play,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          padding: const EdgeInsets.all(16),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 32),
                      ),
                    ),
                  ],
                ),
              ),
            );
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recordText(widget.course['title']),
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Assigned course',
                      style: TextStyle(color: AfaqDesign.blue),
                    ),
                    if (recordText(widget.course['level'], '').isNotEmpty)
                      Text(recordText(widget.course['level'])),
                    if (recordText(
                      recordMap(widget.course['subject'])['name'],
                      '',
                    ).isNotEmpty)
                      Text(
                        recordText(recordMap(widget.course['subject'])['name']),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (recordText(widget.course['summary'], '').isNotEmpty)
                  Text(
                    recordText(widget.course['summary']),
                    style: const TextStyle(fontSize: 17, height: 1.6),
                  ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE1E6EF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Course progress',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Not tracked',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF66788F),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Personal completion is not recorded for teaching assignments.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF66788F),
                        ),
                      ),
                    ],
                  ),
                ),
                if (box.maxWidth < 1050) ...[
                  const SizedBox(height: 20),
                  action,
                ],
              ],
            );
            if (box.maxWidth < 800) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cover, const SizedBox(height: 20), details],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 4, child: cover),
                const SizedBox(width: 24),
                Expanded(flex: 6, child: details),
                if (box.maxWidth >= 1050) ...[
                  const SizedBox(width: 24),
                  SizedBox(width: 205, child: action),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        SizedBox(key: playbackAnchor),
        if (playing) ...[
          PageResult(
            future: modules,
            onRetry: () => setState(() => modules = fetch()),
            builder: (data) {
              final rows = recordList(data);
              if (rows.isEmpty)
                return const EmptyRecords('No modules have been added yet.');
              return TeacherCourseInlineLesson(
                modules: rows,
                load: widget.load,
                apiBaseUrl: widget.apiBaseUrl,
                onClose: () => setState(() => playing = false),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
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
              onViewAll: widget.onOpen,
            );
          },
        ),
      ],
    ),
  );
}
