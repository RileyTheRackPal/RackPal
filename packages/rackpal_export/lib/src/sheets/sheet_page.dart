// rackpal_export/lib/src/sheets/sheet_page.dart -- the ONE way a composed
// sheet scene becomes a PDF page.
//
// The governing shape (docs/08-pdf-export.md §5, §7.4, §7.7): every page is
// a plain `pw.Page` whose entire content is one `pw.FullPage` wrapping one
// `pw.CustomPaint`, which replays one `DiagramScene` -- furniture AND
// content -- through one `PdfDiagramCanvas`. dart_pdf is used as a byte
// writer and a TrueType embedder; not one mark on the sheet comes from a
// `pw.Text` or a `pw.Table`.
//
// WHY `FullPage(ignoreMargins: true)` MAKES §7.4's GOTCHA GO AWAY. §7.4
// warns, normatively, that `pw.CustomPaint` pre-translates the canvas to
// the WIDGET BOX's bottom-left before calling the painter, so the height
// flipped about must be `size.y` -- the widget's height -- and NOT the page
// height. Verified in pdf 3.13.0: `CustomPaint.paint` translates by
// `box.left, box.bottom` and passes `box.size`. Under
// `FullPage(ignoreMargins: true)` the box IS the page (0, 0, W, H), so
// `size.y == pageHeight` and the two coincide. `boxHeight: size.y` is still
// what is passed -- the correct expression, not the coincidence -- so this
// stays right if the wrapper ever changes.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/src/draw/pdf_canvas.dart';
import 'package:rackpal_export/src/sheets/page_sizes.dart';

/// Builds the `pw.Page` for one sheet: [size] of paper carrying [scene].
///
/// [scene] is expected to be in PAGE coordinates (top-left origin, Y down)
/// -- i.e. composed against `SheetGeometry(size)` -- because the canvas
/// flips about the full page height.
pw.Page buildSheetPage({
  required SheetSize size,
  required DiagramScene scene,
  required Map<FontRef, PdfFont> fonts,
  required TextMeasurer measurer,
}) {
  final format = pdfPageFormatFor(size);
  return pw.Page(
    pageTheme: pw.PageTheme(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
    ),
    build: (context) => pw.FullPage(
      ignoreMargins: true,
      child: pw.CustomPaint(
        size: PdfPoint(format.width, format.height),
        painter: (PdfGraphics graphics, PdfPoint boxSize) {
          final canvas = PdfDiagramCanvas(
            graphics: graphics,
            boxHeight: boxSize.y, // size.y, NOT page height -- §7.4
            fonts: fonts,
            measurer: measurer,
          );
          scene.replay(canvas);
          canvas.dispose();
        },
      ),
    ),
  );
}
