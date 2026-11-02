import 'package:flutter/material.dart';
import 'dart:math';
import 'design_tokens.dart';
import 'foundation_ui.dart' show DashboardMetric;
import 'it_workspace_visuals.dart';
import 'platform_form_dialog.dart';
import 'automatic_data_updates.dart';
import 'live_data.dart';
import 'api_client.dart';

class SecurityIncidentRegister extends StatefulWidget {
  const SecurityIncidentRegister({
    super.key,
    required this.request,
    this.initialIncidentId,
    this.initialDescription,
    this.showForm = showPlatformForm,
  });
  final PlatformFormPresenter showForm;
  final String? initialIncidentId;
  final String? initialDescription;
  final Future<dynamic> Function(String path, Map<String, dynamic>? body)
  request;
  @override
  State<SecurityIncidentRegister> createState() =>
      _SecurityIncidentRegisterState();
}

class _SecurityIncidentRegisterState extends State<SecurityIncidentRegister> {
  Map<String, dynamic>? snapshot, selected;
  bool busy = false;
  bool editing = false, accessDenied = false;
  int viewVersion = 0;
  late final AutomaticDataUpdates updates;
  String? error;
  String? sourceDraft;
  int page = 1;
  String? statusFilter, priorityFilter;
  @override
  void initState() {
    super.initState();
    sourceDraft = widget.initialDescription;
    updates = AutomaticDataUpdates(
      canUpdate: () =>
          mounted &&
          !busy &&
          !editing &&
          !accessDenied &&
          !dataWriteInProgress &&
          ModalRoute.of(context)?.isCurrent != false,
      update: updateInBackground,
    );
    initialize();
  }

  @override
  void dispose() {
    updates.dispose();
    super.dispose();
  }

  String get listPath =>
      '/incidents?${Uri(queryParameters: {'page': '$page', if (statusFilter != null) 'status': statusFilter!, if (priorityFilter != null) 'priority': priorityFilter!}).query}';

  Future<void> updateInBackground() async {
    final version = viewVersion, revision = dataChanges.value;
    final id = selected?['id'] as String?;
    bool current() => mounted && version == viewVersion;
    bool canApply() =>
        current() && !editing && !busy && revision == dataChanges.value;
    try {
      final data = await widget.request(listPath, null);
      if (!canApply()) return;
      final detail = id == null
          ? null
          : await widget.request('/incidents/${Uri.encodeComponent(id)}', null);
      if (!canApply()) return;
      setState(() {
        snapshot = Map<String, dynamic>.from(data as Map);
        selected = detail == null
            ? null
            : Map<String, dynamic>.from(detail as Map);
        error = null;
      });
    } catch (e) {
      if (!current()) return;
      final denied =
          e is ApiException && [401, 403, 409].contains(e.statusCode);
      if (!denied && !canApply()) return;
      setState(() {
        if (denied) {
          accessDenied = true;
          snapshot = selected = null;
        }
        error = denied
            ? 'Access could not be verified. Sign in again or check your permissions.'
            : 'Updates could not be checked. Displayed records may be out of date; retrying automatically.';
      });
    }
  }

  Future<void> initialize() async {
    await refresh();
    if (mounted && widget.initialIncidentId != null) {
      await open(widget.initialIncidentId!);
    } else if (mounted &&
        snapshot != null &&
        widget.initialDescription != null) {
      await edit();
    }
  }

