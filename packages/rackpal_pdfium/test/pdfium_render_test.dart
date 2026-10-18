// PLAN-K/1: the vendored pdfium renders a page (DR-153 §11.152).
//
// ═══════════════════════════════════════════════════════════════════════
// THE LOAD-BEARING CASE IS THAT THE PIXELS ARE NOT ALL ONE COLOUR
// ═══════════════════════════════════════════════════════════════════════
// Every failure this binding can have short of a crash produces a
// PLAUSIBLE bitmap. A page that never loaded, a render flag that skipped
// the content, a bitmap nobody filled: each gives back exactly the buffer
// that was asked for, at exactly the right size, full of one value. So
// the size assertions prove nothing on their own, and the ink is what is
// actually asserted.
//
// AND THE BLANK PAGE IS ITS OWN CASE, in the other direction. A test that
// only ever demanded ink would pass against a renderer that painted the
// whole sheet black, which is what an unfilled buffer looks like: PDF
// pages have no background, so anything the page does not paint stays
// whatever the bitmap already held, and a zeroed bitmap is black.
import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_pdfium/rackpal_pdfium.dart';
import 'package:test/test.dart';

import 'vector_pdf.dart';

/// The document, or a failure that names itself.
PdfiumDocument openOrFail(Uint8List bytes) {
  final result = PdfiumDocument.open(bytes);
  if (result case Err(:final error)) {
    fail('the fixture did not open: $error');
  }
  return (result as Ok<PdfiumDocument>).value;
}

/// How many distinct byte values a raster holds, which is the cheapest
/// honest question to ask of a picture.
int distinctValues(PdfiumRaster raster) => raster.bgr.toSet().length;

// The only `skip:` reason in this package. third_party/pdfium/ vendors
// win-x64 alone (DR-153, CR-100), so on macOS the loader finds the Windows
// DLL and dlopen refuses it: 13 cases here failed with that one message on
// the first macOS run (build 481, DR-255). A check red for a known reason
// cannot show a new one, so they skip there, and the macOS floor in
// tools/ci/run_suite.ps1 is lower by exactly them. Chapter #468 (Story #61)
// deletes this and that floor row together. 'an empty file is refused'
// never reaches the binary, so it runs everywhere. Windows never skips.
final String? noMacOSPdfium = Platform.isMacOS
    ? 'no macOS pdfium is vendored yet (Story #61, Chapter #468)'
    : null;

