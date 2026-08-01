// M2-F PHASE 5 — the arithmetic behind CR-105's elevation chip.
//
// CR-105: "a device with unconnected ports shows a port-count chip
// (`🔗 0/12`) in the elevation, and clicking it switches to the schematic
// with that device selected." The click is `rackmate_ui`'s; the two
// numbers are here, and the reason they are here rather than in the screen
// is that a signpost disagreeing with the schedule about how much is wired
// would be worse than no signpost at all.
//
// THE ONE CLAIM WORTH THE MOST TESTS is the denominator. DR-011.1
// materialises a `Port` only when a cable lands on it, so `doc.ports` is
// EMPTY on a freshly-placed device and reading the total from there would
// print `0/0` — "nothing to wire" — on precisely the device the chip
// exists to point at. Every test below that names a total is holding that
// line.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 2);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

const _avr = Uuid('dev-avr');
const _tv = Uuid('dev-tv');
const _shelf = Uuid('dev-shelf');

PortDef _port(
  String key, {
  String family = 'video.hdmi.2_1',
  String order = 'a0',
}) => PortDef(
  key: PortKey(key),
  label: key,
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  position: _pos,
  order: FracIndex(order),
  maxConnections: 4,
);

TemplateBody _body(List<PortDef> ports) => TemplateBody(
  manufacturer: 'Acme',
  model: 'T',
  displayName: 'T',
  ports: ports,
);

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-fill'),
  appVersion: '0.1.0',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
);

void _addDevice(
  RackDocument doc,
  Uuid id,
  String designator,
  TemplateBody body, {
  bool registerTemplate = true,
}) {
  final tplId = 'tpl.${id.v}';
  if (registerTemplate) {
    doc.templates['$tplId@1'] = TemplateSnapshot(
      templateId: TemplateId(tplId),
      version: 1,
      contentHash: 'sha256:$tplId',
      body: body,
      capturedAt: _when,
    );
  }
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(tplId),
      version: 1,
      contentHash: 'sha256:$tplId',
    ),
    designator: designator,
    name: designator,
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
}

/// AVR-1 with four HDMI outputs, TV-1 with two HDMI inputs. Nothing is
/// materialised and nothing is wired — the state a document is in the
/// moment both devices come out of the palette.
RackDocument _pair() {
  final doc = _doc();
  _addDevice(
    doc,
    _avr,
    'AVR-1',
    _body([
      for (var i = 1; i <= 4; i++) _port('hdmi.out.$i', order: 'a$i'),
    ]),
  );
  _addDevice(
    doc,
    _tv,
    'TV-1',
    _body([
      for (var i = 1; i <= 2; i++) _port('hdmi.in.$i', order: 'b$i'),
    ]),
  );
  return doc;
}

ConnectTarget _pin(RackDocument doc, Uuid device, String key) =>
    resolveConnectTarget(doc, deviceId: device, portKey: key)!;

/// Runs a real connect between two pins, so the conductors this file reads
/// are the ones the gesture writes rather than hand-built fixtures.
void _connect(RackDocument doc, Uuid a, String aKey, Uuid b, String bKey) {
  final result = buildConnectPortsCommand(
    doc: doc,
    from: _pin(doc, a, aKey),
    to: _pin(doc, b, bKey),
    media: kUnstatedMedia,
    now: _when,
    actor: 'test',
  );
  if (result is! ConnectPortsReady) {
    throw StateError('fixture connect was refused: $result');
  }
  result.command.apply(doc);
}

