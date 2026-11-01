import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'madrasa_profile_handoff.dart';
import 'madrasa_administration.dart';
import 'madrasa_location_fields.dart';
import 'madrasa_directory_export.dart';
import 'report_preview.dart';
import 'api_client.dart';
import 'automatic_data_updates.dart';
import 'live_data.dart';
import 'design_tokens.dart';
import 'workspace_chrome.dart';
import 'workspace_details_dialog.dart';
import 'platform/finance_export_native.dart'
    if (dart.library.js_interop) 'platform/finance_export_web.dart'
    as files;

class PlatformMadrasasPage extends StatefulWidget {
  const PlatformMadrasasPage({
    super.key,
    required this.load,
    required this.onApplications,
    required this.onSessionExpired,
    this.onAdd,
    this.onOnboarding,
    this.onReview,
    this.onHistory,
    this.saveCsv,
  });
  final Future<dynamic> Function(String) load;
  final VoidCallback onApplications, onSessionExpired;
  final Future<void> Function()? onAdd;
  final void Function(String)? onOnboarding;
  final void Function(String)? onHistory;
  final Future<bool?> Function(Map<String, dynamic>, String)? onReview;
  final Future<bool> Function(String, String)? saveCsv;
  @override
  State<PlatformMadrasasPage> createState() => _DirectoryState();
}

class _DirectoryState extends State<PlatformMadrasasPage> {
  late final AutomaticDataUpdates updates;
  int generation = 0;
  bool stale = false, accessLost = false;
  bool get canSync =>
      mounted &&
      !busy &&
      !exporting &&
      !profileBusy &&
      selected == null &&
      !accessLost &&
      !dataWriteInProgress &&
      search.text.trim() == query &&
      ModalRoute.of(context)?.isCurrent != false;
  void dataChanged() => updates.tick();
  final search = TextEditingController();
  String status = '', location = '', query = '';
  int page = 1, total = 0;
  bool busy = true, exporting = false;
  bool profileBusy = false;
  String? profileError;
  String? reviewError;
  String? error;
  Map<String, dynamic>? summary, selected;
  List<String> locations = [];
  List<Map<String, dynamic>> rows = [];
  @override
  void initState() {
    super.initState();
    updates = AutomaticDataUpdates(
      canUpdate: () => canSync,
      update: () => refresh(quiet: true),
    );
    dataChanges.addListener(dataChanged);
    refresh();
  }

  @override
  void dispose() {
    dataChanges.removeListener(dataChanged);
    updates.dispose();
    search.dispose();
    super.dispose();
  }

  String path({bool export = false}) =>
      '/madrasas?${Uri(queryParameters: {'page': '$page', 'search': query, if (status.isNotEmpty) 'status': status, if (location.isNotEmpty) 'location': location, if (export) 'export': 'true'}).query}';
  Future<void> refresh({bool quiet = false}) async {
    final ticket = ++generation, revision = dataChanges.value;
    if (!quiet) {
      setState(() {
        busy = true;
        error = null;
        accessLost = false;
      });
    }
    try {
      final data = await widget.load(path());
      if (!mounted ||
          ticket != generation ||
          (quiet && (!canSync || revision != dataChanges.value))) {
        return;
      }
      setState(() {
        rows = (data['items'] as List).cast<Map<String, dynamic>>();
        total = data['total'];
        summary = data['summary'];
        locations = (data['locations'] as List? ?? []).cast<String>();
        if (location.isNotEmpty && !locations.contains(location)) {
          locations = [...locations, location];
        }
        stale = false;
        error = null;
      });
    } catch (e) {
      if (!mounted ||
          ticket != generation ||
          (quiet && (!canSync || revision != dataChanges.value))) {
        return;
      }
      final denied = e is ApiException && [401, 403].contains(e.statusCode);
      if (quiet && !denied) {
        setState(() => stale = true);
        return;
      }
      if (denied) {
        setState(() {
          accessLost = true;
          rows = [];
          summary = null;
          error =
              'Madrasa access is unavailable. Check your session and permissions.';
        });
      }
      if (e is ApiException && e.statusCode == 401) {
        widget.onSessionExpired();
      } else if (!denied) {
        setState(() {
          error = 'Could not load madrasas. Please try again.';
          rows = [];
          summary = null;
        });
      }
    } finally {
      if (mounted && ticket == generation && !quiet) {
        setState(() => busy = false);
      }
    }
  }