void main() {
  group('a CAD plot renders', () {
    late PdfiumDocument doc;

    setUp(() => doc = openOrFail(vectorPdf()));
    tearDown(() => doc.close());

    test('every page of the plot is counted', () {
      expect(doc.pageCount, 3);
    });

    test('the page measures the ANSI B box it declares', () {
      final size = doc.sizeOf(0);
      expect(size, isA<Ok<PdfiumPageSize>>());
      final page = (size as Ok<PdfiumPageSize>).value;
      expect(page.widthPt, closeTo(1224, 0.5));
      expect(page.heightPt, closeTo(792, 0.5));
    });

    /// LOAD-BEARING. A bitmap of the right size is what EVERY failure
    /// short of a crash also produces.
    test('the raster carries ink, and is not one flat colour', () {
      final result = doc.render(0, width: 306, height: 198);
      expect(result, isA<Ok<PdfiumRaster>>());
      final raster = (result as Ok<PdfiumRaster>).value;

      expect(raster.width, 306);
      expect(raster.height, 198);
      expect(raster.bgr, hasLength(306 * 198 * 3));
      expect(
        distinctValues(raster),
        greaterThan(1),
        reason: 'a page that never loaded renders as one flat colour',
      );
      expect(
        raster.bgr.where((b) => b < 0x40).length,
        greaterThan(100),
        reason: 'the diagonal and the room name are dark pixels',
      );
    });

    /// LOAD-BEARING in the other direction: this is what proves the
    /// white fill rather than the drawing.
    test('a page that paints nothing renders WHITE, not black', () {
      final blank = openOrFail(vectorPdf(pages: 1, content: ' '));
      addTearDown(blank.close);

      final raster =
          (blank.render(0, width: 64, height: 64) as Ok<PdfiumRaster>).value;
      expect(
        raster.bgr.every((b) => b == 0xFF),
        isTrue,
        reason: 'a PDF page has no background; an unfilled bitmap is black',
      );
    });

    /// LOAD-BEARING, AND NOTHING ELSE HERE COULD SEE IT. A vertically
    /// flipped render has the same size, the same ink and the same bytes
    /// twice, so every other case in this file passes against an
    /// upside-down floorplan. This repository has met that defect once
    /// already, one package over: PLAN-A/3 found that a PDF image
    /// occupies the unit square with its top row at v = 1, so a flipped
    /// placement produces an IDENTICAL bounding box.
    ///
    /// PDF puts y = 0 at the BOTTOM of the page and a raster puts row 0 at
    /// the TOP, so a fill near the top of the page must land in the first
    /// rows.
    test('the raster is not upside down', () {
      // A filled band across the top of the page: y 600 to 750 of 792.
      final doc = openOrFail(
        vectorPdf(pages: 1, content: '0 0 0 rg 100 600 1000 150 re f'),
      );
      addTearDown(doc.close);

      const width = 120;
      const height = 80;
      final raster =
          (doc.render(0, width: width, height: height) as Ok<PdfiumRaster>)
              .value;

      int darkIn(int fromRow, int toRow) => raster.bgr
          .sublist(fromRow * width * 3, toRow * width * 3)
          .where((b) => b < 0x40)
          .length;

      final top = darkIn(0, height ~/ 3);
      final bottom = darkIn(height - height ~/ 3, height);
      expect(top, greaterThan(0), reason: 'the band is drawn near the top');
      expect(
        bottom,
        0,
        reason: 'ink in the bottom third means the page came back flipped',
      );
    });

    /// §8.4: the same document must produce the same bytes.
    test('two renders of one page are byte for byte identical', () {
      final first =
          (doc.render(1, width: 120, height: 80) as Ok<PdfiumRaster>).value;
      final second =
          (doc.render(1, width: 120, height: 80) as Ok<PdfiumRaster>).value;
      expect(first.bgr, orderedEquals(second.bgr));
    });

    test('two pages of the same plot differ, so the index is read', () {
      final one =
          (doc.render(0, width: 160, height: 100) as Ok<PdfiumRaster>).value;
      final two =
          (doc.render(2, width: 160, height: 100) as Ok<PdfiumRaster>).value;
      expect(
        one.bgr,
        isNot(orderedEquals(two.bgr)),
        reason: 'each page names a different room',
      );
    });
  }, skip: noMacOSPdfium);

  group('nothing throws on a bad file (CR-093)', () {
    test('an empty file is refused', () {
      expect(PdfiumDocument.open(Uint8List(0)), isA<Err<PdfiumDocument>>());
    });

    test('bytes that are not a PDF are refused, and pdfium says why', () {
      final result = PdfiumDocument.open(
        Uint8List.fromList(List<int>.filled(2048, 0x41)),
      );
      expect(result, isA<Err<PdfiumDocument>>());
      expect(
        (result as Err<PdfiumDocument>).error.toString(),
        contains('not a PDF'),
      );
    }, skip: noMacOSPdfium);

    test('a truncated plot is refused rather than half-rendered', () {
      final whole = vectorPdf();
      final half = Uint8List.sublistView(whole, 0, whole.length ~/ 2);
      final result = PdfiumDocument.open(half);
      // A rebuild may recover it; what must never happen is a throw.
      if (result case Ok(:final value)) {
        addTearDown(value.close);
        expect(value.pageCount, greaterThan(0));
      }
    }, skip: noMacOSPdfium);

    test('a page past the end is an Err naming both numbers', () {
      final doc = openOrFail(vectorPdf(pages: 1));
      addTearDown(doc.close);

      final result = doc.render(4, width: 10, height: 10);
      expect(result, isA<Err<PdfiumRaster>>());
      expect(
        (result as Err<PdfiumRaster>).error.toString(),
        allOf(contains('page 5'), contains('has 1')),
      );
    }, skip: noMacOSPdfium);

    test('a zero-sized raster is refused before pdfium is asked', () {
      final doc = openOrFail(vectorPdf(pages: 1));
      addTearDown(doc.close);

      expect(doc.render(0, width: 0, height: 10), isA<Err<PdfiumRaster>>());
      expect(doc.render(0, width: 10, height: -1), isA<Err<PdfiumRaster>>());
    }, skip: noMacOSPdfium);

    test('a closed document refuses rather than using a freed handle', () {
      final doc = openOrFail(vectorPdf(pages: 1))..close();

      expect(doc.render(0, width: 10, height: 10), isA<Err<PdfiumRaster>>());
      expect(doc.sizeOf(0), isA<Err<PdfiumPageSize>>());
    }, skip: noMacOSPdfium);

    test('closing twice is not a double free', () {
      openOrFail(vectorPdf(pages: 1))
        ..close()
        ..close();
    }, skip: noMacOSPdfium);
  });
}
