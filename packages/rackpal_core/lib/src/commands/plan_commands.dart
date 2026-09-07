// rackpal_core/src/commands/plan_commands.dart — the Plan view's writers
// (PLAN-C/6, DR-029, DR-037).
//
// Six commands: add, remove and reorder an underlay; set, move and clear a
// pin. Every one is a `Command` with a real `revert`, on M0's standard.
//
// ═══════════════════════════════════════════════════════════════════════
// THE EPOCH MASK IS THE PART THAT GOES WRONG, AND THIS PROJECT HAS THE
// SCAR
// ═══════════════════════════════════════════════════════════════════════
// DR-011.4's first implementation SILENTLY DID NOTHING because
// `ConnectPortsCommand.touches` was `wires | meta` and the meta bump
// advanced the scene epoch past the stamp the wires listener had just
// written. Every symbol still moved, on the very commit the clause was
// about, and nothing failed.
//
// So these masks are DERIVED FROM WHAT EACH COMMAND CHANGES rather than
// chosen to look plausible, and the derivation is written down:
//
//   * A PIN changes where a device or an outlet is on a plan. That feeds
//     `planLowerBound`, which feeds a schedule row's length, which feeds a
//     sheet. A consumer watching cable data subscribes to `wires`, and one
//     watching placement subscribes to `structure`, so a pin touches
//     `structure | wires`. **A mask that stopped at the plan would be
//     DR-011.4's defect in a new place**: the plan scene would redraw and
//     the schedule would keep printing the old length.
//   * AN UNDERLAY changes what is behind the pins and, through
//     calibration, every length derived on it. Adding or removing one is
//     `structure | wires` for the same chain. Its NAME is `meta`, which is
//     why renaming goes through the property table rather than through
//     here.
//   * REORDERING changes which plan draws on top and nothing else, so it
//     is `sheet`: the same class of fact as a `SheetItem` position, which
//     is what that flag was defined for.
//
// `EpochMask.rack` is deliberately absent from all six. It means heightU,
// rails and depth (see `command.dart`), and pinning a rack on a plan
// changes none of them: the rack's geometry is untouched and only its
// position on a picture moves.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The three things a pin can hang on (docs/15 §3.4).
///
/// A CLOSED ENUM AND NOT A STRING, so a command naming a carrier that
/// does not exist is a compile error rather than a silent no-op. The
/// three are `Rack`, `Outlet` and a device whose placement is
/// `OffRackPlacement`; there is no fourth, and the day there is, every
/// switch over this stops compiling and somebody decides.
enum PinCarrier { rack, outlet, offRackDevice }

/// Reads the pin currently on [entityId], or null when there is none or
/// the entity is gone.
PlanPin? _pinOf(RackDocument doc, PinCarrier carrier, Uuid entityId) =>
    switch (carrier) {
      PinCarrier.rack => doc.racks[entityId]?.planPin,
      PinCarrier.outlet => doc.outlets[entityId]?.planPin,
      PinCarrier.offRackDevice => switch (doc.devices[entityId]?.placement) {
        final OffRackPlacement p => p.planPin,
        _ => null,
      },
    };

/// Writes [pin] onto [entityId], or clears it when [pin] is null.
///
/// Returns false when the write could not happen: the entity is missing,
/// or a device's placement is not `OffRackPlacement`. **Silence is not an
/// option here** and the callers below turn a false into a no-op that
/// leaves `_applied` unset, so a later `revert` throws rather than
/// pretending.
bool _writePin(
  RackDocument doc,
  PinCarrier carrier,
  Uuid entityId,
  PlanPin? pin,
) {
  switch (carrier) {
    case PinCarrier.rack:
      final rack = doc.racks[entityId];
      if (rack == null) return false;
      rack.planPin = pin;
      return true;
    case PinCarrier.outlet:
      final outlet = doc.outlets[entityId];
      if (outlet == null) return false;
      outlet.planPin = pin;
      return true;
    case PinCarrier.offRackDevice:
      final device = doc.devices[entityId];
      final placement = device?.placement;
      if (device == null || placement is! OffRackPlacement) return false;
      // PLACEMENT VARIANTS ARE ALL-`final`, so setting a pin REPLACES the
      // placement object rather than mutating it, per `placement.dart`'s
      // own header. `withPlanPin` is the one site that knows the other
      // fields, which is why it exists rather than a longhand rebuild
      // here: a field added to that class later is a silent drop at a
      // longhand site and a compile-visible edit at exactly one.
      device.placement = placement.withPlanPin(pin);
      return true;
  }
}

