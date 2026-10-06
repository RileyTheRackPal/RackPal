// DR-237 (canon §11.236, `#1010`): speaker wire is bare wire.
//
// THE CASE THIS FILE EXISTS FOR is the real catalogue's: an A04's binding
// posts, and an A01's 2-pole Euroblock speaker outputs, into an F05 in-wall
// speaker's screw terminals. `CON-001` sprang back on both, on every speaker
// run in a house, because the binding post mated with banana plugs alone.
// The user's trade fact: bare wire is typical, and combination banana posts
// are mostly on floorstanding and bookshelf speakers.
//
// AND A REAL MISMATCH STILL FIRES, which is the half that keeps the rule
// worth having.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 10, 6);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

/// A document holding [devices] from the seed catalogue (or [bodies]), off
/// any rack, with their ports created.
RackDocument _doc(
  Map<String, String> devices, {
  Map<String, TemplateBody> bodies = const {},
}) {
  final doc = RackDocument(
    id: const Uuid('doc-bare-wire'),
    appVersion: 'test',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    registries: buildSeedRegistries(),
  );
  final catalog = buildSeedCatalog();
  devices.forEach((id, tpl) {
    final body = bodies[tpl] ?? catalog[tpl]!;
    doc.templates['$tpl@1'] = TemplateSnapshot(
      templateId: TemplateId(tpl),
      version: 1,
      contentHash: 'sha256:$tpl',
      body: body,
      capturedAt: _when,
    );
    doc.devices[Uuid(id)] = DeviceInstance(
      id: Uuid(id),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(tpl),
        version: 1,
        contentHash: 'sha256:$tpl',
      ),
      designator: id.toUpperCase(),
      name: id,
      placement: const OffRackPlacement(),
      meta: _meta(),
    );
  });
  return doc;
}

SpringBackVerdict _ask(
  RackDocument doc,
  String from,
  String fromKey,
  String to,
  String toKey,
) => evaluateSpringBack(
  doc,
  resolveConnectTarget(doc, deviceId: Uuid(from), portKey: fromKey)!,
  resolveConnectTarget(doc, deviceId: Uuid(to), portKey: toKey)!,
);

TemplateBody _rca() => TemplateBody(
  manufacturer: 'Test',
  model: 'odd',
  displayName: 'odd',
  frontU: 1,
  side: OccupancySide.front,
  ports: [
    PortDef(
      key: const PortKey('in'),
      label: 'IN',
      connector: const ConnectorTypeId('conn.rca'),
      signalFamily: const SignalFamilyId('audio.speaker_lowz'),
      face: Face.rear,
      order: const FracIndex('a0'),
      direction: PortDirection.sink,
    ),
  ],
);

bool _isConnectorChip(SpringBackVerdict v) =>
    v is SpringBackChip && v.rule == SpringBackRule.connectorsDoNotMate;

void main() {
  test("AN A04's BINDING POSTS INTO AN F05 IN-WALL: no CON-001", () {
    final doc = _doc({'amp': 'A04', 'spk': 'F05'});
    expect(
      _isConnectorChip(_ask(doc, 'amp', 'spk.L.pos', 'spk', 'spk.pos')),
      isFalse,
    );
  });

  test("AN A01's 2-POLE EUROBLOCK SPEAKER OUTPUT INTO AN F05: no CON-001", () {
    final doc = _doc({'amp': 'A01', 'spk': 'F05'});
    final zone = buildSeedCatalog()['A01']!.ports.firstWhere(
      (p) =>
          p.connector.v == 'conn.euroblock_2' &&
          p.signalFamily.v == 'audio.speaker_lowz',
    );
    expect(
      _isConnectorChip(_ask(doc, 'amp', zone.key.v, 'spk', 'spk.pos')),
      isFalse,
    );
  });

  test('A BINDING POST INTO A BOOKSHELF’S BINDING POST: no CON-001', () {
    // The case that fired even post to post: banana alone was listed.
    final bookshelf = TemplateBody(
      manufacturer: 'Test',
      model: 'bookshelf',
      displayName: 'bookshelf',
      frontU: 1,
      side: OccupancySide.front,
      ports: [
        PortDef(
          key: const PortKey('in.p'),
          label: '+',
          connector: const ConnectorTypeId('conn.binding_post'),
          signalFamily: const SignalFamilyId('audio.speaker_lowz'),
          face: Face.rear,
          order: const FracIndex('a0'),
          direction: PortDirection.sink,
        ),
      ],
    );
    final doc = _doc(
      {'amp': 'A04', 'spk': 'bookshelf'},
      bodies: {'bookshelf': bookshelf},
    );
    expect(
      _isConnectorChip(_ask(doc, 'amp', 'spk.L.pos', 'spk', 'in.p')),
      isFalse,
    );
  });

  test("FROM THE SPEAKER'S END TOO: an F05's terminal onto an A04's post", () {
    // §11.236.2: mating is symmetric, so the drag may start at either end.
    final doc = _doc({'amp': 'A04', 'spk': 'F05'});
    expect(
      _isConnectorChip(_ask(doc, 'spk', 'spk.pos', 'amp', 'spk.L.pos')),
      isFalse,
    );
  });

  test("AND A SCREW TERMINAL IS KNOWN NOW: an F05's terminal onto an RCA "
      'jack fires', () {
    final doc = _doc({'spk': 'F05', 'odd': 'odd'}, bodies: {'odd': _rca()});
    expect(
      _isConnectorChip(_ask(doc, 'spk', 'spk.pos', 'odd', 'in')),
      isTrue,
      reason: 'with an empty list the screw terminal was unknown and skipped',
    );
  });

  test('A REAL MISMATCH STILL FIRES: a binding post into an RCA jack', () {
    final rcaSpeaker = _rca();
    final doc = _doc({'amp': 'A04', 'odd': 'odd'}, bodies: {'odd': rcaSpeaker});
    expect(
      _isConnectorChip(_ask(doc, 'amp', 'spk.L.pos', 'odd', 'in')),
      isTrue,
    );
  });
}
