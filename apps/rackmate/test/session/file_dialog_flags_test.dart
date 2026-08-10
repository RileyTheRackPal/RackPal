// THE HALF OF THE ComDlg32 LEAK THAT IS ACTUALLY CLOSED, HELD AT THE ONLY
// LEVEL A DART TEST CAN HOLD IT.
//
// ==================================================================
// WHAT THIS PROVES AND WHAT IT DOES NOT — READ THIS FIRST
// ==================================================================
// Windows' `IFileDialog` records what was opened under
//
//     HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32
//
// — the chosen project's name and full path land in `OpenSavePidlMRU` —
// plus a shortcut under `%APPDATA%\Microsoft\Windows\Recent`.
// `FOS_DONTADDTORECENT` suppresses that key and the shortcut — that is
// what keeps a customer's project FILE NAME off the host — and it is set
// in exactly one function, which this file asserts. A SOURCE GATE, and
// labelled as one, in the same family as `storage_layering_test.dart`
// RULE 7 (which holds "the write path really does fsync" the same way and
// says so).
//
// This file does not pretend the flag is the whole story: the shell writes
// values under ComDlg32 that RackMate does not control — at minimum
// `LastVisitedPidlMRU` (this executable plus the last folder browsed) and
// `CIDSizeMRU` (this executable, written even when the dialog is
// cancelled), measured examples and not an inventory — and no supported
// option prevents them. THAT half is held by `registry_claim_test.dart`,
// which checks the claim and the behaviour against each other; this file
// holds only the flag.
//
// THE THREE LEVELS OF EVIDENCE, so nobody has to guess how much this is
// worth:
//   1. THIS FILE: the flag is present, both dialogs go through the one
//      function that applies it, and `SetOptions` OR-s onto the shell's
//      defaults rather than replacing them.
//   2. `flutter build windows`: the C++ is compiled against the SDK's own
//      `shobjidl.h`, so `FOS_DONTADDTORECENT`, the CLSIDs, and every call
//      signature are checked by the compiler. A typo is a build failure,
//      not a silent no-op — which is precisely what a hand-rolled FFI
//      version would NOT have given.
//   3. DONE ONCE, BY HAND, AND NOT REPEATABLE HERE: the shipped
//      `Release\rackmate.exe` was driven through File ▸ Open with
//      synthetic input and HKCU was diffed either side. That is where the
//      statement above comes from — `OpenSavePidlMRU` unchanged, other
//      subkeys changed. Nothing in this repository can re-run it, and a
//      measurement on one machine cannot establish a complete list
//      anyway; what a suite CAN do is stop the written claim drifting
//      away from it and stop it being restated as a closed list, which is
//      `registry_claim_test.dart`'s job.
//
// A grep sees the call, not the semantics. Someone who wraps the
// `SetOptions` in a condition that is usually false slips past this file,
// exactly as `storage_layering_test.dart` RULE 7 admits for the fsync.
// Stated rather than glossed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _channel = 'windows/runner/file_dialog_channel.cpp';

/// The C++ WITH ITS COMMENTS REMOVED.
///
/// Load-bearing, and found by mutation: the file's header explains the
/// flag at length, so a `contains('FOS_DONTADDTORECENT')` over the raw
/// text stayed green after the flag was deleted from the option set. A
/// gate that passes on the prose describing the fix is not a gate.
String _source() {
  final file = File(_channel);
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'run from the app root. If this file is gone, the app is back on '
        'a dialog that cannot set FOS_DONTADDTORECENT.',
  );
  return _stripComments(file.readAsStringSync());
}

/// Code only: block comments and `//` tails removed.
///
/// EXTRACTED SO THE DART ASSERTIONS GET IT TOO. The D13 cases below
/// assert that the Dart side does NOT contain a Win32 filter spelling,
/// and `file_picker.dart`'s own doc comment explains at length why it
/// must not — which is this file's opening lesson arriving from the
/// other direction: an absence assertion over raw text fails on the
/// prose describing the absence.
String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i == -1 ? line : line.substring(0, i);
    })
    .join('\n');

