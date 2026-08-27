// The three questions the session layer has to ask a human, behind an
// interface.
//
// WHY AN INTERFACE RATHER THAN A `BuildContext`. `SessionController` runs
// the close sequence, the open sequence and the save sequence, and each
// of those is a state machine with branches that matter — a failed save
// must NOT close the window; a cancelled Save As must NOT count as a
// discard; an evicted recents entry must NOT happen for an unreachable
// share. Testing those branches by pumping widgets and tapping buttons
// would test the dialogs forty times over and the branches once each.
//
// So: the controller is tested against a SCRIPTED prompt that answers
// with a fixed sequence, and the DIALOGS are tested separately with real
// `tester.tap` and real `sendKeyEvent`. The shell wires the real one, so
// the production path uses the same dialogs the widget tests drive.
import 'package:rackpal_ui/rackpal_ui.dart';

/// Asks the user the three questions this layer has.
abstract interface class SessionPrompts {
  /// The three-button close-while-dirty prompt. NEVER two buttons.
  Future<UnsavedChangesChoice> confirmDiscard({
    required String documentName,
    int? editCount,
  });

  /// A storage failure. Returns the id of the action pressed; a dismissal
  /// returns the view's own last action, so no branch can fall through to
  /// silence.
  Future<String> showFileError(FileErrorView view);

  /// The startup recovery prompt.
  Future<RecoveryChoice> confirmRecovery({
    required String documentName,
    required DateTime savedAt,
    int? unsavedEditCount,
  });
}