  void filter() {
    page = 1;
    query = search.text.trim();
    refresh();
  }

  Future<void> refreshProfile() async {
    if (profileBusy || selected == null) return;
    final original = selected!;
    setState(() {
      profileBusy = true;
      profileError = null;
    });
    try {
      final result = await widget.load(
        '/madrasas?${Uri(queryParameters: {'code': '${original['code']}'}).query}',
      );
      if (!mounted || !identical(selected, original)) return;
      final matches = (result['items'] as List)
          .where((row) => row['code'] == original['code'])
          .toList();
      if (matches.length != 1) {
        setState(
          () => profileError =
              'This madrasa could not be uniquely located. Return to the directory and refresh.',
        );
      } else {
        setState(() {
          selected = Map<String, dynamic>.from(matches.single as Map);
          rows = rows
              .map((row) => row['code'] == original['code'] ? selected! : row)
              .toList();
          reviewError = null;
        });
      }
    } catch (failure) {
      if (!mounted || !identical(selected, original)) return;
      setState(
        () => profileError =
            'Current details could not be loaded. Previous information is hidden.',
      );
      if (failure is ApiException && failure.statusCode == 401) {
        widget.onSessionExpired();
      }
    } finally {
      if (mounted) setState(() => profileBusy = false);
    }
  }

  void closeProfile() {
    setState(() {
      selected = null;
      profileError = null;
      reviewError = null;
    });
    // Reapply directory filters and summary counts after a profile/status update.
    refresh();
  }

