// rackpal_core/src/draw/scene/plan_turn.dart — the one map between an
// underlay's pixels and the plan scene (DR-184 §11.183.2, `#911`).
//
// ═══════════════════════════════════════════════════════════════════════
// ONE MAP, BECAUSE THERE WERE ABOUT A DOZEN SITES THAT EACH WROTE ITS OWN
// ═══════════════════════════════════════════════════════════════════════
// Until DR-184 the map was the identity: `plan_scene.dart`'s header rules
// that one image pixel is one scene unit, and every site that crossed the
// boundary spelled that as `DPt(p.px.toDouble(), p.py.toDouble())` or
// `PxPt(s.x.round(), s.y.round())`. That was harmless while there was
// nothing to agree on. With a turn in the model, a site that kept the
// identity would draw a pin, a calibration line or a room corner a
// quarter turn away from where the plan's picture is, and nothing in the
// other sites would notice. So every crossing goes through here, and the
// identity survives as the `quarterTurns == 0` case of one function.
//
// ═══════════════════════════════════════════════════════════════════════
// EXACT, AND THAT IS WHY THE TURN IS A QUARTER AND NOT AN ANGLE
// ═══════════════════════════════════════════════════════════════════════
// A quarter turn sends integers to integers. So [toScene] of a `PxPt` is
// exact, [toPixel] of that result gives the same `PxPt` back, and turning
// a plan four times returns every mark to the identical double it started
// at. The matrix [imageToScene] is built from literal 0, 1 and -1 entries
// rather than from `Matrix4.rotationZ`, whose `cos(pi / 2)` is 6.1e-17 and
// would print as a non-zero `cm` entry in the exported PDF: the same
// document would then produce bytes that depend on a libm's last digit,
// which the determinism invariant forbids.
//
// Clockwise AS SEEN, which on a Y-down surface is the direction a positive
// rotation about Z already turns. The four maps, for an image of `w x h`
// pixels and a point `(x, y)` in it:
//
//   0:  (x, y)            the scene is  w x h
//   1:  (h - y, x)        the scene is  h x w
//   2:  (w - x, h - y)    the scene is  w x h
//   3:  (y, w - x)        the scene is  h x w
//
// A top-left pixel lands top-right after one clockwise turn, which is the
// sanity check the tests pin.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/units/px_pt.dart';
import 'package:vector_math/vector_math_64.dart';

/// The exact map between one underlay's pixel space and its plan scene.
@immutable
final class PlanTurn {
  /// A map for an image of [pixelWidth] by [pixelHeight] turned
  /// [quarterTurns] clockwise.
  ///
  /// [quarterTurns] is taken modulo four so that a caller stepping it
  /// (`turns + 1`) can never produce an unmappable value. **The MODEL is
  /// not normalised that way**: a stored value outside 0 to 3 is refused
  /// by the decoder (§11.183.3), because a 5 in a file is somebody's
  /// mistake rather than a turn.
  const PlanTurn({
    required int quarterTurns,
    required this.pixelWidth,
    required this.pixelHeight,
  }) : quarterTurns = quarterTurns % 4;

  /// The map for [underlay] as it stands.
  factory PlanTurn.of(PlanUnderlay underlay) => PlanTurn(
    quarterTurns: underlay.rotationQuarterTurns,
    pixelWidth: underlay.pixelWidth,
    pixelHeight: underlay.pixelHeight,
  );

  /// 0 to 3, clockwise.
  final int quarterTurns;

  /// The stored image's own size, which a turn never changes.
  final int pixelWidth;
  final int pixelHeight;

  /// True when a turn swaps the plan's width and height.
  bool get swapsAxes => quarterTurns.isOdd;

  /// The plan's width AS SEEN, in scene units.
  int get sceneWidth => swapsAxes ? pixelHeight : pixelWidth;

  /// The plan's height AS SEEN, in scene units.
  int get sceneHeight => swapsAxes ? pixelWidth : pixelHeight;

  /// The picture's extent in the scene, which is what a sheet fits and
  /// what `Fit` frames.
  DBox get sceneBounds =>
      DBox.fromLtwh(0, 0, sceneWidth.toDouble(), sceneHeight.toDouble());

  /// Where pixel [p] lands in the scene. Exact.
  DPt toScene(PxPt p) => pointToScene(p.px.toDouble(), p.py.toDouble());

  /// [toScene] for a point that is not on the pixel grid, such as the
  /// centre of a mark being dragged.
  DPt pointToScene(double x, double y) {
    final w = pixelWidth.toDouble();
    final h = pixelHeight.toDouble();
    return switch (quarterTurns) {
      0 => DPt(x, y),
      1 => DPt(h - y, x),
      2 => DPt(w - x, h - y),
      _ => DPt(y, w - x),
    };
  }

  /// The pixel under scene point [s], as doubles and unrounded.
  ///
  /// The inverse of [pointToScene]. Exposed for a caller that has to
  /// subtract two positions before rounding, which is the drag's grab
  /// offset: rounding each end first would move a mark by a pixel on a
  /// press that did not move the pointer.
  (double, double) pointToPixel(DPt s) {
    final w = pixelWidth.toDouble();
    final h = pixelHeight.toDouble();
    return switch (quarterTurns) {
      0 => (s.x, s.y),
      1 => (s.y, h - s.x),
      2 => (w - s.x, h - s.y),
      _ => (w - s.y, s.x),
    };
  }

  /// The pixel under scene point [s], rounded ONCE, half away from zero,
  /// which is `double.round()` and the rule `PlanScale` states for the
  /// same reason: two machines given the same click agree on the pixel.
  PxPt toPixel(DPt s) {
    final (x, y) = pointToPixel(s);
    return PxPt(x.round(), y.round());
  }

  /// The transform that draws the stored image, laid out at
  /// `(0, 0, pixelWidth, pixelHeight)`, into the scene.
  ///
  /// **Null for an unturned plan**, so the scene emits the image exactly
  /// as it did before DR-184 and no display list, op count or exported
  /// byte of an existing document moves.
  ///
  /// Built from literal entries, never from `Matrix4.rotationZ`; the file
  /// header says why. Column-major, as `Matrix4`'s constructor reads: the
  /// map is `x' = a x + c y + tx`, `y' = b x + d y + ty`.
  Matrix4? get imageToScene {
    final w = pixelWidth.toDouble();
    final h = pixelHeight.toDouble();
    Matrix4 affine(
      double a,
      double b,
      double c,
      double d,
      double tx,
      double ty,
    ) => Matrix4(a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);
    return switch (quarterTurns) {
      0 => null,
      1 => affine(0, 1, -1, 0, h, 0),
      2 => affine(-1, 0, 0, -1, w, h),
      _ => affine(0, -1, 1, 0, 0, w),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PlanTurn &&
      other.quarterTurns == quarterTurns &&
      other.pixelWidth == pixelWidth &&
      other.pixelHeight == pixelHeight;

  @override
  int get hashCode => Object.hash(quarterTurns, pixelWidth, pixelHeight);

  @override
  String toString() =>
      'PlanTurn($quarterTurns x 90deg cw, ${pixelWidth}x$pixelHeight)';
}
