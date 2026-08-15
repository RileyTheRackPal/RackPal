// M4-H's gate: the six tokens, and the designed parse errors.
//
// THE ARTIFACT HERE IS THE EXPANDED LIST OF LABELS, not the parse tree,
// so almost every test below asserts what a bank of ports would be
// CALLED. A test that pinned `_Sequential(pad: 2)` would survive a
// rewrite of the expander and tell nobody that HDBT OUT 1 stopped being
// HDBT OUT 01.
//
// The error group asserts three things per failure and they are the
// three a surface renders: the SPAN it underlines, the SENTENCE it
// shows, and the REPAIR chip it offers. Board #218 makes an exception
// reaching the user a failed requirement, so "it throws" is not an
// acceptable answer anywhere in this file.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

/// Parses and expands in one step, failing the test loudly if the
/// pattern did not compile. Every call site here expects success.
List<String> expandOk(String pattern, int count) {
  final parsed = parseLabelPattern(pattern);
  expect(
    parsed,
    isA<LabelPattern>(),
    reason: '"$pattern" should have parsed, and did not',
  );
  return (parsed as LabelPattern).expandAll(count);
}

LabelPatternFailure expandFail(String pattern) {
  final parsed = parseLabelPattern(pattern);
  expect(
    parsed,
    isA<LabelPatternFailure>(),
    reason: '"$pattern" should have been refused, and was not',
  );
  return parsed as LabelPatternFailure;
}

