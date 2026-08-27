// M3-C/3, #149 — the Structure editor's matrix, as a grid model.
//
// WHAT THESE ARE FOR. #149's instruction is "one editor, two views of
// the same rows", and the risk in a second view is the one CR-107 named:
// it starts counting for itself and disagrees with the first. The first
// group is the gate on that and it compares the two outputs rather than
// asserting either.
//
// The rest pin what the matrix does that the table deliberately does
// not: an empty room still gets a row, because a `0` cell is where a
// person types `2`, and a `site` or a `floor` does not, because four
// Cat6 filed against a street address is not a mistake this surface
// should make easy.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 8);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const MediaTypeId _cat6 = MediaTypeId('media.cat6');
const MediaTypeId _rg6 = MediaTypeId('media.rg6');
const MediaTypeId _spk = MediaTypeId('media.16_4');

/// §4.2's ninth column, and the only `isPathwayOnly` one in the seed set.
const MediaTypeId _emt = MediaTypeId('media.conduit_emt');

final class _Doc {
  _Doc({bool seeded = true})
    : doc = RackDocument(
        id: const Uuid('doc-structure-matrix'),
        appVersion: 'test',
        createdAt: _when,
        modifiedAt: _when,
        meta: _meta(),
      ) {
    if (seeded) doc.registries = buildSeedRegistries();
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

  Uuid outlet(String designation, {required Uuid locationId}) =>
      (AddOutletCommand(
        structureBodyId: bodyId,
        designation: designation,
        order: nextOutletOrder(doc),
        now: _when,
        actor: 'test',
        locationId: locationId,
      )..apply(doc)).id;

  /// A rack, a device and one port, so a drop has somewhere real to land.
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
}

/// One location on [d].
///
/// A FREE FUNCTION AND NOT A METHOD, the shape [_drop] takes and for the
/// reason `schedule_test.dart` gives about its own `_link`: half the
/// tests here state two or three rooms in a row and never name them
/// again, and as methods that reads as a cascade on a builder object
/// with the punctuation where the rooms should be.
Uuid _room(
  _Doc d,
  String name, {
  String code = '',
  Uuid? parentId,
  LocationKind kind = LocationKind.room,
}) => (AddLocationCommand(
  name: name,
  code: code,
  kind: kind,
  order: nextLocationOrder(d.doc, parentId: parentId),
  now: _when,
  actor: 'test',
  parentId: parentId,
)..apply(d.doc)).id;

/// One home run, of [media].
Uuid _drop(
  _Doc d, {
  required Uuid outletId,
  required Uuid locationId,
  required String fieldLabel,
  MediaTypeId media = _cat6,
  Uuid? rackPort,
}) {
  d._seq++;
  final built =
      buildAddHomeRunCommand(
            doc: d.doc,
            outletId: outletId,
            fieldLabel: fieldLabel,
            designator: 'W${d._seq.toString().padLeft(3, '0')}',
            netName: 'N${d._seq.toString().padLeft(3, '0')}',
            media: media,
            fieldEnd: PlaceEndpoint(
              description: 'wall plate',
              locationId: locationId,
            ),
            rackEnd: rackPort == null ? null : PortEndpoint(rackPort),
            now: _when,
            actor: 'test',
          )
          as AddHomeRunReady;
  built.command.apply(d.doc);
  return built.command.id;
}

/// The row for [title], or null.
StructureMatrixRow? _row(StructureMatrix m, String title) =>
    m.rows.where((r) => r.title == title).firstOrNull;

/// What [title] holds of [media].
int _cell(StructureMatrix m, String title, MediaTypeId media) {
  final row = _row(m, title)!;
  return row.counts[m.columns.indexOf(media)];
}

void main() {
  group('IT IS A PROJECTION OF THE TABLE, not a second count', () {
    test('Σ over every row is exactly the table drop count', () {
      // The gate. Two views of one editor that disagree about how many
      // cables there are is the divergence CR-107 deleted `StructureDrop`
      // to prevent, arriving through the back door of a tally.
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      final kit = _room(d, 'Kitchen', code: 'KIT');
      final lrPlate = d.outlet('LR-1', locationId: lr);
      final kitPlate = d.outlet('KIT-1', locationId: kit);
      for (var n = 1; n <= 4; n++) {
        _drop(
          d,
          outletId: lrPlate,
          locationId: lr,
          fieldLabel: 'LR-C6-$n',
        );
      }
      _drop(
        d,
        outletId: lrPlate,
        locationId: lr,
        fieldLabel: 'LR-CX-1',
        media: _rg6,
      );
      _drop(d, outletId: kitPlate, locationId: kit, fieldLabel: 'KIT-C6-1');

      final table = buildStructureTable(d.doc);
      final matrix = buildStructureMatrix(d.doc);

      expect(matrix.dropCount, table.dropCount);
      expect(
        matrix.rows.fold<int>(0, (n, r) => n + r.dropCount),
        table.dropCount,
      );
      expect(matrix.columnTotals.fold<int>(0, (n, c) => n + c), 6);
    });

    test('and a room row is exactly that room band drop count', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      final plate = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: plate, locationId: lr, fieldLabel: 'LR-C6-1');
      _drop(
        d,
        outletId: plate,
        locationId: lr,
        fieldLabel: 'LR-CX-1',
        media: _rg6,
      );

      final band = buildStructureTable(d.doc).groups.single;
      final row = _row(buildStructureMatrix(d.doc), 'Living Room')!;
      expect(row.dropCount, band.dropCount);
      expect(row.outletCount, 1);
    });

    test('a link that is not a home run is counted by neither', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      final plate = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: plate, locationId: lr, fieldLabel: 'LR-C6-1');
      AddLinkCommand(
        designator: 'W900',
        netName: 'N900',
        media: _cat6,
        order: const FracIndex('z0'),
        now: _when,
        actor: 'test',
      ).apply(d.doc);

      expect(buildStructureMatrix(d.doc).dropCount, 1);
    });

    test('and a second body drops out when one body is named', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      final plate = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: plate, locationId: lr, fieldLabel: 'LR-C6-1');

      final second = AddStructureCommand(
        title: 'Second',
        designator: 'STR-2',
        now: _when,
        actor: 'test',
      )..apply(d.doc);
      final farPlate = (AddOutletCommand(
        structureBodyId: second.bodyId,
        designation: 'X-1',
        order: nextOutletOrder(d.doc),
        now: _when,
        actor: 'test',
        locationId: lr,
      )..apply(d.doc)).id;
      _drop(d, outletId: farPlate, locationId: lr, fieldLabel: 'X-C6-1');

      expect(buildStructureMatrix(d.doc).dropCount, 2);
      expect(
        buildStructureMatrix(d.doc, structureBodyId: d.bodyId).dropCount,
        1,
      );
    });
  });

  group('AN EMPTY ROOM STILL HAS A ROW, which the table denies it', () {
    test('a room with no drops is a row of zeroes', () {
      // The whole reason the surface exists: a `0` cell is where a
      // person types `2`. A matrix that hid empty rooms would be a
      // bulk-entry grid you cannot enter the first drop on.
      final d = _Doc();
      _room(d, 'Living Room', code: 'LR');
      _room(d, 'Attic', code: 'ATT');

      expect(buildStructureTable(d.doc).groups, isEmpty);

      final matrix = buildStructureMatrix(d.doc);
      expect(matrix.rows.map((r) => r.title), ['Living Room', 'Attic']);
      expect(matrix.rows.every((r) => r.dropCount == 0), isTrue);
      expect(_row(matrix, 'Attic')!.counts, everyElement(0));
    });

    test('rooms are in the tree order, not the creation order', () {
      final d = _Doc();
      final site = _room(d, '123 Oak St', kind: LocationKind.site);
      final level = _room(
        d,
        'Level 1',
        parentId: site,
        kind: LocationKind.floor,
      );
      // Created last, sorted first by its own `order` under Level 1.
      _room(d, 'Office', code: 'OFF', parentId: level);
      _room(d, 'Living Room', code: 'LR', parentId: level);

      final matrix = buildStructureMatrix(d.doc);
      expect(matrix.rows.map((r) => r.title), ['Office', 'Living Room']);
    });

    test('and the indent counts DRAWN rows, so a room sits at 0', () {
      final d = _Doc();
      final site = _room(d, '123 Oak St', kind: LocationKind.site);
      final level = _room(
        d,
        'Level 1',
        parentId: site,
        kind: LocationKind.floor,
      );
      final lr = _room(d, 'Living Room', code: 'LR', parentId: level);
      _room(d, 'Media wall', parentId: lr, kind: LocationKind.zone);

      final matrix = buildStructureMatrix(d.doc);
      expect(_row(matrix, 'Living Room')!.depth, 0);
      expect(_row(matrix, 'Media wall')!.depth, 1);
    });
  });

  group('A ROW IS A PLACE A DROP LANDS, and LocationKind says which', () {
    test('a site, a building and a floor get no row', () {
      final d = _Doc();
      final site = _room(d, '123 Oak St', kind: LocationKind.site);
      final building = _room(
        d,
        'Main house',
        parentId: site,
        kind: LocationKind.building,
      );
      _room(d, 'Level 1', parentId: building, kind: LocationKind.floor);

      expect(buildStructureMatrix(d.doc).rows, isEmpty);
    });

    test('zone and outdoor do, because a cable terminates in one', () {
      final d = _Doc();
      _room(d, 'Media wall', kind: LocationKind.zone);
      _room(d, 'Soffit', kind: LocationKind.outdoor);

      expect(buildStructureMatrix(d.doc).rows, hasLength(2));
    });

    test('but a floor that ALREADY holds drops gets one anyway', () {
      // An import or a reparent can file a drop against a floor, and a
      // matrix that hid the row would hide cable somebody paid for.
      final d = _Doc();
      final level = _room(
        d,
        'Level 1',
        code: 'L1',
        kind: LocationKind.floor,
      );
      final plate = d.outlet('L1-1', locationId: level);
      _drop(d, outletId: plate, locationId: level, fieldLabel: 'L1-C6-1');

      final matrix = buildStructureMatrix(d.doc);
      expect(_row(matrix, 'Level 1')!.dropCount, 1);
    });

    test('a drop whose room is gone lands in the trailing row', () {
      // DR-021 clears references rather than deleting the drops. The
      // table gives them a band and so does this, and the row refuses to
      // be typed into because there is no room to put a new drop in.
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      final plate = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: plate, locationId: lr, fieldLabel: 'LR-C6-1');
      d.controllerlessRemoveRoom(lr);

      final matrix = buildStructureMatrix(d.doc);
      final trailing = matrix.rows.last;
      expect(trailing.locationId, isNull);
      expect(trailing.takesDrops, isFalse);
      expect(trailing.dropCount, 1);
      expect(matrix.dropCount, buildStructureTable(d.doc).dropCount);
    });
  });

  group('THE COLUMNS', () {
    test('are in the registry declaration order, not alphabetical', () {
      // Canon §6.5 groups the 38 types by what they are, and §4.2's own
      // grid is in that order. Alphabetical would put `16/2` in front of
      // `Cat6` and scatter the coax.
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      final plate = d.outlet('LR-1', locationId: lr);
      _drop(
        d,
        outletId: plate,
        locationId: lr,
        fieldLabel: 'LR-SPK-1',
        media: _spk,
      );
      _drop(d, outletId: plate, locationId: lr, fieldLabel: 'LR-C6-1');
      _drop(
        d,
        outletId: plate,
        locationId: lr,
        fieldLabel: 'LR-CX-1',
        media: _rg6,
      );

      expect(buildStructureMatrix(d.doc).columns, [_cat6, _rg6, _spk]);
    });

    test('an asked-for column with no drops is drawn', () {
      final d = _Doc();
      _room(d, 'Living Room', code: 'LR');
      final matrix = buildStructureMatrix(
        d.doc,
        alsoColumns: {_cat6, _rg6},
      );
      expect(matrix.columns, [_cat6, _rg6]);
      expect(_cell(matrix, 'Living Room', _cat6), 0);
    });

    test('an asked-for column the registry cannot fill is NOT drawn', () {
      // Every cell in it would refuse, and a control that can only say
      // no is the `UnbuiltView` defect in one column.
      final d = _Doc(seeded: false);
      _room(d, 'Living Room', code: 'LR');
      expect(
        buildStructureMatrix(d.doc, alsoColumns: {_cat6}).columns,
        isEmpty,
      );
    });

    test('but a dangling media on a real drop KEEPS its column', () {
      // The record that a particular cable went in a particular wall has
      // to outlive the registry entry naming it.
      final d = _Doc(seeded: false);
      final lr = _room(d, 'Living Room', code: 'LR');
      final plate = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: plate, locationId: lr, fieldLabel: 'LR-C6-1');

      final matrix = buildStructureMatrix(d.doc);
      expect(matrix.columns, [_cat6]);
      expect(_cell(matrix, 'Living Room', _cat6), 1);
    });

    test('the seed set is filtered to what the registry carries', () {
      final d = _Doc();
      _room(d, 'Living Room', code: 'LR');
      final matrix = buildStructureMatrix(
        d.doc,
        alsoColumns: kStructureMatrixSeedColumns.toSet(),
      );
      expect(matrix.columns, hasLength(kStructureMatrixSeedColumns.length));

      final bare = _Doc(seeded: false);
      _room(bare, 'Living Room', code: 'LR');
      expect(
        buildStructureMatrix(
          bare.doc,
          alsoColumns: kStructureMatrixSeedColumns.toSet(),
        ).columns,
        isEmpty,
      );
    });

    test('a header is the trade tag, and a dangling id is itself', () {
      final d = _Doc();
      expect(structureMatrixColumnHeader(d.doc, _cat6), 'C6');
      expect(structureMatrixColumnHeader(d.doc, _spk), '16/4');
      expect(
        structureMatrixColumnHeader(d.doc, const MediaTypeId('media.zzz')),
        'media.zzz',
      );
    });

    test('the seed columns are §4.2 nine, and the ninth is EMT', () {
      // THIS ASSERTION USED TO READ `hasLength(8)` with EMT excluded,
      // because the ninth column creates a `Pathway` and nothing in the
      // build could. M3-E/1 is the day named in that comment: the flag,
      // the entity, the drop line and DR-035's two facts all landed, so
      // the column now does what §4.2 says it does.
      expect(kStructureMatrixSeedColumns, hasLength(9));
      expect(
        kStructureMatrixSeedColumns.last,
        const MediaTypeId('media.conduit_emt'),
      );
    });
  });

  group('THE COUNTS', () {
    test('a cell is how many of that media the room holds', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      final plate = d.outlet('LR-1', locationId: lr);
      for (var n = 1; n <= 4; n++) {
        _drop(
          d,
          outletId: plate,
          locationId: lr,
          fieldLabel: 'LR-C6-$n',
        );
      }
      _drop(
        d,
        outletId: plate,
        locationId: lr,
        fieldLabel: 'LR-CX-1',
        media: _rg6,
      );

      final matrix = buildStructureMatrix(d.doc);
      expect(_cell(matrix, 'Living Room', _cat6), 4);
      expect(_cell(matrix, 'Living Room', _rg6), 1);
      expect(_row(matrix, 'Living Room')!.dropCount, 5);
    });

    test('a column total is every room, and it is not the row Σ', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      final kit = _room(d, 'Kitchen', code: 'KIT');
      final lrPlate = d.outlet('LR-1', locationId: lr);
      final kitPlate = d.outlet('KIT-1', locationId: kit);
      _drop(d, outletId: lrPlate, locationId: lr, fieldLabel: 'LR-C6-1');
      _drop(d, outletId: lrPlate, locationId: lr, fieldLabel: 'LR-C6-2');
      _drop(d, outletId: kitPlate, locationId: kit, fieldLabel: 'KIT-C6-1');

      final matrix = buildStructureMatrix(d.doc);
      expect(matrix.columnTotals, [3]);
      expect(_row(matrix, 'Living Room')!.dropCount, 2);
    });

    test('outlets are the plates with a drop on them, not every plate', () {
      // `StructureTable.outletCount`'s own rule: a plate nobody has
      // pulled to is real, and it is not what "2 outlets" means beside
      // "9 drops".
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      final wp1 = d.outlet('WP-1', locationId: lr);
      final wp2 = d.outlet('WP-2', locationId: lr);
      d.outlet('WP-3', locationId: lr);
      _drop(d, outletId: wp1, locationId: lr, fieldLabel: 'LR-C6-1');
      _drop(d, outletId: wp2, locationId: lr, fieldLabel: 'LR-C6-2');

      expect(_row(buildStructureMatrix(d.doc), 'Living Room')!.outletCount, 2);
    });

    test('a landed drop is counted the same as a spare one', () {
      // The matrix counts CABLE. Whether a run is patched is the table's
      // question and the status bar's; a grid that counted only the
      // spares would let somebody order six of a cable they have nine of.
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      final plate = d.outlet('LR-1', locationId: lr);
      _drop(
        d,
        outletId: plate,
        locationId: lr,
        fieldLabel: 'LR-C6-1',
        rackPort: d.panelPort('R01'),
      );
      _drop(d, outletId: plate, locationId: lr, fieldLabel: 'LR-C6-2');

      expect(_cell(buildStructureMatrix(d.doc), 'Living Room', _cat6), 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // §4.2's TINTED `EMT` COLUMN — M3-E/1 (#156), CR-109, DR-032, DR-035
  // ═══════════════════════════════════════════════════════════════════
  // The column that was held out of this grid for three tasks, because
  // a tint with no `Pathway` behind it would have claimed CR-109 held
  // when it did not. What these gate is the half that is easy to get
  // wrong once it is in: the Σ, which §4.2 says excludes it in as many
  // words, and the round trip, without which a cell accepts a number
  // and reads back zero.
  group('a pathway column counts Pathways and not drops', () {
    test('a conduit lands in the cell for its room and medium', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      AddPathwayCommand(
        name: 'Living Room EMT',
        order: nextPathwayOrder(d.doc),
        now: _when,
        actor: 'test',
        pathwayMedia: _emt,
        fromLocationId: lr,
      ).apply(d.doc);

      expect(_cell(buildStructureMatrix(d.doc), 'Living Room', _emt), 1);
    });

    test('it is EXCLUDED from the Σ, which §4.2 states outright', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      final plate = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: plate, locationId: lr, fieldLabel: 'LR-C6-1');
      _drop(d, outletId: plate, locationId: lr, fieldLabel: 'LR-C6-2');
      AddPathwayCommand(
        name: 'Living Room EMT',
        order: nextPathwayOrder(d.doc),
        now: _when,
        actor: 'test',
        pathwayMedia: _emt,
        fromLocationId: lr,
      ).apply(d.doc);

      final row = _row(buildStructureMatrix(d.doc), 'Living Room')!;
      // Two cables and one conduit. A Σ of three would be a number
      // somebody orders cable from.
      expect(row.dropCount, 2);
      expect(row.pathwayCount, 1);
    });

    test('and out of the grid total, which is still the table drop count', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      final plate = d.outlet('LR-1', locationId: lr);
      _drop(d, outletId: plate, locationId: lr, fieldLabel: 'LR-C6-1');
      AddPathwayCommand(
        name: 'Living Room EMT',
        order: nextPathwayOrder(d.doc),
        now: _when,
        actor: 'test',
        pathwayMedia: _emt,
        fromLocationId: lr,
      ).apply(d.doc);

      final m = buildStructureMatrix(d.doc);
      expect(m.dropCount, buildStructureTable(d.doc).dropCount);
      expect(m.dropCount, 1);
    });

    test('a pathway whose room was deleted lands in the trailing band', () {
      // DR-021 clears `fromLocationId` rather than deleting the pathway,
      // so it goes where the orphaned drops go. A conduit that vanished
      // from a screen is a conduit somebody stops accounting for.
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      AddPathwayCommand(
        name: 'Living Room EMT',
        order: nextPathwayOrder(d.doc),
        now: _when,
        actor: 'test',
        pathwayMedia: _emt,
        fromLocationId: lr,
      ).apply(d.doc);
      d.controllerlessRemoveRoom(lr);

      expect(_cell(buildStructureMatrix(d.doc), kUngroupedTitle, _emt), 1);
    });

    test('a pathway with no medium is in no cell, and that is G4', () {
      // What `+ Add pathway` produces: somebody pressed a button and
      // named no medium, so no column can claim it (DR-035 §11.34.5).
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: 'LR');
      AddPathwayCommand(
        name: 'New pathway',
        order: nextPathwayOrder(d.doc),
        now: _when,
        actor: 'test',
        fromLocationId: lr,
      ).apply(d.doc);

      // `alsoColumns` because nothing in the document names EMT: with no
      // medium there is nothing to make the column `present`, which is
      // itself the assertion. The column is the one `⚙ + Media column`
      // and the seed list put on screen.
      final m = buildStructureMatrix(d.doc, alsoColumns: {_emt});
      expect(_cell(m, 'Living Room', _emt), 0);
      expect(d.doc.pathways, hasLength(1));
    });
  });
}

extension on _Doc {
  /// Deletes a room the way DR-021 does, clearing references rather than
  /// deleting the drops that named it.
  void controllerlessRemoveRoom(Uuid id) {
    buildRemoveLocation(doc: doc, locationId: id)!.apply(doc);
  }
}
