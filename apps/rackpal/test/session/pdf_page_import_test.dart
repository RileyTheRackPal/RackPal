// DR-138's PDF route through the app layer: read the pages, and turn the
// one a person picked into an underlay.
//
// ═══════════════════════════════════════════════════════════════════════
// THE POINT OF THIS FILE IS THAT A LIFTED PAGE IS NOT PRIVILEGED
// ═══════════════════════════════════════════════════════════════════════
// DR-138 §11.137.6: a lifted page is an untrusted image that happens to
// have come out of a file this product parsed. Exempting it from a check
// because "we produced it" would be exempting it because we trusted the
// stranger who sent the PDF. So the cases below re-run PLAN-D/4's controls
// on the lifted path and assert they still fire.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rackpal/src/session/pdf_rasteriser.dart';
import 'package:rackpal/src/session/plan_import_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';

final _fixed = DateTime.utc(2026, 9, 7, 9);
const _id = Uuid('0190e3c1-1111-7000-8000-000000000002');

EntityMeta _meta() =>
    EntityMeta(createdAt: _fixed, updatedAt: _fixed, updatedBy: 'tester');

/// A real, decodable JPEG, because this path decodes for real.
Uint8List realJpeg(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(20, 90, 160));
  return img.encodeJpg(image);
}

const String _kFullPage =
    'q\nBT\n36 1692 Td\nET\nQ\nq 2484 0 0 1656 54 36 cm /img0 Do Q\n';
// PDF dictionary syntax has no whitespace between its tokens, so these
// are interpolated pieces rather than adjacent string literals: the
// analyzer is right that adjacent literals usually want a space, and here
// a space would change the fixture.
const String _kImageProps =
    '/Type/XObject/Subtype/Image/Width 100/Height 50/ColorSpace/DeviceRGB';
const String _kImageDict = '$_kImageProps/BitsPerComponent 8/Filter/DCTDecode';

/// A page of a CAD plot: ANSI B, a Type1 font, and NO `/XObject` key.
///
/// One interpolated constant rather than adjacent literals, on
/// `_kImageProps`'s own precedent a few lines up: PDF dictionary syntax has
/// no whitespace between its tokens, and the analyzer's
/// `missing_whitespace_between_adjacent_strings` would have a space added
/// that changes the fixture.
const String _kCadFontRes =
    '<</Font<</F1<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>>>>>';
const String _kCadPageDict = '/MediaBox[0 0 1224 792]/Resources$_kCadFontRes';

/// A CAD PLOT: several pages, a font, linework, and **no image at all**.
///
/// A twin of DR-145 §11.144's real file, which is not in the repository.
/// `rackpal_core`'s `pdf_page_lift_test.dart` carries the same builder for
/// the same reason; the duplication is deliberate, because a test package
/// cannot import another package's tests and neither fixture belongs in
/// shipping code.
Uint8List cadPlotPdf({int pages = 3}) {
  final buf = BytesBuilder();
  void put(String s) => buf.add(latin1.encode(s));
  final kids = [for (var i = 0; i < pages; i++) '${3 + i * 2} 0 R'].join(' ');
  put('%PDF-1.7\n');
  put('1 0 obj\n<</Type/Catalog/Pages 2 0 R>>\nendobj\n');
  put('2 0 obj\n<</Type/Pages/Kids[$kids]/Count $pages>>\nendobj\n');
  for (var i = 0; i < pages; i++) {
    final pageObj = 3 + i * 2;
    final content =
        'q 0.5 w 100 100 m 1100 100 l S Q\n'
        'BT /F1 10 Tf 120 120 Td (BEDROOM ${i + 1}) Tj ET\n';
    put(
      '$pageObj 0 obj\n<</Type/Page/Parent 2 0 R$_kCadPageDict'
      '/Contents ${pageObj + 1} 0 R>>\nendobj\n',
    );
    put('${pageObj + 1} 0 obj\n<</Length ${content.length}>>\nstream\n');
    put(content);
    put('\nendstream\nendobj\n');
  }
  put('trailer\n<</Root 1 0 R>>\n%%EOF\n');
  return buf.toBytes();
}

