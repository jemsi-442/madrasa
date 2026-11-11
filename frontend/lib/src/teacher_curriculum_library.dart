import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// A read-only library of the published versions returned for this teacher.
class TeacherCurriculumLibrary extends StatefulWidget {
  const TeacherCurriculumLibrary({
    super.key,
    required this.assignments,
    required this.onOpen,
  });

  final List<Map> assignments;
  final void Function(Map assignment, bool lessons) onOpen;

  @override
  State<TeacherCurriculumLibrary> createState() =>
      _TeacherCurriculumLibraryState();
}

class _TeacherCurriculumLibraryState extends State<TeacherCurriculumLibrary> {
  final search = TextEditingController();
  String? year;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<Map> adoptions(Map assignment, String? selectedYear) =>
      (assignment['adoptions'] as List).cast<Map>().where((adoption) {
        return selectedYear == null ||
            '${adoption['class']['academicYear']}' == selectedYear;
      }).toList();

  @override
  Widget build(BuildContext context) {
    if (widget.assignments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: _CurriculumBanner(),
      );
    }
    final years = <String>{
      for (final item in widget.assignments)
        for (final adoption in item['adoptions'] as List)
          if (adoption['class']['academicYear'] != null)
            '${adoption['class']['academicYear']}',
    }.toList()..sort((a, b) => b.compareTo(a));
    final selectedYear = years.contains(year) ? year : null;
    final query = search.text.trim().toLowerCase();
    final scoped = widget.assignments
        .where(
          (item) =>
              selectedYear == null || adoptions(item, selectedYear).isNotEmpty,
        )
        .toList();
    final visible = scoped.where((item) {
      final version = item['version'] as Map;
      final searchable = [
        version['subject'],
        version['level'],
        version['description'],
        for (final topic in version['topics'] as List) topic['title'],
        for (final lesson in version['lessons'] as List) lesson['title'],
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
    final subjects = scoped
        .map((item) => '${item['version']['subject']}')
        .toSet();
    final topics = scoped.fold<int>(
      0,
      (sum, item) => sum + (item['version']['topics'] as List).length,
    );
    final lessons = scoped.fold<int>(
      0,
      (sum, item) => sum + (item['version']['lessons'] as List).length,
    );
    final objectives = scoped.fold<int>(
      0,
      (sum, item) =>
          sum +
          (item['version']['topics'] as List).fold<int>(
            0,
            (total, topic) => total + (topic['objectives'] as List).length,
          ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CurriculumBanner(),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 420
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final stat in [
                  (
                    'Assigned subjects',
                    subjects.length,
                    Icons.menu_book_rounded,
                    AfaqDesign.blue,
                  ),
                  ('Topics', topics, Icons.layers_outlined, AfaqDesign.green),
                  (
                    'Lessons',
                    lessons,
                    Icons.play_circle_outline,
                    AfaqDesign.actionGold,
                  ),
                  (
                    'Learning objectives',
                    objectives,
                    Icons.flag_outlined,
                    AfaqDesign.purple,
                  ),
                ])
                  Container(
                    width: width,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: AfaqDesign.cardGradient(stat.$4),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: stat.$4.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(stat.$3, size: 32, color: stat.$4),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stat.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AfaqDesign.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${stat.$2}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: AfaqDesign.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        const Row(
          children: [
            Icon(
              Icons.menu_book_outlined,
              color: AfaqDesign.actionGold,
              size: 32,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'My Assigned Curriculum',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AfaqDesign.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final input = TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Search curriculum',
                hintText: 'Subject, topic or lesson',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () => setState(search.clear),
                        icon: const Icon(Icons.close),
                      ),
              ),
            );
            final yearsInput = DropdownButtonFormField<String>(
              key: ValueKey(selectedYear),
              initialValue: selectedYear ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Academic year',
                prefixIcon: Icon(Icons.calendar_month_outlined),
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('All academic years'),
                ),
                for (final value in years)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: (value) =>
                  setState(() => year = value == '' ? null : value),
            );
            return constraints.maxWidth < 650
                ? Column(
                    children: [input, const SizedBox(height: 16), yearsInput],
                  )
                : Row(
                    children: [
                      Expanded(child: input),
                      const SizedBox(width: 20),
                      SizedBox(width: 270, child: yearsInput),
                    ],
                  );
          },
        ),
        const SizedBox(height: 22),
        if (visible.isEmpty && widget.assignments.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: AfaqDesign.panelDecoration(),
            child: Column(
              children: [
                const Icon(Icons.search_off, size: 36, color: AfaqDesign.muted),
                const SizedBox(height: 12),
                const Text('No curriculum matches these filters.'),
                TextButton(
                  onPressed: () => setState(() {
                    search.clear();
                    year = null;
                  }),
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1200
                ? 3
                : constraints.maxWidth >= 760
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 24) / columns;
            return Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                for (final item in visible)
                  SizedBox(
                    width: width,
                    child: _CurriculumCard(
                      assignment: item,
                      adoptions: adoptions(item, selectedYear),
                      onOpen: (lessons) => widget.onOpen(item, lessons),
                    ),
                  ),
              ],
            );
          },
        ),
        if (visible.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            'Teaching coverage is recorded per class, not learner achievement.',
            style: TextStyle(color: AfaqDesign.muted, fontSize: 14),
          ),
        ],
      ],
    );
  }
}

