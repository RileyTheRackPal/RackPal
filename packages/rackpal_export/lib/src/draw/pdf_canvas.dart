// rackpal_export/lib/src/draw/pdf_canvas.dart -- PURE DART. Isolate-safe.
// No Flutter. Transcribed from docs/08-pdf-export.md §7.7's verbatim
// `PdfDiagramCanvas` listing, with the REQUIRED adaptations to the real
// installed pdf 3.13.0 / vector_math 2.2.0 APIs (spiked directly -- see
// this stage's task brief), plus the methods §7.7 elided entirely
// (drawPolyline, drawCircle, drawEllipse, drawPath, clipRect, clipPath,
// translate, scale) -- those follow the exact same
// save/restore + `_applyFill`/`_applyStroke` idiom the doc shows for
// `drawRect`.
//
// ADAPTATION NOTE ("Pt"/"Box" -> `DPt`/`DBox`): the doc's quoted signatures
// use "Pt"/"Box" for the diagram-space double point/box. This codebase's
// actual names (chosen by the previous M1 stage,
// rackpal_core/src/draw/geometry.dart) are `DPt`/`DBox`, deliberately
// distinct from the model's integer grid `Pt`/`Box` (units/pt.dart,
// units/box.dart) -- see that file's header for why. Used throughout
// below; every other type name (`Stroke`, `Fill`, `Radii`, `DiagramPath`,
// `TextMeasurer`, `TextMetrics`, `TextStyleSpec`, `FontRef`,
// `anchorOffset`, `DiagramCanvas`) is unchanged from rackpal_core/draw/.
//
// ADAPTATION NOTE (`drawRoundRect`): §7.7 elides this method's body
// entirely. The real primitive it must call is the CONFIRMED
// `PdfGraphics.drawRRect(x, y, w, h, rv, rh)` -- note TWO SEPARATE radii
// (vertical, horizontal), not one `Radii` object -- so this file unpacks
// `radii.rv`/`radii.rh` at the call site.

import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// The PDF backend of [DiagramCanvas] (CR-086): replays a [DiagramScene]
/// onto a [PdfGraphics], with the one global Y-flip absorbed once at
/// construction (CR-085, docs/08-pdf-export.md §7.4).
final class PdfDiagramCanvas implements DiagramCanvas {
  PdfDiagramCanvas({
    required PdfGraphics graphics,
    required double boxHeight, // MUST be pw.CustomPaint's size.y -- §7.4
    required Map<FontRef, PdfFont> fonts,
    required TextMeasurer measurer,
  }) : _g = graphics,
       _fonts = fonts,
       _measurer = measurer {
    _g.saveContext();
    _g.setTransform(
      Matrix4.identity()
        ..setEntry(1, 3, boxHeight) // translate y
        ..setEntry(1, 1, -1.0), // scale y by -1 -> one global flip
    );
    _stack.add(Matrix4.identity());
  }

  final PdfGraphics _g;
  final Map<FontRef, PdfFont> _fonts;
  final TextMeasurer _measurer;
  final List<Matrix4> _stack = [];

  /// Balances the constructor's [PdfGraphics.saveContext]. Callers MUST
  /// invoke this once done replaying a scene through this canvas.
  void dispose() => _g.restoreContext();

  // ── state stack ──────────────────────────────────────────────────────

  @override
  void save() {
    _g.saveContext();
    _stack.add(_stack.last.clone());
  }

  @override
  void restore() {
    _g.restoreContext();
    _stack.removeLast();
  }

  @override
  int get saveCount => _stack.length - 1;

  // ── transform ─────────────────────────────────────────────────────────

  void _apply(Matrix4 m) {
    _g.setTransform(m);
    _stack.last.multiply(m);
  }

  @override
  void translate(double dx, double dy) =>
      _apply(Matrix4.translationValues(dx, dy, 0));

  @override
  void scale(double sx, [double? sy]) =>
      _apply(Matrix4.diagonal3Values(sx, sy ?? sx, 1));

  @override
  void rotate(double r) => _apply(Matrix4.rotationZ(r));

  @override
  void transform(Matrix4 m) => _apply(m);

  @override
  Matrix4 get currentTransform => _stack.last.clone();

  /// Uniform scale of the CTM -- powers hairlineFloor and the width clamp.
  double get _k {
    final m = _stack.last;
    return math.sqrt(
      (m.entry(0, 0) * m.entry(1, 1) - m.entry(0, 1) * m.entry(1, 0)).abs(),
    );
  }

  // ── paint state helpers ──────────────────────────────────────────────

  void _applyFill(Fill f) => _g.setColor(PdfColor.fromInt(f.argb));

