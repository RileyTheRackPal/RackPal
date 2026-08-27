// T6.30's row model.
//
// The load-bearing property is TOTALITY: every device in the document lands
// in exactly one group. "The equipment list matches the rack contents
// EXACTLY" is the M1 exit criterion's own wording, and an equipment list
// that omits equipment is the failure it is testing for.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../sheet/sheet_test_support.dart';

const Uuid _rackA = Uuid('rack-a');
const Uuid _rackB = Uuid('rack-b');

DeviceInstance _device({
  required String id,
  required Placement placement,
  String? name,
  String template = 'T1',
  LifecycleStatus lifecycle = LifecycleStatus.new_,
  Uuid? locationId,
  String? notes,
}) => DeviceInstance(
  id: Uuid(id),
  kind: DeviceKind.rackDevice,
  templateRef: TemplateRef(
    templateId: TemplateId(template),
    version: 1,
    contentHash: 'h',
  ),
  designator: id.toUpperCase(),
  name: name ?? '',
  placement: placement,
  meta: testMeta(),
  lifecycleStatus: lifecycle,
  locationId: locationId,
  notes: notes,
);

TemplateSnapshot _snapshot({
  String id = 'T1',
  Mass? weight,
  int? va,
  int frontU = 1,
  int rearU = 0,
  String display = 'Widget',
}) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'h',
  body: TemplateBody(
    manufacturer: 'ACME',
    model: 'MDL-$id',
    displayName: display,
    frontU: frontU,
    rearU: rearU,
    weight: weight,
    power: PowerProfile(apparentVA: va),
  ),
  capturedAt: DateTime.utc(2026),
);

RackDocument _doc({
  required List<Rack> racks,
  required List<DeviceInstance> devices,
  Map<String, TemplateSnapshot>? templates,
  Map<Uuid, Location>? locations,
}) => RackDocument(
  id: const Uuid('doc'),
  appVersion: 'test',
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  meta: testMeta(),
  racks: <Uuid, Rack>{for (final r in racks) r.id: r},
  devices: <Uuid, DeviceInstance>{for (final d in devices) d.id: d},
  templates: templates ?? <String, TemplateSnapshot>{'T1@1': _snapshot()},
  locations: locations ?? <Uuid, Location>{},
);

Rack _rack(Uuid id, String designator, String order) => Rack(
  id: id,
  name: 'NAME',
  designator: designator,
  heightU: 12,
  order: FracIndex(order),
  meta: testMeta(),
);

