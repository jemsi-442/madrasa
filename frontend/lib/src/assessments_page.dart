import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';

const assessmentStates = {
  'DRAFT': 'Draft',
  'SUBMITTED': 'Awaiting review',
  'PUBLISHED': 'Published',
};

class AssessmentsPage extends StatefulWidget {
  const AssessmentsPage({
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
  State<AssessmentsPage> createState() => _AssessmentsPageState();
}

class _AssessmentsPageState extends State<AssessmentsPage> {
  int page = 1, refresh = 0;
  String status = '', classId = '';
  bool opening = false;
  Future<void> open(String id) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final row = recordMap(await widget.load('/api/assessments/$id'));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AssessmentEditor(
          initial: row,
          submit: widget.submit,
          admin: widget.admin,
        ),
      );
      if (mounted) setState(() => refresh++);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assessment unavailable. Refresh and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> create(Map<String, dynamic> options) async {
    final clientId = submissionId();
    String? created;
    final saved = await showAdminForm(
      context,
      title: 'New assessment',
      note:
          'Choose an approved school subject. The current active class roster is saved with this assessment. Scores stay private until reviewed.',
      fields: [
        AdminField(
          'classId',
          'Class',
          options: {
            for (final r in recordList(options['classes']))
              '${r['id']}': recordText(r['name']),
          },
        ),
        AdminField(
          'subjectId',
          'Subject',
          options: {
            for (final r in recordList(options['subjects']))
              '${r['id']}': recordText(r['name']),
          },
        ),
        const AdminField('title', 'Assessment title'),
        AdminField(
          'assessedOn',
          'Assessment date',
          kind: 'date',
          initial: DateTime.now().toIso8601String().substring(0, 10),
        ),
        const AdminField(
          'maxScore',
          'Maximum score',
          kind: 'integer',
          initial: '10',
        ),
      ],
      onSave: (body) async {
        final max = int.tryParse('${body['maxScore']}');
        if (max == null || max < 1 || max > 1000) {
          throw const ApiException('Maximum score must be 1 to 1000', 422);
        }
        final response = recordMap(
          await widget.submit('/api/assessments', {
            ...body,
            'clientId': clientId,
            'maxScore': max,
          }),
        );
        created = '${response['id']}';
      },
    );
    if (saved && mounted) {
      setState(() {
        page = 1;
        refresh++;
      });
      if (created != null) await open(created!);
    }
  }

  @override
  Widget build(BuildContext context) => TeacherData(
    load: widget.load,
    path: '/api/assessments/options',
    refreshToken: widget.refreshToken,
    builder: (raw) {
      final options = recordMap(raw);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeacherNotice(
            widget.admin
                ? 'Review teacher-recorded marks before publishing. Parents see only their own child\'s published results. Retraction removes parent access while preserving the publication history.'
                : 'Record scores and parent-facing feedback. Blank means not assessed, never zero. Save your draft, then submit the complete roster for administrator review.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!widget.admin)
                FilledButton.icon(
                  onPressed: opening ? null : () => create(options),
                  icon: const Icon(Icons.add),
                  label: const Text('New assessment'),
                ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: classId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All my classes'),
                    ),
                    for (final c in recordList(options['classes']))
                      DropdownMenuItem(
                        value: '${c['id']}',
                        child: Text(recordText(c['name'])),
                      ),
                  ],
                  onChanged: opening
                      ? null
                      : (v) => setState(() {
                          classId = v ?? '';
                          page = 1;
                        }),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All statuses'),
                    ),
                    for (final entry in assessmentStates.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: opening
                      ? null
                      : (v) => setState(() {
                          status = v ?? '';
                          page = 1;
                        }),
                ),
              ),
              OutlinedButton.icon(
                onPressed: opening ? null : () => setState(() => refresh++),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TeacherData(
            key: ValueKey('$classId-$status-$page'),
            load: widget.load,
            path:
                '/api/assessments?page=$page${classId.isEmpty ? '' : '&classId=$classId'}${status.isEmpty ? '' : '&status=$status'}',
            refreshToken: refresh + widget.refreshToken,
            builder: (raw) {
              final data = recordMap(raw),
                  rows = recordList(recordMap(raw)['items']);
              final total = recordMap(data['meta'])['totalItems'] as int? ?? 0;
              return SurfacePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PanelHeading(
                      widget.admin
                          ? 'Assessment review queue'
                          : 'My assessments',
                      subtitle:
                          'Open an assessment to view its full roster and review status.',
                    ),
                    if (rows.isEmpty)
                      const EmptyRecords('No assessments match these filters.')
                    else
                      RecordTable(
                        minWidth: 820,
                        columns: const [
                          'Assessment',
                          'Class / subject',
                          'Date',
                          'Learners',
                          'Status',
                          '',
                        ],
                        rows: [
                          for (final row in rows)
                            DataRow(
                              cells: [
                                DataCell(Text(recordText(row['title']))),
                                DataCell(
                                  Text(
                                    '${recordMap(row['class'])['name']} / ${recordMap(row['subject'])['name']}',
                                  ),
                                ),
                                DataCell(Text(shortDate(row['assessedOn']))),
                                DataCell(
                                  Text(
                                    '${recordMap(row['_count'])['results']}',
                                  ),
                                ),
                                DataCell(
                                  TeacherTag(
                                    assessmentStates[row['status']] ?? 'Draft',
                                    color: row['status'] == 'PUBLISHED'
                                        ? forest
                                        : gold,
                                  ),
                                ),
                                DataCell(
                                  OutlinedButton(
                                    onPressed: opening
                                        ? null
                                        : () => open('${row['id']}'),
                                    child: const Text('Open'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('$total assessments | Page $page'),
                        IconButton(
                          tooltip: 'Previous page',
                          onPressed: page > 1 && !opening
                              ? () => setState(() => page--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          tooltip: 'Next page',
                          onPressed: page * 20 < total && !opening
                              ? () => setState(() => page++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );
    },
  );
}

class AssessmentEditor extends StatefulWidget {
  const AssessmentEditor({
    super.key,
    required this.initial,
    required this.submit,
    required this.admin,
  });
  final Map<String, dynamic> initial;
  final PageSubmitter submit;
  final bool admin;
  @override
  State<AssessmentEditor> createState() => _AssessmentEditorState();
}

class _AssessmentEditorState extends State<AssessmentEditor> {
  late Map<String, dynamic> row = widget.initial;
  late final results = recordList(row['results']);
  late final scores = {
    for (final r in results)
      '${r['studentId']}': TextEditingController(
        text: r['score']?.toString() ?? '',
      ),
  };
  late final notes = {
    for (final r in results)
      '${r['studentId']}': TextEditingController(
        text: recordText(r['feedback'], ''),
      ),
  };
  bool dirty = false, busy = false, closing = false;
  String? error, notice;
  bool get editable => !widget.admin && row['status'] == 'DRAFT';
  @override
  void dispose() {
    for (final c in [...scores.values, ...notes.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> close() async {
    if (busy || closing) return;
    closing = true;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved marks?'),
          content: const Text(
            'Your unsaved changes will be lost. If a save was not confirmed, reopen the assessment to check its latest state.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
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

  Future<void> save() async {
    if (busy || !editable) return;
    final payload = <Map<String, dynamic>>[];
    for (final r in results) {
      final id = '${r['studentId']}',
          text = scores['${r['studentId']}']!.text.trim();
      final score = text.isEmpty ? null : int.tryParse(text);
      if (text.isNotEmpty &&
          (score == null || score < 0 || score > (row['maxScore'] as num))) {
        setState(
          () => error =
              'Enter whole-number scores between 0 and ${row['maxScore']}, or leave blank.',
        );
        return;
      }
      payload.add({
        'studentId': id,
        'score': score,
        'feedback': notes[id]!.text.trim(),
      });
    }
    await mutate('results', {'revision': row['revision'], 'results': payload});
  }

  Future<void> mutate(String path, Map<String, dynamic> body) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final saved = recordMap(
        await widget.submit('/api/assessments/${row['id']}/$path', body),
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
              ? 'The assessment changed or the action already completed. Your entries are still here. Close and reopen to review the current record.'
              : e is ApiException && e.statusCode == 422
              ? 'Check all marks. Every learner needs a score before submission or publication.'
              : 'Save not confirmed. Your entries are retained. Retry or reopen to check server state.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> transition(String action) async {
    if (busy || dirty) return;
    String? reason;
    final needsReason = action == 'return' || action == 'retract';
    if (needsReason) {
      final accepted = await showAdminForm(
        context,
        title: action == 'return'
            ? 'Return for corrections'
            : 'Retract publication',
        fields: const [AdminField('reason', 'Reason')],
        note:
            'The reason is kept in the audit history. Retraction hides results from parents, without deleting the prior publication.',
        onSave: (v) async {
          reason = '${v['reason']}';
          if (reason!.trim().length < 3 || reason!.length > 500) {
            throw const ApiException('Invalid reason', 422);
          }
        },
        saveLabel: 'Continue',
      );
      if (!accepted || !mounted) return;
    } else {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            action == 'publish'
                ? 'Publish these results?'
                : 'Submit for review?',
          ),
          content: Text(
            action == 'publish'
                ? 'Each verified parent will see only their own child\'s marks and feedback. Published marks cannot be edited without retraction.'
                : 'The saved roster will be locked for administrator review. Parents cannot see it yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    await mutate('transition', {
      'revision': row['revision'],
      'action': action,
      if (reason != null) 'reason': reason,
    });
  }

  @override
  Widget build(BuildContext context) {
    final recorded = scores.values
        .where((c) => c.text.trim().isNotEmpty)
        .length;
    return PopScope(
      canPop: !busy && !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 850),
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
                        recordText(row['title']),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close assessment',
                      onPressed: busy ? null : close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  '${recordMap(row['class'])['name']} | ${recordMap(row['subject'])['name']} | ${shortDate(row['assessedOn'])}',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TeacherTag(
                      assessmentStates[row['status']] ?? 'Draft',
                      color: row['status'] == 'PUBLISHED' ? forest : gold,
                    ),
                    TeacherTag(
                      '$recorded / ${results.length} recorded',
                      color: blue,
                    ),
                    TeacherTag('Maximum ${row['maxScore']}', color: muted),
                    if (dirty) const TeacherTag('Unsaved changes', color: gold),
                  ],
                ),
                if (row['reviewNote'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TeacherNotice(
                      'Review note: ${row['reviewNote']}',
                      warning: true,
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(notice!, style: const TextStyle(color: forest)),
                  ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    primary: true,
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        Widget score(Map<String, dynamic> r) => TextField(
                          key: ValueKey('score-${r['studentId']}'),
                          controller: scores['${r['studentId']}'],
                          enabled: !busy,
                          readOnly: !editable,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Score',
                            suffixText: '/ ${row['maxScore']}',
                          ),
                          onChanged: (_) => setState(() {
                            dirty = true;
                            notice = null;
                          }),
                        );
                        Widget feedback(Map<String, dynamic> r) => TextField(
                          key: ValueKey('feedback-${r['studentId']}'),
                          controller: notes['${r['studentId']}'],
                          enabled: !busy,
                          readOnly: !editable,
                          maxLength: 500,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Parent-facing feedback',
                          ),
                          onChanged: (_) => setState(() {
                            dirty = true;
                            notice = null;
                          }),
                        );
                        return Column(
                          children: [
                            for (final r in results)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: line),
                                  ),
                                ),
                                child: bounds.maxWidth < 650
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          StudentIdentity(
                                            recordMap(r['student']),
                                          ),
                                          const SizedBox(height: 12),
                                          score(r),
                                          const SizedBox(height: 12),
                                          feedback(r),
                                        ],
                                      )
                                    : Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: StudentIdentity(
                                              recordMap(r['student']),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          SizedBox(width: 110, child: score(r)),
                                          const SizedBox(width: 18),
                                          Expanded(flex: 4, child: feedback(r)),
                                        ],
                                      ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.admin
                      ? 'Review the complete roster. Internal student notes are never included.'
                      : 'Feedback entered here will be visible to the parent after publication.',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (editable)
                      FilledButton.icon(
                        onPressed: busy ? null : save,
                        icon: const Icon(Icons.check),
                        label: Text(busy ? 'Saving...' : 'Save draft'),
                      ),
                    if (editable)
                      OutlinedButton(
                        onPressed: busy || dirty
                            ? null
                            : () => transition('submit'),
                        child: const Text('Submit for review'),
                      ),
                    if (widget.admin && row['status'] == 'SUBMITTED') ...[
                      FilledButton(
                        onPressed: busy ? null : () => transition('publish'),
                        child: const Text('Publish results'),
                      ),
                      OutlinedButton(
                        onPressed: busy ? null : () => transition('return'),
                        child: const Text('Return for corrections'),
                      ),
                    ],
                    if (widget.admin && row['status'] == 'PUBLISHED')
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
