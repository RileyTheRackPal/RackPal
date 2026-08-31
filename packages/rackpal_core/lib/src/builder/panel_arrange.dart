// The nudge canvas's edits, as commands (`#227`, CR-071 part 1, DR-106).
//
// ═══════════════════════════════════════════════════════════════════════
// THE GEOMETRY LIVES HERE AND NOT IN THE WIDGET
// ═══════════════════════════════════════════════════════════════════════
// `port_batch.dart` set the precedent and its reason applies unchanged:
// building the commands in core means the arithmetic is testable without
// pumping a widget, and the widget's only job is deciding WHICH stack they
// land on. Align and distribute are pure geometry over a `RenderedPanel`;
// a version of them living in `rackpal_ui` would be reachable by no test
// in this package, which is the same trap `#229` spent a commit escaping.
//
// EVERY FUNCTION HERE RETURNS `SetPortFieldCommand`s AND MINTS NO COMMAND
// TYPE OF ITS OWN. `port_commands.dart` says why in terms: a single typed
// write to a single port is the shape that command already is, and a
// bespoke one would be a second undo path to the same field.
//
// ── WHAT A NUDGE WRITES ─────────────────────────────────────────────────
// The whole offset goes in `xFineNm`/`yFineNm`; `xTwelfth` and `ruOffset`
// stay 0 (DR-106 §11.105.3). Two representations of one position is how
// they come to disagree, and the corpus's own worked examples do exactly
// this: `xTwelfth: 0` with the offset in `xFineNm`.
//
// ── AND WHAT IT READS ───────────────────────────────────────────────────
// A port with no override has no stored position to add a delta to, so the
// delta is applied to the position the FLOW gave it, read off the
// `RenderedPanel` the caller already has. That is what makes the first
// nudge of an auto-placed jack move it by 1 mm rather than teleport it to
// 1 mm from the panel edge. It is also why these functions take a panel
// and not just a body: the auto position is derived and never stored, so
// there is nowhere else to read it from.
import 'package:rackpal_core/src/builder/port_commands.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/draw/scene/panel_layer.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// One arrow press (CR-071's "1 mm snap", DR-106 §11.105.3).
const Len kPanelNudgeStep = Len(1_000_000);

/// `Shift` + arrow.
const Len kPanelNudgeFine = Len(100_000);

/// `Ctrl` + arrow.
const Len kPanelNudgeCoarse = Len(10_000_000);

/// docs/06 §5's align and distribute, enumerated (DR-106 §11.105.5).
enum PanelArrange {
  alignLeft,
  alignRight,
  alignTop,
  alignBottom,
  alignCentreH,
  alignCentreV,
  distributeH,
  distributeV;

  /// Align needs two cutouts to have a relationship; distribute needs
  /// three, because with two there is nothing between them to space.
  int get minimumSelection => switch (this) {
    PanelArrange.distributeH || PanelArrange.distributeV => 3,
    _ => 2,
  };
}

/// The position [slot] would be written back as, moved by ([dx], [dy]).
///
/// Exposed because the canvas needs it for a drag preview as well as for
/// the commit, and two spellings of "where would this land" is the defect
/// this file exists to avoid.
PanelPosition panelPositionAt(
  PanelSlot slot, {
  Len dx = Len.zero,
  Len dy = Len.zero,
}) => PanelPosition(
  // DR-106 §11.105.3: the coarse fields stay 0 and the fine fields carry
  // everything, so a position has exactly one spelling.
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len(slot.x.nm + dx.nm),
  yFineNm: Len(slot.y.nm + dy.nm),
);

/// Moves every port in [selection] by ([dx], [dy]).
///
/// A port already at the panel's left edge still moves left, into negative
/// x, and that is deliberate: DR-106 §11.105.6 refuses to make an
/// off-panel nudge an error, because the panel already reports overflow as
/// a finding and a person who drags a cutout off the edge is describing
/// something rather than making a mistake. Clamping would silently
/// disagree with the arrow key they pressed.
List<Command<TemplateBody>> buildPanelNudge({
  required TemplateBody body,
  required RenderedPanel panel,
  required Set<String> selection,
  required Len dx,
  required Len dy,
}) {
  if (selection.isEmpty || (dx.nm == 0 && dy.nm == 0)) return const [];
  return _writes(body, [
    for (final slot in _selected(panel, selection))
      (slot.portKey, panelPositionAt(slot, dx: dx, dy: dy)),
  ]);
}

