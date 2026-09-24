// rackpal_ui/src/draw/flutter_canvas.dart -- the ONLY renderer file
// importing `dart:ui`. Transcribed from docs/08-pdf-export.md §7.7's
// verbatim `FlutterDiagramCanvas` listing (CR-086), with the same
// `Pt`/`Box` -> `DPt`/`DBox` adaptation the sibling PDF backend stage made
// (see rackpal_export/src/draw/pdf_canvas.dart's header) plus every
// method §7.7 elided entirely (drawRoundRect, drawPolyline, drawCircle,
// drawEllipse, drawPath, clipRect, clipPath, translate, scale,
// save/restore/saveCount, currentTransform) -- those follow the exact
// same "build a `ui.Path`, dash it if needed, paint it" idiom the doc
// shows for `drawText`/the stroke-paint helper.
//
// ADAPTATION NOTE (imports): `package:flutter/painting.dart` re-exports
// only a handful of `dart:ui` names in its own `show` clause (confirmed
// against the installed Flutter 3.44.4 SDK's `painting.dart`) --
// `FontFeature`, `TextBaseline` and `TextDirection` are NOT among them.
// The doc's §7.7 snippet uses those three unprefixed, which only
// typechecks under an assumed wildcard `dart:ui` import. Since this file
// already needs `dart:ui as ui` for `Canvas`/`Path`/`Paint`/etc., those
// three (plus every other raw-canvas type) are qualified `ui.` throughout
// instead of adding a second, unprefixed `dart:ui` import purely to match
// the doc's spelling -- a purely mechanical adaptation, not a semantic
// one.
//
// ADAPTATION NOTE (`_dashed`): §7.7's verbatim two-argument
// `_dashed(ui.Path p, Stroke s)` builds its cache key as `_PathKey(p)` --
// directly from the `ui.Path`. A raw `ui.Path` has only identity
// `==`/`hashCode` (no value equality), and a fresh `ui.Path` is built at
// every call site here, so keying on the `ui.Path` object itself would
// never hit the cache at all -- a correctness-neutral but pointless miss.
// This adapts the signature to a third parameter, an explicit `_PathKey`
// describing the GEOMETRY that produced `p` (see `_PathKey`'s own doc
// comment for the full identity strategy), so equal geometry actually
// shares one dashed path.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:meta/meta.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/draw/text_run_cache.dart';
import 'package:vector_math/vector_math_64.dart';

/// Resolves a container-member reference to a decoded `ui.Image`.
///
/// Declared HERE and not in `rackpal_core`, because `ui.Image` is a
/// `dart:ui` type and core is Flutter-free by gate. The PDF backend
/// declares its own for the same reason, over `PdfImage`. Neither image
/// type ever reaches the IR, which is what lets one display list drive
/// both.
typedef FlutterImageResolver = ui.Image? Function(ImageRef ref);

/// The Flutter backend of [DiagramCanvas] (CR-086): replays a
/// `DiagramScene` onto a real `ui.Canvas`. Unlike `PdfDiagramCanvas`
/// (rackpal_export/src/draw/pdf_canvas.dart -- not referenced as a
/// dartdoc link since rackpal_ui is a SIBLING package that may not import
/// rackpal_export) there is NO global Y-flip here -- `ui.Canvas` is
/// already top-left, Y-down, the same sense as
/// diagram space (docs/08-pdf-export.md §7.4/§7.6 divergence #1), so this
/// constructor pushes a plain identity matrix rather than a flip.
final class FlutterDiagramCanvas implements DiagramCanvas {
  FlutterDiagramCanvas(
    this._c, {
    required TextMeasurer measurer,
    this.runs,
    this.images,
    this.outerScale = 1,
  }) : _measurer = measurer {
    _stack.add(Matrix4.identity());
  }

  final ui.Canvas _c;
  final TextMeasurer _measurer;
  final List<Matrix4> _stack = [];

