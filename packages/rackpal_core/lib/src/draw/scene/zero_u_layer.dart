// AC-044's plain bar: a 0U occupant, drawn on the rail it is screwed to
// (`#883`, DR-166 §11.165).
//
// ═══════════════════════════════════════════════════════════════════════
// THE HALF OF AC-044 THAT MADE THE OTHER HALF UNREACHABLE
// ═══════════════════════════════════════════════════════════════════════
// That ruling keeps two things in v1: a 0U occupant *"is created and
// edited from the inspector (channel, start U, span)"* and *"renders as a
// plain bar"*. `scene_builder.dart` read `if (placement is! RailPlacement)
// continue;`, so a 0U device was never in the scene, never hit-tested and
// therefore **never selectable** — which is why `#876` had to put its
// fields on the rack panel rather than on the device inspector where
// AC-044 puts them (§11.162.1).
//
// ═══════════════════════════════════════════════════════════════════════
// ON THE RAIL, WHICH IS WHERE THE DEVICE ACTUALLY IS (§11.165.4)
// ═══════════════════════════════════════════════════════════════════════
// AC-044 sends the 16 px gutters and ROTATED bar rendering to v1.1, so the
// v1 bar is neither in a gutter nor turned. The rail already exists in the
// geometry, is ≈7.9 diagram units wide (derived from the real EIA-19
// flange of 15.875 mm, not from a figure in a spec), and is the post a 0U
// PDU is screwed to. `ZeroUChannelSide` already names front/rear × left/
// right, which is exactly the two rails of the face being drawn.
//
// **No new width and no layout change**, so every elevation and every
// printed sheet keeps the geometry it had, and v1.1's gutters can still be
// added OUTSIDE the panel when that half lands.
//
// ═══════════════════════════════════════════════════════════════════════
// AND NO TEXT, WHICH IS WHAT "PLAIN" COSTS
// ═══════════════════════════════════════════════════════════════════════
// 7.9 units is narrower than any legible glyph, and the rotation that
// would let a designator run up the bar is the v1.1 half. So the bar
// carries no ink label and says who it is through selection and through
// `DeviceLayout.semanticLabel`, which is what a screen reader reads. A
// horizontal label beside the bar was the alternative and was refused: it
// would collide with every rack-mounted device at the same U, and
// suppressing it on collision is an overlap rule, which AC-044 also
// defers.
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/rack_geometry.dart';
import 'package:rackpal_core/src/draw/scene/rack_layer.dart' show LayerBuild;
import 'package:rackpal_core/src/draw/scene/rack_style.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/zero_u_channel.dart';
import 'package:rackpal_core/src/units/constants.dart';

/// One occupant, resolved against the channel it names.
typedef ZeroUBar = ({DeviceInstance device, DBox rect, bool lengthKnown});

/// Is [side] on the face being drawn?
bool zeroUSideOnFace(ZeroUChannelSide side, Face face) => switch (side) {
  ZeroUChannelSide.frontLeft ||
  ZeroUChannelSide.frontRight => face == Face.front,
  ZeroUChannelSide.rearLeft || ZeroUChannelSide.rearRight => face == Face.rear,
};

/// Is [side] the LEFT rail as the model names it?
bool zeroUSideIsLeft(ZeroUChannelSide side) =>
    side == ZeroUChannelSide.frontLeft || side == ZeroUChannelSide.rearLeft;

/// Every 0U occupant of [rack] visible on [face], with the rect its bar
/// occupies.
///
/// **[mirrored] SWAPS LEFT AND RIGHT, and nothing else.** A mirrored rear
/// elevation is the same rack read from behind, so the rail a person sees
/// on their left is the one the model calls right. This is the same flag
/// the device layer honours and is passed in rather than recomputed, so
/// the two cannot disagree about which way round the rack is.
List<ZeroUBar> zeroUBars({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Face face,
  required RackGeometry geo,
  required bool mirrored,
}) {
  final channels = <String, ZeroUChannel>{
    for (final c in rack.zeroUChannels) c.id: c,
  };
  final out = <ZeroUBar>[];
  for (final device in devices) {
    final placement = device.placement;
    if (placement is! ZeroUPlacement) continue;
    if (placement.rackId != rack.id) continue;
    final channel = channels[placement.channelId];
    // A CHANNEL THE RACK DOES NOT HAVE IS NOT DRAWN AND NOT A CRASH.
    // `PLC-003` reports it as a finding; a scene builder that threw on it
    // would take the whole elevation down over one bad reference in a
    // hand-edited file.
    if (channel == null) continue;
    if (!zeroUSideOnFace(channel.side, face)) continue;

    final onLeft = zeroUSideIsLeft(channel.side) != mirrored;
    final left = onLeft ? geo.railLeft : geo.rightRailLeft;

    // THE BOTTOM IS THE OCCUPANT'S OWN START, not the channel's: the
    // offset is how far ALONG the channel it sits, and a channel starting
    // at U 1 with a device 4 U up is a device at U 5.
    final startU =
        channel.startU + placement.offsetFromChannelStart.nm ~/ kRackUnit.nm;
    final bottom = geo.yBottomOfU(startU);

    // **UNKNOWN LENGTH IS ONE U AND SAYS SO** (G4, CR-114, §11.165.2).
    // Every document written before `#883` has no span, so this is the
    // ordinary case rather than an edge, and a bar drawn full height
    // would be the fabricated total G4 exists to refuse.
    final span = placement.spanAlongChannel;
    final height = span == null
        ? RackGeometry.unitsPerRu
        : RackGeometry.unitsForLen(span);

    out.add((
      device: device,
      rect: DBox.fromLtwh(
        left,
        bottom - height,
        RackGeometry.railWidth,
        height,
      ),
      lengthKnown: span != null,
    ));
  }
  return out;
}

/// The ops for one bar, in LOCAL space: the rect's own top-left is the
/// origin, as a device fragment's is.
///
/// **AN OUTLINE WHEN THE LENGTH IS UNKNOWN, A FILL WHEN IT IS KNOWN.**
/// That is G4's rule given a shape instead of a number: a hollow stub
/// reads as "something is mounted here and the file does not say how much
/// of it there is", where a solid bar of invented height would read as a
/// measurement. The inspector's span field is the place that fixes it, and
/// it shows the same unknown.
LayerBuild buildZeroUBarLayer({
  required ZeroUBar bar,
  required RackPalette palette,
}) {
  final local = DBox.fromLtwh(0, 0, bar.rect.width, bar.rect.height);
  final ops = <DiagramOp>[
    OpRect(
      local,
      fill: bar.lengthKnown ? Fill(palette.deviceFill) : null,
      stroke: Stroke(argb: palette.deviceStroke, widthPt: 0.6),
    ),
  ];
  return (ops: ops, minTextPt: double.infinity, inkBounds: local);
}
