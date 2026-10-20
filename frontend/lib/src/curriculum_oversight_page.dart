import 'package:flutter/material.dart';
import 'api_client.dart';
import 'workspace_form_dialog.dart';

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
  static const filterKeys = ['madrasa', 'subject', 'level'];
  static const filterLabels = ['Madrasa', 'Subject', 'Level'];
  static const filterLimits = [120, 120, 80];
  bool validateFilters = false;
  String? filterError(int index) =>
      filters[index].text.trim().length > filterLimits[index]
      ? 'Use at most ${filterLimits[index]} characters.'
      : null;
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
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        const WorkspaceFormNotice(
          message:
              'Current class adoptions and teacher-reported teaching across assigned madrasas. Each lesson counts once per class and version. Not assessment or learner achievement. Totals are all-time, not monthly.',
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
                decoration: const InputDecoration(labelText: 'Class adoption'),
                items: [
                  for (final entry in adoptionLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => setState(() => adoption = value ?? ''),
              ),
            ),
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String>(
                initialValue: status,
                key: ValueKey('madrasa-status-$status'),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Madrasa status'),
                items: [
                  for (final entry in statusLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => setState(() => status = value ?? ''),
              ),
            ),
            FilledButton(
              onPressed: () => reload(1, apply: true),
              child: const Text('Apply filters'),
            ),
            TextButton(
              onPressed: () {
                for (final controller in filters) {
                  controller.clear();
                }
                adoption = '';
                status = '';
                reload(1, apply: true);
              },
              child: const Text('Clear filters'),
            ),
            TextButton.icon(
              onPressed: () => reload(1),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
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
              return const LinearProgressIndicator();
            }
            if (snapshot.data is _OversightFailure) {
              return Text(
                (snapshot.data as _OversightFailure).status == 401
                    ? 'Your session has expired. Sign in again.'
                    : 'Learning Oversight is not available for this account.',
              );
            }
            if (snapshot.data == null) {
              return Column(
                children: [
                  const Text('Could not load learning oversight.'),
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
                  Text(
                    page == 1
                        ? 'No assigned frameworks match these filters.'
                        : 'No records on this page. Assignments may have changed; return to the first page to check.',
                  ),
                if (rows.isEmpty && page > 1)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => reload(1),
                      icon: const Icon(Icons.first_page),
                      label: const Text('Back to first page'),
                    ),
                  ),
                for (final row in rows)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['madrasa']} · ${row['madrasaStatus']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${row['subject']} / ${row['level'] ?? 'Level not set'} / v${row['version']}',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${row['adoptedClasses']} class adoption records',
                          ),
                          Text(
                            '${row['taughtClassLessons']} / ${row['plannedClassLessons']} class-lessons recorded as taught',
                          ),
                          Text(
                            '${row['pendingClassLessons']} class-lessons without teaching records',
                          ),
                          if (row['plannedClassLessons'] == 0)
                            const Text(
                              'Teaching coverage is not applicable without adopted classes and planned lessons.',
                            ),
                          if (row['subjectActive'] != true)
                            const Text(
                              'School subject is inactive or not linked. Adoption records do not confirm current teaching access.',
                            ),
                          if (row['madrasaStatus'] != 'ACTIVE' &&
                              row['madrasaStatus'] != 'TRIAL')
                            const Text(
                              'Madrasa is not active. Records are retained for oversight, not evidence of current access.',
                            ),
                        ],
                      ),
                    ),
                  ),
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
