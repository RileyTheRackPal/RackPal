// rackpal_core/src/draw/marquee.dart — CR-102's band, as geometry
// (DR-139 §11.138, PLAN-E/6).
//
// ═══════════════════════════════════════════════════════════════════════
// THE PRODUCT'S FIRST MARQUEE, AND CR-102 HAS RULED IT SINCE M0
// ═══════════════════════════════════════════════════════════════════════
// `PLAN-E/1` went looking for the machinery docs/15 §6 promised the Plan
// editor and found the row vacuous: it said marquee-select was "identical
// to the other two canvases" and **neither of the other two has one**.
// Censused by MECHANISM rather than by the word, which is what made it
// visible: every `SelectMode` call in `lib/` passes exactly one id, so
// `SelectionController`'s `Set<Uuid>` has never held more than one thing
// except through `Ctrl`+click.
//
// DR-139 rules it built ONCE and adopted on all three canvases, which is
// what CR-102's own content requires: a ruling whose whole point is that
// the gesture is uniform across views cannot be honoured by three separate
// implementations.
//
// ═══════════════════════════════════════════════════════════════════════
// PURE, AND IN CORE, FOR THE REASON `hit_test.dart` IS
// ═══════════════════════════════════════════════════════════════════════
// This is the geometric half. The pointer plumbing (when a drag becomes a
// band, what it looks like, when it commits) is `rackpal_ui`'s, and the
// band is SCREEN CHROME there and never a scene op: `buildRackScene` feeds
// the PDF as well as the display (CR-086), so a band added to the scene
// would print.
//
// ═══════════════════════════════════════════════════════════════════════
// THE `partKey` FILTER IS THE PART THAT WOULD HAVE BEEN WRONG
// ═══════════════════════════════════════════════════════════════════════
// A schematic symbol contributes ONE `HitRegion` per port, each carrying
// the symbol's `entityId` and a `partKey`, plus one for the body with no
// `partKey` (`symbol_hit_test.dart`). A band tested against every region
// would therefore select a whole device because it clipped **one pin** of
// it, in WINDOW mode, where that device's body is nowhere near contained.
//
// So only the entity's own box counts, and `partKey == null` is exactly
// that box. The rack elevation and the plan emit one region per entity and
// no parts, so the filter is a no-op there and the schematic is the case
// that needed it.
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';

/// The CAD convention CR-102 names, decided by the drag's direction.
enum MarqueeMode {
  /// Left to right: **fully contained**, drawn solid.
  window,

  /// Right to left: **intersecting**, drawn dashed.
  cross,
}

/// Which convention a drag from [from] to [to] is running.
///
/// ═══════════════════════════════════════════════════════════════════════
/// HORIZONTAL DIRECTION ONLY, AND A ZERO-WIDTH DRAG IS A WINDOW
/// ═══════════════════════════════════════════════════════════════════════
/// Every CAD package this convention comes from reads the X direction and
/// ignores Y, so a drag up-and-right and one down-and-right are the same
/// gesture. A drag with `to.x == from.x` has no direction to read; it is
/// called `window`, which is the stricter of the two, because a band with
/// no width selects nothing under either rule and a user who then widens
/// it rightwards must not see the mode flip under them.
MarqueeMode marqueeModeFor(DPt from, DPt to) =>
    to.x >= from.x ? MarqueeMode.window : MarqueeMode.cross;

/// The band, normalised so it is a real box whichever way it was dragged.
///
/// `DBox.fromCorners` ALREADY DOES THIS and a first draft wrote the four
/// comparisons out again. It exists for exactly this: two arbitrary
/// corners in, a normalised box out.
DBox marqueeBand(DPt from, DPt to) => DBox.fromCorners(from, to);

/// True when [band] wholly encloses [box].
///
/// NOT ON `DBox`, deliberately. `DBox.contains` takes a POINT and every
/// call site in this repo means that; adding a same-named overload for a
/// box is how somebody reads `contains` at a glance and gets the other
/// one. The name says which relation it is and which way round.
bool bandContainsBox(DBox band, DBox box) =>
    box.left >= band.left &&
    box.right <= band.right &&
    box.top >= band.top &&
    box.bottom <= band.bottom;

/// Every entity a band from [from] to [to] catches, over bare [regions],
/// in a total order.
///
/// IDS, DEDUPED, SORTED, AND THE SORT IS NOT TIDINESS. One entity may
/// contribute several regions and a `Set`'s iteration order follows the
/// scene's, which follows a `Map` whose order differs between a freshly
/// built document and the same one reopened from disk. Anything that
/// compares two selections, or writes one into a golden, needs this list
/// to be the same list both times. (This took over from a scene-level
/// `marqueeSelection` wrapper that nothing called; `#945` deleted it and
/// moved its reasoning here, where the rule lives.)
List<String> marqueeSelectionIn(
  List<HitRegion> regions,
  DPt from,
  DPt to,
) {
  final band = marqueeBand(from, to);
  final window = marqueeModeFor(from, to) == MarqueeMode.window;
  final caught = <String>{};
  for (final region in regions) {
    // See the header: a part is not a thing this selection can hold.
    if (region.partKey != null) continue;
    final hit = window
        ? bandContainsBox(band, region.bounds)
        : band.intersects(region.bounds);
    if (hit) caught.add(region.entityId);
  }
  return caught.toList()..sort();
}
