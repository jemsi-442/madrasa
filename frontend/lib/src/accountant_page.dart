import 'dart:async';

import 'package:flutter/material.dart';

import 'accountant_components.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';

class FinanceDestination {
  const FinanceDestination(
    this.page, {
    this.status,
    this.invoiceId,
    this.invoiceNo,
  });
  final int page;
  final String? status;
  final String? invoiceId;
  final String? invoiceNo;

  String get key => '$page-$status-$invoiceId';
}

class AccountantPage extends StatefulWidget {
  const AccountantPage({
    super.key,
    required this.load,
    required this.destination,
    required this.onOpen,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final FinanceDestination destination;
  final ValueChanged<FinanceDestination> onOpen;
  final int refreshToken;

  @override
  State<AccountantPage> createState() => _AccountantPageState();
}

class _AccountantPageState extends State<AccountantPage> {
  final search = TextEditingController();
  Timer? debounce;
  late Future<dynamic> result;
  String? status;
  String? channel;
  String? invoiceId;
  String query = '';
  int page = 1;
  int get section => widget.destination.page;

  @override
  void initState() {
    super.initState();
    status = widget.destination.status;
    invoiceId = widget.destination.invoiceId;
    result = fetch();
  }

  @override
  void didUpdateWidget(AccountantPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) result = fetch();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<dynamic> fetch() {
    if (section == 0) {
      return financeRequest(widget.load, '/api/reports/finance/home');
    }
    final path = switch (section) {
      1 => '/api/invoices',
      2 => '/api/payments',
      _ => '/api/courses/access-requests',
    };
    final params = <String, String>{
      if (section != 3) 'page': '$page',
      if (section != 3) 'pageSize': '10',
      if (status != null) 'status': status!,
      if (section != 3 && query.isNotEmpty) 'search': query,
      if (section == 2 && channel != null) 'channel': channel!,
      if (section == 2 && invoiceId != null) 'invoiceId': invoiceId!,
    };
    return financeRequest(
      widget.load,
      Uri(
        path: path,
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
  }

  void reload() => setState(() {
    result = fetch();
  });

  void searchChanged(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        query = value.trim();
        page = 1;
        if (section != 3) result = fetch();
      });
    });
  }

  void clearFilters() {
    debounce?.cancel();
    search.clear();
    setState(() {
      query = '';
      status = null;
      channel = null;
      page = 1;
      result = fetch();
    });
  }

  void openPayments(Map<String, dynamic> invoice) {
    widget.onOpen(
      FinanceDestination(
        2,
        invoiceId: invoice['id'] as String?,
        invoiceNo: invoice['invoiceNo'] as String?,
      ),
    );
  }

