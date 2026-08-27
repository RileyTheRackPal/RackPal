// rackpal_core/src/draw/scene/rack_layer.dart — pure Dart.
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
//   * the "dotted rail texture" of the 0.40–0.74 tier — also a flat fill.
//
// THE RU RULER ON BOTH EDGES (docs/08 §2.2). [buildRackLayer]'s
// `dualRuler` draws a second ruler column to the RIGHT of the panel,
// numbered from the same `_displayNumber` as the left one — so
// `Rack.ruNumbering` (CR-026, display-only) governs both edges and they
// cannot disagree. It is OFF by default: §2.2 is a requirement about the
// PDF sheet, and the elevation sheet builder is what turns it on. The
// screen keeps one edge, which is what docs/04 §2.1 describes.
//
// The right column is drawn OUTSIDE `RackGeometry.rackWidth` deliberately.
// `rackWidth` is the chassis box that the rack's own layout and the
// editing overlays are built on; growing it to accommodate an annotation
// gutter would move every one of those. The column's ink instead reaches
// `DiagramScene.bounds` through `inkBounds`, which is what the sheet's
// scale-to-fit reads, so the ruler is measured for fit without being part
// of the rack.
//
// REAR MIRRORING now exists — in `RackGeometry.deviceRect`, where it is a
// layout reflection rather than a canvas flip. See that method.

import 'package:rackpal_core/src/draw/bounds_canvas.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/rack_geometry.dart';
import 'package:rackpal_core/src/draw/scene/rack_style.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/enums.dart' show RuNumbering;
import 'package:rackpal_core/src/model/rack.dart';

/// The result of building one scene layer: its ops, the smallest text size
/// it actually emitted (`double.infinity` when it drew no text, folded into
/// `DiagramScene.minTextSizePt`), and the layer's INK BOUNDS.
///
/// `inkBounds` is the box the layer's ops actually cover, in the layer's own
/// coordinate space (LOCAL for device/symbol fragments, absolute for the
/// chassis), or `null` when the layer drew nothing. It is a field rather
/// than something a caller re-derives from a layout rect because a layer is
/// NOT obliged to stay inside the rect it was sized to: `device_layer`
/// happens to, `symbol_layer` deliberately does not — its pins straddle the
/// body edge and its top/bottom labels sit outside it entirely. A caller
/// unioning layout rects alone therefore computes a `DiagramScene.bounds`
/// that is too small, and `bounds` is what drives PDF scale-to-fit
/// (ops.dart, "-> scale-to-fit, tile counts"), so "too small" means
/// "clipped on the page". Every builder fills this in from
/// [inkBoundsOf] — measured from the ops it emitted, never hand-maintained.
typedef LayerBuild = ({List<DiagramOp> ops, double minTextPt, DBox? inkBounds});

/// Builds the chassis fragment for [rack] using [geo], at [lod].
///
/// [measurer] is accepted per the fixed scene-builder signature
/// (AC-016/#13's "lodLevel explicit everywhere" companion — every builder
/// takes the injected measurer even when, as here, anchor-based right
/// alignment means no explicit width measurement is needed).
///
/// [dualRuler] adds the right-hand RU column docs/08 §2.2 requires of the
/// elevation SHEETS; [typeScale] inflates the ruler figures so they clear
/// §6.2's print floor at a reduced drawing scale. Both default to the
/// screen's behaviour — see the file header.
LayerBuild buildRackLayer(
  Rack rack,
  RackGeometry geo,
  TextMeasurer measurer,
  LodLevel lod,
  RackPalette palette, {
  bool dualRuler = false,
  RackTypeScale typeScale = const RackTypeScale.identity(),
}) {
  final ops = <DiagramOp>[];
  var emittedText = false;
  final rulerSize = typeScale.size(RackTextSizes.ruler);

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
    // ONE `_displayNumber` FOR BOTH EDGES. `Rack.ruNumbering` is
    // display-only (CR-026); two edges numbered by two expressions is two
    // chances for one of them to be the stored index.
    final label = _displayNumber(ruIndex, geo.heightU, rack.ruNumbering);
    final centerY = (geo.yTopOfU(ruIndex) + geo.yBottomOfU(ruIndex)) / 2;
    final argb = isMajor ? palette.rulerTextMajor : palette.rulerText;
    ops.add(
      OpText(
        '$label',
        DPt(RackGeometry.rulerWidth - 4, centerY),
        rackText(rulerSize, argb, TextAnchor.midRight),
      ),
    );
    if (dualRuler) {
      ops.add(
        OpText(
          '$label',
          DPt(rackWidth + 4, centerY),
          rackText(rulerSize, argb, TextAnchor.midLeft),
        ),
      );
    }
    emittedText = true;
  }

  return (
    ops: ops,
    minTextPt: emittedText ? rulerSize : double.infinity,
    inkBounds: inkBoundsOf(ops, measurer: measurer),
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
