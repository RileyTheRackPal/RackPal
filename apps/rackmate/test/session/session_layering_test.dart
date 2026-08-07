// SOURCE-LEVEL GATES for the session layer, the siblings of
// `storage_layering_test.dart`'s six.
//
// Each one keeps a native dependency to a single, fakeable seam. A second
// import site is not a style problem: it is a second dialog
// configuration, a second window-event registration or a second
// title-diffing rule to keep in sync — and the second one is always the
// one nobody tests.
import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate/src/session/app_shell.dart' show kViewKeyToTabIndex;
import 'package:rackmate_ui/rackmate_ui.dart';

const _libSession = 'lib/src/session';
const _testSession = 'test/session';

String _stripComments(String source) {
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

List<File> _dartFilesUnder(String path) {
  final dir = Directory(path);
  expect(
    dir.existsSync(),
    isTrue,
    reason: 'run from the app root; $path must exist',
  );
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

String _basename(File f) => f.path.split(Platform.pathSeparator).last;

/// The body of every class / mixin / enum / extension declared at the top
/// level of [source], one string each.
///
/// A TOP-LEVEL FUNCTION'S STATEMENTS ARE INDENTED BY TWO SPACES, exactly
/// like a class member, so RULE 15's declaration pattern cannot be run
/// over a whole file: `if (displays.isEmpty) return null;` inside
/// `validateRestoredBounds` parses as a field named `null`. Splitting on
/// the top-level declaration first is what makes the two-space rule mean
/// "member of a class".
///
/// Relies on `dart format`'s guarantee that a top-level declaration's
/// closing brace sits in column zero — which `flutter analyze` enforces
/// for this repository.
Iterable<String> _classBodies(String source) sync* {
  final lines = source.split('\n');
  final opener = RegExp(r'^[\w\s]*\b(?:class|mixin|enum|extension)\b');
  var i = 0;
  while (i < lines.length) {
    if (opener.hasMatch(lines[i])) {
      final body = StringBuffer();
      i++;
      while (i < lines.length && !lines[i].startsWith('}')) {
        body.writeln(lines[i].replaceAll('\r', ''));
        i++;
      }
      yield body.toString();
    }
    i++;
  }
}

List<String> _importersOf(String package) {
  final importers = <String>[];
  for (final file in _dartFilesUnder('lib')) {
    if (_stripComments(file.readAsStringSync()).contains(package)) {
      importers.add(_basename(file));
    }
  }
  return importers..sort();
}

void main() {
  test('RULE 7 — the native file dialog is reached from exactly ONE '
      'file', () {
    // Every open / save / Save-As flow is widget-testable with no native
    // dialog only because there is one wrapper. A second call site is a
    // second dialog configuration and a second `suggestedName` convention,
    // and the accepted file type is exactly the kind of thing that drifts.
    //
    // THE SEAM IS A CHANNEL NAME NOW, not a package import: `file_selector`
    // was removed because its Windows implementation cannot set
    // FOS_DONTADDTORECENT, so every open and every save wrote the
    // project's name and full path into the host's OpenSavePidlMRU. The
    // rule is the same rule; only the thing being counted changed.
    expect(_importersOf("'rackmate/file_dialog'"), ['file_picker.dart']);
    expect(
      _importersOf('package:file_selector/'),
      isEmpty,
      reason:
          'the package is gone from the pubspec precisely because it '
          'could not set the flag; an import would be a second dialog '
          'that writes every project file name into the host’s '
          'OpenSavePidlMRU',
    );
  });

  test('RULE 8 — window_manager is imported by exactly ONE file', () {
    // `setPreventClose` is the only load-bearing API in the dependency,
    // and the close event has to reach exactly one handler. Two
    // `WindowListener` registrations would mean two close prompts.
    expect(_importersOf('package:window_manager/'), ['window_chrome.dart']);
  });

  test('RULE 9 — screen_retriever is imported by exactly ONE file', () {
    // It is `window_manager`'s own transitive dependency, taken directly
    // only so `validateRestoredBounds` can be given real display work
    // areas. `main.dart` translates it into the pure geometry type at the
    // boundary; nothing below sees a `Display`.
    expect(_importersOf('package:screen_retriever/'), ['main.dart']);
  });

  test('RULE 10 — the session layer never reaches for dart:io', () {
    // The storage layer's own gate allows exactly two files. The session
    // layer sits above `FileStore` and must have none: everything here is
    // testable without a disk BECAUSE it cannot reach one.
    final offenders = <String>[];
    var scanned = 0;
    for (final file in _dartFilesUnder(_libSession)) {
      scanned++;
      final source = _stripComments(file.readAsStringSync());
      if (RegExp('''['"]dart:io['"]''').hasMatch(source)) {
        offenders.add(file.path);
      }
    }
    expect(scanned, greaterThan(5), reason: 'a vacuous scan proves nothing');
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('RULE 11 — nothing in the session tests sleeps', () {
    // Both timer factories and the clock are injected. A `Future.delayed`
    // here is either a real wall-clock wait or a race, and the autosave
    // interval is thirty seconds.
    final offenders = <String>[];
    var scanned = 0;
    for (final file in _dartFilesUnder(_testSession)) {
      scanned++;
      final lines = _stripComments(file.readAsStringSync()).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'Future\.delayed|sleep\s*\(').hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(scanned, greaterThan(5));
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('RULE 12 — the session layer does not reach for print()', () {
    final offenders = <String>[];
    for (final file in _dartFilesUnder(_libSession)) {
      final lines = _stripComments(file.readAsStringSync()).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'(?<![\w.$])(print|debugPrint)\s*\(').hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('RULE 13 — CR-096 still holds with the session layer in place', () {
    // The storage gate asserts the recovery directory is NAMED in one
    // file. This is the same rule re-checked across `lib/` as a whole,
    // because the session layer is the first thing above `RecoveryStore`
    // and is exactly where a "just read them all" helper would appear.
    final namers = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final source = _stripComments(file.readAsStringSync());
      if (RegExp("'recovery'").hasMatch(source) ||
          source.contains('kRecoveryDirName =')) {
        namers.add(_basename(file));
      }
    }
    expect(namers, ['recovery_store.dart']);
  });

  test('RULE 14b — the platform is INJECTED into buildAppServices, never '
      'defaulted', () {
    // `isWindows` picks the errno table a failed save is classified
    // through and decides whether `kWindowsMaxPath` is enforced. It used
    // to default to `true` while `main.dart` never passed it, so on
    // macOS and Linux a disk-full save (ENOSPC 28) fell through the
    // Windows switch to `StorageFailure.unknown` and reached the user as
    // "something went wrong that RackMate does not have a specific
    // explanation for", and any path over 259 characters was refused
    // outright on a filesystem whose real limit is 4096 bytes.
    //
    // The parameter is `required` now, so the compiler holds half of
    // this. The half it cannot hold is that the composition root passes
    // something REAL rather than a literal.
    final services = File('$_libSession/app_services.dart').readAsStringSync();
    expect(
      _stripComments(services),
      contains('required bool isWindows'),
      reason: 'a default is how the wrong wiring stays optional',
    );

    final main = _stripComments(File('lib/main.dart').readAsStringSync());
    expect(
      main,
      contains('isWindows: defaultTargetPlatform == TargetPlatform.windows'),
      reason:
          'the third environment lookup, beside the other two. '
          '`defaultTargetPlatform` rather than `Platform.isWindows` '
          'because storage_layering_test RULE 1 allows dart:io in exactly '
          'two files and main.dart is not one of them.',
    );
  });

  test('RULE 14c — the top-level error channel §12.1 throws into really '
      'exists', () {
    // `session_controller.dart` throws `StateError` twice on purpose —
    // "DocumentStore.open returned a non-OpenError" and its save twin —
    // as the honest way to say "this is our bug, not the user's file".
    // Both are reached from futures nobody awaits. Without these three
    // handlers installed in `main`, they vanish completely, and so does
    // anything thrown by the four awaits before `runApp` — which exits
    // with a black window and no message at all.
    final main = _stripComments(File('lib/main.dart').readAsStringSync());
    for (final handler in [
      'runZonedGuarded(',
      'FlutterError.onError =',
      'PlatformDispatcher.instance.onError =',
    ]) {
      expect(
        main,
        contains(handler),
        reason:
            '$handler is one of the three, and all three are needed: '
            'they catch different things',
      );
    }
    // And it must not become a print: §12.4 forbids a file path reaching
    // a log, and an exception's toString is exactly where one ends up.
    expect(main, isNot(matches(RegExp(r'(?<![\w.$])print\s*\('))));
  });

  test('RULE 14d — the file-name half of the ComDlg32 leak is FIXED, not '
      'merely documented', () {
    // WHAT THIS RULE USED TO BE, and why it is not that any more. It
    // pinned `file_selector_windows-0.9.3+5` as a TRIPWIRE, on the
    // reasoning that the leak was "not fixable from Dart" and that the
    // honest thing was to narrow the claim and wait for upstream. That
    // left a shipped promise false: running the portable build from a USB
    // stick and opening one project still wrote the customer's project
    // name and full path into HKCU\...\ComDlg32\OpenSavePidlMRU.
    //
    // The package is gone. RackMate drives `IFileDialog` itself and sets
    // FOS_DONTADDTORECENT, so what has to be asserted now is that it is
    // still doing so — see `file_dialog_flags_test.dart` for the flag
    // itself. This rule holds the two halves that live in the pubspec and
    // in the Dart seam.
    //
    // THE RULE'S TITLE SAYS "the file-name half" ON PURPOSE.
    // FOS_DONTADDTORECENT closes OpenSavePidlMRU and the %APPDATA% Recent
    // shortcut; beyond that, the shell writes values under ComDlg32 that
    // RackMate does not control — at minimum LastVisitedPidlMRU (this
    // executable plus the last folder browsed) and CIDSizeMRU (this
    // executable, written even on a cancelled dialog), measured examples
    // and not an inventory — and nothing here or anywhere else in the app
    // prevents them. `registry_claim_test.dart` is the rule that keeps
    // every written claim bounded rather than enumerated.
    final lock = File('../../pubspec.lock').readAsStringSync();
    expect(
      lock,
      isNot(contains('  file_selector')),
      reason:
          'file_selector is back in the dependency graph. Its Windows '
          'implementation calls AddOptions only for select_folders and '
          'allow_multiple and its Pigeon message has no field for '
          'anything else, so FOS_DONTADDTORECENT cannot be requested '
          'through it at any price — and without that flag every open '
          'and every save writes the project file name into the host’s '
          'OpenSavePidlMRU.',
    );

    final picker = File('$_libSession/file_picker.dart').readAsStringSync();
    expect(picker, contains('FOS_DONTADDTORECENT'));
    expect(picker, contains('OpenSavePidlMRU'));
  });

  // ======================================================================
  // RULE 15 — A PRODUCTION FIELD WITH NO PRODUCTION WRITER
  // ======================================================================
  // This rule exists because of the SHAPE of a defect, not because of one
  // instance of it. `AppServices.prefs` was a mutable public field
  // documented as "the live prefs, held so a geometry write does not
  // clobber lastSaveDirectory". It was assigned exactly once anywhere in
  // the repository outside its own constructor — and that one assignment
  // was a line in `window_chrome_test.dart`, performing by hand a
  // synchronisation production never performed.
  //
  // The suite was therefore green while every window move wrote the
  // STARTUP prefs back over prefs.json, reverting a `lastSaveDirectory`
  // the user's Save As had recorded correctly 500 ms earlier. NO
  // BEHAVIOURAL TEST COULD HAVE CAUGHT IT: the fixture supplied the
  // missing writer itself, so the code under test never ran in its
  // production configuration. A field whose only writer lives in test code
  // is invisible to a test suite by construction, and the only place the
  // absence is observable is the source.
  //
  // The rule: every MUTABLE PUBLIC instance field declared in `lib/` must
  // be assigned somewhere in `lib/` other than its own declaration. If it
  // never is, it is either dead, or `final`, or — as here — a lie about
  // where the live value lives.
  final fieldDeclaration = RegExp(
    // Exactly two spaces of indent: class members. Applied only INSIDE a
    // class body (see `_classBodies`), because a top-level function's
    // statements are indented by two as well.
    '^ {2}(?! )'
    // Not final/const/static/late, and not an annotation.
    r'(?!final\b|const\b|static\b|late\b|var\b|@)'
    // Not a getter or setter: `int get step;` is an abstract accessor,
    // not a field.
    r'(?![^;\r\n]*\b(?:get|set)\s)'
    // The type. `Function` types carry parentheses, so those are allowed —
    // but `;`, `{`, `}`, `=` and a LINE BREAK are not, which is what
    // excludes method declarations, initialiser lists and (crucially) a
    // match that starts on a stripped comment line and runs into the
    // declaration below it.
    r'([^;{}=\r\n]+?)\s+'
    // The name: public, so it cannot start with `_`, and never the
    // `operator` keyword — `bool operator ==(Object o) => …;` otherwise
    // parses as a field called `operator`.
    r'(?!operator\b)([a-z][A-Za-z0-9_]*)'
    // An optional initialiser. `=(?!>)` keeps expression-bodied getters
    // (`bool get x => …;`) out.
    r'(?:\s*=(?!>)\s*[^;\r\n]+)?;[ \t]*$',
    multiLine: true,
  );

  test('RULE 15 — no mutable public field is written only by a test', () {
    final declarations = <({String file, String name, String line})>[];
    final withoutDeclarations = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final source = _stripComments(file.readAsStringSync());
      for (final body in _classBodies(source)) {
        for (final match in fieldDeclaration.allMatches(body)) {
          declarations.add((
            file: _basename(file),
            name: match[2]!,
            line: match[0]!.trim(),
          ));
        }
      }
      // An ASSIGNMENT, not a declaration. A field that is only ever given
      // its own default is exactly the case being hunted, so its
      // declaration must not count as its writer.
      withoutDeclarations.add(source.replaceAll(fieldDeclaration, ''));
    }
    // A vacuous scan proves nothing: `AppServices.geometry` and
    // `SessionController.onDocumentReplaced` are both real mutable public
    // fields and both are assigned in `lib/`.
    expect(
      declarations.map((d) => d.name),
      containsAll(<String>['geometry', 'onDocumentReplaced']),
      reason: 'the parser must SEE the fields, or this rule is empty',
    );

    final unwritten = <String>[];
    for (final declared in declarations) {
      // TWO SHAPES, AND NEITHER IS "the name appears before an `=`".
      // Found by mutation: the loose version passed `AppServices.prefs`
      // back to mutable because `session_controller.dart` happens to
      // contain the LOCAL `final prefs = stores?.prefs;`. A local with the
      // same name is not a writer of the field.
      //
      //   `x.name =`        — assigned through a receiver
      //   `name =` / `this.name =` at the START of a statement — assigned
      //                       from inside the declaring class
      //
      // A declaration (`final name = …`, `var name = …`) has a keyword
      // before the name and matches neither.
      const assign = r'\s*(?:\?\?=|=(?![=>]))';
      final assignment = RegExp(
        '\\.${declared.name}$assign'
        r'|^\s*(?:this\.)?'
        '${declared.name}$assign',
        multiLine: true,
      );
      if (!withoutDeclarations.any(assignment.hasMatch)) {
        unwritten.add('${declared.file}: ${declared.line}');
      }
    }

    expect(
      unwritten,
      isEmpty,
      reason:
          'a mutable public field with no writer in lib/ is either dead or '
          'is being written by a TEST, which makes the defect invisible to '
          'the suite. Make it `final`, delete it, or write it:\n'
          '${unwritten.join('\n')}',
    );
  });

  test('RULE 15b — ...and the rule itself can fail', () {
    // Guards the guard. The exact shape that shipped: a mutable public
    // field, documented as live, assigned nowhere but in a test.
    const mutant = '''
final class AppServices {
  AppServices({required this.prefs});
  AppPrefs prefs;
  WindowGeometryRecorder? geometry;
  bool get busy => prefs != null;
  Future<void> flush();
}
''';
    final found = [
      for (final body in _classBodies(mutant))
        ...fieldDeclaration.allMatches(body).map((m) => m[2]),
    ];
    expect(
      found,
      unorderedEquals(<String>['prefs', 'geometry']),
      reason:
          'the parser must see the two FIELDS and neither the getter nor '
          'the method, or RULE 15 proves nothing',
    );
  });

  // ======================================================================
  // RULE 14 — THE GLOBAL BINDING GROUPS HAVE NOT GROWN A MEMBER
  // ======================================================================
  // WHAT THIS RULE USED TO BE, AND WHY IT IS NOT THAT ANY MORE. It counted
  // `SingleActivator(LogicalKeyboardKey.…)` literals in `app_shell.dart`
  // with a regex and asserted EXACTLY ELEVEN: four in `kFileShortcuts`, the
  // same four again on the File menu items so the accelerators would
  // render, and three in `kViewShortcuts`. The number was doing two jobs —
  // "the file group has not gained a fifth binding" and "no menu item
  // advertises a key nothing listens for" — and it did both by counting
  // text in one file.
  //
  // M2-H moved every binding into `kKeymap` (macOS debt D7: the eleven
  // literals all hard-coded `control: true`, and macOS needs `Cmd`), so
  // that count is now ZERO and the regex would pass vacuously forever. The
  // rule MOVES rather than relaxes, and it keeps both jobs:
  //
  //   (i)  the global scope is EXACTLY the seven bindings named below —
  //        the same property the eleven was pinning, asserted against the
  //        declaration instead of against its spelling. A new global key
  //        fails here, and so does a deleted one;
  //   (ii) `app_shell.dart` may not construct a `SingleActivator` AT ALL.
  //        A hand-rolled binding beside the registry is invisible to the
  //        generated table and to arbitration — which is precisely the
  //        state M2-H existed to end — and it would re-hard-code `Ctrl`;
  //   (iii) the shell's menus still declare exactly four accelerators
  //        across six items, so `Export PDF…` has none. docs/08 §8.1 gives
  //        it `Ctrl+P` and that binding is not built. The sixth item is
  //        `Project ▸ Locations…` (M3-B/2, CR-112), which has none either.
  //
  // (iii) is weaker than it was and says so: with `shortcut:` now naming a
  // `KeyBindingId`, a menu item CANNOT advertise a key nothing listens for
  // — the row it names is the binding. What is left to catch is an
  // accelerator appearing on an item that was decided not to have one, or
  // one vanishing from a file item, and that is a count.
  test('RULE 14 — exactly two complete keybinding groups are registered', () {
    // docs/04 §8's ~40-binding table is NOT bound wholesale: a partial
    // keymap reads as a whole one, so a group lands only when it is
    // complete. TWO are complete — the four FILE bindings, and the VIEW
    // switch.
    expect(
      keyBindingsIn(KeyScope.global).map((b) => b.id),
      orderedEquals(<KeyBindingId>[
        KeyBindingId.newDocument,
        KeyBindingId.openDocument,
        KeyBindingId.saveDocument,
        KeyBindingId.saveDocumentAs,
        KeyBindingId.switchViewRack,
        KeyBindingId.switchViewSchematic,
        KeyBindingId.switchViewSchedule,
      ]),
      reason:
          'the app binds Ctrl/Cmd+N / +O / +S / +Shift+S and '
          'Ctrl/Cmd+1 / +2 / +4, and nothing else above the root focus '
          'scope. An eighth is either a new binding or a group that grew '
          'without the decision being taken again.',
    );

    final shell = _stripComments(
      File('$_libSession/app_shell.dart').readAsStringSync(),
    );
    expect(
      shell,
      isNot(contains('SingleActivator(')),
      reason:
          'a binding declared here instead of in kKeymap is invisible to '
          'the generated table and to the collision arbitration, and it '
          'hard-codes Ctrl on a platform that may want Cmd. Add a row to '
          'kKeymap and read it back with keymapActivator.',
    );

    final menuItems = RegExp(r'MenuItemButton\(').allMatches(shell).length;
    final accelerators = RegExp('shortcut:').allMatches(shell).length;
    expect(
      [menuItems, accelerators],
      // 5 -> 6 at M3-B/2, and the accelerator count deliberately did NOT
      // move. The sixth is `Project ▸ Locations…` (CR-112), the first item
      // on a second top-level menu; CR-110 already owes that menu a
      // `Structured wiring…` beside it, so this number will move again and
      // should move visibly each time.
      [6, 4],
      reason:
          'five File-menu items — New, Open…, Save, Save As…, Export PDF… '
          '— plus Project ▸ Locations…, and four accelerators, because '
          'neither Export PDF nor Locations has one. docs/08 §8.1 gives '
          'export Ctrl+P; the dialog is not built and neither is the '
          'binding. Locations opens a panel once per project and does not '
          "earn a row in kKeymap, M7's table and arbitration across every "
          'platform.',
    );
  });

  test('RULE 14e — `Ctrl+3` is bound to NOTHING (CR-071)', () {
    // docs/04 §8 line 456 and docs/10 :516: "`Ctrl+3` is reserved for the
    // Rear Panel view and is an unbound no-op until v1.1 (CR-071);
    // `Ctrl+4` is the Schedule in v1 and forever. Do not rebind the
    // Schedule to `Ctrl+3` — `Ctrl+n` is a view identity, not an ordinal."
    //
    // The strip has three tabs and the keys are 1, 2 and 4, which reads
    // like an off-by-one to anybody who has not read that ruling. This is
    // the test that stops the "tidy-up" — moving Schedule onto Ctrl+3
    // would break the same muscle memory twice, once now and once in v1.1
    // when the Rear Panel arrives and takes its key back.
    //
    // IT ASKS THE REGISTRY NOW, AND ASKS A STRICTER QUESTION. The old
    // version grepped `app_shell.dart` for `LogicalKeyboardKey.digit3`,
    // which could only ever speak about one file — and the schematic
    // legitimately binds a BARE `3` to solo domain 3, so a repo-wide grep
    // for the same string would have been wrong. The claim is about the
    // CHORD, `primary+3`, and it is checked across every binding in the
    // application and on every platform: on macOS the chord is `Cmd+3`,
    // and a registry that only refused `Ctrl+3` would let it in there.
    //
    // The reference row is built rather than written out, so "the chord
    // Ctrl+3 resolves to" is computed by the same code the app resolves
    // its own bindings with. A `renderChord` of `Ctrl+3` here and `Cmd+3`
    // on macOS is the proof that the sweep is per-platform and not a
    // three-times-identical loop.
    const rearPanelChord = KeyBinding(
      id: KeyBindingId.switchViewSchedule, // any id; only the chord is read
      scope: KeyScope.global,
      trigger: LogicalKeyboardKey.digit3,
      primary: true,
      label: 'the v1.1 Rear Panel view',
      intent: SwitchViewIntent(3),
      source: 'CR-071',
    );
    for (final platform in TargetPlatform.values) {
      final claimants = kKeymap.where(
        (b) => b.chordOn(platform) == rearPanelChord.chordOn(platform),
      );
      expect(
        claimants,
        isEmpty,
        reason:
            '${rearPanelChord.renderChord(platform)} on ${platform.name} is '
            'claimed by ${claimants.map((b) => b.id.name).join(', ')}. It '
            'is reserved for the v1.1 Rear Panel view and is an unbound '
            'no-op until then; the Schedule is Ctrl+4 in v1 and forever.',
      );
    }

    // The three the v1 strip DOES need, so this cannot pass by the
    // registry being empty.
    final viewSwitches = <int, KeyBindingId>{
      1: KeyBindingId.switchViewRack,
      2: KeyBindingId.switchViewSchematic,
      4: KeyBindingId.switchViewSchedule,
    };
    for (final entry in viewSwitches.entries) {
      final binding = keyBindingFor(entry.value);
      expect(
        binding.trigger.keyLabel,
        '${entry.key}',
        reason: '${entry.value.name} is the digit-${entry.key} view',
      );
      expect(binding.primary, isTrue);
    }

    // AND THE ORDINAL IS SEPARATE FROM THE IDENTITY, which is the other
    // half of the ruling and the half a registry could quietly undo. The
    // Schedule is the third TAB and the fourth KEY; a map that sent key 3
    // anywhere, or sent key 4 to index 3, would be the conflation docs/04
    // §8 forbids.
    expect(kViewKeyToTabIndex, {1: 0, 2: 1, 4: 2});
  });
}
