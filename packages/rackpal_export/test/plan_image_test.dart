// PLAN-H/1 and PLAN-H/2: the screening pass, and the /SMask that must
// never be emitted (docs/15 section 7, DR-037 section 11.36.3, DR-149
// section 11.148.4).
//
// =====================================================================
// PLAN-A/3 PROVED THIS OVER A HAND-BUILT RESOLVER. THIS PROVES IT OVER
// THE REAL ONE.
// =====================================================================
// `pdf_canvas_image_test.dart` asserts no `/SMask` and no `/ExtGState`
// against a `PdfImage` the test itself constructs with `alpha: false`. It
// proves the CANVAS emits no alpha path when handed an opaque image, which
// is a different claim from the one that matters now: that the thing which
// actually builds a `PdfImage` in production never asks for one. That
// function did not exist until PLAN-H/1.
//
// =====================================================================
// THE ARITHMETIC IS ASSERTED ON BYTES, NOT ON A FACTOR
// =====================================================================
// A screening pass tested by "the output is lighter than the input" passes
// for 1% and for 99%. The cases below name the exact sample values 25%
// produces, so a changed constant is a changed test and a person decides.
import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

const String _member = 'underlays/level-1.png';

const ImageRef _ref = ImageRef(
  member: _member,
  format: ImageFormat.png,
  pixelWidth: 4,
  pixelHeight: 1,
);

/// A four-pixel PNG: opaque black, opaque white, opaque mid grey, and a
/// FULLY TRANSPARENT black.
///
/// The fourth is the one that matters. A pass that discarded alpha rather
/// than compositing it would emit black there, which for a PNG exported
/// from CAD is the ordinary background and would print a solid bar across
/// the sheet.
Uint8List _fourPixelPng() {
  final image = im.Image(width: 4, height: 1, numChannels: 4)
    ..setPixelRgba(0, 0, 0, 0, 0, 255)
    ..setPixelRgba(1, 0, 255, 255, 255, 255)
    ..setPixelRgba(2, 0, 128, 128, 128, 255)
    ..setPixelRgba(3, 0, 0, 0, 0, 0);
  return Uint8List.fromList(im.encodePng(image));
}

/// The RGB samples the resolver wrote into the document, recovered from
/// the built `PdfImage`'s own stream buffer.
List<int> _samples(PdfImage image) => image.buf.output().toList();

/// One screened channel: `255 - (255 - v) * 250 / 1000`, truncating.
int _screened(int v) => 255 - ((255 - v) * 250) ~/ 1000;

