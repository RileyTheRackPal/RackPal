// The one spelling of "remove this template from this project" (`#871`,
// DR-158 §11.157).
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS FUNCTION EXISTS RATHER THAN A LOOP AT THE CALL SITE
// ═════════════════════════════════════════════════════════════════════
// The gesture is two kinds of command: one `RemoveDeviceCommand` per
// device standing on the template, then `RemoveTemplateCommand`
// (§11.157.6). Written inline, a caller could get the ORDER right and the
// REFUSAL wrong, or apply the template removal on its own and orphan
// every device that resolved it, which CR-054 says cannot happen. One
// function means there is one place that can be wrong and one place to
// mutation-test.
//
// It also means `#872`'s reachability gate has a single edge to follow
// from the browser to both commands, rather than two constructions in a
// widget that happen to sit next to each other.
//
// ═════════════════════════════════════════════════════════════════════
// THE PLAN COMES IN, IT IS NOT COMPUTED HERE
// ═════════════════════════════════════════════════════════════════════
// `delete_location_dialog.dart`'s rule, which every destructive gesture
// in this product now obeys: the number the confirmation states and the
// set the edit removes are ONE object. A second `planTemplateRemoval`
// call here would be a second walk that could disagree with the sentence
// the person answered.
import 'package:rackpal_core/src/commands/device_commands.dart';
import 'package:rackpal_core/src/commands/template_snapshot_commands.dart';
import 'package:rackpal_core/src/derived/template_removal.dart';
import 'package:rackpal_core/src/document_controller.dart';
import 'package:rackpal_core/src/model/rack_document.dart';

/// Adds [plan]'s removals to [tx], devices first. Returns whether
/// anything was added.
///
/// **A REFUSING PLAN ADDS NOTHING AND RETURNS FALSE**, so a caller that
/// forgets to check `isRemovable` produces an empty transaction rather
/// than a removed seeded template. `TxnScope.add` already drops a child
/// that changed nothing (DR-156 §11.155.1), so an empty transaction
/// leaves no undo entry.
///
/// **DEVICES FIRST, AND THE ORDER IS LOAD-BEARING.** Each
/// `RemoveDeviceCommand` re-plans against the aggregate as it stands when
/// it applies, so the plans compose in sequence: a cable between two
/// departing devices goes with the first of them, and a net carried only
/// by departing cables is collected at the last device that could still
/// have carried it. `Transaction` reverts in reverse order, so undo puts
/// the template back BEFORE the devices whose `TemplateRef` resolves it.
bool addTemplateRemoval(
  TxnScope<RackDocument> tx,
  TemplateRemovalPlan plan,
) {
  if (!plan.isRemovable) return false;

  var changed = false;
  for (final devicePlan in plan.devicePlans) {
    if (tx.add(RemoveDeviceCommand(id: devicePlan.deviceId))) changed = true;
  }
  if (tx.add(RemoveTemplateCommand(templateId: plan.templateId))) {
    changed = true;
  }
  return changed;
}
