import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset, Size;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// Lower / upper bounds on the uniform zoom factor.
///
/// `[0.05, 32.0]` is taken verbatim from the schematic editor's own viewport
/// (docs/05-schematic-editor.md §"Pan and zoom", line 782 — the same
/// hand-rolled viewport this class implements). Reusing the one cited number
/// keeps the two editors' zoom behaviour identical, as the task requested.
const double kMinScale = 0.05;
const double kMaxScale = 32;

/// The hand-rolled scene<->screen transform for the canvas (docs/03 §4.4).
///
/// ## Coordinate regime
/// This viewport maps **scene space** to **screen space**. Scene space is the
/// [DiagramScene]/[DiagramCanvas] regime (docs/03 §7.2, CR-007): double
/// precision, `1 scene unit = 1 PDF point = 1/72 in`, which is exactly what
/// [DPt] measures. Screen space is logical pixels. The identity transform maps
/// one scene point to one logical pixel.
///
/// (The rack editor's "zoom 1.0 => 1U = 22 px" label from docs/04 §2.1 is a
/// separate *display* convention layered on top when rack rendering lands; it
/// is deliberately not baked into the matrix here, so this class stays a plain
/// scene<->screen transform that any future editor can reuse.)
///
/// ## Why not `InteractiveViewer`
/// Rejected per docs/03 §4.4: it never receives `PointerScrollEvent` (so
/// wheel-zoom-to-cursor is impossible inside it), it installs its own
/// `ScaleGestureRecognizer` that fights marquee/drag-to-connect in the gesture
/// arena, and `boundaryMargin` is the wrong model for a model-defined scene.
///
/// ## The multiply order that is easy to get backwards (docs/03 §4.4)
/// Pan deltas arrive in **screen** space and are applied with a
/// **pre**-multiply (`leftTranslate`), so pan speed is independent of zoom.
/// The zoom pivot is a
/// **post**-multiply (`translate`) in **scene** space: translate the pivot to
/// the origin, scale, translate back. Reversing the two produces pan whose
/// speed varies with zoom — the classic hand-rolled-viewport bug.
///
/// No widget watches this object; it is handed to painters as a repaint
/// [Listenable] and to gesture handlers as a plain reference. It has no
/// `BuildContext` coupling.
class ViewportController extends ChangeNotifier {
  ViewportController();

  /// Scene -> screen. Column-major `Matrix4` (vector_math). The returned matrix
  /// is the live instance for zero-allocation reads (a painter passes
  /// `transform.storage` straight to `Canvas.transform`); treat it as
  /// read-only — mutate the viewport through the methods below, never this.
  Matrix4 get transform => _transform;
  final Matrix4 _transform = Matrix4.identity();

  /// Screen -> scene. Lazily inverted and cached; the cache is invalidated on
  /// every mutation, so the (relatively expensive) inversion happens at most
  /// once per frame regardless of how many times it is read.
  Matrix4 get inverseTransform => _inverse ??= Matrix4.inverted(_transform);
  Matrix4? _inverse;

  /// The uniform zoom factor, extracted from the matrix as the length of its
  /// first basis vector. Robust to any accumulated transform; equals
  /// `storage[0]` while no rotation is ever applied (none is, in v1).
  double get scale {
    final s = _transform.storage;
    return math.sqrt(s[0] * s[0] + s[1] * s[1]);
  }

  /// Maps a scene point to its screen position under the current transform.
  DPt sceneToScreen(DPt scenePoint) => _apply(_transform, scenePoint);

  /// Maps a screen point back to the scene point under it.
  DPt screenToScene(DPt screenPoint) => _apply(inverseTransform, screenPoint);

  /// Pans by a **screen-space** delta.
  ///
  /// Applied as a pre-multiply (`leftTranslate`): for an affine matrix whose
  /// bottom row is `[0,0,0,1]` this adds the delta straight onto the
  /// translation column, so the pan moves the same number of pixels no matter
  /// the zoom. Post-multiplying instead would scale the delta by the zoom.
  void panBy(Offset screenDelta) {
    if (screenDelta == Offset.zero) return;
    _transform.leftTranslateByDouble(screenDelta.dx, screenDelta.dy, 0, 1);
    _inverse = null;
    notifyListeners();
  }

