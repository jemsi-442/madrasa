import 'package:flutter/material.dart';
import 'dashboard_components.dart';
import 'workspace_form_dialog.dart';

class CurriculumDeliveryHistoryDialog extends StatefulWidget {
  const CurriculumDeliveryHistoryDialog({
    super.key,
    required this.load,
    required this.adoptionId,
    required this.className,
  });
  final PageLoader load;
  final String adoptionId, className;

  @override
  State<CurriculumDeliveryHistoryDialog> createState() => _HistoryState();
}

class _HistoryState extends State<CurriculumDeliveryHistoryDialog> {
  int page = 1;
  int pendingPage = 1;
  bool pendingExpanded = false;
  late Future<dynamic> result = fetch();
  Future<dynamic> fetch() async {
    try {
      return await widget.load(
        '/api/school-curriculum/deliveries?${Uri(queryParameters: {'classCurriculumId': widget.adoptionId, 'page': '$page', 'pendingPage': '$pendingPage'}).query}',
      );
    } catch (_) {
      return null;
    }
  }

  void go(int target) => setState(() {
    page = target;
    result = fetch();
  });

  void goPending(int target) => setState(() {
    pendingPage = target;
    result = fetch();
  });

  void refresh() => setState(() {
    page = 1;
    pendingPage = 1;
    result = fetch();
  });

  Widget refreshButton() => TextButton.icon(
    onPressed: refresh,
    icon: const Icon(Icons.refresh),
    label: const Text('Refresh history'),
  );

  String date(dynamic value) {
    final parsed = DateTime.tryParse('$value')?.toLocal();
    if (parsed == null) return 'Date unavailable';
    return '${parsed.day}/${parsed.month}/${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => WorkspaceFormDialog(
    title: Text('Teaching history: ${widget.className}'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: FutureBuilder<dynamic>(
          future: result,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load teaching history.'),
                  TextButton(
                    onPressed: () => go(page),
                    child: const Text('Try again'),
                  ),
                  refreshButton(),
                ],
              );
            }
            final data = snapshot.data as Map;
            final items = data['items'] as List;
            final coverage = data['teachingCoverage'] as Map?;
            final pendingLessons = data['pendingLessons'] as List?;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerRight, child: refreshButton()),
                if (coverage != null) ...[
                  Text(
                    'Teaching coverage · v${coverage['version']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${coverage['taughtLessons']} / ${coverage['totalLessons']} lessons recorded as taught',
                  ),
                  const Text(
                    'Current adopted version only. Repeated teaching counts once per lesson.',
                  ),
                  if ((coverage['totalLessons'] as num) > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(
                        value:
                            ((coverage['taughtLessons'] as num) /
                                    (coverage['totalLessons'] as num))
                                .clamp(0.0, 1.0),
                      ),
                    )
                  else
                    const Text(
                      'No lessons in this version; coverage is not applicable.',
                    ),
                  const SizedBox(height: 12),
                  if (pendingLessons != null &&
                      (pendingLessons.isNotEmpty || pendingPage > 1))
                    ExpansionTile(
                      initiallyExpanded: pendingExpanded,
                      onExpansionChanged: (value) => pendingExpanded = value,
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Lessons without teaching records'),
                      subtitle: Text(
                        'Showing ${pendingLessons.length} of ${(coverage['totalLessons'] as num) - (coverage['taughtLessons'] as num)}. Current version only.',
                      ),
                      children: [
                        const Text(
                          'No teaching confirmation is recorded yet. This is not an assessment of learners.',
                        ),
                        for (final lesson in pendingLessons)
                          ListTile(
                            leading: const Icon(Icons.menu_book_outlined),
                            title: Text('${lesson['title']}'),
                          ),
                        if (pendingLessons.isEmpty)
                          const Text(
                            'No pending lessons on this page. Return to the previous page.',
                          ),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: pendingPage > 1
                                  ? () => goPending(pendingPage - 1)
                                  : null,
                              child: const Text('Previous lessons'),
                            ),
                            Text('Lessons page $pendingPage'),
                            TextButton(
                              onPressed: data['pendingHasMore'] == true
                                  ? () => goPending(pendingPage + 1)
                                  : null,
                              child: const Text('Next lessons'),
                            ),
                          ],
                        ),
                      ],
                    )
                  else if (pendingLessons != null &&
                      (coverage['totalLessons'] as num) > 0 &&
                      coverage['taughtLessons'] == coverage['totalLessons'])
                    const Text(
                      'All lessons in this version have a teaching record. Learner achievement is assessed separately.',
                    ),
                ],
                const WorkspaceFormNotice(
                  message:
                      'Teacher-reported teaching, not attendance, assessment or learner achievement. Earlier curriculum versions remain in this history. Times are local.',
                ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No teaching records on this page.'),
                  ),
                for (final row in items) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${row['lesson']['title']}'),
                    subtitle: Text(
                      '${row['assignment']['version']['subject']} / ${row['assignment']['version']['level']} / v${row['assignment']['version']['version']}\n${row['teacher']['fullName']} · ${date(row['taughtAt'])}',
                    ),
                  ),
                  const Divider(),
                ],
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: page > 1 ? () => go(page - 1) : null,
                      child: const Text('Previous'),
                    ),
                    Text('Page $page'),
                    TextButton(
                      onPressed: data['hasMore'] == true
                          ? () => go(page + 1)
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
