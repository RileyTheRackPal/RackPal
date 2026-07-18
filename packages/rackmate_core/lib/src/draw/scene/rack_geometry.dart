// rackmate_core/src/draw/scene/rack_geometry.dart — pure Dart.
//
// The ONE place that turns the model's integer, RU-index rack geometry
// (docs/04-rack-editor.md §2) into the drawing IR's double diagram-space
// geometry (`DPt`/`DBox`, 1 unit = 1 PDF point at zoom 1.0). CR-006:
// elevation X/Y is NEVER stored — it is always derived here from
// `(Placement, rail geometry, face)`. Keeping every unit conversion in this
// one helper (used by rack_layer/device_layer/scene_builder) is what stops
// RU math leaking into rackmate_ui.
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
// Two widths are deliberately NOT physical: the RU ruler column (28) and
// each rail (20) are fixed chrome, exactly as docs/04 states them as fixed
// px — they are legibility furniture, not scaled rack metal. The panel
// width, by contrast, is derived from the real EIA-19 panel width so it
// stays honest against kRackUnit (and lands on ~238.9, matching the doc's
// "239 px").

import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/units/constants.dart';
import 'package:rackmate_core/src/units/len.dart';

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
  /// Lives here (not in rackmate_ui) so the thresholds are one source of
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

  // ── fixed chrome widths (docs/04 §2.1, stated as fixed px) ───────────

  /// RU ruler column, left of the left rail (docs/04: "28 px").
  static const double rulerWidth = 28;

  /// Each rail (docs/04: "20 px each at z1.0").
  static const double railWidth = 20;

  // ── the one physically-derived width ─────────────────────────────────

  /// EIA-19 panel width (19 in = 482.6 mm) in the model's exact nanometres.
  static const Len _eia19PanelWidth = Len(482_600_000);

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
  DBox deviceRect(
    int ruIndex,
    int deviceH, {
    int startTwelfth = 0,
    int spanTwelfths = 12,
  }) {
    final top = yTopOfU(ruIndex + deviceH - 1);
    final bottom = yBottomOfU(ruIndex);
    final left = openingLeft + (startTwelfth / 12) * openingWidth;
    final width = (spanTwelfths / 12) * openingWidth;
    return DBox.fromLtwh(left, top, width, bottom - top);
  }
}
