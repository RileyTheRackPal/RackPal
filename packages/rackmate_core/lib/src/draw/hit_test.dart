// rackmate_core/src/draw/hit_test.dart — pure Dart, Flutter-free.
//
// The GEOMETRIC half of hit-testing (docs/03-architecture.md §7.4, CR-084):
// a point → nearest `HitRegion` query over a `DiagramScene`'s `hits`. The
// POINTER PLUMBING half (one query per frame, spatial hash, cursor policy,
// hover throttle) lives in `rackmate_ui/canvas/`; this stays pure so the
// future read-only mobile shell can reuse it verbatim (§7.4's explicit
// reason for putting it in core).
//
// Two rulings from §7.4 shape this file:
//   * "Return the *nearest* hit, not the first." First-hit picks
//     arbitrarily among overlapping/adjacent regions and "feels broken".
//     So this ranks candidates by distance rather than returning on the
//     first list match.
//   * "Brute force plus an AABB reject" is the right algorithm at this
//     scale (10³ regions, not 10⁵) — no R-tree, no spatial hash until a
//     hover timeline says otherwise. This is that brute-force pass.
//
// M1 SCOPE: every `HitRegion` is a device-body rect (no wire segments yet —
// those arrive with the schematic canvas in M2, ops.dart's `HitRegion`
// note). "Nearest" therefore only bites for overlapping or adjacent
// devices (e.g. a transient overlap mid-drag, or a near-miss click
// resolved by [tolerance] between two stacked devices); it is implemented
// correctly regardless, because this is permanent infrastructure.

import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/draw/ops.dart';

/// Returns the [HitRegion] in [scene] nearest to [point], or `null` if no
/// region is within [tolerance] of it.
///
/// A region qualifies when [point] lies inside its bounds OR within
/// [tolerance] (diagram units) of the bounds' edge — so `tolerance == 0`
/// (the default) means strict containment. Among qualifiers the nearest
/// wins: ranked first by edge distance (0 for any region that contains the
/// point), then — to break ties when the point is inside several
/// overlapping regions — by distance to the region's centre, so the
/// device the cursor is most centred on is chosen. Ties beyond that are
/// broken by list order for determinism.
///
/// Pure and synchronous (no Flutter, no allocation beyond locals) — driven
/// directly by `dart test`.
HitRegion? hitTest(DiagramScene scene, DPt point, {double tolerance = 0}) =>
    hitTestRegions(scene.hits, point, tolerance: tolerance);

/// The list-level core of [hitTest], split out so callers holding a bare
/// `List<HitRegion>` (or a future spatial-hash bucket) can reuse the exact
/// same nearest-hit ranking without a whole `DiagramScene`.
HitRegion? hitTestRegions(
  List<HitRegion> regions,
  DPt point, {
  double tolerance = 0,
}) {
  final tolSq = tolerance * tolerance;

  HitRegion? best;
  var bestEdgeSq = double.infinity;
  var bestCentreSq = double.infinity;

  for (final region in regions) {
    final edgeSq = _distanceSqToBox(region.bounds, point);
    // AABB reject (§7.4): anything farther than the tolerance from the box
    // cannot qualify. Kills ~95% of candidates before the finer ranking.
    if (edgeSq > tolSq) continue;

    final centreSq = _distanceSqToCentre(region.bounds, point);
    // Strictly-less comparisons keep the FIRST region at each minimum, so
    // equal-distance ties fall back to list order (deterministic).
    if (edgeSq < bestEdgeSq ||
        (edgeSq == bestEdgeSq && centreSq < bestCentreSq)) {
      best = region;
      bestEdgeSq = edgeSq;
      bestCentreSq = centreSq;
    }
  }
  return best;
}

/// Squared Euclidean distance from [p] to the nearest point of [b] — `0`
/// when [p] is inside [b]. Squared to avoid a `sqrt` in the hot loop; only
/// compared against other squared distances, never surfaced.
double _distanceSqToBox(DBox b, DPt p) {
  final dx = p.x < b.left
      ? b.left - p.x
      : (p.x > b.right ? p.x - b.right : 0.0);
  final dy = p.y < b.top
      ? b.top - p.y
      : (p.y > b.bottom ? p.y - b.bottom : 0.0);
  return dx * dx + dy * dy;
}

/// Squared distance from [p] to the centre of [b] — the tie-breaker when a
/// point sits inside several overlapping regions at once.
double _distanceSqToCentre(DBox b, DPt p) {
  final cx = (b.left + b.right) / 2;
  final cy = (b.top + b.bottom) / 2;
  final dx = p.x - cx;
  final dy = p.y - cy;
  return dx * dx + dy * dy;
}
