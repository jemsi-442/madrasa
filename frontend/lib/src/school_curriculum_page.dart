import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'design_tokens.dart';
import 'workspace_form_dialog.dart';
import 'curriculum_delivery_history_dialog.dart';

class SchoolCurriculumPage extends StatefulWidget {
  const SchoolCurriculumPage({
    super.key,
    required this.load,
    required this.submit,
    required this.isAdmin,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final bool isAdmin;
  final int refreshToken;
  @override
  State<SchoolCurriculumPage> createState() => _SchoolCurriculumPageState();
}

class _SchoolCurriculumPageState extends State<SchoolCurriculumPage> {
  late Future<dynamic> future = widget.load('/api/school-curriculum');
  bool saving = false;
  final deliveryEvents = <String, String>{};
  final recordedDeliveries = <String>{};

  Future<void> recordTeaching(Map assignment, Map lesson) async {
    if (widget.isAdmin) return;
    final adoptions = (assignment['adoptions'] as List).cast<Map>();
    String? selected = adoptions.length == 1
        ? '${adoptions.single['id']}'
        : null;
    var sending = false;
    String? failure;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final key = '${assignment['id']}/$selected/${lesson['id']}';
          final recorded = recordedDeliveries.contains(key);
          return PopScope(
            canPop: !sending,
            child: WorkspaceFormDialog(
              title: const Text('Record lesson taught'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${lesson['title']}'),
                      Text(
                        '${assignment['version']['subject']} / Version ${assignment['version']['version']}',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selected,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Class taught',
                        ),
                        items: [
                          for (final adoption in adoptions)
                            DropdownMenuItem(
                              value: '${adoption['id']}',
                              child: Text(
                                '${adoption['class']['name']} (${adoption['class']['academicYear']})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: sending
                            ? null
                            : (value) => update(() {
                                selected = value;
                                failure = null;
                              }),
                      ),
                      const SizedBox(height: 16),
                      const WorkspaceFormNotice(
                        message:
                            'Confirm only after teaching this lesson. This records teaching now, not student attendance, assessment or achievement. An internet connection is required.',
                      ),
                      if (recorded)
                        const WorkspaceFormNotice(
                          message:
                              'Teaching recorded successfully during this visit.',
                        ),
                      if (failure != null)
                        WorkspaceFormNotice(message: failure!, isError: true),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: sending || selected == null || recorded
                      ? null
                      : () async {
                          final eventId = deliveryEvents.putIfAbsent(
                            key,
                            submissionId,
                          );
                          update(() {
                            sending = true;
                            failure = null;
                          });
                          try {
                            await widget
                                .submit('/api/school-curriculum/deliveries', {
                                  'classCurriculumId': selected,
                                  'assignmentId': assignment['id'],
                                  'lessonId': lesson['id'],
                                  'clientEventId': eventId,
                                });
                            if (!mounted || !context.mounted) return;
                            recordedDeliveries.add(key);
                            update(() => sending = false);
                          } catch (error) {
                            if (!mounted || !context.mounted) return;
                            update(() {
                              sending = false;
                              failure =
                                  error is ApiException &&
                                      [403, 404, 422].contains(error.statusCode)
                                  ? 'Could not record teaching. Check your class access and the adopted lesson before trying again.'
                                  : error is ApiException &&
                                        error.statusCode == 409
                                  ? 'The curriculum changed or another update is in progress. Retry here; if it persists, close and refresh the curriculum.'
                                  : 'Confirmation was not received. Retry here with the same event; do not refresh or leave this page until confirmed.';
                            });
                          }
                        },
                  child: Text(
                    sending
                        ? 'Recording...'
                        : recorded
                        ? 'Recorded'
                        : 'Confirm taught',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String historyDate(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  String historySummary(Map<String, dynamic> history) {
    final previous =
        (history['previousAssignment'] as Map?)?['version'] as Map? ?? {};
    final framework = [
      previous['subject'],
      previous['level'],
      previous['version'] == null ? null : 'v${previous['version']}',
    ].where((value) => value != null && '$value'.trim().isNotEmpty).join(' / ');
    final adoptedAt = historyDate(history['previousAdoptedAt']);
    final replacedAt = historyDate(history['replacedAt']);
    var period = '';
    if (adoptedAt.isEmpty) {
      if (replacedAt.isNotEmpty) period = ' · replaced $replacedAt';
    } else {
      period = ' · in use from $adoptedAt';
      if (replacedAt.isNotEmpty) period += ' to $replacedAt';
    }
    final label = framework.isEmpty ? 'curriculum version' : framework;
    return 'Previous: $label$period';
  }

  bool canAdopt(Map<String, dynamic> item, Map<String, dynamic> data) {
    if ((data['classes'] as List).isEmpty) return false;
    final mappedSubjectId = item['subjectId']?.toString();
    return (data['subjects'] as List).any(
      (subject) =>
          subject['isActive'] == true &&
          (mappedSubjectId == null || '${subject['id']}' == mappedSubjectId),
    );
  }

  String adoptionUnavailableMessage(
    Map<String, dynamic> item,
    Map<String, dynamic> data,
  ) {
    if ((data['classes'] as List).isEmpty) {
      return 'Create a class before adopting curriculum.';
    }
    final mappedSubjectId = item['subjectId']?.toString();
    if (mappedSubjectId != null) {
      return 'The school subject linked to this curriculum is inactive. Reactivate it before adopting this version in another class.';
    }
    return 'Create an active school subject before adopting curriculum.';
  }

  void reload() =>
      setState(() => future = widget.load('/api/school-curriculum'));
  @override
  void didUpdateWidget(covariant SchoolCurriculumPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) reload();
  }

  Future<void> adopt(
    Map<String, dynamic> assignment,
    Map<String, dynamic> data,
  ) async {
    String? classId, subjectId = assignment['subjectId']?.toString();
    final form = GlobalKey<FormState>();
    final choice = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        title: const Text('Adopt curriculum in a class'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${assignment['version']['subject']} / ${assignment['version']['level']} / ${assignment['version']['version']}',
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: [
                      for (final row in data['classes'])
                        DropdownMenuItem(
                          value: '${row['id']}',
                          child: Text(
                            '${row['name']} (${row['level']}, ${row['academicYear']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => classId = v,
                    validator: (v) => v == null ? 'Choose a class' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: subjectId,
                    decoration: const InputDecoration(
                      labelText: 'Existing school subject',
                    ),
                    items: [
                      for (final row in data['subjects'])
                        DropdownMenuItem(
                          value: '${row['id']}',
                          enabled: row['isActive'] == true,
                          child: Text(
                            '${row['name']}${row['isActive'] == true ? '' : ' (inactive)'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: assignment['subjectId'] == null
                        ? (v) => subjectId = v
                        : null,
                    validator: (v) =>
                        v == null ||
                            !(data['subjects'] as List).any(
                              (row) =>
                                  '${row['id']}' == v &&
                                  row['isActive'] == true,
                            )
                        ? 'Choose an active school subject'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  const WorkspaceFormNotice(
                    message:
                        'Choose the school subject for this assignment the first time. Later classes must use the same subject. Replacing an active class version preserves its history and does not change learner records.',
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
                  'assignmentId': assignment['id'],
                  'classId': classId,
                  'subjectId': subjectId,
                });
              }
            },
            child: const Text('Confirm adoption'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.submit('/api/school-curriculum/adoptions', choice);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Class curriculum updated. Previous adoption history is preserved.',
          ),
        ),
      );
      reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException && e.statusCode == 409
                ? 'The class curriculum changed. Refresh and try again.'
                : e is ApiException && e.statusCode == 422
                ? 'This curriculum is linked to another school subject. Refresh and check the selected subject.'
                : 'Could not adopt curriculum. Check your access and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load curriculum.'),
              TextButton(onPressed: reload, child: const Text('Try again')),
            ],
          ),
        );
      }
      final data = Map<String, dynamic>.from(snapshot.data as Map);
      final assignments = data['assignments'] as List;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Curriculum',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isAdmin
                ? 'Published frameworks available to your madrasa. Choose where they will be used.'
                : 'Published frameworks adopted by your assigned classes.',
          ),
          const SizedBox(height: 16),
          const WorkspaceFormNotice(
            message:
                'Availability, class adoption and learner achievement are separate. Reading a plan does not mark a lesson as taught or an objective as achieved.',
          ),
          const SizedBox(height: 20),
          if (assignments.isEmpty)
            Text(
              widget.isAdmin
                  ? 'No published curriculum has been assigned to your madrasa yet.'
                  : 'No curriculum has been adopted for your assigned classes yet. Contact your madrasa administrator.',
            ),
          for (final item in assignments) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AfaqDesign.panelDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${item['version']['subject']}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item['version']['level']} / Version ${item['version']['version']}',
                  ),
                  const SizedBox(height: 8),
                  Text('${item['version']['description']}'),
                  const Divider(height: 28),
                  const Text(
                    'Class adoption',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if ((item['adoptions'] as List).isEmpty)
                    const Text(
                      'Available to the madrasa; not adopted in any class in your scope.',
                    ),
                  for (final adoption in item['adoptions'])
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${adoption['class']['name']} (${adoption['class']['academicYear']}) / ${adoption['subject']['name']}',
                              ),
                              Text(
                                'Current curriculum: v${item['version']['version']}${historyDate(adoption['createdAt']).isEmpty ? '' : ' · in use since ${historyDate(adoption['createdAt'])}'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => CurriculumDeliveryHistoryDialog(
                              load: widget.load,
                              adoptionId: '${adoption['id']}',
                              className: '${adoption['class']['name']}',
                            ),
                          ),
                          icon: const Icon(Icons.history),
                          label: const Text('Teaching history'),
                        ),
                        for (final history in adoption['history'] as List)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 4),
                            child: Text(
                              historySummary(
                                Map<String, dynamic>.from(history),
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  if (widget.isAdmin)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: FilledButton.icon(
                          onPressed: saving || !canAdopt(item, data)
                              ? null
                              : () => adopt(
                                  Map<String, dynamic>.from(item),
                                  data,
                                ),
                          icon: const Icon(Icons.school_outlined),
                          label: const Text('Use in a class'),
                        ),
                      ),
                    ),
                  if (widget.isAdmin && !canAdopt(item, data))
                    Text(
                      adoptionUnavailableMessage(
                        Map<String, dynamic>.from(item as Map),
                        data,
                      ),
                    ),
                  ExpansionTile(
                    title: const Text('Topics & objectives'),
                    children: [
                      for (final topic in item['version']['topics'])
                        ListTile(
                          title: Text('${topic['title']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final objective in topic['objectives'])
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    '${objective['code']}: ${objective['description']}\nAssessment: ${objective['assessmentMethod']}\nCriteria: ${objective['criteria']}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  ExpansionTile(
                    title: const Text('Shared lesson plans'),
                    children: [
                      if ((item['version']['lessons'] as List).isEmpty)
                        const ListTile(
                          title: Text(
                            'No shared lesson plans in this version.',
                          ),
                        ),
                      for (final lesson in item['version']['lessons'])
                        ListTile(
                          title: Text(
                            '${lesson['title']} / ${lesson['durationMinutes']} min',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${lesson['activities']}'),
                              if (!widget.isAdmin &&
                                  lesson['id'] != null &&
                                  (item['adoptions'] as List).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        recordTeaching(item, lesson),
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
                                    label: const Text('Record lesson taught'),
                                  ),
                                ),
                              for (final link in lesson['objectives'])
                                Text(
                                  '${link['objective']['code']}: ${link['objective']['description']}',
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      );
    },
  );
}
