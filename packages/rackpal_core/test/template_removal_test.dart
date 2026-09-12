// DR-158 §11.157 — a template is removed from a project as a whole, and
// it takes the devices standing on it.
//
// Five clauses, one group each:
//
//   §11.157.1  it is a DOCUMENT edit, so one undo puts all of it back;
//   §11.157.2  the unit is the template ID: every version goes, and a
//              row cannot come back at the previous version;
//   §11.157.3  project-authored only, and a seeded id refuses BY NAME;
//   §11.157.4  the devices go with it, and they take their cables;
//   §11.157.5  an unused template is STILL asked about, which is where
//              this departs from the other three removal plans.

import 'dart:convert';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 9, 12);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

/// The template under test, authored in this project.
const _mine = TemplateId('tpl.mine');

/// A second authored template, the control: nothing asserted about what
/// goes is meaningful beside something that must stay.
const _other = TemplateId('tpl.other');

/// One of the 48 the build ships. Read from the catalog rather than
/// spelled, so a renamed archetype fails here rather than silently
/// turning this into a test about an id nobody ships.
final TemplateId _seeded = TemplateId(kSeedCatalogIds.first);

PortDef _port(String key, {required String order}) => PortDef(
  key: PortKey(key),
  label: key,
  connector: const ConnectorTypeId('conn.xlr3'),
  signalFamily: const SignalFamilyId('audio.analog.balanced'),
  face: Face.rear,
  position: _pos,
  order: FracIndex(order),
  bankKey: 'io',
);

TemplateBody _body(String name, {int ports = 8}) => TemplateBody(
  manufacturer: 'Demo',
  model: name,
  displayName: name,
  banks: [
    BankDef(key: 'io', label: 'IO', abbr: 'IO', order: const FracIndex('a0')),
  ],
  ports: [
    for (var i = 1; i <= ports; i++)
      _port('p.$i', order: 'a${i.toString().padLeft(3, '0')}'),
  ],
);

void _snapshot(RackDocument doc, TemplateId id, int version) {
  doc.templates[templateSnapshotKey(id, version)] = TemplateSnapshot(
    templateId: id,
    version: version,
    contentHash: 'sha256:${id.v}@$version',
    capturedAt: _when,
    body: _body('${id.v} v$version'),
  );
}

void _device(
  RackDocument doc,
  Uuid deviceId,
  TemplateId templateId, {
  int version = 1,
}) {
  doc.devices[deviceId] = DeviceInstance(
    id: deviceId,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: templateId,
      version: version,
      contentHash: 'sha256:${templateId.v}@$version',
    ),
    designator: deviceId.v.toUpperCase(),
    name: deviceId.v,
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
}

/// Two authored templates, `tpl.mine` at three versions, two devices on
/// it wired to each other, and one device on `tpl.other` that must
/// survive everything.
({RackDocument doc, DocumentController controller}) _fixture({
  int cables = 3,
  int devicesOnMine = 2,
}) {
  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0+build.1',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    info: ProjectInfo(projectName: 'DR-158'),
    registries: buildSeedRegistries(),
  );

  // THREE VERSIONS, which is the shape §11.157.2 is about: CR-050 forks
  // rather than mutating, so an edited template leaves earlier snapshots
  // in the file and removing only the newest would make the palette row
  // come back at v2.
  _snapshot(doc, _mine, 1);
  _snapshot(doc, _mine, 2);
  _snapshot(doc, _mine, 3);
  _snapshot(doc, _other, 1);
  _snapshot(doc, _seeded, 1);

  // Placed at DIFFERENT versions, because that is legal and because a
  // count that split by version would miss one of them.
  // dev-a takes the default, which is v1; dev-b is explicitly v3.
  if (devicesOnMine > 0) _device(doc, const Uuid('dev-a'), _mine);
  if (devicesOnMine > 1) _device(doc, const Uuid('dev-b'), _mine, version: 3);
  _device(doc, const Uuid('dev-keep'), _other);

  final controller = DocumentController(doc, clock: FixedClock(_when));

  if (devicesOnMine > 1) {
    for (var i = 1; i <= cables; i++) {
      final from = resolveConnectTarget(
        doc,
        deviceId: const Uuid('dev-a'),
        portKey: 'p.$i',
      )!;
      final to = resolveConnectTarget(
        doc,
        deviceId: const Uuid('dev-b'),
        portKey: 'p.$i',
      )!;
      final built = buildConnectPortsCommand(
        doc: doc,
        from: from,
        to: to,
        media: const MediaTypeId('media.cat6'),
        now: _when,
        actor: 'test',
      );
      controller.run((built as ConnectPortsReady).command);
    }
  }

  // One cable on the survivor, which must still be there at the end.
  final a = resolveConnectTarget(
    doc,
    deviceId: const Uuid('dev-keep'),
    portKey: 'p.7',
  )!;
  final b = resolveConnectTarget(
    doc,
    deviceId: const Uuid('dev-keep'),
    portKey: 'p.8',
  )!;
  final bystander = buildConnectPortsCommand(
    doc: doc,
    from: a,
    to: b,
    media: const MediaTypeId('media.cat6'),
    now: _when,
    actor: 'test',
  );
  controller.run((bystander as ConnectPortsReady).command);

  return (doc: doc, controller: controller);
}

