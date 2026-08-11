// CR-117: write(read(bytes)) == bytes, as an exact BYTE property, over
// four fixtures of increasing complexity. Also persists each fixture's
// first-write bytes to test/fixtures/*.rmpj.json as real files on
// disk — a later milestone's golden-fixture-corpus work builds on these.
//
// Fixture (d) is newer than the others and was added for a reason worth
// stating: (a)-(c) contain no `TemplateSnapshot` at all, so the corpus had
// nothing to say about `_encodePowerProfile` — and that is precisely where
// the container format last moved (schemaVersion 1 -> 2). A golden corpus
// that cannot see the encoder a change touched is not guarding it.
import 'dart:convert';
import 'dart:io';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

EntityMeta _meta({
  DateTime? createdAt,
  DateTime? updatedAt,
  String updatedBy = 'rriley',
  int localRevision = 0,
}) => EntityMeta(
  createdAt: createdAt ?? DateTime.utc(2026, 7, 18, 9),
  updatedAt: updatedAt ?? createdAt ?? DateTime.utc(2026, 7, 18, 9),
  updatedBy: updatedBy,
  localRevision: localRevision,
);

/// (a) An empty new project: just ProjectInfo/ProjectSettings/Registries
/// defaults, no racks.
RackDocument _emptyProjectFixture() => RackDocument(
  id: const Uuid('0190e3c1-0000-7000-8000-000000000000'),
  appVersion: '0.1.0+build.1',
  createdAt: DateTime.utc(2026, 7, 18, 9),
  modifiedAt: DateTime.utc(2026, 7, 18, 9),
  meta: _meta(),
  info: ProjectInfo(projectName: 'Ashford Residence'),
);

/// (b) A project with one Rack and one DeviceInstance placed in it.
RackDocument _rackAndDeviceFixture() {
  final meta = _meta(
    createdAt: DateTime.utc(2026, 7, 18, 9, 16),
    updatedAt: DateTime.utc(2026, 7, 18, 9, 31, 44),
    localRevision: 3,
  );

  final rack = Rack(
    id: const Uuid('0190e3c1-9c50-7d33-9e24-5b3f6da1c423'),
    name: 'AV Rack',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: meta,
    overallDepth: const Len(482600000),
    weightCapacity: const Mass(45359237000),
    zeroUChannels: [
      ZeroUChannel(
        id: 'ch-rear-l',
        side: ZeroUChannelSide.rearLeft,
        startU: 1,
        endU: 12,
      ),
    ],
  );

  const deviceId = Uuid('0190e3c1-ad60-7e44-8f35-6c407eb2d534');
  final device = DeviceInstance(
    id: deviceId,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.generic.hdmi_matrix_4x4'),
      version: 2,
      contentHash:
          'sha256:1f4c8b2e9a0d4471bc35e6f708a19d2c'
          '5b4e37f10a9c8d6e2b1f0a3c7d5e9b04',
    ),
    designator: 'MTX-1',
    name: 'HDMI Matrix',
    placement: RailPlacement(rackId: rack.id, ruIndex: 9, face: Face.front),
    meta: meta,
  );

  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-000000000001'),
    appVersion: '0.1.0+build.1',
    createdAt: DateTime.utc(2026, 7, 18, 9, 14, 2),
    modifiedAt: DateTime.utc(2026, 7, 18, 16, 42, 55),
    meta: meta,
  )..racks[rack.id] = rack;
  doc.devices[device.id] = device;
  return doc;
}

