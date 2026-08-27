// The one `TextMeasurer` the app's widget tests render through.
//
// Built from the bundled Jost TTF read via `dart:io`, exactly as
// `widget_test.dart` and `baseline_parity_test.dart` already do: the rack
// scene needs REAL font metrics to lay out, and an async `rootBundle`
// font load inside a widget test tree is a source of flake that buys
// nothing. Factored out here so a third and fourth test file do not each
// grow their own copy.
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';

/// A real measurer over the bundled Jost Regular (CR-081).
TextMeasurer loadTestMeasurer() {
  final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
  return PdfFontMeasurer.fromBytes(PdfDocument(), {
    const FontRef('Jost'): bytes,
  });
}
