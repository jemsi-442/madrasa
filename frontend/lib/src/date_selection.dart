import 'package:flutter/material.dart';
import 'design_tokens.dart';

String dateValue(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
String monthValue(DateTime day) => dateValue(day).substring(0, 7);

Widget _pickerTheme(BuildContext context, Widget? child) => Theme(
  data: Theme.of(context).copyWith(
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      headerBackgroundColor: AfaqDesign.ink,
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      todayBorder: const BorderSide(color: AfaqDesign.gold, width: 1.5),
    ),
    colorScheme: Theme.of(context).colorScheme.copyWith(
      primary: AfaqDesign.ink,
      onPrimary: Colors.white,
      surface: Colors.white,
    ),
  ),
  child: child!,
);

Future<DateTime?> showAfaqDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  final first = DateUtils.dateOnly(firstDate),
      last = DateUtils.dateOnly(lastDate);
  final initial = DateUtils.dateOnly(initialDate);
  return showDatePicker(
    context: context,
    initialDate: initial.isBefore(first)
        ? first
        : initial.isAfter(last)
        ? last
        : initial,
    firstDate: first,
    lastDate: last,
    helpText: helpText ?? 'Choose date · tap the year to jump quickly',
    builder: _pickerTheme,
  );
}

Future<int?> showAfaqYearPicker(
  BuildContext context, {
  required int initialYear,
  int firstYear = 1900,
  int lastYear = 2100,
}) => showDialog<int>(
  context: context,
  builder: (context) => _pickerTheme(
    context,
    AlertDialog(
      title: const _PickerTitle(
        title: 'Choose year',
        subtitle: 'Scroll to a year or use the shortcut below',
      ),
      content: SizedBox(
        width: 340,
        height: (MediaQuery.sizeOf(context).height * .4).clamp(140.0, 320.0),
        child: YearPicker(
          firstDate: DateTime(firstYear),
          lastDate: DateTime(lastYear, 12, 31),
          selectedDate: DateTime(initialYear.clamp(firstYear, lastYear)),
          onChanged: (date) => Navigator.pop(context, date.year),
        ),
      ),
      actions: [
        if (DateTime.now().year >= firstYear && DateTime.now().year <= lastYear)
          TextButton(
            onPressed: () => Navigator.pop(context, DateTime.now().year),
            child: const Text('This year'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  ),
);

Future<DateTime?> showAfaqMonthPicker(
  BuildContext context, {
  required DateTime initialDate,
  int firstYear = 2000,
  int lastYear = 2100,
}) {
  var year = initialDate.year.clamp(firstYear, lastYear);
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);
  return showDialog<DateTime>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => _pickerTheme(
        context,
        AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const _PickerTitle(
            title: 'Choose month',
            subtitle: 'Tap the year to jump, then choose a month',
          ),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous year',
                        onPressed: year > firstYear
                            ? () => update(() => year--)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final selected = await showAfaqYearPicker(
                              context,
                              initialYear: year,
                              firstYear: firstYear,
                              lastYear: lastYear,
                            );
                            if (selected != null && context.mounted) {
                              update(() => year = selected);
                            }
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text('$year'),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next year',
                        onPressed: year < lastYear
                            ? () => update(() => year++)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final shortcut in [
                        (thisMonth, 'This month'),
                        (lastMonth, 'Last month'),
                      ])
                        ActionChip(
                          avatar: const Icon(Icons.bolt_outlined, size: 18),
                          label: Text(shortcut.$2),
                          onPressed:
                              shortcut.$1.year >= firstYear &&
                                  shortcut.$1.year <= lastYear
                              ? () => Navigator.pop(context, shortcut.$1)
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (var row = 0; row < 4; row++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          for (var col = 1; col <= 3; col++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Semantics(
                                  selected:
                                      year == initialDate.year &&
                                      row * 3 + col == initialDate.month,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                      foregroundColor:
                                          year == initialDate.year &&
                                              row * 3 + col == initialDate.month
                                          ? Colors.white
                                          : AfaqDesign.ink,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      backgroundColor:
                                          year == initialDate.year &&
                                              row * 3 + col == initialDate.month
                                          ? AfaqDesign.ink
                                          : null,
                                    ),
                                    onPressed: () => Navigator.pop(
                                      context,
                                      DateTime(year, row * 3 + col),
                                    ),
                                    child: Text(
                                      const [
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
                                      ][row * 3 + col - 1],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PickerTitle extends StatelessWidget {
  const _PickerTitle({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AfaqDesign.gold.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: AfaqDesign.actionGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AfaqDesign.ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          color: AfaqDesign.muted,
          height: 1.4,
        ),
      ),
    ],
  );
}

class AfaqYearField extends StatelessWidget {
  const AfaqYearField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstYear = 2000,
    this.lastYear = 2100,
  });
  final String label;
  final int value, firstYear, lastYear;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey('$label-$value'),
    initialValue: '$value',
    readOnly: true,
    enabled: onChanged != null,
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: const Icon(Icons.calendar_month_outlined),
    ),
    onTap: onChanged == null
        ? null
        : () async {
            final picked = await showAfaqYearPicker(
              context,
              initialYear: value,
              firstYear: firstYear,
              lastYear: lastYear,
            );
            if (picked != null && context.mounted) onChanged?.call(picked);
          },
  );
}