  /// Zooms by [scaleFactor] about a **screen-space** [screenPivot], keeping the
  /// scene point currently under the pivot fixed under it.
  ///
  /// Post-multiplies `T(pivotScene) * S(k) * T(-pivotScene)` onto the transform
  /// (scene-space pivot, right-multiplied — docs/03 §4.4). The resulting scale
  /// is clamped to `[kMinScale, kMaxScale]`; the clamp is applied to the
  /// *factor* (`k = clampedTarget / current`) so the pivot stays invariant even
  /// at the limits.
  void zoomBy(double scaleFactor, {required Offset screenPivot}) {
    if (!scaleFactor.isFinite || scaleFactor <= 0) return;
    final current = scale;
    final target = (current * scaleFactor).clamp(kMinScale, kMaxScale);
    if (target == current) return; // already at the clamp in this direction.
    final k = target / current;
    final pivot = screenToScene(DPt(screenPivot.dx, screenPivot.dy));
    _transform
      ..translateByDouble(pivot.x, pivot.y, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-pivot.x, -pivot.y, 0, 1);
    _inverse = null;
    notifyListeners();
  }

  /// Frames [sceneBounds] within a [viewportSize]-pixel viewport, centred, with
  /// a small margin, clamped to the zoom range.
  ///
  /// UNDER-SPECIFICATION NOTE (honesty policy): the task pins the signature to
  /// the model's integer [Box], but a [Box]'s coordinates are documented as
  /// *grid units* while this viewport's scene space is *diagram points*. Rather
  /// than teach the viewport the model's unit regime (the model->scene
  /// conversion is the scene builder's single job, CR-007), this treats the
  /// box's integer coordinates as already being in scene/diagram-point space —
  /// i.e. the caller hands over scene bounds. There is no rack content to frame
  /// at this stage, so nothing exercises the choice yet; it is documented here
  /// so the next stage wires the conversion in one place rather than here.
  void fitToContent(Box sceneBounds, Size viewportSize) {
    final bw = sceneBounds.width.toDouble();
    final bh = sceneBounds.height.toDouble();
    if (bw <= 0 || bh <= 0 || viewportSize.isEmpty) {
      reset();
      return;
    }
    const margin = 0.9; // leave ~10% breathing room around the content.
    final s =
        (math.min(viewportSize.width / bw, viewportSize.height / bh) * margin)
            .clamp(kMinScale, kMaxScale);
    final cx = (sceneBounds.gx0 + sceneBounds.gx1) / 2;
    final cy = (sceneBounds.gy0 + sceneBounds.gy1) / 2;
    final tx = viewportSize.width / 2 - s * cx;
    final ty = viewportSize.height / 2 - s * cy;
    _setScaleTranslation(s, tx, ty);
  }

  /// Returns to the identity transform (scale 1, no translation).
  void reset() {
    _transform.setIdentity();
    _inverse = null;
    notifyListeners();
  }

  void _setScaleTranslation(double s, double tx, double ty) {
    _transform.setIdentity();
    final m = _transform.storage;
    m[0] = s; // scale x
    m[5] = s; // scale y
    m[12] = tx; // translate x
    m[13] = ty; // translate y
    _inverse = null;
    notifyListeners();
  }

  /// Projective apply of [m] to [p] with a perspective divide. The divide is a
  /// no-op for the affine matrices this class builds (w stays 1), but doing it
  /// unconditionally keeps the helper correct if a future transform is added.
  static DPt _apply(Matrix4 m, DPt p) {
    final s = m.storage;
    final x = s[0] * p.x + s[4] * p.y + s[12];
    final y = s[1] * p.x + s[5] * p.y + s[13];
    final w = s[3] * p.x + s[7] * p.y + s[15];
    if (w == 1 || w == 0) return DPt(x, y);
    return DPt(x / w, y / w);
  }
}
