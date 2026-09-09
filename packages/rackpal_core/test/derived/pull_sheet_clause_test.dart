// M3's half of exit clause 3, as amended by DR-027 §11.26.2. Board
// M3-D/4 (#155).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS FILE EXISTS WHEN EVERY PART OF IT IS ALREADY TESTED
// ═══════════════════════════════════════════════════════════════════════
// The sort, the grouping and the footage rollup each have cases in
// `schedule_test.dart`, and they pass. What none of them does is assert
// the CLAUSE, which is a compound claim about one document:
//
//   "...exports a Pull Sheet sorted by room and pathway with per-room
//    footage subtotals and initial boxes."
//
// §8.1 makes the exit criterion the unit of truth and says done means
// demonstrated. A milestone whose evidence is three unit tests that were
// never pointed at the same document has demonstrated three mechanisms,
// not the clause. This file points them at one rough-in.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT M3 OWES AND WHAT IT DOES NOT — DR-027 §11.26.2
// ═══════════════════════════════════════════════════════════════════════
// M3 owes the DERIVATION: the rows, the sort by room then pathway, and
// the per-room footage subtotals, "as tested output of `rackpal_core`".
// That phrase is why this is a core test and not an export test.
//
// M6 owes the SHEET: the `SheetRole`, the layout, THE INITIAL BOXES and
// the page. `SheetRole` has three values and none is a Pull Sheet
// (`draw/sheet/sheet_def.dart`), so nothing here asserts a rendered
// artifact, and the clause's "initial boxes" are deliberately absent
// from this file. Reading the clause loosely enough to claim them in M3
// is the checklist-ticking §8.1 refuses.
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIXTURE IS BUILT TO FALSIFY, NOT TO AGREE
// ═══════════════════════════════════════════════════════════════════════
// Rooms are created in an order that is NOT their sorted order, and the
// pathways likewise, so a build that merely preserved insertion order
// would fail rather than coincide. Lengths are deliberately mixed —
// measured, estimated and unknown — because a subtotal is only
// interesting when it has something to be ignorant about.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 9);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _cat6 = MediaTypeId('media.cat6');

Len _ft(int feet) => Len(feet * 12 * Len.nmPerInch);

final class _Job {
  _Job()
    : doc = RackDocument(
        id: const Uuid('doc-clause3'),
        appVersion: 'test',
        createdAt: _when,
        modifiedAt: _when,
        meta: _meta(),
      );

  final RackDocument doc;
  int _seq = 0;

  Uuid _mint(String prefix) => Uuid('$prefix-${_seq++}');
}

Uuid _room(_Job j, String name) {
  final id = j._mint('loc');
  j.doc.locations[id] = Location(
    id: id,
    kind: LocationKind.room,
    name: name,
    code: 'RM',
    order: FracIndex('a${j._seq}'),
    meta: _meta(),
  );
  return id;
}

Uuid _pathway(_Job j, String name) {
  final id = j._mint('path');
  j.doc.pathways[id] = Pathway(
    id: id,
    name: name,
    order: FracIndex('a${j._seq}'),
    meta: _meta(),
  );
  return id;
}

Uuid _outlet(_Job j, Uuid locationId, {Len? nominalRunLength}) {
  final id = j._mint('outlet');
  j.doc.outlets[id] = Outlet(
    id: id,
    structureBodyId: const Uuid('structure-1'),
    designation: 'O${j._seq}',
    locationId: locationId,
    order: FracIndex('a${j._seq}'),
    meta: _meta(),
    nominalRunLength: nominalRunLength,
  );
  return id;
}

