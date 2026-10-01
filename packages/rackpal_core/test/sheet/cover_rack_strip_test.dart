// T0.00's rack summary strip (M6-A2 `#313`, DR-211).
//
// The derivations it reads are tested where they live (`totals.dart`,
// `rack_load_gutter.dart`). What is asserted here is what is NEW: which
// devices the count admits, the order, the cells as a reader sees them,
// the cap and the row that names what the cap left off, and that a real
// starter's power no longer counts steel panels as unknown.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

DeviceInstance _device(
  String id,
  String template, {
  String rack = 'rack-1',
  Placement? placement,
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
  placement:
      placement ??
      RailPlacement(rackId: Uuid(rack), ruIndex: 1, face: Face.front),
  meta: testMeta(),
);

TemplateSnapshot _snap(String id, TemplateBody body) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'h',
  body: body,
  capturedAt: DateTime.utc(2026, 10),
);

final Map<String, TemplateSnapshot> _templates = {
  'AMP@1': _snap(
    'AMP',
    TemplateBody(
      manufacturer: 'Demo',
      model: 'A',
      displayName: 'Amp',
      frontU: 2,
      weight: Mass.fromKilograms(10),
      power: PowerProfile(apparentVA: 300, typicalWatts: 150),
    ),
  ),
  'BLANK@1': _snap(
    'BLANK',
    TemplateBody(
      manufacturer: 'Demo',
      model: 'B',
      displayName: 'Blank',
      frontU: 1,
      category: kCatPassive,
    ),
  ),
};

List<CoverRackRow> _rows(List<Rack> racks, List<DeviceInstance> devices) =>
    coverRackRows(
      racks: racks,
      devices: devices,
      templates: _templates,
      landings: PortLandings.none,
    );

