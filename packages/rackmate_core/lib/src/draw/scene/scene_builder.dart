// rackmate_core/src/draw/scene/scene_builder.dart — pure Dart.
//
// The single conversion point from the model's integer RU-index geometry to
// the drawing IR's double diagram-space geometry (CR-006/CR-007): composes
// the chassis fragment (rack_layer) and one fragment per device
// (device_layer) into ONE `DiagramScene`. Elevation X/Y is derived HERE,
// from `(Placement, rail geometry, face)`, and never stored — and it never
// leaks upward: `rackmate_ui` consumes the finished `DiagramScene` +
// [RackScene] layout and does no RU arithmetic of its own.
//
// SCENE LAYOUT, stated once because two coordinate conventions coexist in
// one scene by design:
//   * The chassis fragment (`fragments[rack.id]`) is in ABSOLUTE scene
//     coordinates (rack top-left at the origin) and replays as the
//     background with no translate.
//   * Each device fragment (`fragments[device.id]`) is in the device's own
//     LOCAL coordinates. In the composed `scene.ops` it is bracketed by
//     `OpSave` / `OpTransform(translate → absolute)` / … / `OpRestore`, so
//     a WHOLE-scene replay (a future PDF export, BoundsCanvas) is coherent
//     and absolute. But `fragments[device.id]` points at the LOCAL ops
//     ONLY (inside that bracket), because `RenderDeviceBox` positions the
//     fragment itself via its parent-data offset (docs/03 §7.8) — so its
//     replay must NOT re-apply the absolute translate.
// `hits` are absolute (hit-testing happens in scene space), which is also
// where each device's on-screen rect comes from.

import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/draw/ops.dart';
import 'package:rackmate_core/src/draw/scene/device_layer.dart';
import 'package:rackmate_core/src/draw/scene/rack_geometry.dart';
import 'package:rackmate_core/src/draw/scene/rack_layer.dart';
import 'package:rackmate_core/src/draw/scene/rack_style.dart';
import 'package:rackmate_core/src/draw/text.dart';
import 'package:rackmate_core/src/model/device_instance.dart';
import 'package:rackmate_core/src/model/placement.dart';
import 'package:rackmate_core/src/model/rack.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:vector_math/vector_math_64.dart';

/// One device's on-screen placement, derived from the model for the current
/// face + LOD. `rackmate_ui` positions the device's `RenderBox` child from
/// [rect] (its `sceneOffset`/`sceneSize`) and reads its fragment via
/// `scene.fragmentFor(deviceId.v)`.
final class DeviceLayout {
  const DeviceLayout({
    required this.deviceId,
    required this.rect,
    required this.semanticLabel,
  });

  final Uuid deviceId;

  /// Absolute diagram-space rect of the device body.
  final DBox rect;

  /// Accessible label — "DES — Name, Type" (docs/04 §7 / §9: the device
  /// widget carries this natively, a core reason the render architecture is
  /// a widget/IR hybrid rather than pure canvas).
  final String semanticLabel;
}

/// The output of [buildRackScene]: the composed [scene] plus the
/// per-device layout the UI needs to place render-object children, and the
/// chassis bounds.
final class RackScene {
  const RackScene({
    required this.scene,
    required this.rackId,
    required this.devices,
    required this.chassisBounds,
  });

  /// The one composed display list. `fragmentFor(rackId.v)` → chassis;
  /// `fragmentFor(deviceId.v)` → that device's local fragment.
  final DiagramScene scene;

  final Uuid rackId;

  /// Visible devices on the requested face, in bottom-to-top order.
  final List<DeviceLayout> devices;

  /// Absolute bounds of the rack chassis (rack top-left at origin).
  final DBox chassisBounds;
}