void main() {
  late PdfDocument document;
  late PdfImageResolver resolve;

  setUp(() {
    document = pw.Document(compress: false).document;
    resolve = planImageResolver(document, {_member: _fourPixelPng()});
  });

  group('the screening arithmetic', () {
    test('black keeps a quarter of its ink and white stays paper', () {
      final samples = _samples(resolve(_ref)!);

      expect(samples.length, 4 * 3, reason: 'RGB, three bytes per pixel');
      // 192 AND NOT 191, AND THE OFF-BY-ONE IS THE INTEGER RULE SHOWING.
      // Black carries 255 units of ink; a quarter of that is 63.75, and
      // CR-001's integer arithmetic truncates the INK rather than the
      // result, so the sample is 255 - 63 = 192. Written out because the
      // hand calculation says 191 and was wrong.
      expect(samples.sublist(0, 3), [192, 192, 192], reason: 'black at 25%');
      expect(samples.sublist(3, 6), [255, 255, 255], reason: 'white is white');
      expect(samples.sublist(6, 9), [224, 224, 224], reason: 'mid grey');
    });

    test('the constant is what the samples say it is', () {
      // Reads the constant rather than restating 191, so a deliberate
      // change moves this case with the code and an accidental one is
      // caught by the literals above.
      expect(kUnderlayInkRetained.v, 250);
      expect(_screened(0), 192);
      expect(_samples(resolve(_ref)!).first, _screened(0));
    });

    /// LOAD-BEARING. Alpha is composited, never dropped.
    test('a fully transparent pixel becomes paper, not black', () {
      final samples = _samples(resolve(_ref)!);
      expect(
        samples.sublist(9, 12),
        [255, 255, 255],
        reason: 'flattened against white BEFORE the screen',
      );
    });

    test('the pass is monotonic and never darkens', () {
      final samples = _samples(resolve(_ref)!);
      for (final v in samples) {
        expect(v, greaterThanOrEqualTo(192));
        expect(v, lessThanOrEqualTo(255));
      }
    });
  });

  group('THE LOGO IS NOT SCREENED (DR-030 §11.29.3)', () {
    const logo = ImageRef(
      member: _member,
      format: ImageFormat.png,
      pixelWidth: 4,
      pixelHeight: 1,
      screened: false,
    );

    test('full value, and still flattened against white', () {
      expect(_samples(resolve(logo)!), [
        ...[0, 0, 0],
        ...[255, 255, 255],
        ...[128, 128, 128],
        // The transparent pixel is paper here too: no alpha, ever.
        ...[255, 255, 255],
      ]);
    });

    test('one member asked for both ways is two images, not whichever '
        'came first', () {
      final screened = resolve(_ref)!;
      final full = resolve(logo)!;
      expect(identical(screened, full), isFalse);
      expect(_samples(screened).first, _screened(0));
      expect(_samples(full).first, 0);
    });
  });

  group('A FULL-VALUE IMAGE IS EMBEDDED AT THE LOGO BOX, NO LARGER '
      '(DR-217 §11.216.6)', () {
    PdfImage resolveSized(int w, int h, {required bool screened}) {
      const member = 'logos/big.png';
      final bytes = Uint8List.fromList(
        im.encodePng(im.Image(width: w, height: h)),
      );
      return planImageResolver(document, {member: bytes})(
        ImageRef(
          member: member,
          format: ImageFormat.png,
          pixelWidth: w,
          pixelHeight: h,
          screened: screened,
        ),
      )!;
    }

    // 833, NOT 834: 3000 : 1350 is the box's own 100 : 45, and the box at
    // 600 dpi is 833.3 px wide, so it is height-bound.
    test('a 3000 x 1350 logo is embedded at 833 x 375', () {
      final image = resolveSized(3000, 1350, screened: false);
      expect((image.width, image.height), (833, 375));
      expect(_samples(image).length, 833 * 375 * 3);
    });

    test('a tall one is height-bound, aspect kept', () {
      final image = resolveSized(600, 1200, screened: false);
      expect((image.width, image.height), (187, 375));
    });

    test('one already inside the box is not touched, never enlarged', () {
      final image = resolveSized(300, 100, screened: false);
      expect((image.width, image.height), (300, 100));
    });

    test('A FLOORPLAN IS NEVER RESIZED: it is drawn at sheet size', () {
      final image = resolveSized(3000, 1350, screened: true);
      expect((image.width, image.height), (3000, 1350));
    });
  });

  group('what the resolver refuses', () {
    test('a member the container does not hold resolves to null', () {
      // The CANVAS decides what that means: `PdfDiagramCanvas.drawImage`
      // throws `MissingImageError`, because docs/15 section 7 rules that a
      // T1.01 which is a title block over white paper is indistinguishable
      // from a plan with no drops on it.
      const missing = ImageRef(
        member: 'underlays/nobody.png',
        format: ImageFormat.png,
        pixelWidth: 1,
        pixelHeight: 1,
      );
      expect(resolve(missing), isNull);
    });

    test('a member that will not decode resolves to null rather than '
        'throwing', () {
      final broken = planImageResolver(document, {
        _member: Uint8List.fromList([1, 2, 3, 4]),
      });
      expect(broken(_ref), isNull);
    });
  });

  group('one image per member', () {
    test('resolving twice returns the identical object', () {
      // A document with two plan sheets over one underlay must hold ONE
      // XObject, or `export_determinism_test.dart` compares a document
      // against itself plus a duplicate megabyte.
      expect(identical(resolve(_ref), resolve(_ref)), isTrue);
    });
  });

  group('no alpha reaches the document, over the REAL resolver', () {
    late Uint8List bytes;

    setUpAll(() async {
      final doc = pw.Document(compress: false);
      final images = planImageResolver(doc.document, {
        _member: _fourPixelPng(),
      });
      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(100, 50, marginAll: 0),
          build: (context) => pw.CustomPaint(
            size: const PdfPoint(100, 50),
            painter: (graphics, size) {
              PdfDiagramCanvas(
                  graphics: graphics,
                  boxHeight: size.y,
                  fonts: const {},
                  measurer: _NoText(),
                  images: images,
                )
                ..drawImage(_ref, const DBox.fromLtwh(0, 0, 100, 50))
                ..dispose();
            },
          ),
        ),
      );
      bytes = await doc.save();
    });

    test('no /SMask is written anywhere in the document', () {
      expect(String.fromCharCodes(bytes), isNot(contains('/SMask')));
    });

    test('no /ExtGState is written and no gs operator is emitted', () {
      final source = String.fromCharCodes(bytes);
      expect(source, isNot(contains('/ExtGState')));
      expect(source, isNot(matches(RegExp(r'\bgs\b'))));
    });

    test('the image IS in the document, so the assertions above are not '
        'vacuous', () {
      final source = String.fromCharCodes(bytes);
      expect(source, contains('/DeviceRGB'));
      expect(source, contains('/Image'));
    });
  });

  group('the size claim, measured rather than argued', () {
    test('a screened line-art plan deflates', () async {
      // "Already-compressed rasters do not deflate" is true of photographs
      // and false of line art, and DR-137 ruled that a floorplan IS line
      // art. dart_pdf has no embed-this-PNG path, so raw RGB is the only
      // door and `/FlateDecode` is what makes it affordable. This measures
      // that rather than asserting it.
      const w = 400;
      const h = 300;
      final plan = im.Image(width: w, height: h, numChannels: 4);
      im.fill(plan, color: im.ColorRgba8(255, 255, 255, 255));
      // A few walls, which is what an architect's page mostly is.
      im.drawLine(
        plan,
        x1: 10,
        y1: 10,
        x2: 390,
        y2: 10,
        color: im.ColorRgba8(0, 0, 0, 255),
      );
      im.drawLine(
        plan,
        x1: 10,
        y1: 10,
        x2: 10,
        y2: 290,
        color: im.ColorRgba8(0, 0, 0, 255),
      );
      im.drawLine(
        plan,
        x1: 200,
        y1: 10,
        x2: 200,
        y2: 290,
        color: im.ColorRgba8(0, 0, 0, 255),
      );

      final doc = pw.Document();
      final images = planImageResolver(doc.document, {
        _member: Uint8List.fromList(im.encodePng(plan)),
      });
      const ref = ImageRef(
        member: _member,
        format: ImageFormat.png,
        pixelWidth: w,
        pixelHeight: h,
      );
      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(400, 300, marginAll: 0),
          build: (context) => pw.CustomPaint(
            size: const PdfPoint(400, 300),
            painter: (graphics, size) {
              PdfDiagramCanvas(
                  graphics: graphics,
                  boxHeight: size.y,
                  fonts: const {},
                  measurer: _NoText(),
                  images: images,
                )
                ..drawImage(ref, const DBox.fromLtwh(0, 0, 400, 300))
                ..dispose();
            },
          ),
        ),
      );
      final bytes = await doc.save();

      const raw = w * h * 3;
      expect(
        bytes.length,
        lessThan(raw ~/ 10),
        reason:
            'raw RGB is $raw bytes; deflate on screened line art should be '
            'an order of magnitude smaller. Actual: ${bytes.length}',
      );
    });
  });
}

/// A measurer for a canvas that draws no text.
final class _NoText implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) =>
      const TextMetrics(
        advanceWidth: 0,
        ascent: 0,
        descent: 0,
        capHeight: 0,
        xHeight: 0,
        lineHeight: 0,
      );
}
