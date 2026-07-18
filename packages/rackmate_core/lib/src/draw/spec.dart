// docs/08-pdf-export.md §7.3 / docs/03-architecture.md §7.3: `Stroke` and
// `Fill` are immediate-mode value objects, not retained setters — they
// travel with the draw call. That is what makes them hashable, and value
// equality on both is LOAD-BEARING (docs/08-pdf-export.md §7.10): a future
// graphics-state cache skips redundant setters by comparing the last
// emitted Stroke/Fill to the next one, so a missed field here is a latent
// content-stream-size bug, not just a cosmetic one.

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

const _dashEquality = ListEquality<double>();

/// Stroke end-cap style. `dart:ui`/`PdfGraphics` both default to [butt]
/// (docs/08-pdf-export.md §7.6 divergence #11 — 1:1, no reconciliation
/// needed).
enum StrokeCap { butt, round, square }

/// Stroke join style at corners.
enum StrokeJoin { miter, round, bevel }

/// Path fill/clip winding rule, used by `DiagramCanvas.clipPath`
/// (docs/08-pdf-export.md §7.3).
enum FillRule { nonZero, evenOdd }

/// An immediate-mode stroke style: colour, width, dash, caps/joins, and
/// the two CR-082 knobs that decide how the line weight behaves under
/// scaling (`scaleWithGeometry`) and how thin it is allowed to get before
/// a floor is applied (`hairlineFloor`).
///
/// Every field participates in `==`/`hashCode` — see the file header for
/// why that must not regress.
@immutable
final class Stroke {
  const Stroke({
    required this.argb,
    required this.widthPt,
    this.dash,
    this.dashPhase = 0.0,
    this.cap = StrokeCap.butt,
    this.join = StrokeJoin.miter,
    // PDF's default miter limit is 10, NOT dart:ui's default of 4
    // (docs/08-pdf-export.md §7.6 divergence #10) — Flutter's adapter sets
    // `strokeMiterLimit = 10` explicitly to match, so 10.0 is the correct
    // shared default here rather than either backend's raw default.
    this.miterLimit = 10.0,
    // Cable traces, symbol outlines and rack rails scale with the
    // diagram; UI chrome, selection halos and hit slop do not (§7.3) —
    // `true` is the more common case among stroked *diagram* geometry, so
    // callers building UI-only overlays should pass `false` explicitly.
    this.scaleWithGeometry = true,
    // Only sheet furniture opts into the 0.25pt print floor; everything
    // else uses the plain 0.5pt signal floor (§7.6 divergence #14).
    this.hairlineFloor = false,
  });

  /// Packed 0xAARRGGBB colour.
  final int argb;

  /// Stroke width in typographic points.
  final double widthPt;

  /// Dash pattern in points (CR-079); `null` means a solid line. Keep
  /// [dashPhase] at 0 for screen/print parity — `PdfGraphics` offsets into
  /// the pattern by phase, while the Flutter side's `dashPath` restarts
  /// per sub-path (§7.6 divergence #5).
  final List<double>? dash;
  final double dashPhase;
  final StrokeCap cap;
  final StrokeJoin join;
  final double miterLimit;
  final bool scaleWithGeometry;
  final bool hairlineFloor;

  @override
  bool operator ==(Object other) =>
      other is Stroke &&
      other.argb == argb &&
      other.widthPt == widthPt &&
      _dashEquality.equals(other.dash, dash) &&
      other.dashPhase == dashPhase &&
      other.cap == cap &&
      other.join == join &&
      other.miterLimit == miterLimit &&
      other.scaleWithGeometry == scaleWithGeometry &&
      other.hairlineFloor == hairlineFloor;

  @override
  int get hashCode => Object.hash(
    argb,
    widthPt,
    dash == null ? null : _dashEquality.hash(dash),
    dashPhase,
    cap,
    join,
    miterLimit,
    scaleWithGeometry,
    hairlineFloor,
  );

  @override
  String toString() =>
      'Stroke(argb: 0x${argb.toRadixString(16)}, widthPt: $widthPt, '
      'dash: $dash, dashPhase: $dashPhase, cap: $cap, join: $join, '
      'miterLimit: $miterLimit, scaleWithGeometry: $scaleWithGeometry, '
      'hairlineFloor: $hairlineFloor)';
}

/// An immediate-mode fill style. Minimal by design (§7.3): flat fills
/// only, no gradients/shadows/blurs/blend modes (CR-088 deletes
/// `RendererCaps` precisely so there is only ever this one shape).
@immutable
final class Fill {
  const Fill(this.argb);

  /// Packed 0xAARRGGBB colour.
  final int argb;

  @override
  bool operator ==(Object other) => other is Fill && other.argb == argb;

  @override
  int get hashCode => argb.hashCode;

  @override
  String toString() => 'Fill(0x${argb.toRadixString(16)})';
}

/// A uniform corner radius pair for `drawRoundRect`: [rv] (vertical) and
/// [rh] (horizontal), matching the real `PdfGraphics.drawRRect(x, y, w, h,
/// rv, rh)` primitive this ultimately lowers to.
///
/// Per-corner radii are NOT supported: the underlying `PdfGraphics`
/// primitive has no per-corner radius parameter, and this project's
/// visual language is flat rectangular sheet furniture only, so a single
/// uniform radius pair (shared by all four corners) is sufficient.
@immutable
final class Radii {
  const Radii(this.rv, this.rh);

  const Radii.circular(double r) : rv = r, rh = r;

  final double rv;
  final double rh;

  @override
  bool operator ==(Object other) =>
      other is Radii && other.rv == rv && other.rh == rh;

  @override
  int get hashCode => Object.hash(rv, rh);

  @override
  String toString() => 'Radii(rv: $rv, rh: $rh)';
}
