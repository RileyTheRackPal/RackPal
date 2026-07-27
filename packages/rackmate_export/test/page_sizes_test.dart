// The ANSI page formats (docs/08-pdf-export.md §6.1).
//
// These numbers exist TWICE — as `SheetSize` in rackmate_core (pure
// geometry, where the furniture is laid out) and as `PdfPageFormat` here
// (what dart_pdf writes into `/MediaBox`). That duplication is deliberate:
// core may not import `package:pdf`. It is also exactly the kind of
// duplication that drifts, so the two are asserted equal here -- the one
// place in the workspace where both are visible.

import 'package:pdf/pdf.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_export/rackmate_export.dart';
import 'package:test/test.dart';

void main() {
  test('the pdf package agrees that a point is 1/72 in', () {
    // The whole nanometre -> point chain assumes it.
    expect(PdfPageFormat.inch, kPdfPointsPerInch);
  });

  test('ANSI B portrait is 792 x 1224 pt', () {
    expect(ansiBPortrait.width, 792.0);
    expect(ansiBPortrait.height, 1224.0);
  });

  test('ANSI A landscape is 792 x 612 pt -- wide, not rotated', () {
    expect(ansiALandscape.width, 792.0);
    expect(ansiALandscape.height, 612.0);
    expect(ansiALandscape.width, greaterThan(ansiALandscape.height));
  });

  test('both formats declare ZERO dart_pdf margins -- we own margins', () {
    // A non-zero margin here would silently offset every full-page
    // painter, and the furniture already applies §6.1's
    // fromLTRB(54, 36, 36, 36) itself.
    for (final format in <PdfPageFormat>[ansiBPortrait, ansiALandscape]) {
      expect(format.marginLeft, 0.0);
      expect(format.marginTop, 0.0);
      expect(format.marginRight, 0.0);
      expect(format.marginBottom, 0.0);
    }
  });

  test('every SheetSize maps to a format of exactly its own dimensions', () {
    // THE anti-drift assertion: core's pure numbers and the PDF page box
    // are the same paper.
    for (final size in SheetSize.values) {
      final format = pdfPageFormatFor(size);
      expect(format.width, size.widthPt, reason: size.name);
      expect(format.height, size.heightPt, reason: size.name);
    }
  });

  test('the format matches what the sheet geometry lays out against', () {
    for (final size in SheetSize.values) {
      final geometry = SheetGeometry(size);
      final format = pdfPageFormatFor(size);
      expect(geometry.pageBox.width, format.width);
      expect(geometry.pageBox.height, format.height);
      // And the frame really is inside the paper.
      expect(geometry.frameBox.right, lessThan(format.width));
      expect(geometry.frameBox.bottom, lessThan(format.height));
    }
  });
}
