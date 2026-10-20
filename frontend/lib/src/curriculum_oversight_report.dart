import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'dashboard_components.dart' show StatusPill;
import 'workspace_form_dialog.dart';

/// A page-scoped snapshot, not institution totals or learner assessment.
class CurriculumOversightReport extends StatelessWidget {
  const CurriculumOversightReport({
    super.key,
    required this.rows,
    this.showSummary = true,
    this.summaryOnly = false,
    this.assessments,
  });
  final List rows;
  final bool showSummary, summaryOnly;
  final Map? assessments;

  int count(Map row, String key) => (row[key] as num?)?.toInt() ?? 0;
  int total(String key) =>
      rows.fold(0, (sum, row) => sum + count(row as Map, key));

  Widget panel(Widget child) => Container(
    decoration: AfaqDesign.panelDecoration(),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget metric(
    BuildContext context,
    String title,
    int value,
    IconData icon,
    Color color,
  ) => panel(
    Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AfaqDesign.muted)),
                const SizedBox(height: 12),
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AfaqDesign.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'On this page',
                  style: TextStyle(fontSize: 13, color: AfaqDesign.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ],
      ),
    ),
  );

  Widget coverage(BuildContext context, Map row) {
    final planned = count(row, 'plannedClassLessons');
    final taught = count(row, 'taughtClassLessons');
    final adopted = count(row, 'adoptedClasses');
    final String nextStep;
    if (adopted == 0) {
      nextStep =
          'Awaiting class adoption. The madrasa administrator must link this framework to a class.';
    } else if (planned == 0) {
      nextStep =
          'No planned class-lessons. Check the adopted version and its lesson content.';
    } else if (taught == 0) {
      nextStep =
          'Awaiting teaching records. Assigned teachers record lessons after teaching.';
    } else if (taught < planned) {
      nextStep =
          'Teaching records are in progress. Follow up with the responsible madrasa on remaining lessons.';
    } else {
      nextStep =
          'All planned class-lessons have teaching records. This does not confirm learner achievement.';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$taught / $planned class-lessons recorded as taught'),
        const SizedBox(height: 10),
        if (planned > 0)
          Semantics(
            label: 'Teacher-reported teaching coverage',
            value: '${(100 * taught / planned).round()} percent',
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (taught / planned).clamp(0.0, 1.0),
                    color: AfaqDesign.blue,
                    backgroundColor: AfaqDesign.tableHeader,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(100 * taught / planned).round()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AfaqDesign.blue,
                  ),
                ),
              ],
            ),
          )
        else
          const Text(
            'Teaching coverage is not applicable without adopted classes and planned lessons.',
            style: TextStyle(color: AfaqDesign.muted),
          ),
        const SizedBox(height: 10),
        Text(
          '${count(row, 'pendingClassLessons')} class-lessons without teaching records',
          style: const TextStyle(fontSize: 13, color: AfaqDesign.muted),
        ),
        const SizedBox(height: 10),
        Text(nextStep, style: const TextStyle(color: AfaqDesign.ink)),
      ],
    );
  }

  Widget reportRow(BuildContext context, Map row, bool wide) {
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${row['madrasa']}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AfaqDesign.ink,
          ),
        ),
        const SizedBox(height: 8),
        StatusPill('${row['madrasaStatus'] ?? 'UNKNOWN'}'),
        const SizedBox(height: 6),
        Text(
          '${row['subject']} / ${row['level'] ?? 'Level not set'} / v${row['version']}',
          style: const TextStyle(color: AfaqDesign.muted),
        ),
        const SizedBox(height: 8),
        Text(
          '${count(row, 'adoptedClasses')} class adoption records',
          style: const TextStyle(fontSize: 13, color: AfaqDesign.muted),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AfaqDesign.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: identity),
                const SizedBox(width: 24),
                Expanded(child: coverage(context, row)),
              ],
            )
          else ...[
            identity,
            const SizedBox(height: 16),
            coverage(context, row),
          ],
          if (row['subjectActive'] != true) ...[
            const SizedBox(height: 12),
            const Text(
              'School subject is inactive or not linked. Adoption records do not confirm current teaching access.',
              style: TextStyle(color: AfaqDesign.actionGold, fontSize: 13),
            ),
          ],
          if (row['madrasaStatus'] != 'ACTIVE' &&
              row['madrasaStatus'] != 'TRIAL') ...[
            const SizedBox(height: 8),
            const Text(
              'Madrasa is not active. Records are retained for oversight, not evidence of current access.',
              style: TextStyle(color: AfaqDesign.actionGold, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget table(BuildContext context) => panel(
    LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teaching record coverage',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'One row per assigned framework. Not an attainment ranking.',
                  style: TextStyle(color: AfaqDesign.muted),
                ),
              ],
            ),
          ),
          if (constraints.maxWidth >= 560)
            Container(
              color: AfaqDesign.tableHeader,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: const Row(
                children: [
                  Expanded(child: Text('Madrasa / framework')),
                  SizedBox(width: 24),
                  Expanded(child: Text('Teaching coverage')),
                ],
              ),
            ),
          for (final row in rows)
            reportRow(context, row as Map, constraints.maxWidth >= 560),
        ],
      ),
    ),
  );

  Widget quranPanel(BuildContext context) => panel(
    Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            color: AfaqDesign.gold,
            size: 28,
          ),
          const SizedBox(height: 16),
          Text(
            "Qur'an learning oversight",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          const WorkspaceFormNotice(
            message:
                'Not connected to this report yet. No passage assessment totals are available here.',
          ),
          const SizedBox(height: 20),
          for (final label in ['Recitation', 'Hifz', 'Revision']) ...[
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            const Text(
              'Requires verified passage assessment records.',
              style: TextStyle(color: AfaqDesign.muted),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(),
            ),
          ],
          const Text(
            "A Qur'an framework assignment is not evidence of recitation, memorisation or mastery. These outcomes must be tracked separately.",
            style: TextStyle(color: AfaqDesign.muted),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000
          ? 4
          : constraints.maxWidth >= 600
          ? 2
          : 1;
      final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
      final metrics = [
        metric(
          context,
          'Framework assignments',
          rows.length,
          Icons.menu_book_outlined,
          AfaqDesign.blue,
        ),
        metric(
          context,
          'Class adoption records',
          total('adoptedClasses'),
          Icons.school_outlined,
          AfaqDesign.green,
        ),
        metric(
          context,
          'Class-lessons taught',
          total('taughtClassLessons'),
          Icons.check_circle_outline,
          AfaqDesign.blue,
        ),
        metric(
          context,
          'Without teaching records',
          total('pendingClassLessons'),
          Icons.schedule,
          AfaqDesign.gold,
        ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showSummary) ...[
            const Text(
              'This page only · All-time snapshot',
              style: TextStyle(color: AfaqDesign.muted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final item in metrics) SizedBox(width: width, child: item),
              ],
            ),
            const SizedBox(height: 24),
          ],
          if (!summaryOnly) ...[
            if (assessments != null) ...[
              panel(
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Published classroom assessments',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${count(assessments!, 'publishedAssessments')} assessments across ${count(assessments!, 'classSubjectScopes')} class-subject combinations',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All-time, for current class adoptions on this page only. Each assessment is counted once if it has a non-retracted published release. Draft-only and fully retracted assessments are excluded.',
                        style: TextStyle(color: AfaqDesign.muted),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'These assessments are linked to classes and subjects, not framework versions. This is not learner coverage, achievement or Qur\'an passage progress.',
                        style: TextStyle(color: AfaqDesign.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (constraints.maxWidth >= 1050)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: table(context)),
                  const SizedBox(width: 24),
                  Expanded(child: quranPanel(context)),
                ],
              )
            else ...[
              table(context),
              const SizedBox(height: 20),
              quranPanel(context),
            ],
            const SizedBox(height: 20),
            const WorkspaceFormNotice(
              message:
                  'Read-only oversight. Teaching corrections remain with the responsible madrasa and teacher. Class adoption records are not a count of unique classes.',
            ),
          ],
        ],
      );
    },
  );
}
