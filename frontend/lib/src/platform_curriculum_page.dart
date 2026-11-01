import 'package:flutter/material.dart';
import 'curriculum_save_conflict.dart';
import 'api_client.dart';
import 'design_tokens.dart';
import 'workspace_chrome.dart';
import 'workspace_form_dialog.dart';
import 'curriculum_topic_dialog.dart';
import 'curriculum_lesson_dialog.dart';
import 'curriculum_oversight_page.dart';

class PlatformCurriculumPage extends StatefulWidget {
  const PlatformCurriculumPage({
    super.key,
    required this.call,
    required this.accountId,
    required this.onSessionExpired,
    this.onOpenOversight,
  });
  final Future<dynamic> Function(String, {Map<String, dynamic>? body}) call;
  final String accountId;
  final VoidCallback onSessionExpired;
  final VoidCallback? onOpenOversight;
  @override
  State<PlatformCurriculumPage> createState() => _PlatformCurriculumPageState();
}

enum _ReadinessAction {
  createFramework,
  editDetails,
  organiseTopics,
  organiseLessons,
  publish,
}

const _maxMadrasaAssignmentBatch = 100;

class _PublicationReadiness {
  const _PublicationReadiness(this.blocker, this.action);

  final String? blocker;
  final _ReadinessAction action;
  bool get isReady => blocker == null;
}

