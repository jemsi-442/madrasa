import 'package:flutter/material.dart';
import 'live_data.dart';
import 'api_client.dart';
import 'workspace_form_dialog.dart';
import 'curriculum_oversight_report.dart';
import 'design_tokens.dart';
import 'madrasa_learning_coverage.dart';
import 'oversight_visuals.dart';
import 'date_selection.dart';

class _OversightFailure {
  const _OversightFailure(this.status);
  final int status;
}

class CurriculumOversightPage extends StatefulWidget {
  const CurriculumOversightPage({
    super.key,
    required this.load,
    required this.onBack,
    required this.onSessionExpired,
  });
  final Future<dynamic> Function(String) load;
  final VoidCallback onBack, onSessionExpired;
  @override
  State<CurriculumOversightPage> createState() => _OversightState();
}

class _OversightState extends State<CurriculumOversightPage> {
  final filters = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  Map<String, String> applied = {};
  String adoption = '';
  String status = '';
  static const statusLabels = {
    '': 'All madrasa statuses',
    'ACTIVE': 'Active',
    'TRIAL': 'Trial',
    'SUSPENDED': 'Suspended',
    'PENDING_ACTIVATION': 'Pending activation',
  };
  static const adoptionLabels = {
    '': 'All assignments',
    'with': 'With class adoptions',
    'without': 'No current class adoption',
  };
  static const filterKeys = [
    'madrasa',
    'subject',
    'level',
    'assessmentMonth',
    'quranMonth',
  ];
  static const filterLabels = [
    'Madrasa',
    'Subject',
    'Level',
    'Assessment month',
    "Qur'an month",
  ];
  static const filterLimits = [120, 120, 80, 7, 7];
  bool validateFilters = false;
  bool filtersExpanded = false;
  bool toolsOpen = false;
  final coverageKey = GlobalKey();
  bool followupsOnly = false;
  String? filterError(int index) {
    final value = filters[index].text.trim();
    if (index >= 3 &&
        value.isNotEmpty &&
        !RegExp(r'^[1-9]\d{3}-(0[1-9]|1[0-2])$').hasMatch(value)) {
      return 'Use YYYY-MM, or leave blank for all time.';
    }
    return value.length > filterLimits[index]
        ? 'Use at most ${filterLimits[index]} characters.'
        : null;
  }

  bool get hasUnappliedChanges {
    for (var i = 0; i < filters.length; i++) {
      if (filters[i].text.trim() != (applied[filterKeys[i]] ?? '')) return true;
    }
    return adoption != (applied['adoption'] ?? '') ||
        status != (applied['status'] ?? '');
  }

