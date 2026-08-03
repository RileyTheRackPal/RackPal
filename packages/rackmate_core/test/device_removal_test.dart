// DR-013 §11.13 — deleting a wired device cascades, and undo puts the
// cables back.
//
// The four shapes the ruling names, one group each:
//
//   §11.13.1  removing a device removes every Link that terminates on it,
//             and its materialised Ports, in ONE undoable command;
//   §11.13.2  the count the dialog states is the count `apply` removes —
//             one number, one source — and a device carrying nothing
//             needs no dialog;
//   §11.13.4  undo restores the cables with the SAME ids, and
//             delete-then-undo is a byte-identical round trip;
//   §11.13.5  the TemplateSnapshot refcount half stays deferred, which is
//             a ruling and not an omission — so it is asserted as still
//             deferred rather than left ambiguous.

import 'dart:convert';

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

const _src = Uuid('dev-src');
const _sink = Uuid('dev-sink');
const _other = Uuid('dev-other');

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

TemplateBody _body(String model, int n) => TemplateBody(
  manufacturer: 'Demo',
  model: model,
  displayName: model,
  banks: [
    BankDef(key: 'io', label: 'IO', abbr: 'IO', order: const FracIndex('a0')),
  ],
  ports: [
    for (var i = 1; i <= n; i++)
      _port('p.$i', order: 'a${i.toString().padLeft(3, '0')}'),
  ],
);

void _addDevice(RackDocument doc, Uuid id, String designator, int ports) {
  final tpl = 'tpl.${id.v}';
  doc.templates['$tpl@1'] = TemplateSnapshot(
    templateId: TemplateId(tpl),
    version: 1,
    contentHash: 'sha256:$tpl',
    capturedAt: _when,
    body: _body(designator, ports),
  );
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(tpl),
      version: 1,
      contentHash: 'sha256:$tpl',
    ),
    designator: designator,
    name: designator,
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
}

