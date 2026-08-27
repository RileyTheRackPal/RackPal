// DR-089, board #769. What these tests defend is not "the path parses".
//
// The wordmark has no reader. Nobody opens the app to check the logo, and
// a mangled one still renders as SOMETHING, which is why an identity is
// exactly the kind of asset that rots silently. So each test below pins a
// property that a plausible future edit would break, and names it:
//
//   * the nominal box, because callers scale by it;
//   * integer coordinates, because CR-117 wants file-bound geometry byte
//     stable and a float here would print differently on two machines;
//   * one path per lockup, because Typodermic's EULA 4.5 forbids fixed
//     artwork that lets a recipient compose new text, and seven separable
//     letters is exactly that;
//   * no nested contours, because `brand.dart` claims nonzero and even-odd
//     agree and the two backends pick different defaults.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// Flattened outline of one subpath, plus the box it occupies.
typedef _Contour = ({List<({double x, double y})> points, _Box box});

typedef _Box = ({double left, double top, double right, double bottom});

/// Splits a [DiagramPath] into contours, flattening cubics finely enough
/// that a bounding box computed from the result is the INK box rather
/// than the control hull. The two differ, and the difference is the
/// overshoot this file asserts.
List<_Contour> _contours(DiagramPath path) {
  final out = <_Contour>[];
  var points = <({double x, double y})>[];
  var cx = 0.0;
  var cy = 0.0;

  void flush() {
    if (points.length < 2) {
      points = [];
      return;
    }
    var l = points.first.x;
    var r = points.first.x;
    var t = points.first.y;
    var b = points.first.y;
    for (final p in points) {
      if (p.x < l) l = p.x;
      if (p.x > r) r = p.x;
      if (p.y < t) t = p.y;
      if (p.y > b) b = p.y;
    }
    out.add((
      points: points,
      box: (left: l, top: t, right: r, bottom: b),
    ));
    points = [];
  }

  for (final c in path.commands) {
    switch (c) {
      case MoveTo(:final x, :final y):
        flush();
        points.add((x: x, y: y));
        cx = x;
        cy = y;
      case LineTo(:final x, :final y):
        points.add((x: x, y: y));
        cx = x;
        cy = y;
      case CubicTo(
        :final x1,
        :final y1,
        :final x2,
        :final y2,
        :final x3,
        :final y3,
      ):
        const steps = 64;
        for (var i = 1; i <= steps; i++) {
          final u = i / steps;
          final v = 1 - u;
          points.add((
            x:
                v * v * v * cx +
                3 * v * v * u * x1 +
                3 * v * u * u * x2 +
                u * u * u * x3,
            y:
                v * v * v * cy +
                3 * v * v * u * y1 +
                3 * v * u * u * y2 +
                u * u * u * y3,
          ));
        }
        cx = x3;
        cy = y3;
      case ClosePath():
        break;
    }
  }
  flush();
  return out;
}

_Box _bounds(List<_Contour> cs) => (
  left: cs.map((c) => c.box.left).reduce((a, b) => a < b ? a : b),
  top: cs.map((c) => c.box.top).reduce((a, b) => a < b ? a : b),
  right: cs.map((c) => c.box.right).reduce((a, b) => a > b ? a : b),
  bottom: cs.map((c) => c.box.bottom).reduce((a, b) => a > b ? a : b),
);

Iterable<double> _coordinates(DiagramPath path) sync* {
  for (final c in path.commands) {
    switch (c) {
      case MoveTo(:final x, :final y):
        yield x;
        yield y;
      case LineTo(:final x, :final y):
        yield x;
        yield y;
      case CubicTo(
        :final x1,
        :final y1,
        :final x2,
        :final y2,
        :final x3,
        :final y3,
      ):
        yield x1;
        yield y1;
        yield x2;
        yield y2;
        yield x3;
        yield y3;
      case ClosePath():
        break;
    }
  }
}