  Future<void> reviewMadrasa(
    Map<String, dynamic> record,
    String decision,
  ) async {
    if (busy || reviewError != null) return;
    setState(() => busy = true);
    try {
      final saved = await widget.onReview!(record, decision);
      if (!mounted || !identical(selected, record)) return;
      if (saved == true) {
        await refreshProfile();
      } else if (saved == false) {
        setState(
          () => reviewError =
              'Decision could not be confirmed. Refresh details before taking another action.',
        );
      }
    } catch (_) {
      if (mounted && identical(selected, record)) {
        setState(
          () => reviewError =
              'Decision could not be confirmed. Refresh details before taking another action.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() async {
    setState(() => exporting = true);
    try {
      final result = await widget.load(path(export: true));
      if (!mounted) return;
      final csv = madrasaDirectoryCsv(result['items'] as List);
      final saved = await (widget.saveCsv ?? files.saveFinanceCsv)(
        'afaq-madrasas.csv',
        csv,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved ? 'CSV export requested.' : 'Export cancelled.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) {
        widget.onSessionExpired();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export failed. Narrow the filters or retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  String admins(Map<String, dynamic> r) => (r['admins'] as List).isEmpty
      ? 'Not assigned'
      : (r['admins'] as List).join(', ');
  String place(Map<String, dynamic> r) {
    final location = r['location'];
    if (location is Map) {
      final parts = ['country', 'region', 'district', 'ward']
          .map((key) => '${location[key] ?? ''}'.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) return parts.join(', ');
    }
    return (r['locations'] as List? ?? []).isEmpty
        ? 'Location not recorded'
        : (r['locations'] as List).join(', ');
  }

  static String label(String s) => switch (s) {
    'REQUESTED' => 'Awaiting approval',
    'APPROVED' => 'Awaiting setup',
    'REJECTED' => 'Declined',
    'ACTIVE' => 'Active',
    'PENDING_ACTIVATION' => 'Onboarding',
    'SUSPENDED' => 'Suspended',
    'TRIAL' => 'Trial',
    _ => s,
  };
  Widget badge(String s) {
    final color = s == 'ACTIVE'
        ? const Color(0xff28875a)
        : s == 'SUSPENDED'
        ? const Color(0xffa53e42)
        : const Color(0xff9c7824);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '• ${label(s)}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget panel(Widget child) =>
      Container(decoration: AfaqDesign.panelDecoration(), child: child);
  Widget metric(
    String title,
    String key,
    String note,
    IconData icon,
    Color color,
  ) => panel(
    Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AfaqDesign.muted),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
            ],
          ),
          Text(
            busy || summary == null ? '—' : '${summary![key]}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AfaqDesign.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            note,
            style: const TextStyle(fontSize: 13, color: AfaqDesign.muted),
          ),
        ],
      ),
    ),
  );
  Widget dropdown(
    String value,
    String hint,
    List<String> values,
    void Function(String) change, {
    bool statuses = false,
  }) => SizedBox(
    width: 180,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      key: ValueKey('$hint$value'),
      isExpanded: true,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: [
        DropdownMenuItem(value: '', child: Text(hint)),
        for (final s in {...values, if (value.isNotEmpty) value})
          DropdownMenuItem(
            value: s,
            child: Text(
              statuses ? label(s) : s,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: busy || exporting
          ? null
          : (v) {
              change(v!);
              filter();
            },
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final mobile = bounds.maxWidth < 750;
      if (selected != null) {
        final r = selected!;
        if (profileBusy || profileError != null) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(mobile ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: closeProfile,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Madrasas'),
                  ),
                ),
                if (profileBusy)
                  const LinearProgressIndicator()
                else
                  WorkspaceDetailsSection(
                    title: 'Madrasa details unavailable',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profileError!),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: refreshProfile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          key: ValueKey('madrasa-profile-${r['id']}'),
          padding: EdgeInsets.all(mobile ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: closeProfile,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Madrasas'),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : refreshProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh details'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        await Clipboard.setData(
                          ClipboardData(text: '${r['code']}'),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Afaq code copied.')),
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not copy. Select the registration code below.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy Afaq code'),
                  ),
                ],
              ),
              WorkspaceRecordHeading(
                title: '${r['name']}',
                subtitle: '${r['code']}',
                trailing: badge(r['status']),
              ),
              const SizedBox(height: 20),
              MadrasaProfileHandoff(status: r['status'] as String),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 680 ? 3 : 1;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final stat in [
                        ('Learners', r['students'], Icons.school_outlined),
                        (
                          'Active teachers',
                          r['teachers'],
                          Icons.menu_book_outlined,
                        ),
                        (
                          'Active administrators',
                          (r['admins'] as List).length,
                          Icons.admin_panel_settings_outlined,
                        ),
                      ])
                        SizedBox(
                          width:
                              (constraints.maxWidth - (columns - 1) * 16) /
                              columns,
                          child: panel(
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Icon(
                                    stat.$3,
                                    color: AfaqDesign.gold,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stat.$1,
                                          style: const TextStyle(
                                            color: AfaqDesign.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${stat.$2 ?? 'Not available'}',
                                          style: TextStyle(
                                            fontSize: stat.$2 == null ? 16 : 28,
                                            fontWeight: FontWeight.w700,
                                            color: AfaqDesign.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1000;
                  final locationSection = WorkspaceDetailsSection(
                    title: 'Location',
                    icon: Icons.location_on_outlined,
                    child: WorkspaceRecordDetails(
                      fields: [
                        if (r['location'] is Map) ...[
                          for (final entry in madrasaLocationLabels.entries)
                            if ([
                                  'country',
                                  'region',
                                  'district',
                                  'ward',
                                ].contains(entry.key) ||
                                '${r['location'][entry.key] ?? ''}'
                                    .trim()
                                    .isNotEmpty)
                              (
                                entry.value,
                                '${r['location'][entry.key] ?? 'Not recorded'}',
                              ),
                        ] else
                          ('Recorded location', place(r)),
                      ],
                    ),
                  );
                  final administration = WorkspaceDetailsSection(
                    title: 'Administration',
                    icon: Icons.admin_panel_settings_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WorkspaceRecordDetails(
                          fields: [
                            ('Afaq code', '${r['code']}'),
                            ('Madrasa status', label(r['status'])),
                            if (r['adminEmail'] != null)
                              (
                                'Proposed administrator email',
                                '${r['adminEmail']}',
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        MadrasaAdministration(record: r),
                        const SizedBox(height: 16),
                        const Text(
                          'Classroom records and finance are managed by the madrasa.',
                          style: TextStyle(color: AfaqDesign.muted),
                        ),
                      ],
                    ),
                  );
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        locationSection,
                        const SizedBox(height: 20),
                        administration,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: locationSection),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: administration),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              WorkspaceDetailsSection(
                title: 'Onboarding & next steps',
                icon: Icons.checklist_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reviewError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            reviewError!,
                            style: const TextStyle(color: Color(0xffa53e42)),
                          ),
                        ),
                      ),
                    if (r['status'] == 'REQUESTED') ...[
                      const Text(
                        'This madrasa is awaiting independent approval before technical setup.',
                      ),
                      if (r['canReview'] == true && widget.onReview != null)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final decision in ['APPROVED', 'REJECTED'])
                              OutlinedButton(
                                onPressed: busy || reviewError != null
                                    ? null
                                    : () => reviewMadrasa(r, decision),
                                child: Text(
                                  decision == 'APPROVED'
                                      ? 'Approve madrasa'
                                      : 'Decline request',
                                ),
                              ),
                          ],
                        )
                      else
                        const Text(
                          'Another Super Admin must review this request.',
                        ),
                    ] else if (r['status'] == 'REJECTED')
                      Text('Decision: ${r['decisionReason'] ?? 'Declined'}')
                    else if (r['applicationId'] != null &&
                        widget.onOnboarding != null)
                      FilledButton.icon(
                        onPressed: () =>
                            widget.onOnboarding!(r['applicationId']),
                        icon: const Icon(Icons.checklist),
                        label: const Text('Review onboarding'),
                      )
                    else if (r['applicationId'] == null)
                      const Text(
                        'No onboarding application is linked to this madrasa.',
                      )
                    else
                      const Text(
                        'Onboarding details are unavailable in this view.',
                      ),
                    if (r['applicationId'] != null && widget.onHistory != null)
                      TextButton(
                        onPressed: () => widget.onHistory!(r['applicationId']),
                        child: const Text('View office history'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      final actions = Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ReportPdfButton(
            load: widget.load,
            path: path(
              export: true,
            ).replaceFirst('/madrasas?', '/madrasas/pdf?'),
            enabled: !busy && !exporting,
          ),
          OutlinedButton.icon(
            onPressed: busy || exporting ? null : export,
            icon: const Icon(Icons.download_outlined),
            label: Text(exporting ? 'Exporting...' : 'Export list'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AfaqDesign.gold),
            onPressed: busy || exporting
                ? null
                : () async {
                    if (widget.onAdd != null) {
                      await widget.onAdd!();
                      if (mounted) refresh();
                    } else {
                      widget.onApplications();
                    }
                  },
            icon: const Icon(Icons.add),
            label: const Text('Add Madrasa'),
          ),
        ],
      );
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AFAQ · INSTITUTION WORKSPACE',
            style: TextStyle(
              color: AfaqDesign.gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Madrasas',
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Register institutions and oversee their setup without replacing local administrators.',
            style: TextStyle(color: AfaqDesign.muted),
          ),
        ],
      );
      return SingleChildScrollView(
        padding: EdgeInsets.all(mobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mobile) ...[
              heading,
              const SizedBox(height: 18),
              actions,
            ] else
              Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 16),
                  Flexible(child: actions),
                ],
              ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (_, c) {
                final n = c.maxWidth >= 1000
                    ? 4
                    : c.maxWidth >= 550
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final m in [
                      (
                        'Total madrasas',
                        'total',
                        'Created madrasa records',
                        Icons.account_balance_outlined,
                        const Color(0xff3569aa),
                      ),
                      (
                        'Active',
                        'active',
                        'Teaching and reporting',
                        Icons.check,
                        const Color(0xff28875a),
                      ),
                      (
                        'Onboarding',
                        'onboarding',
                        'Setup still in progress',
                        Icons.schedule,
                        const Color(0xff9c7824),
                      ),
                      (
                        'Assigned admins',
                        'assignedAdmins',
                        'Active madrasa admin accounts',
                        Icons.people_outline,
                        const Color(0xff8061ad),
                      ),
                    ])
                      SizedBox(
                        width: (c.maxWidth - (n - 1) * 16) / n,
                        child: metric(m.$1, m.$2, m.$3, m.$4, m.$5),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 26),
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Madrasa directory',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            WorkspaceRefreshButton(
                              onRefresh: refresh,
                              loading: busy,
                              tooltip: 'Refresh madrasas',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (_, c) {
                            final field = TextField(
                              controller: search,
                              enabled: !busy && !exporting,
                              maxLength: 100,
                              decoration: InputDecoration(
                                hintText:
                                    'Search madrasa, registration ID or area...',
                                counterText: '',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: IconButton(
                                  tooltip: 'Search',
                                  onPressed: busy ? null : filter,
                                  icon: const Icon(Icons.arrow_forward),
                                ),
                              ),
                              onSubmitted: (_) => filter(),
                            );
                            final filters = [
                              dropdown(
                                status,
                                'All statuses',
                                [
                                  'ACTIVE',
                                  'REQUESTED',
                                  'APPROVED',
                                  'REJECTED',
                                  'PENDING_ACTIVATION',
                                  'TRIAL',
                                  'SUSPENDED',
                                ],
                                (v) => status = v,
                                statuses: true,
                              ),
                              dropdown(
                                location,
                                'All locations',
                                locations,
                                (v) => location = v,
                              ),
                            ];
                            return c.maxWidth < 850
                                ? Column(
                                    children: [
                                      field,
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: filters,
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: field),
                                      const SizedBox(width: 16),
                                      filters[0],
                                      const SizedBox(width: 12),
                                      filters[1],
                                    ],
                                  );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (stale && !accessLost)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Showing previous data. Reconnecting automatically.',
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                  if (busy)
                    const LinearProgressIndicator()
                  else if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(error!),
                          TextButton(
                            onPressed: refresh,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  else if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No madrasas match these filters. New applications appear here after school creation.',
                      ),
                    )
                  else if (mobile) ...[
                    for (final r in rows)
                      ListTile(
                        title: Text('${r['name']}'),
                        subtitle: Text(
                          '${r['code']} · ${place(r)}\n${label(r['status'])}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => setState(() => selected = r),
                      ),
                  ] else
                    LayoutBuilder(
                      builder: (_, c) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: c.maxWidth),
                          child: DataTable(
                            headingRowColor: const WidgetStatePropertyAll(
                              Color(0xfff5f7f9),
                            ),
                            dataRowMinHeight: 72,
                            dataRowMaxHeight: 88,
                            columnSpacing: 24,
                            horizontalMargin: 24,
                            columns: [
                              for (final h in [
                                'Madrasa',
                                'Assigned admin',
                                'Learners',
                                'Teachers',
                                'Status',
                                '',
                              ])
                                DataColumn(
                                  label: Text(
                                    h,
                                    style: const TextStyle(
                                      color: AfaqDesign.muted,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                            rows: [
                              for (final entry in rows.asMap().entries)
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: const Color(
                                              0xffeaf1fc,
                                            ),
                                            child: Text(
                                              '${(page - 1) * 25 + entry.key + 1}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 220,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${entry.value['name']}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '${entry.value['code']} · ${place(entry.value)}',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AfaqDesign.muted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          admins(entry.value),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text('${entry.value['students'] ?? '—'}'),
                                    ),
                                    DataCell(
                                      Text('${entry.value['teachers'] ?? '—'}'),
                                    ),
                                    DataCell(badge(entry.value['status'])),
                                    DataCell(
                                      TextButton(
                                        onPressed: () => setState(
                                          () => selected = entry.value,
                                        ),
                                        child: const Text('Manage →'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          busy || error != null
                              ? 'Directory unavailable'
                              : '$total matching madrasas · Page $page',
                        ),
                        IconButton(
                          tooltip: 'Previous page',
                          onPressed: busy || page <= 1
                              ? null
                              : () {
                                  page--;
                                  refresh();
                                },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          tooltip: 'Next page',
                          onPressed: busy || error != null || page * 25 >= total
                              ? null
                              : () {
                                  page++;
                                  refresh();
                                },
                          icon: const Icon(Icons.chevron_right),
                        ),
                        const Text(
                          'No student-level changes from this directory',
                          style: TextStyle(
                            color: AfaqDesign.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xffeaf1fc),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Adding a madrasa: register its profile → independent approval → assign administrator → review readiness and activate.',
                style: TextStyle(color: Color(0xff3569aa)),
              ),
            ),
          ],
        ),
      );
    },
  );
}
