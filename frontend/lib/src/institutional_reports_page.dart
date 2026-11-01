import 'automatic_data_updates.dart';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'admin_forms.dart' show submissionId;
import 'date_selection.dart';
import 'design_tokens.dart';
import 'report_preview.dart';

class InstitutionalReportsPage extends StatefulWidget {
  const InstitutionalReportsPage({
    super.key,
    required this.load,
    required this.post,
  });
  final Future<dynamic> Function(String) load;
  final Future<dynamic> Function(String, Map<String, dynamic>) post;
  @override
  State<InstitutionalReportsPage> createState() => _ReportsState();
}

class _ReportsState extends State<InstitutionalReportsPage> {
  late final AutomaticDataUpdates updates;
  bool syncing = false, stale = false, accessLost = false;
  DateTime month = DateTime.now();
  String? scope;
  final sections = <String>{'attendance', 'learning', 'donations', 'followups'};
  static const labels = {
    'attendance': 'Madrasa participation and attendance',
    'learning': 'Lessons taught and Qur\'an observations',
    'donations': 'Monthly confirmed donor receipts',
    'followups': 'Open learner support follow-ups',
  };
  List<dynamic> schools = [], recent = [];
  Map<String, dynamic>? snapshot;
  bool busy = true, saving = false, hasMore = false;
  bool generationFailed = false;
  int generation = 0, page = 1;
  String? error, savedId;
  String requestId = submissionId();

  @override
  void initState() {
    super.initState();
    updates = AutomaticDataUpdates(
      canUpdate: () => mounted,
      update: syncLatest,
    );
    initialize();
  }

  @override
  void dispose() {
    updates.dispose();
    super.dispose();
  }

  Future<void> syncLatest() async {
    if (!mounted ||
        accessLost ||
        busy ||
        saving ||
        syncing ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final ticket = generation;
    final historyPage = page;
    syncing = true;
    try {
      final latest = sections.isEmpty
          ? null
          : await widget.post('/institution-reports/preview', input);
      final reports = await widget.load(
        '/institution-reports?page=$historyPage',
      );
      if (!mounted || ticket != generation || saving || historyPage != page) {
        return;
      }
      setState(() {
        snapshot = latest == null
            ? null
            : Map<String, dynamic>.from(latest as Map);
        recent = reports['items'] as List;
        hasMore = reports['hasMore'] == true;
        stale = false;
        if (!generationFailed) error = null;
      });
    } catch (e) {
      if (!mounted || ticket != generation) return;
      setState(() {
        stale = true;
        if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
          accessLost = true;
          snapshot = null;
          recent = [];
          savedId = null;
          error =
              'Report access is unavailable. Sign in again or check your permissions.';
        }
      });
    } finally {
      syncing = false;
    }
  }

  Map<String, dynamic> get input => {
    'month': monthValue(month),
    'organizationId': scope,
    'sections': sections.toList(),
  };

