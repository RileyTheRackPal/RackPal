// The keyboard reference that ships to USERS (`docs/20-user-guide.md` §20.6),
// generated from `kKeymap` and gated against it.
//
// ═══════════════════════════════════════════════════════════════════════
// A USER-FACING KEY LIST IS THE WORST KIND OF SECOND COPY
// ═══════════════════════════════════════════════════════════════════════
// This corpus's standing rule is that a second copy of a moving fact is a
// liability, and it has been proven on the gate count, the analyzer pin,
// the test floors and three sheet counts. A hand-written key list is that
// failure aimed at somebody outside the project: when a binding moves, the
// person holding the stale copy is a tester who concludes the software is
// broken, and nobody here finds out.
//
// So the reference is GENERATED from the same registry the application
// dispatches from, and this test fails when the two disagree. The file is
// checked in rather than built on demand, because a user guide has to be
// readable from the repository without a Flutter toolchain.
//
// REGENERATION IS A DELIBERATE ACT (`byte_roundtrip_test.dart`'s rule):
// `UPDATE_GOLDENS=1 flutter test test/keymap/keymap_reference_golden_test
// .dart` rewrites it, and a plain run only ever compares.
//
// WINDOWS ONLY, AND THAT IS NOT AN OVERSIGHT. DR-009 puts macOS in v1 and
// M7 has not started, so the product ships to Windows alone today. A macOS
// table generated now would be a promise about a build nobody can run. It
// arrives with the platform.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart';

/// Relative to `packages/rackpal_ui`, which is where the suite runs from.
const String _path = '../../docs/reference/keymap-windows.md';

final bool _updateGoldens = Platform.environment['UPDATE_GOLDENS'] == '1';

void main() {
  test('the shipped keyboard reference matches the registry it came from', () {
    final expected = renderKeymapMarkdown(TargetPlatform.windows);
    final file = File(_path);

    if (_updateGoldens) {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(expected);
      return;
    }

    expect(
      file.existsSync(),
      isTrue,
      reason:
          '$_path is missing, and docs/20-user-guide.md §20.6 sends readers '
          'to it. Regenerate with UPDATE_GOLDENS=1.',
    );
    expect(
      file.readAsStringSync().replaceAll('\r\n', '\n'),
      expected.replaceAll('\r\n', '\n'),
      reason:
          'a keybinding moved and the shipped reference did not. It is '
          'GENERATED: run UPDATE_GOLDENS=1 flutter test '
          'test/keymap/keymap_reference_golden_test.dart rather than '
          'editing the markdown, which is what makes it impossible for a '
          "tester's copy to disagree with the product.",
    );
  });

  test('it covers every scope a person can reach, so no group is silently '
      'left out of the user guide', () {
    final rendered = renderKeymapMarkdown(TargetPlatform.windows);
    // THE SCOPES ARE READ OFF THE ENUM, not listed here: a scope added
    // later must either appear in the reference or fail this.
    for (final scope in KeyScope.values) {
      if (keyBindingsIn(scope).isEmpty) continue;
      expect(
        rendered,
        contains('## ${scope.name}'),
        reason: '${scope.name} has bindings and no section',
      );
    }
  });
}
