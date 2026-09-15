// rackpal_core/src/derived/device_outlets.dart, pure Dart.
//
// How many outlets a device PROVIDES and CONSUMES (DR-171, canon §11.170,
// board `#558`). The one resolution the chip strip, `PWR-003` and that
// rule's remedy share, so the button can never answer a different question
// from the finding it sits on.
//
// ─────────────────────────────────────────────────────────────────────────
// NOTHING HERE IS AUTHORED. BOTH COUNTS ARE READ OFF THE DOCUMENT.
// ─────────────────────────────────────────────────────────────────────────
// They used to be two `PowerProfile` integers typed by whoever wrote the
// template, and six of the 51 seed templates stated them against their own
// ports. DR-171 deleted them. The two halves are deliberately asymmetric
// (§11.170.2):
//
//  * PROVIDED is CAPACITY, a hardware fact: the template's `power.*` ports
//    whose role is `outlet`. A 24-outlet PDU provides 24 whether or not
//    anything is plugged into it.
//  * CONSUMED is USAGE, read per device in this order (§11.170.4):
//      1. conductors landing on its inlet-role power ports: that many;
//      2. otherwise a conductor landing on a PoE powered-device port:
//         none, because its power arrives over the data run;
//      3. otherwise one per inlet-role power port, COUNTED FROM PORTS,
//         and every surface that shows the total says how many were.
//
// ─────────────────────────────────────────────────────────────────────────
// A POWER CONNECTION IS A CONDUCTOR ON AN INLET, NOT A LINK OF A CLASS
// ─────────────────────────────────────────────────────────────────────────
// `LinkClass.powerCord` reads like the test and is not one: the classifier
// never returns it (`#908`), so a cord from an amplifier to a PDU in the
// same rack is a `jumper`. The port says what the connection is by being
// an inlet, whatever the link around it is called.
//
// ─────────────────────────────────────────────────────────────────────────
// PER DEVICE, NEVER PER RACK
// ─────────────────────────────────────────────────────────────────────────
// The user's company draws cords for PDU-fed gear, where sequencing or a
// remote reboot matters, and not for everything else. A rack mixes drawn
// and undrawn cords as a matter of course, so a rule that switched a whole
// rack to counting cords once one was drawn would charge every undrawn
// device nothing. Each device answers from its own evidence.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Whether [port] is a `power.*` port playing [role].
///
/// BOTH HALVES ARE NEEDED, because shipped data has each without the
/// other: `P01`'s ground and `F18`'s bonding lug are `power.bonding` ports
/// with no role, and `P03`'s battery expansion is `power.dc_low` with no
/// power spec at all. None of them is an outlet or an inlet.
bool isPowerPortWithRole(PortDef port, PortPowerRole role) =>
    port.signalFamily.v.startsWith('power.') && port.power?.role == role;

/// What [body] PROVIDES: its outlet-role power ports (§11.170.2).
int outletPortCount(TemplateBody body) => body.ports
    .where((p) => isPowerPortWithRole(p, PortPowerRole.outlet))
    .length;

/// [body]'s inlet-role power ports, which is what it consumes when no cord
/// is drawn to it (§11.170.4, clause 3).
int inletPortCount(TemplateBody body) =>
    body.ports.where((p) => isPowerPortWithRole(p, PortPowerRole.inlet)).length;

/// Which template ports, on which devices, have a conductor landing on
/// them.
///
/// Built once per document and read per device, so a rack of forty
/// devices walks the links once rather than forty times.
@immutable
final class PortLandings {
  const PortLandings._(this._byDevice);

  /// Every `PortEndpoint` in [doc]'s links, resolved to its device and its
  /// template port key.
  ///
  /// AN END THAT DOES NOT RESOLVE LANDS NOWHERE. A port missing from
  /// `doc.ports`, or one with no template key, cannot say which inlet it
  /// is, and an unresolvable end is not evidence that a cord was drawn.
  factory PortLandings.of(RackDocument doc) {
    final byDevice = <Uuid, Set<PortKey>>{};
    void land(Endpoint end) {
      if (end is! PortEndpoint) return;
      final port = doc.ports[end.portId];
      final key = port?.templatePortKey;
      if (port == null || key == null) return;
      (byDevice[port.deviceId] ??= <PortKey>{}).add(key);
    }

    for (final link in doc.links.values) {
      for (final conductor in link.conductors) {
        land(conductor.from);
        land(conductor.to);
      }
    }
    return PortLandings._(byDevice);
  }