/// (c) A fuller project: a Link with Services and Conductors, a
/// StructureBody with an Outlet, a Sheet, an AckedFinding, and a Port
/// carrying a non-empty `unknown` passthrough map (forward-compat).
RackDocument _fullerProjectFixture() {
  final meta = _meta(
    createdAt: DateTime.utc(2026, 7, 18, 9, 30),
    updatedAt: DateTime.utc(2026, 7, 18, 16, 41, 55),
    localRevision: 4,
  );

  const rackId = Uuid('0190e3c1-9c50-7d33-9e24-5b3f6da1c423');
  final rack = Rack(
    id: rackId,
    name: 'AV Rack',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: meta,
  );

  const matrixDeviceId = Uuid('0190e3c1-ad60-7e44-8f35-6c407eb2d534');
  final matrixDevice = DeviceInstance(
    id: matrixDeviceId,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.generic.hdmi_matrix_4x4'),
      version: 2,
      contentHash:
          'sha256:1f4c8b2e9a0d4471bc35e6f708a19d2c'
          '5b4e37f10a9c8d6e2b1f0a3c7d5e9b04',
    ),
    designator: 'MTX-1',
    name: 'HDMI Matrix',
    placement: const RailPlacement(
      rackId: rackId,
      ruIndex: 9,
      face: Face.front,
    ),
    meta: meta,
  );

  const structureBodyId = Uuid('0190e3c1-be70-7288-8379-a084bcf61978');
  const structureDeviceId = Uuid('0190e3c1-ad63-7177-9268-9f73abe50867');
  final structureDevice = DeviceInstance(
    id: structureDeviceId,
    kind: DeviceKind.structure,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.system.structure'),
      version: 1,
      contentHash:
          'sha256:0d5e91af73c2b846e10f7d3a95c6b280'
          'e4f1a7d93b05c8e26af14d7302b9c651',
    ),
    designator: 'STR-1',
    name: 'Rough-In - First Floor',
    placement: const OffRackPlacement(
      mountNote: 'Structured media enclosure, hallway',
    ),
    structureBodyId: structureBodyId,
    meta: meta,
  );

  final structureBody = StructureBody(
    id: structureBodyId,
    deviceId: structureDeviceId,
    title: 'Rough-In - First Floor',
    meta: meta,
    enclosureModel: 'Generic 42 in structured media enclosure',
  );

  const outletId = Uuid('0190e3c1-be71-7399-948a-b195cd072a89');
  final outlet = Outlet(
    id: outletId,
    structureBodyId: structureBodyId,
    designation: 'LR-TV-1',
    order: const FracIndex('a0'),
    meta: meta,
    wall: Wall.n,
    mountSurface: MountSurface.wall,
    mountHeightAff: const Len(1524000000),
    tia570Grade: 'TIA-570-D Grade 2',
  );

  final port = Port(
    id: derivePortId(matrixDeviceId, const PortKey('hdmi_out_1')),
    deviceId: matrixDeviceId,
    designator: 'J05',
    templatePortKey: const PortKey('hdmi_out_1'),
    // Non-empty `unknown` passthrough map (deliberately NOT alphabetised
    // here — proves the codec's own key-sort makes this deterministic
    // rather than depending on insertion order) — this is what proves a
    // v1.0 reader can open a v1.4 file without destroying newer data.
    unknown: const {
      'zPlannedFutureField': 42,
      'aNestedFutureBlob': {'z': 1, 'a': 2},
    },
  );

  const netId = Uuid('0190e3c1-d090-79ff-9af0-17fb3c6d80ef');
  final net = Net(
    id: netId,
    name: '',
    signalFamily: const SignalFamilyId('structure.undetermined'),
    meta: meta,
  );

  const linkId = Uuid('0190e3c1-cf80-75bb-96ac-d3b7ef294cab');
  final link = Link(
    id: linkId,
    designator: 'W001',
    media: const MediaTypeId('media.cat6a_futp'),
    order: const FracIndex('a0'),
    meta: meta,
    designatorLocked: true,
    gaugeAwg: 23,
    jacket: JacketRating.cmr,
    // A POPULATED value, not an absent one. The three colour-ish facts
    // this cable carries are all here at once and all different: `cmr`
    // is the NEC fire rating, `T568B` below is (mis)used as the pair
    // record inside the sheath, and `jc.blue` is the colour of the
    // jacket in the wall. A golden corpus that could not SEE a populated
    // `jacketColorId` would not be guarding the encoder at all — that is
    // the lesson fixture (d) already recorded.
    jacketColorId: const JacketColorId('jc.blue'),
    // AND THE EXCEPTION, populated. This run IS a control drop — its
    // keystone will be blue, and its schedule row means "control" — but
    // the crew ran out of blue and pulled yellow. Both facts on disk at
    // once is the state the whole feature exists for, and a golden
    // corpus that could not SEE a populated `jacketColorPulledId` would
    // not be guarding the encoder against dropping it. Same lesson
    // fixture (d) recorded about `_encodePowerProfile`.
    jacketColorPulledId: const JacketColorId('jc.yellow'),
    shielded: true,
    roughInStatus: RoughInStatus.pulled,
    cutLength: const Len(19812000000),
    routedLength: const Len(18288000000),
    services: [
      Service(
        id: 'svc-1',
        signalFamily: const SignalFamilyId('structure.undetermined'),
        netId: netId,
        conductorRoles: const [''],
      ),
    ],
    conductors: [
      Conductor(
        from: PortEndpoint(port.id),
        to: const PlaceEndpoint(
          description: 'LR TV wall plate, north wall, 60 in AFF',
          intendedTermination: TerminationType.keystone,
          serviceLoop: Len(914400000),
        ),
        colorCode: 'T568B',
      ),
    ],
    structureOrigin: StructureOrigin(
      structureBodyId: structureBodyId,
      outletId: outletId,
      fieldLabel: 'LR-TV-1A',
      terminationField: TerminationType.keystone,
      rackLabel: '1A-A12',
      wall: Wall.n,
      mountSurface: MountSurface.wall,
      mountHeightAff: const Len(1524000000),
    ),
  );

  const sheetItemId = Uuid('0190e3c1-e1a1-7e54-8f45-6c3081b2d534');
  final sheet = Sheet(
    id: const Uuid('0190e3c1-e1a0-7d43-9e34-5b2f70a1c423'),
    number: '2',
    title: 'SYSTEM SCHEMATIC',
    order: const FracIndex('a1'),
    meta: meta,
    lifecycleFilter: const {
      LifecycleStatus.existing,
      LifecycleStatus.new_,
      LifecycleStatus.designIntent,
    },
    items: {
      sheetItemId: SheetItem(
        id: sheetItemId,
        targetId: matrixDeviceId,
        position: const Pt(48, 20),
        zOrder: const FracIndex('a1'),
        pinned: true,
      ),
    },
  );

  final ackedFinding = AckedFinding(
    id: const Uuid('0190e3c1-f2b0-7f65-9056-7d4192c3e645'),
    ruleId: 'SIG-001',
    targetFingerprint: 'SIG-001:W002:6d2bef45/7e3cb056',
    reason: 'Existing condition; corrected in Phase 2 under change order CO-3.',
    by: 'rriley',
    at: DateTime.utc(2026, 7, 18, 15, 11, 3),
    demotedTo: Severity.advisory,
    meta: meta,
    targetEntityId: linkId,
  );

  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-000000000002'),
    appVersion: '0.1.0+build.42',
    createdAt: DateTime.utc(2026, 7, 18, 9, 14, 2, 113, 847),
    modifiedAt: DateTime.utc(2026, 7, 18, 16, 42, 55, 902, 310),
    meta: meta,
    sequence: 412,
    // THREE convention entries for the three states that are not
    // "absent": `jc.blue` is what the Link above IS (its convention),
    // `jc.yellow` is what was actually PULLED into it (the exception),
    // and `jc.white` is stocked but not pulled by anything in this
    // document. `jc.white` also carries an EMPTY meaning, which is a
    // value ("the user has not said") and must reach disk as `""`
    // rather than being omitted.
    //
    // Both facts index this ONE map, which is what makes
    // `BLU · CONTROL — PULLED YEL` printable from a single legend
    // rather than needing a second vocabulary for exceptions.
    settings: ProjectSettings(
      jacketColorConventions: {
        const JacketColorId('jc.blue'): const JacketColorDef(
          displayName: 'Blue',
          abbr: 'BLU',
          color: Rgb(0x1F, 0x5F, 0xA8),
          meaning: 'Control — touchscreen / IR balun / RS-232 balun',
        ),
        const JacketColorId('jc.yellow'): const JacketColorDef(
          displayName: 'Yellow',
          abbr: 'YEL',
          color: Rgb(0xEF, 0xC8, 0x1E),
          meaning: 'General data drops',
        ),
        const JacketColorId('jc.white'): const JacketColorDef(
          displayName: 'White',
          abbr: 'WHT',
          color: Rgb(0xF2, 0xF2, 0xEF),
        ),
      },
    ),
  );
  doc.racks[rackId] = rack;
  doc.devices[matrixDeviceId] = matrixDevice;
  doc.devices[structureDeviceId] = structureDevice;
  doc.structures[structureBodyId] = structureBody;
  doc.outlets[outletId] = outlet;
  doc.ports[port.id] = port;
  doc.nets[netId] = net;
  doc.links[linkId] = link;
  doc.sheets[sheet.id] = sheet;
  doc.ackedFindings[ackedFinding.id] = ackedFinding;
  return doc;
}

