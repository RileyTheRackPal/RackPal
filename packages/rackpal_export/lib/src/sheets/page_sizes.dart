// rackpal_export/lib/src/sheets/page_sizes.dart -- the ANSI page formats
// `PdfPageFormat` does not ship (docs/08-pdf-export.md §6.1: "PdfPageFormat
// ships only a3, a4, a5, a6, letter, legal, roll57, roll80").
//
// TWO DELIBERATE CHOICES, both of which have bitten people:
//
// 1. ZERO MARGINS. §6.1 declares the ANSI formats with `marginAll: 0.5*_in`
//    and then overrides margins per sheet role. This exporter does neither:
//    every page carries exactly ONE full-page `pw.CustomPaint`, so dart_pdf
//    never lays anything out and its margin machinery would only be a
//    second, silent source of offsets. §6.1's
//    `EdgeInsets.fromLTRB(54, 36, 36, 36)` lives in
//    `rackpal_core/draw/sheet/sheet_frame.dart` as `SheetMargins.standard`
//    and is applied by the furniture builder, in diagram space, where it is
//    unit-testable without a PDF.
//
// 2. LANDSCAPE IS AN EXPLICITLY WIDE FORMAT, NEVER
//    `PageOrientation.landscape`. Verified in the pinned pdf 3.13.0:
//    `FullPage._getConstraints` (basic.dart) reads
//    `context.page.pageFormat.width`/`.height` UNROTATED, so a rotated
//    theme plus a full-page painter disagree about which axis is which and
//    the painter is handed a portrait box on a landscape page. An explicit
//    792 x 612 has no such seam.
//
// The numbers here are the SECOND declaration of each page size -- the
// first is `SheetSize` in rackpal_core, which is where the pure geometry
// lives. `page_sizes_test.dart` asserts the two agree, so a change to one
// without the other is a red suite rather than a sheet whose furniture is
// laid out for a different piece of paper than the page is.

import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// ANSI B portrait, 792 x 1224 pt (11 x 17 in) -- rack elevations (§6.1).
const PdfPageFormat ansiBPortrait = PdfPageFormat(
  11 * PdfPageFormat.inch,
  17 * PdfPageFormat.inch,
);

/// ANSI A landscape, 792 x 612 pt (11 x 8.5 in) -- the equipment list and
/// details (§6.1).
const PdfPageFormat ansiALandscape = PdfPageFormat(
  11 * PdfPageFormat.inch,
  8.5 * PdfPageFormat.inch,
);

/// ANSI B landscape, 1224 x 792 pt (17 x 11 in) -- the device location
/// plan (§6.1, PLAN-H/1).
///
/// EXPLICITLY WIDE, never a rotated portrait: `sheet_def.dart`'s own note
/// records that `pw.FullPage._getConstraints` reads `pageFormat.width` and
/// `.height` UNROTATED, so a `PageOrientation.landscape` theme and a
/// full-page painter disagree about which axis is which.
const PdfPageFormat ansiBLandscape = PdfPageFormat(
  17 * PdfPageFormat.inch,
  11 * PdfPageFormat.inch,
);

/// The `PdfPageFormat` for a core [SheetSize].
PdfPageFormat pdfPageFormatFor(SheetSize size) => switch (size) {
  SheetSize.ansiBPortrait => ansiBPortrait,
  SheetSize.ansiALandscape => ansiALandscape,
  SheetSize.ansiBLandscape => ansiBLandscape,
};
