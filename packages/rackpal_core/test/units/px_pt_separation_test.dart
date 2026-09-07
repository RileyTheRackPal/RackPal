// PLAN-C/1: the three point types stay three, enforced rather than agreed.
//
// ═══════════════════════════════════════════════════════════════════════
// A DECISION THE TYPE SYSTEM DOES NOT ENFORCE IS A COMMENT
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §3.3 and docs/02 §4.8 rule that `Pt`, `DPt` and `PxPt` are
// distinct concepts and must not be collapsed. That ruling is only worth
// its cost if it cannot be undone by somebody being helpful, and the
// helpful changes are specific and predictable: an `operator +` "so pins
// can be offset", a `toPt()` "for convenience", a shared supertype "to
// deduplicate". Each is one line, each looks like tidying, and each makes
// the mistake spellable.
//
// The behavioural half is trivial and is not what this file is for. The
// source half below is: it reads `px_pt.dart` and fails on the additions
// that would re-open the hole. `draw_source_gate_test.dart` is the
// precedent for a source-level gate over a property a running program
// cannot distinguish from its negation.
//
// WHAT A COLLAPSE ACTUALLY COSTS, so nobody reopens it as a style debate:
// a `Pt` accepted where a `PxPt` was meant does not throw. It rounds the
// pin to the schematic's 2.5 mm lattice, moves the dot by up to a grid
// unit, and the person who finds out is an installer on site looking for
// the wrong wall.

import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

String _source() {
  var dir = Directory.current;
  while (!File('${dir.path}/lib/src/units/px_pt.dart').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('could not find px_pt.dart from ${Directory.current.path}');
    }
    dir = parent;
  }
  return File('${dir.path}/lib/src/units/px_pt.dart').readAsStringSync();
}

/// The file with `//` comments removed, so the prose ABOUT these hazards
/// does not read as the hazards themselves. `import_hardening_test.dart`
/// strips comments for exactly this reason and this file discusses
/// `operator +` at length.
String _code() => _source()
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i == -1 ? line : line.substring(0, i);
    })
    .join('\n');

void main() {
  group('PxPt behaves as a plain value', () {
    test('equality is by value, and both fields carry', () {
      expect(const PxPt(3, 4), const PxPt(3, 4));
      expect(const PxPt(3, 4).hashCode, const PxPt(3, 4).hashCode);
      expect(const PxPt(3, 4), isNot(const PxPt(4, 3)));
      expect(const PxPt(3, 4), isNot(const PxPt(3, 5)));
    });

    test('it prints its own name, so a log cannot be misread as a Pt', () {
      expect(const PxPt(3, 4).toString(), 'PxPt(3, 4)');
      expect(const Pt(3, 4).toString(), 'Pt(3, 4)');
    });

    test('negative and zero coordinates are representable', () {
      // NOT a validity rule. A pin outside the image is a UI concern and
      // a model that refused it here would make an import that shifts an
      // underlay unrepresentable rather than correctable.
      expect(const PxPt(0, 0).px, 0);
      expect(const PxPt(-5, -5).py, -5);
    });
  });

  group('THE SOURCE GATE: the collapse stays a compile error', () {
    test('PxPt declares no arithmetic operator', () {
      // `Pt` has `+` and `-` because two schematic offsets compose. Two
      // positions in an image do not, and offering the operator is how a
      // caller ends up adding a grid delta to a pixel coordinate.
      expect(
        _code(),
        isNot(contains('operator +')),
        reason: 'PxPt gained arithmetic; see this file header',
      );
      expect(_code(), isNot(contains('operator -')));
    });

    test('PxPt offers no conversion to or from the other two types', () {
      for (final hazard in ['toPt', 'toDPt', 'fromPt', 'fromDPt', 'asPt']) {
        expect(
          _code(),
          isNot(contains(hazard)),
          reason: 'PxPt gained $hazard, which is the collapse in one line',
        );
      }
    });

    test('PxPt has no supertype: it implements, extends and mixes in '
        'nothing', () {
      final declaration = RegExp(
        r'final class PxPt[^{]*\{',
      ).firstMatch(_code())!.group(0)!;
      expect(declaration, isNot(contains('extends')));
      expect(declaration, isNot(contains('implements')));
      expect(declaration, isNot(contains('with')));
    });

    test('it does not mention Pt or DPt in CODE at all, only in prose', () {
      // The whole file talks about them; none of that is executable. A
      // reference in code is a dependency, and a dependency between two
      // types that must not be interchangeable is the first half of
      // making them interchangeable.
      expect(_code(), isNot(contains('DPt')));
      expect(
        RegExp(r'\bPt\b').hasMatch(_code().replaceAll('PxPt', '')),
        isFalse,
      );
    });

    test('ANTI-VACUITY: the source was actually read', () {
      // A gate whose file-finder silently returned an empty string would
      // pass every assertion above.
      expect(_source(), contains('final class PxPt'));
      expect(_source().length, greaterThan(1500));
      expect(_code(), contains('final int px;'));
    });
  });
}