  int page = 1;
  int requestGeneration = 0;
  late Future<dynamic> result = fetch();
  Future<dynamic> fetch() async {
    final generation = ++requestGeneration;
    try {
      return await widget.load(
        '/curriculum/oversight?${Uri(queryParameters: {...applied, 'page': '$page'}).query}',
      );
    } on ApiException catch (error) {
      // A superseded request must not invalidate a newer successful report.
      if (error.statusCode == 401 &&
          mounted &&
          generation == requestGeneration) {
        widget.onSessionExpired();
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        return _OversightFailure(error.statusCode);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void reload(int target, {bool apply = false}) {
    if (apply &&
        List.generate(
          filters.length,
          filterError,
        ).any((error) => error != null)) {
      setState(() {
        validateFilters = true;
        filtersExpanded = true;
        toolsOpen = true;
      });
      return;
    }
    setState(() {
      page = target;
      if (apply) {
        validateFilters = false;
        applied = {};
        if (adoption.isNotEmpty) applied['adoption'] = adoption;
        if (status.isNotEmpty) applied['status'] = status;
        for (var i = 0; i < filters.length; i++) {
          final value = filters[i].text.trim();
          if (value.isNotEmpty) {
            applied[filterKeys[i]] = value;
          }
        }
      }
      result = fetch();
    });
  }

  void clearFilters() {
    for (final controller in filters) {
      controller.clear();
    }
    adoption = '';
    status = '';
    reload(1, apply: true);
  }

  Widget statePanel({
    required IconData icon,
    required String title,
    required String description,
    List<Widget> actions = const [],
    bool loading = false,
  }) => Container(
    decoration: AfaqDesign.panelDecoration(),
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AfaqDesign.blue, size: 34),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(description, style: const TextStyle(color: AfaqDesign.muted)),
        if (loading) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator(),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 8, children: actions),
        ],
      ],
    ),
  );

  @override
  void dispose() {
    for (final controller in filters) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AfaqDesign.paper,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'AFAQ · INSTITUTION WORKSPACE',
            style: TextStyle(
              color: AfaqDesign.actionGold,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 16,
            children: [
              Text(
                'Learning Oversight',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: AfaqDesign.bodyFont,
                  fontWeight: FontWeight.w800,
                  color: AfaqDesign.ink,
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month_outlined, size: 20),
                    label: Text(applied['quranMonth'] ?? 'All time'),
                    onPressed: () async {
                      final now = DateTime.now();
                      final date = await showAfaqMonthPicker(
                        context,
                        initialDate:
                            DateTime.tryParse(
                              '${applied['quranMonth'] ?? '${now.year}-${now.month.toString().padLeft(2, '0')}'}-01',
                            ) ??
                            now,
                        lastYear: now.year + 1,
                      );
                      if (date == null || !mounted) return;
                      filters[4].text =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}';
                      reload(1, apply: true);
                    },
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AfaqDesign.ink,
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    label: Text(
                      followupsOnly ? 'Show all madrasas' : 'Review follow-ups',
                    ),
                    onPressed: () {
                      setState(() => followupsOnly = !followupsOnly);
                      final target = coverageKey.currentContext;
                      if (target != null) {
                        Scrollable.ensureVisible(
                          target,
                          duration: const Duration(milliseconds: 250),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'See where support is needed across madrasas, subjects and learning targets.',
            style: TextStyle(color: AfaqDesign.muted),
          ),
          const SizedBox(height: 16),
          LiveDataBuilder(
            future: result,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done ||
                  snapshot.data is! Map) {
                return const SizedBox.shrink();
              }
              if ((snapshot.data as Map)['institution'] is Map) {
                return OversightMetrics(
                  data: (snapshot.data as Map)['institution'] as Map,
                );
              }
              return CurriculumOversightReport(
                rows: (snapshot.data as Map)['items'] as List,
                summaryOnly: true,
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.tune, size: 18),
              label: Text(
                toolsOpen ? 'Hide filters & details' : 'Filters & details',
              ),
              onPressed: () => setState(() => toolsOpen = !toolsOpen),
            ),
          ),
          if (applied.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in applied.entries)
                    InputChip(
                      label: Text(
                        entry.key == 'adoption'
                            ? 'Class adoption: ${adoptionLabels[entry.value]}'
                            : entry.key == 'status'
                            ? 'Madrasa status: ${statusLabels[entry.value]}'
                            : '${filterLabels[filterKeys.indexOf(entry.key)]}: ${entry.value}',
                      ),
                      onDeleted: () {
                        setState(() {
                          applied = {...applied}..remove(entry.key);
                          if (entry.key == 'adoption') {
                            adoption = '';
                          } else if (entry.key == 'status') {
                            status = '';
                          } else {
                            filters[filterKeys.indexOf(entry.key)].clear();
                          }
                        });
                        reload(1);
                      },
                    ),
                ],
              ),
            ),
          if (toolsOpen) ...[
            Container(
              decoration: AfaqDesign.panelDecoration(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Report filters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AfaqDesign.ink,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.menu_book_outlined, size: 18),
                        label: const Text('Back to curriculum'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose the records to include. Changes take effect when you apply filters.',
                    style: TextStyle(color: AfaqDesign.muted, fontSize: 13),
                  ),
                  if (filtersExpanded)
                    const Text(
                      'Assessment and Qur\'an months filter their own records. Teaching remains all-time.',
                      style: TextStyle(color: AfaqDesign.muted),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < filters.length; i++)
                        if (i == 0 || filtersExpanded)
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: filters[i],
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: filterLabels[i],
                                hintText: i >= 3 ? 'YYYY-MM (optional)' : null,
                                suffixIcon: i >= 3
                                    ? IconButton(
                                        tooltip:
                                            'Choose ${filterLabels[i].toLowerCase()}',
                                        icon: const Icon(
                                          Icons.calendar_month_outlined,
                                        ),
                                        onPressed: () async {
                                          final selected =
                                              await showAfaqMonthPicker(
                                                context,
                                                initialDate:
                                                    DateTime.tryParse(
                                                      '${filters[i].text}-01',
                                                    ) ??
                                                    DateTime.now(),
                                              );
                                          if (selected != null && mounted) {
                                            setState(
                                              () => filters[i].text =
                                                  monthValue(selected),
                                            );
                                          }
                                        },
                                      )
                                    : null,
                                errorText: validateFilters
                                    ? filterError(i)
                                    : null,
                              ),
                              onSubmitted: (_) => reload(1, apply: true),
                            ),
                          ),
                      if (filtersExpanded)
                        SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            initialValue: adoption,
                            key: ValueKey(adoption),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Class adoption',
                            ),
                            items: [
                              for (final entry in adoptionLabels.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => adoption = value ?? ''),
                          ),
                        ),
                      if (filtersExpanded)
                        SizedBox(
                          width: 250,
                          child: DropdownButtonFormField<String>(
                            initialValue: status,
                            key: ValueKey('madrasa-status-$status'),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Madrasa status',
                            ),
                            items: [
                              for (final entry in statusLabels.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => status = value ?? ''),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 32),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () => reload(1, apply: true),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Apply filters'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => filtersExpanded = !filtersExpanded),
                        icon: const Icon(Icons.tune),
                        label: Text(
                          filtersExpanded ? 'Fewer filters' : 'More filters',
                        ),
                      ),
                      TextButton(
                        onPressed: clearFilters,
                        child: const Text('Clear filters'),
                      ),
                      TextButton.icon(
                        onPressed: () => reload(1),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Teaching coverage: Not assessment or learner achievement.',
                      style: TextStyle(color: AfaqDesign.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AfaqDesign.tableHeader,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.filter_alt_outlined,
                    size: 20,
                    color: AfaqDesign.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      applied.isEmpty
                          ? 'Applied filters: All assigned frameworks'
                          : 'Applied filters: ${applied.entries.map((entry) => entry.key == 'adoption'
                                ? 'Class adoption: ${adoptionLabels[entry.value]}'
                                : entry.key == 'status'
                                ? 'Madrasa status: ${statusLabels[entry.value]}'
                                : '${filterLabels[filterKeys.indexOf(entry.key)]}: ${entry.value}').join(' / ')}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
            if (hasUnappliedChanges)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Filter changes are not applied yet. Select Apply filters; Refresh and pagination use the applied filters.',
                ),
              ),
            const SizedBox(height: 12),
            if (applied['adoption'] == 'without')
              const WorkspaceFormNotice(
                message:
                    'No current class adoption may mean a version was replaced, not delayed onboarding. Review the assigned version before following up.',
              ),
          ],
          LiveDataBuilder(
            future: result,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return statePanel(
                  icon: Icons.sync,
                  title: 'Loading learning oversight',
                  description:
                      'Fetching the report for your applied filters. Previous figures are hidden until the request completes.',
                  loading: true,
                );
              }
              if (snapshot.data is _OversightFailure) {
                final expired =
                    (snapshot.data as _OversightFailure).status == 401;
                return statePanel(
                  icon: expired
                      ? Icons.lock_clock_outlined
                      : Icons.lock_outline,
                  title: expired
                      ? 'Your session has expired. Sign in again.'
                      : 'Learning Oversight is not available for this account.',
                  description: expired
                      ? 'Sign in again to load current information.'
                      : 'This report requires authorised platform curriculum access.',
                );
              }
              if (snapshot.data == null) {
                return statePanel(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load learning oversight.',
                  description:
                      'No current report is available. Retry to check for updates; this error does not mean the records were deleted.',
                  actions: [
                    TextButton(
                      onPressed: () => reload(page),
                      child: const Text('Try again'),
                    ),
                    if (page > 1) ...[
                      Text('Page $page could not be loaded.'),
                      TextButton.icon(
                        onPressed: () => reload(1),
                        icon: const Icon(Icons.first_page),
                        label: const Text('Back to first page'),
                      ),
                    ],
                  ],
                );
              }
              final data = snapshot.data as Map;
              final rows = data['items'] as List;
              final generatedAt = DateTime.tryParse('${data['generatedAt']}');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (toolsOpen)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: AfaqDesign.panelDecoration(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.schedule_outlined,
                            size: 20,
                            color: AfaqDesign.muted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  generatedAt == null
                                      ? 'Snapshot time unavailable. Refresh to request current data.'
                                      : 'Report generated: ${generatedAt.toUtc().toIso8601String().substring(0, 16).replaceFirst('T', ' ')} UTC',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AfaqDesign.ink,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Snapshot only, not live monitoring. Refresh to check for updates.',
                                  style: TextStyle(
                                    color: AfaqDesign.muted,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final table = KeyedSubtree(
                        key: coverageKey,
                        child: data['institution'] is! Map
                            ? const Text('Institution coverage unavailable.')
                            : MadrasaLearningCoverage(
                                followupsOnly: followupsOnly,
                                key: ValueKey('madrasas-$requestGeneration'),
                                load: widget.load,
                                filters: applied,
                                onSessionExpired: widget.onSessionExpired,
                              ),
                      );
                      final quran = OversightQuranPanel(
                        data: data['quran'] as Map?,
                      );
                      if (constraints.maxWidth < 1050) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [table, const SizedBox(height: 20), quran],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 9, child: table),
                          const SizedBox(width: 24),
                          Expanded(flex: 5, child: quran),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AfaqDesign.blue.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: AfaqDesign.blue,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Institution view is read-only for classroom assessments. Corrections are requested from the responsible teacher or madrasa administrator.',
                            style: TextStyle(
                              color: AfaqDesign.blue,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (toolsOpen && rows.isEmpty)
                    Container(
                      decoration: AfaqDesign.panelDecoration(),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.search_off,
                            color: AfaqDesign.muted,
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            page == 1
                                ? 'No assigned frameworks match these filters.'
                                : 'No records on this page. Assignments may have changed; return to the first page to check.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (page == 1)
                            Text(
                              applied.isEmpty
                                  ? 'Publish a framework and assign it to an active madrasa from Curriculum. Class adoption is a separate step for the madrasa administrator.'
                                  : 'Try fewer filters or show all assignments. No matching records does not mean the frameworks were deleted.',
                              style: const TextStyle(color: AfaqDesign.muted),
                            ),
                          if (page == 1 && applied.isNotEmpty)
                            TextButton.icon(
                              onPressed: clearFilters,
                              icon: const Icon(Icons.filter_alt_off_outlined),
                              label: const Text('Show all assignments'),
                            ),
                          if (page > 1)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => reload(1),
                                icon: const Icon(Icons.first_page),
                                label: const Text('Back to first page'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (toolsOpen && rows.isNotEmpty)
                    ExpansionTile(
                      key: ValueKey('framework-details-$requestGeneration'),
                      title: const Text('Framework and assessment details'),
                      subtitle: Text('${rows.length} assignments on this page'),
                      children: [
                        CurriculumOversightReport(
                          rows: rows,
                          showSummary: true,
                          showQuran: false,
                          assessments: data['assessments'] as Map?,
                          quran: data['quran'] as Map?,
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (toolsOpen)
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: page > 1 ? () => reload(page - 1) : null,
                          child: const Text('Previous'),
                        ),
                        Text('Page $page'),
                        TextButton(
                          onPressed: data['hasMore'] == true
                              ? () => reload(page + 1)
                              : null,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
