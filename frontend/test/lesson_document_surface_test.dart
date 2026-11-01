import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/lesson_document_surface.dart';
import 'package:mif_app/src/lesson_media_delivery.dart';

void main() {
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
