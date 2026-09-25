import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/workspace.dart';

void main() {
  testWidgets('public entry opens a sign-in form', (tester) async {
    await tester.pumpWidget(const MifApp());
    expect(find.text('Login'), findsOneWidget);

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('learner progress shows summary and lesson together', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionContent(
            role: 'LEARNER',
            title: 'My progress',
            data: {
              'summary': {
                'activeCourses': 1,
                'completedLessons': 2,
                'averageProgressPercent': 60,
              },
              'items': [
                {
                  'lesson': {'title': 'Introduction'},
                  'progressPercent': 60,
                },
              ],
            },
          ),
        ),
      ),
    );

    expect(find.text('ACTIVE COURSES'), findsOneWidget);
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('60% complete'), findsOneWidget);
  });

  testWidgets('home and login fit a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MifApp());
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop login renders its brand panel and form', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MifApp());
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
