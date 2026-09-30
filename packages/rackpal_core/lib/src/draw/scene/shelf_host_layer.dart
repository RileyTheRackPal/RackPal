// Devices sitting on a shelf, drawn on the shelf they sit on (DR-204
// §11.203.4, `#953`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE SAME HOLE THE 0U BAR FILLED, ONE PLACEMENT OVER
// ═══════════════════════════════════════════════════════════════════════
// `scene_builder.dart` reads `if (placement is! RailPlacement) continue;`,
// which is what kept a 0U occupant off every elevation until `#883`
// (`zero_u_layer.dart`). A `ShelfPlacement` fell through the same line, so
// the Home Theatre starter's two shelf components were never drawn, never
// hit-tested and never selectable, and the load gutter's `undrawnCount`
// was the only thing that admitted they were in the rack at all.
//
// ═══════════════════════════════════════════════════════════════════════
// AUTO-PACK, LEFT TO RIGHT, AND NOTHING ELSE (AC-043)
// ═══════════════════════════════════════════════════════════════════════
// Hosts are laid in `ShelfPlacement.order` from the shelf's left edge.
// `lateralOffset` is not read: free positioning is one of AC-043's cuts,
// and the field stays in the format only so the free case can arrive
// later. A mirrored rear elevation packs from the right, for the reason
// `RackGeometry.deviceRect` mirrors: it is the same shelf read from
// behind.
//
// **A WIDTH IS DRAWN ONLY WHEN IT IS KNOWN, AND THEN AT TRUE SCALE**
// (§11.203.3). `shelfWidth` is optional; an unknown one is a quarter of
// the shelf, drawn hollow and reading `width unknown`. It is NOT
// `chassisWidth`: that is a 432 mm default on every template, and read
// here it would put every unmeasured cable box across a whole shelf as
// though somebody had measured it.
//
// If the packed widths come to more than the shelf, every host is scaled
// down together to fit, and [ShelfLayout.overflow] says by how much. A
// drop that would cause it is refused where the widths are known
// (§11.203.8); a hand-edited file can still arrive in that state, and an
// elevation that threw on it would take a rack down over one shelf.
import 'package:rackpal_core/src/commands/shelf_placement.dart'
    show devicesOnShelfIn;
import 'package:rackpal_core/src/derived/device_loads.dart' show templateKeyFor;
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/scene/rack_geometry.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/constants.dart' show kRackUnit;
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// One device on a shelf, with the rect it is drawn in.
typedef ShelfHostBox = ({
  DeviceInstance device,
  TemplateBody? body,
  DBox rect,
  bool widthKnown,
});

/// What one shelf's hosts came to.
typedef ShelfLayout = ({
  List<ShelfHostBox> hosts,

  /// How far the packed widths overran the shelf, or null when they fit.
  /// Measured before the scale-to-fit, so it is the real overrun.
  Len? overflow,
});

/// The band at the top of a shelf's block kept clear for the shelf's own
/// designator line: `RackTextSizes.designator` plus its pads.
const double kShelfHeaderUnits = 15;

/// The shelf's tray lip, under the hosts.
const double kShelfTrayUnits = 3;

/// The shortest a host may be drawn and still read as a labelled box.
/// Below it the header is given up and the hosts take the block.
const double _minHostUnits = RackGeometry.unitsPerRu * 0.6;

/// Nanometres per diagram unit: the inverse of `RackGeometry.unitsForLen`.
final double _nmPerUnit = kRackUnit.nm / RackGeometry.unitsPerRu;

/// The rect inside [shelfRect] that hosts are packed into: below the
/// header when there is room for one, above the tray always.
DBox shelfHostArea(DBox shelfRect) {
  final withHeader =
      shelfRect.height - kShelfHeaderUnits - kShelfTrayUnits >= _minHostUnits;
  final top = shelfRect.top + (withHeader ? kShelfHeaderUnits : 0);
  return DBox.fromLtwh(
    shelfRect.left + 2,
    top,
    shelfRect.width - 4,
    shelfRect.bottom - kShelfTrayUnits - top,
  );
}

/// The width a shelf offers its hosts: what its template states, capped
/// at the room it is drawn with, else the room it is drawn with.
Len shelfUsableWidth(TemplateBody? shelfBody, DBox shelfRect) {
  final drawn = Len((shelfHostArea(shelfRect).width * _nmPerUnit).round());
  final stated = shelfBody?.containerUsableWidth;
  return stated == null || stated.nm > drawn.nm ? drawn : stated;
}

