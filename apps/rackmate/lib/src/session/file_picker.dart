// The native open/save dialog seam.
//
// TWO METHODS, BOTH RETURNING A NULLABLE PATH. That is the entire surface
// the app needs from a file dialog, and keeping it that small is what
// makes every open / save / Save-As flow widget-testable end to end with
// no native dialog and no real window: a test supplies a `FakeFilePicker`
// that answers with a literal path or with null for "the user cancelled".
//
// THE DIALOG IS REACHED FROM THIS FILE AND NOWHERE ELSE, and
// `test/session/session_layering_test.dart` asserts it — the same
// mechanism that keeps the app-support lookup to one call site. A second
// call site would be a second dialog configuration to keep in sync, and
// the accepted type group is exactly the kind of thing that drifts.
//
// ==================================================================
// WHY THIS IS A FIRST-PARTY WIN32 DIALOG AND NOT `file_selector`
// ==================================================================
// THE FINDING, restated because it is the whole reason this file changed:
// the portable build runs from a USB stick and writes only into
// `RackMateData` beside the executable, and RackMate's own code writes no
// registry key at all. Every store honours that. The file dialog did not,
// because the writer there is the Windows shell.
//
// Windows' `IFileDialog` records what was opened under
//
//     HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32
//
// — the chosen file's name and full path land in `OpenSavePidlMRU` —
// plus a shortcut under `%APPDATA%\Microsoft\Windows\Recent` and a
// jump-list entry. So running the portable build on a client's PC and
// opening `E:\Jobs\Smith Residence.rackmate` once seeded that PC's
// recent-documents list with the customer's project name.
//
// AND IT COULD NOT BE FIXED THROUGH THE PACKAGE, read off the resolved
// source rather than remembered. `file_selector_windows-0.9.3+5`,
// `windows/file_selector_plugin.cpp`, `ShowDialog`:
//
//     FILEOPENDIALOGOPTIONS dialog_options = 0;
//     if (options.select_folders())  dialog_options |= FOS_PICKFOLDERS;
//     if (options.allow_multiple())  dialog_options |= FOS_ALLOWMULTISELECT;
//     if (dialog_options != 0)       dialog.AddOptions(dialog_options);
//
// `SelectionOptions` — the Pigeon-generated message that is the ONLY
// channel from Dart into that code — carries `allowMultiple`,
// `selectFolders` and `allowedTypes` and nothing else. There is no
// argument, no configuration and no subclass that reaches the flag from
// Dart at any price.
//
// The previous pass's disposition was to DOCUMENT the leak and pin the
// plugin version as a tripwire. That left the behaviour unchanged and the
// deliverable's claim false, so this pass took the option docs/03 §10.1
// already contemplates for exactly this situation — it says of
// `window_manager` that "the only load-bearing API is setPreventClose +
// the close event: ~80 lines of Win32 platform channel". The same trade,
// with a harder deliverable behind it: `windows/runner/file_dialog_channel.cpp`
// drives `IFileDialog` directly, sets the flag, and is ~150 lines of C++
// compiled against the real Windows SDK headers.
//
// WHAT WENT AWAY WITH IT: the `file_selector` dependency, and with it
// `file_selector_android`, which was pulling the `jni` FFI plugin and
// shipping `dartjni.dll` into a Windows-only Release build.
//
// ==================================================================
// WHAT THE SHIPPED BINARY LEAVES ON THE HOST — A BOUND, NOT A LIST
// ==================================================================
// WHY THE SHAPE OF THIS PARAGRAPH CHANGED, WHICH IS THE WHOLE LESSON.
// A claim about this has been wrong FOUR times, and every time in the same
// form: a pass measured some of the ComDlg32 subkeys, wrote down the ones
// it had seen, closed the list — and the next measurement found another
// one. First the leak was merely documented while the deliverable promised
// there was none. Then `FOS_DONTADDTORECENT` was added and mistaken for a
// complete fix, while `LastVisitedPidlMRU` was still being written. Then
// the wording was narrowed to that one key, while `CIDSizeMRU` was also
// being written — on EVERY dialog, including one the user only cancels,
// which is the case the wording had explicitly ruled out. Then the gate
// built to stop the recurrence reasoned only about the key that had been
// named, so the closed half of the sentence was ungated.
//
// AN ENUMERATED CLAIM IS FRAGILE BY CONSTRUCTION. The shell owns that
// list, it varies with the Windows build, and "add the key we just found"
// is guaranteed to be wrong again. So the claim below is a BOUND: it has
// to stay true WITHOUT knowing the complete list, because we have been
// wrong about the complete list three times.
//
// THE MEASUREMENT behind it. `flutter build windows`, then
// `Release\rackmate.exe` driven through File ▸ Open with synthetic input,
// with the ComDlg32 subkeys snapshotted either side of it; and separately
// a C++ harness replicating this dialog's exact configuration, cancelled,
// with all four subkeys diffed either side.
//
// OURS, AND GATED. RackMate's own code writes no registry key: no `Reg*`
// call, no registry package, nothing under HKCU or HKLM from any line we
// ship. Every store writes into the data root and nowhere else. That is a
// property of source we control, so `registry_claim_test.dart` derives it
// from the source instead of trusting this sentence.
//
// THE HALF WE CONTROL, and it is a real win:
//   * nothing is added under `OpenSavePidlMRU` — no `rackmate` subkey
//     appears there, so no opened or saved project's FILE NAME reaches the
//     host at all;
//   * no `.lnk` appears in `%APPDATA%\Microsoft\Windows\Recent`;
//   * no jump-list entry is made.
//
// THE HALF WE DO NOT. The shell writes values under ComDlg32 that
// RackMate does not control — at minimum `LastVisitedPidlMRU`, holding
// UTF-16 `rackmate.exe` followed by a PIDL naming the FOLDER that was
// browsed, and `CIDSizeMRU`, holding `rackmate.exe` and the dialog's
// persisted size and written even when the user opens the dialog and
// presses Escape. Both are measured; both are EXAMPLES, and this is not
// an inventory. The evidence that the folder record is real and not a
// snapshot artefact: a SECOND, freshly launched process opened its dialog
// already positioned in that folder, with no `prefs.json` on disk to have
// supplied it. `FOS_DONTADDTORECENT` is documented against
// `SHAddToRecentDocs`, the recent-DOCUMENTS list; it governs none of
// these, and no other `FILEOPENDIALOGOPTIONS` bit does either.
//
// THE DISPOSITION, so it is not silently re-opened: eliminating them would
// mean abandoning `IFileDialog` for a hand-built file browser — a large
// scope and a worse dialog for an internal tool — so the shell dialog
// stays and the claim is bounded rather than closed.
//
// SO, PLAINLY: running the portable build on a client's machine leaves
// shell-owned HKCU entries naming this executable and the folders it
// browsed — `E:\Jobs`, and not `E:\Jobs\Smith Residence.rackmate` — and
// they survive the stick being pulled. It does not leave project FILE
// NAMES, and it does not leave anything RackMate's own code wrote.
//
// WHAT HOLDS THIS IN PLACE:
//   * `file_dialog_flags_test.dart` asserts `FOS_DONTADDTORECENT` is set
//     in the one place the dialogs are configured, that both dialogs go
//     through it, and that `SetOptions` OR-s rather than replaces.
//   * `registry_claim_test.dart` gates the three things this claim is
//     made of, each against something the project actually controls: that
//     our own source contains no registry write, that the flag is still
//     set, and that no file anywhere has closed the list again. It does
//     NOT hold a list of shell key names, because that would be the same
//     fragility one level up.
//   * `flutter build windows` compiles the C++ against the SDK's own
//     `shobjidl.h`, so the interface, the CLSIDs and every call signature
//     are checked by the compiler rather than by hand-written vtable
//     offsets.
import 'package:flutter/services.dart';
import 'package:rackmate/src/storage/save_paths.dart';