/// (d) A project whose `templates` carry real `PowerProfile`s — one that
/// authors its outlet counts, one that authors an explicit ZERO, and one
/// that authors nothing at all.
///
/// WHY THIS FIXTURE HAD TO EXIST. Fixtures (a)-(c) contain no
/// `TemplateSnapshot` whatsoever, so the golden corpus said nothing about
/// `_encodePowerProfile` — and `_encodePowerProfile` is precisely where the
/// container format last moved (v1 wrote `"outletsProvided": 0`
/// unconditionally; v2 omits the key when the count is unauthored). A
/// format change landed with the byte-level corpus structurally unable to
/// notice it. All three shapes are here so the corpus pins the distinction
/// the change is about: authored, authored-as-zero, and absent are three
/// different things on disk.
RackDocument _templatesAndPowerFixture() {
  final meta = _meta(
    createdAt: DateTime.utc(2026, 7, 18, 11),
    updatedAt: DateTime.utc(2026, 7, 18, 11, 5),
    localRevision: 1,
  );

  TemplateSnapshot snapshot(String id, TemplateBody body) => TemplateSnapshot(
    templateId: TemplateId(id),
    version: 1,
    contentHash: 'sha256:$id',
    body: body,
    capturedAt: DateTime.utc(2026, 7, 18, 11),
  );

  const rackId = Uuid('0190e3c1-9c50-7d33-9e24-5b3f6da1c424');
  final rack = Rack(
    id: rackId,
    name: 'Power Rack',
    designator: 'RK-2',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: meta,
  );

  const pduId = Uuid('0190e3c1-ad60-7e44-8f35-6c407eb2d535');
  final pdu = DeviceInstance(
    id: pduId,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.demo.pdu'),
      version: 1,
      contentHash: 'sha256:tpl.demo.pdu',
    ),
    designator: 'PDU-1',
    name: 'Rack PDU',
    placement: const RailPlacement(
      rackId: rackId,
      ruIndex: 1,
      face: Face.rear,
    ),
    meta: meta,
  );

  const blankId = Uuid('0190e3c1-ad60-7e44-8f35-6c407eb2d536');
  final blank = DeviceInstance(
    id: blankId,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.demo.blank'),
      version: 1,
      contentHash: 'sha256:tpl.demo.blank',
    ),
    designator: 'BLK-1',
    name: 'Blank Panel',
    placement: const RailPlacement(
      rackId: rackId,
      ruIndex: 4,
      face: Face.front,
    ),
    meta: meta,
  );

  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-000000000003'),
    appVersion: '0.1.0+build.1',
    createdAt: DateTime.utc(2026, 7, 18, 11),
    modifiedAt: DateTime.utc(2026, 7, 18, 11, 5),
    meta: meta,
  );
  doc.racks[rackId] = rack;
  doc.devices[pduId] = pdu;
  doc.devices[blankId] = blank;
  doc.templates['tpl.demo.pdu@1'] = snapshot(
    'tpl.demo.pdu',
    TemplateBody(
      manufacturer: 'Generic',
      model: 'PDU 16',
      displayName: 'Rack PDU, 16 outlet',
      frontU: 1,
      side: OccupancySide.rear,
      mountMethod: MountMethod.rackEars,
      power: PowerProfile(
        apparentVA: 120,
        outletsProvided: 16,
        outletsConsumed: 1,
        inletPlug: PlugType.c20,
      ),
    ),
  );
  // Authored AS ZERO — a measurement, and it must stay a key on disk.
  doc.templates['tpl.demo.amp@1'] = snapshot(
    'tpl.demo.amp',
    TemplateBody(
      manufacturer: 'Generic',
      model: 'AMP 16',
      displayName: '16-channel amplifier',
      frontU: 2,
      side: OccupancySide.front,
      mountMethod: MountMethod.rackEars,
      power: PowerProfile(
        apparentVA: 840,
        outletsProvided: 0,
        outletsConsumed: 1,
      ),
    ),
  );
  // Authored NOT AT ALL — both keys must be ABSENT on disk.
  doc.templates['tpl.demo.blank@1'] = snapshot(
    'tpl.demo.blank',
    TemplateBody(
      manufacturer: 'Generic',
      model: 'Blank 1U',
      displayName: 'Blank Panel, 1U',
      frontU: 1,
      side: OccupancySide.front,
      mountMethod: MountMethod.rackEars,
    ),
  );
  return doc;
}