  /// The uniform scale a transform LAYER applies above this canvas, which
  /// its own transform stack cannot see (`#905`).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE EDITOR CANVASES ZOOM ABOVE THE PICTURE, SO `_k` READ 1 AT ALL ZOOMS
  /// ═══════════════════════════════════════════════════════════════════
  /// The plan, rack and schematic canvases push the viewport as a
  /// `pushTransform` layer, so a pan re-projects a cached picture. The
  /// stroke rule below reads `_k` for two decisions, whether a width is
  /// constant on the surface and where the 0.5-point floor sits, and with
  /// the zoom outside the stack both were taken at scale 1. Measured on
  /// the plan canvas through `TestRecordingCanvas`: a 2-unit outline
  /// painted at 0.5, 2 and 8 physical pixels at 25%, 100% and 400%.
  ///
  /// A caller that knows its layer's scale passes it. The default of 1 is
  /// every other caller's behaviour, unchanged.
  final double outerScale;

  /// Resolves an [ImageRef] to an already-decoded `ui.Image`, or null when
  /// no scene this canvas replays contains an `OpImage`.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// SYNCHRONOUS, BECAUSE PAINTING IS.
  /// ═══════════════════════════════════════════════════════════════════
  /// `ui.Canvas.drawImageRect` wants a decoded `ui.Image` and a paint
  /// callback cannot await. Decoding is therefore somebody else's job,
  /// done once when the underlay is imported or the document is opened,
  /// and this is only the lookup. A resolver that decoded on demand would
  /// decode a floorplan on every frame of a pan.
  ///
  /// NULL IS THE ORDINARY STATE, and this sentence named the wrong chapter
  /// as its end. It read "stays so until PLAN-C"; PLAN-C and PLAN-D have
  /// both closed and it is still null, because what ends it is a SCENE
  /// BUILDER and not a model or an importer. Nothing in this repository
  /// emits an `OpImage` outside two test files, so every existing
  /// construction site is still correct without passing anything.
  ///
  /// **IT ENDS AT `PLAN-E/2`, WHICH OWES AN IMPLEMENTATION AND NOT ONLY A
  /// CALL SITE.** `PLAN-E/1`'s census found this typedef has no
  /// implementation anywhere in the tree (docs/12 §5.9.7), and a plan
  /// canvas that cannot draw the plan is not one. The decode-once cache
  /// that satisfies it is shaped by the paragraph above rather than by
  /// this one: the lookup is synchronous, so the decode happens at import
  /// or at open.
  final FlutterImageResolver? images;

  /// M2-G's laid-out-run cache, or null to lay every run out afresh.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// OWNED BY THE RENDER OBJECT, NOT BY THIS CLASS AND NOT BY A `static`
  /// ═══════════════════════════════════════════════════════════════════
  /// A `FlutterDiagramCanvas` is built once PER PAINT (docs/08 §7.8's
  /// `RenderDeviceBox.paint`), so a cache held here would be born and
  /// discarded on the frame it was meant to survive. A `static` one — the
  /// shape `_dashCache` takes — would survive, and would also outlive every
  /// document, hold native `ui.Paragraph`s for a project the user closed an
  /// hour ago, and leak between widget tests in a way no test could see.
  ///
  /// So the render object owns it and passes it in: the cache then lives
  /// exactly as long as the thing that repaints through it, and
  /// `detach()` is a real disposal point.
  ///
  /// NULL IS A SUPPORTED MODE, and it is what every test that measures the
  /// uncached path uses. It is also correct: the cache changes how often a
  /// run is laid out and nothing about what is drawn.
  final TextRunCache? runs;

  /// Cache of already-dashed paths, keyed on (source geometry, dash
  /// pattern) -- see [_PathKey]/[_DashKey]. `static` so every
  /// `FlutterDiagramCanvas` built across the app's lifetime (one per
  /// paint, per docs/08-pdf-export.md §7.8's `RenderDeviceBox.paint`)
  /// shares one cache, matching the doc's own `static final` declaration.
  static final _dashCache = <(_PathKey, _DashKey), ui.Path>{};

  // ── paint state helpers ──────────────────────────────────────────────

  // CR-082 IS TWO INDEPENDENT KNOBS -- see the identical note in
  // `rackpal_export/src/draw/pdf_canvas.dart`'s `_applyStroke`. The width
  // decision reads `scaleWithGeometry`; the FLOOR decision reads
  // `hairlineFloor`. They used to share one branch, which left
  // `scaleWithGeometry` with no readers on either backend. The two
  // spellings coincide at k == 1, so nothing on screen moves.
  ui.Paint _strokePaint(Stroke s) {
    final k = _k == 0 ? 1.0 : _k;
    var w = s.scaleWithGeometry ? s.widthPt : s.widthPt / k;
    final floor = s.hairlineFloor ? 0.25 : 0.5; // pt -- CR-082
    if (w * k < floor) w = floor / k;
    return ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..color = ui.Color(s.argb)
      ..strokeWidth = w
      ..strokeCap = _cap(s.cap)
      ..strokeJoin = _join(s.join)
      ..strokeMiterLimit = s
          .miterLimit // 10.0 to match PDF, not Flutter's
      // default of 4 -- divergence #10.
      ..isAntiAlias = true;
  }

