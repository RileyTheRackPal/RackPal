// rackpal_core/src/draw/scene/rack_geometry.dart — pure Dart.
//
// The ONE place that turns the model's integer, RU-index rack geometry
// (docs/04-rack-editor.md §2) into the drawing IR's double diagram-space
// geometry (`DPt`/`DBox`, 1 unit = 1 PDF point at zoom 1.0). CR-006:
// elevation X/Y is NEVER stored — it is always derived here from
// `(Placement, rail geometry, face)`. Keeping every unit conversion in this
// one helper (used by rack_layer/device_layer/scene_builder) is what stops
// RU math leaking into rackpal_ui.
//
// THE SCALE CHOICE, stated once (this stage's task brief, docs/04 §2.1).
// docs/04 says "Screen geometry at zoom 1.0 is 1U = 22 px, panel width
// 239 px", framed as pixels at 100% zoom. Under CR-007 the DiagramCanvas
// boundary is resolution-independent diagram units where 1 unit = 1 PDF
// point, and "at zoom 1.0 the two coincide" — so we take **22 diagram
// units per RU** as the single scale anchor and DERIVE everything
// length-based from it through one factor, `_unitsPerNm = unitsPerRu /
// kRackUnit.nm`. That means the RU height, the panel width and any device
// depth all scale from the SAME kRackUnit-tied factor and can never drift
// apart (the brief's explicit instruction: "derive it, do not hardcode a
// second unrelated constant that could drift from kRackUnit").
//
// ONE width is deliberately NOT physical: the RU ruler column (28) is
// fixed chrome, exactly as docs/04 states it as fixed px. It sits OUTSIDE
// the mounting panel and is a dimensionless annotation gutter, so nothing
// a reader would scale off depends on it.
//
// THE RAIL WIDTH USED TO BE THE SAME KIND OF CHROME, AND IT WAS NOT
// HARMLESS. docs/04 §2.1 states "20 px each at z1.0" and this file
// honoured that literally. But a rail sits INSIDE the 19 in panel, so
// [openingWidth] — and therefore every full-width device body — was
// derived from it: 238.9 − 2·20 = 198.9 units, which is 15.82 in of
// equivalent, against a real EIA-19 clear opening of 17.75 in. Every
// device on the sheet was 11% narrow horizontally while the vertical axis
// and the overall panel width were exact, and the PDF exporter's whole
// claim is that its elevations are "dimensionally correct against a
// physical tape measure at true scale".
//
// So [railWidth] is now DERIVED from the real 0.625 in rail flange, which
// makes 19 − 2·0.625 = 17.75 in fall out exactly. **This is a stated
// deviation from docs/04 §2.1's "20 px"**: rails render ≈7.86 units wide
// at zoom 1.0 instead of 20, i.e. visibly thinner on screen — and
// proportionally correct, since a real flange is 3.3% of the panel width
// and 20 units was 8.4%. Recorded in docs/m1-implementation-log.md rather
// than left to be discovered by someone measuring a printout.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/units/constants.dart';
import 'package:rackpal_core/src/units/len.dart';

/// The four level-of-detail tiers from docs/04-rack-editor.md §2.1. Passed
/// EXPLICITLY into every scene-builder signature (AC-016/#13) — a builder
/// never infers it from a live zoom, so a cached fragment can never return
/// the wrong LOD after a zoom change.
enum LodLevel {
  /// zoom < 0.40 — solid block, designator only if it fits.
  block,

  /// 0.40–0.74 — designator + U-height badge.
  badge,

  /// 0.75–1.49 — designator + name + type.
  full,

  /// ≥ 1.50 — adds rear port strip / microtext (not built this stage).
  detail;

  /// Maps a viewport zoom factor to its tier, per the docs/04 §2.1 table.
  /// Lives here (not in rackpal_ui) so the thresholds are one source of
  /// truth shared by the screen and any headless caller.
  static LodLevel forScale(double scale) {
    if (scale < 0.40) return LodLevel.block;
    if (scale < 0.75) return LodLevel.badge;
    if (scale < 1.50) return LodLevel.full;
    return LodLevel.detail;
  }
}

/// Derived diagram-space geometry for one rack of a given [heightU].
///
/// Coordinates: the rack's top-left is the scene origin `(0, 0)`; X grows
/// right, Y grows DOWN (the `DPt`/`ui.Canvas` sense — see
/// `draw/geometry.dart`). Vertical positions come from `ruIndex`, which is
/// 1-based with a BOTTOM origin always (CR-025), so U1 sits at the bottom
/// and U[heightU] at the top.
@immutable
final class RackGeometry {
  const RackGeometry(this.heightU);

  /// The number of U in the rack (`Rack.heightU`, 1..60 — CR-038).
  final int heightU;

  // ── the scale anchor and the one derived factor ──────────────────────

  /// Diagram units per rack unit at zoom 1.0 (docs/04 §2.1). The single
  /// anchor everything length-based derives from.
  static const double unitsPerRu = 22;

