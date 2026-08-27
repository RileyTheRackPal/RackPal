// Unit tests for derived/totals.dart — docs/04-rack-editor.md §5's four
// chip-strip rollups.
//
// The bug this file exists to make impossible: the chip strip shipped
// reading "12/12U · 0 free" on the demo rack, which has SW-1 (1U at U7),
// AMP-1 (2U at U4-U5) and UPS-1 (2U at U1-U2) — 5 U used of 12, 7 free.
// The `demo rack` group below reconstructs that exact seed and asserts the
// real numbers, so the same wrong figure cannot come back silently.
//
// The other half is G4/CR-114: unknown is `null`, never `0`, and every
// rollup carries its unknown count. Every "unknown" test here asserts BOTH
// halves — that the total is null AND that the count says how many
// contributors were missing — because a null with no count is just as
// unusable as a fabricated zero.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 7, 18);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

Rack _rack({int heightU = 12, Mass? weightCapacity}) => Rack(
  id: const Uuid('rk-1'),
  name: 'Test Rack',
  designator: 'RK-1',
  heightU: heightU,
  order: const FracIndex('a0'),
  meta: _meta(),
  weightCapacity: weightCapacity,
);

/// A template body whose outlet counts default to UNAUTHORED, matching the
/// app's four demo templates and `catalog_passive.dart`'s three.
///
/// These two used to default to `0` here — mirroring the non-nullable `0`
/// on `PowerProfile` itself — which is why every outlet assertion in this
/// file passed while the chip strip was rendering a fabricated
/// `outlets 0/0` on first launch: no test in the suite could reach the
/// unauthored state, because the fixture could not express it.
TemplateBody _body({
  int frontU = 0,
  int rearU = 0,
  Mass? weight,
  int? apparentVA,
  int? outletsProvided,
  int? outletsConsumed,
  String model = 'dev',
}) => TemplateBody(
  manufacturer: 'Test',
  model: model,
  displayName: model,
  frontU: frontU,
  rearU: rearU,
  side: rearU > 0
      ? (frontU > 0 ? OccupancySide.both : OccupancySide.rear)
      : OccupancySide.front,
  mountMethod: MountMethod.rackEars,
  weight: weight,
  power: PowerProfile(
    apparentVA: apparentVA,
    outletsProvided: outletsProvided,
    outletsConsumed: outletsConsumed,
  ),
);

TemplateSnapshot _snapshot(String id, TemplateBody body) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'sha256:test-$id',
  body: body,
  capturedAt: _now,
);

DeviceInstance _device(
  String id, {
  required String templateId,
  required Placement placement,
  String designator = 'DEV-1',
  DeviceOverrides? overrides,
}) => DeviceInstance(
  id: Uuid(id),
  kind: DeviceKind.rackDevice,
  templateRef: TemplateRef(
    templateId: TemplateId(templateId),
    version: 1,
    contentHash: 'sha256:test-$templateId',
  ),
  designator: designator,
  name: designator,
  placement: placement,
  overrides: overrides,
  meta: _meta(),
);

RailPlacement _rail(
  int ruIndex, {
  Face face = Face.front,
  String rack = 'rk-1',
}) => RailPlacement(rackId: Uuid(rack), ruIndex: ruIndex, face: face);

