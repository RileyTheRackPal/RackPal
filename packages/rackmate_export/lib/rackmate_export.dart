/// `PdfDiagramCanvas`, sheet furniture, schedule tables and document assembly.
///
/// M1 adds the PDF backend of the shared drawing IR (docs/08-pdf-export.md
/// §7.7, CR-086): `PdfDiagramCanvas` and a reference page-wiring helper.
/// Sheet furniture, schedule tables and full document assembly land with
/// the rest of the M1/M6 PDF export work.
library;

export 'src/draw/page_wiring.dart';
export 'src/draw/pdf_canvas.dart';
