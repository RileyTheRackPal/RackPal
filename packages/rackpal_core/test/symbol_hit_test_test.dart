// Unit tests for the relocated schematic hit-tester
// (draw/scene/symbol_hit_test.dart). Pure Dart, no Flutter.
//
// Near-miss and exact-boundary cases are the whole point: a tolerance test
// that only ever probes the dead centre of a pin proves nothing about the
// radius, and the pre-relocation code's port positions were offset from the
// drawn circles by half a port on all four edges — a defect that is
// invisible unless a test compares the two.
//
// THE CROSS-CHECK LIVES IN THIS FILE and is "every pin the layer DRAWS is on
// its body edge, and is hittable exactly there". It is the only test in the
// relocated pair that calls BOTH `buildSymbolLayer` and `SymbolHitTest`, so
// it is the only one that can see them disagree. It used to claim that in a
// comment while recomputing the hit-tester's own formula inline and
// comparing it to itself; the probe points now come out of the painter's
// replayed ops.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

/// Deterministic measurer — `buildSymbolLayer` needs one, and this file
/// never asserts on text.
final class _FakeMeasurer implements TextMeasurer {
  const _FakeMeasurer();

  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

/// A `DiagramCanvas` that keeps only what this file cross-checks: the pin
/// circles the layer actually drew, as (centre, radius) in LOCAL space.
final class _CircleRecorder implements DiagramCanvas {
  final List<(DPt, double)> circles = [];
  int _saveCount = 0;

  @override
  int get saveCount => _saveCount;

  @override
  void drawCircle(DPt c, double radius, {Fill? fill, Stroke? stroke}) =>
      circles.add((c, radius));

  @override
  void save() => _saveCount++;

  @override
  void restore() => _saveCount--;

  @override
  Matrix4 currentTransform = Matrix4.identity();

  @override
  void translate(double dx, double dy) {}

  @override
  void scale(double sx, [double? sy]) {}

  @override
  void rotate(double radians) {}

  @override
  void transform(Matrix4 m) {}

  @override
  void clipRect(DBox r) {}

  @override
  void clipPath(DiagramPath p, {FillRule rule = FillRule.nonZero}) {}

  @override
  void drawLine(DPt a, DPt b, Stroke s) {}

  @override
  void drawPolyline(List<DPt> pts, Stroke s, {bool close = false}) {}

  @override
  void drawPath(DiagramPath p, {Fill? fill, Stroke? stroke}) {}

  @override
  void drawRect(DBox r, {Fill? fill, Stroke? stroke}) {}

  @override
  void drawRoundRect(DBox r, Radii radii, {Fill? fill, Stroke? stroke}) {}

  @override
  void drawEllipse(DPt c, double rx, double ry, {Fill? fill, Stroke? stroke}) {}

  @override
  void drawText(String text, DPt at, TextStyleSpec style) {}

  @override
  void drawImage(ImageRef image, DBox dst) {}

