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
  /// [templatePortKey] TIES THE MATERIALISED PORT TO A `PortDef`, which is
  /// what makes `freePanelPositions` see the position as OCCUPIED.
  ///
  /// It defaults to null because every caller before `#779` wanted only a
  /// port to hang a link off, and null is what they got.
  ///
  /// THE ID HAS TO BE THE DERIVED ONE OR THE PORT IS UNREACHABLE.
  /// `resolveConnectTarget` does not look a port up by its
  /// `templatePortKey`; it computes `derivePortId(deviceId, def.key)` and
  /// asks `doc.ports` for that. A port materialised under any other id is
  /// therefore invisible to every occupancy check in the project, so a
  /// test that bound a conductor to one and then asked which positions
  /// were free was told ALL of them. That is how a `#779` test passed and
  /// went on passing when the line it defended was deleted.
  Uuid panelPort(String designator, {String? templatePortKey}) {
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
    final key = templatePortKey == null ? null : PortKey(templatePortKey);
    final portId = key == null
        ? Uuid('port-${_seq++}')
        : derivePortId(deviceId, key);
    doc.ports[portId] = Port(
      id: portId,
      deviceId: deviceId,
      designator: designator,
      templatePortKey: key,
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

    test('pathways do NOT take that rule, and DR-032 is why', () {
      // This assertion used to read `pathwayCount, 1` — the outlet rule
      // applied to the neighbouring field, which was coherent while
      // nothing in the product could create a `Pathway`. DR-032 makes
      // `Office: 1x ENT` build a pathway and no cable, so the old reading
      // printed `0 pathways` on the keystroke after somebody made one,
      // and the `[ Pathways ]` tab listing it would sit on the same
      // screen as a bar denying it existed.
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
      expect(buildStructureTable(d.doc).pathwayCount, 2);
    });

    test('a pathway with nothing through it still counts', () {
      // DR-032's ordinary output, and the case the old rule got wrong.
      final d = _Doc()..pathway('Office ENT');
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

  group('the columns (docs/07 §4.1)', () {
    test("the defaults are §4.1's, plus FIELD TERM at DR-046", () {
      // NINE, NOT §4.1's EIGHT, and the ninth is ruled rather than
      // slipped in. Until DR-046 `FIELD TERM` and `RACK TERM` read ONE
      // field, so the column a person saw without configuring anything
      // was `RACK TERM` showing the FIELD end's value. Drawing both is
      // what makes the distinction teach itself (§11.45.4).
      expect(kStructureDefaultColumns.map(structureColumnHeader), [
        'FIELD LABEL',
        'RACK LBL',
        'OUTLET',
        'MEDIA',
        'SERVICE',
        'PATHWAY',
        'FIELD TERM',
        'RACK TERM',
        'ROUGH-IN',
      ]);
    });

    test('every column is offered exactly once, default or optional', () {
      final offered = [
        ...kStructureDefaultColumns,
        ...kStructureOptionalColumns,
      ];
      // A column in neither list is unreachable from `⚙ Columns`; a
      // column in both would render twice.
      expect(offered.toSet(), StructureColumnId.values.toSet());
      expect(offered.length, StructureColumnId.values.length);
    });

    test('the five sheet columns print exactly what the sheet prints', () {
      // THE ANTI-DRIFT GATE, in the same shape as the first group's: it
      // compares the two outputs rather than asserting either.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      final pw = d.pathway('PW-LR-1');
      _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
        rackPort: d.panelPort('A01'),
        pathwayId: pw,
      );

      final row = buildStructureTable(d.doc).groups.single.rows.single;
      const shared = <StructureColumnId, ScheduleColumnId>{
        StructureColumnId.fieldLabel: ScheduleColumnId.fieldLabel,
        StructureColumnId.rackLabel: ScheduleColumnId.rackLabel,
        StructureColumnId.media: ScheduleColumnId.media,
        StructureColumnId.service: ScheduleColumnId.type,
        StructureColumnId.pathway: ScheduleColumnId.pathway,
        // `rackTerm` LEFT THIS MAP AT DR-046. It read
        // `ScheduleColumnId.term`, which resolves to the FIELD
        // termination, so the editor's rack column printed the wall
        // end's value. It reads `terminationRack` directly now, and the
        // printed Termination Schedule's own `TERM` column is
        // deliberately unchanged: that sheet is M6's under DR-027 and
        // its column set is a sheet change (§11.45.5, board #679).
      };
      for (final entry in shared.entries) {
        expect(
          structureCell(
            d.doc,
            row,
            entry.key,
            units: UnitSystem.imperial,
          ),
          row.cell(entry.value, units: UnitSystem.imperial),
          reason:
              '${structureColumnHeader(entry.key)} must be the sheet '
              'string, not a second spelling of it',
        );
      }
    });

    test('an unset value is the dash, never an empty cell (G4)', () {
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: o, locationId: lr, fieldLabel: 'LR-TV-1');

      final row = buildStructureTable(d.doc).groups.single.rows.single;
      for (final id in StructureColumnId.values) {
        final cell = structureCell(d.doc, row, id, units: UnitSystem.imperial);
        expect(
          cell,
          isNotEmpty,
          reason:
              '${structureColumnHeader(id)} rendered nothing, which '
              'reads as "nothing to say" where the truth is "nobody has '
              'said"',
        );
      }
      // The five that have no value on a bare rough-in drop say so.
      for (final id in [
        StructureColumnId.installedBy,
        StructureColumnId.notes,
        StructureColumnId.testResult,
        StructureColumnId.certificateId,
        StructureColumnId.cutLength,
      ]) {
        expect(
          structureCell(d.doc, row, id, units: UnitSystem.imperial),
          kUnknownCell,
        );
      }
    });

    test('CUT is the measured length and never the room estimate', () {
      // The defect this forbids: a column headed CUT showing a figure
      // somebody would order cable against, which came from a room
      // estimate nobody measured (AC-024, G4).
      final d = _Doc();
      final lr = d.room(
        'Living Room',
        code: 'LR',
        estimate: const Len(62 * 304800000),
      );
      final o = d.outlet('LR-1', locationId: lr);
      final linkId = _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
      );

      final row = buildStructureTable(d.doc).groups.single.rows.single;
      expect(row.length, isNotNull, reason: 'the room estimate resolved');
      expect(row.lengthIsEstimated, isTrue);
      expect(
        structureCell(
          d.doc,
          row,
          StructureColumnId.cutLength,
          units: UnitSystem.imperial,
        ),
        kUnknownCell,
      );

      d.doc.links[linkId]!.cutLength = const Len(71 * 304800000);
      final measured = buildStructureTable(d.doc).groups.single.rows.single;
      expect(
        structureCell(
          d.doc,
          measured,
          StructureColumnId.cutLength,
          units: UnitSystem.imperial,
        ),
        '71',
      );
    });

    test('a length column follows the project display units', () {
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      final linkId = _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
      );
      d.doc.links[linkId]!.cutLength = const Len(100 * 304800000);

      final row = buildStructureTable(d.doc).groups.single.rows.single;
      expect(
        structureCell(
          d.doc,
          row,
          StructureColumnId.cutLength,
          units: UnitSystem.imperial,
        ),
        '100',
      );
      expect(
        structureCell(
          d.doc,
          row,
          StructureColumnId.cutLength,
          units: UnitSystem.metric,
        ),
        '30',
      );
    });

    test('JACKET and PULLED are two cells where the sheet joins them', () {
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      final linkId = _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
      );
      d.doc.settings.jacketColorConventions.addAll({
        const JacketColorId('jc.blue'): const JacketColorDef(
          displayName: 'Blue',
          abbr: 'BLU',
          color: Rgb(0x00, 0x00, 0xFF),
        ),
        const JacketColorId('jc.yellow'): const JacketColorDef(
          displayName: 'Yellow',
          abbr: 'YEL',
          color: Rgb(0xFF, 0xFF, 0x00),
        ),
      });
      SetLinkJacketColorCommand(
        linkId: linkId,
        conventionId: const JacketColorId('jc.blue'),
      ).apply(d.doc);
      SetLinkPulledJacketColorCommand(
        linkId: linkId,
        pulledId: const JacketColorId('jc.yellow'),
      ).apply(d.doc);

      final row = buildStructureTable(d.doc).groups.single.rows.single;
      expect(
        structureCell(
          d.doc,
          row,
          StructureColumnId.jacketColor,
          units: UnitSystem.imperial,
        ),
        'BLU',
      );
      expect(
        structureCell(
          d.doc,
          row,
          StructureColumnId.jacketColorPulled,
          units: UnitSystem.imperial,
        ),
        'YEL',
      );
      // The sheet still joins them, and that difference is §4.1's own.
      expect(row.jacketColorCell, 'BLU→YEL');
    });

    test('PATHWAY KIND is the kind, where PATHWAY is the name', () {
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      final pw = d.pathway('PW-LR-1');
      d.doc.pathways[pw]!.kind = PathwayKind.jhook;
      _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
        pathwayId: pw,
      );

      final row = buildStructureTable(d.doc).groups.single.rows.single;
      expect(
        structureCell(
          d.doc,
          row,
          StructureColumnId.pathway,
          units: UnitSystem.imperial,
        ),
        'PW-LR-1',
      );
      expect(
        structureCell(
          d.doc,
          row,
          StructureColumnId.pathwayKind,
          units: UnitSystem.imperial,
        ),
        'J-HOOK',
      );
    });

    test('the two DR-031 kinds print, and every kind has a label', () {
      // DR-031 (canon §11.30) discharges DR-020 §11.19.4. The switch in
      // `pathwayKindLabel` is exhaustive, so a missing arm is a compile
      // error rather than a test failure — what this case adds is that
      // the two new values reach a CELL, which is the thing an installer
      // reads, and that no label is silently the empty string.
      final d = _Doc();
      final lr = d.room('Attic Run', code: 'AT');
      final o = d.outlet('AT-1', locationId: lr);
      final pw = d.pathway('PW-AT-1');
      d.doc.pathways[pw]!.kind = PathwayKind.attic;
      _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'AT-TV-1',
        pathwayId: pw,
      );

      final row = buildStructureTable(d.doc).groups.single.rows.single;
      expect(
        structureCell(
          d.doc,
          row,
          StructureColumnId.pathwayKind,
          units: UnitSystem.imperial,
        ),
        'ATTIC',
      );

      expect(pathwayKindLabel(PathwayKind.crawlspace), 'CRAWLSPACE');
      for (final kind in PathwayKind.values) {
        expect(
          pathwayKindLabel(kind),
          isNotEmpty,
          reason: '${kind.name} would print as a blank cell',
        );
      }
    });

    test('a DR-031 kind survives the byte round trip (CR-117)', () {
      // The enum serialises BY NAME, which is the whole reason DR-020
      // deferred this question to the day the editor lands: the two
      // values have to be readable before any gesture can write one.
      final d = _Doc();
      final pw = d.pathway('PW-CS-1');
      d.doc.pathways[pw]!.kind = PathwayKind.crawlspace;

      const codec = JsonDocumentCodec();
      final bytes = codec.write(d.doc);
      final read = codec.read(bytes);
      final reread = (read as Ok<RackDocument>).value;

      expect(reread.pathways[pw]!.kind, PathwayKind.crawlspace);
      expect(codec.write(reread), orderedEquals(bytes));
    });
  });

  group('reading a typed cell back (M3-J/3)', () {
    test('a length column is WHOLE units, and a decimal is refused', () {
      // The rule and its reason: `scheduleLengthCell` rounds, so a cell
      // that accepted `62.5` would store a value its own column then
      // displays as `63`. Refusing is what keeps the number on screen and
      // the number in the file equal.
      expect(
        (parseLengthCell('62', UnitSystem.imperial) as CellParsed<Len>).value,
        const Len(62 * 304800000),
      );
      expect(
        parseLengthCell('62.5', UnitSystem.imperial),
        isA<CellRefused<Len>>(),
      );
      // #585's own example of what must not be accepted.
      expect(
        parseLengthCell('62 ft 3', UnitSystem.imperial),
        isA<CellRefused<Len>>(),
      );
      expect(
        parseLengthCell('-1', UnitSystem.imperial),
        isA<CellRefused<Len>>(),
      );
    });

    test('and it reads the project display units', () {
      expect(
        (parseLengthCell('30', UnitSystem.metric) as CellParsed<Len>).value,
        const Len(30 * 1000000000),
      );
      expect(
        (parseLengthCell('30', UnitSystem.imperial) as CellParsed<Len>).value,
        const Len(30 * 304800000),
      );
    });

    test('a cleared length is UNKNOWN, which is a legal edit (G4)', () {
      final parsed = parseLengthCell('   ', UnitSystem.imperial);
      expect(parsed, isA<CellParsed<Len>>());
      expect((parsed as CellParsed<Len>).value, isNull);
    });

    test('a count keeps 0 and blank apart, which is the whole point', () {
      // DR-020 §11.19.2(3) made `spliceCount` nullable so "nobody looked"
      // and "somebody looked and found none" stop being one answer. That
      // distinction has to survive a text box.
      expect((parseCountCell('0') as CellParsed<int>).value, 0);
      expect((parseCountCell('') as CellParsed<int>).value, isNull);
      expect((parseCountCell('3') as CellParsed<int>).value, 3);
      expect(parseCountCell('two'), isA<CellRefused<int>>());
      expect(parseCountCell('-1'), isA<CellRefused<int>>());
    });

    test('a date is YYYY-MM-DD and nothing else', () {
      // `03/04` is March and April at the same time. A jobsite date wrong
      // by a month is worse than one that is missing.
      expect(
        (parseDateCell('2026-08-08') as CellParsed<DateTime>).value,
        DateTime.utc(2026, 8, 8),
      );
      expect(parseDateCell('08/08/2026'), isA<CellRefused<DateTime>>());
      expect(parseDateCell('8 Aug 2026'), isA<CellRefused<DateTime>>());
      expect((parseDateCell('') as CellParsed<DateTime>).value, isNull);
    });

    test('a date that does not exist is refused, not rolled over', () {
      // `DateTime.utc(2026, 2, 31)` is March 3rd and throws nothing, so a
      // typo would otherwise be stored as a real date nobody meant.
      expect(parseDateCell('2026-02-31'), isA<CellRefused<DateTime>>());
      expect(parseDateCell('2026-13-01'), isA<CellRefused<DateTime>>());
    });

    test('a date round-trips through the cell exactly', () {
      final parsed =
          (parseDateCell('2026-08-08') as CellParsed<DateTime>).value!;
      expect(formatDateCell(parsed), '2026-08-08');
    });

    test('A FLOOR MAY BE NEGATIVE, which is why it is not a count', () {
      // The one behaviour that makes `parseFloorCell` a separate function
      // rather than a call to `parseCountCell`. A basement is `0` under
      // one convention and `-1` under another, and nothing here knows
      // which building the user is standing in. Delete this function and
      // route `Floor` at `parseCountCell` and only this line fails.
      expect((parseFloorCell('-1') as CellParsed<int>).value, -1);
      expect(parseCountCell('-1'), isA<CellRefused<int>>());
    });

    test('a blank floor is UNKNOWN and never ground level (G4)', () {
      // `0` is a real storey somewhere, so a blank that landed as `0`
      // would put a wrong `{FLOOR}` on every rack label in a room nobody
      // had got to yet, and it would look deliberate on the sheet.
      expect((parseFloorCell('') as CellParsed<int>).value, isNull);
      expect((parseFloorCell('   ') as CellParsed<int>).value, isNull);
      expect((parseFloorCell('0') as CellParsed<int>).value, 0);
    });

    test('a floor that is not a whole number is refused', () {
      expect(parseFloorCell('B'), isA<CellRefused<int>>());
      expect(parseFloorCell('1.5'), isA<CellRefused<int>>());
      expect(parseFloorCell('ground'), isA<CellRefused<int>>());
      // The sentence says what to type instead, because "B" is the most
      // likely wrong answer and the field cannot hold it.
      expect(
        (parseFloorCell('B') as CellRefused<int>).reason,
        contains('basement'),
      );
    });
  });

  group('the as-built columns (DR-020 §11.19.2(5))', () {
    test('the as-built set is six, and ROUGH-IN is not one of them', () {
      // ROUGH-IN answers "how far along is this run" and is a DEFAULT;
      // these answer "what did we actually do".
      //
      // SIX SINCE DR-046, and `FIELD TERM` is the one that left. It is a
      // default column now, and a group that toggled a column already on
      // screen would turn it OFF, which is not what "show me the
      // as-built set" means.
      expect(kStructureAsBuiltColumns.map(structureColumnHeader), [
        'TERM. LEN',
        'SPLICES',
        'TEST',
        'CERT ID',
        'INSTALLED BY',
        'TERMINATED',
      ]);
      expect(
        kStructureAsBuiltColumns,
        isNot(contains(StructureColumnId.roughIn)),
      );
      // And every one of them is an OPTIONAL column, off by default.
      for (final id in kStructureAsBuiltColumns) {
        expect(kStructureOptionalColumns, contains(id));
      }
    });

    test('every one of the seven is enterable, and so are the other two '
        'lengths now', () {
      for (final id in kStructureAsBuiltColumns) {
        expect(
          structureColumnIsEditable(id),
          isTrue,
          reason: '${structureColumnHeader(id)} is what #585 makes typeable',
        );
      }
      // THIS CASE USED TO ASSERT THE OPPOSITE, and the change is the
      // point rather than a loosened test. #585 left `CUT` and `ROUTED`
      // read-only because #153 (M3-D/2) owned them, and pinned that
      // boundary here so it stayed deliberate. M3-D/2 has now wired both
      // to a `LinkField`, so the boundary is gone and the assertion
      // follows it. All three of AC-024's lengths are typeable.
      expect(structureColumnIsEditable(StructureColumnId.cutLength), isTrue);
      expect(structureColumnIsEditable(StructureColumnId.routedLength), isTrue);
    });

    test('SPLICES prints 0 as 0 and unknown as the dash', () {
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      final linkId = _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
      );

      String cell() => structureCell(
        d.doc,
        buildStructureTable(d.doc).groups.single.rows.single,
        StructureColumnId.spliceCount,
        units: UnitSystem.imperial,
      );

      expect(cell(), kUnknownCell);
      d.doc.links[linkId]!.spliceCount = 0;
      expect(cell(), '0', reason: 'a confirmed none is not an unknown');
      d.doc.links[linkId]!.spliceCount = 2;
      expect(cell(), '2');
    });

    test('TERMINATED prints a date and never an hour', () {
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      final linkId = _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
      );
      d.doc.links[linkId]!.terminatedAt = DateTime.utc(2026, 8, 8, 14, 30);

      expect(
        structureCell(
          d.doc,
          buildStructureTable(d.doc).groups.single.rows.single,
          StructureColumnId.terminatedAt,
          units: UnitSystem.imperial,
        ),
        '2026-08-08',
      );
    });

    test('TEST is three states, and null is NOT TESTED', () {
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      final linkId = _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
      );

      String cell() => structureCell(
        d.doc,
        buildStructureTable(d.doc).groups.single.rows.single,
        StructureColumnId.testResult,
        units: UnitSystem.imperial,
      );

      expect(cell(), kUnknownCell, reason: 'not tested is not a failure');
      d.doc.links[linkId]!.test = TestResult(pass: false);
      expect(cell(), kTestFailCell);
      d.doc.links[linkId]!.test = TestResult(pass: true);
      expect(cell(), kTestPassCell);
    });
  });

  group("the SERVICE column's menu (DR-025 §11.24.5, board #587)", () {
    final registries = buildSeedRegistries();

    test('every label the menu offers resolves back to the family that '
        'produced it', () {
      // THE PAIR IS A TRUE INVERSE OR IT IS NOTHING, and that is the
      // whole reason the spelling lives in core. The cell PRINTS
      // `signalFamilyCellLabel`, the menu OFFERS it, and the edit arm
      // READS IT BACK. Three spellings would round-trip wrong on the
      // first family whose display name is not simply its tag, which is
      // most of them.
      for (final group in signalFamilyCellGroups(registries)) {
        for (final option in group.options) {
          expect(
            resolveSignalFamilyCell(registries, option.label),
            option.id,
            reason: option.label,
          );
        }
      }
    });

    test('the spelling the cell prints is on the menu, for every '
        'family', () {
      // The other half of the same claim. A menu agreeing with itself
      // proves nothing if the cell spells the family a fourth way.
      for (final family in registries.signalFamilies.values) {
        final domain = registries.signalDomains[family.domain]!;
        expect(
          signalFamilyCellOptions(registries),
          contains(signalFamilyCellLabel(domain, family)),
          reason: family.id.v,
        );
      }
    });

    test('every family appears exactly once across the groups', () {
      final ids = [
        for (final g in signalFamilyCellGroups(registries))
          for (final o in g.options) o.id,
      ];
      expect(ids.toSet(), hasLength(ids.length), reason: 'no duplicates');
      // Against the registry rather than a literal: the catalog is
      // expected to grow, and a number here goes stale on exactly the
      // growth it was written to survive.
      expect(ids, hasLength(registries.signalFamilies.length));
      expect(
        signalFamilyCellOptions(registries),
        hasLength(registries.signalFamilies.length),
      );
    });

    test('groups are ordered by domain id and options by label', () {
      final groups = signalFamilyCellGroups(registries);
      final ids = groups.map((g) => g.domainId.v).toList();
      expect(ids, orderedEquals(ids.toList()..sort()));
      for (final g in groups) {
        final labels = g.options.map((o) => o.label).toList();
        expect(
          labels,
          orderedEquals(labels.toList()..sort()),
          reason: g.tagPrefix,
        );
      }
    });

    test('the order does not depend on map order', () {
      // THE DOC COMMENT'S CLAIM, TESTED RATHER THAN ASSERTED. Dart map
      // iteration is insertion order, so a registry decoded from a file
      // whose keys arrived in a different sequence would reorder the
      // menu under the user if either sort here were partial.
      Map<K, V> reverse<K, V>(Map<K, V> m) => {
        for (final e in m.entries.toList().reversed) e.key: e.value,
      };
      final shuffled = Registries(
        signalDomains: reverse(registries.signalDomains),
        signalFamilies: reverse(registries.signalFamilies),
      );
      expect(
        signalFamilyCellGroups(shuffled).map((g) => g.domainId.v).toList(),
        signalFamilyCellGroups(registries).map((g) => g.domainId.v).toList(),
      );
      expect(
        signalFamilyCellOptions(shuffled),
        signalFamilyCellOptions(registries),
      );
    });

    test('there is no unknown row, unlike the termination columns', () {
      // G4 drawing a real distinction rather than an inconsistency: a
      // `TerminationType?` is nullable because nobody having decided is
      // a genuine absence, while a `Service` always HAS a family and
      // `structure.undetermined` is the encouraged first-class value.
      expect(
        signalFamilyCellOptions(registries),
        isNot(contains(kUnknownCell)),
      );
      expect(
        signalFamilyCellOptions(
          registries,
        ).where((l) => l.contains('Undetermined home run')),
        hasLength(1),
        reason: 'choosing undetermined is a statement, so it is a row',
      );
    });

    test('a filter is a SUBSTRING where a commit is EXACT', () {
      // The two answer different questions rather than disagreeing.
      // `@signal=hdb` must refuse, because DR-025 §11.24.3 never invents
      // a family from a typo; typing `hdb` into a filter box must show
      // HDBaseT, or the box is a search for people who already knew the
      // answer.
      final hdbaset = [
        for (final g in signalFamilyCellGroups(registries))
          for (final o in g.options)
            if (o.id == const SignalFamilyId('video.hdbaset')) o,
      ].single;

      expect(hdbaset.matches('hdb'), isTrue, reason: 'a partial word');
      expect(hdbaset.matches('HBT'), isTrue, reason: 'its shortTag');
      expect(hdbaset.matches('hdbaset'), isTrue, reason: "the id's own tail");
      expect(hdbaset.matches('5play'), isTrue, reason: 'inside displayName');
      expect(hdbaset.matches(''), isTrue, reason: 'an empty box hides nothing');
      expect(hdbaset.matches('   '), isTrue, reason: 'nor does whitespace');
      expect(hdbaset.matches('dante'), isFalse);

      expect(
        resolveSignalFamilyCell(registries, 'hdb'),
        isNull,
        reason: 'a substring must not COMMIT a family',
      );
      expect(
        resolveSignalFamilyCell(registries, 'hdmi'),
        isNull,
        reason: 'and must not pick whichever HDMI generation sorts first',
      );
    });

    test('a cell that names nothing refuses rather than inventing', () {
      expect(resolveSignalFamilyCell(registries, ''), isNull);
      expect(resolveSignalFamilyCell(registries, '   '), isNull);
      expect(resolveSignalFamilyCell(registries, 'VID·Nonsense'), isNull);
      expect(
        resolveSignalFamilyCell(registries, 'video.hdbaset'),
        isNull,
        reason: 'the raw id is not a cell spelling; the label is',
      );
    });

    test('case and surrounding space are forgiven on a commit', () {
      final label = signalFamilyCellLabel(
        registries.signalDomains[const SignalDomainId('video.digital')]!,
        registries.signalFamilies[const SignalFamilyId('video.hdbaset')]!,
      );
      expect(
        resolveSignalFamilyCell(registries, '  ${label.toUpperCase()}  '),
        const SignalFamilyId('video.hdbaset'),
      );
    });

    test('SERVICE is the registry-backed column and the enum ones are not', () {
      expect(
        structureColumnChoicesAreRegistryBacked(StructureColumnId.service),
        isTrue,
      );
      for (final id in [
        StructureColumnId.roughIn,
        StructureColumnId.testResult,
        StructureColumnId.fieldTerm,
        StructureColumnId.rackTerm,
      ]) {
        expect(
          structureColumnChoicesAreRegistryBacked(id),
          isFalse,
          reason: '$id reads a Dart enum and a plain dropdown fits it',
        );
      }
    });

    test('a family whose domain is missing is dropped, not listed '
        'domainless', () {
      // A guard on a DOCUMENT rather than on the seed, which
      // `seed_catalog_test.dart` gates. A domainless family has no tag
      // to file it under and no colour to draw in, and `typeCell` would
      // print a bare id that no menu offers.
      final orphaned = Registries(
        signalFamilies: registries.signalFamilies,
      );
      expect(signalFamilyCellGroups(orphaned), isEmpty);
      expect(signalFamilyCellOptions(orphaned), isEmpty);
      expect(resolveSignalFamilyCell(orphaned, 'VID·HDBaseT (5Play)'), isNull);
    });
  });

  group('the runs nobody landed (DR-072 §11.71, `#716`)', () {
    test('an unlanded rack end is counted, and a landed one is not', () {
      // THE QUESTION THE SCHEMATIC COULD NOT ANSWER: "did I forget one".
      // A half-landed run is drawn, so it is not in `unlabelledLinkIds`
      // and the sheet said nothing about it at all.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      final unlanded = _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
      );
      _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-2',
        rackPort: d.panelPort('A01'),
      );

      expect(unlandedHomeRunIds(d.doc), [unlanded]);
    });

    test('an unlanded FIELD end is not counted, because it is not a job', () {
      // DR-068 lets a speaker run land on its driver and a Cat6 drop end
      // at a wall plate for good. Counting those puts a number on the
      // sheet that never reaches zero, which is how a person learns to
      // stop reading it.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
        rackPort: d.panelPort('A01'),
      );

      final link = d.doc.links.values.single;
      expect(link.conductors.first.from, isNot(isA<PortEndpoint>()));
      expect(
        unlandedHomeRunIds(d.doc),
        isEmpty,
        reason:
            'the rack end is punched down, which is the end that is a '
            'job somebody has to do',
      );
    });

    test('an ordinary patch cable is not a home run and is not counted', () {
      // The count is about the structured wiring. A rack-to-rack jumper
      // has no `structureOrigin` and nothing to land.
      final d = _Doc();
      AddLinkCommand(
        designator: 'W900',
        netName: 'N900',
        media: const MediaTypeId('media.cat6'),
        order: nextLinkOrder(d.doc),
        now: _when,
        actor: 'test',
      ).apply(d.doc);
      expect(unlandedHomeRunIds(d.doc), isEmpty);
    });
  });

  group('the OUTLET column has THREE states (DR-070 §11.69, `#718`)', () {
    /// A run that comes out of no box: a ceiling speaker, whose
    /// conductors land on the driver's own binding posts.
    ScheduleEntry boxlessRow(_Doc d, Uuid roomId) {
      final built =
          buildAddHomeRunCommand(
                doc: d.doc,
                structureBodyId: d.bodyId,
                fieldLabel: 'LR-SPK-L',
                designator: 'W900',
                netName: 'N900',
                media: const MediaTypeId('media.cat6'),
                fieldEnd: PlaceEndpoint(
                  description: 'Living Room ceiling',
                  locationId: roomId,
                ),
                terminationField: TerminationType.bindingPost,
                now: _when,
                actor: 'test',
              )
              as AddHomeRunReady;
      built.command.apply(d.doc);
      final id = built.command.id;
      return buildStructureTable(
        d.doc,
      ).groups.expand((g) => g.rows).firstWhere((r) => r.linkId == id);
    }

    String outletCell(_Doc d, ScheduleEntry row) => structureCell(
      d.doc,
      row,
      StructureColumnId.outlet,
      units: UnitSystem.imperial,
    );

    test('a box prints its designation', () {
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: o, locationId: lr, fieldLabel: 'LR-TV-1');
      final row = buildStructureTable(d.doc).groups.single.rows.single;
      expect(outletCell(d, row), 'LR-1');
    });

    test('NO BOX prints its own token, never the unknown dash', () {
      // The whole point of the second field. `—` means "nobody has said
      // which box"; a ceiling speaker having none is something a person
      // stated, and an estimator counting plates off this column is who
      // the difference is for.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final row = boxlessRow(d, lr);

      expect(outletCell(d, row), kNoBoxCell);
      expect(outletCell(d, row), isNot(kUnknownCell));
      expect(row.boxless, isTrue);
    });

    test('and a boxless run adds no outlet to the count', () {
      // `outletCount` collected `o.outletId` unconditionally, so once the
      // field became nullable a body of nothing but ceiling speakers
      // reported ONE outlet: every drop contributed the same null.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      boxlessRow(d, lr);
      expect(buildStructureTable(d.doc).outletCount, 0);

      final o = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: o, locationId: lr, fieldLabel: 'LR-TV-1');
      expect(buildStructureTable(d.doc).outletCount, 1);
    });

    test("a boxless run keeps its ROOM, and does not fall into the rack's", () {
      // `buildScheduleEntry` reads the room as
      // `from.locationId ?? outlet?.locationId ?? to.locationId`. With no
      // outlet the middle term is gone, and the last one is the
      // equipment room. The builder refuses a boxless run that cannot
      // answer; this is the other half, that the answer is USED.
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      boxlessRow(d, lr);

      final group = buildStructureTable(d.doc).groups.single;
      expect(group.locationId, lr);
      expect(group.title, 'Living Room');
    });
  });

  group('the CLASS column (DR-067 §11.66, board `#712`)', () {
    /// A drop that lands on a real rack port, so the classifier can
    /// resolve both ends and has an opinion to be overruled.
    (_Doc, ScheduleEntry) landed() {
      final d = _Doc();
      final lr = d.room('Living Room', code: 'LR');
      final o = d.outlet('LR-1', locationId: lr);
      _drop(
        d,
        outletId: o,
        locationId: lr,
        fieldLabel: 'LR-TV-1',
        rackPort: d.panelPort('A01'),
      );
      return (d, buildStructureTable(d.doc).groups.single.rows.single);
    }

    test('it is optional, editable and batchable, and headed CLASS', () {
      // OPTIONAL AND NOT A NINTH DEFAULT. §4.1's set answers "what am I
      // pulling and where does it land"; a class is normally derived and
      // normally right, so it does not spend default width.
      expect(kStructureOptionalColumns, contains(StructureColumnId.linkClass));
      expect(
        kStructureDefaultColumns,
        isNot(contains(StructureColumnId.linkClass)),
      );
      expect(structureColumnHeader(StructureColumnId.linkClass), 'CLASS');
      expect(structureColumnIsEditable(StructureColumnId.linkClass), isTrue);
      expect(
        structureColumnIsBatchable(StructureColumnId.linkClass),
        isTrue,
        reason:
            'a class is not unique, so the fill-down that closes out sixty '
            'drops covers it too',
      );
    });

    test('the cell reads the EFFECTIVE class, so an unclassified run '
        "shows the classifier's answer", () {
      final (d, row) = landed();
      final link = d.doc.links[row.linkId]!;
      expect(link.linkClassLocked, isFalse, reason: 'nobody has said');
      expect(
        structureCell(
          d.doc,
          row,
          StructureColumnId.linkClass,
          units: UnitSystem.imperial,
        ),
        'FIELD CABLE',
      );
      expect(
        structureLinkClassIsUserSet(d.doc, row),
        isFalse,
        reason: 'the classifier answering is not a person asserting',
      );
    });

    test("a person's class outranks the classifier and is marked", () {
      final (d, row) = landed();
      SetLinkClassCommand(
        linkId: row.linkId,
        linkClass: LinkClass.jumper,
      ).apply(d.doc);

      expect(
        structureCell(
          d.doc,
          row,
          StructureColumnId.linkClass,
          units: UnitSystem.imperial,
        ),
        'JUMPER',
      );
      expect(structureLinkClassIsUserSet(d.doc, row), isTrue);
      // AND THE CLASSIFIER'S COMPETING ANSWER IS RECOVERABLE, which is
      // §11.8.2's visible-disagreement clause. The person's word stands;
      // standing is not the same as hiding.
      expect(structureLinkClassDisagreement(d.doc, row), 'FIELD CABLE');
    });

    test('clearing the override hands the run back, and the mark goes', () {
      final (d, row) = landed();
      SetLinkClassCommand(
        linkId: row.linkId,
        linkClass: LinkClass.jumper,
      ).apply(d.doc);
      ClearLinkClassOverrideCommand(linkId: row.linkId).apply(d.doc);

      expect(structureLinkClassIsUserSet(d.doc, row), isFalse);
      expect(structureLinkClassDisagreement(d.doc, row), isNull);
      expect(
        structureCell(
          d.doc,
          row,
          StructureColumnId.linkClass,
          units: UnitSystem.imperial,
        ),
        'FIELD CABLE',
        reason:
            'the classifier is heard again, and it never stopped saying '
            'this',
      );
    });

    test('an agreeing override is still an override, and still marked', () {
      // The case that would tempt an implementation to demote the pin
      // "because it matches". `SetLinkClassCommand`'s own doc refuses
      // that: an assertion agreeing with the classifier today is still an
      // assertion, and dropping it would lose the person's word the next
      // time the document moved.
      final (d, row) = landed();
      SetLinkClassCommand(
        linkId: row.linkId,
        linkClass: LinkClass.fieldCable,
      ).apply(d.doc);

      expect(structureLinkClassIsUserSet(d.doc, row), isTrue);
      expect(
        structureLinkClassDisagreement(d.doc, row),
        isNull,
        reason: 'agreeing is not disagreeing',
      );
    });

    test('an undetermined class is the DASH, never a class name and never '
        'the word UNDETERMINED (G4)', () {
      final (d, row) = landed();
      // Take the DEVICE out from under the port, which is the shape a
      // staged or deleted panel leaves behind. `linkClassOf` then fails
      // to resolve that end and returns null, which is the state its own
      // header spends a paragraph refusing to guess about: defaulting to
      // FIELD CABLE asserts a pull nobody established, and defaulting to
      // JUMPER hides the run from the sheet an installer works from.
      //
      // Emptying `doc.racks` alone does NOT do it, and that is worth
      // knowing rather than working around: `rackOfEndpoint` reads the
      // rack id off the device's own placement and never asks whether
      // that rack is still in the document.
      d.doc.devices.clear();

      expect(
        structureCell(
          d.doc,
          row,
          StructureColumnId.linkClass,
          units: UnitSystem.imperial,
        ),
        kUnknownCell,
      );
      expect(
        structureLinkClassDisagreement(d.doc, row),
        isNull,
        reason:
            'an undetermined classifier has failed to resolve an end, '
            'not formed a competing opinion',
      );
    });

    test('every label the menu offers resolves back to its own class', () {
      // The round trip that keeps the picker and the writer speaking one
      // language. `linkClassLabel` is the SHEET's speller and this column
      // borrows it rather than growing a second one.
      for (final value in LinkClass.values) {
        expect(resolveLinkClassCell(linkClassLabel(value)), value);
      }
      // AND THE TWO WORDS THAT ARE NOT CLASSES DO NOT RESOLVE. `AUTO` is
      // a different command; `UNDETERMINED` is what the sheet prints for
      // a classifier that could not tell, which is a fact about the
      // document rather than a choice.
      expect(resolveLinkClassCell(kLinkClassAutoCell), isNull);
      expect(resolveLinkClassCell(linkClassLabel(null)), isNull);
      expect(resolveLinkClassCell('BANANA'), isNull);
    });
  });

  group('the LANDS ON menu (DR-071 §11.70.1, DR-074 §11.73.1)', () {
    /// The snapshot `_Doc.panelPort`'s device REFERS TO and the fixture
    /// never had, because nothing before this asked what a panel has room
    /// for. `freePanelPositions` walks the template body, so without it
    /// every device offers zero positions and the menu is empty.
    ///
    /// REAR, which is DR-040 §11.39.2 clause 4: the front jacks take
    /// patch cords and a pulled cable lands on the back.
    void addPanelTemplate(_Doc d) {
      d.doc.templates['tpl.pp@1'] = TemplateSnapshot(
        templateId: const TemplateId('tpl.pp'),
        version: 1,
        contentHash: 'sha256:tpl.pp',
        body: TemplateBody(
          manufacturer: 'Generic',
          model: 'PP-24',
          displayName: 'Patch Panel, 24-port',
          typePrefix: 'PP',
          ports: [
            for (var i = 1; i <= 3; i++)
              PortDef(
                key: PortKey('rear.$i'),
                label: i.toString().padLeft(2, '0'),
                connector: const ConnectorTypeId('conn.punchdown_110'),
                signalFamily: const SignalFamilyId('net.ethernet'),
                face: Face.rear,
                position: const PanelPosition(
                  ruOffset: 0,
                  xTwelfth: 0,
                  xFineNm: Len.zero,
                  yFineNm: Len.zero,
                ),
                order: FracIndex('a$i'),
              ),
          ],
        ),
        capturedAt: _when,
      );
    }

    test('an UNLANDED row is offered panels and nothing else', () {
      final d = _Doc();
      final room = d.room('Great Room');
      final outlet = d.outlet('GR-TV-1', locationId: room);
      d.panelPort('01');
      addPanelTemplate(d);
      _drop(
        d,
        outletId: outlet,
        locationId: room,
        fieldLabel: 'GR-DATA-1',
      );

      final options = landingCellOptions(d.doc);
      expect(options, contains('PP-1'));
      expect(
        options,
        isNot(contains(kUnlandCell)),
        reason:
            'there is nothing to take off, so an option whose every use '
            'is refused would be `#711` drawn on purpose',
      );
    });

    test('a LANDED row is offered NOT LANDED, last', () {
      final d = _Doc();
      final room = d.room('Great Room');
      final outlet = d.outlet('GR-TV-1', locationId: room);
      final port = d.panelPort('01');
      addPanelTemplate(d);
      _drop(
        d,
        outletId: outlet,
        locationId: room,
        fieldLabel: 'GR-DATA-1',
        rackPort: port,
      );

      final options = landingCellOptions(d.doc, landed: true);
      expect(options, contains(kUnlandCell));
      expect(
        options.last,
        kUnlandCell,
        reason:
            'it goes in AFTER the sort: a destructive option hiding '
            'between MDF-1 and PP-1 is one a person picks by aiming badly',
      );
    });

    // ── `#779`, the PORT column ────────────────────────────────────
    // The artifact is that a person can CHOOSE the hole. Until this
    // column existed `structure_edit_actions.dart` took `free.first` and
    // the choice could not be expressed at all, which is what a person
    // reported. `LANDS ON` still allocates, so the batch case
    // `structureColumnIsEditable` argues for is untouched.

    test('an UNLANDED row is offered no positions, not an empty menu', () {
      final d = _Doc();
      final room = d.room('Great Room');
      final outlet = d.outlet('GR-TV-1', locationId: room);
      d.panelPort('01');
      addPanelTemplate(d);
      _drop(d, outletId: outlet, locationId: room, fieldLabel: 'GR-DATA-1');

      final row = buildStructureTable(d.doc).groups.single.rows.single;
      expect(
        landingPortCellOptions(d.doc, row),
        isEmpty,
        reason:
            'a position menu with no panel asks a question that has '
            'no subject; the surface reads empty as "pick a panel first"',
      );
      expect(landingPortToken(row), isNull);
    });

    test('a LANDED row can always see the position it is on', () {
      // `freePanelPositions` EXCLUDES the occupied one, so without the
      // explicit re-add the dropdown's own value is absent from its own
      // options. That renders blank or asserts, and either way a person
      // cannot read where the drop actually is: `#711` again.
      final d = _Doc();
      final room = d.room('Great Room');
      final outlet = d.outlet('GR-TV-1', locationId: room);
      final port = d.panelPort('01', templatePortKey: 'rear.1');
      addPanelTemplate(d);
      _drop(
        d,
        outletId: outlet,
        locationId: room,
        fieldLabel: 'GR-DATA-1',
        rackPort: port,
      );

      final row = buildStructureTable(d.doc).groups.single.rows.single;
      final current = landingPortToken(row);
      expect(
        freePanelPositions(
          d.doc,
          panelDeviceId: d.doc.ports[port]!.deviceId,
        ).map((f) => f.positionToken),
        isNot(contains(current)),
        reason:
            'the fixture has to actually OCCUPY the position, or the '
            'assertion below passes on a free list that never excluded it',
      );
      expect(current, isNotNull);
      expect(
        landingPortCellOptions(d.doc, row),
        contains(current),
        reason:
            'a dropdown whose value is not among its options is the '
            'defect this project already has a number for',
      );
    });

    test('NOT LANDED names a state, like every other closed-set cell', () {
      // The user settled the word on 2026-08-19. Pinned as a whole string
      // rather than a `contains`, because it is copy: it is read off a
      // menu by whoever is holding the punch tool.
      expect(kUnlandCell, 'NOT LANDED');
    });
  });

  group('a rack label that a person typed (DR-074 §11.73.2)', () {
    ({_Doc d, Uuid linkId}) landed() {
      final d = _Doc();
      final room = d.room('Great Room');
      final outlet = d.outlet('GR-TV-1', locationId: room);
      final port = d.panelPort('01');
      final linkId = _drop(
        d,
        outletId: outlet,
        locationId: room,
        fieldLabel: 'GR-DATA-1',
        rackPort: port,
      );
      return (d: d, linkId: linkId);
    }

    test('is not marked while the allocator owns the name', () {
      final p = landed();
      final row = buildStructureTable(p.d.doc).groups.single.rows.single;
      expect(structureRackLabelIsUserSet(p.d.doc, row), isFalse);
    });

    test('is marked once the cell has been typed into', () {
      final p = landed();
      SetRackLabelCommand(
        linkId: p.linkId,
        rackLabel: 'BY-HAND-7',
        now: _when,
        actor: 'test',
      ).apply(p.d.doc);

      final row = buildStructureTable(p.d.doc).groups.single.rows.single;
      expect(
        structureRackLabelIsUserSet(p.d.doc, row),
        isTrue,
        reason:
            'the mark is how a person learns why a move left their label '
            'alone',
      );
    });

    test('and the mark goes away when the cell is cleared', () {
      final p = landed();
      SetRackLabelCommand(
        linkId: p.linkId,
        rackLabel: 'BY-HAND-7',
        now: _when,
        actor: 'test',
      ).apply(p.d.doc);
      SetRackLabelCommand(
        linkId: p.linkId,
        rackLabel: null,
        now: _when,
        actor: 'test',
      ).apply(p.d.doc);

      final row = buildStructureTable(p.d.doc).groups.single.rows.single;
      expect(structureRackLabelIsUserSet(p.d.doc, row), isFalse);
    });
  });
}
