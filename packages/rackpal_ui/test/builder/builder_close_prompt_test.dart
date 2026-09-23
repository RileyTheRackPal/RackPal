// `Close` asks before it discards (DR-190 §11.189, board #925).
//
// Until DR-190, `Close` called `onDone` directly and `onDone` unmounts the
// builder, so a dirty draft was destroyed with no prompt. These cases drive
// the real button and the real dialog and assert what the HOST saw: whether
// it was told to close, and what it was handed to save.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final class _ProportionalMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

/// What the host observed: how many times it was told to close, and every
/// body it was asked to save.
final class _Host {
  int closes = 0;
  final List<TemplateBody> saved = [];
}

TemplateBody _saveable() =>
    TemplateBody(manufacturer: 'Generic', model: '', displayName: '')
      ..displayName = 'HDMI Matrix 16x16'
      ..typePrefix = 'MTX'
      ..frontU = 4;

Future<_Host> _pump(WidgetTester tester, TemplateBody template) async {
  // The app's own minimum window, as device_builder_screen_test.dart gives.
  tester.view.physicalSize = const Size(1000, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final host = _Host();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeviceBuilderScreen(
          measurer: _ProportionalMeasurer(),
          template: template,
          onDone: () => host.closes++,
          actions: DeviceBuilderActions(
            onSave: (b) {
              host.saved.add(b);
              return null;
            },
          ),
        ),
      ),
    ),
  );
  return host;
}

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label), text);
  await tester.pump();
}

Future<void> _pressClose(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Close'));
  await tester.pumpAndSettle();
}

Finder get _prompt => find.byType(UnsavedChangesDialog);

void main() {
  testWidgets('a clean draft closes with no prompt', (tester) async {
    final host = await _pump(tester, _saveable());

    await _pressClose(tester);

    expect(_prompt, findsNothing);
    expect(host.closes, 1);
  });

  testWidgets('a dirty draft asks, and Cancel keeps it open and unsaved', (
    tester,
  ) async {
    final host = await _pump(tester, _saveable());
    await _type(tester, 'Model', 'IN1608 XI');

    await _pressClose(tester);
    // THE PRECONDITION, asserted rather than assumed: without the prompt
    // the next tap has nothing to land on and the case would pass on a
    // builder that closed silently.
    expect(_prompt, findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(host.closes, 0);
    expect(host.saved, isEmpty);
    // The edit is still there to be saved later.
    expect(find.widgetWithText(TextField, 'Model'), findsOneWidget);
    expect(find.text('IN1608 XI'), findsOneWidget);
  });

  testWidgets("Don't Save closes without saving", (tester) async {
    final host = await _pump(tester, _saveable());
    await _type(tester, 'Model', 'IN1608 XI');

    await _pressClose(tester);
    expect(_prompt, findsOneWidget);
    await tester.tap(find.text('Don’t Save'));
    await tester.pumpAndSettle();

    expect(host.closes, 1);
    expect(host.saved, isEmpty);
  });

  testWidgets('Save saves the edited draft, then closes', (tester) async {
    final host = await _pump(tester, _saveable());
    await _type(tester, 'Model', 'IN1608 XI');

    await _pressClose(tester);
    expect(_prompt, findsOneWidget);
    await tester.tap(
      find.descendant(
        of: _prompt,
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();

    expect(host.saved.single.model, 'IN1608 XI');
    expect(host.closes, 1);
  });

  testWidgets('Save on a draft that cannot be saved stays open and says why', (
    tester,
  ) async {
    // AC-049's three facts, none of them present: Save is refused, so the
    // prompt's Save must be refused too rather than closing on a failure.
    final host = await _pump(
      tester,
      TemplateBody(manufacturer: 'Generic', model: '', displayName: ''),
    );
    await _type(tester, 'Model', 'IN1608 XI');

    await _pressClose(tester);
    expect(_prompt, findsOneWidget);
    await tester.tap(
      find.descendant(
        of: _prompt,
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();

    expect(host.closes, 0);
    expect(host.saved, isEmpty);
    expect(find.text('Not saved. $kBuilderSaveNeeds.'), findsOneWidget);
  });
}
