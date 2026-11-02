import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'foundation_ui.dart' show DashboardMetric;
import 'it_workspace_visuals.dart';
import 'status_badge.dart';
import 'workspace_form_dialog.dart';

class PlatformAccessPage extends StatefulWidget {
  const PlatformAccessPage({
    super.key,
    required this.records,
    required this.busy,
    required this.error,
    required this.page,
    required this.role,
    required this.onRole,
    required this.onPage,
    required this.onRefresh,
    required this.onReview,
    this.status = '',
    this.onStatus,
  });
  final List<Map<String, dynamic>> records;
  final bool busy;
  final String? error;
  final int page;
  final String role;
  final String status;
  final ValueChanged<String>? onStatus;
  final ValueChanged<String> onRole;
  final ValueChanged<int> onPage;
  final VoidCallback onRefresh;
  final ValueChanged<Map<String, dynamic>> onReview;
  @override
  State<PlatformAccessPage> createState() => _PlatformAccessPageState();
}

class _PlatformAccessPageState extends State<PlatformAccessPage> {
  String query = '';
  final search = TextEditingController();
  DialogRoute<bool>? reviewRoute;
  bool get ready => !widget.busy && widget.error == null;

  @override
  void didUpdateWidget(covariant PlatformAccessPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!ready || !identical(oldWidget.records, widget.records)) {
      dismissReview();
    }
  }

  void dismissReview() {
    final route = reviewRoute;
    reviewRoute = null;
    if (route == null) return;
    // Remove only our route, after the navigator has finished this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  @override
  void dispose() {
    dismissReview();
    search.dispose();
    super.dispose();
  }

  String scope(dynamic role) => switch (role) {
    'SUPER_ADMIN' => 'Institution-wide',
    'IT_SECURITY' => 'Technical operations',
    _ => 'Scope unavailable',
  };

  Future<void> review(Map<String, dynamic> row) async {
    if (!ready || reviewRoute != null) return;
    final route = DialogRoute<bool>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        icon: Icons.account_circle_outlined,
        eyebrow: 'ACCOUNT / READ-ONLY',
        title: Text('${row['fullName'] ?? 'Company account'}'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: badge(row)),
                const SizedBox(height: 20),
                ItRecordDetails(
                  values: {
                    'Role': roleName(row['role']),
                    'Access scope': scope(row['role']),
                    'Email': row['email'],
                    'Account ID': row['id'],
                    'Created (UTC)': row['createdAt'],
                  },
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xfff5f7f8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Read-only account review. Access history records account changes; this view does not grant or change permissions.',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.history),
            label: const Text('Access history'),
          ),
        ],
      ),
    );
    reviewRoute = route;
    final history = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(route);
    final valid = identical(reviewRoute, route);
    if (valid) reviewRoute = null;
    if (mounted && valid && history == true && ready) widget.onReview(row);
  }

  String roleName(dynamic role) => switch (role) {
    'SUPER_ADMIN' => 'Super Admin',
    'IT_SECURITY' => 'IT Security',
    _ => 'Role unavailable',
  };
  Widget panel(String title, Widget child) => Container(
    decoration: AfaqDesign.panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(22),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.all(22), child: child),
      ],
    ),
  );
  Widget badge(Map<String, dynamic> row) => AfaqStatusBadge(
    label: '${row['status'] ?? 'Unknown'}',
    color: row['status'] == 'ACTIVE'
        ? const Color(0xff278457)
        : AfaqDesign.muted,
  );
  @override
  Widget build(BuildContext context) {
    final rows = (ready ? widget.records : <Map<String, dynamic>>[])
        .where(
          (r) => '${r['fullName']} ${r['id']} ${roleName(r['role'])}'
              .toLowerCase()
              .contains(query.trim().toLowerCase()),
        )
        .toList();
    final accounts = panel(
      'Accounts & access scope',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: search,
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        search.clear();
                        setState(() => query = '');
                      },
                    ),
              labelText: 'Search this page',
              hintText: 'Account name, ID or role',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('role-${widget.role}'),
            isExpanded: true,
            initialValue: widget.role,
            decoration: const InputDecoration(labelText: 'Account role'),
            items: const [
              DropdownMenuItem(value: '', child: Text('All company roles')),
              DropdownMenuItem(
                value: 'SUPER_ADMIN',
                child: Text('Super Admin'),
              ),
              DropdownMenuItem(
                value: 'IT_SECURITY',
                child: Text('IT Security'),
              ),
            ],
            onChanged: widget.busy
                ? null
                : (value) => widget.onRole(value ?? ''),
          ),
          if (widget.onStatus != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('status-${widget.status}'),
              isExpanded: true,
              initialValue: widget.status,
              decoration: const InputDecoration(labelText: 'Account status'),
              items: const [
                DropdownMenuItem(value: '', child: Text('All statuses')),
                DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                DropdownMenuItem(value: 'DISABLED', child: Text('Disabled')),
              ],
              onChanged: widget.busy
                  ? null
                  : (value) => widget.onStatus!(value ?? ''),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            widget.busy
                ? 'Loading accounts...'
                : widget.error != null
                ? 'Accounts are unavailable. Retry with Refresh.'
                : '${rows.length} of ${widget.records.length} accounts on this page',
            style: const TextStyle(color: AfaqDesign.muted),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty && !widget.busy && widget.error == null)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No accounts match this view.'),
            ),
          LayoutBuilder(
            builder: (context, size) {
              if (size.maxWidth < 650) {
                return Column(
                  children: [
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${row['fullName'] ?? 'Company account'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(roleName(row['role'])),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: badge(row),
                            ),
                            TextButton(
                              onPressed: widget.busy ? null : () => review(row),
                              child: const Text('Review'),
                            ),
                            const Divider(),
                          ],
                        ),
                      ),
                  ],
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(
                    Color(0xfff5f7f8),
                  ),
                  columnSpacing: 24,
                  dataRowMinHeight: 64,
                  dataRowMaxHeight: 80,
                  columns: [
                    for (final label in [
                      'Account',
                      'Role',
                      'Scope',
                      'Status',
                      '',
                    ])
                      DataColumn(label: Text(label)),
                  ],
                  rows: [
                    for (final row in rows)
                      DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 160,
                              child: Text(
                                '${row['fullName'] ?? 'Company account'}',
                              ),
                            ),
                          ),
                          DataCell(Text(roleName(row['role']))),
                          DataCell(Text(scope(row['role']))),
                          DataCell(badge(row)),
                          DataCell(
                            TextButton(
                              onPressed: widget.busy ? null : () => review(row),
                              child: const Text('Review'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Company accounts only. School staff and learner records are not included.',
            style: TextStyle(color: AfaqDesign.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Page ${widget.page}'),
              OutlinedButton(
                onPressed: !ready || widget.page <= 1
                    ? null
                    : () => widget.onPage(widget.page - 1),
                child: const Text('Previous'),
              ),
              OutlinedButton(
                onPressed: !ready || widget.records.length < 20
                    ? null
                    : () => widget.onPage(widget.page + 1),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
    final permissions = panel(
      'IT & Security permissions',
      Column(
        children: [
          for (final item in [
            (
              'Inspect platform health',
              'Connectivity checks and operational metadata',
              true,
            ),
            ('Review audit logs', 'Read-only platform security history', true),
            ('Revoke own sessions', 'Other accounts are not included', true),
            ('Edit grades or Quran records', 'Not part of the IT role', false),
            ('Approve payments', 'Not part of the IT role', false),
            ('Grant Superadmin access', 'Not available to IT', false),
          ]) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.$1),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(item.$2),
              ),
              trailing: Icon(
                item.$3 ? Icons.check : Icons.remove,
                color: item.$3 ? AfaqDesign.ink : AfaqDesign.muted,
              ),
            ),
            const Divider(height: 24),
          ],
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, size) {
        final columns = size.maxWidth >= 1100
            ? 4
            : size.maxWidth >= 650
            ? 2
            : 1;
        final padding = size.maxWidth < 600 ? 16.0 : 28.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ItPageHeading(
                title: 'Access & Roles',
                description:
                    'Review technical access without changing learning or financial records.',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: widget.busy ? null : widget.onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
              if (widget.busy) const LinearProgressIndicator(),
              if (widget.error != null)
                Text(widget.error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final metric in [
                    (
                      'Accounts on this page',
                      '${widget.records.length}',
                      Icons.people_outline,
                    ),
                    (
                      'Active on this page',
                      '${widget.records.where((r) => r['status'] == 'ACTIVE').length}',
                      Icons.verified_user_outlined,
                    ),
                    ('MFA enrollment', 'Not available', Icons.security),
                    ('Access requests', 'Not connected', Icons.schedule),
                  ])
                    SizedBox(
                      width:
                          (size.maxWidth - padding * 2 - (columns - 1) * 16) /
                          columns,
                      child: DashboardMetric(
                        label: metric.$1,
                        value: widget.busy
                            ? 'Loading'
                            : widget.error != null
                            ? 'Unavailable'
                            : metric.$2,
                        icon: metric.$3,
                        accent: AfaqDesign.blue,
                        dense: true,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (size.maxWidth >= 1100)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: accounts),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: permissions),
                  ],
                )
              else ...[
                accounts,
                const SizedBox(height: 24),
                permissions,
              ],
              const SizedBox(height: 24),
              const Text(
                'Read-only access review. Public sign-up does not grant platform roles.',
                style: TextStyle(color: AfaqDesign.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}