  // HONESTY-POLICY NOTE on a gap in the verbatim §7.7 listing: the doc's
  // own quoted `_applyStroke` never calls `PdfGraphics.setMiterLimit`, even
  // though `Stroke.miterLimit` exists and is carried through equality/hash.
  // This transcription preserves that omission faithfully rather than
  // silently "fixing" it. It is invisible for every caller that leaves
  // `miterLimit` at its default 10.0 (PDF's own default is also 10), but a
  // caller that DOES override `miterLimit` will see no effect on this
  // backend. Worth an amendment (`..setMiterLimit(s.miterLimit)` in the
  // cascade below) before v1 ships if any caller actually varies it.
  // CR-082 IS TWO INDEPENDENT KNOBS, AND THEY USED TO BE ONE.
  //
  // `Stroke` carries `scaleWithGeometry` ("cable traces, symbol outlines
  // and rack rails scale with the diagram; UI chrome does not") AND
  // `hairlineFloor` ("sheet furniture uses a 0.25 pt print floor;
  // everything else 0.5 pt"). Both backends used to branch on
  // `hairlineFloor` ALONE for both decisions, so `scaleWithGeometry` had
  // zero readers anywhere in the repository -- a production field whose
  // only mention was its own declaration.
  //
  // It was invisible because no caller had ever applied a scale != 1. The
  // elevation sheets are the first: they wrap the whole rack scene in one
  // `OpTransform` at 1:8, where the two knobs stop agreeing. The width
  // decision now reads `scaleWithGeometry` and the floor decision reads
  // `hairlineFloor`, which is what CR-082 says.
  //
  // At k == 1 the two spellings are identical, which is why this changes
  // nothing about any sheet drawn at 1:1 -- `sheetRule` sets
  // `scaleWithGeometry: false` so furniture keeps behaving exactly as it
  // did, and `stroke_scaling_test.dart` proves the difference at k != 1.
  void _applyStroke(Stroke s) {
    final k = _k == 0 ? 1.0 : _k;
    var w = s.scaleWithGeometry ? s.widthPt : s.widthPt / k;
    final floor = s.hairlineFloor ? 0.25 : 0.5; // pt -- CR-082
    if (w * k < floor) w = floor / k;
    _g
      ..setStrokeColor(PdfColor.fromInt(s.argb))
      ..setLineWidth(w)
      ..setLineCap(_cap(s.cap))
      ..setLineJoin(_join(s.join))
      ..setLineDashPattern(s.dash ?? const <num>[], s.dashPhase.round());
  }

  PdfLineCap _cap(StrokeCap c) => switch (c) {
    StrokeCap.butt => PdfLineCap.butt,
    StrokeCap.round => PdfLineCap.round,
    StrokeCap.square => PdfLineCap.square,
  };

  PdfLineJoin _join(StrokeJoin j) => switch (j) {
    StrokeJoin.miter => PdfLineJoin.miter,
    StrokeJoin.round => PdfLineJoin.round,
    StrokeJoin.bevel => PdfLineJoin.bevel,
  };