void main() {
  test('FOS_DONTADDTORECENT is set', () {
    expect(
      _source(),
      contains('FOS_DONTADDTORECENT'),
      reason:
          'without it, running the portable build from a USB stick and '
          'opening one project writes the customer’s project NAME and '
          'full path into the host’s OpenSavePidlMRU and drops a shortcut '
          r'in %APPDATA%\Microsoft\Windows\Recent. The flag is what '
          'keeps file names off the host; it does not and cannot stop the '
          'shell-owned records beside it',
    );
  });

  test('...in the shared option set BOTH dialogs go through', () {
    final source = _source();
    // One constant, applied by one function, called by both branches. A
    // flag set on the open dialog only would leave every Save As writing
    // the file name into OpenSavePidlMRU.
    expect(
      RegExp(
        r'kSharedOptions\s*=\s*\n?\s*FOS_DONTADDTORECENT',
      ).hasMatch(source),
      isTrue,
      reason: 'the flag must be in the set both dialogs receive',
    );
    expect(
      RegExp(r'ConfigureDialog\(IFileDialog\*').hasMatch(source),
      isTrue,
      reason: 'one function applies it',
    );
    expect(
      RegExp(r'options\s*\|\s*kSharedOptions').hasMatch(source),
      isTrue,
      reason:
          'SetOptions REPLACES the option set. Assigning it blind would '
          'clear the shell’s own defaults for the dialog type — including '
          'FOS_OVERWRITEPROMPT on the save dialog, whose loss silently '
          'overwrites a project the user picked by accident.',
    );
    expect(
      RegExp('CLSID_FileSaveDialog').hasMatch(source),
      isTrue,
      reason: 'and the save dialog really is one of the two',
    );
    expect(
      RegExp('CLSID_FileOpenDialog').hasMatch(source),
      isTrue,
    );
    // Both method names route through the same creation path.
    expect(source, contains('"save"'));
    expect(source, contains('"open"'));
  });

  test('the option set is read back before it is written', () {
    expect(
      _source(),
      contains('GetOptions(&options)'),
      reason:
          'OR-ing onto what the shell already decided is what keeps '
          'FOS_OVERWRITEPROMPT alive on the save dialog',
    );
  });

  // ── D13: the file-type filter (board M3-F/4, #162) ─────────────────
  //
  // Same discipline as the flag above, and for the same reason: the
  // header prose names `csv` several times, so `contains('csv')` over
  // the raw text would stay green after the arm was deleted. Every
  // assertion here runs over `_source()`, which strips comments first.

  test('the filter is chosen from an argument, not hard-coded', () {
    final source = _source();
    expect(
      source,
      contains('StringArg(args, "fileType")'),
      reason:
          'D13: the dialog took no file-type argument at all, so a CSV '
          'import could only be reached through the All files entry',
    );
    expect(
      source,
      contains('*.csv'),
      reason: 'the CSV filter has to exist, not only be described',
    );
    expect(
      source,
      contains('*.rmpj;*.rackmate'),
      reason: 'DR-015 keeps both project spellings in ONE entry',
    );
  });

  test('the DEFAULT extension follows the kind, on both dialogs', () {
    // The half D13 names separately: `SetDefaultExtension` fired inside
    // `ConfigureDialog`, which BOTH branches call, so a Save As of
    // anything that was not a project still acquired `.rmpj`.
    expect(
      _source(),
      contains('SetDefaultExtension(csv ? L"csv" : L"rmpj")'),
      reason:
          'one call, one condition; a second hard-coded call anywhere '
          'would re-open the defect on whichever dialog reached it',
    );
  });

  test('Dart sends a KIND and never a Win32 filter string', () {
    // The decision D13 asks to get right BEFORE D2. A COMDLG_FILTERSPEC
    // pattern crossing the channel would not port: NSOpenPanel wants
    // UTTypes or bare extensions, so the macOS runner would have to
    // parse the pattern back apart, which is D13's "widen it twice".
    final picker = _stripComments(
      File('lib/src/session/file_picker.dart').readAsStringSync(),
    );
    expect(picker, contains('enum FileDialogType'));
    expect(picker, contains("'fileType': type.name"));
    expect(
      picker,
      isNot(contains('COMDLG_FILTERSPEC')),
      reason: 'the Dart side must not know the Win32 spelling',
    );
    expect(
      picker,
      isNot(contains('*.csv')),
      reason: 'nor the pattern; the native side owns both',
    );
  });

  test('an unknown kind falls back rather than showing nothing', () {
    // `csv` is the only special case and everything else takes the
    // project filter, so a Dart value the runner has not been taught
    // yet opens a usable dialog instead of an empty one.
    expect(_source(), contains('*file_type == L"csv"'));
  });

  test('the runner actually registers the channel', () {
    // A perfectly configured dialog nobody wires up is a Ctrl+O that does
    // nothing.
    final window = File('windows/runner/flutter_window.cpp').readAsStringSync();
    expect(window, contains('RegisterFileDialogChannel('));
    final cmake = File('windows/runner/CMakeLists.txt').readAsStringSync();
    expect(
      cmake,
      contains('file_dialog_channel.cpp'),
      reason: 'a source file not in the target is a link error at best',
    );
    expect(
      cmake,
      contains('shell32.lib'),
      reason: 'SHCreateItemFromParsingName lives there',
    );
    expect(cmake, contains('ole32.lib'));
  });

  test('the Dart side names the same channel', () {
    final picker = File(
      'lib/src/session/file_picker.dart',
    ).readAsStringSync();
    final native = _source();
    final name = RegExp(
      r'kChannelName\[\]\s*=\s*"([^"]+)"',
    ).firstMatch(native);
    expect(name, isNotNull);
    expect(
      picker,
      contains("'${name![1]}'"),
      reason:
          'the two ends of a platform channel agree by string only. A '
          'mismatch is a MissingPluginException the first time the user '
          'presses Ctrl+O.',
    );
  });
}
