// canon §11.1.3's "whole v1 router", under test.
//
// Every assertion here is about a PROPERTY the ruling states — orthogonal,
// deterministic, a fixed bend budget, no channel allocation — rather than
// about a coordinate this implementation happens to produce. A golden of
// the point list would pass forever and would tell nobody whether the
// router still obeys the ruling.

import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'schematic_test_document.dart';

/// Whether the axis-aligned segment [a]–[b] enters [body]'s INTERIOR.
///
/// RE-DERIVED HERE rather than reaching for the router's own `_cuts`, and
/// deliberately: a test that asks an implementation whether it obeys itself
/// proves nothing. Strict on all four edges for the same reason the router's
/// copy is strict — every pin sits exactly ON a body edge
/// (`symbolPortCentre`), so an inclusive test would call every wire's own
/// escape stub a crossing and this file would assert nothing at all.
bool cutsBody(DPt a, DPt b, DBox body) {
  double lo(double x, double y) => x < y ? x : y;
  double hi(double x, double y) => x > y ? x : y;
  if (a.y == b.y) {
    if (a.y <= body.top || a.y >= body.bottom) return false;
    return hi(a.x, b.x) > body.left && lo(a.x, b.x) < body.right;
  }
  if (a.x <= body.left || a.x >= body.right) return false;
  return hi(a.y, b.y) > body.top && lo(a.y, b.y) < body.bottom;
}

/// Whether any segment of [points] enters any of [bodies].
bool routeCuts(List<DPt> points, Iterable<DBox> bodies) {
  for (var i = 1; i < points.length; i++) {
    for (final body in bodies) {
      if (cutsBody(points[i - 1], points[i], body)) return true;
    }
  }
  return false;
}

/// How far [escape] sits from [pin] — read back off the route rather than
/// recomputed, so a test never has to know the comb's arithmetic.
double escapeLength(DPt pin, DPt escape) =>
    (escape.x - pin.x).abs() + (escape.y - pin.y).abs();

/// Every consecutive pair of [points] shares an x or a y.
void expectOrthogonal(List<DPt> points, String what) {
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    expect(
      a.x == b.x || a.y == b.y,
      isTrue,
      reason:
          '$what segment $i runs from $a to $b, which is diagonal. §11.1.1 '
          'says an orthogonal polyline and nothing else is one.',
    );
  }
}