  ui.Paint _fillPaint(Fill f) => ui.Paint()
    ..style = ui.PaintingStyle.fill
    ..color = ui.Color(f.argb)
    ..isAntiAlias = true;

  /// dart:ui has NO dash support. Synthesise, and cache -- see the file
  /// header's adaptation note for why the signature gained a [key] param.
  ui.Path _dashed(ui.Path p, _PathKey key, Stroke s) => s.dash == null
      ? p
      : _dashCache.putIfAbsent(
          (key, _DashKey(s.dash!)),
          () => dashPath(p, dashArray: CircularIntervalList<double>(s.dash!)),
        );

  /// Draws [path] (built for [key]'s geometry) stroked with [s], dashing
  /// first if `s.dash` is set. Shared by every stroke-drawing primitive
  /// below.
  void _strokeShape(ui.Path path, _PathKey key, Stroke s) =>
      _c.drawPath(_dashed(path, key, s), _strokePaint(s));

  ui.StrokeCap _cap(StrokeCap c) => switch (c) {
    StrokeCap.butt => ui.StrokeCap.butt,
    StrokeCap.round => ui.StrokeCap.round,
    StrokeCap.square => ui.StrokeCap.square,
  };

  ui.StrokeJoin _join(StrokeJoin j) => switch (j) {
    StrokeJoin.miter => ui.StrokeJoin.miter,
    StrokeJoin.round => ui.StrokeJoin.round,
    StrokeJoin.bevel => ui.StrokeJoin.bevel,
  };

  /// Maps a [FontRef] to the Flutter `fontFamily` string registered in
  /// `apps/rackpal/pubspec.yaml`'s `fonts:` block, so `TextPainter`
  /// rasterises the SAME TTF `PdfFontMeasurer`/`PdfTtfFont` measure on the
  /// PDF side (CR-080, docs/08-pdf-export.md §10.2).
  ///
  /// SCOPE NOTE: only Jost Regular is bundled at this stage (see
  /// `FontRef`'s own doc comment in rackpal_core/src/draw/text.dart), and
  /// `FontRef.family` already carries the exact pubspec family string
  /// (`'Jost'` -- matching both `rackpal_text`'s and
  /// `rackpal_export`'s test fixtures), so this is a passthrough for now.
  /// `bold` is not wired to a distinct family yet because no bold TTF is
  /// bundled -- a later stage adds the SemiBold cut and must branch here.
  String _familyFor(FontRef font) => font.family;

  /// Builds the rounded-rectangle outline as a [DiagramPath] using kappa
  /// cubic-Bezier corners (docs/03-architecture.md §8.3), so this
  /// backend's control points match whatever the PDF backend's native
  /// `PdfGraphics.drawRRect` primitive draws (docs/08-pdf-export.md §7.7:
  /// "Kappa is 0.5522847498307933 on both sides"). Reuses
  /// `rackpal_core`'s own `kappa` constant (declared next to `CubicTo` in
  /// draw/path.dart) rather than re-declaring the magic number.
  DiagramPath _roundRectPath(DBox r, Radii radii) {
    final rv = radii.rv;
    final rh = radii.rh;
    final kx = rh * kappa;
    final ky = rv * kappa;
    final l = r.left;
    final t = r.top;
    final right = r.right;
    final b = r.bottom;
    return DiagramPath([
      MoveTo(l + rh, t),
      LineTo(right - rh, t),
      CubicTo(right - rh + kx, t, right, t + rv - ky, right, t + rv),
      LineTo(right, b - rv),
      CubicTo(right, b - rv + ky, right - rh + kx, b, right - rh, b),
      LineTo(l + rh, b),
      CubicTo(l + rh - kx, b, l, b - rv + ky, l, b - rv),
      LineTo(l, t + rv),
      CubicTo(l, t + rv - ky, l + rh - kx, t, l + rh, t),
      const ClosePath(),
    ]);
  }

