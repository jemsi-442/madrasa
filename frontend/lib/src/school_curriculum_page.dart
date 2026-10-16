import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'design_tokens.dart';
import 'workspace_form_dialog.dart';

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
    String? classId, subjectId;
    final form = GlobalKey<FormState>();
    final choice = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        title: const Text('Use curriculum in a class'),
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
                    decoration: const InputDecoration(
                      labelText: 'Existing school subject',
                    ),
                    items: [
                      for (final row in data['subjects'])
                        DropdownMenuItem(
                          value: '${row['id']}',
                          child: Text(
                            '${row['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => subjectId = v,
                    validator: (v) => v == null ? 'Choose a subject' : null,
                  ),
                  const SizedBox(height: 20),
                  const WorkspaceFormNotice(
                    message:
                        'Confirm this level fits your class. The assigned teacher can read this version and its lesson plans. Existing adoption cannot be replaced here; learner records remain unchanged.',
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
        const SnackBar(content: Text('Curriculum linked to the class.')),
      );
      reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException && e.statusCode == 409
                ? 'This class subject already has a curriculum version. Refresh to see its adoption.'
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
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${adoption['class']['name']} (${adoption['class']['academicYear']}) / ${adoption['subject']['name']}',
                      ),
                    ),
                  if (widget.isAdmin)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: FilledButton.icon(
                          onPressed:
                              saving ||
                                  (data['classes'] as List).isEmpty ||
                                  (data['subjects'] as List).isEmpty
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
                  if (widget.isAdmin &&
                      ((data['classes'] as List).isEmpty ||
                          (data['subjects'] as List).isEmpty))
                    const Text(
                      'Create a class and an active school subject before adopting curriculum.',
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