void main() {
  group('docs/06 §4.2, the six tokens', () {
    test('{n} is sequential from 1', () {
      expect(expandOk('IN {n}', 3), ['IN 1', 'IN 2', 'IN 3']);
    });

    test('{n:2} zero-pads, which is what the 13-step path types', () {
      expect(
        expandOk('HDBT OUT {n:2}', 3),
        ['HDBT OUT 01', 'HDBT OUT 02', 'HDBT OUT 03'],
      );
    });

    test('{n:2} keeps padding only where it is needed', () {
      final out = expandOk('J{n:2}', 11);
      expect(out.first, 'J01');
      expect(out[9], 'J10');
      expect(out.last, 'J11');
    });

    test('{n@k} increments every k rows', () {
      expect(
        expandOk('{n@2}', 6),
        ['1', '1', '2', '2', '3', '3'],
      );
    });

    test('{A} is the spreadsheet column sequence, past Z', () {
      final out = expandOk('{A}', 28);
      expect(out.first, 'A');
      expect(out[25], 'Z');
      expect(out[26], 'AA');
      expect(out[27], 'AB');
    });

    test('{L,R} cycles', () {
      expect(expandOk('{L,R}', 4), ['L', 'R', 'L', 'R']);
    });

    test('a literal set of any size cycles', () {
      expect(
        expandOk('{Y,Pb,Pr}', 4),
        ['Y', 'Pb', 'Pr', 'Y'],
      );
    });

    test('{rev} descends, and lands on 1 rather than 0', () {
      expect(expandOk('{rev}', 4), ['4', '3', '2', '1']);
    });
  });

  group('the composite the worked example is built from', () {
    test('ZONE {n@2} {L,R} is a whole 16-channel amp bank', () {
      // docs/06 §4.1's own row: "ZONE 1 L, ZONE 1 R, ZONE 2 L … ZONE 8 R".
      final out = expandOk('ZONE {n@2} {L,R}', 16);
      expect(out.first, 'ZONE 1 L');
      expect(out[1], 'ZONE 1 R');
      expect(out[2], 'ZONE 2 L');
      expect(out.last, 'ZONE 8 R');
      expect(out.toSet(), hasLength(16), reason: 'every label is distinct');
    });

    test('the 68-port template labels every bank distinctly', () {
      // §9.1's five patterned banks, expanded as the walkthrough types
      // them. The property that matters is that no two ports in a bank
      // share a label, because a duplicate designator is what a rear
      // panel cannot print.
      const banks = {
        'HDMI IN {n:2}': 16,
        'HDBT OUT {n:2}': 16,
        'MIRROR {n:2}': 16,
        'IR OUT {n:2}': 16,
      };
      for (final bank in banks.entries) {
        final out = expandOk(bank.key, bank.value);
        expect(out.toSet(), hasLength(bank.value), reason: bank.key);
        expect(out.first, endsWith('01'));
        expect(out.last, endsWith('16'));
      }
    });
  });

  group('a pattern with no token is legal and is not a sequence', () {
    test('a bare literal repeats', () {
      expect(expandOk('LAN', 2), ['LAN', 'LAN']);
    });

    test('and it reports itself as unsequenced', () {
      expect((parseLabelPattern('LAN') as LabelPattern).isSequenced, isFalse);
      expect(
        (parseLabelPattern('LAN {n}') as LabelPattern).isSequenced,
        isTrue,
      );
    });
  });

  group('parse errors are designed, not thrown (AC-050 / A2.4)', () {
    test('an unclosed brace underlines from the brace to the end', () {
      final f = expandFail('HDMI {n:2');
      expect(f.span, '{n:2');
      expect(f.start, 5);
      expect(f.message, 'This { is never closed.');
      expect(f.repair, 'HDMI {n:2}');
    });

    test('a stray close brace is refused rather than printed', () {
      // Being permissive here would put a literal } on a panel drawing.
      final f = expandFail('HDMI n}');
      expect(f.span, '}');
      expect(f.repair, 'HDMI n');
    });

    test('an unknown token names what IS on offer', () {
      final f = expandFail('IN {x}');
      expect(f.span, '{x}');
      expect(f.message, contains('"x" is not a pattern token'));
      expect(f.message, contains('{n}'));
      expect(f.repair, '{n}');
    });

    test('an unknown token starting with r suggests {rev}', () {
      expect(expandFail('{reverse}').repair, '{rev}');
    });

    test('an empty {} suggests the commonest token', () {
      final f = expandFail('IN {}');
      expect(f.span, '{}');
      expect(f.repair, '{n}');
    });

    test('{n:} says the width is missing', () {
      final f = expandFail('{n:}');
      expect(f.message, contains('needs a width'));
      expect(f.repair, '{n:2}');
    });

    test('a non-numeric width is refused and quoted back', () {
      final f = expandFail('{n:x}');
      expect(f.message, contains('"x"'));
      expect(f.repair, '{n:2}');
    });

    test('a zero width is refused, because it silently does nothing', () {
      expect(expandFail('{n:0}').repair, '{n:2}');
    });

    test('{n@} and {n@0} are both refused', () {
      expect(expandFail('{n@}').message, contains('needs a number'));
      // Zero would divide by zero in the expander; it is caught in the
      // parser so the failure is a sentence rather than a crash.
      expect(expandFail('{n@0}').repair, '{n@2}');
    });

    test('MODIFIERS DO NOT COMPOSE, and the refusal is deliberate', () {
      // Roadmap §2's M4 Risks names generalising this grammar as the
      // milestone's scope hazard. A parser that accepts two modifiers
      // has promised three.
      final f = expandFail('{n@2:2}');
      expect(f.message, contains('not both'));
    });

    test('an empty value in a set is refused with the set repaired', () {
      final f = expandFail('{L,}');
      expect(f.message, contains('empty value'));
      expect(f.repair, '{L}');
    });

    test('the span is always a real range into the source', () {
      for (final bad in ['HDMI {n:2', 'IN {x}', '{n:}', '{L,}', 'a}']) {
        final f = expandFail(bad);
        expect(f.start, greaterThanOrEqualTo(0));
        expect(f.end, lessThanOrEqualTo(bad.length));
        expect(f.start, lessThan(f.end), reason: 'span must be non-empty');
        expect(f.span, bad.substring(f.start, f.end));
      }
    });

    test('every repair chip itself parses', () {
      // A chip that produces a second error is worse than no chip. Only
      // whole-pattern repairs are checked; fragment repairs are the
      // token to substitute and are asserted above.
      for (final bad in ['HDMI {n:2', 'HDMI n}']) {
        final f = expandFail(bad);
        expect(
          parseLabelPattern(f.repair),
          isA<LabelPattern>(),
          reason: 'the chip for "$bad" offers "${f.repair}"',
        );
      }
    });
  });

  group('nothing in this file throws', () {
    test('a pile of malformed input all returns failures', () {
      const nasty = [
        '{',
        '}',
        '{}',
        '{{}}',
        '{n:{n}}',
        '{,}',
        '{,,}',
        '{n@-1}',
        '{n:-1}',
      ];
      for (final input in nasty) {
        expect(
          () => parseLabelPattern(input),
          returnsNormally,
          reason: '"$input" must not throw',
        );
      }
    });

    test('an empty pattern is a legal empty label', () {
      expect(expandOk('', 2), ['', '']);
    });
  });
}
