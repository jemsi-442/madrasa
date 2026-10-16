import 'package:flutter/material.dart';
import 'api_client.dart';
import 'design_tokens.dart';
import 'workspace_chrome.dart';
import 'workspace_form_dialog.dart';
import 'curriculum_topic_dialog.dart';
import 'curriculum_lesson_dialog.dart';

class PlatformCurriculumPage extends StatefulWidget {
  const PlatformCurriculumPage({
    super.key,
    required this.call,
    required this.accountId,
    required this.onSessionExpired,
  });
  final Future<dynamic> Function(String, {Map<String, dynamic>? body}) call;
  final String accountId;
  final VoidCallback onSessionExpired;
  @override
  State<PlatformCurriculumPage> createState() => _PlatformCurriculumPageState();
}

class _PlatformCurriculumPageState extends State<PlatformCurriculumPage> {
  List<Map<String, dynamic>> items = [];
  int tab = 0, page = 1, total = 0, schools = 0;
  int detailTab = 0;
  bool busy = true, saving = false, draftsOnly = false;
  String? error;
  String? focusedId;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  static const tabs = [
    'Subject library',
    'Learning objectives',
    'Versions & publishing',
    'Madrasa assignments',
  ];
  static const detailTabs = [
    'Overview',
    'Topics & Objectives',
    'Lesson Plans',
    'Versions',
    'Assignments',
  ];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.call(
        '/curriculum?page=$page${draftsOnly ? '&review=true' : ''}${focusedId == null ? '' : '&id=${Uri.encodeQueryComponent(focusedId!)}'}',
      );
      if (!mounted) return;
      setState(() {
        items = (data['items'] as List).cast<Map<String, dynamic>>();
        total = data['total'];
        schools = data['madrasaCount'];
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) widget.onSessionExpired();
      setState(() => error = 'Could not load curriculum. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> write(
    String path,
    Map<String, dynamic> body, {
    String? focus,
    int nextTab = 2,
    int nextDetailTab = 0,
  }) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final result = await widget.call(path, body: body);
      if (!mounted) return;
      setState(() {
        focusedId = focus ?? result['id'] as String;
        tab = nextTab;
        detailTab = nextDetailTab;
        draftsOnly = false;
        page = 1;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Curriculum updated.')));
      await load();
      if (mounted && scroll.hasClients) {
        await scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) widget.onSessionExpired();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save. Check your permissions, version and current status, then retry.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    final subject = TextEditingController(text: row?['subject']);
    final version = TextEditingController(text: row?['version'] ?? '1.0');
    final description = TextEditingController(text: row?['description']);
    final objectives = TextEditingController(
      text: (row?['objectives'] as List?)?.join('\n'),
    );
    final form = GlobalKey<FormState>();
    var level = '${row?['level'] ?? ''}';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        title: Text(row == null ? 'New framework' : 'Edit draft'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const WorkspaceFormSection(
                    title: 'Framework details',
                    description:
                        'Name the subject and its version. All fields are required.',
                  ),
                  TextFormField(
                    controller: subject,
                    enabled: row == null,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      hintText: 'For example, Arabic',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                    validator: (v) =>
                        (v?.trim().length ?? 0) < 2 ? 'Enter a subject' : null,
                  ),
                  TextFormField(
                    controller: version,
                    enabled: row == null,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: 'Version',
                      hintText: '1.0',
                      prefixIcon: Icon(Icons.layers_outlined),
                    ),
                    validator: (v) =>
                        RegExp(r'^\d+\.\d+(?:\.\d+)?$').hasMatch(v ?? '')
                        ? null
                        : 'Use a version such as 1.0',
                  ),
                  TextFormField(
                    controller: description,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Briefly describe what this framework covers.',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Enter a description'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  const WorkspaceFormSection(
                    title: 'Learning outcomes',
                    description:
                        'Describe what learners should be able to do. Write one clear objective per line.',
                  ),
                  TextFormField(
                    controller: objectives,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Learning objectives',
                      hintText: 'Recognise Arabic letters\nRead simple words',
                    ),
                    validator: (v) {
                      final lines = (v ?? '')
                          .split('\n')
                          .where((x) => x.trim().isNotEmpty)
                          .toList();
                      return lines.isEmpty ||
                              lines.length > 50 ||
                              lines.any(
                                (x) => x.trim().length < 2 || x.length > 1000,
                              )
                          ? 'Enter 1-50 objectives, 2-1000 characters each'
                          : null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    initialValue: level,
                    decoration: const InputDecoration(
                      labelText: 'Level',
                      hintText: 'For example, Level 1',
                    ),
                    maxLength: 80,
                    onChanged: (value) => level = value.trim(),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Enter a level' : null,
                  ),
                  const WorkspaceFormNotice(
                    message:
                        'Save your work as a draft, then publish when ready. No approval is required.',
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
                  if (row == null) 'subject': subject.text.trim(),
                  if (row == null) 'version': version.text.trim(),
                  'description': description.text.trim(),
                  'level': level,
                  'objectives': objectives.text
                      .split('\n')
                      .map((x) => x.trim())
                      .where((x) => x.isNotEmpty)
                      .toList(),
                });
              }
            },
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
    // Controllers remain alive until the dialog's exit animation has completed.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    subject.dispose();
    version.dispose();
    description.dispose();
    objectives.dispose();
    if (mounted && result != null) {
      await write(
        row == null ? '/curriculum' : '/curriculum/${row['id']}/edit',
        result,
        focus: row?['id'] as String?,
      );
    }
  }

