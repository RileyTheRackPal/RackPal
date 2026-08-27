// #752 — the seventeen device marks as geometry. DR-059, placed by
// DR-083.
//
// ═════════════════════════════════════════════════════════════════════
// THE TEST THIS FILE EXISTS FOR IS `every value draws, and draws once`
// ═════════════════════════════════════════════════════════════════════
// `family_glyph.dart` was written after a glyph that was a CODEPOINT
// measured near-zero and drew full width, because Jost carries none of
// those characters. The gate that keeps this channel out of that hole is
// the one asserting every enum value resolves to a path here rather than
// falling through to text or to nothing.
//
// These cases assert the ARTIFACT and not the mechanism: the op a
// caller receives, the box the ink lands in, and the advance the text
// after it is pushed by. None of them pins an intermediate.
//
// WHAT THEY CANNOT SEE, stated because it is the interesting half: none
// of this measures whether seventeen silhouettes are TELLABLE APART at
// 8 pt on a photocopy. `device_glyph_art.dart`'s header names the four
// neighbourhoods to check and #757 is where a person checks them.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// Every mark except the one that deliberately draws nothing.
Iterable<DeviceGlyph> get _drawn =>
    DeviceGlyph.values.where((g) => g != DeviceGlyph.none);

const _size = 11.0;
const _at = DPt(100, 50);

DiagramOp? _op(DeviceGlyph g) => deviceGlyphOp(
  g,
  _at,
  _size,
  0xFF000000,
  strokeWidthPt: deviceGlyphStrokeWidth(_size),
);

/// Every point a path command puts ink through, control points
/// included. Controls count: a cubic whose handle escapes the box can
/// bow the curve out of it.
List<(double, double)> _points(DiagramPath p) {
  final out = <(double, double)>[];
  for (final c in p.commands) {
    switch (c) {
      case MoveTo(:final x, :final y):
        out.add((x, y));
      case LineTo(:final x, :final y):
        out.add((x, y));
      case CubicTo(
        :final x1,
        :final y1,
        :final x2,
        :final y2,
        :final x3,
        :final y3,
      ):
        out
          ..add((x1, y1))
          ..add((x2, y2))
          ..add((x3, y3));
      case ClosePath():
        break;
    }
  }
  return out;
}

void main() {
  group('every value resolves, and none falls through', () {
    test('all seventeen marks produce exactly one op', () {
      for (final g in _drawn) {
        expect(_op(g), isA<OpPath>(), reason: '$g produced no path');
      }
      expect(_drawn.length, 17);
    });

    test('`none` draws nothing at all, and that is a chosen value rather '
        'than a missing one', () {
      expect(_op(DeviceGlyph.none), isNull);
    });

    test('no mark is an empty path, which is how a forgotten case would '
        'present', () {
      for (final g in _drawn) {
        final op = _op(g)! as OpPath;
        expect(op.p.commands, isNotEmpty, reason: '$g is empty');
      }
    });
  });

  group('the ink stays in the box the advance reserves', () {
    test('every point sits inside the cap-height square', () {
      const r = _size * kDeviceGlyphCapFactor / 2;
      final cx = _at.x + r;
      final cy = _at.y;
      // A hair of tolerance for binary rounding in the cubic constant,
      // not for a shape that genuinely overhangs.
      const eps = 1e-9;
      for (final g in _drawn) {
        for (final (x, y) in _points((_op(g)! as OpPath).p)) {
          expect(
            x,
            inInclusiveRange(cx - r - eps, cx + r + eps),
            reason: '$g escapes horizontally',
          );
          expect(
            y,
            inInclusiveRange(cy - r - eps, cy + r + eps),
            reason: '$g escapes vertically',
          );
        }
      }
    });

    test('the mark starts at the point it is given, never before it', () {
      for (final g in _drawn) {
        for (final (x, _) in _points((_op(g)! as OpPath).p)) {
          expect(x, greaterThanOrEqualTo(_at.x - 1e-9), reason: '$g');
        }
      }
    });
  });

  group('the advance is computed, which is the whole point of geometry', () {
    test('it scales with the type size rather than being a constant', () {
      expect(deviceGlyphAdvance(22), deviceGlyphAdvance(11) * 2);
    });

    test('it clears the cap box, so the text can never sit on the mark', () {
      expect(
        deviceGlyphAdvance(_size),
        greaterThan(_size * kDeviceGlyphCapFactor),
      );
    });

    test('the stroke scales too, so an inflated sheet does not go spindly', () {
      expect(
        deviceGlyphStrokeWidth(22),
        greaterThan(deviceGlyphStrokeWidth(11)),
      );
    });
  });

  group('fill is a distinction the set relies on', () {
    test('blank and source are solid; every other mark is an outline', () {
      for (final g in _drawn) {
        final op = _op(g)! as OpPath;
        final solid = g == DeviceGlyph.blank || g == DeviceGlyph.source;
        expect(op.fill != null, solid, reason: '$g fill');
        expect(op.stroke != null, !solid, reason: '$g stroke');
      }
    });

    test('amplifier and source share their geometry EXACTLY and differ only '
        'by fill, which is the pair a photocopy is most likely to flatten '
        '(art header, note 3)', () {
      final amp = _op(DeviceGlyph.amplifier)! as OpPath;
      final src = _op(DeviceGlyph.source)! as OpPath;
      expect(_points(amp.p), _points(src.p));
      expect(amp.fill, isNull);
      expect(src.fill, isNotNull);
    });
  });

  test('no two marks are the same drawing, so a copy-paste in the switch '
      'fails here rather than on a sheet', () {
    final seen = <String, DeviceGlyph>{};
    for (final g in _drawn) {
      final op = _op(g)! as OpPath;
      // Geometry AND paint, because amplifier and source are one shape
      // in two inks by design.
      final key =
          '${_points(op.p)}|${op.fill?.argb}|${op.stroke?.argb}'
          '|${op.fill == null}';
      final clash = seen[key];
      expect(
        clash,
        isNull,
        reason: '$g draws exactly what $clash draws',
      );
      seen[key] = g;
    }
  });

  test('every seeded category default resolves to a mark that draws, so no '
      'shipped template is silently unmarked', () {
    for (final entry in kCategoryDefaultGlyph.entries) {
      expect(
        _op(entry.value),
        isNotNull,
        reason: '${entry.key} defaults to ${entry.value}, which draws nothing',
      );
    }
  });
}
