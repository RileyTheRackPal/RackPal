// M3-C/2, #148 — the Structure editor's table, as a row model.
//
// WHAT THESE ARE FOR. The eight default columns of docs/07 §4.1 are all
// on `ScheduleEntry` already, so the risk in this file is not that a
// column is wrong: it is that the table quietly becomes a SECOND
// derivation and drifts from the sheet. The first group is the gate on
// that, and it compares the two outputs rather than asserting either.
//
// The rest pin what the table adds and the sheet does not have: the room
// order is the TREE's, the counts are the ones the status bar prints, and
// a drop whose room was deleted still has a band to sit in.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 8);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

final class _Doc {
  _Doc()
    : doc = RackDocument(
        id: const Uuid('doc-structure-table'),
        appVersion: 'test',
        createdAt: _when,
        modifiedAt: _when,
        meta: _meta(),
      ) {
    bodyId = (AddStructureCommand(
      title: 'Rough-In',
      designator: 'STR-1',
      now: _when,
      actor: 'test',
    )..apply(doc)).bodyId;
  }

  final RackDocument doc;
  late final Uuid bodyId;
  int _seq = 0;

  Uuid room(String name, {String code = '', Len? estimate, Uuid? parentId}) =>
      (AddLocationCommand(
        name: name,
        code: code,
        // WITHIN THE PARENT. `nextLocationOrder(doc)` with no parentId
        // allocates among ROOT siblings, so three children of one node
        // would all collide on the same index and the tree's own sort
        // would fall through to the id.
        order: nextLocationOrder(doc, parentId: parentId),
        now: _when,
        actor: 'test',
        parentId: parentId,
        estimatedRunLengthFromRack: estimate,
      )..apply(doc)).id;

  Uuid outlet(String designation, {required Uuid locationId}) =>
      (AddOutletCommand(
        structureBodyId: bodyId,
        designation: designation,
        order: nextOutletOrder(doc),
        now: _when,
        actor: 'test',
        locationId: locationId,
      )..apply(doc)).id;

  /// A rack, a device in it and one port, so a drop has something real to
  /// land on. Returns the port id.
  Uuid panelPort(String designator) {
    final rackId = Uuid('rack-${_seq++}');
    doc.racks[rackId] = Rack(
      id: rackId,
      name: 'RK-1',
      designator: 'RK-1',
      heightU: 42,
      order: FracIndex('a$_seq'),
      meta: _meta(),
    );
    final deviceId = Uuid('dev-${_seq++}');
    doc.devices[deviceId] = DeviceInstance(
      id: deviceId,
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('tpl.pp'),
        version: 1,
        contentHash: 'sha256:tpl.pp',
      ),
      designator: 'PP-1',
      name: 'PP-1',
      placement: RailPlacement(rackId: rackId, ruIndex: 1, face: Face.rear),
      meta: _meta(),
    );
    final portId = Uuid('port-${_seq++}');
    doc.ports[portId] = Port(
      id: portId,
      deviceId: deviceId,
      designator: designator,
    );
    return portId;
  }

  Uuid pathway(String name) {
    final id = Uuid('path-${_seq++}');
    doc.pathways[id] = Pathway(
      id: id,
      name: name,
      order: FracIndex('a$_seq'),
      meta: _meta(),
    );
    return id;
  }
}

/// One home run on [d].
///
/// A FREE FUNCTION, not a method on the builder, for the reason
/// `schedule_test.dart` gives about its own `_link`: a test that states
/// four drops in a row would otherwise read as a cascade on a builder
/// object, which puts the punctuation where the cables should be.
///
/// [rackPort] null leaves the far end unbound, which is the ordinary
/// rough-in state (AC-018).
Uuid _drop(
  _Doc d, {
  required Uuid outletId,
  required Uuid locationId,
  required String fieldLabel,
  Uuid? rackPort,
  Uuid? pathwayId,
}) {
  d._seq++;
  final built =
      buildAddHomeRunCommand(
            doc: d.doc,
            outletId: outletId,
            fieldLabel: fieldLabel,
            designator: 'W${d._seq.toString().padLeft(3, '0')}',
            netName: 'N${d._seq.toString().padLeft(3, '0')}',
            media: const MediaTypeId('media.cat6'),
            fieldEnd: PlaceEndpoint(
              description: 'wall plate',
              locationId: locationId,
            ),
            rackEnd: rackPort == null ? null : PortEndpoint(rackPort),
            pathwayId: pathwayId,
            now: _when,
            actor: 'test',
          )
          as AddHomeRunReady;
  built.command.apply(d.doc);
  return built.command.id;
}