  Future<void> invoiceDetails(
    Map<String, dynamic> invoice,
  ) => showFinanceDetail(
    context,
    title: 'Invoice details',
    child: Builder(
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecordHeading(recordText(invoice['invoiceNo']), invoice['status']),
          FinanceFacts([
            ('Student', recordText(recordMap(invoice['student'])['fullName'])),
            (
              'Admission number',
              recordText(recordMap(invoice['student'])['admissionNo']),
            ),
            (
              'Fee',
              recordText(
                recordMap(invoice['feeStructure'])['name'],
                'No fee structure linked',
              ),
            ),
            ('Currency', recordText(invoice['currency'], 'Not specified')),
            (
              'Amount due',
              financeMoney(
                invoice['amountDue'],
                currency: invoice['currency'] as String?,
              ),
            ),
            (
              'Amount paid',
              financeMoney(
                invoice['amountPaid'],
                currency: invoice['currency'] as String?,
              ),
            ),
            ('Balance', financeBalance(invoice)),
            ('Due date', financeDate(invoice['dueDate'])),
            ('Issued', financeDate(invoice['issuedAt'])),
          ]),
          const SizedBox(height: 12),
          const FinanceNotice(
            'Details reflect the loaded invoice list. Refresh the list for the latest balance.',
          ),
          const SizedBox(height: 18),
          if (invoice['id'] != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                openPayments(invoice);
              },
              icon: const Icon(Icons.payments_outlined),
              label: const Text('View linked payments'),
            ),
        ],
      ),
    ),
  );

  Future<void> paymentDetails(Map<String, dynamic> payment) =>
      showFinanceDetail(
        context,
        title: 'Payment details',
        child: _PaymentDetail(
          load: widget.load,
          id: recordText(payment['id'], ''),
        ),
      );

  Future<void> requestDetails(Map<String, dynamic> request) {
    final invoice = recordMap(request['invoice']);
    final course = recordMap(request['course']);
    final learner = recordMap(request['learnerUser']);
    final student = recordMap(request['student']);
    return showFinanceDetail(
      context,
      title: 'Course access details',
      child: Builder(
        builder: (sheetContext) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RecordHeading(recordText(course['title']), request['status']),
            FinanceFacts([
              (
                'Learner',
                recordText(student['fullName'] ?? learner['fullName']),
              ),
              (
                'Learner reference',
                recordText(student['admissionNo'] ?? learner['email']),
              ),
              ('Requested', financeDate(request['createdAt'])),
              (
                'Request message',
                recordText(request['requestMessage'], 'No message provided'),
              ),
              (
                'Office note',
                recordText(request['officeNote'], 'No office note recorded'),
              ),
              (
                'Reviewed by',
                recordText(
                  recordMap(request['reviewedBy'])['fullName'],
                  'Not reviewed',
                ),
              ),
              if (invoice.isNotEmpty) ...[
                ('Latest invoice', recordText(invoice['invoiceNo'])),
                ('Invoice status', friendlyStatus(invoice['status'])),
                ('Balance', financeBalance(invoice)),
                ('Due date', financeDate(invoice['dueDate'])),
              ],
            ]),
            const SizedBox(height: 12),
            FinanceNotice(
              invoice.isEmpty
                  ? 'No invoice is linked to this request. A request alone does not confirm payment or grant course access.'
                  : 'Check the linked payment record before following up. This view does not change course access.',
            ),
            if (invoice['id'] != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  openPayments(invoice);
                },
                icon: const Icon(Icons.payments_outlined),
                label: const Text('View linked payments'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (section == 0) {
      return PageResult(
        future: result,
        onRetry: reload,
        builder: (data) =>
            AccountantOverview(report: recordMap(data), onOpen: widget.onOpen),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (section == 2 && invoiceId != null) ...[
          SurfacePanel(
            color: const Color(0xFFFFF8E8),
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Payments for ${widget.destination.invoiceNo ?? invoiceId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    invoiceId = null;
                    page = 1;
                    result = fetch();
                  }),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('All invoices'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHeading(
                switch (section) {
                  1 => 'Invoice register',
                  2 => 'Payment activity',
                  _ => 'Course payment follow-up',
                },
                subtitle: switch (section) {
                  1 =>
                    'Find an invoice, check its balance and follow the payment trail.',
                  2 => 'Only completed payments are confirmed collections.',
                  _ =>
                    'Connect each access request to its learner, invoice and payment.',
                },
              ),
              filters(),
              const SizedBox(height: 22),
              PageResult(future: result, onRetry: reload, builder: records),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FinanceNotice(
          section == 1
              ? 'An invoice is a request for payment, not a receipt. Open a record to see linked payments.'
              : section == 2
              ? 'Pending, failed, expired and voided payments are not confirmed collections. Receipts are available only for completed payments.'
              : 'This workspace is for payment follow-up. A new or reviewed request does not automatically grant access.',
          icon: Icons.verified_user_outlined,
        ),
      ],
    );
  }

  Widget filters() {
    final statuses = switch (section) {
      1 => ['PENDING', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'CANCELLED'],
      2 => ['PENDING', 'COMPLETED', 'FAILED', 'EXPIRED', 'VOIDED'],
      _ => ['NEW', 'REVIEWING', 'APPROVED', 'REJECTED'],
    };
    return LayoutBuilder(
      builder: (context, box) {
        final narrow =
            box.maxWidth < 720 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: narrow
                  ? box.maxWidth
                  : box.maxWidth - (section == 2 ? 400 : 200),
              child: TextField(
                controller: search,
                maxLength: 100,
                onChanged: searchChanged,
                decoration: InputDecoration(
                  labelText: section == 3
                      ? 'Search learner or course'
                      : 'Search name or reference',
                  counterText: '',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: narrow ? box.maxWidth : 188,
              child: DropdownButtonFormField<String>(
                key: ValueKey('finance-status-$status'),
                initialValue: status ?? '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All statuses'),
                  ),
                  for (final s in statuses)
                    DropdownMenuItem(value: s, child: Text(friendlyStatus(s))),
                ],
                onChanged: (value) {
                  debounce?.cancel();
                  setState(() {
                    query = search.text.trim();
                    status = value == '' ? null : value;
                    page = 1;
                    result = fetch();
                  });
                },
              ),
            ),
            if (section == 2)
              SizedBox(
                width: narrow ? box.maxWidth : 188,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('finance-channel-$channel'),
                  initialValue: channel ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Channel',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All channels'),
                    ),
                    for (final (id, label) in [
                      ('mpesa', 'M-Pesa'),
                      ('airtel_money', 'Airtel Money'),
                      ('tigo_pesa', 'Tigo Pesa'),
                    ])
                      DropdownMenuItem(value: id, child: Text(label)),
                  ],
                  onChanged: (value) {
                    debounce?.cancel();
                    setState(() {
                      query = search.text.trim();
                      channel = value == '' ? null : value;
                      page = 1;
                      result = fetch();
                    });
                  },
                ),
              ),
            if (query.isNotEmpty || status != null || channel != null)
              TextButton.icon(
                onPressed: clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Clear filters'),
              ),
          ],
        );
      },
    );
  }

  Widget records(dynamic data) {
    final response = recordMap(data);
    final all = recordList(section == 3 ? data : response['items']);
    final items = section == 3 && query.isNotEmpty
        ? all.where((r) {
            final student = recordMap(r['student']);
            final learner = recordMap(r['learnerUser']);
            return [
              recordMap(r['course'])['title'],
              student['fullName'],
              student['admissionNo'],
              learner['fullName'],
              learner['email'],
            ].join(' ').toLowerCase().contains(query.toLowerCase());
          }).toList()
        : all;
    final meta = recordMap(response['meta']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          section == 3
              ? '${items.length} matching requests'
              : '${recordText(meta['totalItems'], 'Unknown')} matching records',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const EmptyRecords(
            'No records match this view. Try a different search or status.',
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final wide =
                  box.maxWidth >= 840 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 20;
              return Column(
                children: [
                  if (wide)
                    Container(
                      padding: const EdgeInsets.all(14),
                      color: const Color(0xFFF5F6F8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              section == 3
                                  ? 'COURSE / LEARNER'
                                  : 'REFERENCE / STUDENT',
                              style: _tableLabel,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              section == 1
                                  ? 'AMOUNT / BALANCE'
                                  : section == 2
                                  ? 'AMOUNT / CHANNEL'
                                  : 'INVOICE',
                              style: _tableLabel,
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text('STATUS / DATE', style: _tableLabel),
                          ),
                          const SizedBox(width: 84),
                        ],
                      ),
                    ),
                  for (final item in items) recordRow(item, wide),
                ],
              );
            },
          ),
        if (section != 3) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Page $page of ${recordText(meta['totalPages'], '1')}',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: page > 1
                        ? () => setState(() {
                            page--;
                            result = fetch();
                          })
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Previous'),
                  ),
                  OutlinedButton.icon(
                    onPressed: page < recordNumber(meta['totalPages'])
                        ? () => setState(() {
                            page++;
                            result = fetch();
                          })
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 18),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget recordRow(Map<String, dynamic> r, bool wide) {
    final invoice = section == 2 || section == 3 ? recordMap(r['invoice']) : r;
    final student = recordMap(section == 2 ? invoice['student'] : r['student']);
    final learner = recordMap(r['learnerUser']);
    final title = recordText(
      section == 1
          ? r['invoiceNo']
          : section == 2
          ? r['reference']
          : recordMap(r['course'])['title'],
    );
    final name = recordText(
      student['fullName'] ??
          learner['fullName'] ??
          recordMap(invoice['course'])['title'],
      'No student linked',
    );
    final amount = section == 3
        ? recordText(invoice['invoiceNo'], 'No invoice linked')
        : financeMoney(
            r[section == 1 ? 'amountDue' : 'amount'],
            currency: r['currency'] as String?,
          );
    final secondary = section == 1
        ? 'Balance: ${financeBalance(r)}'
        : section == 2
        ? '${friendlyStatus(r['channel'])} / ${recordText(invoice['invoiceNo'])}'
        : invoice.isEmpty
        ? 'Awaiting invoice'
        : friendlyStatus(invoice['status']);
    final dateLabel = section == 1 ? 'Due' : 'Created';
    final date = financeDate(r[section == 1 ? 'dueDate' : 'createdAt']);
    void open() {
      if (section == 1) {
        invoiceDetails(r);
      } else if (section == 2) {
        paymentDetails(r);
      } else {
        requestDetails(r);
      }
    }

    Widget pair(String primary, String secondary) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: ink,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          secondary,
          style: const TextStyle(fontSize: 12, color: muted, height: 1.5),
        ),
      ],
    );
    return Container(
      margin: EdgeInsets.only(top: wide ? 0 : 12),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        border: wide
            ? const Border(bottom: BorderSide(color: line))
            : Border.all(color: line),
        borderRadius: wide ? null : BorderRadius.circular(12),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: pair(title, name),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: pair(amount, secondary),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FinanceStatus(r['status']),
                      const SizedBox(height: 6),
                      Text(
                        '$dateLabel $date',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: TextButton(
                    onPressed: open,
                    child: const Text('Details'),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                pair(title, name),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FinanceStatus(r['status']),
                ),
                const SizedBox(height: 14),
                pair(amount, secondary),
                const SizedBox(height: 12),
                Text(
                  '$dateLabel $date',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: open,
                  icon: const Icon(Icons.arrow_forward, size: 17),
                  label: const Text('View details'),
                ),
              ],
            ),
    );
  }
}

