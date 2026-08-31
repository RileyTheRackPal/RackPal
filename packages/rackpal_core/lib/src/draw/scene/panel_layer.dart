// The rear-panel auto-layout (`#226`, M4-K1, docs/06 §5, CR-071 part 1,
// AC-032, DR-057 §11.56.4, DR-105 §11.104.2).
//
// ═══════════════════════════════════════════════════════════════════════
// THE GEOMETRY IS FREE, WHICH IS THE WHOLE ARGUMENT FOR SHIPPING IT
// ═══════════════════════════════════════════════════════════════════════
// CR-071 part 1 REJECTS "you build a device by drawing its rear panel" as
// the authoring model: ports are authored in the grid and connect by
// IDENTITY, so the netlist, the schedule and the PDF are all complete
// without a single coordinate. docs/06 §5 then ships the layout anyway,
// *"because the geometry is free"*: every `ConnectorTypeDef` carries a
// real footprint and a CI gate holds that (AC-050/A2.2).
//
// So this file computes and never stores. `PortDef.position` is the
// OVERRIDE, null meaning automatic (DR-105 §11.104.3), and a template
// with none is not incomplete: docs/06 §5's non-negotiable is true here
// by construction rather than by care.
//
// ═══════════════════════════════════════════════════════════════════════
// 432 mm, NOT 482.6 (AC-032)
// ═══════════════════════════════════════════════════════════════════════
// 482.6 mm is the PANEL width including ears; connectors live on the
// chassis at ~432 mm. Flowing across the panel width would draw jacks out
// past the rails **on the view that gets taped inside the rack door**.
// The flow uses `TemplateBody.chassisWidth` (432 mm by default) and the
// finished field is centred on the 482.6 mm panel at step 6.
//
// ═══════════════════════════════════════════════════════════════════════
// PITCH IS A REFINEMENT, NOT A PREREQUISITE (DR-057 §11.56.4)
// ═══════════════════════════════════════════════════════════════════════
// 20 of the 51 shipped connectors carry a `pitch` and the rest never will:
// a pitch is not derivable, and `conn.binding_post` states 20 mm against a
// 24 mm footprint because ¾ in is the centre spacing binding posts are
// built on. Step 2 therefore falls back to the FOOTPRINT, which is what
// CR-071 says the layout flows from in the first place, so this runs on
// every template rather than on the fraction that carries a pitch.
//
// ═══════════════════════════════════════════════════════════════════════
// A CONNECTOR WITH NO FOOTPRINT OCCUPIES NO WIDTH, AND IS COUNTED
// ═══════════════════════════════════════════════════════════════════════
// docs/06 §5 step 2 skips the connectors §5.1 gives no cutout: hardwired,
// ground lug, unterminated. Four of the 51 are like that, and they are
// **reported rather than dropped silently** ([RenderedPanel.noCutout]),
// because a person looking at a 6-port device that drew 4 jacks needs the
// difference between "two are missing" and "two do not have a hole".
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/rack_geometry.dart';
import 'package:rackpal_core/src/draw/scene/rack_layer.dart' show LayerBuild;
import 'package:rackpal_core/src/draw/scene/rack_style.dart' show rackText;
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/constants.dart' show kRackUnit;
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// EIA-19: the panel width including ears, and what step 6 centres on.
const Len kPanelWidth = Len(482_600_000);

/// The vertical gap a 1U panel leaves so two stacked panels do not touch
/// (docs/06 §5 step 4: `heightU × 44.45 mm − 0.79 mm`).
const Len kPanelHeightGap = Len(790_000);

/// The space left between two adjacent cutouts when a connector states no
/// pitch of its own (docs/06 §5 step 2's `footprintWidth + gutter`).
///
/// **A CONSTANT AND NOT A GUESS AT A PITCH.** DR-057 §11.56.4 refuses to
/// invent a pitch per connector because one is not derivable; a uniform
/// gutter is a LAYOUT choice this file owns, applied identically to every
/// connector that did not state its own spacing, and it is visibly a
/// drawing decision rather than a claim about hardware.
const Len kPanelGutter = Len(2_000_000);

/// The chassis width a body that states none falls back to (AC-032).
///
/// 432 mm, and the distinction from [kPanelWidth]'s 482.6 mm is the whole
/// point of AC-032: connectors live on the chassis, the ears do not carry
/// jacks, and flowing across the panel width draws holes over the rails.
const Len kChassisWidth = Len(432_000_000);