void main() {
  group('the denominator is what the template declares', () {
    test('a freshly-placed device reports its full port count, not 0/0', () {
      final doc = _pair();
      // The precondition, asserted rather than assumed: nothing is
      // materialised. If this ever stops being true the rest of this
      // group stops testing what it says it tests.
      expect(doc.ports, isEmpty);

      final fill = portFillByDevice(doc);
      expect(fill[_avr], const PortFill(connected: 0, total: 4));
      expect(fill[_tv], const PortFill(connected: 0, total: 2));
      expect(fill[_avr]!.label, '0/4');
    });

    test(
      'an unresolvable template snapshot reports 0/0 rather than throwing',
      () {
        final doc = _doc();
        _addDevice(
          doc,
          _avr,
          'AVR-1',
          _body([_port('hdmi.out.1')]),
          registerTemplate: false,
        );
        // CR-054 says a `TemplateRef` always resolves; a hand-edited file
        // says otherwise, and `bodyFor` already treats that as an unknown.
        // The chip then does not appear, which is the honest answer: we do
        // not know how many pins this device has.
        expect(
          portFillByDevice(doc)[_avr],
          const PortFill(connected: 0, total: 0),
        );
        expect(portFillByDevice(doc)[_avr]!.hasUnconnected, isFalse);
      },
    );

    test('every device is in the map, including the port-less ones', () {
      final doc = _pair();
      _addDevice(doc, _shelf, 'SHF-1', _body(const []));
      expect(portFillByDevice(doc).keys, hasLength(3));
      expect(
        portFillByDevice(doc)[_shelf],
        const PortFill(connected: 0, total: 0),
      );
    });
  });

  group('the numerator counts jacks in use', () {
    test('one cable moves both ends by one', () {
      final doc = _pair();
      _connect(doc, _avr, 'hdmi.out.1', _tv, 'hdmi.in.1');

      final fill = portFillByDevice(doc);
      expect(fill[_avr], const PortFill(connected: 1, total: 4));
      expect(fill[_tv], const PortFill(connected: 1, total: 2));
    });

    test('a second cable on the SAME jack still counts one jack', () {
      // `portConductorCount` answers 2 here and is right to — `TOP-003`
      // asks how many plugs are in the port. This asks how many jacks are
      // in use, and the answer to that cannot exceed the port count.
      final doc = _pair();
      _connect(doc, _avr, 'hdmi.out.1', _tv, 'hdmi.in.1');
      _connect(doc, _avr, 'hdmi.out.1', _tv, 'hdmi.in.2');

      expect(
        portConductorCount(
          doc,
          derivePortId(_avr, const PortKey('hdmi.out.1')),
        ),
        2,
      );
      expect(
        portFillByDevice(doc)[_avr],
        const PortFill(connected: 1, total: 4),
      );
      expect(
        portFillByDevice(doc)[_tv],
        const PortFill(connected: 2, total: 2),
      );
    });

    test('wiring the last free jack retires the chip', () {
      final doc = _pair();
      expect(portFillByDevice(doc)[_tv]!.hasUnconnected, isTrue);
      _connect(doc, _avr, 'hdmi.out.1', _tv, 'hdmi.in.1');
      _connect(doc, _avr, 'hdmi.out.2', _tv, 'hdmi.in.2');
      expect(portFillByDevice(doc)[_tv]!.hasUnconnected, isFalse);
      expect(portFillByDevice(doc)[_avr]!.hasUnconnected, isTrue);
    });

    test('undoing a connect puts the count back', () {
      final doc = _pair();
      final result = buildConnectPortsCommand(
        doc: doc,
        from: _pin(doc, _avr, 'hdmi.out.1'),
        to: _pin(doc, _tv, 'hdmi.in.1'),
        media: kUnstatedMedia,
        now: _when,
        actor: 'test',
      );
      final command = (result as ConnectPortsReady).command..apply(doc);
      expect(portFillByDevice(doc)[_avr]!.connected, 1);
      command.revert(doc);
      expect(portFillByDevice(doc)[_avr]!.connected, 0);
      expect(
        portFillByDevice(doc)[_avr]!.total,
        4,
        reason: 'and the total never moved',
      );
    });
  });

  group('occupiedPortIds', () {
    test('an open end occupies nothing', () {
      // AC-018/B1: an `OpenEndpoint` names nothing at all. A cable drawn
      // to nowhere must not make a jack read as full.
      final doc = _pair();
      _connect(doc, _avr, 'hdmi.out.1', _tv, 'hdmi.in.1');
      final before = occupiedPortIds(doc);

      final link = doc.links.values.single;
      final conductor = link.conductors.single;
      link.conductors[0] = Conductor(
        role: conductor.role,
        from: conductor.from,
        to: const OpenEndpoint('left in a J-hook'),
      );

      final after = occupiedPortIds(doc);
      expect(after, hasLength(before.length - 1));
      expect(portFillByDevice(doc)[_tv]!.connected, 0);
      expect(portFillByDevice(doc)[_avr]!.connected, 1);
    });

    test('it is one pass, and the ids it returns are derived ones', () {
      final doc = _pair();
      _connect(doc, _avr, 'hdmi.out.1', _tv, 'hdmi.in.1');
      expect(
        occupiedPortIds(doc),
        {
          derivePortId(_avr, const PortKey('hdmi.out.1')),
          derivePortId(_tv, const PortKey('hdmi.in.1')),
        },
      );
    });
  });

  group('PortFill', () {
    test('unconnected is the difference, and equality is by value', () {
      const fill = PortFill(connected: 3, total: 12);
      expect(fill.unconnected, 9);
      expect(fill.label, '3/12');
      expect(fill, const PortFill(connected: 3, total: 12));
      expect(fill.hashCode, const PortFill(connected: 3, total: 12).hashCode);
      expect(fill, isNot(const PortFill(connected: 3, total: 11)));
    });

    test('a device with no ports is furniture, not "unwired"', () {
      // A blank panel, a vent, a shelf. `kNoSymbolsDetail` already says
      // the schematic will not draw it, so a chip pointing there would be
      // a signpost to nowhere.
      expect(const PortFill(connected: 0, total: 0).hasUnconnected, isFalse);
      expect(const PortFill(connected: 12, total: 12).hasUnconnected, isFalse);
      expect(const PortFill(connected: 0, total: 1).hasUnconnected, isTrue);
    });
  });
}
