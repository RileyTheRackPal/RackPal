// `#911`, DR-184: a floorplan turns in quarter turns, and a stored
// coordinate never does.
//
// WHAT THESE ASSERT IS THAT THE PICTURE AND THE MARKS AGREE. The map is
// the mechanism; the artifact is that a pin drawn on a turned plan sits on
// the same spot of the picture it sat on before the turn, and can still be
// clicked there. So most cases replay the scene the way a surface would and
// read the answer off it, rather than reading the four formulas back.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 9, 18);

const _markR = 18.0;
const _markW = 1.0;

/// NOT SQUARE, and not a round number either way, so a swapped axis or a
/// width used where a height belongs changes every answer below.
const _w = 1600;
const _h = 900;

PlanUnderlay _underlay({int turns = 0}) => PlanUnderlay(
  id: const Uuid('ul-1'),
  name: 'Level 1',
  imageMember: 'underlays/ul-1.png',
  format: PlanImageFormat.png,
  pixelWidth: _w,
  pixelHeight: _h,
  contentHash: 'sha256:test',
  order: const FracIndex('a0'),
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
  rotationQuarterTurns: turns,
);

PlanPinSubject _pin(String id, int x, int y) => PlanPinSubject(
  entityId: Uuid(id),
  at: PxPt(x, y),
  carrier: PlanPinCarrier.device,
);

/// Where [ops] put the stored image, found by replaying them. This is the
/// picture as a surface draws it, transform and all.
DBox _imageInk(List<DiagramOp> ops) {
  final canvas = BoundsCanvas(measurer: const _NoText());
  for (final op in ops) {
    op.replay(canvas);
    if (op is OpImage) break;
  }
  return canvas.bounds!;
}

/// Where a point of the stored image lands once [ops] are replayed: the
/// image is drawn at its own box under whatever transform precedes it, so
/// the transform in force at the image op IS the picture's map.
DPt _pictureLandsAt(List<DiagramOp> ops, PxPt p) {
  final canvas = BoundsCanvas(measurer: const _NoText());
  for (final op in ops) {
    if (op is OpImage) break;
    op.replay(canvas);
  }
  final m = canvas.currentTransform;
  final x = p.px.toDouble();
  final y = p.py.toDouble();
  return DPt(
    m.entry(0, 0) * x + m.entry(0, 1) * y + m.entry(0, 3),
    m.entry(1, 0) * x + m.entry(1, 1) * y + m.entry(1, 3),
  );
}

