// rackpal_core/src/units/px_pt.dart — image-pixel space.
//
// THE THIRD POINT TYPE, DELIBERATELY (docs/15 §3.3, DR-037 §11.36).
// It is not `Pt` (integer 2.5 mm schematic grid units, CR-004) and it is
// not `DPt` (the canvas's device-independent doubles). docs/02 §4.8 warns
// against collapsing distinct concepts onto one name, and these three are
// distinct in kind rather than in units:
//
//   * `Pt`   a position on the schematic's 2.5 mm lattice. Snapped by
//            construction; there is no sub-grid.
//   * `DPt`  a position in the drawing, 1 unit = 1 PDF point, and the
//            same number means the same distance on every backend.
//   * `PxPt` a position INSIDE ONE SPECIFIC RASTER. It means nothing
//            without the image it indexes, and it means something
//            different in the same document as soon as a second underlay
//            is added.
//
// ═══════════════════════════════════════════════════════════════════════
// NAMING THEM ALIKE IS HOW A PIN ENDS UP 2.5 MM FROM WHERE IT WAS PLACED
// ═══════════════════════════════════════════════════════════════════════
// That is the failure this type exists to prevent, and it is a quiet one:
// a `Pt` accepted where a `PxPt` was meant does not throw. It rounds to
// the schematic lattice, moves the dot by up to a grid unit, and the
// person who sees it is the installer, on site, looking for a wall.
//
// So the separation is a COMPILE ERROR AND NOT A CONVENTION. There is no
// implicit conversion in either direction, no shared supertype carrying
// arithmetic, and no `operator +`: two positions in an image have no
// meaningful sum, and offering one would make the mistake spellable.
// `px_pt_separation_test.dart` fails if any of that changes.
//
// WHY IT IS NOT AN EXTENSION TYPE, unlike `Len`. `Len` wraps ONE integer
// and extension types are exactly right for that. This wraps two, so the
// erased representation would have to be a record or a list and every
// benefit is gone. `Pt` is a plain final class for the same reason.
import 'package:meta/meta.dart';

/// A position inside a specific raster, in whole image pixels.
///
/// Whole pixels because that is the resolution the underlay actually has:
/// a fractional pixel is a claim about detail the image does not carry,
/// and rounding it at write time is how a saved pin stops matching the
/// one on screen.
@immutable
final class PxPt {
  const PxPt(this.px, this.py);

  /// Distance from the image's LEFT edge, in pixels.
  final int px;

  /// Distance from the image's TOP edge, in pixels. Y-down, matching how
  /// every raster is addressed and how diagram space already works
  /// (docs/08 §7.4).
  final int py;

  @override
  bool operator ==(Object other) =>
      other is PxPt && other.px == px && other.py == py;

  @override
  int get hashCode => Object.hash(px, py);

  @override
  String toString() => 'PxPt($px, $py)';
}
