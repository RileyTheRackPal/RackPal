// rackpal_core/src/draw/canvas.dart — pure Dart, imports only
// geometry/style/path/image_ref (+ text, for measureText/drawText's
// TextStyleSpec and TextMetrics). This is THE single declaration of
// `DiagramCanvas` in the corpus (docs/08-pdf-export.md §7.3, CR-086);
// docs/03-architecture.md §8.1 cross-references it rather than restating
// it, and this file must not gain a method beyond the ones below without
// an amendment.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE METHOD HAS BEEN ADDED UNDER THAT CLAUSE: `drawImage`.
// ═══════════════════════════════════════════════════════════════════════
// The amendment is DR-029 §11.28.6, which ships the Plan view in v1. Its
// `T1.01 Device Location Plan` prints a screened floorplan underlay, so
// the exported document is no longer 100% vector; DR-030's title-block
// logo is the second consumer. docs/08 §7.3 records the same amendment on
// the document side and docs/15 §7 is the design.
//
// THE CLAUSE IS NOT WEAKENED BY HAVING BEEN USED. It cost a user ruling,
// a canon subsection and edits in three documents to add one method, which
// is the price it exists to charge. The next method costs the same.
//
// WHAT DID NOT COME WITH IT, because the obvious reading of "images" would
// have brought both: no `opacity` parameter and no `ImageRef` decoding.
// docs/08 row 9 forbids alpha "absolutely, with no exception", and an
// opacity argument here is an `/ExtGState` in the PDF backend by the
// shortest possible route. The underlay's screening happens where the
// `PdfImage` is built, in the export backend (DR-037 §11.36.3), and the
// stored bytes stay the architect's page.
//
// Adaptation from the doc's verbatim signatures: every `Pt`/`Box` in the
// quoted interface is this package's double-precision `DPt`/`DBox`
// (`geometry.dart`), NOT the model's integer grid `Pt`/`Box` — see
// `geometry.dart`'s file header for why the names differ.

import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/image_ref.dart';
import 'package:rackpal_core/src/draw/path.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:vector_math/vector_math_64.dart';

/// The single drawing IR both the screen and PDF backends replay
/// (CR-086). No `RendererCaps` (CR-088) — the interface is the common
/// denominator: flat fills, strokes, dashes, text, and one raster op for
/// a referenced image.
///
/// `drawImage`/`ImageRef` are in the v1 interface as of DR-029 §11.28.6,
/// and this comment said the opposite until 2026-09-07 (*"No
/// `drawImage`/`ImageRef` in v1 (RJ-017 defers the title-block logo to
/// v2)"*). RJ-017 is superseded in part by DR-029 and DR-030 (canon
/// §12.32); everything else it accepted is untouched, and **the logo's
/// opacity does not come back with it**.
///
/// The restriction that has NOT moved is the one CR-088 is actually about:
/// no gradients, no shadows, no blurs, no blend modes, no shaders. A
/// raster is none of those. It is the one thing in this interface the two
/// backends cannot compute identically from the same arguments, which is
/// why it carries a REFERENCE and each backend resolves it (see
/// `image_ref.dart`).
abstract interface class DiagramCanvas {
  // ── state stack ──────────────────────────────────────────────────────
  void save();
  void restore();
  int get saveCount;

  // ── transform (all CONCATENATE onto the current CTM) ─────────────────
  void translate(double dx, double dy);
  void scale(double sx, [double? sy]);

  /// Positive = clockwise.
  void rotate(double radians);
  void transform(Matrix4 m);

  /// For `hairlineFloor` + hit-test.
  Matrix4 get currentTransform;

  // ── clip (intersective; undone only by restore()) ────────────────────
  void clipRect(DBox r);
  void clipPath(DiagramPath p, {FillRule rule = FillRule.nonZero});

  // ── primitives ────────────────────────────────────────────────────────
  void drawLine(DPt a, DPt b, Stroke s);
  void drawPolyline(List<DPt> pts, Stroke s, {bool close = false});
  void drawPath(DiagramPath p, {Fill? fill, Stroke? stroke});
  void drawRect(DBox r, {Fill? fill, Stroke? stroke});
  void drawRoundRect(DBox r, Radii radii, {Fill? fill, Stroke? stroke});
  void drawCircle(DPt c, double radius, {Fill? fill, Stroke? stroke});
  void drawEllipse(DPt c, double rx, double ry, {Fill? fill, Stroke? stroke});
  void drawText(String text, DPt at, TextStyleSpec style);

  /// Draws [image] to fill [dst] exactly, top-left to top-left.
  ///
  /// **No opacity and no fit rule.** Opacity would be an `/ExtGState` in
  /// the PDF (docs/08 row 9), and fitting is the caller's arithmetic:
  /// `ImageRef.aspectRatio` is on the handle precisely so a scene builder
  /// can choose a [dst] that does not stretch the picture (DR-030's fit
  /// rule), rather than have this method silently letterbox it and leave
  /// the caller unable to say where the ink actually landed.
  ///
  /// The reference is resolved by the backend, never here: `rackpal_core`
  /// has no image decoder and must not gain one.
  void drawImage(ImageRef image, DBox dst);

  // ── measurement — identical on every backend by construction (§7.5) ──
  TextMetrics measureText(String text, TextStyleSpec style);
}
