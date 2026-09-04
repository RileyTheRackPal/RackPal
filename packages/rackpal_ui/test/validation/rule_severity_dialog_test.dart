// M5-F4 — the per-rule, per-project severity control (`#297`).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

void main() {
  final at = DateTime.utc(2026, 9, 4, 12);

  late Future<RuleSeverityChoice?> pending;

  Future<void> open(
    WidgetTester tester,
    String ruleId, {
    RuleOverride? current,
  }) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                pending = showRuleSeverityDialog(
                  context: context,
                  ruleId: ruleId,
                  current: current,
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

  testWidgets('changing a severity is refused until a reason is written', (
    tester,
  ) async {
    // Unlike an instance acknowledgement, an override ALWAYS needs one:
    // it is a standing decision about the whole project.
    await open(tester, 'PWR-001');
    await tester.tap(find.text('advisory'));
    await tester.pumpAndSettle();

    const expected =
        'Changing what PWR-001 counts as needs a written reason, because '
        'it prints on sheet T0.02 for whoever reads the drawings.';
    expect(find.text(expected), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, kSeverityApply),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byType(TextField),
      'Our jobs are all sub-panel fed and measured on site.',
    );
    await tester.pumpAndSettle();
    expect(find.text(expected), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, kSeverityApply));
    await tester.pumpAndSettle();
    final choice = await pending;
    expect(choice!.severity, Severity.advisory);
    expect(
      choice.reason,
      'Our jobs are all sub-panel fed and measured on site.',
    );
  });

  testWidgets('off is offered plainly, as #297 requires', (tester) async {
    await open(tester, 'LNK-020');
    expect(find.text(kSeverityOff), findsOneWidget);
    await tester.tap(find.text(kSeverityOff));
    // PUMP BEFORE TYPING. The reason field is disabled until a severity
    // is chosen, so `enterText` without this lands on a disabled field,
    // the text never arrives, Apply stays disabled and the test hangs on
    // a dialog that never pops. That is what the first draft did.
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'We track loose ends in the punch list.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, kSeverityApply));
    await tester.pumpAndSettle();
    expect((await pending)!.severity, Severity.off);
  });

  testWidgets('restoring the default needs no reason', (tester) async {
    // The asymmetry is deliberate: removing an override is not a
    // standing decision, it is the withdrawal of one.
    await open(
      tester,
      'PWR-001',
      current: RuleOverride(
        severity: Severity.off,
        reason: 'set earlier',
        by: 'riley',
        at: at,
      ),
    );
    await tester.tap(find.text(severityUseDefault(Severity.warning)));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, kSeverityApply),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, kSeverityApply));
    await tester.pumpAndSettle();
    final choice = await pending;
    expect(choice!.severity, isNull, reason: 'null means restore the default');
    expect(choice.reason, isEmpty);
  });

  testWidgets('the default row names the catalogue severity', (tester) async {
    // So the person can see what they are going back TO without leaving.
    await open(tester, 'PWR-001');
    expect(
      find.text(severityUseDefault(Severity.warning)),
      findsOneWidget,
    );
    expect(kRulesById['PWR-001']!.defaultSeverity, Severity.warning);
  });

  testWidgets('an existing override arrives selected, with its reason', (
    tester,
  ) async {
    await open(
      tester,
      'RCK-003',
      current: RuleOverride(
        severity: Severity.advisory,
        reason: 'We derate racks ourselves.',
        by: 'riley',
        at: at,
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'We derate racks ourselves.',
    );
    // Applying unchanged is legal: the reason is already written.
    await tester.tap(find.widgetWithText(FilledButton, kSeverityApply));
    await tester.pumpAndSettle();
    expect((await pending)!.severity, Severity.advisory);
  });

  testWidgets('the reason field is disabled while restoring the default', (
    tester,
  ) async {
    await open(tester, 'PWR-001');
    expect(
      tester.widget<TextField>(find.byType(TextField)).enabled,
      isFalse,
      reason: 'nothing will read a reason for withdrawing an override',
    );
  });

  testWidgets('Why? is reachable from here too', (tester) async {
    await open(tester, 'SIG-001');
    await tester.tap(find.widgetWithText(TextButton, kWhyLabel));
    await tester.pumpAndSettle();
    expect(find.text(kRulesById['SIG-001']!.rationale), findsOneWidget);
  });

  testWidgets('Esc cancels', (tester) async {
    await open(tester, 'PWR-001');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await pending, isNull);
  });
}