void main() {
  late RackDocument doc;
  late SchematicScene scene;

  setUp(() {
    doc = buildSchematicTestDocument();
    scene = buildFixtureScene(doc);
  });

  DrawnWireLayer layerFor(Set<Uuid> ids) => buildDrawnWireLayer(
    scene: scene,
    doc: doc,
    linkIds: ids,
    measurer: const FakeMeasurer(),
    palette: const SchematicPalette(),
  );

  group('the trace itself', () {
    test('every wire is orthogonal end to end', () {
      final layer = layerFor(doc.links.keys.toSet());
      expect(layer.wires, hasLength(doc.links.length));
      for (final wire in layer.wires) {
        expectOrthogonal(wire.points, 'wire ${wire.linkId.v}');
      }
    });

    test('no wire exceeds the fixed bend budget', () {
      // canon §11.1.3: "a layer-ordered staircase with a FIXED BEND
      // BUDGET, no channel allocation". A route that needed a fifth bend
      // would be a route that wanted the channel router.
      for (final wire in layerFor(doc.links.keys.toSet()).wires) {
        expect(
          wire.bends,
          lessThanOrEqualTo(kMaxTraceBends),
          reason: 'wire ${wire.linkId.v} has ${wire.bends} bends',
        );
      }
    });

    test('a wire starts and ends exactly on the pin its own net label '
        'starts on', () {
      // THE RE-DERIVATION GUARD. `symbol_layer.dart`'s header records what
      // it cost last time: a painter and a hit-tester each computed a pin
      // centre and disagreed by half a pin. `drawn` and `netLabels` are
      // two renderings of ONE Link, so they must leave from one point.
      final byLink = <Uuid, List<DPt>>{};
      for (final label in scene.netLabels) {
        byLink.putIfAbsent(label.linkId, () => <DPt>[]).add(label.pinCentre);
      }
      for (final wire in layerFor(doc.links.keys.toSet()).wires) {
        final pins = byLink[wire.linkId]!;
        expect(pins, contains(wire.points.first));
        expect(pins, contains(wire.points.last));
      }
    });

    test('a straight run is two points, not six collinear ones', () {
      // The bend budget is asserted on `points.length`, so a case analysis
      // that emitted collinear corners would silently spend budget it did
      // not use — and `_simplify` is the only thing preventing it.
      final points = orthogonalTrace(
        fromPin: const DPt(0, 100),
        fromSide: SymbolSide.right,
        fromEscape: 10,
        toPin: const DPt(200, 100),
        toSide: SymbolSide.left,
        toEscape: 10,
      );
      expect(points, <DPt>[const DPt(0, 100), const DPt(200, 100)]);
    });

    test('a mixed-axis pair is an L, and each end leaves along its own '
        'edge', () {
      // A source on a right edge and a sink on a TOP edge. The L is the
      // only shape that lets the first end leave horizontally and the
      // second arrive vertically, and the two escape points are collinear
      // with its corner — so the honest answer is ONE bend, not three
      // spent on points that sit on the same two lines.
      final points = orthogonalTrace(
        fromPin: const DPt(0, 0),
        fromSide: SymbolSide.right,
        fromEscape: 10,
        toPin: const DPt(100, 200),
        toSide: SymbolSide.top,
        toEscape: 10,
      );
      expectOrthogonal(points, 'mixed');
      expect(points, <DPt>[
        const DPt(0, 0),
        const DPt(100, 0),
        const DPt(100, 200),
      ]);
      // Leaves along the RIGHT edge (horizontally, and outward)…
      expect(points[1].y, points.first.y);
      expect(points[1].x, greaterThan(points.first.x));
      // …and arrives along the TOP edge (vertically, from above).
      expect(points[points.length - 2].x, points.last.x);
      expect(points[points.length - 2].y, lessThan(points.last.y));
    });
  });

  group('a wire goes AROUND a body, never across its face', () {
    test('no wire crosses a body it terminates on, and the fixture really '
        'contains routes that would', () {
      // ── WHAT THE FIELD PHOTOGRAPHED ─────────────────────────────────
      // The staircase's corridor is the MIDPOINT of the two escape
      // points, and a midpoint lies beyond both of them only while the
      // two ends escape TOWARDS each other. On a backward edge they do
      // not, so the corridor landed BETWEEN them: the wire left its pin,
      // turned straight back around and ran across the face of its own
      // symbol — over the header band, over the pin labels that had just
      // been moved inside for exactly this reason, and out the far side.
      // Two of them on one pin row read as one line through the device.
      //
      // ── THE SECOND HALF IS THE HALF THAT MATTERS ────────────────────
      // "Nothing crosses anything" passes vacuously on a sheet laid out
      // entirely forward, and would have passed for the whole life of the
      // defect. So every link is re-routed with its BODIES WITHHELD and
      // the routes that then cut are counted: this fixture is REQUIRED to
      // be one the assertion above can fail on, and the day it stops
      // being one, this line says so instead of the suite going quiet.
      final layer = layerFor(doc.links.keys.toSet());
      expect(layer.wires, isNotEmpty);
      var wouldCut = 0;
      for (final wire in layer.wires) {
        final ends = scene.netLabels
            .where((l) => l.linkId == wire.linkId)
            .toList();
        final bodies = <DBox>[
          for (final end in ends)
            scene.symbols.firstWhere((s) => s.id == end.deviceId).bodyRect,
        ];
        for (var i = 1; i < wire.points.length; i++) {
          for (final body in bodies) {
            expect(
              cutsBody(wire.points[i - 1], wire.points[i], body),
              isFalse,
              reason:
                  '${doc.links[wire.linkId]!.designator} runs from '
                  '${wire.points[i - 1]} to ${wire.points[i]} — through '
                  '$body, a body it terminates on',
            );
          }
        }
        if (ends.length < 2) continue;
        final bare = orthogonalTrace(
          fromPin: ends[0].pinCentre,
          fromSide: ends[0].side,
          fromEscape: escapeLength(ends[0].pinCentre, wire.ends[0]),
          toPin: ends[1].pinCentre,
          toSide: ends[1].side,
          toEscape: escapeLength(ends[1].pinCentre, wire.ends[1]),
        );
        if (routeCuts(bare, bodies)) wouldCut++;
      }
      expect(
        wouldCut,
        greaterThan(0),
        reason:
            'every link in the fixture routes cleanly WITHOUT the detour, '
            'so the assertion above is about nothing',
      );
    });

    test('a backward pair takes a lane clear of both bodies instead of '
        'running back through them', () {
      // Two symbols side by side; the link joins the pin on the LEFT
      // one's left edge to the pin on the RIGHT one's right edge. Both
      // escapes point outward, away from each other, so their midpoint
      // lands squarely inside both. This is the screenshot's shape.
      const from = DBox.fromLtwh(0, 0, 100, 100);
      const to = DBox.fromLtwh(300, 0, 100, 100);
      const fromPin = DPt(0, 50);
      const toPin = DPt(400, 50);
      const bodies = <DBox>[from, to];

      final bare = orthogonalTrace(
        fromPin: fromPin,
        fromSide: SymbolSide.left,
        fromEscape: 10,
        toPin: toPin,
        toSide: SymbolSide.right,
        toEscape: 10,
      );
      expect(
        routeCuts(bare, bodies),
        isTrue,
        reason:
            'the geometry must be one the plain staircase gets wrong, or '
            'the assertions below are about nothing',
      );

      final around = orthogonalTrace(
        fromPin: fromPin,
        fromSide: SymbolSide.left,
        fromEscape: 10,
        fromBody: from,
        toPin: toPin,
        toSide: SymbolSide.right,
        toEscape: 10,
        toBody: to,
      );
      expectOrthogonal(around, 'detour');
      expect(routeCuts(around, bodies), isFalse);
      expect(
        around.length - 2,
        lessThanOrEqualTo(kMaxTraceBends),
        reason: 'the detour spends the budget, it does not raise it',
      );
      // THE LANE CLEARS THE UNION, not one body. A lane derived from the
      // near end alone would leave the far end's approach crossing its own
      // partner, which is the same defect one symbol along.
      final highest = around.map((p) => p.y).reduce((a, b) => a < b ? a : b);
      expect(highest, lessThan(from.top));
      expect(highest, lessThan(to.top));
    });

    test('a backward MIXED pair is met along its own edge, from outside', () {
      // A right-edge pin and a BOTTOM-edge pin on a symbol directly below
      // it. The L's corner lands inside the first body, so the direct
      // route crosses the face it has just left.
      //
      // WHICH SIDE THE LANE RUNS DOWN IS NOT A COST QUESTION HERE: a
      // top/bottom pin can only be met from the side it escapes to, so
      // the pin decides. `_detour`'s own note says why no test in this
      // file distinguishes that rule from the cost one — in every
      // routable case the two agree, and claiming otherwise would be
      // reading more into this test than it does.
      const from = DBox.fromLtwh(0, 0, 100, 100);
      const to = DBox.fromLtwh(0, 200, 100, 100);
      const fromPin = DPt(100, 50);
      const toPin = DPt(50, 300);
      const bodies = <DBox>[from, to];

      final bare = orthogonalTrace(
        fromPin: fromPin,
        fromSide: SymbolSide.right,
        fromEscape: 10,
        toPin: toPin,
        toSide: SymbolSide.bottom,
        toEscape: 10,
      );
      expect(routeCuts(bare, bodies), isTrue, reason: 'see the pair above');

      final around = orthogonalTrace(
        fromPin: fromPin,
        fromSide: SymbolSide.right,
        fromEscape: 10,
        fromBody: from,
        toPin: toPin,
        toSide: SymbolSide.bottom,
        toEscape: 10,
        toBody: to,
      );
      expectOrthogonal(around, 'mixed detour');
      expect(routeCuts(around, bodies), isFalse);
      expect(around.length - 2, lessThanOrEqualTo(kMaxTraceBends));
      // ARRIVES FROM BELOW, which is the whole of what "along its own
      // edge" means for a bottom pin: the last leg is vertical and comes
      // from outboard, exactly as the forward L's does.
      final last = around[around.length - 2];
      expect(last.x, toPin.x);
      expect(
        last.y,
        greaterThan(toPin.y),
        reason: 'a bottom pin met from ABOVE has been met through its own '
            'body',
      );
    });

    test("the lane never lands short of an end's own escape, so a wire "
        'does not overshoot its pin and come back', () {
      // ── WHAT PINS THE CLEARANCE, AND NOTHING ELSE DID ───────────────
      // The lane is set one CLEARANCE past the union of the two bodies,
      // and clearance is the LARGER of the two escape distances. Nothing
      // above can see that choice: every geometry in this group gives
      // both ends the same escape, and with equal escapes the larger and
      // the smaller are the same number. Swapping `max` for `min` passed
      // the whole file.
      //
      // It matters as soon as the comb makes them differ, which on a real
      // sheet it does constantly. A lane closer in than an end's own
      // escape point sits BETWEEN that end's body and its escape, so the
      // wire runs out to the lane, carries on PAST the pin to the escape,
      // and then turns round and comes back to the pin — a spike hanging
      // off a jack, which is not a crossing and so no assertion about
      // bodies could ever catch it.
      const from = DBox.fromLtwh(0, 0, 100, 100);
      const to = DBox.fromLtwh(0, 200, 100, 100);
      const fromPin = DPt(100, 50);
      const toPin = DPt(50, 300);
      const toEscape = 40.0;

      final around = orthogonalTrace(
        fromPin: fromPin,
        fromSide: SymbolSide.right,
        // DELIBERATELY UNEQUAL, and this is the whole fixture: the far end
        // is four comb steps out where the near end is one.
        fromEscape: 10,
        fromBody: from,
        toPin: toPin,
        toSide: SymbolSide.bottom,
        toEscape: toEscape,
        toBody: to,
      );
      expect(routeCuts(around, const <DBox>[from, to]), isFalse);

      // Walking back from the pin, while the route is still in the pin's
      // own column, each corner must be FURTHER from the pin than the last
      // — the approach only ever closes.
      var previous = 0.0;
      for (var i = around.length - 2; i >= 0; i--) {
        if (around[i].x != toPin.x) break;
        final away = around[i].y - toPin.y;
        expect(
          away,
          greaterThan(previous),
          reason:
              'the route reaches ${around[i]} and then turns back towards '
              'the pin at $toPin: $around',
        );
        previous = away;
      }
      expect(
        previous,
        greaterThanOrEqualTo(toEscape),
        reason:
            'the approach never reached the escape point, so the loop '
            'above walked nothing and proved nothing',
      );
    });

    test('a cyclic sheet routes cleanly too, mixed pairs and all', () {
      // The five-link fixture is a DAG, and on a DAG every top/bottom-pin
      // end lands on the forward side of its partner — so the mixed
      // branch of the detour is reachable there only through a hand-built
      // box, as two tests above do. Closing the graph makes the layering
      // break a cycle, and the edge it breaks is drawn against the layer
      // order: a real backward mixed pair, on a real scene, through the
      // whole layer rather than through `orthogonalTrace` alone.
      final cyclic = buildSchematicTestDocument(feedback: true);
      final cyclicScene = buildFixtureScene(cyclic);
      final layer = buildDrawnWireLayer(
        scene: cyclicScene,
        doc: cyclic,
        linkIds: cyclic.links.keys.toSet(),
        measurer: const FakeMeasurer(),
        palette: const SchematicPalette(),
      );
      var mixedDetours = 0;
      for (final wire in layer.wires) {
        final ends = cyclicScene.netLabels
            .where((l) => l.linkId == wire.linkId)
            .toList();
        final bodies = <DBox>[
          for (final end in ends)
            cyclicScene.symbols
                .firstWhere((s) => s.id == end.deviceId)
                .bodyRect,
        ];
        expect(
          routeCuts(wire.points, bodies),
          isFalse,
          reason:
              '${cyclic.links[wire.linkId]!.designator} crosses a body it '
              'terminates on: ${wire.points}',
        );
        expect(wire.bends, lessThanOrEqualTo(kMaxTraceBends));
        if (ends.length < 2) continue;
        final horizontals = ends
            .where(
              (e) => e.side == SymbolSide.left || e.side == SymbolSide.right,
            )
            .length;
        final bare = orthogonalTrace(
          fromPin: ends[0].pinCentre,
          fromSide: ends[0].side,
          fromEscape: escapeLength(ends[0].pinCentre, wire.ends[0]),
          toPin: ends[1].pinCentre,
          toSide: ends[1].side,
          toEscape: escapeLength(ends[1].pinCentre, wire.ends[1]),
        );
        if (horizontals == 1 && routeCuts(bare, bodies)) mixedDetours++;
      }
      expect(
        mixedDetours,
        greaterThan(0),
        reason:
            'the cyclic fixture no longer produces a backward MIXED pair, '
            'which is the only reason it exists',
      );
    });
  });

  group('a wire leaves its pin AWAY from its own body', () {
    test('no tag pill lands inside the symbol it belongs to', () {
      // THIS TEST EXISTS BECAUSE A MUTATION SURVIVED. Flipping the
      // right-edge escape to run INTO the body passed every assertion in
      // the group above, because `_simplify` erases an escape point the
      // moment it is collinear with the corner that follows it — which,
      // for a horizontal/horizontal pair, it always is. The escape
      // direction is therefore invisible in `points` and visible only in
      // `ends`, which is where the tag pill is drawn (§11.1.1: "a tag pill
      // at each end"). A pill drawn inside its own symbol's body is the
      // user-visible form of the same defect.
      final layer = layerFor(doc.links.keys.toSet());
      expect(layer.wires, isNotEmpty);
      for (final wire in layer.wires) {
        final ends = scene.netLabels
            .where((l) => l.linkId == wire.linkId)
            .toList();
        expect(wire.ends.length, ends.length);
        for (var i = 0; i < wire.ends.length; i++) {
          final symbol = scene.symbols.firstWhere(
            (s) => s.id == ends[i].deviceId,
          );
          expect(
            symbol.bodyRect.contains(wire.ends[i]),
            isFalse,
            reason:
                'the ${ends[i].side.name} pin of ${symbol.designator} put '
                'its tag pill at ${wire.ends[i]}, inside its own body '
                '${symbol.bodyRect}',
          );
        }
      }
    });

    test('each escape point sits on the far side of its own pin', () {
      // The direction stated as a sign rather than as an inequality
      // against a box, so a symbol that happened to be narrow could not
      // make the assertion above pass by accident.
      for (final side in SymbolSide.values) {
        final trace = orthogonalTrace(
          fromPin: const DPt(100, 100),
          fromSide: side,
          fromEscape: 10,
          // A far-away partner on the opposite axis, so the escape point
          // survives as its own corner rather than being simplified away.
          toPin: const DPt(500, 500),
          toSide: side == SymbolSide.left || side == SymbolSide.right
              ? SymbolSide.top
              : SymbolSide.left,
          toEscape: 10,
        );
        final step = DPt(
          trace[1].x - trace[0].x,
          trace[1].y - trace[0].y,
        );
        switch (side) {
          case SymbolSide.left:
            expect(step.x, lessThan(0));
          case SymbolSide.right:
            expect(step.x, greaterThan(0));
          case SymbolSide.top:
            expect(step.y, lessThan(0));
          case SymbolSide.bottom:
            expect(step.y, greaterThan(0));
        }
      }
    });
  });

  group('the comb — a per-link function, not channel allocation', () {
    test('two links off ADJACENT pins of one symbol turn at different '
        'coordinates', () {
      // WITHOUT THIS the two vertical runs would be drawn on top of each
      // other, which is worse than the crossings v1 accepts. See
      // `wire_trace.dart`'s header for why the fix is a per-pin comb and
      // not §11.1.3 item 2 arriving by the back door.
      const side = SymbolSide.right;
      final first = orthogonalTrace(
        fromPin: const DPt(0, 0),
        fromSide: side,
        fromEscape: 20,
        toPin: const DPt(400, 100),
        toSide: SymbolSide.left,
        toEscape: 20,
      );
      final second = orthogonalTrace(
        fromPin: const DPt(0, 14),
        fromSide: side,
        // One comb step further out — the i-th pin escapes i steps.
        fromEscape: 34,
        toPin: const DPt(400, 300),
        toSide: SymbolSide.left,
        toEscape: 20,
      );
      final firstCorridor = first[1].x;
      final secondCorridor = second[1].x;
      expect(firstCorridor, isNot(secondCorridor));
    });

    test('two links between the SAME PAIR of symbols get different '
        'corridors', () {
      // THE CASE THE COMB IS FOR, and the only one that can see it. Links
      // to DIFFERENT symbols get different corridors whether or not a comb
      // exists, because the corridor is the midpoint of two escape points
      // and the far end has already moved — a fixture with one link per
      // pair let a mutation that deleted the comb survive. The fixture
      // therefore carries two MTX-1 → AMP-1 links, whose two ends are the
      // same two symbols and whose corridors coincide exactly unless the
      // pin index moves them.
      final mtx = deviceNamed(doc, 'MTX-1');
      final amp = deviceNamed(doc, 'AMP-1');
      final between = <Uuid>{};
      final ends = <Uuid, Set<String>>{};
      for (final label in scene.netLabels) {
        ends.putIfAbsent(label.linkId, () => <String>{}).add(label.deviceId);
      }
      ends.forEach((link, devices) {
        if (devices.containsAll(<String>{mtx.id.v, amp.id.v})) {
          between.add(link);
        }
      });
      expect(
        between,
        hasLength(2),
        reason:
            'the fixture must carry two links between one pair, or this '
            'assertion is about nothing',
      );

      // THE ESCAPE DISTANCE ITSELF, isolated. Comparing whole corner
      // POINTS would pass with no comb at all, because the two links leave
      // different PINS and therefore already differ in the other axis —
      // which is how a mutation that deleted the comb survived the first
      // version of this test. Both pins sit on one edge, so their escape
      // points share a coordinate unless the pin index moves them.
      final escapes = <double>{};
      final corridors = <double>{};
      for (final wire in layerFor(between).wires) {
        final onMtx = scene.netLabels.firstWhere(
          (l) => l.linkId == wire.linkId && l.deviceId == mtx.id.v,
        );
        final horizontal =
            onMtx.side == SymbolSide.left || onMtx.side == SymbolSide.right;
        final end = wire.ends[wire.points.first == onMtx.pinCentre ? 0 : 1];
        escapes.add(horizontal ? end.x : end.y);
        corridors.add(horizontal ? wire.points[1].x : wire.points[1].y);
      }
      expect(
        escapes,
        hasLength(2),
        reason:
            'both links left MTX-1 at the same distance — the comb is not '
            'reaching the pin index',
      );
      expect(
        corridors,
        hasLength(2),
        reason:
            'both links between MTX-1 and AMP-1 turn at the same corridor, '
            'so their runs are drawn on top of each other',
      );
    });
  });

  group('determinism (canon §11.1.3: same input ⇒ byte-identical)', () {
    test('two builds of the same scope produce equal ops', () {
      final a = layerFor(doc.links.keys.toSet());
      final b = layerFor(doc.links.keys.toSet());
      expect(a.ops.length, b.ops.length);
      for (var i = 0; i < a.ops.length; i++) {
        expect('${a.ops[i]}', '${b.ops[i]}', reason: 'op $i diverged');
      }
    });

    test('a second document built the same way lays out the same wires', () {
      final other = buildSchematicTestDocument();
      final otherScene = buildFixtureScene(other);
      final mine = layerFor(doc.links.keys.toSet());
      final theirs = buildDrawnWireLayer(
        scene: otherScene,
        doc: other,
        linkIds: other.links.keys.toSet(),
        measurer: const FakeMeasurer(),
        palette: const SchematicPalette(),
      );
      expect(
        theirs.wires.map((w) => w.points.toString()).toList(),
        mine.wires.map((w) => w.points.toString()).toList(),
      );
    });
  });

  group('the four channels ride the wire', () {
    test("every wire strokes in its family's resolved hue, dash and "
        'weight — never a value this file re-derived', () {
      final layer = layerFor(doc.links.keys.toSet());
      final strokes = layer.ops.whereType<OpPolyline>().toList();
      expect(strokes, hasLength(layer.wires.length));
      for (var i = 0; i < strokes.length; i++) {
        final style = layer.wires[i].style;
        expect(strokes[i].s.argb, style.argb);
        expect(strokes[i].s.widthPt, style.widthPt);
        expect(strokes[i].s.dash, style.dash);
      }
      // And the fixture really does exercise more than one hue, or the
      // three assertions above would pass on a monochrome sheet.
      expect(strokes.map((s) => s.s.argb).toSet().length, greaterThan(1));
    });

    test('each end carries a tag pill naming the cable and its type', () {
      final layer = layerFor(doc.links.keys.toSet());
      final texts = layer.ops.whereType<OpText>().map((t) => t.text).toList();
      final w001 = doc.links.values.firstWhere((l) => l.designator == 'W001');
      final pill = texts.firstWhere((t) => t.startsWith('W001'));
      expect(pill, contains(kSignalTagSeparator));
      // The TYPE half is the family short tag, not the display name:
      // `HDMI 2.0 (18 Gbps)` does not fit a pill.
      expect(pill, contains('HD20'));
      // §4.4's `{length}` term is absent rather than guessed — AC-024's
      // three length fields are M3 and every link here has all three null.
      expect(pill, isNot(contains('ft')));
      expect(w001.services, isNotEmpty);
      // Two pills per link: "a tag pill at each end" (§11.1.1).
      expect(texts.where((t) => t.startsWith('W001')), hasLength(2));
    });
  });

  group('scope, and what falls outside it', () {
    test('an empty scope draws nothing at all', () {
      // DR-001: labels are the base state. A sheet with no filter, no
      // hover and no focus must emit ZERO wire ops, and `M2-D`'s own test
      // asserts the same thing about `OpPolyline` in the scene.
      final layer = layerFor(const <Uuid>{});
      expect(layer.ops, isEmpty);
      expect(layer.wires, isEmpty);
    });

    test('a scope of one link draws one wire, not the sheet', () {
      final one = doc.links.keys.first;
      final layer = layerFor(<Uuid>{one});
      expect(layer.wires, hasLength(1));
      expect(layer.wires.single.linkId, one);
    });

    test('a link with no drawn end is counted, never silently dropped', () {
      // A link whose ends are not `PortEndpoint`s gets no stub from M2-D
      // and can get no wire from here. Counting it is the same discipline
      // `NetLabelLayerBuild.unlabelledLinkIds` applies.
      final at = DateTime.utc(2026, 7, 28, 9);
      const id = Uuid('0190e0aa-0000-7000-8000-0000000ffff1');
      doc.links[id] = Link(
        id: id,
        designator: 'W900',
        media: const MediaTypeId('media.cat6'),
        order: const FracIndex('z0'),
        meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
        conductors: [
          const Conductor(
            from: OpenEndpoint('field'),
            to: OpenEndpoint('field'),
          ),
        ],
      );
      final rebuilt = buildFixtureScene(doc);
      final layer = buildDrawnWireLayer(
        scene: rebuilt,
        doc: doc,
        linkIds: <Uuid>{id},
        measurer: const FakeMeasurer(),
        palette: const SchematicPalette(),
      );
      expect(layer.wires, isEmpty);
      expect(layer.unroutableLinkIds, <Uuid>[id]);
    });
  });
}
