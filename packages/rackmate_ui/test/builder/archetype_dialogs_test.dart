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
      // `Paste` is M4-I3 and has no button until it has a dialog.
      await pump(tester);
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

  group('Switch ports (M4-I2, #221)', () {
    Future<void> openSwitch(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(OutlinedButton, 'Switch ports…'));
      await tester.pumpAndSettle();
    }

    Future<void> generate(WidgetTester tester) async {
      await tester.tap(
        find.widgetWithText(FilledButton, kArchetypeGenerateLabel),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the button is beside Matrix I/O', (tester) async {
      await pump(tester);
      expect(
        find.widgetWithText(OutlinedButton, 'Switch ports…'),
        findsOneWidget,
      );
    });

    testWidgets('it opens ready to generate, unlike the matrix', (
      tester,
    ) async {
      // An access port is RJ45 Ethernet on every switch there has ever
      // been, so the picker is pre-filled and Generate is live. The
      // matrix has no such single answer for either side.
      await pump(tester);
      await openSwitch(tester);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, kArchetypeGenerateLabel),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('28 ports across 2 banks'), findsOneWidget);
    });

    testWidgets('THE DEFAULT IS A 24-PORT SWITCH WITH FOUR UPLINKS', (
      tester,
    ) async {
      final h = await pump(tester);
      await openSwitch(tester);
      await generate(tester);
      final body = await h.read(tester);
      expect(body.ports, hasLength(28));
      expect(body.banks.map((b) => b.label), <String>[
        'Access Ports',
        'Uplinks',
      ]);
    });

    testWidgets('Redundant PSU is disabled, and says why', (tester) async {
      await pump(tester);
      await openSwitch(tester);
      expect(find.text(kSwitchRedundantNeedsInlet), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(
                CheckboxListTile,
                'Redundant PSU (PSU A + PSU B)',
              ),
            )
            .onChanged,
        isNull,
      );
    });

    testWidgets('ticking AC inlet enables it and the reason goes', (
      tester,
    ) async {
      await pump(tester);
      await openSwitch(tester);
      await tick(tester, 'AC inlet (C14)');
      expect(find.text(kSwitchRedundantNeedsInlet), findsNothing);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(
                CheckboxListTile,
                'Redundant PSU (PSU A + PSU B)',
              ),
            )
            .onChanged,
        isNotNull,
      );
    });

    testWidgets('the SFP dropdown names the rate the cage IS', (tester) async {
      // A person picking a cage is picking a speed, and `SFP+` alone
      // makes them look it up.
      expect(switchSfpChoiceLabel(SfpFormFactor.sfp), 'SFP (1 Gb/s)');
      expect(switchSfpChoiceLabel(SfpFormFactor.sfpPlus), 'SFP+ (10 Gb/s)');
      expect(switchSfpChoiceLabel(SfpFormFactor.sfp28), 'SFP28 (25 Gb/s)');
    });

    testWidgets('link speed reads in Gb/s above a thousand', (tester) async {
      expect(switchLinkSpeedLabel(100), '100 Mb/s');
      expect(switchLinkSpeedLabel(1000), '1 Gb/s');
      expect(switchLinkSpeedLabel(2500), '2500 Mb/s');
      expect(switchLinkSpeedLabel(10000), '10 Gb/s');
      expect(switchLinkSpeedLabel(null), 'Unknown');
    });

    testWidgets('the PoE row appears only when PoE is ticked', (tester) async {
      await pump(tester);
      await openSwitch(tester);
      expect(find.byKey(kSwitchPoeClassField), findsNothing);
      await tick(tester, 'PoE on the access ports');
      expect(find.byKey(kSwitchPoeClassField), findsOneWidget);
    });

    testWidgets('N01 END TO END: 56 PORTS ACROSS 4 BANKS', (tester) async {
      final h = await pump(tester);
      await openSwitch(tester);
      await count(tester, kSwitchAccessField, '48');
      await tick(tester, 'PoE on the access ports');
      await tick(tester, 'Management port (RJ45)');
      await tick(tester, 'Console (RS-232, front panel)');
      await tick(tester, 'AC inlet (C14)');
      await tick(tester, 'Redundant PSU (PSU A + PSU B)');
      expect(find.text('56 ports across 4 banks'), findsOneWidget);

      await generate(tester);
      final body = await h.read(tester);
      expect(body.ports, hasLength(56));
      expect(body.ports.where((p) => p.face == Face.front), hasLength(1));
      expect(
        body.ports.singleWhere((p) => p.face == Face.front).label,
        'CONSOLE',
      );
    });

    testWidgets('ONE Undo takes the whole switch back', (tester) async {
      final h = await pump(tester);
      await openSwitch(tester);
      await generate(tester);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      final body = await h.read(tester);
      expect(body.ports, isEmpty);
      expect(body.banks, isEmpty);
    });

    testWidgets('a switch and a matrix can share one template', (
      tester,
    ) async {
      // The batch allocator across TWO generators rather than across six
      // plans: nothing here may mint a key the other already took.
      final h = await pump(tester);
      await openSwitch(tester);
      await generate(tester);
      await openDialog(tester);
      await fillWorkedExample(tester);
      await generate(tester);

      final body = await h.read(tester);
      expect(body.ports, hasLength(28 + 68));
      expect(body.ports.map((p) => p.key.v).toSet(), hasLength(96));
      expect(
        body.banks.map((b) => b.key).toSet(),
        hasLength(body.banks.length),
      );
    });
  });
}
