import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'dashboard_components.dart';

class TeacherCourseModules extends StatelessWidget {
  const TeacherCourseModules({
    super.key,
    required this.course,
    required this.modules,
    required this.onOpen,
  });
  final Map<String, dynamic> course;
  final List<Map<String, dynamic>> modules;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    final summary = recordText(course['summary'], '');
    final counts = modules
        .map((m) => recordMap(m['stats'])['lessons'])
        .toList();
    final hasCounts = counts.every((count) => count is num);
    final lessons = counts.whereType<num>().fold<num>(
      0,
      (sum, count) => sum + count,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.isNotEmpty) ...[
          Text(
            summary,
            style: const TextStyle(
              fontSize: 17,
              height: 1.6,
              color: AfaqDesign.ink,
            ),
          ),
          const SizedBox(height: 20),
        ],
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 560 && hasCounts ? 2 : 1;
            final width = (box.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _stat(
                    Icons.layers_outlined,
                    '${modules.length} ${modules.length == 1 ? 'module' : 'modules'}',
                    const Color(0xFFEAF2FC),
                  ),
                ),
                if (hasCounts)
                  SizedBox(
                    width: width,
                    child: _stat(
                      Icons.play_circle_outline,
                      '$lessons ${lessons == 1 ? 'lesson' : 'lessons'}',
                      const Color(0xFFE8F6EE),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Course Modules',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final availableColumns = box.maxWidth >= 1200
                ? 4
                : box.maxWidth >= 700
                ? 2
                : 1;
            final columns = modules.isEmpty
                ? 1
                : availableColumns.clamp(1, modules.length);
            final width = (box.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var index = 0; index < modules.length; index++)
                  SizedBox(width: width, child: _module(modules[index], index)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AfaqDesign.ink),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _module(Map<String, dynamic> module, int index) {
    final summary = recordText(module['summary'], '');
    final count = recordMap(module['stats'])['lessons'];
    final colors = [
      const Color(0xFFEAF2FC),
      const Color(0xFFE8F6EE),
      const Color(0xFFFFF3D7),
    ];
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDDE5ED)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('teacher-course-item-${module['id']}'),
        onTap: () => onOpen(module),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.layers_outlined,
                      size: 28,
                      color: AfaqDesign.ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Module ${index + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                recordText(module['title']),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  summary,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (count is num) Text('$count lessons'),
                  const Text(
                    'View lessons',
                    style: TextStyle(
                      color: AfaqDesign.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
