import 'package:flutter/material.dart';
import 'admin_forms.dart' show shortDate;
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';

class ParentAcademics extends StatefulWidget {
  const ParentAcademics({
    super.key,
    required this.load,
    required this.childId,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final String childId;
  final int refreshToken;
  @override
  State<ParentAcademics> createState() => _ParentAcademicsState();
}

class _ParentAcademicsState extends State<ParentAcademics> {
  int year = DateTime.now().year, page = 1;
  @override
  void didUpdateWidget(covariant ParentAcademics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childId != widget.childId) page = 1;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int>(
              initialValue: year,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Assessment year'),
              items: [
                for (var y = DateTime.now().year; y >= 2000; y--)
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    year = v;
                    page = 1;
                  });
                }
              },
            ),
          ),
          const TeacherTag('Published results only'),
        ],
      ),
      const SizedBox(height: 18),
      TeacherData(
        key: ValueKey('academic-${widget.childId}-$year'),
        load: widget.load,
        path: '/api/assessments/children/${widget.childId}/academic?year=$year',
        refreshToken: widget.refreshToken,
        builder: (raw) {
          final data = recordMap(raw),
              subjects = recordList(recordMap(raw)['subjects']);
          final records = recordList(data['records']);
          final highest = [...subjects]
            ..sort(
              (a, b) => recordNumber(
                b['average'],
              ).compareTo(recordNumber(a['average'])),
            );
          final above = subjects
              .where((r) => recordNumber(r['average']) >= 75)
              .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MetricRow(
                children: [
                  DashboardMetric(
                    label: 'Assessment average',
                    value: data['average'] == null
                        ? 'Not available'
                        : '${data['average']}%',
                    icon: Icons.school_outlined,
                    accent: blue,
                    note: 'Published assessments in $year',
                    dense: true,
                  ),
                  DashboardMetric(
                    label: 'Subjects at 75% or above',
                    value: '$above / ${subjects.length}',
                    icon: Icons.bar_chart_outlined,
                    accent: gold,
                    note: 'Only subjects with published marks',
                    dense: true,
                  ),
                  DashboardMetric(
                    label: 'Highest subject',
                    value: highest.isEmpty
                        ? 'Not available'
                        : recordText(highest.first['name']),
                    icon: Icons.workspace_premium_outlined,
                    accent: forest,
                    note: highest.isEmpty
                        ? 'No published marks yet'
                        : '${highest.first['average']}% assessment average',
                    dense: true,
                  ),
                  DashboardMetric(
                    label: 'Published assessments',
                    value: '${records.length}',
                    icon: Icons.fact_check_outlined,
                    accent: ink,
                    note: 'Approved by the school',
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TeacherNotice(
                recordText(
                  data['policy'],
                  'Published assessment averages are not term grades or class ranks.',
                ),
              ),
              const SizedBox(height: 18),
              if (records.isEmpty)
                const SurfacePanel(
                  child: EmptyRecords(
                    'No published assessment results for this child and year. Drafts and assessments awaiting review are private.',
                  ),
                ),
              if (subjects.isNotEmpty)
                SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PanelHeading(
                        'Subject performance',
                        subtitle:
                            'Average percentage across published assessments for each subject.',
                      ),
                      for (final subject in subjects)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 52,
                                height: 52,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 46,
                                      height: 46,
                                      child: CircularProgressIndicator(
                                        value:
                                            (recordNumber(subject['average']) /
                                                    100)
                                                .clamp(0, 1)
                                                .toDouble(),
                                        color:
                                            recordNumber(subject['average']) >=
                                                75
                                            ? forest
                                            : gold,
                                        backgroundColor: line,
                                        strokeWidth: 4,
                                      ),
                                    ),
                                    Text(
                                      '${recordNumber(subject['average']).round()}%',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  recordText(subject['name']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${subject['assessments']} assessed',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (records.isNotEmpty) ...[
                const SizedBox(height: 18),
                SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PanelHeading(
                        'Published assessment history',
                        subtitle:
                            'Scores and feedback released for your child. No other student results are shown.',
                      ),
                      RecordTable(
                        minWidth: 800,
                        columns: const [
                          'Assessment',
                          'Subject',
                          'Assessed on',
                          'Score',
                          'Percentage',
                          'Published',
                        ],
                        rows: [
                          for (final r
                              in records.skip((page - 1) * 20).take(20))
                            DataRow(
                              cells: [
                                DataCell(Text(recordText(r['title']))),
                                DataCell(
                                  Text(
                                    recordText(recordMap(r['subject'])['name']),
                                  ),
                                ),
                                DataCell(Text(shortDate(r['assessedOn']))),
                                DataCell(
                                  Text('${r['score']} / ${r['maxScore']}'),
                                ),
                                DataCell(TeacherTag('${r['percent']}%')),
                                DataCell(Text(shortDate(r['publishedAt']))),
                              ],
                            ),
                        ],
                      ),
                      Wrap(
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Page $page | ${records.length} assessments'),
                          IconButton(
                            tooltip: 'Previous results',
                            onPressed: page > 1
                                ? () => setState(() => page--)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            tooltip: 'Next results',
                            onPressed: page * 20 < records.length
                                ? () => setState(() => page++)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PanelHeading(
                        'Teacher feedback',
                        subtitle:
                            'Feedback approved with the most recent publications.',
                      ),
                      if (!records.any(
                        (r) => recordText(r['feedback'], '').isNotEmpty,
                      ))
                        const Text('No parent-facing feedback was included.'),
                      for (final r
                          in records
                              .where(
                                (r) => recordText(r['feedback'], '').isNotEmpty,
                              )
                              .take(5))
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F6FB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['teacher']} | ${r['title']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(recordText(r['feedback'])),
                              const SizedBox(height: 8),
                              Text(
                                shortDate(r['publishedAt']),
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
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
      ),
    ],
  );
}
