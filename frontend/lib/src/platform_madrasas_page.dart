import 'package:flutter/material.dart';
import 'api_client.dart';
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
  final Future<void> Function(Map<String, dynamic>, String)? onReview;
  final Future<bool> Function(String, String)? saveCsv;
  @override
  State<PlatformMadrasasPage> createState() => _DirectoryState();
}

class _DirectoryState extends State<PlatformMadrasasPage> {
  final search = TextEditingController();
  String status = '', location = '', query = '';
  int page = 1, total = 0;
  bool busy = true, exporting = false;
  String? error;
  Map<String, dynamic>? summary, selected;
  List<String> locations = [];
  List<Map<String, dynamic>> rows = [];
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String path({bool export = false}) =>
      '/madrasas?${Uri(queryParameters: {'page': '$page', 'search': query, if (status.isNotEmpty) 'status': status, if (location.isNotEmpty) 'location': location, if (export) 'export': 'true'}).query}';
  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.load(path());
      if (!mounted) return;
      setState(() {
        rows = (data['items'] as List).cast<Map<String, dynamic>>();
        total = data['total'];
        summary = data['summary'];
        locations = (data['locations'] as List? ?? []).cast<String>();
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) {
        widget.onSessionExpired();
      } else {
        setState(() {
          error = 'Could not load madrasas. Please try again.';
          rows = [];
          summary = null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void filter() {
    page = 1;
    query = search.text.trim();
    refresh();
  }

  Future<void> export() async {
    setState(() => exporting = true);
    try {
      final result = await widget.load(path(export: true));
      if (!mounted) return;
      String cell(dynamic v) {
        var s = '$v';
        if (RegExp(r'^\s*[=+@\-\t\r\n]').hasMatch(s)) s = "'$s";
        return '"${s.replaceAll('"', '""')}"';
      }

      final csv = [
        [
          'Madrasa',
          'Code',
          'Locations',
          'Assigned admins',
          'Learners',
          'Teachers',
          'Status',
        ],
        for (final r in result['items'] as List)
          [
            r['name'],
            r['code'],
            (r['locations'] as List? ?? []).join('; '),
            (r['admins'] as List).join('; '),
            r['students'],
            r['teachers'],
            r['status'],
          ],
      ].map((r) => r.map(cell).join(',')).join('\r\n');
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
  String place(Map<String, dynamic> r) =>
      (r['locations'] as List? ?? []).isEmpty
      ? 'Location not recorded'
      : (r['locations'] as List).join(', ');
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => selected = null),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Madrasas'),
                ),
              ),
              WorkspaceRecordHeading(
                title: '${r['name']}',
                subtitle: 'Madrasa profile and administration',
                trailing: badge(r['status']),
              ),
              const SizedBox(height: 20),
              WorkspaceDetailsSection(
                title: 'Madrasa details',
                icon: Icons.account_balance_outlined,
                child: WorkspaceRecordDetails(
                  fields: [
                    ('Registration code', '${r['code']}'),
                    ('Location', place(r)),
                    ('Assigned admins', admins(r)),
                    ('Learners', '${r['students'] ?? 'Not enrolled yet'}'),
                    (
                      'Active teachers',
                      '${r['teachers'] ?? 'Not assigned yet'}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              WorkspaceDetailsSection(
                title: 'Onboarding & next steps',
                icon: Icons.checklist_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r['status'] == 'REQUESTED') ...[
                      const Text(
                        'This madrasa is awaiting independent approval before technical setup.',
                      ),
                      if (r['canReview'] == true && widget.onReview != null)
                        Wrap(
                          spacing: 12,
                          children: [
                            for (final decision in ['APPROVED', 'REJECTED'])
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        setState(() => busy = true);
                                        try {
                                          await widget.onReview!(r, decision);
                                        } finally {
                                          if (mounted) {
                                            setState(() => selected = null);
                                            await refresh();
                                          }
                                        }
                                      },
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
                    else
                      const Text(
                        'No onboarding application is linked to this madrasa.',
                      ),
                    if (r['applicationId'] != null && widget.onHistory != null)
                      TextButton(
                        onPressed: () => widget.onHistory!(r['applicationId']),
                        child: const Text('View office history'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const WorkspaceDetailsSection(
                title: 'Management responsibilities',
                icon: Icons.verified_user_outlined,
                child: Text(
                  'Classroom records and finance remain managed inside the madrasa. No student-level changes from this directory.',
                  style: TextStyle(color: AfaqDesign.muted, height: 1.6),
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
                  actions,
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
                                    'Search madrasa or registration ID...',
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
                'Adding a madrasa: register its profile → independent approval → IT setup → assign administrator → review readiness and activate.',
                style: TextStyle(color: Color(0xff3569aa)),
              ),
            ),
          ],
        ),
      );
    },
  );
}