  /// Replays one parsed [DiagramPath] into the current PDF path -- shared
  /// by [drawPath] and [clipPath]. Elided by §7.7; both backends must build
  /// paths from the SAME `DiagramPath` verbs (§8.3's "there is no
  /// drawSvgPath" ruling), so this is the one place that happens on this
  /// backend.
  void _emitPath(DiagramPath p) {
    for (final cmd in p.commands) {
      switch (cmd) {
        case MoveTo(:final x, :final y):
          _g.moveTo(x, y);
        case LineTo(:final x, :final y):
          _g.lineTo(x, y);
        case CubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final x3,
          :final y3,
        ):
          _g.curveTo(x1, y1, x2, y2, x3, y3);
        case ClosePath():
          _g.closePath();
      }
    }
  }

  // ── clip ──────────────────────────────────────────────────────────────

  @override
  void clipRect(DBox r) {
    // Clip is intersective and undone only by restore() (§7.3) -- no
    // saveContext/restoreContext bracket here. Scoping a clip is the
    // CALLER's job via this canvas's own save()/restore(), exactly as with
    // every other DiagramCanvas backend; bracketing it here would undo the
    // clip before the caller's next draw call ever saw it.
    _g.drawRect(r.left, r.top, r.width, r.height);
    _g.clipPath();
  }

  @override
  void clipPath(DiagramPath p, {FillRule rule = FillRule.nonZero}) {
    _emitPath(p);
    _g.clipPath(evenOdd: rule == FillRule.evenOdd);
  }

  // ── primitives ────────────────────────────────────────────────────────

  @override
  void drawLine(DPt a, DPt b, Stroke s) {
    _g.saveContext();
    _applyStroke(s);
    _g
      ..drawLine(a.x, a.y, b.x, b.y)
      ..strokePath();
    _g.restoreContext();
  }

  @override
  void drawPolyline(List<DPt> pts, Stroke s, {bool close = false}) {
    if (pts.isEmpty) return;
    _g.saveContext();
    _applyStroke(s);
    _g.moveTo(pts.first.x, pts.first.y);
    for (final p in pts.skip(1)) {
      _g.lineTo(p.x, p.y);
    }
    // `strokePath(close: true)` is the PDF `s` operator -- close then
    // stroke in one step -- rather than an explicit separate closePath()
    // call, matching `PdfGraphics`'s own idiom for a closed stroked shape.
    _g.strokePath(close: close);
    _g.restoreContext();
  }

  @override
  void drawPath(DiagramPath p, {Fill? fill, Stroke? stroke}) {
    if (fill != null) {
      _g.saveContext();
      _applyFill(fill);
      _emitPath(p);
      _g.fillPath();
      _g.restoreContext();
    }
    if (stroke != null) {
      _g.saveContext();
      _applyStroke(stroke);
      _emitPath(p);
      _g.strokePath();
      _g.restoreContext();
    }
  }

  @override
  void drawRect(DBox r, {Fill? fill, Stroke? stroke}) {
    // Under the global flip, (left, top, w, h) is already correct -- no y
    // math.
    if (fill != null) {
      _g.saveContext();
      _applyFill(fill);
      _g
        ..drawRect(r.left, r.top, r.width, r.height)
        ..fillPath();
      _g.restoreContext();
    }
    if (stroke != null) {
      _g.saveContext();
      _applyStroke(stroke);
      _g
        ..drawRect(r.left, r.top, r.width, r.height)
        ..strokePath();
      _g.restoreContext();
    }
  }

  @override
  void drawRoundRect(DBox r, Radii radii, {Fill? fill, Stroke? stroke}) {
    if (fill != null) {
      _g.saveContext();
      _applyFill(fill);
      _g
        ..drawRRect(r.left, r.top, r.width, r.height, radii.rv, radii.rh)
        ..fillPath();
      _g.restoreContext();
    }
    if (stroke != null) {
      _g.saveContext();
      _applyStroke(stroke);
      _g
        ..drawRRect(r.left, r.top, r.width, r.height, radii.rv, radii.rh)
        ..strokePath();
      _g.restoreContext();
    }
  }

  @override
  void drawCircle(DPt c, double radius, {Fill? fill, Stroke? stroke}) {
    if (fill != null) {
      _g.saveContext();
      _applyFill(fill);
      _g
        ..drawEllipse(c.x, c.y, radius, radius)
        ..fillPath();
      _g.restoreContext();
    }
    if (stroke != null) {
      _g.saveContext();
      _applyStroke(stroke);
      _g
        ..drawEllipse(c.x, c.y, radius, radius)
        ..strokePath();
      _g.restoreContext();
    }
  }

  @override
  void drawEllipse(DPt c, double rx, double ry, {Fill? fill, Stroke? stroke}) {
    if (fill != null) {
      _g.saveContext();
      _applyFill(fill);
      _g
        ..drawEllipse(c.x, c.y, rx, ry)
        ..fillPath();
      _g.restoreContext();
    }
    if (stroke != null) {
      _g.saveContext();
      _applyStroke(stroke);
      _g
        ..drawEllipse(c.x, c.y, rx, ry)
        ..strokePath();
      _g.restoreContext();
    }
  }

  @override
  TextMetrics measureText(String t, TextStyleSpec s) =>
      _measurer.measureText(t, s);

  @override
  void drawText(String text, DPt at, TextStyleSpec s) {
    final font = _fonts[s.font]!;
    final m = measureText(text, s);
    final o = anchorOffset(s.anchor, m); // <- the SHARED helper

    _g.saveContext();
    _applyFill(Fill(s.argb));
    // Counter-flip locally so glyphs are upright, then apply the caller's
    // rotation. Sign is negated because the local frame is now Y-up.
    _g.setTransform(
      Matrix4.identity()
        ..setEntry(0, 3, at.x)
        ..setEntry(1, 3, at.y)
        ..multiply(Matrix4.identity()..setEntry(1, 1, -1.0))
        ..multiply(Matrix4.rotationZ(-s.rotationRad)),
    );
    _g.drawString(font, s.sizePt, text, o.x, -o.y, charSpace: s.letterSpacing);
    _g.restoreContext();
  }
}
