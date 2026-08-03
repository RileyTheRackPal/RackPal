// CR-082's TWO KNOBS, on the SCREEN backend, at a scale != 1.
//
// =====================================================================
// WHY THIS FILE EXISTS, AND WHY IT EXISTS TWICE
// =====================================================================
// `Stroke.scaleWithGeometry` had ZERO readers on either backend: both
// branched on `hairlineFloor` alone for the width decision as well as the
// floor decision. `rackmate_export/test/stroke_scaling_test.dart` is the
// PDF half of the fix's proof.
//
// The screen half needs its own test, and a mutation is what said so:
// reverting `_strokePaint` to the coupled spelling while leaving the PDF
// backend fixed passed the entire `rackmate_ui` suite. A fix that is
// asserted on one of two backends is a fix that will come back on the
// other, which is precisely the divergence CR-086 exists to prevent.
//
// Asserted on the `ui.Paint` that actually reaches the canvas, through
// `flutter_test`'s own `TestRecordingCanvas`, rather than on the stroke
// value that went in.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// The scale the elevation sheets really use at 1:8: `126 / (22 * 8)`.
const double _k = 126 / (22 * 8);

/// A matcher tolerant of `ui.Paint`'s FLOAT32 ROUND TRIP.
///
/// `Paint.strokeWidth`'s getter reconstructs its value from a
/// float32-precision native store, exactly as `Paint.color` does — which
/// is why `editing_overlay_painter_test.dart` carries its own
/// `_colorsMatch` rather than using `==`. So 2.7936507936507935 comes back
/// as 2.7936508655548096, a relative error of 2.6e-8.
///
/// The tolerance is therefore set from float32's own ~1.2e-7 epsilon and
/// NOT tuned: at 1e-6 relative it is fifty times smaller than the smallest
/// difference any assertion here turns on (the coupled and decoupled
/// spellings differ by a factor of 1/k = 1.396).
Matcher _closeToPaint(double expected) =>
    closeTo(expected, expected.abs() * 1e-6 + 1e-9);

void main() {
  late PdfFontMeasurer measurer;

  setUpAll(() {
    final bytes = File(
      '../../apps/rackmate/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), <FontRef, Uint8List>{
      const FontRef('Jost'): bytes,
    });
  });

  /// The `strokeWidth` that reaches the canvas for [stroke], drawn inside a
  /// `scale([scale])` bracket.
  double widthOnCanvas(Stroke stroke, {double scale = _k}) {
    final recording = TestRecordingCanvas();
    FlutterDiagramCanvas(recording, measurer: measurer)
      ..save()
      ..scale(scale)
      ..drawRect(const DBox.fromLtwh(0, 0, 100, 100), stroke: stroke)
      ..restore();

    // A STROKED rect reaches `ui.Canvas` as `drawPath`, not `drawRect` —
    // `FlutterDiagramCanvas.drawRect` builds a `ui.Path` so the dash
    // synthesis has something to walk. Asserting on the call that is
    // actually made rather than the one the name suggests is the
    // difference between measuring the paint and measuring nothing.
    final drawn = recording.invocations
        .where((i) => i.invocation.memberName == #drawPath)
        .toList();
    expect(drawn, hasLength(1), reason: 'nothing was drawn to measure');
    return (drawn.single.invocation.positionalArguments[1] as ui.Paint)
        .strokeWidth;
  }

  group('scaleWithGeometry decides whether the WIDTH scales', () {
    test('true (the default): the width scales with the drawing', () {
      // Under a `scale(k)` canvas the emitted width is the MODEL width; the
      // canvas transform is what thins it on the way to pixels.
      expect(
        widthOnCanvas(const Stroke(argb: 0xFF000000, widthPt: 2)),
        _closeToPaint(2),
      );
    });

    test('FALSE: the width is pre-divided so it is CONSTANT after the '
        'transform — the assertion the old backend failed', () {
      // 2 / 0.71591 = 2.7936. Before the fix this returned 2, because the
      // width decision read `hairlineFloor` and this stroke does not set
      // it.
      expect(
        widthOnCanvas(
          const Stroke(
            argb: 0xFF000000,
            widthPt: 2,
            scaleWithGeometry: false,
          ),
        ),
        _closeToPaint(2 / _k),
      );
    });

    test('the two spellings COINCIDE at scale 1 — which is why nothing '
        'moved on screen', () {
      for (final scaleWithGeometry in <bool>[true, false]) {
        expect(
          widthOnCanvas(
            Stroke(
              argb: 0xFF000000,
              widthPt: 1.4,
              scaleWithGeometry: scaleWithGeometry,
            ),
            scale: 1,
          ),
          _closeToPaint(1.4),
          reason: 'scaleWithGeometry: $scaleWithGeometry',
        );
      }
    });
  });

  group('hairlineFloor decides WHICH FLOOR, independently', () {
    test('signal geometry floors at 0.5 pt of ink', () {
      // 0.3 * 0.71591 = 0.215 on screen, under the 0.5 pt signal floor, so
      // the emitted width is raised to `0.5 / k`.
      expect(
        widthOnCanvas(const Stroke(argb: 0xFF000000, widthPt: 0.3)),
        _closeToPaint(0.5 / _k),
      );
    });

    test('furniture floors at 0.25 pt of ink', () {
      expect(
        widthOnCanvas(
          const Stroke(
            argb: 0xFF000000,
            widthPt: 0.1,
            scaleWithGeometry: false,
            hairlineFloor: true,
          ),
        ),
        _closeToPaint(0.25 / _k),
      );
    });

    test('the two knobs are INDEPENDENT: a scaling stroke can still take '
        'the furniture floor', () {
      // The combination that proves the coupling is gone. 0.3 pt scaling
      // geometry lands at 0.215 on screen — over the 0.25 furniture floor
      // it is clamped, and the clamp is what a coupled implementation
      // could not express separately from the width rule.
      expect(
        widthOnCanvas(
          const Stroke(argb: 0xFF000000, widthPt: 0.3, hairlineFloor: true),
        ),
        _closeToPaint(0.25 / _k),
      );
      // ...while a coarse one is left alone AND scaled.
      expect(
        widthOnCanvas(
          const Stroke(argb: 0xFF000000, widthPt: 1, hairlineFloor: true),
        ),
        _closeToPaint(1),
      );
    });

    test('NO STROKE IS EVER EMITTED AT ZERO (CR-082)', () {
      for (final width in <double>[0, 0.0001, 0.01]) {
        for (final floor in <bool>[true, false]) {
          expect(
            widthOnCanvas(
                  Stroke(
                    argb: 0xFF000000,
                    widthPt: width,
                    hairlineFloor: floor,
                  ),
                ) *
                _k,
            greaterThanOrEqualTo(0.25 - 1e-9),
            reason: 'width $width, hairlineFloor $floor',
          );
        }
      }
    });
  });
}
