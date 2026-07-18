import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/viewport_controller.dart';

/// `kGridUnit` (2.5 mm) expressed in scene units — diagram points, `1 pt =
/// 1/72 in`, the regime [ViewportController] lives in. Equals
/// `kGridUnit.nm * 72 / Len.nmPerInch`, written with the literals so it stays a
/// compile-time constant usable as a default parameter (extension-type member
/// access such as `kGridUnit.nm` is not const-evaluable). ~7.0866 pt.
const double kGridUnitPoints = 2_500_000 * 72 / 25_400_000;

/// Visual parameters for the background grid. Kept separate from the painter so
/// a theme change is a new [GridStyle] (which [GridPainter.shouldRepaint]
/// detects) while the painter and its picture cache are otherwise stable.
@immutable
class GridStyle {
  const GridStyle({
    required this.minorColor,
    required this.majorColor,
    this.minorWidth = 0.6,
    this.majorWidth = 1.0,
    this.majorEvery = 5,
  });

  /// Colour of the fine (per-grid-unit) hairlines.
  final ui.Color minorColor;

  /// Colour of the bolder accent lines. The "every 5th line, bolder" default
  /// borrows the RU ruler's aesthetic precedent (docs/04-rack-editor.md §2.1).
  final ui.Color majorColor;

  /// Nominal minor line width in *screen* pixels.
  final double minorWidth;

  /// Nominal major line width in *screen* pixels.
  final double majorWidth;

  /// A bolder [majorColor] line is drawn every Nth grid line.
  final int majorEvery;

  @override
  bool operator ==(Object other) =>
      other is GridStyle &&
      other.minorColor == minorColor &&
      other.majorColor == majorColor &&
      other.minorWidth == minorWidth &&
      other.majorWidth == majorWidth &&
      other.majorEvery == majorEvery;

  @override
  int get hashCode =>
      Object.hash(minorColor, majorColor, minorWidth, majorWidth, majorEvery);
}

/// A recorded grid picture memoised by key, mirroring the `LayerCache.obtain`
/// pattern in docs/03-architecture.md §7.3. Owned by the screen (not the
/// painter, which the framework never disposes) so the native `ui.Picture` has
/// a clear lifecycle and is released in `dispose`.
class GridCache {
  ui.Picture? _picture;
  Object? _key;

  /// Returns the cached picture when [key] is unchanged, otherwise re-records
  /// it via [draw] and disposes the previous one (native memory — required).
  ui.Picture obtain(
    Object key,
    ui.Rect cullRect,
    void Function(ui.Canvas canvas) draw,
  ) {
    final cached = _picture;
    if (cached != null && _key == key) return cached;
    cached?.dispose();
    final recorder = ui.PictureRecorder();
    draw(ui.Canvas(recorder, cullRect));
    _key = key;
    return _picture = recorder.endRecording();
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
    _key = null;
  }
}

/// Draws the background grid at [gridSpacing] (default one grid unit) under the
/// current [ViewportController] transform.
///
/// Per docs/03-architecture.md §7.2 (L0), the grid is baked into a `ui.Picture`
/// per "zoom decade" rather than redrawn line-by-line every frame. This
/// interprets a "decade" as a coarse **octave** bucket (`round(log2 scale)`):
/// tiny zoom changes stay in the same bucket and reuse the cached picture,
/// while a bucket change or a pan past the baked coverage re-bakes. Lines are
/// recorded in scene coordinates and replayed under the viewport transform.
///
/// HONESTY NOTE (task's standing policy): because the picture is baked in scene
/// space and stroke widths are divided by the bucket's representative scale,
/// hairline width drifts by up to a factor of sqrt(2) across a single octave
/// before the bucket flips. For a background grid this is imperceptible and is
/// the accepted cost of caching across pans; a future ruler/chassis layer that
/// needs pixel-exact strokes would key its cache more finely.
class GridPainter extends CustomPainter {
  GridPainter({
    required this.viewport,
    required this.cache,
    required this.style,
    this.gridSpacing = kGridUnitPoints,
  }) : super(repaint: viewport);

  final ViewportController viewport;
  final GridCache cache;
  final GridStyle style;
  final double gridSpacing;

  /// Below this many screen pixels between lines, a tier is dropped as
  /// illegible clutter. Decided on the bucket's representative scale so the
  /// choice is stable within a bucket (and consistent with the cache key).
  static const double _minScreenSpacing = 5;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final scale = viewport.scale;
    if (scale <= 0 || size.isEmpty) return;

    final bucket = _zoomBucket(scale);
    final repScale = math.pow(2, bucket).toDouble();

