import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';

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
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 148),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Color.alphaBlend(color.withValues(alpha: .10), Colors.white),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: const TextStyle(
            color: ink,
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          note,
          style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
      ],
    ),
  );
}

class TeacherNotice extends StatelessWidget {
  const TeacherNotice(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFAF5E8) : const Color(0xFFF5F7FA),
      border: Border.all(color: warning ? const Color(0xFFEBDDB5) : line),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          warning ? Icons.info_outline : Icons.lock_outline,
          color: warning ? gold : muted,
          size: 19,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: muted, fontSize: 13, height: 1.65),
          ),
        ),
      ],
    ),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
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
  Widget build(BuildContext context) => sessions.isEmpty
      ? const EmptyRecords('No learning sessions recorded yet.')
      : RecordTable(
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
                  DataCell(Text(shortDate(s['learnedOn']))),
                  DataCell(
                    Text(learningActivities[s['activity']] ?? 'Learning'),
                  ),
                  DataCell(Text('${s['ayahFrom']}-${s['ayahTo']}')),
                  DataCell(
                    TeacherTag(
                      s['voidedAt'] != null
                          ? 'Voided'
                          : learningObservations[s['observation']] ??
                                'Recorded',
                      color: s['voidedAt'] != null
                          ? muted
                          : s['observation'] == 'INDEPENDENT'
                          ? forest
                          : gold,
                    ),
                  ),
                  DataCell(
                    Text(recordText(recordMap(s['teacher'])['fullName'])),
                  ),
                  DataCell(
                    s['voidedAt'] == null &&
                            '${s['teacherId']}' == teacherId &&
                            onVoid != null
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
}
