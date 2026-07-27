// THE CLAIM AND THE BEHAVIOUR, CHECKED AGAINST EACH OTHER.
//
// ==================================================================
// WHY THIS FILE EXISTS, AND WHY IT NO LONGER HOLDS A LIST OF KEYS
// ==================================================================
// A statement about what RackMate leaves on a client's machine has now
// been wrong FOUR TIMES, and every time in the same shape:
//
//   1. The leak was DOCUMENTED and left in place, while the deliverable
//      still promised there was no leak.
//   2. `FOS_DONTADDTORECENT` was added — a real fix — and five sites were
//      rewritten to say the leak was closed and the app touched no
//      registry key at all. A verification pass then measured
//      `LastVisitedPidlMRU` still being written.
//   3. The wording was narrowed to "exactly one value ... and nothing
//      else". `CIDSizeMRU` is also written — on EVERY dialog, including
//      one the user merely cancels, which is the case that wording had
//      explicitly ruled out. The verification that blessed the claim had
//      snapshotted two of the four ComDlg32 subkeys, so it could not have
//      seen it.
//   4. The gate built to stop the recurrence — this file's previous
//      version — reasoned only about `LastVisitedPidlMRU`, so the closed
//      half of every claim site was entirely ungated.
//
// THE PATTERN IS THE POINT: AN ENUMERATED CLAIM IS FRAGILE BY
// CONSTRUCTION. Every fix so far was "add the key we just found", which
// is guaranteed to be wrong again the moment a fifth key or a different
// Windows build turns up. The shell owns that list; we do not, we cannot
// measure it exhaustively from here, and no amount of care makes a closed
// statement about someone else's data safe.
//
// SO THE CLAIM IS A BOUND, AND THIS FILE GATES THE THREE THINGS THE BOUND
// IS MADE OF — each against something the project actually controls:
//
//   (a) RACKMATE'S OWN CODE WRITES NO REGISTRY KEY. That is a property of
//       source we own, so it is derived from the source: every Dart file
//       under every package's `lib/`, plus the Windows runner's C++, with
//       comments stripped, must contain no registry WRITE call. (Reads are
//       out of scope because the claim is about writes, and there is one —
//       see `kRegistryWriteApis` for exactly which and why.)
//   (b) `FOS_DONTADDTORECENT` IS SET, which is the half of the shell's
//       behaviour we do control and the reason no project FILE NAME
//       reaches the host. Derived from `kSharedOptions` in the .cpp.
//   (c) NO CLAIM SITE HAS CLOSED THE LIST AGAIN. Every file that
//       discusses the ComDlg32 record must state the bound, must keep any
//       list of shell keys open with `at minimum`, and must be free of
//       the closed-enumeration shapes below. EVERY file — all five
//       packages' `lib/` and `test/`, every pubspec, the whole Windows
//       runner and all of `docs/`. Sweeping less than that was itself an
//       instance of (c): the sweep's own docstring said "everything the
//       project ships or documents" while it read one package, four of the
//       runner's fourteen files and three of the fourteen docs, so a
//       reintroduced closed enumeration anywhere else went ungated. See
//       `_scannedFiles`, which the scope test holds to its description.
//
// WHAT THIS FILE DELIBERATELY DOES NOT DO: hold a list of ComDlg32 key
// names and check the prose against it. That is the same fragility one
// level up — the list would be as incomplete as the prose was, and the
// gate would go green on the day a fifth key appeared. `CIDSizeMRU` and
// `LastVisitedPidlMRU` appear nowhere in this file's logic. They are
// EXAMPLES in the claim sites, hedged, and nothing here depends on the
// examples being complete.
//
// IT STILL RUNS IN BOTH DIRECTIONS. If a future pass abandons the shell
// common dialog for a hand-built browser, or adds code that clears the
// shell's records, the derivation flips and every site still carrying the
// bound FAILS, forcing the claim up to the better truth. And if someone
// quietly restores an absolute wording without changing any behaviour,
// that fails too.
//
// A SOURCE GATE, and labelled as one, in the same family as
// `storage_layering_test.dart` RULE 7 and `session_layering_test.dart`
// RULE 15. Its measured limit: it reads text and source, not a running
// Windows machine. It cannot tell you which keys the shell writes — that
// is exactly the knowledge the claim was rebuilt not to need.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The C++ the dialogs are actually configured in.
const String _cppPath = 'windows/runner/file_dialog_channel.cpp';

/// THE BOUND. Every file that discusses the ComDlg32 record must contain
/// it verbatim (modulo comment leaders, wrapping and case) for as long as
/// the shell common dialog is the dialog.
///
/// It names no key and asserts no count, which is the entire repair: it
/// stays true without anybody knowing the complete list.
///
/// Deliberately a plain clause and not a marker comment: it has to READ as
/// part of the explanation at every site, because a reader who skims one
/// of those files is exactly the person this is protecting.
const String kUncontrolledClaim =
    'the shell writes values under ComDlg32 that RackMate does not control';

/// The hedge that keeps any list of shell keys OPEN.
///
/// Claim sites are allowed — encouraged — to name the keys that have
/// actually been measured, because a reader deserves to know what was
/// found. They are not allowed to present them as the set. This marker is
/// what makes the difference legible, and it is required at every claim
/// site so that "we found another one" is an edit to the examples rather
/// than a correction to a false sentence.
const String kOpenListMarker = 'at minimum';

