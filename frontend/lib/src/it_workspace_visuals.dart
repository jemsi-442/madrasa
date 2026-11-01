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
      const Text(
        'AFAQ / IT WORKSPACE',
        style: TextStyle(
          color: AfaqDesign.gold,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        title,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
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

class ItRecordDetails extends StatelessWidget {
  const ItRecordDetails({super.key, required this.values});
  final Map<String, dynamic> values;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns = bounds.maxWidth >= 600 ? 2 : 1;
      return Wrap(
        spacing: 20,
        runSpacing: 16,
        children: [
          for (final entry in values.entries)
            SizedBox(
              width: (bounds.maxWidth - (columns - 1) * 20) / columns,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AfaqDesign.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    entry.key.endsWith('(UTC)')
                        ? itTimestamp(entry.value)
                        : entry.value == null
                        ? 'Not recorded'
                        : '${entry.value}',
                    style: const TextStyle(color: AfaqDesign.ink, height: 1.5),
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
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AfaqDesign.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AfaqDesign.border, space: 24),
    ),
    child: child,
  );
}
