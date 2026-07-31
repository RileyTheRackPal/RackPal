// DR-011.1/.2/.3 — the pin-to-pin connect command.
//
// THE CASE THIS FILE EXISTS FOR is PORT MATERIALISATION, because it is
// the one place this command breaks the "never allocate in apply()" rule
// and the one place an undo can destroy something the user owned.
//
// Nothing in the app ever writes `doc.ports`: the only
// `doc.ports[id] = Port(...)` in the repository is in
// `apps/rackmate/tool/starters/authoring.dart`, a TOOL. So every pin on a
// document built from the palette is unmaterialised, and a connect that
// required materialised ports would refuse every gesture the product
// offers. DR-011.1 rules that the command materialises inside `apply()`.
//
// That makes TWO properties load-bearing, and both are silent when broken:
//
//   * IDEMPOTENCE — a second apply (a redo) must not overwrite a port
//     that is already there. A `Port` carries a designator, notes,
//     network config, a tap wattage and a circuit id; re-minting it
//     discards all of them and the schedule prints the loss without ever
//     saying anything happened.
//   * REVERT REMOVES EXACTLY WHAT IT ADDED — never a port that already
//     existed. Removing one takes its state with it AND dangles every
//     conductor on every OTHER link that lands there.
//
// The CR-117 byte round-trip below is what catches both at once, and it
// is pinned here rather than in the 1000-sequence fuzz harness for the
// reason `atomic_connect_test.dart` gives: that harness's fixture device
// has no ports at all, so no generated sequence can reach a command that
// writes one.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

final _when = DateTime.utc(2026, 7, 29);
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
const _hdmi = SignalFamilyId('video.hdmi.2_1');
const _media = MediaTypeId('media.hdmi');

PortDef _port(
  String key, {
  String? hint,
  String order = 'a0',
  int maxConnections = 1,
  String family = 'video.hdmi.2_1',
  String? setKey,
  String? setRole,
}) => PortDef(
  key: PortKey(key),
  label: key,
  designatorHint: hint,
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  position: _pos,
  order: FracIndex(order),
  maxConnections: maxConnections,
  setKey: setKey,
  setRole: setRole,
);

void _addDevice(
  RackDocument doc,
  Uuid id,
  String designator,
  List<PortDef> ports, {
  Set<String> materialise = const {},
}) {
  final tplId = 'tpl.${id.v}';
  doc.templates['$tplId@1'] = TemplateSnapshot(
    templateId: TemplateId(tplId),
    version: 1,
    contentHash: 'sha256:$tplId',
    body: TemplateBody(
      manufacturer: 'Acme',
      model: 'T',
      displayName: 'T',
      ports: ports,
    ),
    capturedAt: _when,
  );
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
  for (final key in materialise) {
    final pid = derivePortId(id, PortKey(key));
    doc.ports[pid] = Port(
      id: pid,
      deviceId: id,
      designator: 'PRE-$key',
      templatePortKey: PortKey(key),
      notes: 'punched down in February',
    );
  }
}

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-cc'),
  appVersion: '0.1.0',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
);

/// AVR-1 (one HDMI out) and TV-1 (one HDMI in), neither pin materialised
/// unless [materialise] names it — the state of every real document.
RackDocument _pair({Set<String> materialise = const {}}) {
  final doc = _doc();
  _addDevice(
    doc,
    _avr,
    'AVR-1',
    [
      _port('hdmi.out.1'),
      _port('hdmi.out.2', order: 'a1'),
    ],
    materialise: materialise.where((k) => k.startsWith('hdmi.out')).toSet(),
  );
  _addDevice(
    doc,
    _tv,
    'TV-1',
    [_port('hdmi.in.1')],
    materialise: materialise.where((k) => k.startsWith('hdmi.in')).toSet(),
  );
  return doc;
}

ConnectPortsResult _build(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to, {
  MediaTypeId media = _media,
}) => buildConnectPortsCommand(
  doc: doc,
  from: from,
  to: to,
  media: media,
  now: _when,
  actor: 'test',
);

/// [_build], asserting it produced a command.
ConnectPortsCommand _built(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to, {
  MediaTypeId media = _media,
}) => (_build(doc, from, to, media: media) as ConnectPortsReady).command;

ConnectTarget _out(RackDocument doc, [String key = 'hdmi.out.1']) =>
    resolveConnectTarget(doc, deviceId: _avr, portKey: key)!;

