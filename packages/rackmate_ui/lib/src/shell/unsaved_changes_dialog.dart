// The close-while-dirty prompt (docs/03-architecture.md §9.5).
//
// ==================================================================
// THREE BUTTONS. NEVER TWO.
// ==================================================================
// §9.5 says "a THREE-BUTTON dialog on close-while-dirty: Save / Don't
// Save / Cancel. Never two buttons." The two-button version ("Save" /
// "Discard") is the one every rushed implementation ships, and it is
// wrong for a specific reason rather than a stylistic one: the user who
// hit Alt+F4 by accident has no way to say "I did not mean to close
// this at all". Collapsing Cancel into the window's X — or into the Esc
// key alone — makes the safest answer the least discoverable one.
//
// FOUR RULES THE LAYOUT ENCODES, each testable and each tested with real
// key events and real taps rather than by calling a callback:
//
//   * `Save` is the default action and holds initial focus. Enter saves.
//   * `Esc` is Cancel. It is the standard "I did not mean this" key and
//     it must never reach the destructive action.
//   * NOTHING on the keyboard lands on `Don't Save`. It is reachable by
//     Tab and by pointer, deliberately, and by no accelerator: an
//     irreversible discard must cost a deliberate act.
//   * `barrierDismissible: false`. Clicking outside a dialog is not a
//     decision, and treating it as one silently picks a branch the user
//     never chose.
//
// PRESENTATIONAL ONLY. This widget takes a name and a nullable count and
// returns an enum. It does not know what a file is, cannot save
// anything, and imports nothing from the app layer — which is what keeps
// `rackmate_ui` free of the native file dialog, `window_manager` and
// `dart:io`.
import 'package:flutter/material.dart';
import 'package:rackmate_ui/src/keymap/keymap.dart';

/// What the user chose at the close-while-dirty prompt.
enum UnsavedChangesChoice {
  /// Write the document, then continue with whatever asked.
  save,

  /// Throw the unsaved edits away and continue.
  dontSave,

  /// Do nothing at all. The window stays open; the document stays dirty.
  cancel,
}

/// The three-button Save / Don't Save / Cancel dialog.
final class UnsavedChangesDialog extends StatelessWidget {
  const UnsavedChangesDialog({
    required this.documentName,
    this.editCount,
    super.key,
  });

  /// What the document is called — the same string the window title and
  /// the recents entry use, so the three can never disagree.
  final String documentName;

  /// How many edits would be lost. NULL means UNKNOWN, and the body then
  /// OMITS the count entirely rather than substituting a plausible number
  /// (G4). "12 changes will be lost" that is actually 13 is worse than a
  /// sentence with no number in it.
  final int? editCount;

  /// The body sentence, exposed so a test can assert the G4 omission
  /// without depending on how the dialog lays text out.
  static String bodyText(int? editCount) => switch (editCount) {
    null => 'If you don’t save, your unsaved changes will be lost.',
    1 => 'If you don’t save, 1 change will be lost.',
    final int n => 'If you don’t save, $n changes will be lost.',
  };

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      // "Esc is Cancel, EVERYWHERE, ALWAYS" is what this comment said, in
      // three dialogs, three times. It is one declaration now
      // (`KeyBindingId.dialogDismiss`), so the sentence is enforced rather
      // than repeated — and the row is in the generated table, where
      // arbitration can check that `Esc` means the same thing here as it
      // does on both canvases (canon §1.10 principle (b)).
      //
      // STILL BOUND EXPLICITLY rather than left to the route's own pop,
      // and that half is unchanged: a bare pop returns null, a null here
      // would have to be interpreted, and the only safe interpretation IS
      // cancel — so it is said out loud.
      bindings: dialogDismissShortcut(
        () => Navigator.of(context).pop(UnsavedChangesChoice.cancel),
      ),
      child: AlertDialog(
        title: Text('Save changes to $documentName?'),
        content: Text(bodyText(editCount)),
        // WINDOWS BUTTON ORDER: affirmative, then the alternative, then
        // cancel, left to right. `actions` renders in order.
        actions: [
          // FIRST in the list and autofocused: Enter commits the safe
          // action. `FilledButton` marks it as the default visually as
          // well as behaviourally, so the two agree.
          FilledButton(
            autofocus: true,
            onPressed: () =>
                Navigator.of(context).pop(UnsavedChangesChoice.save),
            child: const Text('Save'),
          ),
          // NO autofocus, NO accelerator, and deliberately not styled as
          // the primary action. The only ways here are a pointer and an
          // explicit Tab.
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(UnsavedChangesChoice.dontSave),
            child: const Text('Don’t Save'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(UnsavedChangesChoice.cancel),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Shows [UnsavedChangesDialog] and resolves with the user's choice.
///
/// Resolves to [UnsavedChangesChoice.cancel] when the route is popped by
/// anything other than a button — the conservative reading, and the only
/// one that cannot lose work.
Future<UnsavedChangesChoice> showUnsavedChangesDialog(
  BuildContext context, {
  required String documentName,
  int? editCount,
}) async {
  final choice = await showDialog<UnsavedChangesChoice>(
    context: context,
    // Clicking outside is not a decision.
    barrierDismissible: false,
    builder: (context) => UnsavedChangesDialog(
      documentName: documentName,
      editCount: editCount,
    ),
  );
  return choice ?? UnsavedChangesChoice.cancel;
}
