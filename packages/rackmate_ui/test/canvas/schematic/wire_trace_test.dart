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
