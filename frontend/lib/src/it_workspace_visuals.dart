import 'package:flutter/material.dart';
import 'design_tokens.dart';

String itTimestamp(dynamic value) {
  if (value == null || '$value'.trim().isEmpty) return 'Not recorded';
  final raw = '$value';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || !RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw)) {
    return 'Time unavailable';
  }
  final date = parsed.toUtc();
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
  String pad(int number) => number.toString().padLeft(2, '0');
  return '${pad(date.day)} ${months[date.month - 1]} ${date.year}, ${pad(date.hour)}:${pad(date.minute)} UTC';
}

class ItPageHeading extends StatelessWidget {
  const ItPageHeading({
    super.key,
    required this.title,
    required this.description,
  });
  final String title, description;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF5ECD6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5D4AB)),
        ),
        child: const Text(
          'AFAQ / IT WORKSPACE',
          style: TextStyle(
            color: AfaqDesign.actionGold,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.4,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        title,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AfaqDesign.ink,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        description,
        style: const TextStyle(color: AfaqDesign.muted, height: 1.5),
      ),
      const SizedBox(height: 24),
    ],
  );
}

/// A consistent, high-contrast section surface for operational dashboards.
class ItSectionPanel extends StatelessWidget {
  const ItSectionPanel({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFD5DEE7)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A011F3D),
          blurRadius: 22,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEDF3F8), Color(0xFFF9FAFC)],
            ),
            border: Border(bottom: BorderSide(color: Color(0xFFD5DEE7))),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 26,
                decoration: BoxDecoration(
                  color: AfaqDesign.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AfaqDesign.ink,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(22), child: child),
      ],
    ),
  );
}

class ItMetricCard extends StatelessWidget {
  const ItMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });
  final String label, value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 150),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: .25)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08011F3D),
          blurRadius: 18,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AfaqDesign.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 26),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          value,
          style: TextStyle(
            color: AfaqDesign.ink,
            fontWeight: FontWeight.w800,
            fontSize: value.length > 9 ? 24 : 32,
            height: 1.2,
          ),
        ),
      ],
    ),
  );
}

class ItRecordDetails extends StatelessWidget {
  const ItRecordDetails({super.key, required this.values});
  final Map<String, dynamic> values;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns =
          bounds.maxWidth >= 600 &&
              MediaQuery.textScalerOf(context).scale(14) <= 20
          ? 2
          : 1;
      return Wrap(
        spacing: 20,
        runSpacing: 16,
        children: [
          for (final entry in values.entries)
            Container(
              width: (bounds.maxWidth - (columns - 1) * 20) / columns,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F8FB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDCE4EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AfaqDesign.muted,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    entry.key.endsWith('(UTC)')
                        ? itTimestamp(entry.value)
                        : entry.value == null
                        ? 'Not recorded'
                        : '${entry.value}',
                    style: const TextStyle(
                      color: AfaqDesign.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class ItWorkspaceSurface extends StatelessWidget {
  const ItWorkspaceSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0x18011F3D),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFD5DEE7)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFDCE4EB), space: 24),
    ),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3F6FA), Color(0xFFFBF9F4)],
        ),
      ),
      child: child,
    ),
  );
}