/// Clears the overrides on [selection], or on EVERY port when it is empty.
///
/// DR-106 §11.105.4: one control whose label says which it will do. The
/// empty set meaning "all" is the whole of that decision, and it is here
/// rather than in the widget so the widget cannot mean something else by
/// an empty selection.
List<Command<TemplateBody>> buildPanelReset({
  required TemplateBody body,
  required Set<String> selection,
}) => _writes(body, [
  for (final port in body.ports)
    if ((selection.isEmpty || selection.contains(port.key.v)) &&
        port.position != null)
      (port.key, null),
]);

/// Applies [op] to [selection].
///
/// Returns empty below [PanelArrange.minimumSelection] rather than doing
/// something defensible-but-surprising with one cutout.
List<Command<TemplateBody>> buildPanelArrange({
  required TemplateBody body,
  required RenderedPanel panel,
  required Set<String> selection,
  required PanelArrange op,
}) {
  final slots = _selected(panel, selection);
  if (slots.length < op.minimumSelection) return const [];

  return switch (op) {
    PanelArrange.alignLeft => _alignTo(body, slots, x: _min(slots, _left)),
    PanelArrange.alignTop => _alignTo(body, slots, y: _min(slots, _top)),
    // Right and bottom align the FAR edge, so a wide cutout and a narrow
    // one finish flush on the side being aligned rather than sharing an
    // origin. Anything else is not what the button says.
    PanelArrange.alignRight => _writes(body, [
      for (final s in slots)
        (
          s.portKey,
          panelPositionAt(s, dx: Len(_max(slots, _right) - _right(s))),
        ),
    ]),
    PanelArrange.alignBottom => _writes(body, [
      for (final s in slots)
        (
          s.portKey,
          panelPositionAt(s, dy: Len(_max(slots, _bottom) - _bottom(s))),
        ),
    ]),
    // Centre on the BOUNDING BOX of the selection, not on the panel: the
    // gesture is "line these up with each other", and centring on the
    // panel would move a tidy group sideways for no reason the person
    // asked for.
    PanelArrange.alignCentreH => _writes(body, [
      for (final s in slots)
        (
          s.portKey,
          panelPositionAt(
            s,
            dx: Len(_centreOf(slots, _left, _right) - _centreX(s)),
          ),
        ),
    ]),
    PanelArrange.alignCentreV => _writes(body, [
      for (final s in slots)
        (
          s.portKey,
          panelPositionAt(
            s,
            dy: Len(_centreOf(slots, _top, _bottom) - _centreY(s)),
          ),
        ),
    ]),
    PanelArrange.distributeH => _distribute(body, slots, horizontal: true),
    PanelArrange.distributeV => _distribute(body, slots, horizontal: false),
  };
}

// ── the arithmetic ──────────────────────────────────────────────────────

int _left(PanelSlot s) => s.x.nm;
int _right(PanelSlot s) => s.x.nm + s.width.nm;
int _top(PanelSlot s) => s.y.nm;
int _bottom(PanelSlot s) => s.y.nm + s.height.nm;
int _centreX(PanelSlot s) => s.x.nm + s.width.nm ~/ 2;
int _centreY(PanelSlot s) => s.y.nm + s.height.nm ~/ 2;

int _min(List<PanelSlot> s, int Function(PanelSlot) f) =>
    s.map(f).reduce((a, b) => a < b ? a : b);
int _max(List<PanelSlot> s, int Function(PanelSlot) f) =>
    s.map(f).reduce((a, b) => a > b ? a : b);

int _centreOf(
  List<PanelSlot> s,
  int Function(PanelSlot) lo,
  int Function(PanelSlot) hi,
) => (_min(s, lo) + _max(s, hi)) ~/ 2;

List<Command<TemplateBody>> _alignTo(
  TemplateBody body,
  List<PanelSlot> slots, {
  int? x,
  int? y,
}) => _writes(body, [
  for (final s in slots)
    (
      s.portKey,
      panelPositionAt(
        s,
        dx: Len(x == null ? 0 : x - s.x.nm),
        dy: Len(y == null ? 0 : y - s.y.nm),
      ),
    ),
]);