/// The half we control, and a site that claims the win has to say which
/// key it won rather than gesture at "the registry".
const String kSuppressedKey = 'OpenSavePidlMRU';

/// The property of OUR OWN SOURCE that the bound rests on, stated at the
/// six canonical sites so a reader meets it beside the part we do not
/// control.
const String kOwnCodeClaim = 'writes no registry key';

/// Registry WRITE APIs. This IS a list, and the distinction from the list
/// this file refuses to keep is the whole design: these are the ways OUR
/// OWN code could write a key — a small, stable, documented API surface we
/// would have to reach for deliberately — not the keys the shell writes,
/// which are somebody else's data and cannot be enumerated from here.
/// Being wrong about this list means missing a write WE made, in code
/// review distance. Being wrong about the shell's is unavoidable, which is
/// why nothing here depends on one.
///
/// WRITES ONLY, AND THAT IS THE CLAIM, NOT A LOOPHOLE. The claim every
/// site makes is that RackMate's own code WRITES no registry key, and a
/// read is not a write. There is one read, and it is worth knowing about:
/// `windows/runner/win32_window.cpp` — the Flutter runner template — calls
/// `RegGetValue(HKEY_CURRENT_USER, ...)` on `AppsUseLightTheme` to pick
/// the window's title-bar theme. It creates nothing and changes nothing,
/// exactly like `path_provider_windows`' `SHGetKnownFolderPath`. A sweep
/// that failed on it would be failing on a true sentence, and the fix
/// would be to delete the sweep.
final List<(String, RegExp)> kRegistryWriteApis = <(String, RegExp)>[
  (
    'a Win32 registry write',
    RegExp(
      r'\bReg(SetValue|SetKeyValue|CreateKey|DeleteKey|DeleteValue|'
      'DeleteTree|SaveKey|RestoreKey|LoadKey|UnLoadKey|ReplaceKey|'
      r'CopyTree|RenameKey|OverridePredefKey)\w*\s*\(',
    ),
  ),
  (
    'a shell registry write helper',
    RegExp(
      r'\bSH(SetValue|DeleteKey|DeleteValue|DeleteEmptyKey|CopyKey|'
      'RegSetValue|RegSetUSValue|RegWriteUSValue|RegCreateUSKey|'
      r'RegDeleteUSValue|RegDeleteEmptyUSKey)\w*\s*\(',
    ),
  ),
  ('the win32_registry package', RegExp('win32_registry')),
  ('a Dart registry handle', RegExp(r'\bRegistry(Key|Value|Hive|ValueType)\b')),
];

/// Wordings that were shipped and measured FALSE. None of them may come
/// back anywhere in the scanned set.
///
/// `_normalise` has already collapsed comment leaders and wrapping, so
/// these match across a line break in a `//` block, a `#` YAML comment or
/// a markdown table cell alike.
final List<(String, RegExp)> kDiscreditedClaims = <(String, RegExp)>[
  ('the whole app touches nothing', RegExp('nothing touches the registry')),
  ('an unqualified whole-app claim', RegExp('touches no registry key')),
  ('an unqualified whole-app claim', RegExp('we write no registry keys')),
  ('an unqualified whole-app claim', RegExp('no registry traces?')),
  ('the leak is not closed', RegExp(r'leak\b[^.]{0,80}\bis closed\b')),
  ('the flag does not do this', RegExp('no comdlg32 mru registry write')),
  // The portable build's old headline promise. It was never true of the
  // file dialog and cannot be made true while the shell owns it.
  ('the build does leave a trace', RegExp('leaves? no trace')),
  ('the build does leave a trace', RegExp('left no trace')),
  ('the build does leave a trace', RegExp('no trace on the host')),
];