/// One drop. [to] defaults to an unbound far end, which is AC-018's
/// fourteen-of-sixty case and the ordinary state at rough-in.
Uuid _drop(
  _Job j, {
  required String designator,
  required Uuid locationId,
  Uuid? pathwayId,
  Uuid? outletId,
  Len? cutLength,
  Endpoint to = const OpenEndpoint('coil'),
}) {
  final id = j._mint('link');
  j.doc.links[id] = Link(
    id: id,
    designator: designator,
    media: _cat6,
    order: FracIndex('a${j._seq.toString().padLeft(4, '0')}'),
    meta: _meta(),
    cutLength: cutLength,
    pathwayId: pathwayId,
    conductors: [
      Conductor(
        from: PlaceEndpoint(description: 'drop', locationId: locationId),
        to: to,
      ),
    ],
    structureOrigin: StructureOrigin(
      structureBodyId: const Uuid('structure-1'),
      outletId: outletId ?? const Uuid('outlet-none'),
      fieldLabel: designator,
    ),
  );
  return id;
}

/// A rough-in across three rooms and two pathways.
///
/// CREATION ORDER IS DELIBERATELY WRONG. The rooms are made Kitchen,
/// Attic, Bedroom and the pathways Riser then Attic Run, so the expected
/// output below is never the order anything was inserted in.
_Job _roughIn() {
  final j = _Job();
  final kitchen = _room(j, 'Kitchen');
  final attic = _room(j, 'Attic');
  final bedroom = _room(j, 'Bedroom');
  final riser = _pathway(j, 'Riser');
  final atticRun = _pathway(j, 'Attic Run');

  // Kitchen: one measured, one estimated through its outlet, one that
  // nobody has any figure for at all.
  final kitchenOutlet = _outlet(j, kitchen, nominalRunLength: _ft(45));
  _drop(
    j,
    designator: 'W001',
    locationId: kitchen,
    pathwayId: riser,
    cutLength: _ft(52),
  );
  _drop(
    j,
    designator: 'W002',
    locationId: kitchen,
    pathwayId: atticRun,
    outletId: kitchenOutlet,
  );
  _drop(j, designator: 'W003', locationId: kitchen, pathwayId: riser);

  // Attic: both measured.
  _drop(
    j,
    designator: 'W004',
    locationId: attic,
    pathwayId: atticRun,
    cutLength: _ft(30),
  );
  _drop(
    j,
    designator: 'W005',
    locationId: attic,
    pathwayId: atticRun,
    cutLength: _ft(20),
  );

  // Bedroom: nothing known at all, which is the room that must not
  // print as if it needed no cable.
  _drop(j, designator: 'W006', locationId: bedroom, pathwayId: riser);
  return j;
}

ScheduleView _pullSheet(RackDocument doc) =>
    scheduleViewOf(doc, preset: SchedulePreset.pullSheet);

