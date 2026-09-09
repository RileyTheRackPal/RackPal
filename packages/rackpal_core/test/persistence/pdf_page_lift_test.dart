// DR-138's lifter: what it accepts, and the much longer list of what it
// refuses and why.
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIXTURES ARE SYNTHETIC AND THE REAL FILE IS NOT IN THE REPOSITORY
// ═══════════════════════════════════════════════════════════════════════
// DR-137 §11.136.6 keeps the plan set out of git: it carries a licensed
// engineer's seal and DR-036's public release publishes every commit ever
// made. So these fixtures are built here, and what they assert is the
// STRUCTURE the lifter keys on rather than one office's output.
//
// The real file was run through this lifter by hand and lifted 18 of 18,
// with byte counts matching an independent carve (docs/12 §5.9.6). That
// measurement is evidence; these tests are the gate.
//
// ═══════════════════════════════════════════════════════════════════════
// MOST OF THIS FILE IS REFUSALS, AND THAT IS THE POINT
// ═══════════════════════════════════════════════════════════════════════
// A lifter that wrongly refuses costs somebody one export from their PDF
// viewer. A lifter that wrongly ACCEPTS hands an installer a drawing with
// the "NOT FOR CONSTRUCTION" stamp, the revision cloud or the redaction
// box quietly missing, and nothing downstream can detect that. So the
// asymmetry is deliberate and each refusal has its own case.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// A minimal but genuine JPEG: SOI, an SOF0 declaring [w] x [h], and EOI.
///
/// Real enough for `readImageHeader`, which is what the lifter runs over
/// the bytes it lifts. Not decodable, and nothing here decodes it.
Uint8List jpegOf(int w, int h) => Uint8List.fromList([
  0xFF, 0xD8, // SOI
  0xFF, 0xC0, 0x00, 0x11, 0x08, // SOF0, length 17, 8-bit
  (h >> 8) & 0xFF, h & 0xFF,
  (w >> 8) & 0xFF, w & 0xFF,
  0x03, // 3 components
  0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
  0xFF, 0xD9, // EOI
]);

/// PDF dictionary syntax has no whitespace between its tokens, so these
/// are named pieces interpolated rather than adjacent string literals.
/// The analyzer is right that adjacent literals usually want a space
/// between them; here a space would change the fixture.
const String kImageProps =
    '/Type/XObject/Subtype/Image/Width 100/Height 50/ColorSpace/DeviceRGB';
const String kJpegImageDict =
    '$kImageProps/BitsPerComponent 8/Filter/DCTDecode';
const String kFlateImageDict =
    '$kImageProps/BitsPerComponent 8/Filter/FlateDecode';
const String kBox = '/MediaBox[0 0 2592 1728]';
const String kSmallBox = '/MediaBox[0 0 100 100]';
const String kRes = '/Resources<</XObject<</img0 5 0 R>>>>';

/// Builds a one-page PDF around [content] and an image XObject.
///
/// Deliberately assembled by hand rather than by a library: the lifter's
/// whole job is reading files it did not write, and a fixture produced by
/// a writer that agrees with it would prove nothing about a stranger's.
Uint8List pdfWith({
  required String content,
  Uint8List? image,
  String imageDict = kJpegImageDict,
  String resources = '<</XObject<</img0 5 0 R>>>>',
  String mediaBox = '[0 0 2592 1728]',
  String? extraObjects,
  String pageExtra = '',
}) {
  final img = image ?? jpegOf(100, 50);
  final buf = BytesBuilder();
  void put(String s) => buf.add(latin1.encode(s));

  put('%PDF-1.4\n');
  put('1 0 obj\n<</Type/Catalog/Pages 2 0 R>>\nendobj\n');
  put('2 0 obj\n<</Type/Pages/Kids[3 0 R]/Count 1>>\nendobj\n');
  put(
    '3 0 obj\n<</Type/Page/Parent 2 0 R/MediaBox $mediaBox'
    '/Resources $resources/Contents 4 0 R$pageExtra>>\nendobj\n',
  );
  put('4 0 obj\n<</Length ${content.length}>>\nstream\n');
  put(content);
  put('\nendstream\nendobj\n');
  put('5 0 obj\n<<$imageDict/Length ${img.length}>>\nstream\n');
  buf.add(img);
  put('\nendstream\nendobj\n');
  if (extraObjects != null) put(extraObjects);
  put('trailer\n<</Root 1 0 R>>\n%%EOF\n');
  return buf.toBytes();
}