void main() {
  group('the fixture is what these tests think it is', () {
    test('three versions of the template under test, two devices on it at '
        'two different versions, and a survivor', () {
      final f = _fixture();
      expect(f.doc.templates.keys, contains('tpl.mine@1'));
      expect(f.doc.templates.keys, contains('tpl.mine@3'));
      expect(f.doc.devices, hasLength(3));
      expect(f.doc.links, hasLength(4));
      expect(
        f.doc.devices[const Uuid('dev-b')]!.templateRef.version,
        3,
        reason: 'placed at a later version than dev-a, which is legal',
      );
    });
  });

  group('§11.157.2 — the unit is the template ID, every version', () {
    test('the plan names every snapshot, newest first', () {
      final plan = planTemplateRemoval(_fixture().doc, _mine);
      expect(plan.snapshotKeys, ['tpl.mine@3', 'tpl.mine@2', 'tpl.mine@1']);
      expect(plan.snapshotCount, 3);
    });

    test('and the command takes all three, leaving the other template '
        'untouched', () {
      final f = _fixture();
      f.controller.transact(
        LabelKey.removeTemplateFromProject,
        (tx) => addTemplateRemoval(tx, planTemplateRemoval(f.doc, _mine)),
      );

      expect(
        f.doc.templates.keys.where((k) => k.startsWith('tpl.mine@')),
        isEmpty,
        reason:
            'removing only the newest would make the palette row come '
            'back at v2, which is the one behaviour §11.157.2 forbids',
      );
      expect(f.doc.templates.keys, contains('tpl.other@1'));
    });
  });

  group('§11.157.3 — project-authored only', () {
    test('a SEEDED id refuses by name, and the plan says which name', () {
      final plan = planTemplateRemoval(_fixture().doc, _seeded);
      expect(plan.refusal, TemplateRemovalRefusal.seeded);
      expect(plan.isRemovable, isFalse);
    });

    test('an id this document does not hold refuses DIFFERENTLY', () {
      final plan = planTemplateRemoval(
        _fixture().doc,
        const TemplateId('tpl.never-existed'),
      );
      expect(plan.refusal, TemplateRemovalRefusal.notInProject);
    });

    test('and a refusing plan writes NOTHING, which is the second guard', () {
      final f = _fixture();
      final before = f.doc.templates.length;
      final depth = f.controller.undo.depth;
      final changed = f.controller.transact(
        LabelKey.removeTemplateFromProject,
        (tx) => addTemplateRemoval(tx, planTemplateRemoval(f.doc, _seeded)),
      );

      expect(changed, isFalse);
      expect(f.doc.templates, hasLength(before));
      expect(
        f.controller.undo.depth,
        depth,
        reason: 'an empty transaction leaves no undo entry (DR-156)',
      );
    });
  });

  group('§11.157.4 — the devices go with it, and take their cables', () {
    test('the plan counts devices and cables in their own units', () {
      final plan = planTemplateRemoval(_fixture().doc, _mine);
      expect(plan.deviceCount, 2);
      expect(
        plan.cableCount,
        3,
        reason:
            'the three cables run BETWEEN the two departing devices, so '
            'they are one union of three and not a sum of six (`#873`)',
      );
      expect(plan.takesDevices, isTrue);
    });

    test('and the edit removes exactly what the plan counted', () {
      final f = _fixture();
      final plan = planTemplateRemoval(f.doc, _mine);
      f.controller.transact(
        LabelKey.removeTemplateFromProject,
        (tx) => addTemplateRemoval(tx, plan),
      );

      expect(f.doc.devices.containsKey(const Uuid('dev-a')), isFalse);
      expect(f.doc.devices.containsKey(const Uuid('dev-b')), isFalse);
      expect(
        f.doc.devices.containsKey(const Uuid('dev-keep')),
        isTrue,
        reason: 'it stands on tpl.other and nothing asked about that',
      );
      expect(
        f.doc.links,
        hasLength(1),
        reason: "3 of 4 go; the survivor's own cable stays",
      );
    });

    test('no surviving device is left resolving a template that is gone, '
        'which is what CR-054 forbids', () {
      final f = _fixture();
      f.controller.transact(
        LabelKey.removeTemplateFromProject,
        (tx) => addTemplateRemoval(tx, planTemplateRemoval(f.doc, _mine)),
      );

      for (final device in f.doc.devices.values) {
        final ref = device.templateRef;
        expect(
          f.doc.templates[templateSnapshotKey(ref.templateId, ref.version)],
          isNotNull,
          reason: '${device.designator} resolves nothing',
        );
      }
    });
  });

  group('§11.157.5 — an unused template is STILL asked about', () {
    test('needsConfirmation is true with no devices standing on it', () {
      final f = _fixture(devicesOnMine: 0);
      final plan = planTemplateRemoval(f.doc, _mine);

      expect(plan.deviceCount, 0);
      expect(plan.takesDevices, isFalse);
      expect(
        plan.needsConfirmation,
        isTrue,
        reason:
            'authoring a template is work that exists nowhere else in '
            'the project, so this is not the consequence-free delete '
            'DR-013 §11.13.2 exempts',
      );
    });

    test('but a REFUSING plan has nothing to ask about', () {
      final plan = planTemplateRemoval(_fixture().doc, _seeded);
      expect(plan.needsConfirmation, isFalse);
    });
  });

  group('§11.157.1 — it is a document edit, so ONE undo puts it all back', () {
    test('undo restores the template, the devices, the ports and the '
        'cables, as one entry', () {
      final f = _fixture();
      final templatesBefore = f.doc.templates.keys.toSet();
      final devicesBefore = f.doc.devices.keys.toSet();
      final linksBefore = f.doc.links.keys.toSet();
      final portsBefore = f.doc.ports.keys.toSet();
      // The fixture wires four cables through the controller, so the
      // stack is not empty to start with. What is asserted is that this
      // gesture added exactly ONE entry and undoing it took exactly one.
      final depthBefore = f.controller.undo.depth;

      f.controller.transact(
        LabelKey.removeTemplateFromProject,
        (tx) => addTemplateRemoval(tx, planTemplateRemoval(f.doc, _mine)),
      );
      expect(f.doc.devices.keys.toSet(), isNot(devicesBefore));
      expect(f.controller.undo.depth, depthBefore + 1);

      f.controller.undoLast();

      expect(f.doc.templates.keys.toSet(), templatesBefore);
      expect(f.doc.devices.keys.toSet(), devicesBefore);
      expect(
        f.doc.links.keys.toSet(),
        linksBefore,
        reason: 'THE SAME ids, not equivalent objects (§11.13.4)',
      );
      expect(f.doc.ports.keys.toSet(), portsBefore);
      expect(
        f.controller.undo.depth,
        depthBefore,
        reason: 'one transaction, so one entry to take back',
      );
    });

    test('and the round trip is BYTE-identical, which is CR-117', () {
      // APPLIED AND REVERTED DIRECTLY, on `device_removal_test`'s note:
      // a controller round trip advances `doc.sequence`, which is
      // envelope bookkeeping that is SUPPOSED to move. What is asserted
      // here is the entity graph.
      const codec = JsonDocumentCodec();
      final f = _fixture();
      final before = utf8.decode(codec.write(f.doc));

      final children = <Command<RackDocument>>[];
      addTemplateRemoval(
        TxnScope<RackDocument>(children, f.doc),
        planTemplateRemoval(f.doc, _mine),
      );
      Transaction<RackDocument>(
        LabelKey.removeTemplateFromProject,
        children,
        null,
        null,
      ).revert(f.doc);

      expect(
        utf8.decode(codec.write(f.doc)),
        before,
        reason:
            'a TemplateSnapshot carries a contentHash every TemplateRef '
            'compares against, so anything but the same object makes '
            'delete-then-undo lossy',
      );
    });

    test('redo takes it away again', () {
      final f = _fixture();
      f.controller.transact(
        LabelKey.removeTemplateFromProject,
        (tx) => addTemplateRemoval(tx, planTemplateRemoval(f.doc, _mine)),
      );
      f.controller.undoLast();
      f.controller.redoLast();

      expect(f.doc.templates.keys, isNot(contains('tpl.mine@1')));
      expect(f.doc.devices.containsKey(const Uuid('dev-a')), isFalse);
      expect(f.doc.devices.containsKey(const Uuid('dev-keep')), isTrue);
    });
  });

  group('the command on its own, and the guard it keeps', () {
    test('removing a template the document does not hold is a NO-OP that '
        'says so', () {
      final f = _fixture();
      final command = RemoveTemplateCommand(
        templateId: const TemplateId('tpl.never-existed'),
      );
      expect(command.apply(f.doc), isFalse);
    });

    test('and reverting BEFORE apply still throws, which is a real bug '
        'staying loud', () {
      final command = RemoveTemplateCommand(templateId: _mine);
      expect(() => command.revert(_fixture().doc), throwsStateError);
    });

    test('the label is its own and not removeDevice', () {
      expect(
        RemoveTemplateCommand(templateId: _mine).label,
        LabelKey.removeTemplateFromProject,
        reason:
            '"Undo Delete Device" after a template removal names one '
            'consequence of the act instead of the act',
      );
    });
  });
}
