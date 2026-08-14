// commands/structure_commands.dart — board M3-A/1.
//
// THE PROPERTY THAT MATTERS HERE IS NOT "IT ADDS A THING". It is the three
// `Command` contract properties from command.dart, because the reason this
// file exists is that `StructureBody` and `Outlet` round-tripped for a
// whole milestone without anything being able to create one, and a command
// that creates but does not cleanly revert just moves the defect.
//
//   * `apply; revert` returns the document to its prior state.
//   * `apply; revert; apply` lands identically to a single `apply` (redo).
//   * Redo recreates the IDENTICAL entity, same ids, because anything
//     stacked on top of it must still resolve.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 8, 6);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-structure'),
  appVersion: '0.1.0',
  createdAt: _now,
  modifiedAt: _now,
  meta: _meta(),
);

AddStructureCommand _addStructure({String title = 'Rough-In'}) =>
    AddStructureCommand(
      title: title,
      designator: 'STR-1',
      now: _now,
      actor: 'test',
      enclosureModel: 'Generic 42 in structured media enclosure',
    );

AddOutletCommand _addOutlet(Uuid bodyId, {String designation = 'GR-TV-1'}) =>
    AddOutletCommand(
      structureBodyId: bodyId,
      designation: designation,
      order: const FracIndex('a0'),
      now: _now,
      actor: 'test',
    );

