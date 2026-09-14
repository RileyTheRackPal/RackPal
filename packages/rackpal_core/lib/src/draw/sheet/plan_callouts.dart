// rackpal_core/src/draw/sheet/plan_callouts.dart — the designator pills on
// `T1.01` (docs/15 §7, DR-150 §11.149, `PLAN-H/3`).
//
// ═══════════════════════════════════════════════════════════════════════
// IT LAYS OUT IN PAGE SPACE, OUTSIDE THE DRAWING'S TRANSFORM BRACKET
// ═══════════════════════════════════════════════════════════════════════
// `plan_sheet.dart` splices the plan scene inside one save/transform/
// restore, and everything in that bracket scales with the drawing.
// **Annotation must not.** `elevation_sheet.dart` records the same
// asymmetry: text inside the bracket shrinks with the picture and the
// title block does not.
//
// It matters more here than there, because scene units on a plan are
// IMAGE PIXELS. A 600-pixel scan and a 4000-pixel scan of one floor fit to
// the same paper, so a pill sized in scene units would print six times
// larger on one than the other for no reason a reader could see. So the
// caller maps each pin through the fit factor and this file works in
// points, and a designator is the same size on every plan in the set.
//
// ═══════════════════════════════════════════════════════════════════════
// OPAQUE, BLACK, AND NO COLOUR AT ALL (DR-150 §11.149.2)
// ═══════════════════════════════════════════════════════════════════════
// `#642` asked for the signal domain's colour. **A pin carries no domain**:
// `Rack` and `Outlet` hold no `SignalFamilyId` and an off-rack device spans
// several, which `plan_scene.dart` wrote down at `PLAN-E/2`. AC-054 prints
// the sheet greyscale anyway.
//
// **The fill is a KNOCK-OUT and not a contrast device.** Black on the
// darkest sample the screening can leave is 11.5:1 (§11.149.4), so
// luminance was never the risk. Dense line work is, and it fails by
// PATTERN: a dimension string crossing a designator is unreadable at any
// ratio. Masking is what a callout bubble is for.
//
// ═══════════════════════════════════════════════════════════════════════
// THE PILL'S GEOMETRY IS BORROWED REASONING, NOT BORROWED CODE
// ═══════════════════════════════════════════════════════════════════════
// `#642` says to reuse the schematic's tag pill. `_PillSizer` is **private
// to `rackpal_ui/src/canvas/schematic/wire_trace.dart`**, and
// `rackpal_export` may never import `rackpal_ui` (docs/03 §7.1) — the
// layering debt recorded since 2026-07-28 that leaves M6's interconnect
// sheets unbuildable until that file moves. Moving a thousand-line file to
// borrow ninety of them belongs to M6 and not to a chapter about callouts
// (DR-150 §11.149.6).
//
// Three of its rules are taken deliberately and each is cited below: the
// near edge anchors rather than the centre, the height comes from the type
// size rather than from font metrics, and the radius is half the height so
// the shape is a stadium.
//
// ═══════════════════════════════════════════════════════════════════════
// A CALLOUT IS NEVER DROPPED
// ═══════════════════════════════════════════════════════════════════════
// When the ring is exhausted the pill is placed at its preferred offset
// anyway, overlapping, with a leader, and [PlanCalloutLayer.crowdedCount]
// says how many. **An absent callout is a drop the stranger cannot find;
// an overlapping one is a drop they can read twice** (G4). The sheet
// reports what it could not place rather than printing fewer callouts than
// there are pins.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// One pin, already mapped to the page, with what it prints.
@immutable
final class CalloutSubject {
  const CalloutSubject({
    required this.entityId,
    required this.at,
    required this.text,
  });

  /// The carrier the pin hangs on. Carried through so the layout order is
  /// the caller's total order rather than this file's.
  final Uuid entityId;

  /// Where the marker sits, in PAGE points.
  final DPt at;

  /// The carrier's own designator — `RK-1`, `WP-1`, `TV-1`
  /// (DR-150 §11.149.3).
  final String text;
}

/// Everything the callouts contribute to a sheet.
@immutable
final class PlanCalloutLayer {
  const PlanCalloutLayer({
    required this.ops,
    required this.crowdedCount,
    required this.leaderCount,
  });

  final List<DiagramOp> ops;

