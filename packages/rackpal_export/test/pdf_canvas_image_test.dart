// `PdfDiagramCanvas.drawImage`, ON THE PAGE (PLAN-A/3).
//
// ─────────────────────────────────────────────────────────────────────────
// A MIRRORED FLOORPLAN HAS A CORRECT BOUNDING BOX
// ─────────────────────────────────────────────────────────────────────────
// This is the whole reason this file reads corners rather than a rect. A
// PDF image XObject occupies the unit square with its TOP row at `v = 1`,
// and `PdfDiagramCanvas` pushes one global Y-flip at construction
// (CR-085). Drawn without a counter-flip the picture lands upside down in
// exactly the same box, every dimensional assertion still passes, and the
// failure is discovered by somebody standing in the wrong room at seven in
// the morning. So `RecoveredImage` records the image's own four corners in
// user space and the assertions below are about which of them is high.
//
// The second property is docs/08 row 9's, which forbids alpha in the
// document "absolutely, with no exception". `PdfImage(..., alpha: true)`
// writes an `/SMask` with nobody calling `setGraphicState`, which is not
// the failure row 9 was written about and which row 9 forbids anyway. The
// resolver is where that is decided, so the assertion is over the SAVED
// BYTES: no `/SMask` anywhere, no `/ExtGState`, no `gs` operator.

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

/// The painter's box, and so the whole page: zero margins, so user space
/// is absolute and every expectation below is arithmetic on the literals.
const double _boxW = 200;
const double _boxH = 100;

/// Two pixels wide, three tall, so a transposition is visible as well as a
/// flip. Raw RGB, three bytes per pixel, which is what `alpha: false`
/// wants.
const int _pxW = 2;
const int _pxH = 3;

const ImageRef _ref = ImageRef(
  member: 'underlays/level-1.png',
  format: ImageFormat.png,
  pixelWidth: _pxW,
  pixelHeight: _pxH,
);

/// Top-left in diagram space, Y down. Deliberately NOT square and NOT
/// centred, so a flip about either axis moves a corner.
const DBox _dst = DBox.fromLtwh(20, 10, 120, 60);

/// Diagram Y (top-left origin, Y down) as PDF user-space Y (Y up).
double _userY(double diagramY) => _boxH - diagramY;

Uint8List _rgb() => Uint8List.fromList(List<int>.filled(_pxW * _pxH * 3, 0x40));

/// Builds a one-page document whose painter draws one image through the
/// real canvas, with [resolver] deciding what it resolves to.
Future<Uint8List> _render(
  PdfImageResolver? Function(PdfDocument doc) resolver,
) async {
  final doc = pw.Document(compress: false);
  final made = resolver(doc.document);
  doc.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(_boxW, _boxH, marginAll: 0),
      build: (context) => pw.CustomPaint(
        size: const PdfPoint(_boxW, _boxH),
        painter: (PdfGraphics graphics, PdfPoint size) {
          PdfDiagramCanvas(
              graphics: graphics,
              boxHeight: size.y, // size.y, NOT page height -- §7.4
              fonts: const {},
              measurer: const _ZeroMeasurer(),
              images: made,
            )
            ..drawImage(_ref, _dst)
            ..dispose();
        },
      ),
    ),
  );
  return Uint8List.fromList(await doc.save());
}

void main() {
  late Uint8List pdfBytes;
  late RecoveredStream page;

  setUpAll(() async {
    pdfBytes = await _render(
      (doc) =>
          (ref) => PdfImage(
            doc,
            image: _rgb(),
            width: _pxW,
            height: _pxH,
            alpha: false, // row 9: no /SMask, ever
          ),
    );
    page = interpretContentStream(
      extractOperatorStream(pdfBytes, mustContain: ' Do'),
    );
  });

  group('the recovery found the page it is about', () {
    test('the document saved and carries exactly one painted XObject', () {
      expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');
      expect(page.images, hasLength(1));
      expect(page.images.single.name, isNotEmpty);
    });
  });

  group('the image lands the right way up, which a box cannot tell you', () {
    test("the image's OWN top edge is the destination's top edge", () {
      final img = page.images.single;
      // Diagram top 10 is user-space y 90; diagram bottom 70 is y 30.
      expect(img.topLeft.$2, closeTo(_userY(10), 1e-9));
      expect(img.bottomLeft.$2, closeTo(_userY(70), 1e-9));
      // Stated a second way, so a reader does not have to do the
      // arithmetic to see the property: the top is ABOVE the bottom.
      expect(img.topLeft.$2, greaterThan(img.bottomLeft.$2));
    });

    test('all four corners land where the destination rect says', () {
      final img = page.images.single;
      expect(img.topLeft.$1, closeTo(20, 1e-9));
      expect(img.topRight.$1, closeTo(140, 1e-9));
      expect(img.topRight.$2, closeTo(_userY(10), 1e-9));
      expect(img.bottomRight.$1, closeTo(140, 1e-9));
      expect(img.bottomRight.$2, closeTo(_userY(70), 1e-9));
    });

    test('it is not mirrored left-to-right either', () {
      final img = page.images.single;
      expect(img.topRight.$1, greaterThan(img.topLeft.$1));
    });

    test('it fills the destination exactly: 120 x 60 points', () {
      final img = page.images.single;
      expect(img.topRight.$1 - img.topLeft.$1, closeTo(120, 1e-9));
      expect(img.topLeft.$2 - img.bottomLeft.$2, closeTo(60, 1e-9));
    });
  });

  group('docs/08 row 9 holds over the saved bytes', () {
    test('no /SMask is written anywhere in the document', () {
      expect(String.fromCharCodes(pdfBytes), isNot(contains('/SMask')));
    });

    test('no /ExtGState is written and no gs operator is emitted', () {
      final source = String.fromCharCodes(pdfBytes);
      expect(source, isNot(contains('/ExtGState')));
      expect(
        extractOperatorStream(pdfBytes, mustContain: ' Do'),
        isNot(contains(' gs')),
      );
    });
  });

  group('a reference nobody can resolve is an error, not a blank page', () {
    test('a canvas with no resolver throws MissingImageError', () async {
      await expectLater(
        _render((doc) => null),
        throwsA(isA<MissingImageError>()),
      );
    });

    test('a resolver that returns null for this member throws too', () async {
      await expectLater(
        _render(
          (doc) =>
              (ref) => null,
        ),
        throwsA(isA<MissingImageError>()),
      );
    });
  });
}

/// Text plays no part here; this exists so the canvas has the collaborator
/// its constructor requires.
final class _ZeroMeasurer implements TextMeasurer {
  const _ZeroMeasurer();

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
