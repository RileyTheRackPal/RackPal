// rackpal_core/src/draw/scene/scene_builder.dart — pure Dart.
//
// The single conversion point from the model's integer RU-index geometry to
// the drawing IR's double diagram-space geometry (CR-006/CR-007): composes
// the chassis fragment (rack_layer) and one fragment per device
// (device_layer) into ONE `DiagramScene`. Elevation X/Y is derived HERE,
// from `(Placement, rail geometry, face)`, and never stored — and it never
// leaks upward: `rackpal_ui` consumes the finished `DiagramScene` +
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

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/catalog/catalog_passive.dart' show kCatPassive;
import 'package:rackpal_core/src/commands/shelf_placement.dart'
    show devicesOnShelfIn;
import 'package:rackpal_core/src/derived/device_loads.dart'
    show elevationOccupancyU, templateKeyFor;
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/device_layer.dart';
import 'package:rackpal_core/src/draw/scene/rack_geometry.dart';
import 'package:rackpal_core/src/draw/scene/rack_layer.dart';
import 'package:rackpal_core/src/draw/scene/rack_load_gutter.dart';
import 'package:rackpal_core/src/draw/scene/rack_style.dart';
import 'package:rackpal_core/src/draw/scene/shelf_host_layer.dart';
import 'package:rackpal_core/src/draw/scene/zero_u_layer.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/enums.dart' show UnitSystem;
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:vector_math/vector_math_64.dart';

/// One device's on-screen placement, derived from the model for the current
/// face + LOD. `rackpal_ui` positions the device's `RenderBox` child from
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
    this.unlabelledDeviceIds = const <Uuid>[],
    this.shelfOverflow = const <Uuid, Len>{},
  });

  /// The one composed display list. `fragmentFor(rackId.v)` → chassis;
  /// `fragmentFor(deviceId.v)` → that device's local fragment.
  final DiagramScene scene;

  final Uuid rackId;

  /// Visible devices on the requested face, in bottom-to-top order.
  final List<DeviceLayout> devices;

  /// Absolute bounds of the rack chassis (rack top-left at origin).
  final DBox chassisBounds;

  /// The devices in [devices] whose block was drawn with NO designator,
  /// because at this drawing scale the inflated label is taller than the
  /// block (`device_layer.dart`'s ladder, rung 3).
  ///
  /// EMPTY IS THE NORMAL CASE and the screen never fills it — `RackTypeScale`
  /// is the identity there. It exists so a printed sheet can never carry an
  /// unlabelled elevation in silence: `elevation_sheet.dart` turns it into
  /// a note ON the sheet and `build_document.dart` into an export notice.
  final List<Uuid> unlabelledDeviceIds;

  /// Every drawn shelf whose hosts are wider than it is, and by how much
  /// (DR-204 §11.203.8). Its hosts are drawn scaled down together to fit,
  /// which can cost a narrow one its mark under `device_layer.dart`'s own
  /// ladder, so the state is REPORTED rather than left for the picture to
  /// hint at. Empty is the normal case.
  final Map<Uuid, Len> shelfOverflow;
}

/// The sheet-only extras docs/08 §2.2 asks of a rack elevation, grouped so
/// a caller opts into the whole print treatment with one value rather than
/// five booleans it has to keep in step.
///
/// EVERY DEFAULT IS THE SCREEN'S CURRENT BEHAVIOUR. The screen and the
/// sheet share one builder (CR-086) but not one set of options, exactly as
/// they already share it while differing in `face`, `lod` and `palette` —
/// what CR-086 forbids is a SECOND renderer, not a parameter.
@immutable
final class RackSceneOptions {
  const RackSceneOptions({
    this.dualRuler = false,
    this.showRuSpan = false,
    this.lifecycleBorders = false,
    this.hatchPassive = false,
    this.loadGutter = false,
    this.units = UnitSystem.imperial,
    this.typeScale = const RackTypeScale.identity(),
  });

  /// What the on-screen canvas draws.
  static const RackSceneOptions screen = RackSceneOptions();

