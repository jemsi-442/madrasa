import 'package:flutter/material.dart';
import 'dashboard_components.dart';
import 'lesson_upload.dart';
import 'teacher_lesson_access.dart';
import 'teacher_lesson_resources.dart';

typedef CourseWrite = Future<dynamic> Function(String, Map<String, dynamic>);

/// Keeps authoring state independent of background dashboard refreshes.
class TeacherCourseWorkspace extends StatefulWidget {
  const TeacherCourseWorkspace({
    super.key,
    required this.load,
    required this.submit,
    required this.update,
    required this.onPreview,
    this.upload,
    this.apiBaseUrl = '',
  });
  final PageLoader load;
  final CourseWrite submit, update;
  final LessonUploader? upload;
  final String apiBaseUrl;
  final void Function(
    Map<String, dynamic>,
    Map<String, dynamic>,
    Map<String, dynamic>,
  )
  onPreview;

  @override
  State<TeacherCourseWorkspace> createState() => _TeacherCourseWorkspaceState();
}

class _TeacherCourseWorkspaceState extends State<TeacherCourseWorkspace> {
  final title = TextEditingController(), notes = TextEditingController();
  List<Map<String, dynamic>> courses = [], modules = [];
  final Map<String, List<Map<String, dynamic>>> lessons = {};
  Map<String, dynamic>? course, module, lesson;
  bool loading = true, saving = false, dirty = false;
  String? error;
  int courseSelectionRevision = 0;
  static const navy = Color(0xff092b49), gold = Color(0xffac7b16);

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    try {
      final rows = recordList(await widget.load('/api/teaching/courses'));
      if (!mounted) return;
      courses = rows;
      if (rows.isNotEmpty) {
        await openCourse(rows.first);
      } else {
        setState(() => loading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Could not load courses. Please try again.';
        });
      }
    }
  }

  Future<bool> canLeave() async {
    if (saving) return false;
    if (!dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard unsaved changes?'),
            content: const Text('Your lesson edits have not been saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> openCourse(Map<String, dynamic> selected) async {
    if (!await canLeave() || !mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = recordList(
        await widget.load('/api/courses/${selected['id']}/modules'),
      );
      final loaded = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        loaded['${row['id']}'] = recordList(
          await widget.load('/api/courses/modules/${row['id']}/lessons'),
        );
      }
      if (!mounted) return;
      setState(() {
        course = selected;
        modules = rows;
        lessons
          ..clear()
          ..addAll(loaded);
        lesson = null;
        module = null;
        dirty = false;
        loading = false;
        for (final row in rows) {
          if (loaded['${row['id']}']!.isNotEmpty) {
            select(row, loaded['${row['id']}']!.first);
            break;
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Could not load the course outline. Try again.';
        });
      }
    }
  }

  void select(Map<String, dynamic> parent, Map<String, dynamic> row) {
    module = parent;
    lesson = Map.of(row);
    title.text = recordText(row['title'], '');
    notes.text = recordText(row['contentText'], '');
    dirty = false;
    error = null;
  }

  Future<void> save() async {
    if (saving || lesson == null) return;
    if (title.text.trim().length < 2) {
      setState(
        () => error = 'Enter a lesson title of at least two characters.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final changes = {'title': title.text.trim(), 'contentText': notes.text};
      await widget.update('/api/courses/lessons/${lesson!['id']}', changes);
      if (!mounted) return;
      setState(() {
        lesson = {...lesson!, ...changes};
        final rows = lessons['${module!['id']}']!;
        final index = rows.indexWhere((row) => row['id'] == lesson!['id']);
        if (index >= 0) rows[index] = lesson!;
        dirty = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lesson saved')));
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Lesson could not be saved. Your edits are still here.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> add({Map<String, dynamic>? parent}) async {
    if (!await canLeave() || !mounted || course == null) return;
    String value = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(parent == null ? 'Add module' : 'Add lesson'),
        content: TextField(
          autofocus: true,
          maxLength: 150,
          onChanged: (text) => value = text,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (value.trim().length >= 2) {
                Navigator.pop(context, value.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final rows = parent == null ? modules : lessons['${parent['id']}']!;
      final position =
          rows.fold<int>(
            0,
            (max, row) => recordNumber(row['position']) > max
                ? recordNumber(row['position']).toInt()
                : max,
          ) +
          1;
      final created = recordMap(
        await widget.submit(
          parent == null
              ? '/api/courses/${course!['id']}/modules'
              : '/api/courses/modules/${parent['id']}/lessons',
          {
            'title': result,
            'position': position,
            if (parent != null) ...{
              'slug': 'lesson-${DateTime.now().microsecondsSinceEpoch}',
              'publicationStatus': 'DRAFT',
              'visibility': 'LOCKED',
            },
          },
        ),
      );
      if (!mounted) return;
      if (created['id'] == null) throw StateError('Missing created record');
      setState(() {
        rows.add(created);
        if (parent == null) {
          lessons['${created['id']}'] = [];
        } else {
          select(parent, created);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not create this item. Check the course before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xffdfe6f2)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x090b3760),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );

  Widget get outline => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 12,
          children: [
            const Text(
              'Course outline',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: navy,
              ),
            ),
            OutlinedButton.icon(
              onPressed: saving ? null : () => add(),
              icon: const Icon(Icons.add),
              label: const Text('Add module'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (modules.isEmpty)
          const Text('Add a module to start organising lessons.'),
        for (final parent in modules)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xffe0e5f0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const Icon(Icons.folder_open, color: gold),
                title: Text(
                  recordText(parent['title']),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                children: [
                  for (final row
                      in lessons['${parent['id']}'] ?? <Map<String, dynamic>>[])
                    ListTile(
                      selected: lesson?['id'] == row['id'],
                      selectedTileColor: const Color(0xfffff4d9),
                      leading: const Icon(Icons.article_outlined),
                      title: Text(recordText(row['title'])),
                      subtitle: Text(friendlyStatus(row['publicationStatus'])),
                      onTap: saving
                          ? null
                          : () async {
                              if (await canLeave() && mounted) {
                                setState(() => select(parent, row));
                              }
                            },
                    ),
                  TextButton.icon(
                    onPressed: saving ? null : () => add(parent: parent),
                    icon: const Icon(Icons.add),
                    label: const Text('Add lesson'),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget get editor => panel(
    lesson == null
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: Text(
                'Choose a lesson from the outline to edit its content.',
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Edit lesson',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                  if (dirty)
                    const Text(
                      'Unsaved changes',
                      style: TextStyle(color: gold),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: title,
                enabled: !saving,
                maxLength: 150,
                onChanged: (_) => setState(() => dirty = true),
                decoration: const InputDecoration(labelText: 'Lesson title'),
              ),
              const SizedBox(height: 8),
              Text(
                'Module: ${recordText(module?['title'])}',
                style: const TextStyle(color: navy),
              ),
              const SizedBox(height: 24),
              const Text(
                'Lesson notes',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                enabled: !saving,
                minLines: 5,
                maxLines: 12,
                onChanged: (_) => setState(() => dirty = true),
                decoration: const InputDecoration(
                  hintText: 'Write the lesson content here...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: saving || !dirty ? null : save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Saving...' : 'Save changes'),
                ),
              ),
              const Divider(height: 40),
              TeacherLessonResources(
                key: ValueKey('editor-resources-${lesson!['id']}'),
                lessonId: '${lesson!['id']}',
                load: widget.load,
                submit: widget.submit,
                update: widget.update,
                upload: widget.upload,
                apiBaseUrl: widget.apiBaseUrl,
              ),
              const Divider(height: 40),
              if (dirty)
                const Text(
                  'Save your changes before publishing or previewing.',
                ),
              if (!dirty)
                TeacherLessonAccess(
                  key: ValueKey('editor-access-${lesson!['id']}'),
                  lesson: lesson!,
                  course: course,
                  update: (path, body) async {
                    setState(() => saving = true);
                    try {
                      final result = await widget.update(path, body);
                      if (mounted) {
                        setState(() {
                          lesson = {...lesson!, ...body};
                          final rows = lessons['${module!['id']}']!;
                          final index = rows.indexWhere(
                            (row) => row['id'] == lesson!['id'],
                          );
                          if (index >= 0) rows[index] = lesson!;
                        });
                      }
                      return result;
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
                ),
            ],
          ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 12,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My courses',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: navy,
                ),
              ),
              SizedBox(height: 6),
              Text('Organise your course and create lessons.'),
            ],
          ),
          OutlinedButton.icon(
            onPressed: lesson == null || dirty || saving || loading
                ? null
                : () => widget.onPreview(course!, module!, lesson!),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview lesson'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(error!, style: const TextStyle(color: Colors.red)),
        ),
      if (courses.isNotEmpty)
        panel(
          DropdownButtonFormField<String>(
            key: ValueKey('${course?['id']}-$courseSelectionRevision'),
            initialValue: course?['id']?.toString(),
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Selected course'),
            items: courses
                .map(
                  (row) => DropdownMenuItem(
                    value: '${row['id']}',
                    child: Text(recordText(row['title'])),
                  ),
                )
                .toList(),
            onChanged: loading || saving
                ? null
                : (id) async {
                    if (id != null) {
                      await openCourse(
                        courses.firstWhere((row) => '${row['id']}' == id),
                      );
                      if (mounted) {
                        setState(() => courseSelectionRevision++);
                      }
                    }
                  },
          ),
        ),
      const SizedBox(height: 20),
      if (loading)
        const LinearProgressIndicator()
      else if (course == null)
        panel(
          Column(
            children: [
              const Text('No assigned courses available.'),
              TextButton(
                onPressed: initialize,
                child: const Text('Check courses'),
              ),
            ],
          ),
        )
      else
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 1000
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: outline),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: editor),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [outline, const SizedBox(height: 20), editor],
                ),
        ),
    ],
  );
}
