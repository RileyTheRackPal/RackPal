import 'dart:io';

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'session/session_fakes.dart';

void main() {
  // A real measurer from the bundled TTF (read via dart:io, as the sibling
  // baseline_parity_test does) so the injected `RackMateApp` renders the rack
  // scene without an async font load in the test tree.
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('Jost'): bytes,
    });
  });

  // A REALISTIC WINDOW, required as of the rack-configuration stage: the
  // screen now lays out docs/04 §1's four columns (palette 280 | canvas |
  // inspector 320), so on the default 800x600 test surface the canvas is
  // ~198 logical pixels wide and its floating chrome — the zoom HUD, the new
  // rack header, the Front/Rear toggle — overlap each other. §1 treats
  // anything under 1080px as the (unbuilt) tablet-collapse case, so this
  // states the supported size rather than relying on a default that happened
  // to work while there were only two columns.
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

  testWidgets('RackMateApp renders the rack canvas with a zoom readout', (
    tester,
  ) async {
    await tester.pumpWidget((await buildTestApp(measurer)).app);

    // M1: the pannable/zoomable canvas now hosts a rack and devices; the HUD
    // shows the live zoom at 100% on the first frame.
    expect(find.byType(RackCanvasScreen), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    // The demo devices expose real Semantics (CR-086 / docs/04 §9): the
    // front face shows AMP-1, whose accessible label is present.
    expect(
      find.bySemanticsLabel(RegExp('AMP-1')),
      findsOneWidget,
    );
  });

  testWidgets('the Front/Rear toggle swaps which devices are shown', (
    tester,
  ) async {
    await tester.pumpWidget((await buildTestApp(measurer)).app);

    // Front face: AMP-1 is present, the rear-only PP-1 is not.
    expect(find.bySemanticsLabel(RegExp('AMP-1')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('PP-1')), findsNothing);

    // Switch to Rear.
    await tester.tap(find.text('Rear'));
    await tester.pumpAndSettle();

    // Rear face: PP-1 appears, AMP-1 is gone.
    expect(find.bySemanticsLabel(RegExp('PP-1')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('AMP-1')), findsNothing);
  });
}