  /// Diagram units per nanometre — derived from [unitsPerRu] and
  /// `kRackUnit` so there is exactly one scale in the system. Any `Len`
  /// converts through [unitsForLen]; nothing introduces a second factor.
  static double get _unitsPerNm => unitsPerRu / kRackUnit.nm;

  /// Converts a physical [Len] to diagram units on the one shared scale.
  /// By construction `unitsForLen(kRackUnit) == unitsPerRu` (asserted by a
  /// unit test), which is the "no drift" guarantee.
  static double unitsForLen(Len l) => l.nm * _unitsPerNm;

  // ── fixed chrome width (docs/04 §2.1, stated as fixed px) ────────────

  /// RU ruler column, left of the left rail (docs/04: "28 px").
  ///
  /// The ONE remaining non-physical width, and it is outside the panel —
  /// see the file header.
  static const double rulerWidth = 28;

  // ── the physically-derived widths ────────────────────────────────────

  /// EIA-19 panel width (19 in = 482.6 mm) in the model's exact nanometres.
  static const Len _eia19PanelWidth = Len(482_600_000);

  /// EIA-19 rail flange width — 0.625 in = 15.875 mm, exactly.
  ///
  /// The figure that makes `19 − 2 × 0.625 = 17.75` in, the standard clear
  /// opening, fall out of [openingWidth] rather than being asserted
  /// separately.
  static const Len _eia19RailFlange = Len(15_875_000);

  /// Each rail, DERIVED from the real flange width — ≈7.86 units at zoom
  /// 1.0, not docs/04's "20 px". See the file header for why that changed
  /// and what it cost.
  static double get railWidth => unitsForLen(_eia19RailFlange);

  /// Full mounting-panel width (rail + opening + rail), derived from the
  /// real EIA-19 width so it stays tied to kRackUnit. ≈ 238.9 units, i.e.
  /// docs/04's "panel width 239 px".
  ///
  /// SCOPE NOTE: only the EIA-19 width class is honoured this stage;
  /// `RackWidthClass.{eia23,tenInch,etsi,customWidth}` (rack.dart) all draw
  /// at EIA-19 geometry for now — a deliberate, flagged cut, not a silent
  /// one.
  static double get panelWidth => unitsForLen(_eia19PanelWidth);

  /// Clear opening between the rails — where a full-width device body sits.
  static double get openingWidth => panelWidth - 2 * railWidth;

  // ── instance geometry ────────────────────────────────────────────────

  /// Total rack height in diagram units.
  double get rackHeight => heightU * unitsPerRu;

  /// Total rack width (ruler + panel).
  double get rackWidth => rulerWidth + panelWidth;

  /// X of the left rail's left edge.
  double get railLeft => rulerWidth;

  /// X of the clear opening's left edge (where twelfth 0 starts).
  double get openingLeft => rulerWidth + railWidth;

  /// X of the right rail's left edge.
  double get rightRailLeft => openingLeft + openingWidth;

  /// Y of the TOP boundary of the U at [ruIndex] (1-based, bottom origin).
  /// `yTopOfU(heightU)` is 0 (topmost U's top edge is the rack top).
  double yTopOfU(int ruIndex) => (heightU - ruIndex) * unitsPerRu;

  /// Y of the BOTTOM boundary of the U at [ruIndex].
  double yBottomOfU(int ruIndex) => (heightU - ruIndex + 1) * unitsPerRu;

  /// Y of the k-th horizontal U boundary counted from the bottom
  /// (`k ∈ [0, heightU]`): k=0 is U1's bottom edge (`= rackHeight`),
  /// k=heightU is the rack's top edge (`= 0`).
  double yOfBoundary(int k) => (heightU - k) * unitsPerRu;

  /// The absolute diagram-space rect of a device that occupies [deviceH]
  /// U's starting (at its lowest U) at [ruIndex], laterally spanning
  /// [spanTwelfths] twelfths from [startTwelfth] (CR-030). The device's
  /// highest U is `ruIndex + deviceH - 1`.
  ///
  /// ── REAR MIRRORING (docs/04 §2.2, CR-035) ───────────────────────────
  /// [mirrored] reflects the lateral span about the opening's centre, so a
  /// half-width device at the LEFT of the front elevation appears at the
  /// RIGHT of the rear one — which is what a technician standing behind
  /// the rack actually sees.
  ///
  /// IT IS A LAYOUT REFLECTION, NOT A CANVAS `scale(-1, 1)`, and that is
  /// the whole design. A negative X scale on the canvas would mirror the
  /// GLYPHS too: every designator, name and model string on the rear sheet
  /// would print backwards. The reflection therefore happens here, in the
  /// geometry, where only rectangles move — and `rack_mirror_test.dart`
  /// asserts that no `OpTransform` in a mirrored scene carries a negative
  /// X scale, so the cheap wrong fix cannot be reintroduced by accident.
  ///
  /// Reflecting the SPAN rather than the rect keeps it exact in integer
  /// twelfths: `mirroredStart = 12 − startTwelfth − spanTwelfths`. A
  /// full-width device (start 0, span 12) is therefore unchanged, and
  /// mirroring twice is the identity.
  DBox deviceRect(
    int ruIndex,
    int deviceH, {
    int startTwelfth = 0,
    int spanTwelfths = 12,
    bool mirrored = false,
  }) {
    final top = yTopOfU(ruIndex + deviceH - 1);
    final bottom = yBottomOfU(ruIndex);
    final start = mirrored ? 12 - startTwelfth - spanTwelfths : startTwelfth;
    final left = openingLeft + (start / 12) * openingWidth;
    final width = (spanTwelfths / 12) * openingWidth;
    return DBox.fromLtwh(left, top, width, bottom - top);
  }

