// Belt to `@internal`'s braces (AC-013). This is a mechanical grep, not a
// full parser: it finds every `@internal`-annotated setter defined under
// lib/src/model/, then asserts no file outside src/model/ and
// src/commands/ contains a plausible call-site for that setter (a
// `.<name> =` assignment that isn't `==`, `!=`, `=>`, or `+=`/`-=`/etc.).
// False negatives are acceptable for a first pass; false positives that
// would make the test flaky are not, so the assignment regex is
// deliberately narrow.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('entity setters are called only from src/commands/', () {
    final modelDir = Directory('lib/src/model');
    final internalSetterPattern = RegExp(
      r'@internal\s*\n\s*set\s+(\w+)\s*\(',
    );

    final setterNames = <String>{};
    for (final f in modelDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final contents = f.readAsStringSync();
      for (final m in internalSetterPattern.allMatches(contents)) {
        setterNames.add(m.group(1)!);
      }
    }

    expect(
      setterNames,
      isNotEmpty,
      reason:
          'no @internal setters found under lib/src/model/ — did the '
          'AC-013 retrofit regress, or did the detection regex above '
          'stop matching the current setter syntax?',
    );

    // Files outside src/model/ and src/commands/ that a setter call must
    // not appear in.
    final otherFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final p = f.path.replaceAll(r'\', '/');
          return !p.contains('/src/model/') &&
              !p.contains('/src/commands/');
        });

    for (final name in setterNames) {
      // Matches `.<name> =` but not `==`, `!=`, `=>`, or compound
      // assignment operators (`+=`, `-=`, etc.) — those aren't plain
      // setter-call assignments.
      final callSite = RegExp(
        '\\.$name\\s*=(?![=>])',
      );
      // Compound assignment (`+=`, `-=`, ...) also isn't a plain setter
      // call; guard against it by checking the character immediately
      // preceding the matched `=`.
      for (final f in otherFiles) {
        final contents = f.readAsStringSync();
        for (final m in callSite.allMatches(contents)) {
          final eqIndex = contents.indexOf('=', m.start);
          final before = contents.substring(0, eqIndex);
          final trimmed = before.trimRight();
          final precedingChar =
              trimmed.isEmpty ? '' : trimmed[trimmed.length - 1];
          const compoundOps = {
            '+',
            '-',
            '*',
            '/',
            '%',
            '&',
            '|',
            '^',
            '~',
            '?',
          };
          if (compoundOps.contains(precedingChar)) continue;
          fail(
            'possible external call to @internal setter "$name" in '
            '${f.path}: ${m.group(0)}',
          );
        }
      }
    }
  });
}