/// Where one port's cutout sits on the panel, in nanometres from the
/// panel's top-left.
@immutable
final class PanelSlot {
  const PanelSlot({
    required this.portKey,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.nudged,
  });

  final PortKey portKey;
  final Len x;
  final Len y;
  final Len width;
  final Len height;

  /// Whether this came from `PortDef.position` rather than from the flow.
  ///
  /// The one thing a `Reset to auto` needs to know, and the reason
  /// DR-105 made that field nullable.
  final bool nudged;

  Len get right => Len(x.nm + width.nm);
  Len get bottom => Len(y.nm + height.nm);
}

/// One template's rear panel, laid out.
@immutable
final class RenderedPanel {
  const RenderedPanel({
    required this.width,
    required this.height,
    required this.slots,
    required this.noCutout,
    required this.overflowed,
  });

  /// Always [kPanelWidth]: the drawing is of a PANEL, whatever the
  /// chassis behind it measures.
  final Len width;

  /// `heightU × kRackUnit − kPanelHeightGap`, or zero for a template with
  /// no rail footprint.
  final Len height;

  final List<PanelSlot> slots;

  /// Ports whose connector states no footprint, in `PortDef.order`.
  ///
  /// **NAMED, NOT COUNTED**, for `library_import.dart`'s reason: a
  /// surface saying "2 ports have no cutout" invites exactly the question
  /// this answers, and the caller has to render something either way.
  final List<PortKey> noCutout;

  /// Ports the flow could not fit in the available height.
  ///
  /// **NOT AN ERROR AND NOT A REFUSAL.** A 48-port patch panel authored
  /// as 1U genuinely does not fit, and that is a fact about the template
  /// worth showing rather than a reason to draw nothing. They are placed
  /// anyway, below the panel, so the preview shows the overflow instead
  /// of hiding it (G4's shape: report, never fabricate).
  final List<PortKey> overflowed;

  bool get isEmpty => slots.isEmpty;

  /// How much of the panel's area the cutouts take, in permille.
  ///
  /// PERMILLE rather than a double, per CR-001's "integer units only,
  /// `Permille` for fractions". Zero when the panel has no height, which
  /// is a field device rather than a full one.
  int get fillPermille {
    final area = width.nm * height.nm;
    if (area <= 0) return 0;
    var used = 0;
    for (final slot in slots) {
      used += slot.width.nm * slot.height.nm;
    }
    return (used * 1000 / area).round();
  }
}

