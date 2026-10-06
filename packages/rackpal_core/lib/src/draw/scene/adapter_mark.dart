// The in-line adapter's mark (DR-235 §11.234.5, `#1001`).
//
// ═══════════════════════════════════════════════════════════════════════
// ONE SHAPE, DRAWN BY EVERY RENDERING OF A CABLE
// ═══════════════════════════════════════════════════════════════════════
// A cable carrying a declared adapter draws the mark on each pennant of
// its net-label pair (on the leader, between pin and flag) and at the
// midpoint of a drawn wire, on screen and on the interconnect sheets. The
// user chose both renderings over docs/05 §12's "on the wire" alone,
// because DR-001's default rendering is the labels and a mark on the wire
// only would almost never be seen. Each pennant, because the model does not
// record which end an adapter sits at.
//
// ═══════════════════════════════════════════════════════════════════════
// A BOWTIE, BECAUSE THE LOZENGE WAS ALREADY A FAMILY
// ═══════════════════════════════════════════════════════════════════════
// DR-235 first ruled a lozenge. Building it found four families (Dante,
// AES67, AVB, TOSLINK) whose glyph is a hollow diamond, drawn inside the
// pennant a few millimetres from where the lozenge would sit on the
// leader: two identical marks meaning two different things on one label.
// The user chose a bowtie, two triangles tip to tip across the cable (two
// different ends meeting), which no family glyph uses (§11.234.6).
//
// ORIENTED ALONG THE CABLE, so the line runs into one tip and out of the
// other. ONE FUNCTION, so the label layer, the wire layer and the legend
// sample cannot draw three different marks.
//
// THE CABLE'S HUE AND WEIGHT, SOLID, OVER THE OPAQUE SURFACE. The fill is
// the surface a mark sits on (`bodyFill`), so the mark masks the line
// under it the way a pennant does and reads as a part on the cable rather
// than a kink in it. The outline takes the cable's colour and weight but
// not its dash: a dashed outline round a shape this small reads as broken.
// Hue is never the only cue (DR-090): the shape is the cue.
import 'dart:math' as math;

import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/path.dart';
import 'package:rackpal_core/src/draw/scene/signal_style.dart';
import 'package:rackpal_core/src/draw/spec.dart';

/// Half the mark's length along the cable, and half its height across it,
/// in grid units: a quarter of the default 3 gu leader, so it sits inside
/// the leader with room either side.
const double kAdapterMarkHalfGu = 0.75;

/// The bowtie centred on [centre], [half] units from centre to each base,
/// its tips meeting at [centre] and its bases across the cable.
/// [horizontal] is the cable's direction there.
OpPath adapterMarkOp(
  DPt centre, {
  required double half,
  required bool horizontal,
  required SignalStyle signal,
  required int fillArgb,
}) {
  final x = centre.x;
  final y = centre.y;
  final h = half;
  // The outline runs base, centre, base, base, centre, base: one closed
  // figure that touches itself at the tips, so fill and stroke both apply
  // to both triangles in one op.
  final points = horizontal
      ? <DPt>[
          DPt(x - h, y - h),
          DPt(x, y),
          DPt(x + h, y - h),
          DPt(x + h, y + h),
          DPt(x, y),
          DPt(x - h, y + h),
        ]
      : <DPt>[
          DPt(x - h, y - h),
          DPt(x, y),
          DPt(x - h, y + h),
          DPt(x + h, y + h),
          DPt(x, y),
          DPt(x + h, y - h),
        ];
  return OpPath(
    DiagramPath([
      MoveTo(points.first.x, points.first.y),
      for (final p in points.skip(1)) LineTo(p.x, p.y),
      const ClosePath(),
    ]),
    fill: Fill(fillArgb),
    stroke: Stroke(
      argb: signal.argb,
      widthPt: signal.widthPt,
      // The two CR-082 knobs, decided together, as `draw_source_gate_test`
      // requires of every stroke: a mark on a cable scales with the cable.
      // ignore: avoid_redundant_argument_values
      scaleWithGeometry: true,
      // And takes the signal floor, not the furniture one; explicit for the
      // same reason.
      // ignore: avoid_redundant_argument_values
      hairlineFloor: false,
    ),
  );
}

/// The mark's box, for a layer's ink bounds.
DBox adapterMarkBox(DPt centre, double half, double strokeWidth) =>
    DBox.fromLtwh(
      centre.x - half,
      centre.y - half,
      half * 2,
      half * 2,
    ).inflate(strokeWidth / 2);

/// The point halfway along [points] by length, and whether the segment it
/// falls on runs horizontally: where a drawn wire's mark sits, and which
/// way it faces. The first point, horizontal, for a polyline with no
/// length.
({DPt at, bool horizontal}) polylineMidpoint(List<DPt> points) =>
    polylinePointAt(points, 0.5);

/// The point [fraction] of the way along [points] by length (0 is the
/// start, 1 the end), and whether its segment runs horizontally. A cable
/// that branches (DR-236) puts its junction at the middle and its adapter
/// mark at a quarter, so the two never sit on one point.
({DPt at, bool horizontal}) polylinePointAt(
  List<DPt> points,
  double fraction,
) {
  if (points.length < 2) return (at: points.first, horizontal: true);
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += _len(points[i - 1], points[i]);
  }
  if (total == 0) return (at: points.first, horizontal: true);
  var left = total * fraction.clamp(0.0, 1.0);
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final step = _len(a, b);
    if (left <= step && step > 0) {
      final t = left / step;
      return (
        at: DPt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t),
        horizontal: (b.x - a.x).abs() >= (b.y - a.y).abs(),
      );
    }
    left -= step;
  }
  final a = points[points.length - 2];
  final b = points.last;
  return (at: b, horizontal: (b.x - a.x).abs() >= (b.y - a.y).abs());
}

double _len(DPt a, DPt b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  return math.sqrt(dx * dx + dy * dy);
}
