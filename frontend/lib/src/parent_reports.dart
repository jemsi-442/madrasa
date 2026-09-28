import 'package:flutter/material.dart';
import 'admin_forms.dart' show shortDate;
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'report_preview.dart';
import 'teacher_ui.dart';

class ParentReports extends StatefulWidget {
  const ParentReports({
    super.key,
    required this.load,
    required this.childId,
    this.refreshToken = 0,
  }) : learnerMode = false;
  const ParentReports.learner({
    super.key,
    required this.load,
    this.refreshToken = 0,
  }) : childId = '',
       learnerMode = true;
  final bool learnerMode;
  final PageLoader load;
  final String childId;
  final int refreshToken;
  @override
  State<ParentReports> createState() => _ParentReportsState();
}

class _ParentReportsState extends State<ParentReports> {
  int page = 1;
  @override
  void didUpdateWidget(covariant ParentReports oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childId != widget.childId) page = 1;
  }

  String get base => widget.learnerMode
      ? '/api/learner/workspace/reports'
      : '/api/student-reports/children/${widget.childId}';
  String path(Map<String, dynamic> row) => '$base/${row['id']}/pdf';
  @override
  Widget build(BuildContext context) => TeacherData(
    key: ValueKey('${widget.childId}-$page'),
    load: widget.load,
    path: '$base?page=$page',
    refreshToken: widget.refreshToken,
    builder: (raw) {
      final data = recordMap(raw), reports = recordList(data['items']);
      final total = recordNumber(recordMap(data['meta'])['totalItems']).toInt();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PanelHeading(
                  'Available Reports',
                  subtitle: widget.learnerMode
                      ? 'View and download your school-published learning reports.'
                      : 'View and download school-published learning reports for your selected child.',
                ),
                if (reports.isEmpty)
                  const EmptyRecords(
                    'No published reports are available. Teacher drafts and reports awaiting review stay private.',
                  )
                else
                  LayoutBuilder(
                    builder: (context, size) => Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final r in reports.take(4))
                          SizedBox(
                            width: size.maxWidth >= 1000
                                ? (size.maxWidth - 48) / 4
                                : size.maxWidth >= 580
                                ? (size.maxWidth - 16) / 2
                                : size.maxWidth,
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                border: Border.all(color: line),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.description_outlined,
                                    color: blue,
                                    size: 34,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    recordText(
                                      recordMap(
                                        recordMap(r['snapshot'])['period'],
                                      )['name'],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Published ${shortDate(r['publishedOn'] ?? r['createdAt'])}',
                                    style: const TextStyle(color: muted),
                                  ),
                                  const SizedBox(height: 14),
                                  TextButton.icon(
                                    onPressed: () => showPublishedReport(
                                      context,
                                      r,
                                      widget.load,
                                      path(r),
                                    ),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: const Text('View report'),
                                  ),
                                  ReportPdfButton(
                                    load: widget.load,
                                    path: path(r),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PanelHeading(
                  'Report History',
                  subtitle:
                      'Each published document keeps the records reviewed at the time it was issued.',
                ),
                if (reports.isNotEmpty)
                  RecordTable(
                    minWidth: 750,
                    columns: const [
                      'Reporting period',
                      'Class',
                      'Date issued',
                      'Status',
                      'Actions',
                    ],
                    rows: [
                      for (final r in reports)
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                recordText(
                                  recordMap(
                                    recordMap(r['snapshot'])['period'],
                                  )['name'],
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                recordText(
                                  recordMap(r['snapshot'])['className'],
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                shortDate(r['publishedOn'] ?? r['createdAt']),
                              ),
                            ),
                            const DataCell(
                              TeacherTag('Published', color: forest),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => showPublishedReport(
                                      context,
                                      r,
                                      widget.load,
                                      path(r),
                                    ),
                                    child: const Text('View'),
                                  ),
                                  ReportPdfButton(
                                    load: widget.load,
                                    path: path(r),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$total published reports | Page $page',
                        style: const TextStyle(color: muted),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Previous reports',
                      onPressed: page > 1 ? () => setState(() => page--) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Next reports',
                      onPressed: page * 20 < total
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
          const TeacherNotice(
            'Need a correction? Contact your school. Retracted reports are no longer available for download. Previously downloaded copies cannot be recalled.',
          ),
        ],
      );
    },
  );
}