    final minorScreen = gridSpacing * repScale;
    final majorSpacing = gridSpacing * style.majorEvery;
    final majorScreen = majorSpacing * repScale;
    final drawMinor = minorScreen >= _minScreenSpacing;
    final drawMajor = majorScreen >= _minScreenSpacing;
    if (!drawMinor && !drawMajor) return; // too dense to read — grid off.

    // Visible scene rect (no rotation, so opposite corners suffice).
    final tl = viewport.screenToScene(const DPt(0, 0));
    final br = viewport.screenToScene(DPt(size.width, size.height));

    // Coverage: pad by one viewport on each side, then snap OUT to a coarse
    // tile so a small pan stays inside the baked region and reuses the cache.
    final tile = majorSpacing;
    final padX = (br.x - tl.x).abs();
    final padY = (br.y - tl.y).abs();
    final covL = _snapDown(tl.x - padX, tile);
    final covT = _snapDown(tl.y - padY, tile);
    final covR = _snapUp(br.x + padX, tile);
    final covB = _snapUp(br.y + padY, tile);
    final coverage = ui.Rect.fromLTRB(covL, covT, covR, covB);

    // Cache key: bucket + snapped coverage + LOD flags + style + spacing. Round
    // the coverage to integers so sub-unit jitter never invalidates the cache.
    final key = (
      bucket,
      covL.round(),
      covT.round(),
      covR.round(),
      covB.round(),
      drawMinor,
      drawMajor,
      style.hashCode,
      (gridSpacing * 1000).round(),
    );

    final picture = cache.obtain(
      key,
      coverage,
      (c) => _bake(
        c,
        coverage,
        repScale,
        drawMinor: drawMinor,
        drawMajor: drawMajor,
      ),
    );

    canvas
      ..save()
      ..transform(viewport.transform.storage)
      ..drawPicture(picture)
      ..restore();
  }

  void _bake(
    ui.Canvas c,
    ui.Rect coverage,
    double repScale, {
    required bool drawMinor,
    required bool drawMajor,
  }) {
    final minorPaint = ui.Paint()
      ..color = style.minorColor
      ..strokeWidth = style.minorWidth / repScale
      ..style = ui.PaintingStyle.stroke
      ..isAntiAlias = true;
    final majorPaint = ui.Paint()
      ..color = style.majorColor
      ..strokeWidth = style.majorWidth / repScale
      ..style = ui.PaintingStyle.stroke
      ..isAntiAlias = true;

    final every = style.majorEvery;

    // Vertical lines (constant x). Dart's `%` is non-negative for a positive
    // divisor, so major detection is correct for negative indices too.
    final firstIx = (coverage.left / gridSpacing).floor();
    final lastIx = (coverage.right / gridSpacing).ceil();
    for (var i = firstIx; i <= lastIx; i++) {
      final isMajor = i % every == 0;
      if (isMajor ? !drawMajor : !drawMinor) continue;
      final x = i * gridSpacing;
      c.drawLine(
        ui.Offset(x, coverage.top),
        ui.Offset(x, coverage.bottom),
        isMajor ? majorPaint : minorPaint,
      );
    }

    // Horizontal lines (constant y).
    final firstIy = (coverage.top / gridSpacing).floor();
    final lastIy = (coverage.bottom / gridSpacing).ceil();
    for (var j = firstIy; j <= lastIy; j++) {
      final isMajor = j % every == 0;
      if (isMajor ? !drawMajor : !drawMinor) continue;
      final y = j * gridSpacing;
      c.drawLine(
        ui.Offset(coverage.left, y),
        ui.Offset(coverage.right, y),
        isMajor ? majorPaint : minorPaint,
      );
    }
  }

  int _zoomBucket(double scale) => (math.log(scale) / math.ln2).round();

  static double _snapDown(double v, double step) => (v / step).floor() * step;
  static double _snapUp(double v, double step) => (v / step).ceil() * step;

  /// Per-frame repaint is driven by the `viewport` repaint listenable (passed
  /// to `super.repaint`), and "don't re-bake on tiny zoom changes" is realised
  /// by the bucket-keyed [GridCache] inside [paint] — the doc's shouldRepaint
  /// "compare the zoom-decade bucket and visible scene rect" guidance, mapped
  /// onto the repaint-listenable architecture (docs/03 §7.3: "no setState in
  /// the canvas path"). shouldRepaint here therefore only reacts to *config*
  /// changes (a theme swap producing a new [GridStyle], a different viewport).
  @override
  bool shouldRepaint(covariant GridPainter old) =>
      viewport != old.viewport ||
      cache != old.cache ||
      style != old.style ||
      gridSpacing != old.gridSpacing;
}
