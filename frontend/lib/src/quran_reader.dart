import 'package:flutter/material.dart';
import 'api_client.dart';
import 'dashboard_components.dart' show PageLoader;
import 'design_tokens.dart';
import 'workspace_form_dialog.dart';

Future<void> showQuranReader(
  BuildContext context,
  PageLoader load, {
  int? initialChapterId,
  int? ayahFrom,
  int? ayahTo,
}) => showDialog<void>(
  context: context,
  builder: (context) => WorkspaceFormDialog(
    title: const Text("Qur'an Reader"),
    icon: Icons.menu_book_outlined,
    content: SizedBox(
      width: 900,
      height: MediaQuery.sizeOf(context).height * .6,
      child: QuranReader(
        load: load,
        initialChapterId: initialChapterId,
        ayahFrom: ayahFrom,
        ayahTo: ayahTo,
      ),
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
  const QuranReader({
    super.key,
    required this.load,
    this.initialChapterId,
    this.ayahFrom,
    this.ayahTo,
  });
  final PageLoader load;
  final int? initialChapterId, ayahFrom, ayahTo;

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
  String? passageNotice;

  int get passagePage => ((widget.ayahFrom ?? 1) - 1) ~/ 10 + 1;

  bool selectedVerse(Map verse) {
    final number = verse['verse_number'];
    return chapterId == widget.initialChapterId &&
        widget.ayahFrom != null &&
        number is int &&
        number >= widget.ayahFrom! &&
        number <= (widget.ayahTo ?? widget.ayahFrom!);
  }

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
      final requested = widget.initialChapterId;
      final chosen = requested == null
          ? available.first
          : available.where((row) => row['id'] == requested).firstOrNull;
      final start = widget.ayahFrom;
      final end = widget.ayahTo ?? start;
      final count = chosen?['verses_count'];
      final invalidPassage =
          start != null &&
          (start < 1 || end! < start || count is! int || end > count);
      setState(() {
        chapters = available;
        limited = isLimited;
        chapterId = chosen?['id'] as int?;
        passageNotice = chosen == null
            ? 'The tracker surah is unavailable in this environment. Choose another surah to read without changing your tracker.'
            : invalidPassage
            ? 'The tracker passage is outside the available surah. Check the selected ayahs in the tracker.'
            : null;
        if (invalidPassage) chapterId = null;
        loading = false;
      });
      if (chapterId != null) {
        await loadVerses(requested == null ? 1 : passagePage);
      }
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
      passageNotice = null;
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

  Future<void> searchSurah() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (_) => _SurahSearch(chapters: chapters),
    );
    if (!mounted || selected == null || selected == chapterId) return;
    chapterId = selected;
    await loadVerses(1);
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
          decoration: InputDecoration(
            labelText: 'Surah',
            suffixIcon: IconButton(
              tooltip: 'Search surahs',
              onPressed: loading || accessFailure ? null : searchSurah,
              icon: const Icon(Icons.search),
            ),
          ),
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
      if (widget.initialChapterId != null && widget.ayahFrom != null) ...[
        Text(
          'Tracker passage: ${widget.initialChapterId}:${widget.ayahFrom}'
          ' - ${widget.initialChapterId}:${widget.ayahTo ?? widget.ayahFrom}',
        ),
        const SizedBox(height: 12),
      ],
      if (loading) ...[
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        const Text('Loading Quran content...'),
      ] else if (passageNotice != null) ...[
        WorkspaceFormNotice(message: passageNotice!),
      ] else if (error != null) ...[
        WorkspaceFormNotice(message: error!),
        if (!accessFailure)
          Wrap(
            spacing: 12,
            children: [
              TextButton(
                onPressed: () =>
                    chapterId == null ? loadChapters() : loadVerses(page),
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
                if (selectedVerse(verse)) ...[
                  const Text(
                    'Selected in tracker',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AfaqDesign.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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

class _SurahSearch extends StatefulWidget {
  const _SurahSearch({required this.chapters});
  final List<Map> chapters;

  @override
  State<_SurahSearch> createState() => _SurahSearchState();
}

class _SurahSearchState extends State<_SurahSearch> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final term = query.trim().toLowerCase();
    final number = int.tryParse(term);
    final matches = widget.chapters
        .where(
          (chapter) =>
              term.isEmpty ||
              (number != null
                  ? chapter['id'] == number
                  : '${chapter['name_simple']} ${chapter['name_arabic'] ?? ''}'
                        .toLowerCase()
                        .contains(term)),
        )
        .toList();
    return WorkspaceFormDialog(
      title: const Text('Find a surah'),
      icon: Icons.search,
      content: SizedBox(
        width: 560,
        height: MediaQuery.sizeOf(context).height * .45,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Surah name or number',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            Text('${matches.length} surahs found'),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching surahs. Try another name or number.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final chapter = matches[index];
                        return ListTile(
                          leading: Text('${chapter['id']}'),
                          title: Text('${chapter['name_simple']}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              Navigator.pop(context, chapter['id'] as int),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
