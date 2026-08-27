// #96-A/1 — the rotation contract, gated before anything relies on it.
//
// ═══════════════════════════════════════════════════════════════════════
// AN OPEN QUESTION THE CORPUS RAISED AND NOBODY COULD CLOSE
// ═══════════════════════════════════════════════════════════════════════
// `TextStyleSpec.rotationRad` has existed since the draw IR was designed,
// is implemented by `BoundsCanvas`, `PdfDiagramCanvas` and
// `FlutterDiagramCanvas`, and has been set to ZERO by every caller in the
// product for the whole of M0-M2. `design-pdf-export.md`'s own
// open-questions list says what that costs:
//
//   > The rotation sign in `drawText`'s counter-flip matrix. Render
//   > [text] on both backends, overlay them, and confirm they rotate the
//   > same way. **Sign errors here are invisible until someone rotates a
//   > label.**
//
// #96-A is someone rotating a label. So the contract is pinned here FIRST,
// in its own commit, before the symbol layer depends on it — because a sign
// error found afterwards looks like a layout bug in the symbol rather than
// a disagreement between two backends.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT IS BEING PINNED
// ═══════════════════════════════════════════════════════════════════════
// Two clauses, both from `TextStyleSpec`'s own doc:
//
//   1. POSITIVE IS CLOCKWISE, matching `DiagramCanvas.rotate`. In diagram
//      space +y is DOWN, so a clockwise quarter turn sends +x to +y.
//   2. ROTATION IS ABOUT THE ANCHOR POINT, not about the baseline origin
//      and not about the run's centre. That is what makes an anchor plus an
//      angle a complete description of where a run lands, and it is the
//      property `symbol_layer` relies on to put a label beside a pin.
//
// The Flutter backend is NOT asserted here and that is deliberate rather
// than an omission: it has no transform recorder, and the schematic goldens
// are rendered through it. A sign error there shows up as every top-edge
// label rendering into the symbol body instead of away from it, which the
// golden catches more loudly than a unit test would.

import 'dart:math' as math;

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// Linear metrics, so every expectation below is arithmetic rather than a
/// number read off a font file.
final class _LinearMeasurer implements TextMeasurer {
  const _LinearMeasurer();

  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt,
    ascent: style.sizePt,
    descent: 0,
    capHeight: style.sizePt,
    xHeight: style.sizePt / 2,
    lineHeight: style.sizePt,
  );
}

/// The ink box of one run drawn at [at].
///
/// `baselineLeft` puts `anchorOffset` at (0, 0), so the unrotated box is
/// exactly `at` -> `at + (width, -ascent)` and every rotated expectation is
/// that box turned about `at`.
DBox _inkOf({
  required DPt at,
  required double rotationRad,
  TextAnchor anchor = TextAnchor.baselineLeft,
  String text = 'ABCD',
  double sizePt = 10,
}) {
  const measurer = _LinearMeasurer();
  final canvas = BoundsCanvas(measurer: measurer)
    ..drawText(
      text,
      at,
      TextStyleSpec(
        font: const FontRef('Jost'),
        sizePt: sizePt,
        argb: 0xFF000000,
        anchor: anchor,
        rotationRad: rotationRad,
      ),
    );
  return canvas.bounds!;
}

void _closeTo(DBox actual, DBox expected, {double tolerance = 0.001}) {
  expect(actual.left, closeTo(expected.left, tolerance), reason: 'left');
  expect(actual.top, closeTo(expected.top, tolerance), reason: 'top');
  expect(actual.right, closeTo(expected.right, tolerance), reason: 'right');
  expect(actual.bottom, closeTo(expected.bottom, tolerance), reason: 'bottom');
}