void main() {
  group('AddStructureCommand creates the device and the body as ONE unit', () {
    test('both halves land, and they point at each other', () {
      final doc = _doc();
      final cmd = _addStructure()..apply(doc);

      final device = doc.devices[cmd.deviceId]!;
      final body = doc.structures[cmd.bodyId]!;

      // The pairing is what makes either half valid. A body whose deviceId
      // resolves to nothing fails the starters' own referential check.
      expect(device.structureBodyId, cmd.bodyId);
      expect(body.deviceId, cmd.deviceId);
      expect(device.kind, DeviceKind.structure);
    });

    test('the device names the RESERVED template ref the starters use', () {
      // Spelled once, in the command, so the app's structure devices cannot
      // drift from the shipped ones and start failing a check the starters
      // pass. CR-054 says a ref always resolves; docs/07 §2 gives this one
      // kind no template, and starter_integrity.dart exempts exactly it.
      final doc = _doc();
      final cmd = _addStructure()..apply(doc);

      expect(doc.devices[cmd.deviceId]!.templateRef, kStructureTemplateRef);
      expect(doc.templates.containsKey('structure@1'), isFalse);
    });

    test('it is placed OFF-RACK, not staged', () {
      // A Structure body is the building side of the job. It is not waiting
      // to be racked, so the Staging Bin (CR-032) is the wrong home.
      final doc = _doc();
      final cmd = _addStructure()..apply(doc);

      expect(doc.devices[cmd.deviceId]!.placement, isA<OffRackPlacement>());
    });

    test('revert removes exactly what apply added', () {
      final doc = _doc();
      _addStructure()
        ..apply(doc)
        ..revert(doc);

      expect(doc.devices, isEmpty);
      expect(doc.structures, isEmpty);
    });

    test('redo recreates the IDENTICAL pair, same ids', () {
      // The whole reason ids are minted in the constructor. An Outlet or a
      // Link.structureOrigin stacked on top of this must still resolve
      // after an undo/redo.
      final doc = _doc();
      final cmd = _addStructure()..apply(doc);
      final deviceId = cmd.deviceId;
      final bodyId = cmd.bodyId;

      cmd
        ..revert(doc)
        ..apply(doc);

      expect(cmd.deviceId, deviceId);
      expect(cmd.bodyId, bodyId);
      expect(doc.devices.keys, [deviceId]);
      expect(doc.structures.keys, [bodyId]);
    });
  });

  group('RemoveStructureCommand', () {
    test('takes both halves and puts both back', () {
      final doc = _doc();
      final add = _addStructure()..apply(doc);

      final remove = RemoveStructureCommand(bodyId: add.bodyId)..apply(doc);
      expect(doc.structures, isEmpty);
      expect(doc.devices, isEmpty);

      remove.revert(doc);
      expect(doc.structures[add.bodyId]!.deviceId, add.deviceId);
      expect(doc.devices[add.deviceId]!.structureBodyId, add.bodyId);
    });

    test('restores the SAME objects, not equivalents', () {
      // Undo must not be a lossy round trip through the entity CR-117's
      // byte gate is about.
      final doc = _doc();
      final add = _addStructure()..apply(doc);
      final body = doc.structures[add.bodyId];
      final device = doc.devices[add.deviceId];

      RemoveStructureCommand(bodyId: add.bodyId)
        ..apply(doc)
        ..revert(doc);

      expect(identical(doc.structures[add.bodyId], body), isTrue);
      expect(identical(doc.devices[add.deviceId], device), isTrue);
    });

    test('does NOT cascade to outlets', () {
      // An Outlet is a fact about the BUILDING and survives the panel it
      // currently feeds. A caller that means both composes a Transaction.
      final doc = _doc();
      final add = _addStructure()..apply(doc);
      final outlet = _addOutlet(add.bodyId)..apply(doc);

      RemoveStructureCommand(bodyId: add.bodyId).apply(doc);

      expect(doc.outlets[outlet.id], isNotNull);
    });

    test('revert before apply throws; apply over a missing body does not', () {
      final doc = _doc();
      expect(
        () => RemoveStructureCommand(bodyId: const Uuid('nope')).revert(doc),
        throwsStateError,
      );

      // "Apply ran and it was already gone" is a legal outcome.
      RemoveStructureCommand(bodyId: const Uuid('nope'))
        ..apply(doc)
        ..revert(doc);
      expect(doc.structures, isEmpty);
    });
  });

  group('AddOutletCommand / RemoveOutletCommand', () {
    test('the outlet lands on its body and reverts cleanly', () {
      final doc = _doc();
      final add = _addStructure()..apply(doc);
      final cmd = _addOutlet(add.bodyId)..apply(doc);

      expect(doc.outlets[cmd.id]!.structureBodyId, add.bodyId);
      expect(doc.outlets[cmd.id]!.designation, 'GR-TV-1');

      cmd.revert(doc);
      expect(doc.outlets, isEmpty);
    });

    test('every unmeasured field stays NULL, never a fabricated zero', () {
      // G4/CR-114 at the point of creation: a caller who has not measured a
      // run length is telling us they do not have one, and defaulting it to
      // zero here would invent the measurement the rollup then reports.
      final doc = _doc();
      final add = _addStructure()..apply(doc);
      final cmd = _addOutlet(add.bodyId)..apply(doc);
      final outlet = doc.outlets[cmd.id]!;

      expect(outlet.nominalRunLength, isNull);
      expect(outlet.mountHeightAff, isNull);
      expect(outlet.floorNumber, isNull);
      expect(outlet.locationId, isNull);
      expect(outlet.pathwayId, isNull);
      expect(outlet.tia570Grade, isNull);
    });

    test('remove restores the same object', () {
      final doc = _doc();
      final add = _addStructure()..apply(doc);
      final cmd = _addOutlet(add.bodyId)..apply(doc);
      final outlet = doc.outlets[cmd.id];

      RemoveOutletCommand(id: cmd.id)
        ..apply(doc)
        ..revert(doc);

      expect(identical(doc.outlets[cmd.id], outlet), isTrue);
    });

    test('nextOutletOrder allocates strictly increasing orders', () {
      // Outlets, like racks and links, go through `nextOrder`. Locations
      // having NO creating command is exactly why their `order` could
      // collide in a decoded document; nothing this file creates repeats
      // that.
      final doc = _doc();
      final add = _addStructure()..apply(doc);

      final orders = <String>[];
      for (var i = 0; i < 4; i++) {
        final order = nextOutletOrder(doc);
        orders.add(order.v);
        AddOutletCommand(
          structureBodyId: add.bodyId,
          designation: 'GR-TV-$i',
          order: order,
          now: _now,
          actor: 'test',
        ).apply(doc);
      }

      expect(orders, orders.toList()..sort());
      expect(orders.toSet(), hasLength(4));
    });
  });

  group('the contract every command in this file owes', () {
    test('apply; revert; apply lands identically to one apply', () {
      final doc = _doc();
      final add = _addStructure()..apply(doc);
      final outlet = _addOutlet(add.bodyId)..apply(doc);

      final once = const JsonDocumentCodec().write(doc);

      add.revert(doc);
      outlet.revert(doc);
      add.apply(doc);
      outlet.apply(doc);

      expect(const JsonDocumentCodec().write(doc), once);
    });

    test('every command declares the structure epoch and its own label', () {
      final add = _addStructure();
      final outlet = _addOutlet(add.bodyId);

      for (final cmd in <Command<RackDocument>>[
        add,
        outlet,
        RemoveStructureCommand(bodyId: add.bodyId),
        RemoveOutletCommand(id: outlet.id),
      ]) {
        expect(
          // `?.` rather than `!`: `touches` is nullable since M4-A and a
          // document command returning null is exactly the defect this
          // assertion exists to catch — null fails `isTrue` with the
          // reason below, which is the right answer either way.
          cmd.touches?.has(EpochMask.structure),
          isTrue,
          reason:
              '${cmd.runtimeType} must bump the structure epoch, or the '
              'canvas will not rebuild after it runs',
        );
        expect(cmd.affects, isNotEmpty, reason: '${cmd.runtimeType}');
      }

      expect(add.label, LabelKey.addStructure);
      expect(outlet.label, LabelKey.addOutlet);
    });
  });
}
