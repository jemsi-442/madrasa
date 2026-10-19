import 'package:flutter/material.dart';
import 'curriculum_save_conflict.dart';
import 'workspace_form_dialog.dart';

class CurriculumLessonDialog extends StatefulWidget {
  const CurriculumLessonDialog({
    super.key,
    required this.topics,
    required this.position,
    required this.maxPosition,
    required this.occupiedPositions,
    this.lesson,
    this.onSave,
  });
  final List<dynamic> topics;
  final int position;
  final int maxPosition;
  final List<int> occupiedPositions;
  final Map<String, dynamic>? lesson;
  final Future<String?> Function(Map<String, dynamic>)? onSave;
  @override
  State<CurriculumLessonDialog> createState() => _CurriculumLessonDialogState();
}

class _CurriculumLessonDialogState extends State<CurriculumLessonDialog> {
  final form = GlobalKey<FormState>();
  final selected = <String>{};
  String title = '', activities = '';
  int minutes = 40;
  late int position;
  bool missingObjectives = false;
  bool submitting = false;
  bool staleVersion = false;
  String? saveError;

  Future<void> save(Map<String, dynamic> data) async {
    if (submitting || staleVersion) return;
    if (widget.onSave == null) {
      Navigator.pop(context, data);
      return;
    }
    setState(() {
      submitting = true;
      saveError = null;
    });
    String? error;
    try {
      error = await widget.onSave!(data);
    } on CurriculumSaveConflict catch (conflict) {
      staleVersion = true;
      error = conflict.message;
    } catch (_) {
      error = 'Could not save. Your changes are still here; try again.';
    }
    if (!mounted) return;
    setState(() {
      submitting = false;
      saveError = error;
    });
    if (error == null) Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    position = widget.lesson?['position'] as int? ?? widget.position;
    final lesson = widget.lesson;
    if (lesson != null) {
      title = lesson['title'];
      activities = lesson['activities'];
      minutes = lesson['durationMinutes'];
      selected.addAll(
        (lesson['objectives'] as List).map((o) => o['objectiveId'] as String),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !submitting,
    child: WorkspaceFormDialog(
      title: Text(widget.lesson == null ? 'Plan a lesson' : 'Edit lesson plan'),
      content: ExcludeFocus(
        excluding: submitting,
        child: AbsorbPointer(
          absorbing: submitting,
          child: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (saveError != null)
                      WorkspaceFormNotice(message: saveError!, isError: true),
                    const WorkspaceFormNotice(
                      message:
                          'A lesson can cover several objectives. Planning it does not mark it as taught or mark learners as achieved.',
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<int>(
                      initialValue: position,
                      decoration: const InputDecoration(
                        labelText: 'Lesson order',
                      ),
                      items: [
                        for (
                          var order = 1;
                          order <= widget.maxPosition;
                          order++
                        )
                          if (!widget.occupiedPositions.contains(order) ||
                              order == position)
                            DropdownMenuItem(
                              value: order,
                              child: Text('Position $order'),
                            ),
                      ],
                      onChanged: (value) => setState(() => position = value!),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      initialValue: title,
                      maxLength: 150,
                      decoration: const InputDecoration(
                        labelText: 'Lesson title',
                      ),
                      onChanged: (v) => title = v.trim(),
                      validator: (v) => (v ?? '').trim().length < 2
                          ? 'Enter a lesson title'
                          : null,
                    ),
                    TextFormField(
                      initialValue: '$minutes',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes)',
                      ),
                      onChanged: (v) => minutes = int.tryParse(v) ?? 0,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null || n < 1 || n > 480
                            ? 'Enter 1-480 minutes'
                            : null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      initialValue: activities,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 10000,
                      decoration: const InputDecoration(
                        labelText: 'Activities & teaching guidance',
                      ),
                      onChanged: (v) => activities = v.trim(),
                      validator: (v) => (v ?? '').trim().length < 10
                          ? 'Describe the planned activities (at least 10 characters)'
                          : null,
                    ),
                    const WorkspaceFormSection(
                      title: 'Learning objectives',
                      description:
                          'Choose one or more objectives from this framework.',
                    ),
                    if (missingObjectives)
                      const Text(
                        'Select at least one objective',
                        style: TextStyle(color: Colors.red),
                      ),
                    for (final topic in widget.topics) ...[
                      Text(
                        '${topic['title']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      for (final objective in topic['objectives'])
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            '${objective['code']} - ${objective['description']}',
                          ),
                          value: selected.contains(objective['id']),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              selected.add(objective['id']);
                            } else {
                              selected.remove(objective['id']);
                            }
                            missingObjectives = selected.isEmpty;
                          }),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: submitting ? null : () => Navigator.pop(context),
          child: Text(staleVersion ? 'Discard edits & view latest' : 'Cancel'),
        ),
        FilledButton(
          onPressed: submitting || staleVersion
              ? null
              : () {
                  final valid = form.currentState!.validate();
                  setState(() => missingObjectives = selected.isEmpty);
                  if (valid && selected.isNotEmpty) {
                    save({
                      'title': title,
                      'position': position,
                      'durationMinutes': minutes,
                      'activities': activities,
                      'objectiveIds': selected.toList(),
                    });
                  }
                },
          child: Text(submitting ? 'Saving...' : 'Save lesson'),
        ),
      ],
    ),
  );
}
