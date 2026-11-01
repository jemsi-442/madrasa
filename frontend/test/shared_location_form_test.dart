import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_forms.dart';
import 'package:mif_app/src/madrasa_location_fields.dart';

void main() {
  for (final fill in [false, true]) {
    testWidgets('optional location form saves structured data fill=$fill', (
      tester,
    ) async {
      Map<String, dynamic>? saved;
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAdminForm(
                  context,
                  title: 'Synthetic residence',
                  fields: const [
                    AdminField(
                      'residence',
                      'Guardian residence',
                      kind: 'location',
                      required: false,
                    ),
                  ],
                  load: (path) async {
                    calls.add(path);
                    return {
                      'items': ['Tanzania'],
                    };
                  },
                  onSave: (body) async {
                    saved = body;
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
      if (fill) {
        await tester.tap(find.text('Guardian residence (optional)'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('madrasa-location-country')),
          'Tan',
        );
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Tanzania'));
        await tester.pumpAndSettle();
        expect(
          calls.single,
          startsWith('/api/organizations/location-suggestions?'),
        );
      }
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        saved,
        fill
            ? {
                'residence': {'country': 'Tanzania'},
              }
            : <String, dynamic>{},
      );
      expect(tester.takeException(), isNull);
    });
  }
  test('summary orders known fields and preserves legacy fallback', () {
    expect(
      locationSummary({
        'ward': 'Synthetic Ward',
        'country': 'Tanzania',
        'private': 'omit',
      }),
      'Tanzania, Synthetic Ward',
    );
    expect(locationSummary(null, fallback: 'Legacy address'), 'Legacy address');
  });
}
