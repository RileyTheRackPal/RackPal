// M2-F PHASE 2 — the caret, the armed pin and the band between them.
//
// The overlay is the only thing a SIGHTED keyboard user has: the status
// line says where the caret is, and this says it on the sheet. So the tests
// below are about the two properties that make it a cursor rather than a
// decoration — it is where the pin actually is, and it is the same size to
// the eye at every zoom.

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'schematic_test_document.dart';

void main() {
  late RackDocument doc;
  late SchematicScene scene;

  setUp(() {
    doc = buildSchematicTestDocument();
    scene = buildFixtureScene(doc);
  });

  const style = ConnectOverlayStyle(
    caretArgb: 0xFF0000FF,
    sourceArgb: 0xFF00FF00,
    bandArgb: 0xFF0000FF,
    candidateArgb: 0x800000FF,
    selectionArgb: 0xFFFF00FF,
  );

  PinRef pinOn(String designator, {int index = 0}) {
    final device = deviceNamed(doc, designator);
    final symbol = scene.symbols.firstWhere((s) => s.id == device.id.v);
    return PinRef(
      deviceId: symbol.id,
      portKey: symbol.allPorts.elementAt(index).key,
    );
  }

  group('locating a pin', () {
    test('every pin the sheet draws is locatable, and at the ONE published '
        'centre', () {
      // `symbolPortCentre` is the single definition of where a pin is —
      // `symbol_layer.dart`'s header records that the painter and the
      // hit-tester once had two and disagreed by half a pin. A third
      // derivation here would be the same defect a layer up, so this
      // asserts the overlay reads that function rather than reproducing it.
      final pins = locatePins(scene);
      expect(pins, isNotEmpty);
      for (final pin in pins) {
        expect(pin.centre, symbolPortCentre(pin.symbol, pin.port));
        expect(locatePin(scene, pin.ref)!.centre, pin.centre);
      }
    });

    test("the walk is the SHEET's order, and it is stable", () {
      // Deterministic order is what lets a keyboard traversal be replayable
      // and a test name a pin by index. `scene.symbols` is by Sugiyama
      // layer then top-to-bottom; `allPorts` walks edges in order.
      final once = locatePins(scene).map((p) => p.ref).toList();
      final twice = locatePins(
        buildFixtureScene(doc),
      ).map((p) => p.ref).toList();
      expect(twice, once);
    });

    test('a pin on a device that has left the document is NOT locatable, '
        'and that is a normal answer', () {
      // The teardown path depends on this being null rather than throwing:
      // a caret held across an undo can name a device that is gone.
      final ref = pinOn('MTX-1');
      final without = buildFixtureScene(
        buildSchematicTestDocument()
          ..devices.remove(deviceNamed(doc, 'MTX-1').id),
      );
      expect(locatePin(without, ref), isNull);
    });

    test('a pin key the symbol does not carry is null too', () {
      expect(
        locatePin(
          scene,
          PinRef(
            deviceId: pinOn('MTX-1').deviceId,
            portKey: 'no.such.port',
          ),
        ),
        isNull,
      );
    });
  });

  group('what it draws', () {
    test('nothing at all when there is no caret and no armed pin', () {
      final overlay = buildConnectOverlay(
        scene: scene,
        style: style,
        scale: 1,
      );
      expect(overlay.isEmpty, isTrue);
      expect(overlay.band, isEmpty);
    });

    test('a caret alone is ONE ring, and no band', () {
      final overlay = buildConnectOverlay(
        scene: scene,
        style: style,
        scale: 1,
        caret: pinOn('MTX-1'),
      );
      expect(overlay.ops.whereType<OpCircle>(), hasLength(1));
      expect(overlay.ops.whereType<OpPolyline>(), isEmpty);
      expect(overlay.caret!.centre, isNotNull);
    });

    test('armed: two rings and a band, and the band ENDS ON BOTH PINS', () {
      final from = pinOn('MTX-1');
      final to = pinOn('AMP-1');
      final overlay = buildConnectOverlay(
        scene: scene,
        style: style,
        scale: 1,
        caret: to,
        source: from,
      );
      expect(overlay.ops.whereType<OpCircle>(), hasLength(2));
      expect(overlay.ops.whereType<OpPolyline>(), hasLength(1));

      // The band is the trace, not a decoration near it: its first and
      // last points are the two pin centres exactly.
      expect(overlay.band.first, locatePin(scene, from)!.centre);
      expect(overlay.band.last, locatePin(scene, to)!.centre);
    });

    test('the band is ORTHOGONAL — docs/05 §7.5, "not a straight line"', () {
      final overlay = buildConnectOverlay(
        scene: scene,
        style: style,
        scale: 1,
        caret: pinOn('AMP-1'),
        source: pinOn('MTX-1'),
      );
      expect(overlay.band.length, greaterThanOrEqualTo(2));
      for (var i = 1; i < overlay.band.length; i++) {
        final a = overlay.band[i - 1];
        final b = overlay.band[i];
        expect(
          a.x == b.x || a.y == b.y,
          isTrue,
          reason:
              'segment $i is diagonal; the band previews the path the '
              'cable will take and the router only turns at right angles',
        );
      }
    });

    test('the band leaves each pin ALONG ITS OWN EDGE before it turns', () {
      // The escape rule, and the reason the preview shares `orthogonalTrace`
      // with the committed wire rather than drawing its own line: a band
      // that left a left-edge pin upwards would promise a cable the router
      // cannot produce.
      final from = locatePin(scene, pinOn('MTX-1'))!;
      final overlay = buildConnectOverlay(
        scene: scene,
        style: style,
        scale: 1,
        caret: pinOn('AMP-1'),
        source: from.ref,
      );
      final first = overlay.band[0];
      final second = overlay.band[1];
      final horizontal =
          from.side == SymbolSide.left || from.side == SymbolSide.right;
      expect(
        horizontal ? first.y == second.y : first.x == second.x,
        isTrue,
        reason:
            'a ${from.side.name}-edge pin escapes '
            '${horizontal ? 'horizontally' : 'vertically'}',
      );
    });
  });

  group('it is a CURSOR, so it does not scale with the sheet', () {
    test('the ring shrinks in diagram units as the zoom grows, so it is the '
        'same size on screen', () {
      // docs/05 §11.6's 12 screen px is the established precedent: a
      // constant in diagram units is 20x stricter at 20x zoom. A caret has
      // the same problem in the other direction — at 0.05x a fixed-unit
      // ring is invisible, and at 32x it swallows the symbol.
      double radiusAt(double scale) => buildConnectOverlay(
        scene: scene,
        style: style,
        scale: scale,
        caret: pinOn('MTX-1'),
      ).ops.whereType<OpCircle>().single.radius;

      expect(radiusAt(2), closeTo(radiusAt(1) / 2, 1e-9));
      expect(radiusAt(0.5), closeTo(radiusAt(1) * 2, 1e-9));
    });

    test('every stroke it emits opts OUT of geometry scaling', () {
      // `Stroke.scaleWithGeometry`'s own doc: "UI chrome, selection halos
      // and hit slop do not [scale] — callers building UI-only overlays
      // should pass false explicitly." This overlay is entirely chrome, so
      // there is no exception to find.
      final overlay = buildConnectOverlay(
        scene: scene,
        style: style,
        scale: 1,
        caret: pinOn('AMP-1'),
        source: pinOn('MTX-1'),
      );
      final strokes = <Stroke>[
        for (final op in overlay.ops)
          if (op is OpCircle && op.stroke != null)
            op.stroke!
          else if (op is OpPolyline)
            op.s,
      ];
      expect(strokes, hasLength(3));
      for (final stroke in strokes) {
        expect(stroke.scaleWithGeometry, isFalse);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // docs/05 §7.3 / DR-114 — THE AMBER RING
  // ═══════════════════════════════════════════════════════════════════
  // *"Ports that would spring back get the same ring in amber `#E69F00`,
  // no pulse. They remain droppable, the chip and `[ Connect anyway ]`
  // are what handles them."*
  //
  // THE TESTS ASSERT ARGB, NOT OP COUNT, and that is the point. The two
  // rings differ ONLY in colour, so a test that counted `OpCircle`s
  // would pass while the overlay painted the wrong verdict on every pin
  // on the sheet — which is exactly the class of test this repo has
  // found asserting a defect as intended behaviour.
  group('the amber "would spring back" ring', () {
    /// The ring drawn on [pin], by its centre, or null when it has none.
    ///
    /// Located by CENTRE rather than by index, because op order is the
    /// overlay's business and a test that pinned it would break on a
    /// z-order change that moved nothing a user can see.
    OpCircle? ringOn(ConnectOverlay overlay, PinRef ref) {
      final centre = locatePin(scene, ref)!.centre;
      for (final op in overlay.ops) {
        if (op is OpCircle && op.center == centre) return op;
      }
      return null;
    }

    test('a spring-back candidate wears #E69F00 and a plain one does not', () {
      final source = pinOn('MTX-1');
      final amber = pinOn('AMP-1');
      final plain = pinOn('AMP-1', index: 1);
      expect(amber, isNot(plain), reason: 'the premise: two distinct pins');

      final overlay = buildConnectOverlay(
        scene: scene,
        style: style,
        scale: 1,
        source: source,
        candidates: [amber, plain],
        springBack: {amber},
      );

      expect(ringOn(overlay, amber)!.stroke!.argb, kSpringBackRingArgb);
      expect(ringOn(overlay, plain)!.stroke!.argb, style.candidateArgb);
      expect(
        kSpringBackRingArgb,
        0xFFE69F00,
        reason: 'docs/05:476 names the figure; DR-114 §11.113.2 fixes it',
      );
    });

    test('it is the SAME ring — same radius, same width, one colour apart', () {
      // docs/05:476's own word is "same", and it is load-bearing rather
      // than terse: the pin is equally reachable, and the difference is
      // entirely what happens on release. A larger or heavier amber ring
      // would read as MORE of a target, which is backwards.
      final source = pinOn('MTX-1');
      final amber = pinOn('AMP-1');
      final plain = pinOn('AMP-1', index: 1);
      final overlay = buildConnectOverlay(
        scene: scene,
        style: style,
        scale: 1,
        source: source,
        candidates: [amber, plain],
        springBack: {amber},
      );
      final a = ringOn(overlay, amber)!;
      final b = ringOn(overlay, plain)!;
      expect(a.radius, b.radius);
      expect(a.stroke!.widthPt, b.stroke!.widthPt);
      expect(a.stroke!.scaleWithGeometry, isFalse);
      expect(a.stroke!.argb, isNot(b.stroke!.argb));
    });

    test('the published list is what was PAINTED, and it is resolved', () {
      final source = pinOn('MTX-1');
      final amber = pinOn('AMP-1');
      final overlay = buildConnectOverlay(
        scene: scene,
        style: style,
        scale: 1,
        source: source,
        candidates: [amber, pinOn('AMP-1', index: 1)],
        springBack: {amber},
      );
      expect(overlay.springBack.map((p) => p.ref), [amber]);
      expect(overlay.springBack.single.centre, locatePin(scene, amber)!.centre);
    });

    test('a spring-back pin that is NOT a candidate is ignored, not drawn', () {
      // docs/05:476 makes these targets DROPPABLE. One the cable could
      // not reach is a tier-1 refusal wearing the tier-2 colour, and the
      // overlay refuses to paint it rather than trusting the caller —
      // the screen asserts the same invariant in `_setTargets`, and two
      // guards on one relation is cheap next to a ring that promises a
      // drop the commit refuses.
      final source = pinOn('MTX-1');
      final legal = pinOn('AMP-1');
      final stranger = pinOn('AMP-1', index: 1);
      final overlay = buildConnectOverlay(
        scene: scene,
        style: style,
        scale: 1,
        source: source,
        candidates: [legal],
        springBack: {stranger},
      );
      expect(ringOn(overlay, stranger), isNull);
      expect(overlay.springBack, isEmpty);
      expect(ringOn(overlay, legal)!.stroke!.argb, style.candidateArgb);
    });

    test("the caret's own pin takes the caret ring, amber or not", () {
      // The pre-existing skip, re-asserted because the amber branch runs
      // inside the loop that does the skipping: two concentric circles
      // on one pin reads as a target rather than as a cursor, and the
      // verdict is not worth breaking the cursor for. The chip says it
      // on release, in words.
      final source = pinOn('MTX-1');
      final caret = pinOn('AMP-1');
      final overlay = buildConnectOverlay(
        scene: scene,
        style: style,
        scale: 1,
        caret: caret,
        source: source,
        candidates: [caret],
        springBack: {caret},
      );
      expect(ringOn(overlay, caret)!.stroke!.argb, style.caretArgb);
      expect(overlay.springBack, isEmpty);
    });

    test('no rings at all on an idle sheet, whatever is passed', () {
      // The candidate walk is gated on a SOURCE being armed, and the
      // amber branch lives inside it. A ring on a sheet nobody is
      // drawing on would be permanent chrome answering a question
      // nobody asked, which is as true of a verdict as of a candidate.
      final overlay = buildConnectOverlay(
        scene: scene,
        style: style,
        scale: 1,
        caret: pinOn('MTX-1'),
        candidates: [pinOn('AMP-1')],
        springBack: {pinOn('AMP-1')},
      );
      expect(overlay.springBack, isEmpty);
      expect(overlay.ops.whereType<OpCircle>(), hasLength(1));
    });
  });

  group('DR-012.3 — the magnet prefers the FAMILY, absolutely', () {
    test('a preferred pin beats a nearer unpreferred one, anywhere inside '
        'the radius', () {
      // docs/05 §7.6: an HDMI band prefers an HDMI port "even if an RJ45
      // port is 3 px nearer". DR-012.3 rules the axis is signalFamily —
      // its example names CONNECTORS, and RJ45-carrying-hdbaset and
      // RJ45-carrying-ethernet are the same connector, which docs/05:145
      // calls the two most dangerous ports in the taxonomy.
      final pins = locatePins(scene);
      final near = pins[0];
      final far = pins[1];
      expect(near.centre, isNot(far.centre));

      // A point sitting exactly ON the near pin: distance 0 versus
      // whatever `far` is away.
      const huge = 10000.0;
      final unweighted = snapToPin(
        scene,
        near.centre,
        tolerance: huge,
        among: [near.ref, far.ref],
      );
      expect(
        unweighted!.ref,
        near.ref,
        reason: 'without a preference the nearest wins — the premise',
      );

      final weighted = snapToPin(
        scene,
        near.centre,
        tolerance: huge,
        among: [near.ref, far.ref],
        preferred: {far.ref},
      );
      expect(
        weighted!.ref,
        far.ref,
        reason:
            'the preference is ABSOLUTE inside the radius: the corpus '
            'gives no number (only "more than 3 px"), so weighting it as '
            'a distance would invent a second unquantified figure',
      );
    });

    test('among two PREFERRED pins the nearer still wins', () {
      final pins = locatePins(scene);
      final near = pins[0];
      final far = pins[1];
      final got = snapToPin(
        scene,
        near.centre,
        tolerance: 10000,
        among: [near.ref, far.ref],
        preferred: {near.ref, far.ref},
      );
      expect(
        got!.ref,
        near.ref,
        reason:
            'the family decides between GROUPS; distance decides '
            'within one',
      );
    });

    test('the preference never reaches outside the tolerance — Ctrl still '
        'means Ctrl', () {
      // The radius is the bound on how far the preference can pull, which
      // is why DR-012.3 needs no number of its own. Ctrl collapses the
      // tolerance to the pin glyph, and a preferred pin outside it must
      // stay unreachable.
      final pins = locatePins(scene);
      final near = pins[0];
      final far = pins[1];
      final got = snapToPin(
        scene,
        near.centre,
        tolerance: 0.5,
        among: [near.ref, far.ref],
        preferred: {far.ref},
      );
      expect(got!.ref, near.ref);
    });

    test('no preference at all behaves exactly as before', () {
      final pins = locatePins(scene);
      final got = snapToPin(
        scene,
        pins[3].centre,
        tolerance: 10000,
        among: [for (final p in pins.take(6)) p.ref],
      );
      expect(got!.ref, pins[3].ref);
    });
  });
}
