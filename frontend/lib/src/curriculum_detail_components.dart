import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Read-only curriculum presentation. Mutations stay with the page callbacks.
class CurriculumDetailPanel extends StatelessWidget {
  const CurriculumDetailPanel({
    super.key,
    required this.title,
    required this.child,
    this.icon = Icons.menu_book_outlined,
    this.accent = AfaqDesign.blue,
  });

  final String title;
  final Widget child;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    decoration: AfaqDesign.panelDecoration(),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          color: AfaqDesign.cardTint(accent, .09),
          child: Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AfaqDesign.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(18), child: child),
      ],
    ),
  );
}

class CurriculumDetailField extends StatelessWidget {
  const CurriculumDetailField({
    super.key,
    required this.label,
    required this.value,
  });
  final String label, value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AfaqDesign.muted,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value.trim().isEmpty ? 'Not specified' : value,
        style: const TextStyle(
          fontSize: 16,
          height: 1.55,
          color: AfaqDesign.ink,
        ),
      ),
    ],
  );
}

class CurriculumDetailTag extends StatelessWidget {
  const CurriculumDetailTag(
    this.text, {
    super.key,
    this.accent = AfaqDesign.blue,
  });
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AfaqDesign.cardTint(accent, .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: accent,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );
}

class SchoolCurriculumDetail extends StatelessWidget {
  const SchoolCurriculumDetail({
    super.key,
    required this.assignment,
    required this.isAdmin,
    required this.openLessons,
    required this.onHistory,
    required this.onRecord,
    required this.historyDate,
    required this.historySummary,
    this.onAdopt,
    this.adoptionMessage,
  });

  final Map assignment;
  final bool isAdmin, openLessons;
  final ValueChanged<Map> onHistory, onRecord;
  final String Function(dynamic) historyDate;
  final String Function(Map<String, dynamic>) historySummary;
  final VoidCallback? onAdopt;
  final String? adoptionMessage;