const _tableLabel = TextStyle(
  fontSize: 10,
  letterSpacing: 0.7,
  fontWeight: FontWeight.w700,
  color: muted,
);

class AccountantOverview extends StatelessWidget {
  const AccountantOverview({
    super.key,
    required this.report,
    required this.onOpen,
  });
  final Map<String, dynamic> report;
  final ValueChanged<FinanceDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    final finance = recordMap(report['finance']);
    final invoices = recordMap(finance['invoices']);
    final collections = recordMap(finance['collections']);
    final expenses = recordMap(finance['expenses']);
    if (finance.isEmpty) {
      return const SurfacePanel(
        child: EmptyRecords('The finance summary is not available yet.'),
      );
    }
    final compact = MediaQuery.sizeOf(context).width < 700;
    final workflow = PanelColumns(
      firstFlex: 3,
      first: SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PanelHeading(
              'Your next actions',
              subtitle: 'Move straight to the records that need a closer look.',
            ),
            FinanceTile(
              title: 'Follow up overdue invoices',
              subtitle:
                  '${recordText(invoices['overdue'], "Unknown")} invoices marked overdue',
              icon: Icons.schedule_outlined,
              accent: const Color(0xFFAF3844),
              onTap: () =>
                  onOpen(const FinanceDestination(1, status: 'OVERDUE')),
            ),
            const SizedBox(height: 12),
            FinanceTile(
              title: 'Check pending payments',
              subtitle: 'Review payments still awaiting confirmation',
              icon: Icons.payments_outlined,
              accent: gold,
              onTap: () =>
                  onOpen(const FinanceDestination(2, status: 'PENDING')),
            ),
            const SizedBox(height: 12),
            FinanceTile(
              title: 'Follow up course requests',
              subtitle: 'Find new requests and their linked invoices',
              icon: Icons.school_outlined,
              accent: blue,
              onTap: () => onOpen(const FinanceDestination(3, status: 'NEW')),
            ),
          ],
        ),
      ),
      second: SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PanelHeading(
              'A clear payment trail',
              subtitle: 'One record at a time, from issue to receipt.',
            ),
            for (final (step, title, description) in [
              (
                '01',
                'Find the invoice',
                'Check the learner, due date and outstanding balance.',
              ),
              (
                '02',
                'Verify the payment',
                'Open linked payments and read the latest recorded status.',
              ),
              (
                '03',
                'View the receipt',
                'Completed payments have a receipt available inside the app.',
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step,
                      style: const TextStyle(
                        fontFamily: 'NotoSerifDisplay',
                        fontSize: 25,
                        color: gold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const FinanceNotice(
              'View-only financial records. No payment is initiated and no balance is changed from these pages.',
              icon: Icons.lock_outline,
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(compact ? 20 : 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [ink, Color(0xFF174A57)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THE FINANCE DESK',
                    style: TextStyle(
                      color: Color(0xFFE1C889),
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    compact
                        ? 'School fees, clearly.'
                        : 'Every record.\nA clearer picture.',
                    style: TextStyle(
                      fontFamily: 'NotoSerifDisplay',
                      fontSize: compact ? 26 : 32,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Follow school fees from invoice to confirmed payment.',
                      style: TextStyle(
                        color: Color(0xFFD6E3E6),
                        height: 1.6,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => onOpen(const FinanceDestination(1)),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('Open invoice register'),
                  ),
                ],
              );
              final balance = Container(
                padding: EdgeInsets.all(compact ? 16 : 22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!compact) ...[
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Color(0xFFE1C889),
                        size: 26,
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'OUTSTANDING BALANCE',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: Color(0xFFD6E3E6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      financeMoney(invoices['outstandingBalance']),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${recordText(invoices['total'], "Unknown")} invoices in the report',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFD6E3E6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Amount as reported; currency unspecified',
                      style: TextStyle(fontSize: 11, color: Color(0xFFD6E3E6)),
                    ),
                  ],
                ),
              );
              if (box.maxWidth < 760 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 24), balance],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: title),
                  const SizedBox(width: 26),
                  Expanded(flex: 2, child: balance),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        if (compact) ...[workflow.first, const SizedBox(height: 20)],
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 1000
                ? 4
                : box.maxWidth >= 600
                ? 2
                : 1;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final (title, amount, note, icon, color) in [
                  (
                    'Invoiced',
                    invoices['amountDue'],
                    'Total issued amount',
                    Icons.receipt_long_outlined,
                    blue,
                  ),
                  (
                    'Collected',
                    collections['collectedAmount'],
                    '${recordText(collections['completedPayments'], "Unknown")} completed payments',
                    Icons.task_alt_outlined,
                    forest,
                  ),
                  (
                    'Expenses',
                    expenses['amount'],
                    '${recordText(expenses['total'], "Unknown")} expense records',
                    Icons.account_balance_outlined,
                    gold,
                  ),
                  (
                    'Net cash flow',
                    finance['netCashFlow'],
                    'Reported collections less expenses',
                    Icons.swap_vert_rounded,
                    ink,
                  ),
                ])
                  SizedBox(
                    width: (box.maxWidth - (columns - 1) * 16) / columns,
                    child: SurfacePanel(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: color, size: 24),
                          const SizedBox(height: 14),
                          Text(
                            title,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            financeMoney(amount),
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            note,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const FinanceNotice(
          'Summary amounts come directly from the finance report, which does not specify currency. Check each record\'s currency before comparing totals.',
        ),
        const SizedBox(height: 24),
        if (compact) workflow.second else workflow,
      ],
    );
  }
}

class _RecordHeading extends StatelessWidget {
  const _RecordHeading(this.title, this.status);
  final String title;
  final dynamic status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          title,
          style: const TextStyle(
            fontFamily: 'NotoSerifDisplay',
            fontSize: 24,
            color: ink,
          ),
        ),
        const SizedBox(height: 12),
        FinanceStatus(status),
      ],
    ),
  );
}