  /// How many pills could not be placed clear of every other one.
  ///
  /// **A NUMBER RATHER THAN A SILENCE.** These are the callouts a reader
  /// may have to disentangle, and `build_document.dart` turns a non-zero
  /// value into an export notice: a sheet that quietly overlaps two
  /// designators looks exactly like a sheet with one drop on that wall.
  final int crowdedCount;

  /// How many pills sit far enough from their pin to need a leader.
  final int leaderCount;
}

/// The pill's type size, in points.
///
/// **A STARTING VALUE, NOT A RULING** (DR-150 §11.149.7), on the retired
/// marker fraction's precedent. What settles it is `PLAN-J`'s print: a
/// designator is read at arm's length off an ANSI B sheet, and no number
/// chosen on a monitor is evidence about that.
///
/// **AND MOVING IT MOVES THE PRINTED MARK** (`#904`, DR-169 §11.168.10).
/// A mark on `T1.01` is ruled to be the size of this pill's round end, so
/// `kPlanMarkPrintRadiusPt` is derived from [kCalloutHeightPt] rather than
/// written out beside it, and a print drill that re-tunes the pill carries
/// the mark with it.
const double kCalloutTextPt = 6.5;

/// Inset of the pill's text from its own outline, in points.
const double kCalloutPadPt = 2;

/// The pill's height, in points, which is twice the radius of its ends.
///
/// From the type size and not from font metrics, for the reason given where
/// the pill is laid out. Named rather than left a local because the printed
/// plan mark reads it (§11.168.10), and two spellings of one sum are two
/// answers the day either term moves.
const double kCalloutHeightPt = kCalloutTextPt + kCalloutPadPt * 2;

/// The pill outline's width, in points.
const double kCalloutOutlinePt = 0.5;

/// The gap between a pin and the NEAR EDGE of its pill at the preferred
/// offset, in points.
const double kCalloutOffsetPt = 6;

/// How far a pill's NEAR EDGE may sit from its pin before it needs a
/// leader.
///
/// ═══════════════════════════════════════════════════════════════════════
/// NEAR EDGE AND NOT CENTRE, WHICH A TEST HAD TO SAY OUT LOUD
/// ═══════════════════════════════════════════════════════════════════════
/// The first draft measured pin-centre to pill-CENTRE, and a lone pin with
/// a four-character designator drew a leader to a pill sitting at its
/// preferred offset: the centre is half a pill-width away and a pill is as
/// wide as its text. Measuring the centre makes the leader rule a function
/// of how long a designator happens to be, which is not what docs/15 §7
/// says. **The pill's near edge is where "within its own pin's clearance"
/// is decided**, and it is exactly the ring radius, so no distance has to
/// be computed at all.
const double kCalloutClearancePt = 10;

/// The gap kept between two pills before they count as colliding.
const double kCalloutGapPt = 1.5;

