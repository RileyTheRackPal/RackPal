// commands/bind_endpoint_command.dart — board M3-K/2 (#664), DR-040
// §11.39.2, AC-018.
//
// THE CLAUSE THIS FILE IS ABOUT IS A LIST OF WHAT MUST NOT CHANGE. Canon
// :2186 words the command as one *"that preserves the ID, the length, the
// jacket, and the test result"*, so the preservation group below is the
// specification transcribed, not a defensive extra: a bind that rebuilt
// the `Link` would pass every assertion about the endpoint and lose the
// four facts the ruling names.
//
// The second load-bearing group is materialisation, for the reason
// `connect_commands_test.dart` gives at length: a redo that re-mints a
// port discards its project state silently, and an undo that removes a
// port it did not create dangles every conductor on every other link that
// lands there.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

final _now = DateTime.utc(2026, 8, 11);
final _later = DateTime.utc(2026, 8, 12);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

const _panel = Uuid('dev-pp1');

/// The rear punchdown positions of a small patch panel.
///
/// REAR, WHICH IS DR-040 §11.39.2 CLAUSE 4. The N03 archetype models front
/// RJ45 jacks and rear 110 punchdowns separately and says why in its own
/// description; a drop lands on the punchdown.
/// An in-wall speaker with two binding posts, modelled the way a driver
/// actually is: its terminals are simply its terminals, and nothing about
/// it has a rack panel's front/rear split.
const Uuid _speaker = Uuid('dev-speaker');

void _addSpeaker(RackDocument doc) {
  const tplId = 'tpl.spk';
  doc.templates['$tplId@1'] = TemplateSnapshot(
    templateId: const TemplateId(tplId),
    version: 1,
    contentHash: 'sha256:$tplId',
    body: TemplateBody(
      manufacturer: 'Generic',
      model: 'IW-6',
      displayName: 'In-wall speaker, 6.5in',
      typePrefix: 'SPK',
      ports: [
        PortDef(
          key: const PortKey('post.1'),
          label: '+/-',
          connector: const ConnectorTypeId('conn.binding_post'),
          signalFamily: const SignalFamilyId('aud.speaker'),
          face: Face.front,
          position: _pos,
          order: const FracIndex('a0'),
        ),
      ],
    ),
    capturedAt: _now,
  );
  doc.devices[_speaker] = DeviceInstance(
    id: _speaker,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId(tplId),
      version: 1,
      contentHash: 'sha256:$tplId',
    ),
    designator: 'SPK-1',
    name: 'Living Room L',
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
}

PortDef _rear(String key, String label, String order) => PortDef(
  key: PortKey(key),
  label: label,
  connector: const ConnectorTypeId('conn.punchdown_110'),
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: Face.rear,
  position: _pos,
  order: FracIndex(order),
);

void _addPanel(RackDocument doc, {Set<String> materialise = const {}}) {
  const tplId = 'tpl.pp24';
  doc.templates['$tplId@1'] = TemplateSnapshot(
    templateId: const TemplateId(tplId),
    version: 1,
    contentHash: 'sha256:$tplId',
    body: TemplateBody(
      manufacturer: 'Generic',
      model: 'PP-24',
      displayName: 'Patch Panel, 24-port',
      typePrefix: 'PP',
      ports: [
        _rear('rear.1', '01', 'a0'),
        _rear('rear.2', '02', 'a1'),
        _rear('rear.3', '03', 'a2'),
      ],
    ),
    capturedAt: _now,
  );
  doc.devices[_panel] = DeviceInstance(
    id: _panel,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId(tplId),
      version: 1,
      contentHash: 'sha256:$tplId',
    ),
    designator: 'PP-1',
    name: 'Patch Panel',
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
  for (final key in materialise) {
    final pid = _pid(key);
    doc.ports[pid] = Port(
      id: pid,
      deviceId: _panel,
      designator: 'PRE-$key',
      templatePortKey: PortKey(key),
      notes: 'punched down in February',
    );
  }
}

