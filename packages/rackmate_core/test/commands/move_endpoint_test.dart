// ignore_for_file: cascade_invocations, an apply/revert pair with
// assertions BETWEEN the two calls is the shape most of these tests take;
// collapsing the pair into a cascade would delete the intermediate
// assertion.
//
// `#722`, DR-074 §11.73 — moving a drop punched into the wrong port.
//
// =====================================================================
// THE PROPERTY THIS FILE IS FOR
// =====================================================================
// Three things survive a move and each of them survives for a different
// reason, so each has its own case here rather than one "it moves" test:
//
//  * the FREED PIN stays in the document (§11.73.4). Deleting it would
//    take a jack somebody else's cable may be about to use.
//  * the TERMINATION stays (§11.73.3). It says how the cable end is
//    finished, not which hole it is in.
//  * a HAND-SET rack label stays (§11.73.2), while an allocated one is
//    re-derived. That is the pair `rackLabelLocked` exists to tell apart,
//    and it is the case most likely to be quietly broken later.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

const _panel = Uuid('dev-pp1');

final _now = DateTime.utc(2026, 8, 18);
final _later = DateTime.utc(2026, 8, 19);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'seed');

/// One rear punchdown. REAR is DR-040 §11.39.2 clause 4: the front jacks
/// take patch cords and a pulled cable lands on the back.
PortDef _rear(String key, String label, String order) => PortDef(
  key: PortKey(key),
  label: label,
  connector: const ConnectorTypeId('conn.punchdown_110'),
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: Face.rear,
  position: _pos,
  order: FracIndex(order),
);

void _addPanel(RackDocument doc) {
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
}