  Future<void> assign(Map<String, dynamic> row) async {
    if (saving) return;
    setState(() => saving = true);
    List<Map<String, dynamic>> choices;
    try {
      final data = await widget.call('/madrasas?status=ACTIVE&export=true');
      choices = (data['items'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load active madrasas. Please try again.'),
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => saving = false);
    }
    if (!mounted) return;
    String? selected;
    final id = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Assign ${row['subject']} ${row['version']}'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Previous version assignments and local lessons remain unchanged.',
                ),
                const SizedBox(height: 16),
                if (choices.isEmpty)
                  const Text('No active madrasas are available.')
                else
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Madrasa'),
                    items: [
                      for (final school in choices)
                        DropdownMenuItem(
                          value: school['id'] as String,
                          child: Text(
                            '${school['name']} (${school['code']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => update(() => selected = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(context, selected),
              child: const Text('Assign version'),
            ),
          ],
        ),
      ),
    );
    if (mounted && id != null) {
      await write(
        '/curriculum/${row['id']}/assign',
        {'organizationId': id},
        focus: row['id'],
        nextTab: 3,
        nextDetailTab: 4,
      );
    }
  }

  Future<void> addTopic(
    Map<String, dynamic> row, [
    Map<String, dynamic>? topic,
  ]) async {
    final topics = row['topics'] as List? ?? [];
    final position =
        topics.fold<int>(
          0,
          (max, topic) =>
              (topic['position'] as int) > max ? topic['position'] as int : max,
        ) +
        1;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CurriculumTopicDialog(
        position: topic?['position'] ?? position,
        topic: topic,
      ),
    );
    if (mounted && result != null) {
      await write(
        '/curriculum/${row['id']}/topics${topic == null ? '' : '/${topic['id']}'}',
        result,
        focus: row['id'],
        nextTab: 1,
        nextDetailTab: 1,
      );
    }
  }

  Future<void> newVersion(Map<String, dynamic> row) async {
    final form = GlobalKey<FormState>();
    var version = '';
    var reason = '';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        title: const Text('Create new version'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WorkspaceFormNotice(
                    message:
                        'Copy ${row['subject']} ${row['version']} into a new draft. Existing madrasa assignments stay on the original version.',
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'New version',
                      hintText: 'For example, 1.1',
                    ),
                    maxLength: 30,
                    onChanged: (value) => version = value.trim(),
                    validator: (value) =>
                        !RegExp(
                          r'^\d+\.\d+(?:\.\d+)?$',
                        ).hasMatch((value ?? '').trim())
                        ? 'Use a version such as 1.1'
                        : value!.trim() == row['version']
                        ? 'Choose a different version number'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Reason for this version',
                    ),
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 1000,
                    onChanged: (value) => reason = value.trim(),
                    validator: (value) => (value ?? '').trim().length < 10
                        ? 'Describe the changes planned (at least 10 characters)'
                        : null,
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
                Navigator.pop(context, {'version': version, 'reason': reason});
              }
            },
            child: const Text('Create draft'),
          ),
        ],
      ),
    );
    if (mounted && result != null) {
      await write('/curriculum/${row['id']}/clone', result);
    }
  }

  Future<void> lessonPlan(
    Map<String, dynamic> row, [
    Map<String, dynamic>? lesson,
  ]) async {
    final lessons = row['lessons'] as List? ?? [];
    final position =
        lessons.fold<int>(
          0,
          (n, l) => (l['position'] as int) > n ? l['position'] as int : n,
        ) +
        1;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CurriculumLessonDialog(
        topics: row['topics'] as List? ?? [],
        position: lesson?['position'] ?? position,
        lesson: lesson,
      ),
    );
    if (mounted && result != null) {
      await write(
        '/curriculum/${row['id']}/lessons${lesson == null ? '' : '/${lesson['id']}'}',
        result,
        focus: row['id'],
        nextTab: 1,
        nextDetailTab: 2,
      );
    }
  }

  Future<void> transition(Map<String, dynamic> row, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        title: Text('Publish ${row['subject']} ${row['version']}?'),
        content: const SizedBox(
          width: 540,
          child: WorkspaceFormNotice(
            message:
                'Publish this version now, then choose its madrasas. Published content cannot be edited; further changes need a new version.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish now'),
          ),
        ],
      ),
    );
    if (mounted && ok == true) {
      await write(
        '/curriculum/${row['id']}/transition',
        {'action': 'publish'},
        focus: row['id'],
        nextTab: 3,
        nextDetailTab: 4,
      );
    }
  }

  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(22),
    decoration: AfaqDesign.panelDecoration(),
    child: child,
  );

  bool readyToPublish(Map<String, dynamic> row) {
    final topics = row['topics'] as List? ?? [];
    return '${row['level'] ?? ''}'.trim().isNotEmpty &&
        topics.isNotEmpty &&
        topics.every(
          (topic) => (topic['objectives'] as List? ?? []).isNotEmpty,
        );
  }

  Widget nextStep(Map<String, dynamic> row) {
    final published = row['status'] == 'PUBLISHED';
    final needsLevel = '${row['level'] ?? ''}'.trim().isEmpty;
    final ready = readyToPublish(row);
    final message = published
        ? 'Published. Next step: select Assign to madrasa. Existing lessons and previous assignments stay unchanged.'
        : needsLevel
        ? 'Next step: set the learning level before organising topics.'
        : !ready
        ? 'Next step: add topics with measurable objectives, assessment methods and achievement criteria.'
        : 'Next step: check your draft, then publish when ready. Lesson plans can be prepared before publication. No approval is required.';
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your next step',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: saving
                ? null
                : () {
                    if (published) {
                      assign(row);
                    } else if (needsLevel) {
                      edit(row);
                    } else {
                      setState(() => detailTab = ready ? 3 : 1);
                    }
                  },
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              published
                  ? 'Choose madrasa'
                  : needsLevel
                  ? 'Set level'
                  : ready
                  ? 'Check publication'
                  : 'Organise topics',
            ),
          ),
        ],
      ),
    );
  }

  Widget card(Map<String, dynamic> row) {
    final published = row['status'] == 'PUBLISHED';
    final focused = focusedId != null;
    final showTopics = focused ? detailTab == 1 : tab == 1;
    final showVersions = focused ? detailTab == 3 : tab == 2;
    final showAssignments = focused ? detailTab == 4 : tab == 3;
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffe7f3ed),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: Color(0xff28875a),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: published
                      ? const Color(0xffe7f3ed)
                      : const Color(0xfff8f0da),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${row['status']}'.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: published
                        ? const Color(0xff28875a)
                        : AfaqDesign.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            row['subject'],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            row['description'],
            style: const TextStyle(color: AfaqDesign.muted),
          ),
          const SizedBox(height: 12),
          Text(
            'Level: ${(row['level'] as String?)?.isNotEmpty == true ? row['level'] : 'Not set'} · ${(row['topics'] as List? ?? []).length} topics',
          ),
          if (focused && detailTab == 0) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Chip(
                  label: Text(
                    '${(row['topics'] as List? ?? []).length} topics',
                  ),
                ),
                Chip(
                  label: Text(
                    '${(row['lessons'] as List? ?? []).length} lesson plans',
                  ),
                ),
                Chip(
                  label: Text(
                    '${row['_count']['assignments']} madrasa assignments',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'General learning outcomes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final objective in row['objectives'])
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('- $objective'),
              ),
            const SizedBox(height: 16),
            const WorkspaceFormNotice(
              message:
                  'Madrasa assignment makes this version available. It does not mean a class has adopted it or a learner has achieved its objectives.',
            ),
          ],
          if (focused && detailTab == 2) ...[
            const SizedBox(height: 18),
            const Text(
              'Lesson plans',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if ((row['lessons'] as List? ?? []).isEmpty)
              const Text(
                'No lesson plans yet. Add objectives, then plan how they will be taught.',
              ),
            for (final lesson in (row['lessons'] as List? ?? [])) ...[
              const SizedBox(height: 12),
              Text(
                '${lesson['title']} · ${lesson['durationMinutes']} min',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              SelectableText('${lesson['activities']}'),
              Wrap(
                spacing: 8,
                children: [
                  for (final link in lesson['objectives'])
                    Chip(label: Text('${link['objective']['code']}')),
                ],
              ),
              if (!published)
                TextButton(
                  onPressed: saving
                      ? null
                      : () =>
                            lessonPlan(row, Map<String, dynamic>.from(lesson)),
                  child: const Text('Edit lesson plan'),
                ),
            ],
            if (!published && (row['topics'] as List? ?? []).isNotEmpty)
              OutlinedButton.icon(
                onPressed: saving ? null : () => lessonPlan(row),
                icon: const Icon(Icons.play_lesson_outlined),
                label: const Text('Plan a lesson'),
              ),
            const Divider(height: 28),
          ],
          if (showTopics) ...[
            if (!published &&
                ((row['level'] as String? ?? '').isEmpty ||
                    (row['topics'] as List? ?? []).isEmpty)) ...[
              const SizedBox(height: 14),
              const WorkspaceFormNotice(
                message:
                    'Before publishing: set the level in Edit draft, then add a topic with assessment methods and achievement criteria. General learning outcomes alone are not enough.',
              ),
            ],
            for (final topic in (row['topics'] as List? ?? [])) ...[
              const Divider(height: 24),
              Text(
                '${topic['title']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (!published)
                TextButton(
                  onPressed: saving
                      ? null
                      : () => addTopic(row, Map<String, dynamic>.from(topic)),
                  child: const Text('Edit topic'),
                ),
              for (final objective in topic['objectives'])
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        '${objective['code']}: ${objective['description']}',
                      ),
                      Text('Assessment: ${objective['assessmentMethod']}'),
                      SelectableText(
                        'Achievement criteria: ${objective['criteria']}',
                      ),
                    ],
                  ),
                ),
            ],
            if (!published)
              TextButton.icon(
                onPressed: saving ? null : () => addTopic(row),
                icon: const Icon(Icons.add),
                label: const Text('Add topic & objectives'),
              ),
          ],
          if (showTopics) ...[
            const SizedBox(height: 16),
            for (final objective in row['objectives'])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('- $objective'),
              ),
          ],
          if (showVersions) ...[
            const SizedBox(height: 16),
            Text('Prepared by: ${row['createdBy'] ?? 'Not recorded'}'),
            if (row['publishedAt'] != null)
              Text('Published: ${row['publishedAt']}'),
            if ((row['reviews'] as List? ?? []).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Recent version history',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final review in (row['reviews'] as List))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${review['fromStatus']} → ${review['toStatus']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${review['actorId']} · ${review['createdAt']}',
                        style: const TextStyle(color: AfaqDesign.muted),
                      ),
                      if (review['comment'] != null)
                        SelectableText('${review['comment']}'),
                    ],
                  ),
                ),
            ],
          ],
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Version ${row['version']}',
                  style: const TextStyle(color: AfaqDesign.muted),
                ),
              ),
              Text(
                '${row['_count']['assignments']} / $schools madrasas',
                style: const TextStyle(color: AfaqDesign.muted),
              ),
            ],
          ),
          if (showAssignments) ...[
            const SizedBox(height: 12),
            for (final a in row['assignments'])
              Text(
                '${a['organization']['name']} (${a['organization']['code']})',
              ),
            if ((row['assignments'] as List).isEmpty)
              const Text('Not assigned yet.'),
          ],
          if (focusedId == null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy || saving
                    ? null
                    : () {
                        setState(() {
                          focusedId = row['id'];
                          detailTab = 0;
                          tab = 1;
                          page = 1;
                          draftsOnly = false;
                        });
                        load();
                      },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Open framework'),
              ),
            ),
          if (showVersions ||
              showAssignments ||
              (focused && detailTab == 0)) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!published)
                  OutlinedButton(
                    onPressed: saving ? null : () => edit(row),
                    child: const Text('Edit draft'),
                  ),
                if (!published)
                  FilledButton(
                    onPressed: saving || !readyToPublish(row)
                        ? null
                        : () => transition(row, 'publish'),
                    child: const Text('Publish version'),
                  ),
                if (published)
                  OutlinedButton.icon(
                    onPressed: saving ? null : () => newVersion(row),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Create new version'),
                  ),
                if (published)
                  OutlinedButton(
                    onPressed: saving ? null : () => assign(row),
                    child: const Text('Assign to madrasa'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final narrow = bounds.maxWidth < 1000;
      final navigationTabs = focusedId == null ? tabs : detailTabs;
      final selectedTab = focusedId == null ? tab : detailTab;
      final visible = items
          .where(
            (r) =>
                !draftsOnly ||
                r['status'] == 'DRAFT' ||
                r['status'] == 'IN_REVIEW' ||
                r['status'] == 'APPROVED',
          )
          .toList();
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final row in visible) {
        groups.putIfAbsent('${row['subject']}', () => []).add(row);
      }
      final library = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (focusedId != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy || saving
                    ? null
                    : () {
                        setState(() {
                          focusedId = null;
                          tab = 0;
                          page = 1;
                        });
                        load();
                      },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to subject library'),
              ),
            ),
            if (!busy && error == null && items.isNotEmpty)
              nextStep(items.first),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  focusedId != null
                      ? detailTabs[detailTab]
                      : tab == 0
                      ? 'Shared subject library'
                      : tabs[tab],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$total versions',
                style: const TextStyle(color: AfaqDesign.muted),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (busy)
            const LinearProgressIndicator()
          else if (error != null)
            panel(
              Column(
                children: [
                  Text(error!),
                  TextButton(onPressed: load, child: const Text('Try again')),
                ],
              ),
            )
          else if (visible.isEmpty)
            panel(
              const Text(
                'No frameworks to display. Create a framework to begin.',
              ),
            )
          else
            LayoutBuilder(
              builder: (_, c) {
                final two = c.maxWidth > 650 && focusedId == null;
                if (tab == 0 && focusedId == null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Grouped by subject. Levels and versions below are from this page; use pagination to see more.',
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 20,
                        runSpacing: 24,
                        children: [
                          for (final group in groups.entries)
                            SizedBox(
                              key: ValueKey('subject-group-${group.key}'),
                              width: two ? (c.maxWidth - 20) / 2 : c.maxWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    group.key,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  for (final row in group.value) ...[
                                    card(row),
                                    if (row != group.value.last)
                                      const SizedBox(height: 12),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                }
                return Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    for (final row in visible)
                      SizedBox(
                        width: two ? (c.maxWidth - 18) / 2 : c.maxWidth,
                        child: card(row),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Page $page'),
              const Spacer(),
              IconButton(
                tooltip: 'Previous page',
                onPressed: busy || page == 1
                    ? null
                    : () {
                        page--;
                        load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed: busy || page * 24 >= total
                    ? null
                    : () {
                        page++;
                        load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      );
      final release = panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Release control',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            for (final step in [
              ('Draft content', 'Build subject objectives and activities.'),
              (
                'Publish a version',
                'Publish directly when ready. No approval required.',
              ),
              ('Assign to madrasas', 'Keep a record of versions in use.'),
            ].indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xffe2e7eb)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: const Color(0xfff8f0da),
                      child: Text(
                        '${step.$1 + 1}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AfaqDesign.gold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.$2.$1,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            step.$2.$2,
                            style: const TextStyle(color: AfaqDesign.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xffeaf1ff),
              child: const Text(
                'Local lesson planning stays with teachers. Central updates do not overwrite recorded learning history.',
              ),
            ),
          ],
        ),
      );
      return SingleChildScrollView(
        controller: scroll,
        padding: EdgeInsets.all(narrow ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'AFAQ / INSTITUTION WORKSPACE',
              style: TextStyle(
                color: AfaqDesign.gold,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 18,
              runSpacing: 12,
              children: [
                const Text(
                  'Curriculum & Subjects',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () {
                              setState(() {
                                tab = 2;
                                page = 1;
                                draftsOnly = true;
                                focusedId = null;
                              });
                              load();
                            },
                      child: const Text('View drafts'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AfaqDesign.gold,
                      ),
                      onPressed: saving ? null : () => edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('New framework'),
                    ),
                    WorkspaceRefreshButton(onRefresh: load, loading: busy),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Develop shared learning frameworks and control what each madrasa adopts.',
              style: TextStyle(color: AfaqDesign.muted),
            ),
            const SizedBox(height: 28),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < navigationTabs.length; i++)
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selectedTab == i
                                ? AfaqDesign.gold
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                if (focusedId != null) {
                                  setState(() => detailTab = i);
                                  return;
                                }
                                final reload = draftsOnly;
                                setState(() {
                                  tab = i;
                                  draftsOnly = false;
                                  if (reload) page = 1;
                                });
                                if (reload) load();
                              },
                        child: Text(
                          navigationTabs[i],
                          style: TextStyle(
                            color: selectedTab == i
                                ? AfaqDesign.gold
                                : AfaqDesign.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 24),
            if (focusedId != null)
              library
            else if (narrow) ...[
              library,
              const SizedBox(height: 20),
              release,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: library),
                  const SizedBox(width: 24),
                  SizedBox(width: 300, child: release),
                ],
              ),
          ],
        ),
      );
    },
  );
}