  /// Replays a [DiagramPath]'s verbs into a fresh `ui.Path` -- shared by
  /// [drawPath], [clipPath] and [drawRoundRect]. Elided by §7.7; both
  /// backends must build paths from the SAME `DiagramPath` verbs (§8.3's
  /// "there is no drawSvgPath" ruling), so this is the one place that
  /// happens on this backend, matching `PdfDiagramCanvas._emitPath`'s
  /// role on the PDF side.
  ui.Path _emit(DiagramPath p) {
    final path = ui.Path();
    for (final cmd in p.commands) {
      switch (cmd) {
        case MoveTo(:final x, :final y):
          path.moveTo(x, y);
        case LineTo(:final x, :final y):
          path.lineTo(x, y);
        case CubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final x3,
          :final y3,
        ):
          path.cubicTo(x1, y1, x2, y2, x3, y3);
        case ClosePath():
          path.close();
      }
    }
    return path;
  }

  // ── state stack ──────────────────────────────────────────────────────

  @override
  void save() {
    _c.save();
    _stack.add(_stack.last.clone());
  }

  @override
  void restore() {
    _c.restore();
    _stack.removeLast();
  }

  @override
  int get saveCount => _stack.length - 1;

  // ── transform ─────────────────────────────────────────────────────────

  void _apply(Matrix4 m) {
    _c.transform(m.storage);
    _stack.last.multiply(m);
  }

  @override
  void translate(double dx, double dy) =>
      _apply(Matrix4.translationValues(dx, dy, 0));

  @override
  void scale(double sx, [double? sy]) =>
      _apply(Matrix4.diagonal3Values(sx, sy ?? sx, 1));

  @override
  void rotate(double radians) => _apply(Matrix4.rotationZ(radians));

  @override
  void transform(Matrix4 m) => _apply(m);

  @override
  Matrix4 get currentTransform => _stack.last.clone();

  /// Uniform scale of the CTM -- powers hairlineFloor and the width clamp.
  /// Mirrors `PdfDiagramCanvas._k` exactly (rackpal_export/src/draw/
  /// pdf_canvas.dart) so both backends clamp hairlines identically.
  ///
  /// TIMES [outerScale], which is the part of the CTM a transform layer
  /// holds and this stack never sees. The PDF canvas has no such layer, so
  /// the mirror still holds wherever the two can meet.
  double get _k {
    final m = _stack.last;
    return outerScale *
        math.sqrt(
          (m.entry(0, 0) * m.entry(1, 1) - m.entry(0, 1) * m.entry(1, 0)).abs(),
        );
  }

  // ── clip ──────────────────────────────────────────────────────────────

  @override
  void clipRect(DBox r) =>
      _c.clipRect(ui.Rect.fromLTWH(r.left, r.top, r.width, r.height));

  @override
  void clipPath(DiagramPath p, {FillRule rule = FillRule.nonZero}) {
    final path = _emit(p)
      ..fillType = rule == FillRule.evenOdd
          ? ui.PathFillType.evenOdd
          : ui.PathFillType.nonZero;
    _c.clipPath(path);
  }

  // ── primitives ────────────────────────────────────────────────────────

  @override
  void drawLine(DPt a, DPt b, Stroke s) {
    final path = ui.Path()
      ..moveTo(a.x, a.y)
      ..lineTo(b.x, b.y);
    final key = _PathKey.geometry('line', [a.x, a.y, b.x, b.y]);
    _strokeShape(path, key, s);
  }

  @override
  void drawPolyline(List<DPt> pts, Stroke s, {bool close = false}) {
    if (pts.isEmpty) return;
    final path = ui.Path()..moveTo(pts.first.x, pts.first.y);
    for (final p in pts.skip(1)) {
      path.lineTo(p.x, p.y);
    }
    if (close) path.close();
    final nums = <double>[
      for (final p in pts) ...[p.x, p.y],
      close ? 1.0 : 0.0,
    ];
    final key = _PathKey.geometry('polyline', nums);
    _strokeShape(path, key, s);
  }

  @override
  void drawPath(DiagramPath p, {Fill? fill, Stroke? stroke}) {
    if (fill != null) {
      _c.drawPath(_emit(p), _fillPaint(fill));
    }
    if (stroke != null) {
      final key = _PathKey.identity('path', p);
      _strokeShape(_emit(p), key, stroke);
    }
  }

  @override
  void drawImage(ImageRef image, DBox dst) {
    final resolved = images?.call(image);
    if (resolved == null) throw MissingImageError(image);
    // No flip and no counter-transform: `ui.Canvas` is already top-left,
    // Y-down, the same sense as diagram space (docs/08 §7.4/§7.6
    // divergence #1), and a `ui.Image`'s own row order matches. The PDF
    // backend's version of this method is NOT symmetric and says why.
    _c.drawImageRect(
      resolved,
      ui.Rect.fromLTWH(
        0,
        0,
        resolved.width.toDouble(),
        resolved.height.toDouble(),
      ),
      ui.Rect.fromLTWH(dst.left, dst.top, dst.width, dst.height),
      // No `color` and no alpha: docs/08 row 9 forbids alpha in the
      // DOCUMENT, and matching it on screen is what keeps the preview
      // honest about what will print. `medium` because an underlay is
      // usually drawn well below its native resolution and `none` shimmers
      // on every pan.
      ui.Paint()
        ..isAntiAlias = true
        ..filterQuality = ui.FilterQuality.medium,
    );
  }

  @override
  void drawRect(DBox r, {Fill? fill, Stroke? stroke}) {
    final rect = ui.Rect.fromLTWH(r.left, r.top, r.width, r.height);
    if (fill != null) {
      _c.drawRect(rect, _fillPaint(fill));
    }
    if (stroke != null) {
      final path = ui.Path()..addRect(rect);
      final key = _PathKey.geometry('rect', [
        r.left,
        r.top,
        r.right,
        r.bottom,
      ]);
      _strokeShape(path, key, stroke);
    }
  }

  @override
  void drawRoundRect(DBox r, Radii radii, {Fill? fill, Stroke? stroke}) {
    final dp = _roundRectPath(r, radii);
    if (fill != null) {
      _c.drawPath(_emit(dp), _fillPaint(fill));
    }
    if (stroke != null) {
      final key = _PathKey.geometry('roundrect', [
        r.left,
        r.top,
        r.right,
        r.bottom,
        radii.rv,
        radii.rh,
      ]);
      _strokeShape(_emit(dp), key, stroke);
    }
  }

  @override
  void drawCircle(DPt c, double radius, {Fill? fill, Stroke? stroke}) =>
      drawEllipse(c, radius, radius, fill: fill, stroke: stroke);

  @override
  void drawEllipse(DPt c, double rx, double ry, {Fill? fill, Stroke? stroke}) {
    final rect = ui.Rect.fromLTWH(c.x - rx, c.y - ry, rx * 2, ry * 2);
    if (fill != null) {
      _c.drawOval(rect, _fillPaint(fill));
    }
    if (stroke != null) {
      final path = ui.Path()..addOval(rect);
      final key = _PathKey.geometry('ellipse', [c.x, c.y, rx, ry]);
      _strokeShape(path, key, stroke);
    }
  }

  @override
  TextMetrics measureText(String t, TextStyleSpec s) =>
      _measurer.measureText(t, s); // <- NOT TextPainter

  /// Lays one run out. The ONE place the font, the feature flags and the
  /// leading distribution are decided — [TextRunCache] calls back into this
  /// rather than building a painter of its own, so a cached run and an
  /// uncached one can never be laid out differently.
  TextRun _layOut(String text, TextStyleSpec s) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: _familyFor(s.font),
          fontSize: s.sizePt,
          color: ui.Color(s.argb),
          height: 1.0,
          leadingDistribution: TextLeadingDistribution.even,
          letterSpacing: s.letterSpacing,
          fontFeatures: const [
            ui.FontFeature.disable('kern'),
            ui.FontFeature.disable('liga'),
            ui.FontFeature.disable('clig'),
          ],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    // ADAPTATION NOTE: docs/08-pdf-export.md §7.7's verbatim snippet writes
    // `computeDistanceToActualBaseline(...)!` as if the method were
    // nullable. On the installed Flutter 3.44.4 SDK it returns a
    // non-nullable `double` (confirmed against
    // flutter/packages/flutter/lib/src/painting/text_painter.dart), so the
    // `!` is dropped -- keeping it is flagged as a genuine
    // `unnecessary_non_null_assertion`, not just a style nit.
    return TextRun(
      tp,
      tp.computeDistanceToActualBaseline(ui.TextBaseline.alphabetic),
    );
  }

  @override
  void drawText(String text, DPt at, TextStyleSpec s) {
    final m = measureText(text, s); // PDF-sourced metrics
    final o = anchorOffset(s.anchor, m); // the SAME shared helper

    // THE KEY IS THE WHOLE `TextStyleSpec`, which means `rotationRad` and
    // `anchor` are in it even though neither changes the layout — rotation
    // is applied to the CANVAS below and the anchor only decides where the
    // laid-out run is painted. The cost is one duplicate entry for a run
    // that appears both rotated and upright, and it is paid deliberately:
    // the alternative is a second identity (docs/09's `styleId`) that would
    // have to be kept in step with `TextStyleSpec.==` by hand, and a key
    // that drifts from the spec is a run painted in the wrong colour.
    final run =
        runs?.runFor(text, s, () => _layOut(text, s)) ?? _layOut(text, s);

    _c
      ..save()
      ..translate(at.x, at.y);
    if (s.rotationRad != 0) _c.rotate(s.rotationRad);
    run.painter.paint(_c, ui.Offset(o.x, o.y - run.baselineOffset));
    _c.restore();
  }
}

