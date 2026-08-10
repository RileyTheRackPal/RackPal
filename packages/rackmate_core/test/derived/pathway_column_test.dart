// docs/08 §3.2 column 9, `PATHWAY` (M3-E/2, #157).
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THIS COLUMN PRINTED BEFORE, AND WHY THAT WAS RECORDED HONESTLY
// ═══════════════════════════════════════════════════════════════════════
// docs/08 §3.2 has always specified `Pathway.designator`, and until #157
// the entity had no such field, so `ScheduleEntry.pathwayName` read
// `Pathway.name` and its doc comment said so in as many words. That is
// the good version of a workaround: it named the gap instead of quietly
// filling it. The field now exists and the workaround is retired.
//
// ═══════════════════════════════════════════════════════════════════════
// THE FALLBACK IS NOT THE OVERLOAD DR-026 REFUSED
// ═══════════════════════════════════════════════════════════════════════
// DR-026 §11.25.1 refused to STORE a designator in `name`, because two
// facts written into one field cannot be told apart afterwards. Both are
// stored separately here; the column chooses between them at print time
// and `pathwayLabelIsDesignator` preserves which one it got, so §3.2's
// font can distinguish an identifier from a description. Nothing is lost
// and nothing is guessed.
//
// M6 RENDERS IT (DR-027 §11.26.2). Nothing here asserts a sheet.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 10);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'rriley');

int _seq = 0;
Uuid _mint(String tag) => Uuid('0190e3c1-0000-7000-8000-${tag}${_seq++}');

final class _Job {
  _Job() {
    doc = RackDocument(
      id: const Uuid('0190e3c1-0000-7000-8000-00000000cafe'),
      appVersion: '0.1.0+build.1',
      createdAt: _when,
      modifiedAt: _when,
      meta: _meta(),
      info: ProjectInfo(projectName: 'Pathway column'),
    );
  }
  late final RackDocument doc;
}

Uuid _room(_Job j, String name) {
  final id = _mint('room');
  j.doc.locations[id] = Location(
    id: id,
    kind: LocationKind.room,
    name: name,
    code: 'RM',
    order: FracIndex('a$_seq'),
    meta: _meta(),
  );
  return id;
}

Uuid _pathway(_Job j, String name, {String? designator}) {
  final id = _mint('path');
  j.doc.pathways[id] = Pathway(
    id: id,
    name: name,
    order: FracIndex('a$_seq'),
    meta: _meta(),
    designator: designator,
  );
  return id;
}

/// One drop, on `pull_sheet_clause_test`'s builder. The far end is
/// unbound, which is AC-018's fourteen-of-sixty case and the ordinary
/// state at rough-in.
void _drop(
  _Job j, {
  required String designator,
  required Uuid locationId,
  Uuid? pathwayId,
}) {
  final id = _mint('link');
  j.doc.links[id] = Link(
    id: id,
    designator: designator,
    media: const MediaTypeId('cat6'),
    order: FracIndex('a${_seq.toString().padLeft(4, '0')}'),
    meta: _meta(),
    pathwayId: pathwayId,
    conductors: [
      Conductor(
        from: PlaceEndpoint(description: 'drop', locationId: locationId),
        to: const OpenEndpoint('coil'),
      ),
    ],
    structureOrigin: StructureOrigin(
      structureBodyId: const Uuid('structure-1'),
      outletId: const Uuid('outlet-none'),
      fieldLabel: designator,
    ),
  );
}

ScheduleEntry _rowFor(RackDocument doc, String designator) =>
    scheduleViewOf(doc, preset: SchedulePreset.pullSheet).rows.firstWhere(
      (r) => r.designator == designator,
    );

/// The `PATHWAY` cell. `units` reaches only the LENGTH column, so which
/// system is passed is irrelevant here and naming that keeps the next
/// reader from wondering.
String _pathwayCell(ScheduleEntry row) =>
    row.cell(ScheduleColumnId.pathway, units: UnitSystem.imperial);

