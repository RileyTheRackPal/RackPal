// M2-F PHASE 2 — the caret, the armed pin and the band between them.
//
// The overlay is the only thing a SIGHTED keyboard user has: the status
// line says where the caret is, and this says it on the sheet. So the tests
// below are about the two properties that make it a cursor rather than a
// decoration — it is where the pin actually is, and it is the same size to
// the eye at every zoom.

import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

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
      final twice = locatePins(buildFixtureScene(doc))
          .map((p) => p.ref)
          .toList();
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
          reason: 'segment $i is diagonal; the band previews the path the '
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
        reason: 'a ${from.side.name}-edge pin escapes '
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
}
