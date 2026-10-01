import 'package:flutter/material.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';
import 'platform/report_download_stub.dart'
    if (dart.library.js_interop) 'platform/report_download_web.dart'
    as platform;

class ReportPdfButton extends StatefulWidget {
  const ReportPdfButton({
    super.key,
    required this.load,
    required this.path,
    this.enabled = true,
  });
  final PageLoader load;
  final String path;
  final bool enabled;
  @override
  State<ReportPdfButton> createState() => _ReportPdfButtonState();
}

class _ReportPdfButtonState extends State<ReportPdfButton> {
  bool busy = false;
  Future<void> download() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final data = recordMap(await widget.load(widget.path));
      if (!mounted) return;
      await platform.saveReportPdf('${data['fileName']}', '${data['base64']}');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Download unavailable. Refresh to check whether this report is still published.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: widget.enabled && !busy && platform.reportDownloadsSupported
        ? download
        : null,
    icon: const Icon(Icons.download_outlined),
    label: Text(
      busy
          ? 'Preparing PDF...'
          : platform.reportDownloadsSupported
          ? 'Download PDF'
          : 'PDF: use web portal',
    ),
  );
}

class LearningReportPreview extends StatelessWidget {
  const LearningReportPreview({
    super.key,
    required this.snapshot,
    this.published = false,
  });
  final Map<String, dynamic> snapshot;
  final bool published;
  @override
  Widget build(BuildContext context) {
    final student = recordMap(snapshot['student']),
        period = recordMap(snapshot['period']);
    final attendance = recordMap(snapshot['attendance']),
        quran = recordMap(snapshot['quran']);
    final marks = recordList(snapshot['assessments']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.school_outlined, color: gold, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                recordText(snapshot['school']),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TeacherTag(
              published ? 'Published' : 'Draft',
              color: published ? forest : gold,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Student Learning Report',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '${student['fullName']} | ${snapshot['className']}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        Text(
          '${period['name']} | ${period['startsOn']} to ${period['endsOn']}',
          style: const TextStyle(color: muted),
        ),
        Text(
          'Prepared by ${snapshot['teacher']}',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 22),
        MetricRow(
          children: [
            DashboardMetric(
              label: 'Published assessments',
              value: '${marks.length}',
              icon: Icons.fact_check_outlined,
              accent: blue,
              note: 'This class and period',
              dense: true,
            ),
            DashboardMetric(
              label: 'Attendance',
              value: attendance['rate'] == null
                  ? 'No records'
                  : '${attendance['rate']}%',
              icon: Icons.calendar_month_outlined,
              accent: forest,
              note: '${attendance['recorded']} recorded days',
              dense: true,
            ),
            DashboardMetric(
              label: "Qur'an memorised",
              value: '${quran['memorisedAyahs']}',
              icon: Icons.menu_book_outlined,
              accent: gold,
              note: 'Unique independent ayahs',
              dense: true,
            ),
            DashboardMetric(
              label: 'Learning sessions',
              value: '${quran['sessions']}',
              icon: Icons.history_outlined,
              accent: blue,
              note: 'Recorded in this period',
              dense: true,
            ),
          ],
        ),
        const SizedBox(height: 22),
        const PanelHeading(
          'Assessment results',
          subtitle: 'Published marks, not a weighted term grade or class rank.',
        ),
        if (marks.isEmpty)
          const EmptyRecords('No published assessments for this period.')
        else
          RecordTable(
            minWidth: 600,
            columns: const [
              'Subject / assessment',
              'Date',
              'Score',
              'Teacher feedback',
            ],
            rows: [
              for (final a in marks)
                DataRow(
                  cells: [
                    DataCell(Text('${a['subject']}\n${a['title']}')),
                    DataCell(Text('${a['date']}')),
                    DataCell(Text('${a['score']} / ${a['maxScore']}')),
                    DataCell(
                      SizedBox(
                        width: 240,
                        child: Text(
                          recordText(a['feedback'], 'No comment'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        // Full feedback is below the compact table, including long approved comments.
        for (final a in marks.where(
          (a) => recordText(a['feedback'], '').isNotEmpty,
        ))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('${a['subject']} (${a['title']}): ${a['feedback']}'),
          ),
        const SizedBox(height: 20),
        const PanelHeading('Attendance & learning'),
        Text(
          'Present: ${attendance['present']} | Late: ${attendance['late']} | Absent: ${attendance['absent']} | Excused: ${attendance['excused']}',
        ),
        const SizedBox(height: 8),
        Text(
          'Reading sessions: ${quran['reading']} | Revision: ${quran['revision']} | Tajweed: ${quran['tajweed']}',
        ),
        const SizedBox(height: 20),
        const PanelHeading('Teacher feedback'),
        SelectableText(recordText(snapshot['feedback'], 'Not yet provided.')),
        const SizedBox(height: 20),
        TeacherNotice(recordText(snapshot['policy'])),
      ],
    );
  }
}

Future<void> showPublishedReport(
  BuildContext context,
  Map<String, dynamic> row,
  PageLoader load,
  String pdfPath,
) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 900),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Published ${recordText(row['publishedOn'] ?? row['createdAt']).split('T').first}',
                  ),
                ),
                IconButton(
                  tooltip: 'Close report',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                primary: true,
                child: LearningReportPreview(
                  snapshot: recordMap(row['snapshot']),
                  published: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ReportPdfButton(load: load, path: pdfPath),
            ),
          ],
        ),
      ),
    ),
  ),
);