/// Lays out one callout per subject and returns the page-space ops.
///
/// [area] is the drawing area: a pill is never placed with any part
/// outside it, because a callout under the title block is a callout
/// nobody reads.
PlanCalloutLayer buildPlanCallouts({
  required List<CalloutSubject> subjects,
  required DBox area,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  final ops = <DiagramOp>[];
  final placed = <DBox>[];
  var crowded = 0;
  var leaders = 0;

  final spec = TextStyleSpec(
    font: kSheetFont,
    sizePt: kCalloutTextPt,
    argb: palette.text,
    anchor: TextAnchor.midCenter,
  );

  for (final subject in subjects) {
    final width =
        measurer.measureText(subject.text, spec).advanceWidth +
        kCalloutPadPt * 2;
    // HEIGHT FROM THE TYPE SIZE, NOT FROM FONT METRICS. `wire_trace.dart`'s
    // reason transfers exactly: the two backends agree on `sizePt` and on
    // ascent/descent only up to their font tables, and a pill a different
    // height on screen than on paper is a parity defect.
    const height = kCalloutHeightPt;

    final spot = _place(
      pin: subject.at,
      width: width,
      height: height,
      area: area,
      placed: placed,
    );
    if (!spot.clear) crowded++;
    placed.add(spot.box);

    final centre = DPt(
      spot.box.left + width / 2,
      spot.box.top + height / 2,
    );
    if (spot.radius > kCalloutClearancePt) {
      leaders++;
      // FROM THE PIN TO THE PILL'S EDGE, not to its centre: a line that
      // ran under the fill would be hidden by the knock-out at one end and
      // visible at the other, which reads as a line that stops short.
      ops.add(
        OpLine(
          subject.at,
          _edgeToward(spot.box, subject.at),
          sheetRule(palette.rule, kCalloutOutlinePt),
        ),
      );
    }

    ops
      ..add(
        OpRoundRect(
          spot.box,
          // A STADIUM: radius half the height, which is what "pill" means
          // and what tells it apart at a glance from the net-label
          // pennant.
          const Radii.circular(height / 2),
          // OPAQUE PAPER, which is the knock-out. Not a tint and not an
          // alpha: docs/08 row 9 forbids alpha in the document
          // absolutely, and a translucent fill would be exactly the wash
          // DR-150 §11.149.2 refused.
          fill: const Fill(0xFFFFFFFF),
          stroke: sheetRule(palette.rule, kCalloutOutlinePt),
        ),
      )
      ..add(OpText(subject.text, centre, spec));
  }

  return PlanCalloutLayer(
    ops: List.unmodifiable(ops),
    crowdedCount: crowded,
    leaderCount: leaders,
  );
}

/// Where one pill lands, whether it got there without a collision, and how
/// far its near edge ended up from the pin.
typedef _Spot = ({DBox box, bool clear, double radius});

/// The ring, in order. Angles clockwise from the preferred north-east,
/// at three radii.
///
/// **DETERMINISTIC AND NOT CLEVER** (DR-150 §11.149.5). It is a heuristic
/// rather than a layout solver, and it is reproducible because the caller
/// hands subjects in `planPinsFor`'s total order.
///
/// North-east first because a drop's marker is read before its label in
/// left-to-right reading order, and a pill up and to the right sits off
/// the wall the drop is usually on.
const List<double> _ringRadii = <double>[
  kCalloutOffsetPt,
  kCalloutClearancePt * 1.6,
  kCalloutClearancePt * 3.1,
  kCalloutClearancePt * 5.2,
];

const List<(double dx, double dy)> _ring = <(double, double)>[
  (0.75, -1),
  (1, 0),
  (0.75, 1),
  (0, 1),
  (-0.75, 1),
  (-1, 0),
  (-0.75, -1),
  (0, -1),
];

_Spot _place({
  required DPt pin,
  required double width,
  required double height,
  required DBox area,
  required List<DBox> placed,
}) {
  DBox boxAt(double dx, double dy, double radius) {
    // THE PILL'S NEAR EDGE ANCHORS, NOT ITS CENTRE. `wire_trace.dart`'s
    // finding, taken deliberately: a pill centred on its anchor puts half
    // of itself back over the thing it labels, and there the field
    // screenshot showed `HDMI IN 1` reading as `MI IN 1`. Here the thing
    // underneath is the marker and the architect's wall.
    final cx = pin.x + dx * (radius + width / 2);
    final cy = pin.y + dy * (radius + height / 2);
    return DBox.fromLtwh(cx - width / 2, cy - height / 2, width, height);
  }

  DBox? fallback;
  // THE FIRST RADIUS IS THE ONLY ONE INSIDE THE CLEARANCE, so a pill that
  // had to move gets a leader by construction: docs/15 §7 draws one
  // "only when the pill cannot sit within its own pin's clearance", and
  // having moved is exactly what that means.
  for (final radius in _ringRadii) {
    for (final (dx, dy) in _ring) {
      final box = boxAt(dx, dy, radius);
      fallback ??= box;
      if (!_insideArea(box, area)) continue;
      if (placed.any((other) => _collides(box, other))) continue;
      return (box: box, clear: true, radius: radius);
    }
  }
  // THE RING IS EXHAUSTED AND THE CALLOUT IS STILL DRAWN (§11.149.5).
  return (box: fallback!, clear: false, radius: _ringRadii.last);
}

bool _insideArea(DBox box, DBox area) =>
    box.left >= area.left &&
    box.top >= area.top &&
    box.right <= area.right &&
    box.bottom <= area.bottom;

bool _collides(DBox a, DBox b) =>
    a.inflate(kCalloutGapPt / 2).intersects(b.inflate(kCalloutGapPt / 2));

/// The point on [box]'s outline nearest [from], clamped to its edges.
DPt _edgeToward(DBox box, DPt from) => DPt(
  from.x.clamp(box.left, box.right),
  from.y.clamp(box.top, box.bottom),
);
