// The two persistent strips the shell can show above the document, and
// one status line below it.
//
// ==================================================================
// READ-ONLY (docs/03-architecture.md §9.2, case 3 of the error surface)
// ==================================================================
// A file whose `schemaVersion` is newer than this build's but whose
// `minReaderVersion` this build still satisfies opens `openReadOnly:
// true`. THAT IS NOT AN ERROR and must not arrive as one. The document is
// fully editable in memory, still autosaves to a recovery snapshot, and
// still exports; the user is blocked from OVERWRITING a file this build
// does not fully understand, and from nothing else. So this is a
// persistent, non-dismissible banner with a way forward — `Save a copy…`
// — rather than a modal that has to be clicked away before work starts.
//
// It is NOT dismissible on purpose: the fact it states changes what
// Ctrl+S does, and a dismissed banner would leave that difference
// unexplained the next time the user pressed it.
//
// ==================================================================
// DEGRADED PERSISTENCE (case 10, and the portable-root-unwritable case)
// ==================================================================
// When the app cannot write to its own data folder — a locked-down
// corporate profile, or a read-only USB stick in portable mode — autosave
// and recents are off for the session. The user did not ask for anything
// and cannot fix it mid-task, so this is NEVER modal. But it is also
// never silence: "never silently do nothing" applies hardest to the
// feature whose entire job is protecting work the user has not saved yet.
// Dismissible, because the user has read it and cannot act on it.
import 'package:flutter/material.dart';
import 'package:rackpal_ui/src/shell/export_notices_dialog.dart';

/// The newer-schema read-only banner. Non-dismissible; see the header.
final class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({required this.onSaveCopy, super.key});

  /// Opens Save As with a `<name> (copy).rppj` suggestion.
  final VoidCallback onSaveCopy;

  /// The banner's sentence, exposed so a test can assert the copy without
  /// depending on layout.
  ///
  /// ==================================================================
  /// THIS SENTENCE USED TO PROMISE SOMETHING THE CODEC DOES NOT DO
  /// ==================================================================
  /// It read: "It is open read-only so nothing in it is lost. Save a copy
  /// to keep your changes." Together those tell the user that the copy
  /// carries the newer build's data forward. It does not. The only
  /// forward-compatibility passthrough in the codec is a literal
  /// `unknown` sub-object at four places — the document root, EntityMeta,
  /// Port and SheetItem — and every entity decoder reads the keys it knows
  /// by name and DISCARDS THE REST. A user who opens a v3 file, works in
  /// it, and follows this banner's own `Save a copy…` affordance gets a
  /// copy with the newer build's data permanently removed, having been
  /// told nothing was lost. CR-093's "unknown fields preserved for a
  /// subsequent Save As" is not implemented.
  ///
  /// So the copy now states the two things that ARE true and are the two
  /// the user needs: the file they opened is left alone, and a copy
  /// contains what this build understood. A false reassurance about data
  /// loss is worse than no message — it is precisely the reassurance that
  /// stops someone going to find the newer RackPal.
  ///
  /// If preservation is implemented later this string changes back in the
  /// same commit. `file_error_dialog_test.dart` asserts the banner renders
  /// whatever is here, and `session_controller_test.dart` asserts the
  /// claim against the BYTES a Save As actually writes — so the sentence
  /// and the behaviour cannot drift apart again unnoticed.
  static const String message =
      'This file was saved by a newer version of RackPal. It is open '
      'read-only, so the file on disk is left exactly as it is. Saving a '
      'copy keeps your changes, but the copy will only contain the parts '
      'this version understands — update RackPal to keep all of it.';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline,
              size: 18,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: onSaveCopy,
              child: const Text('Save a copy…'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dismissible warning strip for a degraded persistence session.
final class ShellWarningBanner extends StatelessWidget {
  const ShellWarningBanner({
    required this.message,
    required this.onDismiss,
    super.key,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              size: 18,
              color: scheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

/// A button the status line carries after its message: `Open`, `Show in
/// folder` after an export (CR-100, docs/08 §8.3's completion strip as
/// one line, M6-I4).
///
/// A RECORD, NOT A CLASS, so the session that sets it needs no import of
/// this package: the app's `DocumentSession` is a model and names the same
/// shape structurally.
typedef StatusAction = ({String label, VoidCallback onPressed});

/// The shell's one-line status readout.
///
/// Carries the outcomes that are REPORTED but are not failures: "Saved."
/// / "Saved. The backup copy could not be updated." / "Recovered from
/// 14:32. Not yet written to Smith.rppj." A save that worked must not
/// raise a dialog, and a save whose backup did not must not be silent —
/// this line is where the difference lives.
final class ShellStatusLine extends StatelessWidget {
  const ShellStatusLine({
    required this.message,
    this.notices = const <String>[],
    this.noticeLabel,
    this.actions = const <StatusAction>[],
    super.key,
  });

  /// Buttons after the message, in order. Empty for every status that is
  /// not an export's.
  final List<StatusAction> actions;

  final String message;

  /// The notices [message] counts (DR-224). When it is not empty and
  /// [message] ends with [noticeLabel], that count is a link to them.
  final List<String> notices;

  /// The count's own words, `6 notices`, which [message] ends with.
  final String? noticeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    final label = noticeLabel;
    // THE COUNT BECOMES THE LINK ONLY WHERE THE LINE PRINTS IT, so the
    // words a person clicks are the words they read. A message that does
    // not end with the count keeps no link rather than a misplaced one.
    final linked =
        notices.isNotEmpty && label != null && message.endsWith(label);
    final buttonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      minimumSize: const Size(0, 20),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: style?.copyWith(decoration: TextDecoration.underline),
    );
    final line = linked
        ? Row(
            children: [
              Flexible(
                child: Text(
                  message.substring(0, message.length - label.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: style?.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
                onPressed: () => showExportNoticesDialog(context, notices),
                child: Text(label),
              ),
            ],
          )
        : Text(
            message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: actions.isEmpty
                ? line
                : Row(
                    children: [
                      Flexible(child: line),
                      for (final a in actions) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          style: buttonStyle,
                          onPressed: a.onPressed,
                          child: Text(a.label),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
