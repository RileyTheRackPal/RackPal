// rackpal_core/src/persistence/pdf_page_option.dart — what the page
// picker is offered, now that a page can arrive two ways (DR-153,
// `PLAN-K/4`).
//
// IT LIVES IN CORE BECAUSE THE DIALOG IS IN `rackpal_ui`, which may not
// depend on the app. The type is pure Dart over `LiftedPdfPage` and
// `PlanRasterPlan`, both of which are here already; the RASTERISER that
// fills a rendered one is in the app, where the native dependency is.
//
// ═══════════════════════════════════════════════════════════════════════
// TWO WAYS IN, AND THE PICKER SHOULD NOT CARE WHICH
// ═══════════════════════════════════════════════════════════════════════
// A page that is one full-page image is LIFTED, byte for byte as the
// architect's office exported it, and DR-138 §11.137.3 is emphatic that
// this is better than rendering rather than merely cheaper: rasterising a
// page whose only content is a JPEG decodes and re-encodes it, losing a
// generation and gaining no pixel.
//
// A page of vectors has no image to lift and is RENDERED. Until `PLAN-K`
// it was refused, and the refusal was the whole of DR-145's finding.
//
// The person choosing a page is choosing a drawing. What the tile needs
// is a picture, a number of pixels and a resolution, and both kinds can
// answer all three, so the difference lives here and not in the dialog.
//
// ═══════════════════════════════════════════════════════════════════════
// A RENDERED OPTION CARRIES A PREVIEW AND A PLAN, WHICH ARE DIFFERENT
// SIZES ON PURPOSE
// ═══════════════════════════════════════════════════════════════════════
// The grid shows thumbnails. Rendering eighteen ARCH D pages at 300 dpi
// to fill it would be four hundred megapixels of work to draw eighteen
// pictures 320 pixels wide, so the preview is rendered small and the
// chosen page is rendered again at [PdfPageOption.resultWidth].
//
// **THE CAPTION REPORTS THE PLAN AND NOT THE PREVIEW.** A tile saying
// "320 x 207, 19 dpi" would be describing the thumbnail it just drew,
// which is not a fact about anything the person is choosing.
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/persistence/pdf_page_lift.dart';
import 'package:rackpal_core/src/persistence/pdf_raster_plan.dart';

/// One page of a PDF, as the picker offers it.
@immutable
sealed class PdfPageOption {
  const PdfPageOption();

  /// Zero-based, in the document's own page order.
  int get pageIndex;

  /// Bytes the tile can decode to show the page.
  Uint8List get previewBytes;

  /// The pixels the underlay will actually have if this page is chosen.
  int get resultWidth;
  int get resultHeight;

  /// Effective resolution over the sheet, or null when the page has no
  /// usable size. **The number DR-137 §11.136.4 made meaningful**: it is
  /// what a person wondering why a 36 inch sheet looks soft is owed.
  double? get resultDpi;
}

/// A page that was one full-page image, taken whole (DR-138).
@immutable
final class LiftedPageOption extends PdfPageOption {
  const LiftedPageOption(this.page);

  final LiftedPdfPage page;

  @override
  int get pageIndex => page.pageIndex;

  @override
  Uint8List get previewBytes => page.bytes;

  @override
  int get resultWidth => page.header.pixelWidth;

  @override
  int get resultHeight => page.header.pixelHeight;

  @override
  double? get resultDpi => page.effectiveDpi;
}

/// A page of vectors, which pdfium can draw (DR-153).
@immutable
final class RenderedPageOption extends PdfPageOption {
  const RenderedPageOption({
    required this.pageIndex,
    required this.plan,
    required this.previewBytes,
  });

  @override
  final int pageIndex;

  /// The size the page will be rendered at when it is chosen, from
  /// `planRasterFor` (DR-153 §11.152.5).
  final PlanRasterPlan plan;

  @override
  final Uint8List previewBytes;

  @override
  int get resultWidth => plan.width;

  @override
  int get resultHeight => plan.height;

  @override
  double? get resultDpi => plan.effectiveDpi;
}
