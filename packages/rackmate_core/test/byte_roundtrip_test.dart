// CR-117: write(read(bytes)) == bytes, as an exact BYTE property, over
// three fixtures of increasing complexity. Also persists each fixture's
// first-write bytes to test/fixtures/*.rackmate.json as real files on
// disk — a later milestone's golden-fixture-corpus work builds on these.
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
          'sha256:1f4c8b2e9a0d4471bc35e6f708a19d2c5b4e37f10a9c8d6e2b1f0a3c7d5e9b04',
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
          'sha256:1f4c8b2e9a0d4471bc35e6f708a19d2c5b4e37f10a9c8d6e2b1f0a3c7d5e9b04',
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
          'sha256:0d5e91af73c2b846e10f7d3a95c6b280e4f1a7d93b05c8e26af14d7302b9c651',
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

void _assertByteRoundTrip(String label, RackDocument fixture) {
  final bytes1 = _codec.write(fixture);

  final directory = Directory('test/fixtures');
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  File('test/fixtures/$label.rackmate.json').writeAsBytesSync(bytes1);

  final decoded = _codec.read(bytes1);
  expect(decoded, isA<Ok<RackDocument>>(), reason: 'read($label) failed');
  final doc2 = (decoded as Ok<RackDocument>).value;

  final bytes2 = _codec.write(doc2);

  // A readable diff on failure (string compare) plus the literal CR-117
  // byte property (list compare) — both must hold.
  expect(
    utf8.decode(bytes2),
    equals(utf8.decode(bytes1)),
    reason: 'byte round trip failed for $label',
  );
  expect(bytes2, equals(bytes1));
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
