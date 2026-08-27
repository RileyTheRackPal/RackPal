// canon §11.1.3's "whole v1 router", under test.
//
// Every assertion here is about a PROPERTY the ruling states — orthogonal,
// deterministic, a fixed bend budget, no channel allocation — rather than
// about a coordinate this implementation happens to produce. A golden of
// the point list would pass forever and would tell nobody whether the
// router still obeys the ruling.

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

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

  group('the corridor — the one position this router chooses', () {
    // Two symbols side by side, both wired through TOP pins, so the two
    // ends escape THE SAME WAY and the corridor is a horizontal row above
    // them. Bodies are withheld throughout: this group is about where the
    // corridor goes when nothing is in the way, which is the case the
    // detour never sees and the case almost every wire on a sheet is in.
    const a = DBox.fromLtwh(0, 0, 100, 100);
    const b = DBox.fromLtwh(300, 0, 100, 100);
    const pinA = DPt(50, 0);
    const pinB = DPt(350, 0);

    List<DPt> pair(double escapeA, double escapeB) => orthogonalTrace(
      fromPin: pinA,
      fromSide: SymbolSide.top,
      fromEscape: escapeA,
      toPin: pinB,
      toSide: SymbolSide.top,
      toEscape: escapeB,
    );

    test('a same-way pair meets PAST the further escape, so neither end '
        'doubles back to reach it', () {
      // ── THE SPIKE, WHICH NO ASSERTION ABOUT BODIES CAN SEE ──────────
      // The corridor was the MIDPOINT of the two escape points. Between
      // two ends facing each other that is right and it is what the three
      // cases were written for. Between two ends facing THE SAME WAY it is
      // a point they are both trying to get past: the near end overshoots
      // to it, and the far end — already beyond it — has to come back
      // inward to meet it, then turn round again for its own pin. The
      // result is a spike hanging off the far jack. It crosses nothing, it
      // is perfectly orthogonal, and it stays inside the bend budget, so
      // every property this file asserted about routes passed over it.
      final route = pair(10, 200);
      expectOrthogonal(route, 'same-way corridor');
      expect(route.length - 2, lessThanOrEqualTo(2));

      // Walking back from EACH pin, while the route is still in that pin's
      // own column, every corner must be further out than the last — the
      // approach only ever closes.
      for (final (pin, corners) in <(DPt, List<DPt>)>[
        (pinA, route),
        (pinB, route.reversed.toList()),
      ]) {
        var previous = 0.0;
        for (var i = corners.length - 2; i >= 0; i--) {
          if (corners[i].x != pin.x) break;
          final away = (corners[i].y - pin.y).abs();
          expect(
            away,
            greaterThan(previous),
            reason:
                'the route reaches ${corners[i]} and then turns back '
                'towards the pin at $pin: $route',
          );
          previous = away;
        }
      }
      // The corridor really is past the FURTHER of the two escapes, which
      // is the whole rule; `min` of the two would satisfy the walk above
      // for one end and strand the other inside its own body.
      expect(route.map((p) => p.y).reduce((x, y) => x < y ? x : y), -200);
      expect(routeCuts(route, const <DBox>[a, b]), isFalse);
    });

    test('two links whose escapes merely SUM alike still get different '
        'corridors', () {
      // ── THE REVERSE-WIRED PATCH PANEL ───────────────────────────
      // The midpoint tracks the SUM of the two combs, not either comb. Any
      // two links whose two escape distances add up alike therefore share
      // a corridor however far apart their pins are — and a panel patched
      // in reverse, port 01 to port 48 and port 02 to port 47, makes every
      // one of its cables such a pair. Forty-eight wires, one line.
      //
      // This is the assertion the comb's own tests cannot make: they vary
      // ONE pin's index against a partner whose index moves with it, so
      // the sum moves too and a midpoint looks like it is tracking the
      // comb. It is the crossed pairing that separates the two rules.
      final crossed = pair(10, 90);
      final straight = pair(50, 50);
      double corridorOf(List<DPt> route) =>
          route.map((p) => p.y).reduce((x, y) => x < y ? x : y);
      expect(
        corridorOf(crossed),
        isNot(corridorOf(straight)),
        reason:
            'both pairs of escapes sum to 100, so a corridor at their '
            'midpoint puts these two cables on one line',
      );
    });

    test('a pair facing EACH OTHER still meets in the middle', () {
      // The forward edge — a right edge feeding a left edge further right,
      // which is what Sugiyama's layering produces and what the great
      // majority of a sheet is. Both ends reach the midpoint travelling the
      // way they left, so it stays the answer, and the rule above must not
      // have quietly moved it.
      final route = orthogonalTrace(
        fromPin: const DPt(0, 0),
        fromSide: SymbolSide.right,
        fromEscape: 10,
        toPin: const DPt(400, 100),
        toSide: SymbolSide.left,
        toEscape: 30,
      );
      expectOrthogonal(route, 'forward corridor');
      // Escapes at x=10 and x=370; the corridor is their midpoint, which
      // lies BETWEEN them — the one thing a same-way pair cannot have.
      expect(route[1].x, (10 + 370) / 2);
      expect(route[1].x, greaterThan(10));
      expect(route[1].x, lessThan(370));
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
      // Two symbols; the link joins the pin on the UPPER one's left edge to
      // the pin on the LOWER one's right edge. Both escapes point outward,
      // away from each other, so their midpoint lands squarely inside both.
      // This is the screenshot's shape.
      //
      // THE SINK IS PUT BELOW THE SOURCE ON PURPOSE. With both pins on one
      // row the cable has no direction along the lane's axis, the lane is
      // decided by a documented tie-break, and this test would be asserting
      // the tie-break rather than the rule.
      const from = DBox.fromLtwh(0, 0, 100, 100);
      const to = DBox.fromLtwh(300, 200, 100, 100);
      const fromPin = DPt(0, 50);
      const toPin = DPt(400, 250);
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
      final lowest = around.map((p) => p.y).reduce((a, b) => a > b ? a : b);
      expect(lowest, greaterThan(from.bottom));
      expect(lowest, greaterThan(to.bottom));
    });

    test('two pins in opposite halves of ONE body leave by opposite '
        'sides', () {
      // ── THE RULE, AND THE TWO IT REPLACED ──────────────────────
      // FIRST the lane was the SHORTER of the two, and at scale the two
      // costs sit within a few per cent of each other — so the choice
      // flipped between adjacent ports on nothing but where each one's
      // partner happened to sit, and cables that plainly belonged together
      // left in opposite directions and met head-on along a shared lane.
      //
      // THEN it was the direction of FLOW, source towards sink. That fixed
      // the flipping and broke the other way: Sugiyama lays sources left of
      // sinks, so every run off one switch turned the SAME way and the ones
      // on the far side dragged a wire across the whole 48-port body.
      //
      // Both were rules about the PAIR. This one is about the PIN: a port
      // leaves by the nearest corner of its OWN body, so the fan splits down
      // the middle of the symbol and nothing crosses more than half of it.
      //
      // THE FIXTURE IS A WIDE SYMBOL, deliberately — the defect only exists
      // on a body wide enough for "which half" to be a real question, and a
      // 100-unit box would let a broken rule pass by being too small to
      // show the difference.
      const switchBody = DBox.fromLtwh(0, 0, 1000, 100);
      const field = DBox.fromLtwh(400, 400, 100, 100);
      const bodies = <DBox>[switchBody, field];
      const sink = DPt(450, 400);

      List<DPt> fromPort(double x) => orthogonalTrace(
        fromPin: DPt(x, 0),
        fromSide: SymbolSide.top,
        fromEscape: 10,
        fromBody: switchBody,
        toPin: sink,
        toSide: SymbolSide.top,
        toEscape: 10,
        toBody: field,
      );

      final nearLeft = fromPort(100);
      final nearRight = fromPort(900);
      for (final route in <List<DPt>>[nearLeft, nearRight]) {
        expectOrthogonal(route, 'half-rule detour');
        expect(routeCuts(route, bodies), isFalse);
        expect(route.length - 2, lessThanOrEqualTo(kMaxTraceBends));
      }

      // The port in the LEFT half leaves to the left of the whole body…
      expect(
        nearLeft.map((p) => p.x).reduce((a, b) => a < b ? a : b),
        lessThan(switchBody.left),
      );
      // …and the one in the RIGHT half leaves to the right of it.
      expect(
        nearRight.map((p) => p.x).reduce((a, b) => a > b ? a : b),
        greaterThan(switchBody.right),
      );
      // NEITHER WRAPS THE FAR END OF THE SWITCH, which is the property the
      // whole change is for and the one the flow rule lost. Asserting only
      // that the two differ would pass on a rule that sent BOTH of them the
      // long way round, which is exactly what the field photographed.
      expect(
        nearLeft.map((p) => p.x).reduce((a, b) => a > b ? a : b),
        lessThan(switchBody.right),
        reason: 'a left-half port reached round the far right of its own body',
      );
      expect(
        nearRight.map((p) => p.x).reduce((a, b) => a < b ? a : b),
        greaterThan(switchBody.left),
        reason: 'a right-half port reached round the far left of its own body',
      );
    });

    test('a pair escaping the SAME way runs its corridor PAST both, and '
        'does not go round the side at all', () {
      // ── THE BRACKETS THE FIELD PHOTOGRAPHED ───────────────────
      // A patch panel at the bottom of a sheet, feeding a device far
      // above, both through TOP-edge pins. The corridor runs across the
      // escape axis — a horizontal row between two top pins — and putting
      // it at the MIDPOINT lands it inside the device above. Running it
      // past the further of the two escapes instead keeps the shape the
      // reader already knows: up, across, down. Two dozen of those are a
      // comb.
      //
      // What the router did instead was turn the moment it cleared the pin
      // and go round the OUTSIDE of the pair, which against a 1000-unit-wide
      // panel is a bracket enclosing the whole drawing. The field sent a
      // picture of two dozen of them nested inside each other.
      const panel = DBox.fromLtwh(0, 800, 1000, 100);
      const above = DBox.fromLtwh(600, 0, 200, 100);
      const bodies = <DBox>[panel, above];

      // ── THE FIXTURE IS ONE THE MIDPOINT GETS WRONG ──────────────────
      // Asserted by building the midpoint route BY HAND rather than by
      // asking `orthogonalTrace` for an undetoured one, which is what this
      // guard used to do. It cannot any more: the corridor rule lives in
      // the staircase now, so the routed and unrouted answers here are the
      // same route and the old guard was comparing a thing to itself.
      const mid = DPt(100, (790 + -10) / 2);
      expect(
        routeCuts(
          <DPt>[
            const DPt(100, 800),
            mid,
            DPt(700, mid.y),
            const DPt(700, 0),
          ],
          bodies,
        ),
        isTrue,
        reason:
            'a corridor at the midpoint of the two escapes must land '
            'inside a body here, or nothing below is about the rule',
      );

      final route = orthogonalTrace(
        fromPin: const DPt(100, 800),
        fromSide: SymbolSide.top,
        fromEscape: 10,
        fromBody: panel,
        toPin: const DPt(700, 0),
        toSide: SymbolSide.top,
        toEscape: 10,
        toBody: above,
      );
      expectOrthogonal(route, 'pushed-out corridor');
      expect(routeCuts(route, bodies), isFalse);

      // IT NEVER STEPS OUTSIDE THE PAIR SIDEWAYS, which is the whole
      // difference between a staircase and a bracket. The side lane would
      // put a corner a clearance beyond `panel.left` and come back.
      expect(
        route.map((p) => p.x).reduce((a, b) => a < b ? a : b),
        greaterThanOrEqualTo(panel.left),
        reason:
            'the wire went round the outside instead of over the top: '
            '$route',
      );
      // The corridor is ABOVE both bodies, which is the side both ends
      // escape towards — the only side either of them could reach.
      expect(
        route.map((p) => p.y).reduce((a, b) => a < b ? a : b),
        lessThan(above.top),
      );
      // AND IT IS CHEAPER IN CORNERS, not just in ink: up, across, down.
      expect(
        route.length - 2,
        lessThanOrEqualTo(2),
        reason: 'a pushed-out corridor is two bends; $route',
      );
    });

    test('the WIDER body decides when the two pins want opposite sides, '
        'and flow breaks a true tie', () {
      // ── A TOP PIN AND A BOTTOM PIN, WHICH IS NOT AN ARBITRARY CHOICE ──
      // The side lane is only REACHED when the pushed-out corridor is
      // unavailable, and it is unavailable exactly when the two ends
      // escape in opposite directions along the corridor's axis — no row
      // outside both bodies can be met from above by one end and from
      // below by the other. So a pair of top pins never gets here at all,
      // and a fixture built from one would be asserting the corridor's
      // behaviour while claiming to test the lane's.
      const wide = DBox.fromLtwh(0, 0, 1000, 100);
      const narrow = DBox.fromLtwh(400, 400, 100, 100);
      final decided = orthogonalTrace(
        // LEFT half of the wide body, escaping UP — wants the left lane.
        fromPin: const DPt(100, 0),
        fromSide: SymbolSide.top,
        fromEscape: 10,
        fromBody: wide,
        // RIGHT half of the narrow one, escaping DOWN — wants the right.
        toPin: const DPt(480, 500),
        toSide: SymbolSide.bottom,
        toEscape: 10,
        toBody: narrow,
      );
      expect(routeCuts(decided, const <DBox>[wide, narrow]), isFalse);
      expect(
        decided.map((p) => p.x).reduce((a, b) => a < b ? a : b),
        lessThan(wide.left),
        reason: 'the narrow body outvoted the wide one',
      );

      // AND WHEN THE SPANS ARE EQUAL there is no nearer corner to appeal
      // to, so the tie falls through to the direction the cable FLOWS —
      // which is why reversing source and sink flips it. No rule based on
      // the pins' positions alone can do that, those being unchanged by
      // the swap.
      const a = DBox.fromLtwh(0, 0, 100, 100);
      const b = DBox.fromLtwh(300, 400, 100, 100);
      const topOfA = DPt(25, 0); // left half of A, escaping up
      const underB = DPt(375, 500); // right half of B, escaping down
      List<DPt> flow(
        DPt source,
        SymbolSide sourceSide,
        DBox sourceBody,
        DPt sink,
        SymbolSide sinkSide,
        DBox sinkBody,
      ) => orthogonalTrace(
        fromPin: source,
        fromSide: sourceSide,
        fromEscape: 10,
        fromBody: sourceBody,
        toPin: sink,
        toSide: sinkSide,
        toEscape: 10,
        toBody: sinkBody,
      );
      final downstream = flow(
        topOfA,
        SymbolSide.top,
        a,
        underB,
        SymbolSide.bottom,
        b,
      );
      final upstream = flow(
        underB,
        SymbolSide.bottom,
        b,
        topOfA,
        SymbolSide.top,
        a,
      );
      expect(
        downstream.map((p) => p.x).reduce((x, y) => x > y ? x : y),
        greaterThan(b.right),
      );
      expect(
        upstream.map((p) => p.x).reduce((x, y) => x < y ? x : y),
        lessThan(a.left),
      );
      expect(routeCuts(downstream, const <DBox>[a, b]), isFalse);
      expect(routeCuts(upstream, const <DBox>[a, b]), isFalse);
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
        reason:
            'a bottom pin met from ABOVE has been met through its own '
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

    test('and the PILL clears the body too, which its anchor alone cannot '
        'tell you', () {
      // ── THE OTHER HALF OF THE FIELD'S SCREENSHOT ────────────────────
      // The test above asserts a POINT is outside the body, and passed
      // while the pill hanging from that point painted over the port
      // label: `escapeGu` is 3 gu and `W053 · VID·HD21` is several times
      // that wide, so a pill CENTRED on the escape put its inner half
      // back inside the symbol — and pills are flushed last, so it won.
      // `HDMI IN 1` read as `MI IN 1`.
      //
      // A point cannot see that; only the box can. The pill now hangs
      // OUTBOARD of its anchor, the rule `net_label_layer` already uses
      // for the pennant at the end of a leader (DR-001: two renderings of
      // one Link put the flag naming it in the same place).
      final layer = layerFor(doc.links.keys.toSet());
      final boxes = layer.ops.whereType<OpRoundRect>().toList();
      expect(boxes, isNotEmpty);
      var at = 0;
      for (final wire in layer.wires) {
        for (final end in scene.netLabels.where(
          (l) => l.linkId == wire.linkId,
        )) {
          final symbol = scene.symbols.firstWhere(
            (s) => s.id == end.deviceId,
          );
          final box = boxes[at++].r;
          expect(
            box.intersects(symbol.bodyRect),
            isFalse,
            reason:
                'the ${end.side.name} pin of ${symbol.designator} put its '
                'tag pill at $box, overlapping its own body '
                '${symbol.bodyRect}',
          );
          // AND THE PILL IS WIDE ENOUGH FOR THE DISTINCTION TO EXIST. A
          // pill narrower than the escape distance would clear the body
          // however it was anchored, and this assertion would then be
          // passing for a reason that has nothing to do with the fix.
          expect(
            box.width,
            greaterThan(const SchematicWireStyle().escapeGu * 2),
            reason:
                'a pill this narrow cannot straddle an edge, so the '
                'assertion above proves nothing about where it hangs',
          );
        }
      }
      expect(
        at,
        boxes.length,
        reason: 'every pill drawn belongs to a wire that was walked',
      );
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
