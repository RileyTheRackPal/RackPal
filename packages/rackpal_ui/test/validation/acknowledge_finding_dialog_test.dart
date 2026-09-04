// M5-F2 — acknowledging from the list (`#295`, CR-019, RJ-006).
//
// THE REFUSAL IS ASSERTED AS THE WHOLE SENTENCE, not as a substring.
// `acknowledgement_commands.dart` promises the message is *"shown beside
// a disabled button, so it has to be the whole explanation"*, and a
// `contains` assertion would pass over a truncated one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

void main() {
  const rackId = Uuid('0190e0dd-0003-7000-8000-000000000001');

  Finding finding(String ruleId, Severity severity) => Finding(
    ruleId: ruleId,
    severity: severity,
    message: 'A sentence about $ruleId.',
    targets: const [rackId],
    primaryEntityId: rackId,
  );

  // THE RESULT FUTURE IS HELD, NOT RETURNED. An `async` helper that
  // returns the dialog's own future is flattened by Dart, so awaiting
  // the helper would not resolve until the dialog closed: the first
  // draft of this file deadlocked every test that way.
  late Future<AcknowledgeChoice?> pending;

  /// Opens the dialog. Its result lands on [pending].
  Future<void> open(WidgetTester tester, Finding f) async {
    // A REAL WINDOW, not the 800x600 default. The dialog now scrolls, so
    // it survives the small one, but a test at a size nobody uses is not
    // measuring the layout anybody sees.
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                pending = showAcknowledgeFindingDialog(
                  context: context,
                  finding: f,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('instance scope needs no reason (RJ-006)', (tester) async {
    await open(tester, finding('SIG-001', Severity.error));
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, kAckConfirm),
    );
    expect(
      button.onPressed,
      isNotNull,
      reason: 'an unexplained single-instance acknowledgement is legal',
    );
    await tester.tap(find.widgetWithText(FilledButton, kAckConfirm));
    await tester.pumpAndSettle();
    final choice = await pending;
    expect(choice, isNotNull);
    expect(choice!.projectWide, isFalse);
    expect(choice.reason, '');
  });

  testWidgets('a project-wide mute is refused until a reason is written', (
    tester,
  ) async {
    await open(tester, finding('SIG-001', Severity.error));

    await tester.tap(find.text(ackScopeProjectWide('SIG-001')));
    await tester.pumpAndSettle();

    // The whole sentence, from core, rendered verbatim.
    const expected =
        'Muting SIG-001 across the whole project needs a written reason, '
        'because it prints on sheet T0.02 for whoever reads the drawings.';
    expect(find.text(expected), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, kAckConfirm))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), 'As-found, agreed on site.');
    await tester.pumpAndSettle();
    expect(find.text(expected), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, kAckConfirm));
    await tester.pumpAndSettle();
    final choice = await pending;
    expect(choice!.projectWide, isTrue);
    expect(choice.reason, 'As-found, agreed on site.');
  });

  testWidgets('whitespace is not a written reason', (tester) async {
    // `isWrittenReason` trims. A dialog that accepted "   " would put a
    // blank line on T0.02 where a justification is meant to print.
    await open(tester, finding('SIG-001', Severity.error));
    await tester.tap(find.text(ackScopeProjectWide('SIG-001')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, kAckConfirm))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await pending, isNull);
  });

  testWidgets('the default keeps the finding at its own severity', (
    tester,
  ) async {
    // NOT `off`. Defaulting to hidden would make the one-click path the
    // one that empties the list.
    await open(tester, finding('LEN-001', Severity.warning));
    await tester.tap(find.widgetWithText(FilledButton, kAckConfirm));
    await tester.pumpAndSettle();
    expect((await pending)!.demotedTo, Severity.warning);
  });

  testWidgets('hiding is offered, just not by default', (tester) async {
    await open(tester, finding('LEN-001', Severity.warning));
    await tester.tap(find.byType(DropdownButton<Severity>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kAckSeverityHidden).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, kAckConfirm));
    await tester.pumpAndSettle();
    expect((await pending)!.demotedTo, Severity.off);
  });

  testWidgets('the reason label says which scope it is for', (tester) async {
    await open(tester, finding('SIG-001', Severity.error));
    expect(find.text(kAckReasonOptional), findsOneWidget);
    await tester.tap(find.text(ackScopeProjectWide('SIG-001')));
    await tester.pumpAndSettle();
    expect(find.text(kAckReasonRequired), findsOneWidget);
    expect(find.text(kAckReasonOptional), findsNothing);
  });

  test('the two reason labels are different strings', () {
    // Both label tests above would pass if they were equal.
    expect(kAckReasonOptional, isNot(kAckReasonRequired));
  });

  testWidgets('Esc cancels', (tester) async {
    await open(tester, finding('SIG-001', Severity.error));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await pending, isNull);
  });
}