/// A project with a Structure body, an outlet, one home run and a panel.
({RackDocument doc, Uuid linkId, Uuid outletId}) _project() {
  final doc = RackDocument(
    id: const Uuid('doc-move-endpoint'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  final structure = AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 'seed',
  )..apply(doc);
  final outlet = AddOutletCommand(
    structureBodyId: structure.bodyId,
    designation: 'GR-TV-1',
    order: nextOutletOrder(doc),
    now: _now,
    actor: 'seed',
  )..apply(doc);
  final run =
      (buildAddHomeRunCommand(
                doc: doc,
                outletId: outlet.id,
                fieldLabel: 'GR-DATA-1',
                designator: 'W001',
                netName: 'N001',
                media: const MediaTypeId('media.cat6'),
                fieldEnd: const PlaceEndpoint(description: 'Great Room'),
                terminationField: TerminationType.keystone,
                now: _now,
                actor: 'seed',
              )
              as AddHomeRunReady)
          .command
        ..apply(doc);
  _addPanel(doc);
  return (doc: doc, linkId: run.id, outletId: outlet.id);
}

/// The id `rear.N` WILL have, pure over `(deviceId, portKey)` (CR-116).
Uuid _pid(String key) => derivePortId(_panel, PortKey(key));

PortMaterialisation _pin(String key, String designator) => PortMaterialisation(
  portId: _pid(key),
  deviceId: _panel,
  portKey: PortKey(key),
  designator: designator,
);

/// Lands a run's rack end on `rear.1` the way `LANDS ON` does.
PortMaterialisation _land(
  RackDocument doc,
  Uuid linkId, {
  String key = 'rear.1',
  String designator = '01',
  String? rackLabel = 'PP1-01',
}) {
  final pin = _pin(key, designator);
  BindEndpointCommand(
    linkId: linkId,
    port: pin,
    rackLabel: rackLabel,
    now: _now,
    actor: 'seed',
  ).apply(doc);
  return pin;
}

MoveEndpointResult _move(
  RackDocument doc,
  Uuid linkId,
  PortMaterialisation to, {
  String? rackLabel = 'PP1-02',
  LinkEnd end = LinkEnd.rack,
  Set<String>? used,
}) => buildMoveEndpointCommand(
  doc: doc,
  linkId: linkId,
  port: to,
  rackLabel: rackLabel,
  // EXCLUDES THIS LINK, which is the caller's job and is why it is a
  // parameter: a scan of the whole document would collide with the label
  // this move is about to replace.
  usedRackLabels: used ?? usedRackLabels(doc, exceptLinkId: linkId),
  now: _later,
  actor: 'tester',
  end: end,
);

MoveEndpointCommand _ready(MoveEndpointResult r) =>
    (r as MoveEndpointReady).command;

String _refusal(MoveEndpointResult r) => (r as MoveEndpointRefused).reason;

Uuid _rackPin(RackDocument doc, Uuid linkId) =>
    (doc.links[linkId]!.conductors.first.to as PortEndpoint).portId;

void main() {
  group('the move itself', () {
    test('re-lands the rack end on the pin it was handed', () {
      final p = _project();
      final was = _land(p.doc, p.linkId);
      final to = _pin('rear.2', '02');

      _ready(_move(p.doc, p.linkId, to)).apply(p.doc);
      expect(_rackPin(p.doc, p.linkId), to.portId);
      expect(_rackPin(p.doc, p.linkId), isNot(was.portId));
    });

    test('reverts to the exact pin it came off', () {
      final p = _project();
      final was = _land(p.doc, p.linkId);
      final to = _pin('rear.2', '02');

      final command = _ready(_move(p.doc, p.linkId, to));
      command.apply(p.doc);
      command.revert(p.doc);
      expect(_rackPin(p.doc, p.linkId), was.portId);
    });

    test('leaves the FIELD end alone', () {
      // A move that rebuilt both ends would let a caller with the wrong
      // pin push the drop out of its own room, which is the failure
      // `BindEndpointCommand`'s own comment names.
      final p = _project();
      _land(p.doc, p.linkId);
      final before = p.doc.links[p.linkId]!.conductors.first.from;
      _ready(_move(p.doc, p.linkId, _pin('rear.2', '02'))).apply(p.doc);
      expect(p.doc.links[p.linkId]!.conductors.first.from, same(before));
    });

    test('keeps the cable ITSELF: id, designator, media, jacket', () {
      // AC-018's list of what a bind must not change, applied to the act
      // that corrects one. Moving a cable to another hole is not making a
      // different cable.
      final p = _project();
      _land(p.doc, p.linkId);
      final link = p.doc.links[p.linkId]!;
      final designator = link.designator;
      final media = link.media;
      final order = link.order;

      _ready(_move(p.doc, p.linkId, _pin('rear.2', '02'))).apply(p.doc);
      final after = p.doc.links[p.linkId]!;
      expect(after.designator, designator);
      expect(after.media, media);
      expect(after.order, order);
      expect(p.doc.links, hasLength(1), reason: 'no second cable was made');
    });

    test('stamps the link, and undo puts the stamp back', () {
      final p = _project();
      _land(p.doc, p.linkId);
      final before = p.doc.links[p.linkId]!.meta;

      final command = _ready(_move(p.doc, p.linkId, _pin('rear.2', '02')));
      command.apply(p.doc);
      expect(p.doc.links[p.linkId]!.meta.updatedBy, 'tester');
      command.revert(p.doc);
      expect(p.doc.links[p.linkId]!.meta, same(before));
    });
  });

  group('what a move must NOT take with it', () {
    test('the freed pin stays in the document (§11.73.4)', () {
      // `ConnectPortsCommand`'s rule. A pin the document already held is
      // not this gesture's to delete: guessing wrong deletes a jack
      // somebody else's cable may be about to use, and a freed pin that
      // came from a template was always drawn.
      final p = _project();
      final was = _land(p.doc, p.linkId);
      expect(p.doc.ports, contains(was.portId));

      _ready(_move(p.doc, p.linkId, _pin('rear.2', '02'))).apply(p.doc);
      expect(
        p.doc.ports,
        contains(was.portId),
        reason: 'the jack is still on the panel; only the cable moved',
      );
      expect(
        portConductorCount(p.doc, was.portId),
        0,
        reason: 'and it now reads as free, which is all "freed" must mean',
      );
    });

    test('the rack termination stays (§11.73.3)', () {
      // It describes how the cable END is finished, not which hole it
      // sits in, and a run can be punched onto a block this project does
      // not model. Clearing it would assert the crew undid work they may
      // never have touched.
      final p = _project();
      _land(p.doc, p.linkId);
      final origin = p.doc.links[p.linkId]!.structureOrigin!;
      SetEntityPropertyCommand<Link, TerminationType?>(
        id: p.linkId,
        field: StructureOriginField.terminationRack,
        from: origin.terminationRack,
        to: TerminationType.punchdown,
        now: _now,
        actor: 'seed',
      ).apply(p.doc);

      _ready(_move(p.doc, p.linkId, _pin('rear.2', '02'))).apply(p.doc);
      expect(
        p.doc.links[p.linkId]!.structureOrigin!.terminationRack,
        TerminationType.punchdown,
      );
    });

    test('the field label and the field termination stay', () {
      final p = _project();
      _land(p.doc, p.linkId);
      _ready(_move(p.doc, p.linkId, _pin('rear.2', '02'))).apply(p.doc);
      final origin = p.doc.links[p.linkId]!.structureOrigin!;
      expect(origin.fieldLabel, 'GR-DATA-1');
      expect(origin.terminationField, TerminationType.keystone);
    });

    test('a pin the move MINTED is un-minted by undo', () {
      // The other half of §11.73.4: only what this apply added may be
      // removed. `freePanelPositions` hands back positions that do not
      // exist as `Port` entities yet, so the target is usually minted
      // here.
      final p = _project();
      _land(p.doc, p.linkId);
      final to = _pin('rear.2', '02');
      expect(p.doc.ports.containsKey(to.portId), isFalse);

      final command = _ready(_move(p.doc, p.linkId, to));
      command.apply(p.doc);
      expect(p.doc.ports, contains(to.portId));
      command.revert(p.doc);
      expect(
        p.doc.ports.containsKey(to.portId),
        isFalse,
        reason: 'this apply created it, so this revert removes it',
      );
    });
  });

  group('the rack label follows the position (§11.73.2)', () {
    test('an ALLOCATED label is re-derived', () {
      final p = _project();
      _land(p.doc, p.linkId);
      expect(p.doc.links[p.linkId]!.structureOrigin!.rackLabel, 'PP1-01');

      final result = _move(p.doc, p.linkId, _pin('rear.2', '02'));
      expect((result as MoveEndpointReady).keptRackLabel, isNull);
      _ready(result).apply(p.doc);
      expect(
        p.doc.links[p.linkId]!.structureOrigin!.rackLabel,
        'PP1-02',
        reason:
            'a label naming the hole the cable has left is worse than no '
            'label at all',
      );
    });

    test('and undo puts the OLD label back', () {
      final p = _project();
      _land(p.doc, p.linkId);
      final command = _ready(_move(p.doc, p.linkId, _pin('rear.2', '02')));
      command.apply(p.doc);
      command.revert(p.doc);
      expect(p.doc.links[p.linkId]!.structureOrigin!.rackLabel, 'PP1-01');
    });

    test('a HAND-SET label survives, and the result says it was kept', () {
      final p = _project();
      _land(p.doc, p.linkId);
      SetRackLabelCommand(
        linkId: p.linkId,
        rackLabel: 'BY-HAND-7',
        now: _now,
        actor: 'seed',
      ).apply(p.doc);

      final result = _move(p.doc, p.linkId, _pin('rear.2', '02'));
      expect(
        (result as MoveEndpointReady).keptRackLabel,
        'BY-HAND-7',
        reason:
            'the surface has to be able to say so: a person who sees an '
            'old-looking label needs to know it survived because they '
            'typed it, not because the move half-failed',
      );

      _ready(result).apply(p.doc);
      final origin = p.doc.links[p.linkId]!.structureOrigin!;
      expect(origin.rackLabel, 'BY-HAND-7');
      expect(origin.rackLabelLocked, isTrue);
    });

    test('undoing a move that KEPT a label does not erase it', () {
      // The bug this kills: capturing `_previousRackLabel` unconditionally
      // and writing it back on revert. The capture never ran, so the
      // restore would write null over the person's own identifier.
      final p = _project();
      _land(p.doc, p.linkId);
      SetRackLabelCommand(
        linkId: p.linkId,
        rackLabel: 'BY-HAND-7',
        now: _now,
        actor: 'seed',
      ).apply(p.doc);

      final command = _ready(_move(p.doc, p.linkId, _pin('rear.2', '02')));
      command.apply(p.doc);
      command.revert(p.doc);
      expect(p.doc.links[p.linkId]!.structureOrigin!.rackLabel, 'BY-HAND-7');
    });

    test('a label that cannot render is written as ABSENT, not kept', () {
      // DR-040 §11.39.5 from the other side. `rewritesRackLabel` true with
      // a null label means the position moved and the name genuinely went
      // away; a nullable label alone could not tell that from "keep it".
      final p = _project();
      _land(p.doc, p.linkId);
      final result = _move(
        p.doc,
        p.linkId,
        _pin('rear.2', '02'),
        rackLabel: null,
      );
      _ready(result).apply(p.doc);
      expect(p.doc.links[p.linkId]!.structureOrigin!.rackLabel, isNull);
    });

    test('a FIELD-end move never touches the rack label', () {
      // The asymmetry `BindEndpointCommand` documents: a rack label is
      // derived from the panel position, and landing a speaker says
      // nothing about what the panel position is called.
      final p = _project();
      _land(p.doc, p.linkId);
      // Land the field end on a pin too, so there is something to move.
      BindEndpointCommand(
        linkId: p.linkId,
        port: _pin('rear.3', '03'),
        rackLabel: null,
        now: _now,
        actor: 'seed',
        end: LinkEnd.field,
      ).apply(p.doc);

      final result = _move(
        p.doc,
        p.linkId,
        _pin('rear.2', '02'),
        end: LinkEnd.field,
        rackLabel: 'SHOULD-NOT-APPEAR',
      );
      expect(_ready(result).rewritesRackLabel, isFalse);
      _ready(result).apply(p.doc);
      expect(p.doc.links[p.linkId]!.structureOrigin!.rackLabel, 'PP1-01');
    });
  });

  group('it refuses', () {
    test('an end that is not landed — that is a landing, not a move', () {
      final p = _project();
      final result = _move(p.doc, p.linkId, _pin('rear.2', '02'));
      expect(
        _refusal(result),
        "That drop's rack end is not landed yet, so there is nothing to "
        'move. Land it instead.',
      );
    });

    test('the pin it is ALREADY on, by name', () {
      final p = _project();
      final was = _land(p.doc, p.linkId);
      expect(
        _refusal(_move(p.doc, p.linkId, was)),
        'W001 is already landed on ${was.designator}.',
      );
    });

    test('a jack another cable is in (TOP-003)', () {
      final p = _project();
      _land(p.doc, p.linkId);

      // A second drop, landed on the pin this move will aim at.
      final other =
          (buildAddHomeRunCommand(
                    doc: p.doc,
                    outletId: p.outletId,
                    fieldLabel: 'GR-DATA-2',
                    designator: 'W002',
                    netName: 'W002',
                    media: const MediaTypeId('media.cat6_utp'),
                    fieldEnd: const PlaceEndpoint(description: 'Great Room'),
                    terminationField: TerminationType.keystone,
                    now: _now,
                    actor: 'seed',
                  )
                  as AddHomeRunReady)
              .command
            ..apply(p.doc);
      final taken = _land(
        p.doc,
        other.id,
        key: 'rear.2',
        designator: '02',
        rackLabel: 'PP1-02',
      );

      expect(
        _refusal(_move(p.doc, p.linkId, taken)),
        '${taken.designator} already has a cable landed on it. Pick a free '
        'position.',
      );
    });

    test('a cable that is not a home run', () {
      final p = _project();
      p.doc.links[const Uuid('patch-1')] = Link(
        id: const Uuid('patch-1'),
        designator: 'W900',
        media: const MediaTypeId('media.cat6_utp'),
        order: const FracIndex('a5'),
        meta: _meta(),
      );
      expect(
        _refusal(_move(p.doc, const Uuid('patch-1'), _pin('rear.2', '02'))),
        contains('is not a home run'),
      );
    });

    test('a cable that is not in this project', () {
      final p = _project();
      expect(
        _refusal(_move(p.doc, const Uuid('nope'), _pin('rear.2', '02'))),
        'That cable is not in this project.',
      );
    });

    test('a re-derived label another drop already holds (CR-113)', () {
      final p = _project();
      _land(p.doc, p.linkId);
      expect(
        _refusal(
          _move(
            p.doc,
            p.linkId,
            _pin('rear.2', '02'),
            used: {'PP1-02'},
          ),
        ),
        contains('is already used by another drop'),
      );
    });

    test('and NOT the label the moving drop itself holds', () {
      // The exclusion that makes the gesture usable: the caller passes a
      // scan without this link, or every move refuses itself.
      final p = _project();
      _land(p.doc, p.linkId);
      expect(
        _move(
          p.doc,
          p.linkId,
          _pin('rear.2', '02'),
          rackLabel: 'PP1-01',
        ),
        isA<MoveEndpointReady>(),
      );
    });
  });

  test('revert before apply names itself', () {
    final p = _project();
    _land(p.doc, p.linkId);
    expect(
      () => _ready(_move(p.doc, p.linkId, _pin('rear.2', '02'))).revert(p.doc),
      throwsA(isA<StateError>()),
    );
  });
}
