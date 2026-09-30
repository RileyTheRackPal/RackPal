// rackpal_core/src/draw/scene/device_layer.dart — pure Dart.
//
// Builds ONE device's DiagramScene fragment (docs/03-architecture.md §7.2
// layer L2, CR-086). This is exactly the fragment `RenderDeviceBox.paint`
// replays through `FlutterDiagramCanvas` — "pixels come from the shared IR;
// behaviour comes from the widget".
//
// COORDINATES: the fragment is built in the device's own LOCAL space —
// body top-left at (0, 0), extent `width × height` in diagram units. Its
// absolute position in the rack is carried separately (by the render
// object's parent data on screen, and by a wrapping translate in the
// composed scene). Building it local is what lets a device MOVE by changing
// one offset without rebuilding its ops, and matches the doc's
// RenderDeviceBox.paint snippet (a bare fragment replay).
//
// SCOPE, stated honestly (this stage's task brief): body + designator +
// name + type + the three sheet features docs/08 §2.2 asks of a device
// block — the RU span label, the `lifecycleStatus` border, and the hatch
// band that marks a blank, a vent or a shelf. DEFERRED and NOT drawn: the
// rear port strip, weight microtext, PDU outlet map, finding/lock/reversed
// badges, ⚡ amps, and the 🔗 port-count chip (docs/04 §2.1 ≥0.75 / ≥1.50
// tiers) — ports and wiring are M2's job.
//
// `DeviceOverrides` REACHES THIS FILE NOW, but only through one field.
// DR-080 makes `overrides.accentColor` the body fill, resolved ahead of
// the template's own; the type NAME is still taken straight from
// `TemplateBody.displayName` and ignores `overrides.displayName`. Two
// sentences rather than one, because "overrides are not applied here"
// stopped being true and a comment that has quietly become false is the
// thing this repository has been bitten by most.
//
// ─────────────────────────────────────────────────────────────────────────
// TEXT IS EMITTED ONLY WHEN IT FITS — AND THE DESIGNATOR IS DROPPED LAST
// ─────────────────────────────────────────────────────────────────────────
// At `LodLevel.full` the designator used to be emitted UNCONDITIONALLY
// while the name and type were each guarded by a vertical fit check. That
// was invisible while every caller drew at model scale, because a 1U body
// is 22 units and an 11-unit designator with 4 units of padding always
// fits. The PDF exporter inflates rack text (`RackTypeScale`) so it clears
// §6.2's 6.0 pt print floor, which makes "the label is taller than the
// block" reachable for the first time.
//
// THE FIRST FIX FOR THAT WAS A BLACKOUT, AND IT SHIPPED. Guarding the
// designator with `_pad + designatorPt <= height - _pad` suppressed the
// WHOLE label branch — designator, badge, name and type — for every 1U
// device on any elevation drawn at 1:10 or smaller: at 1:10 the inflated
// designator is 15.61 units and `4 + 15.61 <= 22 - 4` is false. A 58–60U
// rack is legal (kMaxRackHeightU = 60, CR-038) and picks 1:10, so a user
// could build one, export, and get elevations on which no device carried
// a designator at all — the one string that joins a block to its T6.30
// row — with nothing in the export summary saying so.
//
// So the guard is now a LADDER, dropped from the least important rung up:
//
//   1. type   — dropped first (it is also on T6.30, twice over)
//   2. name   — dropped next
//   3. the designator + RU-span badge line — dropped LAST, and only when
//      the glyphs are literally taller than the body. Its vertical PAD
//      shrinks to zero before the line is given up, because 4 units of
//      whitespace is not worth a nameless rectangle.
//
// And when even rung 3 fails, [DeviceLayerBuild.labelDropped] says so, all
// the way out to the export summary. "Never silently do nothing."

import 'dart:math' as math;

import 'package:rackpal_core/src/draw/bounds_canvas.dart';
import 'package:rackpal_core/src/draw/contrast.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/device_glyph_art.dart';
import 'package:rackpal_core/src/draw/scene/rack_geometry.dart';
import 'package:rackpal_core/src/draw/scene/rack_layer.dart' show LayerBuild;
import 'package:rackpal_core/src/draw/scene/rack_style.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/device_glyph.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/template.dart' show TemplateBody;

const double _pad = 4;

/// A [LayerBuild] plus the one thing a device fragment can silently lose.
///
/// A distinct type rather than a fourth field on `LayerBuild`, because the
/// chassis, the gutter and the symbol layer have no label to drop and a
/// record they all had to fill in with `false` would say the wrong thing
/// about them.
typedef DeviceLayerBuild = ({
  List<DiagramOp> ops,
  double minTextPt,
  DBox? inkBounds,

  /// The body was drawn with NO designator: at this drawing scale the
  /// inflated glyphs are taller than the block itself. See the file header
  /// — this is what turns a blackout into a reported omission.
  bool labelDropped,
});