  // ── the INVERSE conversion: scene-space Y → snapped ruIndex ──────────
  //
  // Drag-to-move needs the reverse of the forward geometry above. The task
  // brief and docs/04 §3.1 both pin the formula
  //   ruIndex = clamp(round((cursorSceneY − ghostHeight/2 − rackOriginY)
  //                          / kRackUnit), 1, heightU − heightU(device) + 1)
  // but that spelling assumes a TOP-origin index that grows downward with
  // Y. This scene is BOTTOM-origin (CR-025): U1 is at the bottom (largest
  // Y), U[heightU] at the top (Y = 0). So the honest inverse is not that
  // literal expression — it is the algebraic inverse of [deviceRect]'s own
  // top edge, which is what guarantees the two directions cannot drift
  // (round-trip tested). The clamp BOUNDS are exactly the doc's
  // `[1, heightU − deviceH + 1]`; only the sign of the Y term flips to
  // match this file's downward-Y, bottom-origin convention. `rackOriginY`
  // is 0 here — the rack's top-left is the scene origin (see the class
  // doc), so it drops out.

  /// The highest `ruIndex` a device of [deviceH] U can occupy without
  /// overflowing the rack top: `heightU − deviceH + 1`, floored at 1 so a
  /// device taller than the rack still yields a legal (if overflowing)
  /// index rather than an inverted clamp range.
  int maxRuIndexFor(int deviceH) {
    final max = heightU - deviceH + 1;
    return max < 1 ? 1 : max;
  }

  /// Given a device's TOP-edge Y in scene space and its [deviceH], the
  /// snapped, rack-clamped `ruIndex` it should occupy. Exact inverse of
  /// `yTopOfU(ruIndex + deviceH - 1)` (the top edge [deviceRect] emits), so
  /// `ruIndexForTopY(deviceRect(r, h).top, h) == r` for every valid `r`
  /// (proved by rack_geometry_test's round-trip).
  int ruIndexForTopY(double topY, int deviceH) {
    // Forward: top = (heightU − ruIndex − deviceH + 1) · unitsPerRu.
    // Solve for ruIndex, then round to the nearest U and clamp to the rack.
    final raw = (heightU - deviceH + 1) - topY / unitsPerRu;
    return raw.round().clamp(1, maxRuIndexFor(deviceH));
  }

  /// docs/04 §3.1's drag spelling, made consistent with this geometry: the
  /// cursor is treated as the vertical CENTRE of the ghost, so the ghost's
  /// top edge is `cursorSceneY − ghostHeight/2` and `ghostHeight =
  /// deviceH · unitsPerRu`. Delegates to [ruIndexForTopY] so there is still
  /// exactly ONE inverse formula — this is only the centre-offset the doc's
  /// `− ghostHeight/2` term expresses, not a second derivation.
  int ruIndexForCursorY(double cursorSceneY, int deviceH) =>
      ruIndexForTopY(cursorSceneY - (deviceH * unitsPerRu) / 2, deviceH);

  /// The rack height implied by dragging THE RACK'S OWN TOP EDGE to
  /// [topY] (docs/04-rack-editor.md §4.1's third way to change height).
  ///
  /// A genuinely different direction from [ruIndexForTopY], not a
  /// rephrasing of it: that one snaps a DEVICE's top edge and clamps to
  /// the CURRENT `heightU`, which is precisely the quantity this one is
  /// solving for — it could never express "24U (+3)". Here the rack's
  /// BOTTOM edge is fixed at `y = rackHeight` and the top edge moves, so
  /// the height is the distance between them in U. That fixed bottom is
  /// also why "growing is always safe... existing ruIndex values are
  /// untouched": U1 does not move when the top does.
  ///
  /// Bounds default to CR-038's `[1, 60]`. `topY == 0` returns the
  /// current [heightU] exactly (the identity case), and a negative
  /// [topY] — the edge dragged ABOVE the current top — grows the rack.
  int heightForTopEdgeY(
    double topY, {
    int minHeightU = 1,
    int maxHeightU = 60,
  }) => ((rackHeight - topY) / unitsPerRu).round().clamp(
    minHeightU,
    maxHeightU,
  );

  // A single-field value type with no equality is a repaint hazard the
  // moment `heightU` becomes mutable: every rebuild allocates a fresh
  // `RackGeometry`, and any `shouldRepaint` comparing `geo != old.geo`
  // would then be unconditionally true. Value equality makes those
  // comparisons mean what they read as.

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RackGeometry && other.heightU == heightU;

  @override
  int get hashCode => heightU.hashCode;

  @override
  String toString() => 'RackGeometry(${heightU}U)';
}
