import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/lesson_document_surface.dart';
import 'package:mif_app/src/lesson_media_delivery.dart';
import 'package:mif_app/src/pdf_reading_frame.dart';

void main() {
  testWidgets('PDF opens fullscreen once and can minimize and expand again', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: LessonDocumentSurface(
              delivery: LessonMediaDelivery(
                uri: Uri.parse('asset:guide'),
                kind: 'PDF',
                title: 'Synthetic PDF',
                expiresAt: null,
                downloadAllowed: false,
                assetPath: 'assets/media-preview/guide.pdf',
              ),
              onReady: () {},
              onError: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('Minimize PDF'), findsOneWidget);
    expect(find.byType(PdfReadingFrame), findsOneWidget);
    final fullscreen = tester
        .widgetList<LessonDocumentSurface>(find.byType(LessonDocumentSurface))
        .singleWhere((surface) => surface.fullScreen);
    fullscreen.onPageChanged!(2);
    await tester.tap(find.byTooltip('Minimize PDF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('Minimize PDF'), findsNothing);
    expect(find.text('Full-screen PDF'), findsOneWidget);
    await tester.tap(find.text('Full-screen PDF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('Minimize PDF'), findsOneWidget);
    expect(
      tester
          .widgetList<LessonDocumentSurface>(find.byType(LessonDocumentSurface))
          .singleWhere((surface) => surface.fullScreen)
          .initialPage,
      2,
    );
    Navigator.of(tester.element(find.byType(PdfReadingFrame))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Full-screen PDF'), findsOneWidget);
    await tester.tap(find.text('Full-screen PDF'));
    await tester.pump();
    expect(find.byTooltip('Minimize PDF'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed text leaves loading state without exposing error details',
    (tester) async {
      var errors = 0;
      var ready = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonDocumentSurface(
              delivery: LessonMediaDelivery(
                uri: Uri.parse('asset:missing'),
                kind: 'TEXT',
                title: 'Synthetic missing text',
                expiresAt: null,
                downloadAllowed: false,
                assetPath: 'assets/nonexistent-synthetic-test.txt',
              ),
              onReady: () {
                ready++;
              },
              onError: () {
                errors++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Loading text...'), findsNothing);
      expect(find.textContaining('Use Reload player'), findsOneWidget);
      expect(find.textContaining('nonexistent-synthetic-test'), findsNothing);
      expect(errors, 1);
      expect(ready, 0);
    },
  );

  testWidgets('bundled text becomes selectable and signals readiness once', (
    tester,
  ) async {
    var errors = 0;
    var ready = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonDocumentSurface(
            delivery: LessonMediaDelivery(
              uri: Uri.parse('asset:checklist'),
              kind: 'TEXT',
              title: 'Synthetic text',
              expiresAt: null,
              downloadAllowed: false,
              assetPath: 'assets/media-preview/checklist.txt',
            ),
            onReady: () {
              ready++;
            },
            onError: () {
              errors++;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('Loading text...'), findsNothing);
    expect(errors, 0);
    expect(ready, 1);
  });
}