/// Set `UPDATE_GOLDENS=1` to REGENERATE the corpus instead of asserting
/// against it. That is a deliberate, reviewed step of a format change —
/// never something a test run does on its own. Regenerating and then
/// committing the result is how a format change is proposed; the diff on
/// those four files IS the review.
final bool _updateGoldens = Platform.environment['UPDATE_GOLDENS'] == '1';

/// CR-117, asserted against the bytes ON DISK.
///
/// HISTORY, because this is the second spelling of this function and the
/// first one could not fail. From `b94bd60` (M0) until this change it
/// began by OVERWRITING `test/fixtures/$label.rmpj.json` with the
/// bytes it was about to check, and then compared those bytes to
/// themselves round-tripped. That proves
/// `write(read(write(doc))) == write(doc)` — internal self-consistency —
/// and says nothing whatever about the committed file. The golden was an
/// OUTPUT, not an input, so ANY self-consistent format change passed and
/// silently rewrote the corpus that was supposed to catch it. It did
/// exactly that when `jacketColorConventions` became an unconditional key:
/// every stored document's bytes moved, all four goldens were rewritten
/// mid-run, and the suite stayed green.
///
/// CR-117 is stated in docs/03-architecture.md §9.1 as
/// `write(read(bytes)) == bytes`, where `bytes` are bytes that already
/// exist. M0's exit criterion names it. So this now asserts TWO distinct
/// properties, and neither implies the other:
///
///   1. THE STORED-BYTES PROPERTY. Read the committed golden, write it
///      back, and require the result to be byte-identical. This is CR-117
///      literally, and it is what fails when the container format moves
///      under a document a user already has on disk.
///   2. THE GENERATOR PROPERTY. The in-memory fixture must encode to
///      exactly those committed bytes, so the corpus cannot drift away
///      from the code that claims to produce it.
///
/// Property 1 is the one that was missing for the whole of M0 and M1.
/// (f) DR-007's gang list, on the same argument fixture (d) was added
/// under: (a)-(e) contain no `gangs` key at all, so the corpus had
/// nothing to say about `_encodeGang`.
///
/// **THAT (a)-(e) STAY BYTE-IDENTICAL IS HALF THE PROOF** and is why this
/// is a new fixture rather than gangs bolted onto (c). An empty gang list
/// emits no key, so every document written before M3-H reads and rewrites
/// unchanged, and `kSchemaVersion` had no reason to move. Mutating (c)
/// would have proved the encoder while destroying that evidence.
///
/// Every distinguishable cell state appears exactly once: an occupied
/// cell, a conductor cell, a decided blank, an undecided cell, a strap
/// with no cells filled at all, and a gang with no strap chosen.
RackDocument _plateGangsFixture() {
  final meta = _meta(createdAt: DateTime.utc(2026, 8, 11, 10));

  const structureBodyId = Uuid('0190e3c1-1111-7000-8000-000000000001');
  const structureDeviceId = Uuid('0190e3c1-1111-7000-8000-000000000002');
  const outletId = Uuid('0190e3c1-1111-7000-8000-000000000003');
  const dataLinkId = Uuid('0190e3c1-1111-7000-8000-000000000004');
  const speakerLinkId = Uuid('0190e3c1-1111-7000-8000-000000000005');

  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-000000000005'),
    appVersion: '0.1.0+build.1',
    createdAt: DateTime.utc(2026, 8, 11, 10),
    modifiedAt: DateTime.utc(2026, 8, 11, 10, 30),
    meta: meta,
  );

  doc.devices[structureDeviceId] = DeviceInstance(
    id: structureDeviceId,
    kind: DeviceKind.structure,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.system.structure'),
      version: 1,
      contentHash: 'sha256:tpl.system.structure',
    ),
    designator: 'STR-1',
    name: 'Rough-In - First Floor',
    placement: const OffRackPlacement(mountNote: 'Hallway enclosure'),
    structureBodyId: structureBodyId,
    meta: meta,
  );
  doc.structures[structureBodyId] = StructureBody(
    id: structureBodyId,
    deviceId: structureDeviceId,
    title: 'Rough-In - First Floor',
    meta: meta,
  );

  doc.outlets[outletId] = Outlet(
    id: outletId,
    structureBodyId: structureBodyId,
    designation: 'WP-1',
    order: const FracIndex('a0'),
    meta: meta,
    gangs: [
      // Gang 0: a 2x3, holding one jack, two speaker posts in
      // NON-ADJACENT cells (DR-007 §11.7.2 as revised), one decided
      // blank, and two cells nobody has ruled on.
      Gang(
        strap: Strap(
          width: 2,
          height: 3,
          cells: {
            0: const LinkEndOccupant(dataLinkId),
            1: const ConductorOccupant(ConductorRef(speakerLinkId, 0)),
            4: const ConductorOccupant(ConductorRef(speakerLinkId, 1)),
            5: const BlankInsert(),
          },
        ),
      ),
      // Gang 1: a strap chosen and nothing decided about any cell. The
      // `cells` key is absent, not an empty list.
      Gang(strap: Strap(width: 1, height: 1)),
      // Gang 2: no strap chosen. Encodes as `{}` — absent key, never an
      // explicit null (G4/CR-114).
      Gang(),
    ],
  );

  doc.links[dataLinkId] = Link(
    id: dataLinkId,
    designator: 'W001',
    media: const MediaTypeId('media.cat6'),
    order: const FracIndex('a0'),
    meta: meta,
    structureOrigin: StructureOrigin(
      structureBodyId: structureBodyId,
      outletId: outletId,
      fieldLabel: 'LR-DATA-1',
      terminationField: TerminationType.keystone,
    ),
  );
  doc.links[speakerLinkId] = Link(
    id: speakerLinkId,
    designator: 'W002',
    media: const MediaTypeId('media.speaker.16-2'),
    order: const FracIndex('a1'),
    meta: meta,
    conductors: const [
      Conductor(from: OpenEndpoint('+'), to: OpenEndpoint('+'), role: '+'),
      Conductor(from: OpenEndpoint('-'), to: OpenEndpoint('-'), role: '-'),
    ],
    structureOrigin: StructureOrigin(
      structureBodyId: structureBodyId,
      outletId: outletId,
      fieldLabel: 'LR-SPK-1',
      // The value that did not exist before M3-H, on disk.
      terminationField: TerminationType.bindingPost,
    ),
  );

  return doc;
}

