// Passives leave T6.30's equipment rows for its MATERIALS (M6-F6 `#970`,
// DR-211 §11.210.3, DR-213).
//
// ═══════════════════════════════════════════════════════════════════════
// THE STARTER BIJECTION, ON THIS SIDE OF THE PACKAGE LINE TOO
// ═══════════════════════════════════════════════════════════════════════
// `equipment_list.dart`'s header pointed at `equipment_list_test.dart` for
// the starter bijection; that file's is synthetic and none of its devices
// is passive, so moving every passive off the rows left this package's
// whole suite green. The starter bijection lives in `rackpal_export`'s
// `starters_export_test.dart`, in ink, and it did fail. This is its model
// form, so `rackpal_core` catches the defect on its own, in the shape
// DR-213 §11.212.3 restates: every device is one row or one unit.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../sheet/sheet_test_support.dart';

const List<String> _starters = <String>[
  'apartment',
  'home_theatre',
  'small_office',
  'whole_house',
];

RackDocument _starter(String name) =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/$name.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

void main() {
  group('on every starter (§11.212.3)', () {
    for (final name in _starters) {
      group(name, () {
        final doc = _starter(name);
        final list = buildEquipmentList(doc);

        test('EVERY DEVICE IS ONE ROW OR ONE MATERIALS UNIT, never both and '
            'never neither', () {
          final rowIds = [for (final r in list.rows) r.deviceId];
          final unitIds = [for (final m in list.materials) ...m.deviceIds];
          expect(
            {...rowIds, ...unitIds},
            doc.devices.keys.toSet(),
            reason: 'a device is missing from the sheet',
          );
          expect(
            rowIds.length + unitIds.length,
            doc.devices.length,
            reason: 'a device is counted twice',
          );
        });

        test('THE MATERIALS ARE EXACTLY THE PASSIVES', () {
          final passives = {
            for (final d in doc.devices.values)
              if (isPassiveDevice(d, doc.templates)) d.id,
          };
          expect(
            {for (final m in list.materials) ...m.deviceIds},
            passives,
          );
          expect(
            list.rows.where((r) => passives.contains(r.deviceId)),
            isEmpty,
          );
        });

        test('A RACK SUBTOTAL IS STILL THE WHOLE RACK (§11.212.1): it equals '
            'computeRackRollups, and counts its passives', () {
          final landings = PortLandings.of(doc);
          for (final group in list.groups.where((g) => !g.isUnplaced)) {
            final rack = doc.racks[group.rackId]!;
            final rollups = computeRackRollups(
              rack: rack,
              devices: doc.devices.values,
              templates: doc.templates,
              face: Face.front,
              landings: landings,
            );
            expect(
              group.mass.value,
              rollups.weight.value,
              reason: rack.designator,
            );
            expect(
              group.mass.unknownCount,
              rollups.weight.unknownCount,
              reason: rack.designator,
            );
            expect(
              group.apparentVA.value,
              rollups.apparentVA.value,
              reason: rack.designator,
            );
            final inMaterials = list.materials.fold<int>(
              0,
              (n, m) =>
                  n +
                  m.where
                      .where((w) => w.$1 == rack.designator)
                      .fold<int>(0, (k, w) => k + w.$2),
            );
            expect(group.passiveCount, inMaterials, reason: rack.designator);
          }
        });

        test("THE COVER'S COUNT IS T6.30's ROWS, rack by rack", () {
          final cover = {
            for (final r in coverRackRows(
              racks: doc.racks.values,
              devices: doc.devices.values,
              templates: doc.templates,
              landings: PortLandings.of(doc),
            ))
              r.rackId: r.activeDevices,
          };
          for (final group in list.groups.where((g) => !g.isUnplaced)) {
            expect(cover[group.rackId], group.rows.length, reason: group.title);
          }
        });

        test('the plan schedule can still join a passive (rowFor)', () {
          for (final id in [for (final m in list.materials) ...m.deviceIds]) {
            expect(list.rowFor(id)?.deviceId, id);
          }
        });
      });
    }
  });

  group('the materials rows (§11.212.2)', () {
    TemplateSnapshot snap(String id, String name) => TemplateSnapshot(
      templateId: TemplateId(id),
      version: 1,
      contentHash: 'h',
      body: TemplateBody(
        manufacturer: 'Generic',
        model: id,
        displayName: name,
        frontU: 1,
        category: kCatPassive,
        weight: Mass.fromKilograms(1),
        power: PowerProfile(apparentVA: 0, typicalWatts: 0),
      ),
      capturedAt: DateTime.utc(2026, 10),
    );

    DeviceInstance device(
      String id,
      String template,
      String rack, {
      LifecycleStatus status = LifecycleStatus.new_,
    }) => DeviceInstance(
      id: Uuid(id),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(template),
        version: 1,
        contentHash: 'h',
      ),
      designator: id.toUpperCase(),
      name: id,
      placement: RailPlacement(
        rackId: Uuid(rack),
        ruIndex: 1,
        face: Face.front,
      ),
      meta: testMeta(),
      lifecycleStatus: status,
    );

    test(
      'ONE ROW PER ITEM AND STATUS, with the split by rack in rack order',
      () {
        final doc = RackDocument(
          id: const Uuid('doc-materials'),
          appVersion: 'test',
          createdAt: DateTime.utc(2026, 10),
          modifiedAt: DateTime.utc(2026, 10),
          meta: testMeta(),
        );
        for (final r in [
          testRack(id: 'r1'),
          testRack(id: 'r2', designator: 'RK-2', order: 'b0'),
        ]) {
          doc.racks[r.id] = r;
        }
        doc.templates['VNT@1'] = snap('VNT', 'Vent Panel, 1U');
        doc.templates['BLK@1'] = snap('BLK', 'Blank Panel, 1U');
        for (final d in [
          device('v1', 'VNT', 'r2'),
          device('v2', 'VNT', 'r1'),
          device('v3', 'VNT', 'r1'),
          device('v4', 'VNT', 'r1', status: LifecycleStatus.existing),
          device('b1', 'BLK', 'r1'),
        ]) {
          doc.devices[d.id] = d;
        }
        final rows = [
          for (final m in buildEquipmentList(doc).materials)
            (m.item, m.qty, lifecycleLabel(m.lifecycleStatus), m.whereText),
        ];
        expect(rows, <(String, int, String, String)>[
          ('Blank Panel, 1U', 1, 'NEW', 'RK-1 × 1'),
          ('Vent Panel, 1U', 3, 'NEW', 'RK-1 × 2, RK-2 × 1'),
          ('Vent Panel, 1U', 1, 'EXISTING', 'RK-1 × 1'),
        ]);
      },
    );
  });

  group('on the sheet', () {
    final doc = _starter('whole_house');
    final list = buildEquipmentList(doc);
    final pages = paginateEquipmentList(
      list: list,
      drawingArea: sheetLayoutFor(
        SheetSet.forRacks(doc.racks.values).sheets.firstWhere(
          (s) => s.role == SheetRole.equipmentList,
        ),
        const <RevisionEntry>[],
      ).drawingArea,
      measurer: FakeMeasurer(),
    );
    final items = [for (final p in pages) ...p.items];

    test('THE SUBTOTAL SAYS IT COUNTS THE PASSIVES', () {
      final subtotal = items.whereType<ScheduleSubtotal>().first.text;
      final group = list.groups.first;
      expect(
        subtotal,
        contains(
          '${group.rows.length} DEVICES + ${group.passiveCount} PASSIVES '
          '(SEE MATERIALS)',
        ),
      );
    });

    test('A MATERIALS BAND FOLLOWS THE LAST RACK, one line per item', () {
      final bands = items.whereType<ScheduleBand>().map((b) => b.title);
      expect(bands.last, kMaterialsBandTitle);
      final materialRows = items
          .whereType<ScheduleRow>()
          .where((r) => r.span != null)
          .toList();
      expect(materialRows, hasLength(list.materials.length));
      expect(
        materialRows.map((r) => r.span),
        [for (final m in list.materials) m.whereText],
      );
    });
  });
}