/// The shape the real corpus emits: an empty text block, then one image
/// drawn across the sheet.
const String kFullPageContent =
    'q\nBT\n36 1692 Td\nET\nQ\nq 2484 0 0 1656 54 36 cm /img0 Do Q\n';

/// A page of a CAD plot: **ANSI B landscape** (17 x 11 in), which is what
/// the real file declares on all three of its pages, and a `/Resources`
/// that is **populated and image-free**, which is the whole point of the
/// fixture.
///
/// One interpolated constant rather than adjacent literals, on
/// [kImageProps]'s own precedent: PDF dictionary syntax has no whitespace
/// between its tokens, and `missing_whitespace_between_adjacent_strings`
/// would have a space added that changes the fixture.
const String kCadFontRes =
    '<</Font<</F1<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>>>>>';
const String kCadPageDict = '/MediaBox[0 0 1224 792]/Resources$kCadFontRes';

/// A CAD PLOT: several pages, fonts and linework, and **no image at all**
/// (DR-145 §11.144.6).
///
/// ═══════════════════════════════════════════════════════════════════════
/// A TWIN OF A REAL FILE, NOT THE MINIMUM THAT EXERCISES THE RULE
/// ═══════════════════════════════════════════════════════════════════════
/// The second real plan set this project has been given is an AutoCAD 2022
/// plot: three ANSI B pages, a classic cross-reference table, 39 `/Font`
/// occurrences and **zero `/XObject`**. It is not in the repository
/// (DR-145 §11.144.6), so this reproduces its SIGNATURE.
///
/// It is deliberately not `pdfWith(resources: '<<>>')`, which is the same
/// rule at its boundary. A drawing office emits a resource dictionary
/// **populated with fonts** and holding no images, and the difference
/// between an empty dict and a populated one is the difference between
/// proving the branch exists and proving it is reached by the thing that
/// will keep arriving.
Uint8List cadPlotPdf({int pages = 3}) {
  final buf = BytesBuilder();
  void put(String s) => buf.add(latin1.encode(s));

  // Page objects are 3, 5, 7 ...; their content streams 4, 6, 8 ...
  final kids = [for (var i = 0; i < pages; i++) '${3 + i * 2} 0 R'].join(' ');
  put('%PDF-1.7\n');
  put('1 0 obj\n<</Type/Catalog/Pages 2 0 R>>\nendobj\n');
  put('2 0 obj\n<</Type/Pages/Kids[$kids]/Count $pages>>\nendobj\n');
  for (var i = 0; i < pages; i++) {
    final pageObj = 3 + i * 2;
    // Linework and a room name, which is what a plot is: path operators
    // and text, and nothing else.
    final content =
        'q 0.5 w 100 100 m 1100 100 l S Q\n'
        'BT /F1 10 Tf 120 120 Td (BEDROOM ${i + 1}) Tj ET\n';
    put(
      '$pageObj 0 obj\n<</Type/Page/Parent 2 0 R$kCadPageDict'
      '/Contents ${pageObj + 1} 0 R>>\nendobj\n',
    );
    put('${pageObj + 1} 0 obj\n<</Length ${content.length}>>\nstream\n');
    put(content);
    put('\nendstream\nendobj\n');
  }
  put('trailer\n<</Root 1 0 R>>\n%%EOF\n');
  return buf.toBytes();
}

List<Outcome<LiftedPdfPage>> pagesOf(Uint8List bytes) =>
    (liftPdfPages(bytes) as Ok<List<Outcome<LiftedPdfPage>>>).value;

LiftedPdfPage soleLift(Uint8List bytes) {
  final pages = pagesOf(bytes);
  expect(pages, hasLength(1));
  return (pages.single as Ok<LiftedPdfPage>).value;
}

String refusalOf(Uint8List bytes) {
  final pages = pagesOf(bytes);
  expect(pages, hasLength(1));
  return (pages.single as Err<LiftedPdfPage>).error.toString();
}

