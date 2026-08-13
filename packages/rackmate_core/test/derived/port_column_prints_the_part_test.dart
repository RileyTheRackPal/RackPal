// DR-054 (canon §11.53), board #667 — the `PORT` column prints the number
// silkscreened on the part, so it and `RACK LBL` describe one hole one way.
//
// THE DEFECT. `RACK LBL` has rendered `PortDef.label` since DR-040
// §11.39.8. `PORT` rendered `Port.designator`, and `portDesignatorFormat`
// is `J{PORT_SEQ:2}` where `PORT_SEQ` counts the FRONT jacks a drop never
// touches, so on a three-up/three-down fixture the hole labelled `01`
// designates `J04`. One sheet, two numbers, one position, and a tech on a
// ladder had to know which was which.
//
// THE COMPOUND CLAIM IS WHAT IS ASSERTED, NOT EITHER COLUMN ALONE. A case
// pinning `PORT == '01'` and a case pinning `RACK LBL` endsWith `01` are
// two mechanisms; the claim is that the two columns AGREE, and only a case
// that reads both off one row can see it. See the house rule on asserting
// the artifact: three good tests over three fixtures demonstrate three
// mechanisms and not one claim.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final DateTime _now = DateTime.utc(2026, 8, 13);

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

/// A panel that silkscreens `01..N` on BOTH faces, with the front ports
/// declared first so `PORT_SEQ` and the label cannot coincide: a drop
/// lands on the REAR (DR-040 clause 4), whose first hole is labelled `01`
/// and sequenced fourth on a three-position panel.
Uuid _panel(RackDocument doc, {int positions = 3}) {
  const tplId = 'tpl.pp';
  doc.templates['$tplId@1'] = TemplateSnapshot(
    templateId: const TemplateId(tplId),
    version: 1,
    contentHash: 'sha256:$tplId',
    body: TemplateBody(
      manufacturer: 'Generic',
      model: 'PP',
      displayName: 'Patch Panel',
      typePrefix: 'PP',
      ports: [
        for (var i = 1; i <= positions; i++)
          PortDef(
            key: PortKey('front.$i'),
            label: i.toString().padLeft(2, '0'),
            connector: const ConnectorTypeId('conn.rj45'),
            signalFamily: const SignalFamilyId('net.ethernet'),
            face: Face.front,
            position: _pos,
            order: FracIndex('a$i'),
          ),
        for (var i = 1; i <= positions; i++)
          PortDef(
            key: PortKey('rear.$i'),
            label: i.toString().padLeft(2, '0'),
            connector: const ConnectorTypeId('conn.punchdown_110'),
            signalFamily: const SignalFamilyId('net.ethernet'),
            face: Face.rear,
            position: _pos,
            order: FracIndex('b$i'),
          ),
      ],
    ),
    capturedAt: _now,
  );

  final room = AddLocationCommand(
    name: 'Media Closet',
    code: 'MC',
    order: nextLocationOrder(doc),
    floorNumber: 1,
    spaceCode: 'A',
    now: _now,
    actor: 'test',
  )..apply(doc);

  const id = Uuid('dev-PP-1');
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId(tplId),
      version: 1,
      contentHash: 'sha256:$tplId',
    ),
    designator: 'PP-1',
    name: 'Patch Panel',
    placement: const OffRackPlacement(),
    locationId: room.id,
    meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
  );
  return id;
}

RackDocument _landedProject({int drops = 3}) {
  final doc = RackDocument(
    id: const Uuid('doc-port'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
  )..registries = buildSeedRegistries();
  AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 'test',
  ).apply(doc);
  _panel(doc);
  AddLocationCommand(
    name: 'Living Room',
    code: 'LR',
    order: nextLocationOrder(doc),
    now: _now,
    actor: 'test',
  ).apply(doc);

  final parsed = parseDropLine('Living Room: ${drops}x Cat6 @panel=PP-1');
  final plan = planDropLine(
    doc: doc,
    line: parsed as DropLineParsed,
    now: _now,
    actor: 'test',
  );
  expect(plan, isA<DropLinePlanReady>(), reason: '$plan');
  for (final c in (plan as DropLinePlanReady).commands) {
    c.apply(doc);
  }
  return doc;
}

/// The rows for drops that actually landed on the panel.
List<ScheduleEntry> _landedRows(RackDocument doc) => buildSchedule(
  doc,
).rows.where((r) => r.farEnd.deviceDesignator == 'PP-1').toList();

void main() {
  group('the PORT column prints the number on the part', () {
    test('PORT and RACK LBL name the same hole', () {
      // THE COMPOUND CLAIM. Before DR-054 the rack label ended `01` while
      // PORT read `J04`, and each was individually defensible.
      final doc = _landedProject();
      final rows = _landedRows(doc);
      expect(rows, isNotEmpty, reason: 'nothing landed; fixture is wrong');

      for (final row in rows) {
        final port = row.farEnd.portCell;
        final label = row.rackLabel;
        expect(label, isNotNull, reason: 'DR-040 allocates one per landing');
        expect(
          label!.endsWith(port),
          isTrue,
          reason:
              'RACK LBL "$label" and PORT "$port" describe one hole; '
              'DR-054 §11.53.3',
        );
      }
    });

    test('PORT reads the silkscreen and not the allocated designator', () {
      final doc = _landedProject();
      final rows = _landedRows(doc);
      final shown = rows.map((r) => r.farEnd.portCell).toList();

      // `01`, `02`, `03` on the rear, NOT `J04`, `J05`, `J06`.
      expect(shown, ['01', '02', '03']);
      expect(
        shown.any((s) => s.startsWith('J')),
        isFalse,
        reason: 'J04 appears nowhere on the physical part',
      );
    });

    test('the allocated designator is UNCHANGED and still identifies', () {
      // DR-054 §11.53.4 deliberately did NOT touch allocation, because
      // Port.designator is stored and changing it would leave one document
      // holding two conventions.
      final doc = _landedProject();
      final designators = _landedRows(
        doc,
      ).map((r) => r.farEnd.portDesignator).toList();
      expect(
        designators.every((d) => d != null && d.startsWith('J')),
        isTrue,
        reason: 'identity is untouched; only the rendering moved',
      );
    });

    test('a port whose template silkscreens nothing still prints J-form', () {
      // The uniformity clause: panelPositionToken already falls back, so
      // an ordinary device port renders exactly as it did before.
      final doc = _landedProject();
      final row = _landedRows(doc).first;
      final port = doc.ports[row.farEnd.portId!]!;
      final body = doc.templates.values.first.body;
      final def = body.ports.firstWhere(
        (p) => p.key.v == port.templatePortKey!.v,
      );
      expect(
        panelPositionToken(def, port.designator),
        def.label,
        reason: 'labelled: the label wins',
      );
      expect(
        panelPositionToken(
          PortDef(
            key: const PortKey('k'),
            label: '',
            connector: const ConnectorTypeId('conn.rj45'),
            signalFamily: const SignalFamilyId('net.ethernet'),
            face: Face.rear,
            position: _pos,
            order: const FracIndex('a1'),
          ),
          'J09',
        ),
        'J09',
        reason: 'unlabelled: the designator is the fallback, unchanged',
      );
    });
  });
}