/// Puts a pin on a rack, an outlet or an off-rack device, or moves the
/// one already there (docs/15 §3.4).
///
/// ONE COMMAND FOR SET AND MOVE, and the label is what makes that
/// honest: `setPlanPin` when there was nothing there and `movePlanPin`
/// when there was, decided at [apply] from the document rather than by
/// the caller. "Undo Move Pin" in front of somebody who has just placed
/// their first pin names an act they did not perform, and asking the
/// call site to know which it was is how the two drift apart.
final class SetPlanPinCommand extends Command<RackDocument> {
  SetPlanPinCommand({
    required this.carrier,
    required this.entityId,
    required this.pin,
  });

  final PinCarrier carrier;
  final Uuid entityId;

  /// Where the pin goes. Never null: clearing is
  /// [ClearPlanPinCommand], which carries its own label so the Edit menu
  /// can say which act it is offering to take back.
  final PlanPin pin;

  PlanPin? _previous;
  bool _applied = false;
  bool _wasMove = false;

  @override
  LabelKey get label => _wasMove ? LabelKey.movePlanPin : LabelKey.setPlanPin;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [entityId];

  @override
  void apply(RackDocument doc) {
    // REFUSES A PIN NAMING AN UNDERLAY THIS DOCUMENT DOES NOT HAVE, which
    // is the whole reason `Outlet.planPin` is kept out of the property
    // table (`set_entity_property_command_test.dart`): a table row's
    // `set` writes and returns with no way to refuse, and a dangling
    // reference in a drawing is what DR-021's cascade spends a ruling
    // avoiding elsewhere.
    if (!doc.underlays.containsKey(pin.underlayId)) return;
    _previous = _pinOf(doc, carrier, entityId);
    _wasMove = _previous != null;
    _applied = _writePin(doc, carrier, entityId, pin);
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('SetPlanPinCommand.revert called before apply().');
    }
    _writePin(doc, carrier, entityId, _previous);
  }
}

/// Takes a pin off (docs/15 §3.4).
///
/// Its own command and its own label rather than a `SetPlanPinCommand`
/// with a null pin, on `ClearLinkClassOverrideCommand`'s precedent: "Undo
/// Set Pin" in front of somebody who has just removed one names the
/// opposite act.
final class ClearPlanPinCommand extends Command<RackDocument> {
  ClearPlanPinCommand({required this.carrier, required this.entityId});

  final PinCarrier carrier;
  final Uuid entityId;

  PlanPin? _previous;
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.clearPlanPin;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [entityId];

  @override
  void apply(RackDocument doc) {
    _previous = _pinOf(doc, carrier, entityId);
    // NOTHING TO DO IS NOT AN ERROR, but it must not look like a done
    // thing either: `_applied` stays false, so a `revert` that follows
    // throws instead of writing a null over whatever is there by then.
    if (_previous == null) return;
    _applied = _writePin(doc, carrier, entityId, null);
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('ClearPlanPinCommand.revert called before apply().');
    }
    _writePin(doc, carrier, entityId, _previous);
  }
}

/// Brings a floorplan into the project (docs/15 §3.1).
///
/// The IMAGE BYTES are not this command's business. [underlay] names a
/// container member and the import path writes it (`PLAN-D`); this
/// command adds the entity that points at it. Undoing therefore leaves an
/// orphaned member in the container, which is correct: the member is
/// cheap, the bytes are the architect's, and deleting them on an undo
/// would make a redo unable to find them.
final class AddPlanUnderlayCommand extends Command<RackDocument> {
  AddPlanUnderlayCommand({required this.underlay});

  final PlanUnderlay underlay;

  bool _applied = false;

  @override
  LabelKey get label => LabelKey.addPlanUnderlay;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [underlay.id];

  @override
  void apply(RackDocument doc) {
    if (doc.underlays.containsKey(underlay.id)) return;
    doc.underlays[underlay.id] = underlay;
    _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('AddPlanUnderlayCommand.revert called before apply().');
    }
    doc.underlays.remove(underlay.id);
  }
}

