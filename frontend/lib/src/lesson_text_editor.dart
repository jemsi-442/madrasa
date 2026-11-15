import 'package:flutter/material.dart';

class LessonTextEditor extends StatefulWidget {
  const LessonTextEditor({
    super.key,
    required this.lessonId,
    required this.submit,
  });
  final String lessonId;
  final Future<dynamic> Function(String, Map<String, dynamic>) submit;

  @override
  State<LessonTextEditor> createState() => _LessonTextEditorState();
}

class _LessonTextEditorState extends State<LessonTextEditor> {
  final title = TextEditingController();
  final text = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false, preview = false, available = false;
  String? error;

  @override
  void dispose() {
    title.dispose();
    text.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.submit(
        '/api/courses/lessons/${Uri.encodeComponent(widget.lessonId)}/text-resources',
        {
          'title': title.text.trim(),
          'text': text.text.trim(),
          'visibility': available ? 'FREE' : 'LOCKED',
        },
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Could not confirm saving. Your text is still here. Check the resource list before retrying if the connection was interrupted.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.article_outlined,
                      color: Color(0xFFAD8524),
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Add text resource',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close editor',
                      onPressed: saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: title,
                  enabled: !saving,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Resource title',
                    hintText: 'e.g. Lesson notes',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: text,
                  enabled: !saving,
                  minLines: 8,
                  maxLines: 16,
                  maxLength: 50000,
                  decoration: const InputDecoration(
                    labelText: 'Lesson text',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Write the lesson text.'
                      : null,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available to course learners'),
                  subtitle: Text(
                    available
                        ? 'Course and lesson access rules still apply.'
                        : 'Saved locked. Learners cannot open it yet.',
                  ),
                  value: available,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => available = value),
                ),
                if (preview)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7EF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.text.trim(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          text.text.trim(),
                          style: const TextStyle(fontSize: 17, height: 1.7),
                        ),
                      ],
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (saving)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () {
                              if (form.currentState!.validate()) {
                                setState(() => preview = !preview);
                              }
                            },
                      icon: const Icon(Icons.visibility_outlined),
                      label: Text(preview ? 'Hide preview' : 'Preview'),
                    ),
                    FilledButton.icon(
                      onPressed: saving ? null : save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(saving ? 'Saving...' : 'Save resource'),
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
}
