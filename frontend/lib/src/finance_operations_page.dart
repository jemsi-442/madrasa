import 'dart:async';

import 'package:flutter/material.dart';

import 'accountant_components.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'finance_entry_form.dart';
import 'finance_presentation.dart';
import 'foundation_ui.dart';

class FinanceOperationsPage extends StatefulWidget {
  const FinanceOperationsPage({
    super.key,
    required this.page,
    required this.load,
    required this.submit,
    required this.update,
    this.refreshToken = 0,
  });
  final int page;
  final PageLoader load;
  final PageSubmitter submit, update;
  final int refreshToken;
  @override
  State<FinanceOperationsPage> createState() => _FinanceOperationsPageState();
}

class _FinanceOperationsPageState extends State<FinanceOperationsPage> {
  final search = TextEditingController();
  Timer? timer;
  String query = '', filter = '';
  DateTimeRange? dates;
  int page = 1;
  late Future<dynamic> result = fetch();
  bool get fees => widget.page == 4;
  bool get expenses => widget.page == 5;
  bool get inquiries => widget.page == 7;
  String get path => fees
      ? '/api/fee-structures'
      : expenses
      ? '/api/expenses'
      : '/api/public-inquiries';

  @override
  void didUpdateWidget(FinanceOperationsPage old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) result = fetch();
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<dynamic> fetch() => financeRequest(
    widget.load,
    Uri(
      path: path,
      queryParameters: {
        if (!inquiries) 'page': '$page',
        if (!inquiries) 'pageSize': '10',
        if (query.isNotEmpty) 'search': query,
        if (fees && filter.isNotEmpty) 'isActive': filter,
        if (inquiries) 'inquiryType': 'FINANCE',
        if (inquiries && filter.isNotEmpty) 'status': filter,
        if (expenses && dates != null) ...{
          'dateFrom': dates!.start.toIso8601String().substring(0, 10),
          'dateTo': dates!.end.toIso8601String().substring(0, 10),
        },
      },
    ).toString(),
  );

  void reload() => setState(() {
    result = fetch();
  });