void _assertByteRoundTrip(String label, RackDocument fixture) {
  final file = File('test/fixtures/$label.rmpj.json');
  final fresh = _codec.write(fixture);

  if (_updateGoldens) {
    final directory = Directory('test/fixtures');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    file.writeAsBytesSync(fresh);
    markTestSkipped('UPDATE_GOLDENS=1 — regenerated $label, asserted nothing');
    return;
  }

  expect(
    file.existsSync(),
    isTrue,
    reason:
        'the golden test/fixtures/$label.rmpj.json is missing. It is a '
        'checked-in INPUT, not an output — regenerate deliberately with '
        'UPDATE_GOLDENS=1 and commit the diff.',
  );
  final stored = file.readAsBytesSync();

  // (1) CR-117 against the bytes on disk.
  final decoded = _codec.read(stored);
  expect(decoded, isA<Ok<RackDocument>>(), reason: 'read($label) failed');
  final reencoded = _codec.write((decoded as Ok<RackDocument>).value);
  expect(
    utf8.decode(reencoded),
    equals(utf8.decode(stored)),
    reason:
        'CR-117 broken for $label: write(read(bytes)) != bytes. A document '
        'already on disk does not survive a load-and-save unchanged.',
  );
  expect(reencoded, equals(stored));

  // (2) The generator still produces exactly the committed corpus.
  expect(
    utf8.decode(fresh),
    equals(utf8.decode(stored)),
    reason:
        'the $label fixture no longer encodes to its committed golden. If '
        'this is an intended format change, regenerate with '
        'UPDATE_GOLDENS=1 and review the diff — that diff is the change.',
  );
  expect(fresh, equals(stored));
}

