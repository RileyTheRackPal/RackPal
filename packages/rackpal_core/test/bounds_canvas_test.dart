// Unit tests for `BoundsCanvas` (draw/bounds_canvas.dart) — the third
// `DiagramCanvas` backend (CR-089). Pure Dart, no Flutter.
//
// A bounds pass is only worth anything if it is TIGHT in the directions
// that matter and never SMALLER than the ink: too large wastes page, too
// small clips the drawing. So every test here asserts an exact box, and the
// cases that earn their keep are the ones where the naive answer is wrong —
// a stroke straddling an edge, a text run anchored so it extends backwards
// from its own anchor point, ink under a transform, ink removed by a clip.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

/// ~0.55 em per character, matching the other draw suites' fake so the
/// numbers here can be checked by hand.
final class _FakeMeasurer implements TextMeasurer {
  const _FakeMeasurer();

  static const double _emPerChar = 0.55;

  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * _emPerChar,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

DBox? _of(List<DiagramOp> ops) =>
    inkBoundsOf(ops, measurer: const _FakeMeasurer());

void _expectBox(DBox? actual, DBox expected) {
  expect(actual, isNotNull);
  expect(actual!.left, closeTo(expected.left, 1e-9), reason: 'left');
  expect(actual.top, closeTo(expected.top, 1e-9), reason: 'top');
  expect(actual.right, closeTo(expected.right, 1e-9), reason: 'right');
  expect(actual.bottom, closeTo(expected.bottom, 1e-9), reason: 'bottom');
}

void main() {
  group('nothing drawn', () {
    test('is null, not an empty box at the origin', () {
      // The distinction is load-bearing: a caller that unions an empty box
      // at (0,0) into a page that starts at (500,500) drags the page origin
      // back to zero and scales the drawing to a quarter of the sheet.
      expect(_of(const []), isNull);
      expect(BoundsCanvas(measurer: const _FakeMeasurer()).bounds, isNull);
    });

    test('an empty string draws no ink', () {
      expect(
        _of([
          OpText('', const DPt(50, 50), rackText(10, 0, TextAnchor.topLeft)),
        ]),
        isNull,
      );
    });
  });

  group('primitives', () {
    test('a filled rect is exactly its rect', () {
      _expectBox(
        _of(const [
          OpRect(DBox.fromLtwh(10, 20, 30, 40), fill: Fill(0xFF000000)),
        ]),
        const DBox.fromLtwh(10, 20, 30, 40),
      );
    });

    test('a STROKED rect grows by half the stroke width on every edge — a '
        'stroke straddles the path, it does not sit inside it', () {
      _expectBox(
        _of(const [
          OpRect(
            DBox.fromLtwh(0, 0, 100, 50),
            stroke: Stroke(argb: 0xFF000000, widthPt: 4),
          ),
        ]),
        const DBox.fromLtwh(-2, -2, 104, 54),
      );
    });

    test('a circle is its centre plus or minus the radius', () {
      _expectBox(
        _of(const [OpCircle(DPt(100, 100), 8, fill: Fill(0xFF000000))]),
        const DBox.fromLtwh(92, 92, 16, 16),
      );
    });

    test('a line covers both endpoints regardless of direction', () {
      _expectBox(
        _of(const [
          OpLine(DPt(80, 90), DPt(10, 20), Stroke(argb: 0, widthPt: 0)),
        ]),
        const DBox.fromLtwh(10, 20, 70, 70),
      );
    });

    test('an ellipse uses both radii', () {
      _expectBox(
        _of(const [OpEllipse(DPt(0, 0), 5, 9, fill: Fill(0xFF000000))]),
        const DBox.fromLtwh(-5, -9, 10, 18),
      );
    });

    test('a path covers every referenced coordinate', () {
      _expectBox(
        _of(const [
          OpPath(
            DiagramPath([MoveTo(-3, -3), LineTo(7, 0), LineTo(-3, 3)]),
            fill: Fill(0xFF000000),
          ),
        ]),
        const DBox.fromLtwh(-3, -3, 10, 6),
      );
    });

    test('a polyline covers every point', () {
      _expectBox(
        _of(const [
          OpPolyline([
            DPt(0, 0),
            DPt(30, -10),
            DPt(15, 40),
          ], Stroke(argb: 0, widthPt: 0)),
        ]),
        const DBox.fromLtwh(0, -10, 30, 50),
      );
    });
  });

  group('text', () {
    // 10pt, 5 chars -> advance 27.5; ascent 7.5, descent 2.5.
    const text = 'HELLO';
    const size = 10.0;
    const advance = 27.5;

    test('topLeft anchors the box below and right of the anchor point', () {
      _expectBox(
        _of([
          OpText(
            text,
            const DPt(100, 200),
            rackText(size, 0, TextAnchor.topLeft),
          ),
        ]),
        const DBox.fromLtwh(100, 200, advance, 10),
      );
    });

    test('midRight extends BACKWARDS from its anchor, and the box says so', () {
      // The rack ruler is drawn this way; a bounds pass that assumed text
      // grows right and down from the anchor would report the ruler column
      // as empty.
      _expectBox(
        _of([
          OpText(
            text,
            const DPt(24, 50),
            rackText(size, 0, TextAnchor.midRight),
          ),
        ]),
        const DBox.fromLtwh(24 - advance, 45, advance, 10),
      );
    });

    test('bottomCenter sits ABOVE the anchor, centred on it — the exact '
        'case that puts a symbol port label outside the body', () {
      _expectBox(
        _of([
          OpText(
            text,
            const DPt(0, 0),
            rackText(size, 0, TextAnchor.bottomCenter),
          ),
        ]),
        const DBox.fromLtwh(-advance / 2, -10, advance, 10),
      );
    });

    test('a rotated run is measured through its rotated hull', () {
      // A quarter turn about the anchor: the run that spanned 27.5 across
      // and 10 down now spans 10 across and 27.5 down.
      final box = _of([
        const OpText(
          text,
          DPt(0, 0),
          TextStyleSpec(
            font: kRackFont,
            sizePt: size,
            argb: 0,
            anchor: TextAnchor.topLeft,
            rotationRad: 3.141592653589793 / 2,
          ),
        ),
      ]);
      _expectBox(box, const DBox.fromLtwh(-10, 0, 10, advance));
    });
  });

  group('transform and state stack', () {
    test('a translate moves the ink, and restore undoes it', () {
      _expectBox(
        _of([
          const OpRect(DBox.fromLtwh(0, 0, 10, 10), fill: Fill(0xFF000000)),
          const OpSave(),
          OpTransform(Matrix4.translationValues(100, 200, 0)),
          const OpRect(DBox.fromLtwh(0, 0, 10, 10), fill: Fill(0xFF000000)),
          const OpRestore(),
          const OpRect(DBox.fromLtwh(-5, -5, 1, 1), fill: Fill(0xFF000000)),
        ]),
        const DBox.fromLtwh(-5, -5, 115, 215),
      );
    });

    test('a rotation is hulled from all four corners, not two', () {
      // 45 degrees about the origin: a 10x10 box at the origin becomes a
      // diamond 14.14 wide. Mapping only two corners would report 10.
      final box = _of([
        OpTransform(Matrix4.rotationZ(3.141592653589793 / 4)),
        const OpRect(DBox.fromLtwh(-5, -5, 10, 10), fill: Fill(0xFF000000)),
      ]);
      expect(box!.width, closeTo(14.142135623730951, 1e-9));
      expect(box.height, closeTo(14.142135623730951, 1e-9));
    });

    test('a scale scales the ink', () {
      _expectBox(
        _of([
          OpTransform(Matrix4.diagonal3Values(2, 3, 1)),
          const OpRect(DBox.fromLtwh(1, 1, 10, 10), fill: Fill(0xFF000000)),
        ]),
        const DBox.fromLtwh(2, 3, 20, 30),
      );
    });
  });

  group('clipping', () {
    test('ink a clipRect removes is not counted', () {
      _expectBox(
        _of(const [
          OpClipRect(DBox.fromLtwh(0, 0, 50, 50)),
          OpRect(DBox.fromLtwh(-100, -100, 300, 300), fill: Fill(0xFF000000)),
        ]),
        const DBox.fromLtwh(0, 0, 50, 50),
      );
    });

    test('a clip is undone by restore', () {
      _expectBox(
        _of(const [
          OpSave(),
          OpClipRect(DBox.fromLtwh(0, 0, 10, 10)),
          OpRect(DBox.fromLtwh(0, 0, 100, 100), fill: Fill(0xFF000000)),
          OpRestore(),
          OpRect(DBox.fromLtwh(0, 0, 100, 100), fill: Fill(0xFF000000)),
        ]),
        const DBox.fromLtwh(0, 0, 100, 100),
      );
    });

    test('ink entirely outside the clip contributes nothing at all', () {
      expect(
        _of(const [
          OpClipRect(DBox.fromLtwh(0, 0, 10, 10)),
          OpRect(DBox.fromLtwh(500, 500, 10, 10), fill: Fill(0xFF000000)),
        ]),
        isNull,
      );
    });
  });

  test('an unbalanced restore does not throw — a cosmetic defect must not '
      'crash an export', () {
    expect(
      _of(const [
        OpRestore(),
        OpRect(DBox.fromLtwh(0, 0, 5, 5), fill: Fill(0xFF000000)),
      ]),
      const DBox.fromLtwh(0, 0, 5, 5),
    );
  });

  test('measureText delegates to the injected measurer (CR-081)', () {
    final canvas = BoundsCanvas(measurer: const _FakeMeasurer());
    final style = rackText(10, 0, TextAnchor.topLeft);
    expect(
      canvas.measureText('abc', style).advanceWidth,
      const _FakeMeasurer().measureText('abc', style).advanceWidth,
    );
  });
}
