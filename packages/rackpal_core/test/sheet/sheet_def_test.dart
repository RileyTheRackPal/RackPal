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
    test('one rack resolves to exactly the six sheets the doc names, the '
        'cover, the legend and the exceptions first (M6-A, M6-B, M6-C)', () {
      final set = SheetSet.forRacks(<Rack>[testRack()]);

      expect(set.sheets.map((s) => s.ncsId), <String>[
        'T0.00',
        'T0.01',
        'T0.02',
        'T2.01',
        'T2.02',
        'T6.30',
      ]);
      expect(set.sheets.map((s) => s.role), <SheetRole>[
        SheetRole.cover,
        SheetRole.symbolLegend,
        SheetRole.exceptions,
        SheetRole.rackElevationFront,
        SheetRole.rackElevationRear,
        SheetRole.equipmentList,
      ]);
      expect(set.total, 6);
      expect(set.notices, isEmpty);
    });

    test('every sheet carries the SAME total, known before rendering', () {
      final set = SheetSet.forRacks(<Rack>[testRack()]);
      expect(set.sheets.map((s) => s.total), everyElement(6));
      expect(set.sheets.map((s) => s.index), <int>[1, 2, 3, 4, 5, 6]);
    });

    test('TWO racks give 2N+4 = 8 sheets with no id collision', () {
      // The whole reason the dry run exists. A counter that was right for
      // one rack would print "SHEET 6 OF 6" on sheet 8 here. 2N+4 since
      // M6-C: the cover, the legend, the exceptions and the equipment
      // list, and two per rack.
      final set = SheetSet.forRacks(<Rack>[
        testRack(id: 'r1'),
        testRack(id: 'r2', designator: 'RK-2', order: 'b0'),
      ]);

      expect(set.total, 8);
      expect(set.sheets.map((s) => s.ncsId), <String>[
        'T0.00',
        'T0.01',
        'T0.02',
        'T2.01',
        'T2.02',
        'T2.03',
        'T2.04',
        'T6.30',
      ]);
      expect(set.sheets.map((s) => s.ncsId).toSet(), hasLength(8));
      expect(set.sheets.map((s) => s.total), everyElement(8));
      expect(set.sheets.map((s) => s.index), <int>[1, 2, 3, 4, 5, 6, 7, 8]);
      expect(set.notices, isEmpty);
    });

    test('elevation sheets carry their rack; the equipment list does not', () {
      final set = SheetSet.forRacks(<Rack>[testRack(id: 'r1')]);

      // [0] to [2] are T0.00, T0.01 and T0.02, which open every set and
      // name no rack (M6-A, M6-B, M6-C).
      expect(set.sheets[0].rackId, isNull);
      expect(set.sheets[1].rackId, isNull);
      expect(set.sheets[2].rackId, isNull);
      expect(set.sheets[3].rackId, const Uuid('r1'));
      expect(set.sheets[3].rackDesignator, 'RK-1');
      expect(set.sheets[4].rackId, const Uuid('r1'));
      expect(set.sheets[5].rackId, isNull);
    });

    test('racks are ordered by Rack.order, not by iteration order', () {
      final set = SheetSet.forRacks(<Rack>[
        testRack(id: 'z', designator: 'RK-Z', order: 'z0'),
        testRack(id: 'a', designator: 'RK-A'),
      ]);

      expect(set.sheets[3].rackDesignator, 'RK-A');
      expect(set.sheets[5].rackDesignator, 'RK-Z');
    });

    test('racks sharing an order fall back to id, deterministically', () {
      final set = SheetSet.forRacks(<Rack>[
        testRack(id: 'b', designator: 'RK-B'),
        testRack(id: 'a', designator: 'RK-A'),
      ]);
      expect(set.sheets[3].rackDesignator, 'RK-A');
    });

    test('a rackless project still resolves the cover, the legend, the '
        'exceptions and the equipment list', () {
      // The export UX refuses a rackless document out loud rather than
      // emitting this — but the answer the resolver gives must be honest.
      final set = SheetSet.forRacks(const <Rack>[]);
      expect(set.sheets.map((s) => s.ncsId), <String>[
        'T0.00',
        'T0.01',
        'T0.02',
        'T6.30',
      ]);
      expect(set.total, 4);
    });

    test('a set large enough to overflow the NCS sequence reports a notice '
        'rather than failing', () {
      // 50 racks pushes the front-elevation sequence past two digits. CR-023
      // and G3: a naming convention never withholds the bytes of a user.
      final racks = <Rack>[
        for (var i = 0; i < 50; i++)
          testRack(
            id: 'r$i',
            designator: 'RK-$i',
            order: 'a${i.toString().padLeft(3, '0')}',
          ),
      ];
      final set = SheetSet.forRacks(racks, numbering: SheetNumbering.ncs);

      expect(set.total, 104);
      expect(set.notices, isNotEmpty);
      expect(set.notices.first, contains('does not match the NCS pattern'));
      // Still emitted — the notice does not remove the sheet.
      expect(set.sheets, hasLength(104));

      // UNDER `simple` THE PATTERN IS NOT CHECKED (CR-066): the same set,
      // the same ids, and no notice about a convention nobody chose.
      final simple = SheetSet.forRacks(racks);
      expect(simple.notices.where((n) => n.contains('NCS pattern')), isEmpty);
      expect(
        simple.sheets.map((s) => s.ncsId),
        set.sheets.map((s) => s.ncsId),
      );
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
    // absent from this enum rather than stubbed. EIGHT SINCE M6-E1 (`#332`,
    // DR-220): T6.20 arrived as a role, decided by a ruling. NINE SINCE
    // M6-E2 (`#976`, DR-221): T5.01. ELEVEN SINCE M6-K (`#977`, DR-222):
    // the Pull Sheet and the Termination Schedule. TWELVE SINCE M6-D
    // (`#328`, DR-225): T6.01…, the interconnect sheets, one role for all
    // of them, since the domain is a field on the sheet and not a role.
    test('names the twelve sheets in this set, and no others', () {
      expect(SheetRole.values, hasLength(12));
      expect(SheetRole.interconnect.title, 'INTERCONNECT');
      expect(SheetRole.interconnect.size, SheetSize.ansiBLandscape);
      expect(SheetRole.interconnect.zoned, isTrue);
      expect(SheetRole.pullSheet.title, 'PULL SHEET');
      expect(SheetRole.terminationSchedule.title, 'TERMINATION SCHEDULE');
      expect(SheetRole.pinoutDetails.title, 'PLATE, PANEL AND PINOUT DETAILS');
      expect(SheetRole.pinoutDetails.size, SheetSize.ansiALandscape);
      expect(SheetRole.unusedHomeRuns.title, 'UNUSED HOME RUNS');
      expect(SheetRole.unusedHomeRuns.size, SheetSize.ansiALandscape);
      expect(SheetRole.exceptions.title, 'EXCEPTIONS AND ACKNOWLEDGEMENTS');
      expect(SheetRole.cover.title, 'COVER AND DRAWING INDEX');
      expect(SheetRole.symbolLegend.title, 'SYMBOL LEGEND');
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
      // The legend is ANSI B landscape too, as §6.1 gives the cover,
      // legend and exceptions.
      expect(SheetRole.symbolLegend.size, SheetSize.ansiBLandscape);
      expect(SheetSize.ansiBLandscape.sizeCode, 'B');
    });

    test('only the elevations are per-rack', () {
      // `perRack` drives the set resolution, and a plan that claimed it
      // would emit one sheet per rack per underlay.
      expect(SheetRole.devicePlan.perRack, isFalse);
      expect(SheetRole.equipmentList.perRack, isFalse);
      expect(SheetRole.symbolLegend.perRack, isFalse);
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

  group('the interconnect sheets, T6.01… (DR-225)', () {
    final seeds = buildSeedSignalDomains();
    List<SignalDomainDef> domains(int n) => [
      for (final id in kInterconnectDomainOrder) seeds[id]!,
    ].take(n).toList();

    test('sit after the elevations and before the Pull Sheet, numbered '
        'T6.01 on in the order the caller gives, each naming its domain', () {
      final set = SheetSet.forRacks(
        <Rack>[testRack()],
        interconnectDomains: domains(2),
        pullSheets: 1,
      );
      expect(set.sheets.map((s) => s.ncsId), <String>[
        'T0.00',
        'T0.01',
        'T0.02',
        'T2.01',
        'T2.02',
        'T6.01',
        'T6.02',
        'T6.10',
        'T6.30',
      ]);
      final sheets = set.sheets.where((s) => s.role == SheetRole.interconnect);
      expect(sheets.map((s) => s.domainName), <String>[
        'Digital Video',
        'Analog Video & RF',
      ]);
      expect(sheets.map((s) => s.legendNcsId), everyElement('T0.01'));
      expect(set.notices, isEmpty);
    });

    test('all eight seeded domains fit T6.01 to T6.08, so no id is borrowed '
        'from the Pull Sheet', () {
      final set = SheetSet.forRacks(
        <Rack>[testRack()],
        interconnectDomains: domains(8),
        pullSheets: 1,
      );
      expect(
        set.sheets
            .where((s) => s.role == SheetRole.interconnect)
            .map((s) => s.ncsId),
        <String>[
          'T6.01',
          'T6.02',
          'T6.03',
          'T6.04',
          'T6.05',
          'T6.06',
          'T6.07',
          'T6.08',
        ],
      );
      expect(set.notices, isEmpty);
    });

    test('a tenth domain takes the shared pool FIRST, being first in set '
        'order, and says why its number jumps', () {
      final extra = [
        for (var i = 0; i < 2; i++)
          SignalDomainDef(
            id: SignalDomainId('zz.extra$i'),
            displayName: 'Extra $i',
            tagPrefix: 'X$i',
            color: seeds[kInterconnectDomainOrder.first]!.color,
            colorDark: seeds[kInterconnectDomainOrder.first]!.colorDark,
            dashPattern: const <int>[],
            lineWeightPermille: 1000,
            glyph: '*',
            glyphAlt: '*',
          ),
      ];
      final set = SheetSet.forRacks(
        <Rack>[testRack()],
        interconnectDomains: [...domains(8), ...extra],
        pullSheets: 6,
      );
      final ids = set.sheets.map((s) => s.ncsId).toList();
      expect(ids, containsAllInOrder(<String>['T6.08', 'T6.09', 'T6.60']));
      // The Pull Sheet's own overflow moves past it rather than reusing it.
      expect(ids, contains('T6.61'));
      expect(ids.toSet(), hasLength(ids.length), reason: 'an id printed twice');
      expect(set.notices.join(), contains('T6.01–T6.09'));
    });
  });
}
