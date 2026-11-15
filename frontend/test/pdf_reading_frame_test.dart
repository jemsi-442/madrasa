import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/pdf_reading_frame.dart';

void main() {
  testWidgets('PDF controls preserve reading space after landscape resize', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfReadingFrame(
            title: 'A synthetic lesson with a long document title',
            onClose: () => closed = true,
            toolbar: Wrap(
              children: List.generate(
                8,
                (index) => SizedBox(
                  width: 140,
                  height: 48,
                  child: TextButton(
                    onPressed: () {},
                    child: Text('Control $index'),
                  ),
                ),
              ),
            ),
            child: const SizedBox.expand(key: ValueKey('canvas')),
          ),
        ),
      ),
    );
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(find.text('PDF DOCUMENT'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('canvas'))).height,
      greaterThan(260),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Control 7').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Close PDF viewer'));
    expect(closed, isTrue);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.text('PDF DOCUMENT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('PDF reading frame preserves document space at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfReadingFrame(
              title:
                  'A long synthetic lesson document title for responsive reading',
              onClose: () => closed = true,
              toolbar: const Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  PdfControlGroup(
                    children: [
                      IconButton(
                        onPressed: null,
                        icon: Icon(Icons.chevron_left),
                      ),
                      Text('Page 1 of 12'),
                      IconButton(
                        onPressed: null,
                        icon: Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  PdfControlGroup(
                    children: [
                      IconButton(onPressed: null, icon: Icon(Icons.zoom_out)),
                      IconButton(onPressed: null, icon: Icon(Icons.zoom_in)),
                      Text('Fit width'),
                      SizedBox(width: 12),
                    ],
                  ),
                ],
              ),
              child: const SizedBox.expand(key: ValueKey('document-canvas')),
            ),
          ),
        ),
      );
      expect(find.text('PDF DOCUMENT'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('document-canvas'))).height,
        greaterThan(550),
      );
      await tester.tap(find.byTooltip('Close PDF viewer'));
      expect(closed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
