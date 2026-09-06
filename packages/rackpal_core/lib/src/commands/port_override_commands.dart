// rackpal_core/src/commands/port_override_commands.dart — pure Dart.
//
// Door 1, one level down: correcting a fact about ONE jack on ONE device.
// `#233` (M4-L4), CR-053, DR-098 §11.97.6.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY THIS IS NOT A `SetEntityPropertyCommand`
// ─────────────────────────────────────────────────────────────────────────
// Every other property edit in the product is one, and door 1's four
// device fields are too. A port cannot be, and the reason is that MOST
// PORTS DO NOT EXIST.
//
// `Port` is lazily materialised: it is written to `doc.ports` only when it
// carries project state, so on a document built by dropping devices out of
// the palette every pin is a `PortDef` on a template and nothing else.
// `EntityField` resolves an entity out of a map and writes to it; there is
// nothing in the map to write to, and a field table cannot create one.
//
// So this command MATERIALISES, and it does it on DR-011.1's precedent,
// which `connect_commands.dart` established for exactly this situation and
// documented at length. The same three properties hold here:
//
//   * IT ALLOCATES NOTHING. The port id is `derivePortId(deviceId, key)`,
//     a pure UUIDv5 (CR-116, AC-006) giving the same answer on every peer
//     and every replay. The DESIGNATOR is allocated caller-side and
//     carried on the command, as `AddLinkCommand.netName` is.
//   * MATERIALISATION IS IDEMPOTENT. An existing port keeps everything it
//     carries; only the one overridden field moves.
//   * `revert` REMOVES EXACTLY WHAT `apply` ADDED. A port that already
//     existed survives an undo with its state, and one this command
//     created goes away again, because a port left behind holding no
//     override is a row in the file that means nothing.
//
// ─────────────────────────────────────────────────────────────────────────
// TWO FIELDS AND A LABEL THAT IS NOT ONE OF THEM
// ─────────────────────────────────────────────────────────────────────────
// `PortOverrides` carries `connector` and `signalFamily`. The user's own
// name for a jack is `Port.userLabel`, a first-class field with a real
// reader (`derived/schedule.dart`'s port-label column, since DR-054), and
// `PortOverrides.label` was an unread duplicate of it that `#233` deleted.
// So this command writes all three facts and only two of them are
// overrides, which is the honest shape rather than a tidy one.

import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/model/port.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Which fact about a port is being corrected.
enum PortFactField {
  /// `Port.userLabel`. NOT an override: a first-class instance field.
  userLabel,

  /// `PortOverrides.connector`.
  connector,

  /// `PortOverrides.signalFamily`.
  signalFamily,

  /// `Port.tapWatts`. NOT an override: a first-class instance field, and
  /// the only one here that FEEDS A ROLLUP (`ELE-005`, DR-132).
  tapWatts,

  /// `Port.lowZBypass`. Also first-class, and it moves the RESOLVED
  /// signal family (DR-131), so it is a `wires` edit and not a `meta`
  /// one.
  lowZBypass,
}

/// Sets one fact on one port, materialising the port if the document does
/// not hold it yet.
///
/// [value] is `null` to clear the override and fall back to the template,
/// which is the two-state shape `#233` settled on: nothing here feeds a
/// rollup total, so there is no third state to distinguish (see
/// `derived/port_facts.dart`).
final class SetPortFactCommand extends Command<RackDocument> {
  SetPortFactCommand({
    required this.deviceId,
    required this.portKey,
    required this.field,
    required this.value,
    required this.designatorIfMaterialised,
    required this.now,
    required this.actor,
  });

  final Uuid deviceId;
  final PortKey portKey;
  final PortFactField field;

  /// The new value, or null to inherit the template's.
  ///
  /// `Object?` because the fields are several types and this command is
  /// one. The switch in [_write] is exhaustive over [PortFactField], so a
  /// new field cannot be added without a compile error here. **That is
  /// not a small property**: DR-128 shipped a ruling describing two
  /// buttons that did not exist, and the exhaustive switch is what caught
  /// it within the hour.
  final Object? value;

  /// The designator to give the port IF this command materialises it,
  /// allocated caller-side exactly as `PortMaterialisation.designator` is.
  final String designatorIfMaterialised;

