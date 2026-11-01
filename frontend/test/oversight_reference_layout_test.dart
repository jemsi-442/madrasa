import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_oversight_page.dart';
import 'package:mif_app/src/madrasa_learning_coverage.dart';
import 'package:mif_app/src/oversight_visuals.dart';

void main() {
  for (final width in [390.0, 1600.0]) {
    testWidgets('reference layout uses cards and table at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurriculumOversightPage(
              onBack: () {},
              onSessionExpired: () {},
              load: (path) async => path.contains('/madrasas?')
                  ? {
                      'items': [
                        {
                          'id': '1',
                          'name': 'Synthetic Madrasa',
                          'eligible': 6,
                          'recorded': 2,
                          'unrecorded': 4,
                          'needingSupport': 1,
                          'status': 'ACTIVE',
                        },
                      ],
                      'hasMore': false,
                    }
                  : {
                      'items': [],
                      'hasMore': false,
                      'institution': {
                        'eligible': 6,
                        'recorded': 2,
                        'unrecorded': 4,
                        'needingSupport': 1,
                        'madrasas': 1,
                      },
                      'quran': {
                        'classScopes': 1,
                        'activities': [
                          {'activity': 'READING', 'sessions': 9},
                          {'activity': 'MEMORIZATION', 'sessions': 3},
                        ],
                      },
                    },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OversightMetrics), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await tester.ensureVisible(find.text('Review follow-ups'));
      await tester.tap(find.text('Review follow-ups'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MadrasaLearningCoverage>(
              find.byType(MadrasaLearningCoverage),
            )
            .followupsOnly,
        isTrue,
      );
      await tester.ensureVisible(find.text('Show all madrasas'));
      await tester.tap(find.text('Show all madrasas'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MadrasaLearningCoverage>(
              find.byType(MadrasaLearningCoverage),
            )
            .followupsOnly,
        isFalse,
      );
      final table = tester.getTopLeft(find.byType(MadrasaLearningCoverage));
      final quran = tester.getTopLeft(find.byType(OversightQuranPanel));
      if (width > 1000) {
        expect(quran.dy, table.dy);
        expect(quran.dx, greaterThan(table.dx));
      } else {
        expect(quran.dy, greaterThan(table.dy));
      }
      await tester.ensureVisible(find.text('Hifz'));
      await tester.tap(find.text('Hifz'));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
