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
    this.onQuran,
    this.onAssessments,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final String apiBaseUrl;
  final VoidCallback onBrowse;
  final VoidCallback? onQuran, onAssessments;
  final int refreshToken;

  @override
  State<LearnerProgressPage> createState() => _LearnerProgressPageState();
}

class _LearnerProgressPageState extends State<LearnerProgressPage> {
  late Future<dynamic> current = widget.load('/api/learner/progress');
  String course = '', status = 'All', search = '';
  int page = 0;
  static const pageSize = 5;
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void clearFilters() => setState(() {
    searchController.clear();
    search = '';
    course = '';
    status = 'All';
    page = 0;
  });

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
      final matching = rows.where((row) {
        final lesson = recordMap(row['lesson']);
        final item = recordMap(row['course']);
        return (selectedCourse.isEmpty ||
                recordText(item['id']) == selectedCourse) &&
            '${lesson['title']} ${item['title']}'.toLowerCase().contains(
              search.trim().toLowerCase(),
            );
      }).toList();
      final matchingDone = matching.where(completed).length;
      final filtered = matching
          .where(
            (row) =>
                status == 'All' || (status == 'Completed') == completed(row),
          )
          .toList();
      final done = rows.where(completed).length;
      final pages = (filtered.length / pageSize).ceil().clamp(1, 1000000);
      final currentPage = page.clamp(0, pages - 1);
      final visible = filtered.skip(currentPage * pageSize).take(pageSize);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              const heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My progress',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'See your recorded lesson activity.',
                    style: TextStyle(fontSize: 17, color: muted),
                  ),
                ],
              );
              final actions = Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (widget.onQuran != null)
                    OutlinedButton.icon(
                      onPressed: widget.onQuran,
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text("Qur'an learning"),
                    ),
                  if (widget.onAssessments != null)
                    OutlinedButton.icon(
                      onPressed: widget.onAssessments,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Teacher assessments'),
                    ),
                ],
              );
              if (widget.onQuran == null && widget.onAssessments == null) {
                return heading;
              }
              if (box.maxWidth >= 1000 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 20) {
                return Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 24),
                    Flexible(child: actions),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 16), actions],
              );
            },
          ),
          const SizedBox(height: 16),
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
                      color: metric.$1 == 'Tracked lessons'
                          ? const Color(0xFFF0EDFF)
                          : metric.$1 == 'Completed'
                          ? const Color(0xFFE8F7EF)
                          : const Color(0xFFFFF6DF),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  metric.$1,
                                  style: const TextStyle(color: muted),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${metric.$2}',
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w700,
                                    color: metric.$3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: metric.$3.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              metric.$1 == 'Tracked lessons'
                                  ? Icons.layers_outlined
                                  : metric.$1 == 'Completed'
                                  ? Icons.check_circle_outline
                                  : Icons.menu_book_outlined,
                              size: 30,
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
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Recorded lesson progress',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lesson activity only. Course mastery and teacher assessments are shown separately.',
                  style: TextStyle(color: muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, box) {
                    final searchField = TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Search lessons or courses',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() {
                                  searchController.clear();
                                  search = '';
                                  page = 0;
                                }),
                              ),
                      ),
                      onChanged: (value) => setState(() {
                        search = value;
                        page = 0;
                      }),
                    );
                    final courseField = DropdownButtonFormField<String>(
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
                      onChanged: (value) => setState(() {
                        course = value ?? '';
                        page = 0;
                      }),
                    );
                    return box.maxWidth >= 760
                        ? Row(
                            children: [
                              Expanded(flex: 2, child: searchField),
                              const SizedBox(width: 20),
                              Expanded(child: courseField),
                            ],
                          )
                        : Column(
                            children: [
                              searchField,
                              const SizedBox(height: 16),
                              courseField,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in ['All', 'In progress', 'Completed'])
                      ChoiceChip(
                        label: Text(
                          '$value  ${value == 'All'
                              ? matching.length
                              : value == 'Completed'
                              ? matchingDone
                              : matching.length - matchingDone}',
                        ),
                        selected: status == value,
                        onSelected: (_) => setState(() {
                          status = value;
                          page = 0;
                        }),
                      ),
                    if (search.isNotEmpty ||
                        selectedCourse.isNotEmpty ||
                        status != 'All')
                      TextButton.icon(
                        onPressed: clearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Clear filters'),
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
                LayoutBuilder(
                  builder: (context, box) {
                    if (box.maxWidth >= 900 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 20) {
                      return Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.5),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F3F7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            children: [
                              for (final label in [
                                'Lesson',
                                'Recorded progress',
                                'Status',
                                '',
                              ])
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: ink,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          for (final row in visible)
                            TableRow(
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: line)),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color:
                                              (completed(row) ? forest : blue)
                                                  .withValues(alpha: .09),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.menu_book_outlined,
                                          color: completed(row) ? forest : blue,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              recordText(
                                                recordMap(
                                                  row['lesson'],
                                                )['title'],
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              recordText(
                                                recordMap(
                                                  row['course'],
                                                )['title'],
                                              ),
                                              style: const TextStyle(
                                                color: muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: LinearProgressIndicator(
                                            value:
                                                (recordNumber(
                                                          row['progressPercent'],
                                                        ) /
                                                        100)
                                                    .clamp(0, 1),
                                            color: completed(row)
                                                ? forest
                                                : gold,
                                            backgroundColor: line,
                                            minHeight: 9,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${recordNumber(row['progressPercent']).clamp(0, 100).round()}%',
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (completed(row) ? forest : gold)
                                            .withValues(alpha: .10),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        completed(row)
                                            ? 'Completed'
                                            : 'In progress',
                                        style: TextStyle(
                                          color: completed(row) ? forest : gold,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: completed(row)
                                      ? TextButton.icon(
                                          onPressed: () => open(row),
                                          icon: const Icon(
                                            Icons.arrow_forward,
                                            size: 20,
                                          ),
                                          label: const Text('Review lesson'),
                                        )
                                      : FilledButton.icon(
                                          onPressed: () => open(row),
                                          icon: const Icon(
                                            Icons.arrow_forward,
                                            size: 20,
                                          ),
                                          label: const Text('Continue lesson'),
                                        ),
                                ),
                              ],
                            ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        for (final row in visible) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: completed(row)
                                  ? const Color(0xFFF2FAF6)
                                  : const Color(0xFFFFFAEF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Icon(
                                      completed(row)
                                          ? Icons.check_circle_outline
                                          : Icons.timelapse,
                                      color: completed(row) ? forest : gold,
                                    ),
                                    Text(
                                      completed(row)
                                          ? 'Completed'
                                          : 'In progress',
                                      style: TextStyle(
                                        color: completed(row) ? forest : gold,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  recordText(recordMap(row['lesson'])['title']),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  recordText(recordMap(row['course'])['title']),
                                  style: const TextStyle(
                                    color: muted,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                LinearProgressIndicator(
                                  value:
                                      (recordNumber(row['progressPercent']) /
                                              100)
                                          .clamp(0, 1),
                                  color: completed(row) ? forest : gold,
                                  backgroundColor: line,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(8),
                                  semanticsLabel: 'Recorded lesson progress',
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
                                        completed(row)
                                            ? 'Review lesson'
                                            : 'Continue lesson',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
                if (filtered.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      Text(
                        'Showing ${currentPage * pageSize + 1}-${(currentPage * pageSize + pageSize).clamp(0, filtered.length)} of ${filtered.length} lessons',
                        style: const TextStyle(color: muted),
                      ),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: currentPage > 0
                                ? () => setState(() => page = currentPage - 1)
                                : null,
                            child: const Text('Previous'),
                          ),
                          if (MediaQuery.sizeOf(context).width >= 900 &&
                              MediaQuery.textScalerOf(context).scale(14) <= 20)
                            for (final number in {
                              0,
                              if (currentPage > 0) currentPage - 1,
                              currentPage,
                              if (currentPage + 1 < pages) currentPage + 1,
                              pages - 1,
                            }.toList()..sort())
                              Semantics(
                                selected: number == currentPage,
                                label: 'Page ${number + 1} of $pages',
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                    backgroundColor: number == currentPage
                                        ? ink
                                        : null,
                                    foregroundColor: number == currentPage
                                        ? Colors.white
                                        : ink,
                                  ),
                                  onPressed: () =>
                                      setState(() => page = number),
                                  child: Text('${number + 1}'),
                                ),
                              )
                          else
                            Text('${currentPage + 1} / $pages'),
                          OutlinedButton(
                            onPressed: currentPage + 1 < pages
                                ? () => setState(() => page = currentPage + 1)
                                : null,
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ],
                  ),
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
          const SizedBox(height: 16),
          const Text(
            'Opening media does not mark a lesson complete.',
            style: TextStyle(color: muted),
          ),
        ],
      );
    },
  );
}