  final DateTime now;
  final String actor;

  Uuid get portId => derivePortId(deviceId, portKey);

  /// True when [apply] created the port, so [revert] knows to remove it.
  bool _materialised = false;
  Object? _previous;

  @override
  LabelKey get label => LabelKey.setEntityProperty;

  /// `meta` for the label, `wires` for the two that describe what the jack
  /// IS. A corrected connector or family changes what may legally land on
  /// this pin, and the schematic's own rules read it.
  @override
  EpochMask get touches => switch (field) {
    PortFactField.userLabel => EpochMask.meta,
    // `tapWatts` is `wires` because `ELE-005` reads it, and a load rule
    // that recomputes only on `meta` would miss the edit that put the
    // line over. `lowZBypass` because it moves the resolved family and
    // two tier-2 rules read that.
    PortFactField.connector ||
    PortFactField.signalFamily ||
    PortFactField.tapWatts ||
    PortFactField.lowZBypass => EpochMask.meta | EpochMask.wires,
  };

  /// The DEVICE, not the port. A selection holds devices; a port id is a
  /// join, which is `SaveTemplateToProjectCommand`'s own reasoning about
  /// template keys applied to the other end of the model.
  @override
  Iterable<Uuid> get affects => [deviceId];

  /// Per port, per field, so typing in a label box collapses into one undo
  /// entry while correcting a label and then a connector does not.
  @override
  Object? get mergeKey => (SetPortFactCommand, portId, field);

  @override
  void apply(RackDocument doc) {
    _materialised = false;
    var port = doc.ports[portId];
    if (port == null) {
      port = Port(
        id: portId,
        deviceId: deviceId,
        designator: designatorIfMaterialised,
        templatePortKey: portKey,
      );
      doc.ports[portId] = port;
      _materialised = true;
    }
    _previous = _read(port);
    _write(port, value);
  }

  @override
  void revert(RackDocument doc) {
    if (_materialised) {
      // EXACTLY WHAT WAS ADDED. The port did not exist before this ran, so
      // putting the old value back would leave a port holding nothing,
      // which is a row in the file that means nothing and which the
      // lazy-materialisation rule exists to keep out.
      doc.ports.remove(portId);
      return;
    }
    final port = doc.ports[portId];
    if (port == null) return;
    _write(port, _previous);
  }

  Object? _read(Port port) => switch (field) {
    PortFactField.userLabel => port.userLabel,
    PortFactField.connector => port.overrides.connector,
    PortFactField.signalFamily => port.overrides.signalFamily,
    PortFactField.tapWatts => port.tapWatts,
    PortFactField.lowZBypass => port.lowZBypass,
  };

  void _write(Port port, Object? v) {
    switch (field) {
      case PortFactField.userLabel:
        port.userLabel = v as String?;
      case PortFactField.connector:
        port.overrides.connector = v as ConnectorTypeId?;
      case PortFactField.signalFamily:
        port.overrides.signalFamily = v as SignalFamilyId?;
      case PortFactField.tapWatts:
        // NULL IS "NOT RECORDED" AND SURVIVES AS AN ABSENT KEY (G4).
        // `ELE-005` counts it as an unknown and names the speaker rather
        // than treating it as no load, so clearing this box is a real
        // statement and not a reset.
        port.tapWatts = v as int?;
      case PortFactField.lowZBypass:
        // NON-NULLABLE, so a cleared value is `false`: a transformer is
        // either switched out or it is not, and "unknown bypass" is not
        // a state a speaker can be in.
        port.lowZBypass = (v as bool?) ?? false;
    }
    // NO `meta.touch` HERE, AND THE REASON IS THE MODEL RATHER THAN AN
    // OVERSIGHT: `Port` CARRIES NO `EntityMeta`, by CR-095. Every other entity
    // this command system writes has one and every other property command
    // touches it, so this is the one edit in the product that leaves no
    // timestamp and no actor. `now` and `actor` are still taken, because
    // the command's signature should not change on the day a port grows
    // one, and because a caller that had to remember which commands want
    // a clock is a caller that will get it wrong.
  }
}