void main() {
  group('the wordmark occupies the box it declares', () {
    test('ink is flush left and right against the nominal width', () {
      final box = _bounds(_contours(rackPalLockupPath(ruled: false)));
      expect(box.left, 0);
      expect(box.right, kRackPalLockupWidth);
    });

    test('ink overshoots the cap line, and ONLY the cap line', () {
      // If the top ever reads 0 the outlines were trimmed to their ink,
      // which would sit the wordmark high against type set beside it.
      //
      // THE BOTTOM IS EXACT AND THAT IS NOT A TRIM. RACKMATE overshot at
      // both ends because `M` is the only glyph here that passes below
      // the baseline; RACKPAL has no M, so the baseline is flush. This
      // assertion used to read `height + overshoot` and would have kept
      // passing over the old mark's data, which is how a suite ends up
      // pinning the wrong wordmark.
      final box = _bounds(_contours(rackPalLockupPath(ruled: false)));
      expect(box.top, -kRackPalLockupOvershoot);
      expect(box.bottom, kRackPalLockupHeight);
    });

    test('the rule sits where the constants say, and spans the full width', () {
      final ruled = _contours(rackPalLockupPath(ruled: true));
      final plain = _contours(rackPalLockupPath(ruled: false));
      final added = ruled
          .where(
            (c) => !plain.any((p) => p.box == c.box),
          )
          .toList();
      expect(added, hasLength(1), reason: 'the rule is the only difference');
      expect(added.single.box, (
        left: 0.0,
        top: kRackPalLockupRuleTop.toDouble(),
        right: kRackPalLockupWidth.toDouble(),
        bottom: (kRackPalLockupRuleTop + kRackPalLockupRuleHeight).toDouble(),
      ));
    });
  });

  group('properties the licence and the backends depend on', () {
    test('every coordinate is an integer, so the geometry is byte stable', () {
      for (final variant in [true, false]) {
        final path = rackPalLockupPath(ruled: variant);
        final fractional = _coordinates(
          path,
        ).where((v) => v != v.roundToDouble()).toList();
        expect(
          fractional,
          isEmpty,
          reason: 'ruled: $variant emitted non-integer coordinates',
        );
      }
    });

    test('each lockup is ONE path holding every letter as a subpath', () {
      // EULA 4.5: fixed artwork must not let a recipient compose new text.
      // A refactor that "helpfully" splits these into addressable glyphs
      // turns a logo into an alphabet product. Asserting the type alone
      // would pass whatever the data holds, so count the subpaths: eight
      // letters in one object, plus the rule in the ruled variant.
      expect(_contours(rackPalLockupPath(ruled: false)), hasLength(7));
      expect(_contours(rackPalLockupPath(ruled: true)), hasLength(8));
    });

    test('the mark spells RACK over PAL, and not some other seven letters', () {
      // THE ASSERTION THIS FILE DID NOT HAVE, AND THE REASON IT MATTERS.
      // Every other test here is geometric, so the whole suite stayed
      // green when the rename swept this file's comments and constants
      // to RackPal while the outlines still drew RACK over MATE. Counting
      // contours does not help either: eight letters became seven, but
      // seven is seven whatever they spell.
      //
      // What is specific to THIS mark is the shape of the split. Row 1
      // carries four letters at the full measure; row 2 carries three,
      // ending 812 units short. RACKMATE was four and four, both flush.
      // No other arrangement of this wordmark produces these numbers.
      final cs = _contours(rackPalLockupPath(ruled: false));
      final row1 = cs
          .where((c) => c.box.bottom <= kRackPalLockupCapHeight)
          .toList();
      final row2 = cs.where((c) => c.box.top >= kRackPalLockupRuleTop).toList();

      expect(row1, hasLength(4), reason: 'R A C K');
      expect(row2, hasLength(3), reason: 'P A L');
      expect(row1.length + row2.length, cs.length, reason: 'no stray subpath');

      expect(_bounds(row1).right, kRackPalLockupWidth);
      expect(_bounds(row2).right, kRackPalLockupWidth - 812);
      expect(_bounds(row2).left, 0, reason: 'PAL is flush left, not centred');
    });

    test('no contour nests inside another, so the fill rule cannot matter', () {
      // `brand.dart` claims nonzero and even-odd agree because this face's
      // counters are open. Flutter defaults to nonzero and PDF's `f`
      // operator is nonzero too, but `f*` is one edit away, and a closed
      // counter added later would make that edit visible only in print.
      final cs = _contours(rackPalLockupPath(ruled: true));
      for (final outer in cs) {
        for (final inner in cs) {
          if (identical(outer, inner)) continue;
          final contained =
              inner.box.left > outer.box.left &&
              inner.box.right < outer.box.right &&
              inner.box.top > outer.box.top &&
              inner.box.bottom < outer.box.bottom;
          expect(
            contained,
            isFalse,
            reason: 'a contour at ${inner.box} nests inside ${outer.box}',
          );
        }
      }
    });

    test('parsing is memoised, so a redraw does not re-parse', () {
      expect(
        identical(
          rackPalLockupPath(ruled: true),
          rackPalLockupPath(ruled: true),
        ),
        isTrue,
      );
    });
  });

  group('Riley is a second mark and behaves like one', () {
    test('occupies the box the constants declare', () {
      // TOLERANCED WHERE THE WORDMARK IS EXACT, AND THE DIFFERENCE IS
      // REAL. A type designer puts curve extrema on integers, so the
      // letterforms' flattened ink lands exactly on their declared box.
      // Riley is traced from a raster and has no such guarantee: a cubic
      // may bulge marginally past the endpoint that bounded it, and here
      // it does, by about 0.05 units in 675. Asserting equality would be
      // asserting a property the artwork was never given.
      const slack = 0.5;
      final box = _bounds(_contours(rackPalRileyPath()));
      expect(box.left, closeTo(0, slack));
      expect(box.top, closeTo(0, slack));
      expect(box.right, closeTo(kRackPalRileyWidth, slack));
      expect(box.bottom, closeTo(kRackPalRileyHeight, slack));
    });

    test('stands exactly cap-high, so it is not fitted by eye', () {
      // The number the lockup composition depends on: Riley's height IS
      // the cap height, which is what lets it sit on the row-2 baseline
      // with no scaling decision to get wrong later.
      expect(kRackPalRileyHeight, kRackPalLockupCapHeight);
    });

    test('is taller than wide, which is what decides the app icon', () {
      // A 1.876:1 wordmark cannot fill a square icon slot. Riley can.
      // If this ever inverts, the icon guidance in this file is wrong.
      expect(kRackPalRileyWidth, lessThan(kRackPalRileyHeight));
    });

    test('has a hole, so it needs even-odd and the wordmark does not', () {
      // The eye. `brand.dart` promises nonzero and even-odd AGREE for the
      // letterforms, because their counters are open; that promise does
      // not extend here, and this is the assertion that says so out loud.
      final cs = _contours(rackPalRileyPath());
      expect(cs, hasLength(2), reason: 'silhouette plus the eye');
      final outer =
          cs.first.box.right - cs.first.box.left >
              cs.last.box.right - cs.last.box.left
          ? cs.first
          : cs.last;
      final inner = identical(outer, cs.first) ? cs.last : cs.first;
      expect(
        inner.box.left > outer.box.left &&
            inner.box.right < outer.box.right &&
            inner.box.top > outer.box.top &&
            inner.box.bottom < outer.box.bottom,
        isTrue,
        reason: 'the eye nests inside the silhouette',
      );
    });

    test('placed flush right on row 2, clear of PAL', () {
      expect(kRackPalRileyLeft + kRackPalRileyWidth, kRackPalLockupWidth);
      expect(kRackPalRileyTop + kRackPalRileyHeight, kRackPalLockupHeight);
      // 268 units of air between the L and the silhouette.
      expect(kRackPalRileyLeft - (kRackPalLockupWidth - 812), 268);
    });
  });
}
