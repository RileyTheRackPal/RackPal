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
  final chassis = body.chassisWidth.nm > 0
      ? body.chassisWidth
      : const Len(432_000_000);
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
