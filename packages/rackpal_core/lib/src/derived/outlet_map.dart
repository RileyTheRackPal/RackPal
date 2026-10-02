// rackpal_core/src/derived/outlet_map.dart, pure Dart.
//
// AC-026: "PDU outlet assignments appear ... as an outlet map, not as
// twenty cable rows." docs/08 §2.2 puts the map on `T6.30` (M6-F5,
// `#340`), and DR-219 §11.218.2 rules its shape: one row per outlet with a
// cord drawn to it, then each provider's free count. This computes and
// never draws.
//
// ═══════════════════════════════════════════════════════════════════════
// THE SAME FACTS `PWR-003` READS, SO THE MAP AND THE RULE AGREE
// ═══════════════════════════════════════════════════════════════════════
// A provider is a device whose template has outlet-role power ports
// (`outletPortCount`, DR-171 §11.170.2): a PDU, a UPS, a sequencer. A cord
// is a conductor with one end on such a port. And the devices the map
// cannot place, because nothing is drawn to them, are exactly the ones
// `resolveDeviceOutlets` charges by clause 3 (`consumedFromPorts`); the
// map counts them in one line rather than guessing an outlet.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackpal_core/src/derived/device_outlets.dart';
import 'package:rackpal_core/src/model/conductor.dart' show PortEndpoint;
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// One outlet with a cord drawn to it.
@immutable
final class OutletAssignment {
  const OutletAssignment({
    required this.outletLabel,
    required this.device,
    required this.inletLabel,
    required this.cord,
  });

  final String outletLabel;

  /// What the cord's other end lands on, or null when it lands on no
  /// device port (an open end, a place).
  final DeviceInstance? device;

  /// That port's label, or null with [device].
  final String? inletLabel;

  /// The link's designator.
  final String cord;
}

/// One device that provides outlets, and what is drawn to them.
@immutable
final class OutletProvider {
  const OutletProvider({
    required this.device,
    required this.outletCount,
    required this.assignments,
  });

  final DeviceInstance device;

  /// Its outlet-role power ports.
  final int outletCount;

  /// In the template's outlet order, then by cord designator.
  final List<OutletAssignment> assignments;

  /// Outlets with at least one cord drawn.
  int get assignedCount => assignments.map((a) => a.outletLabel).toSet().length;

  int get freeCount => outletCount - assignedCount;
}

/// AC-026's outlet map for a whole document.
@immutable
final class OutletMap {
  const OutletMap({required this.providers, required this.undrawnDevices});

  /// By designator, then id.
  final List<OutletProvider> providers;

  /// Devices charged an outlet per inlet because no cord is drawn to them
  /// (DR-171 §11.170.4, clause 3).
  final int undrawnDevices;
}

TemplateBody? _body(RackDocument doc, DeviceInstance device) =>
    bodyFor(device, doc.templates);

/// The outlet map of [doc] (DR-219 §11.218.2).
OutletMap buildOutletMap(RackDocument doc) {
  PortDef? defOf(Uuid portId) {
    final port = doc.ports[portId];
    final key = port?.templatePortKey;
    if (port == null || key == null) return null;
    final device = doc.devices[port.deviceId];
    if (device == null) return null;
    for (final def in _body(doc, device)?.ports ?? const <PortDef>[]) {
      if (def.key == key) return def;
    }
    return null;
  }

  final providers = <OutletProvider>[];
  final devices = doc.devices.values.toList()
    ..sort((a, b) {
      final byName = a.designator.compareTo(b.designator);
      return byName != 0 ? byName : a.id.v.compareTo(b.id.v);
    });
  for (final device in devices) {
    final body = _body(doc, device);
    if (body == null) continue;
    final outlets = [
      for (final p in body.ports)
        if (isPowerPortWithRole(p, PortPowerRole.outlet)) p,
    ];
    if (outlets.isEmpty) continue;
    final order = {for (final (i, p) in outlets.indexed) p.key: i};

    final found = <(int, OutletAssignment)>[];
    for (final link in doc.links.values) {
      for (final conductor in link.conductors) {
        for (final (here, there) in [
          (conductor.from, conductor.to),
          (conductor.to, conductor.from),
        ]) {
          if (here is! PortEndpoint) continue;
          final port = doc.ports[here.portId];
          if (port == null || port.deviceId != device.id) continue;
          final def = defOf(here.portId);
          final index = def == null ? null : order[def.key];
          if (def == null || index == null) continue;
          final other = there is PortEndpoint ? doc.ports[there.portId] : null;
          found.add((
            index,
            OutletAssignment(
              outletLabel: def.label,
              device: other == null ? null : doc.devices[other.deviceId],
              inletLabel: there is PortEndpoint
                  ? defOf(there.portId)?.label
                  : null,
              cord: link.designator,
            ),
          ));
        }
      }
    }
    // TOTAL ORDER: outlet position, then cord designator, then the far
    // device's id, so one link landing twice still sorts the same way.
    found.sort((a, b) {
      final byOutlet = a.$1.compareTo(b.$1);
      if (byOutlet != 0) return byOutlet;
      final byCord = a.$2.cord.compareTo(b.$2.cord);
      if (byCord != 0) return byCord;
      return (a.$2.device?.id.v ?? '').compareTo(b.$2.device?.id.v ?? '');
    });
    providers.add(
      OutletProvider(
        device: device,
        outletCount: outlets.length,
        assignments: List.unmodifiable([for (final f in found) f.$2]),
      ),
    );
  }

  final landings = PortLandings.of(doc);
  var undrawn = 0;
  for (final device in doc.devices.values) {
    final outlets = resolveDeviceOutlets(device, _body(doc, device), landings);
    if (outlets.consumedFromPorts) undrawn++;
  }

  return OutletMap(
    providers: List.unmodifiable(providers),
    undrawnDevices: undrawn,
  );
}
