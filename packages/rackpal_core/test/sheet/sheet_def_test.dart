// draw/sheet/sheet_def.dart — sheet identity and the SHEET i OF n dry run.
//
// The named risk this exists to close: "three-sheet PDF" in the M1 exit
// criterion is the ONE-RACK case. With N racks the set is 2N + 1 sheets, so
// a running counter incremented during rendering is right for one rack and
// wrong for two — which is exactly the bug that ships, because the exit
// criterion only exercises one rack.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

void main() {
  group('NCS id validation (section 2.1)', () {
    test('accepts the ids this set actually uses', () {
      for (final id in <String>['T2.01', 'T2.02', 'T6.30', 'T0.00', 'TA1.01']) {
        expect(isValidNcsId(id), isTrue, reason: id);
      }
    });

    test('rejects malformed ids', () {
      for (final id in <String>['T2.1', 'T2.001', '2.01', 't2.01', '', 'T21']) {
        expect(isValidNcsId(id), isFalse, reason: '[$id]');
      }
    });
  });

  group('SheetSet.forRacks', () {
    test('one rack resolves to exactly the three sheets the doc names', () {
      final set = SheetSet.forRacks(<Rack>[testRack()]);

      expect(set.sheets.map((s) => s.ncsId), <String>[
        'T2.01',
        'T2.02',
        'T6.30',
      ]);
      expect(set.sheets.map((s) => s.role), <SheetRole>[
        SheetRole.rackElevationFront,
        SheetRole.rackElevationRear,
        SheetRole.equipmentList,
      ]);
      expect(set.total, 3);
      expect(set.notices, isEmpty);
    });

    test('every sheet carries the SAME total, known before rendering', () {
      final set = SheetSet.forRacks(<Rack>[testRack()]);
      expect(set.sheets.map((s) => s.total), everyElement(3));
      expect(set.sheets.map((s) => s.index), <int>[1, 2, 3]);
    });

    test('TWO racks give 2N+1 = 5 sheets with no id collision', () {
      // The whole reason the dry run exists. A counter that was right for
      // one rack would print "SHEET 3 OF 3" on sheet 5 here.
      final set = SheetSet.forRacks(<Rack>[
        testRack(id: 'r1'),
        testRack(id: 'r2', designator: 'RK-2', order: 'b0'),
      ]);

      expect(set.total, 5);
      expect(set.sheets.map((s) => s.ncsId), <String>[
        'T2.01',
        'T2.02',
        'T2.03',
        'T2.04',
        'T6.30',
      ]);
      expect(set.sheets.map((s) => s.ncsId).toSet(), hasLength(5));
      expect(set.sheets.map((s) => s.total), everyElement(5));
      expect(set.sheets.map((s) => s.index), <int>[1, 2, 3, 4, 5]);
      expect(set.notices, isEmpty);
    });

    test('elevation sheets carry their rack; the equipment list does not', () {
      final set = SheetSet.forRacks(<Rack>[testRack(id: 'r1')]);

      expect(set.sheets[0].rackId, const Uuid('r1'));
      expect(set.sheets[0].rackDesignator, 'RK-1');
      expect(set.sheets[1].rackId, const Uuid('r1'));
      expect(set.sheets[2].rackId, isNull);
    });

    test('racks are ordered by Rack.order, not by iteration order', () {
      final set = SheetSet.forRacks(<Rack>[
        testRack(id: 'z', designator: 'RK-Z', order: 'z0'),
        testRack(id: 'a', designator: 'RK-A'),
      ]);

      expect(set.sheets[0].rackDesignator, 'RK-A');
      expect(set.sheets[2].rackDesignator, 'RK-Z');
    });

    test('racks sharing an order fall back to id, deterministically', () {
      final set = SheetSet.forRacks(<Rack>[
        testRack(id: 'b', designator: 'RK-B'),
        testRack(id: 'a', designator: 'RK-A'),
      ]);
      expect(set.sheets[0].rackDesignator, 'RK-A');
    });

    test('a rackless project still resolves the equipment list alone', () {
      // The export UX refuses a rackless document out loud rather than
      // emitting this — but the answer the resolver gives must be honest.
      final set = SheetSet.forRacks(const <Rack>[]);
      expect(set.sheets.map((s) => s.ncsId), <String>['T6.30']);
      expect(set.total, 1);
    });

    test('a set large enough to overflow the NCS sequence reports a notice '
        'rather than failing', () {
      // 50 racks pushes the front-elevation sequence past two digits. CR-023
      // and G3: a naming convention never withholds the bytes of a user.
      final set = SheetSet.forRacks(<Rack>[
        for (var i = 0; i < 50; i++)
          testRack(
            id: 'r$i',
            designator: 'RK-$i',
            order: 'a${i.toString().padLeft(3, '0')}',
          ),
      ]);

      expect(set.total, 101);
      expect(set.notices, isNotEmpty);
      expect(set.notices.first, contains('does not match the NCS pattern'));
      // Still emitted — the notice does not remove the sheet.
      expect(set.sheets, hasLength(101));
    });
  });

  group('the schedule never numbers itself into a RESERVED id', () {
    // ==================================================================
    // docs/08 §2.2: "T6.40 Power Schedule and T6.50 Network/IP Schedule …
    // defer to v1.1". They are ids belonging to OTHER SHEET TYPES.
    // ==================================================================
    // `'T6.${30 + page}'` ran off the end of its own decade at the
    // eleventh schedule page and emitted `T6.40` — and `isValidNcsId`
    // waved it through, so the confusable case was silent while the
    // harmless one (`T6.100`, at page 71) was the one that raised a
    // notice. ~370 devices is eleven pages: a large job, not an absurd
    // one.

    test('the first ten pages are the block §2.2 gives it', () {
      expect(
        <String>[for (var p = 0; p < 10; p++) equipmentListNcsId(p)],
        <String>[
          'T6.30',
          'T6.31',
          'T6.32',
          'T6.33',
          'T6.34',
          'T6.35',
          'T6.36',
          'T6.37',
          'T6.38',
          'T6.39',
        ],
      );
    });

    test('the eleventh page is NOT T6.40', () {
      expect(equipmentListNcsId(10), isNot('T6.40'));
      expect(isReservedNcsId(equipmentListNcsId(10)), isFalse);
    });

    test('no page of a very long schedule lands on a reserved id', () {
      // Past both reserved decades — their own continuation pages would
      // want T6.41… and T6.51…, so whole decades are left alone rather
      // than single numbers.
      for (var page = 0; page < 40; page++) {
        final id = equipmentListNcsId(page);
        expect(
          isReservedNcsId(id),
          isFalse,
          reason: 'page $page took $id',
        );
        expect(isValidNcsId(id), isTrue, reason: 'page $page took $id');
      }
    });

    test('the jump is REPORTED — a gap in the numbering is not silent', () {
      final set = SheetSet.forRacks(
        <Rack>[testRack()],
        equipmentListSheets: 11,
      );

      expect(set.sheets.map((s) => s.ncsId), isNot(contains('T6.40')));
      expect(
        set.notices.any((n) => n.contains('T6.60')),
        isTrue,
        reason:
            'a reader looking for page 11 between T6.39 and T6.60 is owed '
            'the reason for the gap',
      );
    });

    test('a schedule that FITS its block reports nothing', () {
      final set = SheetSet.forRacks(
        <Rack>[testRack()],
        equipmentListSheets: 10,
      );

      expect(set.sheets.last.ncsId, 'T6.39');
      expect(set.notices, isEmpty);
    });

    test('a reserved id anywhere in a set raises a notice', () {
      // The guard is on the RESOLVED set, not only on the schedule's own
      // numbering, so a future sheet role that lands on T6.40 is reported
      // the day it does rather than the day someone notices in print.
      expect(isReservedNcsId('T6.40'), isTrue);
      expect(isReservedNcsId('T6.50'), isTrue);
      expect(isReservedNcsId('T6.30'), isFalse);
      expect(kReservedNcsIds['T6.40'], contains('Power Schedule'));
    });
  });

  group('SheetRole', () {
    // FOUR SINCE `PLAN-H/1`, AND THE CANARY IS THE POINT RATHER THAN THE
    // NUMBER. This read `hasLength(3)` and `names the three sheets` while
    // `SheetRole` had three values; docs/15 §8 adds `T1.01` and the count
    // moves with it. What it still refuses is a role appearing without
    // anybody deciding: eight of §2.2's twelve slots are M6's and are
    // absent from this enum rather than stubbed.
    test('names the four sheets in this set, and no others', () {
      expect(SheetRole.values, hasLength(4));
      expect(SheetRole.devicePlan.title, 'DEVICE LOCATION PLAN');
      expect(SheetRole.rackElevationFront.title, 'RACK ELEVATION — FRONT');
      expect(SheetRole.rackElevationRear.title, 'RACK ELEVATION — REAR');
      expect(SheetRole.equipmentList.title, 'EQUIPMENT LIST AND MATERIALS');
    });

    test('assigns the paper of section 6.1: elevations ANSI B portrait, the '
        'list ANSI A landscape, the plan ANSI B landscape', () {
      expect(SheetRole.rackElevationFront.size, SheetSize.ansiBPortrait);
      expect(SheetRole.rackElevationRear.size, SheetSize.ansiBPortrait);
      expect(SheetRole.equipmentList.size, SheetSize.ansiALandscape);
      // A BUILDING IS WIDE, and the exit criterion prints at ANSI B
      // (DR-037 §11.36.1), so the sheet the drill judges and the sheet
      // this emits are the same paper.
      expect(SheetRole.devicePlan.size, SheetSize.ansiBLandscape);
      expect(SheetSize.ansiBLandscape.sizeCode, 'B');
    });

    test('only the elevations are per-rack', () {
      // `perRack` drives the set resolution, and a plan that claimed it
      // would emit one sheet per rack per underlay.
      expect(SheetRole.devicePlan.perRack, isFalse);
      expect(SheetRole.equipmentList.perRack, isFalse);
      expect(SheetRole.rackElevationFront.perRack, isTrue);
      expect(SheetRole.rackElevationRear.perRack, isTrue);
    });

    test('never says BOM', () {
      // AC-055. The word is banned in the corpus; asserting it here means
      // a future rename cannot reintroduce it quietly.
      for (final role in SheetRole.values) {
        expect(role.title.toUpperCase(), isNot(contains('BOM')));
      }
    });
  });
}
