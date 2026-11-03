// The shipped licence is the granted licence (DR-189, DR-036 §11.35.4).
//
// ═══════════════════════════════════════════════════════════════════════
// THE ONE STALE COPY IN THIS CORPUS THAT IS A LEGAL PROBLEM
// ═══════════════════════════════════════════════════════════════════════
// This repository's standing rule is that a second copy of a moving fact
// is a liability, and it has been proven on the gate count, the analyzer
// pin, the test floors and four separate counts of things. Every one of
// those went stale and produced a WRONG NUMBER.
//
// A licence is different in kind. `LICENSE` at the repository root is what
// the project grants; `apps/rackpal/assets/LICENSE` is what the running
// application shows a user through `showLicensePage`. **If those two
// drift, the product tells somebody they may do something the repository
// does not permit, or withholds something it does.**
//
// THE COPY EXISTS BECAUSE FLUTTER LEAVES NO CHOICE, and that was measured
// rather than assumed: an asset entry of `../../LICENSE` was tried first
// and `rootBundle.loadString` throws on it, because asset paths cannot
// escape the package directory. So the copy is mandatory and this gate is
// what makes it safe.
//
// **BYTE-FOR-BYTE, NOT "CONTAINS".** A licence that is nearly the licence
// is not the licence. Line endings are normalised because git may check
// the two out differently, and nothing else is.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Relative to `apps/rackpal`, which is where this suite runs from.
const String _shipped = 'assets/LICENSE';
const String _granted = '../../LICENSE';

String _read(String path) {
  final file = File(path);
  expect(
    file.existsSync(),
    isTrue,
    reason:
        '$path is missing. DR-036 §11.35.4 requires the licence to be '
        'findable; DR-189 §11.188.5 records that it was absent for six '
        'weeks after it was ruled.',
  );
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  test('the licence the app SHOWS is the licence the repository GRANTS', () {
    expect(
      _read(_shipped),
      _read(_granted),
      reason:
          'assets/LICENSE and the root LICENSE have diverged. The app '
          'would now show a user terms the project does not grant. Copy '
          'the root file over the asset; do not edit the asset.',
    );
  });

  test('and it really is the AGPL, not the GPL it replaced (DR-189)', () {
    final text = _read(_granted);
    expect(
      text,
      contains('GNU AFFERO GENERAL PUBLIC LICENSE'),
      reason: 'DR-189 §11.188.1 rules AGPLv3-or-later',
    );
    expect(
      text,
      contains('13. Remote Network Interaction'),
      reason:
          'the clause that distinguishes AGPL from GPL. Without it the '
          'file is the licence this ruling moved AWAY from, which a '
          'title line alone cannot tell you',
    );
  });

  test('THE OUTPUT EXCEPTION IS PRESENT AND IS MARKED NOT IN FORCE, so the '
      'repository and the About box cannot disagree', () {
    // At the repository root until DR-259 moved it to docs/, so that a
    // draft at the root could not be read as part of the licence.
    final exception = File('../../docs/proposed-output-exception.md');
    expect(
      exception.existsSync(),
      isTrue,
      reason: 'DR-036 §11.35.4 requires the exception to be findable',
    );
    final text = exception.readAsStringSync();
    expect(
      text,
      contains('NOT IN FORCE'),
      reason:
          'DR-189 §11.188.6 sends this text to a qualified reviewer, before '
          'v1.0 since DR-259. The About box says the same thing, and a '
          'banner removed here without the dialog changing would leave '
          'the product and the repository making different claims. When '
          'counsel signs it off, BOTH change in one commit.',
    );
  });
}