  /// docs/08 §2.2's "RU ruler BOTH EDGES".
  final bool dualRuler;

  /// docs/08 §2.2's `4U · 12–15` in place of the plain `4U` badge.
  final bool showRuSpan;

  /// docs/08 §2.2's `lifecycleStatus` border — dash and weight, not hue.
  final bool lifecycleBorders;

  /// docs/08 §2.2's "blanks, vents and shelves as hatched bands".
  final bool hatchPassive;

  /// docs/08 §2.2's "cumulative mass from the bottom up, draw, and BTU/hr
  /// in the gutter".
  final bool loadGutter;

  /// Which units the gutter's figures print in
  /// (`ProjectSettings.displayUnits`, CR-097).
  final UnitSystem units;

  /// Inflates every label so it clears §6.2's print floor at a reduced
  /// drawing scale. See [RackTypeScale].
  final RackTypeScale typeScale;

  /// This value with the named fields replaced and everything else
  /// carried over.
  ///
  /// Exists so [forPrint] can be what its name says. It is also the shape
  /// a per-rack or detail-sheet override needs — the callers the old
  /// [forPrint] would have silently discarded.
  ///
  /// EVERY FIELD MUST APPEAR HERE, and `scene_builder_test.dart` asserts
  /// it the only way a language without reflection can: `custom.copyWith()`
  /// with no arguments must equal `custom` for a value whose every field
  /// is non-default. A field added to this class and forgotten here would
  /// otherwise be dropped by [forPrint], silently, on every printed sheet.
  RackSceneOptions copyWith({
    bool? dualRuler,
    bool? showRuSpan,
    bool? lifecycleBorders,
    bool? hatchPassive,
    bool? loadGutter,
    UnitSystem? units,
    RackTypeScale? typeScale,
  }) => RackSceneOptions(
    dualRuler: dualRuler ?? this.dualRuler,
    showRuSpan: showRuSpan ?? this.showRuSpan,
    lifecycleBorders: lifecycleBorders ?? this.lifecycleBorders,
    hatchPassive: hatchPassive ?? this.hatchPassive,
    loadGutter: loadGutter ?? this.loadGutter,
    units: units ?? this.units,
    typeScale: typeScale ?? this.typeScale,
  );

  /// THIS options value with the print treatment applied on top.
  ///
  /// IT NOW USES THE RECEIVER. It used to build a fresh value from
  /// literals and ignore `this` entirely, so
  /// `RackSceneOptions.screen.forPrint(…)` advertised "take the screen
  /// options and add print" while discarding them. `screen` is
  /// all-defaults, so the two agreed and nothing was wrong on paper — but
  /// a detail sheet or a per-rack override written as
  /// `myOptions.forPrint(…)` would have lost every customisation, and so
  /// would ANY field added to this class after today, with no compiler or
  /// test complaint either time.
  ///
  /// The five treatment flags are still forced, because they ARE the
  /// print treatment: docs/08 §2.2 asks a printed elevation for both
  /// rulers, the RU span label, lifecycle borders, hatched passives and
  /// the load gutter. Everything else the receiver carries survives.
  RackSceneOptions forPrint({
    required RackTypeScale typeScale,
    required UnitSystem units,
  }) => copyWith(
    dualRuler: true,
    showRuSpan: true,
    lifecycleBorders: true,
    hatchPassive: true,
    loadGutter: true,
    units: units,
    typeScale: typeScale,
  );

  // Value equality exists for ONE reason: it is what makes [copyWith]'s
  // completeness checkable without reflection. See that method's doc.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RackSceneOptions &&
          other.dualRuler == dualRuler &&
          other.showRuSpan == showRuSpan &&
          other.lifecycleBorders == lifecycleBorders &&
          other.hatchPassive == hatchPassive &&
          other.loadGutter == loadGutter &&
          other.units == units &&
          other.typeScale == typeScale;

  @override
  int get hashCode => Object.hash(
    dualRuler,
    showRuSpan,
    lifecycleBorders,
    hatchPassive,
    loadGutter,
    units,
    typeScale,
  );

