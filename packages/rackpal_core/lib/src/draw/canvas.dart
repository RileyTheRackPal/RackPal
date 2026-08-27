// rackpal_core/src/draw/canvas.dart — pure Dart, imports only
// geometry/style/path (+ text, for measureText/drawText's TextStyleSpec
// and TextMetrics). This is THE single declaration of `DiagramCanvas` in
// the corpus (docs/08-pdf-export.md §7.3, CR-086); docs/03-architecture.md
// §8.1 cross-references it rather than restating it, and this file must
// not gain a method beyond the ones below without an amendment.
//
// Adaptation from the doc's verbatim signatures: every `Pt`/`Box` in the
// quoted interface is this package's double-precision `DPt`/`DBox`
// (`geometry.dart`), NOT the model's integer grid `Pt`/`Box` — see
// `geometry.dart`'s file header for why the names differ.

import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/path.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:vector_math/vector_math_64.dart';

/// The single drawing IR both the screen and PDF backends replay
/// (CR-086). No `drawImage`/`ImageRef` in v1 (RJ-017 defers the
/// title-block logo to v2) and no `RendererCaps` (CR-088) — the interface
/// is the common denominator: flat fills, strokes, dashes and text only.
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

  // ── measurement — identical on every backend by construction (§7.5) ──
  TextMetrics measureText(String text, TextStyleSpec style);
}
