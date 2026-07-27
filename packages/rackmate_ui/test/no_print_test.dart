// A source-level gate: no `print` in shipped `rackmate_ui` code.
//
// Same shape, and the same reason, as `rackmate_core`'s
// `no_flutter_import_test.dart` — a rule that only lives in a review
// checklist is a rule that gets broken. Eight `print` calls shipped into
// committed code under `canvas/schematic/`, `schedule/` and
// `staging_bin_overlay.dart` before this test existed, alongside a debug
// border and a constraint dump, and nothing in the build objected. The
// `avoid_print` lint DID fire on every one of them; it fires at INFO, in a
// project that carries 211 of those by design, so it was invisible. This
// fails the build instead.
//
// Scope is `lib/` only. Tests may print.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches `print(` / `debugPrint(` as a CALL, not as a substring of a
/// longer identifier (`sprint(`, `blueprint(`, `pdfPrint(` are all fine),
/// and not `.print(` on some object of the user's own.
final _printCall = RegExp(r'(?<![\w.$])(print|debugPrint)\s*\(');

/// Strips `//` line comments and `/* */` block comments, so a header that
/// DESCRIBES the rule — like this file's own subject, or the comment in
/// `unbuilt_view.dart` explaining what was removed — is not a violation.
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

void main() {
  test('no print() survives anywhere in rackmate_ui/lib', () {
    final lib = Directory('lib');
    expect(
      lib.existsSync(),
      isTrue,
      reason: 'run from the package root, where lib/ is',
    );

    final offenders = <String>[];
    var scanned = 0;
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      scanned++;
      final lines = _stripComments(entity.readAsStringSync()).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (_printCall.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    // Guards the guard: a scan that found no files would pass vacuously.
    expect(scanned, greaterThan(10));
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