class _PaymentDetail extends StatefulWidget {
  const _PaymentDetail({required this.load, required this.id});
  final PageLoader load;
  final String id;
  @override
  State<_PaymentDetail> createState() => _PaymentDetailState();
}

class _PaymentDetailState extends State<_PaymentDetail> {
  late Future<dynamic> result = fetch();
  bool receipt = false;
  Future<dynamic> fetch() => financeRequest(
    widget.load,
    '/api/payments/${Uri.encodeComponent(widget.id)}${receipt ? '/receipt' : ''}',
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (receipt)
        TextButton.icon(
          onPressed: () => setState(() {
            receipt = false;
            result = fetch();
          }),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to payment'),
        ),
      PageResult(
        future: result,
        onRetry: () => setState(() {
          result = fetch();
        }),
        builder: (data) {
          final response = recordMap(data);
          final payment = receipt ? recordMap(response['payment']) : response;
          if (payment.isEmpty) {
            return const EmptyRecords('Payment details are not available.');
          }
          final invoice = recordMap(response['invoice']);
          final student = recordMap(
            receipt ? response['student'] : invoice['student'],
          );
          if (receipt && payment['status'] != 'COMPLETED') {
            return const FinanceNotice(
              'A receipt is not available for an unconfirmed payment.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RecordHeading(
                receipt
                    ? recordText(response['receiptNo'])
                    : recordText(payment['reference']),
                payment['status'],
              ),
              const SizedBox(height: 14),
              Text(
                receipt ? 'Payment receipt' : 'Payment amount',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 5),
              SelectableText(
                financeMoney(
                  payment['amount'],
                  currency: payment['currency'] as String?,
                ),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 14),
              FinanceFacts([
                if (receipt)
                  (
                    'School',
                    recordText(recordMap(response['organization'])['name']),
                  ),
                if (receipt)
                  ('Branch', recordText(recordMap(response['branch'])['name'])),
                (
                  'Student',
                  recordText(student['fullName'], 'No student linked'),
                ),
                if (recordMap(invoice['course']).isNotEmpty)
                  ('Course', recordText(recordMap(invoice['course'])['title'])),
                ('Invoice', recordText(invoice['invoiceNo'])),
                ('Channel', friendlyStatus(payment['channel'])),
                ('Reference', recordText(payment['reference'])),
                (
                  'Provider transaction',
                  recordText(payment['providerTxnRef'], 'Not recorded'),
                ),
                ('Created', financeDate(payment['createdAt'])),
                ('Paid on', financeDate(payment['paidAt'])),
                if (receipt)
                  (
                    'Invoice balance',
                    financeMoney(
                      invoice['balanceRemaining'],
                      currency: payment['currency'] as String?,
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              if (!receipt && payment['status'] == 'COMPLETED')
                FilledButton.icon(
                  onPressed: () => setState(() {
                    receipt = true;
                    result = fetch();
                  }),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('View receipt'),
                )
              else
                FinanceNotice(
                  receipt
                      ? 'Receipt retrieved from the school payment record. Keep the reference when contacting the office.'
                      : 'This payment is not confirmed. No receipt can be issued yet.',
                ),
            ],
          );
        },
      ),
    ],
  );
}
