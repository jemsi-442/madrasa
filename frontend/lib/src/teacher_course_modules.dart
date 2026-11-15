import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'dashboard_components.dart';

class TeacherCourseModules extends StatelessWidget {
  const TeacherCourseModules({
    super.key,
    required this.course,
    required this.modules,
    required this.onOpen,
    this.onViewAll,
  });
  final Map<String, dynamic> course;
  final List<Map<String, dynamic>> modules;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final VoidCallback? onViewAll;

  num? total(String field) {
    final values = modules.map((m) => recordMap(m['stats'])[field]);
    return values.every((v) => v is num)
        ? values.cast<num>().fold<num>(0, (a, b) => a + b)
        : null;
  }

  static String duration(num? minutes) => minutes == null
      ? 'Not specified'
      : minutes >= 60
      ? '${minutes ~/ 60}h ${minutes.toInt() % 60}m'
      : '${minutes.toInt()} min';
  static const tones = [
    Color(0xFF0763CE),
    Color(0xFF009D50),
    Color(0xFFB37A05),
    Color(0xFF7140BE),
  ];
  static const backgrounds = [
    Color(0xFFE8F3FF),
    Color(0xFFEAF9F2),
    Color(0xFFFFF7E6),
    Color(0xFFF4EFFF),
  ];

  @override
  Widget build(BuildContext context) {
    final lessons = total('lessons');
    final resources = total('resources');
    final summary = recordText(course['summary'], '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.isNotEmpty) ...[
          Text(summary, style: const TextStyle(fontSize: 17, height: 1.5)),
          const SizedBox(height: 20),
        ],
        LayoutBuilder(
          builder: (context, box) {
            final availableWidth =
                box.maxWidth /
                (MediaQuery.textScalerOf(context).scale(17) / 17);
            final columns = availableWidth >= 1100
                ? 4
                : availableWidth >= 600
                ? 2
                : 1;
            final labels = [
              '${modules.length} ${modules.length == 1 ? 'module' : 'modules'}',
              lessons == null
                  ? 'Lessons unavailable'
                  : '$lessons ${lessons == 1 ? 'lesson' : 'lessons'}',
              resources == null
                  ? 'Resources unavailable'
                  : '$resources resources',
              duration(total('estimatedMinutes')),
            ];
            final icons = [
              Icons.layers_outlined,
              Icons.play_circle_outline,
              Icons.description_outlined,
              Icons.schedule,
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (var i = 0; i < 4; i++)
                  SizedBox(
                    width: (box.maxWidth - (columns - 1) * 16) / columns,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 112),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: backgrounds[i],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: tones[i].withValues(alpha: .10),
                            child: Icon(icons[i], color: tones[i], size: 36),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  labels[i],
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: AfaqDesign.ink,
                                  ),
                                ),
                                if (i == 3)
                                  const Text(
                                    'Estimated duration',
                                    style: TextStyle(fontSize: 14),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: Color(0xFFE4E9F1)),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 30,
                  color: AfaqDesign.actionGold,
                ),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Course Modules',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            if (onViewAll != null)
              TextButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: const Text('View all modules'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final availableWidth =
                box.maxWidth /
                (MediaQuery.textScalerOf(context).scale(16) / 16);
            final columns = availableWidth >= 1500
                ? 4
                : availableWidth >= 1100
                ? 3
                : availableWidth >= 600
                ? 2
                : 1;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var i = 0; i < modules.length; i++)
                  SizedBox(
                    width: (box.maxWidth - (columns - 1) * 16) / columns,
                    child: _module(modules[i], i),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _module(Map<String, dynamic> module, int index) {
    final stats = recordMap(module['stats']);
    final tone = tones[index % tones.length];
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E6EF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('teacher-course-item-${module['id']}'),
        onTap: () => onOpen(module),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgrounds[index % backgrounds.length],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.layers_outlined, color: tone, size: 36),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Module ${index + 1}',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_circle_right_outlined,
                          size: 28,
                          color: AfaqDesign.ink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      recordText(module['title']),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (stats['lessons'] is num)
                          _badge(
                            Icons.play_circle_outline,
                            '${stats['lessons']} ${stats['lessons'] == 1 ? 'lesson' : 'lessons'}',
                            tone,
                          ),
                        if (stats['resources'] is num)
                          _badge(
                            Icons.description_outlined,
                            '${stats['resources']} ${stats['resources'] == 1 ? 'resource' : 'resources'}',
                            tone,
                          ),
                        if (stats['estimatedMinutes'] is num)
                          _badge(
                            Icons.schedule,
                            '${duration(stats['estimatedMinutes'])} estimated',
                            tone,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'View lessons',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AfaqDesign.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color tone) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: tone),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AfaqDesign.ink),
          ),
        ),
      ],
    ),
  );
}