/// A project with a Structure body, an Outlet, one home run and a panel.
({RackDocument doc, Uuid linkId}) _project({
  Set<String> materialise = const {},
}) {
  final doc = RackDocument(
    id: const Uuid('doc-bind'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  final structure = AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 'test',
  )..apply(doc);
  final outlet = AddOutletCommand(
    structureBodyId: structure.bodyId,
    designation: 'LR-TV-1',
    order: nextOutletOrder(doc),
    now: _now,
    actor: 'test',
  )..apply(doc);
  final run =
      (buildAddHomeRunCommand(
                doc: doc,
                outletId: outlet.id,
                fieldLabel: 'LR-DATA-1',
                designator: 'W001',
                netName: 'N001',
                media: const MediaTypeId('media.cat6'),
                fieldEnd: const PlaceEndpoint(description: 'LR TV wall'),
                now: _now,
                actor: 'test',
              )
              as AddHomeRunReady)
          .command
        ..apply(doc);
  _addPanel(doc, materialise: materialise);
  return (doc: doc, linkId: run.id);
}

/// The id `rear.N` WILL have. Pure over `(deviceId, portKey)` (CR-116),
/// which is the property the whole materialise-in-apply design rests on.
Uuid _pid(String key) => derivePortId(_panel, PortKey(key));

PortMaterialisation _pin(String key, String designator) => PortMaterialisation(
  portId: _pid(key),
  deviceId: _panel,
  portKey: PortKey(key),
  designator: designator,
);

BindEndpointResult _build(
  RackDocument doc,
  Uuid linkId, {
  String key = 'rear.1',
  String designator = '01',
  String? rackLabel = '1A-PP-101',
  Set<String> usedRackLabels = const {},
}) => buildBindEndpointCommand(
  doc: doc,
  linkId: linkId,
  port: _pin(key, designator),
  rackLabel: rackLabel,
  usedRackLabels: usedRackLabels,
  now: _later,
  actor: 'tech',
);

BindEndpointCommand _ready(BindEndpointResult r) =>
    (r as BindEndpointReady).command;

String _refusal(BindEndpointResult r) => (r as BindEndpointRefused).reason;

void main() {
  group('the landing itself', () {
    test('the far end stops being open and names the port', () {
      // AC-018's forty-six, at the artifact. Before this command existed
      // the product could produce only the fourteen kind.
      final p = _project();
      final link = p.doc.links[p.linkId]!;
      expect(link.conductors.first.to, isA<OpenEndpoint>());

      _ready(_build(p.doc, p.linkId)).apply(p.doc);

      final end = p.doc.links[p.linkId]!.conductors.first.to;
      expect(end, isA<PortEndpoint>());
      expect(
        (end as PortEndpoint).portId,
        _pid('rear.1'),
      );
    });

    test(
      'the FIELD end is untouched, because the other end is the gesture',
      () {
        // A bind that rebuilt both ends would let a caller who passed the
        // wrong pin move the drop out of the room it was pulled to.
        final p = _project();
        final before = p.doc.links[p.linkId]!.conductors.first.from;

        _ready(_build(p.doc, p.linkId)).apply(p.doc);

        expect(p.doc.links[p.linkId]!.conductors.first.from, same(before));
      },
    );

    test('the rack label lands, and a null one lands as null (G4)', () {
      // DR-040 §11.39.5: the endpoint and the label are two facts. A panel
      // whose location cannot render `{FLOOR}` still gets punched down.
      final p = _project();
      _ready(_build(p.doc, p.linkId, rackLabel: null)).apply(p.doc);

      expect(
        p.doc.links[p.linkId]!.conductors.first.to,
        isA<PortEndpoint>(),
        reason: 'the bind happened anyway',
      );
      expect(p.doc.links[p.linkId]!.structureOrigin!.rackLabel, isNull);
    });

    test('a blank rack label is normalised to null, never to ""', () {
      // `''` is a third state every reader downstream would have to guess
      // about, which is `LinkField.notes`' stated rule.
      final p = _project();
      _ready(_build(p.doc, p.linkId, rackLabel: '   ')).apply(p.doc);

      expect(p.doc.links[p.linkId]!.structureOrigin!.rackLabel, isNull);
    });
  });

  group('WHAT CANON :2186 SAYS MUST NOT CHANGE', () {
    test('the id, the W number, the net, the media and the lengths all '
        'survive the bind', () {
      // The clause transcribed: "preserves the ID, the length, the jacket,
      // and the test result". A bind that rebuilt the Link would pass
      // every endpoint assertion above and lose all of this.
      final p = _project();
      final link = p.doc.links[p.linkId]!;
      const length = Len(780 * Len.nmPerInch);
      final result = TestResult(pass: true, certificateId: 'CERT-7');
      link
        ..routedLength = length
        ..jacketColorId = const JacketColorId('jacket.blue')
        ..test = result
        ..roughInStatus = RoughInStatus.pulled;
      final services = link.services;
      final designator = link.designator;

      _ready(_build(p.doc, p.linkId)).apply(p.doc);

      final after = p.doc.links[p.linkId]!;
      expect(after.id, p.linkId);
      expect(after.designator, designator, reason: 'the W number');
      expect(after.services, same(services), reason: 'the net');
      expect(after.media, const MediaTypeId('media.cat6'));
      expect(after.routedLength, length, reason: 'the length');
      expect(
        after.jacketColorId,
        const JacketColorId('jacket.blue'),
        reason: 'the jacket',
      );
      expect(after.test, same(result), reason: 'the test result');
      expect(after.roughInStatus, RoughInStatus.pulled);
      // And the field label, which is the one identifier an unbound end
      // ever had and is printed on physical cable.
      expect(after.structureOrigin!.fieldLabel, 'LR-DATA-1');
    });

    test('undo restores the open end AND its own words', () {
      // An OpenEndpoint's description is not always the constant
      // `AddHomeRunCommand` writes: a round-tripped file or a starter may
      // carry a person's note, and an undo that replaced it with the
      // default would quietly edit something somebody wrote.
      final p = _project();
      final link = p.doc.links[p.linkId]!;
      link.conductors[0] = Conductor(
        from: link.conductors.first.from,
        to: const OpenEndpoint('coil above the hall ceiling'),
      );

      _ready(_build(p.doc, p.linkId))
        ..apply(p.doc)
        ..revert(p.doc);

      final end = p.doc.links[p.linkId]!.conductors.first.to;
      expect(end, isA<OpenEndpoint>());
      expect((end as OpenEndpoint).description, 'coil above the hall ceiling');
      expect(p.doc.links[p.linkId]!.structureOrigin!.rackLabel, isNull);
    });
  });

  group('port materialisation (DR-011.1)', () {
    test('a pin the document never held is created by apply()', () {
      // Nothing in the app writes `doc.ports`, so a panel dropped out of
      // the palette has none and a bind demanding one would refuse every
      // real document.
      final p = _project();
      final id = _pid('rear.1');
      expect(p.doc.ports[id], isNull);

      _ready(_build(p.doc, p.linkId)).apply(p.doc);

      expect(p.doc.ports[id]!.designator, '01');
      expect(p.doc.ports[id]!.deviceId, _panel);
    });

    test('IDEMPOTENT: a redo does not re-mint a port that is already '
        'there', () {
      // A `Port` carries a designator, notes, network config and a circuit
      // id. Re-minting discards all of them and nothing says so.
      final p = _project(materialise: {'rear.1'});
      _ready(_build(p.doc, p.linkId))
        ..apply(p.doc)
        ..revert(p.doc)
        ..apply(p.doc);

      final port = p.doc.ports[_pid('rear.1')]!;
      expect(port.designator, 'PRE-rear.1', reason: 'never rewritten');
      expect(port.notes, 'punched down in February');
    });

    test('revert removes what it created and NEVER what it found', () {
      // Removing a pre-existing port takes its state with it and dangles
      // every conductor on every OTHER link that lands there. The two
      // halves are separate documents on purpose: one bind cannot be both
      // the found case and the created case.
      final found = _project(materialise: {'rear.1'});
      _ready(_build(found.doc, found.linkId))
        ..apply(found.doc)
        ..revert(found.doc);
      final kept = found.doc.ports[_pid('rear.1')];
      expect(kept, isNotNull, reason: 'not this command"s port to remove');
      expect(kept!.notes, 'punched down in February');

      final made = _project();
      _ready(_build(made.doc, made.linkId))
        ..apply(made.doc)
        ..revert(made.doc);
      expect(made.doc.ports[_pid('rear.1')], isNull);
    });

    test('CR-117: apply then revert restores byte-identical JSON', () {
      final p = _project();
      final before = _codec.write(p.doc);

      final cmd = _ready(_build(p.doc, p.linkId))..apply(p.doc);
      expect(
        _codec.write(p.doc),
        isNot(before),
        reason: 'guards the assertion below against passing vacuously',
      );

      cmd.revert(p.doc);
      expect(_codec.write(p.doc), before);
    });

    test('CR-117 holds when the port was ALREADY materialised', () {
      // The asymmetric case: revert must restore the endpoint and keep the
      // port, byte for byte.
      final p = _project(materialise: {'rear.1'});
      final before = _codec.write(p.doc);

      final cmd = _ready(_build(p.doc, p.linkId))..apply(p.doc);
      expect(_codec.write(p.doc), isNot(before));

      cmd.revert(p.doc);
      expect(_codec.write(p.doc), before);
    });
  });

  group('the five refusals, each a different fact', () {
    test('a cable that is not in the project', () {
      final p = _project();
      expect(
        _refusal(_build(p.doc, const Uuid('nope'))),
        contains('not in this project'),
      );
    });

    test('a patch is not a drop', () {
      // This writes a rackLabel onto a StructureOrigin, and a link without
      // one is an ordinary connection between two devices.
      final p = _project();
      final plain = AddLinkCommand(
        designator: 'W900',
        netName: 'N900',
        media: const MediaTypeId('media.cat6'),
        order: nextLinkOrder(p.doc),
        now: _now,
        actor: 'test',
      )..apply(p.doc);

      expect(_refusal(_build(p.doc, plain.id)), contains('not a home run'));
    });

    test('a drop that is ALREADY landed is refused, not re-landed', () {
      // DR-040 §11.39.6: moving a drop off a jack it is punched into is
      // its own gesture and is not ruled. Silently re-landing it would
      // rewrite a termination somebody recorded.
      final p = _project();
      _ready(_build(p.doc, p.linkId)).apply(p.doc);

      final second = _build(
        p.doc,
        p.linkId,
        key: 'rear.2',
        designator: '02',
        rackLabel: '1A-PP-102',
      );
      expect(_refusal(second), contains('already landed'));
    });

    test('a punchdown position that already has a cable in it', () {
      // Asked through `portConductorCount` rather than answered again, so
      // TOP-003 keeps living in one place.
      final p = _project();
      _ready(_build(p.doc, p.linkId)).apply(p.doc);

      final outlet = p.doc.links[p.linkId]!.structureOrigin!.outletId!;
      final second =
          (buildAddHomeRunCommand(
                    doc: p.doc,
                    outletId: outlet,
                    fieldLabel: 'LR-DATA-2',
                    designator: 'W002',
                    netName: 'N002',
                    media: const MediaTypeId('media.cat6'),
                    fieldEnd: const PlaceEndpoint(description: 'LR TV wall'),
                    now: _now,
                    actor: 'test',
                  )
                  as AddHomeRunReady)
              .command
            ..apply(p.doc);

      expect(
        _refusal(_build(p.doc, second.id, rackLabel: '1A-PP-102')),
        contains('already has a cable'),
      );
    });

    test('a rack label another drop already spent (CR-113)', () {
      // Two cables sharing a rack label is two rows of the Pull Sheet
      // naming one hole in one panel.
      final p = _project();
      expect(
        _refusal(_build(p.doc, p.linkId, usedRackLabels: {'1A-PP-101'})),
        contains('already used'),
      );
    });

    test('a label a drop only APPEARS to share is not a collision', () {
      // The set is the caller's, and `usedRackLabels` excludes the link
      // being edited. Nothing here may refuse a drop for holding its own
      // label.
      final p = _project();
      expect(
        _build(p.doc, p.linkId, usedRackLabels: {'1A-PP-999'}),
        isA<BindEndpointReady>(),
      );
    });
  });

  group('the rack label is ALLOCATED, not typed (M3-K/3, §11.39.3)', () {
    /// Gives the panel a room with the two identifiers the preset wants.
    Uuid telecom(RackDocument doc, {int? floor = 1, String? space = 'A'}) {
      final add = AddLocationCommand(
        name: 'Media Closet',
        code: 'MC',
        order: nextLocationOrder(doc),
        floorNumber: floor,
        spaceCode: space,
        now: _now,
        actor: 'test',
      )..apply(doc);
      doc.devices[_panel]!.locationId = add.id;
      return add.id;
    }

    test('the shipped preset renders from the landing, not from a typist', () {
      // `allocateOutletRackLabel` shipped with M3-D/1 and had four
      // callers, all in its own test file. This is its first real one.
      final p = _project();
      telecom(p.doc);

      final r = resolveRackLabel(
        doc: p.doc,
        panelDeviceId: _panel,
        portDesignator: '01',
        usedRackLabels: const {},
      );

      // `{FLOOR}{SPACE}-{PANEL}{PORT:2}` over floor 1, space A, panel
      // PP-1, port 01. §11.39.3: `{PANEL}` is the DEVICE DESIGNATOR,
      // because the model has no `Panel` entity to hold anything shorter.
      expect(r.label, '1A-PP-101');
      expect(r.note, isNull);
    });

    test('a project that customised its pattern is HONOURED, not bypassed', () {
      // The whole argument for allocating instead of typing (CR-045): a
      // string somebody types is governed by no pattern at all.
      final p = _project();
      telecom(p.doc);
      p.doc.settings.outletRackLabelFormat = const IdFormat(
        '{PANEL}.{PORT}@{SPACE}',
      );

      final r = resolveRackLabel(
        doc: p.doc,
        panelDeviceId: _panel,
        portDesignator: '07',
        usedRackLabels: const {},
      );

      expect(r.label, 'PP-1.07@A');
      expect(r.note, isNull);
    });

    test('NO FLOOR NUMBER MEANS NO LABEL, AND THE BIND STILL HAPPENS', () {
      // DR-040 §11.39.5. This is the ordinary state of a project nobody
      // has filled the telecom room's identifiers on, and it must not read
      // as an error path.
      final p = _project();
      telecom(p.doc, floor: null);

      final r = resolveRackLabel(
        doc: p.doc,
        panelDeviceId: _panel,
        portDesignator: '01',
        usedRackLabels: const {},
      );

      expect(r.label, isNull);
      // THE SENTENCE NAMES THE FIELD IN PLAIN WORDS. A person who has
      // never read the pattern cannot act on `{FLOOR}`. It quotes the
      // pattern too, which is `LabelTokensMissing.pattern`'s stated
      // reason: somebody who CUSTOMISED their scheme needs to see the
      // scheme in order to know which of its tokens went missing.
      expect(r.note, contains('a floor number'));
      expect(r.note, contains('{FLOOR}{SPACE}-{PANEL}{PORT:2}'));
      // And it says the drop landed, because it did.
      expect(r.note, contains('landed'));

      _ready(_build(p.doc, p.linkId, rackLabel: r.label)).apply(p.doc);
      expect(p.doc.links[p.linkId]!.conductors.first.to, isA<PortEndpoint>());
    });

    test("the floor is the PANEL'S, never the room the drop starts in", () {
      // `1A` is the telecom room. A drop pulled from a second-floor
      // bedroom does not make the panel's label say `2`.
      final p = _project();
      telecom(p.doc);
      final bedroom = AddLocationCommand(
        name: 'Bedroom 2',
        code: 'BR2',
        order: nextLocationOrder(p.doc),
        floorNumber: 2,
        spaceCode: 'Z',
        now: _now,
        actor: 'test',
      )..apply(p.doc);
      p.doc.links[p.linkId]!.conductors[0] = Conductor(
        from: PlaceEndpoint(description: 'BR2 wall', locationId: bedroom.id),
        to: p.doc.links[p.linkId]!.conductors.first.to,
      );

      final r = resolveRackLabel(
        doc: p.doc,
        panelDeviceId: _panel,
        portDesignator: '01',
        usedRackLabels: const {},
      );

      expect(r.label, '1A-PP-101', reason: 'not 2Z-');
    });

    test("a panel with no location of its own inherits its RACK's", () {
      // The same walk `_portEnd` uses. Reading `device.locationId` alone
      // would call a rail-mounted panel roomless and drop the two tokens.
      final p = _project();
      final loc = AddLocationCommand(
        name: 'Media Closet',
        code: 'MC',
        order: nextLocationOrder(p.doc),
        floorNumber: 1,
        spaceCode: 'A',
        now: _now,
        actor: 'test',
      )..apply(p.doc);
      final rack = AddRackCommand(
        designator: 'RK-1',
        name: 'Main',
        heightU: 12,
        order: nextRackOrder(p.doc.racks.values.map((r) => r.order)),
        now: _now,
        actor: 'test',
      )..apply(p.doc);
      p.doc.racks[rack.id]!.locationId = loc.id;
      p.doc.devices[_panel]!.placement = RailPlacement(
        rackId: rack.id,
        ruIndex: 1,
        face: Face.front,
      );

      final r = resolveRackLabel(
        doc: p.doc,
        panelDeviceId: _panel,
        portDesignator: '01',
        usedRackLabels: const {},
      );

      expect(r.label, '1A-PP-101');
    });
  });

  group('EITHER END MAY LAND (DR-068, `#714`)', () {
    // WHY THIS EXISTS. The command bound the rack end and nothing else,
    // so a run could land on a patch panel and never on the thing at the
    // other end of it. For a Cat6 drop that is right: the run ends at a
    // wall plate and whatever plugs in is a separate patch cord. For an
    // in-wall speaker it is wrong, because the run IS one continuous
    // conductor from the amplifier to the binding posts on the driver,
    // and a product that could not say so made the user draw a second
    // cable that does not exist.

    test('a field bind lands `from`, and leaves the rack end alone', () {
      final p = _project();
      final before = p.doc.links[p.linkId]!.conductors.first.to;

      final result = buildBindEndpointCommand(
        doc: p.doc,
        linkId: p.linkId,
        port: _pin('rear.1', '01'),
        rackLabel: null,
        usedRackLabels: const {},
        now: _later,
        actor: 'tech',
        end: LinkEnd.field,
      );
      _ready(result).apply(p.doc);

      final conductor = p.doc.links[p.linkId]!.conductors.first;
      expect(conductor.from, isA<PortEndpoint>());
      expect((conductor.from as PortEndpoint).portId, _pid('rear.1'));
      expect(
        conductor.to,
        same(before),
        reason:
            'the gesture is about one end; rebuilding both would let a '
            'caller that passed the wrong pin move the drop out of its own '
            'room',
      );
    });

    test('a field bind does NOT touch the field label', () {
      // The two labels are not symmetric and this is the asymmetry. A
      // rack label is DERIVED from where the run landed, so the bind is
      // what can know it. A field label names the wall plate, was typed
      // when the drop was created, and is unique project-wide (CR-113):
      // landing a speaker records where the copper ends and says nothing
      // about what the plate is called.
      final p = _project();
      final was = p.doc.links[p.linkId]!.structureOrigin!.fieldLabel;

      _ready(
        buildBindEndpointCommand(
          doc: p.doc,
          linkId: p.linkId,
          port: _pin('rear.1', '01'),
          rackLabel: null,
          usedRackLabels: const {},
          now: _later,
          actor: 'tech',
          end: LinkEnd.field,
        ),
      ).apply(p.doc);

      final origin = p.doc.links[p.linkId]!.structureOrigin!;
      expect(origin.fieldLabel, was);
      expect(
        origin.rackLabel,
        isNull,
        reason:
            'and it wrote no rack label either: the panel position is '
            'untouched by what happened at the wall',
      );
    });

    test('undoing a field bind restores the field end and nothing else', () {
      final p = _project();
      final beforeFrom = p.doc.links[p.linkId]!.conductors.first.from;
      _ready(
          buildBindEndpointCommand(
            doc: p.doc,
            linkId: p.linkId,
            port: _pin('rear.1', '01'),
            rackLabel: null,
            usedRackLabels: const {},
            now: _later,
            actor: 'tech',
            end: LinkEnd.field,
          ),
        )
        ..apply(p.doc)
        ..revert(p.doc);

      final conductor = p.doc.links[p.linkId]!.conductors.first;
      expect(conductor.from, same(beforeFrom));
      expect(
        p.doc.links[p.linkId]!.structureOrigin!.rackLabel,
        isNull,
        reason:
            'a field bind never wrote one, so the revert must not '
            'clear a panel position from a null it never captured',
      );
    });

    test('the two ends land independently, and both stick', () {
      // The pair the whole ruling is for: a speaker run with the driver
      // at one end and the amplifier at the other, as ONE cable.
      final p = _project();
      _ready(
        buildBindEndpointCommand(
          doc: p.doc,
          linkId: p.linkId,
          port: _pin('rear.1', '01'),
          rackLabel: null,
          usedRackLabels: const {},
          now: _later,
          actor: 'tech',
          end: LinkEnd.field,
        ),
      ).apply(p.doc);
      _ready(
        _build(p.doc, p.linkId, key: 'rear.2', designator: '02'),
      ).apply(p.doc);

      final conductor = p.doc.links[p.linkId]!.conductors.first;
      expect((conductor.from as PortEndpoint).portId, _pid('rear.1'));
      expect((conductor.to as PortEndpoint).portId, _pid('rear.2'));
      expect(
        p.doc.links[p.linkId]!.structureOrigin!.rackLabel,
        '1A-PP-101',
        reason: 'the rack bind still allocates its label',
      );
    });

    test('an already-landed FIELD end refuses, and says which end', () {
      final p = _project();
      BindEndpointResult attempt() => buildBindEndpointCommand(
        doc: p.doc,
        linkId: p.linkId,
        port: _pin('rear.1', '01'),
        rackLabel: null,
        usedRackLabels: const {},
        now: _later,
        actor: 'tech',
        end: LinkEnd.field,
      );
      _ready(attempt()).apply(p.doc);

      final refusal = _refusal(attempt());
      expect(refusal, contains('field end'));
      expect(
        refusal,
        isNot(contains('rack end')),
        reason:
            'a refusal naming the wrong end sends a person to look at '
            'the wrong half of the cable',
      );
    });

    test('a rack bind still refuses in the rack end`s own words', () {
      final p = _project();
      _ready(_build(p.doc, p.linkId)).apply(p.doc);
      expect(_refusal(_build(p.doc, p.linkId)), contains('rack end'));
    });

    test("a speaker's binding posts are reachable to a FIELD bind and "
        'invisible to a rack one', () {
      // DR-040 §11.39.2 clause 4 is a rule about the two SIDES OF A PANEL
      // IN A RACK: one side takes pulled cable, the other takes patch
      // cords, and the drop belongs on the first. An in-wall speaker has
      // no such geometry — its binding posts are simply its terminals —
      // so inheriting the split offers it ZERO positions and refuses
      // every direct run, which is the defect `#713` was filed for.
      final p = _project();
      _addSpeaker(p.doc);

      expect(
        freePanelPositions(p.doc, panelDeviceId: _speaker),
        isEmpty,
        reason:
            'clause 4 still holds for the rack end, and a speaker has '
            'no rear',
      );
      final field = freePanelPositions(
        p.doc,
        panelDeviceId: _speaker,
        end: LinkEnd.field,
      );
      expect(field, hasLength(1));
      expect(field.single.port.deviceId, _speaker);
    });

    test('and clause 4 is untouched for the rack end of a real panel', () {
      final p = _project();
      final rear = freePanelPositions(p.doc, panelDeviceId: _panel);
      expect(rear, hasLength(3), reason: "the panel's three punchdowns");
    });
  });

  group('AC-018 end to end', () {
    test('a landed drop still schedules and still carries its W number', () {
      // The half of AC-018 that was already true and must STAY true: the
      // criterion counts sixty rows, not forty-six.
      final p = _project();
      _ready(_build(p.doc, p.linkId)).apply(p.doc);

      final entry = buildSchedule(
        p.doc,
      ).rows.firstWhere((r) => r.linkId == p.linkId);
      expect(entry.designator, 'W001');
      expect(entry.rackLabel, '1A-PP-101');
      expect(entry.fieldLabel, 'LR-DATA-1');
    });
  });
}