  Future<void> initialize() async {
    accessLost = false;
    try {
      final result = await widget.load('/institution-reports/options');
      if (!mounted) return;
      setState(() => schools = result['items'] as List);
      await history();
      if (mounted) await refresh();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Unable to load reports. Please retry.';
        });
      }
    }
  }

  Future<void> history() async {
    final result = await widget.load('/institution-reports?page=$page');
    if (mounted) {
      setState(() {
        recent = result['items'] as List;
        hasMore = result['hasMore'] == true;
      });
    }
  }

  Future<void> refresh() async {
    final ticket = ++generation;
    setState(() {
      busy = true;
      error = null;
      snapshot = null;
      savedId = null;
      generationFailed = false;
      requestId = submissionId();
    });
    if (sections.isEmpty) {
      setState(() => busy = false);
      return;
    }
    try {
      final result = await widget.post('/institution-reports/preview', input);
      if (mounted && ticket == generation) {
        setState(() {
          snapshot = Map<String, dynamic>.from(result as Map);
          stale = false;
        });
      }
    } catch (_) {
      if (mounted && ticket == generation) {
        setState(
          () => error =
              'Unable to load this period. Check your access and retry.',
        );
      }
    } finally {
      if (mounted && ticket == generation) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    generation++;
    setState(() {
      saving = true;
      generationFailed = false;
      error = null;
    });
    try {
      final result = await widget.post('/institution-reports', {
        ...input,
        'requestId': requestId,
      });
      if (!mounted) return;
      setState(() {
        savedId = result['id'] as String;
        page = 1;
      });
      await history();
    } catch (_) {
      if (mounted) {
        setState(() {
          generationFailed = true;
          error =
              'Could not complete the request. Retry safely; the same draft will not be duplicated.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffe1e7eb)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
  Widget title(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AfaqDesign.ink,
    ),
  );
  Widget caption(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xff718096)),
  );

  Widget detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final content = Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            height: 1.5,
            color: AfaqDesign.ink,
          ),
        );
        if (bounds.maxWidth < 400) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [caption(label), const SizedBox(height: 4), content],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: caption(label)),
            const SizedBox(width: 20),
            Flexible(child: content),
          ],
        );
      },
    ),
  );

  Widget badge(String text, {bool green = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: green ? const Color(0xffe7f3ec) : const Color(0xfff8f0da),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: green ? const Color(0xff268353) : const Color(0xff906c21),
      ),
    ),
  );

  String reportDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return date == null
        ? 'Unavailable'
        : MaterialLocalizations.of(context).formatMediumDate(date);
  }

  Widget historyRows() => LayoutBuilder(
    builder: (context, bounds) {
      if (bounds.maxWidth >= 900) {
        return SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: const WidgetStatePropertyAll(Color(0xfff5f7f9)),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xff60748b),
            ),
            dataRowMinHeight: 68,
            dataRowMaxHeight: 100,
            columnSpacing: 20,
            horizontalMargin: 16,
            columns: [
              for (final label in [
                'Report',
                'Scope',
                'Status',
                'Created',
                'Download',
              ])
                DataColumn(label: Text(label)),
            ],
            rows: [
              for (final report in recent)
                DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 190,
                        child: Text(
                          '${report['month']} institution summary',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 170,
                        child: Text(
                          report['scope'] as String,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(badge('Draft')),
                    DataCell(Text(reportDate(report['createdAt']))),
                    DataCell(
                      ReportPdfButton(
                        load: widget.load,
                        path: '/institution-reports/${report['id']}/pdf',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      }
      return Column(
        children: [
          for (final report in recent)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xffe1e7eb)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${report['month']} institution summary',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  badge('Draft'),
                  detail('Madrasa scope', report['scope'] as String),
                  detail('Created', reportDate(report['createdAt'])),
                  const Divider(height: 20),
                  ReportPdfButton(
                    load: widget.load,
                    path: '/institution-reports/${report['id']}/pdf',
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
  Widget note(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xfff8f0da),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xff906c21), height: 1.5),
    ),
  );
  Widget field(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xff60748b),
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
  Widget fixedField(String text) => InputDecorator(
    decoration: const InputDecoration(border: OutlineInputBorder()),
    child: Text(text),
  );
  List<dynamic> get items => snapshot?['items'] as List? ?? [];
  int get available => items.where((item) => item['hasData'] == true).length;

  Future<void> preview() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Report preview · ${monthValue(month)}'),
      content: SizedBox(
        width: 850,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail('Madrasa scope', snapshot!['scope'] as String),
              const SizedBox(height: 16),
              note(
                'Draft snapshot. Record counts are not unique learners or attainment. Data availability is not a submitted monthly report.',
              ),
              const SizedBox(height: 16),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title(item['name'] as String),
                        const SizedBox(height: 6),
                        caption(item['code'] as String),
                        const Divider(height: 24),
                        if (item['attendance'] != null)
                          detail('Attendance records', '${item['attendance']}'),
                        if (item['lessons'] != null)
                          detail('Lessons taught', '${item['lessons']}'),
                        if (item['quran'] != null)
                          detail('Qur\'an observations', '${item['quran']}'),
                        if (item['receipts'] != null)
                          detail(
                            'Confirmed receipts',
                            (item['receipts'] as List).isEmpty
                                ? 'No receipts'
                                : (item['receipts'] as List)
                                      .map(
                                        (r) =>
                                            '${r['currency']} ${r['amount']}',
                                      )
                                      .join('\n'),
                          ),
                        if (item['followups'] != null)
                          detail(
                            'Support notes open at month end',
                            '${item['followups']}',
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Widget form(double width) {
    final fieldWidth = width < 600 ? width : (width - 20) / 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title('Create an institution report'),
        const SizedBox(height: 24),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            SizedBox(
              width: fieldWidth,
              child: field(
                'Report type',
                fixedField('Monthly institution summary'),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: field(
                'Period',
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    MaterialLocalizations.of(context).formatMonthYear(month),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final selected = await showAfaqMonthPicker(
                            context,
                            initialDate: month,
                            lastYear: DateTime.now().year,
                          );
                          if (!mounted || selected == null) return;
                          setState(() => month = selected);
                          await refresh();
                        },
                ),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: field(
                'Madrasa scope',
                DropdownButtonFormField<String>(
                  initialValue: scope ?? '',
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All madrasas'),
                    ),
                    for (final school in schools)
                      DropdownMenuItem(
                        value: school['id'] as String,
                        child: Text(
                          school['name'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) {
                          setState(() => scope = value == '' ? null : value);
                          refresh();
                        },
                ),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: field('Export format', fixedField('PDF report')),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Include sections',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        for (final entry in labels.entries)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(entry.value),
            value: sections.contains(entry.key),
            onChanged: saving
                ? null
                : (checked) {
                    setState(() {
                      checked == true
                          ? sections.add(entry.key)
                          : sections.remove(entry.key);
                    });
                    refresh();
                  },
          ),
        const Divider(height: 32),
        note(
          sections.isEmpty
              ? 'Choose at least one section.'
              : snapshot == null
              ? 'Choose a period and scope to check data availability.'
              : '$available of ${items.length} madrasas have records in the selected sections. Missing records will be flagged in the draft.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: snapshot == null || busy || saving ? null : preview,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Preview report'),
            ),
            FilledButton.icon(
              onPressed:
                  snapshot == null ||
                      items.isEmpty ||
                      busy ||
                      saving ||
                      savedId != null
                  ? null
                  : save,
              icon: const Icon(Icons.download_outlined),
              label: Text(
                saving
                    ? 'Generating...'
                    : savedId != null
                    ? 'Draft saved'
                    : 'Generate draft',
              ),
            ),
            if (savedId != null)
              ReportPdfButton(
                load: widget.load,
                path: '/institution-reports/$savedId/pdf',
              ),
          ],
        ),
      ],
    );
  }

  Widget readiness() => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title('Reporting readiness'),
        const SizedBox(height: 24),
        Text(
          busy
              ? 'Checking...'
              : snapshot == null
              ? 'Not available'
              : '$available / ${items.length}',
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: AfaqDesign.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Madrasas with source records'),
        const SizedBox(height: 20),
        LinearProgressIndicator(
          value: busy
              ? null
              : items.isEmpty
              ? 0
              : available / items.length,
          color: AfaqDesign.gold,
          backgroundColor: const Color(0xffedf0f2),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: items.length > 6 ? 350 : null,
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xffedf0f2)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        badge(
                          item['hasData'] == true ? 'Available' : 'No records',
                          green: item['hasData'] == true,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        caption('Availability is not formal submission.'),
        const SizedBox(height: 4),
        caption('No records does not mean no activity.'),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AFAQ · INSTITUTION WORKSPACE',
          style: TextStyle(
            color: AfaqDesign.gold,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Institutional Reports',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AfaqDesign.ink,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Combine madrasa records into a clear picture for leadership.',
        ),
        const SizedBox(height: 8),
        caption(
          accessLost
              ? 'Automatic updates stopped. Check your access.'
              : stale
              ? 'Updates paused. Showing the last loaded data; reconnecting automatically.'
              : 'Data updates automatically every 30 seconds. Saved PDFs remain unchanged.',
        ),
        const SizedBox(height: 24),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                note(error!),
                TextButton(
                  onPressed: saving
                      ? null
                      : generationFailed
                      ? save
                      : initialize,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, bounds) {
            final left = panel(
              LayoutBuilder(builder: (context, inner) => form(inner.maxWidth)),
            );
            if (bounds.maxWidth < 1000) {
              return Column(
                children: [left, const SizedBox(height: 24), readiness()],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 9, child: left),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: readiness()),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title('Recent reports'),
              const SizedBox(height: 8),
              caption('Saved snapshots. Exports respect access permissions.'),
              const SizedBox(height: 16),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No saved reports yet. Generate your first draft above.',
                  ),
                ),
              if (recent.isNotEmpty) historyRows(),
              if (page > 1 || hasMore)
                Row(
                  children: [
                    TextButton(
                      onPressed: busy || saving || page == 1
                          ? null
                          : () => changePage(-1),
                      child: const Text('Previous'),
                    ),
                    Text('Page $page'),
                    TextButton(
                      onPressed: busy || saving || !hasMore
                          ? null
                          : () => changePage(1),
                      child: const Text('Next'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> changePage(int delta) async {
    generation++;
    final previous = page;
    setState(() {
      page += delta;
      busy = true;
    });
    try {
      await history();
    } catch (_) {
      if (mounted) {
        setState(() {
          page = previous;
          error = 'Unable to load report history.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
