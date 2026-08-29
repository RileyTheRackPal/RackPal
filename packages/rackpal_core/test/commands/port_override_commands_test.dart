// M4-L4's core half: a port's facts get a producer and a resolver.
// `#233`, CR-053, DR-098 §11.97.6.
//
// =====================================================================
// THE RESOLVER IS THE POINT, NOT THE FIELD
// =====================================================================
// DR-098's census found `PortOverrides` had NO READER anywhere: three
// fields, codec-covered since M0, under CR-117's byte gate, consumed by
// nothing. §11.97.6 ruled that M4-L4 "owes a resolver before it owes a
// form", because writing into a field nothing reads is a save that
// changes nothing a person can see.
//
// So the load-bearing cases here are not "the override was written". They
// are that `ConnectTarget` — the join the connect gesture acts on and the
// thing tier-1 rules are evaluated against — ANSWERS WITH THE CORRECTION.
// A test that only inspected `port.overrides.connector` would pass just as
// happily with the resolver deleted.
//
// =====================================================================
// MATERIALISATION IS THE OTHER HALF
// =====================================================================
// Most ports do not exist. `Port` is written to `doc.ports` only when it
// carries project state, so on a document built by dropping devices out of
// the palette every pin is a `PortDef` and nothing else. Correcting one
// has to create it, on DR-011.1's precedent, and undoing has to take it
// away again: a port left behind holding no override is a row in the file
// that means nothing.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 8, 29);
final _later = DateTime.utc(2026, 8, 29, 1);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'seed');

const _deviceId = Uuid('d1');
const _portKey = PortKey('p1');
const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

TemplateBody _body() => TemplateBody(
  manufacturer: 'Test',
  model: 'sw',
  displayName: 'Switch',
  frontU: 1,
  side: OccupancySide.front,
  mountMethod: MountMethod.rackEars,
  ports: [
    PortDef(
      key: _portKey,
      label: 'PORT 1',
      connector: const ConnectorTypeId('conn.rj45'),
      signalFamily: const SignalFamilyId('net.ethernet'),
      face: Face.rear,
      position: _pos,
      order: const FracIndex('a0'),
    ),
  ],
);

RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('doc-port-facts'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.templates['sw@1'] = TemplateSnapshot(
    templateId: const TemplateId('sw'),
    version: 1,
    contentHash: 'unhashed:sw@1',
    body: _body(),
    capturedAt: _now,
  );
  doc.devices[_deviceId] = DeviceInstance(
    id: _deviceId,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('sw'),
      version: 1,
      contentHash: 'unhashed:sw@1',
    ),
    designator: 'SW-1',
    name: 'SW-1',
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
  return doc;
}

SetPortFactCommand _set(PortFactField field, Object? value) =>
    SetPortFactCommand(
      deviceId: _deviceId,
      portKey: _portKey,
      field: field,
      value: value,
      designatorIfMaterialised: 'J01',
      now: _later,
      actor: 'test',
    );

/// The join the connect gesture acts on, which is what has to answer.
ConnectTarget _target(RackDocument doc) =>
    resolveConnectTarget(doc, deviceId: _deviceId, portKey: _portKey.v)!;

