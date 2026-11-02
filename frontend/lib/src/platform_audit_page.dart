import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'foundation_ui.dart' show DashboardMetric;
import 'it_workspace_visuals.dart';
import 'report_preview.dart';
import 'audit_labels.dart';

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
    this.exportPdf,
  });
  final List<Map<String, dynamic>> records;
  final bool busy;
  final String? error;
  final Widget filters;
  final int page;
  final ValueChanged<int> onPage;
  final VoidCallback onRefresh;
  final ValueChanged<Map<String, dynamic>> onDetails;
  final Future<dynamic> Function(List<String> ids)? exportPdf;
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
      final ready = !widget.busy && widget.error == null;
      final rows = (ready ? widget.records : <Map<String, dynamic>>[])
          .where(
            (r) =>
                '${r['id']} ${r['actorId']} ${r['actorRole']} ${r['action']} ${r['entityId']} ${auditActionLabel(r['action'])} ${auditRoleLabel(r['actorRole'])}'
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
            ItSectionPanel(
              title: 'Security audit trail',
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    if (widget.exportPdf != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AfaqDesign.blue.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const SizedBox(
                              width: 260,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Export visible events',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Current page only. Each PDF export is recorded in the audit log.',
                                    style: TextStyle(
                                      color: AfaqDesign.muted,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ReportPdfButton(
                              enabled: ready && rows.isNotEmpty,
                              path: '/audit-events/pdf',
                              load: (_) => widget.exportPdf!(
                                rows.map((row) => '${row['id']}').toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
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
                                    Text(auditRoleLabel(r['actorRole'])),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 260,
                                      child: Text(
                                        auditActionLabel(r['action']),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 160,
                                      child: Text(
                                        auditReferenceLabel(r['entityType']),
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
                                auditActionLabel(r['action']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                itTimestamp(r['createdAt']),
                                style: const TextStyle(color: AfaqDesign.muted),
                              ),
                              const SizedBox(height: 8),
                              Text(auditRoleLabel(r['actorRole'])),
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
                      widget.busy
                          ? 'Loading audit events...'
                          : widget.error != null
                          ? 'Audit events are unavailable. Retry with Refresh.'
                          : 'Showing ${rows.length} of ${widget.records.length} events on page ${widget.page}',
                      style: const TextStyle(color: AfaqDesign.muted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Page ${widget.page}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
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
                    'Controlled export',
                    'IT exports contain selected events only, without event metadata or secrets. Share only with authorised recipients.',
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