/// THE SHAPES A CLOSED CLAIM COMES IN — not the words of any one of them.
///
/// Each of the four wrong claims was a different sentence; what they had
/// in common was arithmetic ("exactly one value"), exhaustion ("nothing
/// else"), or a braced set read as the whole. These patterns are matched
/// against SHAPE, and a hit only counts when a registry word is nearby —
/// see [closedEnumerations] — because "the only thing that makes it hard"
/// is ordinary prose and "the only HKCU value" is the defect.
final List<(String, RegExp)> kClosedEnumerationShapes = <(String, RegExp)>[
  ('an exhaustive "nothing else"', RegExp(r'\bnothing (else|more|further)\b')),
  (
    'a closed "no other ..."',
    RegExp(
      r'\bno other\s+(hkcu\s+|comdlg32\s+|registry\s+|shell\s+|mru\s+)*'
      r'(key|value|entry|entries|record|subkey|trace)s?\b',
    ),
  ),
  (
    'a counted residual',
    RegExp(
      r'\b(exactly|just|only|leaves|leave|left|leaving)\s+(exactly\s+)?'
      r'(one|two|three|a single|1|2|3)\s+'
      r'(hkcu\s+|comdlg32\s+|registry\s+|shell\s+|mru\s+)*'
      r'(key|value|entry|entries|record|thing|item|trace)s?\b',
    ),
  ),
  (
    'a counted residual',
    RegExp(
      r'\b(one|a single|two|three)\s+(hkcu|comdlg32|registry|shell)\s+'
      r'(key|value|entry|record|subkey)s?\b',
    ),
  ),
  (
    'a closed "the only ..."',
    RegExp(
      r'\bthe only\s+(hkcu\s+|comdlg32\s+|registry\s+|shell\s+)*'
      r'(key|value|entry|record|subkey|trace)s?\b',
    ),
  ),
  (
    'a closed pair',
    RegExp(r'\b(both|the two)\s+(comdlg32\s+)?(key|value|record|subkey)s?\b'),
  ),
  (
    'a claimed complete list',
    // "this IS the complete list" is the offence. "we cannot establish a
    // complete list" and "true without knowing the complete list" are the
    // repair, and a rule that failed on those would be unusable.
    RegExp(
      r'\b((is|are)\s+the\s+(complete|full|exhaustive)\s+list|'
      r'the\s+(complete|full|exhaustive)\s+list\s+(is|reads|follows))\b',
    ),
  ),
  ('an exhaustive "that is all"', RegExp(r'\bthat is (all|everything)\b')),
  ('a closed "exactly this"', RegExp(r'\bleaves? exactly\b')),
  (
    'a braced set read as the whole record',
    // The `{OpenSavePidlMRU, LastVisitedPidlMRU}` shorthand three of the
    // four wrong claims used. Only identifiers, spaces and commas inside
    // the braces, so a Dart or markdown code block that merely happens to
    // mention one of these names is not a claim about the set; and `mru`
    // must END an identifier, or `{id, fromRuIndex, toRuIndex}` — a real
    // record type in docs/03 — matches on `fro-MRU-index` and the rule
    // fires on a code sample about moving a device.
    RegExp(r'\{[a-z0-9_ ,]*mru\b[a-z0-9_ ,]*\}'),
  ),
];

/// A closed-enumeration shape only counts as one when it is talking about
/// the registry. Without this the rule fires on "the only thing that makes
/// it hard is WHERE persistence writes" and every other ordinary use of
/// English in a file that happens to mention ComDlg32 further down.
const List<String> kRegistryContextWords = <String>[
  'hkcu',
  'hklm',
  'comdlg32',
  'registry',
  'mru',
];

/// How far either side of a match a registry word has to appear.
const int kContextWindow = 160;

/// The workspace's other four packages, relative to this app's root. Shared
/// by BOTH sweeps below, because the defect this file was widened to fix was
/// precisely two sweeps disagreeing about how much of the project they read.
const List<String> kSiblingPackages = <String>[
  'rackmate_core',
  'rackmate_text',
  'rackmate_export',
  'rackmate_ui',
];

/// The files this rule reads: EVERY file this workspace ships, tests with,
/// or documents, minus this one — which necessarily contains every banned
/// literal.
///
/// Concretely, and the docstring is the specification the
/// 'the sweep reads the whole project' test below holds it to:
///
///   * all five packages' `lib/` and `test/` trees (`.dart`),
///   * all five packages' pubspecs, and the workspace root's,
///   * the Windows runner's C++ (`.cpp`/`.cc`/`.h`),
///   * `README.md`,
///   * every `.md` under `docs/`.
///
/// THE SCOPE IS THE RULE. A version of this list that reads four of the
/// fourteen runner files and three of the fourteen docs — which is what it
/// read before — leaves a closed enumeration reintroduced in
/// `packages/rackmate_ui/lib` or in `docs/00-overview.md` completely
/// ungated, while the docstring above it says otherwise. That is the same
/// defect class this file exists to prevent: a claim that does not match
/// what was measured. Narrow it and the test below fails.
///
/// `docs/research/` is EXCLUDED on purpose: those are dated research notes
/// recording what was believed at the time, not claims the project makes.
List<File> _scannedFiles() {
  final files = <File>[
    ..._dartFilesUnder('lib'),
    ..._dartFilesUnder('test'),
    File('pubspec.yaml'),
    for (final package in kSiblingPackages) ...[
      ..._dartFilesUnder('../../packages/$package/lib'),
      ..._dartFilesUnder('../../packages/$package/test'),
      File('../../packages/$package/pubspec.yaml'),
    ],
    File('../../pubspec.yaml'),
    ..._nativeSourceUnder('windows'),
    File('../../README.md'),
    ..._documentationFiles(),
  ];
  return files
      .where((f) => f.existsSync() && !_isThisFile(f))
      .toList(growable: false);
}

/// Every `.md` under `docs/`, less `docs/research/`.
List<File> _documentationFiles() {
  final directory = Directory('../../docs');
  if (!directory.existsSync()) return const <File>[];
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) {
        final path = _label(f);
        if (path.contains('/docs/research/')) return false;
        return path.endsWith('.md');
      })
      .toList(growable: false);
}

/// EVERY LINE OF SOURCE THIS PROJECT SHIPS AND WROTE — the population
/// claim (a) is about.
///
/// The workspace's five package `lib/` trees plus the Windows runner. Not
/// tests (they do not ship), not `build/`, not the Flutter SDK's own
/// ephemeral headers under `windows/flutter/ephemeral/` (not ours, and
/// not a place we could put a registry write even if we wanted one).
List<File> _ownSourceFiles() => <File>[
  ..._dartFilesUnder('lib'),
  for (final package in kSiblingPackages)
    ..._dartFilesUnder('../../packages/$package/lib'),
  ..._nativeSourceUnder('windows'),
].where((f) => f.existsSync()).toList(growable: false);