/// Cache-key identity for the `ui.Path` built for one stroked draw call,
/// so [FlutterDiagramCanvas._dashed] only reuses a cached dashed path for
/// PROVABLY the same input geometry -- see the file header's adaptation
/// note for why this exists as a standalone key rather than wrapping the
/// `ui.Path` itself.
///
/// IDENTITY STRATEGY (documented per this stage's task brief, because a
/// wrong choice here is a real visual bug, not just a missed cache hit):
///
///  - For `drawLine`/`drawPolyline`/`drawRect`/`drawRoundRect`/
///    `drawCircle`/`drawEllipse` (the `_PathKey.geometry` constructor):
///    the key is the exact numeric parameters that determine the
///    resulting outline (a `kind` discriminator tag plus a flat
///    `List<double>`). Two calls with equal parameters are PROVABLY the
///    same geometry, so reusing the cached dash is safe.
///  - For `drawPath`/`clipPath` (the `_PathKey.identity` constructor):
///    the source `DiagramPath` has NO value equality of its own (see
///    rackpal_core/src/draw/path.dart -- only its individual
///    `PathCommand`s do), and re-deriving one here from `p.commands` would
///    risk silently drifting out of sync with a future change to that
///    file. Rather than guess, this keys on the `DiagramPath` INSTANCE's
///    own identity. Symbol glyphs are parsed once at catalog load and the
///    same instance is reused on every subsequent draw (path.dart's own
///    header: "parsed once, at catalog load"), so identity equality still
///    hits the cache for the common case. Two DIFFERENT `DiagramPath`
///    instances that happen to describe the same geometry simply miss the
///    cache -- the safe failure mode the task brief asks for, never a
///    wrongly-reused stale dash.
@immutable
final class _PathKey {
  const _PathKey.geometry(this._kind, this._nums) : _identity = null;