/// A document with two wired devices and one untouched bystander.
///
/// The bystander is the control: every assertion about what a delete
/// removes is only meaningful beside something it must NOT remove.
({RackDocument doc, DocumentController controller}) _fixture({
  int cables = 3,
}) {
  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0+build.1',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    info: ProjectInfo(projectName: 'DR-013'),
    registries: buildSeedRegistries(),
  );
  _addDevice(doc, _src, 'SRC-1', 8);
  _addDevice(doc, _sink, 'SNK-1', 8);
  _addDevice(doc, _other, 'OTH-1', 8);

  final controller = DocumentController(
    doc,
    clock: FixedClock(_when),
  );

  for (var i = 1; i <= cables; i++) {
    final from = resolveConnectTarget(doc, deviceId: _src, portKey: 'p.$i')!;
    final to = resolveConnectTarget(doc, deviceId: _sink, portKey: 'p.$i')!;
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
  // One cable that touches NEITHER device under test.
  final a = resolveConnectTarget(doc, deviceId: _other, portKey: 'p.7')!;
  final b = resolveConnectTarget(doc, deviceId: _other, portKey: 'p.8')!;
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
    test('three cables on the device under test, one bystander, and ports '
        'materialised only where cables landed', () {
      final f = _fixture();
      expect(f.doc.links, hasLength(4));
      // DR-011.1: a port exists because a cable reached it. Three cables
      // between SRC-1 and SNK-1 is six ports, plus two on the bystander.
      expect(f.doc.ports, hasLength(8));
      expect(
        f.doc.ports.values.where((p) => p.deviceId == _src),
        hasLength(3),
      );
    });
  });

  group('§11.13.2 — the plan is the number the dialog says', () {
    test('it counts CABLES, and the cables are the ones that land on the '
        'device', () {
      final f = _fixture();
      final plan = planDeviceRemoval(f.doc, _src);
      expect(plan.cableCount, 3);
      expect(plan.needsConfirmation, isTrue);
      expect(plan.portIds, hasLength(3));
      expect(
        plan.linkIds.toSet(),
        isNot(contains(f.doc.links.entries.last.key)),
        reason: 'the bystander cable is on neither device under test',
      );
    });

    test('a device carrying nothing needs NO dialog — §11.13.2 verbatim', () {
      final f = _fixture();
      final plan = planDeviceRemoval(f.doc, _other);
      // OTH-1 carries its own bystander cable, so use a device that
      // genuinely carries none: add one.
      _addDevice(f.doc, const Uuid('dev-bare'), 'BARE-1', 4);
      final bare = planDeviceRemoval(f.doc, const Uuid('dev-bare'));
      expect(bare.cableCount, 0);
      expect(bare.needsConfirmation, isFalse);
      expect(bare.isEmpty, isFalse, reason: 'the device exists; it is idle');
      // And the control still reports its own cable.
      expect(plan.cableCount, 1);
    });

    test('a device this document does not have plans nothing, and that is '
        'not an error', () {
      final f = _fixture();
      final plan = planDeviceRemoval(f.doc, const Uuid('dev-ghost'));
      expect(plan.isEmpty, isTrue);
      expect(plan.needsConfirmation, isFalse);
    });

    test('ONE NUMBER, ONE SOURCE — apply removes exactly what the plan '
        'counted', () {
      // The clause this whole file exists for. A dialog that said "3
      // cables" and removed 4 is worse than no dialog.
      final f = _fixture();
      final plan = planDeviceRemoval(f.doc, _src);
      final before = f.doc.links.length;
      f.controller.run(RemoveDeviceCommand(id: _src));
      expect(before - f.doc.links.length, plan.cableCount);
    });
  });

  group('§11.13.1 — the cascade', () {
    test('removing a wired device removes its cables, its ports and its '
        'nets, and leaves the bystander alone', () {
      final f = _fixture();
      final bystanderId = f.doc.links.entries.last.key;

      f.controller.run(RemoveDeviceCommand(id: _src));

      expect(f.doc.devices.containsKey(_src), isFalse);
      expect(f.doc.links, hasLength(1));
      expect(f.doc.links.containsKey(bystanderId), isTrue);
      expect(
        f.doc.ports.values.where((p) => p.deviceId == _src),
        isEmpty,
        reason:
            'a Port belongs to exactly one device and that device is '
            'gone',
      );
      expect(f.doc.devices.containsKey(_sink), isTrue);
      expect(
        f.doc.ports.values.where((p) => p.deviceId == _sink),
        hasLength(3),
        reason:
            "THE FAR END'S PORTS STAY, and that is the ruling rather than "
            'an oversight. §11.13.1 removes every Link that terminates on '
            'the device "and ITS materialised Ports" — its own. A jack on '
            'a device that still exists is not a lie just because nothing '
            'is plugged into it; it is a jack. DR-011.1 makes a port '
            'appear when a cable reaches it and says nothing about '
            'un-materialising, and RemoveLinkCommand does not strip ports '
            'either — only ConnectPortsCommand.revert does, for the ones '
            'that one command minted.',
      );
    });

    test('THE DOCUMENT DOES NOT LIE — no surviving conductor names a port '
        'that is gone', () {
      // CR-017's "the gesture may hesitate; the document may not lie", and
      // the exact defect DR-013 was ruled to close: before the cascade a
      // delete left Links whose PortEndpoints named ports that no longer
      // existed, and the schedule printed a row citing a device that is
      // not in the document.
      final f = _fixture();
      f.controller.run(RemoveDeviceCommand(id: _src));

      for (final link in f.doc.links.values) {
        for (final conductor in link.conductors) {
          for (final end in [conductor.from, conductor.to]) {
            if (end is! PortEndpoint) continue;
            expect(
              f.doc.ports.containsKey(end.portId),
              isTrue,
              reason:
                  'link ${link.designator} terminates on a port the '
                  'document no longer has',
            );
          }
        }
      }
    });

    test('and the schedule has no row citing the deleted device', () {
      // The observable form of the same defect, at the surface G1 calls
      // the deliverable.
      final f = _fixture();
      expect(buildSchedule(f.doc).rows, isNotEmpty);
      f.controller.run(RemoveDeviceCommand(id: _src));
      for (final row in buildSchedule(f.doc).rows) {
        expect(row.from.deviceDesignator, isNot('SRC-1'));
        expect(row.to.deviceDesignator, isNot('SRC-1'));
      }
    });

    test('a net shared with a surviving link is NOT removed', () {
      // The asymmetry device_removal.dart's header is about: a Port
      // belongs to one device, a Net belongs to none. Deleting a net a
      // survivor still carries would leave that survivor's service
      // pointing at nothing — the same lie, arriving through the tidy-up.
      final f = _fixture();
      final bystander = f.doc.links.values.last;
      final sharedNet = bystander.services.first.netId!;

      // Point one of SRC-1's links at the bystander's net as well.
      final victim = f.doc.links.values.first;
      victim.services.add(
        Service(
          id: 'svc-shared',
          signalFamily: const SignalFamilyId('audio.analog.balanced'),
          netId: sharedNet,
        ),
      );

      f.controller.run(RemoveDeviceCommand(id: _src));
      expect(
        f.doc.nets.containsKey(sharedNet),
        isTrue,
        reason: 'the bystander still carries it',
      );
    });

    test('ONE undo entry, not one per cable', () {
      final f = _fixture();
      final depthBefore = f.controller.undo.depth;
      f.controller.run(RemoveDeviceCommand(id: _src));
      expect(f.controller.undo.depth, depthBefore + 1);
      expect(f.controller.undo.undoLabelKey, LabelKey.removeDevice.name);
    });
  });

  group('§11.13.4 — undo restores the cables, with the SAME ids', () {
    test('every link, net and port comes back under its own id', () {
      final f = _fixture();
      final linksBefore = f.doc.links.keys.toSet();
      final netsBefore = f.doc.nets.keys.toSet();
      final portsBefore = f.doc.ports.keys.toSet();

      f.controller.run(RemoveDeviceCommand(id: _src));
      expect(f.doc.links.keys.toSet(), isNot(linksBefore));

      f.controller.undo.undo(f.doc);

      expect(f.doc.links.keys.toSet(), linksBefore);
      expect(f.doc.nets.keys.toSet(), netsBefore);
      expect(f.doc.ports.keys.toSet(), portsBefore);
      expect(f.doc.devices.containsKey(_src), isTrue);
    });

    test('the designators come back too — a W number is what an installer '
        'reads off the schedule', () {
      final f = _fixture();
      final before = f.doc.links.values.map((l) => l.designator).toList()
        ..sort();
      f.controller.run(RemoveDeviceCommand(id: _src));
      f.controller.undo.undo(f.doc);
      final after = f.doc.links.values.map((l) => l.designator).toList()
        ..sort();
      expect(after, before);
    });

    test('DELETE-THEN-UNDO IS BYTE-IDENTICAL — the CR-117 property, on the '
        'gesture DR-013 §11.13.4 names', () {
      // APPLY AND REVERT DIRECTLY, which is how `command_roundtrip_test`
      // states this same property and is the only scoping that is honest.
      // Going through the controller advances `doc.sequence` — envelope
      // bookkeeping that is SUPPOSED to move, because a document that has
      // been edited and undone really is at a later state id. Comparing
      // bytes across a controller round trip would assert that the
      // envelope is untouched by an edit, which it is not, and the only
      // way to make that pass would be to stop the counter moving.
      //
      // What §11.13.4 is about is the ENTITY graph: "revert must put back
      // every Link, Service, Conductor, Net and Port that apply removed,
      // with the SAME ids."
      const codec = JsonDocumentCodec();
      final f = _fixture();
      final before = utf8.decode(codec.write(f.doc));

      final command = RemoveDeviceCommand(id: _src)..apply(f.doc);
      expect(utf8.decode(codec.write(f.doc)), isNot(before));

      command.revert(f.doc);
      expect(
        utf8.decode(codec.write(f.doc)),
        before,
        reason:
            'anything less makes delete-then-undo a lossy round trip '
            "through the one entity CR-117's byte gate is about",
      );
    });

    test('and redo takes them away again, still as one entry', () {
      final f = _fixture();
      f.controller.run(RemoveDeviceCommand(id: _src));
      final afterDelete = f.doc.links.length;
      f.controller.undo.undo(f.doc);
      f.controller.undo.redo(f.doc);
      expect(f.doc.links, hasLength(afterDelete));
      expect(f.doc.devices.containsKey(_src), isFalse);
    });

    test('deleting an UNWIRED device is still a clean round trip', () {
      const codec = JsonDocumentCodec();
      final f = _fixture();
      _addDevice(f.doc, const Uuid('dev-bare'), 'BARE-1', 4);
      final before = utf8.decode(codec.write(f.doc));
      RemoveDeviceCommand(id: const Uuid('dev-bare'))
        ..apply(f.doc)
        ..revert(f.doc);
      expect(utf8.decode(codec.write(f.doc)), before);
    });
  });

  group('§11.13.5 — what stays deferred, asserted as deferred', () {
    test('the TemplateSnapshot is NOT dropped, and that is the ruling', () {
      // Not an omission. An unreferenced snapshot is inert and AC-006's
      // lazy design already leaves them in files for devices that were
      // never placed, so it is file size rather than correctness. Pinned
      // so that building it later is a deliberate act with a test to
      // change, rather than something that quietly starts happening.
      final f = _fixture();
      final key = 'tpl.${_src.v}@1';
      expect(f.doc.templates.containsKey(key), isTrue);
      f.controller.run(RemoveDeviceCommand(id: _src));
      expect(
        f.doc.templates.containsKey(key),
        isTrue,
        reason: 'DR-013 §11.13.5 leaves the refcount half untouched',
      );
    });
  });

  group('the guard the cascade rewrote', () {
    test('reverting a delete that found nothing is a NO-OP, not a throw', () {
      // `apply` ran and there was nothing to remove — legal since the
      // cascade, because a device can now be gone for reasons other than
      // this command. It used to throw StateError out of undo, which
      // command_roundtrip_test's thousand random sequences found on the
      // first run after the cascade landed.
      final f = _fixture();
      final command = RemoveDeviceCommand(id: const Uuid('dev-ghost'))
        ..apply(f.doc);
      expect(() => command.revert(f.doc), returnsNormally);
    });

    test('but reverting BEFORE apply still throws — that is a real bug and '
        'is still loud', () {
      final f = _fixture();
      final command = RemoveDeviceCommand(id: _src);
      expect(() => command.revert(f.doc), throwsStateError);
    });
  });
}
