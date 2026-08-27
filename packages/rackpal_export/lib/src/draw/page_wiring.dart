// rackpal_export/lib/src/draw/page_wiring.dart -- reference wiring only
// (docs/08-pdf-export.md §7.7 "Wiring it to a page"). Nothing in this
// stage calls this function; it is recorded here so a later stage
// assembling the real export document does not have to rediscover the ONE
// call shape that avoids §7.4's gotcha:
//
//   boxHeight MUST be pw.CustomPaint's size.y -- the WIDGET's height --
//   NOT the page height. Getting it wrong offsets every diagram vertically
//   by the page margin, and the result looks plausible enough to ship.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/src/draw/pdf_canvas.dart';

/// Builds one [pw.Page] that replays [scene] through a fresh
/// [PdfDiagramCanvas].
///
/// This is the canonical call shape, not a general-purpose API: a real
/// sheet-export stage also needs `pageTheme` (border + title block, §5),
/// multi-sheet pagination, and per-sheet scale-to-fit, none of which are
/// this stage's job. Kept here mainly so `boxHeight: size.y` is never
/// re-derived incorrectly from scratch.
pw.Page buildDiagramScenePage({
  required double usableWidth,
  required double usableHeight,
  required DiagramScene scene,
  required Map<FontRef, PdfFont> fonts,
  required TextMeasurer measurer,
  pw.PageTheme? pageTheme,
}) {
  return pw.Page(
    pageTheme: pageTheme,
    build: (context) => pw.CustomPaint(
      size: PdfPoint(usableWidth, usableHeight),
      painter: (PdfGraphics graphics, PdfPoint size) {
        final canvas = PdfDiagramCanvas(
          graphics: graphics,
          boxHeight: size.y, // size.y, NOT page height -- see file header
          fonts: fonts,
          measurer: measurer,
        );
        scene.replay(canvas);
        canvas.dispose();
      },
    ),
  );
}
