import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';

class DonationsPage extends StatefulWidget {
  const DonationsPage({
    super.key,
    required this.load,
    required this.submit,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final int refreshToken;
  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage> {
  String directory = 'donors', search = '';
  int page = 1;
  late Future<dynamic> future = fetch();
  Future<dynamic> fetch() async {
    final values = await Future.wait([
      widget.load('/api/fundraising/overview'),
      widget.load('/api/fundraising/donations?pageSize=5'),
      widget.load('/api/fundraising/campaigns?pageSize=5'),
      widget.load(
        '/api/fundraising/$directory?${Uri(queryParameters: {'page': '$page', 'pageSize': '10', 'search': search}).query}',
      ),
    ]);
    return {
      'overview': values[0],
      'recent': values[1],
      'campaigns': values[2],
      'directory': values[3],
    };
  }

  void reload() {
    setState(() {
      future = fetch();
    });
  }

  @override
  void didUpdateWidget(covariant DonationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) future = fetch();
  }

  static const donorField = AdminField(
    'donorId',
    'Donor',
    lookupPath: '/api/fundraising/donors',
  );
  static const campaignField = AdminField(
    'campaignId',
    'Campaign',
    lookupPath: '/api/fundraising/campaigns',
    lookupLabel: 'title',
  );
  Future<void> create(String kind) async {
    final (title, fields) = switch (kind) {
      'donors' => (
        'Add donor',
        const [
          AdminField('fullName', 'Full name'),
          AdminField('email', 'Email address', kind: 'email', required: false),
          AdminField('phone', 'Phone number', required: false),
        ],
      ),
      'campaigns' => (
        'Create campaign',
        const [
          AdminField('title', 'Campaign name'),
          AdminField('goalAmount', 'Fundraising goal (TZS)', kind: 'money'),
          AdminField(
            'description',
            'Description',
            kind: 'notes',
            required: false,
          ),
        ],
      ),
      _ => (
        'Add pledge',
        const [
          donorField,
          campaignField,
          AdminField('amount', 'Pledged amount (TZS)', kind: 'money'),
          AdminField('dueOn', 'Due date', kind: 'date'),
        ],
      ),
    };
    final saved = await showAdminForm(
      context,
      title: title,
      fields: fields,
      load: widget.load,
      onSave: (body) async {
        await widget.submit('/api/fundraising/$kind', body);
      },
    );
    if (saved && mounted) {
      directory = kind;
      page = 1;
      search = '';
      reload();
    }
  }

  Future<void> receive({Map<String, dynamic>? pledge}) async {
    final key = submissionId(),
        timestamp = DateTime.now().toUtc().toIso8601String();
    final saved = await showAdminForm(
      context,
      title: 'Record donation',
      load: widget.load,
      saveLabel: 'Save donation',
      note: pledge == null
          ? 'Record money already received. For a promise to contribute, add a pledge instead.'
          : '${recordText(recordMap(pledge['donor'])['fullName'])} - ${recordText(recordMap(pledge['campaign'])['title'])}',
      fields: [
        if (pledge == null) ...[donorField, campaignField],
        const AdminField('amount', 'Amount received (TZS)', kind: 'money'),
        const AdminField(
          'method',
          'Payment method',
          options: {
            'CASH': 'Cash',
            'BANK': 'Bank transfer',
            'MOBILE_MONEY': 'Mobile money',
          },
        ),
        const AdminField('reference', 'Payment reference', required: false),
      ],
      onSave: (body) async {
        await widget.submit('/api/fundraising/donations', {
          ...body,
          'idempotencyKey': key,
          'receivedAt': timestamp,
          if (pledge != null) ...{
            'donorId': pledge['donorId'],
            'campaignId': pledge['campaignId'],
            'pledgeId': pledge['id'],
          },
        });
      },
    );
    if (saved && mounted) reload();
  }

  Future<void> receipt(Map<String, dynamic> row) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _Receipt(load: widget.load, id: '${row['id']}'),
    );
  }

  Future<void> voidEntry(Map<String, dynamic> row) async {
    final saved = await showAdminForm(
      context,
      title: 'Void donation',
      saveLabel: 'Void donation',
      note:
          'TZS ${moneyText(row['amount'])} will be removed from collection totals. The receipt and reason will remain in the records.',
      fields: const [AdminField('reason', 'Reason', kind: 'notes')],
      onSave: (body) async {
        await widget.submit(
          '/api/fundraising/donations/${row['id']}/void',
          body,
        );
      },
    );
    if (saved && mounted) reload();
  }