void main() {
  const at = DPt(100, 100);
  // 4 glyphs x 10 pt = 40 wide, ascent 10, descent 0.
  const width = 40.0;
  const ascent = 10.0;

  group('the unrotated box is what the rotated ones are turned from', () {
    test('baselineLeft runs right from the anchor and up by the ascent', () {
      _closeTo(
        _inkOf(at: at, rotationRad: 0),
        const DBox.fromLtwh(100, 100 - ascent, width, ascent),
      );
    });
  });

  group('positive is CLOCKWISE, and +y is down', () {
    test('a quarter turn clockwise sends the run DOWN the page', () {
      // +x -> +y. The run leaves the anchor heading down, and the ascent —
      // which pointed up (-y) — now points right (+x). So the box is tall
      // and narrow, starting at the anchor and descending.
      _closeTo(
        _inkOf(at: at, rotationRad: math.pi / 2),
        const DBox.fromLtwh(100, 100, ascent, width),
      );
    });

    test('a quarter turn ANTICLOCKWISE sends the run UP the page', () {
      // THE ONE #96-A USES. A top-edge port label must climb away from the
      // symbol body, and the body is below a top-edge pin.
      _closeTo(
        _inkOf(at: at, rotationRad: -math.pi / 2),
        const DBox.fromLtwh(100 - ascent, 100 - width, ascent, width),
      );
    });

    test('half a turn mirrors the run through the anchor', () {
      _closeTo(
        _inkOf(at: at, rotationRad: math.pi),
        const DBox.fromLtwh(100 - width, 100, width, ascent),
      );
    });

    test('and the two quarter turns are NOT the same box, which is the '
        'whole point of a sign', () {
      // A sign error makes these identical or swaps them. Stated as its own
      // assertion because both of the tests above could be satisfied by a
      // measurer that ignored rotation entirely IF the box happened to be
      // square — it is not, but nothing above says so.
      expect(
        _inkOf(at: at, rotationRad: math.pi / 2),
        isNot(equals(_inkOf(at: at, rotationRad: -math.pi / 2))),
      );
    });
  });

  group('rotation is about the ANCHOR, not the baseline origin', () {
    test('a centred anchor turns about the anchor, so the run straddles '
        'it', () {
      // `midCenter` puts the anchor in the middle of the run. Turned a
      // quarter clockwise the box must still straddle `at` — if the
      // implementation rotated about the BASELINE ORIGIN instead, the box
      // would swing off to one side.
      final box = _inkOf(
        at: at,
        rotationRad: math.pi / 2,
        anchor: TextAnchor.midCenter,
      );
      expect(box.left, lessThan(at.x));
      expect(box.right, greaterThan(at.x));
      expect(box.top, lessThan(at.y));
      expect(box.bottom, greaterThan(at.y));
      // Tall and narrow after the turn, not wide and short.
      expect(box.height, greaterThan(box.width));
    });

    test('an unrotated midCenter run is wide and short, so the turn is what '
        'changed it', () {
      final box = _inkOf(
        at: at,
        rotationRad: 0,
        anchor: TextAnchor.midCenter,
      );
      expect(box.width, greaterThan(box.height));
    });
  });

  group('rackText carries the angle through', () {
    test('it defaults to zero and passes what it is given', () {
      expect(
        rackText(
          RackTextSizes.type,
          0xFF000000,
          TextAnchor.midLeft,
        ).rotationRad,
        0,
      );
      expect(
        rackText(
          RackTextSizes.type,
          0xFF000000,
          TextAnchor.midLeft,
          rotationRad: -math.pi / 2,
        ).rotationRad,
        closeTo(-math.pi / 2, 1e-12),
      );
    });

    test('and the angle participates in equality, so a cached run cannot '
        'serve a rotated one', () {
      // `text_run_cache.dart` keys on the style. Two styles differing only
      // in rotation MUST NOT compare equal, or the schematic would paint a
      // horizontal label from the cache where a rotated one was asked for.
      final flat = rackText(8, 0xFF000000, TextAnchor.midLeft);
      final turned = rackText(
        8,
        0xFF000000,
        TextAnchor.midLeft,
        rotationRad: -math.pi / 2,
      );
      expect(flat == turned, isFalse);
      expect(flat.hashCode == turned.hashCode, isFalse);
    });
  });
}