  @override
  Widget build(BuildContext context) {
    final version = assignment['version'] as Map;
    final adoptions = assignment['adoptions'] as List;
    final topics = version['topics'] as List;
    final lessons = version['lessons'] as List;
    final classes = CurriculumDetailPanel(
      title: 'Class adoption',
      icon: Icons.school_outlined,
      accent: AfaqDesign.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (adoptions.isEmpty)
            const Text(
              'Available to the madrasa; not adopted in any class in your scope.',
            ),
          for (final adoption in adoptions) ...[
            Text(
              '${adoption['class']['name']}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AfaqDesign.ink,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CurriculumDetailTag('${adoption['class']['academicYear']}'),
                CurriculumDetailTag(
                  '${adoption['subject']['name']}',
                  accent: AfaqDesign.green,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Current curriculum: v${version['version']}${historyDate(adoption['createdAt']).isEmpty ? '' : ' · in use since ${historyDate(adoption['createdAt'])}'}',
              style: const TextStyle(color: AfaqDesign.muted, height: 1.5),
            ),
            if (adoption['teachingCoverage'] is Map) ...[
              const SizedBox(height: 18),
              Text(
                'Teaching coverage: ${adoption['teachingCoverage']['taughtLessons']} / ${adoption['teachingCoverage']['totalLessons']} lessons',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if ((adoption['teachingCoverage']['totalLessons'] as num) > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                    color: AfaqDesign.green,
                    backgroundColor: AfaqDesign.cardTint(AfaqDesign.green, .12),
                    value:
                        ((adoption['teachingCoverage']['taughtLessons']
                                    as num) /
                                (adoption['teachingCoverage']['totalLessons']
                                    as num))
                            .clamp(0.0, 1.0),
                  ),
                ),
              const Text(
                'Current version only. Teacher-reported teaching, not learner achievement.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AfaqDesign.muted,
                ),
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => onHistory(adoption),
              icon: const Icon(Icons.history),
              label: const Text('Teaching history'),
            ),
            for (final history in adoption['history'] as List) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AfaqDesign.canvas,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  historySummary(Map<String, dynamic>.from(history)),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AfaqDesign.muted,
                  ),
                ),
              ),
            ],
            if (adoption != adoptions.last) const Divider(height: 36),
          ],
          if (isAdmin) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdopt,
              icon: const Icon(Icons.school_outlined),
              label: const Text('Use in a class'),
            ),
            if (adoptionMessage != null) ...[
              const SizedBox(height: 12),
              Text(adoptionMessage!, style: const TextStyle(height: 1.5)),
            ],
          ],
        ],
      ),
    );
    final plans = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          title: 'Shared lesson plans',
          id: 'lessons',
          count: lessons.length,
          icon: Icons.auto_stories_outlined,
          expanded: !isAdmin && openLessons,
          children: [
            if (lessons.isEmpty)
              const Text('No shared lesson plans in this version.'),
            if (lessons.isNotEmpty)
              CurriculumLessonPlansBrowser(
                key: ValueKey('${assignment['id']}-${version['id']}'),
                lessons: lessons,
                buildLesson: (i) => CurriculumDetailPanel(
                  title: '${lessons[i]['title']}',
                  accent: AfaqDesign.actionGold,
                  icon: Icons.menu_book_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          CurriculumDetailTag(
                            'Lesson ${i + 1}',
                            accent: AfaqDesign.actionGold,
                          ),
                          CurriculumDetailTag(
                            '${lessons[i]['durationMinutes']} min',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      CurriculumDetailField(
                        label: 'Teaching activities',
                        value: '${lessons[i]['activities'] ?? ''}',
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Linked learning objectives',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      if ((lessons[i]['objectives'] as List).isEmpty)
                        const Text(
                          'No learning objectives linked.',
                          style: TextStyle(color: AfaqDesign.muted),
                        ),
                      for (final link in lessons[i]['objectives'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CurriculumDetailField(
                            label: '${link['objective']['code']}',
                            value: '${link['objective']['description']}',
                          ),
                        ),
                      if (!isAdmin &&
                          lessons[i]['id'] != null &&
                          adoptions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: () => onRecord(lessons[i]),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Record lesson taught'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _section(
          title: 'Topics & objectives',
          id: 'topics',
          count: topics.length,
          icon: Icons.layers_outlined,
          expanded: !isAdmin && !openLessons,
          children: [
            if (topics.isEmpty) const Text('No topics in this version.'),
            for (var i = 0; i < topics.length; i++) ...[
              CurriculumTopicDetail(
                key: PageStorageKey(
                  '${assignment['id']}-topic-${topics[i]['id'] ?? i}',
                ),
                topic: topics[i],
                number: i + 1,
                initiallyExpanded: i == 0,
              ),
              if (i < topics.length - 1) const SizedBox(height: 16),
            ],
          ],
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AfaqDesign.panelDecoration(color: AfaqDesign.paper),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CurriculumDetailTag('${version['level']}'),
                  CurriculumDetailTag(
                    'Version ${version['version']}',
                    accent: AfaqDesign.actionGold,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${version['subject']}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AfaqDesign.ink,
                ),
              ),
              if ('${version['description'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Text(
                    '${version['description']}',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: AfaqDesign.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 1000) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isAdmin) ...[classes, const SizedBox(height: 20)],
                  plans,
                  if (!isAdmin) ...[const SizedBox(height: 20), classes],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: plans),
                const SizedBox(width: 24),
                Expanded(flex: 3, child: classes),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required String id,
    required int count,
    required IconData icon,
    required bool expanded,
    required List<Widget> children,
  }) => Container(
    decoration: AfaqDesign.panelDecoration(),
    child: ExpansionTile(
      key: PageStorageKey('${assignment['id']}-$id-$openLessons'),
      maintainState: true,
      initiallyExpanded: expanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(icon, color: AfaqDesign.actionGold),
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '$count ${id == 'topics' ? 'topics' : 'lesson plans'}',
        style: const TextStyle(color: AfaqDesign.muted, fontSize: 13),
      ),
      children: children,
    ),
  );
}

