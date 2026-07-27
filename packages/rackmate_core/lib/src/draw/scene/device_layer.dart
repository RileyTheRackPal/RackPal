// rackmate_core/src/draw/scene/device_layer.dart — pure Dart.
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
// name + type only. DEFERRED and NOT drawn: the rear port strip, weight
// microtext, PDU outlet map, finding/lock/reversed badges, ⚡ amps, and the
// 🔗 port-count chip (docs/04 §2.1 ≥0.75 / ≥1.50 tiers) — ports and wiring
// are M2's job. `DeviceOverrides` (device_instance.dart) are also not
// applied yet: the type name comes straight from the template body.

import 'dart:math' as math;

import 'package:rackmate_core/src/draw/bounds_canvas.dart';
import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/draw/ops.dart';
import 'package:rackmate_core/src/draw/scene/rack_geometry.dart';
import 'package:rackmate_core/src/draw/scene/rack_layer.dart' show LayerBuild;
import 'package:rackmate_core/src/draw/scene/rack_style.dart';
import 'package:rackmate_core/src/draw/spec.dart';
import 'package:rackmate_core/src/draw/text.dart';
import 'package:rackmate_core/src/model/device_instance.dart';
import 'package:rackmate_core/src/model/template.dart' show TemplateBody;

const double _pad = 4;

/// Builds [device]'s local-coordinate fragment. [body] is the resolved
/// template body, [deviceH] the U-height on the current face, and
/// [width]/[height] the device's diagram-space extent (from
/// [RackGeometry.deviceRect]). [measurer] is used at [LodLevel.block] to
/// decide whether the designator actually fits (docs/04 §2.1: "designator
/// only if ≥ 20 px wide").
LayerBuild buildDeviceLayer(
  DeviceInstance device,
  TemplateBody body, {
  required int deviceH,
  required double width,
  required double height,
  required LodLevel lod,
  required RackPalette palette,
  required TextMeasurer measurer,
}) {
  final ops = <DiagramOp>[];
  final sizes = <double>[];

  final rect = DBox.fromLtwh(0, 0, width, height);
  final fill = Fill(palette.deviceFill);
  final stroke = Stroke(argb: palette.deviceStroke, widthPt: 1);

  // Body: rounded at ≥0.75 zoom, a plain block below (docs/04 §2.1).
  if (lod == LodLevel.full || lod == LodLevel.detail) {
    ops.add(
      OpRoundRect(rect, const Radii.circular(3), fill: fill, stroke: stroke),
    );
  } else {
    ops.add(OpRect(rect, fill: fill, stroke: stroke));
  }

  final designator = device.designator;
  final name = device.name;
  final typeName = body.displayName;

  if (lod == LodLevel.block) {
    // Solid block: designator centred, ONLY if it fits (measured) and the
    // body is at least 20 units wide.
    final style = rackText(
      RackTextSizes.designator,
      palette.deviceDesignator,
      TextAnchor.midCenter,
    );
    final m = measurer.measureText(designator, style);
    if (width >= 20 && m.advanceWidth <= width - 2 * _pad) {
      ops.add(OpText(designator, DPt(width / 2, height / 2), style));
      sizes.add(RackTextSizes.designator);
    }
  } else {
    // Designator (top-left) + U-height badge (top-right) on every tier at
    // or above `badge`.
    ops.add(
      OpText(
        designator,
        const DPt(_pad, _pad),
        rackText(
          RackTextSizes.designator,
          palette.deviceDesignator,
          TextAnchor.topLeft,
        ),
      ),
    );
    sizes.add(RackTextSizes.designator);

    ops.add(
      OpText(
        '${deviceH}U',
        DPt(width - _pad, _pad),
        rackText(RackTextSizes.badge, palette.deviceBadge, TextAnchor.topRight),
      ),
    );
    sizes.add(RackTextSizes.badge);

    // full / detail: stack name then type below the designator, each only
    // if it fits vertically (a 1U body has room for the designator only).
    if (lod == LodLevel.full || lod == LodLevel.detail) {
      var y = _pad + RackTextSizes.designator + 2;
      if (y + RackTextSizes.name <= height - _pad) {
        ops.add(
          OpText(
            name,
            DPt(_pad, y),
            rackText(
              RackTextSizes.name,
              palette.deviceName,
              TextAnchor.topLeft,
            ),
          ),
        );
        sizes.add(RackTextSizes.name);
        y += RackTextSizes.name + 2;
      }
      if (typeName.isNotEmpty && y + RackTextSizes.type <= height - _pad) {
        ops.add(
          OpText(
            typeName,
            DPt(_pad, y),
            rackText(
              RackTextSizes.type,
              palette.deviceType,
              TextAnchor.topLeft,
            ),
          ),
        );
        sizes.add(RackTextSizes.type);
      }
    }
  }

  return (
    ops: ops,
    minTextPt: sizes.isEmpty ? double.infinity : sizes.reduce(math.min),
    inkBounds: inkBoundsOf(ops, measurer: measurer),
  );
}
