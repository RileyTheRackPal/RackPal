#ifndef RUNNER_FILE_DIALOG_CHANNEL_H_
#define RUNNER_FILE_DIALOG_CHANNEL_H_

#include <flutter/flutter_engine.h>
#include <windows.h>

// Registers `rackpal/file_dialog`, the app's own open/save dialogs.
//
// ==================================================================
// WHY THIS EXISTS AT ALL, AND WHY IT IS ~150 LINES OF C++
// ==================================================================
// The portable build runs from a USB stick and writes only into its own
// `RackPalData` folder beside the executable. Everything in the storage
// layer honours that; RackPal itself writes no registry key anywhere. The
// file dialog is the one place where the HOST gets written to, because the
// writer is the Windows shell and not this app.
//
// Windows' `IFileDialog` records what was opened under
// `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32` —
// the chosen file's name and full path land in `OpenSavePidlMRU` — plus a
// shortcut under `%APPDATA%\Microsoft\Windows\Recent` and a jump-list
// entry. So opening `E:\Jobs\Smith Residence.rackpal` once on a client's
// PC seeded that PC's recent-documents list with the customer's project
// name.
//
// `file_selector_windows` cannot set `FOS_DONTADDTORECENT` and cannot be
// made to. Its Pigeon-generated `SelectionOptions` carries `allowMultiple`,
// `selectFolders` and `allowedTypes` and nothing else, and its `ShowDialog`
// calls `AddOptions` only for the first two — so there is no argument, no
// configuration and no subclass that reaches the flag from Dart at any
// price. The choices were an upstream change on somebody else's schedule,
// a narrowed claim, or owning the dialog. docs/03 §10.1 already
// contemplates exactly this trade for `window_manager` ("the only
// load-bearing API is setPreventClose + the close event: ~80 lines of
// Win32 platform channel"), and the same reasoning applies here with a
// harder deliverable behind it.
//
// ==================================================================
// WHAT IS AND IS NOT WRITTEN — STATED AS A BOUND, NOT AS A LIST
// ==================================================================
// THIS CLAIM HAS BEEN WRONG FOUR TIMES, AND EVERY TIME THE SAME WAY: a
// pass measured some of the ComDlg32 subkeys, wrote down the ones it had
// seen, closed the list — and the next measurement found another one.
// `OpenSavePidlMRU` was the first. `LastVisitedPidlMRU` was the second.
// `CIDSizeMRU` was the third, and it is written even when the user opens
// the dialog and presses Escape — a case every previous wording had
// explicitly ruled out. The shell owns that list, not us; it differs by
// Windows build; and a statement that depends on having it complete is
// wrong by construction. So this is a BOUND, and it is deliberately not
// an inventory.
//
// OURS, AND GATED. RackPal's own code writes no registry key — no `Reg*`
// call, no registry package, nothing under HKCU or HKLM from any line we
// ship. That is a property of source we control, so
// `registry_claim_test.dart` derives it from the source rather than
// trusting this sentence.
//
// THE HALF WE CONTROL. `FOS_DONTADDTORECENT` is set, and that is what
// keeps the user's FILE NAME off the host: nothing is added under
// `OpenSavePidlMRU` (no `rackpal` subkey appears there) and no shortcut
// appears in `%APPDATA%\Microsoft\Windows\Recent`. Measured against the
// shipped binary; held at the flag by `file_dialog_flags_test.dart`.
//
// THE HALF WE DO NOT. The shell writes values under ComDlg32 that
// RackPal does not control — at minimum `LastVisitedPidlMRU` (this
// executable's name plus the last FOLDER browsed into) and `CIDSizeMRU`
// (this executable's name and the dialog's persisted size, written on
// every dialog including a cancelled one). Both were measured; both are
// EXAMPLES, not the inventory. `FOS_DONTADDTORECENT` is defined against
// `SHAddToRecentDocs` — the recent-DOCUMENTS list — and governs none of
// them, and there is no supported option that does while the dialog is
// the shell common dialog. Only abandoning `IFileDialog` for a hand-built
// file browser would, which was weighed and declined.
//
// SO, BOUNDED: running the portable build on a client's machine leaves
// shell-owned HKCU entries naming this executable and folders it browsed
// — `E:\Jobs`, never `E:\Jobs\Smith Residence.rackpal` — and they
// survive the stick being pulled. It does not leave project FILE NAMES,
// and it does not leave anything RackPal's own code wrote.
//
// The flag is set in one place, `kSharedOptions` in the .cpp, and
// `file_dialog_flags_test.dart` asserts it is still there.
// `registry_claim_test.dart` asserts that the paragraphs above still
// match what the .cpp actually does, and that no site anywhere in the
// project has closed the list again.
void RegisterFileDialogChannel(flutter::FlutterEngine* engine, HWND owner);

#endif  // RUNNER_FILE_DIALOG_CHANNEL_H_
