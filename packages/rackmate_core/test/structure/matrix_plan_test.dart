// M3-C/3, #149 — one matrix cell, changed.
//
// WHAT THESE GATE. docs/07 §4.2 is one sentence and three of its clauses
// are rules a surface could quietly get wrong: N drops in ONE command,
// the HIGHEST-SEQUENCE unconnected ones on a decrement, and a REFUSAL
// rather than a deletion when a run is patched. The last is the one with
// consequences, because the alternative to refusing is unwiring a panel
// somebody has already terminated.
//
// The tests apply the returned commands themselves rather than through a
// controller: what is being pinned is the PLAN, and the transaction that
// carries it is the app layer's.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 8);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const MediaTypeId _cat6 = MediaTypeId('media.cat6');
const MediaTypeId _rg6 = MediaTypeId('media.rg6');

final class _Doc {
  _Doc({bool withStructure = true})
    : doc = RackDocument(
        id: const Uuid('doc-matrix-plan'),
        appVersion: 'test',
        createdAt: _when,
        modifiedAt: _when,
        meta: _meta(),
      ) {
    doc.registries = buildSeedRegistries();
    if (withStructure) {
      bodyId = (AddStructureCommand(
        title: 'Rough-In',
        designator: 'STR-1',
        now: _when,
        actor: 'test',
      )..apply(doc)).bodyId;
    }
  }

  final RackDocument doc;
  Uuid? bodyId;
  int _seq = 0;

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

Uuid _room(_Doc d, String name, {String code = 'LR'}) => (AddLocationCommand(
  name: name,
  code: code,
  order: nextLocationOrder(d.doc),
  now: _when,
  actor: 'test',
)..apply(d.doc)).id;

/// Sets a cell the way the app layer does: plan, then apply the whole
/// list or none of it.
MatrixCellPlan _set(
  _Doc d, {
  required Uuid locationId,
  required MediaTypeId media,
  required int to,
}) {
  final plan = planMatrixCell(
    doc: d.doc,
    locationId: locationId,
    media: media,
    targetCount: to,
    now: _when,
    actor: 'test',
    structureBodyId: d.bodyId,
  );
  if (plan case MatrixCellReady(:final commands)) {
    for (final c in commands) {
      c.apply(d.doc);
    }
  }
  return plan;
}

/// Patches a drop into a real panel port, which is what makes it
/// CONNECTED and therefore undeletable from the grid.
///
/// The rack end is `Conductor.to` (`buildAddHomeRunCommand` puts the
/// field end in `from`), and a `Conductor` is immutable, so the list
/// entry is replaced rather than mutated.
void _land(_Doc d, Uuid linkId) {
  final link = d.doc.links[linkId]!;
  final was = link.conductors.first;
  link.conductors[0] = Conductor(
    from: was.from,
    to: PortEndpoint(d.panelPort('R${d._seq}')),
    role: was.role,
  );
}

/// What the grid says [locationId] holds of [media].
///
/// [media] IS PASSED AS AN ASKED-FOR COLUMN, which is what a surface
/// showing that column does. Without it a cell emptied to zero would
/// take its whole column off the grid, and `indexOf` would answer -1 —
/// correct behaviour, and not the question this helper is asking.
int _cell(_Doc d, Uuid locationId, MediaTypeId media) {
  final matrix = buildStructureMatrix(
    d.doc,
    structureBodyId: d.bodyId,
    alsoColumns: {media},
  );
  final row = matrix.rows.firstWhere((r) => r.locationId == locationId);
  return row.counts[matrix.columns.indexOf(media)];
}

void main() {
  group('AN INCREMENT MATERIALISES DROPS', () {
    test('0 to 2 is two Links, one outlet and one undo entry', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');

      final plan = _set(d, locationId: lr, media: _cat6, to: 2);

      expect(plan, isA<MatrixCellReady>());
      final ready = plan as MatrixCellReady;
      expect(ready.added, 2);
      expect(ready.removed, 0);
      // One outlet plus two drops, in that order, in ONE list a caller
      // applies inside one transaction.
      expect(ready.commands, hasLength(3));
      expect(ready.commands.first, isA<AddOutletCommand>());
      expect(d.doc.links, hasLength(2));
      expect(_cell(d, lr, _cat6), 2);
    });

    test('and the labels are allocated, not left for later', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      final plan =
          _set(d, locationId: lr, media: _cat6, to: 2) as MatrixCellReady;

      expect(plan.fieldLabels, hasLength(2));
      expect(plan.fieldLabels.toSet(), hasLength(2));
      for (final label in plan.fieldLabels) {
        expect(label, contains('LR'));
      }
    });

    test('a cell already at that number produces nothing at all', () {
      // Tabbing across sixty cells commits every one of them. A no-op
      // that produced a command would cost an undo step per keystroke.
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 2);

      expect(
        _set(d, locationId: lr, media: _cat6, to: 2),
        isA<MatrixCellUnchanged>(),
      );
      expect(d.doc.links, hasLength(2));
    });

