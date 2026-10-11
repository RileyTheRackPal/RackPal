// DR-236 §11.235.2 (BRK-A/2, `#1005`): a set's conductors appended to an
// EXISTING cable, so one cable reaches another device.
//
// ═════════════════════════════════════════════════════════════════════
// DR-014's SPLIT, READ THE OTHER WAY
// ═════════════════════════════════════════════════════════════════════
// A 16/4 run to a room, tapped at the first speaker and continued to the
// second, is ONE cable, one pull and one row (RJ-016). CR-014 always let a
// Link reach N devices; what the product lacked was a way to say so. The set
// gesture connects one set to one set and mints a cable, so the nearest a
// person could get was a set connect and a DR-014 split: two cables where
// the crew pulls one. This plans exactly what the set gesture plans, with
// `planAtomicConnect`, and writes the conductors into the cable the person
// chose instead of a new one.
//
// THE SAME PLAN, so tier 1 refuses exactly as it does for any set, and the
// plan's `pairs` are what the surface asks tier 2 about (DR-234). Nothing
// here asks tier 2: core does not hesitate, the gesture does.
//
// ═════════════════════════════════════════════════════════════════════
// FOUR REFUSALS OF ITS OWN, BEFORE THE PLAN
// ═════════════════════════════════════════════════════════════════════
//  * the cable is gone;
//  * the cable is a HOME RUN, one conductor from a plate to a rack by
//    shape, which a second set would make something no home-run reader
//    understands;
//  * the source device is not one the cable already reaches: the ruling's
//    "a free set on a device the cable already reaches", because a cable
//    is continued from where it is, not started somewhere new;
//  * THE SET CARRIES ANOTHER FAMILY than the cable. An implementer's
//    default, stated to the user rather than ruled: both of DR-236's cases
//    (the 16/4, a dual-head IR emitter) are one family, and a cable with two
//    services is AC-021's machinery, not this.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/commands/atomic_connect.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/connect_commands.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/derived/connect_target.dart';
import 'package:rackpal_core/src/derived/port_set_resolution.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/port.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Appends [conductors] to the cable [linkId], creating the ports they land
/// on that the document does not hold, and takes back exactly that.
final class AppendSetToLinkCommand extends Command<RackDocument> {
  AppendSetToLinkCommand({
    required this.linkId,
    required this.conductors,
    required this.materialisations,
  });

  /// The cable being continued.
  final Uuid linkId;

  /// The planned conductors, in declared order.
  final List<Conductor> conductors;

  /// The ports to create first, designators already allocated.
  final List<PortMaterialisation> materialisations;

  /// HELD BY IDENTITY, NOT BY VALUE, on `DeclareInlineAdapterCommand`'s
  /// argument: two conductors can be field-for-field equal, and a revert by
  /// value could take somebody else's.
  final List<Conductor> _appended = [];
  final List<Uuid> _materialised = [];

  @override
  LabelKey get label => LabelKey.appendSetToLink;

  @override
  EpochMask get touches => EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [
    linkId,
    for (final spec in materialisations) spec.portId,
  ];

  @override
  bool apply(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null || conductors.isEmpty) return false;
    _materialised.clear();
    for (final spec in materialisations) {
      if (doc.ports.containsKey(spec.portId)) continue;
      doc.ports[spec.portId] = Port(
        id: spec.portId,
        deviceId: spec.deviceId,
        designator: spec.designator,
        templatePortKey: spec.portKey,
      );
      _materialised.add(spec.portId);
    }
    _appended
      ..clear()
      ..addAll(conductors.map(_copy));
    link.conductors.addAll(_appended);
    return true;
  }

  @override
  void revert(RackDocument doc) {
    final link = doc.links[linkId];
    if (link != null) {
      link.conductors.removeWhere(
        (c) => _appended.any((a) => identical(a, c)),
      );
    }
    for (final portId in _materialised) {
      doc.ports.remove(portId);
    }
    _appended.clear();
    _materialised.clear();
  }

  static Conductor _copy(Conductor c) => Conductor(
    from: c.from,
    to: c.to,
    role: c.role,
    pairNumber: c.pairNumber,
    colorCode: c.colorCode,
  );
}

