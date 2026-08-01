// D7's OWED GATE — board #94.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ONE THAT WAS MARKED DONE WITH NOTHING WATCHING IT
// ═══════════════════════════════════════════════════════════════════════
// M2-H replaced 43 hard-coded `SingleActivator` literals with `kKeymap`,
// whose `primary` modifier resolves to `Ctrl` or `Cmd` per platform. That
// discharged macOS debt D7. Two tests were left holding it:
//
//   * `apps/rackmate/test/session/session_layering_test.dart` RULE 14 bans
//     the constructor by scanning source — but it scans `app_shell.dart`,
//     AND NOTHING ELSE;
//   * `keymap_arbitration_test.dart` arbitrates the registry's CONTENT
//     across every `TargetPlatform` — but never reads `lib/` for literals.
//
// So the ban was enforced over ONE FILE in the app package, while EVERY
// BINDING SURFACE IN THE PRODUCT EXCEPT THE FILE MENU lives here: the rack
// canvas, the schematic canvas, three dialogs. M2-F added nine schematic
// rows (kKeymap 35 -> 44) and #93 added two more (-> 46) to the ungated
// package.
//
// docs/13 §3.5 names the next one: M3-C, the Structure editor, is "the
// largest remaining binding surface in v1, in the ungated package. If D7
// regresses anywhere, here." **This lands BEFORE M3-C rather than after,**
// because a gate added after the bindings land tells you what you already
// shipped.
//
// ═══════════════════════════════════════════════════════════════════════
// COMMENTS MUST BE STRIPPED, AND THAT IS MEASURED RATHER THAN CAUTIOUS
// ═══════════════════════════════════════════════════════════════════════
// A naive `grep 'SingleActivator('` over this package fails TODAY, on
// correct code: `rack_canvas_screen.dart` discusses the framework's
// exact-modifier semantics in prose and writes
// `SingleActivator(keyZ, control: true)` inside a comment to do it. Twenty
// mentions of the type across `lib/`, exactly ONE of them a constructor
// call — the legitimate one in `keymap.dart`. A gate that cannot tell
// those apart is a gate that gets deleted the first time it cries wolf.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strips block and line comments — `session_layering_test.dart`'s own
/// helper, ported, because this gate is the same shape as RULE 14 and
/// should fail for the same reasons in the same way.
///
/// It is deliberately NOT a Dart parser. The false-negative it admits is a
/// `//` sequence inside a string literal truncating that line, which for a
/// ban on a CONSTRUCTOR CALL cannot hide a violation: the call would have
/// to be inside the same string, where it is not code.
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
    reason: 'run from the package root; $path must exist',
  );
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Where a keystroke is ALLOWED to be constructed: the registry itself.
///
/// `KeyBinding.activatorFor` is the one place `primary` becomes a real
/// chord, which is the entire point of D7 — one answer to "Ctrl or Cmd?",
/// and it is a function of the platform.
const String _kRegistryDir = 'lib/src/keymap/';

/// Every way to build a `ShortcutActivator` by hand.
///
/// THREE, NOT ONE, and the two extra ones cost nothing to name. The board
/// item asks for `SingleActivator(`; the property being defended is
/// "no binding exists that the generated table and the arbitration cannot
/// see", and `CharacterActivator` and the older `LogicalKeySet` have that
/// same property. Neither is used in this package today — measured — so
/// adding them now is free, and the moment one appears it is a binding
/// nobody declared.
const Map<String, String> _kBannedConstructors = <String, String>{
  'SingleActivator(':
      'the chord D7 exists for: a literal here hard-codes control: true '
      'and is invisible to arbitration',
  'CharacterActivator(':
      'a character-based binding is still a binding, and the generated '
      'table cannot see it',
  'LogicalKeySet(':
      'the pre-SingleActivator API, and the one a copied Stack Overflow '
      'answer is most likely to bring back',
};

void main() {
  group('D7 — no keystroke is constructed outside the keymap registry', () {
    late final sources = _dartFilesUnder('lib');

    test('the scan reaches the files it claims to — this package is where '
        'the bindings actually are', () {
      // A SCAN THAT FOUND NOTHING BECAUSE IT LOOKED NOWHERE passes
      // silently forever, which is the failure mode this whole gate was
      // written to end. So the corpus is asserted before the ban is.
      expect(
        sources.length,
        greaterThan(30),
        reason: 'rackmate_ui had ~60 lib sources when this was written; a '
            'count this low means the walk is not reaching them',
      );
      final canvases = sources
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => p.contains('canvas/'))
          .toList();
      expect(
        canvases,
        isNotEmpty,
        reason: 'the rack and schematic canvases are the two largest '
            'binding surfaces in the product and must be in scope',
      );
    });

    test('no banned constructor appears in lib/ outside src/keymap/', () {
      final offences = <String>[];
      for (final file in sources) {
        final path = file.path.replaceAll(r'\', '/');
        if (path.contains(_kRegistryDir)) continue;
        final code = _stripComments(file.readAsStringSync());
        for (final entry in _kBannedConstructors.entries) {
          if (!code.contains(entry.key)) continue;
          offences.add('$path constructs ${entry.key} — ${entry.value}');
        }
      }
      expect(
        offences,
        isEmpty,
        reason:
            'declare a row in kKeymap and read it back with '
            'keymapShortcuts/keymapActivator. A binding built by hand is '
            'invisible to the generated table (CR-101, M7 exit criterion) '
            'and to arbitrate(), so it cannot collide with anything — '
            'which means nothing catches it when it does:\n'
            '${offences.join('\n')}',
      );
    });

    test('the registry is where the one construction lives, and it is '
        'still there', () {
      // THE OTHER HALF, and without it the ban above can be satisfied by
      // deleting the mechanism. If `activatorFor` ever stops building a
      // SingleActivator, `primary` has stopped resolving per platform and
      // D7 has regressed in the one place the ban does not look.
      final keymap = File('lib/src/keymap/keymap.dart').readAsStringSync();
      final code = _stripComments(keymap);
      expect(
        code,
        contains('SingleActivator('),
        reason: 'KeyBinding.activatorFor is the ONE place primary becomes '
            'a keystroke. A ban with nothing left to permit means the '
            'resolution went somewhere this gate is not looking.',
      );
    });

    test('comments are stripped, not matched around — the prose in this '
        'package would otherwise fail the gate', () {
      // NOT A HYPOTHETICAL. `rack_canvas_screen.dart` explains the
      // framework's exact-modifier matching and writes
      // `SingleActivator(keyZ, control: true)` in a comment to do it. This
      // asserts the trap is still present, so that if somebody "tidies"
      // the stripper away the gate fails here rather than starting to
      // report the canvas as a violation.
      final canvas = File('lib/src/canvas/rack_canvas_screen.dart')
          .readAsStringSync();
      expect(
        canvas,
        contains('SingleActivator('),
        reason: 'the prose that makes comment-stripping load-bearing has '
            'moved; if it is genuinely gone, this test can go too',
      );
      expect(
        _stripComments(canvas),
        isNot(contains('SingleActivator(')),
        reason: 'the stripper is what tells prose from code, and this is '
            'the file that proves it has to',
      );
    });
  });
}