  @override
  String toString() =>
      'RackSceneOptions(dualRuler: $dualRuler, showRuSpan: $showRuSpan, '
      'lifecycleBorders: $lifecycleBorders, hatchPassive: $hatchPassive, '
      'loadGutter: $loadGutter, units: ${units.name}, '
      'typeScale: ${typeScale.factor})';
}

/// Builds the [RackScene] for [rack] + its [devices] on [face] at [lod].
///
/// [templates] resolves each device's `TemplateRef` to a body; [measurer]
/// is injected (CR-081) and threaded to the layers. A device is drawn only
/// when it is rail-mounted on [face] and occupies ≥ 1 U on that face —
/// anything else is simply skipped (docs/04 §2.2's face is a coordinate,
/// but this stage's face is a filter; dual-face occupancy is deferred, see
/// the file docs of rack_layer/device_layer).
///
/// ── REAR MIRRORING (docs/04 §2.2, CR-035, roadmap M1 item 3) ──────────
/// On `Face.rear` the lateral span of every device is reflected about the
/// opening's centre when `rack.mirrorRearElevation` is set — which it is
/// by default. It is read from the RACK rather than passed in, because it
/// is a per-rack property with a `SetEntityPropertyCommand` behind it and a
/// caller that could pass something else would be a second answer to a
/// question the model already answers.
///
/// The reflection lives in `RackGeometry.deviceRect`, so it moves the
/// LAYOUT and never the glyphs — see that method on why a canvas
/// `scale(-1, 1)` is the wrong shape. A rack with the flag OFF draws
/// unmirrored, and the sheet builder puts a `NOT MIRRORED` chip on it so
/// the reader knows which convention they are looking at.
RackScene buildRackScene({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Map<String, TemplateSnapshot> templates,
  required Face face,
  required LodLevel lod,
  required TextMeasurer measurer,
  RackPalette palette = const RackPalette(),
  RackSceneOptions options = RackSceneOptions.screen,
}) {
  final geo = RackGeometry(rack.heightU);
  final ops = <DiagramOp>[];
  final fragments = <String, IntRange>{};
  final hits = <HitRegion>[];
  final layouts = <DeviceLayout>[];
  final unlabelled = <Uuid>[];
  var minText = double.infinity;
  var bounds = DBox.fromLtwh(0, 0, geo.rackWidth, geo.rackHeight);
  final mirrored = face == Face.rear && rack.mirrorRearElevation;

  // ── chassis fragment (absolute, keyed by the rack id) ────────────────
  final chassis = buildRackLayer(
    rack,
    geo,
    measurer,
    lod,
    palette,
    dualRuler: options.dualRuler,
    typeScale: options.typeScale,
  );
  ops.addAll(chassis.ops);
  fragments[rack.id.v] = IntRange(0, ops.length);
  minText = _min(minText, chassis.minTextPt);
  // `bounds` is the scene's INK extent, not the union of its layout rects:
  // it is what drives PDF scale-to-fit and the elevation tile count
  // (ops.dart), and a layer is free to draw outside the rect it was sized
  // to. The chassis frame's 1.2pt stroke straddles the rack box's edge and
  // the RU ruler sits left of the rails, so even here the two differ.
  bounds = _grow(bounds, chassis.inkBounds);

  // ── device fragments (local, wrapped in an absolute translate) ───────
  final visible = _visibleDevices(rack, devices, templates, face);
  // What was drawn and where, for the shelf pass below: a host is laid on
  // the rect its shelf was actually drawn at, on this face, or not at all.
  final drawnRail = <({DeviceInstance device, DBox rect})>[];
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
      mirrored: mirrored,
    );

    // A shelf with something on it (DR-204 §11.203.10).
    final hosting =
        body.isContainer && devicesOnShelfIn(devices, device.id).isNotEmpty;
    final built = buildDeviceLayer(
      device,
      body,
      deviceH: deviceH,
      width: rect.width,
      height: rect.height,
      lod: lod,
      palette: palette,
      measurer: measurer,
      // The span label needs `ruIndex`, which the device fragment's LOCAL
      // coordinates deliberately do not carry — so it is resolved here,
      // where the placement is in hand.
      ruSpanLabel: options.showRuSpan
          ? ruSpanLabel(placement.ruIndex, deviceH)
          : null,
      lifecycleBorder: options.lifecycleBorders,
      // `TemplateBody.category` is the only AUTHORED signal that says
      // "this is a blank, a vent or a shelf" — the seeded catalog puts
      // exactly those three under `kCatPassive`. A user-authored blank
      // panel filed under some other category simply does not hatch,
      // which is graceful degradation rather than a guess about what the
      // author meant. Recorded in the M1 log as a known partial.
      // NOT ON A LOADED SHELF (§11.203.10): its hosts sit over the band,
      // and one drawn hollow (width unknown) had the 45° lines running
      // through its label. The header's designator and mark already say
      // what it is; an empty shelf keeps its hatch.
      hatched: options.hatchPassive && body.category == kCatPassive && !hosting,
      typeScale: options.typeScale,
      // A SHELF CARRYING DEVICES keeps its top line only, with its load
      // on it (DR-204 §11.203.7, §11.203.10): its hosts cover the rest.
      // A shelf carrying nothing draws as any device does.
      hostingNote: hosting
          ? formatShelfLoad(
              shelfLoad(
                devices: devices,
                templates: templates,
                shelfId: device.id,
              ),
              body.containerWeightCapacity,
              options.units,
            )
          : null,
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
    if (built.labelDropped) unlabelled.add(device.id);
    hits.add(HitRegion(device.id.v, rect));
    drawnRail.add((device: device, rect: rect));
    layouts.add(
      DeviceLayout(
        deviceId: device.id,
        rect: rect,
        semanticLabel: _semanticLabel(device, body),
      ),
    );
    minText = _min(minText, built.minTextPt);
    // The fragment's ink bounds are LOCAL, like its ops — shifted by the
    // same translate the composed scene brackets them with.
    bounds = _grow(
      bounds.union(rect),
      built.inkBounds?.shift(rect.left, rect.top),
    );
  }

  // ── shelf hosts (DR-204 §11.203.4, `#953`) ────────────────────────────
  //
  // In the same three lists a rail device and a 0U bar use, because being
  // in `hits` and `layouts` is what "selectable" MEANS on this canvas.
  // Drawn after every rail device, so a host paints over its shelf.
  final shelves = layoutAllShelves(
    devices: devices,
    templates: templates,
    placed: drawnRail,
    mirrored: mirrored,
    headerUnits: shelfHeaderUnitsFor(options.typeScale),
  );
  for (final layout in shelves.values) {
    for (final host in layout.hosts) {
      final body = host.body;
      // An unresolved template draws nothing, as it does on the rails.
      if (body == null) continue;
      final rect = host.rect;
      final built = buildDeviceLayer(
        host.device,
        body,
        deviceH: 1,
        width: rect.width,
        height: rect.height,
        lod: lod,
        palette: palette,
        measurer: measurer,
        lifecycleBorder: options.lifecycleBorders,
        typeScale: options.typeScale,
        showBadge: false,
        widthUnknown: !host.widthKnown,
      );
      ops
        ..add(const OpSave())
        ..add(OpTransform(Matrix4.translationValues(rect.left, rect.top, 0)));
      final localStart = ops.length;
      ops.addAll(built.ops);
      final localEnd = ops.length;
      ops.add(const OpRestore());
      fragments[host.device.id.v] = IntRange(localStart, localEnd);
      if (built.labelDropped) unlabelled.add(host.device.id);
      hits.add(HitRegion(host.device.id.v, rect));
      layouts.add(
        DeviceLayout(
          deviceId: host.device.id,
          rect: rect,
          semanticLabel: host.widthKnown
              ? _semanticLabel(host.device, body)
              : '${_semanticLabel(host.device, body)}, width unknown',
        ),
      );
      minText = _min(minText, built.minTextPt);
      bounds = _grow(
        bounds.union(rect),
        built.inkBounds?.shift(rect.left, rect.top),
      );
    }
  }
  // THE SHELF KEEPS ONLY WHAT NO HOST COVERS. Nearest-hit breaks a tie
  // between two containing regions on distance to centre, so a click on a
  // wide host near its edge could pick the shelf under it. Cutting each
  // shelf's region to its header, its tray and its free width makes the
  // host the ONLY region there: the answer by construction rather than by
  // geometry. One pass, so no index is carried across an edit of the list.
  if (shelves.isNotEmpty) {
    final rebuilt = <HitRegion>[
      for (final hit in hits)
        if (shelves[Uuid(hit.entityId)] case final layout?)
          for (final part in shelfFreeRegions(hit.bounds, layout))
            HitRegion(hit.entityId, part)
        else
          hit,
    ];
    hits
      ..clear()
      ..addAll(rebuilt);
  }

  // ── 0U bars (absolute, on the rails) ─────────────────────────────────
  //
  // AC-044's plain bar (`#883`, DR-166 §11.165). These go in the same
  // three lists a rail device does, because "selectable" is exactly what
  // being in `hits` and `layouts` MEANS on this canvas: `#876` had to put
  // its inspector fields on the rack panel rather than the device panel
  // because a 0U device could not be selected, and this is the line that
  // was missing.
  //
  // A FRAGMENT IS RECORDED, AND THE FIRST VERSION SAID IT DID NOT NEED
  // ONE. That comment reasoned that a bar is one absolute rect with no
  // local origin worth having. It is not optional: the canvas builds a
  // `_DeviceBoxLeaf` for every entry in `devices` and calls
  // `fragmentFor(id)`, which THROWS on an id it has no range for, so the
  // first run painted an `ArgumentError` instead of an elevation. The
  // bar's ops are local and bracketed like any device's.
  for (final bar in zeroUBars(
    rack: rack,
    devices: devices,
    face: face,
    geo: geo,
    mirrored: mirrored,
  )) {
    final built = buildZeroUBarLayer(bar: bar, palette: palette);
    ops
      ..add(const OpSave())
      ..add(
        OpTransform(
          Matrix4.translationValues(bar.rect.left, bar.rect.top, 0),
        ),
      );
    final localStart = ops.length;
    ops.addAll(built.ops);
    final localEnd = ops.length;
    ops.add(const OpRestore());
    fragments[bar.device.id.v] = IntRange(localStart, localEnd);
    hits.add(HitRegion(bar.device.id.v, bar.rect));
    layouts.add(
      DeviceLayout(
        deviceId: bar.device.id,
        rect: bar.rect,
        semanticLabel: _zeroUSemanticLabel(bar),
      ),
    );
    bounds = _grow(
      bounds.union(bar.rect),
      built.inkBounds?.shift(bar.rect.left, bar.rect.top),
    );
  }

  // ── load gutter (absolute, outside the chassis box) ──────────────────
  //
  // Composed here rather than being a second scene the sheet concatenates,
  // so its Y positions come from the same `RackGeometry` the ruler does
  // and one `OpTransform` scales the elevation and its readings together.
  if (options.loadGutter) {
    final gutter = buildRackLoadGutterLayer(
      geo: geo,
      profile: computeRackLoadProfile(
        rack: rack,
        devices: devices,
        templates: templates,
      ),
      measurer: measurer,
      units: options.units,
      palette: palette,
      typeScale: options.typeScale,
    );
    ops.addAll(gutter.ops);
    minText = _min(minText, gutter.minTextPt);
    bounds = _grow(bounds, gutter.inkBounds);
  }

  final scene = DiagramScene(
    ops: ops,
    bounds: bounds,
    hits: hits,
    minTextSizePt: minText.isFinite
        ? minText
        : options.typeScale.size(RackTextSizes.ruler),
    fragments: fragments,
  );

  return RackScene(
    scene: scene,
    rackId: rack.id,
    devices: layouts,
    chassisBounds: DBox.fromLtwh(0, 0, geo.rackWidth, geo.rackHeight),
    unlabelledDeviceIds: List.unmodifiable(unlabelled),
    shelfOverflow: Map.unmodifiable({
      for (final MapEntry(key: id, value: layout) in shelves.entries)
        if (layout.overflow case final over?) id: over,
    }),
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

/// Filters [devices] to those rail-mounted in [rack] whose template gives
/// them ≥ 1 U of occupancy ON [face], sorted bottom-to-top by `ruIndex`
/// (ties broken by id) for a deterministic op order.
///
/// WHAT IS DRAWN IS DECIDED BY [elevationOccupancyU], not by a copy of it.
/// The three lines it replaces existed here and, restated, in
/// `rack_load_gutter.dart` — which counts what this skips so the sheet can
/// SAY how many devices T6.30 lists in this rack and no elevation shows.
/// Two spellings of one predicate would make that count describe a
/// different set from the one actually left out.
///
/// ── OCCUPANCY DECIDES THE FACE, NOT THE MOUNT (docs/04 §2.2, CR-036) ──
/// There used to be a `placement.face != face` line here as well, and it
/// is why every shipped starter's T2.02 was an empty 42U frame: a device
/// bolted to the FRONT rails with `{frontU: 3, rearU: 3, side: both}` — a
/// UPS, a matrix, an amplifier — occupies rear U that a technician
/// standing behind the rack can see and reach, and this dropped all of
/// them. docs/04 §2.2: the face "selects a coordinate, not a filter".
///
/// A device's REAR block is bottom-anchored at the same `ruIndex` its
/// front block is, and spans `rearU`. That is a derivation, not a stored
/// fact (CR-006): the model carries one `ruIndex` per rail placement, and
/// a chassis rests on the U it is screwed into whichever side you read it
/// from. `frontU != rearU` (a deep chassis with a shallow front panel)
/// therefore draws two different heights off one index, which is what the
/// occupancy struct is for.
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

    final body = templates[templateKeyFor(device.templateRef)]?.body;
    final deviceH = elevationOccupancyU(device, body, face);
    // Non-null only when the body resolved and gave ≥ 1 U on this face,
    // which is exactly what makes the `body!` below safe.
    if (deviceH == null) continue;

    out.add(_VisibleDevice(device, body!, placement, deviceH));
  }
  out.sort((a, b) {
    final byRu = a.placement.ruIndex.compareTo(b.placement.ruIndex);
    return byRu != 0 ? byRu : a.device.id.v.compareTo(b.device.id.v);
  });
  return out;
}

