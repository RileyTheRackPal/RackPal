// rackpal_core/src/derived/pinout_details.dart — pure Dart.
//
// What turns T5.01 on, and what it prints (docs/08 §2.2 row n+5, M6-E2b
// `#975`, DR-221).
//
// ═══════════════════════════════════════════════════════════════════════
// FOUR KINDS OF NON-STANDARD PINOUT, EACH AGAINST A STATED STANDARD
// ═══════════════════════════════════════════════════════════════════════
// docs/08 names four, and DR-221 gave each a standard to differ from:
//
//  1. AN IR PORT WITH A VARIANT OTHER THAN MONO TIP-SLEEVE (§11.220.2).
//     Mono TS is the standard; `xantech-stereo` is the powered receiver
//     jack, the one that kills an emitter plugged into it. IR families
//     only: no other variant has a declared standard.
//  2. A CABLE WHOSE WIRING STANDARD DIFFERS FROM THE PROJECT'S (DR-180
//     §11.179.4): `wiringStandardExceptions`, which was written for this.
//  3. A NULL-MODEM CABLE (§11.220.4). Nothing in the UI sets one yet
//     (`#973`); a file that carries one prints it.
//  4. A TERMINAL BLOCK WIRED IN AN ORDER OTHER THAN ITS FAMILY'S STANDARD
//     (§11.220.5). Two standards exist, Cresnet and RS-232; a family with
//     none never counts, and an order nobody recorded never counts (G4).
//
// "PLACED" MEANS IN THE DOCUMENT. A device on a shelf, in the field or in
// the staging bin is still hardware somebody will wire, so every device
// instance is read, not only the racked ones.
//
// THE PIN MAP IS THE USER'S RULING, NOT A COMMENT'S. Every copy of the
// receiver pinout the corpus held had ring and sleeve reversed until
// DR-221 §11.220.3; the map below is the one the user settled.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/builder/port_validation.dart' show kIrFamilies;
import 'package:rackpal_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackpal_core/src/derived/port_facts.dart';
import 'package:rackpal_core/src/derived/schedule.dart';
import 'package:rackpal_core/src/derived/wiring_standard.dart';
import 'package:rackpal_core/src/model/link.dart' show CrossoverKind;
import 'package:rackpal_core/src/model/port.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The IR standard (DR-221 §11.220.2). A port with any other variant is
/// listed.
const String kStandardIrVariant = 'mono-tip-sleeve';

/// What T5.01 prints for a known IR variant (DR-221 §11.220.3). A variant
/// not here prints that its map is not recorded, never a guess.
const Map<String, String> kIrPinMaps = <String, String>{
  'mono-tip-sleeve': 'TIP IR · SLEEVE GND',
  'xantech-stereo': 'TIP IR · RING +12 V · SLEEVE GND',
};

/// The declared terminal orders, pin 1 first (DR-221 §11.220.5). Only
/// these two families have one; the user judged audio too variable by
/// manufacturer to call a deviation non-standard.
final Map<SignalFamilyId, List<String>> kTerminalStandards =
    <SignalFamilyId, List<String>>{
      const SignalFamilyId('ctl.cresnet'): const ['24', 'Y', 'Z', 'G'],
      const SignalFamilyId('ctl.rs232'): const ['TX', 'RX', 'G'],
    };

/// One port on a placed device, as T5.01 names it.
@immutable
final class PinoutPort {
  const PinoutPort({
    required this.deviceId,
    required this.deviceDesignator,
    required this.portLabel,
    required this.family,
  });

  final Uuid deviceId;
  final String deviceDesignator;
  final String portLabel;
  final SignalFamilyId family;
}

/// An IR port whose variant is not the standard.
@immutable
final class IrVariantRow {
  const IrVariantRow({required this.port, required this.variant});

  final PinoutPort port;
  final String variant;

  /// [kIrPinMaps]' entry, or null when the variant's map is not recorded.
  String? get pinMap => kIrPinMaps[variant];
}

/// A terminal block wired in an order other than its family's standard.
@immutable
final class TerminalOrderRow {
  const TerminalOrderRow({
    required this.port,
    required this.roles,
    required this.standard,
  });

