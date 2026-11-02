import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'foundation_ui.dart' show DashboardMetric;
import 'it_workspace_visuals.dart';
import 'status_badge.dart';

class PlatformSessionsPage extends StatefulWidget {
  const PlatformSessionsPage({
    super.key,
    required this.records,
    required this.busy,
    required this.error,
    required this.page,
    required this.onPage,
    required this.onRefresh,
    required this.details,
    this.oversight = false,
    this.source = 'platform',
    this.onSource,
  });
  final bool oversight;
  final String source;
  final ValueChanged<String>? onSource;
  final List<Map<String, dynamic>> records;
  final bool busy;
  final String? error;
  final int page;
  final ValueChanged<int> onPage;
  final VoidCallback onRefresh;
  final Widget Function(Map<String, dynamic>) details;
  @override
  State<PlatformSessionsPage> createState() => _PlatformSessionsPageState();
}

class _PlatformSessionsPageState extends State<PlatformSessionsPage> {
  String? selected;
  String filter = 'all';
  final detailKey = GlobalKey();
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
        Padding(padding: const EdgeInsets.all(20), child: child),
      ],
    ),
  );
  void choose(Map<String, dynamic> row, bool compact) {
    setState(() => selected = '${row['id']}');
    if (compact) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && detailKey.currentContext != null) {
          Scrollable.ensureVisible(
            detailKey.currentContext!,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final compact = size.maxWidth < 1100;
      final ready = !widget.busy && widget.error == null;
      final rows = (ready ? widget.records : <Map<String, dynamic>>[])
          .where(
            (r) =>
                filter == 'all' ||
                (r['current'] == true) == (filter == 'current'),
          )
          .toList();
      final chosen = rows.where((r) => '${r['id']}' == selected).firstOrNull;
      final list = panel(
        widget.oversight ? 'Account sessions' : 'Your active sessions',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.oversight) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: widget.source,
                decoration: const InputDecoration(labelText: 'Account group'),
                items: const [
                  DropdownMenuItem(
                    value: 'platform',
                    child: Text('Platform accounts'),
                  ),
                  DropdownMenuItem(
                    value: 'madrasa',
                    child: Text('All madrasa accounts'),
                  ),
                ],
                onChanged: ready
                    ? (value) {
                        setState(() {
                          selected = null;
                          filter = 'all';
                        });
                        if (value != null) widget.onSource?.call(value);
                      }
                    : null,
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              key: ValueKey('session-filter-${widget.source}'),
              initialValue: filter,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Session filter'),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(
                    widget.oversight
                        ? 'All listed sessions'
                        : 'All your sessions',
                  ),
                ),
                DropdownMenuItem(
                  value: 'current',
                  child: Text('Current session'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Other sessions')),
              ],
              onChanged: (value) => setState(() => filter = value ?? 'all'),
            ),
            const SizedBox(height: 20),
            Text(
              widget.busy
                  ? 'Loading sessions...'
                  : widget.error != null
                  ? 'Sessions are unavailable. Retry with Refresh.'
                  : '${rows.length} of ${widget.records.length} sessions on this page',
              style: const TextStyle(color: AfaqDesign.muted),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty && !widget.busy && widget.error == null)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No sessions match this view.'),
              ),
            if (!compact && rows.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  columnSpacing: 22,
                  headingRowColor: const WidgetStatePropertyAll(
                    Color(0xfff5f7f8),
                  ),
                  dataRowMinHeight: 72,
                  dataRowMaxHeight: 88,
                  columns: [
                    for (final label in [
                      'Session',
                      if (widget.oversight) 'IP address',
                      'Signed in (UTC)',
                      'Expires (UTC)',
                      '',
                    ])
                      DataColumn(label: Text(label)),
                  ],
                  rows: [
                    for (final row in rows)
                      DataRow(
                        selected: '${row['id']}' == selected,
                        onSelectChanged: widget.busy
                            ? null
                            : (_) => choose(row, false),
                        cells: [
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row['current'] == true
                                      ? 'Current session'
                                      : widget.oversight
                                      ? '${row['accountName'] ?? 'Account'}'
                                      : 'Another session',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  row['current'] == true
                                      ? 'This sign-in'
                                      : widget.oversight
                                      ? '${row['role'] ?? ''} / ${row['scope'] ?? ''}'
                                      : 'Your account',
                                  style: const TextStyle(
                                    color: AfaqDesign.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.oversight)
                            DataCell(
                              Text('${row['ipAddress'] ?? 'Not recorded'}'),
                            ),
                          DataCell(
                            SizedBox(
                              width: 145,
                              child: Text(itTimestamp(row['createdAt'])),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 145,
                              child: Text(itTimestamp(row['expiresAt'])),
                            ),
                          ),
                          DataCell(
                            TextButton(
                              onPressed: widget.busy
                                  ? null
                                  : () => choose(row, false),
                              child: const Text('Review'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            if (compact)
              for (final row in rows) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: '${row['id']}' == selected
                        ? const Color(0xffedf3fa)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(
                            Icons.devices_outlined,
                            color: AfaqDesign.blue,
                          ),
                          Text(
                            row['current'] == true
                                ? 'Current session'
                                : widget.oversight
                                ? '${row['accountName'] ?? 'Account'}'
                                : 'Another session',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          AfaqStatusBadge(
                            label: row['current'] == true
                                ? 'Current'
                                : 'Listed',
                            color: AfaqDesign.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.oversight) ...[
                        Text('${row['role'] ?? ''} / ${row['scope'] ?? ''}'),
                        Text(
                          'IP address: ${row['ipAddress'] ?? 'Not recorded'}',
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        'Signed in: ${itTimestamp(row['createdAt'])}',
                        style: const TextStyle(color: AfaqDesign.muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Expires: ${itTimestamp(row['expiresAt'])}',
                        style: const TextStyle(color: AfaqDesign.muted),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: widget.busy
                              ? null
                              : () => choose(row, compact),
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('Review'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            const SizedBox(height: 16),
            Text(
              widget.oversight
                  ? 'IP is recorded at sign-in or renewal, not live location. Older sessions may have no IP. Madrasa entries represent renewable access, not online devices.'
                  : 'Your account only. Session identifiers appear in the selected review.',
              style: TextStyle(color: AfaqDesign.muted),
            ),
            const SizedBox(height: 16),
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
      final detail = Container(
        key: detailKey,
        child: panel(
          'Session review',
          chosen == null
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.touch_app_outlined,
                        size: 36,
                        color: AfaqDesign.muted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.busy
                            ? 'Checking session access...'
                            : widget.error != null
                            ? 'Session details are hidden until access is verified again.'
                            : 'Select a session to review its details.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => selected = null),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Close review'),
                      ),
                    ),
                    widget.details(chosen),
                  ],
                ),
        ),
      );
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
            ItPageHeading(
              title: widget.oversight ? 'Sessions' : 'Sessions & Devices',
              description: widget.oversight
                  ? 'Inspect account access and recorded IP addresses across the platform and madrasas.'
                  : 'Review and manage sessions for your signed-in platform account.',
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
                    'Sessions on this page',
                    '${widget.records.length}',
                    Icons.devices_outlined,
                  ),
                  ('Registered devices', 'Not connected', Icons.phonelink),
                  ('Device trust', 'Not measured', Icons.shield_outlined),
                  ('Offline devices', 'Not measured', Icons.sync),
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
            if (!compact)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: list),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: detail),
                ],
              )
            else ...[
              list,
              const SizedBox(height: 24),
              detail,
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xffeaf1fc),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Revoking a session prevents new server requests. It does not erase locally cached data. Signing out the current session returns you to login.',
              ),
            ),
          ],
        ),
      );
    },
  );
}
