// The startup recovery prompt, driven by real taps and key events.
//
// The two properties worth defending here are both about the DESTRUCTIVE
// branch: Discard confirms before it acts, and Esc means "not now"
// instead of "throw it away".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// Holds whatever the dialog resolved with, so an assertion can read it
/// after the route has popped.
final class _Result {
  RecoveryChoice? choice;
}

Future<_Result> _open(
  WidgetTester tester, {
  String documentName = 'Smith Residence',
  int? count = 12,
}) async {
  final result = _Result();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async => result.choice = await showRecoveryPromptDialog(
            context,
            documentName: documentName,
            savedAt: DateTime.utc(2026, 7, 26, 12, 32),
            unsavedEditCount: count,
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
  testWidgets('offers exactly Recover / Discard / Keep for later', (
    tester,
  ) async {
    await _open(tester);

    expect(find.widgetWithText(FilledButton, 'Recover'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Keep for later'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Discard'), findsOneWidget);
  });

  testWidgets('§9.4 copy, with the count', (tester) async {
    await _open(tester);
    expect(
      find.text(
        'RackMate closed unexpectedly. '
        'Recover Smith Residence (12 unsaved changes)?',
      ),
      findsOneWidget,
    );
  });

  testWidgets('G4: a null count omits the parenthetical entirely', (
    tester,
  ) async {
    await _open(tester, count: null);

    // After a crash there is no undo stack left to consult; the count
    // comes from the sidecar, and a sidecar that never recorded one must
    // not be filled in with a plausible number.
    expect(
      find.text('RackMate closed unexpectedly. Recover Smith Residence?'),
      findsOneWidget,
    );
  });

  testWidgets('Recover is the default and Enter takes it', (tester) async {
    final result = await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result.choice, RecoveryChoice.recover);
  });

  testWidgets('Esc means KEEP FOR LATER, never discard', (tester) async {
    final result = await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // The one answer that cannot lose data. A dialog that appears
    // unexpectedly at launch is exactly the kind a user dismisses
    // reflexively.
    expect(result.choice, RecoveryChoice.keepForLater);
  });

  testWidgets('Discard CONFIRMS before it acts, and the confirm states the '
      'count', (tester) async {
    final result = await _open(tester);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(
      find.text('This cannot be undone. 12 changes will be lost.'),
      findsOneWidget,
    );
    // The SAFE answer is the default in the confirm, inverting the outer
    // dialog: this dialog exists to make the destructive answer cost
    // something.
    expect(find.widgetWithText(FilledButton, 'Keep it'), findsOneWidget);
    expect(result.choice, isNull);
  });

  testWidgets('declining the confirm returns to the prompt rather than '
      'closing it', (tester) async {
    final result = await _open(tester);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    // The user has not yet answered the question that was asked.
    expect(find.text('Unsaved work was found'), findsOneWidget);
    expect(result.choice, isNull);
  });

  testWidgets('a confirmed discard resolves with discard', (tester) async {
    final result = await _open(tester);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    // `.last` because the outer prompt's own Discard button is still
    // mounted underneath the confirm.
    await tester.tap(find.widgetWithText(TextButton, 'Discard').last);
    await tester.pumpAndSettle();
    expect(result.choice, RecoveryChoice.discard);
  });

  testWidgets('Keep for later resolves with keepForLater', (tester) async {
    final result = await _open(tester);
    await tester.tap(find.text('Keep for later'));
    await tester.pumpAndSettle();
    expect(result.choice, RecoveryChoice.keepForLater);
  });

  test('the prompt and confirm sentences are pure functions', () {
    expect(
      RecoveryPromptDialog.promptText('Smith', 1),
      'RackMate closed unexpectedly. Recover Smith (1 unsaved change)?',
    );
    expect(
      RecoveryPromptDialog.discardConfirmText(null),
      'This cannot be undone. The unsaved changes will be lost.',
    );
  });
}