  @override
  TextMetrics measureText(String text, TextStyleSpec style) =>
      const _FakeMeasurer().measureText(text, style);
}

/// The pin circles [symbol]'s layer really draws, in ABSOLUTE sheet space —
/// replayed out of `buildSymbolLayer`'s ops, never recomputed.
List<(DPt, double)> _drawnPins(RenderedSymbol symbol) {
  final canvas = _CircleRecorder();
  for (final op in buildSymbolLayer(
    symbol,
    palette: const SchematicPalette(),
    measurer: const _FakeMeasurer(),
  ).ops) {
    op.replay(canvas);
  }
  return [
    for (final (centre, radius) in canvas.circles)
      (
        DPt(
          centre.x + symbol.bodyRect.left,
          centre.y + symbol.bodyRect.top,
        ),
        radius,
      ),
  ];
}

var _order = 0;

PortDef _port(
  String key, {
  required String family,
  required PortDirection direction,
}) => PortDef(
  key: PortKey(key),
  label: key,
  connector: const ConnectorTypeId('test'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  order: FracIndex('a${_order++}'),
  direction: direction,
);

PortDef _in(String key) =>
    _port(key, family: 'video.hdmi.2_0', direction: PortDirection.sink);
PortDef _out(String key) =>
    _port(key, family: 'video.hdmi.2_0', direction: PortDirection.source);

RenderedSymbol _symbol({
  String id = 'dev-1',
  List<PortDef> ports = const [],
  DPt origin = const DPt(0, 0),
  double minBodyWidth = 140,
  double minBodyHeight = 100,
}) => buildSymbolGeometry(
  id: id,
  designator: id.toUpperCase(),
  ports: ports,
  headerHeight: 24,
  portSize: 8,
  portPitch: 16,
  minBodyWidth: minBodyWidth,
  minBodyHeight: minBodyHeight,
  origin: origin,
);

void main() {
  setUp(() => _order = 0);

  group('snapToGrid', () {
    final t = SymbolHitTest(symbols: const []);

    test('snaps to the nearest multiple of the grid pitch', () {
      expect(t.snapToGrid(const DPt(23, 37)), const DPt(20, 40));
      expect(t.snapToGrid(const DPt(0, 0)), const DPt(0, 0));
    });

    test('a point already on the grid is unchanged', () {
      expect(t.snapToGrid(const DPt(40, 60)), const DPt(40, 60));
    });

    test('EXACT halfway rounds AWAY FROM ZERO, in both directions', () {
      // 10 is exactly half of the default 20-unit pitch.
      expect(t.snapToGrid(const DPt(10, 10)), const DPt(20, 20));
      expect(t.snapToGrid(const DPt(-10, -10)), const DPt(-20, -20));
    });

    test('just below halfway rounds down, just above rounds up', () {
      expect(t.snapToGrid(const DPt(9.999, 0)).x, 0);
      expect(t.snapToGrid(const DPt(10.001, 0)).x, 20);
    });

    test('negative coordinates snap symmetrically', () {
      expect(t.snapToGrid(const DPt(-23, -37)), const DPt(-20, -40));
    });

    test(
      'a non-positive grid disables snapping instead of dividing by zero',
      () {
        final zero = SymbolHitTest(
          symbols: const [],
          params: const SymbolHitTestParams(snapGridSize: 0),
        );
        expect(zero.snapToGrid(const DPt(23, 37)), const DPt(23, 37));
        final negative = SymbolHitTest(
          symbols: const [],
          params: const SymbolHitTestParams(snapGridSize: -5),
        );
        expect(negative.snapToGrid(const DPt(23, 37)), const DPt(23, 37));
      },
    );

    test('honours a custom pitch', () {
      final fine = SymbolHitTest(
        symbols: const [],
        params: const SymbolHitTestParams(snapGridSize: 5),
      );
      expect(fine.snapToGrid(const DPt(23, 37)), const DPt(25, 35));
    });
  });

  group('testPoint — empty sheet', () {
    test('reports a snap hit and populates snapPosition, never null', () {
      final t = SymbolHitTest(symbols: const []);
      final r = t.testPoint(const DPt(23, 37));
      expect(r.kind, SymbolHitKind.snap);
      expect(r.position, const DPt(23, 37));
      expect(r.snapPosition, const DPt(20, 40));
      expect(r.nodeId, isNull);
      expect(r.portKey, isNull);
    });
  });

  group('testPoint — pins', () {
    test('a click dead on a pin centre reports that pin', () {
      final s = _symbol(ports: [_in('J01')], origin: const DPt(100, 100));
      final port = s.ports[SymbolSide.left]!.single;
      final centre = symbolPortCentre(s, port);

      final r = SymbolHitTest(symbols: [s]).testPoint(centre);
      expect(r.kind, SymbolHitKind.port);
      expect(r.nodeId, 'dev-1');
      expect(r.portKey, 'J01');
      expect(r.side, SymbolSide.left);
      expect(r.position, centre);
    });

    test(
      'the reported hit position is the pin CENTRE the layer draws, not the '
      'queried point',
      () {
        final s = _symbol(ports: [_in('J01')]);
        final port = s.ports[SymbolSide.left]!.single;
        final centre = symbolPortCentre(s, port);
        final r = SymbolHitTest(
          symbols: [s],
        ).testPoint(DPt(centre.x + 3, centre.y + 3));
        expect(r.position, centre);
      },
    );

    test('EXACTLY at the tolerance boundary still hits (inclusive)', () {
      // `portHitTolerance` is slop around the pin's DRAWN circle, not around
      // a dimensionless centre — the pin region a scene carries is the pin's
      // real ink (`centre ± size / 2`), and the tolerance is what
      // `hitTestRegions` adds on top. portSize 8 -> the circle reaches 4
      // out, so the boundary for a 12 tolerance is 16 from the centre.
      final s = _symbol(ports: [_in('J01')], origin: const DPt(200, 200));
      final centre = symbolPortCentre(s, s.ports[SymbolSide.left]!.single);
      // A non-default tolerance, so this also proves the parameter is read
      // rather than only exercising the default.
      const t = SymbolHitTestParams(portHitTolerance: 12);
      final query = SymbolHitTest(symbols: [s], params: t);
      expect(query.testPoint(DPt(centre.x, centre.y - 16)).portKey, 'J01');
      // And one unit beyond it is a miss, so the boundary is a boundary and
      // not merely "somewhere inside a much larger target".
      expect(
        query.testPoint(DPt(centre.x, centre.y - 16.001)).kind,
        isNot(SymbolHitKind.port),
      );
    });

    test('one unit OUTSIDE the tolerance is a near miss', () {
      // Placed clear of the body so the miss falls through to `snap`, which
      // proves the pin was rejected rather than merely outranked. Default
      // tolerance 15 + the drawn circle's 4 = 19 reachable; 20 is not.
      final s = _symbol(ports: [_in('J01')], origin: const DPt(200, 200));
      final centre = symbolPortCentre(s, s.ports[SymbolSide.left]!.single);
      final t = SymbolHitTest(symbols: [s]);
      expect(t.testPoint(DPt(centre.x - 19, centre.y)).portKey, 'J01');
      final r = t.testPoint(DPt(centre.x - 20, centre.y));
      expect(r.kind, isNot(SymbolHitKind.port));
      expect(r.portKey, isNull);
    });

    test('tolerance is a RADIUS, not a square: the diagonal corner misses', () {
      final s = _symbol(ports: [_in('J01')], origin: const DPt(400, 400));
      final centre = symbolPortCentre(s, s.ports[SymbolSide.left]!.single);
      // (-15, -15) is 15.56 from the drawn circle's box (11, 11 past each
      // edge) — outside a 15 tolerance, but inside a 15 SQUARE of slop.
      final r = SymbolHitTest(
        symbols: [s],
      ).testPoint(DPt(centre.x - 15, centre.y - 15));
      expect(r.kind, isNot(SymbolHitKind.port));
      // The same distance taken straight along an axis DOES hit, so the
      // rejection above is about the shape of the target, not its size.
      expect(
        SymbolHitTest(
          symbols: [s],
        ).testPoint(DPt(centre.x - 15, centre.y)).portKey,
        'J01',
      );
    });

    test('the NEAREST pin wins when two are within tolerance', () {
      // Two left pins one pitch (16) apart, both inside a 15 tolerance from
      // a point biased toward the second.
      final s = _symbol(ports: [_in('J01'), _in('J02')]);
      final a = symbolPortCentre(s, s.ports[SymbolSide.left]![0]);
      final b = symbolPortCentre(s, s.ports[SymbolSide.left]![1]);
      final biased = DPt(a.x, a.y + (b.y - a.y) * 0.6);

      final r = SymbolHitTest(symbols: [s]).testPoint(biased);
      expect(r.portKey, 'J02');
      expect(a.distanceTo(biased), greaterThan(b.distanceTo(biased)));
    });

    test('an exact tie between two pins resolves to the earlier symbol '
        '(deterministic, not arbitrary)', () {
      final a = _symbol(id: 'a', ports: [_out('P')]);
      _order = 0;
      final b = _symbol(id: 'b', ports: [_in('P')], origin: const DPt(140, 0));
      // a's right pin and b's left pin are both at x = 140, same y.
      final pa = symbolPortCentre(a, a.ports[SymbolSide.right]!.single);
      final pb = symbolPortCentre(b, b.ports[SymbolSide.left]!.single);
      expect(pa, pb);

      expect(SymbolHitTest(symbols: [a, b]).testPoint(pa).nodeId, 'a');
      expect(SymbolHitTest(symbols: [b, a]).testPoint(pa).nodeId, 'b');
    });

    test('pins BEAT bodies globally — a pin on the second symbol wins over '
        'the body of the first symbol', () {
      // The pre-relocation code returned symbol[0]'s body before it had
      // even looked at symbol[1]'s pins, so edge pins on a stacked symbol
      // were unreachable.
      final big = _symbol(id: 'big', minBodyWidth: 400, minBodyHeight: 400);
      _order = 0;
      final small = _symbol(
        id: 'small',
        ports: [_in('J01')],
        origin: const DPt(150, 150),
      );
      final pin = symbolPortCentre(small, small.ports[SymbolSide.left]!.single);
      expect(big.bodyRect.contains(pin), isTrue, reason: 'pin is over `big`');

      final r = SymbolHitTest(symbols: [big, small]).testPoint(pin);
      expect(r.kind, SymbolHitKind.port);
      expect(r.nodeId, 'small');
    });

    test('a pin on ANY edge is reachable, with its side reported', () {
      final s = _symbol(
        ports: [
          _in('L'),
          _out('R'),
          _port('T', family: 'net.ethernet', direction: PortDirection.sink),
          _port('B', family: 'power.ac_iec', direction: PortDirection.sink),
        ],
        origin: const DPt(50, 50),
      );
      final t = SymbolHitTest(symbols: [s]);
      for (final port in s.allPorts) {
        final r = t.testPoint(symbolPortCentre(s, port));
        expect(r.kind, SymbolHitKind.port, reason: port.key);
        expect(r.portKey, port.key);
        expect(r.side, port.side);
      }
    });

    test('every pin the layer DRAWS is on its body edge, and is hittable '
        'exactly there', () {
      // THE CROSS-CHECK. Three parties have to agree and each is derived
      // independently:
      //   1. THE PAINTER — the circle centres replayed out of
      //      `buildSymbolLayer`'s ops. Not `symbolPortCentreLocal`; the
      //      previous version of this test called that instead and so
      //      compared the hit-tester's own formula to itself, which left the
      //      historical (size/2, size/2) offset passing on all four edges.
      //   2. DOCS/05 §3 — a pin is ON its edge. Read off `bodyRect` here, so
      //      moving the shared centre definition moves only ONE side of the
      //      comparison.
      //   3. THE HIT-TESTER — `testPoint` must report a port there, and the
      //      centre it reports must be the drawn centre to the last bit.
      final s = _symbol(
        ports: [
          _in('L1'),
          _in('L2'),
          _out('R1'),
          _port('T1', family: 'ctl.rs232', direction: PortDirection.sink),
          _port('B1', family: 'power.ac_iec', direction: PortDirection.sink),
        ],
        origin: const DPt(321.5, 87.25),
      );
      final drawn = _drawnPins(s);
      final t = SymbolHitTest(symbols: [s]);
      final body = s.bodyRect;

      expect(
        drawn,
        hasLength(s.allPorts.length),
        reason: 'the layer drew one circle per pin',
      );
      expect(drawn, isNotEmpty, reason: 'nothing to cross-check otherwise');

      final reached = <String>{};
      for (final (centre, radius) in drawn) {
        // 2. On an edge of the body, as §3 requires — measured from the body
        // rectangle alone.
        final onEdge =
            centre.x == body.left ||
            centre.x == body.right ||
            centre.y == body.top ||
            centre.y == body.bottom;
        expect(
          onEdge,
          isTrue,
          reason: 'a pin was drawn at $centre, off every edge of $body',
        );

        // 3. The hit-tester finds a pin there, and calls it the same point.
        final r = t.testPoint(centre);
        expect(
          r.kind,
          SymbolHitKind.port,
          reason: 'nothing hittable at the drawn pin $centre',
        );
        expect(
          r.position,
          centre,
          reason:
              'the hit-tester puts pin ${r.portKey} at ${r.position}, the '
              'layer drew it at $centre',
        );

        // …and the region a SCENE would carry is that same circle, so a
        // generic `hitTest(scene, p)` consumer sees the drawn ink too.
        final region = symbolHitRegions([
          s,
        ]).firstWhere((x) => x.partKey == r.portKey);
        expect(
          region.bounds,
          DBox.fromLtwh(
            centre.x - radius,
            centre.y - radius,
            radius * 2,
            radius * 2,
          ),
        );
        reached.add(r.portKey!);
      }

      // No pin was drawn twice and none was missed: the walk above covered
      // every port exactly once.
      expect(reached, s.allPorts.map((p) => p.key).toSet());
    });
  });

  group('testPoint — bodies', () {
    test('a click inside the body away from any pin reports the node', () {
      final s = _symbol(ports: [_in('J01')]);
      final r = SymbolHitTest(symbols: [s]).testPoint(const DPt(70, 80));
      expect(r.kind, SymbolHitKind.node);
      expect(r.nodeId, 'dev-1');
      expect(r.portKey, isNull);
      expect(r.position, const DPt(70, 80));
      expect(r.snapPosition, const DPt(80, 80));
    });

    test('the body boundary is INCLUSIVE (DBox.contains semantics)', () {
      final s = _symbol();
      final t = SymbolHitTest(symbols: [s]);
      expect(t.testPoint(s.bodyRect.bottomRight).kind, SymbolHitKind.node);
      expect(
        t.testPoint(DPt(s.bodyRect.right + 0.001, s.bodyRect.bottom)).kind,
        SymbolHitKind.snap,
      );
    });

    test('among overlapping bodies the one whose CENTRE is nearest wins', () {
      final a = _symbol(id: 'a', minBodyWidth: 200, minBodyHeight: 200);
      final b = _symbol(
        id: 'b',
        origin: const DPt(150, 150),
        minBodyWidth: 200,
        minBodyHeight: 200,
      );
      final t = SymbolHitTest(symbols: [a, b]);
      // (180, 180) is inside both; b's centre (250,250) is 99 away, a's
      // centre (100,100) is 113 away.
      expect(t.testPoint(const DPt(180, 180)).nodeId, 'b');
      // (160, 160) is inside both but nearer a's centre.
      expect(t.testPoint(const DPt(160, 160)).nodeId, 'a');
    });

    test('overlapping bodies at an exact tie resolve by list order', () {
      final a = _symbol(id: 'a');
      final b = _symbol(id: 'b');
      expect(
        SymbolHitTest(symbols: [a, b]).testPoint(const DPt(70, 70)).nodeId,
        'a',
      );
      expect(
        SymbolHitTest(symbols: [b, a]).testPoint(const DPt(70, 70)).nodeId,
        'b',
      );
    });

    test('a click outside every body falls through to snap', () {
      final s = _symbol();
      final r = SymbolHitTest(symbols: [s]).testPoint(const DPt(1000, 1000));
      expect(r.kind, SymbolHitKind.snap);
      expect(r.nodeId, isNull);
    });
  });

  // ── the reconciliation with HitRegion / DiagramScene.hits (CR-084,
  //    docs/03 §7.4) ────────────────────────────────────────────────────
  group('symbolHitRegions — symbols in the ESTABLISHED hit mechanism', () {
    DiagramScene sceneOf(List<RenderedSymbol> symbols) => DiagramScene(
      ops: const [],
      bounds: const DBox.fromLtwh(0, 0, 1000, 1000),
      hits: symbolHitRegions(symbols),
      minTextSizePt: 6,
      fragments: const {},
    );

    test('a schematic scene assembled from symbolHitRegions answers the '
        'generic hitTest() — the query the mobile shell reuses verbatim', () {
      final s = _symbol(ports: [_in('J01')], origin: const DPt(100, 100));
      final scene = sceneOf([s]);

      // Before this existed, `hits` was empty and this returned null for
      // every point over every symbol.
      expect(scene.hits, isNotEmpty);
      final body = hitTest(scene, const DPt(170, 180));
      expect(body, isNotNull);
      expect(body!.entityId, 'dev-1');
      expect(body.partKey, isNull, reason: 'the body is the whole entity');
    });

    test('a pin is reachable through the generic query too, and reports '
        'WHICH pin', () {
      final s = _symbol(ports: [_in('J01')], origin: const DPt(100, 100));
      final centre = symbolPortCentre(s, s.ports[SymbolSide.left]!.single);
      final hit = hitTest(sceneOf([s]), centre);
      expect(hit, isNotNull);
      expect(hit!.entityId, 'dev-1');
      expect(hit.partKey, 'J01');
    });

    test('a generic consumer that only knows about entities still resolves a '
        'pin hit to the owning device', () {
      final s = _symbol(ports: [_in('J01')], origin: const DPt(100, 100));
      for (final region in symbolHitRegions([s])) {
        expect(region.entityId, s.id);
      }
    });

    test('pin regions are the pin CIRCLE the layer draws — no hit slop is '
        'baked into the scene', () {
      final s = _symbol(ports: [_in('J01')], origin: const DPt(10, 20));
      final port = s.ports[SymbolSide.left]!.single;
      final centre = symbolPortCentre(s, port);
      final pin = symbolHitRegions([s]).firstWhere((r) => r.partKey == 'J01');
      expect(
        pin.bounds,
        DBox.fromLtwh(
          centre.x - port.size / 2,
          centre.y - port.size / 2,
          port.size,
          port.size,
        ),
      );
    });

    test('SymbolHitTest ranks exactly the regions a scene would carry', () {
      final s = _symbol(
        ports: [_in('J01'), _out('J02')],
        origin: const DPt(7, 9),
      );
      expect(SymbolHitTest(symbols: [s]).regions, symbolHitRegions([s]));
    });

    test('every symbol contributes one region per pin plus one body', () {
      final s = _symbol(
        ports: [
          _in('L'),
          _out('R'),
          _port('T', family: 'net.ethernet', direction: PortDirection.sink),
          _port('B', family: 'power.ac_iec', direction: PortDirection.sink),
        ],
      );
      final regions = symbolHitRegions([s]);
      expect(regions, hasLength(5));
      expect(regions.where((r) => r.partKey == null), hasLength(1));
      expect(
        regions.where((r) => r.partKey != null).map((r) => r.partKey),
        s.allPorts.map((p) => p.key),
      );
    });
  });

  group('value semantics', () {
    test('SymbolHitResult compares by value', () {
      const a = SymbolHitResult(
        kind: SymbolHitKind.port,
        position: DPt(1, 2),
        nodeId: 'n',
        portKey: 'p',
        side: SymbolSide.left,
      );
      const b = SymbolHitResult(
        kind: SymbolHitKind.port,
        position: DPt(1, 2),
        nodeId: 'n',
        portKey: 'p',
        side: SymbolSide.left,
      );
      const c = SymbolHitResult(
        kind: SymbolHitKind.port,
        position: DPt(1, 2),
        nodeId: 'n',
        portKey: 'q',
        side: SymbolSide.left,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('SymbolHitTestParams compares by value', () {
      expect(const SymbolHitTestParams(), const SymbolHitTestParams());
      expect(
        const SymbolHitTestParams(portHitTolerance: 12),
        const SymbolHitTestParams(portHitTolerance: 12),
      );
      expect(
        const SymbolHitTestParams(),
        isNot(const SymbolHitTestParams(portHitTolerance: 14)),
      );
    });

    test('a default-constructed result reports no hit', () {
      const r = SymbolHitResult();
      expect(r.kind, SymbolHitKind.none);
      expect(r.nodeId, isNull);
    });
  });

  group('SymbolPort.bankKey — published for multi-draw (DR-012.2)', () {
    test("a pin's bank survives into the rendered symbol", () {
      // It did not before M2-F Phase 4. `bankKey` was read ONCE, by
      // `symbolSideForPort`, to choose an edge — and then discarded, so a
      // caller holding a `RenderedSymbol` could not ask which bank a pin
      // was in. docs/05:484's multi-draw is "with N ports selected in ONE
      // BANK", which that surface could not express.
      final symbol = _symbol(
        ports: [
          PortDef(
            key: const PortKey('in.1'),
            label: 'IN 1',
            connector: const ConnectorTypeId('test'),
            signalFamily: const SignalFamilyId('video.hdmi.2_0'),
            face: Face.rear,
            order: const FracIndex('a0'),
            direction: PortDirection.sink,
            bankKey: 'inputs',
          ),
          _out('out.1'),
        ],
      );
      final banked = symbol.allPorts.firstWhere((p) => p.key == 'in.1');
      final unbanked = symbol.allPorts.firstWhere((p) => p.key == 'out.1');
      expect(banked.bankKey, 'inputs');
      expect(
        unbanked.bankKey,
        isNull,
        reason:
            'a pin in no bank says so, rather than being lumped with '
            'the last one that had a key',
      );
    });

    test('the seed catalog really does populate banks, so the gesture has '
        'data to work with', () {
      // The counterpart to DR-012's three EMPTY fields. Banks are the one
      // grouping the catalog actually declares — 257 ports carry one —
      // which is why multi-draw is buildable where a rule reading
      // `channelIndex` would not have been.
      final catalog = buildSeedCatalog();
      var banked = 0;
      var total = 0;
      for (final body in catalog.values) {
        for (final port in body.ports) {
          total++;
          if (port.bankKey != null) banked++;
        }
      }
      expect(total, greaterThan(0));
      expect(
        banked,
        greaterThan(total ~/ 2),
        reason:
            'most catalog ports declare a bank; if that ever stops '
            'being true, multi-draw loses its selection unit',
      );
    });

    test('bankKey participates in equality — two pins alike but for their '
        'bank are not the same pin', () {
      const a = SymbolPort(
        key: 'p',
        label: 'P',
        side: SymbolSide.left,
        offset: 1,
        size: 2,
        direction: PortDirection.sink,
        family: SignalFamilyId('f'),
        bankKey: 'one',
      );
      const b = SymbolPort(
        key: 'p',
        label: 'P',
        side: SymbolSide.left,
        offset: 1,
        size: 2,
        direction: PortDirection.sink,
        family: SignalFamilyId('f'),
        bankKey: 'two',
      );
      expect(a, isNot(b));
      expect(
        a,
        SymbolPort(
          key: a.key,
          label: a.label,
          side: a.side,
          offset: a.offset,
          size: a.size,
          direction: a.direction,
          family: a.family,
          bankKey: a.bankKey,
        ),
      );
    });
  });
}
