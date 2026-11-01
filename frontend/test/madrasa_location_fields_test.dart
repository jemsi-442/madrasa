import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/madrasa_location_fields.dart';

void main() {
  testWidgets(
    'changing country refreshes region options without erasing typed areas',
    (tester) async {
      final values = <String, String>{'country': 'Tanzania'};
      final calls = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MadrasaLocationFields(
                values: values,
                loadSuggestions: (path) async {
                  final uri = Uri.parse(path);
                  calls.add(uri);
                  return {
                    'items': [
                      uri.queryParameters['country'] == 'Kenya'
                          ? 'Synthetic County'
                          : 'Synthetic Region',
                    ],
                  };
                },
              ),
            ),
          ),
        ),
      );
      final region = find.byKey(const ValueKey('madrasa-location-region'));
      await tester.enterText(region, 'Syn');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Synthetic Region'), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, 'Kenya'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Synthetic Region'), findsNothing);
      expect(values['region'], 'Syn');
      // Explicitly move focus, then return without changing the text.
      await tester.tap(find.byKey(const ValueKey('madrasa-location-country')));
      await tester.tap(region);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(calls.last.queryParameters['country'], 'Kenya');
      expect(find.widgetWithText(ListTile, 'Synthetic County'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late responses cannot restore options after a parent changes away and back',
    (tester) async {
      final values = <String, String>{'country': 'Tanzania'};
      final response = Completer<dynamic>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MadrasaLocationFields(
                values: values,
                loadSuggestions: (_) => response.future,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('madrasa-location-region')),
        'Syn',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.widgetWithText(ActionChip, 'Kenya'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ActionChip, 'Tanzania'));
      await tester.pump();
      response.complete({
        'items': ['Stale Region'],
      });
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Stale Region'), findsNothing);
      expect(values['region'], 'Syn');
      expect(find.text('Finding suggestions...'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('selects country and scoped region suggestions', (tester) async {
    final values = <String, String>{};
    final calls = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MadrasaLocationFields(
              values: values,
              loadSuggestions: (path) async {
                final uri = Uri.parse(path);
                calls.add(uri);
                return {
                  'items': uri.queryParameters['field'] == 'country'
                      ? ['Tanzania']
                      : ['Dar es Salaam'],
                };
              },
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('madrasa-location-country')),
      'Tan',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Tanzania'));
    await tester.pumpAndSettle();
    expect(values['country'], 'Tanzania');
    await tester.enterText(
      find.byKey(const ValueKey('madrasa-location-region')),
      'Dar',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.widgetWithText(ListTile, 'Dar es Salaam')).dy,
      lessThanOrEqualTo(
        tester
            .getTopLeft(find.byKey(const ValueKey('madrasa-location-ward')))
            .dy,
      ),
    );
    await tester.tap(find.widgetWithText(ListTile, 'Dar es Salaam'));
    await tester.pumpAndSettle();
    expect(values['region'], 'Dar es Salaam');
    expect(calls.last.queryParameters['country'], 'Tanzania');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'explains missing parents and lookup failures without blocking typing',
    (tester) async {
      final values = <String, String>{'country': 'Tanzania'};
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MadrasaLocationFields(
                values: values,
                loadSuggestions: (_) async {
                  calls++;
                  throw Exception('offline');
                },
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('madrasa-location-district')),
        'Kin',
      );
      await tester.pumpAndSettle();
      expect(find.text('Enter region first.'), findsOneWidget);
      expect(calls, 0);
      await tester.enterText(
        find.byKey(const ValueKey('madrasa-location-region')),
        'Dar',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(
        find.text('Suggestions unavailable. You can still enter the area.'),
        findsOneWidget,
      );
      expect(values['region'], 'Dar');
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 700.0]) {
    testWidgets(
      'country shortcuts change labels without losing local entries at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final values = <String, String>{};
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MadrasaLocationFields(values: values),
              ),
            ),
          ),
        );
        await tester.tap(find.widgetWithText(ActionChip, 'Tanzania'));
        await tester.pumpAndSettle();
        expect(find.text('Region *'), findsOneWidget);
        expect(find.text('District *'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('madrasa-location-region')),
          'Synthetic Area',
        );
        await tester.tap(find.widgetWithText(ActionChip, 'Kenya'));
        await tester.pumpAndSettle();
        expect(find.text('County *'), findsOneWidget);
        expect(find.text('Sub-county *'), findsOneWidget);
        expect(values['region'], 'Synthetic Area');
        expect(find.text('Synthetic Area'), findsOneWidget);
        expect(values['country'], 'Kenya');
        await tester.enterText(
          find.byKey(const ValueKey('madrasa-location-country')),
          'Uganda',
        );
        await tester.pumpAndSettle();
        expect(find.text('Region / County / State *'), findsOneWidget);
        expect(values['country'], 'Uganda');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'requires country region district and ward but allows optional villages',
    (tester) async {
      final key = GlobalKey<FormState>();
      final values = <String, String>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: key,
                child: MadrasaLocationFields(values: values),
              ),
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.enterText(
        find.byKey(const ValueKey('madrasa-location-country')),
        'Kenya',
      );
      await tester.enterText(
        find.byKey(const ValueKey('madrasa-location-region')),
        'Synthetic County',
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.enterText(
        find.byKey(const ValueKey('madrasa-location-district')),
        'Synthetic District',
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.enterText(
        find.byKey(const ValueKey('madrasa-location-ward')),
        'Synthetic Ward',
      );
      expect(key.currentState!.validate(), isTrue);
      expect(values['ward'], 'Synthetic Ward');
      expect(find.text('Hamlet (optional)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