  /// Nothing lands anywhere.
  ///
  /// FOR A CALLER WITH NO GRAPH, and only that: a test stating a rack in
  /// four lines. A caller holding a document passes [PortLandings.of], or
  /// every cord drawn in it is silently ignored.
  static const PortLandings none = PortLandings._(<Uuid, Set<PortKey>>{});

  final Map<Uuid, Set<PortKey>> _byDevice;

  /// The template port keys on [deviceId] that a conductor end lands on.
  Set<PortKey> on(Uuid deviceId) => _byDevice[deviceId] ?? const <PortKey>{};
}

/// One device's outlet counts, by §11.170.4.
@immutable
final class DeviceOutlets {
  const DeviceOutlets({
    required this.provided,
    required this.consumed,
    required this.consumedFromPorts,
  });

  /// The template did not resolve, so nothing about its ports is known.
  /// The only unknown this resolution has left (G4).
  static const DeviceOutlets unknown = DeviceOutlets(
    provided: null,
    consumed: null,
    consumedFromPorts: false,
  );

  /// [outletPortCount] of the template, or null when it did not resolve.
  final int? provided;

  /// The outlets this device draws from, or null when it did not resolve.
  final int? consumed;

  /// Whether [consumed] came from clause 3: nothing is wired to this
  /// device's power, so it is charged one outlet per inlet port.
  ///
  /// FALSE WHEN THERE IS NO INLET TO COUNT. A bus-powered keypad consumes
  /// zero with no assumption behind it, and flagging it would put every
  /// passive panel into the "counted from ports" sentence.
  final bool consumedFromPorts;

  @override
  String toString() =>
      'DeviceOutlets(provided: $provided, consumed: $consumed'
      '${consumedFromPorts ? ', from ports' : ''})';
}

/// [device]'s outlet counts against its [body], reading [landings] for the
/// cords and PoE runs that land on it.
///
/// [body] is null for a snapshot that did not resolve, which is
/// [DeviceOutlets.unknown]: no `DeviceOverrides` field can stand in for a
/// port list, so nothing here survives a missing template.
///
/// A TEMPLATE WITH NO PORTS AT ALL IS UNKNOWN TOO, and not a measured
/// zero (G4). §11.170.2 reads the port list as a complete description of
/// the hardware, which presupposes that somebody described it: AC-049 lets
/// a template be saved with three fields and no ports, and an empty list
/// cannot tell a blank panel from an amplifier nobody has entered yet.
/// Reading it as `0/0` is the confident chip `totals.dart` was rewritten to
/// stop. A template with ports and no power port is different, and is a
/// real zero: its ports were described, and none of them take power.
DeviceOutlets resolveDeviceOutlets(
  DeviceInstance device,
  TemplateBody? body,
  PortLandings landings,
) {
  if (body == null || body.ports.isEmpty) return DeviceOutlets.unknown;
  final landed = landings.on(device.id);
  var provided = 0;
  var inlets = 0;
  var cords = 0;
  var poeFed = false;
  for (final port in body.ports) {
    final isLanded = landed.contains(port.key);
    if (isPowerPortWithRole(port, PortPowerRole.outlet)) provided++;
    if (isPowerPortWithRole(port, PortPowerRole.inlet)) {
      inlets++;
      if (isLanded) cords++;
    }
    if (isLanded && port.poe?.role == PoeRole.pd) poeFed = true;
  }
  // Clause 1. The drawing says how many cords, so that is the answer, even
  // for a redundant-supply switch with only one of its two cords drawn.
  if (cords > 0) {
    return DeviceOutlets(
      provided: provided,
      consumed: cords,
      consumedFromPorts: false,
    );
  }
  // Clause 2. Powered over its data run, so no outlet at all.
  if (poeFed) {
    return DeviceOutlets(
      provided: provided,
      consumed: 0,
      consumedFromPorts: false,
    );
  }
  // Clause 3. Nothing says otherwise, so every inlet will want an outlet,
  // and the result says that is where the number came from.
  return DeviceOutlets(
    provided: provided,
    consumed: inlets,
    consumedFromPorts: inlets > 0,
  );
}
