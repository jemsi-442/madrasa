import 'package:flutter/material.dart';
import 'api_client.dart';
import 'workspace_form_dialog.dart';
import 'curriculum_oversight_report.dart';
import 'design_tokens.dart';

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
  static const filterKeys = ['madrasa', 'subject', 'level', 'assessmentMonth'];
  static const filterLabels = [
    'Madrasa',
    'Subject',
    'Level',
    'Assessment month',
  ];
  static const filterLimits = [120, 120, 80, 7];
  bool validateFilters = false;
  String? filterError(int index) {
    final value = filters[index].text.trim();
    if (index == 3 &&
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
      setState(() => validateFilters = true);
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
        Icon(icon, color: AfaqDesign.blue, size: 30),
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
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to curriculum'),
          ),
        ),
        Text(
          'Learning Oversight',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontFamily: AfaqDesign.bodyFont,
            fontWeight: FontWeight.w800,
            color: AfaqDesign.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Monitor curriculum adoption and teacher-reported teaching across madrasas.',
          style: TextStyle(color: AfaqDesign.muted),
        ),
        const SizedBox(height: 16),
        FutureBuilder<dynamic>(
          future: result,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                snapshot.data is! Map) {
              return const SizedBox.shrink();
            }
            return CurriculumOversightReport(
              rows: (snapshot.data as Map)['items'] as List,
              summaryOnly: true,
            );
          },
        ),
        const WorkspaceFormNotice(
          message:
              'Current class adoptions and teacher-reported teaching across assigned madrasas. Each lesson counts once per class and version. Not assessment or learner achievement. Totals are all-time, not monthly.',
        ),
        const SizedBox(height: 16),
        Container(
          decoration: AfaqDesign.panelDecoration(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filter teaching records',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a madrasa, framework or adoption status, then apply. Assessment month filters assessments by their assessment date only; teaching figures remain all-time.',
                style: TextStyle(color: AfaqDesign.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < filters.length; i++)
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: filters[i],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: filterLabels[i],
                          hintText: i == 3 ? 'YYYY-MM (optional)' : null,
                          errorText: validateFilters ? filterError(i) : null,
                        ),
                        onSubmitted: (_) => reload(1, apply: true),
                      ),
                    ),
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
                  FilledButton(
                    onPressed: () => reload(1, apply: true),
                    child: const Text('Apply filters'),
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
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          applied.isEmpty
              ? 'Applied filters: All assigned frameworks'
              : 'Applied filters: ${applied.entries.map((entry) => entry.key == 'adoption'
                    ? 'Class adoption: ${adoptionLabels[entry.value]}'
                    : entry.key == 'status'
                    ? 'Madrasa status: ${statusLabels[entry.value]}'
                    : '${filterLabels[filterKeys.indexOf(entry.key)]}: ${entry.value}').join(' / ')}',
          style: Theme.of(context).textTheme.labelLarge,
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
        FutureBuilder<dynamic>(
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
                icon: expired ? Icons.lock_clock_outlined : Icons.lock_outline,
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
                Text(
                  generatedAt == null
                      ? 'Snapshot time unavailable. Refresh to request current data.'
                      : 'Report generated: ${generatedAt.toUtc().toIso8601String()} (UTC)',
                ),
                const Text(
                  'Snapshot only, not live monitoring. Refresh to check for updates.',
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  Container(
                    decoration: AfaqDesign.panelDecoration(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.search_off,
                          color: AfaqDesign.muted,
                          size: 32,
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
                if (rows.isNotEmpty)
                  CurriculumOversightReport(
                    rows: rows,
                    showSummary: false,
                    assessments: data['assessments'] as Map?,
                  ),
                const SizedBox(height: 16),
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
  );
}
