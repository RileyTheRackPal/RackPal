// The ISSUED FOR CONSTRUCTION stamp (M6-G5 `#346`, CR-022, DR-216).
//
// On every sheet of a stamped set, directly above the revision block and
// its width; a full-width band above the strip on the compact sheet, which
// has no revision block. RESERVED in the layout, so the drawing area (and
// with it every pagination dry run) stops above it.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

final DateTime _issued = DateTime.utc(2026, 10);

SheetSet _set({required bool stamped}) =>
    SheetSet.forRacks(<Rack>[testRack()], stamped: stamped);

SheetFurniture _furniture(SheetDef sheet) => buildSheetFurniture(
  sheet: sheet,
  info: fullProjectInfo(),
  settings: ProjectSettings(),
  rack: sheet.rackId == null ? null : testRack(),
  revisions: const <RevisionEntry>[],
  scale: DrawingScale.standard(8),
  fileName: 'smith.rppj',
  issuedAt: _issued,
  measurer: FakeMeasurer(),
);

void main() {
  group('the set marks it (§11.215.2: every sheet)', () {
    test('a stamped set marks EVERY sheet, and an unstamped one none', () {
      expect(
        _set(stamped: true).sheets.map((s) => s.stamped),
        everyElement(isTrue),
      );
      expect(
        _set(stamped: false).sheets.map((s) => s.stamped),
        everyElement(isFalse),
      );
      expect(
        oneRackSheetSet().sheets.map((s) => s.stamped),
        everyElement(isFalse),
      );
    });

    test("the flag is part of a sheet's identity, and nothing else moves", () {
      final on = _set(stamped: true).sheets;
      final off = _set(stamped: false).sheets;
      expect(on.map((s) => s.ncsId), off.map((s) => s.ncsId));
      for (var i = 0; i < on.length; i++) {
        expect(on[i], isNot(off[i]), reason: on[i].ncsId);
      }
    });
  });

  group('the layout reserves it', () {
    test(
      'ABOVE THE REVISION BLOCK, its width, and the drawing stops above it',
      () {
        final off = SheetLayout.resolve(
          geometry: const SheetGeometry(SheetSize.ansiBLandscape),
          revisionRowCount: 2,
        );
        final on = SheetLayout.resolve(
          geometry: const SheetGeometry(SheetSize.ansiBLandscape),
          revisionRowCount: 2,
          stamped: true,
        );
        expect(off.stampBox, isNull);
        final stamp = on.stampBox!;
        final revision = on.revisionBlockBox!;
        expect(stamp.left, closeTo(revision.left, 1e-9));
        expect(stamp.right, closeTo(revision.right, 1e-9));
        expect(stamp.bottom, closeTo(revision.top, 1e-9));
        expect(stamp.height, kStampHeight);
        expect(on.drawingArea.bottom, lessThanOrEqualTo(stamp.top));
        // The furniture below it does not move.
        expect(on.titleBlockBox, off.titleBlockBox);
        expect(on.revisionBlockBox, off.revisionBlockBox);
      },
    );

    test('the drawing area is shorter by exactly the stamp', () {
      for (final size in SheetSize.values) {
        final off = SheetLayout.resolve(
          geometry: SheetGeometry(size),
          revisionRowCount: 3,
        );
        final on = SheetLayout.resolve(
          geometry: SheetGeometry(size),
          revisionRowCount: 3,
          stamped: true,
        );
        expect(
          off.drawingArea.height - on.drawingArea.height,
          closeTo(kStampHeight, 1e-9),
          reason: '$size',
        );
      }
    });

    test('ON THE COMPACT STRIP, a full-width band directly above it', () {
      final on = SheetLayout.resolve(
        geometry: const SheetGeometry(SheetSize.ansiALandscape),
        revisionRowCount: 2,
        stamped: true,
      );
      expect(on.revisionBlockBox, isNull);
      final stamp = on.stampBox!;
      expect(stamp.left, closeTo(on.frameBox.left, 1e-9));
      expect(stamp.right, closeTo(on.frameBox.right, 1e-9));
      expect(stamp.bottom, closeTo(on.titleBlockBox.top, 1e-9));
    });
  });

  group('the furniture draws it', () {
    test('every stamped sheet prints the words and the issue date, inside '
        'its stamp box and inside the margin box', () {
      for (final sheet in _set(stamped: true).sheets) {
        final furniture = _furniture(sheet);
        final texts = textOps(furniture.ops);
        final words = texts.where((t) => t.text == kIssuedForConstruction);
        expect(words, hasLength(1), reason: sheet.ncsId);
        final date = texts.where(
          (t) => t.text == formatSheetDate(_issued),
        );
        expect(date, isNotEmpty, reason: sheet.ncsId);
        final box = furniture.layout.stampBox!;
        expect(box.contains(words.single.at), isTrue, reason: sheet.ncsId);

        final ink = inkBoundsOf(furniture.ops, measurer: FakeMeasurer())!;
        final page = furniture.layout.geometry.marginBox.inflate(1);
        expect(ink.left, greaterThanOrEqualTo(page.left), reason: sheet.ncsId);
        expect(ink.right, lessThanOrEqualTo(page.right), reason: sheet.ncsId);
        expect(ink.top, greaterThanOrEqualTo(page.top), reason: sheet.ncsId);
      }
    });

    test('an unstamped sheet prints neither', () {
      for (final sheet in _set(stamped: false).sheets) {
        expect(
          textsOf(_furniture(sheet).ops),
          isNot(contains(kIssuedForConstruction)),
          reason: sheet.ncsId,
        );
      }
    });
  });
}