/// Lays out every device on [shelf], whose block is drawn at [shelfRect].
ShelfLayout layoutShelfHosts({
  required Iterable<DeviceInstance> devices,
  required Map<String, TemplateSnapshot> templates,
  required DeviceInstance shelf,
  required DBox shelfRect,
  required bool mirrored,
}) {
  final area = shelfHostArea(shelfRect);
  final shelfBody = templates[templateKeyFor(shelf.templateRef)]?.body;
  final usable = shelfUsableWidth(shelfBody, shelfRect);
  final unknownSlot = Len(usable.nm ~/ 4);

  final hosts = devicesOnShelfIn(devices, shelf.id);
  final widths = <Len>[];
  final known = <bool>[];
  final bodies = <TemplateBody?>[];
  for (final host in hosts) {
    final body = templates[templateKeyFor(host.templateRef)]?.body;
    bodies.add(body);
    final w = body?.shelfWidth;
    known.add(w != null);
    widths.add(w ?? unknownSlot);
  }
  final total = widths.fold<int>(0, (sum, w) => sum + w.nm);
  final overflow = total > usable.nm ? Len(total - usable.nm) : null;
  // Scaled together when they do not fit, and at true scale when they do.
  final fit = overflow == null ? 1.0 : usable.nm / total;

  final out = <ShelfHostBox>[];
  var cursor = 0.0;
  for (var i = 0; i < hosts.length; i++) {
    final w = RackGeometry.unitsForLen(widths[i]) * fit;
    final left = mirrored ? area.right - cursor - w : area.left + cursor;
    out.add((
      device: hosts[i],
      body: bodies[i],
      rect: DBox.fromLtwh(left, area.top, w, area.height),
      widthKnown: known[i],
    ));
    cursor += w;
  }
  return (hosts: out, overflow: overflow);
}

/// Every drawn shelf that has at least one host, keyed by shelf id.
///
/// [placed] is the scene's own list of drawn rail devices and their rects,
/// so a shelf that is not drawn on this face draws no hosts, and a host is
/// never drawn somewhere its shelf is not.
Map<Uuid, ShelfLayout> layoutAllShelves({
  required Iterable<DeviceInstance> devices,
  required Map<String, TemplateSnapshot> templates,
  required Iterable<({DeviceInstance device, DBox rect})> placed,
  required bool mirrored,
}) {
  final out = <Uuid, ShelfLayout>{};
  for (final p in placed) {
    final layout = layoutShelfHosts(
      devices: devices,
      templates: templates,
      shelf: p.device,
      shelfRect: p.rect,
      mirrored: mirrored,
    );
    if (layout.hosts.isNotEmpty) out[p.device.id] = layout;
  }
  return out;
}

/// The parts of [shelfRect] no host of [layout] covers: its header band,
/// its tray, and the strip either side of the packed hosts.
///
/// These become the shelf's hit regions in place of its whole rect, so a
/// click on a host can only ever find the host (see `scene_builder.dart`).
/// Rectangles, not a polygon, because a `HitRegion` is one box and the
/// hosts are packed edge to edge in one band, so four boxes are exact.
List<DBox> shelfFreeRegions(DBox shelfRect, ShelfLayout layout) {
  if (layout.hosts.isEmpty) return [shelfRect];
  var hostsLeft = double.infinity;
  var hostsRight = double.negativeInfinity;
  var bandTop = double.infinity;
  var bandBottom = double.negativeInfinity;
  for (final h in layout.hosts) {
    if (h.rect.left < hostsLeft) hostsLeft = h.rect.left;
    if (h.rect.right > hostsRight) hostsRight = h.rect.right;
    if (h.rect.top < bandTop) bandTop = h.rect.top;
    if (h.rect.bottom > bandBottom) bandBottom = h.rect.bottom;
  }
  final parts = <DBox>[
    DBox.fromLtwh(
      shelfRect.left,
      shelfRect.top,
      shelfRect.width,
      bandTop - shelfRect.top,
    ),
    DBox.fromLtwh(
      shelfRect.left,
      bandBottom,
      shelfRect.width,
      shelfRect.bottom - bandBottom,
    ),
    DBox.fromLtwh(
      shelfRect.left,
      bandTop,
      hostsLeft - shelfRect.left,
      bandBottom - bandTop,
    ),
    DBox.fromLtwh(
      hostsRight,
      bandTop,
      shelfRect.right - hostsRight,
      bandBottom - bandTop,
    ),
  ];
  return [
    for (final p in parts)
      if (p.width > 0 && p.height > 0) p,
  ];
}
