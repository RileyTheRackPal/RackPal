// What `Project ▸ Add outlet…` MEANS. Board M3-C/5 (#151), DR-024.
//
// The picker in `rackmate_ui` decides nothing and runs nothing; this is
// where a chosen recipe becomes commands on the undo stack, in the shape
// `drop_entry_actions.dart` and `locations_actions.dart` established.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// Wires the outlet picker to a live [DocumentController].
///
/// NO `onRefuse` HERE, for the reason its sibling states: this surface's
/// refusals are already on screen, above the button, before it is
/// pressed. A snackbar repeating them would be the surface shouting at
/// somebody who is looking at the answer.
OutletTemplateActions buildOutletTemplateActions({
  required DocumentController controller,
}) => OutletTemplateActions(
  onCommit: (template, locationId) {
    // PLANNED HERE, NOT IN THE PICKER, against this controller's clock
    // and actor. The picker plans on every rebuild to draw its preview,
    // and those values reach `EntityMeta.createdAt` and `.updatedBy` on
    // every command a plan carries — so committing the preview's commands
    // would stamp the literal string `preview` onto real cable records.
    // That is the defect M3-A/6 found in the drop panel, and it was
    // invisible to all fourteen gates.
    //
    // Re-planning costs nothing: `planOutletFromTemplate` mutates no
    // document.
    final plan = planOutletFromTemplate(
      doc: controller.doc,
      template: template,
      locationId: locationId,
      now: controller.clock.nowUtc(),
      actor: controller.actor,
    );
    if (plan is! OutletTemplatePlanReady) return plan;

    // ONE TRANSACTION, ONE UNDO ENTRY. A plate and its four cables are
    // what a person means by "that outlet", so undo must take the plate
    // and not the last cable on it.
    controller.transact(LabelKey.addOutletFromTemplate, (tx) {
      for (final c in plan.commands) {
        tx.add(c);
      }
    });
    return plan;
  },
  onCreateStructure: () {
    // The Structure device the outlet hangs on. Created with the corpus's
    // own default designator rather than asking, exactly as the drop
    // panel does: a project that has none has exactly one sensible first
    // one, and naming it is an edit the user can make afterwards.
    controller.run(
      AddStructureCommand(
        title: 'Rough-In',
        designator: 'STR-1',
        now: controller.clock.nowUtc(),
        actor: controller.actor,
      ),
    );
  },
);
