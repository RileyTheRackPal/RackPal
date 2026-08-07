// What `Project ▸ Locations…` means, in commands. Board M3-B/2, CR-112,
// DR-021.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY THIS IS A FILE AND NOT SIXTY LINES INSIDE `app_shell.dart`
// ─────────────────────────────────────────────────────────────────────────
// `LocationsPanel` takes callbacks rather than a `DocumentController`,
// because `rackmate_ui` may not own the mutation entry point: that is the
// same shape `RackInspectorPanel` uses. Someone has to translate the
// panel's five gestures into commands, and doing it inline in the shell's
// build method would put the only copy of that translation somewhere no
// test can reach without pumping the whole application.
//
// So it is a function returning the actions object, and
// `locations_actions_test.dart` drives it directly.
//
// ─────────────────────────────────────────────────────────────────────────
// EVERY `now` AND `actor` COMES FROM THE CONTROLLER
// ─────────────────────────────────────────────────────────────────────────
// `_controller.clock.nowUtc()` and `_controller.actor`, the way
// `rack_canvas_screen.dart` does it in eleven places. A `DateTime.now()`
// here would make every location edit untestable at the one point the
// document records WHEN, and the injected clock is why the app's tests are
// not time-dependent.
//
// ─────────────────────────────────────────────────────────────────────────
// THE REFUSAL IS NOT COMPOSED HERE EITHER
// ─────────────────────────────────────────────────────────────────────────
// `buildReparentLocation` produces DR-021 §11.20.5's sentence naming both
// nodes. This passes it through unchanged. A shell that rewrote it into
// "Cannot move location" would throw away exactly the part that tells the
// user which two nodes are the problem.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// The default name a location gets when it is created from the panel.
///
/// Created NAMED rather than with an empty name and an inline editor,
/// because the panel selects the new node and focuses nothing: a row that
/// rendered as `(unnamed)` until the user found the Name field would look
/// like the create had half-failed.
const String kNewLocationName = 'New location';

/// Wires [LocationsPanel]'s gestures to commands on [controller].
///
/// [confirmRemoval] is asked before a delete that costs anything, and is
/// the seam the widget test replaces: `confirmLocationRemoval` needs a
/// `BuildContext` and this file has none.
LocationsPanelActions buildLocationsPanelActions({
  required DocumentController controller,
  required Future<bool> Function(LocationRemovalPlan plan, String name)
  confirmRemoval,
  required void Function(String reason) onRefuse,
}) {
  RackDocument doc() => controller.doc;

  void set<T>(Uuid id, EntityField<Location, T> field, T value) {
    final cmd = buildSetEntityProperty(
      doc: doc(),
      id: id,
      field: field,
      to: value,
      now: controller.clock.nowUtc(),
      actor: controller.actor,
    );
    // Null is "already that value", which is a no-op rather than an error
    // (docs/04 §3.4's "never silently do nothing" read from the other
    // side). Pushing an empty entry onto the undo stack would make Ctrl+Z
    // do nothing visible once per keystroke that changed nothing.
    if (cmd != null) controller.run(cmd);
  }

  return LocationsPanelActions(
    onAdd: (parentId) {
      final cmd = AddLocationCommand(
        name: kNewLocationName,
        // NO CODE. `{ROOM_ABBR}` reads `Location.code`, and a code derived
        // from "New location" would put `NE` on real labels the moment
        // someone renamed the room and did not think to look at the field
        // beneath it. Empty is honest and visible.
        code: '',
        order: nextLocationOrder(doc(), parentId: parentId),
        parentId: parentId,
        now: controller.clock.nowUtc(),
        actor: controller.actor,
      );
      controller.run(cmd);
      return cmd.id;
    },
    onRename: (id, name) => set(id, LocationField.name, name),
    onSetCode: (id, code) => set(id, LocationField.code, code),
    onSetKind: (id, kind) => set(id, LocationField.kind, kind),
    onReparent: (id, newParentId) {
      final result = buildReparentLocation(
        doc: doc(),
        id: id,
        newParentId: newParentId,
        now: controller.clock.nowUtc(),
        actor: controller.actor,
      );
      switch (result) {
        case ReparentLocationReady(:final command):
          controller.run(command);
          return null;
        // Two outcomes, one return value, and they are NOT the same thing
        // arriving twice: `Unchanged` means the node is already there and
        // there is nothing to say, `Refused` carries a sentence that must
        // reach the user. Collapsing them into a nullable command would
        // lose the second.
        case ReparentLocationUnchanged():
          return null;
        case ReparentLocationRefused(:final reason):
          return reason;
      }
    },
    onDelete: (id) async {
      final cmd = buildRemoveLocation(doc: doc(), locationId: id);
      if (cmd == null) return false;
      // The name is read BEFORE the delete, obviously, but also before the
      // confirmation: the dialog is describing a document that still has
      // this room in it.
      final name = doc().locations[id]?.name.trim() ?? '';
      final proceed = await confirmRemoval(
        cmd.plan,
        name.isEmpty ? kUnnamedLocation : name,
      );
      if (!proceed) return false;
      controller.run(cmd);
      return true;
    },
    onRefuse: onRefuse,
  );
}
