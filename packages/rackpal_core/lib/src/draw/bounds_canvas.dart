// rackpal_core/src/draw/bounds_canvas.dart — pure Dart.
//
// `BoundsCanvas` (CR-089, docs/03-architecture.md §7.2/§8.3, docs/08-pdf-
// export.md §7.9): the third `DiagramCanvas` backend. It draws nothing and
// accumulates the diagram's TRUE INK EXTENT — the value scale-to-fit,
// zoom-to-fit and the elevation tile count all need, and which the docs say
// "there is no other way to get".
//
// WHY IT IS A CANVAS AND NOT A SWITCH OVER `DiagramOp`: a bounds pass that
// walks the op list re-implements the transform stack, the clip stack and
// the text-anchor resolution that the two real backends already agree on
// through `DiagramCanvas`. A third implementation of those is a third
// chance to disagree — exactly what CR-086 exists to prevent. This one
// replays through the SAME interface, so a `DiagramScene` whose ops a
// backend can draw is a scene this can measure, by construction.
//
// WHAT "INK" MEANS HERE, stated precisely because a bounding box that is
// wrong in the tight direction clips a drawing:
//   * A stroked shape contributes its geometry inflated by HALF the stroke
//     width, because that is where the ink actually lands.
//   * Text contributes `advanceWidth × (ascent + descent)` positioned
//     through the SHARED [anchorOffset], so a `TextAnchor.bottomCenter`
//     label above a pin is measured where the backend will actually put it.
//   * Cubic segments contribute `DiagramPath.bounds`, which is a
//     conservative superset (control points, not curve extrema) — that
//     file's own note says this is the bound `BoundsCanvas` wants.
//   * Clips are honoured intersectively, so ink a `clipRect` removes is not
//     counted.
// The one deliberate approximation: a `Stroke` is inflated in LOCAL space
// before the CTM is applied, so under a non-uniform scale the inflation
// scales with the geometry. That is exactly right for
// `Stroke.scaleWithGeometry` (the default) and conservative for the
// hairline case, and every transform in the scene builders is a
// translation, where the two are identical.

import 'dart:math' as math;

import 'package:rackpal_core/src/draw/canvas.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/path.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:vector_math/vector_math_64.dart';

/// The ink extent of [ops], or `null` when they draw nothing at all.
///
/// The convenience wrapper every scene layer uses: build the ops, replay
/// them through a [BoundsCanvas], take the box. [measurer] must be the SAME
/// measurer the layer built its text with (CR-081) — measuring a label with
/// a different font is measuring a different label.
DBox? inkBoundsOf(Iterable<DiagramOp> ops, {required TextMeasurer measurer}) {
  final canvas = BoundsCanvas(measurer: measurer);
  for (final op in ops) {
    op.replay(canvas);
  }
  return canvas.bounds;
}

/// A [DiagramCanvas] that accumulates ink extent instead of painting.
final class BoundsCanvas implements DiagramCanvas {
  BoundsCanvas({required this.measurer});

  /// The measurer text extents come from — the SAME injected one the layer
  /// built its text with (CR-081).
  final TextMeasurer measurer;

  /// The transform + clip stack. Index 0 is the base state, which
  /// [restore] never pops (an unbalanced restore is the caller's bug, and
  /// throwing here would turn a cosmetic defect into a crash in an export).
  final List<_GraphicsState> _stack = [
    _GraphicsState(Matrix4.identity(), null),
  ];

  DBox? _bounds;

  /// The union of everything drawn so far, in the canvas's own root
  /// coordinate space — `null` if nothing has been drawn, which is the
  /// honest answer for an empty layer and is NOT the same as an empty box
  /// at the origin.
  DBox? get bounds => _bounds;

  _GraphicsState get _state => _stack.last;

  // ── state stack ──────────────────────────────────────────────────────

  @override
  int get saveCount => _stack.length;

  @override
  void save() => _stack.add(_state.copy());

  @override
  void restore() {
    if (_stack.length > 1) _stack.removeLast();
  }

  // ── transform ────────────────────────────────────────────────────────

  @override
  Matrix4 get currentTransform => _state.ctm.clone();

  @override
  void transform(Matrix4 m) => _state.ctm.multiply(m);

  @override
  void translate(double dx, double dy) =>
      _state.ctm.multiply(Matrix4.translationValues(dx, dy, 0));

  @override
  void scale(double sx, [double? sy]) =>
      _state.ctm.multiply(Matrix4.diagonal3Values(sx, sy ?? sx, 1));

  @override
  void rotate(double radians) =>
      _state.ctm.multiply(Matrix4.rotationZ(radians));

  // ── clip ─────────────────────────────────────────────────────────────

  @override
  void clipRect(DBox r) => _clip(_toRoot(r));

  @override
  void clipPath(DiagramPath p, {FillRule rule = FillRule.nonZero}) {
    if (p.commands.isEmpty) return;
    _clip(_toRoot(p.bounds));
  }

  // ── primitives ───────────────────────────────────────────────────────

  @override
  void drawLine(DPt a, DPt b, Stroke s) =>
      _ink(DBox.fromCorners(a, b).inflate(s.widthPt / 2));

  @override
  void drawPolyline(List<DPt> pts, Stroke s, {bool close = false}) {
    if (pts.isEmpty) return;
    _ink(_hull(pts).inflate(s.widthPt / 2));
  }

