// T0.00's drawing index (M6-A3 `#314`, DR-212).
//
// THE EXPECTED ROWS ARE WRITTEN OUT BY HAND, not derived from the code
// under test: an index is a list a person reads, and the only useful
// assertion about it is the list itself.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

PlanUnderlay _plan() => PlanUnderlay(
  id: const Uuid('plan-1'),
  name: 'Main Floor',
  imageMember: 'underlays/plan-1.png',
  format: PlanImageFormat.png,
  pixelWidth: 2000,
  pixelHeight: 1500,
  contentHash: 'sha256:plan',
  order: const FracIndex('a0'),
  meta: testMeta(),
);

List<(String, String, String)> _rows(List<SheetDef> sheets) => [
  for (final r in coverIndexRows(sheets)) (r.positions, r.ids, r.title),
];

List<Rack> _racks(int n) => [
  for (var i = 0; i < n; i++)
    testRack(
      id: 'r$i',
      designator: 'RK-${i + 1}',
      order: 'a${i.toString().padLeft(3, '0')}',
    ),
];

void main() {
  group('the rows (§11.211.1, §11.211.2, §11.211.3)', () {
    test('EVERY RESOLVED SHEET, BOTH NUMBERS, in set order, and a '
        'multi-page schedule as one row', () {
      final set = SheetSet.forRacks(
        _racks(2),
        equipmentListSheets: 3,
        planUnderlays: [_plan()],
      );
      expect(_rows(set.sheets), <(String, String, String)>[
        ('1', 'T0.00', 'COVER AND DRAWING INDEX'),
        ('2', 'T0.01', 'SYMBOL LEGEND'),
        ('3', 'T0.02', 'EXCEPTIONS AND ACKNOWLEDGEMENTS'),
        ('4', 'T1.01', 'DEVICE LOCATION PLAN · Main Floor'),
        ('5', 'T2.01', 'RACK ELEVATION — FRONT · RK-1'),
        ('6', 'T2.02', 'RACK ELEVATION — REAR · RK-1'),
        ('7', 'T2.03', 'RACK ELEVATION — FRONT · RK-2'),
        ('8', 'T2.04', 'RACK ELEVATION — REAR · RK-2'),
        ('9–11', 'T6.30–T6.32', 'EQUIPMENT LIST AND MATERIALS (3 pages)'),
      ]);
    });

    test('AN AUTO SHEET THE SET DID NOT EMIT IS NOT INDEXED: no plan, no '
        'T1 row', () {
      // docs/08 §2.2's whole rule: the index is built from the RESOLVED
      // list, so it can never name a sheet that is not in the file.
      final ids = _rows(
        SheetSet.forRacks(_racks(1)).sheets,
      ).map((r) => r.$2).toList();
      expect(ids, <String>[
        'T0.00',
        'T0.01',
        'T0.02',
        'T2.01',
        'T2.02',
        'T6.30',
      ]);
    });

    test('a single schedule page is a plain row, not a range of one', () {
      final last = _rows(SheetSet.forRacks(_racks(1)).sheets).last;
      expect(last, ('6', 'T6.30', 'EQUIPMENT LIST AND MATERIALS'));
    });
  });

  group('the column, and overflow (§11.211.4)', () {
    // The reserved column's real size on a landscape B cover: the test
    // draws into the box the cover would hand it.
    DBox column() {
      final set = SheetSet.forRacks(_racks(1));
      return buildCoverSheet(
        sheet: set.sheets.first,
        info: minimalProjectInfo(),
        settings: ProjectSettings(),
        revisions: const <RevisionEntry>[],
        fileName: 'c.rppj',
        issuedAt: DateTime.utc(2026, 10),
        measurer: FakeMeasurer(),
        racks: _racks(1),
        devices: const [],
        templates: const {},
        landings: PortLandings.none,
        sheets: set.sheets,
      ).indexColumn;
    }

    CoverIndexResult draw(int racks) => drawCoverIndex(
      rows: coverIndexRows(SheetSet.forRacks(_racks(racks)).sheets),
      box: column(),
      measurer: FakeMeasurer(),
    );

    void expectInside(CoverIndexResult r, DBox box, FakeMeasurer m) {
      for (final op in textOps(r.ops)) {
        expect(op.at.x, greaterThanOrEqualTo(box.left), reason: op.text);
        expect(
          op.at.x + m.measureText(op.text, op.style).advanceWidth,
          lessThanOrEqualTo(box.right + 0.01),
          reason: op.text,
        );
        expect(op.at.y, inInclusiveRange(box.top, box.bottom), reason: op.text);
      }
    }

    test('A SMALL SET IS ONE COLUMN and lists everything', () {
      final r = draw(1);
      expect(r.columns, 1);
      expect(r.omitted, isEmpty);
    });

    test('A LONG SET FLOWS INTO SUB-COLUMNS before anything is omitted, '
        'and stays inside the column', () {
      final box = column();
      final perColumn = ((box.height - (kCoverIndexRow + 6)) / kCoverIndexRow)
          .floor();
      // Rows = cover, legend, list, plus two per rack: pick rack counts
      // that need exactly two and exactly three sub-columns.
      final twoCols = (perColumn + 2) ~/ 2;
      final threeCols = (2 * perColumn + 2) ~/ 2;
      final measurer = FakeMeasurer();
      final two = drawCoverIndex(
        rows: coverIndexRows(SheetSet.forRacks(_racks(twoCols)).sheets),
        box: box,
        measurer: measurer,
      );
      expect(two.columns, 2);
      expect(two.omitted, isEmpty);
      expectInside(two, box, measurer);
      final three = drawCoverIndex(
        rows: coverIndexRows(SheetSet.forRacks(_racks(threeCols)).sheets),
        box: box,
        measurer: measurer,
      );
      expect(three.columns, 3);
      expect(three.omitted, isEmpty);
      expectInside(three, box, measurer);
    });

    test('IN THREE SUB-COLUMNS A TITLE GIVES WAY FROM THE ROLE, and the rack '
        'that tells the rows apart survives', () {
      final box = column();
      final perColumn = ((box.height - (kCoverIndexRow + 6)) / kCoverIndexRow)
          .floor();
      final r = drawCoverIndex(
        rows: coverIndexRows(
          SheetSet.forRacks(_racks((2 * perColumn + 2) ~/ 2)).sheets,
        ),
        box: box,
        measurer: FakeMeasurer(),
      );
      expect(r.columns, 3);
      final elevations = textsOf(
        r.ops,
      ).where((t) => t.contains(' · RK-')).toList();
      expect(elevations, isNotEmpty);
      for (final t in elevations) {
        // The face AND the rack survive: the two facts that tell one
        // elevation row from the next. The first draft kept neither.
        expect(
          t,
          matches(RegExp(r'^(FRONT|REAR|RACK ELEVATION).* · RK-\d+$')),
          reason: t,
        );
        expect(t, matches(RegExp('FRONT|REAR')), reason: t);
      }
    });

    test('A SET THREE COLUMNS CANNOT HOLD names what it leaves out, in its '
        'last row and in the result', () {
      final box = column();
      final r = draw(200);
      expect(r.columns, kCoverIndexMaxColumns);
      expect(r.omitted, isNotEmpty);
      final texts = textsOf(r.ops);
      expect(texts.last, coverIndexOmittedText(r.omitted));
      expect(texts.last, startsWith('+ ${r.omitted.length} more sheets'));
      // The last sheet of the set is among those named.
      expect(r.omitted.last.ncsId, 'T6.30');
      expectInside(r, box, FakeMeasurer());
    });
  });

  test('ON THE COVER, the index is drawn and the sheet is titled for it', () {
    final set = SheetSet.forRacks(_racks(1));
    expect(set.sheets.first.title, 'COVER AND DRAWING INDEX');
    final cover = buildCoverSheet(
      sheet: set.sheets.first,
      info: fullProjectInfo(),
      settings: ProjectSettings(),
      revisions: const <RevisionEntry>[],
      fileName: 'c.rppj',
      issuedAt: DateTime.utc(2026, 10),
      measurer: FakeMeasurer(),
      racks: _racks(1),
      devices: const [],
      templates: const {},
      landings: PortLandings.none,
      sheets: set.sheets,
    );
    final texts = textsOf(cover.scene.ops);
    expect(texts, containsAll(['DRAWING INDEX', 'T2.02', 'SYMBOL LEGEND']));
    expect(cover.indexColumns, 1);
    expect(cover.indexOmitted, isEmpty);
  });
}
