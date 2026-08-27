// Unit tests for the pure geometric hit-test (draw/hit_test.dart, CR-084).
// No Flutter: hitTest is point → nearest HitRegion over a DiagramScene, and
// the whole point of §7.4 is that this is synchronously testable off any
// canvas or hardware.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

DiagramScene _sceneWith(List<HitRegion> hits) => DiagramScene(
  ops: const [],
  bounds: const DBox.fromLtwh(0, 0, 1000, 1000),
  hits: hits,
  minTextSizePt: 11,
  fragments: const {},
);

// A deterministic fake measurer so the buildRackScene-based test needs no TTF.
final class _FakeMeasurer implements TextMeasurer {
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

void main() {
  group('hitTest — containment', () {
    test('a point inside a region returns that region', () {
      final scene = _sceneWith([
        const HitRegion('a', DBox.fromLtwh(0, 0, 10, 10)),
        const HitRegion('b', DBox.fromLtwh(100, 100, 10, 10)),
      ]);
      expect(hitTest(scene, const DPt(5, 5))?.entityId, 'a');
      expect(hitTest(scene, const DPt(105, 105))?.entityId, 'b');
    });

    test('a point in empty space with no tolerance hits nothing', () {
      final scene = _sceneWith([
        const HitRegion('a', DBox.fromLtwh(0, 0, 10, 10)),
      ]);
      expect(hitTest(scene, const DPt(50, 50)), isNull);
    });

    test('boundary points count as inside (inclusive bounds)', () {
      final scene = _sceneWith([
        const HitRegion('a', DBox.fromLtwh(0, 0, 10, 10)),
      ]);
      expect(hitTest(scene, const DPt(10, 10))?.entityId, 'a');
    });
  });

  group('hitTest — tolerance', () {
    test('a near-miss within tolerance still hits; beyond it does not', () {
      final scene = _sceneWith([
        const HitRegion('a', DBox.fromLtwh(0, 0, 10, 10)),
      ]);
      // 3 units to the right of the box's right edge.
      expect(hitTest(scene, const DPt(13, 5), tolerance: 4)?.entityId, 'a');
      expect(hitTest(scene, const DPt(13, 5), tolerance: 2), isNull);
    });
  });

  group('hitTest — NEAREST, not first (§7.4)', () {
    test('adjacent regions: the nearer edge wins regardless of list order', () {
      const left = HitRegion('left', DBox.fromLtwh(0, 0, 10, 10));
      const right = HitRegion('right', DBox.fromLtwh(20, 0, 10, 10));
      // Point at x=17: 7 from left's right edge, 3 from right's left edge.
      final scene = _sceneWith([left, right]);
      final flipped = _sceneWith([right, left]);
      const p = DPt(17, 5);
      expect(hitTest(scene, p, tolerance: 10)?.entityId, 'right');
      // List order must not change the answer (that is the "not first" rule).
      expect(
        hitTest(flipped, p, tolerance: 10)?.entityId,
        'right',
      );
    });

    test('overlapping regions containing the point: nearest centre wins', () {
      // Two boxes both contain (12,12); the point is dead-centre of the
      // small one and off-centre in the big one, so the small one is picked.
      const big = HitRegion('big', DBox.fromLtwh(0, 0, 40, 40));
      const small = HitRegion('small', DBox.fromLtwh(8, 8, 8, 8));
      expect(
        hitTest(_sceneWith([big, small]), const DPt(12, 12))?.entityId,
        'small',
      );
      // Order-independent.
      expect(
        hitTest(_sceneWith([small, big]), const DPt(12, 12))?.entityId,
        'small',
      );
    });

    test('exact ties fall back to list order (deterministic)', () {
      // Two identical boxes: same edge distance AND same centre distance.
      const box = DBox.fromLtwh(0, 0, 10, 10);
      const first = HitRegion('first', box);
      const second = HitRegion('second', box);
      expect(
        hitTest(_sceneWith([first, second]), const DPt(5, 5))?.entityId,
        'first',
      );
    });
  });

  group('hitTest — against a real built scene', () {
    test("a click at a device rect's centre selects that device", () {
      final rack = Rack(
        id: const Uuid('rack-1'),
        name: 'R',
        designator: 'RK-1',
        heightU: 12,
        order: const FracIndex('a0'),
        meta: EntityMeta(
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          updatedBy: 't',
        ),
      );
      final templates = {
        'amp@1': TemplateSnapshot(
          templateId: const TemplateId('amp'),
          version: 1,
          contentHash: 'h',
          capturedAt: DateTime.utc(2026),
          body: TemplateBody(
            manufacturer: 'D',
            model: 'amp',
            displayName: 'Amp',
            frontU: 2,
          ),
        ),
      };
      final device = DeviceInstance(
        id: const Uuid('dev-amp'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('amp'),
          version: 1,
          contentHash: 'h',
        ),
        designator: 'AMP-1',
        name: 'Amp',
        placement: const RailPlacement(
          rackId: Uuid('rack-1'),
          ruIndex: 4,
          face: Face.front,
        ),
        meta: EntityMeta(
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          updatedBy: 't',
        ),
      );
      final result = buildRackScene(
        rack: rack,
        devices: [device],
        templates: templates,
        face: Face.front,
        lod: LodLevel.full,
        measurer: _FakeMeasurer(),
      );
      final rect = result.devices.single.rect;
      final centre = DPt(
        (rect.left + rect.right) / 2,
        (rect.top + rect.bottom) / 2,
      );
      expect(hitTest(result.scene, centre)?.entityId, 'dev-amp');
    });
  });
}