List<File> _nativeSourceUnder(String root) {
  final directory = Directory(root);
  if (!directory.existsSync()) return const <File>[];
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) {
        final path = _label(f);
        if (path.contains('/ephemeral/') || path.contains('/build/')) {
          return false;
        }
        return path.endsWith('.cpp') ||
            path.endsWith('.cc') ||
            path.endsWith('.h');
      })
      .toList(growable: false);
}

bool _isThisFile(File f) => _label(f).endsWith('registry_claim_test.dart');

List<File> _dartFilesUnder(String root) {
  final directory = Directory(root);
  if (!directory.existsSync()) return const <File>[];
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList(growable: false);
}

String _label(File f) => f.path.replaceAll(r'\', '/');

/// Comment leaders, wrapping and case removed, so one literal clause can
/// be asserted across a `//` block, a `#` YAML comment, a `*` bullet and a
/// markdown table cell without four spellings of it.
String _normalise(String raw) {
  final lines = raw.replaceAll('\r', '').split('\n').map((line) {
    var l = line.trimLeft();
    for (final leader in const ['//', '#', '*', '>', '|']) {
      while (l.startsWith(leader)) {
        l = l.substring(leader.length).trimLeft();
      }
    }
    return l;
  });
  return lines.join(' ').replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

/// Source WITH ITS COMMENTS REMOVED — the same technique, and for the same
/// reason, as `file_dialog_flags_test.dart`: the files this reads explain
/// the registry at length, and a derivation that read the prose describing
/// the behaviour rather than the behaviour would answer the same thing
/// whatever the code did.
String stripComments(String source) {
  final withoutBlocks = source.replaceAll(
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

String _cppCode() {
  final file = File(_cppPath);
  expect(
    file.existsSync(),
    isTrue,
    reason: 'run from the app root; $_cppPath is where the truth is derived '
        'from',
  );
  return stripComments(file.readAsStringSync());
}

/// Every registry WRITE API named by [code]. Pure and exported so the
/// mutants below can drive it with source that is not in the tree.
List<String> registryWritesIn(String code) {
  final found = <String>[];
  for (final (why, pattern) in kRegistryWriteApis) {
    for (final match in pattern.allMatches(code)) {
      found.add('${match[0]} — $why');
    }
  }
  return found;
}

/// The three things the bound is made of, read off the source rather than
/// remembered.
typedef DialogTruth = ({
  bool ownCodeWritesNoRegistryKey,
  bool suppressesOpenSave,
  bool shellWritesValuesWeDoNotControl,
});

DialogTruth deriveDialogTruth(
  String cppCode, {
  required bool ownSourceIsClean,
}) {
  // THE SHELL COMMON DIALOG IS THE WRITER. While the app creates one, the
  // shell keeps records under ComDlg32 that no documented option governs,
  // which is the measured fact this whole file exists to keep stated.
  // Replacing `IFileDialog` with a hand-built browser is the only thing
  // that ends it, and it would show up here as these CLSIDs going away.
  final usesShellDialog =
      cppCode.contains('CLSID_FileOpenDialog') &&
      cppCode.contains('CLSID_FileSaveDialog') &&
      cppCode.contains('IFileDialog');

  // ...or CODE THAT TOUCHES THE REGISTRY AT ALL: a snapshot-and-restore, a
  // delete, a mitigation of any shape has to reach a registry API. Note
  // what is NOT here — a search for a key NAME. A mitigation keyed to the
  // name of one key is exactly the fix that has failed three times; any
  // registry API in the dialog implementation flips the derivation, and
  // flips claim (a) with it, so both halves have to be restated together.
  final mitigates = registryWritesIn(cppCode).isNotEmpty;

  return (
    ownCodeWritesNoRegistryKey: ownSourceIsClean,
    suppressesOpenSave: RegExp(
      r'kSharedOptions\s*=\s*\n?\s*FOS_DONTADDTORECENT',
    ).hasMatch(cppCode),
    shellWritesValuesWeDoNotControl: usesShellDialog && !mitigates,
  );
}

/// Files that discuss the ComDlg32 record at all. Derived, not listed, so
/// a new file that starts making the claim is gated the day it is written.
bool isClaimSite(String normalised) =>
    normalised.contains('pidlmru') || normalised.contains('comdlg32');

/// Closed-enumeration shapes present in [normalised], each one within
/// [kContextWindow] characters of a registry word.
///
/// Pure, and takes its input, so the mutants below can drive it with text
/// that is not in the tree — the only way to show this rule can fail while
/// the tree is green.
List<String> closedEnumerations(String normalised) {
  final found = <String>[];
  for (final (why, pattern) in kClosedEnumerationShapes) {
    for (final match in pattern.allMatches(normalised)) {
      final from = (match.start - kContextWindow).clamp(0, normalised.length);
      final to = (match.end + kContextWindow).clamp(0, normalised.length);
      final window = normalised.substring(from, to);
      if (kRegistryContextWords.any(window.contains)) {
        found.add('"${match[0]}" — $why');
      }
    }
  }
  return found;
}

/// The claim sites that must ALWAYS exist. Without this the rule passes
/// vacuously the moment somebody deletes the paragraphs instead of
/// correcting them — which is the cheapest way to make a gate like this
/// stop meaning anything.
const List<String> kMandatoryClaimSites = <String>[
  'windows/runner/file_dialog_channel.h',
  'windows/runner/file_dialog_channel.cpp',
  'lib/src/session/file_picker.dart',
  'lib/src/storage/data_root.dart',
  '../../README.md',
  '../../docs/03-architecture.md',
];

void main() {
  late final Map<String, String> scanned;
  late final Map<String, List<String>> ownSourceOffences;
  late final DialogTruth truth;

  setUpAll(() {
    scanned = <String, String>{
      for (final file in _scannedFiles())
        _label(file): _normalise(file.readAsStringSync()),
    };
    ownSourceOffences = <String, List<String>>{};
    for (final file in _ownSourceFiles()) {
      final hits = registryWritesIn(stripComments(file.readAsStringSync()));
      if (hits.isNotEmpty) ownSourceOffences[_label(file)] = hits;
    }
    truth = deriveDialogTruth(
      _cppCode(),
      ownSourceIsClean: ownSourceOffences.isEmpty,
    );
  });

  test('the derivation is not vacuous — it reads real files', () {
    // If `_cppCode()` ever returned an empty string, or the own-source
    // sweep ever found nothing to read, every claim below would be derived
    // from nothing and the rule would pass by accident.
    expect(_cppCode().trim(), isNotEmpty);
    expect(_cppCode(), contains('RegisterFileDialogChannel'));
    expect(scanned, isNotEmpty);
    expect(
      _ownSourceFiles().length,
      greaterThan(100),
      reason:
          'claim (a) is a sweep over every line this project ships. A '
          'handful of files means the roots moved and the sweep is now '
          'reading almost nothing.',
    );
    expect(
      _ownSourceFiles().map(_label).where((p) => p.endsWith('.cpp')),
      isNotEmpty,
      reason: 'the Windows runner is where a registry call would go',
    );
  });

  test('the sweep reads the whole project, not a hand-picked corner', () {
    // THE SCOPE IS ITSELF A CLAIM, AND THIS IS WHERE IT IS CHECKED.
    // `_scannedFiles` used to say "everything the project ships or
    // documents" and read one package's `lib/`, four of the runner's
    // fourteen files and three of the fourteen docs. A closed enumeration
    // written into any other package or any other doc sailed through, and
    // nothing failed — the gate was narrower than its own description,
    // which is the exact defect it was built to catch, one level up.
    //
    // So the corpus is asserted against the filesystem rather than against
    // a list, and re-narrowing it fails here.
    final paths = scanned.keys.toSet();
    bool covered(String fragment) => paths.any((p) => p.contains(fragment));

    final missing = <String>[
      for (final package in kSiblingPackages) ...[
        if (!covered('/packages/$package/lib/')) 'packages/$package/lib',
        if (!covered('/packages/$package/test/')) 'packages/$package/test',
        if (!paths.contains('../../packages/$package/pubspec.yaml'))
          'packages/$package/pubspec.yaml',
      ],
      if (!covered('lib/src/session/')) 'lib (this app)',
      if (!paths.contains('pubspec.yaml')) 'pubspec.yaml (this app)',
      if (!paths.contains('../../pubspec.yaml')) 'pubspec.yaml (workspace)',
      if (!paths.contains('../../README.md')) 'README.md',
    ];
    expect(
      missing,
      isEmpty,
      reason:
          'the sweep no longer reads part of the workspace its own docstring '
          'promises. Widen it back, or the claim sites in the parts it '
          'skipped are ungated:\n${missing.join('\n')}',
    );

    // EVERY doc, derived from the directory — so a doc added tomorrow is
    // gated the day it lands rather than the day somebody remembers.
    final docsOnDisk = Directory('../../docs')
        .listSync(recursive: true)
        .whereType<File>()
        .map(_label)
        .where((p) => p.endsWith('.md') && !p.contains('/docs/research/'))
        .toSet();
    expect(docsOnDisk.length, greaterThan(10));
    expect(
      docsOnDisk.difference(paths),
      isEmpty,
      reason: 'docs/ is read whole, less docs/research/. These were skipped',
    );

    // ...and every runner source, for the same reason.
    final runnerOnDisk = _nativeSourceUnder('windows').map(_label).toSet();
    expect(runnerOnDisk.length, greaterThan(8));
    expect(runnerOnDisk.difference(paths), isEmpty);
  });

  // ======================================================================
  // (a) OUR OWN CODE
  // ======================================================================
  test('RackMate’s own code writes no registry key', () {
    expect(
      ownSourceOffences,
      isEmpty,
      reason:
          'the claim every claim site makes about OUR half — that nothing '
          'RackMate ships writes a registry key — is now false. Either '
          'remove the call, or rewrite the claim everywhere: it is the '
          'part of the sentence a reader is entitled to take as ours.\n'
          '${ownSourceOffences.entries.map((e) => '${e.key}: '
              '${e.value.join(', ')}').join('\n')}',
    );
    final silent = <String>[];
    for (final path in kMandatoryClaimSites) {
      final text = scanned[path];
      if (text == null || !text.contains(kOwnCodeClaim)) silent.add(path);
    }
    expect(
      silent,
      isEmpty,
      reason:
          'the canonical sites must state the half we DO control — '
          '"$kOwnCodeClaim" — beside the half we do not, or a reader takes '
          'the whole ComDlg32 paragraph as something RackMate did:\n'
          '${silent.join('\n')}',
    );
  });

  // ======================================================================
  // (b) THE FLAG
  // ======================================================================
  test('the C++ still suppresses OpenSavePidlMRU, and every site says so', () {
    // The half that IS a win, held to the same standard as the half that
    // is not. If the flag ever goes, the sites naming `OpenSavePidlMRU` as
    // suppressed become the false claim, and `file_dialog_flags_test.dart`
    // fails alongside this.
    expect(
      truth.suppressesOpenSave,
      isTrue,
      reason:
          'FOS_DONTADDTORECENT is no longer in kSharedOptions. Every file '
          'listed by this rule claims the project file NAME is kept off '
          'the host, and that claim is now false — fix the C++ or rewrite '
          'all of them.',
    );
    final silent = <String>[];
    scanned.forEach((path, text) {
      if (!isClaimSite(text)) return;
      if (!text.contains(kSuppressedKey.toLowerCase())) silent.add(path);
    });
    expect(
      silent,
      isEmpty,
      reason:
          'a file that discusses the ComDlg32 record must name the key the '
          'flag actually suppresses ($kSuppressedKey) rather than gesture '
          'at "the registry" — the difference between what we control and '
          'what we do not is the entire finding:\n${silent.join('\n')}',
    );
  });

  // ======================================================================
  // (c) THE BOUND, AND THAT IT IS STILL A BOUND
  // ======================================================================
  test('every claim site states the bound', () {
    expect(
      truth.shellWritesValuesWeDoNotControl,
      isTrue,
      reason:
          'the C++ no longer creates a shell common dialog, or now calls a '
          'registry API itself. If the shell-owned residue is genuinely '
          'gone, this test should be inverted and the sentence '
          '"$kUncontrolledClaim" removed from every file below — that is '
          'the good direction, and it must not happen silently.',
    );
    final unstated = mismatchedClaimSites(scanned, truth);
    expect(
      unstated,
      isEmpty,
      reason:
          'measured against the shipped binary and against a harness that '
          'replicates this dialog exactly: opening one project writes '
          '`rackmate.exe` and the browsed FOLDER into ComDlg32, and merely '
          'opening and cancelling the dialog writes `rackmate.exe` again '
          'somewhere else. Every file that discusses this record must '
          'state the bound in these words — "$kUncontrolledClaim" — '
          'because the person deciding whether to run a portable build on '
          'a client machine reads one of them, not all of '
          'them:\n${unstated.join('\n')}',
    );
  });

  test('every claim site keeps its list of shell keys OPEN', () {
    final closed = <String>[];
    scanned.forEach((path, text) {
      if (!isClaimSite(text)) return;
      if (!text.contains(kOpenListMarker)) closed.add(path);
    });
    expect(
      closed,
      isEmpty,
      reason:
          'a claim site may name the keys that were measured — a reader '
          'wants to know — but it may not present them as the set. '
          '"$kOpenListMarker" is what marks the difference, and its '
          'absence is how three of the four wrong versions of this claim '
          'read:\n${closed.join('\n')}',
    );
  });

  test('no claim site has closed the enumeration again', () {
    final offences = <String>[];
    scanned.forEach((path, text) {
      if (!isClaimSite(text)) return;
      for (final hit in closedEnumerations(text)) {
        offences.add('$path: $hit');
      }
    });
    expect(
      offences,
      isEmpty,
      reason:
          'this is the shape the claim has been wrong in four times: a '
          'count, an exhaustion, or a braced set, asserted over data the '
          'shell owns and we cannot enumerate. State the bound instead — '
          'what we control, what we do not, and what a reader should '
          'therefore expect:\n${offences.join('\n')}',
    );
  });

  test('no discredited absolute has come back', () {
    final offences = <String>[];
    scanned.forEach((path, text) {
      for (final (why, pattern) in kDiscreditedClaims) {
        if (pattern.hasMatch(text)) {
          offences.add('$path: /${pattern.pattern}/ — $why');
        }
      }
    });
    expect(
      offences,
      isEmpty,
      reason:
          'each of these was shipped, and each was measured false. State '
          'what IS and IS NOT written instead:\n${offences.join('\n')}',
    );
  });

  test('every mandatory claim site still discusses the ComDlg32 record', () {
    final missing = <String>[];
    for (final path in kMandatoryClaimSites) {
      final text = scanned[path];
      if (text == null || !isClaimSite(text)) missing.add(path);
    }
    expect(
      missing,
      isEmpty,
      reason:
          'these files are where a reader goes to find out what running '
          'this on a client machine leaves behind. Deleting the paragraph '
          'is not a way to make the claim true:\n${missing.join('\n')}',
    );
  });

  // ======================================================================
  // GUARDS THE GUARD
  // ======================================================================
  // Every assertion above is over the real tree, which is green — so none
  // of them demonstrates that it CAN fail. These do, on synthetic text, in
  // the same spirit as `session_layering_test.dart` RULE 15b.
  group('the rule itself can fail', () {
    const honest =
        '// FOS_DONTADDTORECENT keeps everything out of OpenSavePidlMRU.\n'
        '// Beyond that the shell writes values under ComDlg32 that\n'
        '// RackMate does not control — at minimum LastVisitedPidlMRU and\n'
        '// CIDSizeMRU, which are examples and not an inventory.';
    const truthful = (
      ownCodeWritesNoRegistryKey: true,
      suppressesOpenSave: true,
      shellWritesValuesWeDoNotControl: true,
    );

    test('a claim site that omits the bound is caught', () {
      const silent =
          '// FOS_DONTADDTORECENT closes the ComDlg32 leak. Nothing is\n'
          '// written to OpenSavePidlMRU, so there is nothing left.';
      expect(
        mismatchedClaimSites({'silent': _normalise(silent)}, truthful),
        ['silent'],
      );
      expect(
        mismatchedClaimSites({'honest': _normalise(honest)}, truthful),
        isEmpty,
      );
    });

    test('...and so is a bound left behind after the residue really goes', () {
      // THE OTHER DIRECTION. Someone replaces the shell dialog for real;
      // the sentence in every file is now the false one.
      const fixed = (
        ownCodeWritesNoRegistryKey: true,
        suppressesOpenSave: true,
        shellWritesValuesWeDoNotControl: false,
      );
      expect(
        mismatchedClaimSites({'stale': _normalise(honest)}, fixed),
        ['stale'],
      );
    });

    test('a file that never mentions the keys is not a claim site', () {
      const unrelated = '// The rack editor draws 42U of rails.';
      expect(isClaimSite(_normalise(unrelated)), isFalse);
      expect(
        mismatchedClaimSites({'unrelated': _normalise(unrelated)}, truthful),
        isEmpty,
      );
      expect(closedEnumerations(_normalise(unrelated)), isEmpty);
    });

    test('the derivation flips when the shell dialog goes away', () {
      const handBuilt = '''
ComPtr<IRackMateBrowser> dialog;
constexpr FILEOPENDIALOGOPTIONS kSharedOptions =
    FOS_DONTADDTORECENT | FOS_FORCEFILESYSTEM;
''';
      final derived = deriveDialogTruth(handBuilt, ownSourceIsClean: true);
      expect(derived.shellWritesValuesWeDoNotControl, isFalse);
      expect(derived.suppressesOpenSave, isTrue);
    });

    test('...and when the runner starts touching the registry itself', () {
      // A MITIGATION OF ANY SHAPE, found without naming a single key.
      const mitigated = '''
ComPtr<IFileDialog> dialog;
CoCreateInstance(saving ? CLSID_FileSaveDialog : CLSID_FileOpenDialog);
RegDeleteValueW(hkey, value_name);
constexpr FILEOPENDIALOGOPTIONS kSharedOptions =
    FOS_DONTADDTORECENT | FOS_FORCEFILESYSTEM;
''';
      expect(
        deriveDialogTruth(
          mitigated,
          ownSourceIsClean: registryWritesIn(mitigated).isEmpty,
        ).shellWritesValuesWeDoNotControl,
        isFalse,
      );
    });

    test('...and it does NOT flip for the shipping shape', () {
      const shipping = '''
ComPtr<IFileDialog> dialog;
CoCreateInstance(saving ? CLSID_FileSaveDialog : CLSID_FileOpenDialog);
constexpr FILEOPENDIALOGOPTIONS kSharedOptions =
    FOS_DONTADDTORECENT | FOS_FORCEFILESYSTEM | FOS_NOCHANGEDIR;
''';
      final derived = deriveDialogTruth(shipping, ownSourceIsClean: true);
      expect(derived.shellWritesValuesWeDoNotControl, isTrue);
      expect(derived.suppressesOpenSave, isTrue);
    });

    test('a dropped flag is caught', () {
      const noFlag = '''
ComPtr<IFileDialog> dialog;
CoCreateInstance(saving ? CLSID_FileSaveDialog : CLSID_FileOpenDialog);
constexpr FILEOPENDIALOGOPTIONS kSharedOptions =
    FOS_FORCEFILESYSTEM | FOS_NOCHANGEDIR;
''';
      expect(
        deriveDialogTruth(noFlag, ownSourceIsClean: true).suppressesOpenSave,
        isFalse,
      );
    });

    test('a registry write in our own source is found, in C++ and in Dart', () {
      expect(
        registryWritesIn('RegSetValueExW(key, L"x", 0, REG_SZ, data, len);'),
        isNotEmpty,
      );
      expect(
        registryWritesIn('RegCreateKeyExW(HKEY_CURRENT_USER, ...);'),
        isNotEmpty,
      );
      expect(
        registryWritesIn('SHDeleteValueW(HKEY_CURRENT_USER, k, v);'),
        isNotEmpty,
      );
      expect(
        registryWritesIn("import 'package:win32_registry/win32_registry.dart';"),
        isNotEmpty,
      );
      expect(
        registryWritesIn('final key = RegistryKey.openPath(hive);'),
        isNotEmpty,
      );
    });

    test('...and the ordinary spellings that merely look like one are not', () {
      // `RegisterFileDialogChannel` and `RegExp` are in this tree several
      // hundred times over. A pattern that matched them would make claim
      // (a) unmeetable and the whole rule would be deleted, which is the
      // real failure mode for a check like this.
      expect(
        registryWritesIn('RegisterFileDialogChannel(engine, owner);'),
        isEmpty,
      );
      expect(registryWritesIn('RegisterPlugins(engine);'), isEmpty);
      expect(registryWritesIn(r"RegExp(r'\s+').hasMatch(text);"), isEmpty);
      expect(registryWritesIn('final registrar = Registrar();'), isEmpty);
    });

    test('a registry READ is not a registry write', () {
      // This is not a hole, it is the claim. `win32_window.cpp` — the
      // Flutter runner template — reads `AppsUseLightTheme` to pick the
      // title-bar theme, and claim (a) says WRITES. A sweep that failed on
      // this would be failing on a true sentence.
      expect(
        registryWritesIn(
          'LSTATUS result = RegGetValue(HKEY_CURRENT_USER, '
          'kGetPreferredBrightnessRegKey, kGetPreferredBrightnessRegValue, '
          'RRF_RT_REG_DWORD, nullptr, &light_mode, &light_mode_size);',
        ),
        isEmpty,
      );
      expect(registryWritesIn('RegQueryValueExW(key, name, ...);'), isEmpty);
      expect(registryWritesIn('RegOpenKeyExW(root, path, 0, KEY_READ, &k);'),
          isEmpty);
    });

    test('a registry call hidden in a comment is not a registry call', () {
      // ...and, more importantly, PROSE ABOUT the registry is not one
      // either. Every claim site names HKCU repeatedly; a sweep that read
      // comments would report all of them and (a) could never be green.
      const commented = '''
// We could RegDeleteValueW(HKEY_CURRENT_USER, ...) here, and we do not.
void ConfigureDialog() {}
''';
      expect(registryWritesIn(commented), isNotEmpty);
      expect(registryWritesIn(stripComments(commented)), isEmpty);
    });

    test('each closed-enumeration shape really does catch what shipped', () {
      // A ban list whose patterns match nothing is a ban list that would
      // not have caught what shipped. These are the actual sentences, from
      // the four claim sites this task was raised against.
      const shipped = r'''
SO A PORTABLE BUILD LEAVES EXACTLY THIS ON A CLIENT'S MACHINE: one HKCU
value naming this executable and one folder path. Nothing else: no file
name, no shortcut, no jump-list entry.
Running the portable build leaves ONE thing behind in that machine's HKCU.
A portable build DOES leave one HKCU value on a client's machine.
The dialog records what was opened in ComDlg32\\{OpenSavePidlMRU,
LastVisitedPidlMRU}, and no other key is written.
The two ComDlg32 keys are the only value the shell leaves, and that is all
— this is the complete list, and there is nothing more under HKCU.
''';
      final text = _normalise(shipped);
      final hits = closedEnumerations(text);
      for (final (why, pattern) in kClosedEnumerationShapes) {
        expect(
          hits.any((h) => h.endsWith(why)),
          isTrue,
          reason: '/${pattern.pattern}/ ($why) matches nothing in the '
              'wording it was written to ban',
        );
      }
    });

    test('...and does NOT fire on ordinary prose that is merely nearby', () {
      // THE COST OF A NOISY RULE IS THAT IT GETS DELETED. These sentences
      // are all real, all in scanned files, and all fine.
      const ordinary = '''
The only thing that makes it hard is WHERE persistence writes its
out-of-document state. FOS_DONTADDTORECENT is set in exactly one function,
applied by one function, called by both branches, and ComDlg32 is named
right here. Normalising that is SavePaths.forTarget's job, in exactly one
place. It governs none of these, and no other FILEOPENDIALOGOPTIONS bit
does either. Both dialogs go through it.
''';
      expect(closedEnumerations(_normalise(ordinary)), isEmpty);
    });

    test('the open-list marker is what separates the two', () {
      const hedged =
          '// ComDlg32 records more than one thing: at minimum '
          'LastVisitedPidlMRU.';
      const unhedged = '// ComDlg32 records LastVisitedPidlMRU.';
      expect(_normalise(hedged).contains(kOpenListMarker), isTrue);
      expect(_normalise(unhedged).contains(kOpenListMarker), isFalse);
    });
  });
}

/// Claim sites whose text does not match [truth].
///
/// Pure, and takes its inputs, so the mutants above can drive it with text
/// that is not in the tree — which is the only way to show this rule can
/// fail while the tree is green.
List<String> mismatchedClaimSites(
  Map<String, String> scanned,
  DialogTruth truth,
) {
  final bound = kUncontrolledClaim.toLowerCase();
  final mismatched = <String>[];
  scanned.forEach((path, text) {
    if (!isClaimSite(text)) return;
    if (text.contains(bound) != truth.shellWritesValuesWeDoNotControl) {
      mismatched.add(path);
    }
  });
  return mismatched..sort();
}