void main() {
  group('the shape the real corpus emits', () {
    test('a page that is one full-page image lifts', () {
      final page = soleLift(pdfWith(content: kFullPageContent));

      expect(page.pageIndex, 0);
      expect(page.header.pixelWidth, 100);
      expect(page.header.pixelHeight, 50);
      expect(page.header.format, PlanImageFormat.jpeg);
      expect(page.sheetWidthPt, 2592);
      expect(page.sheetHeightPt, 1728);
    });

    test('THE LIFTED BYTES ARE THE EMBEDDED BYTES, which is the whole '
        'claim that lifting beats rasterising', () {
      // DR-138 §11.137.3: rasterising a page whose only content is a
      // JPEG decodes it and re-encodes the result, losing a generation
      // and gaining no pixel. If this assertion ever weakens to a size
      // or a dimension check, the ruling's argument has been given up.
      final source = jpegOf(640, 480);
      final page = soleLift(
        pdfWith(content: kFullPageContent, image: source),
      );
      expect(page.bytes, source);
    });

    test('effectiveDpi is the ceiling on any useful rasterisation', () {
      // 2160 px across 2592 pt is 36 inches, so 60 dpi: the number
      // DR-137 §11.136.4 turns on.
      final page = soleLift(
        pdfWith(content: kFullPageContent, image: jpegOf(2160, 1440)),
      );
      expect(page.effectiveDpi, closeTo(60, 0.01));
    });

    test('a sheet with no width reports no dpi rather than dividing by '
        'zero', () {
      final refusal = refusalOf(
        pdfWith(content: kFullPageContent, mediaBox: '[0 0 0 1728]'),
      );
      expect(refusal, contains('empty MediaBox'));
    });
  });

  group('RULE 4: a page that paints anything of its own is refused', () {
    // The rule that earns its keep. Rules 1 to 3 all hold on a page that
    // ALSO has "VOID" stamped across it, and lifting the image alone
    // would hand an installer a superseded drawing.
    for (final op in const ['Tj', 'TJ', 'S', 'f', 'B', 'sh', 'BI']) {
      test('a `$op` operator refuses the page', () {
        final refusal = refusalOf(
          pdfWith(
            content: 'q BT /F1 12 Tf (VOID) $op ET Q\n$kFullPageContent',
          ),
        );
        expect(refusal, contains('paints its own content'));
        expect(refusal, contains('`$op`'));
      });
    }

    test('AN EMPTY BT/ET PAIR IS NOT PAINTING, which is what the real '
        'corpus emits', () {
      // The negative half. A rule that refused every BT would refuse
      // every page of the only real file this project has.
      expect(
        () => soleLift(pdfWith(content: kFullPageContent)),
        returnsNormally,
      );
    });

    test('A STRING CONTAINING AN OPERATOR NAME IS NOT AN OPERATOR', () {
      // `(Tj)` is a title block's text, not a paint. A tokeniser that
      // could not tell them apart would refuse pages for the wrong
      // reason, and the refusal message would send somebody looking for
      // drawing content that is not there.
      final page = soleLift(
        pdfWith(content: 'q (Tj S f) Q\n$kFullPageContent'),
      );
      expect(page.pageIndex, 0);
    });
  });

  group('RULE 1: exactly one image', () {
    test('two XObjects are refused with the count', () {
      final refusal = refusalOf(
        pdfWith(
          content: kFullPageContent,
          resources: '<</XObject<</img0 5 0 R/img1 5 0 R>>>>',
        ),
      );
      expect(refusal, contains('draws 2 images rather than one'));
    });

    test('no XObject at all is refused', () {
      final refusal = refusalOf(
        pdfWith(content: 'q 1 0 0 1 0 0 cm Q', resources: '<<>>'),
      );
      expect(refusal, contains('draws no image'));
    });

    test('A REAL CAD PLOT IS REFUSED ON EVERY PAGE, and this fixture is a '
        'twin of one rather than the rule at its boundary', () {
      // DR-145 §11.144: the second real plan set this project has been
      // given is an AutoCAD 2022 plot with zero image XObjects, and the
      // shipped importer refuses all three of its pages. The measurement
      // is docs/12 §5.9.15; this is the gate that keeps it true.
      final pages = pagesOf(cadPlotPdf());
      expect(pages, hasLength(3), reason: 'the page tree resolved');
      for (var i = 0; i < pages.length; i++) {
        final page = pages[i];
        expect(page, isA<Err<LiftedPdfPage>>(), reason: 'page ${i + 1}');
        final error = (page as Err<LiftedPdfPage>).error;
        expect((error as PdfPageNotLiftableError).reason, 'draws no image');
      }
    });

    test('AND FOR THE RIGHT REASON, having resolved a POPULATED resource '
        'dictionary first', () {
      // Being right and being right for the right reason are two checks,
      // and docs/12 §5.9.6.4 is why the second is run: this lifter once
      // refused all 18 pages of the FIRST real plan set with a plausible
      // content refusal while the parser was the thing at fault.
      //
      // `draws no image` sits after the MediaBox, malformed-box and
      // Resources checks, so reaching it on a page whose Resources hold a
      // `/Font` proves those passed on real-shaped input.
      final page = pagesOf(cadPlotPdf(pages: 1)).single;
      final error = (page as Err<LiftedPdfPage>).error;
      final refusal = (error as PdfPageNotLiftableError).reason;
      expect(refusal, 'draws no image');
      // The sentences a parse failure would have produced instead. A case
      // asserting only the positive would still pass if the lifter began
      // failing earlier for an unrelated reason, which is exactly the
      // shape §5.9.6.4 records.
      expect(refusal, isNot(contains('MediaBox')));
      expect(refusal, isNot(contains('resources')));
      expect(refusal, isNot(contains('unreadable')));
    });
  });

  group('RULE 2: the image must be liftable as it stands', () {
    test('a FlateDecode image is refused BY FILTER NAME, because lifting '
        'it would mean re-encoding', () {
      final refusal = refusalOf(
        pdfWith(
          content: kFullPageContent,
          imageDict: kFlateImageDict,
        ),
      );
      expect(refusal, contains('/FlateDecode'));
      expect(refusal, contains('re-encoded rather than lifted'));
    });

    test('a form XObject is refused as a form, not as an image problem', () {
      final refusal = refusalOf(
        pdfWith(
          content: kFullPageContent,
          imageDict: '/Type/XObject/Subtype/Form/BBox[0 0 10 10]',
        ),
      );
      expect(refusal, contains('draws a form rather than an image'));
    });
  });

  group('RULE 3: exactly one Do, and it names that image', () {
    test('a page that draws nothing is refused', () {
      final refusal = refusalOf(pdfWith(content: 'q 1 0 0 1 0 0 cm Q'));
      expect(refusal, contains('draws nothing'));
    });

    test('two draws are refused with the count', () {
      final refusal = refusalOf(
        pdfWith(content: '$kFullPageContent q /img0 Do Q\n'),
      );
      expect(refusal, contains('draws 2 objects rather than one'));
    });

    test('a Do naming something else is refused', () {
      final refusal = refusalOf(
        pdfWith(
          content: 'q 2484 0 0 1656 54 36 cm /other Do Q\n',
        ),
      );
      expect(refusal, contains('draws something other than its own image'));
    });
  });

  group('RULE 5: the image must actually be the sheet', () {
    test('a small image on a big sheet is an ILLUSTRATION and is refused '
        'with both percentages', () {
      final refusal = refusalOf(
        pdfWith(content: 'q 200 0 0 150 40 40 cm /img0 Do Q\n'),
      );
      expect(refusal, contains('illustration on a page rather than the page'));
      expect(refusal, contains('%'));
    });

    test('the real corpus 95.8% coverage is ACCEPTED, so the tolerance is '
        'not decoration', () {
      // 2484/2592 is 95.8%: a 54 pt margin on an ARCH D sheet. A rule
      // demanding exact coverage would refuse every page of the only
      // real file this project has.
      expect(
        () => soleLift(pdfWith(content: kFullPageContent)),
        returnsNormally,
      );
    });
  });

  group('the whole file, before any page', () {
    test('something that is not a PDF is refused as such', () {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 13, 10, 26, 10]);
      expect((liftPdfPages(png) as Err).error, isA<NotAPdfError>());
    });

    test('a file over the cap is refused ON ITS SIZE, with the cap lowered '
        'rather than the fixture raised', () {
      // `JsonLimits`' trick again: proving a size gate fires must not
      // cost a 64 MB fixture.
      final pdf = pdfWith(content: kFullPageContent);
      final out = liftPdfPages(pdf, maxBytes: 32);
      expect((out as Err).error, isA<DocumentTooLargeError>());
    });

    test('AN OBJECT STREAM IS ITS OWN REFUSAL, not "this page has vector '
        'content"', () {
      // The objects are valid and are inside a compressed stream this
      // lifter does not decompress, so it cannot even see whether the
      // page would have qualified. Conflating that with a content
      // refusal would send somebody looking for drawing content that is
      // not the issue.
      final pdf = pdfWith(
        content: kFullPageContent,
        extraObjects: '9 0 obj\n<</Type/ObjStm/N 2/First 8>>\nendobj\n',
      );
      expect(
        (liftPdfPages(pdf) as Err).error,
        isA<PdfCompressedCrossReferenceError>(),
      );
    });

    test('garbage after the header is refused rather than throwing', () {
      final junk = Uint8List.fromList([
        ...latin1.encode('%PDF-1.4\n'),
        ...List<int>.filled(400, 0x41),
      ]);
      expect((liftPdfPages(junk) as Err).error, isA<PdfUnreadableError>());
    });

    test('every truncation of a good file is an Err and never a throw', () {
      // CR-093 over the whole prefix space, which is the property a
      // single truncation case cannot establish.
      final pdf = pdfWith(content: kFullPageContent);
      for (var cut = 1; cut < pdf.length; cut += 7) {
        final head = Uint8List.sublistView(pdf, 0, cut);
        expect(
          () => liftPdfPages(head),
          returnsNormally,
          reason: 'truncated at $cut',
        );
      }
    });
  });

  group('the page tree is a graph a stranger wrote', () {
    test('a cycle in the page tree terminates instead of hanging', () {
      final buf = BytesBuilder();
      void put(String s) => buf.add(latin1.encode(s));
      put('%PDF-1.4\n');
      put('2 0 obj\n<</Type/Pages/Kids[6 0 R]/Count 1>>\nendobj\n');
      // 6 points back at 2, which points at 6.
      put('6 0 obj\n<</Type/Pages/Parent 2 0 R/Kids[2 0 R]>>\nendobj\n');
      put('trailer\n<</Root 1 0 R>>\n%%EOF\n');
      final out = liftPdfPages(buf.toBytes());
      // Either refusal is correct; hanging is not, and that is what this
      // case is really asserting.
      expect(out, isA<Err<List<Outcome<LiftedPdfPage>>>>());
    });

    test('MediaBox is INHERITED from the parent, which a real class of '
        'file depends on', () {
      // A page omitting MediaBox takes its parent's. Missing this makes
      // those files look like they declare no sheet size at all.
      final buf = BytesBuilder();
      void put(String s) => buf.add(latin1.encode(s));
      final img = jpegOf(100, 50);
      put('%PDF-1.4\n');
      put('1 0 obj\n<</Type/Catalog/Pages 2 0 R>>\nendobj\n');
      put(
        '2 0 obj\n<</Type/Pages/Kids[3 0 R]/Count 1$kBox>>\nendobj\n',
      );
      put(
        '3 0 obj\n<</Type/Page/Parent 2 0 R$kRes/Contents 4 0 R>>\nendobj\n',
      );
      put('4 0 obj\n<</Length ${kFullPageContent.length}>>\nstream\n');
      put(kFullPageContent);
      put('\nendstream\nendobj\n');
      put(
        '5 0 obj\n<<$kJpegImageDict/Length ${img.length}>>\nstream\n',
      );
      buf.add(img);
      put('\nendstream\nendobj\n');
      put('trailer\n<</Root 1 0 R>>\n%%EOF\n');

      final page = soleLift(buf.toBytes());
      expect(page.sheetWidthPt, 2592);
    });

    test('a page count past the cap is refused, and it is a DIFFERENT '
        'defence from the byte cap', () {
      // A small file can declare thousands of pages, and the picker
      // decodes a thumbnail each. The byte cap never fires.
      final kids = List<String>.generate(40, (i) => '${10 + i} 0 R').join(' ');
      final buf = BytesBuilder();
      void put(String s) => buf.add(latin1.encode(s));
      put('%PDF-1.4\n');
      put('2 0 obj\n<</Type/Pages/Kids[$kids]/Count 40>>\nendobj\n');
      for (var i = 0; i < 40; i++) {
        put(
          '${10 + i} 0 obj\n<</Type/Page/Parent 2 0 R$kSmallBox>>\nendobj\n',
        );
      }
      put('trailer\n<</Root 1 0 R>>\n%%EOF\n');
      final err =
          liftPdfPages(buf.toBytes(), maxPages: 5)
              as Err<List<Outcome<LiftedPdfPage>>>;
      expect(err.error, isA<PdfUnreadableError>());
      expect(err.error.toString(), contains('more than 5 pages'));
    });
  });

  group('the caps PLAN-D/4 built still run on a lifted image', () {
    test('a lifted image declaring 60000x60000 is refused by the SAME cap '
        'that guards a picked file', () {
      // DR-138 §11.137.6: a lifted page is an untrusted image like any
      // other, and is not exempted from a check on the grounds that this
      // product produced it.
      final bomb = jpegOf(60000, 60000);
      final out = pagesOf(pdfWith(content: kFullPageContent, image: bomb));
      expect((out.single as Err).error, isA<ImageTooLargeError>());
    });
  });
}