void main() {
  group('the picture turns with the plan', () {
    test('an unturned plan draws exactly as before, with no bracket', () {
      // EVERY PLAN THAT EXISTED BEFORE DR-184 IS UNTURNED, and §11.183.2
      // promises none of their display lists moves. No transform op, and
      // the image is op zero at its own box, is that promise in the form a
      // display list can be checked for.
      final ops = buildPlanScene(
        underlay: _underlay(),
        pins: const [],
        markerRadius: _markR,
        markerWeight: _markW,
      ).scene.ops;
      expect(ops.whereType<OpTransform>(), isEmpty);
      expect(ops.first, isA<OpImage>());
      expect((ops.first as OpImage).dst, const DBox.fromLtwh(0, 0, 1600, 900));
    });

    for (final turns in [1, 2, 3]) {
      test('turned $turns, the picture fills exactly the scene bounds', () {
        final built = buildPlanScene(
          underlay: _underlay(turns: turns),
          pins: const [],
          markerRadius: _markR,
          markerWeight: _markW,
        );
        final swapped = turns.isOdd;
        expect(
          built.underlayBounds,
          DBox.fromLtwh(0, 0, swapped ? 900 : 1600, swapped ? 1600 : 900),
        );
        expect(_imageInk(built.scene.ops), built.underlayBounds);
      });
    }

    test('ONE TURN CLOCKWISE PUTS THE TOP-LEFT CORNER TOP-RIGHT', () {
      // The sanity check `plan_turn.dart`'s header names: clockwise as the
      // plan is SEEN. A map that turned the other way would pass every
      // round-trip case below and still show the plan upside down from
      // what the button promised.
      final ops = buildPlanScene(
        underlay: _underlay(turns: 1),
        pins: const [],
        markerRadius: _markR,
        markerWeight: _markW,
      ).scene.ops;
      expect(_pictureLandsAt(ops, const PxPt(0, 0)), const DPt(900, 0));
      expect(_pictureLandsAt(ops, const PxPt(1600, 0)), const DPt(900, 1600));
      expect(_pictureLandsAt(ops, const PxPt(0, 900)), const DPt(0, 0));
    });
  });

  group('a mark stays on its spot of the picture', () {
    for (final turns in [0, 1, 2, 3]) {
      test('turned $turns, a pin is clickable where the picture shows its '
          'pixel', () {
        const at = PxPt(1200, 150);
        final built = buildPlanScene(
          underlay: _underlay(turns: turns),
          pins: [_pin('d1', at.px, at.py)],
          markerRadius: _markR,
          markerWeight: _markW,
        );
        final onPicture = _pictureLandsAt(built.scene.ops, at);
        expect(hitTest(built.scene, onPicture)?.entityId, 'd1');
      });
    }

    test('and the old spot is empty once the plan has turned', () {
      // THE CONTROL FOR THE CASE ABOVE. If the pin were drawn at its
      // stored pixel regardless of the turn, the case above would pass on
      // turn 0 and this would fail on turn 1.
      const at = PxPt(1200, 150);
      final built = buildPlanScene(
        underlay: _underlay(turns: 1),
        pins: [_pin('d1', at.px, at.py)],
        markerRadius: _markR,
        markerWeight: _markW,
      );
      expect(hitTest(built.scene, const DPt(1200, 150)), isNull);
    });
  });

  group('the map is exact', () {
    test('every turn round-trips every corner and an interior pixel', () {
      const points = [
        PxPt(0, 0),
        PxPt(1600, 0),
        PxPt(0, 900),
        PxPt(1600, 900),
        PxPt(1234, 567),
      ];
      for (final turns in [0, 1, 2, 3]) {
        final turn = PlanTurn.of(_underlay(turns: turns));
        for (final p in points) {
          expect(turn.toPixel(turn.toScene(p)), p, reason: 'turn $turns, $p');
        }
      }
    });

    test('the matrix that draws the picture holds only whole numbers', () {
      // `Matrix4.rotationZ(pi / 2)` holds 6.1e-17 where a 0 belongs, and
      // that digit would reach the exported PDF's `cm` operator. Whole
      // entries are what make the same document export the same bytes on
      // every machine, which is the determinism invariant.
      for (final turns in [1, 2, 3]) {
        final m = PlanTurn.of(_underlay(turns: turns)).imageToScene!;
        for (final v in m.storage) {
          expect(v, v.roundToDouble(), reason: 'turn $turns entry $v');
        }
      }
    });

    test(
      'a stepped value wraps, so a caller cannot build an unmappable one',
      () {
        expect(
          const PlanTurn(
            quarterTurns: -1,
            pixelWidth: 10,
            pixelHeight: 5,
          ).quarterTurns,
          3,
        );
        expect(
          const PlanTurn(
            quarterTurns: 4,
            pixelWidth: 10,
            pixelHeight: 5,
          ).quarterTurns,
          0,
        );
      },
    );
  });

  group('the sheet', () {
    test('fits the plan as seen, so a turned plan prints the other way up', () {
      // A sheet that fitted the STORED box would size a landscape plan as
      // a portrait one. `planUnderlayBounds` is what the sheet fits.
      expect(
        planUnderlayBounds(_underlay()),
        const DBox.fromLtwh(0, 0, 1600, 900),
      );
      expect(
        planUnderlayBounds(_underlay(turns: 1)),
        const DBox.fromLtwh(0, 0, 900, 1600),
      );
    });
  });
}

final class _NoText implements TextMeasurer {
  const _NoText();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('these scenes draw no text');
}
