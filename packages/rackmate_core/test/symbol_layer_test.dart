// Unit tests for the relocated schematic symbol layer
// (draw/scene/symbol_layer.dart). Pure Dart, no Flutter.
//
// This code shipped with ZERO coverage in `rackmate_ui`, which is why the
// defects it carried — port labels rendered as `'P' + id`, sources on the
// input edge, a hit-test that disagreed with the painter by half a port on
// all four edges — survived twelve consecutive "fix" commits. Everything
// here asserts on RECORDED OPS or on computed geometry, never "it built
// without throwing".

import 'dart:math' as math;

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

// ── deterministic fake measurer ──────────────────────────────────────────
// ~0.55 em per character, matching scene_builder_test's fake so the two
// suites agree about what "fits".
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

const _kZeroPosition = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

var _order = 0;

PortDef _port(
  String key, {
  required String family,
  required PortDirection direction,
  String? label,
}) => PortDef(
  key: PortKey(key),
  label: label ?? key,
  connector: const ConnectorTypeId('test'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  position: _kZeroPosition,
  order: FracIndex('a${_order++}'),
  direction: direction,
);

PortDef _in(String key) =>
    _port(key, family: 'video.hdmi.2_0', direction: PortDirection.sink);
PortDef _out(String key) =>
    _port(key, family: 'video.hdmi.2_0', direction: PortDirection.source);

RenderedSymbol _symbol(
  List<PortDef> ports, {
  String id = 'dev-1',
  String designator = 'MTX-1',
  String name = '',
  double headerHeight = 24,
  double portSize = 8,
  double portPitch = 16,
  double minBodyWidth = 140,
  double minBodyHeight = 0,
  DPt origin = const DPt(0, 0),
}) => buildSymbolGeometry(
  id: id,
  designator: designator,
  name: name,
  ports: ports,
  headerHeight: headerHeight,
  portSize: portSize,
  portPitch: portPitch,
  minBodyWidth: minBodyWidth,
  minBodyHeight: minBodyHeight,
  origin: origin,
);

/// Replays built ops through a `DiagramCanvas` double and returns what it saw.
/// Asserting on the REPLAY (not just the op list) is what proves the ops a
/// backend receives are the ops that were built — the same contract
/// `rackmate_export` will drive.
///
/// EVERY ARGUMENT OF EVERY CALL IS STRINGIFIED INTO [calls], and that is
/// load-bearing rather than tidy. This recorder used to append the bare word
/// `'transform'` and drop the `Matrix4` — so `expect(run(), run())`, the
/// determinism check below, compared two identical lists of the literal
/// string `'transform'` and could not see an arrowhead rotated to a fresh
/// `Random().nextDouble()` on every build. A recorder that discards an
/// argument makes every assertion over [calls] blind to it, so this one
/// discards nothing: matrices go in as their full 16-element storage, paths
/// as their command list, and every fill/stroke/style as its own value. The
/// test named "the recorder can SEE a changed arrowhead angle" is the guard
/// that keeps it that way.
final class _RecordingCanvas implements DiagramCanvas {
  final List<String> calls = [];
  final List<DPt> circles = [];
  final List<(String, DPt, TextStyleSpec)> texts = [];
  final List<Matrix4> transforms = [];
  int _saveCount = 0;

  static String _path(DiagramPath p) => p.commands.join(';');

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
  void transform(Matrix4 m) {
    transforms.add(m);
    calls.add('transform(${m.storage.join(",")})');
  }

  @override
  void clipRect(DBox r) => calls.add('clipRect($r)');

  @override
  void clipPath(DiagramPath p, {FillRule rule = FillRule.nonZero}) =>
      calls.add('clipPath(${_path(p)},$rule)');

  @override
  void drawLine(DPt a, DPt b, Stroke s) => calls.add('drawLine($a,$b,$s)');

  @override
  void drawPolyline(List<DPt> pts, Stroke s, {bool close = false}) =>
      calls.add('drawPolyline($pts,$s,$close)');

  @override
  void drawPath(DiagramPath p, {Fill? fill, Stroke? stroke}) =>
      calls.add('drawPath(${_path(p)},$fill,$stroke)');

  @override
  void drawRect(DBox r, {Fill? fill, Stroke? stroke}) =>
      calls.add('drawRect($r,$fill,$stroke)');

  @override
  void drawRoundRect(DBox r, Radii radii, {Fill? fill, Stroke? stroke}) =>
      calls.add('drawRoundRect($r,$radii,$fill,$stroke)');

  @override
  void drawCircle(DPt c, double radius, {Fill? fill, Stroke? stroke}) {
    circles.add(c);
    calls.add('drawCircle($c,$radius,$fill,$stroke)');
  }

  @override
  void drawEllipse(DPt c, double rx, double ry, {Fill? fill, Stroke? stroke}) =>
      calls.add('drawEllipse($c,$rx,$ry,$fill,$stroke)');

  @override
  void drawText(String text, DPt at, TextStyleSpec style) {
    texts.add((text, at, style));
    calls.add('drawText($text,$at,$style)');
  }

  @override
  TextMetrics measureText(String text, TextStyleSpec style) =>
      const _FakeMeasurer().measureText(text, style);
}

_RecordingCanvas _replay(List<DiagramOp> ops) {
  final canvas = _RecordingCanvas();
  for (final op in ops) {
    op.replay(canvas);
  }
  return canvas;
}

void main() {
  setUp(() => _order = 0);

  // ── docs/05 §3: "Inputs left, outputs right, control and network top,
  //    AC power bottom." ────────────────────────────────────────────────
  group('symbolSideForPort — edge assignment (docs/05 §3)', () {
    test('a sink is an INPUT and goes LEFT', () {
      expect(
        symbolSideForPort(
          _port('in1', family: 'video.hdmi.2_0', direction: PortDirection.sink),
        ),
        SymbolSide.left,
      );
    });

    test('a source is an OUTPUT and goes RIGHT', () {
      expect(
        symbolSideForPort(
          _port(
            'out1',
            family: 'video.hdmi.2_0',
            direction: PortDirection.source,
          ),
        ),
        SymbolSide.right,
      );
    });

    test('control and network go TOP regardless of direction', () {
      for (final family in ['ctl.rs232', 'ctl.contact', 'net.ethernet']) {
        for (final dir in PortDirection.values) {
          expect(
            symbolSideForPort(_port('p', family: family, direction: dir)),
            SymbolSide.top,
            reason: '$family/$dir belongs on the control gutter',
          );
        }
      }
    });

    test('every power.* family goes BOTTOM regardless of direction', () {
      for (final family in [
        'power.ac_iec',
        'power.ac_branch',
        'power.ac_hardwired',
        'power.dc_low',
        'power.bonding',
      ]) {
        for (final dir in PortDirection.values) {
          expect(
            symbolSideForPort(_port('p', family: family, direction: dir)),
            SymbolSide.bottom,
            reason: '$family/$dir belongs on the power comb',
          );
        }
      }
    });

    test(
      'role beats direction: an AC power SOURCE is bottom, not right',
      () {
        expect(
          symbolSideForPort(
            _port(
              'j07',
              family: 'power.ac_iec',
              direction: PortDirection.source,
            ),
          ),
          SymbolSide.bottom,
        );
        expect(
          symbolSideForPort(
            _port('lan', family: 'net.ethernet', direction: PortDirection.sink),
          ),
          SymbolSide.top,
        );
      },
    );

    test(
      'bidirectional/busNode/passive A-V fall to the input edge '
      '(no dominant-direction field exists to read)',
      () {
        for (final dir in [
          PortDirection.bidirectional,
          PortDirection.busNode,
          PortDirection.passive,
        ]) {
          expect(
            symbolSideForPort(
              _port('p', family: 'audio.line_bal', direction: dir),
            ),
            SymbolSide.left,
          );
        }
      },
    );

    test('namespace matching is exact — "powered.x" is not power', () {
      expect(
        symbolSideForPort(
          _port('p', family: 'powered.x', direction: PortDirection.source),
        ),
        SymbolSide.right,
      );
      expect(
        symbolSideForPort(
          _port('p', family: 'network.x', direction: PortDirection.source),
        ),
        SymbolSide.right,
      );
    });
  });

  // ── geometry ─────────────────────────────────────────────────────────
  group('buildSymbolGeometry', () {
    test('distributes ports onto the four edges by role', () {
      final s = _symbol([
        _port('in1', family: 'video.hdmi.2_0', direction: PortDirection.sink),
        _port('in2', family: 'video.hdmi.2_0', direction: PortDirection.sink),
        _port(
          'out1',
          family: 'video.hdmi.2_0',
          direction: PortDirection.source,
        ),
        _port('rs232', family: 'ctl.rs232', direction: PortDirection.sink),
        _port('iec', family: 'power.ac_iec', direction: PortDirection.sink),
      ]);
      expect(
        s.ports[SymbolSide.left]!.map((p) => p.key),
        ['in1', 'in2'],
      );
      expect(s.ports[SymbolSide.right]!.map((p) => p.key), ['out1']);
      expect(s.ports[SymbolSide.top]!.map((p) => p.key), ['rs232']);
      expect(s.ports[SymbolSide.bottom]!.map((p) => p.key), ['iec']);
    });

    test('every SymbolSide key exists even with no ports at all', () {
      final s = _symbol([]);
      for (final side in SymbolSide.values) {
        expect(s.ports[side], isEmpty);
      }
      expect(s.allPorts, isEmpty);
    });

    test(
      'height grows with the busiest SIDE edge: header + (n + 1) * pitch',
      () {
        // 3 left, 1 right -> max side count 3.
        final s = _symbol([
          _port('a', family: 'video.hdmi.2_0', direction: PortDirection.sink),
          _port('b', family: 'video.hdmi.2_0', direction: PortDirection.sink),
          _port('c', family: 'video.hdmi.2_0', direction: PortDirection.sink),
          _port('d', family: 'video.hdmi.2_0', direction: PortDirection.source),
        ]);
        expect(s.bodyRect.height, 24 + (3 + 1) * 16);
      },
    );

    test('height never drops below minBodyHeight', () {
      final s = _symbol([], minBodyHeight: 500);
      expect(s.bodyRect.height, 500);
    });

    test('width grows with the busiest TOP/BOTTOM edge', () {
      // 6 control ports on top: (6 + 1) * 16 = 112 < minBodyWidth 140.
      final narrow = _symbol([
        for (var i = 0; i < 6; i++)
          _port('c$i', family: 'ctl.contact', direction: PortDirection.sink),
      ]);
      expect(narrow.bodyRect.width, 140);

      // 12 control ports: (12 + 1) * 16 = 208 > 140, so the body grows.
      _order = 0;
      final wide = _symbol([
        for (var i = 0; i < 12; i++)
          _port('c$i', family: 'ctl.contact', direction: PortDirection.sink),
      ]);
      expect(wide.bodyRect.width, 208);
    });

    test('side pins sit one pitch apart, centred in their slot', () {
      final s = _symbol([
        _port('a', family: 'video.hdmi.2_0', direction: PortDirection.sink),
        _port('b', family: 'video.hdmi.2_0', direction: PortDirection.sink),
      ]);
      final left = s.ports[SymbolSide.left]!;
      expect(left[0].offset, 0.5 * 16);
      expect(left[1].offset, 1.5 * 16);
      expect(left[1].offset - left[0].offset, 16);
    });

    test('top pins are centred as a group across the width', () {
      // 2 top pins on a 140-wide body: group width 32, so it starts at 54.
      final s = _symbol([
        _port('c0', family: 'ctl.contact', direction: PortDirection.sink),
        _port('c1', family: 'ctl.contact', direction: PortDirection.sink),
      ]);
      final top = s.ports[SymbolSide.top]!;
      const start = (140.0 - 2 * 16) / 2;
      expect(top[0].offset, start + 0.5 * 16);
      expect(top[1].offset, start + 1.5 * 16);
      // Symmetric about the body's horizontal centre.
      expect(
        (top[0].offset + top[1].offset) / 2,
        closeTo(s.bodyRect.width / 2, 1e-9),
      );
    });

    test(
      'within-edge order follows the supplied order (§3 FIXED_ORDER) — '
      'ports are hardware and are never reordered to prettify a drawing',
      () {
        final s = _symbol([
          _port('J03', family: 'audio.line_bal', direction: PortDirection.sink),
          _port('J01', family: 'audio.line_bal', direction: PortDirection.sink),
          _port('J02', family: 'audio.line_bal', direction: PortDirection.sink),
        ]);
        expect(
          s.ports[SymbolSide.left]!.map((p) => p.key),
          ['J03', 'J01', 'J02'],
        );
      },
    );

    test('carries the port label through, not a synthesised id string', () {
      final s = _symbol([
        _port(
          'J01',
          family: 'video.hdmi.2_0',
          direction: PortDirection.sink,
          label: 'IN 1',
        ),
      ]);
      expect(s.ports[SymbolSide.left]!.single.label, 'IN 1');
      expect(s.ports[SymbolSide.left]!.single.key, 'J01');
    });

    test('movedTo relocates the body and leaves everything else alone', () {
      final s = _symbol([
        _in('J01'),
        _port('lan', family: 'net.ethernet', direction: PortDirection.sink),
      ], origin: const DPt(10, 20));
      final moved = s.movedTo(const DPt(500, 600));

      expect(moved.bodyRect.topLeft, const DPt(500, 600));
      expect(moved.bodyRect.width, s.bodyRect.width);
      expect(moved.bodyRect.height, s.bodyRect.height);
      expect(moved.id, s.id);
      expect(moved.designator, s.designator);
      expect(moved.headerHeight, s.headerHeight);
      expect(moved.allPorts.toList(), s.allPorts.toList());
      // The original is untouched — moving returns a new value.
      expect(s.bodyRect.topLeft, const DPt(10, 20));
    });

    test('a moved symbol builds byte-identical LOCAL ops — a move never '
        'invalidates the fragment', () {
      final s = _symbol([_in('J01'), _out('J02')]);
      List<String> opsOf(RenderedSymbol sym) => _replay(
        buildSymbolLayer(
          sym,
          palette: const SchematicPalette(),
          measurer: const _FakeMeasurer(),
        ).ops,
      ).calls;
      expect(opsOf(s.movedTo(const DPt(999, -444))), opsOf(s));
    });

    test('movedTo shifts every ABSOLUTE pin centre by the same delta', () {
      final s = _symbol([
        _in('J01'),
        _out('J02'),
        _port('t', family: 'ctl.rs232', direction: PortDirection.sink),
      ], origin: const DPt(10, 20));
      final moved = s.movedTo(const DPt(60, 120));
      final before = s.allPorts.map((p) => symbolPortCentre(s, p)).toList();
      final after = moved.allPorts
          .map((p) => symbolPortCentre(moved, p))
          .toList();
      for (var i = 0; i < before.length; i++) {
        expect(after[i].x - before[i].x, 50);
        expect(after[i].y - before[i].y, 100);
      }
    });

    test('allPorts walks left, right, top, bottom deterministically', () {
      final s = _symbol([
        _port('iec', family: 'power.ac_iec', direction: PortDirection.sink),
        _port('lan', family: 'net.ethernet', direction: PortDirection.sink),
        _port('out', family: 'video.hdmi.2_0', direction: PortDirection.source),
        _port('in', family: 'video.hdmi.2_0', direction: PortDirection.sink),
      ]);
      expect(s.allPorts.map((p) => p.key), ['in', 'out', 'lan', 'iec']);
    });
  });

  // ── the one port-centre definition ───────────────────────────────────
  group('symbolPortCentre', () {
    test('places every pin ON its own edge, at its offset', () {
      final s = _symbol([
        _port('in', family: 'video.hdmi.2_0', direction: PortDirection.sink),
        _port('out', family: 'video.hdmi.2_0', direction: PortDirection.source),
        _port('lan', family: 'net.ethernet', direction: PortDirection.sink),
        _port('iec', family: 'power.ac_iec', direction: PortDirection.sink),
      ], origin: const DPt(300, 200));

      final left = s.ports[SymbolSide.left]!.single;
      final right = s.ports[SymbolSide.right]!.single;
      final top = s.ports[SymbolSide.top]!.single;
      final bottom = s.ports[SymbolSide.bottom]!.single;

      expect(symbolPortCentre(s, left).x, s.bodyRect.left);
      expect(symbolPortCentre(s, left).y, s.bodyRect.top + 24 + left.offset);
      expect(symbolPortCentre(s, right).x, s.bodyRect.right);
      expect(symbolPortCentre(s, top).y, s.bodyRect.top);
      expect(symbolPortCentre(s, top).x, s.bodyRect.left + top.offset);
      expect(symbolPortCentre(s, bottom).y, s.bodyRect.bottom);
    });

    test('absolute == local + bodyRect.topLeft, for every edge', () {
      final s = _symbol([
        _port('in', family: 'video.hdmi.2_0', direction: PortDirection.sink),
        _port('out', family: 'video.hdmi.2_0', direction: PortDirection.source),
        _port('lan', family: 'net.ethernet', direction: PortDirection.sink),
        _port('iec', family: 'power.ac_iec', direction: PortDirection.sink),
      ], origin: const DPt(-37.5, 918.25));
      for (final port in s.allPorts) {
        final local = symbolPortCentreLocal(s, port);
        expect(
          symbolPortCentre(s, port),
          DPt(local.x + s.bodyRect.left, local.y + s.bodyRect.top),
          reason: 'edge ${port.side}',
        );
      }
    });
  });

  // ── the layer: assertions on RECORDED CANVAS OPS ─────────────────────
  group('buildSymbolLayer — recorded ops', () {
    test('emits body fill, header band, hairline rule and body outline', () {
      final s = _symbol([]);
      final built = buildSymbolLayer(
        s,
        palette: const SchematicPalette(),
        measurer: const _FakeMeasurer(),
      );
      final rects = built.ops.whereType<OpRect>().toList();

      // Body fill (no stroke), header band, then the outline (no fill).
      expect(
        rects[0].r,
        DBox.fromLtwh(0, 0, s.bodyRect.width, s.bodyRect.height),
      );
      expect(rects[0].fill, const Fill(0xFFFFFFFF));
      expect(rects[0].stroke, isNull);

      expect(rects[1].r, const DBox.fromLtwh(0, 0, 140, 24));
      expect(rects[1].fill, const Fill(0xFFE8E8E8));

      expect(rects[2].r, rects[0].r);
      expect(rects[2].stroke, isNotNull);
      expect(rects[2].fill, isNull);

      final rule = built.ops.whereType<OpLine>().single;
      expect(rule.a, const DPt(0, 24));
      expect(rule.b, const DPt(140, 24));
    });

    test('the header band uses headerFill, not the body fill', () {
      // The pre-relocation painter declared `headerFill` and then filled the
      // header with `deviceFill`, making the band invisible.
      const palette = SchematicPalette(
        headerFill: 0xFF112233,
        bodyFill: 0xFFAABBCC,
      );
      final built = buildSymbolLayer(
        _symbol([]),
        palette: palette,
        measurer: const _FakeMeasurer(),
      );
      final rects = built.ops.whereType<OpRect>().toList();
      expect(rects[0].fill, const Fill(0xFFAABBCC));
      expect(rects[1].fill, const Fill(0xFF112233));
    });

    test('builds LOCAL ops: the body rect starts at the origin even when '
        'the symbol is placed far away', () {
      final built = buildSymbolLayer(
        _symbol([], origin: const DPt(640, 480)),
        palette: const SchematicPalette(),
        measurer: const _FakeMeasurer(),
      );
      expect(built.ops.whereType<OpRect>().first.r.topLeft, const DPt(0, 0));
    });

    test('draws the designator in the header', () {
      final canvas = _replay(
        buildSymbolLayer(
          _symbol([], designator: 'AMP-12'),
          palette: const SchematicPalette(),
          measurer: const _FakeMeasurer(),
        ).ops,
      );
      final designator = canvas.texts.firstWhere((t) => t.$1 == 'AMP-12');
      expect(designator.$2, const DPt(4, 4));
      expect(designator.$3.anchor, TextAnchor.topLeft);
      expect(designator.$3.sizePt, RackTextSizes.designator);
    });

    test(
      'draws the instance name right-aligned when it MEASURES as fitting',
      () {
        final canvas = _replay(
          buildSymbolLayer(
            _symbol([], designator: 'A', name: 'Head End'),
            palette: const SchematicPalette(),
            measurer: const _FakeMeasurer(),
          ).ops,
        );
        final name = canvas.texts.firstWhere((t) => t.$1 == 'Head End');
        expect(name.$2, const DPt(136, 4));
        expect(name.$3.anchor, TextAnchor.topRight);
      },
    );

    test('drops the instance name rather than overprinting it when it '
        'does not fit', () {
      final canvas = _replay(
        buildSymbolLayer(
          _symbol(
            [],
            name: 'A very long head-end instance name indeed',
          ),
          palette: const SchematicPalette(),
          measurer: const _FakeMeasurer(),
        ).ops,
      );
      expect(canvas.texts.map((t) => t.$1), isNot(contains(contains('very'))));
      expect(canvas.texts.map((t) => t.$1), contains('MTX-1'));
    });

    test('draws each pin label VERBATIM — never "P" + id', () {
      // The screen's `Pin1` / `Pout1` boxes came from `'P${port.id}'`.
      final canvas = _replay(
        buildSymbolLayer(
          _symbol([
            _port(
              'in1',
              family: 'video.hdmi.2_0',
              direction: PortDirection.sink,
              label: 'IN 1',
            ),
            _port(
              'out1',
              family: 'video.hdmi.2_0',
              direction: PortDirection.source,
              label: 'OUT 1',
            ),
          ]),
          palette: const SchematicPalette(),
          measurer: const _FakeMeasurer(),
        ).ops,
      );
      final drawn = canvas.texts.map((t) => t.$1).toList();
      expect(drawn, containsAll(['IN 1', 'OUT 1']));
      expect(drawn, isNot(contains('Pin1')));
      expect(drawn, isNot(contains('Pout1')));
    });

    test('omits the label op entirely for an unlabelled pin', () {
      final canvas = _replay(
        buildSymbolLayer(
          _symbol([
            _port(
              'in1',
              family: 'video.hdmi.2_0',
              direction: PortDirection.sink,
              label: '',
            ),
          ]),
          palette: const SchematicPalette(),
          measurer: const _FakeMeasurer(),
        ).ops,
      );
      // Only the designator remains.
      expect(canvas.texts.map((t) => t.$1), ['MTX-1']);
    });

    test('side labels are drawn INSIDE the body, top/bottom OUTSIDE it', () {
      final s = _symbol([
        _port(
          'in',
          family: 'video.hdmi.2_0',
          direction: PortDirection.sink,
          label: 'L',
        ),
        _port(
          'out',
          family: 'video.hdmi.2_0',
          direction: PortDirection.source,
          label: 'R',
        ),
        _port(
          'lan',
          family: 'net.ethernet',
          direction: PortDirection.sink,
          label: 'T',
        ),
        _port(
          'iec',
          family: 'power.ac_iec',
          direction: PortDirection.sink,
          label: 'B',
        ),
      ]);
      final canvas = _replay(
        buildSymbolLayer(
          s,
          palette: const SchematicPalette(),
          measurer: const _FakeMeasurer(),
        ).ops,
      );
      final byText = {for (final t in canvas.texts) t.$1: t};

      // Left pin is at x = 0; its label must be to the RIGHT of it (inside).
      expect(byText['L']!.$2.x, greaterThan(0));
      expect(byText['L']!.$3.anchor, TextAnchor.midLeft);
      // Right pin is at x = width; its label must be to the LEFT (inside).
      expect(byText['R']!.$2.x, lessThan(s.bodyRect.width));
      expect(byText['R']!.$3.anchor, TextAnchor.midRight);
      // Top pin is at y = 0; its label sits ABOVE (outside).
      expect(byText['T']!.$2.y, lessThan(0));
      // Bottom pin is at y = height; its label sits BELOW (outside).
      expect(byText['B']!.$2.y, greaterThan(s.bodyRect.height));

      // ── #96-A: the top/bottom anchors changed with the quarter turn ──
      //
      // They were `bottomCenter` / `topCenter`, which put the run's MIDDLE
      // over the pin and let it spread sideways into its neighbours — the
      // overlap the field found. Turned `-pi/2` the run climbs the page, so
      // the anchor picks which END sits at the pin, and that is what sends
      // each edge's text away from the body: `midLeft` starts the run at a
      // top pin and carries it further up, `midRight` ends it at a bottom
      // pin so it reaches further down. One angle, two anchors, one reading
      // direction. See `_labelRotation` and `port_label_overlap_test.dart`.
      expect(byText['T']!.$3.anchor, TextAnchor.midLeft);
      expect(byText['T']!.$3.rotationRad, closeTo(-math.pi / 2, 1e-12));
      expect(byText['B']!.$3.anchor, TextAnchor.midRight);
      expect(byText['B']!.$3.rotationRad, closeTo(-math.pi / 2, 1e-12));
      // And the side labels are NOT turned — they never overlapped, because
      // there the pins are spaced along Y and the text runs along X.
      expect(byText['L']!.$3.rotationRad, 0);
      expect(byText['R']!.$3.rotationRad, 0);
    });

    test('every drawn circle sits ON the body edge its pin belongs to, at '
        "that pin's own offset (docs/05 §3)", () {
      // WHAT THIS DOES *NOT* DO, and why. It used to compare `canvas.circles`
      // against `symbolPortCentreLocal` — the exact expression
      // `buildSymbolLayer` evaluates to construct each `OpCircle`. Both sides
      // therefore moved together for ANY definition: offsetting
      // `symbolPortCentreLocal` by (size/2, size/2) on all four edges, which
      // is the historical defect the file header names, left this passing.
      //
      // So the expectation below is re-derived from §3's own words — a pin is
      // ON its edge, at `headerHeight + offset` along a side edge and at
      // `offset` along the top/bottom — using only `bodyRect`, `headerHeight`
      // and `SymbolPort.offset`. One side of the comparison is the painter,
      // the other is the spec. The painter/HIT-TESTER agreement is a
      // different claim and is proved in `symbol_hit_test_test.dart`
      // ("every pin the layer DRAWS is on its body edge and hittable there"),
      // which is the only test in the pair that calls both.
      final s = _symbol([
        _port('in', family: 'video.hdmi.2_0', direction: PortDirection.sink),
        _port('in2', family: 'video.hdmi.2_0', direction: PortDirection.sink),
        _port('out', family: 'video.hdmi.2_0', direction: PortDirection.source),
        _port('lan', family: 'net.ethernet', direction: PortDirection.sink),
        _port('iec', family: 'power.ac_iec', direction: PortDirection.sink),
      ]);
      final canvas = _replay(
        buildSymbolLayer(
          s,
          palette: const SchematicPalette(),
          measurer: const _FakeMeasurer(),
        ).ops,
      );

      final w = s.bodyRect.width;
      final h = s.bodyRect.height;
      const headerHeight = 24.0;
      final expected = [
        for (final p in s.allPorts)
          switch (p.side) {
            SymbolSide.left => DPt(0, headerHeight + p.offset),
            SymbolSide.right => DPt(w, headerHeight + p.offset),
            SymbolSide.top => DPt(p.offset, 0),
            SymbolSide.bottom => DPt(p.offset, h),
          },
      ];
      expect(canvas.circles, expected);

      // And the shared definition agrees with the same independent reading,
      // so the hit-tester (which queries through it) is anchored too.
      expect(
        s.allPorts.map((p) => symbolPortCentreLocal(s, p)).toList(),
        expected,
      );
    });

    test('a sink arrowhead points INTO the body; a source points AWAY', () {
      final s = _symbol([
        _port('in', family: 'video.hdmi.2_0', direction: PortDirection.sink),
        _port('out', family: 'video.hdmi.2_0', direction: PortDirection.source),
      ]);
      final canvas = _replay(
        buildSymbolLayer(
          s,
          palette: const SchematicPalette(),
          measurer: const _FakeMeasurer(),
        ).ops,
      );
      expect(canvas.transforms, hasLength(2));

      // The untransformed arrow apex is at (+t/2, 0); transform it and check
      // which way it actually ends up pointing relative to its own centre.
      DPt apexDir(Matrix4 m) {
        final o = m.transform3(Vector3.zero());
        final a = m.transform3(Vector3(1, 0, 0));
        return DPt(a.x - o.x, a.y - o.y);
      }

      // Left edge (a sink): into the body means +x.
      expect(apexDir(canvas.transforms[0]).x, closeTo(1, 1e-9));
      // Right edge (a source): away from the body also means +x.
      expect(apexDir(canvas.transforms[1]).x, closeTo(1, 1e-9));
    });

    test('a top sink arrow points DOWN and a bottom sink arrow points UP', () {
      final s = _symbol([
        _port('lan', family: 'net.ethernet', direction: PortDirection.sink),
        _port('iec', family: 'power.ac_iec', direction: PortDirection.sink),
      ]);
      final canvas = _replay(
        buildSymbolLayer(
          s,
          palette: const SchematicPalette(),
          measurer: const _FakeMeasurer(),
        ).ops,
      );
      DPt apexDir(Matrix4 m) {
        final o = m.transform3(Vector3.zero());
        final a = m.transform3(Vector3(1, 0, 0));
        return DPt(a.x - o.x, a.y - o.y);
      }

      expect(apexDir(canvas.transforms[0]).y, closeTo(1, 1e-9)); // top: down
      expect(apexDir(canvas.transforms[1]).y, closeTo(-1, 1e-9)); // bottom: up
    });

    test('bidirectional/busNode/passive pins get NO arrowhead — the model '
        'carries no dominant direction to draw', () {
      for (final dir in [
        PortDirection.bidirectional,
        PortDirection.busNode,
        PortDirection.passive,
      ]) {
        _order = 0;
        final built = buildSymbolLayer(
          _symbol([_port('p', family: 'audio.line_bal', direction: dir)]),
          palette: const SchematicPalette(),
          measurer: const _FakeMeasurer(),
        );
        expect(built.ops.whereType<OpPath>(), isEmpty, reason: '$dir');
        expect(built.ops.whereType<OpTransform>(), isEmpty, reason: '$dir');
        // The pin circle is still drawn.
        expect(built.ops.whereType<OpCircle>(), hasLength(1));
      }
    });

    test('every save is matched by a restore (a leaked save corrupts the '
        'rest of the sheet)', () {
      final canvas = _replay(
        buildSymbolLayer(
          _symbol([
            _port(
              'in',
              family: 'video.hdmi.2_0',
              direction: PortDirection.sink,
            ),
            _port(
              'out',
              family: 'video.hdmi.2_0',
              direction: PortDirection.source,
            ),
            _port('lan', family: 'net.ethernet', direction: PortDirection.sink),
          ]),
          palette: const SchematicPalette(),
          measurer: const _FakeMeasurer(),
        ).ops,
      );
      expect(canvas.saveCount, 0);
      expect(canvas.calls.where((c) => c == 'save'), hasLength(3));
      expect(canvas.calls.where((c) => c == 'restore'), hasLength(3));
    });

    test('minTextPt reports the SMALLEST size actually emitted', () {
      final withPins = buildSymbolLayer(
        _symbol([
          _port(
            'in',
            family: 'video.hdmi.2_0',
            direction: PortDirection.sink,
            label: 'IN 1',
          ),
        ]),
        palette: const SchematicPalette(),
        measurer: const _FakeMeasurer(),
      );
      expect(withPins.minTextPt, RackTextSizes.type);
      expect(
        withPins.minTextPt,
        lessThan(RackTextSizes.designator),
        reason: 'the pin label is the smallest ink on the symbol',
      );
    });

    test('minTextPt is the designator size when only the header is drawn', () {
      final bare = buildSymbolLayer(
        _symbol([]),
        palette: const SchematicPalette(),
        measurer: const _FakeMeasurer(),
      );
      expect(bare.minTextPt, RackTextSizes.designator);
    });

    test('the built ops are deterministic — two builds of one input agree on '
        'every op AND on every ARGUMENT, arrowhead matrices included', () {
      List<String> run() {
        _order = 0;
        final s = _symbol([
          _port('a', family: 'video.hdmi.2_0', direction: PortDirection.sink),
          _port('b', family: 'ctl.rs232', direction: PortDirection.sink),
          _port('c', family: 'power.ac_iec', direction: PortDirection.sink),
          _port('d', family: 'video.hdmi.2_0', direction: PortDirection.source),
        ]);
        return _replay(
          buildSymbolLayer(
            s,
            palette: const SchematicPalette(),
            measurer: const _FakeMeasurer(),
          ).ops,
        ).calls;
      }

      final first = run();
      expect(first, run());

      // NOT VACUOUS, and this is the whole reason the assertion above is
      // worth writing. The recorder used to log the bare word 'transform'
      // and throw the `Matrix4` away, so a build that rotated every
      // arrowhead to a fresh `math.Random().nextDouble()` compared equal to
      // itself. These two lines pin that the four arrowhead matrices really
      // are inside the strings being compared.
      expect(first, isNot(contains('transform')));
      expect(
        first.where((c) => c.startsWith('transform(')),
        hasLength(4),
        reason: 'four directed pins, four arrowhead matrices, all recorded',
      );
    });

    test('the recorder can SEE a changed arrowhead angle — the guard that '
        'stops the determinism test above from passing on any build', () {
      // A direct check on the harness rather than on the layer: if this
      // fails, every `expect(calls, ...)` in this file has quietly stopped
      // being able to observe a transform argument.
      final a = _RecordingCanvas()..transform(Matrix4.rotationZ(0.5));
      final b = _RecordingCanvas()..transform(Matrix4.rotationZ(0.6));
      expect(a.calls, isNot(b.calls));

      // Same for the other argument-carrying ops the symbol emits.
      final circleA = _RecordingCanvas()
        ..drawCircle(const DPt(0, 0), 4, fill: const Fill(0xFF000000));
      final circleB = _RecordingCanvas()
        ..drawCircle(const DPt(0, 0), 4, fill: const Fill(0xFFFF0000));
      expect(circleA.calls, isNot(circleB.calls));

      final pathA = _RecordingCanvas()
        ..drawPath(const DiagramPath([MoveTo(0, 0), LineTo(1, 1)]));
      final pathB = _RecordingCanvas()
        ..drawPath(const DiagramPath([MoveTo(0, 0), LineTo(1, 2)]));
      expect(pathA.calls, isNot(pathB.calls));
    });
  });

  // ── ink bounds: the invariant a composed scene depends on ────────────
  group('buildSymbolLayer — inkBounds', () {
    LayerBuild built(RenderedSymbol s) => buildSymbolLayer(
      s,
      palette: const SchematicPalette(),
      measurer: const _FakeMeasurer(),
    );

    test('a bare symbol reports its body, grown by the outline stroke', () {
      // No pins, no outside labels: the only ink past the body rect is the
      // 1pt outline straddling it.
      final s = _symbol([]);
      final ink = built(s).inkBounds!;
      expect(
        ink,
        DBox.fromLtwh(
          -0.5,
          -0.5,
          s.bodyRect.width + 1,
          s.bodyRect.height + 1,
        ),
      );
    });

    test('a LEFT pin pushes the ink half a port OUTSIDE the body — the '
        'exact overrun a caller unioning bodyRects would clip', () {
      // portSize 8, so the circle centred ON the left edge reaches x = -4;
      // its 1pt stroke reaches -4.5.
      final s = _symbol([
        _port(
          'in',
          family: 'video.hdmi.2_0',
          direction: PortDirection.sink,
          label: '',
        ),
      ]);
      final ink = built(s).inkBounds!;
      expect(ink.left, -4.5);
      expect(ink.left, lessThan(0), reason: 'bodyRect.left is 0');
    });

    test('a RIGHT pin pushes the ink half a port past the right edge', () {
      final s = _symbol([
        _port(
          'out',
          family: 'video.hdmi.2_0',
          direction: PortDirection.source,
          label: '',
        ),
      ]);
      expect(built(s).inkBounds!.right, s.bodyRect.width + 4.5);
    });

    test('a TOP port label lands entirely outside the body, and the ink '
        'bounds contain it', () {
      // ── #96-A CHANGED THE ARITHMETIC, NOT THE CLAIM ──────────────────
      // The label still sits `_kPortLabelGap` (5) above the pin centre. What
      // moved is how far its own box then reaches: unturned it added one
      // ascent+descent (8 units for 8 pt text); turned `-pi/2` it climbs by
      // its full ADVANCE WIDTH instead, because the run's long axis is now
      // vertical.
      //
      // DERIVED FROM THE MEASURER rather than restated as a literal. The old
      // `-13` was a hand-computed constant, and hand-computing this one would
      // have to be redone every time the label text or `_emPerChar` changed
      // — which is exactly how a constant stops describing the code.
      const label = 'LAN';
      final s = _symbol([
        _port(
          'lan',
          family: 'net.ethernet',
          direction: PortDirection.sink,
          label: label,
        ),
      ]);
      final width = const _FakeMeasurer()
          .measureText(
            label,
            rackText(RackTextSizes.type, 0, TextAnchor.midLeft),
          )
          .advanceWidth;
      final ink = built(s).inkBounds!;
      expect(
        ink.top,
        closeTo(-(5 + width), 0.001),
        reason: 'pin centre 0, gap 5, then the whole turned run',
      );
      expect(
        ink.top,
        lessThan(-4.5),
        reason: 'the label reaches further out than the pin circle does',
      );
    });

    test('a BOTTOM port label lands below the body', () {
      const label = 'IEC C14';
      final s = _symbol([
        _port(
          'iec',
          family: 'power.ac_iec',
          direction: PortDirection.sink,
          label: label,
        ),
      ]);
      final width = const _FakeMeasurer()
          .measureText(
            label,
            rackText(RackTextSizes.type, 0, TextAnchor.midRight),
          )
          .advanceWidth;
      expect(
        built(s).inkBounds!.bottom,
        closeTo(s.bodyRect.height + 5 + width, 0.001),
      );
    });

    test('the docs/05 §3.1 MTX-1 fixture overruns its body on all four '
        'sides at once', () {
      final s = _symbol([
        for (var i = 1; i <= 4; i++) _in('IN$i'),
        for (var i = 1; i <= 4; i++) _out('OUT$i'),
        _port(
          'rs232',
          family: 'ctl.rs232',
          direction: PortDirection.sink,
          label: 'RS-232',
        ),
        _port(
          'iec',
          family: 'power.ac_iec',
          direction: PortDirection.sink,
          label: 'IEC C14',
        ),
      ], minBodyWidth: 180);
      final ink = built(s).inkBounds!;
      expect(ink.left, lessThan(s.bodyRect.left));
      expect(ink.top, lessThan(s.bodyRect.top));
      expect(ink.right, greaterThan(s.bodyRect.right));
      expect(ink.bottom, greaterThan(s.bodyRect.bottom));
    });

    test('inkBounds is measured from the ops, so it moves when the ops do',
        () {
      // Deleting the labels shrinks the reported box: proof the value is
      // derived, not a hand-maintained constant that happens to be roomy.
      final labelled = built(
        _symbol([
          _port(
            'lan',
            family: 'net.ethernet',
            direction: PortDirection.sink,
            label: 'LAN',
          ),
        ]),
      ).inkBounds!;
      _order = 0;
      final bare = built(
        _symbol([
          _port(
            'lan',
            family: 'net.ethernet',
            direction: PortDirection.sink,
            label: '',
          ),
        ]),
      ).inkBounds!;
      expect(labelled.top, lessThan(bare.top));
    });

    test('LOCAL like the ops: a moved symbol reports the same box', () {
      final s = _symbol([_in('J01'), _out('J02')], origin: const DPt(10, 20));
      expect(
        built(s.movedTo(const DPt(900, -300))).inkBounds,
        built(s).inkBounds,
      );
    });
  });

  // ── BankDef.symbolSide: an author-declared edge that must not be
  //    silently discarded ────────────────────────────────────────────────
  group('buildSymbolGeometry — BankDef.symbolSide (CR-055)', () {
    PortDef banked(
      String key, {
      required String family,
      required PortDirection direction,
      required String bank,
    }) => PortDef(
      key: PortKey(key),
      label: key,
      connector: const ConnectorTypeId('test'),
      signalFamily: SignalFamilyId(family),
      face: Face.rear,
      position: _kZeroPosition,
      order: FracIndex('a${_order++}'),
      direction: direction,
      bankKey: bank,
    );

    BankDef bank(String key, SymbolSide side) => BankDef(
      key: key,
      label: key,
      abbr: key,
      order: const FracIndex('a'),
      symbolSide: side,
    );

    test("an author's explicit RIGHT beats the family/direction rule", () {
      // audio.line_bal sinks would go LEFT by the §3 rule. The bank says
      // right, and the bank wins.
      final ports = [
        banked(
          'z1',
          family: 'audio.line_bal',
          direction: PortDirection.sink,
          bank: 'zone_out',
        ),
        banked(
          'z2',
          family: 'audio.line_bal',
          direction: PortDirection.sink,
          bank: 'zone_out',
        ),
      ];
      final ignored = _symbol(ports);
      expect(
        ignored.ports[SymbolSide.left]!.map((p) => p.key),
        ['z1', 'z2'],
        reason: 'without the banks map there is nothing to consult',
      );

      final honoured = buildSymbolGeometry(
        id: 'dev-1',
        designator: 'MTX-1',
        ports: ports,
        banks: [bank('zone_out', SymbolSide.right)],
        headerHeight: 24,
        portSize: 8,
        portPitch: 16,
        minBodyWidth: 140,
      );
      expect(honoured.ports[SymbolSide.right]!.map((p) => p.key), ['z1', 'z2']);
      expect(honoured.ports[SymbolSide.left], isEmpty);
    });

    test('an explicit TOP beats the power rule, and an explicit BOTTOM beats '
        'the control rule — the author is not overruled by a namespace', () {
      final ports = [
        banked(
          'ac',
          family: 'power.ac_iec',
          direction: PortDirection.sink,
          bank: 'up',
        ),
        banked(
          'rs',
          family: 'ctl.rs232',
          direction: PortDirection.sink,
          bank: 'down',
        ),
      ];
      final s = buildSymbolGeometry(
        id: 'dev-1',
        designator: 'MTX-1',
        ports: ports,
        banks: [bank('up', SymbolSide.top), bank('down', SymbolSide.bottom)],
        headerHeight: 24,
        portSize: 8,
        portPitch: 16,
        minBodyWidth: 140,
      );
      expect(s.ports[SymbolSide.top]!.single.key, 'ac');
      expect(s.ports[SymbolSide.bottom]!.single.key, 'rs');
    });

    test('a bank still at the model DEFAULT is not a decision: outputs stay '
        'on the output edge', () {
      // `BankDef.symbolSide` is non-nullable and defaults to left, so the
      // seed catalog leaves every bank it does not care about at left.
      // Treating that as an author choice would drag every device OUTPUT
      // onto the input edge.
      expect(kUndeclaredSymbolSide, SymbolSide.left);
      final s = buildSymbolGeometry(
        id: 'dev-1',
        designator: 'MTX-1',
        ports: [
          banked(
            'o1',
            family: 'video.hdmi.2_0',
            direction: PortDirection.source,
            bank: 'hdmiOut',
          ),
        ],
        banks: [bank('hdmiOut', SymbolSide.left)],
        headerHeight: 24,
        portSize: 8,
        portPitch: 16,
        minBodyWidth: 140,
      );
      expect(s.ports[SymbolSide.right]!.single.key, 'o1');
    });

    test('a port whose bankKey matches nothing falls back to the rule', () {
      final s = buildSymbolGeometry(
        id: 'dev-1',
        designator: 'MTX-1',
        ports: [
          banked(
            'p',
            family: 'power.ac_iec',
            direction: PortDirection.sink,
            bank: 'missing',
          ),
        ],
        banks: [bank('other', SymbolSide.right)],
        headerHeight: 24,
        portSize: 8,
        portPitch: 16,
        minBodyWidth: 140,
      );
      expect(s.ports[SymbolSide.bottom]!.single.key, 'p');
    });

    test('duplicate bank keys resolve to the FIRST, matching PortBuilder', () {
      final s = buildSymbolGeometry(
        id: 'dev-1',
        designator: 'MTX-1',
        ports: [
          banked(
            'p',
            family: 'video.hdmi.2_0',
            direction: PortDirection.sink,
            bank: 'b',
          ),
        ],
        banks: [bank('b', SymbolSide.top), bank('b', SymbolSide.bottom)],
        headerHeight: 24,
        portSize: 8,
        portPitch: 16,
        minBodyWidth: 140,
      );
      expect(s.ports[SymbolSide.top]!.single.key, 'p');
    });

    test('symbolSideForPort reads the bank directly too', () {
      final port = banked(
        'p',
        family: 'video.hdmi.2_0',
        direction: PortDirection.sink,
        bank: 'b',
      );
      expect(symbolSideForPort(port), SymbolSide.left);
      expect(
        symbolSideForPort(port, bank: bank('b', SymbolSide.bottom)),
        SymbolSide.bottom,
      );
    });
  });

  // ── value semantics and aliasing ─────────────────────────────────────
  group('RenderedSymbol value semantics', () {
    test('compares by VALUE — a symbol moved to where it already is equals '
        'itself', () {
      final s = _symbol([_in('J01'), _out('J02')], origin: const DPt(3, 4));
      expect(s.movedTo(const DPt(3, 4)), s);
      expect(s.movedTo(const DPt(3, 4)).hashCode, s.hashCode);
      expect(s.movedTo(const DPt(5, 4)), isNot(s));
    });

    test('two independently built symbols with identical fields are equal — '
        'so the ports map compares by content, not identity', () {
      final a = _symbol([_in('J01')]);
      _order = 0;
      final b = _symbol([_in('J01')]);
      expect(identical(a.ports, b.ports), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing pins make differing symbols', () {
      final a = _symbol([_in('J01')]);
      _order = 0;
      final b = _symbol([_in('J02')]);
      expect(a, isNot(b));
    });

    test('the ports map is UNMODIFIABLE, so a move cannot mutate its source '
        'through the shared map', () {
      final s = _symbol([_in('J01'), _in('J02')]);
      final moved = s.movedTo(const DPt(500, 500));
      expect(
        () => moved.ports[SymbolSide.left]!.removeLast(),
        throwsUnsupportedError,
      );
      expect(
        () => moved.ports[SymbolSide.right] = <SymbolPort>[],
        throwsUnsupportedError,
      );
      expect(s.ports[SymbolSide.left], hasLength(2));
    });
  });

  group('DPtDistance', () {
    test('is a real Euclidean distance (3-4-5)', () {
      expect(const DPt(0, 0).distanceTo(const DPt(3, 4)), 5);
    });

    test('agrees with dart:math.sqrt on an irrational case', () {
      expect(
        const DPt(1, 1).distanceTo(const DPt(2, 2)),
        closeTo(math.sqrt(2), 1e-15),
      );
    });

    test('is zero for a point and itself, and symmetric', () {
      const a = DPt(-4.5, 12.25);
      const b = DPt(7, -0.75);
      expect(a.distanceTo(a), 0);
      expect(a.distanceTo(b), b.distanceTo(a));
    });
  });
}
