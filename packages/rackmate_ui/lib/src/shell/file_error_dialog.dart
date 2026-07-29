// The one dialog every storage failure reaches the user through.
//
// IT NEVER SEES A `SaveError` OR AN `OpenError`. It renders a
// [FileErrorView] — a title, a detail paragraph and a list of labelled
// actions — and returns the id of whichever action was pressed. That is
// what keeps `rackmate_ui` ignorant of files: the app layer owns the
// sealed error hierarchies, does the exhaustive switch that guarantees no
// failure ships without copy, and hands this widget a value object.
//
// WHY A LIST OF ACTIONS RATHER THAN FIXED BUTTONS. The ten named failure
// conditions do not share a button set. A disconnected network drive
// offers [Save As…] [Try again] [Cancel]; a newer-schema refusal offers
// [OK] and deliberately NO "open anyway"; a corrupt file with a sibling
// backup offers [Open the backup] [Cancel] and without one offers only
// [Cancel]. Fixed buttons would force either a lowest-common-denominator
// dialog or ten near-identical widgets.
//
// THE PATH IS SHOWN IN FULL, ON PURPOSE. §12.4 forbids a file path in a
// LOG; this is the user's own screen, and "could not save to
// \\NAS\jobs\Smith.rackmate" is the sentence that tells them which of
// their three network shares is down. The two surfaces have different
// rules and the difference is deliberate.
import 'package:flutter/material.dart';
import 'package:rackmate_ui/src/keymap/keymap.dart';

/// One button on a [FileErrorDialog].
@immutable
final class FileErrorAction {
  const FileErrorAction({
    required this.id,
    required this.label,
    this.isPrimary = false,
  });

  /// Returned by [showFileErrorDialog] when this button is pressed. A
  /// STABLE identifier rather than the label, so copy can be reworded
  /// without silently rerouting the caller's switch.
  final String id;

  final String label;

  /// Rendered as the filled default and given initial focus. At most one
  /// action should set it; the app-layer presenter is where that is
  /// decided, because which action is safe depends on the failure.
  final bool isPrimary;

  @override
  bool operator ==(Object other) =>
      other is FileErrorAction &&
      other.id == id &&
      other.label == label &&
      other.isPrimary == isPrimary;

  @override
  int get hashCode => Object.hash(id, label, isPrimary);

  @override
  String toString() => 'FileErrorAction($id)';
}

/// Everything a storage failure needs to say, with the error type already
/// resolved away.
@immutable
final class FileErrorView {
  const FileErrorView({
    required this.title,
    required this.detail,
    required this.actions,
    this.reassurance,
  });

  /// One sentence naming what did not happen.
  final String title;

  /// Why, in plain language, with the path when the path is the point.
  final String detail;

  /// The line that tells the user their work is not gone. Present on
  /// every FAILED SAVE, because that is the question the user actually
  /// has and the one a raw errno never answers.
  final String? reassurance;

  /// At least one. A dialog with no way out is not a dialog.
  final List<FileErrorAction> actions;

  /// The id of the action that a dismissal (Esc, or a pop from anywhere
  /// else) is equivalent to — the LAST action, which is by construction
  /// the least destructive one in every view this app builds.
  String get dismissActionId => actions.last.id;

  @override
  bool operator ==(Object other) =>
      other is FileErrorView &&
      other.title == title &&
      other.detail == detail &&
      other.reassurance == reassurance &&
      _sameActions(other.actions, actions);

  static bool _sameActions(List<FileErrorAction> a, List<FileErrorAction> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(title, detail, reassurance, Object.hashAll(actions));

  @override
  String toString() => 'FileErrorView($title)';
}

/// Renders a [FileErrorView].
final class FileErrorDialog extends StatelessWidget {
  const FileErrorDialog({required this.view, super.key});

  final FileErrorView view;

  @override
  Widget build(BuildContext context) {
    final reassurance = view.reassurance;
    return CallbackShortcuts(
      // Esc dismisses, and the VIEW says what dismissing means — an error
      // with a `Retry` and a `Cancel` must not have `Esc` retry. The key
      // itself is `KeyBindingId.dialogDismiss`, shared with the other two
      // dialogs so all three are one row in the generated table.
      bindings: dialogDismissShortcut(
        () => Navigator.of(context).pop(view.dismissActionId),
      ),
      child: AlertDialog(
        title: Text(view.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(view.detail),
            if (reassurance != null) ...[
              const SizedBox(height: 12),
              Text(
                reassurance,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
        actions: [
          for (final action in view.actions)
            if (action.isPrimary)
              FilledButton(
                autofocus: true,
                onPressed: () => Navigator.of(context).pop(action.id),
                child: Text(action.label),
              )
            else
              TextButton(
                onPressed: () => Navigator.of(context).pop(action.id),
                child: Text(action.label),
              ),
        ],
      ),
    );
  }
}

/// Shows [FileErrorDialog] and resolves with the pressed action's id.
///
/// A dismissal resolves to [FileErrorView.dismissActionId] rather than
/// null, so the caller's switch stays exhaustive and "the user closed the
/// dialog" cannot fall through to doing nothing unreported.
Future<String> showFileErrorDialog(
  BuildContext context,
  FileErrorView view,
) async {
  final pressed = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => FileErrorDialog(view: view),
  );
  return pressed ?? view.dismissActionId;
}
