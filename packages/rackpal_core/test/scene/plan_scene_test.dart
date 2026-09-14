// PLAN-E/2: the plan scene builder (docs/15 §6, plan_scene.dart).
//
// The property most of these are really about is the coordinate rule: one
// image pixel is one scene unit, so a `PlanPin` at `PxPt(x, y)` is
// clickable at `DPt(x, y)`. They assert it through `hitTest` rather than by
// reading the mapping back, because the mapping is not the artifact: being
// able to click the pin is.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 9, 8);

/// The radius every case here draws at, in scene units.
///
/// A scene is told its mark's size by the surface drawing it (DR-169
/// §11.168.2, and required since `#904`). These cases are about where a
/// pin is and which carrier it is, not how big it is, so any radius
/// serves. This one is near what the retired fraction gave the 2000-pixel
/// fixture, so no hit test moved.
const _markR = 18.0;

/// The line weight every case here draws at, in surface units (DR-169
/// §11.168.11, required since `#905`). Like [_markR], any value serves for
/// cases about position and carrier.
const _markW = 1.0;

PlanUnderlay _underlay({
  int width = 2000,
  int height = 1400,
  PlanImageFormat format = PlanImageFormat.png,
}) => PlanUnderlay(
  id: const Uuid('ul-1'),
  name: 'Level 1',
  imageMember: 'underlays/ul-1.png',
  format: format,
  pixelWidth: width,
  pixelHeight: height,
  contentHash: 'sha256:test',
  order: const FracIndex('a0'),
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
);

PlanPinSubject _pin(
  String id,
  int x,
  int y, {
  PlanPinCarrier carrier = PlanPinCarrier.device,
}) => PlanPinSubject(
  entityId: Uuid(id),
  at: PxPt(x, y),
  carrier: carrier,
);