/// docs/06 §5's six steps, run over [body].
///
/// A PURE FUNCTION of the body and the registries. It writes nothing, and
/// two calls on one template return equal layouts (DR-105 §11.104.2).
RenderedPanel buildPanelGeometry({
  required TemplateBody body,
  required Registries registries,
}) {
  final heightU = body.frontU > body.rearU ? body.frontU : body.rearU;
  final height = heightU <= 0
      ? Len.zero
      : Len(heightU * kRackUnit.nm - kPanelHeightGap.nm);

  // STEP 1: banks in `BankDef.order`, ports within a bank in
  // `PortDef.order`. A port whose bank this body does not declare sorts
  // last rather than being dropped: the grid permits one (`bankKey` is a
  // free string) and a layout that silently loses a port is worse than
  // one that puts it at the end.
  final bankOrder = <String, String>{
    for (final bank in body.banks) bank.key: bank.order.v,
  };
  final ports = [...body.ports]
    ..sort((a, b) {
      // AN EXPLICIT RANK, NOT A MAX-CHARACTER SENTINEL. The first draft
      // sorted an unknown bank behind `'￿'`, which reads as a
      // trick and, more usefully, tripped the glyph-coverage gate: that
      // gate holds that every non-ASCII codepoint in the source has a
      // font glyph in both weights, and U+FFFF is a noncharacter. The
      // gate could not know the string is never drawn, and it was right
      // to ask.
      final ra = bankOrder.containsKey(a.bankKey ?? '') ? 0 : 1;
      final rb = bankOrder.containsKey(b.bankKey ?? '') ? 0 : 1;
      if (ra != rb) return ra - rb;
      final ba = bankOrder[a.bankKey ?? ''] ?? '';
      final bb = bankOrder[b.bankKey ?? ''] ?? '';
      final byBank = ba.compareTo(bb);
      if (byBank != 0) return byBank;
      final byOrder = a.order.v.compareTo(b.order.v);
      // A TOTAL COMPARATOR, ending on the key, which is unique within a
      // body by construction. `List.sort` is not stable in Dart, so two
      // ports sharing a bank and an order would otherwise let map
      // iteration decide the panel.
      return byOrder != 0 ? byOrder : a.key.v.compareTo(b.key.v);
    });

  final slots = <PanelSlot>[];
  final noCutout = <PortKey>[];
  final overflowed = <PortKey>[];

  // STEPS 2 AND 3: flow left to right at pitch-or-footprint, wrapping at
  // the CHASSIS width (AC-032), tracking each row's tallest cutout so the
  // next row clears it.
  final chassis = body.chassisWidth.nm > 0 ? body.chassisWidth : kChassisWidth;
  var cursorX = 0;
  var rowTop = 0;
  var rowHeight = 0;
  final rows = <List<PanelSlot>>[<PanelSlot>[]];

  for (final port in ports) {
    final def = registries.connectorTypes[port.connector];
    final footprintWidth = def?.footprintWidth;
    final footprintHeight = def?.footprintHeight;
    if (footprintWidth == null || footprintHeight == null) {
      // §5.1's no-cutout kinds. They occupy no panel width and are
      // reported so a caller can say so.
      noCutout.add(port.key);
      continue;
    }

    // STEP 2's advance. `pitch` is the CENTRE spacing a connector states
    // for itself; the fallback is the footprint plus this file's gutter.
    final advance = def?.pitch?.nm ?? (footprintWidth.nm + kPanelGutter.nm);

    // STEP 3. Wrap when this cutout would cross the chassis edge, never
    // when the ADVANCE would: the advance includes spacing that may sit
    // past the last jack, and wrapping on it drops a column that fits.
    if (cursorX > 0 && cursorX + footprintWidth.nm > chassis.nm) {
      rowTop += rowHeight;
      rowHeight = 0;
      cursorX = 0;
      rows.add(<PanelSlot>[]);
    }

    final slot = PanelSlot(
      portKey: port.key,
      x: Len(cursorX),
      y: Len(rowTop),
      width: footprintWidth,
      height: footprintHeight,
      nudged: false,
    );
    rows.last.add(slot);
    cursorX += advance;
    if (footprintHeight.nm > rowHeight) rowHeight = footprintHeight.nm;
  }

  // STEP 4: distribute the rows vertically inside the panel height. The
  // rows were stacked tight while flowing; this spreads them so a 1U
  // panel with one row centres it and a 3U panel with three does not
  // leave them all at the top.
  final usedHeight = rowTop + rowHeight;
  final slack = height.nm - usedHeight;
  final gaps = rows.length + 1;
  final lead = slack > 0 && gaps > 0 ? slack ~/ gaps : 0;

  var rowIndex = 0;
  for (final row in rows) {
    if (row.isEmpty) continue;
    rowIndex++;
    // STEP 6's other half, per row: centre the row's own run on the
    // chassis, then the whole field on the panel. Doing it per row is
    // what makes a short last row look laid out rather than abandoned.
    final rowWidth = row.last.right.nm;
    final chassisLead = (chassis.nm - rowWidth) ~/ 2;
    final panelLead = (kPanelWidth.nm - chassis.nm) ~/ 2;
    final dx = chassisLead + panelLead;
    final dy = lead * rowIndex;
    for (final slot in row) {
      final placed = PanelSlot(
        portKey: slot.portKey,
        x: Len(slot.x.nm + dx),
        y: Len(slot.y.nm + dy),
        width: slot.width,
        height: slot.height,
        nudged: false,
      );
      if (height.nm > 0 && placed.bottom.nm > height.nm) {
        overflowed.add(placed.portKey);
      }
      slots.add(placed);
    }
  }

  // THE OVERRIDE WINS, AND IT IS APPLIED LAST (DR-105 §11.104.3). A
  // nudged port keeps the coordinate a person gave it, and everything
  // else keeps the flow's. This is deliberately NOT a re-flow around the
  // nudged ones: CR-071 frames the interaction as nudging rather than
  // placing, so the auto field must not move under a hand that touched
  // one jack.
  final byKey = {for (var i = 0; i < slots.length; i++) slots[i].portKey.v: i};
  for (final port in ports) {
    final override = port.position;
    if (override == null) continue;
    final at = byKey[port.key.v];
    if (at == null) continue;
    final was = slots[at];
    slots[at] = PanelSlot(
      portKey: was.portKey,
      // `xTwelfth` is docs/research's twelfth-of-a-rack-unit grid, and
      // `xFineNm` the offset within it; `ruOffset` is whole RU down.
      x: Len(override.xTwelfth * (kRackUnit.nm ~/ 12) + override.xFineNm.nm),
      y: Len(override.ruOffset * kRackUnit.nm + override.yFineNm.nm),
      width: was.width,
      height: was.height,
      nudged: true,
    );
  }

  return RenderedPanel(
    width: kPanelWidth,
    height: height,
    slots: slots,
    noCutout: noCutout,
    overflowed: overflowed,
  );
}