/// A one-page PDF wrapping [image], with [content] as the page's stream.
Uint8List onePagePdf(
  Uint8List image, {
  String content = _kFullPage,
  String mediaBox = '[0 0 2592 1728]',
}) {
  final buf = BytesBuilder();
  void put(String s) => buf.add(latin1.encode(s));
  put('%PDF-1.4\n');
  put('1 0 obj\n<</Type/Catalog/Pages 2 0 R>>\nendobj\n');
  put('2 0 obj\n<</Type/Pages/Kids[3 0 R]/Count 1>>\nendobj\n');
  put(
    '3 0 obj\n<</Type/Page/Parent 2 0 R/MediaBox$mediaBox'
    '/Resources<</XObject<</img0 5 0 R>>>>/Contents 4 0 R>>\nendobj\n',
  );
  put('4 0 obj\n<</Length ${content.length}>>\nstream\n');
  put(content);
  put('\nendstream\nendobj\n');
  put('5 0 obj\n<<$_kImageDict/Length ${image.length}>>\nstream\n');
  buf.add(image);
  put('\nendstream\nendobj\n');
  put('trailer\n<</Root 1 0 R>>\n%%EOF\n');
  return buf.toBytes();
}

List<Outcome<PdfPageOption>> okPages(Uint8List pdf, {PdfRasteriser? with_}) =>
    (readPdfPages(pdf, rasteriser: with_) as Ok<List<Outcome<PdfPageOption>>>)
        .value;

Object errorOf(Outcome<Object?> o) => (o as Err).error;

/// A one-page plot of vectors on a SMALL sheet: 144 x 72 pt, which is
/// 600 x 300 px at DR-153's 300 dpi.
///
/// Small on purpose. The rule is the same at any size and the core suite
/// asserts it on the real sheet sizes; a case here that rendered ANSI B
/// would spend sixteen megapixels to prove a member name.
/// One interpolated constant rather than adjacent literals, on the core
/// fixture's own precedent: PDF dictionary syntax has no whitespace
/// between its tokens, and `missing_whitespace_between_adjacent_strings`
/// would have a space added that changes the fixture.
const String _kSmallPageDict = '/MediaBox[0 0 144 72]/Resources$_kCadFontRes';

Uint8List smallVectorPdf() {
  final buf = BytesBuilder();
  void put(String s) => buf.add(latin1.encode(s));
  const content = 'q 1 w 10 10 m 130 60 l S Q\n';
  put('%PDF-1.7\n');
  put('1 0 obj\n<</Type/Catalog/Pages 2 0 R>>\nendobj\n');
  put('2 0 obj\n<</Type/Pages/Kids[3 0 R]/Count 1>>\nendobj\n');
  put(
    '3 0 obj\n<</Type/Page/Parent 2 0 R$_kSmallPageDict'
    '/Contents 4 0 R>>\nendobj\n',
  );
  put('4 0 obj\n<</Length ${content.length}>>\nstream\n');
  put(content);
  put('\nendstream\nendobj\n');
  put('trailer\n<</Root 1 0 R>>\n%%EOF\n');
  return buf.toBytes();
}

