import 'package:flutter/material.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'workspace_form_dialog.dart';
import 'curriculum_detail_components.dart';
import 'design_tokens.dart';

class _HistoryAccessFailure {
  const _HistoryAccessFailure(this.expired);
  final bool expired;
}

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
    } on ApiException catch (error) {
      if ([401, 403, 404].contains(error.statusCode)) {
        return _HistoryAccessFailure(error.statusCode == 401);
      }
      return null;
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
      width: 720,
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
            if (snapshot.data is _HistoryAccessFailure) {
              final failure = snapshot.data as _HistoryAccessFailure;
              return WorkspaceFormNotice(
                isError: true,
                message: failure.expired
                    ? 'Your session has expired. Close this history and sign in again.'
                    : 'Teaching history is unavailable for this class or account. Close this history and refresh your curriculum to check access.',
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
                  CurriculumDetailPanel(
                    title: 'Teaching coverage · v${coverage['version']}',
                    accent: AfaqDesign.green,
                    icon: Icons.bar_chart_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${coverage['taughtLessons']} / ${coverage['totalLessons']} lessons recorded as taught',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AfaqDesign.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Current adopted version only. Repeated teaching counts once per lesson.',
                          style: TextStyle(
                            color: AfaqDesign.muted,
                            height: 1.5,
                          ),
                        ),
                        if ((coverage['totalLessons'] as num) > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                              color: AfaqDesign.green,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (pendingLessons != null &&
                      (pendingLessons.isNotEmpty || pendingPage > 1))
                    ExpansionTile(
                      key: PageStorageKey(
                        '${widget.adoptionId}-pending-lessons',
                      ),
                      initiallyExpanded: pendingExpanded,
                      onExpansionChanged: (value) => pendingExpanded = value,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      childrenPadding: const EdgeInsets.all(12),
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
                const SizedBox(height: 24),
                const Text(
                  'Recorded teaching',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AfaqDesign.ink,
                  ),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No teaching records on this page.'),
                  ),
                for (final row in items) ...[
                  CurriculumDetailPanel(
                    title: '${row['lesson']['title']}',
                    icon: Icons.check_circle_outline,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            CurriculumDetailTag(
                              '${row['assignment']['version']['subject']}',
                            ),
                            CurriculumDetailTag(
                              '${row['assignment']['version']['level']} / v${row['assignment']['version']['version']}',
                              accent: AfaqDesign.actionGold,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CurriculumDetailField(
                          label: 'Recorded by',
                          value: '${row['teacher']['fullName']}',
                        ),
                        const SizedBox(height: 16),
                        CurriculumDetailField(
                          label: 'Taught on (local time)',
                          value: date(row['taughtAt']),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                const WorkspaceFormNotice(
                  message:
                      'Teacher-reported teaching, not attendance, assessment or learner achievement. Earlier curriculum versions remain in this history. Times are local.',
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
