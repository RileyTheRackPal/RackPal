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
  final withoutBlocks = file.readAsStringSync().replaceAll(
    RegExp(r'/\*.*?\*/', dotAll: true),
    '',
  );
  return withoutBlocks
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i == -1 ? line : line.substring(0, i);
      })
      .join('\n');
}

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
