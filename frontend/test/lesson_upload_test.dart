import 'dart:async';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/lesson_upload.dart';
import 'package:mif_app/src/lesson_upload_editor.dart';

void main() {
  for (final invalidSize in [0, lessonUploadLimit + 1]) {
    testWidgets(
      'invalid replacement of size $invalidSize keeps valid selection',
      (tester) async {
        var picks = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: LessonUploadEditor(
              lessonId: 'synthetic',
              pickFile: () async => picks++ == 0
                  ? XFile.fromData(
                      Uint8List.fromList([1]),
                      path: 'Original.pdf',
                    )
                  : _SizedFile(invalidSize),
              upload: (_, _, _, _, _) async => fail('Must not upload'),
            ),
          ),
        );
        await tester.tap(find.text('Choose file'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), 'My resource');
        await tester.ensureVisible(find.text('Change file'));
        await tester.tap(find.text('Change file'));
        await tester.pumpAndSettle();
        expect(find.text('Original.pdf'), findsOneWidget);
        expect(find.text('My resource'), findsOneWidget);
        expect(
          find.textContaining(
            invalidSize == 0 ? 'This file is empty' : 'exceeds the 50 MB limit',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('unreadable file keeps details and never starts upload', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LessonUploadEditor(
          lessonId: 'synthetic',
          pickFile: () async => _UnreadableFile(),
          upload: (_, _, _, _, _) async =>
              fail('Must not upload unreadable file'),
        ),
      ),
    );
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Practice resource');
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.ensureVisible(find.text('Upload resource'));
    await tester.tap(find.text('Upload resource'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not read the selected file'),
      findsOneWidget,
    );
    expect(find.textContaining('Upload could not be confirmed'), findsNothing);
    expect(find.text('Practice resource'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(find.text('Guide.pdf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remove selected video preserves custom title and access', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LessonUploadEditor(
          lessonId: 'synthetic',
          pickFile: () async => XFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            path: 'Practice.mp4',
          ),
          upload: (_, _, _, _, _) async => fail('Must not upload'),
        ),
      ),
    );
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'My practice');
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Remove file'));
    await tester.tap(find.text('Remove file'));
    await tester.pumpAndSettle();
    expect(find.text('Practice.mp4'), findsNothing);
    expect(find.text('My practice'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((w) => w is FilledButton),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing a file clears its generated title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LessonUploadEditor(
          lessonId: 'synthetic',
          pickFile: () async =>
              XFile.fromData(Uint8List.fromList([1]), path: 'Guide.pdf'),
          upload: (_, _, _, _, _) async => fail('Must not upload'),
        ),
      ),
    );
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove file'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      isEmpty,
    );
  });

  test('video has a larger bounded limit than documents', () {
    expect(lessonUploadLimitFor('mp4'), 250 * 1024 * 1024);
    for (final format in ['pdf', 'mp3', 'wav', 'png', 'jpg']) {
      expect(lessonUploadLimitFor(format), 50 * 1024 * 1024);
    }
  });
  testWidgets('successful upload closes without asking to discard', (
    tester,
  ) async {
    dynamic result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<dynamic>(
                  context: context,
                  builder: (_) => LessonUploadEditor(
                    lessonId: 'synthetic',
                    pickFile: () async => XFile.fromData(
                      Uint8List.fromList([37, 80, 68, 70]),
                      path: 'Guide.pdf',
                    ),
                    upload: (_, _, _, _, _) async => {'id': 'saved-resource'},
                  ),
                );
              },
              child: const Text('Open upload'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Upload resource'));
    await tester.tap(find.text('Upload resource'));
    await tester.pumpAndSettle();
    expect(result, {'id': 'saved-resource'});
    expect(find.byType(LessonUploadEditor), findsNothing);
    expect(find.text('Leave this upload?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'changing files updates generated titles but keeps custom titles',
    (tester) async {
      var index = 0;
      final names = ['First.pdf', 'Second.pdf', 'Third.pdf'];
      await tester.pumpWidget(
        MaterialApp(
          home: LessonUploadEditor(
            lessonId: 'synthetic',
            pickFile: () async => XFile.fromData(
              Uint8List.fromList([37, 80, 68, 70]),
              path: names[index++],
            ),
            upload: (_, _, _, _, _) async => fail('Must not upload'),
          ),
        ),
      );
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      await tester.tap(find.text('Change file'));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'My teaching guide');
      await tester.tap(find.text('Change file'));
      await tester.pumpAndSettle();
      expect(find.text('My teaching guide'), findsOneWidget);
      expect(find.text('Third.pdf'), findsOneWidget);
    },
  );

  testWidgets(
    'cancel and back protect resource details until discard confirmed',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<dynamic>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => LessonUploadEditor(
                    lessonId: 'synthetic',
                    upload: (_, _, _, _, _) async => fail('Must not upload'),
                  ),
                ),
                child: const Text('Open upload'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open upload'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Unsaved resource');
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Leave this upload?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved resource'), findsOneWidget);
      await tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Leave this upload?'), findsOneWidget);
      await tester.tap(find.text('Leave upload'));
      await tester.pumpAndSettle();
      expect(find.byType(LessonUploadEditor), findsNothing);
      expect(find.text('Open upload'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('supported file extensions are normalized', () {
    expect(lessonFileFormat('Photo.JPEG'), 'jpg');
    expect(lessonFileFormat('guide.PDF'), 'pdf');
    expect(lessonFileFormat('script.exe'), isNull);
  });

  test('upload sends raw bytes with authentication, not JSON', () async {
    final bytes = Uint8List.fromList([37, 80, 68, 70]);
    final api = MifApiClient(
      baseUrl: 'https://school.test',
      browserAuth: false,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Content-Type'], 'application/octet-stream');
        expect(request.headers['Authorization'], 'Bearer synthetic-token');
        expect(request.bodyBytes, bytes);
        return http.Response('{"data":{"id":"synthetic-asset"}}', 201);
      }),
    );
    final result = await api.request(
      '/api/courses/lessons/1/upload?format=pdf',
      method: 'POST',
      accessToken: 'synthetic-token',
      binaryBody: bytes,
    );
    expect(result['id'], 'synthetic-asset');
  });

  test('network failure does not automatically resend upload', () async {
    var calls = 0;
    final api = MifApiClient(
      baseUrl: 'https://school.test',
      browserAuth: false,
      client: MockClient((_) async {
        calls++;
        throw http.ClientException('offline');
      }),
    );
    await expectLater(
      api.request(
        '/upload',
        method: 'POST',
        binaryBody: Uint8List.fromList([1]),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });

  testWidgets('cancelled picker leaves upload disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LessonUploadEditor(
          lessonId: 'synthetic',
          pickFile: () async => null,
          upload: (_, _, _, _, _) async => fail('Must not upload'),
        ),
      ),
    );
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((w) => w is FilledButton),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('unsupported file is rejected before upload', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LessonUploadEditor(
          lessonId: 'synthetic',
          pickFile: () async =>
              XFile.fromData(Uint8List.fromList([1]), path: 'test.exe'),
          upload: (_, _, _, _, _) async => fail('Must not upload'),
        ),
      ),
    );
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose a PDF, JPG, PNG, MP4, MP3 or WAV file.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'failed upload keeps selection and title and defaults to locked',
    (tester) async {
      final pending = Completer<dynamic>();
      await tester.pumpWidget(
        MaterialApp(
          home: LessonUploadEditor(
            lessonId: 'synthetic',
            pickFile: () async => XFile.fromData(
              Uint8List.fromList([37, 80, 68, 70]),
              path: 'Guide.pdf',
            ),
            upload: (lesson, title, format, visibility, bytes) {
              expect(lesson, 'synthetic');
              expect(title, 'Guide');
              expect(format, 'pdf');
              expect(visibility, 'LOCKED');
              return pending.future;
            },
          ),
        ),
      );
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Upload resource'));
      await tester.tap(find.text('Upload resource'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        find.textContaining('Waiting for server confirmation'),
        findsOneWidget,
      );
      for (final label in ['Remove file', 'Change file', 'Upload resource']) {
        final button = tester.widget<ButtonStyleButton>(
          find.byWidgetPredicate(
            (widget) =>
                widget is ButtonStyleButton &&
                find
                    .descendant(
                      of: find.byWidget(widget),
                      matching: find.text(label),
                    )
                    .evaluate()
                    .isNotEmpty,
          ),
        );
        expect(button.onPressed, isNull, reason: '$label must be disabled');
      }
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      pending.completeError(const ApiException('offline', 0));
      await tester.pumpAndSettle();
      expect(find.text('Guide.pdf'), findsOneWidget);
      expect(find.text('Guide'), findsOneWidget);
      expect(
        find.textContaining('Upload could not be confirmed'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _UnreadableFile extends XFile {
  _UnreadableFile() : super('Guide.pdf');

  @override
  Future<int> length() async => 4;

  @override
  Future<Uint8List> readAsBytes() async => throw StateError('File unavailable');
}

class _SizedFile extends XFile {
  _SizedFile(this.size) : super('Replacement.pdf');
  final int size;

  @override
  Future<int> length() async => size;
}
