// rackpal_core/src/commands/plan_commands.dart — the Plan view's writers
// (PLAN-C/6, DR-029, DR-037).
//
// Add, remove and reorder an underlay; set, move and clear a pin;
// calibrate a plan (`PLAN-F/1`, DR-144); draw, reshape and clear a room
// outline (`LEN-A/2`, DR-050). Every one is a `Command` with a real
// `revert`, on M0's standard.
//
// **THE COUNT IS NOT WRITTEN HERE.** This sentence read *"seven acts over
// six classes"* until `LEN-A/2` made it ten over eight, and a second copy
// of a moving number is a liability rather than a convenience: the acts
// are the `LabelKey` values these classes return and the classes are the
// ones below, both of which a reader can count and neither of which can go
// stale.
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
//   * A CALIBRATION turns a pixel distance into a `Len` and feeds the
//     same chain a pin does, so it carries the same mask. See
//     `SetPlanScaleCommand`'s own header for why `sheet` is absent from
//     it as well.
//   * AN UNDERLAY changes what is behind the pins and, through
//     calibration, every length derived on it. Adding or removing one is
//     `structure | wires` for the same chain. Its NAME is `meta`, which is
//     why renaming goes through the property table rather than through
//     here.
//   * REORDERING changes which plan draws on top and nothing else, so it
//     is `sheet`: the same class of fact as a `SheetItem` position, which
//     is what that flag was defined for.
//   * A ROOM OUTLINE is the one whose consumer does not exist yet, and it
//     carries `structure | wires` anyway. Its only purpose is to produce
//     `Location.estimatedRunLengthFromRack`, which feeds the same chain a
//     pin feeds; `LEN-A/3` builds the derivation. **A spurious wake costs
//     a redraw and a missed wake ships a stale length**, so the narrow
//     mask is the one that would have to be remembered later. See
//     `SetRoomOutlineCommand` for the argument in full.
//
// `EpochMask.rack` is deliberately absent from all six. It means heightU,
// rails and depth (see `command.dart`), and pinning a rack on a plan
// changes none of them: the rack's geometry is untouched and only its
// position on a picture moves.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackpal_core/src/derived/underlay_removal.dart';
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

/// Which kind of carrier [entityId] is, or NULL when it is nothing that
/// can hold a pin.
///
/// ═══════════════════════════════════════════════════════════════════════
/// IT ASKS THE DOCUMENT RATHER THAN TRANSLATING `PlanPinCarrier`
/// ═══════════════════════════════════════════════════════════════════════
/// `draw/scene/plan_scene.dart` has a second three-value enum for the same
/// three carriers, and its own header says the duplication is deliberate:
/// one says which collection a WRITER reaches into, the other says which
/// mark to DRAW. `draw_source_gate_test.dart` keeps the drawing concern
/// out of this layer, so a converter between them would be exactly the
/// import that gate refuses.
///
/// **NOTHING NEEDED THIS UNTIL `#878`** (DR-162 §11.161.1), and the reason
/// is worth recording: every writer so far knew its carrier before it
/// started. The palette drag places a device, the drop table pins an
/// outlet, the strip row carries its own kind. Clearing a pin is the first
/// gesture that begins from a mark somebody is LOOKING AT and has to work
/// back to what it hangs on.
///
/// **A RACKED DEVICE ANSWERS NULL**, not `offRackDevice`. Only
/// `OffRackPlacement` carries a `planPin` (docs/15 §3.4), so a device in a
/// rack is not a carrier at all, and saying so here is what stops a caller
/// building a command `_writePin` would refuse.
PinCarrier? pinCarrierFor(RackDocument doc, Uuid entityId) {
  if (doc.racks.containsKey(entityId)) return PinCarrier.rack;
  if (doc.outlets.containsKey(entityId)) return PinCarrier.outlet;
  if (doc.devices[entityId]?.placement is OffRackPlacement) {
    return PinCarrier.offRackDevice;
  }
  return null;
}

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
  bool apply(RackDocument doc) {
    // REFUSES A PIN NAMING AN UNDERLAY THIS DOCUMENT DOES NOT HAVE, which
    // is the whole reason `Outlet.planPin` is kept out of the property
    // table (`set_entity_property_command_test.dart`): a table row's
    // `set` writes and returns with no way to refuse, and a dangling
    // reference in a drawing is what DR-021's cascade spends a ruling
    // avoiding elsewhere.
    if (!doc.underlays.containsKey(pin.underlayId)) return false;
    _previous = _pinOf(doc, carrier, entityId);
    _wasMove = _previous != null;
    return _applied = _writePin(doc, carrier, entityId, pin);
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
  bool apply(RackDocument doc) {
    _previous = _pinOf(doc, carrier, entityId);
    // NOTHING TO DO IS NOT AN ERROR, but it must not look like a done
    // thing either: `_applied` stays false, so a `revert` that follows
    // throws instead of writing a null over whatever is there by then.
    if (_previous == null) return false;
    return _applied = _writePin(doc, carrier, entityId, null);
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('ClearPlanPinCommand.revert called before apply().');
    }
    _writePin(doc, carrier, entityId, _previous);
  }
}

