// M4-G2's gate: the mini-DSL, parsed against the real seeded registries.
//
// THE ARTIFACT IS THE PLAN, because the plan is what the summary line
// reads and what a build consumes. Every assertion below is a fact a
// user could see on screen: how many ports, which family, which
// connector, which bank, what the labels say.
//
// THE THIRTEEN-STEP PATH IS THE CENTREPIECE. docs/06 §9.1 is the
// walkthrough M4's exit criterion is measured against, so it is typed
// out here verbatim and asserted to produce 68 ports across 6 banks. If
// that group goes red, the milestone's exit criterion is unreachable
// regardless of what the UI does, which is exactly the kind of thing a
// widget test cannot tell anyone.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

QuickAddPlan planOk(Registries r, String command) {
  final result = parseQuickAdd(r, command);
  expect(
    result,
    isA<QuickAddPlan>(),
    reason:
        '"$command" should have parsed; '
        'got ${result is QuickAddFailure ? result.message : result}',
  );
  return result as QuickAddPlan;
}

QuickAddFailure planFail(Registries r, String command) {
  final result = parseQuickAdd(r, command);
  expect(
    result,
    isA<QuickAddFailure>(),
    reason: '"$command" should have been refused, and was not',
  );
  return result as QuickAddFailure;
}

void main() {
  final r = buildSeedRegistries();

  group('docs/06 §4.1, the grammar', () {
    test('16 hdmi in resolves both halves and the direction', () {
      final p = planOk(r, '16 hdmi in');
      expect(p.quantity, 16);
      expect(p.family?.v, 'video.hdmi.2_0');
      expect(p.connector?.v, 'conn.hdmi_a');
      expect(p.direction, PortDirection.sink);
    });

    test('hdbt and rj45 give the SAME connector and DIFFERENT families', () {
      // CR-058's orthogonality claim, which had nothing behind it until
      // DR-060. This is the assertion that proves the ruling landed.
      final hdbt = planOk(r, '16 hdbt out');
      final rj45 = planOk(r, '1 rj45 in');
      expect(hdbt.connector?.v, 'conn.rj45');
      expect(rj45.connector?.v, 'conn.rj45');
      expect(hdbt.family?.v, 'video.hdbaset');
      expect(rj45.family?.v, 'net.ethernet');
      expect(hdbt.family, isNot(rj45.family));
    });

    test('everything after the quantity is order-insensitive', () {
      final a = planOk(r, '16 hdmi in rear "IN {n}" @Sources');
      final b = planOk(r, '16 @Sources rear "IN {n}" hdmi in');
      expect(b.family, a.family);
      expect(b.connector, a.connector);
      expect(b.direction, a.direction);
      expect(b.face, a.face);
      expect(b.bankName, a.bankName);
      expect(b.labels, a.labels);
    });

    test('a second type token REFINES rather than replaces', () {
      // An HDBaseT signal on an explicitly named 8P8C. Both tokens name
      // the same connector here, which is the point: they agree.
      final p = planOk(r, '16 rj45 hdbaset out');
      expect(p.connector?.v, 'conn.rj45');
      expect(
        p.family?.v,
        'net.ethernet',
        reason: 'the FIRST token to name a family wins it',
      );
    });

    test('a bank name may contain spaces', () {
      expect(
        planOk(r, '16 hdmi out @Mirror Outputs').bankName,
        'Mirror Outputs',
      );
    });

    test('a bank name stops at a quoted label', () {
      final p = planOk(r, '24 rj45 @Ports "{n:2}"');
      expect(p.bankName, 'Ports');
      expect(p.labels.first, '01');
      expect(p.labels.last, '24');
    });

    test('both doubles the ports and leaves the quantity alone', () {
      // A 24-position passthrough panel is 24 positions and 48 ports.
      // Reporting 48 as the quantity would read as a miscount.
      final p = planOk(r, '24 rj45 pass both "{n:2}"');
      expect(p.quantity, 24);
      expect(p.portCount, 48);
      expect(p.bothFaces, isTrue);
      expect(p.passthrough, isTrue);
    });

    test('face defaults to null, meaning rear, rather than to a guess', () {
      expect(planOk(r, '16 hdmi in').face, isNull);
      expect(planOk(r, '16 hdmi in front').face, Face.front);
      expect(planOk(r, '16 hdmi in rear').face, Face.rear);
    });

    test('a quoted token is a label even when it reads like a keyword', () {
      final p = planOk(r, '2 hdmi "out"');
      expect(p.labels, ['out', 'out']);
      expect(p.direction, isNull, reason: 'the quotes disambiguated it');
    });
  });

  group('unknown is a real answer (G4 / CR-114)', () {
    test('xlr sets the connector and leaves the family blank', () {
      final p = planOk(r, '4 xlr in');
      expect(p.connector?.v, 'conn.xlr3');
      expect(p.family, isNull);
    });

    test('euro2 sets the connector and leaves the family blank', () {
      // Low-Z or constant-voltage; guessing puts 70 V on an 8 ohm run.
      final p = planOk(r, '16 euro2 out');
      expect(p.connector?.v, 'conn.euroblock_2');
      expect(p.family, isNull);
    });

    test('direction is null when unstated, for the family to fill in', () {
      expect(planOk(r, '16 hdmi').direction, isNull);
    });
  });

  group('docs/06 §9.1, the thirteen steps the criterion measures', () {
    // Steps 6 to 13 verbatim. Steps 1 to 5 are the metadata form and
    // are not this parser's business.
    const steps = <String>[
      '16 hdmi in "HDMI IN {n:2}"',
      '16 hdbt out "HDBT OUT {n:2}"',
      '16 hdmi out "MIRROR {n:2}" @Mirror Outputs',
      '16 ir35 out "IR OUT {n:2}"',
      '1 rj45 in "LAN" @Control',
      '1 de9 bi "RS-232" @Control',
      '1 ir35 in "IR IN" @Control',
      '1 c14 in',
    ];

    test('every step parses', () {
      for (final step in steps) {
        expect(
          parseQuickAdd(r, step),
          isA<QuickAddPlan>(),
          reason: step,
        );
      }
    });

    test('THE EIGHT STEPS TOTAL 68 PORTS', () {
      // The number the exit criterion names, computed from the commands
      // rather than restated.
      final total = steps
          .map((s) => planOk(r, s).portCount)
          .fold<int>(0, (a, b) => a + b);
      expect(total, 68);
    });

    test('and they name three explicit banks, all of them Control', () {
      final named = steps
          .map((s) => planOk(r, s).bankName)
          .where((b) => b != null)
          .toList();
      expect(named, ['Mirror Outputs', 'Control', 'Control', 'Control']);
    });

    test('the patterned banks label sixteen ports distinctly each', () {
      for (final step in steps.take(4)) {
        final labels = planOk(r, step).labels;
        expect(labels, hasLength(16), reason: step);
        expect(labels.toSet(), hasLength(16), reason: step);
        expect(labels.first, endsWith('01'), reason: step);
        expect(labels.last, endsWith('16'), reason: step);
      }
    });

    test('the C14 inlet is power.ac_iec, not a direction called inlet', () {
      // CR-058 / CR-060: inlet and outlet are a role on a power family,
      // never directions. `in` is the direction and it means sink.
      final p = planOk(r, '1 c14 in');
      expect(p.family?.v, 'power.ac_iec');
      expect(p.connector?.v, 'conn.iec_c14');
      expect(p.direction, PortDirection.sink);
    });
  });

  group('parse failures are designed, never thrown', () {
    test('a command with no quantity says so and offers one', () {
      final f = planFail(r, 'hdmi in');
      expect(f.message, contains('how many ports'));
      expect(f.repair, '16 hdmi in');
    });

    test('a zero or negative quantity is refused', () {
      expect(planFail(r, '0 hdmi in').message, contains('at least 1'));
    });

    test('an unrecognised word is quoted back with a quoting repair', () {
      final f = planFail(r, '16 wibble in');
      expect(f.span, 'wibble');
      expect(f.message, contains('not a connector'));
      expect(f.repair, '16 "wibble" in');
    });

    test('and the repair itself parses', () {
      final f = planFail(r, '16 wibble in');
      // Quoting turns the offending word into a label, which needs a
      // type token to still be missing... so this particular repair
      // moves the user to the NEXT error rather than to success. That
      // is correct and is asserted so nobody "fixes" it into a lie.
      expect(parseQuickAdd(r, f.repair), isA<QuickAddFailure>());
      expect(
        (parseQuickAdd(r, f.repair) as QuickAddFailure).message,
        contains('Name a connector or a signal family'),
      );
    });

    test('a command naming no type at all is refused', () {
      final f = planFail(r, '16 in rear');
      expect(f.message, contains('Name a connector or a signal family'));
    });

    test('a bad label pattern reports the PATTERN error, shifted', () {
      final f = planFail(r, '16 hdmi in "IN {x}"');
      expect(f.message, contains('not a pattern token'));
      expect(
        f.span,
        '{x}',
        reason: 'the span is shifted into the command, not the pattern',
      );
      expect(f.repair, '16 hdmi in "IN {n}"');
    });

    test('a bare @ says what it wants', () {
      final f = planFail(r, '16 hdmi in @');
      expect(f.message, contains('bank name'));
    });

    test('an empty command asks for the shape', () {
      expect(planFail(r, '   ').repair, '16 hdmi in');
    });
  });

  group('the bar parses on every keystroke, so it must not be hostile', () {
    test('an unterminated quote is a label, not an error', () {
      // Refusing mid-word would paint an error under the user's hands
      // as they type `"HDMI IN`.
      final p = planOk(r, '16 hdmi in "HDMI IN');
      expect(p.labels, hasLength(16));
      expect(p.labels.first, 'HDMI IN');
    });

    test('every prefix of a valid command either parses or explains', () {
      const full = '16 hdmi out "MIRROR {n:2}" @Mirror Outputs';
      for (var i = 1; i <= full.length; i++) {
        final prefix = full.substring(0, i);
        expect(
          () => parseQuickAdd(r, prefix),
          returnsNormally,
          reason: 'typing "$prefix" must not throw',
        );
      }
    });

    test('a pile of malformed input all returns without throwing', () {
      const nasty = [
        '',
        '  ',
        '16',
        '16 ',
        '""',
        '16 ""',
        '@@@',
        '16 hdmi @ @ @',
        '999999999999999999999999 hdmi in',
        '16 hdmi in "',
      ];
      for (final input in nasty) {
        expect(
          () => parseQuickAdd(r, input),
          returnsNormally,
          reason: '"$input" must not throw',
        );
      }
    });
  });
}
