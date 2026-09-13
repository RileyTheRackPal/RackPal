// The one spelling of "remove this plate" and "remove this panel"
// (`#877`, DR-160 §11.159).
//
// ═════════════════════════════════════════════════════════════════════
// WHY THESE ARE FUNCTIONS RATHER THAN LOOPS AT THE CALL SITE
// ═════════════════════════════════════════════════════════════════════
// `template_removal_txn.dart`'s argument, and it reaches further here
// because there are two gestures and one of them contains the other.
// Written inline, a caller could get the ORDER right and the NET wrong,
// or remove a body and leave its plates behind, which DR-160 §11.159.3
// says cannot happen because `Outlet.structureBodyId` is non-nullable.
// One function means one place that can be wrong and one place to
// mutation-test.
//
// It also means `#872`'s reachability gate has a single edge to follow
// from the Outlets tab to `RemoveOutletCommand`, and from the editor
// header to `RemoveStructureCommand`, rather than a handful of
// constructions in a widget that happen to sit near each other.
//
// ═════════════════════════════════════════════════════════════════════
// THE PLAN COMES IN, IT IS NOT COMPUTED HERE
// ═════════════════════════════════════════════════════════════════════
// `delete_location_dialog.dart`'s rule, which every destructive gesture
// in this product now obeys: the number the confirmation states and the
// set the edit removes are ONE object. A second `planOutletRemoval` call
// here would be a second walk that could disagree with the sentence the
// person answered.
//
// ═════════════════════════════════════════════════════════════════════
// CABLES FIRST, THEN THE PLATE, THEN THE BODY
// ═════════════════════════════════════════════════════════════════════
// `Transaction` reverts in reverse order, so undo puts the body back
// BEFORE the plates whose `structureBodyId` names it, and a plate back
// before the drops whose `structureOrigin.outletId` names IT. Every
// intermediate state on the way out and on the way back resolves.
import 'package:rackpal_core/src/commands/link_commands.dart';
import 'package:rackpal_core/src/commands/structure_commands.dart';
import 'package:rackpal_core/src/derived/structure_removal.dart';
import 'package:rackpal_core/src/document_controller.dart';
import 'package:rackpal_core/src/model/rack_document.dart';

/// Adds [plan]'s removals to [tx], cables first. Returns whether anything
/// was added.
///
/// **AN EMPTY PLAN ADDS NOTHING AND RETURNS FALSE**, so a caller holding a
/// plan for an outlet somebody already deleted produces an empty
/// transaction rather than a `RemoveOutletCommand` that reports success
/// over a document it did not change. `TxnScope.add` already drops a
/// child that changed nothing (DR-156 §11.155.1), so an empty transaction
/// leaves no undo entry.
bool addOutletRemoval(TxnScope<RackDocument> tx, OutletRemovalPlan plan) {
  if (plan.isEmpty) return false;

  var changed = false;
  for (final drop in plan.drops) {
    // THE NET ANSWER COMES FROM THE PLAN, not from a second
    // `netToRemoveWith` call: `TxnScope` deliberately does not expose the
    // aggregate, and a re-derivation partway through a cascade would be
    // asking about a document three removals into itself.
    if (tx.add(RemoveLinkCommand(id: drop.linkId, netId: drop.netId))) {
      changed = true;
    }
  }
  if (tx.add(RemoveOutletCommand(id: plan.outletId))) changed = true;
  return changed;
}

/// Adds [plan]'s removals to [tx]: each plate with its cables, then the
/// drops no plate carried, then the body and its paired device.
///
/// Returns whether anything was added; an empty plan adds nothing, on
/// [addOutletRemoval]'s reasoning.
bool addStructureRemoval(TxnScope<RackDocument> tx, StructureRemovalPlan plan) {
  if (plan.isEmpty) return false;

  var changed = false;
  for (final outlet in plan.outletPlans) {
    if (addOutletRemoval(tx, outlet)) changed = true;
  }
  for (final drop in plan.otherDrops) {
    if (tx.add(RemoveLinkCommand(id: drop.linkId, netId: drop.netId))) {
      changed = true;
    }
  }
  // LAST, AND IT TAKES THE DEVICE WITH IT. `RemoveStructureCommand`
  // removes both halves of the pairing itself (`structure_commands.dart`:
  // "neither half is valid alone"), which is why this composes with that
  // command rather than a `RemoveDeviceCommand` beside it.
  //
  // **NO PORTS ARE COLLECTED, AND THAT IS CHECKED RATHER THAN ASSUMED.**
  // `RemoveDeviceCommand` takes a device's materialised `Port` rows, and
  // this does not, because a Structure device cannot have any: it names
  // `kStructureTemplateRef`, which resolves to nothing on purpose, so
  // `bodyFor` returns null inside `resolveConnectTarget` and no connect
  // gesture can ever reach it. A later change that gave the Structure
  // device a real template would make that false and this line wrong.
  if (tx.add(RemoveStructureCommand(bodyId: plan.bodyId))) changed = true;
  return changed;
}
