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
// `RackPalData` beside the executable, and RackPal's own code writes no
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
// opening `E:\Jobs\Smith Residence.rppj` once seeded that PC's
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
// `Release\rackpal.exe` driven through File ▸ Open with synthetic input,
// with the ComDlg32 subkeys snapshotted either side of it; and separately
// a C++ harness replicating this dialog's exact configuration, cancelled,
// with all four subkeys diffed either side.
//
// OURS, AND GATED. RackPal's own code writes no registry key: no `Reg*`
// call, no registry package, nothing under HKCU or HKLM from any line we
// ship. Every store writes into the data root and nowhere else. That is a
// property of source we control, so `registry_claim_test.dart` derives it
// from the source instead of trusting this sentence.
//
// THE HALF WE CONTROL, and it is a real win:
//   * nothing is added under `OpenSavePidlMRU` — no `rackpal` subkey
//     appears there, so no opened or saved project's FILE NAME reaches the
//     host at all;
//   * no `.lnk` appears in `%APPDATA%\Microsoft\Windows\Recent`;
//   * no jump-list entry is made.
//
// THE HALF WE DO NOT. The shell writes values under ComDlg32 that
// RackPal does not control — at minimum `LastVisitedPidlMRU`, holding
// UTF-16 `rackpal.exe` followed by a PIDL naming the FOLDER that was
// browsed, and `CIDSizeMRU`, holding `rackpal.exe` and the dialog's
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
// browsed — `E:\Jobs`, and not `E:\Jobs\Smith Residence.rppj` — and
// they survive the stick being pulled. It does not leave project FILE
// NAMES, and it does not leave anything RackPal's own code wrote.
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
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal_ui/rackpal_ui.dart'
    show WebPageLauncher, isOpenableWebUrl;

/// The platform channel `windows/runner/file_dialog_channel.cpp` serves.
///
/// NAMED HERE AND NOWHERE ELSE on the Dart side; the C++ end names it once
/// too, and `session_layering_test.dart` RULE 7 asserts the Dart half.
const MethodChannel kFileDialogChannel = MethodChannel(
  'rackpal/file_dialog',
);

/// Which files a dialog should offer, as a KIND rather than a filter
/// string (docs/13 D13, board M3-F/4).
///
/// **THE WIRE VALUE IS THE ENUM NAME**, and the native side switches on
/// it. Dart never sends a `COMDLG_FILTERSPEC`, and that is the decision
/// D13 asks to get right BEFORE D2: a Win32 filter pattern does not
/// port, because `NSOpenPanel` wants `UTType`s or bare extensions and
/// would have to parse the pattern back apart. A kind maps onto both, so
/// the macOS runner implements the same two words rather than a Windows
/// contract in disguise.
///
/// Adding a value means adding a ROW to `kFileKinds` in
/// `windows/runner/file_dialog_channel.cpp`; an unrecognised kind falls
/// back to [project] there rather than showing the user nothing.
enum FileDialogType {
  /// `.rppj`, `.rmpj` and `.rackmate` in one entry (DR-015, DR-179).
  project,

  /// `.csv`, for M3-F's import.
  csv,

  /// `.rpdx` and `.rmdx`, a single device template (docs/06 §7.3, DR-179).
  ///
  /// **DECLARED AHEAD OF ITS CALLER, AND THAT IS THE POINT OF `#234`.**
  /// The import and export surface is `#236` and does not exist; the
  /// codec it needs is `#235` and does not exist either. This arm ships
  /// first because the alternative its own board item names is the one
  /// that actually happens: a surface built against a dialog that cannot
  /// offer its file type acquires a second hard-coded filter beside the
  /// first, and then the two disagree.
  ///
  /// The precedent for declaring-before-reading is DR-098 §11.97.4, which
  /// keeps `bodyDepth` unread because M5's `RCK-012` is a NAMED consumer.
  /// The name is the whole difference between this and an unreachable
  /// field, so it is written down: **`#236`**.
  device,

  /// `.rpda` and `.rmda`, a device library (DR-015 §11.15.3, DR-179).
  ///
  /// **THE FOURTH KIND, AND THE TABLE IS WHY IT COSTS ONE ROW.** `#234`
  /// replaced two parallel ternaries with `kFileKinds` precisely so the
  /// third and fourth kinds would not each nest another condition, and
  /// `file_dialog_flags_test.dart` fails if this value has no row there.
  /// Adding the arm is not optional and cannot be forgotten.
  library,

