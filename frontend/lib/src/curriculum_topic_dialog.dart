import 'package:flutter/material.dart';
import 'workspace_form_dialog.dart';

class CurriculumTopicDialog extends StatefulWidget {
  const CurriculumTopicDialog({super.key, required this.position, this.topic});
  final int position;
  final Map<String, dynamic>? topic;
  @override
  State<CurriculumTopicDialog> createState() => _CurriculumTopicDialogState();
}

class _CurriculumTopicDialogState extends State<CurriculumTopicDialog> {
  final form = GlobalKey<FormState>();
  String title = '';
  final objectives = <Map<String, String>>[{}];
  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) => WorkspaceFormDialog(
    title: Text(
      widget.topic == null
          ? 'Add topic & objectives'
          : 'Edit topic & objectives',
    ),
    content: SizedBox(
      width: 650,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              for (var i = 0; i < objectives.length; i++) ...[
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
                  onChanged: (value) => objectives[i]['code'] = value.trim(),
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
                    DropdownMenuItem(value: 'ORAL', child: Text('Oral')),
                    DropdownMenuItem(value: 'WRITTEN', child: Text('Written')),
                    DropdownMenuItem(
                      value: 'PRACTICAL',
                      child: Text('Practical demonstration', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'OBSERVATION',
                      child: Text('Observation'),
                    ),
                  ],
                  onChanged: (value) =>
                      objectives[i]['assessmentMethod'] = value!,
                  validator: (value) =>
                      value == null ? 'Choose an assessment method' : null,
                ),
                const SizedBox(height: 14),
                field(
                  'Achievement criteria',
                  (value) => objectives[i]['criteria'] = value,
                  initial: objectives[i]['criteria'],
                ),
                const Divider(),
              ],
              if (objectives.length < 50)
                OutlinedButton.icon(
                  onPressed: () => setState(() => objectives.add({})),
                  icon: const Icon(Icons.add),
                  label: const Text('Add another objective'),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, {
              'title': title,
              'position': widget.position,
              'objectives': objectives,
            });
          }
        },
        child: const Text('Save topic'),
      ),
    ],
  );
}