  Future<void> refresh({String? incidentId}) async {
    final version = ++viewVersion;
    final keepId = incidentId ?? selected?['id'] as String?;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.request(listPath, null);
      if (mounted && version == viewVersion) {
        setState(() {
          accessDenied = false;
          snapshot = Map<String, dynamic>.from(data as Map);
          if (keepId == null) selected = null;
        });
      }
    } catch (e) {
      if (mounted && version == viewVersion) {
        setState(() {
          snapshot = null;
          selected = null;
          accessDenied =
              e is ApiException && [401, 403, 409].contains(e.statusCode);
          error = accessDenied
              ? 'Access could not be verified. Sign in again or check your permissions.'
              : 'Incident records could not be loaded. Try again; no new incident has been saved.';
        });
      }
    } finally {
      if (mounted && version == viewVersion) setState(() => busy = false);
    }
    if (mounted &&
        version == viewVersion &&
        snapshot != null &&
        keepId != null) {
      await open(keepId);
    }
  }

  Future<void> open(String id) async {
    final version = ++viewVersion;
    setState(() {
      busy = true;
      error = null;
      selected = null;
    });
    try {
      final data = await widget.request(
        '/incidents/${Uri.encodeComponent(id)}',
        null,
      );
      if (mounted && version == viewVersion) {
        setState(() => selected = Map<String, dynamic>.from(data as Map));
      }
    } catch (_) {
      if (mounted && version == viewVersion) {
        setState(() => error = 'Could not load the incident.');
      }
    } finally {
      if (mounted && version == viewVersion) setState(() => busy = false);
    }
  }

  Future<void> edit({bool update = false}) async {
    final request = widget.request;
    final original = selected;
    final title = TextEditingController();
    final note = TextEditingController(text: update ? '' : sourceDraft);
    setState(() {
      editing = true;
      if (!update) sourceDraft = null;
    });
    final form = GlobalKey<FormState>();
    var choice = update ? '${original!['status']}' : 'MEDIUM';
    var saving = false;
    final random = Random.secure();
    final requestId = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    Map<String, dynamic>? submitted;
    String? savedId;
    String? failure;
    final saved = await widget.showForm(
      context,
      (context) => StatefulBuilder(
        builder: (context, change) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(update ? 'Update incident' : 'Record incident'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Do not include passwords, tokens or learner records.',
                      ),
                      const SizedBox(height: 16),
                      if (!update)
                        TextFormField(
                          controller: title,
                          enabled: !saving && submitted == null,
                          maxLength: 160,
                          decoration: const InputDecoration(
                            labelText: 'Summary',
                          ),
                          validator: (v) => (v ?? '').trim().length < 5
                              ? 'Enter at least 5 characters'
                              : null,
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: choice,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: update ? 'Status' : 'Priority',
                        ),
                        items: [
                          for (final s
                              in update
                                  ? ['OPEN', 'INVESTIGATING', 'RESOLVED']
                                  : ['LOW', 'MEDIUM', 'HIGH'])
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: saving || submitted != null
                            ? null
                            : (v) => choice = v!,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: note,
                        enabled: !saving && submitted == null,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 4000,
                        decoration: InputDecoration(
                          labelText: update
                              ? 'Response / resolution note'
                              : 'Description',
                        ),
                        validator: (v) => (v ?? '').trim().length < 10
                            ? 'Enter at least 10 characters'
                            : null,
                      ),
                      if (failure != null)
                        Text(
                          failure!,
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        submitted ??= update
                            ? {
                                'requestId': requestId,
                                'revision': original!['revision'],
                                'status': choice,
                                'note': note.text.trim(),
                              }
                            : {
                                'requestId': requestId,
                                'title': title.text.trim(),
                                'description': note.text.trim(),
                                'priority': choice,
                              };
                        change(() {
                          saving = true;
                          failure = null;
                        });
                        try {
                          final result = await request(
                            update
                                ? '/incidents/${original!['id']}'
                                : '/incidents',
                            submitted!,
                          );
                          savedId = result is Map
                              ? result['id'] as String?
                              : null;
                          savedId ??= update ? original!['id'] as String : null;
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (_) {
                          if (context.mounted) {
                            change(() {
                              saving = false;
                              failure = update
                                  ? 'Save could not be confirmed. Your text is retained. Retry Save safely with the same response. If the incident changed, cancel and reload before making a new update.'
                                  : 'Save could not be confirmed. Your text is retained. Retry Save safely using the same request; fields are locked to prevent duplicates.';
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() => editing = false);
    // Wait for the dialog route to finish its closing animation before disposal.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    title.dispose();
    note.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incident saved.')));
      await refresh(incidentId: savedId);
    }
  }

  Widget panel(String title, Widget body) => Container(
    decoration: AfaqDesign.panelDecoration(),
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        body,
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final rows = (snapshot?['items'] as List? ?? []).cast<Map>();
      final left = panel(
        'Incident register',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rows.isEmpty && !busy && error == null)
              Text(
                statusFilter == null && priorityFilter == null
                    ? 'No incidents recorded.'
                    : 'No incidents match these filters.',
              ),
            for (final r in rows) ...[
              Text(
                '${r['title']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${r['priority']} priority  |  ${r['status']}',
                style: const TextStyle(color: AfaqDesign.blue),
              ),
              Text(
                itTimestamp(r['createdAt']),
                style: const TextStyle(color: AfaqDesign.muted),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy ? null : () => open('${r['id']}'),
                  child: const Text('Open'),
                ),
              ),
              const Divider(),
            ],
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  onPressed: busy || page <= 1
                      ? null
                      : () {
                          page--;
                          refresh();
                        },
                  child: const Text('Previous'),
                ),
                Text('Page $page'),
                OutlinedButton(
                  onPressed:
                      busy || page * 20 >= (snapshot?['total'] as int? ?? 0)
                      ? null
                      : () {
                          page++;
                          refresh();
                        },
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
      );
      final right = panel(
        'Selected incident',
        selected == null
            ? const Text('Select an incident to review its response history.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${selected!['title']}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('${selected!['description']}'),
                  const SizedBox(height: 16),
                  ItRecordDetails(
                    values: {
                      'Priority': selected!['priority'],
                      'Status': selected!['status'],
                      'Owner ID': selected!['ownerId'],
                      'Created (UTC)': selected!['createdAt'],
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : () => edit(update: true),
                    child: const Text('Update response'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Response history',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (final e in selected!['entries'] as List? ?? []) ...[
                    const Divider(height: 24),
                    Text('${e['status']} - ${itTimestamp(e['createdAt'])}'),
                    Text('${e['note']}'),
                    Text(
                      'Recorded by: ${e['actorId']}',
                      style: const TextStyle(color: AfaqDesign.muted),
                    ),
                  ],
                ],
              ),
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ItPageHeading(
              title: 'Security Incidents',
              description:
                  'Investigate alerts and preserve response history. An incident is not proof of a breach.',
            ),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: busy || accessDenied ? null : () => edit(),
                  icon: const Icon(Icons.add),
                  label: Text(
                    sourceDraft != null
                        ? 'Continue receipt draft'
                        : 'Record incident',
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : refresh,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (sourceDraft != null && !editing)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Receipt draft retained on this page. Not saved yet; continue the draft to review and save it.',
                ),
              ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final m in [
                  ('Open incidents', 'open'),
                  ('High priority', 'high'),
                  ('Resolved this month (UTC)', 'resolved'),
                ])
                  SizedBox(
                    width: size.maxWidth >= 1100
                        ? (size.maxWidth - 80) / 3
                        : size.maxWidth - 48,
                    child: DashboardMetric(
                      label: m.$1,
                      value: snapshot == null
                          ? 'Unavailable'
                          : '${snapshot![m.$2]}',
                      icon: Icons.shield_outlined,
                      accent: AfaqDesign.gold,
                      dense: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final filter in [
                  (
                    'Status',
                    statusFilter,
                    ['', 'OPEN', 'INVESTIGATING', 'RESOLVED'],
                    ['All statuses', 'Open', 'Investigating', 'Resolved'],
                  ),
                  (
                    'Priority',
                    priorityFilter,
                    ['', 'HIGH', 'MEDIUM', 'LOW'],
                    ['All priorities', 'High', 'Medium', 'Low'],
                  ),
                ])
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: filter.$2 ?? '',
                      isExpanded: true,
                      decoration: InputDecoration(labelText: filter.$1),
                      items: [
                        for (var i = 0; i < filter.$3.length; i++)
                          DropdownMenuItem(
                            value: filter.$3[i],
                            child: Text(filter.$4[i]),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) {
                              setState(() {
                                final next = value == '' ? null : value;
                                if (filter.$1 == 'Status') {
                                  statusFilter = next;
                                } else {
                                  priorityFilter = next;
                                }
                                page = 1;
                                selected = null;
                              });
                              refresh();
                            },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Summary counts cover all incidents. Filters apply to the register below.',
            ),
            const SizedBox(height: 24),
            if (size.maxWidth >= 1100)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 24),
                  Expanded(child: right),
                ],
              )
            else ...[
              left,
              const SizedBox(height: 24),
              right,
            ],
          ],
        ),
      );
    },
  );
}