/// Gives a room its shape, or changes the one it has (DR-050 §11.49,
/// `LEN-A/2`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// A COMMAND AND NOT A PROPERTY-TABLE ROW, FOR `planPin`'s REASON
/// ═══════════════════════════════════════════════════════════════════════
/// `set_entity_property_command_test.dart` keeps `Location.planOutline`
/// out of the table and names this command as the owner. The reason is
/// the one [SetPlanPinCommand] already carries: a row's `set` writes and
/// returns **with no way to refuse**, and a `RoomOutline` names an
/// underlay by id, so a row would let a caller shape a room on a plan
/// this document does not hold.
///
/// ═══════════════════════════════════════════════════════════════════════
/// AND IT REFUSES A SHAPE THE PRODUCT COULD NOT MEASURE
/// ═══════════════════════════════════════════════════════════════════════
/// `RoomOutline` HOLDS a two-vertex outline rather than throwing, because
/// the decoder must read whatever is on disk (CR-093). That is a rule
/// about READING somebody else's file. **This is the product's own
/// writer**, and authoring a shape it has already said it cannot measure
/// would put a degenerate polygon in a document with nobody to blame for
/// it. The two facts are not in tension: one is tolerance of the world,
/// the other is discipline about what we ourselves write.
final class SetRoomOutlineCommand extends Command<RackDocument> {
  SetRoomOutlineCommand({required this.locationId, required this.outline});

  final Uuid locationId;

  /// The shape. Never null: clearing is [ClearRoomOutlineCommand], which
  /// carries its own label so the Edit menu can say which act it is
  /// offering to take back.
  final RoomOutline outline;

  RoomOutline? _previous;
  bool _applied = false;
  bool _wasReshape = false;

  @override
  LabelKey get label =>
      _wasReshape ? LabelKey.reshapeRoomOutline : LabelKey.drawRoomOutline;

  /// ═══════════════════════════════════════════════════════════════════
  /// `wires` IS OWED BY WHAT AN OUTLINE IS FOR, NOT BY WHAT READS IT
  /// TODAY
  /// ═══════════════════════════════════════════════════════════════════
  /// This file's header says masks are *"DERIVED FROM WHAT EACH COMMAND
  /// CHANGES rather than chosen to look plausible"*, and on the day this
  /// lands the derivation reads nothing: `LEN-A/3` builds the consumer.
  ///
  /// It is `wires` anyway, and the asymmetry is the argument. An outline's
  /// only purpose is to produce `Location.estimatedRunLengthFromRack`,
  /// which feeds a schedule row's length, which feeds a sheet: the exact
  /// chain a pin feeds. **A spurious wake costs a redraw. A missed wake
  /// ships a stale length**, which is DR-011.4's defect, and shipping the
  /// narrow mask now would mean `LEN-A/3` has to remember to widen it.
  @override
  EpochMask get touches => EpochMask.structure | EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [locationId];

  @override
  bool apply(RackDocument doc) {
    final location = doc.locations[locationId];
    if (location == null) return false;
    if (!doc.underlays.containsKey(outline.underlayId)) return false;
    if (!outline.isUsable) return false;
    _previous = location.planOutline;
    _wasReshape = _previous != null;
    location.planOutline = outline;
    return _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('SetRoomOutlineCommand.revert called before apply().');
    }
    doc.locations[locationId]?.planOutline = _previous;
  }
}