/// What a screen reader hears for a 0U bar (`#883`).
///
/// **IT SAYS WHEN THE LENGTH IS NOT RECORDED**, because the drawing says
/// it with a hollow outline and an outline is not available to somebody
/// who is not looking at it. G4's rule is that an unknown is reported
/// rather than filled in, and a semantic label is a report.
String _zeroUSemanticLabel(ZeroUBar bar) {
  final d = bar.device;
  final who = d.name.isEmpty ? d.designator : '${d.designator} ${d.name}';
  return bar.lengthKnown ? '$who, 0U' : '$who, 0U, length not recorded';
}

String _semanticLabel(DeviceInstance device, TemplateBody body) {
  final type = body.displayName;
  final name = device.name;
  final buffer = StringBuffer(device.designator);
  if (name.isNotEmpty) buffer.write(' — $name');
  if (type.isNotEmpty) buffer.write(', $type');
  return buffer.toString();
}

/// docs/08 §2.2's RU span label — `4U · 12–15` for a 4 U device at U12,
/// `1U · 7` for a single-U one.
///
/// EN DASH for the range, matching §2.2's own spelling, and never a hyphen
/// — `12-15` reads as an identifier.
String ruSpanLabel(int ruIndex, int deviceH) => deviceH == 1
    ? '1U · $ruIndex'
    : '${deviceH}U · $ruIndex–${ruIndex + deviceH - 1}';

double _min(double a, double b) => a < b ? a : b;

/// [box] widened to include [ink], if the layer drew anything at all.
DBox _grow(DBox box, DBox? ink) => ink == null ? box : box.union(ink);
