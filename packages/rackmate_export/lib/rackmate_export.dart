/// `PdfDiagramCanvas`, sheet furniture, schedule tables and document assembly.
///
/// M1 adds the PDF backend of the shared drawing IR (docs/08-pdf-export.md
/// §7.7, CR-086): `PdfDiagramCanvas` and a reference page-wiring helper.
///
/// The sheet-frame stage adds the ANSI page formats §6.1 says
/// `PdfPageFormat` is missing, and `buildSheetPage` — the one wiring that
/// turns a composed `DiagramScene` into a full-page PDF page. Everything
/// else about a sheet (margins, border, title block, revision block, the
/// drawing scale) is PURE CORE, under `rackmate_core/draw/sheet/`, because
/// `rackmate_ui` must be able to replay the identical scene for the
/// on-screen preview and may not import this package (docs/03 §7.1).
/// Schedule tables and full document assembly land with the sheets
/// themselves.
library;

export 'src/document/build_document.dart';
export 'src/document/export_request.dart';
export 'src/draw/page_wiring.dart';
export 'src/draw/pdf_canvas.dart';
export 'src/sheets/page_sizes.dart';
export 'src/sheets/sheet_page.dart';