  /// A floorplan to import as a plan underlay: PNG, JPEG or PDF
  /// (DR-029, PLAN-D).
  ///
  /// **THE FIRST KIND WHOSE FILTER COVERS THREE FORMATS**, because a
  /// floorplan arrives as whichever of them the architect's office
  /// exports and asking the user which menu item to use would be asking
  /// them to classify a file they were sent.
  ///
  /// **THE FILTER IS A COURTESY AND NEVER THE CHECK.** What is accepted
  /// is decided by `sniffImportKind` on the CONTENT (PLAN-D/4, M4-M4's
  /// rule), because a dialog filter is advisory: "All files" is one click
  /// away, and a `.png` that is really an executable passes any filter
  /// ever written.
  ///
  /// **OPEN ONLY.** Nothing in this product saves a floorplan; an import
  /// copies one into the container. The `kFileKinds` row carries `png` as
  /// its default extension because the struct requires one, and that row
  /// is wrong the day a save path appears.
  floorplan,

  /// The integrator's logo: PNG, JPEG, PDF or SVG (`#590`, DR-217).
  ///
  /// **floorplan's row with SVG added, and its own row rather than that
  /// one widened**, because the floorplan import refuses SVG and a filter
  /// offering it there would offer a file the import then refuses. Open
  /// only, and the content sniff decides, for the same reasons.
  logo,
}

/// Native open and save dialogs, behind two methods.
abstract interface class FilePicker {
  /// Asks the user which document to open. Null means cancelled.
  Future<String?> pickOpen({
    String? initialDirectory,
    FileDialogType type = FileDialogType.project,
  });

  /// Asks the user where to save. Null means cancelled.
  ///
  /// The returned path may have NO EXTENSION — the Windows dialog hands
  /// back `Smith` when the user types `Smith` under the "All files"
  /// filter. Normalising that is `SavePaths.forTarget`'s job, in exactly
  /// one place.
  Future<String?> pickSave({
    String? suggestedName,
    String? initialDirectory,
    FileDialogType type = FileDialogType.project,
  });
}

/// The production picker: RackPal's own `IFileDialog`.
final class Win32FilePicker implements FilePicker {
  const Win32FilePicker({this.channel = kFileDialogChannel});

  /// Injected only so a test can point the picker at a channel it has
  /// installed a mock handler on; production always takes the default.
  final MethodChannel channel;

  @override
  Future<String?> pickOpen({
    String? initialDirectory,
    FileDialogType type = FileDialogType.project,
  }) => _invoke('open', {
    'initialDirectory': initialDirectory,
    'confirmButtonText': 'Open',
    'fileType': type.name,
  });

  @override
  Future<String?> pickSave({
    String? suggestedName,
    String? initialDirectory,
    FileDialogType type = FileDialogType.project,
  }) => _invoke('save', {
    'initialDirectory': initialDirectory,
    'fileType': type.name,
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

/// The `.rppj` filter both dialogs offer, as the native side spells
/// it. Declared here so a reader of this file can see what the dialog
/// shows without opening the C++.
const String kRackPalFilterLabel = 'RackPal project';

/// The default suggested name for a document that has never been saved.
String defaultSaveName(String displayName) => '$displayName$kDocumentExtension';

/// Shows a folder in the operating system's file manager (DR-194, `#941`).
///
/// True when the operating system says it showed the folder; false when it
/// refused or the call failed. Never throws: a menu item that cannot open a
/// folder says so, it does not crash the window.
///
/// A FUNCTION TYPE rather than a method on [FilePicker], so the two fakes
/// that implement the picker are not made to answer a question they are
/// not about, and a test injects a closure.
typedef FolderRevealer = Future<bool> Function(String folder);

/// [FolderRevealer] over the channel [Win32FilePicker] uses, which
/// `file_dialog_channel.cpp` serves as `revealFolder`.
Future<bool> win32RevealFolder(String folder) async {
  try {
    return await kFileDialogChannel.invokeMethod<bool>('revealFolder', {
          'path': folder,
        }) ??
        false;
  } on Object {
    return false;
  }
}

/// [WebPageLauncher] over the same channel, which `file_dialog_channel.cpp`
/// serves as `openUrl` (NET-A/4a, `#994`, DR-048 §11.47.7, DR-229).
///
/// ON THIS CHANNEL, BESIDE [win32RevealFolder], because it is the same act:
/// ShellExecuteW's "open" verb on a string, with a success code above 32.
/// No package and no plugin DLL, for the reason `pubspec.yaml` gives for the
/// file dialog: every native binary in the portable ZIP is one more for an
/// enterprise allowlist to block.
///
/// THE SCHEME IS CHECKED ON BOTH SIDES OF THE CHANNEL. Here, so nothing but
/// `http` and `https` is ever sent; and in the C++, so a future caller of
/// the channel cannot hand ShellExecute a path to a program. Never throws.
Future<bool> win32OpenWebPage(Uri url) async {
  if (!isOpenableWebUrl(url)) return false;
  try {
    return await kFileDialogChannel.invokeMethod<bool>('openUrl', {
          'url': url.toString(),
        }) ??
        false;
  } on Object {
    return false;
  }
}