/// Takes a floorplan out, and every pin that stood on it with it
/// (docs/15 §3.1).
///
/// ═══════════════════════════════════════════════════════════════════════
/// IT CASCADES, ON DR-021's REASONING AND NOT ON A NEW ONE
/// ═══════════════════════════════════════════════════════════════════════
/// A `PlanPin` names its underlay. Removing the underlay and leaving the
/// pins would leave every one of them pointing at nothing, which is
/// exactly the dangling reference DR-021 §11.20 refuses for a `Location`
/// subtree: it clears the nine references rather than leaving them
/// hanging. The pins are captured first and restored by [revert], so the
/// undo puts back the plan AND the dots on it, which is what a person who
/// pressed Ctrl+Z expects to see.
final class RemovePlanUnderlayCommand extends Command<RackDocument> {
  RemovePlanUnderlayCommand({required this.underlayId});

  final Uuid underlayId;

  /// The underlay taken out, restored by [revert].
  ///
  /// `late` and non-nullable, with [_applied] carrying the "has run" bit
  /// rather than a null check. That is `SetLinkClassCommand`'s documented
  /// pattern and it is what the analyzer asks for: a nullable field whose
  /// null only ever means "apply has not run" is two facts wearing one
  /// value.
  late PlanUnderlay _removed;

  /// The pins this removal cleared, so [revert] can put them back.
  ///
  /// `late final` rather than an eager `{}`: the lint asks for it, and it
  /// is also honest, because before [apply] runs there is no answer to
  /// "which pins did this clear" and an empty map claims there were none.
  late final Map<(PinCarrier, Uuid), PlanPin> _clearedPins = {};
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.removePlanUnderlay;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [
    underlayId,
    ..._clearedPins.keys.map((k) => k.$2),
  ];

  @override
  void apply(RackDocument doc) {
    final underlay = doc.underlays[underlayId];
    if (underlay == null) return;
    _removed = underlay;

    for (final rack in doc.racks.values) {
      final pin = rack.planPin;
      if (pin != null && pin.underlayId == underlayId) {
        _clearedPins[(PinCarrier.rack, rack.id)] = pin;
        rack.planPin = null;
      }
    }
    for (final outlet in doc.outlets.values) {
      final pin = outlet.planPin;
      if (pin != null && pin.underlayId == underlayId) {
        _clearedPins[(PinCarrier.outlet, outlet.id)] = pin;
        outlet.planPin = null;
      }
    }
    for (final device in doc.devices.values) {
      final placement = device.placement;
      if (placement is! OffRackPlacement) continue;
      final pin = placement.planPin;
      if (pin != null && pin.underlayId == underlayId) {
        _clearedPins[(PinCarrier.offRackDevice, device.id)] = pin;
        device.placement = placement.withPlanPin(null);
      }
    }

    doc.underlays.remove(underlayId);
    _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError(
        'RemovePlanUnderlayCommand.revert called before apply().',
      );
    }
    doc.underlays[underlayId] = _removed;
    for (final entry in _clearedPins.entries) {
      _writePin(doc, entry.key.$1, entry.key.$2, entry.value);
    }
  }
}

/// Moves a floorplan in the stacking order (docs/15 §3.1).
///
/// `sheet` AND NOT `structure`, which is the one mask on this page that is
/// not about lengths: which plan draws on top changes what a person sees
/// and changes no derived number at all. That is the same class of fact as
/// a `SheetItem` position, which is what `EpochMask.sheet` was defined
/// for.
final class ReorderPlanUnderlayCommand extends Command<RackDocument> {
  ReorderPlanUnderlayCommand({required this.underlayId, required this.order});

  final Uuid underlayId;
  final FracIndex order;

  late FracIndex _previous;
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.reorderPlanUnderlay;

  @override
  EpochMask get touches => EpochMask.sheet;

  @override
  Iterable<Uuid> get affects => [underlayId];

  @override
  void apply(RackDocument doc) {
    final underlay = doc.underlays[underlayId];
    if (underlay == null) return;
    _previous = underlay.order;
    underlay.order = order;
    _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError(
        'ReorderPlanUnderlayCommand.revert called before apply().',
      );
    }
    doc.underlays[underlayId]?.order = _previous;
  }
}
