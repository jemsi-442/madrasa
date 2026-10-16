import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/design_theme.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/workspace_form_dialog.dart';

void main() {
  test('all workspace themes share field and dialog styling', () {
    final theme = buildAfaqTheme();
    final admin = adminTheme(theme);
    expect(
      admin.inputDecorationTheme.fillColor,
      theme.inputDecorationTheme.fillColor,
    );
    expect(
      admin.inputDecorationTheme.floatingLabelBehavior,
      FloatingLabelBehavior.always,
    );
    expect(admin.dialogTheme.shape, theme.dialogTheme.shape);
  });
  for (final width in [320.0, 1400.0]) {
    testWidgets(
      'shared form remains usable at $width with keyboard and large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final form = GlobalKey<FormState>();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAfaqTheme(),
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.4),
                viewInsets: EdgeInsets.only(bottom: 200),
              ),
              child: Scaffold(
                body: WorkspaceFormDialog(
                  title: const Text('Create a framework'),
                  content: SizedBox(
                    width: 480,
                    child: SingleChildScrollView(
                      child: Form(
                        key: form,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Subject',
                                hintText: 'Enter subject name',
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'Enter a subject name' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () {}, child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () => form.currentState!.validate(),
                      child: const Text('Save draft'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Save draft'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a subject name'), findsOneWidget);
        expect(find.text('AFAQ / WORKSPACE'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