  void searched(String value) {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        query = value.trim();
        page = 1;
        result = fetch();
      });
    });
  }

  Future<void> create() async {
    final outcome = await showFinanceEntry(
      context,
      expense: expenses,
      submit: widget.submit,
    );
    if (!mounted || outcome == null) return;
    timer?.cancel();
    search.clear();
    setState(() {
      query = '';
      filter = '';
      dates = null;
      page = 1;
      result = fetch();
    });
    if (outcome == FinanceEntryOutcome.saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            expenses ? 'Expense recorded.' : 'Fee structure created.',
          ),
        ),
      );
    }
  }

  Future<void> chooseDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: dates,
    );
    if (!mounted || range == null) return;
    timer?.cancel();
    setState(() {
      query = search.text.trim();
      dates = range;
      page = 1;
      result = fetch();
    });
  }

  Future<void> details(Map<String, dynamic> row) async {
    if (inquiries) {
      await showFinanceDetail(
        context,
        title: 'Finance inquiry',
        child: _InquiryDetail(
          row: row,
          update: widget.update,
          onChanged: reload,
        ),
      );
      return;
    }
    await showFinanceDetail(
      context,
      title: expenses ? 'Expense details' : 'Fee structure details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            recordText(row[expenses ? 'title' : 'name']),
            style: const TextStyle(
              fontSize: 23,
              fontFamily: 'NotoSerifDisplay',
              color: ink,
            ),
          ),
          const SizedBox(height: 12),
          FinanceFacts([
            (
              'Amount',
              financeMoney(
                row['amount'],
                currency: expenses ? row['currency'] as String? : 'TZS',
              ),
            ),
            (
              'Branch',
              recordText(recordMap(row['branch'])['name'], 'School-wide'),
            ),
            if (fees) ...[
              (
                'Class',
                recordText(
                  recordMap(row['class'])['name'],
                  'No specific class',
                ),
              ),
              ('Billing cycle', friendlyStatus(row['billingCycle'])),
              ('Status', row['isActive'] == true ? 'Active' : 'Inactive'),
            ] else ...[
              ('Expense date', financeDate(row['expenseDate'])),
              (
                'Recorded by',
                recordText(recordMap(row['recordedBy'])['fullName']),
              ),
              (
                'Description',
                recordText(row['description'], 'No description recorded'),
              ),
            ],
            ('Created', financeDate(row['createdAt'])),
          ]),
          const SizedBox(height: 14),
          const FinanceNotice(
            'Editing and deletion are not available for this record. Contact the school office if a correction is needed.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinanceSectionHeading(
              fees
                  ? 'Fee structures'
                  : expenses
                  ? 'Expense register'
                  : 'Finance inbox',
              eyebrow: fees
                  ? 'Billing setup'
                  : expenses
                  ? 'School expenditure'
                  : 'Office follow-up',
              icon: fees
                  ? Icons.price_change_outlined
                  : expenses
                  ? Icons.account_balance_wallet_outlined
                  : Icons.mark_email_unread_outlined,
              accent: fees
                  ? gold
                  : expenses
                  ? forest
                  : blue,
              action: inquiries
                  ? null
                  : FilledButton.icon(
                      onPressed: create,
                      icon: Icon(
                        expenses ? Icons.add_card_outlined : Icons.add,
                      ),
                      label: Text(
                        expenses ? 'Record expense' : 'Add fee structure',
                      ),
                    ),
              subtitle: fees
                  ? 'Set billing rates. Creating a fee does not issue invoices.'
                  : expenses
                  ? 'Record school costs and keep the supporting details together.'
                  : 'Follow up finance inquiries without accessing other office messages.',
            ),
            LayoutBuilder(
              builder: (context, box) => Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: box.maxWidth < 700
                        ? box.maxWidth
                        : box.maxWidth - 252,
                    child: TextField(
                      controller: search,
                      maxLength: inquiries ? 150 : 100,
                      onChanged: searched,
                      decoration: const InputDecoration(
                        labelText: 'Search records',
                        counterText: '',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  if (!expenses)
                    SizedBox(
                      width: box.maxWidth < 700 ? box.maxWidth : 240,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('operations-filter-$filter'),
                        initialValue: filter,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('All statuses'),
                          ),
                          for (final (value, label)
                              in fees
                                  ? [('true', 'Active'), ('false', 'Inactive')]
                                  : [
                                      ('NEW', 'New'),
                                      ('CONTACTED', 'Contacted'),
                                      ('CLOSED', 'Closed'),
                                    ])
                            DropdownMenuItem(value: value, child: Text(label)),
                        ],
                        onChanged: (value) {
                          timer?.cancel();
                          setState(() {
                            query = search.text.trim();
                            filter = value ?? '';
                            page = 1;
                            result = fetch();
                          });
                        },
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: chooseDates,
                      icon: const Icon(Icons.date_range_outlined, size: 18),
                      label: const Text('Choose date range'),
                    ),
                  if (dates != null)
                    Text(
                      '${financeDate(dates!.start)} - ${financeDate(dates!.end)}',
                      style: const TextStyle(color: muted),
                    ),
                  if (query.isNotEmpty || filter.isNotEmpty || dates != null)
                    TextButton.icon(
                      onPressed: () {
                        timer?.cancel();
                        search.clear();
                        setState(() {
                          query = '';
                          filter = '';
                          dates = null;
                          page = 1;
                          result = fetch();
                        });
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                      label: const Text('Clear filters'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            PageResult(
              future: result,
              onRetry: reload,
              builder: (data) {
                final map = recordMap(data),
                    rows = recordList(
                      inquiries ? data : recordMap(data)['items'],
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FinanceFilterSummary(
                      count: inquiries
                          ? '${rows.length} matching inquiries'
                          : '${recordText(recordMap(map['meta'])['totalItems'], 'Unknown')} matching records',
                      filters: [
                        if (query.isNotEmpty) 'Search: $query',
                        if (filter.isNotEmpty)
                          'Status: ${fees ? (filter == 'true' ? 'Active' : 'Inactive') : friendlyStatus(filter)}',
                        if (dates != null)
                          'Dates: ${financeDate(dates!.start)} - ${financeDate(dates!.end)}',
                      ],
                    ),
                    if (rows.isEmpty)
                      const FinanceEmptyState('No records match this view.')
                    else
                      LayoutBuilder(
                        builder: (context, box) {
                          final wide =
                              box.maxWidth >= 840 &&
                              MediaQuery.textScalerOf(context).scale(14) <= 20;
                          if (wide) {
                            return RecordTable(
                              minWidth: 840,
                              columns: inquiries
                                  ? const ['Subject', 'From', 'Status', '']
                                  : fees
                                  ? const [
                                      'Fee structure',
                                      'Amount (TZS)',
                                      'Billing / status',
                                      '',
                                    ]
                                  : const [
                                      'Expense',
                                      'Amount',
                                      'Date / recorder',
                                      '',
                                    ],
                              rows: [
                                for (final row in rows)
                                  DataRow(
                                    cells: [
                                      DataCell(
                                        SizedBox(
                                          width: 240,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                recordText(
                                                  row[inquiries
                                                      ? 'subject'
                                                      : fees
                                                      ? 'name'
                                                      : 'title'],
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (!inquiries) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  [
                                                    recordText(
                                                      recordMap(
                                                        row['branch'],
                                                      )['name'],
                                                      row.containsKey('branch')
                                                          ? 'School-wide'
                                                          : 'Scope not supplied',
                                                    ),
                                                    if (fees &&
                                                        recordMap(
                                                              row['class'],
                                                            )['name'] !=
                                                            null)
                                                      recordText(
                                                        recordMap(
                                                          row['class'],
                                                        )['name'],
                                                      ),
                                                  ].join(' / '),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: muted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          inquiries
                                              ? recordText(row['fullName'])
                                              : financeMoney(
                                                  row['amount'],
                                                  currency: fees
                                                      ? null
                                                      : row['currency']
                                                            as String?,
                                                ),
                                        ),
                                      ),
                                      DataCell(
                                        inquiries
                                            ? FinanceStatus(row['status'])
                                            : Text(
                                                fees
                                                    ? '${friendlyStatus(row['billingCycle'])}\n${row['isActive'] == true ? 'Active' : 'Inactive'}'
                                                    : '${financeDate(row['expenseDate'])}\n${recordText(recordMap(row['recordedBy'])['fullName'])}',
                                              ),
                                      ),
                                      DataCell(
                                        OutlinedButton.icon(
                                          onPressed: () => details(row),
                                          icon: const Icon(
                                            Icons.chevron_right,
                                            size: 16,
                                          ),
                                          label: const Text('Details'),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              for (final row in rows)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: FinanceTile(
                                    title: recordText(
                                      row[inquiries
                                          ? 'subject'
                                          : fees
                                          ? 'name'
                                          : 'title'],
                                    ),
                                    subtitle: inquiries
                                        ? '${recordText(row['fullName'])}\n${financeDate(row['createdAt'])}'
                                        : '${financeMoney(row['amount'], currency: fees ? 'TZS' : row['currency'] as String?)}\n${fees ? friendlyStatus(row['billingCycle']) : financeDate(row['expenseDate'])}',
                                    icon: inquiries
                                        ? Icons.mark_email_unread_outlined
                                        : fees
                                        ? Icons.price_change_outlined
                                        : Icons.account_balance_wallet_outlined,
                                    accent: inquiries
                                        ? blue
                                        : fees
                                        ? gold
                                        : forest,
                                    onTap: () => details(row),
                                    trailing: inquiries
                                        ? FinanceStatus(row['status'])
                                        : fees
                                        ? FinanceStatus(
                                            row['isActive'] == true
                                                ? 'ACTIVE'
                                                : 'INACTIVE',
                                          )
                                        : null,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    if (!inquiries)
                      DirectoryPager(
                        meta: recordMap(map['meta']),
                        onPage: (next) => setState(() {
                          page = next;
                          result = fetch();
                        }),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FinanceNotice(
        inquiries
            ? 'Changing an inquiry status records office follow-up only. It does not send an email, message or payment reminder.'
            : expenses
            ? 'Expense dates are used for financial reporting. Creating an expense records a cost; it does not make a bank or mobile-money transfer.'
            : 'Rates are used for TZS school invoices. Existing class-specific rates remain visible; this form creates rates in your account scope.',
      ),
    ],
  );
}

class _InquiryDetail extends StatefulWidget {
  const _InquiryDetail({
    required this.row,
    required this.update,
    required this.onChanged,
  });
  final Map<String, dynamic> row;
  final PageSubmitter update;
  final VoidCallback onChanged;
  @override
  State<_InquiryDetail> createState() => _InquiryDetailState();
}

class _InquiryDetailState extends State<_InquiryDetail> {
  late String status = recordText(widget.row['status'], 'NEW');
  late String selected = status;
  bool busy = false;
  String? error;

  Future<void> save() async {
    if (busy || selected == status) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = recordMap(
        await widget.update(
          '/api/public-inquiries/${Uri.encodeComponent('${widget.row['id']}')}/status',
          {'status': selected},
        ),
      );
      if (response['status'] != selected) {
        throw StateError('Unconfirmed update');
      }
      if (!mounted) return;
      widget.onChanged();
      setState(() => status = selected);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = e is ApiException && e.statusCode == 403
            ? 'You cannot update this inquiry.'
            : 'The status change could not be confirmed. Retry or close and refresh the inbox.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          recordText(widget.row['subject']),
          style: const TextStyle(
            fontSize: 23,
            color: ink,
            fontFamily: 'NotoSerifDisplay',
          ),
        ),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: FinanceStatus(status)),
        FinanceFacts([
          ('From', recordText(widget.row['fullName'])),
          ('Phone', recordText(widget.row['phone'])),
          ('Email', recordText(widget.row['email'], 'Not supplied')),
          ('Preferred contact', friendlyStatus(widget.row['preferredContact'])),
          ('Received', financeDate(widget.row['createdAt'])),
          ('Message', recordText(widget.row['message'])),
        ]),
        const Divider(),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Follow-up status'),
          items: [
            for (final s in ['NEW', 'CONTACTED', 'CLOSED'])
              DropdownMenuItem(value: s, child: Text(friendlyStatus(s))),
          ],
          onChanged: busy ? null : (v) => setState(() => selected = v!),
        ),
        const SizedBox(height: 16),
        const FinanceNotice(
          'Mark Contacted only after contacting the sender separately. This button does not send a message.',
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Color(0xFFAF3844))),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy || selected == status ? null : save,
          child: Text(busy ? 'Saving...' : 'Save status'),
        ),
      ],
    ),
  );
}
