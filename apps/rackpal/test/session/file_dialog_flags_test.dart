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
// values under ComDlg32 that RackPal does not control — at minimum
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
//      `Release\rackpal.exe` was driven through File ▸ Open with
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
import 'package:rackpal/src/storage/save_paths.dart';

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
      contains('*.rmpj;*.rackpal'),
      reason: 'DR-015 keeps both project spellings in ONE entry',
    );
    expect(
      source,
      contains('*.rmdx'),
      reason:
          'M4-M1 (#234): the device-template filter has to exist, or the '
          'import surface #236 builds will reach for a second hard-coded '
          'array, which is the defect that item exists to prevent',
    );
  });

  // ── M4-M1: the kind table (board #234) ─────────────────────────────
  //
  // WHY THESE READ A TABLE AND NOT A TERNARY. Until #234 the filter and
  // the default extension were two `csv ? … : …` expressions over one
  // condition, and the assertion here was `contains` over the exact
  // ternary text — a MECHANISM assertion, which the house style forbids
  // and which the third kind broke on contact. What the criterion
  // actually wants is that every kind Dart can send has a filter AND a
  // matching default extension, bound so they cannot drift apart. That
  // is a property of the table, so the table is what is read.

  /// The `kFileKinds` rows as `{wire name: default extension}`.
  Map<String, String> nativeKinds() {
    final rows = RegExp(
      r'\{L"(\w+)",\s*\w+,\s*ARRAYSIZE\(\w+\),\s*L"(\w+)"\}',
    ).allMatches(_source());
    return {for (final m in rows) m.group(1)!: m.group(2)!};
  }

  /// The `FileDialogType` values, in declaration order.
  List<String> dartKinds() {
    final picker = _stripComments(
      File('lib/src/session/file_picker.dart').readAsStringSync(),
    );
    final body = RegExp(
      r'enum FileDialogType\s*\{([^}]*)\}',
      dotAll: true,
    ).firstMatch(picker);
    expect(body, isNotNull, reason: 'the enum is the wire vocabulary');
    return RegExp(
      r'\w+',
    ).allMatches(body!.group(1)!).map((m) => m.group(0)!).toList();
  }

  test('every kind Dart can send is a row the runner knows', () {
    // THE DEFECT THIS CATCHES IS SILENT. An unrecognised kind does not
    // throw and does not show an empty dialog — it falls back to the
    // project filter, so `Export device template…` would open a dialog
    // offering `*.rmpj` and a person would reasonably conclude the
    // feature was mis-wired rather than the runner un-taught.
    expect(
      nativeKinds().keys.toSet(),
      containsAll(dartKinds()),
      reason:
          'add the row in file_dialog_channel.cpp in the same commit as '
          'the enum value, or the new kind silently gets the project '
          'filter',
    );
  });

  test('the filter and the DEFAULT extension are one row, not two', () {
    // The half D13 names separately: `SetDefaultExtension` fired inside
    // `ConfigureDialog`, which BOTH branches call, so a Save As of
    // anything that was not a project still acquired `.rmpj`. A row
    // carrying both is what stops the pair disagreeing again.
    final source = _source();
    expect(
      source,
      contains('SetDefaultExtension(kind->default_extension)'),
      reason:
          'ONE call reading the row. A second hard-coded call anywhere '
          'would re-open the defect on whichever dialog reached it',
    );
    expect(
      source,
      contains('SetFileTypes(kind->filter_count, kind->filters)'),
      reason: 'and the filter comes from the same row, not another branch',
    );
    expect(
      nativeKinds(),
      containsPair('project', 'rmpj'),
      reason: 'DR-015: a Save with no extension typed is a .rmpj',
    );
    expect(nativeKinds(), containsPair('csv', 'csv'));
    expect(
      nativeKinds(),
      containsPair(
        'device',
        // Read out of the Dart constant rather than spelled twice, so the
        // two ends cannot drift. docs/06 §7.3 fixes the extension.
        kDeviceTemplateExtension.substring(1),
      ),
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
    // A Dart value the runner has not been taught yet opens a USABLE
    // dialog instead of an empty one. The fallback is row zero, so the
    // property is "row zero is project" plus "the loop may find nothing",
    // and both are read rather than assumed.
    final source = _source();
    expect(
      source,
      contains('const FileKind* kind = &kFileKinds[0]'),
      reason: 'the fallback is the initialiser, so no match is not a crash',
    );
    expect(
      dartKinds().first,
      'project',
      reason:
          'and row zero must be the project kind. Dart declares the same '
          'order and its enum names the fallback in FileDialogType.device',
    );
    expect(
      nativeKinds().keys.first,
      'project',
      reason: 'the C++ table is what actually decides it',
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