// ═══════════════════════════════════════════════════════════════════════
// THE DRAWING, WHICH IS A SEPARATE QUESTION FROM THE LAYOUT
// ═══════════════════════════════════════════════════════════════════════
// [buildPanelGeometry] answers "where does each cutout go" and stops. This
// half answers "what ink does that make", in the same `DiagramOp` IR every
// other layer emits, and for the same reason `device_glyph_mark.dart`
// gives: a hand-drawn Flutter `Path` that merely LOOKED like the panel
// would be a second drawing of one thing, and two drawings of one thing
// come to disagree silently, on paper, which is the half nobody looks at
// until a job site does (CR-086).
//
// T2.02, the printed Rear Panel sheet, is NOT fed by this yet (DR-105
// §11.104.5). That is a wiring decision, not a capability one: when the
// sheet is built it calls this function rather than growing its own.

/// Chrome for the rear-panel drawing.
///
/// NOT SIGNAL COLOUR. Nothing here is derived from a port's family or
/// domain, so PAL-1 (canon §14) has no jurisdiction and CR-078's "colour
/// lives on the signal domain" is not being quietly re-litigated: these
/// are the panel, the chassis outline and the cutouts, which are metal.
final class PanelPalette {
  const PanelPalette({
    this.panelFill = 0xFFF1F5F9,
    this.panelStroke = 0xFF334155,
    this.chassisStroke = 0xFF94A3B8,
    this.cutoutFill = 0xFFFFFFFF,
    this.cutoutStroke = 0xFF334155,
    this.nudgedStroke = 0xFF2563EB,
    this.overflowStroke = 0xFFB45309,
    this.overflowFill = 0xFFFEF3C7,
    this.label = 0xFF475569,
  });

  final int panelFill;
  final int panelStroke;

  /// The 432 mm chassis field, drawn dashed INSIDE the 482.6 mm panel.
  ///
  /// Drawn at all because AC-032's distinction is invisible otherwise, and
  /// it is the distinction that stops jacks being drawn out over the rack
  /// ears on the one view that gets taped inside the door.
  final int chassisStroke;

  final int cutoutFill;
  final int cutoutStroke;

  /// A cutout whose position came from `PortDef.position` rather than the
  /// flow (`PanelSlot.nudged`). Outline only: a nudge is a fact about
  /// AUTHORSHIP, not about the hardware, so it must not read as a
  /// different kind of jack.
  final int nudgedStroke;

  /// A cutout the panel has no room for. Per DR-105 §11.104.8 this is a
  /// finding, never a refusal, so it is drawn and flagged rather than
  /// dropped or clipped away.
  final int overflowStroke;
  final int overflowFill;

  final int label;
}

/// Type size for a cutout's designator, in diagram units.
///
/// One value and no scale ladder: the preview is small, the labels are
/// either legible or suppressed, and [buildPanelLayer] measures rather
/// than guesses which.
const double kPanelLabelSize = 2.4;

