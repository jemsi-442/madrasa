import 'package:flutter/material.dart';
import 'dashboard_components.dart';
import 'course_section_heading.dart';
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
  final outlineSearch = TextEditingController();
  // These lists use the page's scroll; never restore offsets from tile storage.
  final moduleScroll = ScrollController(keepScrollOffset: false);
  final lessonScrolls = <String, ScrollController>{};
  String outlineStatus = 'ALL';
  bool get outlineFiltered =>
      outlineSearch.text.trim().isNotEmpty || outlineStatus != 'ALL';

  List<Map<String, dynamic>> visibleLessons(Map<String, dynamic> parent) {
    final query = outlineSearch.text.trim().toLowerCase();
    final moduleMatches = recordText(
      parent['title'],
    ).toLowerCase().contains(query);
    return (lessons['${parent['id']}'] ?? <Map<String, dynamic>>[])
        .where(
          (row) =>
              (outlineStatus == 'ALL' ||
                  row['publicationStatus'] == outlineStatus) &&
              (moduleMatches ||
                  recordText(row['title']).toLowerCase().contains(query)),
        )
        .toList();
  }

  List<Map<String, dynamic>> get visibleModules => modules.where((parent) {
    if (!outlineFiltered || visibleLessons(parent).isNotEmpty) return true;
    return outlineStatus == 'ALL' &&
        recordText(
          parent['title'],
        ).toLowerCase().contains(outlineSearch.text.trim().toLowerCase());
  }).toList();
  List<Map<String, dynamic>> courses = [], modules = [];
  final Map<String, List<Map<String, dynamic>>> lessons = {};
  Map<String, dynamic>? course, module, lesson;
  bool loading = true, saving = false, dirty = false;
  bool confirmingExit = false, allowExit = false;
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
    outlineSearch.dispose();
    moduleScroll.dispose();
    for (final controller in lessonScrolls.values) {
      controller.dispose();
    }
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
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save your lesson changes?'),
        content: const Text(
          'Save before continuing, or keep editing this lesson.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save and continue'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (action == 'save') return save();
    return action == 'discard';
  }

  Future<void> leaveWorkspace(Object? result) async {
    if (confirmingExit || saving) return;
    confirmingExit = true;
    try {
      if (!await canLeave() || !mounted) return;
      final route = ModalRoute.of(context);
      if (route?.isCurrent != true) return;
      setState(() => allowExit = true);
      // Let PopScope receive the permission before retrying navigation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route?.isCurrent == true) {
          Navigator.of(context).pop(result);
        }
      });
    } finally {
      confirmingExit = false;
    }
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
        outlineSearch.clear();
        outlineStatus = 'ALL';
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

  void updateDirtyState() {
    setState(() {
      dirty =
          lesson != null &&
          (title.text.trim() != recordText(lesson!['title'], '').trim() ||
              notes.text != recordText(lesson!['contentText'], ''));
    });
  }

  Future<bool> save() async {
    if (saving || lesson == null) return false;
    if (title.text.trim().length < 2) {
      setState(
        () => error = 'Enter a lesson title of at least two characters.',
      );
      return false;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final changes = {'title': title.text.trim(), 'contentText': notes.text};
      await widget.update('/api/courses/lessons/${lesson!['id']}', changes);
      if (!mounted) return false;
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
      return true;
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Lesson could not be saved. Your edits are still here.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> add({Map<String, dynamic>? parent}) async {
    if (!await canLeave() || !mounted || course == null) return;
    String value = '';
    final formKey = GlobalKey<FormState>();
    bool submitting = false;
    String? creationError;
    final rows = parent == null ? modules : lessons['${parent['id']}']!;
    final position =
        rows.fold<int>(
          0,
          (max, row) => recordNumber(row['position']) > max
              ? recordNumber(row['position']).toInt()
              : max,
        ) +
        1;
    final slug = 'lesson-${DateTime.now().microsecondsSinceEpoch}';
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> create() async {
            if (submitting || !formKey.currentState!.validate()) return;
            setDialogState(() {
              submitting = true;
              creationError = null;
            });
            try {
              final result = recordMap(
                await widget.submit(
                  parent == null
                      ? '/api/courses/${course!['id']}/modules'
                      : '/api/courses/modules/${parent['id']}/lessons',
                  {
                    'title': value.trim(),
                    'position': position,
                    if (parent != null) ...{
                      'slug': slug,
                      'publicationStatus': 'DRAFT',
                      'visibility': 'LOCKED',
                    },
                  },
                ),
              );
              if (result['id'] == null) {
                throw StateError('Missing created record');
              }
              if (context.mounted) Navigator.pop(context, result);
            } catch (_) {
              if (!context.mounted) return;
              setDialogState(() {
                submitting = false;
                creationError =
                    'Could not confirm creation. Your title is still here. Check the outline before retrying if the connection was interrupted.';
              });
            }
          }

          return PopScope(
            canPop: !submitting,
            child: AlertDialog(
              title: Text(parent == null ? 'Add module' : 'Add lesson'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      enabled: !submitting,
                      autofocus: true,
                      maxLength: 150,
                      textInputAction: TextInputAction.done,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (text) => (text ?? '').trim().length < 2
                          ? 'Enter a title of at least two characters.'
                          : null,
                      onFieldSubmitted: (_) => create(),
                      onChanged: (text) => value = text,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    if (creationError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          creationError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting ? null : create,
                  child: Text(submitting ? 'Creating...' : 'Create'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      error = null;
      rows.add(created);
      outlineSearch.clear();
      outlineStatus = 'ALL';
      if (parent == null) {
        lessons['${created['id']}'] = [];
      } else {
        select(parent, created);
      }
    });
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

  Future<void> reorder(int from, int to, {Map<String, dynamic>? parent}) async {
    if (saving || loading) return;
    final rows = parent == null ? modules : lessons['${parent['id']}']!;
    if (to > from) to--;
    if (from == to) return;
    final next = List<Map<String, dynamic>>.of(rows);
    next.insert(to, next.removeAt(from));
    setState(() => saving = true);
    try {
      await widget.update(
        parent == null
            ? '/api/courses/${course!['id']}/modules/order'
            : '/api/courses/modules/${parent['id']}/lessons/order',
        {
          'ids': next.map((row) => '${row['id']}').toList(),
          'expectedIds': rows.map((row) => '${row['id']}').toList(),
        },
      );
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < next.length; i++) {
          next[i] = {...next[i], 'position': i + 1};
        }
        if (parent == null) {
          modules = next;
        } else {
          lessons['${parent['id']}'] = next;
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Order was not saved. Your lesson edits are safe. Save your edits and reopen the course if its outline changed elsewhere.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget dragHandle(int index, String label) => ReorderableDragStartListener(
    index: index,
    enabled: !saving && !loading && !outlineFiltered,
    child: Tooltip(
      message: outlineFiltered
          ? 'Clear filters to reorder'
          : 'Drag to reorder $label',
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.drag_indicator, color: navy),
      ),
    ),
  );

  Widget get outline => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CourseSectionHeading(
          'Course outline',
          icon: Icons.account_tree_outlined,
          action: OutlinedButton.icon(
            onPressed: saving ? null : () => add(),
            icon: const Icon(Icons.add),
            label: const Text('Add module'),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('outline-search'),
          controller: outlineSearch,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Find a module or lesson',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: outlineSearch.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(outlineSearch.clear),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const ValueKey('outline-status'),
          child: DropdownButtonFormField<String>(
            key: ValueKey(outlineStatus),
            initialValue: outlineStatus,
            decoration: const InputDecoration(labelText: 'Lesson status'),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
              DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
              DropdownMenuItem(value: 'PUBLISHED', child: Text('Published')),
            ],
            onChanged: (value) =>
                setState(() => outlineStatus = value ?? 'ALL'),
          ),
        ),
        const SizedBox(height: 16),
        if (outlineFiltered)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Filtered outline. Clear filters to reorder.'),
          ),
        if (modules.isNotEmpty && visibleModules.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No modules or lessons match these filters.'),
          ),
        if (modules.isEmpty)
          const Text('Add a module to start organising lessons.'),
        if (!outlineFiltered &&
            (modules.length > 1 ||
                lessons.values.any((rows) => rows.length > 1)))
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Drag to reorder. Changes to order save automatically.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xff60748c),
              ),
            ),
          ),
        ReorderableListView(
          key: const PageStorageKey('course-outline-module-scroll'),
          scrollController: moduleScroll,
          primary: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (from, to) {
            if (!outlineFiltered) reorder(from, to);
          },
          children: [
            for (final parent in visibleModules)
              Padding(
                key: ValueKey('module-${parent['id']}'),
                padding: const EdgeInsets.only(bottom: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xfff6f8fc),
                    border: Border.all(color: const Color(0xffe0e5f0)),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x080c3454),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    key: PageStorageKey(
                      'course-outline-module-${parent['id']}',
                    ),
                    initiallyExpanded: true,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        dragHandle(modules.indexOf(parent), 'module'),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffe7edf7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${modules.indexOf(parent) + 1}'.padLeft(2, '0'),
                            style: const TextStyle(
                              color: navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      recordText(parent['title']),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: navy,
                      ),
                    ),
                    subtitle: Text(
                      '${lessons['${parent['id']}']?.length ?? 0} lessons',
                    ),
                    children: [
                      ReorderableListView(
                        // Keep scroll offsets separate from ExpansionTile's stored bool.
                        key: PageStorageKey(
                          'course-outline-lessons-${parent['id']}',
                        ),
                        scrollController: lessonScrolls.putIfAbsent(
                          '${parent['id']}',
                          () => ScrollController(keepScrollOffset: false),
                        ),
                        primary: false,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        onReorder: (from, to) {
                          if (!outlineFiltered) {
                            reorder(from, to, parent: parent);
                          }
                        },
                        children: [
                          for (final row in visibleLessons(parent))
                            Padding(
                              key: ValueKey('lesson-${row['id']}'),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: lesson?['id'] == row['id']
                                    ? const Color(0xfffff3d6)
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: lesson?['id'] == row['id']
                                        ? const Color(0xffddbc6d)
                                        : const Color(0xffe5eaf2),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  selected: lesson?['id'] == row['id'],
                                  selectedTileColor: const Color(0xfffff4d9),
                                  leading: dragHandle(
                                    lessons['${parent['id']}']!.indexOf(row),
                                    'lesson',
                                  ),
                                  title: Text(
                                    recordText(row['title']),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                      color: navy,
                                    ),
                                  ),
                                  trailing: Icon(
                                    lesson?['id'] == row['id']
                                        ? Icons.edit_outlined
                                        : Icons.chevron_right,
                                    size: 20,
                                    color: navy,
                                  ),
                                  subtitle: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            row['publicationStatus'] ==
                                                'PUBLISHED'
                                            ? const Color(0xffe3f3e9)
                                            : const Color(0xffedf0f5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        friendlyStatus(
                                          row['publicationStatus'],
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              row['publicationStatus'] ==
                                                  'PUBLISHED'
                                              ? const Color(0xff21724c)
                                              : const Color(0xff52647a),
                                        ),
                                      ),
                                    ),
                                  ),
                                  onTap: saving
                                      ? null
                                      : () async {
                                          if (lesson?['id'] == row['id']) {
                                            return;
                                          }
                                          if (await canLeave() && mounted) {
                                            setState(() => select(parent, row));
                                          }
                                        },
                                ),
                              ),
                            ),
                        ],
                      ),
                      if ((lessons['${parent['id']}'] ?? []).isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No lessons yet. Add your first lesson below.',
                          ),
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
              CourseSectionHeading(
                'Edit lesson',
                icon: Icons.edit_note,
                action: OutlinedButton.icon(
                  onPressed: dirty || saving
                      ? null
                      : () => widget.onPreview(course!, module!, lesson!),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Preview lesson'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                dirty
                    ? 'Unsaved changes'
                    : lesson!['publicationStatus'] == 'PUBLISHED'
                    ? 'Published'
                    : 'Draft',
                style: TextStyle(
                  color: dirty ? gold : navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: title,
                enabled: !saving,
                maxLength: 150,
                onChanged: (_) => updateDirtyState(),
                decoration: const InputDecoration(labelText: 'Lesson title'),
              ),
              const SizedBox(height: 8),
              Text(
                'Module: ${recordText(module?['title'])}',
                style: const TextStyle(color: navy),
              ),
              const SizedBox(height: 24),
              const CourseSectionHeading(
                'Lesson notes',
                icon: Icons.notes_outlined,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                enabled: !saving,
                minLines: 5,
                maxLines: 12,
                onChanged: (_) => updateDirtyState(),
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

  Widget get courseStatistics {
    final rows = lessons.values.expand((items) => items).toList();
    final published = rows
        .where((row) => row['publicationStatus'] == 'PUBLISHED')
        .length;
    final metrics = [
      (
        'Modules',
        modules.length,
        Icons.layers_outlined,
        const Color(0xffeee8ff),
        const Color(0xff6341b5),
      ),
      (
        'Total lessons',
        rows.length,
        Icons.menu_book_outlined,
        const Color(0xffe6f1ff),
        const Color(0xff2463ae),
      ),
      (
        'Published lessons',
        published,
        Icons.check_circle_outline,
        const Color(0xffe4f6ed),
        const Color(0xff23804f),
      ),
      (
        'Draft lessons',
        rows.length - published,
        Icons.edit_outlined,
        const Color(0xfffff4dc),
        const Color(0xffa57718),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 500
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final metric in metrics)
              Container(
                width: width,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      metric.$4,
                      Color.lerp(metric.$4, Colors.white, .5)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: metric.$5.withValues(alpha: .15)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.$1,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${metric.$2}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: metric.$5.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(metric.$3, size: 32, color: metric.$5),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: allowExit || (!dirty && !saving),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leaveWorkspace(result);
    },
    child: Column(
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
          ],
        ),
        const SizedBox(height: 20),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        if (!loading && course != null) ...[
          courseStatistics,
          const SizedBox(height: 22),
        ],
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
        else ...[
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
      ],
    ),
  );
}