void main() {
  group('totality — nothing is silently dropped', () {
    test('every device lands in exactly one group', () {
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          _device(
            id: 'rail',
            placement: const RailPlacement(
              rackId: _rackA,
              ruIndex: 3,
              face: Face.front,
            ),
          ),
          _device(id: 'off', placement: const OffRackPlacement()),
          _device(id: 'staged', placement: const StagedPlacement()),
        ],
      );

      final list = buildEquipmentList(doc);

      expect(list.rowCount, 3);
      expect(
        list.rows.map((r) => r.designator).toSet(),
        <String>{'RAIL', 'OFF', 'STAGED'},
      );
      expect(list.unplacedCount, 2);
    });

    test('a rail placement naming a rack the document does NOT hold still '
        'produces a row', () {
      // The failure that would otherwise be invisible: a device that
      // believes it is in a rack nobody can find has no group to be in, and
      // dropping it would remove equipment from the equipment list.
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          _device(
            id: 'ghost',
            placement: const RailPlacement(
              rackId: Uuid('rack-that-is-gone'),
              ruIndex: 1,
              face: Face.front,
            ),
          ),
        ],
      );

      final list = buildEquipmentList(doc);

      expect(list.rowCount, 1);
      expect(list.groups.last.title, kUnplacedGroupTitle);
      expect(list.groups.last.rows.single.designator, 'GHOST');
    });

    test('an empty document produces no groups and no rows', () {
      final list = buildEquipmentList(
        _doc(racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')], devices: const []),
      );

      expect(list.rowCount, 0);
      expect(list.unplacedCount, 0);
      // The rack group still exists so the sheet names the rack.
      expect(list.groups, hasLength(1));
    });
  });

  group('order is total and deterministic (§8.4)', () {
    test('racks in Rack.order, rows by RU DESCENDING', () {
      final doc = _doc(
        racks: <Rack>[
          _rack(_rackB, 'RK-2', 'a5'),
          _rack(_rackA, 'RK-1', 'a0'),
        ],
        devices: <DeviceInstance>[
          for (final ru in <int>[1, 9, 5])
            _device(
              id: 'a$ru',
              placement: RailPlacement(
                rackId: _rackA,
                ruIndex: ru,
                face: Face.front,
              ),
            ),
          _device(
            id: 'b1',
            placement: const RailPlacement(
              rackId: _rackB,
              ruIndex: 2,
              face: Face.front,
            ),
          ),
        ],
      );

      final list = buildEquipmentList(doc);

      expect(
        list.groups.map((g) => g.title.split(' · ').first).toList(),
        <String>['RK-1', 'RK-2'],
      );
      expect(
        list.groups.first.rows.map((r) => r.ruIndex).toList(),
        <int>[9, 5, 1],
      );
    });

    test('rows with no RU sort AFTER the rail-mounted ones', () {
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          _device(
            id: 'zzz',
            placement: const ZeroUPlacement(
              rackId: _rackA,
              channelId: 'c',
              offsetFromChannelStart: Len(0),
              orientation: ZeroUOrientation.vertical,
            ),
          ),
          _device(
            id: 'aaa',
            placement: const RailPlacement(
              rackId: _rackA,
              ruIndex: 1,
              face: Face.front,
            ),
          ),
        ],
      );

      final rows = buildEquipmentList(doc).groups.single.rows;
      expect(rows.map((r) => r.designator).toList(), <String>['AAA', 'ZZZ']);
    });

    test('ties at the same RU break by device UUID, not by Map order', () {
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          for (final id in <String>['zeta', 'alpha', 'mid'])
            _device(
              id: id,
              placement: const RailPlacement(
                rackId: _rackA,
                ruIndex: 4,
                face: Face.front,
              ),
            ),
        ],
      );

      expect(
        buildEquipmentList(
          doc,
        ).groups.single.rows.map((r) => r.deviceId.v).toList(),
        <String>['alpha', 'mid', 'zeta'],
      );
    });

    test('two builds of the same document are identical', () {
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          for (var i = 0; i < 8; i++)
            _device(
              id: 'd$i',
              placement: RailPlacement(
                rackId: _rackA,
                ruIndex: i + 1,
                face: Face.front,
              ),
            ),
        ],
      );

      expect(
        buildEquipmentList(doc).rows.map((r) => r.deviceId.v).toList(),
        buildEquipmentList(doc).rows.map((r) => r.deviceId.v).toList(),
      );
    });
  });

  group('subtotals equal computeRackRollups on the same inputs', () {
    test('mass and VA agree, unknown counts included', () {
      final templates = <String, TemplateSnapshot>{
        'T1@1': _snapshot(weight: const Mass(2_000_000_000), va: 120),
        'T2@1': _snapshot(id: 'T2'), // no weight, no VA
      };
      final devices = <DeviceInstance>[
        _device(
          id: 'known',
          placement: const RailPlacement(
            rackId: _rackA,
            ruIndex: 1,
            face: Face.front,
          ),
        ),
        _device(
          id: 'unknown',
          template: 'T2',
          placement: const RailPlacement(
            rackId: _rackA,
            ruIndex: 3,
            face: Face.front,
          ),
        ),
      ];
      final rack = _rack(_rackA, 'RK-1', 'a0');
      final doc = _doc(
        racks: <Rack>[rack],
        devices: devices,
        templates: templates,
      );

      final group = buildEquipmentList(doc).groups.single;
      final rollups = computeRackRollups(
        rack: rack,
        devices: devices,
        templates: templates,
        face: Face.front,
      );

      expect(group.mass.value?.ug, rollups.weight.value?.ug);
      expect(group.mass.unknownCount, 1);
      expect(group.mass.unknownCount, rollups.weight.unknownCount);
      expect(group.apparentVA.value, rollups.apparentVA.value);
      expect(group.apparentVA.unknownCount, rollups.apparentVA.unknownCount);
    });

    test('a subtotal with NO known contributor is null, never zero', () {
      final rack = _rack(_rackA, 'RK-1', 'a0');
      final doc = _doc(
        racks: <Rack>[rack],
        devices: <DeviceInstance>[
          _device(
            id: 'x',
            placement: const RailPlacement(
              rackId: _rackA,
              ruIndex: 1,
              face: Face.front,
            ),
          ),
        ],
        templates: <String, TemplateSnapshot>{'T1@1': _snapshot()},
      );

      final group = buildEquipmentList(doc).groups.single;
      expect(group.mass.value, isNull);
      expect(group.mass.unknownCount, 1);
    });

    test('an EMPTY rack subtotals a genuine zero — nobody was asked', () {
      final group = buildEquipmentList(
        _doc(racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')], devices: const []),
      ).groups.single;

      expect(group.mass.value, Mass.zero);
      expect(group.mass.unknownCount, 0);
    });
  });

  group('cells', () {
    test('the RU label is docs/08 §2.2\'s "4U · 12–15"', () {
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          _device(
            id: 'big',
            placement: const RailPlacement(
              rackId: _rackA,
              ruIndex: 12,
              face: Face.front,
            ),
          ),
        ],
        templates: <String, TemplateSnapshot>{'T1@1': _snapshot(frontU: 4)},
      );

      expect(buildEquipmentList(doc).rows.single.ruLabel, '4U · 12–15');
    });

    test('a 1 U device prints "1U · 7", not a degenerate range', () {
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          _device(
            id: 'one',
            placement: const RailPlacement(
              rackId: _rackA,
              ruIndex: 7,
              face: Face.front,
            ),
          ),
        ],
      );

      expect(buildEquipmentList(doc).rows.single.ruLabel, '1U · 7');
    });

    test('an UNMODELLED rail device says so rather than claiming a span', () {
      // Rail-placed, but the template gives it zero U on the face it claims
      // — `rack_shrink.dart`'s "its height is not knowable".
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          _device(
            id: 'rear',
            placement: const RailPlacement(
              rackId: _rackA,
              ruIndex: 5,
              face: Face.rear,
            ),
          ),
        ],
      );

      final row = buildEquipmentList(doc).rows.single;
      expect(row.ruSpan, isNull);
      expect(row.ruLabel, '— · 5');
    });

    test('a 0U occupant prints 0U, not an em dash', () {
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          _device(
            id: 'pdu',
            placement: const ZeroUPlacement(
              rackId: _rackA,
              channelId: 'c',
              offsetFromChannelStart: Len(0),
              orientation: ZeroUOrientation.vertical,
            ),
          ),
        ],
      );

      final row = buildEquipmentList(doc).rows.single;
      expect(row.mounting, EquipmentMounting.zeroU);
      expect(row.ruLabel, '0U');
    });

    test('the description falls back to the template display name', () {
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          _device(
            id: 'named',
            name: 'Living room amp',
            placement: const RailPlacement(
              rackId: _rackA,
              ruIndex: 1,
              face: Face.front,
            ),
          ),
          _device(
            id: 'unnamed',
            placement: const RailPlacement(
              rackId: _rackA,
              ruIndex: 2,
              face: Face.front,
            ),
          ),
        ],
      );

      final rows = <String, String>{
        for (final r in buildEquipmentList(doc).rows)
          r.designator: r.description,
      };
      expect(rows['NAMED'], 'Living room amp');
      expect(rows['UNNAMED'], 'Widget');
    });

    test('the location resolves through the document, or stays null', () {
      const locId = Uuid('loc');
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          _device(
            id: 'placed',
            locationId: locId,
            placement: const RailPlacement(
              rackId: _rackA,
              ruIndex: 1,
              face: Face.front,
            ),
          ),
          _device(
            id: 'nowhere',
            placement: const RailPlacement(
              rackId: _rackA,
              ruIndex: 2,
              face: Face.front,
            ),
          ),
        ],
        locations: <Uuid, Location>{
          locId: Location(
            id: locId,
            kind: LocationKind.room,
            name: 'Media Room',
            code: 'MR',
            order: const FracIndex('a0'),
            meta: testMeta(),
          ),
        },
      );

      final rows = <String, String?>{
        for (final r in buildEquipmentList(doc).rows) r.designator: r.location,
      };
      expect(rows['PLACED'], 'Media Room');
      expect(rows['NOWHERE'], isNull);
    });

    test('QTY is always 1 — the identical-device collapse is NOT built', () {
      // Deliberate: a quantity rollup is exactly the transform that makes
      // an off-by-one invisible to the exit criterion's bijection test.
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          for (var i = 1; i <= 3; i++)
            _device(
              id: 'same$i',
              placement: RailPlacement(
                rackId: _rackA,
                ruIndex: i,
                face: Face.front,
              ),
            ),
        ],
      );

      final list = buildEquipmentList(doc);
      expect(list.rowCount, 3);
      for (final row in list.rows) {
        expect(row.qty, 1);
      }
    });
  });

  group('an ABSENT cell is an em dash, never a blank', () {
    // ==================================================================
    // "AN EMPTY CELL READS AS 'NOBODY FILLED THIS IN'" — text_fit.dart's
    // own kEmDash doc, which this file was breaking.
    // ==================================================================
    // `STR-1` is the one device in every starter with no template snapshot
    // behind it, and that is the SPEC (docs/07 §2: "No template"). It
    // printed a row with two BLANK cells beside three em dashes, and a
    // reader had no way to tell which blank meant "there is none" and
    // which meant "somebody forgot".

    RackDocument docWithNoTemplate() => _doc(
      racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
      devices: <DeviceInstance>[
        _device(
          id: 'str',
          name: 'Rough-In — First Floor',
          template: 'structure',
          placement: const OffRackPlacement(),
        ),
      ],
      templates: <String, TemplateSnapshot>{'T1@1': _snapshot()},
    );

    test('an unresolved template gives null manufacturer and model, not '
        'empty strings', () {
      final row = buildEquipmentList(docWithNoTemplate()).rows.single;

      expect(row.manufacturer, isNull);
      expect(row.model, isNull);
    });

    test('a blank authored manufacturer is null too — same cell, same '
        'meaning', () {
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          _device(
            id: 'blank',
            placement: const RailPlacement(
              rackId: _rackA,
              ruIndex: 1,
              face: Face.front,
            ),
          ),
        ],
        templates: <String, TemplateSnapshot>{
          'T1@1': TemplateSnapshot(
            templateId: const TemplateId('T1'),
            version: 1,
            contentHash: 'h',
            body: TemplateBody(
              manufacturer: '  ',
              model: '',
              displayName: 'Widget',
              frontU: 1,
            ),
            capturedAt: DateTime.utc(2026),
          ),
        },
      );

      final row = buildEquipmentList(doc).rows.single;
      expect(row.manufacturer, isNull);
      expect(row.model, isNull);
    });

    test('the FACE cell of an off-rack device says NONE, never nothing', () {
      // And NOT an em dash: "not on a face" is a fact the model states,
      // and the em dash means "we do not know".
      expect(EquipmentMounting.none.label, 'NONE');
      for (final mounting in EquipmentMounting.values) {
        expect(mounting.label, isNotEmpty, reason: mounting.name);
        expect(mounting.label, isNot(kUnknownCell), reason: mounting.name);
      }
    });
  });

  group('the MODEL cell reads doc.structures', () {
    // A structure device has no template BY SPEC, and the model string it
    // does have lives on the `StructureBody` beside it. Nothing under
    // `derived/` read `doc.structures` at all, so `whole_house`'s "Generic
    // 42 in structured media enclosure" sat in the document and never
    // reached the deliverable.
    test('StructureBody.enclosureModel reaches the row', () {
      const bodyId = Uuid('sbody');
      const deviceId = Uuid('str');
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          DeviceInstance(
            id: deviceId,
            kind: DeviceKind.structure,
            templateRef: const TemplateRef(
              templateId: TemplateId('structure'),
              version: 1,
              contentHash: 'sha256:structure-no-template',
            ),
            designator: 'STR-1',
            name: 'Rough-In — First Floor',
            placement: const OffRackPlacement(),
            meta: testMeta(),
            structureBodyId: bodyId,
          ),
        ],
      );
      doc.structures[bodyId] = StructureBody(
        id: bodyId,
        deviceId: deviceId,
        title: 'Rough-In — First Floor',
        meta: testMeta(),
        enclosureModel: 'Generic 42 in structured media enclosure',
      );

      final row = buildEquipmentList(doc).rows.single;
      expect(row.model, 'Generic 42 in structured media enclosure');
      // Still unknown, and still said so — the structure body carries no
      // manufacturer.
      expect(row.manufacturer, isNull);
    });

    test('a template model still WINS — the structure fallback never '
        'overwrites an authored one', () {
      const bodyId = Uuid('sbody');
      const deviceId = Uuid('d');
      final doc = _doc(
        racks: <Rack>[_rack(_rackA, 'RK-1', 'a0')],
        devices: <DeviceInstance>[
          DeviceInstance(
            id: deviceId,
            kind: DeviceKind.rackDevice,
            templateRef: const TemplateRef(
              templateId: TemplateId('T1'),
              version: 1,
              contentHash: 'h',
            ),
            designator: 'D-1',
            name: '',
            placement: const RailPlacement(
              rackId: _rackA,
              ruIndex: 1,
              face: Face.front,
            ),
            meta: testMeta(),
            structureBodyId: bodyId,
          ),
        ],
      );
      doc.structures[bodyId] = StructureBody(
        id: bodyId,
        deviceId: deviceId,
        title: 'x',
        meta: testMeta(),
        enclosureModel: 'SHOULD NOT WIN',
      );

      expect(buildEquipmentList(doc).rows.single.model, 'MDL-T1');
    });
  });

  group('lifecycle labels never leak the Dart keyword workaround', () {
    test('new_ prints NEW', () {
      expect(lifecycleLabel(LifecycleStatus.new_), 'NEW');
      for (final status in LifecycleStatus.values) {
        expect(lifecycleLabel(status), isNot(contains('_')));
        expect(lifecycleLabel(status), isNotEmpty);
      }
    });
  });
}