  final PinoutPort port;
  final List<String> roles;
  final List<String> standard;
}

/// Everything T5.01 lists, in the order it prints.
@immutable
final class PinoutDetails {
  const PinoutDetails({
    required this.irPorts,
    required this.wiringExceptions,
    required this.nullModems,
    required this.terminalOrders,
  });

  final List<IrVariantRow> irPorts;

  /// Schedule rows whose standard differs from the project's.
  final List<ScheduleEntry> wiringExceptions;
  final List<ScheduleEntry> nullModems;
  final List<TerminalOrderRow> terminalOrders;

  /// Whether nothing is non-standard, which is T5.01 absent.
  bool get isEmpty =>
      irPorts.isEmpty &&
      wiringExceptions.isEmpty &&
      nullModems.isEmpty &&
      terminalOrders.isEmpty;
}

/// Whether [roles] is a non-standard order for [family]: false when the
/// family has no declared standard or nobody recorded an order.
bool isNonStandardTerminalOrder(SignalFamilyId family, List<String>? roles) {
  final standard = kTerminalStandards[family];
  if (standard == null || roles == null) return false;
  if (roles.length != standard.length) return true;
  for (var i = 0; i < roles.length; i++) {
    if (roles[i] != standard[i]) return true;
  }
  return false;
}

/// T5.01's contents for [doc]. [schedule] is the export's one
/// `buildSchedule(doc)`, for CR-107's reason: two derivations of one row
/// can disagree.
///
/// ORDER. Devices by designator, natural, then id, so the sort is total;
/// within a device, the template's port order. Cables by designator,
/// natural, then link id.
PinoutDetails pinoutDetailsOf(RackDocument doc, Schedule schedule) {
  final materialised = <(Uuid, PortKey), Port>{
    for (final port in doc.ports.values)
      if (port.templatePortKey case final key?) (port.deviceId, key): port,
  };
  final devices = doc.devices.values.toList()
    ..sort((a, b) {
      final byName = compareDesignators(a.designator, b.designator);
      return byName != 0 ? byName : a.id.v.compareTo(b.id.v);
    });

  final ir = <IrVariantRow>[];
  final terminals = <TerminalOrderRow>[];
  for (final device in devices) {
    final body = bodyFor(device, doc.templates);
    if (body == null) continue;
    final defs = body.ports.toList()
      ..sort((a, b) {
        final byOrder = a.order.v.compareTo(b.order.v);
        return byOrder != 0 ? byOrder : a.key.v.compareTo(b.key.v);
      });
    for (final def in defs) {
      final port = materialised[(device.id, def.key)];
      final family = resolvePortSignalFamily(port, def);
      PinoutPort named() => PinoutPort(
        deviceId: device.id,
        deviceDesignator: device.designator,
        portLabel: resolvePortLabel(port, def),
        family: family,
      );
      final variant = def.pinoutVariant?.trim();
      if (kIrFamilies.contains(family) &&
          variant != null &&
          variant.isNotEmpty &&
          variant != kStandardIrVariant) {
        ir.add(IrVariantRow(port: named(), variant: variant));
      }
      if (isNonStandardTerminalOrder(family, def.terminalRoles)) {
        terminals.add(
          TerminalOrderRow(
            port: named(),
            roles: List.unmodifiable(def.terminalRoles!),
            standard: kTerminalStandards[family]!,
          ),
        );
      }
    }
  }

  int byCable(ScheduleEntry a, ScheduleEntry b) {
    final byId = compareDesignators(a.designator, b.designator);
    return byId != 0 ? byId : a.linkId.v.compareTo(b.linkId.v);
  }

  final exceptionIds = {
    for (final link in wiringStandardExceptions(doc)) link.id,
  };
  return PinoutDetails(
    irPorts: List.unmodifiable(ir),
    wiringExceptions: List.unmodifiable(
      schedule.rows.where((r) => exceptionIds.contains(r.linkId)).toList()
        ..sort(byCable),
    ),
    nullModems: List.unmodifiable(
      schedule.rows
          .where((r) => r.crossover == CrossoverKind.nullModem)
          .toList()
        ..sort(byCable),
    ),
    terminalOrders: List.unmodifiable(terminals),
  );
}
