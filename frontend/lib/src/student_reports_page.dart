import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'assessments_page.dart' show assessmentStates;
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'report_preview.dart';
import 'teacher_ui.dart';

class StudentReportsPage extends StatefulWidget {
  const StudentReportsPage({
    super.key,
    required this.load,
    required this.submit,
    required this.admin,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final bool admin;
  final int refreshToken;
  @override
  State<StudentReportsPage> createState() => _StudentReportsPageState();
}

class _StudentReportsPageState extends State<StudentReportsPage> {
  String classId = '', periodId = '', status = '';
  int page = 1, refresh = 0;
  bool opening = false;
  Future<void> open(String id) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final row = recordMap(await widget.load('/api/student-reports/$id'));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StudentReportEditor(
          initial: row,
          load: widget.load,
          submit: widget.submit,
          admin: widget.admin,
        ),
      );
      if (mounted) setState(() => refresh++);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report unavailable. Refresh and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> period() async {
    final clientId = submissionId();
    final saved = await showAdminForm(
      context,
      title: 'New reporting period',
      note:
          'Use a month, term or year. Dates are fixed once created to protect report history. Reports can be published only after the end date.',
      fields: const [
        AdminField('name', 'Period name'),
        AdminField('startsOn', 'Start date', kind: 'date'),
        AdminField('endsOn', 'End date', kind: 'date'),
      ],
      onSave: (body) async {
        final from = DateTime.parse('${body['startsOn']}'),
            to = DateTime.parse('${body['endsOn']}');
        if (to.isBefore(from) || to.difference(from).inDays > 366) {
          throw const ApiException(
            'Choose a valid period of up to one year.',
            422,
          );
        }
        await widget.submit('/api/student-reports/periods', {
          ...body,
          'clientId': clientId,
        });
      },
    );
    if (saved && mounted) setState(() => refresh++);
  }

  Future<void> prepare(Map<String, dynamic> options) async {
    Map<String, dynamic>? choice;
    final selected = await showAdminForm(
      context,
      title: 'Prepare student report',
      saveLabel: 'Choose learner',
      note:
          'Reports use published assessments, recorded attendance and Quran sessions for the selected period and class.',
      fields: [
        AdminField(
          'classId',
          'Class',
          options: {
            for (final c in recordList(options['classes']))
              '${c['id']}': '${c['name']}',
          },
        ),
        AdminField(
          'periodId',
          'Reporting period',
          options: {
            for (final p in recordList(options['periods']))
              '${p['id']}': '${p['name']}',
          },
        ),
      ],
      onSave: (body) async {
        choice = body;
      },
    );
    if (!selected || !mounted || choice == null) return;
    setState(() => opening = true);
    String? created;
    try {
      final roster = recordList(
        await widget.load(
          '/api/student-reports/roster?classId=${choice!['classId']}',
        ),
      );
      if (!mounted) return;
      if (roster.isEmpty) {
        throw const ApiException('No active learners in this class.', 422);
      }
      final saved = await showAdminForm(
        context,
        title: 'Select learner',
        saveLabel: 'Prepare report',
        note:
            'One report per learner and period. An existing report will be opened instead of duplicated.',
        fields: [
          AdminField(
            'studentId',
            'Learner',
            options: {
              for (final s in roster)
                '${s['id']}': '${s['fullName']} (${s['admissionNo']})',
            },
          ),
        ],
        onSave: (body) async {
          final row = recordMap(
            await widget.submit('/api/student-reports', {
              ...body,
              'periodId': choice!['periodId'],
            }),
          );
          created = '${row['id']}';
        },
      );
      if (saved && mounted) {
        setState(() {
          refresh++;
          page = 1;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Learners unavailable. Check the class and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
    if (mounted && created != null) await open(created!);
  }

  Widget filter(
    String label,
    String value,
    Map<String, String> values,
    ValueChanged<String> changed,
  ) => SizedBox(
    width: 230,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: '', child: Text('All ${label.toLowerCase()}')),
        for (final e in values.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: opening
          ? null
          : (v) => setState(() {
              changed(v ?? '');
              page = 1;
            }),
    ),
  );
  @override
  Widget build(BuildContext context) => TeacherData(
    load: widget.load,
    path: '/api/student-reports/options',
    refreshToken: refresh + widget.refreshToken,
    builder: (raw) {
      final options = recordMap(raw);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeacherNotice(
            widget.admin
                ? 'Set reporting periods, review each report, then publish. Retraction preserves the old snapshot but removes parent access.'
                : 'Prepare a learning report for each learner. Save parent-facing feedback and refresh source records before submitting. Parents see only published reports.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: opening
                    ? null
                    : () => widget.admin ? period() : prepare(options),
                icon: const Icon(Icons.add),
                label: Text(
                  widget.admin ? 'New reporting period' : 'Prepare report',
                ),
              ),
              filter('Periods', periodId, {
                for (final p in recordList(options['periods']))
                  '${p['id']}': '${p['name']}',
              }, (v) => periodId = v),
              filter('Classes', classId, {
                for (final c in recordList(options['classes']))
                  '${c['id']}': '${c['name']}',
              }, (v) => classId = v),
              filter('Statuses', status, assessmentStates, (v) => status = v),
            ],
          ),
          if (recordList(options['periods']).isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: TeacherNotice(
                'No reporting periods yet. An administrator must set a period before teachers can prepare reports.',
              ),
            ),
          const SizedBox(height: 20),
          TeacherData(
            key: ValueKey('$periodId-$classId-$status-$page'),
            load: widget.load,
            path:
                '/api/student-reports?page=$page${periodId.isEmpty ? '' : '&periodId=$periodId'}${classId.isEmpty ? '' : '&classId=$classId'}${status.isEmpty ? '' : '&status=$status'}',
            refreshToken: refresh + widget.refreshToken,
            builder: (raw) {
              final data = recordMap(raw), rows = recordList(data['items']);
              final total = recordNumber(
                recordMap(data['meta'])['totalItems'],
              ).toInt();
              final counts = {
                for (final s in recordList(data['stats']))
                  '${s['status']}': s['_count'],
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MetricRow(
                    children: [
                      DashboardMetric(
                        label: 'Student reports',
                        value: '$total',
                        icon: Icons.description_outlined,
                        accent: blue,
                        note: 'Matching your filters',
                        dense: true,
                      ),
                      DashboardMetric(
                        label: 'Drafts',
                        value: '${counts['DRAFT'] ?? 0}',
                        icon: Icons.edit_note,
                        accent: gold,
                        note: 'Teacher preparation',
                        dense: true,
                      ),
                      DashboardMetric(
                        label: 'Awaiting review',
                        value: '${counts['SUBMITTED'] ?? 0}',
                        icon: Icons.fact_check_outlined,
                        accent: forest,
                        note: 'Administrator review',
                        dense: true,
                      ),
                      DashboardMetric(
                        label: 'Published',
                        value: '${counts['PUBLISHED'] ?? 0}',
                        icon: Icons.verified_outlined,
                        accent: blue,
                        note: 'Open to verify source status',
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SurfacePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PanelHeading(
                          widget.admin
                              ? 'Report review queue'
                              : 'My class reports',
                          subtitle:
                              'Review the full parent report before submission or publication.',
                        ),
                        if (rows.isEmpty)
                          const EmptyRecords('No reports match these filters.')
                        else
                          RecordTable(
                            minWidth: 780,
                            columns: const [
                              'Student',
                              'Class',
                              'Period',
                              'Report status',
                              'Actions',
                            ],
                            rows: [
                              for (final r in rows)
                                DataRow(
                                  cells: [
                                    DataCell(
                                      StudentIdentity(
                                        recordMap(r['student']),
                                        subtitle: recordText(
                                          recordMap(
                                            r['student'],
                                          )['admissionNo'],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        recordText(
                                          recordMap(r['class'])['name'],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        recordText(
                                          recordMap(r['period'])['name'],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      TeacherTag(
                                        assessmentStates[r['status']] ??
                                            'Draft',
                                        color: r['status'] == 'PUBLISHED'
                                            ? forest
                                            : gold,
                                      ),
                                    ),
                                    DataCell(
                                      OutlinedButton.icon(
                                        onPressed: opening
                                            ? null
                                            : () => open('${r['id']}'),
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Preview'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$total reports | Page $page',
                                style: const TextStyle(color: muted),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Previous reports',
                              onPressed: page > 1 && !opening
                                  ? () => setState(() => page--)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              tooltip: 'Next reports',
                              onPressed: page * 20 < total && !opening
                                  ? () => setState(() => page++)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      );
    },
  );
}

class StudentReportEditor extends StatefulWidget {
  const StudentReportEditor({
    super.key,
    required this.initial,
    required this.load,
    required this.submit,
    required this.admin,
  });
  final Map<String, dynamic> initial;
  final PageLoader load;
  final PageSubmitter submit;
  final bool admin;
  @override
  State<StudentReportEditor> createState() => _StudentReportEditorState();
}

class _StudentReportEditorState extends State<StudentReportEditor> {
  late Map<String, dynamic> row = widget.initial;
  late final feedback = TextEditingController(
    text: recordText(row['feedback'], ''),
  );
  bool busy = false, dirty = false, closing = false;
  String? error, notice;
  bool get editable => !widget.admin && row['status'] == 'DRAFT';
  @override
  void dispose() {
    feedback.dispose();
    super.dispose();
  }

  Future<void> close() async {
    if (busy || closing) return;
    closing = true;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Discard unsaved feedback?'),
          content: const Text(
            'If a save was not confirmed, reopen the report to check its latest state.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      if (discard != true) {
        closing = false;
        return;
      }
    }
    if (mounted) {
      setState(() => dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> mutate(String path, Map<String, dynamic> body) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final saved = recordMap(
        await widget.submit('/api/student-reports/${row['id']}/$path', {
          'revision': row['revision'],
          ...body,
        }),
      );
      if (mounted) {
        setState(() {
          row = saved;
          dirty = false;
          notice = 'Saved to the school server.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException && e.statusCode == 409
              ? 'The report or source records changed. Your feedback is still here. Reopen the report; a submitted report must be returned to the teacher for refresh.'
              : e is ApiException && e.statusCode == 422
              ? e.message
              : 'Save not confirmed. Your feedback is retained. Retry or reopen to verify.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> transition(String action) async {
    if (busy || dirty) return;
    String? reason;
    if (action == 'return' || action == 'retract') {
      final ok = await showAdminForm(
        context,
        title: action == 'return' ? 'Return report' : 'Retract report',
        saveLabel: 'Continue',
        fields: const [AdminField('reason', 'Reason')],
        note:
            'The reason is audited. Prior publications remain in school history.',
        onSave: (v) async {
          reason = '${v['reason']}'.trim();
          if (reason!.length < 3 || reason!.length > 500) {
            throw const ApiException('Use 3 to 500 characters.', 422);
          }
        },
      );
      if (!ok || !mounted) return;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(
            action == 'publish'
                ? 'Publish this report?'
                : 'Submit report for review?',
          ),
          content: Text(
            action == 'publish'
                ? 'Verified parents of this child will be able to view and download this snapshot.'
                : 'The saved report will be locked for administrator review. Parents cannot see it yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await mutate('transition', {
      'action': action,
      if (reason != null) 'reason': reason,
    });
  }

  @override
  Widget build(BuildContext context) {
    final published = row['status'] == 'PUBLISHED';
    final releases = recordList(row['releases']);
    final snapshot = recordMap(
      published && releases.isNotEmpty
          ? releases.first['snapshot']
          : row['draft'],
    );
    return PopScope(
      canPop: !dirty && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 900),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Parent report preview',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close report',
                      onPressed: busy ? null : close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  assessmentStates[row['status']] ?? 'Draft',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (row['sourcesCurrent'] == false)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TeacherNotice(
                              published
                                  ? 'A source assessment was retracted. This report is hidden from parents. Retract this report, then refresh and review a corrected draft.'
                                  : 'Source records have changed. Save and refresh the draft before submitting. Admins should return submitted reports to the teacher.',
                              warning: true,
                            ),
                          ),
                        if (row['reviewNote'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TeacherNotice(
                              'Review note: ${row['reviewNote']}',
                            ),
                          ),
                        LearningReportPreview(
                          snapshot: snapshot,
                          published: published,
                        ),
                        if (editable) ...[
                          const SizedBox(height: 18),
                          TextField(
                            controller: feedback,
                            enabled: !busy,
                            minLines: 3,
                            maxLines: 6,
                            maxLength: 2000,
                            decoration: const InputDecoration(
                              labelText: 'Parent-facing teacher feedback',
                              hintText:
                                  'Describe progress and useful next steps.',
                            ),
                            onChanged: (_) => setState(() => dirty = true),
                          ),
                        ],
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TeacherNotice(error!, warning: true),
                          ),
                        if (notice != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              notice!,
                              style: const TextStyle(color: forest),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    ReportPdfButton(
                      load: widget.load,
                      path: '/api/student-reports/${row['id']}/pdf',
                      enabled: !busy && !dirty && row['sourcesCurrent'] == true,
                    ),
                    if (editable) ...[
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => mutate('draft', {
                                'feedback': feedback.text.trim(),
                              }),
                        child: const Text('Save & refresh draft'),
                      ),
                      FilledButton(
                        onPressed:
                            busy || dirty || row['sourcesCurrent'] != true
                            ? null
                            : () => transition('submit'),
                        child: const Text('Submit for review'),
                      ),
                    ],
                    if (widget.admin && row['status'] == 'SUBMITTED') ...[
                      OutlinedButton(
                        onPressed: busy ? null : () => transition('return'),
                        child: const Text('Return for corrections'),
                      ),
                      FilledButton(
                        onPressed: busy || row['sourcesCurrent'] != true
                            ? null
                            : () => transition('publish'),
                        child: const Text('Publish report'),
                      ),
                    ],
                    if (widget.admin && published)
                      OutlinedButton(
                        onPressed: busy ? null : () => transition('retract'),
                        child: const Text('Retract publication'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
