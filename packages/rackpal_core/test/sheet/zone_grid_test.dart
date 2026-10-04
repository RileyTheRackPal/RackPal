// §5.1's zone band and grid (M6-G1 `#342`, DR-215).
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

void main() {
  group('which sheets are zoned (§11.214.1)', () {
    test('THE DRAWINGS ARE ZONED; the front matter and the tables are not', () {
      expect(
        {for (final r in SheetRole.values) r: r.zoned},
        {
          SheetRole.cover: false,
          SheetRole.symbolLegend: false,
          SheetRole.exceptions: false,
          SheetRole.devicePlan: true,
          SheetRole.rackElevationFront: true,
          SheetRole.rackElevationRear: true,
          // A DRAWING, named in §11.214.1's own list, and the reason the
          // schedule's `REF` column exists (CR-073).
          SheetRole.interconnect: true,
          // THE SCHEDULES ARE TABLES (DR-222). `REF` would point INTO the
          // drawings' zones; the schedules carry none of their own.
          SheetRole.pullSheet: false,
          SheetRole.terminationSchedule: false,
          // T6.20 IS A TABLE (DR-220): the inset, not the band.
          SheetRole.unusedHomeRuns: false,
          SheetRole.equipmentList: false,
          // T6.50 IS A TABLE (DR-228).
          SheetRole.networkSchedule: false,
          // T5.01 IS TABLES (DR-221 §11.220.1).
          SheetRole.pinoutDetails: false,
        },
      );
    });

    test("a zoned sheet gives up the band; a table keeps §3.2's widths", () {
      const plain = SheetGeometry(SheetSize.ansiALandscape);
      const zoned = SheetGeometry(SheetSize.ansiBPortrait, zoned: true);
      // §3.2's 690 pt usable width on ANSI A landscape is untouched.
      expect(plain.frameBox.width, 690);
      expect(
        zoned.marginBox.width - zoned.frameBox.width,
        closeTo(2 * 0.22 * 72, 1e-9),
      );
    });
  });

  group('the grid (§5.1)', () {
    test('ONE ZONE PER 4.25 IN, rounded, at least two: B landscape 4 x 2, '
        'D 8 x 5, B portrait 2 x 4', () {
      expect(
        zoneGrid(const SheetGeometry(SheetSize.ansiBLandscape, zoned: true)),
        (4, 2),
      );
      expect(
        zoneGrid(const SheetGeometry(SheetSize.ansiBPortrait, zoned: true)),
        (2, 4),
      );
      // ANSI D is not a SheetSize yet; §5.1's 8 x 5 is checked on its
      // frame: 34 x 22 in less the standard margins and the band.
      expect(zoneCount(34 * 72 - 90 - 2 * 0.22 * 72), 8);
      expect(zoneCount(22 * 72 - 72 - 2 * 0.22 * 72), 5);
      expect(zoneCount(100), 2, reason: 'never fewer than two');
    });

    test('ZONES RUN FROM THE LOWER RIGHT (§11.214.2): A1 at the lower-right '
        'corner, the highest letter and number at the upper left', () {
      const g = SheetGeometry(SheetSize.ansiBPortrait, zoned: true);
      final f = g.frameBox;
      expect(zoneAt(g, DPt(f.right - 1, f.bottom - 1)), 'A1');
      expect(zoneAt(g, DPt(f.left + 1, f.top + 1)), 'D2');
      expect(zoneAt(g, DPt(f.left + 1, f.bottom - 1)), 'A2');
      expect(zoneAt(g, DPt(f.right - 1, f.top + 1)), 'D1');
      expect(zoneAt(g, DPt(f.left - 5, f.top + 1)), isNull, reason: 'outside');
      expect(
        zoneAt(
          const SheetGeometry(SheetSize.ansiBPortrait),
          DPt(f.left + f.width / 2, f.top + f.height / 2),
        ),
        isNull,
        reason: 'an unzoned sheet has no zones',
      );
    });

    test('letters skip I and O, as drawing sheets do', () {
      expect([for (var i = 0; i < 10; i++) zoneLetter(i)].join(), 'ABCDEFGHJK');
      expect(zoneLetter(13), 'P');
    });
  });

  group('on the sheet', () {
    List<String> frameTexts(SheetGeometry g) =>
        textsOf(buildSheetFrameLayer(g).ops);

    test('A ZONED FRAME LABELS EVERY ZONE on both of its sides, and draws a '
        'tick at every boundary', () {
      const g = SheetGeometry(SheetSize.ansiBPortrait, zoned: true);
      final texts = frameTexts(g);
      expect(texts.where((t) => t == '1'), hasLength(2));
      expect(texts.where((t) => t == '2'), hasLength(2));
      for (final letter in ['A', 'B', 'C', 'D']) {
        expect(texts.where((t) => t == letter), hasLength(2), reason: letter);
      }
      final ticks = buildSheetFrameLayer(g).ops.whereType<OpLine>();
      // (2 - 1) column boundaries x 2 bands + (4 - 1) row boundaries x 2.
      expect(ticks, hasLength(2 * 1 + 2 * 3));
    });

    test('an unzoned frame draws no labels at all', () {
      expect(
        frameTexts(const SheetGeometry(SheetSize.ansiALandscape)),
        isEmpty,
      );
    });

    test('THE ELEVATION SHEET IS LAID OUT ON THE ZONED FRAME', () {
      final sheet = SheetSet.forRacks([testRack()]).sheets.firstWhere(
        (s) => s.role == SheetRole.rackElevationFront,
      );
      expect(sheetLayoutFor(sheet, const []).geometry.zoned, isTrue);
    });
  });
}