/// What [planAppendSetToLink] decided.
@immutable
sealed class AppendSetResult {
  const AppendSetResult();
}

/// The append is legal. [plan] carries the pairs tier 2 is asked about.
@immutable
final class AppendSetReady extends AppendSetResult {
  const AppendSetReady({required this.plan, required this.command});

  final AtomicConnectPlan plan;
  final AppendSetToLinkCommand command;
}

/// Why nothing would be appended, in words for a person, and the tier-1
/// rule when one refused.
@immutable
final class AppendSetRefused extends AppendSetResult {
  const AppendSetRefused(this.message, {this.ruleId});

  final String message;
  final String? ruleId;
}

/// Plans appending [fromSetKey] on [fromDeviceId] to [toSetKey] on
/// [toDeviceId], into the cable [linkId] (DR-236 §11.235.2).
AppendSetResult planAppendSetToLink(
  RackDocument doc, {
  required Uuid linkId,
  required Uuid fromDeviceId,
  required String fromSetKey,
  required Uuid toDeviceId,
  required String toSetKey,
}) {
  final link = doc.links[linkId];
  if (link == null) {
    return const AppendSetRefused('That cable is no longer in this project.');
  }
  if (link.structureOrigin != null) {
    return AppendSetRefused(
      '${link.designator} is a home run, one conductor from a plate to a '
      'rack. Draw the next set as its own cable.',
    );
  }
  final reaches = <Uuid>{
    for (final c in link.conductors)
      for (final e in [c.from, c.to])
        if (e is PortEndpoint) ?doc.ports[e.portId]?.deviceId,
  };
  if (!reaches.contains(fromDeviceId)) {
    return AppendSetRefused(
      '${link.designator} does not reach '
      '${doc.devices[fromDeviceId]?.designator ?? 'that device'}, so a set '
      'there cannot continue it.',
    );
  }

  final from = resolvePortSet(doc, fromDeviceId, fromSetKey);
  if (from != null && from.members.isNotEmpty) {
    final pin = resolveConnectTarget(
      doc,
      deviceId: fromDeviceId,
      portKey: from.members.first.portKey.v,
    );
    final family = link.services.isEmpty
        ? null
        : link.services.first.signalFamily;
    if (pin != null && family != null && pin.signalFamily != family) {
      return AppendSetRefused(
        '${link.designator} carries ${family.v} and the ${from.def.label} '
        'carries ${pin.signalFamily.v}. Draw it as its own cable.',
      );
    }
  }

  final planned = planAtomicConnect(
    doc,
    fromDeviceId: fromDeviceId,
    fromSetKey: fromSetKey,
    toDeviceId: toDeviceId,
    toSetKey: toSetKey,
  );
  switch (planned) {
    case null:
      return const AppendSetRefused('That set is no longer in this document.');
    case AtomicConnectNotAtomic(:final setKey):
      return AppendSetRefused(
        'The "$setKey" group wires one pin at a time, so it cannot be added '
        'to a cable as a set.',
      );
    case AtomicConnectRefused(:final ruleId, :final message):
      return AppendSetRefused(message, ruleId: ruleId);
    case AtomicConnectReady(:final plan):
      if (plan.conductors.isEmpty) {
        return const AppendSetRefused('Neither set has a pin to land on.');
      }
      final reserved = <Uuid, Set<String>>{};
      final materialisations = <PortMaterialisation>[];
      for (final port in plan.neededPorts) {
        final target = resolveConnectTarget(
          doc,
          deviceId: port.deviceId,
          portKey: port.portKey.v,
        );
        if (target == null) continue;
        final used = reserved.putIfAbsent(port.deviceId, () => <String>{});
        final designator = allocatePortDesignatorFor(
          doc,
          target,
          alsoUsed: used,
        );
        used.add(designator);
        materialisations.add(
          PortMaterialisation(
            portId: port.portId,
            deviceId: port.deviceId,
            portKey: port.portKey,
            designator: designator,
          ),
        );
      }
      return AppendSetReady(
        plan: plan,
        command: AppendSetToLinkCommand(
          linkId: linkId,
          conductors: List<Conductor>.unmodifiable(plan.conductors),
          materialisations: List<PortMaterialisation>.unmodifiable(
            materialisations,
          ),
        ),
      );
  }
}