  @override
  void drawPath(DiagramPath p, {Fill? fill, Stroke? stroke}) {
    if (p.commands.isEmpty) return;
    _ink(_paint(p.bounds, fill, stroke));
  }

  @override
  void drawRect(DBox r, {Fill? fill, Stroke? stroke}) =>
      _ink(_paint(r, fill, stroke));

  @override
  void drawRoundRect(DBox r, Radii radii, {Fill? fill, Stroke? stroke}) =>
      _ink(_paint(r, fill, stroke));

  @override
  void drawCircle(DPt c, double radius, {Fill? fill, Stroke? stroke}) => _ink(
    _paint(
      DBox.fromLtwh(c.x - radius, c.y - radius, 2 * radius, 2 * radius),
      fill,
      stroke,
    ),
  );

  @override
  void drawEllipse(DPt c, double rx, double ry, {Fill? fill, Stroke? stroke}) =>
      _ink(
        _paint(
          DBox.fromLtwh(c.x - rx, c.y - ry, 2 * rx, 2 * ry),
          fill,
          stroke,
        ),
      );

  @override
  void drawText(String text, DPt at, TextStyleSpec style) {
    if (text.isEmpty) return;
    final m = measurer.measureText(text, style);
    // `anchorOffset` returns the offset from the anchor point to the text
    // run's BASELINE origin — the same value both real backends use, so the
    // box measured here is the box that will be painted.
    final o = anchorOffset(style.anchor, m);
    final left = at.x + o.x;
    final baseline = at.y + o.y;
    final box = DBox.fromLtwh(
      left,
      baseline - m.ascent,
      m.advanceWidth,
      m.ascent + m.descent,
    );
    if (style.rotationRad == 0) {
      _ink(box);
      return;
    }
    // Rotation happens about the ANCHOR point in both backends
    // (`PdfDiagramCanvas.drawText` sets the local frame's origin to `at`
    // before rotating), so the rotated hull is taken about `at` too.
    final cos = math.cos(style.rotationRad);
    final sin = math.sin(style.rotationRad);
    DPt spin(double x, double y) {
      final dx = x - at.x;
      final dy = y - at.y;
      return DPt(at.x + dx * cos - dy * sin, at.y + dx * sin + dy * cos);
    }

    _ink(
      _hull([
        spin(box.left, box.top),
        spin(box.right, box.top),
        spin(box.right, box.bottom),
        spin(box.left, box.bottom),
      ]),
    );
  }

  // ── measurement ──────────────────────────────────────────────────────

  @override
  TextMetrics measureText(String text, TextStyleSpec style) =>
      measurer.measureText(text, style);

  // ── internals ────────────────────────────────────────────────────────

  /// [local] grown by half the stroke width when it is stroked. An unpainted
  /// shape (neither fill nor stroke) still contributes its geometry: the
  /// backends treat that as a no-op, but counting it can only make the box
  /// larger, never clip real ink.
  DBox _paint(DBox local, Fill? fill, Stroke? stroke) =>
      stroke == null ? local : local.inflate(stroke.widthPt / 2);

  /// Folds one LOCAL-space box into [bounds] — transformed by the CTM and
  /// intersected with the active clip.
  void _ink(DBox local) {
    final box = _toRoot(local);
    final clip = _state.clip;
    final visible = clip == null ? box : _intersect(box, clip);
    if (visible == null) return;
    _bounds = _bounds == null ? visible : _bounds!.union(visible);
  }

  /// [local] mapped through the CTM. All four corners are mapped, not just
  /// two, so a rotation is handled correctly (an axis-aligned box under a
  /// rotation is not an axis-aligned box).
  DBox _toRoot(DBox local) {
    final m = _state.ctm;
    return _hull([
      _apply(m, local.left, local.top),
      _apply(m, local.right, local.top),
      _apply(m, local.right, local.bottom),
      _apply(m, local.left, local.bottom),
    ]);
  }

  void _clip(DBox rootBox) {
    final current = _state.clip;
    _state.clip = current == null ? rootBox : _intersect(rootBox, current);
    // A fully-degenerate intersection is expressed as an empty box rather
    // than null, because null already means "no clip at all".
    _state.clip ??= const DBox.fromLtwh(0, 0, 0, 0);
  }
}

DPt _apply(Matrix4 m, double x, double y) {
  final v = m.transform3(Vector3(x, y, 0));
  return DPt(v.x, v.y);
}

DBox _hull(List<DPt> pts) {
  var box = DBox.fromCorners(pts.first, pts.first);
  for (final p in pts.skip(1)) {
    box = box.union(DBox.fromCorners(p, p));
  }
  return box;
}

DBox? _intersect(DBox a, DBox b) {
  final left = math.max(a.left, b.left);
  final top = math.max(a.top, b.top);
  final right = math.min(a.right, b.right);
  final bottom = math.min(a.bottom, b.bottom);
  if (right < left || bottom < top) return null;
  return DBox.fromLtwh(left, top, right - left, bottom - top);
}

final class _GraphicsState {
  _GraphicsState(this.ctm, this.clip);

  Matrix4 ctm;
  DBox? clip;

  _GraphicsState copy() => _GraphicsState(ctm.clone(), clip);
}