void main() {
  group(
    'RU on the ACTIVE FACE (docs/04 §5: front and rear are two answers)',
    () {
      test('counts distinct occupied U and reports the rest free', () {
        final rack = _rack();
        final templates = {
          'a@1': _snapshot('a', _body(frontU: 2)),
          'b@1': _snapshot('b', _body(frontU: 1)),
        };
        final devices = [
          _device('d1', templateId: 'a', placement: _rail(1)), // U1-U2
          _device('d2', templateId: 'b', placement: _rail(7)), // U7
        ];

        final r = computeRackRollups(
          rack: rack,
          devices: devices,
          templates: templates,
          face: Face.front,
        );

        expect(r.ruCapacity, 12);
        expect(r.ruUsed, 3);
        expect(r.ruFree, 9);
        expect(r.face, Face.front);
      });

      test('a REAR-only device does not consume FRONT RU, and vice versa', () {
        final rack = _rack();
        final templates = {'pp@1': _snapshot('pp', _body(rearU: 1))};
        final devices = [
          _device(
            'pp-1',
            templateId: 'pp',
            placement: _rail(9, face: Face.rear),
          ),
        ];

        final front = computeRackRollups(
          rack: rack,
          devices: devices,
          templates: templates,
          face: Face.front,
        );
        final rear = computeRackRollups(
          rack: rack,
          devices: devices,
          templates: templates,
          face: Face.rear,
        );

        expect(
          front.ruUsed,
          0,
          reason: 'a rear patch panel occupies no front U',
        );
        expect(front.ruFree, 12);
        expect(rear.ruUsed, 1);
        expect(rear.ruFree, 11);
        expect(rear.face, Face.rear);
      });

      test('a BOTH-sides device occupies its own height on each face — the '
          'face is the ELEVATION, not the PLACEMENT', () {
        // docs/04 §2.2: the face control "selects a coordinate, not a
        // filter". This device is bolted to the FRONT rails and its template
        // gives it 2U front / 1U rear, so both elevations draw it and both
        // chips must count it.
        //
        // This assertion used to read `rear.ruUsed == 0`, with a comment
        // saying its placement was on the front so it contributed nothing to
        // the rear — the very rule the scene builder stopped applying. With
        // the elevation honouring CR-036 and the strip still filtering on
        // `placement.face`, `whole_house` rendered 19 device boxes on the
        // rear canvas under a chip reading `RU rear 0/42`.
        final rack = _rack();
        final templates = {'x@1': _snapshot('x', _body(frontU: 2, rearU: 1))};
        final devices = [_device('x-1', templateId: 'x', placement: _rail(3))];

        expect(
          computeRackRollups(
            rack: rack,
            devices: devices,
            templates: templates,
            face: Face.front,
          ).ruUsed,
          2,
        );
        final rear = computeRackRollups(
          rack: rack,
          devices: devices,
          templates: templates,
          face: Face.rear,
        );
        expect(rear.ruUsed, 1, reason: 'the rear elevation draws its 1U');
        expect(
          rear.ruUnknownCount,
          0,
          reason: 'the model states its rear height; nothing is unknown',
        );
      });

      test('a device bolted to the FRONT rails with no front footprint is '
          'counted on the REAR and is unknown on neither', () {
        // The rear lacing bar screwed to the front rails: `frontU 0 /
        // rearU 1`. `stackOccupancyU`s doc names this exact shape. Before
        // the repair the front chip counted it as an UNKNOWN contributor
        // (zero U on the face it claims to be mounted on) and the rear chip
        // did not count it at all, so one 1U device managed to be missing
        // from one elevation and a superscript on the other.
        final rack = _rack();
        final templates = {'bar@1': _snapshot('bar', _body(rearU: 1))};
        final devices = [
          _device('bar-1', templateId: 'bar', placement: _rail(4)),
        ];

        final front = computeRackRollups(
          rack: rack,
          devices: devices,
          templates: templates,
          face: Face.front,
        );
        final rear = computeRackRollups(
          rack: rack,
          devices: devices,
          templates: templates,
          face: Face.rear,
        );

        expect(front.ruUsed, 0);
        expect(
          front.ruUnknownCount,
          0,
          reason: 'zero front U is a MEASUREMENT',
        );
        expect(rear.ruUsed, 1);
        expect(rear.ruUnknownCount, 0);
      });

      test('OVERLAPPING placements count a shared U once, not twice', () {
        // An RCK-001 error state the model permits; the rollup must not
        // report 4 U used out of a 12U rack when only 3 slots are taken.
        final rack = _rack();
        final templates = {'a@1': _snapshot('a', _body(frontU: 2))};
        final devices = [
          _device('d1', templateId: 'a', placement: _rail(1)), // U1-U2
          _device('d2', templateId: 'a', placement: _rail(2)), // U2-U3
        ];

        final r = computeRackRollups(
          rack: rack,
          devices: devices,
          templates: templates,
          face: Face.front,
        );

        expect(r.ruUsed, 3);
        expect(r.ruFree, 9);
      });

      test('a device hanging past the top counts only the U that exist', () {
        final rack = _rack(heightU: 4);
        final templates = {'tall@1': _snapshot('tall', _body(frontU: 3))};
        final devices = [
          _device('t-1', templateId: 'tall', placement: _rail(3)), // U3-U5
        ];

        final r = computeRackRollups(
          rack: rack,
          devices: devices,
          templates: templates,
          face: Face.front,
        );

        expect(r.ruUsed, 2, reason: 'U3 and U4 exist; U5 does not');
        expect(r.ruFree, 2);
      });

      test('an unresolvable template is COUNTED as unknown, never as free', () {
        final rack = _rack();
        final devices = [
          _device('ghost', templateId: 'missing', placement: _rail(1)),
        ];

        final r = computeRackRollups(
          rack: rack,
          devices: devices,
          templates: const {},
          face: Face.front,
        );

        expect(r.ruUsed, 0);
        expect(r.ruUnknownCount, 1);
      });

      test('an empty rack is 0 used / all free, with nothing unknown', () {
        final r = computeRackRollups(
          rack: _rack(),
          devices: const [],
          templates: const {},
          face: Face.front,
        );

        expect(r.ruUsed, 0);
        expect(r.ruFree, 12);
        expect(r.ruUnknownCount, 0);
      });
    },
  );

  group('membership: which devices load THIS rack', () {
    test('a device in ANOTHER rack contributes nothing', () {
      final templates = {
        'a@1': _snapshot('a', _body(frontU: 2, weight: const Mass(1_000_000))),
      };
      final devices = [
        _device(
          'other',
          templateId: 'a',
          placement: _rail(1, rack: 'rk-2'),
        ),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.ruUsed, 0);
      expect(r.weight.knownCount, 0);
      expect(r.weight.unknownCount, 0);
    });

    test('a STAGED device (the Staging Bin, CR-032) loads no rack', () {
      final templates = {
        'a@1': _snapshot('a', _body(frontU: 2, weight: const Mass(1_000_000))),
      };
      final devices = [
        _device(
          'staged',
          templateId: 'a',
          placement: const StagedPlacement(
            lastRackId: Uuid('rk-1'),
            lastRuIndex: 4,
            lastFace: Face.front,
          ),
        ),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.ruUsed, 0);
      expect(r.weight.value, Mass.zero, reason: 'nobody contributed at all');
      expect(r.weight.unknownCount, 0);
    });

    test('a 0U channel occupant adds WEIGHT but no RU', () {
      final templates = {
        'pdu@1': _snapshot('pdu', _body(weight: const Mass(4_000_000_000))),
      };
      final devices = [
        _device(
          'pdu-1',
          templateId: 'pdu',
          placement: const ZeroUPlacement(
            rackId: Uuid('rk-1'),
            channelId: 'ch-a',
            offsetFromChannelStart: Len(0),
            orientation: ZeroUOrientation.vertical,
          ),
        ),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.ruUsed, 0);
      expect(r.weight.value, const Mass(4_000_000_000));
      expect(r.weight.knownCount, 1);
    });

    test('a SHELF-hosted device loads the rack its host is in', () {
      final templates = {
        'shelf@1': _snapshot(
          'shelf',
          _body(frontU: 1, weight: const Mass(2_000_000_000)),
        ),
        'box@1': _snapshot('box', _body(weight: const Mass(3_000_000_000))),
      };
      final devices = [
        _device('shelf-1', templateId: 'shelf', placement: _rail(5)),
        _device(
          'box-1',
          templateId: 'box',
          placement: const ShelfPlacement(
            hostDeviceId: Uuid('shelf-1'),
            order: FracIndex('a0'),
          ),
        ),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.ruUsed, 1, reason: 'the shelf occupies U5; its guest does not');
      expect(
        r.weight.value,
        const Mass(5_000_000_000),
        reason: 'a shelf guest loads the rack exactly as the shelf does',
      );
      expect(r.weight.knownCount, 2);
    });

    test('a shelf host in ANOTHER rack takes its guest with it', () {
      final templates = {
        'shelf@1': _snapshot('shelf', _body(frontU: 1)),
        'box@1': _snapshot('box', _body(weight: const Mass(3_000_000_000))),
      };
      final devices = [
        _device(
          'shelf-1',
          templateId: 'shelf',
          placement: _rail(5, rack: 'rk-2'),
        ),
        _device(
          'box-1',
          templateId: 'box',
          placement: const ShelfPlacement(
            hostDeviceId: Uuid('shelf-1'),
            order: FracIndex('a0'),
          ),
        ),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.weight.knownCount, 0);
      expect(r.weight.unknownCount, 0);
    });

    test('a shelf-host CYCLE in a corrupt file terminates, never hangs', () {
      final templates = {'box@1': _snapshot('box', _body())};
      final devices = [
        _device(
          'a',
          templateId: 'box',
          placement: const ShelfPlacement(
            hostDeviceId: Uuid('b'),
            order: FracIndex('a0'),
          ),
        ),
        _device(
          'b',
          templateId: 'box',
          placement: const ShelfPlacement(
            hostDeviceId: Uuid('a'),
            order: FracIndex('a1'),
          ),
        ),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.ruUsed, 0);
      expect(r.weight.knownCount, 0);
    });
  });

  group('Rollup.fromScan is the one spelling of rule 1', () {
    // The rule was written four times: a private `_totalOrUnknown` in
    // totals.dart, a verbatim copy of it in rack_load_gutter.dart, and the
    // ternary inline in equipment_list.dart and schedule.dart. They agreed,
    // so nothing was wrong; they were also free to stop agreeing. These
    // assert the rule at the one place it now lives, so the four surfaces
    // that read it cannot answer differently.
    test('a partial scan reports the KNOWN sum, not null', () {
      // The figure is a lower bound and `unknownCount` is what says so.
      // Nulling a total somebody DID contribute to would discard a
      // measurement, which is the opposite failure to fabricating one.
      final r = Rollup<int>.fromScan(sum: 7, knownCount: 2, unknownCount: 3);
      expect(r.value, 7);
      expect(r.isUnknown, isFalse);
      expect(r.knownCount, 2);
      expect(r.unknownCount, 3);
    });

    test('nothing known and somebody silent is UNKNOWN', () {
      final r = Rollup<int>.fromScan(sum: 0, knownCount: 0, unknownCount: 4);
      expect(r.value, isNull);
      expect(r.isUnknown, isTrue);
      expect(r.unknownCount, 4);
    });

    test('nobody asked at all is a MEASURED zero, not unknown', () {
      final r = Rollup<int>.fromScan(sum: 0, knownCount: 0, unknownCount: 0);
      expect(r.value, 0);
      expect(r.isUnknown, isFalse);
    });

    test('it carries an extension-type sum through unchanged', () {
      // `Mass` erases to int at runtime, and the rollup that most needs
      // exact integer arithmetic is the one this factory is generic for.
      final r = Rollup<Mass>.fromScan(
        sum: const Mass(1500),
        knownCount: 1,
        unknownCount: 1,
      );
      expect(r.value, const Mass(1500));
      expect(r.value?.ug, 1500);
    });
  });

  group('unknown is NULL, never 0 (G4, CR-114, docs/04 §5)', () {
    test('a rack whose every device lacks a weight reports NULL, not 0 kg', () {
      final templates = {
        'a@1': _snapshot('a', _body(frontU: 2)),
        'b@1': _snapshot('b', _body(frontU: 1)),
      };
      final devices = [
        _device('d1', templateId: 'a', placement: _rail(1)),
        _device('d2', templateId: 'b', placement: _rail(7)),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.weight.value, isNull);
      expect(r.weight.isUnknown, isTrue);
      expect(r.weight.unknownCount, 2);
      expect(r.weight.knownCount, 0);
    });

    test('an EMPTY rack reports a genuine zero, not unknown', () {
      // Nobody was asked, so nothing is being guessed: an empty rack
      // really does add no weight and provide no outlets.
      final r = computeRackRollups(
        rack: _rack(),
        devices: const [],
        templates: const {},
        face: Face.front,
      );

      expect(r.weight.value, Mass.zero);
      expect(r.weight.isUnknown, isFalse);
      expect(r.weight.unknownCount, 0);
      expect(r.apparentVA.value, 0);
      expect(r.outletsProvided.value, 0);
    });

    test('a PARTIAL weight total sums the known and counts the rest', () {
      final templates = {
        'known@1': _snapshot(
          'known',
          _body(frontU: 1, weight: const Mass(2_000_000_000)),
        ),
        'unknown@1': _snapshot('unknown', _body(frontU: 1)),
      };
      final devices = [
        _device('d1', templateId: 'known', placement: _rail(1)),
        _device('d2', templateId: 'known', placement: _rail(2)),
        _device('d3', templateId: 'unknown', placement: _rail(3)),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.weight.value, const Mass(4_000_000_000));
      expect(r.weight.knownCount, 2);
      expect(r.weight.unknownCount, 1);
      expect(r.weight.isUnknown, isFalse);
    });

    test('a DeviceOverrides weight beats the template weight', () {
      final templates = {
        'a@1': _snapshot(
          'a',
          _body(frontU: 1, weight: const Mass(2_000_000_000)),
        ),
      };
      final devices = [
        _device(
          'd1',
          templateId: 'a',
          placement: _rail(1),
          overrides: DeviceOverrides(weight: const Mass(9_000_000_000)),
        ),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.weight.value, const Mass(9_000_000_000));
    });

    test('an override supplies a weight the template does NOT have', () {
      final templates = {'a@1': _snapshot('a', _body(frontU: 1))};
      final devices = [
        _device(
          'd1',
          templateId: 'a',
          placement: _rail(1),
          overrides: DeviceOverrides(weight: const Mass(1_500_000_000)),
        ),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.weight.value, const Mass(1_500_000_000));
      expect(r.weight.unknownCount, 0);
    });

    test('weightCapacity comes straight off the rack, null when unset', () {
      expect(
        computeRackRollups(
          rack: _rack(),
          devices: const [],
          templates: const {},
          face: Face.front,
        ).weightCapacity,
        isNull,
      );
      expect(
        computeRackRollups(
          rack: _rack(weightCapacity: const Mass(90_718_474_000)),
          devices: const [],
          templates: const {},
          face: Face.front,
        ).weightCapacity,
        const Mass(90_718_474_000),
      );
    });
  });

  group('VA is VA (CR-056, AC-020) and is never inferred from watts', () {
    test('sums apparentVA and counts the templates that omit it', () {
      final templates = {
        'amp@1': _snapshot('amp', _body(frontU: 2, apparentVA: 840)),
        'sw@1': _snapshot('sw', _body(frontU: 1, apparentVA: 400)),
        'blank@1': _snapshot('blank', _body(frontU: 1)),
      };
      final devices = [
        _device('d1', templateId: 'amp', placement: _rail(1)),
        _device('d2', templateId: 'sw', placement: _rail(4)),
        _device('d3', templateId: 'blank', placement: _rail(6)),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.apparentVA.value, 1240);
      expect(r.apparentVA.knownCount, 2);
      expect(r.apparentVA.unknownCount, 1);
    });

    test('a template with typicalWatts but no apparentVA is UNKNOWN VA', () {
      // AC-039's rejected behaviour, restated as a test: a power factor
      // nobody authored is not a power factor this code may assume.
      final body = _body(frontU: 1)..power.typicalWatts = 300;
      final templates = {'a@1': _snapshot('a', body)};
      final devices = [_device('d1', templateId: 'a', placement: _rail(1))];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.apparentVA.value, isNull);
      expect(r.apparentVA.unknownCount, 1);
    });

    test('a rear-face device still contributes VA to the FRONT elevation', () {
      final templates = {
        'pp@1': _snapshot('pp', _body(rearU: 1, apparentVA: 60)),
      };
      final devices = [
        _device(
          'pp-1',
          templateId: 'pp',
          placement: _rail(9, face: Face.rear),
        ),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.ruUsed, 0, reason: 'RU is per-face');
      expect(r.apparentVA.value, 60, reason: 'power is rack-wide');
    });
  });

  group('outlets', () {
    test('sums provided and consumed across both faces', () {
      // All three templates AUTHOR both counts — including the zeros. A
      // seeded template with no outlets says `outletsProvided: 0`
      // explicitly (catalog_*.dart), and that is a measurement.
      final templates = {
        'pdu@1': _snapshot(
          'pdu',
          _body(frontU: 1, outletsProvided: 16, outletsConsumed: 0),
        ),
        'amp@1': _snapshot(
          'amp',
          _body(frontU: 2, outletsProvided: 0, outletsConsumed: 1),
        ),
        'pp@1': _snapshot(
          'pp',
          _body(rearU: 1, outletsProvided: 0, outletsConsumed: 1),
        ),
      };
      final devices = [
        _device('d1', templateId: 'pdu', placement: _rail(1)),
        _device('d2', templateId: 'amp', placement: _rail(3)),
        _device(
          'd3',
          templateId: 'pp',
          placement: _rail(9, face: Face.rear),
        ),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.outletsProvided.value, 16);
      expect(r.outletsConsumed.value, 2);
      expect(r.outletsProvided.unknownCount, 0);
      expect(r.outletsConsumed.unknownCount, 0);
    });

    test('a RESOLVED but unauthored outlet count is unknown, not a measured '
        'zero (rule 1)', () {
      // The defect: `outletsProvided`/`outletsConsumed` were non-nullable
      // ints defaulting to 0, so this rack of two perfectly-resolvable
      // templates rendered `outlets 0/0` with no superscript — a rack
      // stating as FACT that it provides zero outlets when the truth is
      // that nobody authored outlet data for either template.
      final templates = {
        'ups@1': _snapshot('ups', _body(frontU: 2)),
        'amp@1': _snapshot('amp', _body(frontU: 2)),
      };
      final devices = [
        _device('d1', templateId: 'ups', placement: _rail(1)),
        _device('d2', templateId: 'amp', placement: _rail(4)),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.outletsProvided.value, isNull);
      expect(r.outletsProvided.isUnknown, isTrue);
      expect(r.outletsProvided.unknownCount, 2);
      expect(r.outletsProvided.knownCount, 0);
      expect(r.outletsConsumed.value, isNull);
      expect(r.outletsConsumed.unknownCount, 2);
    });

    test('provided and consumed carry INDEPENDENT unknown counts', () {
      // A template may state one and not the other. Sharing one count
      // attributes one rollup's ignorance to the other.
      final templates = {
        'pdu@1': _snapshot('pdu', _body(frontU: 1, outletsProvided: 24)),
        'amp@1': _snapshot('amp', _body(frontU: 2, outletsConsumed: 1)),
      };
      final devices = [
        _device('d1', templateId: 'pdu', placement: _rail(1)),
        _device('d2', templateId: 'amp', placement: _rail(4)),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.outletsProvided.value, 24);
      expect(r.outletsProvided.knownCount, 1);
      expect(r.outletsProvided.unknownCount, 1, reason: 'the amp is silent');
      expect(r.outletsConsumed.value, 1);
      expect(r.outletsConsumed.knownCount, 1);
      expect(r.outletsConsumed.unknownCount, 1, reason: 'the PDU is silent');
    });

    test('outletsUnknownCount counts a device silent about EITHER half — '
        'the number the one-chip `outlets a/b` has to state', () {
      // The same divergent shape as the test above, read the way the chip
      // strip reads it: ONE chip showing `outlets 1/24`, so ONE unknown
      // count, and it is neither rollup's own. Both `unknownCount`s are 1
      // (max = 1, which UNDER-counts and is what the chip used to show,
      // superscript-free), while TWO of the two devices are missing from
      // the figure on screen.
      final templates = {
        'pdu@1': _snapshot('pdu', _body(frontU: 1, outletsProvided: 24)),
        'amp@1': _snapshot('amp', _body(frontU: 2, outletsConsumed: 1)),
      };
      final devices = [
        _device('d1', templateId: 'pdu', placement: _rail(1)),
        _device('d2', templateId: 'amp', placement: _rail(4)),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.outletsUnknownCount, 2);
    });

    test('a device silent about BOTH halves is ONE incomplete contributor, '
        'not two', () {
      // The other bound: the SUM of the two counts is 2 here, and 2 would
      // be a fabricated number — there is one device and it is silent once.
      final templates = {
        'pdu@1': _snapshot(
          'pdu',
          _body(frontU: 1, outletsProvided: 24, outletsConsumed: 1),
        ),
        'blank@1': _snapshot('blank', _body(frontU: 1)),
      };
      final devices = [
        _device('d1', templateId: 'pdu', placement: _rail(1)),
        _device('d2', templateId: 'blank', placement: _rail(4)),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.outletsProvided.unknownCount, 1);
      expect(r.outletsConsumed.unknownCount, 1);
      expect(
        r.outletsUnknownCount,
        1,
        reason: 'one device, one silence — the sum of the two counts is 2',
      );
    });

    test('a rack where every device states both outlet counts has nothing '
        'unknown', () {
      final templates = {
        'pdu@1': _snapshot(
          'pdu',
          _body(frontU: 1, outletsProvided: 24, outletsConsumed: 1),
        ),
      };
      final devices = [_device('d1', templateId: 'pdu', placement: _rail(1))];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.outletsUnknownCount, 0);
    });

    test('an unresolvable template makes outlets unknown for that device', () {
      final templates = {
        'pdu@1': _snapshot(
          'pdu',
          _body(frontU: 1, outletsProvided: 16, outletsConsumed: 1),
        ),
      };
      final devices = [
        _device('d1', templateId: 'pdu', placement: _rail(1)),
        _device('ghost', templateId: 'missing', placement: _rail(5)),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(r.outletsProvided.value, 16);
      expect(
        r.outletsProvided.unknownCount,
        1,
        reason: 'only the ghost; the PDU states its outlets',
      );
      expect(r.outletsConsumed.unknownCount, 1);
      // Weight and VA are unknown for BOTH: the PDU template authors
      // neither, and the ghost authors nothing at all.
      expect(r.apparentVA.unknownCount, 2);
      expect(r.weight.unknownCount, 2);
    });
  });

  // ── the unknown contributor that used to be dropped (G4) ──────────────
  group('RU on a face the template gives the device no height on', () {
    test('a rail placement whose template resolves to 0U on the DISPLAYED '
        'face counts as unknown, not as a known zero', () {
      // The P01 quick-add case: a 0U-vertical template rail-placed on the
      // rear. `ruUnknownCount` was incremented only when the snapshot
      // failed to resolve, so this device — resolvable, present, on this
      // very face — added nothing to `ruUsed` and nothing to the unknown
      // count either. The rear chip read `RU rear 0/12` with no
      // superscript while a device sat on that face.
      final templates = {
        'pdu0u@1': _snapshot('pdu0u', _body(model: '0U PDU')), // 0U both faces
      };
      final devices = [
        _device(
          'd1',
          templateId: 'pdu0u',
          placement: _rail(3, face: Face.rear),
        ),
      ];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.rear,
      );

      expect(r.ruUsed, 0);
      expect(
        r.ruUnknownCount,
        1,
        reason: 'the chip must read "RU rear 0/12 ⁽¹⁾", not a bare 0/12',
      );
    });

    test('a front-only device does NOT inflate the rear unknown count', () {
      // The guard on the guard: a 1U front panel viewed from the rear is
      // not an unknown rear occupant, it is simply not a rear occupant.
      final templates = {'blk@1': _snapshot('blk', _body(frontU: 1))};
      final devices = [_device('d1', templateId: 'blk', placement: _rail(3))];

      final r = computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.rear,
      );

      expect(r.ruUsed, 0);
      expect(r.ruUnknownCount, 0);
    });
  });

  group('the demo rack — the exact numbers the chip strip got wrong', () {
    // rack_canvas_screen.dart's `_buildDemoDocument`: RK-1, 12U, with
    // UPS-1 (2U @ U1), AMP-1 (2U @ U4), SW-1 (1U @ U7) on the front and
    // PP-1 (rear 1U @ U9). The shipped strip read "12/12U · 0 free".
    RackRollups demo(Face face) {
      final templates = {
        'ups@1': _snapshot('ups', _body(frontU: 2, model: 'Rack UPS 1500VA')),
        'amp@1': _snapshot('amp', _body(frontU: 2, model: '16-ch amplifier')),
        'sw@1': _snapshot('sw', _body(frontU: 1, model: '24-port PoE switch')),
        'pp@1': _snapshot('pp', _body(rearU: 1, model: '24-port patch panel')),
      };
      final devices = [
        _device('dev-ups', templateId: 'ups', placement: _rail(1)),
        _device('dev-amp', templateId: 'amp', placement: _rail(4)),
        _device('dev-sw', templateId: 'sw', placement: _rail(7)),
        _device(
          'dev-pp',
          templateId: 'pp',
          placement: _rail(9, face: Face.rear),
        ),
      ];
      return computeRackRollups(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: face,
      );
    }

    test('FRONT reads 5 used / 7 free of 12, not 12 used / 0 free', () {
      final r = demo(Face.front);
      expect(r.ruUsed, 5);
      expect(r.ruFree, 7);
      expect(r.ruCapacity, 12);
      expect(r.ruUnknownCount, 0);
    });

    test('REAR reads 1 used / 11 free — PP-1 is a rear device', () {
      final r = demo(Face.rear);
      expect(r.ruUsed, 1);
      expect(r.ruFree, 11);
    });

    test('every other rollup is honestly UNKNOWN, with a count of 4', () {
      // None of the four demo templates authors a weight, a VA figure or
      // outlet counts, so the strip must show an em dash on three chips —
      // not "0 kg · 0 VA · 0 outlets", which is what it shipped.
      //
      // The outlet pair was the last one still fabricating: it read a
      // confident `outlets 0/0` with no superscript on the app's own
      // default document, because the fields were non-nullable ints
      // defaulting to 0. All FOUR chips are honest now.
      final r = demo(Face.front);
      expect(r.weight.value, isNull);
      expect(r.weight.unknownCount, 4);
      expect(r.apparentVA.value, isNull);
      expect(r.apparentVA.unknownCount, 4);
      expect(r.outletsProvided.value, isNull);
      expect(r.outletsProvided.unknownCount, 4);
      expect(r.outletsConsumed.value, isNull);
      expect(r.outletsConsumed.unknownCount, 4);
    });
  });
}