/// Even GAPS, not even centres.
///
/// ═══════════════════════════════════════════════════════════════════════
/// WHY GAPS, ON THIS DRAWING SPECIFICALLY
/// ═══════════════════════════════════════════════════════════════════════
/// Distributing centres is the common default and it is wrong here,
/// because a rear panel mixes cutout sizes constantly: a 19 mm XLR beside
/// a 10 mm RJ45 beside a 24 mm binding post. Even centres leaves the gaps
/// visibly uneven, which is exactly the "eight near-misses" look this
/// operation exists to fix. Even gaps is what a person means by "space
/// these out" when the things being spaced are different widths.
///
/// The two extremes do not move: they are the span the rest are
/// distributed within, and moving them would make the operation depend on
/// its own previous result.
List<Command<TemplateBody>> _distribute(
  TemplateBody body,
  List<PanelSlot> slots, {
  required bool horizontal,
}) {
  final lo = horizontal ? _left : _top;
  final hi = horizontal ? _right : _bottom;
  final extent = horizontal
      ? (PanelSlot s) => s.width.nm
      : (PanelSlot s) => s.height.nm;

  // TOTAL ORDER, because Dart's `List.sort` is not stable and a comparator
  // that ties leaves two cutouts free to swap between two runs of the same
  // operation. The port key breaks it and is unique by construction.
  final sorted = [...slots]
    ..sort((a, b) {
      final c = lo(a).compareTo(lo(b));
      return c != 0 ? c : a.portKey.v.compareTo(b.portKey.v);
    });

  final span = _max(sorted, hi) - _min(sorted, lo);
  final occupied = sorted.fold(0, (n, s) => n + extent(s));
  // A selection whose cutouts already fill their own span has no slack to
  // distribute. Returning nothing beats writing a negative gap.
  if (span <= occupied) return const [];

  final gap = (span - occupied) ~/ (sorted.length - 1);
  var cursor = _min(sorted, lo);
  final writes = <(PortKey, PanelPosition?)>[];
  for (final s in sorted) {
    writes.add((
      s.portKey,
      panelPositionAt(
        s,
        dx: Len(horizontal ? cursor - s.x.nm : 0),
        dy: Len(horizontal ? 0 : cursor - s.y.nm),
      ),
    ));
    cursor += extent(s) + gap;
  }
  return _writes(body, writes);
}

/// The slots [selection] names, in the panel's own order.
///
/// SILENTLY DROPS A KEY THE PANEL DOES NOT HOLD, which is the right
/// behaviour rather than a lapse: a port whose connector states no cutout
/// gets no slot at all ([RenderedPanel.noCutout]), and it can legitimately
/// be selected in the grid while having nothing on the panel to move.
List<PanelSlot> _selected(RenderedPanel panel, Set<String> selection) => [
  for (final s in panel.slots)
    if (selection.contains(s.portKey.v)) s,
];

/// Turns (port, position) pairs into commands, skipping the no-ops.
///
/// A command whose `from` equals its `to` is an undo entry that does
/// nothing, and a toolbar that mints one per press makes `Ctrl+Z` feel
/// broken. This is where align-when-already-aligned stops being an edit.
List<Command<TemplateBody>> _writes(
  TemplateBody body,
  List<(PortKey, PanelPosition?)> pairs,
) {
  final byKey = {for (final port in body.ports) port.key.v: port};
  final out = <Command<TemplateBody>>[];
  for (final (key, to) in pairs) {
    final port = byKey[key.v];
    if (port == null) continue;
    final from = port.position;
    if (_samePosition(from, to)) continue;
    out.add(
      SetPortFieldCommand<PanelPosition?>(
        port: key,
        field: PortDefField.panelPosition,
        from: from,
        to: to,
      ),
    );
  }
  return out;
}

bool _samePosition(PanelPosition? a, PanelPosition? b) {
  if (a == null || b == null) return a == null && b == null;
  return a.ruOffset == b.ruOffset &&
      a.xTwelfth == b.xTwelfth &&
      a.xFineNm.nm == b.xFineNm.nm &&
      a.yFineNm.nm == b.yFineNm.nm;
}