void main() {
  group('CR-117 — byte round trip over fixtures of increasing complexity', () {
    test('(a) empty new project', () {
      _assertByteRoundTrip('a_empty_project', _emptyProjectFixture());
    });

    test('(b) one rack, one device placed in it', () {
      _assertByteRoundTrip('b_rack_and_device', _rackAndDeviceFixture());
    });

    test('(c) link+services+conductors, structure+outlet, sheet, '
        'ackedFinding, unknown passthrough', () {
      _assertByteRoundTrip('c_fuller_project', _fullerProjectFixture());
    });

    test('(d) templates carrying power profiles — authored, authored-zero '
        'and absent outlet counts', () {
      _assertByteRoundTrip(
        'd_templates_and_power',
        _templatesAndPowerFixture(),
      );
    });

    test('(f) DR-007 gangs — a filled strap, an untouched strap, and a '
        'gang with no strap chosen', () {
      _assertByteRoundTrip('f_plate_gangs', _plateGangsFixture());
    });
  });

  group("DR-007's gang list costs an existing file nothing", () {
    // THE POINT OF THE WHOLE GROUP: fixtures (a)-(d) are checked-in bytes
    // written before `gangs` existed, and they still round-trip exactly.
    // That is what makes `kSchemaVersion` staying at 2 true rather than
    // merely convenient, and it would be destroyed by adding gangs to any
    // of them. See `_plateGangsFixture`'s doc comment.
    test('an outlet with no gangs emits no key at all', () {
      final bytes = _codec.write(_fullerProjectFixture());
      expect(utf8.decode(bytes), isNot(contains('"gangs"')));
    });

    test(
      'a decoded pre-M3-H outlet has an empty gang list, not a null one',
      () {
        final stored = File(
          'test/fixtures/c_fuller_project.rmpj.json',
        ).readAsBytesSync();
        final doc = (_codec.read(stored) as Ok<RackDocument>).value;
        expect(doc.outlets.values.single.gangs, isEmpty);
      },
    );

    test('a gang with no strap survives as a gang, not as an absence', () {
      final bytes = _codec.write(_plateGangsFixture());
      final doc = (_codec.read(bytes) as Ok<RackDocument>).value;
      final gangs = doc.outlets.values.single.gangs;
      expect(gangs, hasLength(3));
      expect(gangs[2].strap, isNull);
      // The undecided cells came back undecided rather than as blanks.
      expect(gangs[0].strap!.undecidedCount, 2);
      expect(gangs[1].strap!.undecidedCount, 1);
    });

    test('a strap size no manufacturer makes is refused on read', () {
      final json = utf8.decode(_codec.write(_plateGangsFixture()));
      final bad = json.replaceFirst('"width": 2', '"width": 3');
      final result = _codec.read(utf8.encode(bad));
      expect(result, isA<Err<RackDocument>>());
    });
  });

  group('the Placement/Outlet passthrough (DR-019 §11.18.2(5))', () {
    // Fixtures (a)-(d) predate this key, which is exactly the argument
    // fixture (d) was added under: a corpus that cannot see the encoder a
    // change touched is not guarding it.
    //
    // These assert on BYTES rather than only on the round-trip property.
    // A codec that dropped the bag on decode and re-emitted nothing would
    // round-trip perfectly and still have lost the caller's data, which is
    // the whole failure DR-019 names.

    test('a placement bag survives the trip, and reaches the bytes', () {
      final doc = _rackAndDeviceFixture();
      final device = doc.devices.values.first;
      final rail = device.placement as RailPlacement;
      device.placement = RailPlacement(
        rackId: rail.rackId,
        ruIndex: rail.ruIndex,
        face: rail.face,
        unknown: const <String, Object?>{'planPin': 'kept', 'futureU': 7},
      );

      final bytes = const JsonDocumentCodec().write(doc);
      expect(utf8.decode(bytes), contains('"planPin": "kept"'));

      final back = const JsonDocumentCodec().read(bytes);
      final reread =
          (back as Ok<RackDocument>).value.devices.values.first.placement
              as RailPlacement;
      expect(reread.unknown['planPin'], 'kept');
      expect(reread.unknown['futureU'], 7);
      expect(const JsonDocumentCodec().write(back.value), bytes);
    });

    test('an EMPTY bag writes no key at all, so files that predate it still '
        'round-trip', () {
      // The rule that makes omission safe: nothing ever writes `{}`, so no
      // file this build produces can contain the empty bag that would fail
      // to survive the trip back. Adding the key unconditionally, as
      // `_encodePort` does, would have changed the bytes of all four
      // starters and every checked-in fixture.
      //
      // Asserted on the PLACEMENT NODE, not on the whole document: `Port`
      // and `EntityMeta` DO write `"unknown": {}` unconditionally, and a
      // document-wide string search finds theirs and proves nothing about
      // this key.
      final bytes = const JsonDocumentCodec().write(_rackAndDeviceFixture());
      final root = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      final document = root['document']! as Map<String, Object?>;
      final devices = document['devices']! as Map<String, Object?>;
      final device = devices.values.first! as Map<String, Object?>;
      final placement = device['placement']! as Map<String, Object?>;

      expect(placement['type'], 'rail');
      expect(placement.containsKey('unknown'), isFalse);
    });
  });

  group('PowerProfile on disk: absent is not zero (CR-114, CR-117)', () {
    // The three-way distinction fixture (d) exists for, asserted directly on
    // the bytes rather than only through the round-trip property — a codec
    // that wrote `0` for every unauthored count would round-trip perfectly
    // and still be the fabrication `derived/totals.dart` refuses.
    Map<String, Object?> powerOf(String templateKey) {
      final text = utf8.decode(_codec.write(_templatesAndPowerFixture()));
      final root = jsonDecode(text) as Map<String, Object?>;
      final document = root['document']! as Map<String, Object?>;
      final templates = document['templates']! as Map<String, Object?>;
      final snapshot = templates[templateKey]! as Map<String, Object?>;
      final body = snapshot['body']! as Map<String, Object?>;
      return body['power']! as Map<String, Object?>;
    }

    test('an authored count is written', () {
      final power = powerOf('tpl.demo.pdu@1');
      expect(power['outletsProvided'], 16);
      expect(power['outletsConsumed'], 1);
    });

    test('an authored ZERO is written as a zero, not omitted', () {
      final power = powerOf('tpl.demo.amp@1');
      expect(power.containsKey('outletsProvided'), isTrue);
      expect(power['outletsProvided'], 0);
    });

    test('an unauthored count has NO key at all', () {
      final power = powerOf('tpl.demo.blank@1');
      expect(power.containsKey('outletsProvided'), isFalse);
      expect(power.containsKey('outletsConsumed'), isFalse);
    });

    test('and THAT is why the file stamps a minReaderVersion a v1 build '
        'refuses', () {
      // The omission above is the breaking change. A v1 reader called
      // `asInt(json['outletsProvided'], ...)` and threw a FormatException on
      // it — a corrupt-file error for a file that is not corrupt. A v1
      // build's `migrateToCurrent` refuses outright when
      // `minReaderVersion > kSchemaVersion`, and ITS kSchemaVersion is 1, so
      // this is the number that turns that crash into a refusal.
      final text = utf8.decode(_codec.write(_templatesAndPowerFixture()));
      final root = jsonDecode(text) as Map<String, Object?>;
      expect(root['schemaVersion'], kSchemaVersion);
      expect(root['minReaderVersion'], kMinReaderVersion);
      expect(root['minReaderVersion']! as int, greaterThan(1));
    });
  });

  group('Canonical JSON shape', () {
    test('is pretty-printed with 2-space indent and sorted keys', () {
      final bytes = _codec.write(_emptyProjectFixture());
      final text = utf8.decode(bytes);

      expect(text, contains('\n  "appVersion"'));
      // "appVersion" must sort before "createdAt", which sorts before
      // "document", which sorts before "generator" — spot-checking a few
      // adjacent root keys is enough to prove the whole tree is sorted
      // (deepSortKeys is exercised uniformly, not per-key).
      final appVersionIndex = text.indexOf('"appVersion"');
      final createdAtIndex = text.indexOf('"createdAt"');
      final documentIndex = text.indexOf('"document"');
      final generatorIndex = text.indexOf('"generator"');
      expect(appVersionIndex, lessThan(createdAtIndex));
      expect(createdAtIndex, lessThan(documentIndex));
      expect(documentIndex, lessThan(generatorIndex));
    });

    test('never writes an explicit null for an absent nullable field', () {
      final bytes = _codec.write(_rackAndDeviceFixture());
      final text = utf8.decode(bytes);

      expect(text, isNot(contains(': null')));
    });

    test('integers never render in exponential notation', () {
      final bytes = _codec.write(_fullerProjectFixture());
      final text = utf8.decode(bytes);

      expect(text, isNot(contains('e+')));
      expect(text, isNot(contains('E+')));
    });
  });
}