/// The platform channel `windows/runner/file_dialog_channel.cpp` serves.
///
/// NAMED HERE AND NOWHERE ELSE on the Dart side; the C++ end names it once
/// too, and `session_layering_test.dart` RULE 7 asserts the Dart half.
const MethodChannel kFileDialogChannel = MethodChannel(
  'rackmate/file_dialog',
);

/// Native open and save dialogs, behind two methods.
abstract interface class FilePicker {
  /// Asks the user which document to open. Null means cancelled.
  Future<String?> pickOpen({String? initialDirectory});

  /// Asks the user where to save. Null means cancelled.
  ///
  /// The returned path may have NO EXTENSION — the Windows dialog hands
  /// back `Smith` when the user types `Smith` under the "All files"
  /// filter. Normalising that is `SavePaths.forTarget`'s job, in exactly
  /// one place.
  Future<String?> pickSave({String? suggestedName, String? initialDirectory});
}

/// The production picker: RackMate's own `IFileDialog`.
final class Win32FilePicker implements FilePicker {
  const Win32FilePicker({this.channel = kFileDialogChannel});

  /// Injected only so a test can point the picker at a channel it has
  /// installed a mock handler on; production always takes the default.
  final MethodChannel channel;

  @override
  Future<String?> pickOpen({String? initialDirectory}) => _invoke('open', {
    'initialDirectory': initialDirectory,
    'confirmButtonText': 'Open',
  });

  @override
  Future<String?> pickSave({
    String? suggestedName,
    String? initialDirectory,
  }) => _invoke('save', {
    'initialDirectory': initialDirectory,
    // The dialog shows this in the file-name field. It carries the
    // extension so the common path — the user presses Save without
    // editing — already produces a well-named file, and
    // `SavePaths.forTarget` catches the case where they delete it.
    'suggestedName': suggestedName,
    'confirmButtonText': 'Save',
  });

  /// A CANCEL AND A FAILURE ARE BOTH `null`, AND THAT IS NOT A SHRUG.
  ///
  /// The native side reports a cancel as a successful `null` and reserves
  /// `PlatformException` for a shell that could not create or show the
  /// dialog at all — a state in which there is no dialog for the user to
  /// answer and therefore nothing this seam can return but "no path". The
  /// caller treats a null as "the user cancelled", which is the only
  /// non-destructive reading: nothing is opened, nothing is overwritten,
  /// and the document on screen is untouched.
  ///
  /// It is not silent. `PlatformException` carries a message, and this
  /// method deliberately does NOT swallow it into a bare `catch` — it is
  /// rethrown into §12.1's programmer-error channel, which `main()`
  /// installs, because a Windows shell that cannot open a file dialog is
  /// our problem to hear about and not the user's to guess at.
  Future<String?> _invoke(String method, Map<String, String?> arguments) async {
    return channel.invokeMethod<String>(method, arguments);
  }
}

/// The `.rackmate` filter both dialogs offer, as the native side spells
/// it. Declared here so a reader of this file can see what the dialog
/// shows without opening the C++.
const String kRackMateFilterLabel = 'RackMate project';

/// The default suggested name for a document that has never been saved.
String defaultSaveName(String displayName) =>
    '$displayName$kDocumentExtension';
