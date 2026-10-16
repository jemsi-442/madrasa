import 'package:flutter/material.dart';
import 'workspace_form_dialog.dart';

class CurriculumLessonDialog extends StatefulWidget {
  const CurriculumLessonDialog({
    super.key,
    required this.topics,
    required this.position,
    this.lesson,
  });
  final List<dynamic> topics;
  final int position;
  final Map<String, dynamic>? lesson;
  @override
  State<CurriculumLessonDialog> createState() => _CurriculumLessonDialogState();
}

class _CurriculumLessonDialogState extends State<CurriculumLessonDialog> {
  final form = GlobalKey<FormState>();
  final selected = <String>{};
  String title = '', activities = '';
  int minutes = 40;
  bool missingObjectives = false;
  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) => WorkspaceFormDialog(
    title: Text(widget.lesson == null ? 'Plan a lesson' : 'Edit lesson plan'),
    content: SizedBox(
      width: 650,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WorkspaceFormNotice(
                message:
                    'A lesson can cover several objectives. Planning it does not mark it as taught or mark learners as achieved.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                initialValue: title,
                maxLength: 150,
                decoration: const InputDecoration(labelText: 'Lesson title'),
                onChanged: (v) => title = v.trim(),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Enter a lesson title' : null,
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final valid = form.currentState!.validate();
          setState(() => missingObjectives = selected.isEmpty);
          if (valid && selected.isNotEmpty) {
            Navigator.pop(context, {
              'title': title,
              'position': widget.position,
              'durationMinutes': minutes,
              'activities': activities,
              'objectiveIds': selected.toList(),
            });
          }
        },
        child: const Text('Save lesson'),
      ),
    ],
  );
}
