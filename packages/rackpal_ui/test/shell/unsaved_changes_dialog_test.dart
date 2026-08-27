// The close-while-dirty prompt, driven by real taps and real key events.
//
// EVERY ASSERTION HERE IS ABOUT A RULE THAT COSTS SOMEBODY THEIR WORK IF
// IT BREAKS, and none of them calls a callback directly — the dialog is
// mounted, focused and operated the way a user operates it, because the
// interesting bugs in this widget are all about WHICH BUTTON THE
// KEYBOARD REACHES.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// Holds whatever the dialog resolved with, so an assertion can read it
/// after the route has popped.
///
/// EVERY KEYBOARD TEST BELOW READS THIS rather than merely checking that
/// the dialog closed. "The dialog closed" is true for all three answers,
/// including the one that throws work away — an assertion that cannot
/// tell Cancel from Don't Save is not defending anything.
final class _Result {
  UnsavedChangesChoice? choice;
}

Future<_Result> _open(
  WidgetTester tester, {
  String documentName = 'Smith Residence',
  int? editCount = 12,
}) async {
  final result = _Result();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async => result.choice = await showUnsavedChangesDialog(
            context,
            documentName: documentName,
            editCount: editCount,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('THREE buttons. Never two.', (tester) async {
    await _open(tester);

    // The spec says this in exactly those words, and the two-button
    // version is what every rushed implementation ships: the user who
    // hit Alt+F4 by accident then has no way to say "I did not mean to
    // close this at all".
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Don’t Save'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('the title names the document', (tester) async {
    await _open(tester, documentName: 'Jones Loft');
    expect(find.text('Save changes to Jones Loft?'), findsOneWidget);
  });

  testWidgets('the body states the edit count', (tester) async {
    await _open(tester, editCount: 9);
    expect(
      find.text('If you don’t save, 9 changes will be lost.'),
      findsOneWidget,
    );
  });

  testWidgets('one change is singular, not "1 changes"', (tester) async {
    await _open(tester, editCount: 1);
    expect(
      find.text('If you don’t save, 1 change will be lost.'),
      findsOneWidget,
    );
  });

  testWidgets('G4: an UNKNOWN count omits the number rather than guessing '
      'one', (tester) async {
    await _open(tester, editCount: null);

    // "12 changes will be lost" that is actually 13 is worse than a
    // sentence with no number in it. `editsSinceSave` returns null when
    // the undo stack was poisoned or the save point aged out, and this is
    // what the UI must do with that.
    expect(
      find.text('If you don’t save, your unsaved changes will be lost.'),
      findsOneWidget,
    );
    expect(find.textContaining(RegExp(r'\d')), findsNothing);
  });

  testWidgets('Save holds initial focus, so Enter is the SAFE action', (
    tester,
  ) async {
    final result = await _open(tester);

    // Driven as a real key event rather than by asserting on a property:
    // "autofocus is set" and "Enter reaches THIS button" are different
    // claims, and only the second one matters.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(result.choice, UnsavedChangesChoice.save);
  });

  testWidgets('Esc is Cancel', (tester) async {
    final result = await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    // THE CHOICE, not merely "it closed". Esc landing on Don't Save
    // would close the dialog just as convincingly and would throw the
    // user's work away.
    expect(result.choice, UnsavedChangesChoice.cancel);
  });

  testWidgets('NOTHING on the keyboard lands on Don’t Save', (tester) async {
    // The destructive action is neither the default nor focus-first, and
    // no accelerator reaches it. Both single-key answers are DRIVEN and
    // both must land somewhere else — reading `autofocus` off the widget
    // would prove only that one particular spelling of the bug is absent.
    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.escape]) {
      final result = await _open(tester);
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(
        result.choice,
        isNot(UnsavedChangesChoice.dontSave),
        reason: '$key must not reach the irreversible action',
      );
    }
  });

  testWidgets('clicking outside is not a decision', (tester) async {
    await _open(tester);

    // `barrierDismissible: false`. A tap on the scrim must leave the
    // dialog exactly where it is — the alternative is silently picking a
    // branch the user never chose.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('each button resolves with its own choice', (tester) async {
    for (final (label, expected) in <(String, UnsavedChangesChoice)>[
      ('Save', UnsavedChangesChoice.save),
      ('Don’t Save', UnsavedChangesChoice.dontSave),
      ('Cancel', UnsavedChangesChoice.cancel),
    ]) {
      UnsavedChangesChoice? choice;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => choice = await showUnsavedChangesDialog(
                context,
                documentName: 'Doc',
                editCount: 3,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(choice, expected, reason: '"$label" must mean $expected');
    }
  });

  test('bodyText is the single source of the count sentence', () {
    // Exposed so the app layer and this suite assert the same string
    // rather than two copies of it drifting apart.
    expect(
      UnsavedChangesDialog.bodyText(null),
      'If you don’t save, your unsaved changes will be lost.',
    );
    expect(
      UnsavedChangesDialog.bodyText(1),
      'If you don’t save, 1 change will be lost.',
    );
    expect(
      UnsavedChangesDialog.bodyText(7),
      'If you don’t save, 7 changes will be lost.',
    );
  });
}