void main() {
  group('the underlay', () {
    test('is op zero, so every mark is drawn over it', () {
      final scene = buildPlanScene(
        markerRadius: _markR,
        markerWeight: _markW,
        underlay: _underlay(),
        pins: [_pin('d1', 100, 100)],
      ).scene;
      expect(scene.ops.first, isA<OpImage>());
    });

    test('is drawn at its intrinsic size, so aspect cannot be stretched', () {
      // `DiagramCanvas.drawImage` has no fit rule on purpose (DR-029
      // §11.28.6): the caller picks a destination that does not distort
      // the picture. Picking the intrinsic size is the shortest way to
      // honour that, and this is the assertion that it was picked.
      // DELIBERATELY NOT THE FIXTURE'S DEFAULT SIZE. An assertion of
      // 2000x1400 against a helper that also defaults to 2000x1400 passes
      // whether or not the argument reached the builder.
      final scene = buildPlanScene(
        markerRadius: _markR,
        markerWeight: _markW,
        underlay: _underlay(width: 1600, height: 900),
        pins: const [],
      ).scene;
      final image = scene.ops.first as OpImage;
      expect(image.dst.width, 1600);
      expect(image.dst.height, 900);
      expect(image.dst.width / image.dst.height, image.image.aspectRatio);
    });

    test('carries the member and format the container actually holds', () {
      final scene = buildPlanScene(
        markerRadius: _markR,
        markerWeight: _markW,
        underlay: _underlay(format: PlanImageFormat.jpeg),
        pins: const [],
      ).scene;
      final image = scene.ops.first as OpImage;
      expect(image.image.member, 'underlays/ul-1.png');
      expect(image.image.format, ImageFormat.jpeg);
    });
  });

  group('a pin is where the pixel is', () {
    test('hit-testing the pixel coordinate finds the pin', () {
      // THE COORDINATE RULE, ASSERTED AS THE THING IT BUYS. One image
      // pixel is one scene unit, so the point stored in the document is
      // the point a click lands on.
      final built = buildPlanScene(
        markerRadius: _markR,
        markerWeight: _markW,
        underlay: _underlay(),
        pins: [_pin('dev-7', 640, 480)],
      );
      final hit = hitTest(built.scene, const DPt(640, 480));
      expect(hit?.entityId, 'dev-7');
    });

    test('the hit names the CARRIER, so clicking a mark selects the thing', () {
      // A `PlanPin` has no id of its own; it hangs off a device, an outlet
      // or a rack (docs/15 §3.4). The region therefore has to carry the
      // carrier's id or the inspector has nothing to show.
      final built = buildPlanScene(
        markerRadius: _markR,
        markerWeight: _markW,
        underlay: _underlay(),
        // Asymmetric on purpose: a square coordinate cannot see a
        // transposed x and y, and three of this file's fixtures are square.
        pins: [_pin('outlet-3', 210, 45, carrier: PlanPinCarrier.outlet)],
      );
      expect(hitTest(built.scene, const DPt(210, 45))?.entityId, 'outlet-3');
    });

    test('a click well away from every mark hits nothing', () {
      final built = buildPlanScene(
        markerRadius: _markR,
        markerWeight: _markW,
        underlay: _underlay(),
        pins: [_pin('d1', 100, 100)],
      );
      expect(hitTest(built.scene, const DPt(1500, 900)), isNull);
    });

    test('a pin dragged off the picture is still selectable', () {
      // The scene's bounds are the underlay's, so a pin outside it draws
      // outside the picture. It must still be clickable, or a mis-drag
      // becomes a mark nobody can select to fix. `PLN-002` counts it
      // either way; being unable to reach it is what would make the plan
      // dishonest.
      final built = buildPlanScene(
        markerRadius: _markR,
        markerWeight: _markW,
        underlay: _underlay(width: 800, height: 600),
        pins: [_pin('stray', 900, 700)],
      );
      expect(hitTest(built.scene, const DPt(900, 700))?.entityId, 'stray');
      expect(built.underlayBounds.contains(const DPt(900, 700)), isFalse);
    });
  });

  group('the three carriers are told apart', () {
    List<DiagramOp> opsFor(PlanPinCarrier carrier) {
      final built = buildPlanScene(
        markerRadius: _markR,
        markerWeight: _markW,
        underlay: _underlay(),
        pins: [_pin('e', 500, 500, carrier: carrier)],
      );
      final range = built.scene.fragments['e']!;
      return built.scene.ops.sublist(range.start, range.end);
    }

    test('the rack datum is a crossed square, not one more dot', () {
      // Every length on the plan is measured from the rack (`PLN-003`), so
      // a plan where the rack is indistinguishable from a ceiling speaker
      // is one somebody has to count on. The cross is what makes it a
      // datum rather than an occupant.
      final ops = opsFor(PlanPinCarrier.rack);
      expect(ops.whereType<OpRect>(), hasLength(1));
      expect(ops.whereType<OpLine>(), hasLength(2));
      expect(ops.whereType<OpCircle>(), isEmpty);
    });

    test('an outlet is the plainest mark, because there are sixty of '
        'them', () {
      final ops = opsFor(PlanPinCarrier.outlet);
      expect(ops.whereType<OpCircle>(), hasLength(1));
      expect(ops.whereType<OpRect>(), isEmpty);
    });

    test('a device reads apart from an outlet', () {
      // THIS ASSERTED THE MECHANISM AND NOW ASSERTS THE ARTIFACT
      // (`#901`, DR-169 §11.168.6). It read `hasLength(2)`, because a
      // device was a circle plus an inner dot at `r / 3` and that dot was
      // how it differed. The dot is the space the domain glyph occupies
      // now, so the difference moved to the ring's WEIGHT. What the case
      // is for did not move: two carriers must not draw the same mark.
      final device = opsFor(PlanPinCarrier.device);
      final outlet = opsFor(PlanPinCarrier.outlet);

      // The ops carry no `toString`, so comparing the LISTS compares two
      // `Instance of 'OpCircle'` strings and passes over anything. The
      // weight is the difference, so the weight is what the case reads.
      expect(
        device.whereType<OpCircle>().single.stroke!.widthPt,
        greaterThan(outlet.whereType<OpCircle>().single.stroke!.widthPt),
      );
    });
  });

  group('the marker is the size its caller says', () {
    // THIS GROUP ASSERTED THE RETIRED RULE UNTIL `#904`. Its first case
    // was "a 4000px plan and a 600px plan get proportionate marks", which
    // is exactly the property DR-169 §11.168.2 retired, still certified as
    // intended behaviour after both surfaces had stopped wanting it. The
    // default it tested is gone: a surface states its radius from its own
    // scale, and the scene draws what it is told.
    test('the radius drawn is the one the caller passed', () {
      final built = buildPlanScene(
        markerRadius: _markR,
        markerWeight: _markW,
        underlay: _underlay(),
        pins: [_pin('e', 10, 10, carrier: PlanPinCarrier.outlet)],
      );
      final range = built.scene.fragments['e']!;
      expect((built.scene.ops[range.start] as OpCircle).radius, _markR);
    });
  });

  group('the scene as a whole', () {
    test('gives every pin its own replayable fragment (CR-086)', () {
      final built = buildPlanScene(
        markerRadius: _markR,
        markerWeight: _markW,
        underlay: _underlay(),
        pins: [_pin('a', 10, 10), _pin('b', 20, 20)],
      );
      expect(built.scene.fragments.keys, containsAll(['ul-1', 'a', 'b']));
      expect(built.scene.fragmentFor('a').ops, isNotEmpty);
    });

    test('reports no smallest text, because it draws none', () {
      // `double.infinity` reads as "nothing to check" to docs/08 §6.2's
      // legibility trigger. Zero would read as "something illegible".
      final built = buildPlanScene(
        markerRadius: _markR,
        markerWeight: _markW,
        underlay: _underlay(),
        pins: const [],
      );
      expect(built.scene.minTextSizePt, double.infinity);
      expect(built.scene.ops.whereType<OpText>(), isEmpty);
    });

    test('an empty plan is the underlay and nothing else', () {
      final built = buildPlanScene(
        markerRadius: _markR,
        markerWeight: _markW,
        underlay: _underlay(),
        pins: const [],
      );
      expect(built.scene.ops, hasLength(1));
      expect(built.scene.hits, isEmpty);
    });
  });
}
