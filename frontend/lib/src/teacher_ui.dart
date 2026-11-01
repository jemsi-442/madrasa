import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'shared_feedback.dart';
import 'status_badge.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'workspace_details_dialog.dart';

typedef TeacherNavigate =
    void Function(int page, {String? classId, Map<String, dynamic>? student});
const teachingDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const learningActivities = {
  'READING': 'Reading',
  'MEMORIZATION': 'Memorisation',
  'REVISION': 'Revision',
  'TAJWEED': 'Tajweed review',
};
const learningObservations = {
  'INDEPENDENT': 'Independent',
  'WITH_SUPPORT': 'With support',
  'NEEDS_PRACTICE': 'Needs more practice',
};

class TeacherMetric extends StatelessWidget {
  const TeacherMetric(
    this.label,
    this.value,
    this.note,
    this.icon,
    this.color, {
    super.key,
  });
  final String label, value, note;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => DashboardMetric(
    label: label,
    value: value,
    note: note,
    icon: icon,
    accent: color,
  );
}

class TeacherNotice extends StatelessWidget {
  const TeacherNotice(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => AfaqNotice(
    text,
    icon: warning ? Icons.info_outline : Icons.lock_outline,
    color: warning ? gold : muted,
  );
}

class StudentIdentity extends StatelessWidget {
  const StudentIdentity(this.student, {super.key, this.subtitle});
  final Map<String, dynamic> student;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final name = recordText(student['fullName'], 'Student');
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((s) => s.isEmpty ? '' : s[0])
        .join()
        .toUpperCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFE7F0FC),
          child: Text(
            initials,
            style: const TextStyle(fontSize: 13, color: blue),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600, color: ink),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle ?? recordText(student['admissionNo'], ''),
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TeacherTag extends StatelessWidget {
  const TeacherTag(this.text, {super.key, this.color = forest});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      AfaqStatusBadge(label: text, color: color);
}

class TeacherData extends StatefulWidget {
  const TeacherData({
    super.key,
    required this.load,
    required this.path,
    required this.builder,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final String path;
  final int refreshToken;
  final Widget Function(dynamic data) builder;
  @override
  State<TeacherData> createState() => _TeacherDataState();
}

class _TeacherDataState extends State<TeacherData> {
  late Future<dynamic> future = widget.load(widget.path);
  void reload() => setState(() {
    future = widget.load(widget.path);
  });
  @override
  void didUpdateWidget(covariant TeacherData oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path ||
        widget.refreshToken != oldWidget.refreshToken) {
      future = widget.load(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) =>
      PageResult(future: future, onRetry: reload, builder: widget.builder);
}

String passageLabel(Map<String, dynamic> session, [String? name]) =>
    '${name ?? 'Surah ${session['surahId']}'} | ${session['ayahFrom']}-${session['ayahTo']}';

class LearningHistory extends StatelessWidget {
  const LearningHistory(
    this.sessions, {
    super.key,
    this.onVoid,
    this.teacherId,
  });
  final List<Map<String, dynamic>> sessions;
  final void Function(Map<String, dynamic>)? onVoid;
  final String? teacherId;
  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const EmptyRecords('No learning sessions recorded yet.');
    }
    final table = RecordTable(
      minWidth: 700,
      columns: const [
        'Date',
        'Activity',
        'Ayahs',
        'Observation',
        'Recorded by',
        '',
      ],
      rows: [
        for (final s in sessions)
          DataRow(
            cells: [
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortDate(s['learnedOn'])),
                    if (s['timetableSlot'] != null)
                      Text(
                        '${recordMap(s['timetableSlot'])['startsAt']}-${recordMap(s['timetableSlot'])['endsAt']}',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                  ],
                ),
              ),
              DataCell(Text(learningActivities[s['activity']] ?? 'Learning')),
              DataCell(Text('${s['ayahFrom']}-${s['ayahTo']}')),
              DataCell(
                TeacherTag(
                  s['voidedAt'] != null
                      ? 'Voided'
                      : learningObservations[s['observation']] ?? 'Recorded',
                  color: s['voidedAt'] != null
                      ? muted
                      : s['observation'] == 'INDEPENDENT'
                      ? forest
                      : gold,
                ),
              ),
              DataCell(Text(recordText(recordMap(s['teacher'])['fullName']))),
              DataCell(
                s['voidedAt'] != null
                    ? IconButton(
                        tooltip: 'View correction details',
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => WorkspaceDetailsDialog(
                            title: 'Learning record correction',
                            icon: Icons.history,
                            fields: [
                              ('Passage', passageLabel(s)),
                              (
                                'Activity',
                                learningActivities[s['activity']] ?? 'Learning',
                              ),
                              (
                                'Original observation',
                                learningObservations[s['observation']] ??
                                    'Not recorded',
                              ),
                              ('Learning date', shortDate(s['learnedOn'])),
                              (
                                'Recorded by',
                                recordText(recordMap(s['teacher'])['fullName']),
                              ),
                              ('Voided on', shortDate(s['voidedAt'])),
                            ],
                            sections: [
                              (
                                'Reason for correction',
                                recordText(
                                  s['voidReason'],
                                  'No correction reason recorded.',
                                ),
                              ),
                              (
                                'History retained',
                                'This entry is voided and no longer contributes to memorised ayahs. The original learning record remains in history.',
                              ),
                            ],
                          ),
                        ),
                      )
                    : '${s['teacherId']}' == teacherId && onVoid != null
                    ? IconButton(
                        tooltip: 'Correct this record',
                        onPressed: () => onVoid!(s),
                        icon: const Icon(Icons.edit_note),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) return table;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < table.rows.length; index++) ...[
              if (index > 0) const Divider(height: 32),
              Padding(
                key: ValueKey('learning-history-card-${sessions[index]['id']}'),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: table.rows[index].cells[0].child),
                        table.rows[index].cells[5].child,
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (var field = 1; field < 5; field++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              table.columns[field],
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(color: muted),
                            ),
                            const SizedBox(height: 4),
                            table.rows[index].cells[field].child,
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
