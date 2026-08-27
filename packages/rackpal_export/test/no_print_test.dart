// The gate rackpal_export did not have, and the hole that proved it was
// needed.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY THIS FILE EXISTS
// ─────────────────────────────────────────────────────────────────────────
// `rackpal_ui` and `apps/rackpal` both carry a `no_print_test.dart`.
// `rackpal_export` carried none — and two assertion-free scratch files
// (`zz_scratch_dump_test.dart`, `zz_probe_test.dart`) sat in this
// directory and ran as part of `dart test`, doing nothing but `print`.
// Three of the package's reported "passing" tests contained no `expect` of
// any kind. `print` is how they did their work, so a print gate is exactly
// what would have caught them, and the package did not have one.
//
// ─────────────────────────────────────────────────────────────────────────
// IT COVERS test/ AS WELL AS lib/, WHICH IS THE WHOLE POINT
// ─────────────────────────────────────────────────────────────────────────
// The two sibling gates scan `lib/` only, on the argument that `print` is
// a shipping defect. That argument is right about shipping and wrong about
// what happened here: the escape was in `test/`. A `print` in a test is a
// debugging session someone forgot to finish — it writes to the same
// console the runner uses, and it is the tell-tale of an assertion that was
// never written. So both trees are scanned.
//
// ─────────────────────────────────────────────────────────────────────────
// AND A TEST THAT CANNOT FAIL IS CAUGHT DIRECTLY
// ─────────────────────────────────────────────────────────────────────────
// The print gate catches the scratch files this time because printing is
// what they did. A silent one would still walk through, so the second test
// below states the property that was actually violated: a file named
// `*_test.dart` asserts something.

import 'dart:io';

import 'package:test/test.dart';

import 'support/source_gate.dart';

void main() {
  test('nothing in rackpal_export calls print — lib OR test', () {
    final offenders = <String>[];
    var scanned = 0;
    for (final dir in <String>['lib', 'test']) {
      for (final f in dartFilesUnder(dir)) {
        scanned++;
        final lines = stripComments(f.readAsStringSync()).split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (callsPrint(lines[i])) {
            offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }

    // Guards the guard, the way both sibling gates do.
    expect(scanned, greaterThan(10));
    expect(offenders, isEmpty, reason: offenders.join('\n'));
    // ...and the two trees really were BOTH walked, which is the whole
    // difference between this gate and its siblings.
    expect(dartFilesUnder('lib'), isNotEmpty);
    expect(dartFilesUnder('test'), isNotEmpty);
  });

  test('EVERY *_test.dart file asserts something', () {
    // `zz_scratch_dump_test.dart` had two tests and zero `expect` calls;
    // `zz_probe_test.dart` had one test and zero. They could not fail, and
    // they padded the green count by three. A file that runs under the test
    // runner and never asserts is not a test, whatever it is named.
    final assertionless = <String>[];
    var scanned = 0;
    for (final f in dartFilesUnder('test')) {
      if (!f.path.endsWith('_test.dart')) continue;
      scanned++;
      if (!callsExpect(f.readAsStringSync())) assertionless.add(f.path);
    }

    expect(scanned, greaterThan(5), reason: 'no test files were scanned');
    expect(
      assertionless,
      isEmpty,
      reason:
          'these run as tests and cannot fail:\n${assertionless.join('\n')}',
    );
  });

  test('the scanners are not vacuous — they DO fire on the shapes they '
      'are about', () {
    // Without this, a `stripComments` that returned the empty string, or a
    // pattern that matched nothing at all, would make both gates above
    // pass on any repository whatsoever.
    expect(
      callsPrint(
        'void main() { ${'pri'
            'nt'}(1); }',
      ),
      isTrue,
    );
    expect(
      callsExpect(
        'test("x", () { ${'expe'
            'ct'}(1, 1); });',
      ),
      isTrue,
    );
    // ...and they are not so eager that an identifier trips them.
    expect(callsPrint('final _printCall = 1;'), isFalse);
    expect(
      callsPrint(
        '// a comment that says ${'pri'
            'nt'}(x)',
      ),
      isFalse,
    );
    expect(callsExpect('final unexpected = 1;'), isFalse);
    // The gate file this package needed and did not have is itself scanned
    // by the two tests above, so it must survive its own rules.
    expect(File('test/no_print_test.dart').existsSync(), isTrue);
  });
}
