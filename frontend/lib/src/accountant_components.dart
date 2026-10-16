import 'package:flutter/material.dart';
import 'status_badge.dart';
import 'shared_feedback.dart';

import 'dashboard_components.dart';
import 'foundation_ui.dart';

Future<dynamic> financeRequest(PageLoader load, String path) {
  final request = Future<dynamic>.sync(() => load(path));
  // A fast failure can precede the next frame. Keep it handled until the UI
  // subscribes; FutureBuilder still receives the original result or error.
  request.ignore();
  return request;
}

/// Fixed-point formatting keeps decimal API amounts out of floating-point math.
BigInt? financeMinorUnits(dynamic value) {
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch('$value');
  if (match == null) return null;
  final units =
      BigInt.parse(match[2]!) * BigInt.from(100) +
      BigInt.parse((match[3] ?? '').padRight(2, '0'));
  return match[1] == '-' ? -units : units;
}

String financeMoney(dynamic value, {String? currency}) {
  final units = financeMinorUnits(value);
  if (units == null) return 'Not available';
  final digits = (units.abs() ~/ BigInt.from(100)).toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  final cents = (units.abs() % BigInt.from(100)).toString().padLeft(2, '0');
  final prefix = currency == null || currency.isEmpty ? '' : '$currency ';
  return '$prefix${units.isNegative ? '-' : ''}$grouped.$cents';
}

String financeBalance(Map<String, dynamic> invoice) {
  final due = financeMinorUnits(invoice['amountDue']);
  final paid = financeMinorUnits(invoice['amountPaid']);
  if (due == null || paid == null) return 'Not available';
  final balance = due - paid;
  final raw =
      '${balance.isNegative ? '-' : ''}'
      '${balance.abs() ~/ BigInt.from(100)}.'
      '${(balance.abs() % BigInt.from(100)).toString().padLeft(2, '0')}';
  return financeMoney(raw, currency: invoice['currency'] as String?);
}

String financeDate(dynamic value) {
  final date = DateTime.tryParse('$value');
  if (date == null) return 'Not recorded';
  const months = [
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
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class FinanceStatus extends StatelessWidget {
  const FinanceStatus(this.status, {super.key});
  final dynamic status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'PAID' || 'COMPLETED' || 'APPROVED' || 'ACTIVE' || 'CLOSED' => forest,
      'OVERDUE' || 'FAILED' || 'REJECTED' => const Color(0xFFAF3844),
      'PENDING' || 'NEW' => const Color(0xFF89651B),
      'PARTIALLY_PAID' || 'REVIEWING' || 'CONTACTED' => blue,
      _ => muted,
    };
    return AfaqStatusBadge(label: friendlyStatus(status), color: color);
  }
}

class FinanceNotice extends StatelessWidget {
  const FinanceNotice(this.text, {super.key, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AfaqNotice(text, icon: icon);
}

class FinanceTile extends StatelessWidget {
  const FinanceTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent = gold,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => AfaqActionTile(
    title: title,
    subtitle: subtitle,
    icon: icon,
    onTap: onTap,
    accent: accent,
    trailing: trailing,
  );
}

class FinanceFacts extends StatelessWidget {
  const FinanceFacts(this.facts, {super.key});
  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (label, value) in facts)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: LayoutBuilder(
            builder: (context, box) {
              final labelWidget = Text(
                label,
                style: const TextStyle(color: muted, fontSize: 12),
              );
              final valueWidget = SelectableText(
                value,
                style: const TextStyle(
                  color: ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              );
              if (box.maxWidth < 400 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelWidget,
                    const SizedBox(height: 4),
                    valueWidget,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: labelWidget),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: valueWidget),
                ],
              );
            },
          ),
        ),
    ],
  );
}

Future<void> showFinanceDetail(
  BuildContext context, {
  required String title,
  required Widget child,
}) async {
  FocusScope.of(context).unfocus();
  Widget contents(BuildContext context) => Padding(
    padding: const EdgeInsets.all(22),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close details',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
  if (MediaQuery.sizeOf(context).width < 700) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(primary: true, child: contents(context)),
        ),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: SingleChildScrollView(primary: true, child: contents(context)),
        ),
      ),
    );
  }
}
