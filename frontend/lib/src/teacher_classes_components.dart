import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';

class TeacherClassesBanner extends StatelessWidget {
  const TeacherClassesBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [AfaqDesign.ink, Color(0xFF184E67)],
      ),
    ),
    child: LayoutBuilder(
      builder: (context, box) => Row(
        children: [
          if (box.maxWidth >= 500) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AfaqDesign.actionGold,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.groups_outlined,
                size: 38,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 24),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Classes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: box.maxWidth < 500 ? 28 : 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your teaching groups, courses and weekly timetable.',
                  style: TextStyle(
                    color: Color(0xFFDCE8EF),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class TeacherClassQuickActions extends StatelessWidget {
  const TeacherClassQuickActions({super.key, required this.onOpen});
  final TeacherNavigate onOpen;

  @override
  Widget build(BuildContext context) => SurfacePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Quick actions',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: AfaqDesign.ink,
          ),
        ),
        const SizedBox(height: 18),
        for (final (label, icon, page, color) in [
          (
            'Record attendance',
            Icons.calendar_month_outlined,
            4,
            AfaqDesign.blue,
          ),
          (
            'Manage my courses',
            Icons.menu_book_outlined,
            5,
            AfaqDesign.actionGold,
          ),
          ('View curriculum', Icons.layers_outlined, 10, AfaqDesign.green),
          ('Class reports', Icons.bar_chart_outlined, 9, AfaqDesign.actionGold),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: color.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                leading: Icon(icon, color: color),
                title: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => onOpen(page),
              ),
            ),
          ),
      ],
    ),
  );
}
