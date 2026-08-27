// Minimal sanity checks for the M1 shared drawing IR (draw/). NOT the
// screen/print parity test (that is a later stage's job) — just enough to
// catch a broken SVG parser, a broken equality override, or a broken
// replay/fragment mechanism before they reach a scene builder.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

/// A `DiagramCanvas` test double that records every call it receives, so
/// `DiagramOp.replay`/`DiagramScene.replay` can be asserted on without a
/// real backend.
final class _RecordingCanvas implements DiagramCanvas {
  final List<String> calls = [];
  int _saveCount = 0;

  @override
  int get saveCount => _saveCount;

  @override
  void save() {
    _saveCount++;
    calls.add('save');
  }

  @override
  void restore() {
    _saveCount--;
    calls.add('restore');
  }

  @override
  void translate(double dx, double dy) => calls.add('translate($dx,$dy)');

  @override
  void scale(double sx, [double? sy]) => calls.add('scale($sx,$sy)');

  @override
  void rotate(double radians) => calls.add('rotate($radians)');

  @override
  Matrix4 currentTransform = Matrix4.identity();

  @override
  void transform(Matrix4 m) => calls.add('transform');

  @override
  void clipRect(DBox r) => calls.add('clipRect($r)');

  @override
  void clipPath(DiagramPath p, {FillRule rule = FillRule.nonZero}) =>
      calls.add('clipPath($rule)');

  @override
  void drawLine(DPt a, DPt b, Stroke s) => calls.add('drawLine($a,$b)');

  @override
  void drawPolyline(List<DPt> pts, Stroke s, {bool close = false}) =>
      calls.add('drawPolyline(${pts.length},$close)');

  @override
  void drawPath(DiagramPath p, {Fill? fill, Stroke? stroke}) =>
      calls.add('drawPath');

  @override
  void drawRect(DBox r, {Fill? fill, Stroke? stroke}) =>
      calls.add('drawRect($r)');

  @override
  void drawRoundRect(DBox r, Radii radii, {Fill? fill, Stroke? stroke}) =>
      calls.add('drawRoundRect($r,$radii)');

  @override
  void drawCircle(DPt c, double radius, {Fill? fill, Stroke? stroke}) =>
      calls.add('drawCircle($c,$radius)');

  @override
  void drawEllipse(DPt c, double rx, double ry, {Fill? fill, Stroke? stroke}) =>
      calls.add('drawEllipse($c,$rx,$ry)');

  @override
  void drawText(String text, DPt at, TextStyleSpec style) =>
      calls.add('drawText($text,$at)');

  @override
  TextMetrics measureText(String text, TextStyleSpec style) =>
      const TextMetrics(
        advanceWidth: 0,
        ascent: 0,
        descent: 0,
        capHeight: 0,
        xHeight: 0,
        lineHeight: 0,
      );
}

