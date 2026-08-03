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
    for (final f
        in modelDir
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
    //
    // SCANS rackmate_ui TOO. Until the rack-configuration stage the UI had
    // no reason to touch a `Rack` setter, and this test only ever looked
    // at rackmate_core/lib — so `@internal` plus the analyzer was the ONLY
    // thing standing between the inspector and a dozen direct field
    // writes that would bypass the command system entirely. A whole panel
    // of editable fields is exactly the wrong place to rely on a lint
    // nobody has to look at.
    //
    // The sibling path is resolved relative to this package's CWD and
    // guarded, so the test degrades to core-only rather than failing if
    // the workspace layout ever moves. That is a real trade-off: it will
    // stop protecting anything silently. Worth revisiting if the packages
    // are ever rearranged.
    final scanRoots = <Directory>[
      Directory('lib'),
      Directory('../rackmate_ui/lib'),
    ].where((d) => d.existsSync()).toList();

    expect(
      scanRoots.length,
      2,
      reason:
          'expected to scan both rackmate_core/lib and '
          '../rackmate_ui/lib; found ${scanRoots.map((d) => d.path)}. If '
          'the workspace layout changed, update this path — otherwise the '
          'UI package silently stops being checked.',
    );

    final otherFiles = scanRoots
        .expand((d) => d.listSync(recursive: true))
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final p = f.path.replaceAll(r'\', '/');
          return !p.contains('/src/model/') && !p.contains('/src/commands/');
        })
        .toList();

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
          final precedingChar = trimmed.isEmpty
              ? ''
              : trimmed[trimmed.length - 1];
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
          // `this.<name> = ...` is an INITIALIZING FORMAL with a default
          // value in a constructor parameter list, not a setter call —
          // e.g. `RackPreset({this.isSwingFrame = false})`. The grep
          // matches by setter NAME across every model type, so any value
          // class anywhere in the package that happens to share a field
          // name with an @internal setter would otherwise trip it.
          //
          // Safe to skip wholesale in THIS workspace: `unnecessary_this`
          // is enabled by very_good_analysis 9.0.0 (analysis_options
          // line 194), so an explicit `this.x = v` in a method body is a
          // lint failure and cannot exist here. Were that lint ever
          // disabled, this exclusion would start hiding real call sites.
          if (contents.startsWith('this', m.start - 4 < 0 ? 0 : m.start - 4) &&
              m.start >= 4) {
            continue;
          }
          fail(
            'possible external call to @internal setter "$name" in '
            '${f.path}: ${m.group(0)}',
          );
        }
      }
    }
  });
}
