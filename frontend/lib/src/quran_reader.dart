import 'package:flutter/material.dart';
import 'api_client.dart';
import 'dashboard_components.dart' show PageLoader;
import 'design_tokens.dart';
import 'workspace_form_dialog.dart';

Future<void> showQuranReader(BuildContext context, PageLoader load) =>
    showDialog<void>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        title: const Text("Qur'an Reader"),
        icon: Icons.menu_book_outlined,
        content: SizedBox(
          width: 900,
          height: MediaQuery.sizeOf(context).height * .6,
          child: QuranReader(load: load),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close reader'),
          ),
        ],
      ),
    );

/// Read-only provider content. Deliberately has no student or submission context.
class QuranReader extends StatefulWidget {
  const QuranReader({super.key, required this.load});
  final PageLoader load;

  @override
  State<QuranReader> createState() => _QuranReaderState();
}

class _QuranReaderState extends State<QuranReader> {
  final scroll = ScrollController();
  List<Map> chapters = [], verses = [];
  int? chapterId, nextPage;
  int page = 1, totalPages = 1, generation = 0;
  bool loading = true, limited = false;
  String? error;
  bool accessFailure = false;

  @override
  void initState() {
    super.initState();
    loadChapters();
  }

  @override
  void dispose() {
    generation++;
    scroll.dispose();
    super.dispose();
  }

  String failure(Object exception) {
    if (exception is ApiException) {
      if (exception.statusCode == 401) {
        return 'Your session has expired. Sign in again.';
      }
      if (exception.statusCode == 403) {
        return 'Quran content is not available for this account.';
      }
    }
    return 'Quran content is unavailable. The provider may not be configured or reachable. No replacement text is shown.';
  }

  void failed(Object exception, int request) {
    if (!mounted || request != generation) return;
    setState(() {
      loading = false;
      verses = [];
      error = failure(exception);
      accessFailure =
          exception is ApiException &&
          [401, 403].contains(exception.statusCode);
    });
  }

  Future<void> loadChapters() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
      accessFailure = false;
      verses = [];
    });
    try {
      final data =
          await widget.load('/api/teacher-workspace/quran/content/chapters')
              as Map;
      final rows = (data['chapters'] as List).cast<Map>();
      final isLimited = data['limitedContent'] == true;
      final available = rows
          .where((row) => !isLimited || (row['id'] as int) <= 2)
          .toList();
      if (available.isEmpty) {
        throw const FormatException('No available chapters');
      }
      if (!mounted || request != generation) return;
      setState(() {
        chapters = available;
        limited = isLimited;
        chapterId = available.first['id'] as int;
      });
      await loadVerses(1);
    } catch (exception) {
      failed(exception, request);
    }
  }

  Future<void> loadVerses(int targetPage) async {
    final request = ++generation;
    setState(() {
      page = targetPage;
      loading = true;
      error = null;
      accessFailure = false;
      verses = [];
      nextPage = null;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
    try {
      final data =
          await widget.load(
                '/api/teacher-workspace/quran/content/chapters/$chapterId/verses?page=$targetPage&per_page=10',
              )
              as Map;
      final rows = (data['verses'] as List).cast<Map>();
      final pagination = data['pagination'] as Map;
      final returnedTotal = pagination['total_pages'];
      final returnedNext = pagination['next_page'];
      if (data['chapterId'] != chapterId ||
          pagination['current_page'] != targetPage ||
          returnedTotal is! int ||
          returnedTotal < targetPage ||
          returnedNext !=
              (targetPage < returnedTotal ? targetPage + 1 : null) ||
          rows.isEmpty ||
          rows.any(
            (row) =>
                row['text_uthmani'] is! String ||
                (row['text_uthmani'] as String).isEmpty,
          )) {
        throw const FormatException('Invalid reader response');
      }
      if (!mounted || request != generation) return;
      setState(() {
        verses = rows;
        nextPage = returnedNext as int?;
        totalPages = returnedTotal;
        loading = false;
      });
    } catch (exception) {
      failed(exception, request);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    controller: scroll,
    children: [
      const Text(
        'Content source: Quran Foundation',
        style: TextStyle(color: AfaqDesign.muted),
      ),
      const SizedBox(height: 8),
      const Text(
        'Reading does not record student achievement or save a learning session.',
      ),
      if (limited) ...[
        const SizedBox(height: 12),
        const WorkspaceFormNotice(
          message:
              'Test environment: only Al-Fatihah and Al-Baqarah are available. This is not the full Quran.',
        ),
      ],
      if (chapters.isNotEmpty) ...[
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: ValueKey(chapterId),
          initialValue: chapterId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Surah'),
          items: [
            for (final chapter in chapters)
              DropdownMenuItem(
                value: chapter['id'] as int,
                child: Text(
                  '${chapter['id']}. ${chapter['name_simple']}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: loading || accessFailure
              ? null
              : (value) {
                  if (value == null) return;
                  chapterId = value;
                  loadVerses(1);
                },
        ),
      ],
      const SizedBox(height: 20),
      if (loading) ...[
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        const Text('Loading Quran content...'),
      ] else if (error != null) ...[
        WorkspaceFormNotice(message: error!),
        if (!accessFailure)
          Wrap(
            spacing: 12,
            children: [
              TextButton(
                onPressed: () =>
                    chapters.isEmpty ? loadChapters() : loadVerses(page),
                child: const Text('Try again'),
              ),
              if (chapters.isNotEmpty && page > 1)
                TextButton(
                  onPressed: () => loadVerses(page - 1),
                  child: const Text('Previous page'),
                ),
            ],
          ),
      ] else ...[
        for (final verse in verses)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: AfaqDesign.panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ayah ${verse['verse_key']}',
                  style: const TextStyle(color: AfaqDesign.muted),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  verse['text_uthmani'] as String,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 30, height: 2),
                ),
              ],
            ),
          ),
        Text('Page $page of $totalPages'),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: page > 1 ? () => loadVerses(page - 1) : null,
              child: const Text('Previous'),
            ),
            TextButton(
              onPressed: nextPage != null ? () => loadVerses(nextPage!) : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    ],
  );
}