ConnectTarget _in(RackDocument doc) =>
    resolveConnectTarget(doc, deviceId: _tv, portKey: 'hdmi.in.1')!;

Uuid _outId([String key = 'hdmi.out.1']) => derivePortId(_avr, PortKey(key));
Uuid _inId() => derivePortId(_tv, const PortKey('hdmi.in.1'));

/// The command with fixed ids, so a test can name what it created.
ConnectPortsCommand _command(
  RackDocument doc, {
  String fromKey = 'hdmi.out.1',
  SignalFamilyId family = _hdmi,
}) => ConnectPortsCommand(
  from: PortMaterialisation.of(
    _out(doc, fromKey),
    designator: allocatePortDesignatorFor(doc, _out(doc, fromKey)),
  ),
  to: PortMaterialisation.of(
    _in(doc),
    designator: allocatePortDesignatorFor(doc, _in(doc)),
  ),
  designator: 'W001',
  netName: 'N001',
  signalFamily: family,
  media: _media,
  order: const FracIndex('a0'),
  now: _when,
  actor: 'test',
  id: const Uuid('lnk-1'),
  netId: const Uuid('net-1'),
);

void main() {
  group('port materialisation', () {
    test('materialises BOTH unmaterialised pins, at their derived ids', () {
      final doc = _pair();
      expect(doc.ports, isEmpty);

      _command(doc).apply(doc);

      expect(doc.ports.keys.toSet(), {_outId(), _inId()});
      expect(doc.ports[_outId()]!.deviceId, _avr);
      expect(
        doc.ports[_outId()]!.templatePortKey,
        const PortKey('hdmi.out.1'),
        reason:
            'the template join (CR-051) is what survives a template '
            'version bump; a port without it is orphaned on reload',
      );
    });

    test('IS IDEMPOTENT — a second apply leaves an existing port alone', () {
      // A redo runs apply() again. A `Port` carries a designator, notes,
      // network config, a tap wattage and a circuit id; re-minting it
      // discards every one of them silently.
      final doc = _pair(materialise: {'hdmi.out.1'});
      final before = doc.ports[_outId()]!;

      _command(doc)
        ..apply(doc)
        ..revert(doc)
        ..apply(doc);

      expect(
        identical(doc.ports[_outId()], before),
        isTrue,
        reason: 'the pre-existing Port object itself must survive',
      );
      expect(doc.ports[_outId()]!.designator, 'PRE-hdmi.out.1');
      expect(doc.ports[_outId()]!.notes, 'punched down in February');
    });

    test('a document that ALREADY has the port is untouched by it', () {
      final doc = _pair(materialise: {'hdmi.out.1', 'hdmi.in.1'});
      final portsBefore = _codec.write(doc);

      _command(doc).apply(doc);

      expect(doc.ports, hasLength(2), reason: 'nothing new was materialised');
      expect(doc.ports[_outId()]!.designator, 'PRE-hdmi.out.1');
      expect(doc.ports[_inId()]!.designator, 'PRE-hdmi.in.1');
      expect(portsBefore, isNotEmpty);
    });

    test('REVERT REMOVES ONLY WHAT THIS APPLY ADDED', () {
      // The out pin already exists and the in pin does not. An undo that
      // removed both takes the user's designator, notes and every OTHER
      // link's conductor endpoint with it.
      final doc = _pair(materialise: {'hdmi.out.1'});
      final cmd = _command(doc)..apply(doc);
      expect(doc.ports.keys.toSet(), {_outId(), _inId()});

      cmd.revert(doc);

      expect(
        doc.ports.keys.toSet(),
        {_outId()},
        reason:
            "the pre-existing port is not this command's to remove; the "
            'one it minted is',
      );
      expect(doc.ports[_outId()]!.notes, 'punched down in February');
    });

    test('revert twice does not remove the port a re-apply re-created', () {
      final doc = _pair();
      final cmd = _command(doc)
        ..apply(doc)
        ..revert(doc);
      expect(doc.ports, isEmpty);

      // A stray second revert must be inert, not destructive.
      cmd
        ..revert(doc)
        ..apply(doc);
      expect(doc.ports.keys.toSet(), {_outId(), _inId()});
    });
  });

  group('ConnectPortsCommand — one gesture, one undo entry', () {
    test('writes ONE Link, ONE Conductor, TWO PortEndpoints, ONE Net', () {
      final doc = _pair();
      _command(doc).apply(doc);

      expect(doc.links, hasLength(1));
      expect(doc.nets, hasLength(1));
      final link = doc.links[const Uuid('lnk-1')]!;
      expect(link.conductors, hasLength(1));
      expect(link.services, hasLength(1));
      expect((link.conductors.single.from as PortEndpoint).portId, _outId());
      expect((link.conductors.single.to as PortEndpoint).portId, _inId());
    });

    test('ONE undo entry for the whole gesture, ports included', () {
      final doc = _pair();
      final controller = DocumentController(doc, clock: FixedClock(_when))
        ..run(_command(doc));

      expect(
        controller.undo.depth,
        1,
        reason:
            'materialising two ports and creating a link is one thing the '
            'user did; three entries would take three undos to reverse',
      );
      expect(controller.undo.undoLabelKey, LabelKey.connectPorts.name);
      expect(doc.ports, hasLength(2));

      controller.undoLast();
      expect(doc.links, isEmpty);
      expect(doc.nets, isEmpty);
      expect(doc.ports, isEmpty);
      expect(controller.undo.canUndo, isFalse);

      controller.redoLast();
      expect(doc.ports.keys.toSet(), {_outId(), _inId()});
      expect(doc.links, hasLength(1));
    });

    test('CR-117: apply then revert restores byte-identical JSON', () {
      final doc = _pair();
      final before = _codec.write(doc);

      final cmd = _command(doc)..apply(doc);
      expect(
        _codec.write(doc),
        isNot(before),
        reason: 'guards the assertion below against passing vacuously',
      );

      cmd.revert(doc);
      expect(_codec.write(doc), before);
    });

    test('CR-117 holds when ONE end was already materialised', () {
      // The asymmetric case: revert must remove one port and keep the
      // other, byte for byte.
      final doc = _pair(materialise: {'hdmi.out.1'});
      final before = _codec.write(doc);

      final cmd = _command(doc)..apply(doc);
      expect(_codec.write(doc), isNot(before));

      cmd.revert(doc);
      expect(_codec.write(doc), before);
    });

    test('apply; revert; apply lands where a single apply does', () {
      final doc = _pair();
      final cmd = _command(doc)..apply(doc);
      final once = _codec.write(doc);

      cmd
        ..revert(doc)
        ..apply(doc);

      expect(_codec.write(doc), once);
    });

    test('redo recreates IDENTICAL entities', () {
      final doc = _pair();
      final cmd = _command(doc)..apply(doc);
      final firstPortIds = doc.ports.keys.toList();
      final firstLink = doc.links[const Uuid('lnk-1')]!;
      final firstEnds = [
        (firstLink.conductors.single.from as PortEndpoint).portId.v,
        (firstLink.conductors.single.to as PortEndpoint).portId.v,
      ];

      cmd
        ..revert(doc)
        ..apply(doc);

      final second = doc.links[const Uuid('lnk-1')]!;
      expect(doc.ports.keys.toList(), firstPortIds);
      expect(second.designator, 'W001');
      expect(doc.nets[const Uuid('net-1')]!.name, 'N001');
      expect(
        [
          (second.conductors.single.from as PortEndpoint).portId.v,
          (second.conductors.single.to as PortEndpoint).portId.v,
        ],
        firstEnds,
      );
    });

    test('the mixed-port Link survives a round trip intact', () {
      final doc = _pair();
      _command(doc).apply(doc);

      final decoded = _codec.read(_codec.write(doc));
      expect(decoded, isA<Ok<RackDocument>>());
      final read = (decoded as Ok<RackDocument>).value;
      expect(read.ports, hasLength(2));
      expect(
        (read.links[const Uuid('lnk-1')]!.conductors.single.from
                as PortEndpoint)
            .portId,
        _outId(),
      );
    });

    test('carries its own label, and touches wires AND meta', () {
      final doc = _pair();
      final cmd = _command(doc);
      expect(cmd.label, LabelKey.connectPorts);
      expect(cmd.touches.has(EpochMask.wires), isTrue);
      expect(
        cmd.touches.has(EpochMask.meta),
        isTrue,
        reason:
            'materialisation MINTS A DESIGNATOR, and a surface subscribed '
            'only to wires would draw the run against a pin whose '
            'identifier it has never read',
      );
      expect(
        cmd.touches.has(EpochMask.structure),
        isFalse,
        reason: 'a materialised port moves nothing; structure is placement',
      );
      expect(cmd.affects, [
        const Uuid('lnk-1'),
        const Uuid('net-1'),
        _outId(),
        _inId(),
      ]);
    });

    test('REFUSES to build a conductor from a pin to itself', () {
      // The zero-conductor guard: a conductor whose two ends are one jack
      // is no electrical path at all, and a Link carrying it is a
      // pull-sheet row for a cable that connects nothing (CR-010,
      // CR-014). A throw, not an assert — release builds strip asserts.
      final doc = _pair();
      final target = _out(doc);
      expect(
        () => ConnectPortsCommand(
          from: PortMaterialisation.of(target, designator: 'J01'),
          to: PortMaterialisation.of(target, designator: 'J01'),
          designator: 'W001',
          netName: 'N001',
          signalFamily: _hdmi,
          media: _media,
          order: const FracIndex('a0'),
          now: _when,
          actor: 'test',
        ),
        throwsArgumentError,
      );
      expect(doc.links, isEmpty);
      expect(doc.ports, isEmpty);
    });
  });

  group('DR-011.3 — the REAL signal family, not structure.undetermined', () {
    test('flows to the Net AND the Service', () {
      final doc = _pair();
      _command(doc).apply(doc);

      final net = doc.nets[const Uuid('net-1')]!;
      final service = doc.links[const Uuid('lnk-1')]!.services.single;
      expect(net.signalFamily, _hdmi);
      expect(service.signalFamily, _hdmi);
      expect(
        net.signalFamily,
        isNot(const SignalFamilyId('structure.undetermined')),
        reason:
            'the placeholder every link used to land on — it put the whole '
            'project in the str domain, and CR-078 keys hue, dash, weight '
            'and glyph off the family',
      );
      expect(
        service.signalFamily,
        isNot(const SignalFamilyId('structure.undetermined')),
      );
    });

    test('the builder takes it from the pin the user grabbed', () {
      final doc = _pair();
      expect(_built(doc, _out(doc), _in(doc)).signalFamily, _hdmi);
    });

    test('a non-HDMI pin gets ITS family, not the last one that shipped', () {
      final doc = _doc();
      _addDevice(doc, _avr, 'AVR-1', [
        _port('spk.out.1', family: 'audio.speaker'),
      ]);
      _addDevice(doc, _tv, 'TV-1', [
        _port('spk.in.1', family: 'audio.speaker'),
      ]);
      _built(
        doc,
        resolveConnectTarget(doc, deviceId: _avr, portKey: 'spk.out.1')!,
        resolveConnectTarget(doc, deviceId: _tv, portKey: 'spk.in.1')!,
        media: const MediaTypeId('media.spk_16_2'),
      ).apply(doc);
      expect(
        doc.nets.values.single.signalFamily,
        const SignalFamilyId('audio.speaker'),
      );
    });
  });

  group('kUnstatedMedia — the cable type the document cannot state', () {
    test('the seeded registries carry NO media type at all, so no id a '
        'connect could pick would resolve', () {
      // THE PREMISE, ASSERTED RATHER THAN QUOTED. `seed_registries.dart`'s
      // header says `mediaTypes` stays empty (docs/02 §5.3's table was out
      // of DR-010's scope); this fails if that ever changes, which is
      // exactly when the connect path should start offering a real choice
      // instead of writing nothing.
      expect(buildSeedRegistries().mediaTypes, isEmpty);
    });

    test('a link built with it reaches the schedule as an UNRESOLVED media '
        '— counted, not invented', () {
      // G4 in the one place it is expensive to get wrong: the termination
      // schedule is what an installer buys cable from. `ProjectSettings
      // .defaultNetworkMedia` is `media.cat6a_futp`, and writing that on
      // an HDMI run would put a plausible — and wrong — cable spec in
      // front of them, which reads as data rather than as a guess.
      final doc = _pair();
      _built(doc, _out(doc), _in(doc), media: kUnstatedMedia).apply(doc);

      final row = buildSchedule(doc).rows.single;
      expect(row.mediaId, kUnstatedMedia);
      expect(
        row.media,
        isNull,
        reason: 'ScheduleRow.media is the nullable registry entry, whose '
            'own doc reads "counted, never invented" — an unstated cable '
            'lands in that arm',
      );
    });

    test('it round-trips byte-for-byte — an empty id is a value, not a '
        'hole', () {
      // CR-117 over the one field this constant touches. `Link.media` is
      // encoded as a bare string, so the risk was never the empty value
      // itself but a reader that treated `''` as absent and dropped it.
      final doc = _pair();
      _built(doc, _out(doc), _in(doc), media: kUnstatedMedia).apply(doc);
      final bytes = _codec.write(doc);
      final again = _codec.read(bytes);
      expect(again, isA<Ok<RackDocument>>());
      final reread = (again as Ok<RackDocument>).value;
      expect(reread.links.values.single.media, kUnstatedMedia);
      expect(_codec.write(reread), bytes);
    });
  });

  group('buildConnectPortsCommand — allocation and refusal', () {
    test('a refusal produces NO command and NO document change', () {
      // DR-011.5: a T1 rule refuses outright, so there must be nothing to
      // undo — which means nothing may be written, ports included.
      final doc = _pair();
      final before = _codec.write(doc);
      final result = _build(doc, _out(doc), _out(doc));

      expect(result, isA<ConnectPortsRefused>());
      expect((result as ConnectPortsRefused).ruleId, 'TOP-001');
      expect(result.message, contains('AVR-1'));
      expect(_codec.write(doc), before);
      expect(doc.ports, isEmpty);
    });

    test('allocates W001/N001 and appends the link order', () {
      final doc = _pair();
      final cmd = _built(doc, _out(doc), _in(doc));
      expect(cmd.designator, 'W001');
      expect(cmd.netName, 'N001');
      expect(cmd.order, const FracIndex('a0'));

      cmd.apply(doc);
      final second = _build(doc, _out(doc, 'hdmi.out.2'), _in(doc));
      expect(second, isA<ConnectPortsRefused>());
      expect(
        (second as ConnectPortsRefused).ruleId,
        'TOP-003',
        reason: 'TV-1 J01 is a maxConnections:1 pin and is now occupied',
      );
    });

    test('the conductor carries the setRole when BOTH pins declare it', () {
      final doc = _doc();
      _addDevice(doc, _avr, 'AVR-1', [
        _port('spk.p', setKey: 'spk', setRole: '+'),
      ]);
      _addDevice(doc, _tv, 'TV-1', [
        _port('spk.p', setKey: 'spk', setRole: '+'),
      ]);
      final result =
          _build(
                doc,
                resolveConnectTarget(doc, deviceId: _avr, portKey: 'spk.p')!,
                resolveConnectTarget(doc, deviceId: _tv, portKey: 'spk.p')!,
              )
              as ConnectPortsReady;
      result.command.apply(doc);
      expect(result.roleMismatch, isNull);
      expect(result.command.role, '+');
      expect(doc.links.values.single.conductors.single.role, '+');
    });

    test('A POLARITY INVERSION IS NOT WRITTEN AS IF IT WERE CORRECT', () {
      // Drag an amp's `+` onto a speaker's `-`. The role is a claim about
      // the WHOLE conductor, and this link has exactly one — so taking it
      // from the grabbed end alone stamps `+` on a conductor whose far
      // end is the minus post, and `buildSchedule` prints `[+]` beside
      // it. The installer lands the plus leg on the minus terminal with
      // every sheet agreeing. AC-030 exists to make that inexpressible;
      // `AtomicConnectCommand` reports it as a `RoleMismatch`, and on the
      // pin-to-pin path — DR-011.2's primary gesture — it is one drag.
      final doc = _doc();
      _addDevice(doc, _avr, 'AMP-1', [
        _port('zone.1.pos', setKey: 'z1', setRole: '+'),
      ]);
      _addDevice(doc, _tv, 'SPK-1', [
        _port('in.neg', setKey: 'in', setRole: '-'),
      ]);
      final from = resolveConnectTarget(
        doc,
        deviceId: _avr,
        portKey: 'zone.1.pos',
      )!;
      final to = resolveConnectTarget(doc, deviceId: _tv, portKey: 'in.neg')!;

      final result = _build(doc, from, to);
      expect(
        result,
        isA<ConnectPortsReady>(),
        reason:
            'polarity is NOT one of TOP-001..005, and docs/02 §5 opens '
            '"a rule not listed here does not exist" — refusing here '
            'would invent a sixth tier-1 rule and make an as-found '
            'system undrawable (G2, CR-017)',
      );
      final ready = result as ConnectPortsReady;

      expect(
        ready.roleMismatch,
        isNotNull,
        reason: 'ready is not the same as silent',
      );
      expect(ready.roleMismatch!.position, 0);
      expect(ready.roleMismatch!.fromRole, '+');
      expect(ready.roleMismatch!.toRole, '-');

      ready.command.apply(doc);
      expect(
        ready.command.role,
        '',
        reason:
            "ScheduleConductor.role documents '' as 'the cable has one "
            "electrical path whose role is the cable', which is exactly "
            'this link — and it is the only value that does not claim '
            'the conductor is the plus leg',
      );
      expect(doc.links.values.single.conductors.single.role, '');
      expect(
        buildSchedule(doc).rows.single.conductors.single.role,
        '',
        reason: 'the schedule is where the wrong claim would have printed',
      );
    });

    test('an empty role on one end is no role, not a role that differs', () {
      // `Conductor.role`'s own doc gives "" as a value, so a template may
      // spell "unroled" as null or as "". Comparing them raw would report
      // a mismatch on every half-roled pair.
      final doc = _doc();
      _addDevice(doc, _avr, 'AVR-1', [_port('a', setRole: '')]);
      _addDevice(doc, _tv, 'TV-1', [_port('b', setRole: 'L')]);
      final ready =
          _build(
                doc,
                resolveConnectTarget(doc, deviceId: _avr, portKey: 'a')!,
                resolveConnectTarget(doc, deviceId: _tv, portKey: 'b')!,
              )
              as ConnectPortsReady;
      expect(ready.roleMismatch, isNull);
      expect(ready.command.role, '');
    });
  });

  group('port designator allocation', () {
    test('PORT_SEQ is the TEMPLATE position, not a running count', () {
      // Ports materialise lazily, so "lowest unused on this device" would
      // number pins in the order the user happened to patch them. Patch
      // the second output first and it would become J01 while the
      // silkscreen beside it reads J02.
      final doc = _pair();
      expect(templatePortSeq(doc, _out(doc, 'hdmi.out.2')), 2);
      expect(
        allocatePortDesignatorFor(doc, _out(doc, 'hdmi.out.2')),
        'J02',
        reason:
            'the second declared port is J02 whether or not the first one '
            'has ever been patched',
      );
      expect(allocatePortDesignatorFor(doc, _out(doc)), 'J01');
    });

    test('an already-materialised port keeps the designator it has', () {
      final doc = _pair(materialise: {'hdmi.out.1'});
      expect(allocatePortDesignatorFor(doc, _out(doc)), 'PRE-hdmi.out.1');
    });

    test('walks past a designator a hand-edited file already put there', () {
      final doc = _pair();
      final other = derivePortId(_avr, const PortKey('hdmi.out.2'));
      doc.ports[other] = Port(id: other, deviceId: _avr, designator: 'J01');
      expect(
        allocatePortDesignatorFor(doc, _out(doc)),
        'J02',
        reason: 'CR-042 requires uniqueness within the device',
      );
    });

    test('honours a project that customised portDesignatorFormat', () {
      final doc = _pair();
      doc.settings.portDesignatorFormat = const IdFormat('P{PORT_SEQ}');
      expect(allocatePortDesignatorFor(doc, _out(doc)), 'P1');
    });
  });

  group('allocateLinkDesignator', () {
    test('the first link is W001 — the format engine, not a concatenation', () {
      expect(
        allocateLinkDesignator(
          settings: ProjectSettings(),
          usedDesignators: const {},
        ),
        'W001',
      );
    });

    test('takes the LOWEST unused, filling a gap rather than appending', () {
      expect(
        allocateLinkDesignator(
          settings: ProjectSettings(),
          usedDesignators: const {'W001', 'W003'},
        ),
        'W002',
      );
    });

    test('DESIGNATORPAD IS NOT APPLIED — the double-pad trap', () {
      // Same trap as `allocateNetName`, same reasoning, and the pad must
      // EXCEED the token width to prove anything: at `designatorPad = 2`
      // pre-padding to "01" and then letting `{SEQ:3}` widen it lands on
      // the right answer either way. Five is past `:3`.
      final settings = ProjectSettings()..designatorPad = 5;
      expect(
        allocateLinkDesignator(settings: settings, usedDesignators: const {}),
        'W001',
        reason:
            'applying the DEVICE pad here gives W00001 and renumbers every '
            'cable in a project whose device designators happen to be '
            'zero-padded — and Link.designator prints on the schedule',
      );
    });

    test('A SEQUENCE-LESS PATTERN THROWS INSTEAD OF SPINNING FOREVER', () {
      // `linkDesignatorFormat` is persisted as a raw string and decoded as
      // `IdFormat(raw)` — json_codec's `_decodeIdFormat` checks no tokens —
      // so a hand-edited file can carry a pattern that renders the same
      // text for every SEQ. The second link then had nothing new to find
      // and the walk spun in a tight synchronous loop that no timeout can
      // interrupt: not a slow test, a frozen UI isolate with every unsaved
      // edit inside it.
      final settings = ProjectSettings()
        ..linkDesignatorFormat = const IdFormat('W');
      expect(
        allocateLinkDesignator(settings: settings, usedDesignators: const {}),
        'W',
        reason: 'the FIRST one is still allocatable',
      );
      expect(
        () => allocateLinkDesignator(
          settings: settings,
          usedDesignators: const {'W'},
        ),
        throwsA(isA<DesignatorExhaustedException>()),
      );
    });

    test('a pattern that CYCLES is caught too, not just a constant one', () {
      // `|first 1` keeps varying — W1, W2, … W9 — and then repeats W1.
      // A "did the last two candidates differ" guard passes this and
      // hangs; the walk stops when a candidate REPEATS.
      final settings = ProjectSettings()
        ..linkDesignatorFormat = const IdFormat('W{SEQ|first 1}');
      final used = {for (var i = 1; i <= 9; i++) 'W$i'};
      expect(
        () => allocateLinkDesignator(settings: settings, usedDesignators: used),
        throwsA(
          isA<DesignatorExhaustedException>().having(
            (e) => e.distinctCandidates,
            'distinctCandidates',
            9,
          ),
        ),
      );
      expect(
        allocateLinkDesignator(
          settings: settings,
          usedDesignators: used.difference({'W7'}),
        ),
        'W7',
        reason: 'and it still finds a gap when there is one',
      );
    });

    test('every allocator in the file shares the guard', () {
      // One loop, four callers — the termination argument lives in one
      // place instead of four copies that drift.
      final settings = ProjectSettings()
        ..deviceDesignatorFormat = const IdFormat('{TYPE_PREFIX}')
        ..netNameFormat = const IdFormat('N')
        ..portDesignatorFormat = const IdFormat('J');
      expect(
        () => allocateDeviceDesignator(
          settings: settings,
          typePrefix: 'AMP',
          usedDesignators: const {'AMP'},
        ),
        throwsA(isA<DesignatorExhaustedException>()),
      );
      expect(
        () => allocateNetName(settings: settings, usedNames: const {'N'}),
        throwsA(isA<DesignatorExhaustedException>()),
      );
      expect(
        () => allocatePortDesignator(
          settings: settings,
          portSeq: 1,
          usedDesignators: const {'J'},
        ),
        throwsA(isA<DesignatorExhaustedException>()),
      );
    });

    test('allocateLinkDesignatorFor reads the document', () {
      final doc = _pair();
      expect(allocateLinkDesignatorFor(doc), 'W001');
      _command(doc).apply(doc);
      expect(allocateLinkDesignatorFor(doc), 'W002');
    });
  });

  group('nextOrder — the generalised fractional index', () {
    test('appends after every existing LINK order, not just rack orders', () {
      expect(nextOrder(const <FracIndex>[]).v, 'a0');
      expect(nextOrder(const [FracIndex('a0'), FracIndex('a1')]).v, 'a2');
    });

    test('nextRackOrder still answers the same thing', () {
      expect(
        nextRackOrder(const [FracIndex('a0')]).v,
        nextOrder(const [FracIndex('a0')]).v,
      );
    });

    test('a second link sorts after the first', () {
      final doc = _pair();
      _command(doc).apply(doc);
      expect(
        nextOrder(doc.links.values.map((l) => l.order)).v.compareTo('a0'),
        greaterThan(0),
      );
    });
  });
}
