import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'attendance_register_page.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';

class _AttendanceDraft {
  _AttendanceDraft(this.student)
    : original = recordMap(student['attendance']),
      status = recordMap(student['attendance'])['status'] as String?,
      time = TextEditingController(
        text: recordText(recordMap(student['attendance'])['checkInTime'], ''),
      ),
      notes = TextEditingController(
        text: recordText(recordMap(student['attendance'])['reason'], ''),
      );
  final Map<String, dynamic> student, original;
  String? status;
  final TextEditingController time, notes;
  bool selected = false;
  String get id => '${student['id']}';
  bool get changed =>
      status != original['status'] ||
      time.text.trim() != recordText(original['checkInTime'], '') ||
      notes.text.trim() != recordText(original['reason'], '');
  Map<String, dynamic> get payload => {
    'studentId': id,
    'version': recordNumber(original['version']).toInt(),
    'status': status,
    'checkInTime': time.text.trim().isEmpty ? null : time.text.trim(),
    'reason': notes.text.trim().isEmpty ? null : notes.text.trim(),
  };
  void dispose() {
    time.dispose();
    notes.dispose();
  }
}

class AttendanceRegisterEditor extends StatefulWidget {
  const AttendanceRegisterEditor({
    super.key,
    required this.data,
    required this.submit,
    required this.reload,
  });
  final Map<String, dynamic> data;
  final PageSubmitter submit;
  final Future<dynamic> Function() reload;
  @override
  State<AttendanceRegisterEditor> createState() =>
      _AttendanceRegisterEditorState();
}

class _AttendanceRegisterEditorState extends State<AttendanceRegisterEditor> {
  late Map<String, dynamic> data = widget.data;
  late List<_AttendanceDraft> rows = drafts(data);
  final correction = TextEditingController();
  String? error;
  bool busy = false, conflict = false;
  List<_AttendanceDraft> drafts(Map<String, dynamic> value) => [
    for (final student in recordList(value['items']))
      if (student['editable'] == true) _AttendanceDraft(student),
  ];
  List<_AttendanceDraft> get changed => rows.where((r) => r.changed).toList();
  bool get correcting => changed.any((r) => r.original.isNotEmpty);

  @override
  void dispose() {
    for (final row in rows) {
      row.dispose();
    }
    correction.dispose();
    super.dispose();
  }

  Future<bool> confirmDiscard() async {
    if (changed.isEmpty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard unsaved changes?'),
            content: const Text('Your changes have not been saved.'),
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
        ) ??
        false;
  }

  Future<void> close() async {
    if (busy) return;
    if (await confirmDiscard() && mounted) Navigator.pop(context, false);
  }

