import 'package:flutter/material.dart';
import 'api_client.dart';
import 'design_tokens.dart';
import 'workspace_chrome.dart';
import 'workspace_details_dialog.dart';

class PlatformStaffPage extends StatefulWidget {
  const PlatformStaffPage({
    super.key,
    required this.load,
    required this.onCompanyAccounts,
    required this.onApplications,
    required this.onSessionExpired,
  });
  final Future<dynamic> Function(String) load;
  final VoidCallback onCompanyAccounts, onApplications, onSessionExpired;
  @override
  State<PlatformStaffPage> createState() => _PlatformStaffPageState();
}

class _PlatformStaffPageState extends State<PlatformStaffPage> {
  final search = TextEditingController();
  String query = '', role = '', status = '', preview = 'ADMIN';
  int page = 1, total = 0;
  bool busy = true;
  String? error;
  Map<String, dynamic>? summary;
  List<Map<String, dynamic>> rows = [];
  static const roles = {
    'ADMIN': 'Madrasa Admin',
    'TEACHER': 'Teacher',
    'ACCOUNTANT': 'Accountant',
  };
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

  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
      rows = [];
    });
    try {
      final params = Uri(
        queryParameters: {
          'page': '$page',
          'search': query,
          if (role.isNotEmpty) 'role': role,
          if (status.isNotEmpty) 'status': status,
        },
      ).query;
      final result = await widget.load('/staff-directory?$params');
      if (!mounted) return;
      setState(() {
        rows = (result['items'] as List).cast<Map<String, dynamic>>();
        total = result['total'] as int;
        summary = result['summary'];
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) {
        widget.onSessionExpired();
      } else {
        setState(() => error = 'Could not load accounts. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: AfaqDesign.panelDecoration(),
    child: child,
  );
  Widget badge(String label, {bool good = true}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: good ? const Color(0xffe7f3ed) : const Color(0xfff8f0da),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      '• $label',
      style: TextStyle(
        color: good ? const Color(0xff28875a) : const Color(0xff9c7824),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );
  Widget metric(
    String title,
    String key,
    String note,
    IconData icon,
    Color color,
  ) => panel(
    Column(
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
          busy || error != null || summary == null ? '—' : '${summary![key]}',
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
  );
  Future<void> invite() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite user'),
        content: const Text(
          'Madrasa administrator invitations follow the approved madrasa onboarding process.\n\nTeachers and accountants are added by their own madrasa administrator. This page does not grant cross-madrasa access or send invitations directly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Choose madrasa'),
          ),
        ],
      ),
    );
    if (mounted && proceed == true) widget.onApplications();
  }

  Widget permission(String title, String description, bool allowed) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AfaqDesign.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              allowed ? Icons.check : Icons.remove,
              size: 20,
              color: allowed ? const Color(0xff28875a) : AfaqDesign.muted,
            ),
          ],
        ),
      ),
      const Divider(height: 1),
    ],
  );
  void review(Map<String, dynamic> row) => showDialog<void>(
    context: context,
    builder: (context) => WorkspaceDetailsDialog(
      title: row['fullName'] as String,
      statusFields: const {'Account status', 'Madrasa status'},
      fields: [
        ('Role', roles[row['role']] ?? '${row['role']}'),
        ('Assigned madrasa', '${row['school']['name']}'),
        ('Madrasa code', '${row['school']['code']}'),
        ('Account status', '${row['status']}'),
        ('Madrasa status', '${row['school']['status']}'),
      ],
      sections: const [
        (
          'Access scope',
          'Access is limited to the assigned madrasa. An active account does not override a suspended madrasa or grant access to another school.',
        ),
        (
          'Who can make changes?',
          'Changes to school staff accounts remain with the responsible madrasa administrator.',
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final compact = bounds.maxWidth < 1000;
      final directory = panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Accounts & scope',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                WorkspaceRefreshButton(
                  onRefresh: refresh,
                  loading: busy,
                  tooltip: 'Refresh staff directory',
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (_, filters) => Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: filters.maxWidth >= 600
                        ? filters.maxWidth - 330
                        : filters.maxWidth,
                    child: TextField(
                      controller: search,
                      enabled: !busy,
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: 'Search staff or madrasa',
                        counterText: '',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Search accounts',
                          onPressed: busy
                              ? null
                              : () {
                                  query = search.text.trim();
                                  page = 1;
                                  refresh();
                                },
                          icon: const Icon(Icons.arrow_forward),
                        ),
                      ),
                      onSubmitted: (_) {
                        query = search.text.trim();
                        page = 1;
                        refresh();
                      },
                    ),
                  ),
                  DropdownButton<String>(
                    value: role,
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All staff roles'),
                      ),
                      for (final r in roles.entries)
                        DropdownMenuItem(value: r.key, child: Text(r.value)),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            role = v!;
                            page = 1;
                            refresh();
                          },
                  ),
                  DropdownButton<String>(
                    value: status,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All statuses')),
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'DISABLED',
                        child: Text('Disabled'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            status = v!;
                            page = 1;
                            refresh();
                          },
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            if (busy)
              const LinearProgressIndicator()
            else if (error != null) ...[
              Text(error!),
              TextButton(onPressed: refresh, child: const Text('Try again')),
            ] else if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No staff accounts match these filters.'),
              )
            else if (bounds.maxWidth < 750)
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(row['fullName'] as String),
                  subtitle: Text(
                    '${roles[row['role']]} · ${row['status']}\n${row['school']['name']} · ${row['school']['code']}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Review ${row['fullName']}',
                    onPressed: () => review(row),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ),
            if (!busy &&
                error == null &&
                rows.isNotEmpty &&
                bounds.maxWidth >= 750)
              LayoutBuilder(
                builder: (_, c) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: c.maxWidth),
                    child: DataTable(
                      headingRowColor: const WidgetStatePropertyAll(
                        Color(0xfff5f7f9),
                      ),
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 80,
                      horizontalMargin: 0,
                      columnSpacing: 22,
                      columns: [
                        for (final h in [
                          'Account',
                          'Role',
                          'Access scope',
                          'Status',
                          '',
                        ])
                          DataColumn(
                            label: Text(
                              h,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AfaqDesign.muted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                      rows: [
                        for (final row in rows)
                          DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: Text(
                                    row['fullName'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(roles[row['role']]!)),
                              DataCell(
                                SizedBox(
                                  width: 150,
                                  child: Text(
                                    row['school']['name'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                badge(
                                  row['status'] == 'ACTIVE'
                                      ? 'Active'
                                      : 'Disabled',
                                  good: row['status'] == 'ACTIVE',
                                ),
                              ),
                              DataCell(
                                Tooltip(
                                  message: 'Review ${row['fullName']}',
                                  child: TextButton(
                                    onPressed: () => review(row),
                                    child: const Text('Review'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            const Divider(height: 24),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  busy || error != null
                      ? 'Directory not ready'
                      : '$total accounts · Page $page',
                ),
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: busy || page == 1
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
              ],
            ),
          ],
        ),
      );
      final permissions = panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Role preview',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                badge('Least privilege'),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: preview,
              isExpanded: true,
              items: [
                for (final r in roles.entries)
                  DropdownMenuItem(value: r.key, child: Text(r.value)),
              ],
              onChanged: (v) => setState(() => preview = v!),
            ),
            const SizedBox(height: 16),
            permission(
              preview == 'TEACHER'
                  ? 'Teaching & learner records'
                  : preview == 'ACCOUNTANT'
                  ? 'School financial operations'
                  : 'Manage students',
              preview == 'TEACHER'
                  ? 'Authorised teaching assignments only'
                  : 'Assigned madrasa only',
              true,
            ),
            permission(
              'Assign teachers',
              preview == 'ADMIN'
                  ? 'Assigned madrasa only'
                  : 'Madrasa administrator responsibility',
              preview == 'ADMIN',
            ),
            permission('View other madrasas', 'No cross-madrasa access', false),
            permission(
              'Institution donor records',
              'Not included in school roles',
              false,
            ),
            permission(
              'Grant Superadmin access',
              'Company access remains separate',
              false,
            ),
            const SizedBox(height: 20),
            const Text(
              'This is a role summary, not a permission editor. The backend checks each request and school scope.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Parents and children are not listed here. Family links remain managed inside each madrasa.',
            ),
          ],
        ),
      );
      return SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'AFAQ / INSTITUTION WORKSPACE',
              style: TextStyle(
                color: AfaqDesign.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 12,
              children: [
                Text(
                  'Users & Permissions',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton.icon(
                  onPressed: invite,
                  style: FilledButton.styleFrom(
                    backgroundColor: AfaqDesign.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Invite user'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Review staff roles and assigned madrasas. Company accounts remain separate.',
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (_, size) {
                final columns = size.maxWidth >= 1000
                    ? 4
                    : size.maxWidth >= 600
                    ? 2
                    : 1;
                final width = (size.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: width,
                      child: metric(
                        'Madrasa admins',
                        'admins',
                        'Active in assigned madrasas',
                        Icons.apartment_outlined,
                        const Color(0xff356bc0),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: metric(
                        'Teachers',
                        'teachers',
                        'Active teaching accounts',
                        Icons.menu_book_outlined,
                        const Color(0xff28875a),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: metric(
                        'Guardian links',
                        'guardianLinks',
                        'Recorded links to children',
                        Icons.people_outline,
                        AfaqDesign.gold,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: metric(
                        'Pending requests',
                        'pendingRequests',
                        'Admin onboarding awaiting approval',
                        Icons.lock_outline,
                        const Color(0xff7962b4),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            if (compact) ...[
              directory,
              const SizedBox(height: 20),
              permissions,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: directory),
                  const SizedBox(width: 20),
                  Expanded(child: permissions),
                ],
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xfff8f0da),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AfaqDesign.gold),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Permission changes follow authorised workflows. Public registration does not grant privileged roles.',
                      style: TextStyle(color: Color(0xff997627)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
