import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_oversight_report.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('page-scoped oversight report at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: CurriculumOversightReport(
                rows: [
                  {
                    'madrasa': 'Synthetic A',
                    'madrasaStatus': 'ACTIVE',
                    'subject': 'Arabic',
                    'level': 'Level 1',
                    'version': '1.0',
                    'subjectActive': true,
                    'adoptedClasses': 2,
                    'taughtClassLessons': 1,
                    'plannedClassLessons': 4,
                    'pendingClassLessons': 3,
                  },
                  {
                    'madrasa': 'Synthetic B',
                    'madrasaStatus': 'SUSPENDED',
                    'subject': 'Hadith',
                    'level': 'Level 2',
                    'version': '1.0',
                    'subjectActive': false,
                    'adoptedClasses': 3,
                    'taughtClassLessons': 2,
                    'plannedClassLessons': 8,
                    'pendingClassLessons': 6,
                  },
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('This page only · All-time snapshot'), findsOneWidget);
      expect(find.text('On this page'), findsNWidgets(4));
      for (final total in ['2', '5', '3', '9']) {
        expect(find.text(total), findsOneWidget);
      }
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      expect(find.text('25%'), findsNWidgets(2));
      for (final progress in tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      )) {
        expect(progress.value, .25);
      }
      expect(
        find.textContaining('not evidence of current access'),
        findsOneWidget,
      );
      expect(find.textContaining('inactive or not linked'), findsOneWidget);
      expect(
        find.textContaining('Not connected to this report yet.'),
        findsOneWidget,
      );
      expect(find.text('450 / 520'), findsNothing);
      final table = tester.getTopLeft(find.text('Teaching record coverage'));
      final quran = tester.getTopLeft(find.text("Qur'an learning oversight"));
      if (width > 1000) {
        expect(quran.dx, greaterThan(table.dx));
      } else {
        expect(quran.dy, greaterThan(table.dy));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