  @override
  Widget build(BuildContext context) => PageResult(
    future: future,
    onRetry: reload,
    builder: (data) {
      final map = recordMap(data), summary = recordMap(map['overview']);
      final recent = recordList(recordMap(map['recent'])['items']);
      final campaigns = recordList(recordMap(map['campaigns'])['items']);
      final records = recordMap(map['directory']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: receive,
              icon: const Icon(Icons.add),
              label: const Text('Record donation'),
            ),
          ),
          const SizedBox(height: 16),
          MetricRow(
            children: [
              DashboardMetric(
                label: 'Total collected',
                value: moneyText(summary['collectedAmount']),
                icon: Icons.volunteer_activism_outlined,
                accent: forest,
                note: 'TZS received, excluding voids',
              ),
              DashboardMetric(
                label: 'Monthly pledges',
                value: moneyText(summary['monthlyPledges']),
                icon: Icons.event_note_outlined,
                accent: blue,
                note: 'TZS promised for this month',
              ),
              DashboardMetric(
                label: 'Pending collections',
                value: moneyText(summary['pendingAmount']),
                icon: Icons.schedule_outlined,
                accent: gold,
                note: 'TZS remaining on pledges',
              ),
              DashboardMetric(
                label: 'Total donors',
                value: recordText(summary['totalDonors'], '0'),
                icon: Icons.groups_outlined,
                accent: const Color(0xFFBE4A5C),
                note: 'Registered supporters',
              ),
            ],
          ),
          const SizedBox(height: 18),
          AdminPanelGrid(
            children: [
              SurfacePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PanelHeading(
                      'Collection trend',
                      subtitle: 'Received donations - last 6 months',
                    ),
                    ColumnChart(
                      height: 180,
                      items: [
                        for (final r in recordList(summary['trend']))
                          ChartDatum(
                            monthName(r['month']),
                            recordNumber(r['amount']),
                            ink,
                          ),
                      ],
                    ),
                    const Text(
                      'Amounts in TZS',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              SurfacePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PanelHeading(
                      'Donations by campaign',
                      subtitle: 'Share of all received donations',
                    ),
                    RingChart(
                      center: moneyText(summary['collectedAmount']),
                      caption: 'TZS collected',
                      items: [
                        for (final (i, row) in recordList(
                          summary['distribution'],
                        ).indexed)
                          ChartDatum(
                            recordText(row['name']),
                            recordNumber(row['amount']),
                            [ink, gold, blue, forest, lavender, muted][i % 6],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SurfacePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PanelHeading(
                      'Recent transactions',
                      action: TextButton(
                        onPressed: () {
                          directory = 'donations';
                          page = 1;
                          search = '';
                          reload();
                        },
                        child: const Text('View all'),
                      ),
                    ),
                    if (recent.isEmpty)
                      const EmptyRecords('No donations recorded yet.'),
                    for (final r in recent)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: blue.withValues(alpha: .08),
                          child: const Icon(
                            Icons.volunteer_activism_outlined,
                            size: 20,
                            color: ink,
                          ),
                        ),
                        title: Text(
                          recordText(recordMap(r['donor'])['fullName']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${shortDate(r['receivedAt'])} | ${friendlyStatus(r['status'])}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          moneyText(r['amount']),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: () => receipt(r),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          PanelColumns(
            firstFlex: 2,
            first: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PanelHeading('Fundraising records'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in const {
                        'donors': 'Donors',
                        'donations': 'Donations',
                        'campaigns': 'Campaigns',
                        'pledges': 'Pledges',
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: directory == entry.key,
                          onSelected: (_) {
                            directory = entry.key;
                            page = 1;
                            search = '';
                            reload();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: ValueKey(directory),
                    initialValue: search,
                    decoration: const InputDecoration(
                      hintText: 'Search records',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onFieldSubmitted: (v) {
                      search = v.trim();
                      page = 1;
                      reload();
                    },
                  ),
                  const SizedBox(height: 16),
                  directoryTable(recordList(records['items'])),
                  DirectoryPager(
                    meta: recordMap(records['meta']),
                    onPage: (p) {
                      page = p;
                      reload();
                    },
                  ),
                ],
              ),
            ),
            second: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PanelHeading('Quick actions'),
                      for (final action in [
                        ('donors', 'Add donor', Icons.person_add_alt),
                        (
                          'campaigns',
                          'Create campaign',
                          Icons.campaign_outlined,
                        ),
                        ('pledges', 'Add pledge', Icons.event_note_outlined),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: OutlinedButton.icon(
                            onPressed: () => create(action.$1),
                            icon: Icon(action.$3),
                            label: Text(action.$2),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PanelHeading(
                        'Campaign goals',
                        subtitle: 'Most recently created campaigns',
                      ),
                      if (campaigns.isEmpty)
                        const EmptyRecords('Create a campaign to begin.'),
                      for (final campaign in campaigns)
                        DataBar(
                          label: recordText(campaign['title']),
                          value: recordNumber(campaign['collectedAmount']),
                          maximum: recordNumber(campaign['goalAmount']),
                          color: gold,
                          displayValue:
                              '${recordText(campaign['progressPercent'], '0')}%',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget directoryTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const EmptyRecords('No matching records yet.');
    return switch (directory) {
      'donors' => RecordTable(
        minWidth: 600,
        columns: const [
          'Name',
          'Contact',
          'Total given (TZS)',
          'Last donation',
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(Text(recordText(r['fullName']))),
                DataCell(
                  Text(recordText(r['email'], recordText(r['phone'], '-'))),
                ),
                DataCell(Text(moneyText(r['totalGiven']))),
                DataCell(Text(shortDate(r['lastDonationAt']))),
              ],
            ),
        ],
      ),
      'campaigns' => RecordTable(
        minWidth: 600,
        columns: const [
          'Campaign',
          'Collected (TZS)',
          'Goal (TZS)',
          'Progress',
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(Text(recordText(r['title']))),
                DataCell(Text(moneyText(r['collectedAmount']))),
                DataCell(Text(moneyText(r['goalAmount']))),
                DataCell(Text('${r['progressPercent']}%')),
              ],
            ),
        ],
      ),
      'pledges' => RecordTable(
        minWidth: 650,
        columns: const [
          'Donor',
          'Campaign',
          'Due date',
          'Remaining (TZS)',
          'Action',
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(Text(recordText(recordMap(r['donor'])['fullName']))),
                DataCell(Text(recordText(recordMap(r['campaign'])['title']))),
                DataCell(Text(shortDate(r['dueOn']))),
                DataCell(Text(moneyText(r['outstandingAmount']))),
                DataCell(
                  TextButton(
                    onPressed: recordNumber(r['outstandingAmount']) > 0
                        ? () => receive(pledge: r)
                        : null,
                    child: const Text('Record payment'),
                  ),
                ),
              ],
            ),
        ],
      ),
      _ => RecordTable(
        minWidth: 680,
        columns: const ['Donor', 'Amount (TZS)', 'Date', 'Status', 'Actions'],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(Text(recordText(recordMap(r['donor'])['fullName']))),
                DataCell(Text(moneyText(r['amount']))),
                DataCell(Text(shortDate(r['receivedAt']))),
                DataCell(StatusPill('${r['status']}')),
                DataCell(
                  PopupMenuButton<String>(
                    tooltip: 'Donation actions',
                    onSelected: (v) =>
                        v == 'receipt' ? receipt(r) : voidEntry(r),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'receipt',
                        child: Text('View receipt'),
                      ),
                      if (r['status'] == 'RECEIVED')
                        const PopupMenuItem(
                          value: 'void',
                          child: Text('Void donation'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    };
  }
}

String monthName(dynamic month) {
  final date = DateTime.tryParse('$month-01');
  return date == null
      ? '-'
      : const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ][date.month - 1];
}

class AdminPanelGrid extends StatelessWidget {
  const AdminPanelGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= 1150
          ? 3
          : c.maxWidth >= 760
          ? 2
          : 1;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          for (final child in children)
            SizedBox(
              width: (c.maxWidth - (columns - 1) * 18) / columns,
              child: child,
            ),
        ],
      );
    },
  );
}

class _Receipt extends StatefulWidget {
  const _Receipt({required this.load, required this.id});
  final PageLoader load;
  final String id;
  @override
  State<_Receipt> createState() => _ReceiptState();
}

class _ReceiptState extends State<_Receipt> {
  late Future<dynamic> future = widget.load(
    '/api/fundraising/donations/${widget.id}/receipt',
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Donation receipt'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: PageResult(
          future: future,
          onRetry: () {
            setState(() {
              future = widget.load(
                '/api/fundraising/donations/${widget.id}/receipt',
              );
            });
          },
          builder: (data) {
            final r = recordMap(data);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  recordText(recordMap(r['organization'])['name']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(recordText(r['receiptNumber'])),
                const Divider(),
                Text(
                  'TZS ${moneyText(r['amount'])}',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                StatusPill('${r['status']}'),
                const SizedBox(height: 16),
                Text('Donor: ${recordText(recordMap(r['donor'])['fullName'])}'),
                Text(
                  'Campaign: ${recordText(recordMap(r['campaign'])['title'])}',
                ),
                Text('Received: ${shortDate(r['receivedAt'])}'),
                Text('Method: ${friendlyStatus(r['method'])}'),
                if (r['reference'] != null)
                  SelectableText('Reference: ${r['reference']}'),
                Text(
                  'Recorded by: ${recordText(recordMap(r['recordedBy'])['fullName'])}',
                ),
                if (r['voidReason'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Void reason: ${r['voidReason']}',
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