/// Renders [panel] as `DiagramOp`s in the panel's LOCAL coordinates, with
/// the panel's top-left at the origin.
///
/// [measurer] is real work and not a formality: a designator is drawn only
/// if it MEASURES narrower than its own cutout, the same "only if it fits"
/// discipline `device_layer` and `symbol_layer` apply. A 10 mm RJ45 cutout
/// cannot hold `NET-SW-1 PORT 24` at any size a person would read, and a
/// label that overhangs its neighbour is worse than no label: on this
/// drawing the labels are what tell an installer which hole to use.
LayerBuild buildPanelLayer(
  RenderedPanel panel, {
  required TemplateBody body,
  required TextMeasurer measurer,
  PanelPalette palette = const PanelPalette(),
}) {
  // Geometry stays geometry: `PanelSlot` carries no label, because a
  // coordinate does not need one and `#226`'s twenty tests would all have
  // had to restate it. The caller always has the body -- it just handed
  // the same one to `buildPanelGeometry` -- so the lookup is free.
  final labelOf = <String, String>{
    for (final port in body.ports) port.key.v: port.label,
  };
  final chassisWidth = body.chassisWidth.nm > 0
      ? body.chassisWidth
      : kChassisWidth;

  final ops = <DiagramOp>[];
  final sizes = <double>[];
  // Ink bounds are ACCUMULATED, not assumed to be the panel. An
  // overflowing cutout is drawn BELOW the panel on purpose (DR-105
  // §11.104.8: a finding, not a refusal), so a `inkBounds` set to the
  // panel rect would clip exactly the thing the drawing exists to show.
  var inkL = 0.0;
  var inkT = 0.0;
  var inkR = 0.0;
  var inkB = 0.0;
  void cover(DBox b) {
    if (b.left < inkL) inkL = b.left;
    if (b.top < inkT) inkT = b.top;
    if (b.right > inkR) inkR = b.right;
    if (b.bottom > inkB) inkB = b.bottom;
  }

  double u(Len l) => RackGeometry.unitsForLen(l);

  final width = u(panel.width);
  final height = u(panel.height);
  final panelBox = DBox.fromLtwh(0, 0, width, height);
  cover(panelBox);

  ops.add(
    OpRect(
      panelBox,
      fill: Fill(palette.panelFill),
      stroke: Stroke(argb: palette.panelStroke, widthPt: 0.6),
    ),
  );

  // The chassis field, centred, dashed. Skipped when it is not narrower
  // than the panel — a full-width chassis would draw a dashed line exactly
  // on the panel outline, which reads as a rendering fault rather than as
  // "these two happen to be equal".
  final chassis = u(chassisWidth);
  if (chassis > 0 && chassis < width - 0.5) {
    final inset = (width - chassis) / 2;
    ops.add(
      OpRect(
        DBox.fromLtwh(inset, 0, chassis, height),
        // BOTH CR-082 KNOBS, NAMED TOGETHER, because `draw_source_gate_
        // test.dart` refuses a Stroke that decides one and inherits the
        // other -- and it caught this one. The decision: the chassis field
        // is diagram geometry, one op away from the panel outline it sits
        // inside, so it SCALES; and it is sheet furniture, so it may
        // legitimately print finer than the 0.5 pt signal floor.
        stroke: Stroke(
          argb: palette.chassisStroke,
          widthPt: 0.35,
          dash: const [1.5, 1.5],
          // Redundant against the default AND REQUIRED ANYWAY, which is
          // the same standoff `symbol_layer.dart:722` records: the
          // analyzer calls an explicit default noise, and
          // `draw_source_gate_test.dart` refuses a Stroke that decides
          // `hairlineFloor` while inheriting this. The source gate wins,
          // because the flags disagreeing silently is what it exists to
          // stop.
          // ignore: avoid_redundant_argument_values
          scaleWithGeometry: true,
          hairlineFloor: true,
        ),
      ),
    );
  }

  final overflowed = panel.overflowed.map((k) => k.v).toSet();

  for (final slot in panel.slots) {
    final rect = DBox.fromLtwh(
      u(slot.x),
      u(slot.y),
      u(slot.width),
      u(slot.height),
    );
    cover(rect);
    final isOver = overflowed.contains(slot.portKey.v);
    ops.add(
      OpRoundRect(
        rect,
        const Radii.circular(0.6),
        fill: Fill(isOver ? palette.overflowFill : palette.cutoutFill),
        stroke: Stroke(
          argb: isOver
              ? palette.overflowStroke
              : slot.nudged
              ? palette.nudgedStroke
              : palette.cutoutStroke,
          // A nudged or overflowing cutout is heavier, not differently
          // hued alone: the same "dash and weight, never hue" discipline
          // `device_layer` applies to lifecycle borders, and the reason
          // this drawing still reads when it prints in greyscale.
          widthPt: isOver || slot.nudged ? 0.7 : 0.45,
        ),
      ),
    );

    final label = labelOf[slot.portKey.v] ?? '';
    if (label.isEmpty) continue;
    final style = rackText(
      kPanelLabelSize,
      palette.label,
      TextAnchor.topCenter,
    );
    if (measurer.measureText(label, style).advanceWidth > rect.width) continue;
    final midX = (rect.left + rect.right) / 2;
    ops.add(OpText(label, DPt(midX, rect.bottom + 0.6), style));
    sizes.add(kPanelLabelSize);
  }

  return (
    ops: ops,
    minTextPt: sizes.isEmpty
        ? double.infinity
        : sizes.reduce((a, b) => a < b ? a : b),
    inkBounds: DBox.fromLtwh(inkL, inkT, inkR - inkL, inkB - inkT),
  );
}