void main() {
  group('the CONNECT TARGET answers with the correction, not the template', () {
    test('a corrected connector reaches the pin the gesture acts on', () {
      final doc = _doc();
      expect(_target(doc).connector, const ConnectorTypeId('conn.rj45'));

      _set(PortFactField.connector, const ConnectorTypeId('conn.xlr3')).apply(
        doc,
      );

      expect(
        _target(doc).connector,
        const ConnectorTypeId('conn.xlr3'),
        reason:
            'the resolver is what makes the override mean anything; '
            'inspecting port.overrides directly would pass without it',
      );
    });

    test('a corrected signal family likewise', () {
      final doc = _doc();
      expect(_target(doc).signalFamily, const SignalFamilyId('net.ethernet'));

      _set(
        PortFactField.signalFamily,
        const SignalFamilyId('audio.analog'),
      ).apply(doc);

      expect(_target(doc).signalFamily, const SignalFamilyId('audio.analog'));
    });

    test("the user's label outranks the template's silkscreen", () {
      // ASSERTED ON THE RESOLVER, NOT ON `portDesignator`, and the first
      // draft of this case got that wrong. It expected `PORT 1` from an
      // unmaterialised port on the theory that "no port means no
      // designator"; the answer was `J01`, because step 2 of
      // `portDesignator`'s documented order is the PLANNED designator, the
      // one the allocator will give this pin the instant it materialises.
      // That step is almost always available, so the label branch below it
      // is a deep fallback and `portDesignator` is the wrong window onto
      // this rule.
      final doc = _doc();
      final def = _body().ports.single;
      expect(resolvePortLabel(null, def), 'PORT 1');

      _set(PortFactField.userLabel, 'UPLINK').apply(doc);

      final port = doc.ports[derivePortId(_deviceId, _portKey)]!;
      expect(resolvePortLabel(port, def), 'UPLINK');
    });

    test('clearing an override falls back to the template', () {
      final doc = _doc();
      _set(PortFactField.connector, const ConnectorTypeId('conn.xlr3')).apply(
        doc,
      );
      _set(PortFactField.connector, null).apply(doc);

      expect(_target(doc).connector, const ConnectorTypeId('conn.rj45'));
    });

    test('a blank template label still falls back to the key', () {
      // `PortDef.label` is a non-nullable String and an empty one means
      // "nothing is printed on this jack", which is a known absence.
      final def = PortDef(
        key: const PortKey('p9'),
        label: '   ',
        connector: const ConnectorTypeId('conn.rj45'),
        signalFamily: const SignalFamilyId('net.ethernet'),
        face: Face.rear,
        position: _pos,
        order: const FracIndex('a0'),
      );
      expect(resolvePortLabel(null, def), 'p9');
    });
  });

  group('materialisation, on DR-011.1s precedent', () {
    test('correcting a port that does not exist CREATES it', () {
      final doc = _doc();
      expect(doc.ports, isEmpty, reason: 'every pin starts unmaterialised');

      _set(PortFactField.connector, const ConnectorTypeId('conn.xlr3')).apply(
        doc,
      );

      final port = doc.ports[derivePortId(_deviceId, _portKey)];
      expect(port, isNotNull);
      expect(port!.designator, 'J01');
      expect(port.templatePortKey, _portKey);
    });

    test('UNDO REMOVES THE PORT IT CREATED, leaving no empty row', () {
      final doc = _doc();
      final cmd = _set(
        PortFactField.connector,
        const ConnectorTypeId('conn.xlr3'),
      )..apply(doc);

      cmd.revert(doc);

      expect(
        doc.ports,
        isEmpty,
        reason:
            'a port holding no override is a row in the file that means '
            'nothing, which lazy materialisation exists to keep out',
      );
    });

    test('a port that ALREADY existed survives an undo with its state', () {
      final doc = _doc();
      // Materialise it with a label first.
      _set(PortFactField.userLabel, 'UPLINK').apply(doc);

      final second = _set(
        PortFactField.connector,
        const ConnectorTypeId('conn.xlr3'),
      )..apply(doc);
      second.revert(doc);

      final port = doc.ports[derivePortId(_deviceId, _portKey)];
      expect(port, isNotNull, reason: 'the second undo must not delete it');
      expect(port!.userLabel, 'UPLINK');
      expect(port.overrides.connector, isNull);
    });

    test('the port id is derived, so a replay lands on the same port', () {
      // CR-116/AC-006: `derivePortId` is a pure UUIDv5, which is what makes
      // materialising inside `apply` safe.
      final a = _doc();
      final b = _doc();
      _set(PortFactField.userLabel, 'X').apply(a);
      _set(PortFactField.userLabel, 'X').apply(b);

      expect(a.ports.keys.single, b.ports.keys.single);
    });
  });

  group('the command behaves like the others', () {
    test('per port, per field, so two corrections are two undo entries', () {
      final label = _set(PortFactField.userLabel, 'X');
      final conn = _set(
        PortFactField.connector,
        const ConnectorTypeId('conn.xlr3'),
      );
      expect(label.mergeKey, isNot(conn.mergeKey));
    });

    test('a connector or family edit invalidates WIRES, not just meta', () {
      // The schematic's rules read what a pin is; a correction nothing
      // repaints is a correction the canvas keeps contradicting.
      expect(
        _set(PortFactField.connector, null).touches.bits & EpochMask.wires.bits,
        isNot(0),
      );
      expect(
        _set(PortFactField.userLabel, null).touches.bits & EpochMask.wires.bits,
        0,
        reason: 'a label moves no wire',
      );
    });
  });

  test('the corrected port round-trips byte-exactly (CR-117)', () {
    final doc = _doc();
    _set(PortFactField.connector, const ConnectorTypeId('conn.xlr3')).apply(
      doc,
    );
    _set(PortFactField.userLabel, 'UPLINK').apply(doc);

    final bytes = const JsonDocumentCodec().write(doc);
    final back = const JsonDocumentCodec().read(bytes);
    expect(back, isA<Ok<RackDocument>>());
    expect(
      const JsonDocumentCodec().write((back as Ok<RackDocument>).value),
      bytes,
    );
    final port = back.value.ports.values.single;
    expect(port.overrides.connector, const ConnectorTypeId('conn.xlr3'));
    expect(port.userLabel, 'UPLINK');
  });
}