class _CurriculumBanner extends StatelessWidget {
  const _CurriculumBanner();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: LayoutBuilder(
      builder: (context, constraints) => Container(
        constraints: const BoxConstraints(minHeight: 190),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AfaqDesign.ink, Color(0xFF184E67)]),
        ),
        child: Stack(
          children: [
            if (constraints.maxWidth > 700)
              Positioned.fill(
                left: constraints.maxWidth * .61,
                child: Image.asset(
                  'assets/learning-hero.png',
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AfaqDesign.ink,
                      AfaqDesign.ink.withValues(alpha: .92),
                      AfaqDesign.ink.withValues(alpha: .08),
                    ],
                    stops: const [0, .57, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(constraints.maxWidth < 600 ? 24 : 36),
              child: SizedBox(
                width: constraints.maxWidth > 700
                    ? constraints.maxWidth * .61
                    : double.infinity,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book, color: Color(0xFFE8BC58)),
                        SizedBox(width: 12),
                        Text(
                          'CURRICULUM',
                          style: TextStyle(
                            color: Color(0xFFE8BC58),
                            letterSpacing: 2,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'My Curriculum',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Your subjects, lesson plans and teaching progress in one place.',
                      style: TextStyle(
                        color: Color(0xFFDCE8EF),
                        fontSize: 17,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CurriculumCard extends StatelessWidget {
  const _CurriculumCard({
    required this.assignment,
    required this.adoptions,
    required this.onOpen,
  });
  final Map assignment;
  final List<Map> adoptions;
  final ValueChanged<bool> onOpen;

  @override
  Widget build(BuildContext context) {
    final version = assignment['version'] as Map;
    final subject = '${version['subject']}';
    final name = subject.toLowerCase();
    final icon = name.contains('arabic')
        ? Icons.translate
        : name.contains('fiqh')
        ? Icons.balance_outlined
        : Icons.menu_book_rounded;
    final accent = name.contains('arabic')
        ? AfaqDesign.green
        : name.contains('fiqh')
        ? AfaqDesign.actionGold
        : AfaqDesign.blue;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AfaqDesign.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 136,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AfaqDesign.ink, accent]),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(icon, size: 76, color: const Color(0xFFE8BC58)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5D27A),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${version['level']}',
                    style: const TextStyle(
                      color: AfaqDesign.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AfaqDesign.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${version['description'] ?? ''}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AfaqDesign.muted, height: 1.5),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _count(
                      Icons.layers_outlined,
                      '${(version['topics'] as List).length} topics',
                    ),
                    _count(
                      Icons.play_circle_outline,
                      '${(version['lessons'] as List).length} lessons',
                    ),
                    _count(
                      Icons.school_outlined,
                      '${adoptions.length} classes',
                    ),
                  ],
                ),
                const Divider(height: 30),
                for (final adoption in adoptions) ...[
                  Text(
                    '${adoption['class']['name']} (${adoption['class']['academicYear']})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AfaqDesign.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (adoption['teachingCoverage'] case final Map coverage) ...[
                    Text(
                      'Taught ${coverage['taughtLessons']} of ${coverage['totalLessons']} lessons',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AfaqDesign.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (coverage['totalLessons'] as num) > 0
                          ? ((coverage['taughtLessons'] as num) /
                                    (coverage['totalLessons'] as num))
                                .clamp(0.0, 1.0)
                          : 0,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(8),
                      color: AfaqDesign.green,
                      backgroundColor: const Color(0xFFE8EDF3),
                    ),
                  ] else
                    const Text(
                      'Teaching coverage unavailable',
                      style: TextStyle(fontSize: 13, color: AfaqDesign.muted),
                    ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Published version ${version['version']}',
                  style: const TextStyle(fontSize: 13, color: AfaqDesign.muted),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => onOpen(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AfaqDesign.actionGold,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(150, 48),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('View lessons'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onOpen(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(140, 48),
                      ),
                      icon: const Icon(Icons.event_note_outlined),
                      label: const Text('Lesson plan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _count(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 19, color: AfaqDesign.ink),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: AfaqDesign.ink, fontSize: 13)),
    ],
  );
}