class CurriculumLessonPlansBrowser extends StatefulWidget {
  const CurriculumLessonPlansBrowser({
    super.key,
    required this.lessons,
    required this.buildLesson,
  });

  final List lessons;
  final Widget Function(int index) buildLesson;

  @override
  State<CurriculumLessonPlansBrowser> createState() =>
      _CurriculumLessonPlansBrowserState();
}

class _CurriculumLessonPlansBrowserState
    extends State<CurriculumLessonPlansBrowser> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final terms = query.split(RegExp(r'\s+'));
    final matches = <int>[];
    for (var i = 0; i < widget.lessons.length; i++) {
      final lesson = widget.lessons[i] as Map;
      final text = [
        lesson['title'] ?? '',
        lesson['activities'] ?? '',
        for (final link in lesson['objectives'] as List) ...[
          link['objective']['code'] ?? '',
          link['objective']['description'] ?? '',
        ],
      ].join(' ').toLowerCase();
      if (query.isEmpty || terms.every(text.contains)) matches.add(i);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const PageStorageKey('curriculum-lesson-search'),
          controller: search,
          maxLength: 100,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Find a lesson plan',
            hintText: 'Lesson, activity or objective code',
            counterText: '',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear lesson search',
                    onPressed: () => setState(search.clear),
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text(
          'Showing ${matches.length} of ${widget.lessons.length} lesson plans',
          style: const TextStyle(color: AfaqDesign.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (matches.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AfaqDesign.panelDecoration(),
            child: const Column(
              children: [
                Icon(Icons.search_off, color: AfaqDesign.muted, size: 32),
                SizedBox(height: 12),
                Text(
                  'No matching lesson plans',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Try another word or clear the search.',
                  style: TextStyle(color: AfaqDesign.muted, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        for (final index in matches) ...[
          KeyedSubtree(
            key: ValueKey(widget.lessons[index]['id'] ?? index),
            child: widget.buildLesson(index),
          ),
          if (index != matches.last) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class CurriculumTopicDetail extends StatelessWidget {
  const CurriculumTopicDetail({
    super.key,
    required this.topic,
    required this.number,
    this.initiallyExpanded = false,
  });

  final Map topic;
  final int number;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final objectives = topic['objectives'] as List;
    return Container(
      decoration: AfaqDesign.panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        collapsedBackgroundColor: AfaqDesign.cardTint(AfaqDesign.blue, .06),
        leading: CircleAvatar(
          backgroundColor: AfaqDesign.cardTint(AfaqDesign.blue, .12),
          foregroundColor: AfaqDesign.blue,
          child: Text('$number'),
        ),
        title: Text(
          '${topic['title']}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AfaqDesign.ink,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${objectives.length} learning ${objectives.length == 1 ? 'objective' : 'objectives'}',
            style: const TextStyle(color: AfaqDesign.muted, fontSize: 13),
          ),
        ),
        children: [
          if (objectives.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No objectives in this topic.'),
            ),
          for (var i = 0; i < objectives.length; i++) ...[
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: CurriculumDetailTag('${objectives[i]['code']}'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${objectives[i]['description']}',
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                  color: AfaqDesign.ink,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AfaqDesign.canvas,
                borderRadius: BorderRadius.circular(8),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final method = CurriculumDetailField(
                    label: 'Assessment method',
                    value: '${objectives[i]['assessmentMethod'] ?? ''}',
                  );
                  final criteria = CurriculumDetailField(
                    label: 'Success criteria',
                    value: '${objectives[i]['criteria'] ?? ''}',
                  );
                  if (constraints.maxWidth < 640 ||
                      MediaQuery.textScalerOf(context).scale(16) > 20) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [method, const SizedBox(height: 20), criteria],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: method),
                      const SizedBox(width: 28),
                      Expanded(child: criteria),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
