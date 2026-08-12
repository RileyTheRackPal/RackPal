// DR-047 §11.46.4's table, asserted as the ARTIFACT it produces: what a
// materials sheet would order for one plate.
//
// The cases that matter are the two the ruling had to choose between, and
// the one G4 governs. An all-brush plate is ONE part; a mixed plate is a
// Decora plate plus inserts; and a plate with an opening nobody has fitted
// cannot be named at all, because that opening is exactly what decides
// between the first two.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 12);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _outletId = Uuid('22222222-2222-4222-8222-222222222222');
const _bodyId = Uuid('11111111-1111-4111-8111-111111111111');

Outlet _outlet(List<Gang> gangs) => Outlet(
  id: _outletId,
  structureBodyId: _bodyId,
  designation: 'WP-1',
  order: const FracIndex('a0'),
  meta: _meta(),
  gangs: gangs,
);

Gang _brush() => Gang(fitting: const PassThrough(PassThroughStyle.brush));
Gang _bullNose() => Gang(fitting: const PassThrough(PassThroughStyle.bullNose));
Gang _strap(int w, int h) => Gang(
  fitting: Strap(width: w, height: h),
);

void main() {
  group('the plate the fittings imply', () {
    test('no gangs is no plate, not a 0-gang one', () {
      // §11.44.4's plateless outlet, unchanged by this ruling. An access
      // point screwed to the box needs no part at all.
      final m = computePlateMaterials(_outlet([]));
      expect(m.coverPlate, CoverPlateKind.none);
      expect(m.coverPlateGangs, 0);
      expect(m.passThroughInserts, isEmpty);
    });

    test('every opening brushed is ONE brush plate and no inserts', () {
      final m = computePlateMaterials(_outlet([_brush(), _brush()]));
      expect(m.coverPlate, CoverPlateKind.brush);
      expect(m.coverPlateGangs, 2);
      // ORDERING THE INSERTS TOO WOULD BE ORDERING THE SAME HOLE TWICE.
      expect(m.passThroughInserts, isEmpty);
    });

    test('a strap beside a brush is a Decora plate PLUS one insert', () {
      // The stock fact the user settled: nobody manufactures every
      // Decora-plus-brush combination, so a mixed plate is bought as a
      // standard plate and an insert.
      final m = computePlateMaterials(_outlet([_strap(1, 2), _brush()]));
      expect(m.coverPlate, CoverPlateKind.decora);
      expect(m.coverPlateGangs, 2);
      expect(m.passThroughInserts, [PassThroughStyle.brush]);
      expect(m.strapPortCounts, [2]);
    });

    test('two DIFFERENT pass-through styles is also a plate plus inserts', () {
      // Which is why the rule keys on "one style" and not on "all
      // pass-through": a plate brushed at one opening and bull-nose at
      // the next is not a part anybody makes either.
      final m = computePlateMaterials(_outlet([_brush(), _bullNose()]));
      expect(m.coverPlate, CoverPlateKind.decora);
      expect(m.passThroughInserts, [
        PassThroughStyle.brush,
        PassThroughStyle.bullNose,
      ]);
    });

    test('all straps is the plate this product already ordered', () {
      final m = computePlateMaterials(_outlet([_strap(2, 3), _strap(1, 1)]));
      expect(m.coverPlate, CoverPlateKind.decora);
      expect(m.strapPortCounts, [6, 1]);
      expect(m.passThroughInserts, isEmpty);
    });
  });

  group('an opening nobody has fitted (G4)', () {
    test('with no strap to settle it, the plate cannot be NAMED', () {
      // Not "missing" and not "Decora". The unfitted gang could still
      // turn this into an integral brush plate, and naming a part on the
      // strength of an absence of work is the defect G4 exists to stop.
      final m = computePlateMaterials(_outlet([_brush(), Gang()]));
      expect(m.coverPlate, CoverPlateKind.unknown);
      expect(m.coverPlateGangs, 2, reason: 'how many openings IS known');
      expect(m.gangsUnchosen, 1);
      expect(m.isComplete, isFalse);
      // The insert travels with the plate: the same opening is either an
      // insert or part of the plate, so neither answer is emitted.
      expect(m.passThroughInserts, isEmpty);
    });

    test('a strap anywhere settles it as Decora whatever else is open', () {
      // A strap needs a Decora opening, and no later decision can change
      // that. So the plate is nameable even with a gang still open.
      final m = computePlateMaterials(_outlet([_strap(1, 1), Gang()]));
      expect(m.coverPlate, CoverPlateKind.decora);
      expect(m.gangsUnchosen, 1);
      // A LOWER BOUND, and gangsUnchosen is what says so.
      expect(m.strapPortCounts, [1]);
    });

    test('straps and blanks stay exact while a gang is open', () {
      // Withholding a count somebody HAS decided because a different
      // opening is undecided would be counting down instead of counting.
      final strap = Strap(width: 1, height: 2)
        ..cells[0] = const BlankInsert()
        ..cells[1] = const BlankInsert();
      final m = computePlateMaterials(
        _outlet([Gang(fitting: strap), Gang()]),
      );
      expect(m.blankInserts, 2);
      expect(m.strapPortCounts, [2]);
    });
  });

  test('an undecided cell is not a blank and is not ordered', () {
    // §11.7.4, and the reason nothing auto-blanks: two blanks on every
    // plate a designer had not finished is a parts order derived from an
    // absence of work.
    final m = computePlateMaterials(
      _outlet([Gang(fitting: Strap(width: 2, height: 3))]),
    );
    expect(m.blankInserts, 0);
  });
}
