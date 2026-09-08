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

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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
const String _kPageDict =
    '/MediaBox[0 0 2592 1728]/Resources<</XObject<</img0 5 0 R>>>>';

/// A one-page PDF wrapping [image], with [content] as the page's stream.
Uint8List onePagePdf(Uint8List image, {String content = _kFullPage}) {
  final buf = BytesBuilder();
  void put(String s) => buf.add(latin1.encode(s));
  put('%PDF-1.4\n');
  put('1 0 obj\n<</Type/Catalog/Pages 2 0 R>>\nendobj\n');
  put('2 0 obj\n<</Type/Pages/Kids[3 0 R]/Count 1>>\nendobj\n');
  put(
    '3 0 obj\n<</Type/Page/Parent 2 0 R$_kPageDict/Contents 4 0 R>>\nendobj\n',
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

List<Outcome<LiftedPdfPage>> okPages(Uint8List pdf) =>
    (readPdfPages(pdf) as Ok<List<Outcome<LiftedPdfPage>>>).value;

Object errorOf(Outcome<Object?> o) => (o as Err).error;

void main() {
  group('readPdfPages', () {
    test('a liftable page comes back for the picker', () {
      final pages = okPages(onePagePdf(realJpeg(100, 50)));
      expect(pages, hasLength(1));
      final page = (pages.single as Ok<LiftedPdfPage>).value;
      expect(page.header.pixelWidth, 100);
      expect(page.effectiveDpi, closeTo(100 / 36, 0.01));
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
      expect(text, contains('PLAN-D/3'));
    });

    test('something that is not a PDF is refused before any of that', () {
      expect(errorOf(readPdfPages(realJpeg(10, 10))), isA<NotAPdfError>());
    });
  });

  group('importLiftedPdfPage: the lifted page is NOT privileged', () {
    LiftedPdfPage soleLifted(Uint8List pdf) =>
        (okPages(pdf).single as Ok<LiftedPdfPage>).value;

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
}
