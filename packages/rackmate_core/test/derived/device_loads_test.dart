// The SHARED load resolver and the SHARED belongs-to-rack predicate.
//
// These two functions were extracted out of `derived/totals.dart` so the
// chip strip, the elevation's load gutter and T6.30's rows and subtotals
// all read the same numbers through the same code. The tests that matter
// most here are therefore the ones that would catch a SECOND resolution
// path reappearing: `totals_test.dart` still passes unchanged (the refactor
// was behaviour-preserving), and `equipment_list_test.dart` asserts the
// schedule's subtotal equals `computeRackRollups`' figure.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'test',
);

DeviceInstance _device({
  required String id,
  required Placement placement,
  Mass? weightOverride,
  int? wattsOverride,
}) => DeviceInstance(
  id: Uuid(id),
  kind: DeviceKind.rackDevice,
  templateRef: const TemplateRef(
    templateId: TemplateId('T1'),
    version: 1,
    contentHash: 'h',
  ),
  designator: id.toUpperCase(),
  name: '',
  placement: placement,
  meta: _meta(),
  overrides: DeviceOverrides(
    weight: weightOverride,
    typicalWatts: wattsOverride,
  ),
);

TemplateBody _body({
  Mass? weight,
  int? typicalWatts,
  int? apparentVA,
  int? btuOverride,
  int? nameplateWatts,
  int frontU = 1,
  int rearU = 0,
}) => TemplateBody(
  manufacturer: 'M',
  model: 'X',
  displayName: 'X',
  frontU: frontU,
  rearU: rearU,
  power: PowerProfile(
    typicalWatts: typicalWatts,
    apparentVA: apparentVA,
    btuPerHourOverride: btuOverride,
    nameplateWatts: nameplateWatts,
  ),
  weight: weight,
);

