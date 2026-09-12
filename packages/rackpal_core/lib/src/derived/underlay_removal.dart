// rackpal_core/src/derived/underlay_removal.dart — what removing a
// floorplan page costs, counted before it costs it (`#870`, DR-029).
//
// ═══════════════════════════════════════════════════════════════════════
// ONE ANSWER READ TWICE, WHICH IS `planLocationRemoval`'s WHOLE POINT
// ═══════════════════════════════════════════════════════════════════════
// `delete_location_dialog.dart` states the rule this file exists to obey:
// *"A dialog that said '4 rooms' and removed five would be worse than no
// dialog, and the only structural guarantee against that is one answer
// read twice."*
//
// So `RemovePlanUnderlayCommand.apply` enumerates what it clears by
// calling THIS function, and the confirmation counts the same object. The
// command previously walked the four collections itself, inline, which
// was correct and unshareable: a dialog asking the same question would
// have been a second walk that could drift.
import 'package:rackpal_core/src/commands/plan_commands.dart' show PinCarrier;
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// What a floorplan page takes with it.
///
/// **TWO NUMBERS IN DIFFERENT UNITS**, on `LocationRemovalPlan`'s own
/// reasoning. A pin cleared is a thing that loses its POSITION and stays
/// in the project; a room outline cleared is a drawing that goes, and the
/// estimate derived from it goes with it. Reporting them as one total
/// would describe neither.
final class UnderlayRemovalPlan {
  const UnderlayRemovalPlan({
    required this.underlayId,
    required this.pins,
    required this.outlines,
  });

  final Uuid underlayId;

  /// Every carrier pinned to this page, and the pin it would lose.
  ///
  /// Keyed the way `RemovePlanUnderlayCommand` stores them, so the
  /// command can write its revert map straight from this.
  final Map<(PinCarrier, Uuid), PlanPin> pins;

  /// Every room whose outline was drawn on this page.
  final Map<Uuid, RoomOutline> outlines;

  int get pinCount => pins.length;
  int get outlineCount => outlines.length;

  /// Whether removing it costs anything a person should be asked about.
  ///
  /// **A BARE PAGE IS NOT ASKED ABOUT**, which is DR-013 §11.13.2's last
  /// sentence and `confirmLocationRemoval`'s behaviour: *"a prompt for a
  /// consequence-free delete is the nag that teaches people to click
  /// through prompts, including this one on the day it matters."* An
  /// imported page nobody has pinned to yet is exactly that case, and it
  /// is the common one when somebody picked the wrong page out of a PDF.
  bool get needsConfirmation => pins.isNotEmpty || outlines.isNotEmpty;
}

/// What removing [underlayId] would clear.
///
/// Returns an EMPTY plan for an id the document does not hold, rather
/// than throwing: a caller asking about a page that is already gone is
/// asking a reasonable question and the answer is "nothing".
UnderlayRemovalPlan planUnderlayRemoval(RackDocument doc, Uuid underlayId) {
  final pins = <(PinCarrier, Uuid), PlanPin>{};
  final outlines = <Uuid, RoomOutline>{};

  for (final rack in doc.racks.values) {
    final pin = rack.planPin;
    if (pin != null && pin.underlayId == underlayId) {
      pins[(PinCarrier.rack, rack.id)] = pin;
    }
  }
  for (final outlet in doc.outlets.values) {
    final pin = outlet.planPin;
    if (pin != null && pin.underlayId == underlayId) {
      pins[(PinCarrier.outlet, outlet.id)] = pin;
    }
  }
  for (final device in doc.devices.values) {
    final placement = device.placement;
    if (placement is! OffRackPlacement) continue;
    final pin = placement.planPin;
    if (pin != null && pin.underlayId == underlayId) {
      pins[(PinCarrier.offRackDevice, device.id)] = pin;
    }
  }
  for (final location in doc.locations.values) {
    final outline = location.planOutline;
    if (outline != null && outline.underlayId == underlayId) {
      outlines[location.id] = outline;
    }
  }

  return UnderlayRemovalPlan(
    underlayId: underlayId,
    pins: pins,
    outlines: outlines,
  );
}
