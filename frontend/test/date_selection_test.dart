import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/date_selection.dart';
import 'package:mif_app/src/admin_forms.dart';

void main() {
  testWidgets('month year jump preserves selection when cancelled', (
    tester,
  ) async {
    DateTime? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => selected = await showAfaqMonthPicker(
                context,
                initialDate: DateTime(2026, 10),
                firstYear: 2020,
                lastYear: 2030,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(find.text('Choose month'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(selected, isNull);
    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feb'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2025, 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('date picker clamps an existing date to allowed bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAfaqDatePicker(
                context: context,
                initialDate: DateTime(2030),
                firstDate: DateTime(2020),
                lastDate: DateTime(2026, 10, 31),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .initialDate,
      DateTime(2026, 10, 31),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('short month dialog scrolls and shortcuts respect year limits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DateTime? selected;
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => selected = await showAfaqMonthPicker(
                context,
                initialDate: DateTime(2001),
                firstYear: 2000,
                lastYear: 2002,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final chip = tester.widget<ActionChip>(
      find.widgetWithText(ActionChip, 'This month'),
    );
    if (now.year > 2002) expect(chip.onPressed, isNull);
    await tester.ensureVisible(find.text('Dec'));
    await tester.tap(find.text('Dec'));
    await tester.pumpAndSettle();
    expect(monthValue(selected!), '2001-12');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'this month shortcut returns the first day of the current month',
    (tester) async {
      DateTime? selected;
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => selected = await showAfaqMonthPicker(
                  context,
                  initialDate: DateTime(now.year - 1),
                  firstYear: now.year - 2,
                  lastYear: now.year + 2,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();
      expect(selected, DateTime(now.year, now.month));
    },
  );
  testWidgets('month picker on small screens selects month without a day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DateTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showAfaqMonthPicker(
                context,
                initialDate: DateTime(2026, 10),
                firstYear: 2025,
                lastYear: 2026,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Next year',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feb'));
    await tester.pumpAndSettle();
    expect(monthValue(picked!), '2025-02');
    expect(picked!.day, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'existing birth date opens in its year and saves unchanged on cancel',
    (tester) async {
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAdminForm(
                  context,
                  title: 'Synthetic learner',
                  fields: const [
                    AdminField(
                      'dob',
                      'Date of birth',
                      kind: 'date',
                      initial: '1996-02-29',
                    ),
                  ],
                  onSave: (values) async {
                    saved = values;
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Choose date of birth'));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.initialDate, DateTime(1996, 2, 29));
      expect(picker.firstDate.year, 1900);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?['dob'], '1996-02-29');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('year field selects a year directly', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AfaqYearField(
            label: 'Report year',
            value: 2026,
            firstYear: 2020,
            lastYear: 2030,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025'));
    await tester.pumpAndSettle();
    expect(selected, 2025);
    expect(tester.takeException(), isNull);
  });
}