void main() {
  const rackId = Uuid('rack-1');

  group('resolveDeviceLoads', () {
    test('an instance override beats the template', () {
      final loads = resolveDeviceLoads(
        _device(
          id: 'd',
          placement: const RailPlacement(
            rackId: rackId,
            ruIndex: 1,
            face: Face.front,
          ),
          weightOverride: const Mass(5_000_000_000),
          wattsOverride: 120,
        ),
        _body(weight: const Mass(1_000_000_000), typicalWatts: 40),
      );

      expect(loads.mass, const Mass(5_000_000_000));
      expect(loads.typicalWatts, 120);
    });

    test('an override survives a template that does not resolve', () {
      // A device whose snapshot is missing but whose weight was typed in is
      // a KNOWN mass. Short-circuiting on `body == null` would under-report
      // the rack.
      final loads = resolveDeviceLoads(
        _device(
          id: 'd',
          placement: const StagedPlacement(),
          weightOverride: const Mass(2_000_000_000),
        ),
        null,
      );

      expect(loads.mass, const Mass(2_000_000_000));
      expect(loads.apparentVA, isNull);
    });

    test('everything is null when nothing is authored — never zero', () {
      final loads = resolveDeviceLoads(
        _device(
          id: 'd',
          placement: const StagedPlacement(),
        ),
        _body(),
      );

      expect(loads.mass, isNull);
      expect(loads.apparentVA, isNull);
      expect(loads.typicalWatts, isNull);
      expect(loads.btuPerHour, isNull);
      expect(loads.outletsProvided, isNull);
      expect(loads.outletsConsumed, isNull);
    });

    test('an authored ZERO is a measurement and stays one', () {
      final loads = resolveDeviceLoads(
        _device(id: 'd', placement: const StagedPlacement()),
        TemplateBody(
          manufacturer: 'M',
          model: 'X',
          displayName: 'X',
          power: PowerProfile(outletsProvided: 0, outletsConsumed: 0),
          weight: Mass.zero,
        ),
      );

      expect(loads.outletsProvided, 0);
      expect(loads.mass, Mass.zero);
    });
  });

  group('BTU/hr is derived from typicalWatts and NOTHING ELSE (AC-039)', () {
    test('typicalWatts converts through the one shared factor', () {
      final loads = resolveDeviceLoads(
        _device(id: 'd', placement: const StagedPlacement()),
        _body(typicalWatts: 100),
      );

      expect(loads.btuPerHour, closeTo(100 * 3.412142, 1e-9));
    });

    test('btuPerHourOverride wins outright', () {
      final loads = resolveDeviceLoads(
        _device(id: 'd', placement: const StagedPlacement()),
        _body(typicalWatts: 100, btuOverride: 900),
      );

      expect(loads.btuPerHour, 900);
    });

    test('nameplateWatts is NOT a substitute — AC-039 rejected exactly '
        'that', () {
      // A thermal figure invented from a UL label is a number an installer
      // sizes a fan against. `nameplateWatts` is present and large;
      // `typicalWatts` is absent; the answer must be UNKNOWN.
      final loads = resolveDeviceLoads(
        _device(id: 'd', placement: const StagedPlacement()),
        _body(nameplateWatts: 800),
      );

      expect(loads.btuPerHour, isNull);
      expect(loads.typicalWatts, isNull);
    });

    test('apparentVA is NOT a substitute either — that assumes a power '
        'factor nobody authored', () {
      final loads = resolveDeviceLoads(
        _device(id: 'd', placement: const StagedPlacement()),
        _body(apparentVA: 500),
      );

      expect(loads.btuPerHour, isNull);
    });
  });

  group('hostRackOf / belongsToRack', () {
    Map<Uuid, DeviceInstance> byId(List<DeviceInstance> ds) =>
        <Uuid, DeviceInstance>{for (final d in ds) d.id: d};

    test('rails and 0U resolve directly', () {
      final rail = _device(
        id: 'rail',
        placement: const RailPlacement(
          rackId: rackId,
          ruIndex: 3,
          face: Face.front,
        ),
      );
      final zero = _device(
        id: 'zero',
        placement: const ZeroUPlacement(
          rackId: rackId,
          channelId: 'c',
          offsetFromChannelStart: Len(0),
          orientation: ZeroUOrientation.vertical,
        ),
      );
      final map = byId([rail, zero]);

      expect(hostRackOf(rail, map), rackId);
      expect(hostRackOf(zero, map), rackId);
      expect(belongsToRack(rail, rackId, map), isTrue);
      expect(belongsToRack(rail, const Uuid('other'), map), isFalse);
    });

    test('a shelf chain resolves through its host', () {
      final shelf = _device(
        id: 'shelf',
        placement: const RailPlacement(
          rackId: rackId,
          ruIndex: 5,
          face: Face.front,
        ),
      );
      final onShelf = _device(
        id: 'ontop',
        placement: const ShelfPlacement(
          hostDeviceId: Uuid('shelf'),
          order: FracIndex('a0'),
        ),
      );

      expect(hostRackOf(onShelf, byId([shelf, onShelf])), rackId);
    });

    test('off-rack and staged belong to no rack — that is the point of '
        'those variants', () {
      final off = _device(id: 'o', placement: const OffRackPlacement());
      final staged = _device(id: 's', placement: const StagedPlacement());

      expect(hostRackOf(off, byId([off])), isNull);
      expect(hostRackOf(staged, byId([staged])), isNull);
    });

    test('a shelf CYCLE terminates instead of hanging', () {
      // A corrupt or hand-edited file can express `a hosts b hosts a`. The
      // visited set is what stops that spinning the UI thread.
      final a = _device(
        id: 'a',
        placement: const ShelfPlacement(
          hostDeviceId: Uuid('b'),
          order: FracIndex('a0'),
        ),
      );
      final b = _device(
        id: 'b',
        placement: const ShelfPlacement(
          hostDeviceId: Uuid('a'),
          order: FracIndex('a0'),
        ),
      );

      expect(hostRackOf(a, byId([a, b])), isNull);
    });

    test('a missing host is not a rack membership', () {
      final orphan = _device(
        id: 'x',
        placement: const ShelfPlacement(
          hostDeviceId: Uuid('gone'),
          order: FracIndex('a0'),
        ),
      );

      expect(hostRackOf(orphan, byId([orphan])), isNull);
    });
  });

  group('supportingRailPlacement — where in the stack a mass sits', () {
    test('a shelf-hosted device inherits its host rail placement', () {
      final shelf = _device(
        id: 'shelf',
        placement: const RailPlacement(
          rackId: rackId,
          ruIndex: 9,
          face: Face.front,
        ),
      );
      final onShelf = _device(
        id: 'ontop',
        placement: const ShelfPlacement(
          hostDeviceId: Uuid('shelf'),
          order: FracIndex('a0'),
        ),
      );
      final map = <Uuid, DeviceInstance>{shelf.id: shelf, onShelf.id: onShelf};

      expect(supportingRailPlacement(onShelf, map)?.ruIndex, 9);
    });

    test('a 0U occupant has NO rail placement — and is not given one', () {
      // Attributing it to the rack bottom would be a vertical position the
      // model does not carry. The gutter counts it at the top reading and
      // says so instead.
      final zero = _device(
        id: 'zero',
        placement: const ZeroUPlacement(
          rackId: rackId,
          channelId: 'c',
          offsetFromChannelStart: Len(0),
          orientation: ZeroUOrientation.vertical,
        ),
      );

      expect(
        supportingRailPlacement(zero, <Uuid, DeviceInstance>{zero.id: zero}),
        isNull,
      );
    });
  });

  group('occupancyU', () {
    test('a face with zero U is UNKNOWN, not a measured zero', () {
      // The exact shape that made the rear chip read `RU rear 0/12` with a
      // device rail-placed at U3.
      expect(occupancyU(_body(frontU: 2), Face.rear), isNull);
      expect(occupancyU(_body(frontU: 2), Face.front), 2);
      expect(occupancyU(null, Face.front), isNull);
    });
  });

  group('templateKeyFor', () {
    test('is the one spelling of the snapshot key', () {
      expect(
        templateKeyFor(
          const TemplateRef(
            templateId: TemplateId('AMP'),
            version: 3,
            contentHash: 'h',
          ),
        ),
        'AMP@3',
      );
    });
  });
}