void main() {
  group('Stroke/Fill/Radii value equality', () {
    test('Stroke equality covers every field, including dash', () {
      const a = Stroke(argb: 0xFF000000, widthPt: 1, dash: [6, 3]);
      const b = Stroke(argb: 0xFF000000, widthPt: 1, dash: [6, 3]);
      const c = Stroke(argb: 0xFF000000, widthPt: 1, dash: [6, 4]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('Stroke.miterLimit defaults to 10.0, matching PDF not dart:ui', () {
      const s = Stroke(argb: 0, widthPt: 1);
      expect(s.miterLimit, 10.0);
    });

    test('Fill(argb) single-arg constructor and equality', () {
      expect(const Fill(0xFFFF0000), equals(const Fill(0xFFFF0000)));
    });

    test('Radii.circular sets both radii uniformly', () {
      const r = Radii.circular(4);
      expect(r.rv, 4);
      expect(r.rh, 4);
    });
  });

  group('DiagramPath.fromSvg', () {
    test('parses M/L/Z and reports absolute commands', () {
      final path = DiagramPath.fromSvg('M0 0 L10 0 L10 10 Z');
      expect(path.commands, [
        const MoveTo(0, 0),
        const LineTo(10, 0),
        const LineTo(10, 10),
        const ClosePath(),
      ]);
    });

    test('supports relative commands and implicit repeats', () {
      final path = DiagramPath.fromSvg('m1 1 l2 0 0 2');
      expect(path.commands, [
        const MoveTo(1, 1),
        const LineTo(3, 1), // relative +2,0
        const LineTo(3, 3), // implicit repeat of l: +0,+2
      ]);
    });

    test('parses a cubic and reports its endpoints absolutely', () {
      final path = DiagramPath.fromSvg('M0 0 C1 2 3 4 5 6');
      expect(path.commands, [
        const MoveTo(0, 0),
        const CubicTo(1, 2, 3, 4, 5, 6),
      ]);
    });

    test('bounds covers every referenced coordinate', () {
      final path = DiagramPath.fromSvg('M0 0 L10 0 L10 10 L0 10 Z');
      final bounds = path.bounds;
      expect(bounds.left, 0);
      expect(bounds.top, 0);
      expect(bounds.right, 10);
      expect(bounds.bottom, 10);
    });

    test('fails loudly on an unsupported command (arcs)', () {
      expect(
        () => DiagramPath.fromSvg('M0 0 A5 5 0 0 1 10 10'),
        throwsFormatException,
      );
    });

    test('fails loudly when data does not start with a command', () {
      expect(() => DiagramPath.fromSvg('10 10'), throwsFormatException);
    });
  });

  group('anchorOffset', () {
    const m = TextMetrics(
      advanceWidth: 20,
      ascent: 8,
      descent: 2,
      capHeight: 6,
      xHeight: 4,
      lineHeight: 10,
    );

    test('topLeft has no offset in X and offsets to ascent in Y', () {
      final o = anchorOffset(TextAnchor.topLeft, m);
      expect(o.x, 0);
      expect(o.y, 8);
    });

    test('midCenter centres in X and splits the height in Y', () {
      final o = anchorOffset(TextAnchor.midCenter, m);
      expect(o.x, -10);
      expect(o.y, 8 - 10 / 2);
    });

    test('bottomRight offsets by full width and negative descent', () {
      final o = anchorOffset(TextAnchor.bottomRight, m);
      expect(o.x, -20);
      expect(o.y, -2);
    });

    test('baseline* variants have zero Y offset', () {
      expect(anchorOffset(TextAnchor.baselineLeft, m).y, 0);
      expect(anchorOffset(TextAnchor.baselineCenter, m).y, 0);
      expect(anchorOffset(TextAnchor.baselineRight, m).y, 0);
    });
  });

  group('DiagramOp.replay forwards to the matching DiagramCanvas call', () {
    test('one op per primitive', () {
      final canvas = _RecordingCanvas();
      const stroke = Stroke(argb: 0xFF000000, widthPt: 1);
      const style = TextStyleSpec(
        font: FontRef('Jost'),
        sizePt: 12,
        argb: 0xFF000000,
        anchor: TextAnchor.baselineLeft,
      );
      final ops = <DiagramOp>[
        const OpSave(),
        OpTransform(Matrix4.identity()),
        const OpClipRect(DBox.fromLtwh(0, 0, 10, 10)),
        OpClipPath(DiagramPath.fromSvg('M0 0 L1 1 Z')),
        const OpLine(DPt(0, 0), DPt(1, 1), stroke),
        const OpPolyline([DPt(0, 0), DPt(1, 1)], stroke),
        OpPath(DiagramPath.fromSvg('M0 0 L1 1 Z'), stroke: stroke),
        const OpRect(DBox.fromLtwh(0, 0, 1, 1), stroke: stroke),
        const OpRoundRect(
          DBox.fromLtwh(0, 0, 1, 1),
          Radii.circular(1),
          stroke: stroke,
        ),
        const OpCircle(DPt(0, 0), 1, stroke: stroke),
        const OpEllipse(DPt(0, 0), 1, 2, stroke: stroke),
        const OpText('RK-1', DPt(0, 0), style),
        const OpRestore(),
      ];
      for (final op in ops) {
        op.replay(canvas);
      }
      expect(canvas.calls, [
        'save',
        'transform',
        contains('clipRect'),
        'clipPath(FillRule.nonZero)',
        contains('drawLine'),
        'drawPolyline(2,false)',
        'drawPath',
        contains('drawRect'),
        contains('drawRoundRect'),
        contains('drawCircle'),
        contains('drawEllipse'),
        'drawText(RK-1,DPt(0.0, 0.0))',
        'restore',
      ]);
    });
  });

  group('DiagramScene', () {
    test('replay walks every op in order', () {
      final canvas = _RecordingCanvas();
      const DiagramScene(
        ops: [OpSave(), OpRestore()],
        bounds: DBox.fromLtwh(0, 0, 1, 1),
        hits: [],
        minTextSizePt: 6,
        fragments: {},
      ).replay(canvas);
      expect(canvas.calls, ['save', 'restore']);
    });

    test('fragmentFor slices ops by the registered range (CR-086)', () {
      const scene = DiagramScene(
        ops: [OpSave(), OpRestore(), OpSave(), OpRestore()],
        bounds: DBox.fromLtwh(0, 0, 1, 1),
        hits: [],
        minTextSizePt: 6,
        fragments: {'dev-1': IntRange(2, 4)},
      );
      final fragment = scene.fragmentFor('dev-1');
      expect(fragment.ops, [const OpSave(), const OpRestore()]);
      expect(fragment.bounds, scene.bounds);
    });

    test('fragmentFor throws for an unregistered entity id', () {
      const scene = DiagramScene(
        ops: [],
        bounds: DBox.fromLtwh(0, 0, 1, 1),
        hits: [],
        minTextSizePt: 6,
        fragments: {},
      );
      expect(() => scene.fragmentFor('missing'), throwsArgumentError);
    });
  });

  test('HitRegion.contains delegates to DBox.contains', () {
    const region = HitRegion('dev-1', DBox.fromLtwh(0, 0, 10, 10));
    expect(region.contains(const DPt(5, 5)), isTrue);
    expect(region.contains(const DPt(50, 50)), isFalse);
  });
}
