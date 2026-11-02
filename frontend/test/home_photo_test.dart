import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/home_photo.dart';

void main() {
  testWidgets(
    'slow photo shows a stable placeholder without continuous animation',
    (tester) async {
      final bundle = _DelayedPhotoBundle();
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: bundle,
            child: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: HomePhoto(
                    asset: 'delayed-photo.jpg',
                    description: 'Team photo',
                    aspectRatio: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Loading photo'), findsOneWidget);
      expect(tester.getSize(find.byType(HomePhoto)), const Size(320, 160));
      expect(tester.binding.hasScheduledFrame, isFalse);
      bundle.result.completeError(StateError('Simulated unavailable image'));
      await tester.pumpAndSettle();
      expect(find.text('Loading photo'), findsNothing);
      expect(find.text('Photo unavailable'), findsOneWidget);
      expect(tester.getSize(find.byType(HomePhoto)), const Size(320, 160));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('missing photo keeps its reserved space and readable fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: HomePhoto(
                asset: 'assets/missing-test-photo.jpg',
                description: 'Test photo',
                aspectRatio: 2,
              ),
            ),
          ),
        ),
      ),
    );
    final initialSize = tester.getSize(find.byType(HomePhoto));
    expect(initialSize, const Size(320, 160));
    await tester.pumpAndSettle();
    expect(find.text('Photo unavailable'), findsOneWidget);
    expect(tester.getSize(find.byType(HomePhoto)), initialSize);
    expect(tester.takeException(), isNull);
  });
}

class _DelayedPhotoBundle extends CachingAssetBundle {
  final result = Completer<ByteData>();
  @override
  Future<ByteData> load(String key) =>
      key == 'delayed-photo.jpg' ? result.future : rootBundle.load(key);
}