  _PathKey.identity(this._kind, DiagramPath path)
    : _nums = const [],
      _identity = path;

  final String _kind;
  final List<double> _nums;
  final DiagramPath? _identity;

  @override
  bool operator ==(Object other) {
    if (other is! _PathKey || other._kind != _kind) return false;
    if (_identity != null || other._identity != null) {
      return identical(_identity, other._identity);
    }
    if (_nums.length != other._nums.length) return false;
    for (var i = 0; i < _nums.length; i++) {
      if (_nums[i] != other._nums[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => _identity != null
      ? Object.hash(_kind, identityHashCode(_identity))
      : Object.hash(_kind, Object.hashAll(_nums));
}

/// Cache-key identity for a `Stroke.dash` pattern, paired with [_PathKey]
/// as the `_dashCache` key. Value equality on the dash array only -- the
/// rest of `Stroke` (colour, width, caps, ...) does not affect the
/// resulting dashed *path geometry*, only how it is later painted.
@immutable
final class _DashKey {
  _DashKey(this.dash);

  final List<double> dash;

  @override
  bool operator ==(Object other) {
    if (other is! _DashKey || other.dash.length != dash.length) return false;
    for (var i = 0; i < dash.length; i++) {
      if (other.dash[i] != dash[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(dash);
}
