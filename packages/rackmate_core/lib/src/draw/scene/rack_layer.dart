// rackmate_core/src/draw/scene/rack_layer.dart — pure Dart.
//
// Builds the rack CHASSIS fragment (docs/03-architecture.md §7.2 layer L1):
// the enclosure frame, the two rails, the U-boundary division lines and the
// RU ruler. All in ABSOLUTE diagram-space coordinates with the rack's
// top-left at the scene origin, so this fragment replays directly (no
// per-fragment translate) as the canvas background.
//
// SCOPE, stated honestly (this stage's task brief). What is faithful here:
// the RU ruler (one figure per U, right-aligned, bolder every 5th — docs/04
// §2.1), the U-boundary division lines (30% / 60% opacity, bolder every
// 5th), and the two LOD tiers below 0.75 zoom. What is DEFERRED and drawn
// as a flat placeholder, not silently omitted:
//   * real hole geometry and ear screws (docs/04 §2.1 ≥0.75 tier) — rails
//     are a flat fill at every tier here;
//   * the "dotted rail texture" of the 0.40–0.74 tier — also a flat fill;
//   * rear-mirroring and the "NOT MIRRORED" chip (docs/04 §2.2).

import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/draw/ops.dart';
import 'package:rackmate_core/src/draw/scene/rack_geometry.dart';
import 'package:rackmate_core/src/draw/scene/rack_style.dart';
import 'package:rackmate_core/src/draw/spec.dart';
import 'package:rackmate_core/src/draw/text.dart';
import 'package:rackmate_core/src/model/enums.dart' show RuNumbering;
import 'package:rackmate_core/src/model/rack.dart';

/// The result of building one scene layer: its ops plus the smallest text
/// size it actually emitted (`double.infinity` when it drew no text), which
/// scene_builder folds into `DiagramScene.minTextSizePt`.
typedef LayerBuild = ({List<DiagramOp> ops, double minTextPt});

/// Builds the chassis fragment for [rack] using [geo], at [lod].
///
/// [measurer] is accepted per the fixed scene-builder signature
/// (AC-016/#13's "lodLevel explicit everywhere" companion — every builder
/// takes the injected measurer even when, as here, anchor-based right
/// alignment means no explicit width measurement is needed).
LayerBuild buildRackLayer(
  Rack rack,
  RackGeometry geo,
  TextMeasurer measurer,
  LodLevel lod,
  RackPalette palette,
) {
  final ops = <DiagramOp>[];
  var emittedText = false;

  final rackHeight = geo.rackHeight;
  final rackWidth = geo.rackWidth;

  // ── enclosure frame (around the mounting panel, ruler excluded) ──────
  ops.add(
    OpRect(
      DBox.fromLtwh(
        geo.railLeft,
        0,
        rackWidth - geo.railLeft,
        rackHeight,
      ),
      stroke: Stroke(argb: palette.frame, widthPt: 1.2),
    ),
  );

  // ── rails: flat fill (+ outline at ≥ badge). Holes/ear screws deferred.
  final railStroke = lod == LodLevel.block
      ? null
      : Stroke(argb: palette.railStroke, widthPt: 0.6);
  final railFill = Fill(palette.rail);
  ops
    ..add(
      OpRect(
        DBox.fromLtwh(geo.railLeft, 0, RackGeometry.railWidth, rackHeight),
        fill: railFill,
        stroke: railStroke,
      ),
    )
    ..add(
      OpRect(
        DBox.fromLtwh(geo.rightRailLeft, 0, RackGeometry.railWidth, rackHeight),
        fill: railFill,
        stroke: railStroke,
      ),
    );

  // ── U-boundary division lines (interior boundaries k = 1..heightU-1) ──
  final minorStroke = Stroke(argb: palette.divisionMinor, widthPt: 0.5);
  final majorStroke = Stroke(argb: palette.divisionMajor, widthPt: 0.8);
  for (var k = 1; k < geo.heightU; k++) {
    final isMajor = k % 5 == 0;
    // block LOD drops the minor lines as illegible clutter.
    if (lod == LodLevel.block && !isMajor) continue;
    final y = geo.yOfBoundary(k);
    ops.add(
      OpLine(
        DPt(geo.railLeft, y),
        DPt(rackWidth, y),
        isMajor ? majorStroke : minorStroke,
      ),
    );
  }

  // ── RU ruler: one figure per U, right-aligned, bolder every 5th ──────
  for (var ruIndex = 1; ruIndex <= geo.heightU; ruIndex++) {
    final isMajor = ruIndex % 5 == 0;
    if (lod == LodLevel.block && !isMajor) continue;
    final label = _displayNumber(ruIndex, geo.heightU, rack.ruNumbering);
    final centerY = (geo.yTopOfU(ruIndex) + geo.yBottomOfU(ruIndex)) / 2;
    ops.add(
      OpText(
        '$label',
        DPt(RackGeometry.rulerWidth - 4, centerY),
        rackText(
          RackTextSizes.ruler,
          isMajor ? palette.rulerTextMajor : palette.rulerText,
          TextAnchor.midRight,
        ),
      ),
    );
    emittedText = true;
  }

  return (
    ops: ops,
    minTextPt: emittedText ? RackTextSizes.ruler : double.infinity,
  );
}

/// The DISPLAYED ruler figure for [ruIndex]. `ruIndex` is always stored
/// 1-based bottom-origin (CR-025); numbering direction is display-only
/// (CR-026), so only what the user SEES changes here — never the stored
/// index.
int _displayNumber(int ruIndex, int heightU, RuNumbering numbering) =>
    switch (numbering) {
      RuNumbering.bottomUpFromOne => ruIndex,
      RuNumbering.topDown => heightU - ruIndex + 1,
    };
