// `apps/rackpal/src/session/pdf_rasteriser.dart` — the seam between the
// import flow and the vendored pdfium (DR-153 §11.152.4, `PLAN-K/4`).
//
// ═══════════════════════════════════════════════════════════════════════
// A SEAM, BECAUSE THE FLOW MUST BE TESTABLE WITHOUT THE BINARY
// ═══════════════════════════════════════════════════════════════════════
// The sequence a page takes through the importer is ordinary Dart and its
// cases should not need a DLL, a real PDF or a hundred milliseconds of
// rendering to run. So the flow takes a [PdfRasteriser] and the app hands
// it [pdfiumRenderPng].
//
// **AND THE REAL ONE IS STILL EXERCISED.** A fake that agrees with the
// flow proves the flow and nothing about pdfium, which is why
// `plan_import_pdfium_test.dart` runs the real path end to end on a real
// vector PDF. Both halves are needed: this repository has been caught
// once by a parser whose thirty-one synthetic cases all passed and which
// refused every page of the first real file it met.
//
// ═══════════════════════════════════════════════════════════════════════
// IT RETURNS PNG BYTES RATHER THAN PIXELS
// ═══════════════════════════════════════════════════════════════════════
// Everything downstream of the importer speaks in encoded bytes:
// `importFloorplanBytes` sniffs, reads a header, decodes, and re-checks
// the decode against what the header claimed. Handing it raw pixels would
// mean either a second import path with none of those checks, or a
// container member in a format nothing else in this product reads.
//
// So the encode belongs here, and the PNG is what DR-153 §11.152.5 rules:
// line art deflates, and a JPEG of line art rings around every wall.
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_pdfium/rackpal_pdfium.dart';

/// Renders page [pageIndex] of [pdf] at exactly [width] by [height]
/// pixels, encoded as a PNG.
///
/// A FUNCTION AND NOT AN INTERFACE, on `PdfImageResolver`'s precedent and
/// the ruling's own words: the importer calls it through an injected
/// function. A fake is a closure, which is what makes the flow's cases
/// ordinary Dart.
///
/// Never returns a throw for anything about the FILE (CR-093).
/// [PdfiumUnavailable] may still be thrown, because a missing binary is a
/// fact about the installation rather than about the document.
typedef PdfRasteriser =
    Outcome<Uint8List> Function(
      Uint8List pdf,
      int pageIndex, {
      required int width,
      required int height,
    });

/// The real one, over the vendored binary.
Outcome<Uint8List> pdfiumRenderPng(
  Uint8List pdf,
  int pageIndex, {
  required int width,
  required int height,
}) {
  final opened = PdfiumDocument.open(pdf);
  if (opened case Err(:final error)) return Err(error);
  final document = (opened as Ok<PdfiumDocument>).value;

  // THE DOCUMENT IS CLOSED WHETHER OR NOT THE RENDER WORKED, and it holds
  // native memory nothing else will reclaim: a leak here is a copy of the
  // whole PDF per attempt.
  try {
    final rendered = document.render(pageIndex, width: width, height: height);
    if (rendered case Err(:final error)) return Err(error);
    final raster = (rendered as Ok<PdfiumRaster>).value;

    // `ChannelOrder.bgr` RATHER THAN A SWAP LOOP. pdfium writes blue
    // first and the encoder is told so, which is one less pass over fifty
    // megabytes and one less place to get a channel order wrong.
    final image = img.Image.fromBytes(
      width: raster.width,
      height: raster.height,
      bytes: raster.bgr.buffer,
      numChannels: 3,
      order: img.ChannelOrder.bgr,
    );
    return Ok(img.encodePng(image));
  } finally {
    document.close();
  }
}