void main() {
  group('clause 3, the half M3 owes (DR-027 §11.26.2)', () {
    test('every drop is on the sheet, including the unbound far ends '
        '(AC-018)', () {
      // G1 first: the schedule is the deliverable, and a run missing
      // from it is a cable nobody pulls. All six of these have open far
      // ends, which is the state AC-018 puts fourteen of sixty drops in.
      final view = _pullSheet(_roughIn().doc);
      expect(view.rowCount, 6);
      expect(
        view.rows.map((r) => r.designator),
        containsAll(['W001', 'W002', 'W003', 'W004', 'W005', 'W006']),
        reason:
            'an unbound far end still schedules and still carries a W '
            'number',
      );
      expect(view.exclusions.total, 0);
    });

    test('sorted by ROOM, then PATHWAY, then designator', () {
      // The clause names two keys and §3.6 supplies the third. Attic
      // before Bedroom before Kitchen is alphabetical and is NOT the
      // order the rooms were created in; within Kitchen, Attic Run
      // precedes Riser for the same reason.
      final view = _pullSheet(_roughIn().doc);
      expect(view.sort, ScheduleSort.roomThenPathway);
      expect(
        view.rows.map((r) => r.designator),
        orderedEquals(
          // Attic (Attic Run) · Bedroom (Riser) · Kitchen (Attic Run, then
          // Riser, and W001 before W003 on the designator tiebreak).
          ['W004', 'W005', 'W006', 'W002', 'W001', 'W003'],
        ),
      );
    });

    test('the bands are the rooms, in that same order', () {
      final view = _pullSheet(_roughIn().doc);
      expect(view.grouping, ScheduleGrouping.room);
      expect(
        view.groups.map((g) => g.title),
        orderedEquals(['Attic', 'Bedroom', 'Kitchen']),
      );
      expect(
        view.groups.fold<int>(0, (n, g) => n + g.rowCount),
        view.rowCount,
        reason: 'every row is in exactly one band',
      );
    });

    test('per-room footage subtotals, each stating what it could not '
        'see', () {
      final view = _pullSheet(_roughIn().doc);
      final byTitle = {for (final g in view.groups) g.title: g};

      // Measured only: 30 + 20, nothing unknown.
      final attic = byTitle['Attic']!;
      expect(attic.footage.value, _ft(50));
      expect(attic.footage.knownCount, 2);
      expect(attic.footage.unknownCount, 0);
      expect(attic.estimatedCount, 0);

      // Mixed: a cut 52 and an estimated 45 are both quantities, one
      // drop supplies nothing, and the estimate is counted separately so
      // the subtotal's standing is visible (§3.8's "3 estimated").
      final kitchen = byTitle['Kitchen']!;
      expect(kitchen.footage.value, _ft(97));
      expect(kitchen.footage.knownCount, 2);
      expect(kitchen.footage.unknownCount, 1);
      expect(kitchen.estimatedCount, 1);

      // AND THE ROOM NOBODY HAS MEASURED IS UNKNOWN, NOT ZERO (G4).
      // This is the assertion the whole clause turns on: a subtotal of
      // `0` here reads as "this room needs no cable".
      final bedroom = byTitle['Bedroom']!;
      expect(bedroom.footage.isUnknown, isTrue);
      expect(bedroom.footage.value, isNull);
      expect(bedroom.footage.unknownCount, 1);
    });

    test('the sheet-wide total agrees with the bands and counts the '
        'gaps', () {
      final view = _pullSheet(_roughIn().doc);
      expect(view.footage.value, _ft(147));
      expect(view.footage.knownCount, 4);
      expect(view.footage.unknownCount, 2);
      expect(view.estimatedCount, 1);
    });

    test('and the whole derivation is deterministic (§8.4)', () {
      // Two builds of an unmodified document produce the identical
      // table: same rows in the same order, same bands, same subtotals.
      final doc = _roughIn().doc;
      final first = _pullSheet(doc);
      final second = _pullSheet(doc);
      expect(
        second.rows.map((r) => r.designator),
        orderedEquals(first.rows.map((r) => r.designator)),
      );
      expect(
        second.groups.map((g) => g.title),
        orderedEquals(first.groups.map((g) => g.title)),
      );
      expect(
        second.groups.map((g) => g.footage.value),
        orderedEquals(first.groups.map((g) => g.footage.value)),
      );
    });
  });

  group('what this clause does NOT reach, so M6 is not read as done', () {
    test('there is no Pull Sheet role to render one with', () {
      // DR-027 §11.26.2 in executable form. If a `SheetRole.pullSheet`
      // ever appears, this case fails and whoever added it has to decide
      // whether M3's clause or M6's now owns the sheet — which is the
      // conversation the seam exists to force.
      expect(
        SheetRole.values.map((r) => r.name),
        orderedEquals([
          // `devicePlan` ARRIVED AT `PLAN-H/1` AND IS NOT THIS CASE'S
          // QUARRY. docs/15 §8 rules `T1.01` into v1 with the Plan view,
          // so a fourth role is a ruling being applied rather than M6's
          // work leaking into M3. The list is asserted whole, rather than
          // the absence checked alone, precisely so an addition has to be
          // looked at: this one was, and it is legitimate.
          'devicePlan',
          'rackElevationFront',
          'rackElevationRear',
          'equipmentList',
        ]),
        reason:
            'M6 owes the sheet: the SheetRole, the layout, the initial '
            'boxes and the page',
      );
      // THE ACTUAL CLAIM, stated so it survives the next legitimate
      // addition without anybody having to re-read the list above.
      expect(
        SheetRole.values.map((r) => r.name),
        isNot(contains('pullSheet')),
        reason: 'DR-027 §11.26.2: M3 owes the rows, M6 owns the sheet',
      );
    });
  });
}