void main() {
  group('IT IS A PROJECTION, not a second derivation', () {
    test('every cell comes off the same ScheduleEntry the sheet uses', () {
      // The gate. CR-107 deleted `StructureDrop` because two entities
      // carrying the same facts diverge within a week of real use; a
      // table that computed its own media name and its own termination
      // would be that divergence one layer up, on the surface people
      // trust most because they are typing into it.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: o, locationId: lr, fieldLabel: 'LR-TV-1');

      final table = buildStructureTable(d.doc).groups.single.rows.single;
      final sheet = buildSchedule(d.doc).rows.single;

      // docs/07 §4.1's eight default columns, one by one. Value equality
      // rather than `identical`, because two builds of a pure derivation
      // are two object graphs; what must not diverge is what they SAY.
      expect(table.linkId, sheet.linkId);
      expect(table.fieldLabel, sheet.fieldLabel);
      expect(table.rackLabel, sheet.rackLabel);
      expect(table.outletDesignation, sheet.outletDesignation);
      expect(table.media, sheet.media);
      expect(table.signalFamily, sheet.signalFamily);
      expect(table.pathwayName, sheet.pathwayName);
      expect(table.terminationType, sheet.terminationType);
      expect(table.roughInStatus, sheet.roughInStatus);
    });

    test('and it keeps rows a Pull Sheet preset would drop', () {
      // `buildSchedule` is total, one row per Link. An editor that hid a
      // row would let somebody delete a room's last drop and see nothing
      // change.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: o, locationId: lr, fieldLabel: 'LR-TV-1');

      final table = buildStructureTable(d.doc);
      final pullSheet = scheduleViewOf(
        d.doc,
        preset: SchedulePreset.pullSheet,
      );
      expect(table.dropCount, greaterThanOrEqualTo(pullSheet.rows.length));
      expect(table.dropCount, 1);
    });

    test('a link that is not a home run is not on this table at all', () {
      // The table is the Structure body's, and an ordinary rack-to-rack
      // patch cable has no `structureOrigin`.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: o, locationId: lr, fieldLabel: 'LR-TV-1');
      AddLinkCommand(
        designator: 'W900',
        netName: 'N900',
        media: const MediaTypeId('media.cat6'),
        order: nextLinkOrder(d.doc),
        now: _when,
        actor: 'test',
      ).apply(d.doc);

      expect(buildSchedule(d.doc).rows, hasLength(2));
      expect(buildStructureTable(d.doc).dropCount, 1);
    });

    test('and a second Structure body can be asked for on its own', () {
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: o, locationId: lr, fieldLabel: 'LR-TV-1');
      final second = AddStructureCommand(
        title: 'Exterior',
        designator: 'STR-2',
        now: _when,
        actor: 'test',
      )..apply(d.doc);

      expect(buildStructureTable(d.doc).dropCount, 1);
      expect(
        buildStructureTable(d.doc, structureBodyId: second.bodyId).dropCount,
        0,
      );
      expect(
        buildStructureTable(d.doc, structureBodyId: d.bodyId).dropCount,
        1,
      );
    });
  });

  group("the room order is the TREE's, not the sheet's sort", () {
    test('rooms come out in tree order, parents before children', () {
      // The table sits beside the location tree in docs/07 §4. Two panels
      // disagreeing about which room is third is the kind of defect
      // nobody reports and everybody distrusts.
      final d = _Doc();
      final house = d.room('123 Oak St');
      final level1 = d.room('Level 1', parentId: house);
      final kitchen = d.room('Kitchen', code: 'KIT', parentId: level1);
      final living = d.room('Living Room', code: 'LR', parentId: level1);
      final attic = d.room('Attic', code: 'ATT', parentId: house);

      // Created in an order that is NOT the tree order, so a `Map`
      // iteration would come out differently.
      for (final (room, label) in [
        (attic, 'ATT-TV-1'),
        (living, 'LR-TV-1'),
        (kitchen, 'KIT-TV-1'),
      ]) {
        _drop(
          d,
          outletId: d.outlet('$label-o', locationId: room),
          locationId: room,
          fieldLabel: label,
        );
      }

      expect(
        buildStructureTable(d.doc).groups.map((g) => g.title),
        ['Kitchen', 'Living Room', 'Attic'],
      );
    });

    test('a room with no drops gets no band', () {
      // The tree beside the table lists every room. An empty band each
      // would push the drops off the screen in a project with forty.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      d.room('Kitchen', code: 'KIT');
      _drop(
        d,
        outletId: d.outlet('LR-1', locationId: lr),
        locationId: lr,
        fieldLabel: 'LR-TV-1',
      );

      expect(buildStructureTable(d.doc).groups, hasLength(1));
    });

    test('the group carries the room code and estimate the header prints', () {
      final d = _Doc();
      final lr = d.room(
        'Living Room',
        code: 'LR',
        estimate: const Len(62 * 304800000),
      );
      _drop(
        d,
        outletId: d.outlet('LR-1', locationId: lr),
        locationId: lr,
        fieldLabel: 'LR-TV-1',
      );

      final group = buildStructureTable(d.doc).groups.single;
      expect(group.code, 'LR');
      expect(group.estimatedRunLength, const Len(62 * 304800000));
      expect(group.dropCount, 1);
    });

    test('a room with no estimate reports UNKNOWN, not zero', () {
      // G4/CR-114: a room nobody has paced out is not a room at zero
      // feet, and the header must not print one.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      _drop(
        d,
        outletId: d.outlet('LR-1', locationId: lr),
        locationId: lr,
        fieldLabel: 'LR-TV-1',
      );

      expect(
        buildStructureTable(d.doc).groups.single.estimatedRunLength,
        isNull,
      );
    });

    test('a room with no code reports empty, which is a real state', () {
      // M3-B creates rooms without codes on purpose: a room created by
      // hand is being named, not labelled.
      final d = _Doc();
      final attic = d.room('Attic');
      _drop(
        d,
        outletId: d.outlet('A-1', locationId: attic),
        locationId: attic,
        fieldLabel: 'W-1',
      );

      expect(buildStructureTable(d.doc).groups.single.code, '');
    });
  });

  group('the counts the status bar prints', () {
    test('drops, connected and spare, per room and in total', () {
      // docs/07 §4's own status line: `52 drops · 41 connected · 11 spare`.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final kit = d.room('Kitchen', code: 'KIT');
      final lrOutlet = d.outlet('LR-1', locationId: lr);
      final kitOutlet = d.outlet('KIT-1', locationId: kit);

      _drop(
        d,
        outletId: lrOutlet,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
        rackPort: d.panelPort('A01'),
      );
      _drop(d, outletId: lrOutlet, locationId: lr, fieldLabel: 'LR-TV-2');
      _drop(d, outletId: kitOutlet, locationId: kit, fieldLabel: 'KIT-AP-1');

      final table = buildStructureTable(d.doc);
      expect(table.dropCount, 3);
      expect(table.connectedCount, 1);
      expect(table.spareCount, 2);

      final rooms = {for (final g in table.groups) g.title: g};
      expect(rooms['Living Room']!.connectedCount, 1);
      expect(rooms['Living Room']!.spareCount, 1);
      expect(rooms['Kitchen']!.connectedCount, 0);
      expect(rooms['Kitchen']!.spareCount, 1);
    });

    test('an UNBOUND far end is spare, which is the rough-in state', () {
      // AC-018: fourteen of the exit criterion's sixty drops have one.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      _drop(
        d,
        outletId: d.outlet('LR-1', locationId: lr),
        locationId: lr,
        fieldLabel: 'LR-TV-1',
      );

      final table = buildStructureTable(d.doc);
      expect(table.connectedCount, 0);
      expect(table.spareCount, 1);
      expect(table.hasUnresolvedEnds, isFalse);
    });

    test('outlets counts the ones WITH drops, not every outlet', () {
      // "9 outlets" beside "52 drops" means the plates these cables land
      // on. An outlet somebody created and has not pulled to is real, and
      // it is not what that number says.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final used = d.outlet('LR-1', locationId: lr);
      d.outlet('LR-2', locationId: lr);
      _drop(d, outletId: used, locationId: lr, fieldLabel: 'LR-TV-1');
      _drop(d, outletId: used, locationId: lr, fieldLabel: 'LR-TV-2');

      expect(d.doc.outlets, hasLength(2));
      expect(buildStructureTable(d.doc).outletCount, 1);
    });

    test('pathways likewise, and a drop in none costs nothing', () {
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      final run = d.pathway('PW-LR-1');
      d.pathway('PW-LR-2');
      _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
        pathwayId: run,
      );
      _drop(d, outletId: o, locationId: lr, fieldLabel: 'LR-TV-2');

      expect(d.doc.pathways, hasLength(2));
      expect(buildStructureTable(d.doc).pathwayCount, 1);
    });

    test('AN UNRESOLVED PORT IS NEITHER, and the table says so', () {
      // A `PortEndpoint` naming a port this document does not hold is a
      // FAULT, not a state. Counting it connected reports work nobody can
      // trace; counting it spare invites a second cable onto the same
      // panel port. So it is in neither, and `drops != connected + spare`
      // is the signal.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      _drop(
        d,
        outletId: d.outlet('LR-1', locationId: lr),
        locationId: lr,
        fieldLabel: 'LR-TV-1',
        rackPort: const Uuid('port-that-is-not-here'),
      );

      final table = buildStructureTable(d.doc);
      expect(table.dropCount, 1);
      expect(table.connectedCount, 0);
      expect(table.hasUnresolvedEnds, isTrue);
    });
  });

  group('a drop whose room is gone still has a band (DR-021)', () {
    test('it lands in NO ROOM RECORDED rather than vanishing', () {
      // DR-021 §11.20 in its own words: a cleared drop "lands in the Pull
      // Sheet's `NO ROOM RECORDED` band instead of vanishing". The editor
      // owes the same, more so — this is the surface somebody would use
      // to put it back.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: o, locationId: lr, fieldLabel: 'LR-TV-1');
      _drop(d, outletId: o, locationId: lr, fieldLabel: 'LR-TV-2');

      RemoveLocationCommand(
        plan: planLocationRemoval(d.doc, lr),
      ).apply(d.doc);

      final table = buildStructureTable(d.doc);
      expect(table.dropCount, 2);
      expect(table.groups.single.title, kUngroupedTitle);
      expect(table.groups.single.locationId, isNull);
    });

    test('and the band is LAST, after every room', () {
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final kit = d.room('Kitchen', code: 'KIT');
      _drop(
        d,
        outletId: d.outlet('LR-1', locationId: lr),
        locationId: lr,
        fieldLabel: 'LR-TV-1',
      );
      _drop(
        d,
        outletId: d.outlet('KIT-1', locationId: kit),
        locationId: kit,
        fieldLabel: 'KIT-AP-1',
      );

      RemoveLocationCommand(
        plan: planLocationRemoval(d.doc, lr),
      ).apply(d.doc);

      expect(
        buildStructureTable(d.doc).groups.map((g) => g.title),
        ['Kitchen', kUngroupedTitle],
      );
    });
  });

  group('it mutates nothing and is stable', () {
    test('two builds of an unmodified document are identical', () {
      // A widget rebuilds this on every frame.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      for (var i = 1; i <= 4; i++) {
        _drop(d, outletId: o, locationId: lr, fieldLabel: 'LR-TV-$i');
      }

      final a = buildStructureTable(d.doc);
      final b = buildStructureTable(d.doc);

      expect(a.groups.map((g) => g.title), b.groups.map((g) => g.title));
      expect(
        a.groups.single.rows.map((r) => r.designator),
        b.groups.single.rows.map((r) => r.designator),
      );
      expect(a.dropCount, b.dropCount);
    });

    test('an empty project is an empty table, not a crash', () {
      expect(buildStructureTable(_Doc().doc).groups, isEmpty);
      expect(buildStructureTable(_Doc().doc).dropCount, 0);
    });
  });
}
