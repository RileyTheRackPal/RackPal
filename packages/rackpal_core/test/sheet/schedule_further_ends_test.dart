// DR-236 §11.235.3 (BRK-A/4, `#1007`): a cable that reaches several devices
// is one Pull Sheet row naming every far end, and a Termination Schedule
// line per pair of ends under its one cable number.
//
// THE CASE THIS FILE EXISTS FOR is `the footage is the cable's, once`. The
// obvious way to print a line per end is a schedule row per end, and the
// view sums its rows' lengths into the Pull Sheet's footage: a 16/4 printed
// as two rows is a crew buying two lengths of cable they pull once.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

final _when = DateTime.utc(2026, 10, 6);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _rack = Uuid('rack-a');
const _rackB = Uuid('rack-b');
const _amp = Uuid('amp');
const _spk1 = Uuid('spk-1');
const _spk2 = Uuid('spk-2');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

PortDef _pin(String key, String set, String role, PortDirection dir, int i) =>
    PortDef(
      key: PortKey(key),
      label: key.toUpperCase(),
      connector: const ConnectorTypeId('conn.screw_terminal'),
      signalFamily: const SignalFamilyId('audio.speaker_lowz'),
      face: Face.rear,
      position: _pos,
      order: FracIndex('a${i.toString().padLeft(2, '0')}'),
      direction: dir,
      setKey: set,
      setRole: role,
    );

void _place(
  RackDocument doc,
  Uuid id,
  List<String> sets,
  List<PortDef> ports, {
  required bool inRack,
  bool inRoom = false,
}) {
  final tpl = 'tpl.${id.v}';
  doc.templates['$tpl@1'] = TemplateSnapshot(
    templateId: TemplateId(tpl),
    version: 1,
    contentHash: 'sha256:$tpl',
    body: TemplateBody(
      manufacturer: 'Test',
      model: id.v,
      displayName: id.v,
      frontU: 1,
      side: OccupancySide.front,
      portSets: [
        for (final s in sets)
          PortSetDef(key: s, label: s, kind: SetKind.speakerPair),
      ],
      ports: ports,
    ),
    capturedAt: _when,
  );
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(tpl),
      version: 1,
      contentHash: 'sha256:$tpl',
    ),
    designator: id.v.toUpperCase(),
    name: id.v,
    placement: inRoom
        ? const OffRackPlacement()
        : RailPlacement(
            rackId: inRack ? _rack : _rackB,
            ruIndex: 1,
            face: Face.front,
          ),
    meta: _meta(),
  );
  for (final p in ports) {
    final pid = derivePortId(id, p.key);
    doc.ports[pid] = Port(
      id: pid,
      deviceId: id,
      designator: p.key.v.toUpperCase(),
      templatePortKey: p.key,
    );
  }
}

Endpoint _at(Uuid device, String key) =>
    PortEndpoint(derivePortId(device, PortKey(key)));

/// The amplifier in RK-1, two speakers in RK-2 (a speaker outside any rack
/// leaves the class undetermined, which is G4 and not this file's case),
/// and one cable: W012,
/// zone 1 to SPK-1 and, when [continued], zone 2 to SPK-2.
RackDocument _doc({bool continued = true, bool speakersInRoom = false}) {
  final doc = RackDocument(
    id: const Uuid('doc-further'),
    appVersion: 'test',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    registries: buildSeedRegistries(),
  );
  for (final (i, rack) in [_rack, _rackB].indexed) {
    doc.racks[rack] = Rack(
      id: rack,
      name: rack.v,
      designator: 'RK-${i + 1}',
      heightU: 24,
      order: FracIndex('a$i'),
      meta: _meta(),
    );
  }
  _place(
    doc,
    _amp,
    ['z1', 'z2'],
    [
      _pin('z1.p', 'z1', '+', PortDirection.source, 0),
      _pin('z1.n', 'z1', '-', PortDirection.source, 1),
      _pin('z2.p', 'z2', '+', PortDirection.source, 2),
      _pin('z2.n', 'z2', '-', PortDirection.source, 3),
    ],
    inRack: true,
  );
  for (final s in [_spk1, _spk2]) {
    _place(
      doc,
      s,
      ['in'],
      [
        _pin('in.p', 'in', '+', PortDirection.sink, 0),
        _pin('in.n', 'in', '-', PortDirection.sink, 1),
      ],
      inRack: false,
      inRoom: speakersInRoom,
    );
  }
  doc.links[const Uuid('w012')] = Link(
    id: const Uuid('w012'),
    designator: 'W012',
    media: const MediaTypeId('media.cat6_utp'),
    order: const FracIndex('a0'),
    meta: _meta(),
    cutLength: Len.fromMillimetres(15000),
    conductors: [
      Conductor(from: _at(_amp, 'z1.p'), to: _at(_spk1, 'in.p'), role: '+'),
      Conductor(from: _at(_amp, 'z1.n'), to: _at(_spk1, 'in.n'), role: '-'),
      if (continued) ...[
        Conductor(from: _at(_amp, 'z2.p'), to: _at(_spk2, 'in.p'), role: '+'),
        Conductor(from: _at(_amp, 'z2.n'), to: _at(_spk2, 'in.n'), role: '-'),
      ],
    ],
  );
  return doc;
}

