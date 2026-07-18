import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackmate/main.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

void main() {
  // A real measurer from the bundled TTF (read via dart:io, as the sibling
  // baseline_parity_test does) so the injected `RackMateApp` renders the rack
  // scene without an async font load in the test tree.
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/IBMPlexSans-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('IBM Plex Sans'): bytes,
    });
  });

  testWidgets('RackMateApp renders the rack canvas with a zoom readout', (
    tester,
  ) async {
    await tester.pumpWidget(RackMateApp(measurer: measurer));

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
    await tester.pumpWidget(RackMateApp(measurer: measurer));

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