    test('raising an existing cell adds only the difference', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 2);

      final plan =
          _set(d, locationId: lr, media: _cat6, to: 5) as MatrixCellReady;
      expect(plan.added, 3);
      expect(_cell(d, lr, _cat6), 5);
    });

    test('a cell is a TARGET, so it is read off the current document', () {
      // The widget's own idea of the count goes stale on an undo, on a
      // typed line, on a second window. This is what makes the number
      // mean the same thing every time.
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 4);
      // Something else takes two out from under the grid.
      _set(d, locationId: lr, media: _cat6, to: 2);

      expect(
        (_set(d, locationId: lr, media: _cat6, to: 3) as MatrixCellReady).added,
        1,
      );
    });

    test('one media column does not disturb another', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 4);
      _set(d, locationId: lr, media: _rg6, to: 2);

      expect(_cell(d, lr, _cat6), 4);
      expect(_cell(d, lr, _rg6), 2);
    });

    test('nor does one room disturb another', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      final kit = _room(d, 'Kitchen', code: 'KIT');
      _set(d, locationId: lr, media: _cat6, to: 4);
      _set(d, locationId: kit, media: _cat6, to: 1);

      expect(_cell(d, lr, _cat6), 4);
      expect(_cell(d, kit, _cat6), 1);
    });
  });

  group('AN INCREMENT CREATES A PLATE, exactly as the typed line does', () {
    test('each gesture is its own outlet, and the Outlets column says so', () {
      // The matrix does not know about plates: a cell is a room and a
      // cable, and a real plate is mixed media. Joining the room's first
      // outlet would put speaker cable on a TV plate somebody else made.
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 4);
      _set(d, locationId: lr, media: _rg6, to: 2);

      expect(d.doc.outlets, hasLength(2));
      final matrix = buildStructureMatrix(d.doc);
      expect(matrix.rows.single.outletCount, 2);
    });

    test('and a decrement never takes the outlet with it', () {
      // A plate with no drops is a real state, and deleting one because
      // the last drop left would destroy an entity another gesture may
      // have created deliberately.
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 2);
      _set(d, locationId: lr, media: _cat6, to: 0);

      expect(d.doc.links, isEmpty);
      expect(d.doc.outlets, hasLength(1));
    });
  });

  group('A DECREMENT TAKES THE HIGHEST-SEQUENCE UNCONNECTED DROPS', () {
    test('4 to 2 deletes the last two in the table order', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 4);

      final before = [
        for (final row in buildStructureTable(d.doc).groups.single.rows)
          row.fieldLabel,
      ];
      final plan =
          _set(d, locationId: lr, media: _cat6, to: 2) as MatrixCellReady;

      expect(plan.removed, 2);
      expect(plan.added, 0);
      final after = [
        for (final row in buildStructureTable(d.doc).groups.single.rows)
          row.fieldLabel,
      ];
      // The FIRST two survive, which is what "highest-sequence" means
      // read off the table's own order.
      expect(after, before.sublist(0, 2));
    });

    test('to 0 empties the cell and leaves the other column alone', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 3);
      _set(d, locationId: lr, media: _rg6, to: 2);

      _set(d, locationId: lr, media: _cat6, to: 0);
      expect(_cell(d, lr, _cat6), 0);
      expect(_cell(d, lr, _rg6), 2);
    });

    test('the net goes with the link, because no survivor names it', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 1);
      expect(d.doc.nets, hasLength(1));

      _set(d, locationId: lr, media: _cat6, to: 0);
      expect(d.doc.nets, isEmpty);
    });

    test('and undo puts every deleted drop back', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 4);
      final labels = [
        for (final row in buildStructureTable(d.doc).groups.single.rows)
          row.fieldLabel,
      ];

      final plan =
          planMatrixCell(
                doc: d.doc,
                locationId: lr,
                media: _cat6,
                targetCount: 1,
                now: _when,
                actor: 'test',
                structureBodyId: d.bodyId,
              )
              as MatrixCellReady;
      for (final c in plan.commands) {
        c.apply(d.doc);
      }
      expect(_cell(d, lr, _cat6), 1);

      for (final c in plan.commands.reversed) {
        c.revert(d.doc);
      }
      expect(_cell(d, lr, _cat6), 4);
      expect([
        for (final row in buildStructureTable(d.doc).groups.single.rows)
          row.fieldLabel,
      ], labels);
    });
  });

  group('AND IT REFUSES TO DELETE A CONNECTED ONE (CR-017)', () {
    test('a patched run survives and the highest-sequence SPARE goes', () {
      // §4.2's clause is "the highest-sequence UNCONNECTED drops", so a
      // landed run at the bottom of the cell is stepped over rather than
      // taken, and rather than making the whole gesture refuse.
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 3);

      final rows = buildStructureTable(d.doc).groups.single.rows;
      _land(d, rows.last.linkId);

      expect(
        _set(d, locationId: lr, media: _cat6, to: 2),
        isA<MatrixCellReady>(),
      );
      final after = [
        for (final row in buildStructureTable(d.doc).groups.single.rows)
          row.linkId,
      ];
      expect(after, contains(rows.last.linkId));
      expect(after, contains(rows.first.linkId));
      expect(after, isNot(contains(rows[1].linkId)));
    });

    test('the refusal names the floor the cell cannot go below', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 3);
      for (final row in buildStructureTable(d.doc).groups.single.rows) {
        _land(d, row.linkId);
      }

      final plan = _set(d, locationId: lr, media: _cat6, to: 1);
      expect(plan, isA<MatrixCellRefused>());
      final reason = (plan as MatrixCellRefused).reason;
      expect(reason, contains('Living Room'));
      expect(reason, contains('cannot go below 3'));
      expect(_cell(d, lr, _cat6), 3);
    });

    test('it is all or nothing: a partial deletion never happens', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      _set(d, locationId: lr, media: _cat6, to: 4);
      // Two spare, two landed. Asking for 1 needs three and can only
      // have two.
      for (final row in buildStructureTable(d.doc).groups.single.rows.take(2)) {
        _land(d, row.linkId);
      }

      expect(
        _set(d, locationId: lr, media: _cat6, to: 1),
        isA<MatrixCellRefused>(),
      );
      expect(_cell(d, lr, _cat6), 4);
      // And the reachable target still works.
      expect(
        _set(d, locationId: lr, media: _cat6, to: 2),
        isA<MatrixCellReady>(),
      );
      expect(_cell(d, lr, _cat6), 2);
    });
  });

  group('THE REFUSALS THAT ARE NOT ABOUT PATCHING', () {
    test('a blank project offers to create the Structure device', () {
      // An offer rather than an error, for the same reason the drop
      // line's is: it is the one thing every blank project is missing.
      final d = _Doc(withStructure: false);
      final lr = _room(d, 'Living Room');
      expect(
        planMatrixCell(
          doc: d.doc,
          locationId: lr,
          media: _cat6,
          targetCount: 2,
          now: _when,
          actor: 'test',
        ),
        isA<MatrixCellNeedsStructure>(),
      );
    });

    test('two Structure devices and no id refuses rather than guessing', () {
      // Filing sixty drops on the wrong body puts them on the wrong
      // sheet. Picking between them is #158.
      final d = _Doc();
      AddStructureCommand(
        title: 'Second',
        designator: 'STR-2',
        now: _when,
        actor: 'test',
      ).apply(d.doc);
      final lr = _room(d, 'Living Room');

      expect(
        planMatrixCell(
          doc: d.doc,
          locationId: lr,
          media: _cat6,
          targetCount: 2,
          now: _when,
          actor: 'test',
        ),
        isA<MatrixCellRefused>(),
      );
      // Named, it proceeds.
      expect(
        planMatrixCell(
          doc: d.doc,
          locationId: lr,
          media: _cat6,
          targetCount: 2,
          now: _when,
          actor: 'test',
          structureBodyId: d.bodyId,
        ),
        isA<MatrixCellReady>(),
      );
    });

    test('a room that is gone refuses', () {
      final d = _Doc();
      expect(
        planMatrixCell(
          doc: d.doc,
          locationId: const Uuid('no-such-room'),
          media: _cat6,
          targetCount: 2,
          now: _when,
          actor: 'test',
        ),
        isA<MatrixCellRefused>(),
      );
    });

    test('a negative target refuses', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      expect(
        planMatrixCell(
          doc: d.doc,
          locationId: lr,
          media: _cat6,
          targetCount: -1,
          now: _when,
          actor: 'test',
        ),
        isA<MatrixCellRefused>(),
      );
    });

    test('a media type this project does not carry refuses', () {
      final d = _Doc();
      final lr = _room(d, 'Living Room');
      final plan = planMatrixCell(
        doc: d.doc,
        locationId: lr,
        media: const MediaTypeId('media.unobtainium'),
        targetCount: 2,
        now: _when,
        actor: 'test',
      );
      expect(plan, isA<MatrixCellRefused>());
      expect(
        (plan as MatrixCellRefused).reason,
        contains('media.unobtainium'),
      );
    });

    test('a room with no code refuses, and the sentence says which', () {
      // `{ROOM_ABBR}` reads `Location.code`, so a room being named and
      // not labelled cannot have its drops labelled. The line refuses
      // the same way, and CR-046 is why the field exists.
      final d = _Doc();
      final lr = _room(d, 'Living Room', code: '');
      final plan = planMatrixCell(
        doc: d.doc,
        locationId: lr,
        media: _cat6,
        targetCount: 2,
        now: _when,
        actor: 'test',
      );
      expect(plan, isA<MatrixCellRefused>());
      expect((plan as MatrixCellRefused).reason, contains('Living Room'));
    });
  });
}
