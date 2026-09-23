// docs/05 §10's *"a single Tidy sheet behind a plain confirm lays out all
// unpinned symbols"* (CR-068, DR-187 §11.186.3).
//
// ═══════════════════════════════════════════════════════════════════════
// A CONFIRM HERE AND NOT ON THE PAGE PICKER, WHICH IS NOT INCONSISTENCY
// ═══════════════════════════════════════════════════════════════════════
// `pdf_page_picker_dialog.dart` one folder over argues the opposite case
// and is right to: importing the wrong page is one `Ctrl+Z` away and a
// prompt whose consequence is one undo is the nag that teaches people to
// click through prompts.
//
// **THIS ONE IS DIFFERENT IN THE THING IT DESTROYS.** An undo brings the
// arrangement back, but the arrangement is work nobody can see all of:
// twenty symbols moved by hand over an afternoon look exactly like twenty
// symbols the layout happened to place, and a person who presses this by
// accident cannot tell from the screen whether they have lost anything.
// That is the same test `delete_device_dialog.dart` applies to a delete
// that drops rows off the schedule, and it is why docs/05 asks for the
// confirm in terms.
//
// ═══════════════════════════════════════════════════════════════════════
// THE COUNT IS NOT COMPUTED HERE
// ═══════════════════════════════════════════════════════════════════════
// It arrives from `TidySheetCommand.wouldReflow`, the same predicate
// `apply` filters on. A dialog that said "12 symbols" and moved 13 would
// be worse than no dialog, and the only way to guarantee it cannot is for
// the sentence and the edit to read one answer.

import 'package:flutter/material.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// Asks before handing [count] symbols back to the layout. True to go.
Future<bool> confirmTidySheet(
  BuildContext context, {
  required int count,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => TidySheetDialog(count: count),
  );
  return answer ?? false;
}

/// The confirm itself. Public so a widget test can pump it without a route.
class TidySheetDialog extends StatelessWidget {
  const TidySheetDialog({required this.count, super.key});

  /// How many symbols the layout will move, from `wouldReflow`.
  final int count;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    // Through the keymap registry rather than a literal `Esc`, so the row
    // is in the generated table and arbitration can see it (CR-101).
    bindings: dialogDismissShortcut(() => Navigator.of(context).pop(false)),
    child: AlertDialog(
      title: Text(
        count == 1 ? 'Tidy 1 symbol?' : 'Tidy $count symbols?',
      ),
      content: Text(
        // WHAT IS SPARED IS STATED, because that is the sentence a person
        // needs to decide. "This cannot be undone" would be a lie, and
        // "are you sure?" tells them nothing they did not already know.
        count == 1
            ? 'The layout will place 1 unpinned symbol again. Pinned symbols '
                  'stay where they are.'
            : 'The layout will place $count unpinned symbols again. Pinned '
                  'symbols stay where they are.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Tidy sheet'),
        ),
      ],
    ),
  );
}