/// Builds the [RackScene] for [rack] + its [devices] on [face] at [lod].
///
/// [templates] resolves each device's `TemplateRef` to a body; [measurer]
/// is injected (CR-081) and threaded to the layers. A device is drawn only
/// when it is rail-mounted on [face] and occupies ≥ 1 U on that face —
/// anything else is simply skipped (docs/04 §2.2's face is a coordinate,
/// but this stage's face is a filter; rear-mirroring and dual-face
/// occupancy are deferred, see the file docs of rack_layer/device_layer).
RackScene buildRackScene({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Map<String, TemplateSnapshot> templates,
  required Face face,
  required LodLevel lod,
  required TextMeasurer measurer,
  RackPalette palette = const RackPalette(),
}) {
  final geo = RackGeometry(rack.heightU);
  final ops = <DiagramOp>[];
  final fragments = <String, IntRange>{};
  final hits = <HitRegion>[];
  final layouts = <DeviceLayout>[];
  var minText = double.infinity;
  var bounds = DBox.fromLtwh(0, 0, geo.rackWidth, geo.rackHeight);

  // ── chassis fragment (absolute, keyed by the rack id) ────────────────
  final chassis = buildRackLayer(rack, geo, measurer, lod, palette);
  ops.addAll(chassis.ops);
  fragments[rack.id.v] = IntRange(0, ops.length);
  minText = _min(minText, chassis.minTextPt);

  // ── device fragments (local, wrapped in an absolute translate) ───────
  final visible = _visibleDevices(rack, devices, templates, face);
  for (final entry in visible) {
    final device = entry.device;
    final body = entry.body;
    final deviceH = entry.deviceH;
    final placement = entry.placement;

    final rect = geo.deviceRect(
      placement.ruIndex,
      deviceH,
      startTwelfth: placement.startTwelfth,
      spanTwelfths: placement.spanTwelfths,
    );

    final built = buildDeviceLayer(
      device,
      body,
      deviceH: deviceH,
      width: rect.width,
      height: rect.height,
      lod: lod,
      palette: palette,
      measurer: measurer,
    );

    ops
      ..add(const OpSave())
      ..add(OpTransform(Matrix4.translationValues(rect.left, rect.top, 0)));
    final localStart = ops.length;
    ops.addAll(built.ops);
    final localEnd = ops.length;
    ops.add(const OpRestore());

    // The fragment is the LOCAL ops only (see the file header) — the
    // wrapping save/translate/restore stay in scene.ops for whole-scene
    // replay but are excluded from what RenderDeviceBox replays.
    fragments[device.id.v] = IntRange(localStart, localEnd);
    hits.add(HitRegion(device.id.v, rect));
    layouts.add(
      DeviceLayout(
        deviceId: device.id,
        rect: rect,
        semanticLabel: _semanticLabel(device, body),
      ),
    );
    minText = _min(minText, built.minTextPt);
    bounds = bounds.union(rect);
  }

  final scene = DiagramScene(
    ops: ops,
    bounds: bounds,
    hits: hits,
    minTextSizePt: minText.isFinite ? minText : RackTextSizes.ruler,
    fragments: fragments,
  );

  return RackScene(
    scene: scene,
    rackId: rack.id,
    devices: layouts,
    chassisBounds: DBox.fromLtwh(0, 0, geo.rackWidth, geo.rackHeight),
  );
}

/// A resolved, drawable device on the requested face.
final class _VisibleDevice {
  const _VisibleDevice(this.device, this.body, this.placement, this.deviceH);

  final DeviceInstance device;
  final TemplateBody body;
  final RailPlacement placement;
  final int deviceH;
}

/// Filters [devices] to those rail-mounted on [face] with a resolvable
/// template and ≥ 1 U of occupancy on that face, sorted bottom-to-top by
/// `ruIndex` (ties broken by id) for a deterministic op order.
List<_VisibleDevice> _visibleDevices(
  Rack rack,
  Iterable<DeviceInstance> devices,
  Map<String, TemplateSnapshot> templates,
  Face face,
) {
  final out = <_VisibleDevice>[];
  for (final device in devices) {
    final placement = device.placement;
    if (placement is! RailPlacement) continue;
    if (placement.rackId != rack.id) continue;
    if (placement.face != face) continue;

    final snapshot = templates[_templateKey(device.templateRef)];
    if (snapshot == null) continue;
    final body = snapshot.body;

    final deviceH = face == Face.front ? body.frontU : body.rearU;
    if (deviceH <= 0) continue;

    out.add(_VisibleDevice(device, body, placement, deviceH));
  }
  out.sort((a, b) {
    final byRu = a.placement.ruIndex.compareTo(b.placement.ruIndex);
    return byRu != 0 ? byRu : a.device.id.v.compareTo(b.device.id.v);
  });
  return out;
}

/// The `RackDocument.templates` key for [ref] — `"$templateId@$version"`
/// (rack_document.dart / template.dart).
String _templateKey(TemplateRef ref) => '${ref.templateId.v}@${ref.version}';

String _semanticLabel(DeviceInstance device, TemplateBody body) {
  final type = body.displayName;
  final name = device.name;
  final buffer = StringBuffer(device.designator);
  if (name.isNotEmpty) buffer.write(' — $name');
  if (type.isNotEmpty) buffer.write(', $type');
  return buffer.toString();
}

double _min(double a, double b) => a < b ? a : b;