/// A real PNG of exactly [w] by [h], because `importFloorplanBytes`
/// decodes what it is given and re-checks the decode against the header.
Uint8List stubPng(int w, int h) {
  final image = img.Image(width: w, height: h)
    ..clear(img.ColorRgb8(255, 255, 255));
  for (var x = 0; x < w; x++) {
    image.setPixelRgb(x, h ~/ 2, 0, 0, 0);
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// A renderer that draws one line and answers at exactly the size asked
/// for. It proves the FLOW; `plan_import_pdfium_test.dart` proves pdfium.
Outcome<Uint8List> _fakeRasteriser(
  Uint8List pdf,
  int pageIndex, {
  required int width,
  required int height,
}) => Ok(stubPng(width, height));

void main() {
  group('readPdfPages', () {
    test('a liftable page comes back for the picker', () {
      final pages = okPages(onePagePdf(realJpeg(100, 50)));
      expect(pages, hasLength(1));
      final page = (pages.single as Ok<PdfPageOption>).value;

      expect(page, isA<LiftedPageOption>());
      expect(page.resultWidth, 100);
      expect(page.resultDpi, closeTo(100 / 36, 0.01));
    });

    test('A PDF WHOSE PAGES ARE ALL REFUSED IS ITS OWN ERROR, not '
        '"PDF import is not available"', () {
      // The two sentences are different and only one is true. Telling
      // somebody PDF import is unavailable, about a file this product
      // just parsed a page of, would be false.
      final pdf = onePagePdf(
        realJpeg(100, 50),
        content: 'q BT (VOID) Tj ET Q\n$_kFullPage',
      );
      final error = errorOf(readPdfPages(pdf));
      expect(error, isA<PdfHasNoLiftablePageError>());
      expect(error, isNot(isA<PdfImportNotAvailableError>()));
    });

    test('and it carries the page count and the FIRST page’s reason, so '
        'the message is specific', () {
      final pdf = onePagePdf(
        realJpeg(100, 50),
        content: 'q BT (VOID) Tj ET Q\n$_kFullPage',
      );
      final text = errorOf(readPdfPages(pdf)).toString();
      expect(text, contains('1 page '));
      expect(text, contains('paints its own content'));
      // THE CITATION MOVED WITH THE COPY. It read PLAN-D/3 while the
      // sentence's job was to stand in for a missing rasteriser; the
      // sentence now describes what happens when the rasteriser also
      // declines, which is DR-153's.
      expect(text, contains('DR-153'));
    });

    test('A REAL CAD PLOT: three pages, all refused, and the sentence says '
        'THREE', () {
      // ═══════════════════════════════════════════════════════════════
      // THE COUNT HAD NEVER BEEN ANYTHING BUT ONE
      // ═══════════════════════════════════════════════════════════════
      // Every fixture in this file is a ONE-page PDF, so
      // `PdfHasNoLiftablePageError.pageCount` had only ever rendered as
      // `1 page`. DR-145 §11.144's real file is three pages, and the
      // sentence a person sees is the plural one.
      //
      // The fixture is a twin of that file's signature rather than the
      // minimum that trips the rule: a classic xref, ANSI B pages, a
      // populated `/Resources` holding a font, path and text operators,
      // and no `/XObject` anywhere.
      // WITH NO RASTERISER, which is what this call means: the flow
      // hands one in and every case below does. A CAD plot with nothing
      // able to draw it is still three refused pages, and the count in
      // the sentence is what this case is about.
      final text = errorOf(readPdfPages(cadPlotPdf())).toString();
      expect(text, contains('has 3 pages'));
      expect(text, contains('draws no image'));
      // AND THE ADVICE IS NO LONGER "convert it yourself". A page that
      // reaches this sentence is one the renderer also declined, so the
      // remedy is a different viewer rather than a different format
      // (DR-153). The old copy said "for now", about a feature that now
      // exists.
      expect(text, isNot(contains('for now')));
      expect(text, contains('If another viewer opens this file'));
    });

    test('something that is not a PDF is refused before any of that', () {
      expect(errorOf(readPdfPages(realJpeg(10, 10))), isA<NotAPdfError>());
    });
  });

  group('importLiftedPdfPage: the lifted page is NOT privileged', () {
    LiftedPdfPage soleLifted(Uint8List pdf) =>
        ((okPages(pdf).single as Ok<PdfPageOption>).value as LiftedPageOption)
            .page;

    Outcome<ImportedFloorplan> importIt(LiftedPdfPage page) =>
        importLiftedPdfPage(
          page: page,
          id: _id,
          name: 'A-2.1 First Floor',
          order: const FracIndex('a0'),
          meta: _meta(),
        );

    test('a lifted page becomes an underlay naming a container member', () {
      final page = soleLifted(onePagePdf(realJpeg(120, 80)));
      final result = (importIt(page) as Ok<ImportedFloorplan>).value;

      expect(result.underlay.format, PlanImageFormat.jpeg);
      expect(result.underlay.pixelWidth, 120);
      expect(result.underlay.imageMember, 'underlays/${_id.v}.jpg');
      expect(result.underlay.contentHash, startsWith('sha256:'));
    });

    test('THE STORED BYTES ARE THE PDF’S OWN BYTES, so lifting has not '
        'quietly become a re-encode', () {
      // DR-138 §11.137.3's whole claim. If this ever weakens, the ruling's
      // argument for preferring the lifter over a rasteriser is gone and
      // this file should say so.
      final source = realJpeg(200, 140);
      final page = soleLifted(onePagePdf(source));
      final result = (importIt(page) as Ok<ImportedFloorplan>).value;
      expect(result.memberBytes, source);
    });

    test('AN IMPORTED PLAN IS STILL UNCALIBRATED, PDF or not', () {
      // G4. The route in does not change what is known about scale.
      final page = soleLifted(onePagePdf(realJpeg(120, 80)));
      final result = (importIt(page) as Ok<ImportedFloorplan>).value;
      expect(result.underlay.scale, isNull);
      expect(result.underlay.isCalibrated, isFalse);
    });

    test('PLAN-D/4’S PIXEL CAP STILL FIRES on a lifted page, which is '
        'the exemption this file exists to refuse', () {
      // The lifter's own header read already refuses this, so the page
      // never reaches the import. Asserted from the outside, because what
      // matters is that the bomb does not become an underlay, not which
      // of the two guards stopped it.
      final bomb = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xC0,
        0x00,
        0x11,
        0x08,
        0xEA,
        0x60,
        0xEA,
        0x60,
        0x03,
        0x01,
        0x22,
        0x00,
        0x02,
        0x11,
        0x01,
        0x03,
        0x11,
        0x01,
        0xFF,
        0xD9,
      ]);
      // The one page is refused, so the whole file takes the all-refused
      // path. That is the correct shape and the FIRST draft of this test
      // asserted the other one.
      final error = errorOf(readPdfPages(onePagePdf(bomb)));
      expect(error, isA<PdfHasNoLiftablePageError>());
      // AND THE CAP'S OWN SENTENCE SURVIVES INTO THE MESSAGE. Collapsing
      // it to "could not be read" would make a refused-on-size page sound
      // like a damaged file, which is a different problem with a
      // different remedy.
      expect(error.toString(), contains('ImageTooLargeError'));
    });
  });

  group('the direct path still refuses a PDF, and says why', () {
    test('importFloorplanBytes on a PDF is a SKIPPED PICKER, not an '
        'unsupported format', () {
      // The arm is kept rather than deleted: this function is the one
      // every route reaches, so a PDF arriving here means somebody went
      // around the picker.
      final pdf = onePagePdf(realJpeg(50, 50));
      final result = importFloorplanBytes(
        bytes: pdf,
        id: _id,
        name: 'x',
        order: const FracIndex('a0'),
        meta: _meta(),
      );
      expect(errorOf(result), isA<PdfImportNotAvailableError>());
    });
  });

  group('PLAN-K/4: a page of vectors is RENDERED rather than refused', () {
    /// LOAD-BEARING, AND IT IS THE ONE THAT COULD ROT QUIETLY.
    /// DR-138 §11.137.3 rules that lifting is not a cheaper rasterisation
    /// but a better one: rasterising a page whose only content is a JPEG
    /// decodes and re-encodes it, losing a generation and gaining no
    /// pixel. A renderer that ran on a liftable page would pass every
    /// other case in this file while quietly throwing that away.
    test('a liftable page is still LIFTED, and the renderer is not asked', () {
      var asked = 0;
      final pages = okPages(
        onePagePdf(realJpeg(100, 50)),
        with_: (pdf, index, {required width, required height}) {
          asked++;
          return Ok(stubPng(width, height));
        },
      );

      expect(pages.single, isA<Ok<PdfPageOption>>());
      expect(
        (pages.single as Ok<PdfPageOption>).value,
        isA<LiftedPageOption>(),
      );
      expect(asked, 0, reason: 'lifting is preferred, not merely cheaper');
    });

    test('every page of a CAD plot comes back as a rendered option', () {
      final pages = okPages(cadPlotPdf(), with_: _fakeRasteriser);

      expect(pages, hasLength(3));
      for (final page in pages) {
        expect(page, isA<Ok<PdfPageOption>>());
        expect((page as Ok<PdfPageOption>).value, isA<RenderedPageOption>());
      }
    });

    test('the plan comes from the page MediaBox, at the ruled dpi', () {
      final option =
          (okPages(cadPlotPdf(), with_: _fakeRasteriser).first
                  as Ok<PdfPageOption>)
              .value;

      // ANSI B at 300 dpi. The rule is asserted in the core suite; what
      // this case proves is that the page's MediaBox reached it.
      expect(option.resultWidth, 5100);
      expect(option.resultHeight, 3300);
      expect(option.resultDpi, closeTo(300, 0.001));
    });

    /// THE PREVIEW IS SMALL AND THE RESULT IS NOT. Rendering eighteen
    /// ARCH D pages at 300 dpi to fill a grid of thumbnails would be four
    /// hundred megapixels of work to draw pictures 320 px wide.
    test('the PREVIEW is asked for at thumbnail width, not at the plan', () {
      final asks = <List<int>>[];
      okPages(
        cadPlotPdf(pages: 1),
        with_: (pdf, index, {required width, required height}) {
          asks.add([width, height]);
          return Ok(stubPng(width, height));
        },
      );

      expect(asks, hasLength(1));
      expect(asks.single.first, kPagePreviewWidth);
      expect(
        asks.single.last,
        closeTo(kPagePreviewWidth * 792 / 1224, 1),
        reason: 'the thumbnail keeps the shape of the sheet',
      );
    });

    test('with no rasteriser it is refused exactly as it was before', () {
      // The seam is what changed, and nothing else. A flow handed no
      // renderer behaves as PLAN-D/3 shipped.
      final error = errorOf(readPdfPages(cadPlotPdf()));
      expect(error, isA<PdfHasNoLiftablePageError>());
    });

    test('a render that fails reports ITS reason and not the one the '
        'lifter gave', () {
      // One page, so the document-level guard fires and the sentence a
      // person reads is the one under test.
      final error = errorOf(
        readPdfPages(
          cadPlotPdf(pages: 1),
          rasteriser: (pdf, index, {required width, required height}) =>
              const Err('the renderer said no'),
        ),
      );

      expect(error.toString(), contains('the renderer said no'));
      expect(
        error.toString(),
        isNot(contains('draws no image')),
        reason: 'the lift refusal was superseded by the render attempt',
      );
    });

    /// A refusal ABOUT the MediaBox cannot be rendered: nothing knows how
    /// big to draw it, and `PdfPageNotLiftableError.hasSheetSize` is what
    /// says so.
    test('a page with no usable MediaBox is not offered to the renderer', () {
      var asked = 0;
      final error = errorOf(
        readPdfPages(
          onePagePdf(realJpeg(10, 10), mediaBox: '[0 0 0 0]'),
          rasteriser: (pdf, index, {required width, required height}) {
            asked++;
            return Ok(stubPng(width, height));
          },
        ),
      );

      expect(asked, 0, reason: 'nothing knows how big to draw it');
      expect(error.toString(), contains('MediaBox'));
    });
  });

  group('importRenderedPdfPage keeps the source (DR-153 §11.152.6)', () {
    RenderedPageOption smallOption() =>
        (okPages(smallVectorPdf(), with_: _fakeRasteriser).single
                    as Ok<PdfPageOption>)
                .value
            as RenderedPageOption;

    Outcome<ImportedFloorplan> importIt(Uint8List pdf) => importRenderedPdfPage(
      pdf: pdf,
      option: smallOption(),
      rasteriser: _fakeRasteriser,
      id: _id,
      name: 'A-2.1 First Floor',
      order: const FracIndex('a0'),
      meta: _meta(),
    );

    test('the underlay is the page at the planned size, stored as PNG', () {
      final pdf = smallVectorPdf();
      final result = (importIt(pdf) as Ok<ImportedFloorplan>).value;

      expect(result.underlay.format, PlanImageFormat.png);
      expect(result.underlay.pixelWidth, smallOption().plan.width);
      expect(result.underlay.pixelHeight, smallOption().plan.height);
      expect(result.underlay.imageMember, 'underlays/${_id.v}.png');
    });

    /// LOAD-BEARING. The vector is gone once the page is drawn, and only
    /// the source can bring it back.
    test('it names the source PDF, the page inside it, and its hash', () {
      final pdf = smallVectorPdf();
      final underlay = (importIt(pdf) as Ok<ImportedFloorplan>).value.underlay;
      final source = underlay.sourcePage;

      expect(source, isNotNull);
      expect(source!.member, 'sources/${_id.v}.pdf');
      expect(source.pageIndex, 0);
      expect(source.contentHash, '$kSha256Prefix${sha256.convert(pdf)}');
    });

    /// The other half of the asymmetry, and the reason it is a ruling
    /// rather than an implementation detail: a lifted page's stored bytes
    /// ARE the source, so a copy would store one drawing twice.
    test('AND A LIFTED PAGE KEEPS NOTHING', () {
      final page =
          ((okPages(onePagePdf(realJpeg(120, 80))).single as Ok<PdfPageOption>)
                      .value
                  as LiftedPageOption)
              .page;
      final result =
          (importLiftedPdfPage(
                    page: page,
                    id: _id,
                    name: 'lifted',
                    order: const FracIndex('a0'),
                    meta: _meta(),
                  )
                  as Ok<ImportedFloorplan>)
              .value;

      expect(result.underlay.sourcePage, isNull);
    });

    test('AN IMPORTED PLAN IS STILL UNCALIBRATED, rendered or not', () {
      final result =
          (importIt(smallVectorPdf()) as Ok<ImportedFloorplan>).value;
      expect(result.underlay.scale, isNull);
    });
  });
}
