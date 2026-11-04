import 'design_tokens.dart';
import 'package:flutter/material.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';

class LessonContents extends StatelessWidget {
  const LessonContents({
    super.key,
    required this.lessons,
    required this.currentId,
    required this.progress,
    required this.onSelect,
  });
  final List<Map<String, dynamic>> lessons;
  final String currentId;
  final Map<String, Map<String, dynamic>> progress;
  final ValueChanged<Map<String, dynamic>>? onSelect;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final lesson in lessons) {
      final group = recordText(
        lesson['moduleId'],
        recordText(lesson['moduleTitle'], 'Lessons'),
      );
      (groups[group] ??= []).add(lesson);
    }
    int percent(Map<String, dynamic> lesson) => recordNumber(
      (progress[recordText(lesson['id'])] ??
          recordMap(lesson['progress']))['progressPercent'],
    ).toInt();
    final completed = lessons.where((lesson) => percent(lesson) >= 100).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '$completed of ${lessons.length} lessons complete',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            value: lessons.isEmpty ? 0 : completed / lessons.length,
            minHeight: 4,
            color: forest,
            backgroundColor: line,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in groups.entries)
          _LessonGroup(
            collapsible: groups.length > 1,
            key: ValueKey('module-${entry.key}-$currentId'),
            initiallyExpanded: entry.value.any(
              (lesson) => recordText(lesson['id']) == currentId,
            ),
            title: Text(
              recordText(entry.value.first['moduleTitle'], 'Lessons'),
              style: const TextStyle(
                color: ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            children: [
              for (final lesson in entry.value)
                Builder(
                  builder: (context) {
                    final active = recordText(lesson['id']) == currentId;
                    final allowed = [
                      'OPEN',
                      'PREVIEW',
                    ].contains(lesson['accessState']);
                    final done = percent(lesson) >= 100;
                    final minutes = recordNumber(lesson['estimatedMinutes']);
                    final status = !allowed
                        ? 'Access required'
                        : done
                        ? 'Completed'
                        : active
                        ? 'Current lesson'
                        : percent(lesson) > 0
                        ? '${percent(lesson)}% recorded'
                        : 'Not started';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Semantics(
                        selected: active,
                        child: OutlinedButton(
                          key: ValueKey('outline-lesson-${lesson['id']}'),
                          onPressed: onSelect != null && allowed && !active
                              ? () => onSelect!(lesson)
                              : null,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: active
                                ? gold.withValues(alpha: .12)
                                : Colors.white,
                            disabledForegroundColor: active ? ink : muted,
                            foregroundColor: ink,
                            padding: const EdgeInsets.all(12),
                            side: BorderSide(
                              color: active
                                  ? gold.withValues(alpha: .45)
                                  : line,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 22,
                                child: Text(
                                  '${lessons.indexOf(lesson) + 1}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Icon(
                                !allowed
                                    ? Icons.lock_outline
                                    : done
                                    ? Icons.check_circle
                                    : active
                                    ? Icons.play_circle_filled
                                    : Icons.radio_button_unchecked,
                                size: AfaqDesign.iconSmall,
                                color: !allowed
                                    ? muted
                                    : done
                                    ? forest
                                    : active
                                    ? gold
                                    : muted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recordText(lesson['title']),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          status,
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (minutes > 0)
                                          Text(
                                            '$minutes min estimated',
                                            style: const TextStyle(
                                              color: muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _LessonGroup extends StatelessWidget {
  const _LessonGroup({
    super.key,
    required this.collapsible,
    required this.initiallyExpanded,
    required this.title,
    required this.children,
  });

  final bool collapsible, initiallyExpanded;
  final Widget title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => collapsible
      ? ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: title,
          children: children,
        )
      : Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
}