/// Builds [device]'s local-coordinate fragment. [body] is the resolved
/// template body, [deviceH] the U-height on the current face, and
/// [width]/[height] the device's diagram-space extent (from
/// [RackGeometry.deviceRect]). [measurer] is used at [LodLevel.block] to
/// decide whether the designator actually fits (docs/04 §2.1: "designator
/// only if ≥ 20 px wide").
///
/// The four sheet options — all off by default, so the screen is unchanged
/// and the elevation sheet builder is what turns them on:
///
/// * [ruSpanLabel] replaces the plain `4U` badge with docs/08 §2.2's
///   `4U · 12–15`. The caller supplies it because only the scene builder
///   holds the `ruIndex` this fragment's LOCAL coordinates deliberately do
///   not.
/// * [lifecycleBorder] draws the body outline through
///   [lifecycleStroke] — dash and weight, never hue (P4).
/// * [hatched] fills the body with the 45° band docs/08 §2.2 asks for on
///   blanks, vents and shelves.
/// * [typeScale] inflates every label so it clears §6.2's print floor.
DeviceLayerBuild buildDeviceLayer(
  DeviceInstance device,
  TemplateBody body, {
  required int deviceH,
  required double width,
  required double height,
  required LodLevel lod,
  required RackPalette palette,
  required TextMeasurer measurer,
  String? ruSpanLabel,
  bool lifecycleBorder = false,
  bool hatched = false,
  RackTypeScale typeScale = const RackTypeScale.identity(),
  // A DEVICE ON A SHELF (DR-204 §11.203.4). It has no U of its own, so
  // no U badge; and an unknown shelf width is drawn HOLLOW, reading
  // `width unknown` where the type goes, which is the 0U bar's treatment
  // of an unknown length (§11.165.2) applied to the other axis.
  bool showBadge = true,
  bool widthUnknown = false,
  // A SHELF CARRYING DEVICES (DR-204 §11.203.10, `#968`): non-null means
  // it hosts something, and it is then the shelf's load line. The shelf
  // keeps ONLY its top line, designator and badge with this note between
  // them, because its hosts are drawn over the rest of its body and its
  // name and type lines showed through them (and straight through a
  // hollow, width-unknown one). The name and type are in the inspector.
  String? hostingNote,
}) {
  final ops = <DiagramOp>[];
  final sizes = <double>[];
  var labelDropped = false;

  final designatorPt = typeScale.size(RackTextSizes.designator);
  final namePt = typeScale.size(RackTextSizes.name);
  final typePt = typeScale.size(RackTextSizes.type);
  final badgePt = typeScale.size(RackTextSizes.badge);

  // DR-080 §11.79.4: the accent IS the body fill, resolved instance
  // override first, then the template, then the palette. That order is
  // door 1 of CR-054 read literally, an instance-level statement being by
  // construction the more specific one, and this is the first thing on
  // the elevation to read a `DeviceOverrides` at all.
  // DR-098 §11.97.3 added a third state and this reads it through the
  // model's resolver rather than re-spelling the precedence: an accent
  // stated UNKNOWN falls through to `palette.deviceFill` exactly as an
  // absent one does, because "I do not know this device's colour" and
  // "nobody said" paint the same box. That is the one place a cleared
  // override and an inherited one are indistinguishable, and they are
  // indistinguishable because a fill has no way to draw an unknown.
  final fillArgb =
      device.overrides.resolveAccentColor(body.accentColor)?.argb ??
      palette.deviceFill;

  // The ink then follows the FILL rather than the palette, because one of
  // the eight shipped swatches is pure black while all four label colours
  // are dark inks chosen against a near-white default.
  // A hollow host has no fill for its ink to stand on, so it takes the
  // palette's dark inks over whatever the shelf is drawn in.
  final onDark = !widthUnknown && prefersLightInk(fillArgb);
  final inkDesignator = onDark
      ? palette.deviceDesignatorOnDark
      : palette.deviceDesignator;
  final inkName = onDark ? palette.deviceNameOnDark : palette.deviceName;
  final inkType = onDark ? palette.deviceTypeOnDark : palette.deviceType;
  final inkBadge = onDark ? palette.deviceBadgeOnDark : palette.deviceBadge;

  final rect = DBox.fromLtwh(0, 0, width, height);
  final fill = widthUnknown ? null : Fill(fillArgb);
  final stroke = lifecycleBorder
      ? lifecycleStroke(device.lifecycleStatus, palette.deviceStroke)
      : Stroke(argb: palette.deviceStroke, widthPt: 1);

  // Body: rounded at ≥0.75 zoom, a plain block below (docs/04 §2.1).
  if (lod == LodLevel.full || lod == LodLevel.detail) {
    ops.add(
      OpRoundRect(rect, const Radii.circular(3), fill: fill, stroke: stroke),
    );
  } else {
    ops.add(OpRect(rect, fill: fill, stroke: stroke));
  }

  if (hatched) ops.addAll(hatchBand(rect, palette.deviceType));

  final designator = device.designator;
  // AN UNKNOWN SHELF WIDTH TAKES THE SECOND LINE, not the third, so it is
  // the first thing to draw once there is room for anything under the
  // designator. **On a 2U shelf there is not**: a host there is 26 units
  // tall and the label ladder seats the designator alone. The HOLLOW body
  // is then the whole statement, which is exactly the 0U bar's treatment
  // of an unknown length (§11.165.2), and the semantic label says it in
  // words for somebody who cannot see the outline.
  final name = widthUnknown ? 'width unknown' : device.name;
  final typeName = widthUnknown ? device.name : body.displayName;

  if (lod == LodLevel.block) {
    // Solid block: designator centred, ONLY if it fits (measured) and the
    // body is at least 20 units wide.
    final style = rackText(
      designatorPt,
      inkDesignator,
      TextAnchor.midCenter,
    );
    final m = measurer.measureText(designator, style);
    if (width >= 20 && m.advanceWidth <= width - 2 * _pad) {
      ops.add(OpText(designator, DPt(width / 2, height / 2), style));
      sizes.add(designatorPt);
    }
    // NOT reported as a dropped label: at `block` the docs/04 §2.1 tier
    // itself says "designator only if it fits", the omission is a zoom
    // affordance the user can undo by zooming in, and no sheet is ever
    // drawn at this tier (`elevation_sheet.dart` pins `LodLevel.full`).
  } else {
    // The top line — designator (top-left) + U-height badge (top-right) —
    // on every tier at or above `badge`. Its vertical pad SHRINKS to keep
    // the line rather than letting 8 units of whitespace cost a device its
    // only identifier; the line is given up only when the glyphs are
    // taller than the body. See the file header.
    final pad = math.min(_pad, (height - designatorPt) / 2);
    if (pad < 0) {
      labelDropped = true;
    } else {
      // DR-083 §11.82.1: the mark rides THIS line, ahead of the text, and
      // the text shifts right by an advance computed from the type size.
      // It sits here because this line always draws, so it inherits that
      // survival; a mark anywhere else needs its own drop tier, in the one
      // function whose drop tiers have already shipped a blackout (header).
      //
      // READ THROUGH `effectiveGlyph`, NEVER `body.glyph`: 22 of the 48
      // seeded templates still inherit their mark from the category
      // (DR-084 authored the other 26), so reading the field directly
      // draws nothing for those.
      final advance = deviceGlyphAdvance(designatorPt);
      // The mark is given up when it would take more than a quarter of the
      // label band. Past that it competes with the designator instead of
      // labelling it, and the designator is what a person in front of the
      // rack actually needs.
      //
      // DROPPING THE MARK CANNOT SUPPRESS A LINE, and that is the property
      // this shape exists to guarantee: the guard chooses between mark and
      // no mark, never between text and no text. It is also NOT reported
      // through `labelDropped`, which is about the label — a caller warned
      // that a device lost its identifier when it only lost its mark would
      // be told something false.
      final mark = advance * 4 <= width - 2 * _pad
          ? deviceGlyphOp(
              effectiveGlyph(body.glyph, body.category),
              DPt(_pad, pad + designatorPt / 2),
              designatorPt,
              inkDesignator,
              strokeWidthPt: deviceGlyphStrokeWidth(designatorPt),
            )
          : null;
      if (mark != null) {
        // DR-083 §11.82.2: over a hatch, the mark wins, on a panel knocked
        // out of the 45° band in the RESOLVED fill.
        //
        // THE COLLISION IS NOT HYPOTHETICAL AND NO RULING HAD NAMED IT.
        // `kCategoryDefaultGlyph` maps `kCatPassive` to `blank`, and
        // `scene_builder` hatches exactly `kCatPassive`, so the devices
        // defaulting to the blank mark are precisely the ones buried in
        // 45° lines. Suppressing the mark there was the tempting answer
        // and would have made `blank` and `shelf` draw nothing whenever
        // `hatchPassive` is on, which is its default: two of seventeen
        // ruled values unreachable, inside the fix for unreachable values.
        if (hatched) {
          final r = designatorPt * kDeviceGlyphCapFactor / 2;
          final midY = pad + designatorPt / 2;
          final bleed = r / 3;
          ops.add(
            OpRect(
              DBox.fromLtwh(
                _pad - bleed,
                midY - r - bleed,
                2 * (r + bleed),
                2 * (r + bleed),
              ),
              fill: fill,
            ),
          );
        }
        ops.add(mark);
      }

      // The whole text column starts after the mark, so its left edge runs
      // straight down all three lines rather than the designator alone
      // stepping in and the two under it hanging back.
      final textLeft = mark == null ? _pad : _pad + advance;

      ops.add(
        OpText(
          designator,
          DPt(textLeft, pad),
          rackText(designatorPt, inkDesignator, TextAnchor.topLeft),
        ),
      );
      sizes.add(designatorPt);

      // docs/08 §2.2's `4U · 12–15` when the caller supplied it, the plain
      // U-height badge otherwise. Same line, so it costs no extra height.
      var noteRight = width - _pad;
      if (showBadge) {
        final badge = ruSpanLabel ?? '${deviceH}U';
        final badgeStyle = rackText(badgePt, inkBadge, TextAnchor.topRight);
        ops.add(OpText(badge, DPt(width - _pad, pad), badgeStyle));
        sizes.add(badgePt);
        noteRight -= measurer.measureText(badge, badgeStyle).advanceWidth + 6;
      }

      // THE LOAD LINE, between the designator and the badge and only if it
      // fits there, measured: a note that cannot fit is dropped, never the
      // designator or the badge. It is not reported through
      // `labelDropped`, which is about the device's identifier.
      if (hostingNote case final note?) {
        final style = rackText(typePt, inkType, TextAnchor.topRight);
        final designatorEnd =
            textLeft +
            measurer
                .measureText(
                  designator,
                  rackText(designatorPt, inkDesignator, TextAnchor.topLeft),
                )
                .advanceWidth;
        final noteWidth = measurer.measureText(note, style).advanceWidth;
        if (noteRight - noteWidth >= designatorEnd + 8) {
          ops.add(
            OpText(
              note,
              DPt(noteRight, pad + (designatorPt - typePt) / 2),
              style,
            ),
          );
          sizes.add(typePt);
        }
      }

      // full / detail: stack name then type below the designator, each
      // only if it fits vertically (a 1U body has room for the designator
      // only). These are rungs 2 and 1 of the ladder — dropped before the
      // line above them ever is.
      if (hostingNote == null &&
          (lod == LodLevel.full || lod == LodLevel.detail)) {
        var y = pad + designatorPt + 2;
        if (y + namePt <= height - pad) {
          ops.add(
            OpText(
              name,
              DPt(textLeft, y),
              rackText(namePt, inkName, TextAnchor.topLeft),
            ),
          );
          sizes.add(namePt);
          y += namePt + 2;
        }
        if (typeName.isNotEmpty && y + typePt <= height - pad) {
          ops.add(
            OpText(
              typeName,
              DPt(textLeft, y),
              rackText(typePt, inkType, TextAnchor.topLeft),
            ),
          );
          sizes.add(typePt);
        }
      }
    }
  }

  return (
    ops: ops,
    minTextPt: sizes.isEmpty ? double.infinity : sizes.reduce(math.min),
    inkBounds: inkBoundsOf(ops, measurer: measurer),
    labelDropped: labelDropped,
  );
}

