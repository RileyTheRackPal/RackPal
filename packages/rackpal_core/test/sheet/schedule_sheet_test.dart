// T6.10 and T6.15's pages and their numbers (M6-K `#978`, `#979`, `#980`,
// DR-222).
//
// On real data: Whole House's 27 field cables on the Pull Sheet and its
// 15 landed runs on the Termination Schedule, paginated over a sweep of
// page heights so every band lands at a page foot somewhere. And the
// shared overflow pool, which four schedules now draw from in set order.
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

ScheduleView _view(RackDocument doc, SchedulePreset preset) =>
    buildScheduleView(buildSchedule(doc), preset: preset);

DBox _area(SheetSize size, {double? height}) {
  final full = SheetLayout.resolve(
    geometry: SheetGeometry(size),
    revisionRowCount: 0,
  ).drawingArea;
  return height == null
      ? full
      : DBox.fromLtwh(full.left, full.top, full.width, height);
}

List<ScheduleSheetPage> _paginate(
  RackDocument doc,
  SchedulePreset preset, {
  double? height,
}) {
  final size = preset == SchedulePreset.pullSheet
      ? SheetSize.ansiAPortrait
      : SheetSize.ansiALandscape;
  return paginateSchedule(
    view: _view(doc, preset),
    title: 'T',
    registries: doc.registries,
    drawingArea: _area(size, height: height),
    measurer: FakeMeasurer(),
    units: UnitSystem.imperial,
  );
}

