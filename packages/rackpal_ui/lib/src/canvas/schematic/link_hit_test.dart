// rackpal_ui/src/canvas/schematic/link_hit_test.dart
//
// POINTING AT A CABLE. Under DR-001 the default render of a link is a pair
// of net-label pennants, so the thing on the sheet a user can actually aim
// at is a pennant — not a wire, which exists only inside a hovered or
// filtered scope.
//
// ═════════════════════════════════════════════════════════════════════
// NO NEW GEOMETRY, AND `net_label_layer.dart` ALREADY SAID SO
// ═════════════════════════════════════════════════════════════════════
// `RenderedNetLabel.pennant` is the pennant's outer box, ABSOLUTE and apex
// included, measured by the layer that drew it. That field exists for
// exactly this: its own header records the decision to keep link ids OUT of
// `DiagramScene.hitRegions` — *"mixing link ids into it would silently
// change what every existing consumer of that list is looking at. The
// geometry M2-E needs is published as `RenderedNetLabel` instead — measured
// here, once, so a hover test cannot drift from what was drawn."*
//
// So this file measures nothing. It reads what was drawn, which is the
// difference between a hit test and a second opinion.
//
// ═════════════════════════════════════════════════════════════════════
// LAST DRAWN WINS
// ═════════════════════════════════════════════════════════════════════
// `scene.netLabels` is in the scene's own op order — by domain, then by
// link — and the display list has no z-index, so a later pennant paints
// over an earlier one. Two overlapping pennants therefore resolve to the
// one the user can SEE, which means walking the list backwards. Ranking by
// distance-to-centre instead would hand back the pennant underneath
// whenever the visible one is the larger of the two.

import 'package:meta/meta.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// The link whose pennant contains [point], or null when none does.
///
/// [tolerance] is in DIAGRAM UNITS, not pixels — the caller converts, the
/// same way `schematic_canvas_screen.dart` converts docs/05 §11.6's 12 px
/// pin tolerance by the live scale. A constant in diagram units is 20x
/// stricter at 20x zoom.
///
/// A link with BOTH pennants under the point resolves to itself either way,
/// so this needs no de-duplication: the answer is a link id, and both of a
/// link's labels carry the same one (§11.5 — *"both flags of a net show the
/// identical string and highlight together on hover"*).
Uuid? linkAtPoint(
  SchematicScene scene,
  DPt point, {
  double tolerance = 0,
}) {
  for (var i = scene.netLabels.length - 1; i >= 0; i--) {
    final label = scene.netLabels[i];
    if (label.pennant.inflate(tolerance).contains(point)) return label.linkId;
  }
  return null;
}

/// What a press on a pennant would write: which run, which END of it, and
/// whether writing it LANDS the run or MOVES it.
///
/// ═════════════════════════════════════════════════════════════════════
/// THE ANCHOR IS THE END THIS GESTURE IS NOT WRITING
/// ═════════════════════════════════════════════════════════════════════
/// One rule covering two opposite readings of a pennant (see
/// `_runEndAt`), and it is what makes the preview honest: the band drawn
/// while the pointer is down spans [anchorPortId] and whatever pin the
/// pointer is over, which is exactly the pair the document holds one
/// event later (DR-073 §11.72.2). A landing anchors on the pin the run
/// already has; a move anchors on the FAR end and swings the near one.
@immutable
final class RunEndGrab {
  const RunEndGrab({
    required this.linkId,
    required this.end,
    required this.anchorPortId,
    required this.moving,
  });

  /// The home run being finished or corrected.
  final Uuid linkId;

  /// The end a commit will write. `Conductor.from` for [LinkEnd.field],
  /// `to` for [LinkEnd.rack].
  final LinkEnd end;

  /// The pin at the OTHER end, which the preview band starts from.
  final Uuid anchorPortId;

  /// True when [end] already sits on a pin, so the commit is
  /// `MoveEndpointCommand` rather than `BindEndpointCommand` (DR-074
  /// §11.73.1). They are two acts with two undo labels, and the surface
  /// carries the distinction because the model does.
  final bool moving;

  @override
  String toString() =>
      'RunEndGrab(${moving ? 'move' : 'land'} ${end.name} of $linkId)';
}

/// The rendered pennant containing [point], or null when none does.
///
/// WHICH PENNANT, NOT WHICH LINK, and that distinction is what DR-074
/// §11.73.1 needs. [linkAtPoint] answers with a link id, and a run landed
/// at BOTH ends draws two pennants carrying the same one: a gesture that
/// moves "the end you grabbed" cannot be built on an answer that cannot
/// tell the two apart. `RenderedNetLabel` already carries the device and
/// the port key it was drawn against, so the end is readable off the hit
/// with no new geometry.
///
/// Same walk, same LAST DRAWN WINS rule, same tolerance contract as
/// [linkAtPoint] — one measurement, read two ways, rather than two walks
/// that can disagree about which pennant is on top.
RenderedNetLabel? netLabelAtPoint(
  SchematicScene scene,
  DPt point, {
  double tolerance = 0,
}) {
  for (var i = scene.netLabels.length - 1; i >= 0; i--) {
    final label = scene.netLabels[i];
    if (label.pennant.inflate(tolerance).contains(point)) return label;
  }
  return null;
}

/// Every rendered pennant belonging to [linkId], in the scene's op order.
///
/// USUALLY TWO, and the exceptions are both normal rather than faults: ONE
/// for a home run to the field (AC-018 — the far end is an `OpenEndpoint`
/// and lands on no pin), and ZERO when the link's domain is filtered out or
/// neither of its devices has a symbol on this sheet. A caller drawing a
/// selection mark iterates whatever it gets; a caller that assumed two
/// would draw a mark at a stale position on a filtered sheet.
List<RenderedNetLabel> pennantsOfLink(SchematicScene scene, Uuid linkId) =>
    <RenderedNetLabel>[
      for (final label in scene.netLabels)
        if (label.linkId == linkId) label,
    ];