/// Spacing between hatch lines, in diagram units.
const double _kHatchPitch = 7;

/// The 45° hatch band docs/08 §2.2 asks for on blanks, vents and shelves.
///
/// ─────────────────────────────────────────────────────────────────────
/// NO NEW CANVAS METHOD (CR-088)
/// ─────────────────────────────────────────────────────────────────────
/// A hatch is the obvious place to reach for a pattern fill, an image or
/// an alpha mask, and `DiagramCanvas` deliberately has none of those. It
/// is drawn instead as a `clipRect` plus a run of `drawLine`s, both of
/// which every backend already implements identically, so the band renders
/// the same on screen, in the PDF and in `BoundsCanvas`.
///
/// The clip is scoped by the surrounding save/restore, matching §7.3's
/// "clip is intersective and undone only by restore".
List<DiagramOp> hatchBand(DBox body, int argb) {
  final ops = <DiagramOp>[
    const OpSave(),
    OpClipRect(body),
  ];
  final stroke = Stroke(argb: argb, widthPt: 0.5);
  // 45° lines running bottom-left to top-right. Starting the sweep at
  // `-height` is what makes the band cover the whole rect rather than
  // only its upper-right triangle.
  for (var x = body.left - body.height; x < body.right; x += _kHatchPitch) {
    ops.add(
      OpLine(
        DPt(x, body.bottom),
        DPt(x + body.height, body.top),
        stroke,
      ),
    );
  }
  return ops..add(const OpRestore());
}