  Future<void> refresh() async {
    if (!await confirmDiscard() || !mounted) return;
    setState(() {
      busy = true;
    });
    try {
      final result = recordMap(await widget.reload());
      if (!mounted) return;
      setState(() {
        for (final row in rows) {
          row.dispose();
        }
        data = result;
        rows = drafts(result);
        correction.clear();
        error = null;
        conflict = false;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'The register could not be refreshed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void markSelected(String status) => setState(() {
    for (final row in rows.where((r) => r.selected)) {
      row.status = status;
      if (!['PRESENT', 'LATE'].contains(status)) row.time.clear();
    }
  });

  Future<void> save() async {
    final updates = changed;
    String? validation;
    for (final row in updates) {
      if (row.status == null) {
        validation =
            'Choose an attendance status for ${row.student['fullName']}.';
      }
      if (row.time.text.isNotEmpty &&
          !RegExp(
            r'^([01]\d|2[0-3]):[0-5]\d$',
          ).hasMatch(row.time.text.trim())) {
        validation = 'Use a valid check-in time, for example 07:45.';
      }
      if (row.notes.text.trim().length > 255) {
        validation = 'Keep each note within 255 characters.';
      }
    }
    if (correcting && correction.text.trim().length < 5) {
      validation = 'Add a short reason for correcting saved attendance.';
    }
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    if (updates.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.submit('/api/attendance/register', {
        'classId': '${recordMap(data['class'])['id']}',
        'date': data['date'],
        if (correcting) 'correctionReason': correction.text.trim(),
        'records': updates.map((r) => r.payload).toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          conflict = e is ApiException && e.statusCode == 409;
          error = conflict
              ? 'This register has changed. Reload it to review the latest attendance before editing again.'
              : e is ApiException && e.statusCode == 422
              ? e.message
              : 'We could not confirm your save. Your changes are still here. Retry, or reload to check saved attendance.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .9,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily register',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          Text(
                            '${recordMap(data['class'])['name']} | ${shortDate(data['date'])}',
                            style: const TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close register',
                      onPressed: busy ? null : close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              final allSelected = rows.every((r) => r.selected);
                              for (final row in rows) {
                                row.selected = !allSelected;
                              }
                            }),
                      icon: const Icon(Icons.checklist),
                      label: Text(
                        rows.isNotEmpty && rows.every((r) => r.selected)
                            ? 'Clear selection'
                            : 'Select all',
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: !busy && rows.any((r) => r.selected),
                      onSelected: markSelected,
                      itemBuilder: (_) => [
                        for (final (key, label, _, _) in attendanceKinds)
                          PopupMenuItem(value: key, child: Text(label)),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Mark selected (${rows.where((r) => r.selected).length})',
                          style: const TextStyle(color: blue),
                        ),
                      ),
                    ),
                    Text(
                      '${changed.length} unsaved changes',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: rows.isEmpty
                      ? const EmptyRecords(
                          'No students can be marked in this register.',
                        )
                      : ListView.separated(
                          primary: true,
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const Divider(height: 28),
                          itemBuilder: (_, index) => rowFields(rows[index]),
                        ),
                ),
                if (correcting)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: correction,
                      enabled: !busy,
                      maxLength: 255,
                      decoration: const InputDecoration(
                        labelText: 'Reason for correction',
                        counterText: '',
                        hintText:
                            'Explain why the saved attendance needs to change',
                      ),
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Color(0xFFBD414F),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (error != null)
                      OutlinedButton.icon(
                        onPressed: busy ? null : refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload register'),
                      ),
                    TextButton(
                      onPressed: busy ? null : close,
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('save-attendance'),
                      onPressed: busy || conflict || changed.isEmpty
                          ? null
                          : save,
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(busy ? 'Saving...' : 'Save attendance'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget rowFields(_AttendanceDraft row) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 700;
      final statusField = DropdownButtonFormField<String>(
        key: ValueKey('status-${row.id}-${row.status}'),
        initialValue: row.status,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Status'),
        hint: const Text('Not marked'),
        items: [
          for (final (key, label, _, _) in attendanceKinds)
            DropdownMenuItem(value: key, child: Text(label)),
        ],
        onChanged: busy
            ? null
            : (v) => setState(() {
                row.status = v;
                if (!['PRESENT', 'LATE'].contains(v)) row.time.clear();
              }),
      );
      final timeField = TextField(
        key: ValueKey('time-${row.id}'),
        controller: row.time,
        enabled: !busy && ['PRESENT', 'LATE'].contains(row.status),
        keyboardType: TextInputType.datetime,
        maxLength: 5,
        decoration: const InputDecoration(
          labelText: 'Check-in',
          hintText: '07:45',
          counterText: '',
        ),
        onChanged: (_) => setState(() {}),
      );
      final noteField = TextField(
        key: ValueKey('notes-${row.id}'),
        controller: row.notes,
        enabled: !busy,
        maxLength: 255,
        decoration: const InputDecoration(
          labelText: 'Notes',
          hintText: 'Optional',
          counterText: '',
        ),
        onChanged: (_) => setState(() {}),
      );
      final name = Row(
        children: [
          Checkbox(
            value: row.selected,
            onChanged: busy
                ? null
                : (v) => setState(() => row.selected = v ?? false),
            semanticLabel: 'Select ${row.student['fullName']}',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recordText(row.student['fullName']),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  recordText(row.student['admissionNo']),
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                if (row.student['current'] != true)
                  const Text(
                    'Previous class member',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      );
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            name,
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(flex: 3, child: statusField),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: timeField),
              ],
            ),
            const SizedBox(height: 12),
            noteField,
          ],
        );
      }
      return Row(
        children: [
          Expanded(flex: 3, child: name),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: statusField),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: timeField),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: noteField),
        ],
      );
    },
  );
}