void main() {
  group('the PATHWAY cell', () {
    test('prints the DESIGNATOR when one is written, and says it is one', () {
      final j = _Job();
      final room = _room(j, 'Living Room');
      final trunk = _pathway(
        j,
        'attic run to the garage',
        designator: 'T1',
      );
      _drop(j, designator: 'W001', locationId: room, pathwayId: trunk);

      final row = _rowFor(j.doc, 'W001');
      expect(_pathwayCell(row), 'T1');
      expect(row.pathwayLabelIsDesignator, isTrue);
    });

    test('falls back to the NAME when no designator is written, and says it '
        'is NOT a designator', () {
      // Without the fallback, every project in existence loses this column
      // to em rules the day the field ships, because no pathway anywhere
      // carries a designator yet.
      final j = _Job();
      final room = _room(j, 'Living Room');
      final trunk = _pathway(j, 'attic run to the garage');
      _drop(j, designator: 'W001', locationId: room, pathwayId: trunk);

      final row = _rowFor(j.doc, 'W001');
      expect(_pathwayCell(row), 'attic run to the garage');
      expect(row.pathwayLabelIsDesignator, isFalse);
    });

    test('BOTH FACTS SURVIVE onto the row, so nothing downstream has to '
        'reverse the fallback', () {
      final j = _Job();
      final room = _room(j, 'Living Room');
      final trunk = _pathway(j, 'attic run to the garage', designator: 'T1');
      _drop(j, designator: 'W001', locationId: room, pathwayId: trunk);

      final row = _rowFor(j.doc, 'W001');
      expect(row.pathwayDesignator, 'T1');
      expect(row.pathwayName, 'attic run to the garage');
    });

    test('a drop in no pathway prints the unknown marker, not an empty '
        'cell (G4)', () {
      final j = _Job();
      final room = _room(j, 'Living Room');
      _drop(j, designator: 'W001', locationId: room);

      final row = _rowFor(j.doc, 'W001');
      expect(_pathwayCell(row), kUnknownCell);
      expect(row.pathwayLabelIsDesignator, isFalse);
    });
  });

  group('grouping and sorting follow the cell', () {
    test('the band title is the value the cells under it print', () {
      // A band headed `T1` over rows reading "attic run to the garage" is
      // a sheet disagreeing with itself.
      final j = _Job();
      final room = _room(j, 'Living Room');
      final labelled = _pathway(j, 'attic run to the garage', designator: 'T1');
      final unlabelled = _pathway(j, 'riser to level 2');
      _drop(j, designator: 'W001', locationId: room, pathwayId: labelled);
      _drop(j, designator: 'W002', locationId: room, pathwayId: unlabelled);

      final view = scheduleViewOf(
        j.doc,
        preset: SchedulePreset.pullSheet,
        grouping: ScheduleGrouping.pathway,
      );

      for (final band in view.groups) {
        for (final row in band.rows) {
          expect(
            _pathwayCell(row),
            band.title,
            reason:
                'band "${band.title}" carries a row printing '
                '"${_pathwayCell(row)}"',
          );
        }
      }
    });

    test('rows with no pathway band under NO PATHWAY RECORDED, which is not '
        'a pathway called that', () {
      final j = _Job();
      final room = _room(j, 'Living Room');
      _drop(j, designator: 'W001', locationId: room);

      final view = scheduleViewOf(
        j.doc,
        preset: SchedulePreset.pullSheet,
        grouping: ScheduleGrouping.pathway,
      );
      expect(view.groups.single.title, kNoPathwayGroupTitle);
      expect(view.groups.single.key, isNull);
    });

    test('room-then-pathway sorts on the printed value, and stays total', () {
      // `Zulu trunk` has designator `A1`, `Alpha trunk` has none. Sorting
      // on the NAME would order Alpha first; sorting on what prints puts
      // `A1` first. The point is not which is nicer, it is that the order
      // matches the column a reader is scanning.
      final j = _Job();
      final room = _room(j, 'Living Room');
      final zulu = _pathway(j, 'Zulu trunk', designator: 'A1');
      final alpha = _pathway(j, 'Alpha trunk');
      _drop(j, designator: 'W002', locationId: room, pathwayId: alpha);
      _drop(j, designator: 'W001', locationId: room, pathwayId: zulu);

      final rows = scheduleViewOf(
        j.doc,
        preset: SchedulePreset.pullSheet,
        sort: ScheduleSort.roomThenPathway,
      ).rows;

      expect(
        rows.map((r) => _pathwayCell(r)),
        orderedEquals(<String>['A1', 'Alpha trunk']),
      );
    });
  });
}
