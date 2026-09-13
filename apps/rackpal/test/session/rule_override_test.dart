// `#879`, in the shell — a rule override is a SIGNED decision, and the
// signature comes from the session.
//
// =====================================================================
// A MUTATION NAMED THIS FILE INTO EXISTENCE
// =====================================================================
// `project_settings_dialog_test.dart` proves the section writes the
// severity, the reason and the author it was handed. It passes its OWN
// actor in, so blanking the one the shell hands over SURVIVED: nothing
// anywhere asserted that the author on a persisted decision is the person
// using the product.
//
// The same is true of the clock. `RuleOverride.at` is persisted and
// prints on `T0.02` beside the reason, and a dialog given a fixed epoch
// would date every decision in the project to the same instant without
// any test noticing.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'session_fakes.dart';

void main() {
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('Jost'): bytes,
    });
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1400)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('the override is signed by the SESSION, not by a default', (
    tester,
  ) async {
    final built = await buildTestApp(measurer);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    final controller = built.session.services.session.controller;
    final doc = built.session.services.session.document;

    // File ▸ Project settings…
    await tester.tap(find.widgetWithText(SubmenuButton, 'File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kProjectSettingsLabel));
    await tester.pumpAndSettle();

    final list = find
        .descendant(
          of: find.byKey(kProjectSettingsListKey),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(kOverrideARule),
      200,
      scrollable: list,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(kOverrideARule));
    await tester.pumpAndSettle();

    final rule = overridableRules().first;
    await tester.tap(find.text(rule.ruleId));
    await tester.pumpAndSettle();

    // The severity dialog, anchored on its confirm: the settings dialog
    // is still an `AlertDialog` underneath it.
    final severityDialog = find.ancestor(
      of: find.text(kSeverityApply),
      matching: find.byType(AlertDialog),
    );
    await tester.tap(
      find.descendant(
        of: severityDialog,
        matching: find.text(Severity.warning.name),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: severityDialog, matching: find.byType(TextField)),
      'Agreed with the owner on site.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(kSeverityApply));
    await tester.pumpAndSettle();

    final written = doc.settings.ruleOverrides[rule.ruleId];
    expect(
      written,
      isNotNull,
      reason: 'nothing opened this dialog at all before `#879`',
    );
    expect(written!.severity, Severity.warning);
    expect(written.reason, 'Agreed with the owner on site.');
    expect(
      written.by,
      controller.actor,
      reason:
          'the author is half of what makes this a signed decision, and '
          'it prints on T0.02 beside the reason',
    );
    expect(
      written.at,
      controller.clock.nowUtc(),
      reason:
          'the date is the other half, and a dialog given a fixed epoch '
          'would date every decision in the project to one instant',
    );
  });

  testWidgets('and it is undoable, because settings live in the document', (
    tester,
  ) async {
    final built = await buildTestApp(measurer);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    final doc = built.session.services.session.document;
    final rule = overridableRules().first;

    // Seeded rather than clicked: what is under test here is the UNDO,
    // and the gesture above already proves the write.
    built.session.services.session.controller.run(
      SetRuleOverrideCommand(
        ruleId: rule.ruleId,
        from: null,
        to: RuleOverride(
          severity: Severity.off,
          reason: 'Not applicable to this job.',
          by: 'test',
          at: DateTime.utc(2026, 9, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(doc.settings.ruleOverrides, hasLength(1));

    // The Edit menu names it, which is `#874`'s machinery meeting
    // `#879`'s command.
    await tester.tap(find.widgetWithText(SubmenuButton, 'Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Undo Override rule severity'), findsOneWidget);

    await tester.tap(find.text('Undo Override rule severity'));
    await tester.pumpAndSettle();
    expect(doc.settings.ruleOverrides, isEmpty);
  });
}
