// T6.20's pages and its place in the set (M6-E1 `#332`, DR-220).
//
// What the export test cannot sweep: every page size from one run to well
// past a page, checked for the two things a schedule's paginator gets
// wrong, a band stranded at a page foot and a page that opens on rows it
// does not name. And the numbering, whose overflow is shared with T6.30's.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

RackDocument _starter(String name) =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/$name.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

DBox get _area => SheetLayout.resolve(
  geometry: const SheetGeometry(SheetSize.ansiALandscape),
  revisionRowCount: 0,
).drawingArea;

/// Whole House's twelve real runs, dealt into [rooms] rooms of [perRoom]
/// rows each, so the sweep pages real cells rather than invented ones.
List<UnusedHomeRunRoom> _rooms(int rooms, int perRoom) {
  final doc = _starter('whole_house');
  final real = [
    for (final room in unusedHomeRunsOf(buildSchedule(doc), doc)) ...room.runs,
  ];
  return [
    for (var r = 0; r < rooms; r++)
      UnusedHomeRunRoom(
        roomId: Uuid('room-$r'),
        title: 'Room $r',
        runs: [for (var i = 0; i < perRoom; i++) real[(r + i) % real.length]],
      ),
  ];
}

List<UnusedRunsPage> _paginate(List<UnusedHomeRunRoom> rooms) =>
    paginateUnusedRuns(
      rooms: rooms,
      drawingArea: _area,
      measurer: FakeMeasurer(),
      units: UnitSystem.imperial,
    );

void main() {
  group('PAGINATION', () {
    test('NOTHING UNUSED IS NO PAGE: the sheet is AUTO, never a page '
        'saying none', () {
      expect(_paginate(const []), isEmpty);
    });

    test('one page: the heading, the OPEN key, a band per room, its rows', () {
      final pages = _paginate(_rooms(2, 3));
      expect(pages, hasLength(1));
      final items = pages.single.items;
      final heading = items.first as UnusedRunsHeading;
      expect(heading.text, '$kUnusedRunsHeading (6)');
      expect(heading.notes, [kOpenEndKey]);
      expect(
        [
          for (final i in items)
            if (i is UnusedRunsBand) i.text,
        ],
        ['ROOM 0 · 3 runs', 'ROOM 1 · 3 runs'],
      );
      expect(pages.single.designators, hasLength(6));
    });

    test('the lifecycle key prints only when a suffix does (DR-206)', () {
      final doc = _starter('whole_house');
      expect(
        _paginate(unusedHomeRunsOf(buildSchedule(doc), doc)).first.items.first,
        isA<UnusedRunsHeading>().having((h) => h.notes, 'notes', [
          kOpenEndKey,
        ]),
        reason: 'precondition: every Whole House run is new',
      );
      doc.links.values
              .singleWhere((l) => l.designator == 'W004')
              .lifecycleStatus =
          LifecycleStatus.future;
      final pages = _paginate(unusedHomeRunsOf(buildSchedule(doc), doc));
      final heading = pages.first.items.first as UnusedRunsHeading;
      expect(heading.notes, [kOpenEndKey, kLifecycleSuffixKey]);
      final w004 = pages
          .expand((p) => p.items)
          .whereType<UnusedRunsRow>()
          .singleWhere((r) => r.designator == 'W004');
      expect(w004.cells.first, ['W004 FUT']);
    });

    // THE PROPERTY, swept rather than sampled: `#337` found a band
    // stranded at a page foot on T6.30 that one sample size missed.
    for (final (rooms, perRoom) in [
      (1, 1),
      (1, 40),
      (1, 90),
      (3, 17),
      (6, 12),
      (12, 9),
      (30, 3),
    ]) {
      test('$rooms rooms of $perRoom: every run once, in order; no page ends '
          'on a band; a page that opens inside a room names it (cont.)', () {
        final input = _rooms(rooms, perRoom);
        final pages = _paginate(input);
        expect(
          [for (final p in pages) ...p.designators],
          [
            for (final room in input)
              for (final run in room.runs) run.entry.designator,
          ],
        );
        final body = unusedRunsBodyArea(_area);
        for (final (n, page) in pages.indexed) {
          final items = page.items;
          expect(
            items.fold<double>(0, (y, i) => y + i.height),
            lessThanOrEqualTo(body.height),
            reason: 'page ${n + 1} fits its body',
          );
          expect(
            items.last,
            isA<UnusedRunsRow>(),
            reason: 'page ${n + 1} ends on a row, never a band',
          );
          final heading = items.first as UnusedRunsHeading;
          expect(heading.continued, n > 0);
          // The first thing after the heading is a band: a continued one
          // when the page opens inside a room.
          expect(items[1], isA<UnusedRunsBand>(), reason: 'page ${n + 1}');
          final prev = n == 0 ? null : pages[n - 1].items;
          if (prev != null) {
            final lastBand = prev.whereType<UnusedRunsBand>().last;
            final opensInside = !(items[1] as UnusedRunsBand).continued;
            if (!opensInside) {
              expect((items[1] as UnusedRunsBand).title, lastBand.title);
            }
          }
        }
      });
    }

    test('THE CONTROL: the sweep reaches more than one page', () {
      expect(_paginate(_rooms(1, 90)).length, greaterThan(2));
    });
  });

  group('THE SET (§11.219.5)', () {
    List<SheetDef> sheets({int unused = 0, int equipment = 1}) =>
        SheetSet.forRacks(
          [testRack()],
          unusedHomeRunSheets: unused,
          equipmentListSheets: equipment,
        ).sheets;

    test('NONE UNUSED, NO T6.20: the set is the one it was before', () {
      expect(
        sheets().map((s) => s.role),
        isNot(contains(SheetRole.unusedHomeRuns)),
      );
    });

    test('T6.20 sits after the elevations and before T6.30', () {
      final ids = sheets(unused: 2).map((s) => s.ncsId).toList();
      expect(ids.sublist(ids.length - 5), [
        'T2.01',
        'T2.02',
        'T6.20',
        'T6.21',
        'T6.30',
      ]);
    });

    test('AN ELEVENTH PAGE takes T6.60, and the equipment list overflows '
        'after it: no id on two sheets', () {
      final set = SheetSet.forRacks(
        [testRack()],
        unusedHomeRunSheets: 12,
        equipmentListSheets: 11,
      );
      final unused = [
        for (final s in set.sheets)
          if (s.role == SheetRole.unusedHomeRuns) s.ncsId,
      ];
      final equipment = [
        for (final s in set.sheets)
          if (s.role == SheetRole.equipmentList) s.ncsId,
      ];
      expect(unused, [
        for (var n = 20; n < 30; n++) 'T6.$n',
        'T6.60',
        'T6.61',
      ]);
      expect(equipment, [for (var n = 30; n < 40; n++) 'T6.$n', 'T6.62']);
      final ids = set.sheets.map((s) => s.ncsId).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(set.notices.join('\n'), contains('Unused home runs need 12'));
      expect(set.notices.join('\n'), contains('numbered from T6.62'));
    });

    test('T6.20 fitting its ten leaves the equipment overflow at T6.60', () {
      expect(
        sheets(unused: 10, equipment: 11).last.ncsId,
        'T6.60',
      );
    });
  });
}
