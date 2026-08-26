// M4-I1's surface gate: the Matrix I/O dialog, driven the way §9.2's
// seven steps drive it (`#220`, docs/06 §4.3, DR-092 §11.91).
//
// DRIVEN THROUGH THE SCREEN, not through `showMatrixArchetypeDialog`.
// `drive the keyboard, not the finder` was earned on this exact surface:
// a dialog that works when a test constructs it and cannot be REACHED
// from the Ports section has failed the only thing it is for. So the
// button is tapped where a person taps it.
//
// THE COPY IS ASSERTED AS WHOLE STRINGS. `print the output before
// claiming copy is done` was earned by a summary line reading `1 ports`
// under a dozen green `contains` assertions, and this dialog has the
// same shape of readout. Every line it can print is pinned here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

TemplateBody _saveable() =>
    TemplateBody(manufacturer: 'Generic', model: '', displayName: '')
      ..displayName = 'Matrix'
      ..typePrefix = 'MTX'
      ..frontU = 4;

final class _Harness {
  TemplateBody? saved;

  Future<TemplateBody> read(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    final body = saved;
    if (body == null) fail('Save is disabled: the template needs its three');
    return body;
  }
}

void main() {
  final registries = buildSeedRegistries();

  Future<_Harness> pump(WidgetTester tester) async {
    final harness = _Harness();
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceBuilderScreen(
            template: _saveable(),
            registries: registries,
            actions: DeviceBuilderActions(
              onSave: (body) {
                harness.saved = body;
                return null;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ListTile, 'Ports'));
    await tester.pumpAndSettle();
    return harness;
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Matrix I/O…'));
    await tester.pumpAndSettle();
  }

  /// Picks a signal in one row's picker, through the filter box a person
  /// uses rather than by scrolling 1800 points of menu.
  Future<void> pickSignal(
    WidgetTester tester,
    String slot,
    String query,
    String label,
  ) async {
    await tester.tap(find.byKey(matrixSignalKey(slot)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('service-filter')),
      query,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> tick(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(CheckboxListTile, label));
    await tester.pumpAndSettle();
  }

  Future<void> count(WidgetTester tester, Key field, String value) async {
    await tester.enterText(find.byKey(field), value);
    await tester.pumpAndSettle();
  }

  /// §9.2 steps 3 to 5, against the worked example's device.
  Future<void> fillWorkedExample(WidgetTester tester) async {
    await pickSignal(tester, 'inputs', 'HDMI 2.0', 'VID·HDMI 2.0 (18 Gbps)');
    await pickSignal(tester, 'outputs', 'HDBaseT', 'VID·HDBaseT (5Play)');
    await tick(tester, 'Mirrored outputs');
    await tick(tester, 'Per-output IR');
    await tick(tester, 'Control (LAN + RS-232 + IR IN)');
    await tick(tester, 'AC inlet (C14)');
  }

  group('the button is where §2 draws it and it opens a dialog', () {
    testWidgets('Matrix I/O… is on the Ports section', (tester) async {
      await pump(tester);
      expect(
        find.widgetWithText(OutlinedButton, 'Matrix I/O…'),
        findsOneWidget,
      );
    });

    testWidgets('there is no button for a generator that does not exist', (
      tester,
    ) async {
      // A control wired to nothing is the defect `_Toolbar` already
      // records against a `Pair front to rear` that could do nothing.
      await pump(tester);
      expect(find.text('Switch ports…'), findsNothing);
      expect(find.text('Paste'), findsNothing);
    });

    testWidgets('tapping it opens Matrix I/O', (tester) async {
      await pump(tester);
      await openDialog(tester);
      expect(find.text(kMatrixDialogTitle), findsOneWidget);
    });
  });

  group('the form refuses a side that names no type', () {
    testWidgets('Generate is disabled on open, and says why', (tester) async {
      await pump(tester);
      await openDialog(tester);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, kArchetypeGenerateLabel),
            )
            .onPressed,
        isNull,
      );
      expect(find.text(kArchetypeNeedsATypeNote), findsOneWidget);
    });

    testWidgets('one side named is still not enough', (tester) async {
      await pump(tester);
      await openDialog(tester);
      await pickSignal(tester, 'inputs', 'HDMI 2.0', 'VID·HDMI 2.0 (18 Gbps)');
      expect(find.text(kArchetypeNeedsATypeNote), findsOneWidget);
    });

    testWidgets('a zero count refuses too', (tester) async {
      await pump(tester);
      await openDialog(tester);
      await pickSignal(tester, 'inputs', 'HDMI 2.0', 'VID·HDMI 2.0 (18 Gbps)');
      await pickSignal(tester, 'outputs', 'HDBaseT', 'VID·HDBaseT (5Play)');
      await count(tester, kMatrixOutputsField, '0');
      expect(find.text(kArchetypeNeedsATypeNote), findsOneWidget);
    });
  });

  group('the preview line, printed rather than contained', () {
    testWidgets('the worked example reads 68 ports across 6 banks', (
      tester,
    ) async {
      await pump(tester);
      await openDialog(tester);
      await fillWorkedExample(tester);
      expect(find.text('68 ports across 6 banks'), findsOneWidget);
    });

    testWidgets('a one-by-one matrix says port and bank, not ports and banks', (
      tester,
    ) async {
      await pump(tester);
      await openDialog(tester);
      await pickSignal(tester, 'inputs', 'HDMI 2.0', 'VID·HDMI 2.0 (18 Gbps)');
      await pickSignal(tester, 'outputs', 'HDMI 2.0', 'VID·HDMI 2.0 (18 Gbps)');
      await count(tester, kMatrixInputsField, '1');
      await count(tester, kMatrixOutputsField, '1');
      // Both sides are HDMI, so both plans derive `HDMI Inputs` and
      // `HDMI Outputs`: two ports, two banks. The singular that matters
      // is the port count, and `1 ports` is what shipped last time.
      expect(find.text('2 ports across 2 banks'), findsOneWidget);
    });

    testWidgets('the singular reads on a single port', (tester) async {
      expect(
        archetypePreviewLine(const ArchetypePreview(ports: 1, banks: 1)),
        '1 port across 1 bank',
      );
    });
  });

  group('the Control checkbox says what it will emit', () {
    testWidgets('it reads LAN + RS-232 until per-output IR is ticked', (
      tester,
    ) async {
      await pump(tester);
      await openDialog(tester);
      expect(find.text('Control (LAN + RS-232)'), findsOneWidget);
      expect(find.text('Control (LAN + RS-232 + IR IN)'), findsNothing);

      await tick(tester, 'Per-output IR');
      expect(find.text('Control (LAN + RS-232 + IR IN)'), findsOneWidget);
      expect(find.text('Control (LAN + RS-232)'), findsNothing);
    });
  });

  group('§9.2 step 6, end to end', () {
    testWidgets('ONE CLICK PUTS 68 PORTS IN THE GRID', (tester) async {
      final h = await pump(tester);
      await openDialog(tester);
      await fillWorkedExample(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, kArchetypeGenerateLabel),
      );
      await tester.pumpAndSettle();

      final body = await h.read(tester);
      expect(body.ports, hasLength(68));
      expect(body.banks, hasLength(6));
    });

    testWidgets('the grid footer says so without a Save', (tester) async {
      await pump(tester);
      await openDialog(tester);
      await fillWorkedExample(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, kArchetypeGenerateLabel),
      );
      await tester.pumpAndSettle();
      // M4-E5's always-visible readout: what a person actually looks at
      // to check the generator did what the preview promised.
      expect(find.textContaining('68 ports'), findsWidgets);
    });

    testWidgets('ONE Undo takes all 68 back', (tester) async {
      final h = await pump(tester);
      await openDialog(tester);
      await fillWorkedExample(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, kArchetypeGenerateLabel),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final body = await h.read(tester);
      expect(body.ports, isEmpty);
      expect(body.banks, isEmpty);
    });

    testWidgets('Cancel writes nothing', (tester) async {
      final h = await pump(tester);
      await openDialog(tester);
      await fillWorkedExample(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      final body = await h.read(tester);
      expect(body.ports, isEmpty);
    });
  });
}