/// Takes a room's shape off (DR-050 §11.49, `LEN-A/2`).
///
/// Its own command and its own label rather than a [SetRoomOutlineCommand]
/// with a null outline, on [ClearPlanPinCommand]'s precedent exactly.
final class ClearRoomOutlineCommand extends Command<RackDocument> {
  ClearRoomOutlineCommand({required this.locationId});

  final Uuid locationId;

  RoomOutline? _previous;
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.clearRoomOutline;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [locationId];

  @override
  bool apply(RackDocument doc) {
    final location = doc.locations[locationId];
    _previous = location?.planOutline;
    // NOTHING TO DO IS NOT AN ERROR, but it must not look like a done
    // thing either: `_applied` stays false, so a `revert` that follows
    // throws instead of writing a null over whatever is there by then.
    // [ClearPlanPinCommand]'s own comment, and its own reasoning.
    if (location == null || _previous == null) return false;
    location.planOutline = null;
    return _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('ClearRoomOutlineCommand.revert called before apply().');
    }
    doc.locations[locationId]?.planOutline = _previous;
  }
}

/// The next `order` for a new underlay.
///
/// PER DOCUMENT, on `nextPathwayOrder`'s precedent: underlays are a flat
/// list and `order` decides which plan draws on top, not which room it is
/// in. A new one goes last, which is what an import means.
FracIndex nextUnderlayOrder(RackDocument doc) =>
    nextOrder(doc.underlays.values.map((u) => u.order));

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
  bool apply(RackDocument doc) {
    if (doc.underlays.containsKey(underlay.id)) return false;
    doc.underlays[underlay.id] = underlay;
    return _applied = true;
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

  /// The room outlines this removal cleared, by location id, so [revert]
  /// can put them back.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// AN OUTLINE DANGLING IS WORSE THAN A PIN DANGLING, AND `LEN-A/1`
  /// PROVED IT
  /// ═══════════════════════════════════════════════════════════════════
  /// A pin left over a removed underlay is a stray point.
  /// `documentMinReaderVersion` checks every pin individually, so a
  /// document carrying one still stamps `kPlanMinReaderVersion` and an
  /// older build opens it read-only.
  ///
  /// **The outline is checked the same way and for the same reason, and
  /// `room_outline_test.dart` says in capitals what happens without it**:
  /// an older build opens the file read-write and deletes the drawing on
  /// save, which is DR-019 §11.18.1's hazard. Clearing here is the other
  /// half of that: the stamp makes the orphan survivable, and this makes
  /// the product stop producing one.
  late final Map<Uuid, RoomOutline> _clearedOutlines = {};
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.removePlanUnderlay;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [
    underlayId,
    ..._clearedPins.keys.map((k) => k.$2),
    ..._clearedOutlines.keys,
  ];

  @override
  bool apply(RackDocument doc) {
    final underlay = doc.underlays[underlayId];
    if (underlay == null) return false;
    _removed = underlay;

    // ONE ANSWER READ TWICE (`#870`). This used to walk the four
    // collections inline, which was correct and unshareable: the
    // confirmation that has to say "3 pins" before the fact would have
    // been a second walk that could drift from this one.
    // `planUnderlayRemoval` is now the only place that decides what a
    // page carries, and the dialog counts THIS object.
    final plan = planUnderlayRemoval(doc, underlayId);
    _clearedPins.addAll(plan.pins);
    _clearedOutlines.addAll(plan.outlines);

    for (final entry in plan.pins.keys) {
      final (carrier, id) = entry;
      _writePin(doc, carrier, id, null);
    }
    for (final locationId in plan.outlines.keys) {
      doc.locations[locationId]?.planOutline = null;
    }

    doc.underlays.remove(underlayId);
    return _applied = true;
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
    for (final entry in _clearedOutlines.entries) {
      doc.locations[entry.key]?.planOutline = entry.value;
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
  bool apply(RackDocument doc) {
    final underlay = doc.underlays[underlayId];
    if (underlay == null) return false;
    _previous = underlay.order;
    underlay.order = order;
    return _applied = true;
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

/// Sets the calibration on an underlay, or replaces the one already there
/// (docs/15 §5, DR-144 §11.143, PLAN-F/1).
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE SEVENTH WRITER, AND `PlanScale` HAD NONE UNTIL IT
/// ═══════════════════════════════════════════════════════════════════════
/// `PLAN-C/2` built the model and `PLAN-C/5` serialized it, and no command
/// on this page set a scale: `PlanUnderlay.scale` was null in every
/// document this product could produce, and every one of `PlanScale`'s
/// derivation methods had zero call sites in `lib/`. DR-144 §11.143.1 is
/// the census, and it is the third chapter in a row to find a modelled
/// field nothing can reach.
///
/// ═══════════════════════════════════════════════════════════════════════
/// A COMMAND AND NOT A SETTINGS FIELD, WHICH IS docs/15 §5's OWN WORDING
/// ═══════════════════════════════════════════════════════════════════════
/// *"Recalibration is a document command like any other and is undoable.
/// It changes every derived length on that plan at once, which is exactly
/// why it goes through the command stack."* A settings field that silently
/// rewrote sixty schedule rows would be unauditable and unundoable.
///
/// ONE COMMAND FOR SET AND REPLACE, with the label decided at [apply] from
/// the document, on `SetPlanPinCommand`'s precedent one class up: "Undo
/// Recalibrate" in front of somebody who has just calibrated a fresh plan
/// names an act they did not perform.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE MASK MATCHES THE PINS', AND THAT IS A DERIVATION RATHER THAN A COPY
/// ═══════════════════════════════════════════════════════════════════════
/// A scale turns a pixel distance into a `Len`, which feeds
/// `planLowerBound`, which feeds a schedule row's length, which feeds a
/// sheet. That is the identical chain this file already derived for a pin,
/// so the mask is the identical `structure | wires`.
///
/// **`sheet` IS ABSENT ON PURPOSE.** `T1.01`'s scale bar will read this
/// value (`PLAN-H/4`), and adding `sheet` here while the pin commands feed
/// the same sheet without it would leave two commands on one chain
/// disagreeing about their own consequences. When that sheet exists, it is
/// the whole chain that gets re-derived, not this one command. `PLAN-F/2`
/// tests the mask against a listener rather than against itself, which is
/// what DR-011.4's scar asks for.
final class SetPlanScaleCommand extends Command<RackDocument> {
  SetPlanScaleCommand({required this.underlayId, required this.scale});

  final Uuid underlayId;

  /// The calibration. **Never null**: there is no gesture that sets a
  /// scale to unknown, and DR-144 §11.143.8 declines to invent one, so a
  /// nullable field here would be a state nothing can produce and every
  /// reader has to consider.
  final PlanScale scale;

  PlanScale? _previous;
  bool _applied = false;
  bool _wasRecalibration = false;

  @override
  LabelKey get label =>
      _wasRecalibration ? LabelKey.recalibratePlan : LabelKey.calibratePlan;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [underlayId];

  @override
  bool apply(RackDocument doc) {
    final underlay = doc.underlays[underlayId];
    if (underlay == null) return false;
    _previous = underlay.scale;
    // A REPLACEMENT IS DECIDED FROM THE PREVIOUS VALUE'S PRESENCE, not
    // from its usability. An underlay carrying a scale whose two points
    // coincide is calibrated as far as the document is concerned and
    // useless as far as a length is concerned; replacing it is still
    // recalibration, and calling it a first calibration would name the
    // act by a property of the value rather than by what happened.
    _wasRecalibration = _previous != null;
    underlay.scale = scale;
    return _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('SetPlanScaleCommand.revert called before apply().');
    }
    doc.underlays[underlayId]?.scale = _previous;
  }
}

/// Turns a plan a quarter, clockwise or anticlockwise (DR-184 §11.183,
/// `#911`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// RELATIVE, BECAUSE THAT IS WHAT BOTH OF ITS CALLERS SAY
/// ═══════════════════════════════════════════════════════════════════════
/// A button and a key both mean "one more quarter this way", and neither
/// knows or cares what the plan's turn is now. A command that took the
/// TARGET would make each caller read the model to compute it, which is a
/// second place to get `% 4` wrong. Revert restores the value [apply]
/// found rather than turning back, so undo is exact even against a file
/// whose stored turn was written by somebody else.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE MASK IS `sheet`, ON `ReorderPlanUnderlayCommand`'S REASONING
/// ═══════════════════════════════════════════════════════════════════════
/// A turn changes what `T1.01` draws and which way up the canvas shows the
/// picture. It changes no length, because a length is measured between
/// stored pixels and no stored pixel moves (§11.183.2), so `structure` and
/// `wires`, which [SetPlanScaleCommand] declares because a scale DOES feed
/// every run, are absent on purpose.
final class RotatePlanCommand extends Command<RackDocument> {
  RotatePlanCommand({required this.underlayId, required this.clockwise});

  final Uuid underlayId;

  /// True for a quarter turn clockwise as the plan is seen.
  final bool clockwise;

  int _previous = 0;
  bool _applied = false;

  @override
  LabelKey get label => clockwise
      ? LabelKey.rotatePlanClockwise
      : LabelKey.rotatePlanAnticlockwise;

  @override
  EpochMask get touches => EpochMask.sheet;

  @override
  Iterable<Uuid> get affects => [underlayId];

  @override
  bool apply(RackDocument doc) {
    final underlay = doc.underlays[underlayId];
    if (underlay == null) return false;
    _previous = underlay.rotationQuarterTurns;
    // DART'S `%` IS NON-NEGATIVE for a positive divisor, so `0 - 1` wraps
    // to 3 rather than to -1 and the stored value never leaves 0..3.
    underlay.rotationQuarterTurns = (_previous + (clockwise ? 1 : -1)) % 4;
    return _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('RotatePlanCommand.revert called before apply().');
    }
    doc.underlays[underlayId]?.rotationQuarterTurns = _previous;
  }
}

/// Sets a plan's name and the location it shows (DR-185 §11.184, `#912`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE WRITER TWO MODELLED FIELDS NEVER HAD
/// ═══════════════════════════════════════════════════════════════════════
/// `PlanUnderlay.name` was the file's for the life of the project and
/// `PlanUnderlay.locationId` was accepted by every import signature and
/// passed by no caller. So three pages of one PDF read the same, the rail's
/// room line never printed, and DR-142's rule made a floorless plan's
/// unpinned strip list every carrier in the project (§11.184.0).
///
/// ONE COMMAND FOR BOTH, because the dialog that raises it edits both and
/// §11.184.1 rules them one undo entry.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THREE REFUSALS, AND A NO-OP IS ONE OF THEM
/// ═══════════════════════════════════════════════════════════════════════
/// A plan that is not there; a name that is empty once trimmed, which is a
/// row nobody can read; and a location this document does not hold, which
/// would be the dangling reference DR-021 exists to prevent. **And a change
/// that changes nothing**, on DR-156's contract: a dialog confirmed with
/// `Enter` and no edit must not leave an undo entry that undoes nothing.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE MASK
/// ═══════════════════════════════════════════════════════════════════════
/// `meta` for the name, which `T1.01`'s title block prints, so `sheet` as
/// well. `structure` for the location, because it is the scope the
/// unpinned strip and the PLN advisories read, and it is the location a
/// device dropped from the palette onto this plan is placed in.
final class SetPlanUnderlayDetailsCommand extends Command<RackDocument> {
  SetPlanUnderlayDetailsCommand({
    required this.underlayId,
    required this.name,
    required this.locationId,
  });

  final Uuid underlayId;

  /// The new name, stored TRIMMED.
  final String name;

  /// The location the plan shows, or null for a plan that shows no one
  /// place, which is a site plan and an ordinary answer (docs/15 §3.1).
  final Uuid? locationId;

  String _previousName = '';
  Uuid? _previousLocation;
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.editPlanUnderlay;

  @override
  EpochMask get touches =>
      EpochMask.meta | EpochMask.sheet | EpochMask.structure;

  @override
  Iterable<Uuid> get affects => [underlayId];

  @override
  bool apply(RackDocument doc) {
    final underlay = doc.underlays[underlayId];
    if (underlay == null) return false;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final location = locationId;
    if (location != null && !doc.locations.containsKey(location)) {
      return false;
    }
    if (underlay.name == trimmed && underlay.locationId == location) {
      return false;
    }
    _previousName = underlay.name;
    _previousLocation = underlay.locationId;
    underlay
      ..name = trimmed
      ..locationId = location;
    return _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError(
        'SetPlanUnderlayDetailsCommand.revert called before apply().',
      );
    }
    doc.underlays[underlayId]
      ?..name = _previousName
      ..locationId = _previousLocation;
  }
}
