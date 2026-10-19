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
  late Future<dynamic> result = fetch();
  Future<dynamic> fetch() async {
    try {
      return await widget.load(
        '/api/school-curriculum/deliveries?${Uri(queryParameters: {'classCurriculumId': widget.adoptionId, 'page': '$page'}).query}',
      );
    } catch (_) {
      return null;
    }
  }

  void go(int target) => setState(() {
    page = target;
    result = fetch();
  });

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
                ],
              );
            }
            final data = snapshot.data as Map;
            final items = data['items'] as List;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