void main() {
  group('which devices the count admits (§11.210.3)', () {
    test('A PASSIVE IS LEFT OUT; an active device and an unresolved one are '
        'counted', () {
      final row = _rows(
        [testRack()],
        [
          _device('amp', 'AMP'),
          _device('blank', 'BLANK'),
          // No template at all: nothing says it is passive, so it counts.
          _device('mystery', 'NOPE'),
        ],
      ).single;
      expect(row.activeDevices, 2);
    });

    test('a staged device and another rack’s device are not this '
        'rack’s', () {
      final row = _rows(
        [testRack(), testRack(id: 'rack-2', designator: 'RK-2', order: 'b0')],
        [
          _device('amp', 'AMP'),
          _device('other', 'AMP', rack: 'rack-2'),
          _device('staged', 'AMP', placement: const StagedPlacement()),
        ],
      ).first;
      expect(row.activeDevices, 1);
    });
  });

  test('ROWS FOLLOW RACK ORDER, not argument order', () {
    final rows = _rows([
      testRack(id: 'z', designator: 'RK-Z', order: 'z0'),
      testRack(id: 'a', designator: 'RK-A'),
    ], const []);
    expect(rows.map((r) => r.designator), ['RK-A', 'RK-Z']);
  });

  test('the cells read as a reader sees them, units and all', () {
    final row = _rows([testRack()], [_device('amp', 'AMP')]).single;
    expect(coverRackCells(row, UnitSystem.metric), <String>[
      'RK-1  MASTER RACK',
      '42U',
      '1',
      'F 2 · R 0',
      formatMassRollup(row.mass, UnitSystem.metric),
      '300 VA',
      formatBtuRollup(row.btuPerHour),
    ]);
    expect(coverRackCells(row, UnitSystem.metric)[4], '10.0 kg');
  });

  group('a strip too long is capped and says so (§11.210.4)', () {
    final racks = [
      for (var i = 0; i < 30; i++)
        testRack(
          id: 'r$i',
          designator: 'RK-$i',
          order: 'a${i.toString().padLeft(2, '0')}',
        ),
    ];
    final sheets = SheetSet.forRacks(racks).sheets;

    test('THE RACKS THAT FIT PRINT, then one row naming the rest and the '
        'elevations that hold them', () {
      final rows = _rows(racks, const []);
      final strip = drawCoverRackStrip(
        rows: rows,
        sheets: sheets,
        units: UnitSystem.imperial,
        left: 0,
        width: 700,
        // Room for the heading, the column heads and ten lines.
        ceiling: 0,
        bottom: 2 * kCoverStripRow + 4 + 10 * kCoverStripRow,
        measurer: FakeMeasurer(),
      );
      expect((strip.shown, strip.hidden), (9, 21));
      final texts = textsOf(strip.ops);
      expect(texts, contains('RK-8  MASTER RACK'));
      expect(texts, isNot(contains('RK-9  MASTER RACK')));
      // The resolved set gives RK-9's front elevation T2.19 and RK-29's
      // rear T2.60, so the row names exactly that span.
      final hiddenSheets = sheets
          .where(
            (s) => s.rackDesignator == 'RK-9' || s.rackDesignator == 'RK-29',
          )
          .map((s) => s.ncsId)
          .toList();
      expect(
        texts.last,
        '+ 21 more racks: see ${hiddenSheets.first}–${hiddenSheets.last}',
      );
    });

    test('every rack that fits gets a row and no closing row', () {
      final strip = drawCoverRackStrip(
        rows: _rows(racks.take(3).toList(), const []),
        sheets: sheets,
        units: UnitSystem.imperial,
        left: 0,
        width: 700,
        ceiling: 0,
        bottom: 400,
        measurer: FakeMeasurer(),
      );
      expect((strip.shown, strip.hidden), (3, 0));
      expect(textsOf(strip.ops).any((t) => t.startsWith('+ ')), isFalse);
    });
  });

  test('ON THE COVER: the strip sits at the foot of the left block, under '
      'its headings', () {
    final cover = buildCoverSheet(
      sheet: SheetSet.forRacks([testRack()]).sheets.first,
      info: fullProjectInfo(),
      settings: ProjectSettings(),
      revisions: const <RevisionEntry>[],
      fileName: 'cover.rppj',
      issuedAt: DateTime.utc(2026, 10),
      measurer: FakeMeasurer(),
      racks: [testRack()],
      devices: [_device('amp', 'AMP')],
      templates: _templates,
      landings: PortLandings.none,
      sheets: SheetSet.forRacks([testRack()]).sheets,
    );
    final ops = textOps(cover.scene.ops);
    final signOff = ops.singleWhere((o) => o.text == 'SIGN-OFF');
    final heading = ops.singleWhere((o) => o.text == 'RACKS');
    expect(heading.at.y, greaterThan(signOff.at.y), reason: 'below the block');
    expect(heading.at.x, lessThan(cover.indexColumn.left));
    // AT THE FOOT, beside the title block rather than above it: the first
    // render stopped at the furniture's top and left a third of the left
    // side empty below the strip.
    expect(heading.at.y, greaterThan(cover.indexColumn.bottom));
    expect(ops.map((o) => o.text), containsAll(kCoverStripHeaders));
    expect((cover.racksShown, cover.racksHidden), (1, 0));
  });

  test('THE CATALOG FIX, ON A REAL STARTER: no passive in Whole House is an '
      'unknown power contributor (§11.210.5)', () {
    final doc =
        (const JsonDocumentCodec().read(
                  File(
                    '../../apps/rackpal/assets/starters/whole_house.rppj',
                  ).readAsBytesSync(),
                )
                as Ok<RackDocument>)
            .value;
    final rack = doc.racks.values.single;
    final byId = {for (final d in doc.devices.values) d.id: d};
    final passives = [
      for (final d in doc.devices.values)
        if (belongsToRack(d, rack.id, byId) &&
            bodyFor(d, doc.templates)?.category == kCatPassive)
          d,
    ];
    expect(passives, isNotEmpty, reason: 'precondition: it has passives');
    final load = computeRackLoadProfile(
      rack: rack,
      devices: passives,
      templates: doc.templates,
    );
    expect(load.apparentVA.unknownCount, 0);
    expect(load.apparentVA.value, 0);
    expect(load.btuPerHour.unknownCount, 0);
  });
}
