// Document builders the DRC fixture corpus is assembled from (M5-G1).
//
// ONE BUILDER SET FOR ALL 56 FIXTURES, so a near-miss differs from its
// known-bad in exactly the property under test and not in six incidental
// ways a reader has to diff by eye. AC-051's near-miss is only evidence
// if it is genuinely one property away.
//
// NOT `buildPlaceFromCatalogCommand`, for the reason `drc_test.dart`
// already gives at length: that path enforces the tier-1 placement rules
// and refuses an overlap, so a fixture built through it could not express
// the states tier 3 exists to report. DR-112 is the ruling: tier 1 gates
// the GESTURE, tier 3 reports the STATE, and a document can reach a state
// no gesture would have made.
import 'package:rackpal_core/rackpal_core.dart';

/// The one clock every fixture uses, so nothing depends on the wall.
final DateTime fixtureAt = DateTime.utc(2026, 9, 4, 12);

EntityMeta fixtureMeta() =>
    EntityMeta(createdAt: fixtureAt, updatedAt: fixtureAt, updatedBy: 'fx');

/// Ids are derived from a seed so a fixture can name one without a
/// counter shared between files.
Uuid fixtureId(int n) =>
    Uuid('0190e0dd-0f00-7000-8000-${n.toString().padLeft(12, '0')}');

/// The rack every fixture that needs one starts from: 12U, empty.
const Uuid kFixtureRackId = Uuid('0190e0dd-0f00-7000-8000-0000000000ff');

/// An empty project with one rack.
///
/// [weightCapacity] and [usableDepth] default to NULL, and null is
/// unknown to `RCK-003` and `RCK-012`: a rack whose capacity nobody
/// stated cannot be over it. Only the fixtures for those two rules state
/// them, which is how every other fixture stays silent on them.
RackDocument fixtureDoc({
  int heightU = 12,
  Mass? weightCapacity,
  Len? usableDepth,
}) {
  final d = RackDocument(
    id: fixtureId(0),
    appVersion: '0.5.50',
    createdAt: fixtureAt,
    modifiedAt: fixtureAt,
    meta: fixtureMeta(),
    info: ProjectInfo(projectName: 'DRC FIXTURE'),
    registries: buildSeedRegistries(),
  );
  d.racks[kFixtureRackId] = Rack(
    id: kFixtureRackId,
    name: 'HEAD END',
    designator: 'RK-1',
    heightU: heightU,
    order: const FracIndex('a0'),
    weightCapacity: weightCapacity,
    usableDepth: usableDepth,
    meta: fixtureMeta(),
  );
  return d;
}

/// Places [catalogId] at [ru], bypassing the placement planner.
///
/// [seq] must be unique within one document; it is the device's id.
DeviceInstance fixturePlace(
  RackDocument doc,
  String catalogId,
  int ru, {
  required int seq,
  Face face = Face.front,
  String? designator,
}) {
  final body = buildSeedCatalog()[catalogId]!;
  doc.templates[templateKey(catalogId, 1)] = TemplateSnapshot(
    templateId: TemplateId(catalogId),
    version: 1,
    contentHash: 'sha256:seed-$catalogId',
    body: body,
    capturedAt: fixtureAt,
  );
  final device = DeviceInstance(
    id: fixtureId(seq),
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(catalogId),
      version: 1,
      contentHash: 'sha256:seed-$catalogId',
    ),
    designator: designator ?? '$catalogId-$seq',
    name: body.displayName,
    placement: RailPlacement(rackId: kFixtureRackId, ruIndex: ru, face: face),
    meta: fixtureMeta(),
  );
  doc.devices[device.id] = device;
  return device;
}

/// A device's front occupancy, MEASURED from the catalog rather than
/// remembered. `drc_test.dart` learned this the hard way: its first draft
/// asserted V01 was 2U and it is 3U.
int fixtureHeightOf(String catalogId) => buildSeedCatalog()[catalogId]!.frontU;

/// A body carrying ONLY what the rule under test reads.
///
/// THIS IS WHAT MAKES `#300` ACHIEVABLE. A seed-catalog device states a
/// mass, an outlet draw and an unsupported-mass limit, so placing one to
/// test RU overlap also arms `PWR-003` and `RCK-013` and the fixture
/// stops being evidence about overlap. Every field here defaults to null,
/// and a null is UNKNOWN to these predicates, which is silence.
TemplateBody fixtureBody({
  int frontU = 1,
  int rearU = 0,
  Mass? weight,
  Mass? maxUnsupportedMass,
  Len? bodyDepth,
  PowerProfile? power,
  List<PortDef>? ports,
  String displayName = 'Fixture device',
}) => TemplateBody(
  manufacturer: 'FX',
  model: 'fx-$frontU',
  displayName: displayName,
  frontU: frontU,
  rearU: rearU,
  side: frontU > 0 && rearU > 0
      ? OccupancySide.both
      : (rearU > 0 ? OccupancySide.rear : OccupancySide.front),
  weight: weight,
  maxUnsupportedMass: maxUnsupportedMass,
  bodyDepth: bodyDepth,
  power: power,
  ports: ports ?? [],
);

/// Bare power ports for a body that has to provide or consume outlets,
/// which since DR-171 is the only way a body can (§11.170.2).
///
/// `power.ac_branch` on NEMA 5-15, `P04`'s own spelling, so a fixture port
/// is one the registry knows and no other rule has a reason to look at.
List<PortDef> fixturePowerPorts({int outlets = 0, int inlets = 0}) => [
  for (var i = 1; i <= inlets; i++)
    PortDef(
      key: PortKey('ac.in.$i'),
      label: 'AC IN $i',
      connector: const ConnectorTypeId('conn.nema_5_15p'),
      signalFamily: const SignalFamilyId('power.ac_branch'),
      face: Face.rear,
      order: FracIndex('a${i.toString().padLeft(3, '0')}'),
      power: PortPowerSpec(role: PortPowerRole.inlet),
    ),
  for (var i = 1; i <= outlets; i++)
    PortDef(
      key: PortKey('ac.out.$i'),
      label: 'OUT $i',
      connector: const ConnectorTypeId('conn.nema_5_15r'),
      signalFamily: const SignalFamilyId('power.ac_branch'),
      face: Face.rear,
      order: FracIndex('b${i.toString().padLeft(3, '0')}'),
      power: PortPowerSpec(role: PortPowerRole.outlet),
    ),
];

/// Places a device built from [body] at [ru], bypassing the planner.
DeviceInstance fixturePlaceBody(
  RackDocument doc,
  TemplateBody body,
  int ru, {
  required int seq,
  required String designator,
  Face face = Face.front,
}) {
  final id = 'fx-$seq';
  doc.templates[templateKey(id, 1)] = TemplateSnapshot(
    templateId: TemplateId(id),
    version: 1,
    contentHash: 'sha256:$id',
    body: body,
    capturedAt: fixtureAt,
  );
  final device = DeviceInstance(
    id: fixtureId(seq),
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(id),
      version: 1,
      contentHash: 'sha256:$id',
    ),
    designator: designator,
    name: body.displayName,
    placement: RailPlacement(rackId: kFixtureRackId, ruIndex: ru, face: face),
    meta: fixtureMeta(),
  );
  doc.devices[device.id] = device;
  return device;
}