void main() {
  group('ON, AND AN EMPTY SCHEDULE SAYS SO', () {
    test('Apartment, no cables: one page, the heading, the sentence', () {
      for (final preset in [
        SchedulePreset.pullSheet,
        SchedulePreset.terminationSchedule,
      ]) {
        final pages = _paginate(_starter('apartment'), preset);
        expect(pages, hasLength(1), reason: '$preset');
        expect(
          pages.single.items.whereType<ScheduleSheetNote>().single.text,
          kNoCablesText,
        );
      }
    });
  });

  group('WHOLE HOUSE', () {
    test('THE PULL SHEET: every field cable once, in the view’s order, '
        'across its pages', () {
      final doc = _starter('whole_house');
      final pages = _paginate(doc, SchedulePreset.pullSheet);
      expect(pages.length, greaterThan(1), reason: 'precondition: overflows');
      expect(
        [for (final p in pages) ...p.designators],
        [
          for (final r in _view(doc, SchedulePreset.pullSheet).rows)
            r.designator,
        ],
      );
      expect(pages.expand((p) => p.designators), hasLength(27));
    });

    test('page 2 opens with the heading, the section and the room, each '
        '(cont.)', () {
      final page = _paginate(
        _starter('whole_house'),
        SchedulePreset.pullSheet,
      )[1].items;
      expect((page[0] as ScheduleSheetHeading).continued, isTrue);
      expect((page[1] as ScheduleSectionBand).continued, isTrue);
      expect((page[2] as ScheduleGroupBand).continued, isTrue);
      expect(page[3], isA<ScheduleSheetRow>());
    });

    test(
      'THE TERMINATION SCHEDULE names its twelve exclusions as runs '
      'landing in no rack, and says nothing about jumpers it has none of',
      () {
        final heading =
            _paginate(
                  _starter('whole_house'),
                  SchedulePreset.terminationSchedule,
                ).first.items.first
                as ScheduleSheetHeading;
        final note = heading.notes.single;
        expect(note, contains('12 runs landing in no rack'));
        expect(note, isNot(contains('Jumpers')));
      },
    );

    // SWEPT, NOT SAMPLED (M6-E2's lesson): every page height from 150 to
    // 600 pt, so every band lands at a page foot somewhere.
    for (final preset in [
      SchedulePreset.pullSheet,
      SchedulePreset.terminationSchedule,
    ]) {
      test('$preset, page heights 150 to 600: no page ends on a band, and '
          'every page that opens on a row names its group first', () {
        final doc = _starter('whole_house');
        for (var h = 150.0; h <= 600; h += 3) {
          final pages = _paginate(doc, preset, height: h);
          for (final (n, page) in pages.indexed) {
            final last = page.items.last;
            expect(
              last is ScheduleSectionBand || last is ScheduleGroupBand,
              isFalse,
              reason: '$h pt: page ${n + 1} ends on a band',
            );
            final firstRow = page.items.indexWhere(
              (i) => i is ScheduleSheetRow,
            );
            if (firstRow > 0) {
              expect(
                page.items.sublist(0, firstRow).whereType<ScheduleGroupBand>(),
                isNotEmpty,
                reason: '$h pt: page ${n + 1} opens on a row with no room',
              );
            }
          }
        }
      });
    }
  });

  group('THE TYPE CHIP AND ITS TAG (§3.5, #980)', () {
    test('the tag is the legend’s, beside the chip when it fits and '
        'beneath it when it does not', () {
      final doc = _starter('whole_house');
      final rows = _paginate(
        doc,
        SchedulePreset.pullSheet,
      ).expand((p) => p.items).whereType<ScheduleSheetRow>();
      final typeAt = kPullSheetColumns.indexWhere(
        (c) => c.id == ScheduleColumnId.type,
      );
      for (final row in rows) {
        final tag = scheduleTypeTag(row.entry, doc.registries);
        final cell = row.cells[typeAt];
        expect(cell.last, tag, reason: row.designator);
        expect(cell.length == 1 || cell.first.isEmpty, isTrue);
      }
      // THE PLACEMENT, as the render showed it: a mutation that always put
      // the tag beside the chip passed every line above. `NET·NET` is too
      // wide for what the chip leaves and goes beneath; `RF·RF` fits.
      Iterable<List<String>> cellsTagged(String tag) => [
        for (final r in rows)
          if (scheduleTypeTag(r.entry, doc.registries) == tag) r.cells[typeAt],
      ];
      expect(cellsTagged('NET·NET'), isNotEmpty);
      for (final cell in cellsTagged('NET·NET')) {
        expect(cell, ['', 'NET·NET']);
      }
      expect(cellsTagged('RF·RF'), isNotEmpty);
      for (final cell in cellsTagged('RF·RF')) {
        expect(cell, ['RF·RF']);
      }
    });

    test('the chip is a tinted box and a line at the family’s own dash '
        'and weight', () {
      final doc = _starter('whole_house');
      final style = resolveSignalStyle(
        family: const SignalFamilyId('audio.speaker_lowz'),
        registries: doc.registries,
      );
      final ops = typeChipOps(style, 0, 10);
      final box = ops.whereType<OpRect>().single;
      expect(box.r.width, kTypeChipWidth);
      expect(box.r.height, kTypeChipHeight);
      expect(box.fill!.argb, tintOverWhite(style.argb, kTypeChipTint));
      final line = ops.whereType<OpLine>().single;
      expect(line.s.argb, style.argb);
      expect(line.s.dash, style.dash);
      expect(line.s.widthPt, style.widthPt);
    });
  });

  group('THE NUMBERS (DR-222 §11.221.1)', () {
    test('the Schedule screen’s picker names the first page the set '
        'prints, for both presets', () {
      expect(
        SchedulePreset.pullSheet.sheetId,
        scheduleNcsId(0, blockStart: kPullSheetBlockStart),
      );
      expect(
        SchedulePreset.terminationSchedule.sheetId,
        scheduleNcsId(0, blockStart: kTerminationBlockStart),
      );
    });

    test('blocks of five, T6.10 to T6.14 and T6.15 to T6.19, before T6.20', () {
      final ids = SheetSet.forRacks(
        [testRack()],
        pullSheets: 2,
        terminationSheets: 1,
        unusedHomeRunSheets: 1,
      ).sheets.map((s) => s.ncsId).toList();
      expect(ids.sublist(ids.length - 5), [
        'T6.10',
        'T6.11',
        'T6.15',
        'T6.20',
        'T6.30',
      ]);
    });

    test('FOUR SCHEDULES OVERFLOWING draw one pool in set order, and no id '
        'is on two sheets', () {
      final set = SheetSet.forRacks(
        [testRack()],
        pullSheets: 7,
        terminationSheets: 6,
        unusedHomeRunSheets: 12,
        equipmentListSheets: 11,
      );
      List<String> idsOf(SheetRole role) => [
        for (final s in set.sheets)
          if (s.role == role) s.ncsId,
      ];
      expect(idsOf(SheetRole.pullSheet), [
        'T6.10',
        'T6.11',
        'T6.12',
        'T6.13',
        'T6.14',
        'T6.60',
        'T6.61',
      ]);
      expect(idsOf(SheetRole.terminationSchedule).last, 'T6.62');
      expect(idsOf(SheetRole.unusedHomeRuns).sublist(10), ['T6.63', 'T6.64']);
      expect(idsOf(SheetRole.equipmentList).last, 'T6.65');
      final ids = set.sheets.map((s) => s.ncsId).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(set.notices.join('\n'), contains('The Pull Sheet needs 7 pages'));
    });
  });
}
