import 'package:flutter/material.dart';

/// Publication is separate from uploading and from learner permissions.
class TeacherLessonAccess extends StatefulWidget {
  const TeacherLessonAccess({
    super.key,
    required this.lesson,
    this.course,
    this.update,
  });

  final Map<String, dynamic> lesson;
  final Map<String, dynamic>? course;
  final Future<dynamic> Function(String, Map<String, dynamic>)? update;

  @override
  State<TeacherLessonAccess> createState() => _TeacherLessonAccessState();
}

class _TeacherLessonAccessState extends State<TeacherLessonAccess> {
  late Map<String, dynamic> lesson = Map.of(widget.lesson);
  bool saving = false;
  String? error;

  @override
  void didUpdateWidget(covariant TeacherLessonAccess oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!saving &&
        (oldWidget.lesson['id'] != widget.lesson['id'] ||
            oldWidget.lesson['publicationStatus'] !=
                widget.lesson['publicationStatus'] ||
            oldWidget.lesson['visibility'] != widget.lesson['visibility'])) {
      lesson = Map.of(widget.lesson);
      error = null;
    }
  }

  Future<void> changeAccess(bool publish) async {
    if (saving || widget.update == null) return;
    var visibility = '${lesson['visibility'] ?? 'LOCKED'}';
    var submitting = false;
    String? dialogError;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: !submitting,
          child: AlertDialog(
            title: Text(
              publish ? 'Publish lesson' : 'Hide lesson from learners',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    publish
                        ? 'Only learners with access to the published course and matching programme can see this lesson. Resource restrictions remain unchanged.'
                        : 'This lesson returns to draft. Uploaded files and recorded learner progress are kept.',
                  ),
                  if (publish) ...[
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: visibility,
                      decoration: const InputDecoration(
                        labelText: 'Lesson access',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'FREE',
                          child: Text('Available to course learners'),
                        ),
                        DropdownMenuItem(
                          value: 'PAID',
                          child: Text('Paid access'),
                        ),
                        DropdownMenuItem(
                          value: 'PREVIEW',
                          child: Text('Preview'),
                        ),
                        DropdownMenuItem(
                          value: 'LOCKED',
                          child: Text('Locked'),
                        ),
                        DropdownMenuItem(
                          value: 'UNLISTED',
                          child: Text('Unlisted'),
                        ),
                      ],
                      onChanged: submitting
                          ? null
                          : (value) => visibility = value!,
                    ),
                  ],
                  if (dialogError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      dialogError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        setDialogState(() {
                          submitting = true;
                          dialogError = null;
                        });
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        final changes = <String, dynamic>{
                          'publicationStatus': publish ? 'PUBLISHED' : 'DRAFT',
                          if (publish) 'visibility': visibility,
                        };
                        try {
                          await widget.update!(
                            '/api/courses/lessons/${Uri.encodeComponent('${lesson['id']}')}',
                            changes,
                          );
                          if (mounted) {
                            setState(() => lesson = {...lesson, ...changes});
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              dialogError =
                                  'Could not save lesson access. Your selection is kept. Try again.';
                            });
                          }
                        } finally {
                          if (mounted) setState(() => saving = false);
                          if (dialogContext.mounted) {
                            setDialogState(() => submitting = false);
                          }
                        }
                      },
                child: Text(
                  submitting
                      ? 'Saving...'
                      : publish
                      ? 'Publish lesson'
                      : 'Hide lesson',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = lesson['publicationStatus'];
    final locked = lesson['visibility'] == 'LOCKED';
    final (title, description, icon, color) = switch (status) {
      'DRAFT' => (
        'Draft lesson',
        'Learners cannot see this lesson yet. Publish when ready; the course must also be published by your madrasa administrator.',
        Icons.edit_note_outlined,
        const Color(0xFF956B18),
      ),
      'ARCHIVED' => (
        'Archived lesson',
        'This lesson is not available to learners. Uploaded resources remain available for teacher preview.',
        Icons.inventory_2_outlined,
        const Color(0xFF64748B),
      ),
      'PUBLISHED' when locked => (
        'Published, but locked',
        'Learners cannot open this lesson while it is locked. Ask your madrasa administrator to review lesson access.',
        Icons.lock_outline,
        const Color(0xFF956B18),
      ),
      'PUBLISHED' when lesson['visibility'] == 'UNLISTED' => (
        'Published, but unlisted',
        'This lesson is hidden from the learner lesson list. Change lesson access to make it available.',
        Icons.visibility_off_outlined,
        const Color(0xFF956B18),
      ),
      'PUBLISHED' => (
        'Lesson published',
        'Learners still need course access. Locked resources remain teacher-preview only.',
        Icons.check_circle_outline,
        const Color(0xFF23735C),
      ),
      _ => (
        'Publication status unavailable',
        'Learner access cannot be confirmed from this view.',
        Icons.info_outline,
        const Color(0xFF64748B),
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(height: 1.5)),
                if (widget.course != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Course: ${widget.course!['publicationStatus'] ?? 'Unknown'} | Programme: ${widget.course!['programme'] ?? 'Unknown'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (widget.course!['publicationStatus'] != 'PUBLISHED')
                    const Text(
                      'Course is not published. Learners cannot see its lessons yet.',
                    ),
                ],
                if (widget.update != null && lesson['id'] != null) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: saving ? null : () => changeAccess(true),
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(
                          saving
                              ? 'Saving...'
                              : status == 'PUBLISHED'
                              ? 'Change lesson access'
                              : 'Publish lesson',
                        ),
                      ),
                      if (status == 'PUBLISHED')
                        OutlinedButton.icon(
                          onPressed: saving ? null : () => changeAccess(false),
                          icon: const Icon(Icons.visibility_off_outlined),
                          label: const Text('Hide from learners'),
                        ),
                    ],
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
