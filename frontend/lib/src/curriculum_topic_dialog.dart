import 'dart:convert';
import 'package:flutter/material.dart';
import 'curriculum_save_conflict.dart';
import 'workspace_form_dialog.dart';

class CurriculumTopicDialog extends StatefulWidget {
  const CurriculumTopicDialog({
    super.key,
    required this.position,
    required this.maxPosition,
    required this.occupiedPositions,
    this.topic,
    this.onSave,
  });
  final int position;
  final int maxPosition;
  final List<int> occupiedPositions;
  final Map<String, dynamic>? topic;
  final Future<String?> Function(Map<String, dynamic>)? onSave;
  @override
  State<CurriculumTopicDialog> createState() => _CurriculumTopicDialogState();
}

class _CurriculumTopicDialogState extends State<CurriculumTopicDialog> {
  final form = GlobalKey<FormState>();
  String title = '';
  final objectives = <Map<String, String>>[{}];
  final removedObjectives = <({int index, Map<String, String> value})>[];
  late int position;
  bool submitting = false;
  bool staleVersion = false;
  String? saveError;
  late String initialContent;
  bool confirmingClose = false;

  String get currentContent => jsonEncode([title, position, objectives]);
  bool get hasChanges => currentContent != initialContent;

  Future<void> requestClose() async {
    if (submitting || confirmingClose) return;
    if (!hasChanges || staleVersion) {
      Navigator.pop(context);
      return;
    }
    confirmingClose = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'Your topic changes have not been saved. Keep editing to preserve them.',
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
    confirmingClose = false;
    if (mounted && discard == true) Navigator.pop(context);
  }

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
    position = widget.topic?['position'] as int? ?? widget.position;
    if (widget.topic != null) {
      title = widget.topic!['title'] as String;
      objectives.clear();
      for (final objective in widget.topic!['objectives']) {
        objectives.add({
          for (final key in [
            'code',
            'description',
            'assessmentMethod',
            'criteria',
          ])
            key: objective[key] as String,
        });
      }
    }
    initialContent = currentContent;
  }

  Widget field(
    String label,
    void Function(String) changed, {
    int minimum = 10,
    int maximum = 1000,
    String? initial,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      decoration: InputDecoration(labelText: label),
      initialValue: initial,
      maxLength: maximum,
      onChanged: (value) => changed(value.trim()),
      validator: (value) => (value ?? '').trim().length < minimum
          ? 'Enter at least $minimum characters'
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !submitting && !hasChanges,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) requestClose();
    },
    child: WorkspaceFormDialog(
      title: Text(
        widget.topic == null
            ? 'Add topic & objectives'
            : 'Edit topic & objectives',
      ),
      content: ExcludeFocus(
        excluding: submitting,
        child: AbsorbPointer(
          absorbing: submitting,
          child: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                onChanged: () => setState(() {}),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (saveError != null)
                      WorkspaceFormNotice(message: saveError!, isError: true),
                    DropdownButtonFormField<int>(
                      initialValue: position,
                      decoration: const InputDecoration(
                        labelText: 'Topic order',
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
                    const SizedBox(height: 14),
                    field(
                      'Topic title',
                      (value) => title = value,
                      minimum: 2,
                      maximum: 150,
                      initial: title,
                    ),
                    const WorkspaceFormNotice(
                      message:
                          'Describe observable skills and how the teacher will assess them. Watching a video alone does not demonstrate achievement.',
                    ),
                    const SizedBox(height: 20),
                    if (removedObjectives.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${removedObjectives.length} objective(s) removed from this form. Changes apply when saved.',
                            ),
                          ),
                          TextButton(
                            onPressed: objectives.length >= 50
                                ? null
                                : () => setState(() {
                                    final removed = removedObjectives
                                        .removeLast();
                                    objectives.insert(
                                      removed.index.clamp(0, objectives.length),
                                      removed.value,
                                    );
                                  }),
                            child: const Text('Undo'),
                          ),
                        ],
                      ),
                    for (var i = 0; i < objectives.length; i++)
                      Column(
                        key: ObjectKey(objectives[i]),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WorkspaceFormSection(
                            title: 'Objective ${i + 1}',
                            description: 'Use a unique code within this topic.',
                          ),
                          TextFormField(
                            initialValue: objectives[i]['code'],
                            decoration: const InputDecoration(
                              labelText: 'Objective code',
                              hintText: 'FIQH-001',
                            ),
                            maxLength: 40,
                            onChanged: (value) =>
                                objectives[i]['code'] = value.trim(),
                            validator: (value) {
                              final code = (value ?? '').trim();
                              if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code)) {
                                return 'Use letters, numbers, hyphens or underscores';
                              }
                              if (objectives
                                      .where(
                                        (o) =>
                                            o['code']?.toLowerCase() ==
                                            code.toLowerCase(),
                                      )
                                      .length >
                                  1) {
                                return 'Use a unique code';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          field(
                            'Expected skill',
                            (value) => objectives[i]['description'] = value,
                            initial: objectives[i]['description'],
                          ),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: objectives[i]['assessmentMethod'],
                            decoration: const InputDecoration(
                              labelText: 'Assessment method',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ORAL',
                                child: Text('Oral'),
                              ),
                              DropdownMenuItem(
                                value: 'WRITTEN',
                                child: Text('Written'),
                              ),
                              DropdownMenuItem(
                                value: 'PRACTICAL',
                                child: Text(
                                  'Practical demonstration',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'OBSERVATION',
                                child: Text('Observation'),
                              ),
                            ],
                            onChanged: (value) =>
                                objectives[i]['assessmentMethod'] = value!,
                            validator: (value) => value == null
                                ? 'Choose an assessment method'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          field(
                            'Achievement criteria',
                            (value) => objectives[i]['criteria'] = value,
                            initial: objectives[i]['criteria'],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: objectives.length <= 1
                                  ? null
                                  : () => setState(() {
                                      removedObjectives.add((
                                        index: i,
                                        value: objectives.removeAt(i),
                                      ));
                                    }),
                              icon: const Icon(Icons.remove_circle_outline),
                              label: const Text('Remove objective'),
                            ),
                          ),
                          const Divider(),
                        ],
                      ),
                    if (objectives.length < 50)
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          objectives.add({});
                        }),
                        icon: const Icon(Icons.add),
                        label: const Text('Add another objective'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: submitting ? null : requestClose,
          child: Text(staleVersion ? 'Discard edits & view latest' : 'Cancel'),
        ),
        FilledButton(
          onPressed: submitting || staleVersion
              ? null
              : () {
                  if (form.currentState!.validate()) {
                    save({
                      'title': title,
                      'position': position,
                      'objectives': [
                        for (final objective in objectives)
                          Map<String, String>.from(objective),
                      ],
                    });
                  }
                },
          child: Text(submitting ? 'Saving...' : 'Save topic'),
        ),
      ],
    ),
  );
}