List<ScheduleSheetRow> _sheetRows(RackDocument doc, SchedulePreset preset) {
  final pages = paginateSchedule(
    view: buildScheduleView(buildSchedule(doc), preset: preset),
    title: 'T',
    registries: doc.registries,
    drawingArea: SheetLayout.resolve(
      geometry: const SheetGeometry(SheetSize.ansiALandscape),
      revisionRowCount: 0,
    ).drawingArea,
    measurer: FakeMeasurer(),
    units: UnitSystem.metric,
  );
  return [
    for (final p in pages) ...p.items.whereType<ScheduleSheetRow>(),
  ];
}

void main() {
  test('THE CONTROL: an ordinary cable has no further ends and prints as it '
      'did', () {
    final row = buildSchedule(_doc(continued: false)).rows.single;
    expect(row.furtherPairs, isEmpty);
    expect(
      row.cell(ScheduleColumnId.fromRoomOutlet, units: UnitSystem.metric),
      isNot(contains(' + ')),
    );
  });

  test('THE 16/4 IS ONE ROW, naming both speakers on the side it does not '
      'share', () {
    final rows = buildSchedule(_doc()).rows;
    expect(rows, hasLength(1), reason: 'one cable, one pull (RJ-016)');
    // Rack to rack the amplifier is the row's FROM, which the second pair
    // shares, so SPK-2 joins the TO side, beside SPK-1's rack.
    final row = rows.single;
    expect(
      row.cell(ScheduleColumnId.toRackRuFace, units: UnitSystem.metric),
      endsWith(' + SPK-2'),
    );
    expect(
      row.cell(ScheduleColumnId.fromRoomOutlet, units: UnitSystem.metric),
      isNot(contains(' + ')),
    );
  });

  test("THE FOOTAGE IS THE CABLE'S, ONCE", () {
    final plain = buildScheduleView(
      buildSchedule(_doc(continued: false)),
      preset: SchedulePreset.terminationSchedule,
    );
    final continued = buildScheduleView(
      buildSchedule(_doc()),
      preset: SchedulePreset.terminationSchedule,
    );
    expect(continued.rowCount, 1);
    expect(continued.footage.value, plain.footage.value);
    expect(continued.footage.value, Len.fromMillimetres(15000));
  });

  test('THE TERMINATION SCHEDULE PRINTS A LINE PER PAIR under one cable '
      'number, the second naming SPK-2 and the amplifier pins it lands on', () {
    final rows = _sheetRows(_doc(), SchedulePreset.terminationSchedule);
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.designator), everyElement('W012'));
    expect(rows.first.continuation, isFalse);
    expect(rows.last.continuation, isTrue);
    final flat = rows.last.cells.expand((c) => c).join(' | ');
    expect(flat, contains('SPK-2'));
    expect(flat, contains('Z2.P'), reason: "the amplifier's zone 2 pin");
    expect(flat, isNot(contains('15')), reason: 'no length printed twice');
  });

  test('THE PULL SHEET HAS NO SECOND LINE: its one row names both', () {
    final rows = _sheetRows(_doc(), SchedulePreset.pullSheet);
    expect(rows, hasLength(1));
  });

  test('THE TAP-AND-CONTINUE PROPER, speakers in the room: SPK-2 joins SPK-1 '
      'in FROM, beside the end it is', () {
    // The amplifier is the row's TO (the rack end), which the second pair
    // shares, so the new end goes to FROM. Its class is undetermined (an
    // off-rack device has no rack, G4), which is a separate matter.
    final row = buildSchedule(_doc(speakersInRoom: true)).rows.single;
    expect(
      row.cell(ScheduleColumnId.fromRoomOutlet, units: UnitSystem.metric),
      contains('SPK-1 + SPK-2'),
    );
    expect(
      row.cell(ScheduleColumnId.toRackRuFace, units: UnitSystem.metric),
      isNot(contains(' + ')),
    );
  });
}
