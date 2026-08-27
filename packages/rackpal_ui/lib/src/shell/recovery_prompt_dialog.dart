// The startup recovery prompt (docs/03-architecture.md §9.4).
//
// §9.4 fixes the copy and the three choices verbatim: "RackPal closed
// unexpectedly. Recover Smith Residence (12 unsaved changes)?" with
// Recover / Discard / Keep for later.
//
// WHY `KEEP FOR LATER` IS NOT A POLITE `DISCARD`. It leaves both files on
// disk untouched, and the snapshot WILL be offered again next launch.
// That is intentional: the data is still at risk, and silently forgetting
// unsaved work because the user was busy the first time is the failure
// this whole feature exists to prevent. One more prompt is the cheaper
// mistake.
//
// WHY `DISCARD` CONFIRMS. It is the only irreversible button in the
// dialog, and it is one click from a keyboard user who is dismissing a
// surprise prompt at launch. The confirm step states the count, so the
// number the user is throwing away is on screen at the moment they throw
// it away.
//
// THE COUNT IS NULLABLE, AND THAT IS LOAD-BEARING (G4). After a crash
// there is no undo stack left to consult, so the count comes from the
// sidecar the snapshot was written with. A sidecar that predates the
// field — or that could not record one — yields null, and the prompt then
// says "unsaved changes" with no number rather than inventing one.
import 'package:flutter/material.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart';

/// What the user chose at the recovery prompt.
enum RecoveryChoice {
  /// Load the snapshot as the current document, dirty, unsaved.
  recover,

  /// Delete the snapshot and its sidecar. Confirmed first.
  discard,

  /// Leave both on disk. Offered again next launch, on purpose.
  keepForLater,
}

/// Recover / Discard / Keep for later.
final class RecoveryPromptDialog extends StatelessWidget {
  const RecoveryPromptDialog({
    required this.documentName,
    required this.savedAt,
    this.unsavedEditCount,
    super.key,
  });

  /// What the snapshot's sidecar called the document.
  final String documentName;

  /// When the snapshot was taken, in LOCAL time — the user reads a clock,
  /// not a UTC instant.
  final DateTime savedAt;

  /// How many edits stood between the snapshot and the last save, or null
  /// when the sidecar did not record one. Null OMITS the count.
  final int? unsavedEditCount;

  /// §9.4's sentence, built so a test can assert the G4 omission without
  /// depending on layout.
  static String promptText(String documentName, int? unsavedEditCount) {
    final suffix = switch (unsavedEditCount) {
      null => '',
      1 => ' (1 unsaved change)',
      final int n => ' ($n unsaved changes)',
    };
    return 'RackPal closed unexpectedly. '
        'Recover $documentName$suffix?';
  }

  /// The Discard confirmation's body. Same nullable-count rule.
  static String discardConfirmText(int? unsavedEditCount) {
    final lost = switch (unsavedEditCount) {
      null => 'The unsaved changes',
      1 => '1 change',
      final int n => '$n changes',
    };
    return 'This cannot be undone. $lost will be lost.';
  }

  static String _clock(DateTime at) {
    final local = at.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      // Esc is "not now", never "throw it away" — the conservative answer,
      // which is what `KeyBindingId.dialogDismiss` means in all three
      // dialogs even though all three pop a different VALUE. The key comes
      // from the registry; the answer stays here, because only this dialog
      // knows which of its outcomes cannot lose work.
      bindings: dialogDismissShortcut(
        () => Navigator.of(context).pop(RecoveryChoice.keepForLater),
      ),
      child: AlertDialog(
        title: const Text('Unsaved work was found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(promptText(documentName, unsavedEditCount)),
            const SizedBox(height: 12),
            Text(
              'Snapshot taken at ${_clock(savedAt)}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(RecoveryChoice.recover),
            child: const Text('Recover'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(RecoveryChoice.keepForLater),
            child: const Text('Keep for later'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final confirmed = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: Text('Discard the recovered $documentName?'),
                  content: Text(discardConfirmText(unsavedEditCount)),
                  actions: [
                    // The SAFE action is the default here, inverting the
                    // outer dialog's arrangement: this dialog's job is to
                    // make the destructive answer cost something.
                    FilledButton(
                      autofocus: true,
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Keep it'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Discard'),
                    ),
                  ],
                ),
              );
              if (confirmed ?? false) {
                navigator.pop(RecoveryChoice.discard);
              }
              // An unconfirmed discard returns to THIS dialog rather than
              // closing it — the user has not yet answered the question
              // that was asked.
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}

/// Shows [RecoveryPromptDialog] and resolves with the user's choice.
///
/// Anything other than an explicit button resolves to
/// [RecoveryChoice.keepForLater] — the only answer that cannot lose data.
Future<RecoveryChoice> showRecoveryPromptDialog(
  BuildContext context, {
  required String documentName,
  required DateTime savedAt,
  int? unsavedEditCount,
}) async {
  final choice = await showDialog<RecoveryChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => RecoveryPromptDialog(
      documentName: documentName,
      savedAt: savedAt,
      unsavedEditCount: unsavedEditCount,
    ),
  );
  return choice ?? RecoveryChoice.keepForLater;
}
