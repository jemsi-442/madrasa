import 'package:flutter/material.dart';
import 'admin_forms.dart' show PageSubmitter;
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'learner_lesson_reader.dart';

class LearnerProgressPage extends StatefulWidget {
  const LearnerProgressPage({
    super.key,
    required this.load,
    required this.submit,
    required this.apiBaseUrl,
    required this.onBrowse,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final String apiBaseUrl;
  final VoidCallback onBrowse;
  final int refreshToken;

  @override
  State<LearnerProgressPage> createState() => _LearnerProgressPageState();
}

class _LearnerProgressPageState extends State<LearnerProgressPage> {
  late Future<dynamic> current = widget.load('/api/learner/progress');
  String course = '', status = 'All', search = '';

  @override
  void didUpdateWidget(covariant LearnerProgressPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) reload();
  }

  void reload() => setState(() {
    current = widget.load('/api/learner/progress');
  });

  bool completed(Map<String, dynamic> row) =>
      row['completedAt'] != null || recordNumber(row['progressPercent']) >= 100;

  Future<void> open(Map<String, dynamic> row) async {
    final id = recordText(recordMap(row['lesson'])['id'], '');
    if (id.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LearnerLessonReader(
          id: id,
          load: widget.load,
          submit: widget.submit,
          apiBaseUrl: widget.apiBaseUrl,
        ),
      ),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) => PageResult(
    future: current,
    onRetry: reload,
    builder: (data) {
      final rows = (recordMap(data)['items'] as List? ?? [])
          .map(recordMap)
          .toList();
      final courses = <String, String>{};
      for (final row in rows) {
        final item = recordMap(row['course']);
        courses[recordText(item['id'])] = recordText(item['title']);
      }
      final selectedCourse = courses.containsKey(course) ? course : '';
      final filtered = rows.where((row) {
        final lesson = recordMap(row['lesson']);
        final item = recordMap(row['course']);
        return (selectedCourse.isEmpty ||
                recordText(item['id']) == selectedCourse) &&
            (status == 'All' || (status == 'Completed') == completed(row)) &&
            '${lesson['title']} ${item['title']}'.toLowerCase().contains(
              search.trim().toLowerCase(),
            );
      }).toList();
      final done = rows.where(completed).length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final metric in [
                  ('Tracked lessons', rows.length, blue),
                  ('Completed', done, forest),
                  ('In progress', rows.length - done, gold),
                ])
                  SizedBox(
                    width: box.maxWidth >= 760
                        ? (box.maxWidth - 32) / 3
                        : box.maxWidth,
                    child: SurfacePanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(metric.$1, style: const TextStyle(color: muted)),
                          const SizedBox(height: 8),
                          Text(
                            '${metric.$2}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: metric.$3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your recorded lesson progress',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Recorded lessons only, not whole-course coverage or teacher assessment. Opening media does not mark a lesson complete.',
            style: TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search lessons or courses',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => search = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedCourse),
                  initialValue: selectedCourse,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Course'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All courses'),
                    ),
                    for (final entry in courses.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => course = value ?? ''),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in ['All', 'In progress', 'Completed'])
                      ChoiceChip(
                        label: Text(value),
                        selected: status == value,
                        onSelected: (_) => setState(() => status = value),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (filtered.isEmpty)
                  EmptyRecords(
                    rows.isEmpty
                        ? 'No lesson progress recorded yet.'
                        : 'No lessons match these filters.',
                  ),
                for (final row in filtered) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      completed(row)
                          ? Icons.check_circle_outline
                          : Icons.timelapse,
                      color: completed(row) ? forest : gold,
                    ),
                    title: Text(recordText(recordMap(row['lesson'])['title'])),
                    subtitle: Text(
                      recordText(recordMap(row['course'])['title']),
                    ),
                  ),
                  LinearProgressIndicator(
                    value: (recordNumber(row['progressPercent']) / 100).clamp(
                      0,
                      1,
                    ),
                    color: completed(row) ? forest : gold,
                    backgroundColor: line,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${recordNumber(row['progressPercent']).clamp(0, 100).round()}% recorded',
                      ),
                      TextButton.icon(
                        onPressed: () => open(row),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          completed(row) ? 'Review lesson' : 'Continue lesson',
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                ],
                if (rows.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: widget.onBrowse,
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Browse courses'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