class _PlatformCurriculumPageState extends State<PlatformCurriculumPage> {
  List<Map<String, dynamic>> items = [];
  int tab = 0, page = 1, total = 0, schools = 0;
  int detailTab = 0;
  bool busy = true, saving = false, draftsOnly = false;
  bool oversight = false;
  String? error;
  String? focusedId;
  String activeQuery = '';
  int loadGeneration = 0;
  final searchController = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    searchController.dispose();
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
    final generation = ++loadGeneration;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final query = <String, String>{
        'page': '$page',
        if (draftsOnly) 'review': 'true',
        if (focusedId != null) 'id': focusedId!,
        if (focusedId == null && activeQuery.isNotEmpty) 'q': activeQuery,
      };
      final data = await widget.call(
        '/curriculum?${Uri(queryParameters: query).query}',
      );
      if (!mounted || generation != loadGeneration) return;
      final loadedItems = (data['items'] as List).cast<Map<String, dynamic>>();
      final cloneInfo = data['cloneInfo'];
      if (focusedId != null && cloneInfo is Map) {
        final index = loadedItems.indexWhere((item) => item['id'] == focusedId);
        if (index >= 0) {
          loadedItems[index] = {
            ...loadedItems[index],
            'cloneInfo': Map<String, dynamic>.from(cloneInfo),
          };
        }
      }
      setState(() {
        items = loadedItems;
        total = data['total'];
        schools = data['madrasaCount'];
      });
    } catch (e) {
      if (!mounted || generation != loadGeneration) return;
      if (e is ApiException && e.statusCode == 401) widget.onSessionExpired();
      setState(() => error = 'Could not load curriculum. Please try again.');
    } finally {
      if (mounted && generation == loadGeneration) {
        setState(() => busy = false);
      }
    }
  }

  void searchCurriculum() {
    final nextQuery = searchController.text.trim();
    if (nextQuery == activeQuery && focusedId == null && page == 1) return;
    setState(() {
      activeQuery = nextQuery;
      focusedId = null;
      page = 1;
    });
    load();
  }

  String? _updatedAt(Map<String, dynamic> row) {
    final value = row['updatedAt'];
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is String && DateTime.tryParse(value) != null) return value;
    return null;
  }

  String _displayTimestamp(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return 'Date unavailable';
    final local = parsed.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${local.day} ${months[local.month - 1]} ${local.year} · $hour:$minute $period';
  }

  String _statusLabel(dynamic value) {
    final words = '$value'.toLowerCase().replaceAll('_', ' ').trim();
    if (words.isEmpty || words == 'null') return 'Unknown status';
    return words
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Future<bool> write(
    String path,
    Map<String, dynamic> body, {
    String? focus,
    String? expectedUpdatedAt,
    int nextTab = 2,
    int nextDetailTab = 0,
    String conflictMessage =
        'This framework changed or is no longer available. Refresh and try again.',
    String? validationMessage,
    void Function(String)? onFailure,
    VoidCallback? onStaleVersion,
  }) async {
    if (saving) return false;
    setState(() => saving = true);
    try {
      if (focus != null &&
          !path.endsWith('/assign') &&
          !path.endsWith('/clone') &&
          expectedUpdatedAt == null) {
        throw const ApiException('Framework version is unavailable', 409);
      }
      final result = await widget.call(
        path,
        body: {
          ...body,
          if (expectedUpdatedAt != null) 'expectedUpdatedAt': expectedUpdatedAt,
        },
      );
      if (!mounted) return false;
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
      return true;
    } catch (e) {
      if (!mounted) return false;
      if (e is ApiException && e.statusCode == 401) widget.onSessionExpired();
      if (e is ApiException && e.statusCode == 409) {
        setState(() {
          if (focus != null) focusedId = focus;
          draftsOnly = false;
          page = 1;
        });
        await load();
        if (!mounted) return false;
      }
      final positionTaken =
          e is ApiException &&
          e.statusCode == 409 &&
          e.message.contains('already uses this position');
      final versionAlreadyExists =
          e is ApiException &&
          e.statusCode == 409 &&
          e.message.contains('subject version already exists');
      final linkedObjective =
          e is ApiException &&
          e.statusCode == 409 &&
          e.message.contains('Remove this objective from lesson plans');
      final invalidObjectiveSelection =
          e is ApiException &&
          e.statusCode == 422 &&
          e.message == 'Choose objectives from this framework version';
      final staleForm =
          onFailure != null &&
          e is ApiException &&
          e.statusCode == 409 &&
          (e.message.startsWith('Framework changed') ||
              e.message.startsWith('Published frameworks cannot be edited'));
      var message = versionAlreadyExists
          ? path.endsWith('/edit')
                ? 'That subject and version already exist at the selected level. Choose a different level or create a new version.'
                : 'That version already exists for this subject and level. Choose a different version number.'
          : positionTaken
          ? 'That order number was just taken. Choose another position after checking the latest draft.'
          : linkedObjective
          ? 'This objective is used in a lesson plan. Keep its original code, or cancel and remove its lesson links before changing or deleting it. Your entries are still here.'
          : invalidObjectiveSelection
          ? 'One or more selected objectives are not available in this framework version. Review the selected objectives before saving. Your lesson details are still here; if the list is outdated, cancel and reopen the latest draft.'
          : staleForm
          ? 'This version changed or was published while you were editing. Your entries are still here for reference. Cancel and reopen the latest draft before saving; create a new version if it is published.'
          : e is ApiException && e.statusCode == 409
          ? conflictMessage
          : e is ApiException &&
                e.statusCode == 422 &&
                validationMessage != null
          ? validationMessage
          : 'Could not save. Check your permissions, version and current status, then retry.';
      if (e is ApiException && e.statusCode == 409 && error != null) {
        message +=
            ' The latest version could not be loaded. After closing this form, use Try again on the page before editing again.';
      }
      if (staleForm) onStaleVersion?.call();
      if (onFailure != null) {
        onFailure(message);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
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
    var submitting = false;
    var staleVersion = false;
    String? saveError;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !submitting,
          child: WorkspaceFormDialog(
            title: Text(row == null ? 'New framework' : 'Edit draft'),
            content: IgnorePointer(
              ignoring: submitting,
              child: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (saveError != null)
                          WorkspaceFormNotice(
                            message: saveError!,
                            isError: true,
                          ),
                        const WorkspaceFormSection(
                          title: 'Framework details',
                          description:
                              'Name the subject and its version. All fields are required.',
                        ),
                        TextFormField(
                          controller: subject,
                          readOnly: submitting,
                          enabled: row == null,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            hintText: 'For example, Arabic',
                            prefixIcon: Icon(Icons.menu_book_outlined),
                          ),
                          validator: (v) => (v?.trim().length ?? 0) < 2
                              ? 'Enter a subject'
                              : null,
                        ),
                        TextFormField(
                          controller: version,
                          readOnly: submitting,
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
                          readOnly: submitting,
                          maxLength: 500,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText:
                                'Briefly describe what this framework covers.',
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
                          readOnly: submitting,
                          minLines: 4,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Learning objectives',
                            hintText:
                                'Recognise Arabic letters\nRead simple words',
                          ),
                          validator: (v) {
                            final lines = (v ?? '')
                                .split('\n')
                                .where((x) => x.trim().isNotEmpty)
                                .toList();
                            return lines.isEmpty ||
                                    lines.length > 50 ||
                                    lines.any(
                                      (x) =>
                                          x.trim().length < 2 ||
                                          x.length > 1000,
                                    )
                                ? 'Enter 1-50 objectives, 2-1000 characters each'
                                : null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          initialValue: level,
                          readOnly: submitting,
                          decoration: const InputDecoration(
                            labelText: 'Level',
                            hintText: 'For example, Level 1',
                          ),
                          maxLength: 80,
                          onChanged: (value) => level = value.trim(),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter a level'
                              : null,
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
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(context),
                child: Text(
                  staleVersion ? 'Discard edits & view latest' : 'Cancel',
                ),
              ),
              FilledButton(
                onPressed: submitting || staleVersion
                    ? null
                    : () async {
                        if (form.currentState!.validate()) {
                          final body = <String, dynamic>{
                            if (row == null) 'subject': subject.text.trim(),
                            if (row == null) 'version': version.text.trim(),
                            'description': description.text.trim(),
                            'level': level,
                            'objectives': objectives.text
                                .split('\n')
                                .map((x) => x.trim())
                                .where((x) => x.isNotEmpty)
                                .toList(),
                          };
                          update(() {
                            submitting = true;
                            saveError = null;
                          });
                          final saved = await write(
                            row == null
                                ? '/curriculum'
                                : '/curriculum/${row['id']}/edit',
                            body,
                            focus: row?['id'] as String?,
                            expectedUpdatedAt: row == null
                                ? null
                                : _updatedAt(row),
                            onFailure: (message) => saveError = message,
                            onStaleVersion: () => staleVersion = true,
                          );
                          if (!context.mounted) return;
                          update(() => submitting = false);
                          if (saved) Navigator.pop(context);
                        }
                      },
                child: Text(submitting ? 'Saving...' : 'Save draft'),
              ),
            ],
          ),
        ),
      ),
    );
    // Controllers remain alive until the dialog's exit animation has completed.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    subject.dispose();
    version.dispose();
    description.dispose();
    objectives.dispose();
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
    final alreadyAssigned = (row['assignments'] as List? ?? [])
        .map((assignment) => '${assignment['organizationId']}')
        .toSet();
    final available = choices
        .where((school) => !alreadyAssigned.contains('${school['id']}'))
        .toList();
    final selected = <String>{};
    var searchQuery = '';
    var selectionLimitReached = false;
    final previews = <String, Map<String, dynamic>>{};
    final previewErrors = <String>{};
    final previewLoading = <String>{};
    final organizationIds = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final matching = available.where((school) {
            final query = searchQuery.trim().toLowerCase();
            return query.isEmpty ||
                '${school['name']}'.toLowerCase().contains(query) ||
                '${school['code']}'.toLowerCase().contains(query);
          }).toList();
          return WorkspaceFormDialog(
            title: Text('Assign ${row['subject']} ${row['version']}'),
            content: SizedBox(
              width: 560,
              height: MediaQuery.sizeOf(context).height * .68,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const WorkspaceFormNotice(
                    message:
                        'Choose one or more active madrasas. Trial madrasas keep existing access but can receive new assignments only after activation. Existing assignments and local lessons remain unchanged.',
                  ),
                  if (available.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          choices.isEmpty
                              ? 'No active madrasas are available.'
                              : 'This version is already assigned to every active madrasa.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Find an active madrasa',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => update(() => searchQuery = value),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: matching.isEmpty
                            ? null
                            : () => update(() {
                                final matchingIds = matching
                                    .map((school) => '${school['id']}')
                                    .toSet();
                                if (matchingIds.every(selected.contains)) {
                                  selected.removeAll(matchingIds);
                                  selectionLimitReached = false;
                                } else if (selected.length +
                                        matchingIds
                                            .difference(selected)
                                            .length >
                                    _maxMadrasaAssignmentBatch) {
                                  selectionLimitReached = true;
                                } else {
                                  selected.addAll(matchingIds);
                                  selectionLimitReached = false;
                                }
                              }),
                        icon: const Icon(Icons.done_all),
                        label: Text(
                          matching.isNotEmpty &&
                                  matching.every(
                                    (school) =>
                                        selected.contains('${school['id']}'),
                                  )
                              ? 'Clear matching selection'
                              : 'Select all matching (${matching.length})',
                        ),
                      ),
                    ),
                    if (selectionLimitReached)
                      const WorkspaceFormNotice(
                        isError: true,
                        message:
                            'A single assignment can include up to 100 madrasas. Remove some selections or assign the remaining madrasas in another batch.',
                      ),
                    Expanded(
                      child: matching.isEmpty
                          ? const Center(
                              child: Text(
                                'No active madrasas match this search.',
                              ),
                            )
                          : ListView.builder(
                              itemCount: matching.length,
                              itemBuilder: (_, index) {
                                final school = matching[index];
                                final id = '${school['id']}';
                                final preview = previews[id];
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    CheckboxListTile(
                                      value: selected.contains(id),
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('${school['name']}'),
                                      subtitle: Text('${school['code']}'),
                                      secondary: IconButton(
                                        tooltip: preview != null
                                            ? 'Hide madrasa preview'
                                            : 'Preview madrasa',
                                        onPressed: previewLoading.contains(id)
                                            ? null
                                            : () async {
                                                if (preview != null) {
                                                  update(
                                                    () => previews.remove(id),
                                                  );
                                                  return;
                                                }
                                                update(() {
                                                  previewErrors.remove(id);
                                                  previewLoading.add(id);
                                                });
                                                try {
                                                  final result = await widget.call(
                                                    '/curriculum/${row['id']}/assignment-preview?organizationId=${Uri.encodeQueryComponent(id)}',
                                                  );
                                                  if (!context.mounted) return;
                                                  update(
                                                    () => previews[id] =
                                                        Map<
                                                          String,
                                                          dynamic
                                                        >.from(result),
                                                  );
                                                } catch (error) {
                                                  if (!context.mounted) return;
                                                  if (error is ApiException &&
                                                      error.statusCode == 401) {
                                                    widget.onSessionExpired();
                                                  }
                                                  update(
                                                    () => previewErrors.add(id),
                                                  );
                                                } finally {
                                                  if (context.mounted) {
                                                    update(
                                                      () => previewLoading
                                                          .remove(id),
                                                    );
                                                  }
                                                }
                                              },
                                        icon: previewLoading.contains(id)
                                            ? const SizedBox.square(
                                                dimension: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Icon(
                                                preview != null
                                                    ? Icons
                                                          .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                              ),
                                      ),
                                      onChanged: (checked) => update(() {
                                        if (checked == true) {
                                          if (selected.length >=
                                              _maxMadrasaAssignmentBatch) {
                                            selectionLimitReached = true;
                                          } else {
                                            selected.add(id);
                                            selectionLimitReached = false;
                                          }
                                        } else {
                                          selected.remove(id);
                                          selectionLimitReached = false;
                                        }
                                      }),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                    ),
                                    if (previewErrors.contains(id))
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          left: 16,
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          'Could not load this madrasa preview. Try again.',
                                        ),
                                      ),
                                    if (preview != null)
                                      _assignmentPreviewCard(preview),
                                  ],
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${selected.length} / $_maxMadrasaAssignmentBatch madrasa(s) selected',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, selected.toList()),
                icon: const Icon(Icons.school_outlined),
                label: Text('Assign to ${selected.length}'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || organizationIds == null || organizationIds.isEmpty) return;
    final selectedSchools = choices
        .where((school) => organizationIds.contains('${school['id']}'))
        .toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        title: const Text('Confirm madrasa assignment'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${row['subject']} · ${row['level']} · v${row['version']}'),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .4,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final school in selectedSchools)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.account_balance_outlined),
                          title: Text('${school['name']}'),
                          subtitle: Text(
                            _assignmentConfirmationSubtitle(
                              school,
                              previews['${school['id']}'],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const WorkspaceFormNotice(
                message:
                    'Review the class and subject details shown for madrasa previews. A name match is only a suggestion. Assignment makes this published framework available; it does not adopt it in a class or record learner achievement.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.school_outlined),
            label: Text('Assign to ${selectedSchools.length}'),
          ),
        ],
      ),
    );
    if (mounted && confirm == true) {
      await write(
        '/curriculum/${row['id']}/assign',
        {'organizationIds': organizationIds},
        focus: row['id'],
        nextTab: 3,
        nextDetailTab: 4,
        validationMessage:
            'One or more selected madrasas is no longer active. Refresh the list and choose active madrasas again; no assignments were created.',
      );
    }
  }

  String _assignmentConfirmationSubtitle(
    Map<String, dynamic> school,
    Map<String, dynamic>? preview,
  ) {
    final code = '${school['code']}';
    if (preview == null || preview['madrasa'] is! Map) {
      return '$code · Preview not opened';
    }
    final madrasa = Map<String, dynamic>.from(preview['madrasa'] as Map);
    final subjects = (madrasa['activeSubjects'] as List?) ?? const [];
    final matches = subjects
        .where(
          (subject) =>
              subject is Map && subject['nameMatchesFramework'] == true,
        )
        .length;
    final classCount = madrasa['classCount'] ?? 0;
    final matchNote = matches == 1
        ? '1 subject name suggestion'
        : '$matches subject name suggestions';
    final classLabel = classCount == 1 ? 'class' : 'classes';
    final subjectLabel = subjects.length == 1
        ? 'active subject'
        : 'active subjects';
    return '$code · $classCount $classLabel · ${subjects.length} $subjectLabel · $matchNote';
  }

  Widget _assignmentPreviewCard(Map<String, dynamic> preview) {
    final madrasa = Map<String, dynamic>.from(preview['madrasa'] as Map);
    final framework = Map<String, dynamic>.from(preview['framework'] as Map);
    final branches = (madrasa['branches'] as List?) ?? const [];
    final classLevels = (madrasa['classLevels'] as List?) ?? const [];
    final subjects = (madrasa['activeSubjects'] as List?) ?? const [];
    final existing = preview['existingAssignment'] as Map?;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff5f8fc),
        border: Border.all(color: const Color(0xffdce5ee)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${madrasa['name']} · ${madrasa['code']}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Framework: ${framework['subject']} · ${framework['level']} · v${framework['version']}',
          ),
          Text(
            'Classes: ${madrasa['classCount']} · Active subjects: ${subjects.length}',
          ),
          if (branches.isNotEmpty)
            Text(
              'Branches: ${branches.map((branch) {
                final item = Map<String, dynamic>.from(branch as Map);
                return '${item['name']}${item['location'] == null ? '' : ' · ${item['location']}'}';
              }).join(', ')}',
            ),
          const SizedBox(height: 8),
          const Text(
            'Class levels',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          if (classLevels.isEmpty)
            const Text('No classes registered yet.')
          else
            for (final group in classLevels)
              Text(
                '${group['level']} · ${group['academicYear']}: ${group['classCount']} class(es)',
              ),
          const SizedBox(height: 8),
          const Text(
            'Active local subjects',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          if (subjects.isEmpty)
            const Text(
              'No active subjects. The madrasa admin will need to create or activate one before class adoption.',
            )
          else
            for (final subject in subjects)
              Text(
                '${subject['name']} (${subject['code']})${subject['nameMatchesFramework'] == true ? ' · name match suggestion only' : ''}',
              ),
          if (existing != null) ...[
            const SizedBox(height: 8),
            Text(
              'Already assigned · ${existing['classAdoptionCount']} class adoption(s)',
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${preview['note']}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> addTopic(
    Map<String, dynamic> row, [
    Map<String, dynamic>? topic,
  ]) async {
    final topics = row['topics'] as List? ?? [];
    final position = topic?['position'] as int? ?? _nextFreePosition(topics);
    if (position > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This draft has reached its topic limit.'),
        ),
      );
      return;
    }
    final maxPosition = _orderLimit(topics);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CurriculumTopicDialog(
        position: position,
        maxPosition: maxPosition,
        occupiedPositions: [
          for (final existing in topics)
            if (existing['id'] != topic?['id']) existing['position'] as int,
        ],
        topic: topic,
        onSave: (body) => saveContentDialog(
          '/curriculum/${row['id']}/topics${topic == null ? '' : '/${topic['id']}'}',
          body,
          row,
          1,
        ),
      ),
    );
  }

  Future<String?> saveContentDialog(
    String path,
    Map<String, dynamic> body,
    Map<String, dynamic> row,
    int section,
  ) async {
    String? error;
    var staleVersion = false;
    final saved = await write(
      path,
      body,
      focus: row['id'],
      expectedUpdatedAt: _updatedAt(row),
      nextTab: 1,
      nextDetailTab: section,
      onFailure: (message) => error = message,
      onStaleVersion: () => staleVersion = true,
    );
    if (staleVersion) throw CurriculumSaveConflict(error!);
    return saved ? null : error ?? 'Could not save. Please try again.';
  }

  Future<void> newVersion(Map<String, dynamic> row) async {
    final form = GlobalKey<FormState>();
    var version = '';
    var reason = '';
    var submitting = false;
    String? saveError;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !submitting,
          child: WorkspaceFormDialog(
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
                      if (saveError != null)
                        WorkspaceFormNotice(message: saveError!, isError: true),
                      WorkspaceFormNotice(
                        message:
                            'Copy ${row['subject']} ${row['version']} into a new draft. Existing madrasa assignments stay on the original version.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        readOnly: submitting,
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
                        readOnly: submitting,
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
                onPressed: submitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (form.currentState!.validate()) {
                          update(() {
                            submitting = true;
                            saveError = null;
                          });
                          final saved = await write(
                            '/curriculum/${row['id']}/clone',
                            {'version': version, 'reason': reason},
                            onFailure: (message) => saveError = message,
                          );
                          if (!context.mounted) return;
                          update(() => submitting = false);
                          if (saved) Navigator.pop(context);
                        }
                      },
                child: Text(submitting ? 'Creating...' : 'Create draft'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> lessonPlan(
    Map<String, dynamic> row, [
    Map<String, dynamic>? lesson,
  ]) async {
    final lessons = row['lessons'] as List? ?? [];
    final position = lesson?['position'] as int? ?? _nextFreePosition(lessons);
    if (position > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This draft has reached its lesson limit.'),
        ),
      );
      return;
    }
    final maxPosition = _orderLimit(lessons);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CurriculumLessonDialog(
        topics: row['topics'] as List? ?? [],
        position: position,
        maxPosition: maxPosition,
        occupiedPositions: [
          for (final existing in lessons)
            if (existing['id'] != lesson?['id']) existing['position'] as int,
        ],
        lesson: lesson,
        onSave: (body) => saveContentDialog(
          '/curriculum/${row['id']}/lessons${lesson == null ? '' : '/${lesson['id']}'}',
          body,
          row,
          2,
        ),
      ),
    );
  }

  int _nextFreePosition(List rows) {
    final occupied = rows
        .map((row) => (row as Map)['position'])
        .whereType<int>()
        .where((position) => position >= 1 && position <= 1000)
        .toSet();
    for (var position = 1; position <= 1000; position++) {
      if (!occupied.contains(position)) return position;
    }
    return 1001;
  }

  int _orderLimit(List rows) {
    var largest = 0;
    for (final row in rows) {
      final position = (row as Map)['position'];
      if (position is int && position > largest) largest = position;
    }
    return (largest + 1).clamp(1, 1000);
  }

  Future<void> removeDraftContent(
    Map<String, dynamic> row, {
    required String type,
    required String id,
    required String title,
  }) async {
    final isTopic = type == 'topics';
    if (isTopic) {
      final objectiveIds = <String>{};
      for (final topic in row['topics'] as List? ?? []) {
        if ('${topic['id']}' == id) {
          for (final objective in topic['objectives'] as List? ?? []) {
            objectiveIds.add('${objective['id']}');
          }
          break;
        }
      }
      final linkedLessons = <String>[];
      for (final lesson in row['lessons'] as List? ?? []) {
        final links = lesson['objectives'] as List? ?? [];
        if (links.any((link) {
          final objective = link['objective'] as Map?;
          final objectiveId = link['objectiveId'] ?? objective?['id'];
          return objectiveId != null && objectiveIds.contains('$objectiveId');
        })) {
          linkedLessons.add('${lesson['title']}');
        }
      }
      if (linkedLessons.isNotEmpty) {
        final review = await showDialog<bool>(
          context: context,
          builder: (context) => WorkspaceFormDialog(
            title: Text('"$title" is used in lesson plans'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const WorkspaceFormNotice(
                      message:
                          'Remove this topic from its lesson plans before deleting it. Edit each plan to unlink the objective, or remove the whole plan if it has no other objectives.',
                    ),
                    const SizedBox(height: 12),
                    for (final lessonTitle in linkedLessons)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.play_lesson_outlined),
                        title: Text(lessonTitle),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep topic'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Review lesson plans'),
              ),
            ],
          ),
        );
        if (mounted && review == true) {
          setState(() {
            focusedId = row['id'] as String;
            detailTab = 2;
            tab = 1;
            page = 1;
            draftsOnly = false;
          });
          load();
        }
        return;
      }
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        title: Text('Remove $title?'),
        content: SizedBox(
          width: 520,
          child: WorkspaceFormNotice(
            message: isTopic
                ? 'This removes the topic and its objectives from this draft. First remove its objectives from any lesson plans. Published versions are never changed.'
                : 'This removes the lesson plan and its objective links from this draft. Published versions are never changed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove from draft'),
          ),
        ],
      ),
    );
    if (mounted && ok == true) {
      await write(
        '/curriculum/${row['id']}/$type/$id/delete',
        const {},
        focus: row['id'],
        expectedUpdatedAt: _updatedAt(row),
        nextTab: 1,
        nextDetailTab: isTopic ? 1 : 2,
        conflictMessage: isTopic
            ? 'This topic is still linked to a lesson plan. Remove its objective links, then try again.'
            : 'This lesson plan changed or is no longer available. Refresh and try again.',
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
                'Publish this version now, then choose its madrasas. Lesson plans are optional, but add any central guidance before publishing. Published content cannot be edited; changes need a new version.',
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
        expectedUpdatedAt: _updatedAt(row),
        nextTab: 3,
        nextDetailTab: 4,
        validationMessage:
            'Check each lesson title, duration, teaching guidance and objective links, then try publishing again.',
      );
    }
  }

  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(22),
    decoration: AfaqDesign.panelDecoration(),
    child: child,
  );

  _PublicationReadiness publicationReadiness(Map<String, dynamic> row) {
    final subject = '${row['subject'] ?? ''}'.trim();
    final version = '${row['version'] ?? ''}'.trim();
    final description = '${row['description'] ?? ''}'.trim();
    final outcomes = row['objectives'] as List? ?? [];
    final topics = row['topics'] as List? ?? [];
    final level = '${row['level'] ?? ''}'.trim();
    if (subject.length < 2 || subject.length > 120) {
      return const _PublicationReadiness(
        'Start a new framework with a subject name between 2 and 120 characters.',
        _ReadinessAction.createFramework,
      );
    }
    if (version.length > 30 ||
        !RegExp(r'^\d+\.\d+(?:\.\d+)?$').hasMatch(version)) {
      return const _PublicationReadiness(
        'Start a new framework with a version such as 1.0 or 1.0.1.',
        _ReadinessAction.createFramework,
      );
    }
    if (description.length < 2 || description.length > 500) {
      return const _PublicationReadiness(
        'Set a framework description between 2 and 500 characters.',
        _ReadinessAction.editDetails,
      );
    }
    if (outcomes.isEmpty ||
        outcomes.length > 50 ||
        outcomes.any((outcome) {
          final value = '$outcome'.trim();
          return value.length < 2 || value.length > 1000;
        })) {
      return const _PublicationReadiness(
        'Add 1 to 50 learning outcomes, each 2 to 1000 characters.',
        _ReadinessAction.editDetails,
      );
    }
    if (level.isEmpty) {
      return const _PublicationReadiness(
        'Set the learning level first.',
        _ReadinessAction.editDetails,
      );
    }
    if (level.length > 80) {
      return const _PublicationReadiness(
        'Shorten the learning level to 80 characters.',
        _ReadinessAction.editDetails,
      );
    }
    if (topics.isEmpty) {
      return const _PublicationReadiness(
        'Add topics with measurable objectives, assessment methods and achievement criteria.',
        _ReadinessAction.organiseTopics,
      );
    }
    final topicPositions = <int>{};
    for (final topic in topics) {
      final title = '${topic['title'] ?? ''}'.trim();
      if (title.length < 2 || title.length > 150) {
        return const _PublicationReadiness(
          'Give each topic a title between 2 and 150 characters.',
          _ReadinessAction.organiseTopics,
        );
      }
      final objectives = topic['objectives'] as List? ?? [];
      if (objectives.isEmpty || objectives.length > 50) {
        return _PublicationReadiness(
          'Add 1 to 50 objectives to "$title".',
          _ReadinessAction.organiseTopics,
        );
      }
      final objectiveCodes = <String>{};
      for (final objective in objectives) {
        final code = '${objective['code'] ?? ''}'.trim();
        final description = '${objective['description'] ?? ''}'.trim();
        final method = '${objective['assessmentMethod'] ?? ''}';
        final criteria = '${objective['criteria'] ?? ''}'.trim();
        final label = code.isEmpty
            ? 'an objective in "$title"'
            : 'objective $code';
        if (code.length > 40 || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code)) {
          return _PublicationReadiness(
            'Use a valid code for $label.',
            _ReadinessAction.organiseTopics,
          );
        }
        if (!objectiveCodes.add(code.toLowerCase())) {
          return _PublicationReadiness(
            'Use a unique objective code within "$title".',
            _ReadinessAction.organiseTopics,
          );
        }
        if (description.length < 10 || description.length > 1000) {
          return _PublicationReadiness(
            'Describe the observable skill for $label in 10 to 1000 characters.',
            _ReadinessAction.organiseTopics,
          );
        }
        if (!const {
          'ORAL',
          'WRITTEN',
          'PRACTICAL',
          'OBSERVATION',
        }.contains(method)) {
          return _PublicationReadiness(
            'Choose an assessment method for $label.',
            _ReadinessAction.organiseTopics,
          );
        }
        if (criteria.length < 10 || criteria.length > 1000) {
          return _PublicationReadiness(
            'Add achievement criteria for $label in 10 to 1000 characters.',
            _ReadinessAction.organiseTopics,
          );
        }
      }
      final position = topic['position'];
      if (position is! int || position < 1 || position > 1000) {
        return _PublicationReadiness(
          'Set a valid order for "$title" (1 to 1000).',
          _ReadinessAction.organiseTopics,
        );
      }
      if (!topicPositions.add(position)) {
        return const _PublicationReadiness(
          'Give every topic a different order number.',
          _ReadinessAction.organiseTopics,
        );
      }
    }
    final frameworkObjectiveIds = <String>{
      for (final topic in topics)
        for (final objective in topic['objectives'] as List? ?? [])
          if (objective is Map && objective['id'] != null) '${objective['id']}',
    };
    final lessonPositions = <int>{};
    for (final lesson in row['lessons'] as List? ?? []) {
      final title = '${lesson['title'] ?? 'lesson'}'.trim();
      final duration = lesson['durationMinutes'];
      final activities = '${lesson['activities'] ?? ''}'.trim();
      if (title.length < 2 || title.length > 150) {
        return _PublicationReadiness(
          'Give each lesson a title between 2 and 150 characters.',
          _ReadinessAction.organiseLessons,
        );
      }
      final position = lesson['position'];
      if (position is! int || position < 1 || position > 1000) {
        return _PublicationReadiness(
          'Set a valid order for "$title" (1 to 1000).',
          _ReadinessAction.organiseLessons,
        );
      }
      if (duration is! int || duration < 1 || duration > 480) {
        return _PublicationReadiness(
          'Set the duration for "$title" between 1 and 480 minutes.',
          _ReadinessAction.organiseLessons,
        );
      }
      if (activities.length < 10 || activities.length > 10000) {
        return _PublicationReadiness(
          'Add teaching guidance for "$title" in 10 to 10000 characters.',
          _ReadinessAction.organiseLessons,
        );
      }
      if (!lessonPositions.add(position)) {
        return const _PublicationReadiness(
          'Give every lesson plan a different order number.',
          _ReadinessAction.organiseLessons,
        );
      }
      final linkedObjectives = lesson['objectives'] as List? ?? [];
      if (linkedObjectives.isEmpty ||
          linkedObjectives.any((link) {
            if (link is! Map) return true;
            final objective = link['objective'];
            final objectiveId = objective is Map
                ? objective['id']
                : link['objectiveId'];
            return objectiveId == null ||
                !frameworkObjectiveIds.contains('$objectiveId');
          })) {
        return _PublicationReadiness(
          'Link "$title" to at least one objective from this framework.',
          _ReadinessAction.organiseLessons,
        );
      }
    }
    return const _PublicationReadiness(null, _ReadinessAction.publish);
  }

  bool readyToPublish(Map<String, dynamic> row) =>
      publicationReadiness(row).isReady;

  bool assignmentIsActive(Map<String, dynamic> assignment) {
    final status = (assignment['organization'] as Map?)?['status'];
    return status == 'ACTIVE';
  }

  bool assignmentIsTrial(Map<String, dynamic> assignment) =>
      (assignment['organization'] as Map?)?['status'] == 'TRIAL';

  bool assignmentIsSuspended(Map<String, dynamic> assignment) =>
      (assignment['organization'] as Map?)?['status'] == 'SUSPENDED';

  int countAssignments(
    List assignments,
    bool Function(Map<String, dynamic>) test,
  ) => assignments
      .where((assignment) => test(Map<String, dynamic>.from(assignment as Map)))
      .length;

  int countActiveAssignments(List assignments) => assignments
      .where(
        (assignment) =>
            assignmentIsActive(Map<String, dynamic>.from(assignment as Map)),
      )
      .length;

  int countActiveAdoptions(List assignments) => assignments
      .where(
        (assignment) =>
            assignmentIsActive(Map<String, dynamic>.from(assignment as Map)),
      )
      .fold<int>(
        0,
        (count, assignment) =>
            count + ((assignment['_count']?['adoptions'] as int?) ?? 0),
      );

  int countTrialAdoptions(List assignments) => assignments
      .where(
        (assignment) =>
            assignmentIsTrial(Map<String, dynamic>.from(assignment as Map)),
      )
      .fold<int>(
        0,
        (count, assignment) =>
            count + ((assignment['_count']?['adoptions'] as int?) ?? 0),
      );

  String assignmentStatus(Map<String, dynamic> assignment) {
    final adopted = (assignment['_count']?['adoptions'] as int?) ?? 0;
    final subject = assignment['subject'] as Map<String, dynamic>?;
    final subjectStatus = assignment['subjectId'] == null
        ? adopted > 0
              ? 'Existing class adoption needs subject-link review'
              : 'School subject not linked'
        : subject == null
        ? 'Mapped subject unavailable'
        : subject['isActive'] == true
        ? 'School subject: ${subject['name']}'
        : 'Inactive subject: ${subject['name']}';
    final status = (assignment['organization'] as Map?)?['status'];
    if (status == 'SUSPENDED') {
      return 'Madrasa suspended · $adopted historical class adoptions · $subjectStatus';
    }
    if (status == 'TRIAL') {
      return 'Trial access · $adopted existing class adoptions · $subjectStatus';
    }
    if (status != 'ACTIVE') {
      return 'Madrasa status unavailable · $adopted recorded class adoptions · Not counted as active · $subjectStatus';
    }
    final adoptionLabel = adopted == 1
        ? '1 class adoption record'
        : '$adopted class adoption records';
    return '$adoptionLabel · $subjectStatus';
  }

  Widget nextStep(Map<String, dynamic> row) {
    final published = row['status'] == 'PUBLISHED';
    final needsLevel = '${row['level'] ?? ''}'.trim().isEmpty;
    final readiness = publicationReadiness(row);
    final ready = readiness.isReady;
    final assignments = row['assignments'] as List? ?? [];
    final activeAssignments = countActiveAssignments(assignments);
    final noActiveMadrasas = schools == 0;
    final allActiveMadrasasAssigned =
        schools > 0 && activeAssignments >= schools;
    final message = published
        ? noActiveMadrasas
              ? 'Published. There are no active madrasas available to assign this version to right now.'
              : allActiveMadrasasAssigned
              ? 'Assigned to all $schools active madrasas. Next, review subject links and class adoption.'
              : 'Assigned to $activeAssignments of $schools active madrasas. Assign it to more madrasas if needed.'
        : !ready
        ? 'Next step: ${readiness.blocker}'
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
            onPressed: saving || (published && noActiveMadrasas)
                ? null
                : () {
                    if (published) {
                      if (allActiveMadrasasAssigned) {
                        setState(() => detailTab = 4);
                      } else {
                        assign(row);
                      }
                    } else {
                      switch (readiness.action) {
                        case _ReadinessAction.createFramework:
                          edit(null);
                          break;
                        case _ReadinessAction.editDetails:
                          edit(row);
                          break;
                        case _ReadinessAction.organiseTopics:
                          setState(() => detailTab = 1);
                          break;
                        case _ReadinessAction.organiseLessons:
                          setState(() => detailTab = 2);
                          break;
                        case _ReadinessAction.publish:
                          setState(() => detailTab = 3);
                          break;
                      }
                    }
                  },
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              published
                  ? noActiveMadrasas
                        ? 'No active madrasas'
                        : allActiveMadrasasAssigned
                        ? 'Review assignments'
                        : 'Choose madrasa'
                  : readiness.action == _ReadinessAction.createFramework
                  ? 'Create corrected framework'
                  : readiness.action == _ReadinessAction.editDetails
                  ? needsLevel
                        ? 'Set level'
                        : 'Edit framework details'
                  : readiness.action == _ReadinessAction.publish
                  ? 'Check publication'
                  : readiness.action == _ReadinessAction.organiseLessons
                  ? 'Organise lesson plans'
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
    final assignments = row['assignments'] as List? ?? [];
    final cloneInfo = row['cloneInfo'] as Map<String, dynamic>?;
    final activeAssignmentTotal = countActiveAssignments(assignments);
    final trialAssignmentTotal = countAssignments(
      assignments,
      assignmentIsTrial,
    );
    final suspendedAssignmentTotal = countAssignments(
      assignments,
      assignmentIsSuspended,
    );
    final activeAdoptions = countActiveAdoptions(assignments);
    final trialAdoptions = countTrialAdoptions(assignments);
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
                    '$activeAssignmentTotal active madrasa assignments',
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
                '${lesson['title'] ?? 'Untitled lesson'} · ${lesson['durationMinutes'] ?? 0} min',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              SelectableText('${lesson['activities'] ?? ''}'),
              Wrap(
                spacing: 8,
                children: [
                  for (final link in lesson['objectives'] as List? ?? [])
                    Chip(
                      label: Text(
                        '${(link as Map)['objective']?['code'] ?? link['objectiveId'] ?? 'Objective'}',
                      ),
                    ),
                ],
              ),
              if (!published)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => lessonPlan(
                              row,
                              Map<String, dynamic>.from(lesson),
                            ),
                      child: const Text('Edit lesson plan'),
                    ),
                    TextButton.icon(
                      onPressed: saving
                          ? null
                          : () => removeDraftContent(
                              row,
                              type: 'lessons',
                              id: '${lesson['id']}',
                              title: '${lesson['title']}',
                            ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                  ],
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
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: saving
                          ? null
                          : () =>
                                addTopic(row, Map<String, dynamic>.from(topic)),
                      child: const Text('Edit topic'),
                    ),
                    TextButton.icon(
                      onPressed: saving
                          ? null
                          : () => removeDraftContent(
                              row,
                              type: 'topics',
                              id: '${topic['id']}',
                              title: '${topic['title']}',
                            ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                  ],
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
            if (cloneInfo != null) ...[
              WorkspaceFormNotice(
                message:
                    'Draft cloned from ${cloneInfo['sourceVersion']?['subject'] ?? row['subject']} ${cloneInfo['sourceVersion']?['version'] ?? cloneInfo['sourceVersionId']}. Reason: ${cloneInfo['reason']}. The source version and its madrasa assignments remain unchanged.',
              ),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 16),
            Text('Prepared by: ${row['createdByName'] ?? 'Not recorded'}'),
            if (row['publishedAt'] != null)
              Text('Published: ${_displayTimestamp(row['publishedAt'])}'),
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
                        '${_statusLabel(review['fromStatus'])} → ${_statusLabel(review['toStatus'])}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${review['actorName'] ?? 'Platform account'} · ${_displayTimestamp(review['createdAt'])}',
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
                '$activeAssignmentTotal / $schools active madrasas',
                style: const TextStyle(color: AfaqDesign.muted),
              ),
            ],
          ),
          if (showAssignments) ...[
            const SizedBox(height: 12),
            for (final assignment in assignments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance_outlined),
                title: Text(
                  '${assignment['organization']?['name'] ?? 'Madrasa unavailable'} (${assignment['organization']?['code'] ?? 'Code unavailable'})',
                ),
                subtitle: Text(
                  assignmentStatus(Map<String, dynamic>.from(assignment)),
                ),
              ),
            if (assignments.isEmpty) const Text('Not assigned yet.'),
            if (assignments.isNotEmpty)
              Text(
                '$activeAdoptions recorded class adoption(s) at active madrasas.${trialAssignmentTotal == 0 ? '' : ' $trialAdoptions existing class adoption(s) at $trialAssignmentTotal trial madrasa(s) remain available.'} ${suspendedAssignmentTotal == 0 ? '' : '$suspendedAssignmentTotal suspended assignment(s) are retained as history. '}These are adoption records, not proof that the linked subject is currently active or that learners achieved the objectives.',
                style: const TextStyle(color: AfaqDesign.muted),
              ),
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
  Widget build(BuildContext context) => oversight
      ? CurriculumOversightPage(
          load: (path) => widget.call(path),
          onBack: () => setState(() => oversight = false),
          onSessionExpired: widget.onSessionExpired,
        )
      : buildCurriculum(context);

  Widget buildCurriculum(BuildContext context) => LayoutBuilder(
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
          if (focusedId == null) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => searchCurriculum(),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Search curriculum',
                      hintText: 'Subject, topic or lesson',
                      helperText: 'You can also search by objective code.',
                      helperMaxLines: 2,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: busy
                                  ? null
                                  : () {
                                      searchController.clear();
                                      searchCurriculum();
                                    },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Search curriculum',
                  onPressed: searchCurriculum,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
              if (total > 0)
                Text(
                  activeQuery.isEmpty
                      ? '$total versions'
                      : '$total search results',
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 32,
                    color: AfaqDesign.gold,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    focusedId != null
                        ? 'Framework unavailable'
                        : activeQuery.isNotEmpty
                        ? 'No matching frameworks'
                        : draftsOnly
                        ? 'No unpublished frameworks'
                        : 'No frameworks yet',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AfaqDesign.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    focusedId != null
                        ? 'This framework is no longer available. Return to the library to choose another.'
                        : activeQuery.isNotEmpty
                        ? 'No frameworks match "$activeQuery".'
                        : draftsOnly
                        ? 'There are no drafts to continue. Published versions are still available in the subject library.'
                        : 'Use New framework to add your first subject and learning objectives.',
                    style: const TextStyle(
                      color: AfaqDesign.muted,
                      height: 1.5,
                    ),
                  ),
                  if (draftsOnly &&
                      activeQuery.isEmpty &&
                      focusedId == null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () {
                              setState(() {
                                draftsOnly = false;
                                tab = 0;
                                page = 1;
                              });
                              load();
                            },
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('View subject library'),
                    ),
                  ],
                  if (activeQuery.isNotEmpty)
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              searchController.clear();
                              searchCurriculum();
                            },
                      icon: const Icon(Icons.close),
                      label: const Text('Clear search'),
                    ),
                ],
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
                        'Browse subjects, levels and versions.',
                        style: TextStyle(color: AfaqDesign.muted, height: 1.5),
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
          if (total > 0 && !busy && error == null)
            Row(
              children: [
                Text(
                  'Showing ${(page - 1) * 24 + 1}-${page * 24 < total ? page * 24 : total} of $total',
                ),
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
      final releaseRow = focusedId != null
          ? (items.isNotEmpty ? items.first : null)
          : (visible.isNotEmpty ? visible.first : null);
      final release = panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Release control',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (releaseRow == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your publishing steps',
                    style: TextStyle(color: AfaqDesign.muted, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  for (final step in [
                    (1, 'Draft content'),
                    (2, 'Publish when ready'),
                    (3, 'Assign to madrasas'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xfff8f0da),
                            child: Text(
                              '${step.$1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AfaqDesign.gold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              step.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              )
            else ...[
              Builder(
                builder: (context) {
                  final published = releaseRow['status'] == 'PUBLISHED';
                  final ready = readyToPublish(releaseRow);
                  final assignments = releaseRow['assignments'] as List? ?? [];
                  final activeAssignments = countActiveAssignments(assignments);
                  final trialAssignments = countAssignments(
                    assignments,
                    assignmentIsTrial,
                  );
                  final suspendedAssignments = countAssignments(
                    assignments,
                    assignmentIsSuspended,
                  );
                  final trialAdoptions = countTrialAdoptions(assignments);
                  final adoptions = countActiveAdoptions(assignments);
                  final activeAssignmentRows = assignments
                      .where(
                        (assignment) => assignmentIsActive(
                          Map<String, dynamic>.from(assignment as Map),
                        ),
                      )
                      .toList();
                  final pendingSubjectMappings = activeAssignmentRows
                      .where((assignment) => assignment['subjectId'] == null)
                      .length;
                  final inactiveSubjectMappings = activeAssignmentRows
                      .where(
                        (assignment) =>
                            assignment['subjectId'] != null &&
                            assignment['subject']?['isActive'] != true,
                      )
                      .length;
                  final steps = [
                    (
                      'Complete draft',
                      ready
                          ? 'Level, topics and measurable objectives are ready.'
                          : 'Add a level, topics and measurable assessment criteria.',
                      ready,
                    ),
                    (
                      'Publish version',
                      published
                          ? 'Published directly by Super Admin; no approval step.'
                          : ready
                          ? 'Ready to publish when you confirm the draft.'
                          : 'Complete the draft before publishing.',
                      published,
                    ),
                    (
                      'Assign to madrasas',
                      !published
                          ? 'Available after publication.'
                          : activeAssignments == 0
                          ? suspendedAssignments == 0 && trialAssignments == 0
                                ? 'Published, but not assigned to any active madrasa yet.'
                                : 'No active assignments. ${trialAssignments == 0 ? '' : '$trialAssignments trial madrasa(s) retain access to existing assignments. '}${suspendedAssignments == 0 ? '' : '$suspendedAssignments suspended assignment(s) are retained as history.'}'
                          : 'Assigned to $activeAssignments active madrasa(s).${trialAssignments == 0 ? '' : ' $trialAssignments trial madrasa(s) retain access to existing assignments ($trialAdoptions class adoptions).'}${suspendedAssignments == 0 ? '' : ' $suspendedAssignments suspended assignment(s) retained as history.'}',
                      activeAssignments > 0,
                    ),
                    (
                      'Link school subjects',
                      !published
                          ? 'Available after publication and madrasa assignment.'
                          : activeAssignments == 0
                          ? 'Assign this version to an active madrasa before linking its school subject.'
                          : pendingSubjectMappings > 0
                          ? '$pendingSubjectMappings assignment(s) need a school-subject link; check existing adoptions before changing legacy mappings.'
                          : inactiveSubjectMappings > 0
                          ? '$inactiveSubjectMappings linked school subject(s) are inactive.'
                          : 'All active madrasa assignments have a linked active school subject.',
                      activeAssignments > 0 &&
                          pendingSubjectMappings == 0 &&
                          inactiveSubjectMappings == 0,
                    ),
                    (
                      'Class adoption',
                      activeAssignments == 0
                          ? 'No active madrasa assignment; no class can currently adopt this version.'
                          : adoptions == 0
                          ? 'Assigned; no class adoption record exists yet.'
                          : '$adoptions class adoption record(s) across active madrasas.',
                      adoptions > 0,
                    ),
                  ];
                  return Column(
                    children: [
                      for (final step in steps.indexed)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: step.$2.$3
                                ? const Color(0xfff0f7f2)
                                : const Color(0xfffbfcfd),
                            border: Border.all(
                              color: step.$2.$3
                                  ? const Color(0xffcfe5d5)
                                  : const Color(0xffe2e7eb),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: step.$2.$3
                                    ? const Color(0xffdcefe2)
                                    : const Color(0xfff8f0da),
                                child: step.$2.$3
                                    ? const Icon(
                                        Icons.check,
                                        size: AfaqDesign.iconSmall,
                                        color: Color(0xff28875a),
                                      )
                                    : Text(
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      step.$2.$2,
                                      style: const TextStyle(
                                        color: AfaqDesign.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffeaf1ff),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learning history stays protected',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AfaqDesign.ink,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Teachers manage local lesson plans. Published updates do not overwrite recorded learning history.',
                    style: TextStyle(color: AfaqDesign.muted, height: 1.5),
                  ),
                ],
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
                fontSize: 12,
                height: 1.5,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Curriculum & Subjects',
                  style: TextStyle(
                    fontSize: 32,
                    height: 1.2,
                    color: AfaqDesign.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Develop shared learning frameworks and choose what each madrasa adopts.',
                  style: TextStyle(color: AfaqDesign.muted, height: 1.5),
                ),
                const SizedBox(height: 20),
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
                      child: const Text('View unpublished'),
                    ),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : widget.onOpenOversight ??
                                () => setState(() => oversight = true),
                      icon: const Icon(Icons.insights_outlined),
                      label: const Text('Learning Oversight'),
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
