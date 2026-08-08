// What `Project ▸ Add drops…` MEANS. Board M3-C/1 (#147).
//
// The panel in `rackmate_ui` decides nothing and runs nothing; this is
// where a planned line becomes commands on the undo stack, in the shape
// `locations_actions.dart` already established for M3-B.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// The name a room created from the entry surface gets, and the code it
/// gets with it.
///
/// A CODE IS GENERATED HERE AND NOWHERE ELSE, and it is the one place
/// this file guesses. `AddLocationCommand` from the Locations panel
/// deliberately leaves `code` empty (M3-B), because a room created by
/// hand is being named and not labelled. A room created from a drop line
/// is the opposite: the line's next act is to label nine cables, and
/// `{ROOM_ABBR}` reads exactly this field. Without it the very next plan
/// refuses with "Attic needs a short code" — technically correct, and a
/// dead stop three characters into a sixty-drop session.
///
/// The guess is INITIALS, upper-cased: "Living Room" becomes `LR`,
/// "Attic" becomes `A`. It is visible in the preview before a single
/// label is committed, editable in `Project ▸ Locations…`, and wrong in a
/// way the user can see rather than wrong in a way they find at the
/// panel.
String initialsFor(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  if (words.length == 1) {
    // One word gives one letter too little to be useful, so take up to
    // three: "Attic" becomes `ATT`, which is what a person would write.
    final w = words.single;
    return w.substring(0, w.length < 3 ? w.length : 3).toUpperCase();
  }
  return words.map((w) => w[0]).join().toUpperCase();
}

/// Wires the entry panel to a live [DocumentController].
DropEntryActions buildDropEntryActions({
  required DocumentController controller,
  required void Function(String reason) onRefuse,
}) => DropEntryActions(
  onCommit: (plan) {
    // ONE TRANSACTION, ONE UNDO ENTRY. Nine drops and their outlet are
    // what a person means by "that line", so undo must take the line and
    // not the last cable on it.
    controller.transact(LabelKey.addDrops, (tx) {
      for (final c in plan.commands) {
        tx.add(c);
      }
    });
  },
  onCreateLocation: (name) {
    controller.run(
      AddLocationCommand(
        name: name,
        code: initialsFor(name),
        order: nextLocationOrder(controller.doc),
        now: controller.clock.nowUtc(),
        actor: controller.actor,
      ),
    );
  },
  onCreateStructure: () {
    // The Structure device a drop's outlet hangs on. Created with the
    // corpus's own default designator rather than asking: a project that
    // has none has exactly one sensible first one, and naming it is an
    // edit the user can make afterwards in the inspector.
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
