import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'foundation_ui.dart' show DashboardMetric;
import 'it_workspace_visuals.dart';

class PlatformAuditPage extends StatefulWidget {
  const PlatformAuditPage({
    super.key,
    required this.records,
    required this.busy,
    required this.error,
    required this.filters,
    required this.page,
    required this.onPage,
    required this.onRefresh,
    required this.onDetails,
  });
  final List<Map<String, dynamic>> records;
  final bool busy;
  final String? error;
  final Widget filters;
  final int page;
  final ValueChanged<int> onPage;
  final VoidCallback onRefresh;
  final ValueChanged<Map<String, dynamic>> onDetails;
  @override
  State<PlatformAuditPage> createState() => _PlatformAuditPageState();
}

class _PlatformAuditPageState extends State<PlatformAuditPage> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final rows = widget.records
          .where(
            (r) =>
                '${r['id']} ${r['actorId']} ${r['actorRole']} ${r['action']} ${r['entityId']}'
                    .toLowerCase()
                    .contains(search.text.trim().toLowerCase()),
          )
          .toList();
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
              title: 'Audit Logs',
              description:
                  'Trace platform actions through read-only security history.',
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
                    'Events on this page',
                    '${widget.records.length}',
                    Icons.description_outlined,
                  ),
                  (
                    'Account changes on page',
                    '${widget.records.where((r) => ['platform.account.disabled', 'platform.account.restored'].contains(r['action'])).length}',
                    Icons.manage_accounts_outlined,
                  ),
                  (
                    'Failed logins on page',
                    '${widget.records.where((r) => r['action'] == 'platform.login.failed').length}',
                    Icons.lock_outline,
                  ),
                  ('Review queue', 'Not connected', Icons.visibility_outlined),
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
            Container(
              decoration: AfaqDesign.panelDecoration(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Security audit trail',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Search this page',
                      hintText: 'Event ID, actor or action',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(search.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  widget.filters,
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  if (rows.isEmpty && !widget.busy && widget.error == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No audit events match this view.'),
                    ),
                  if (size.maxWidth >= 1000 && rows.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: const WidgetStatePropertyAll(
                          Color(0xfff5f7f8),
                        ),
                        columnSpacing: 24,
                        dataRowMinHeight: 72,
                        dataRowMaxHeight: 90,
                        columns: [
                          for (final title in [
                            'Time (UTC)',
                            'Actor role',
                            'Action',
                            'Reference',
                            '',
                          ])
                            DataColumn(label: Text(title)),
                        ],
                        rows: [
                          for (final r in rows)
                            DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 165,
                                    child: Text(itTimestamp(r['createdAt'])),
                                  ),
                                ),
                                DataCell(
                                  Text('${r['actorRole'] ?? 'Not recorded'}'),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 260,
                                    child: Text('${r['action']}'),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 160,
                                    child: Text(
                                      '${r['entityType'] ?? 'Not recorded'}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  TextButton(
                                    onPressed: widget.busy
                                        ? null
                                        : () => widget.onDetails(r),
                                    child: const Text('Details'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    )
                  else
                    for (final r in rows) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${r['action']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              itTimestamp(r['createdAt']),
                              style: const TextStyle(color: AfaqDesign.muted),
                            ),
                            Text('${r['actorRole'] ?? 'Role not recorded'}'),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: widget.busy
                                    ? null
                                    : () => widget.onDetails(r),
                                child: const Text('Details'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  const SizedBox(height: 16),
                  Text(
                    'Showing ${rows.length} of ${widget.records.length} events on page ${widget.page}',
                    style: const TextStyle(color: AfaqDesign.muted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: widget.busy || widget.page <= 1
                            ? null
                            : () => widget.onPage(widget.page - 1),
                        child: const Text('Previous'),
                      ),
                      OutlinedButton(
                        onPressed: widget.busy || widget.records.length < 20
                            ? null
                            : () => widget.onPage(widget.page + 1),
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final note in [
                  (
                    'Read-only history',
                    'No edit or delete controls are available here.',
                  ),
                  (
                    'Restricted metadata',
                    'Only fields returned by the authorised audit API are shown. Failed login actors identify target accounts, not verified people.',
                  ),
                  (
                    'Export unavailable',
                    'Audit export is not connected. This page does not grant permission to export sensitive records.',
                  ),
                ])
                  Container(
                    width: size.maxWidth >= 1100
                        ? (size.maxWidth - padding * 2 - 32) / 3
                        : size.maxWidth - padding * 2,
                    padding: const EdgeInsets.all(22),
                    decoration: AfaqDesign.panelDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.$1,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          note.$2,
                          style: const TextStyle(
                            color: AfaqDesign.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
