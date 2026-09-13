// The palette, in the real shell (`#885`, DR-165 §11.164).
//
// ═══════════════════════════════════════════════════════════════════════
// THIS IS THE HALF `rackpal_ui` CANNOT PROVE
// ═══════════════════════════════════════════════════════════════════════
// `test/canvas/rack_with_palette.dart` composes a palette and a canvas the
// way this shell composes them, and every palette case in that package
// pumps it. **A helper that mirrors a host proves the two agree with each
// other**, which is the shape
// `.okf/practices/a-surface-tested-alone-has-no-host.md` was written
// about: the Outlets tab had two green files and neither mounted it.
//
// So these cases ask the questions only the real `AppShell` can answer.
// Which views carry a column. Whether the state behind it survives a tab
// change, which is the whole reason there is one host rather than two.
// And whether a palette row activated on the Plan tab reaches the plan
// editor at all, which is `armPaletteDrag`'s own comment finally coming
// true: it was public for four milestones so "the host that owns a palette
// hands the armed pointer down", and all three of its call sites were
// tests.
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
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Finder palette() => find.byType(DevicePalettePanel);

  testWidgets('THE TWO VIEWS THAT PLACE A DEVICE HAVE A COLUMN, and the '
      'five that do not, do not', (tester) async {
    await tester.pumpWidget((await buildTestApp(measurer)).app);

    // The app opens on the Rack tab.
    expect(palette(), findsOneWidget, reason: 'the Rack tab places on rails');

    await openTab(tester, 'Plan');
    expect(
      palette(),
      findsOneWidget,
      reason:
          'THE WHOLE TICKET. docs/15 §6 opens its gesture table with '
          '"drag from the device palette onto the plan", and until now the '
          'palette was not on screen when this tab was',
    );

    for (final absent in const [
      'Locations',
      'Device Manager',
      'Structured Wiring',
      'Schematic',
      'Schedule',
    ]) {
      await openTab(tester, absent);
      expect(
        palette(),
        findsNothing,
        reason:
            '$absent has no device placement gesture, and a palette '
            'beside it is a control that cannot act on anything in view '
            '(docs/04 §3.4)',
      );
    }
  });

  testWidgets('ONE HOST, so a filter typed on one tab is still there on the '
      'other', (tester) async {
    // The reason the column is placed by each view while the STATE lives
    // above the tab view. A host per tab would be two search queries, and
    // the filter a person typed before switching would be gone when they
    // arrived.
    await tester.pumpWidget((await buildTestApp(measurer)).app);

    await tester.enterText(find.byType(TextField).first, 'matrix');
    await tester.pumpAndSettle();

    await openTab(tester, 'Plan');

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'matrix',
      reason: 'the same host, so the same controller',
    );
  });

  testWidgets('A PALETTE REFUSAL LANDS ON THE CANVAS STATUS LINE, not in a '
      'snack bar', (tester) async {
    // ═══════════════════════════════════════════════════════════════════
    // FOUND BY A MUTATION, AND IT IS A REAL REGRESSION RISK
    // ═══════════════════════════════════════════════════════════════════
    // "No device matches" was `onRefuse: _status.show` for four
    // milestones, read mid-keystroke a few inches from the field it is
    // about. The palette is the shell's now, and the obvious wiring is
    // the shell's own refusal channel, which is a snack bar: that would
    // cover the canvas to say something about the search box. So the host
    // asks the OPEN CANVAS where its refusals go, exactly as it asks it
    // to place and to arm, and this is what holds that in place.
    await tester.pumpWidget((await buildTestApp(measurer)).app);

    await tester.enterText(find.byType(TextField).first, 'zzzznothing');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('No device matches'), findsOneWidget);
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason:
          'the rack has a status line, and a snack bar would cover the '
          'canvas to say something about the search box',
    );
  });

  testWidgets('A ROW ACTIVATED ON THE PLAN TAB REACHES THE PLAN EDITOR, '
      'which refuses it by name', (tester) async {
    // docs/15 §6's gesture is a DRAG, because the act places the device
    // AND sets its pin in one command: a floorplan has no caret and no
    // default spot, so an activated row has nowhere to mean. What this
    // case proves is the ROUTE — that the shell's dispatch reaches
    // `PlanEditorScreenState` rather than the rack screen or nothing.
    final built = await buildTestApp(measurer);
    await tester.pumpWidget(built.app);
    await openTab(tester, 'Plan');

    final before = built.session.services.session.document.devices.length;
    // THE FILTER-AND-ENTER PATH, which docs/04 §3.2 makes equal to a
    // double-click and which a widget test can drive without a
    // double-tap recognizer's timer.
    await tester.enterText(find.byType(TextField).first, 'HDMI Matrix 4x4');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Drag HDMI Matrix 4x4 onto the plan'),
      findsOneWidget,
    );
    expect(
      built.session.services.session.document.devices,
      hasLength(before),
      reason: 'a refusal writes nothing',
    );
  });
}
