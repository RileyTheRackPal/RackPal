// PLAN-F/1: reading a distance a person typed (DR-144 §11.143.5).
//
// ═══════════════════════════════════════════════════════════════════════
// THE ASSERTION THAT MATTERS IS A REFUSAL, WHICH IS UNUSUAL AND IS WHY
// ═══════════════════════════════════════════════════════════════════════
// Most parser tests here are about what a grammar accepts. The load-bearing
// case in this file is `36`, which is refused: it is 36 inches or 36 feet,
// the two differ by twelve, and the number they scale is every length the
// plan will ever yield. A parser that quietly picked one would pass every
// acceptance case below and be wrong by an order of magnitude on the input
// people actually type.
//
// The refusal is asserted by its TEXT and not merely by its type, because
// the sentence is the whole remedy: a refusal that did not name both
// readings would leave the person retyping the same thing.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

Len _read(String text, [UnitSystem units = UnitSystem.imperial]) {
  final result = parseDistanceEntry(text, units);
  expect(
    result,
    isA<DistanceRead>(),
    reason:
        '$text was refused: '
        '${result is DistanceRefused ? result.reason : ''}',
  );
  return (result as DistanceRead).value;
}

String _refusal(String text, [UnitSystem units = UnitSystem.imperial]) {
  final result = parseDistanceEntry(text, units);
  expect(result, isA<DistanceRefused>(), reason: '$text was accepted');
  return (result as DistanceRefused).reason;
}

void main() {
  group('a bare number is refused, and the sentence names both readings', () {
    test('imperial: 36 could be inches or feet', () {
      final reason = _refusal('36');
      expect(reason, contains('36 inches'));
      expect(reason, contains('36 feet'));
      expect(reason, contains('36in'));
      expect(reason, contains('36ft'));
    });

    test('metric: 2.4 could be metres or millimetres', () {
      final reason = _refusal('2.4', UnitSystem.metric);
      expect(reason, contains('2.4 metres'));
      expect(reason, contains('2.4 millimetres'));
    });

    test('a decimal and a fraction are refused the same way', () {
      expect(_refusal('36.5'), contains('36.5 inches'));
      expect(_refusal('1/2'), contains('1/2 inches'));
    });
  });

  group('imperial forms', () {
    test('inches, in every spelling', () {
      const expected = 36 * Len.nmPerInch;
      for (final text in ['36"', '36in', '36 in', '36 inch', '36 inches']) {
        expect(_read(text).nm, expected, reason: text);
      }
    });

    test('feet, in every spelling', () {
      const expected = 3 * 12 * Len.nmPerInch;
      for (final text in ["3'", '3ft', '3 ft', '3 foot', '3 feet']) {
        expect(_read(text).nm, expected, reason: text);
      }
    });

    test('feet and inches together, spaced or not', () {
      const expected = 42 * Len.nmPerInch;
      for (final text in ["3' 6\"", "3'6\"", '3ft 6in', '3ft6in']) {
        expect(_read(text).nm, expected, reason: text);
      }
    });

    test('a decimal is exact, not approximated through a double', () {
      expect(_read('3.5ft').nm, 42 * Len.nmPerInch);
      expect(_read('0.5in').nm, Len.nmPerInch ~/ 2);
    });

    test('a fraction, which is what a shop drawing is written in', () {
      expect(_read('6-1/2"').nm, (13 * Len.nmPerInch) ~/ 2);
      expect(_read('6 1/2"').nm, (13 * Len.nmPerInch) ~/ 2);
      expect(_read('1/2"').nm, Len.nmPerInch ~/ 2);
    });

    test('THE OUTPUT OF toFeetInches PARSES BACK, which is the round trip '
        'a person performs by reading the screen and retyping it', () {
      // `toFeetInches` is what every length in this product is displayed
      // as. A parser that could not read its own product's display form
      // would refuse the string the user is copying.
      for (final nm in [
        42 * Len.nmPerInch,
        (13 * Len.nmPerInch) ~/ 2,
        (3 * 12 * Len.nmPerInch) + (13 * Len.nmPerInch) ~/ 2,
        36 * Len.nmPerInch,
      ]) {
        final shown = Len(nm).toFeetInches();
        expect(_read(shown).nm, nm, reason: shown);
      }
    });
  });

  group('metric forms', () {
    test('every unit and spelling', () {
      expect(_read('2.4m', UnitSystem.metric).nm, 2400000000);
      expect(_read('2.4 metres', UnitSystem.metric).nm, 2400000000);
      expect(_read('2400mm', UnitSystem.metric).nm, 2400000000);
      expect(_read('240cm', UnitSystem.metric).nm, 2400000000);
      expect(_read('2400 millimeters', UnitSystem.metric).nm, 2400000000);
    });

    test('compound, largest first', () {
      expect(_read('1m 20cm', UnitSystem.metric).nm, 1200000000);
    });
  });

  group('the unit system chooses the wording and NOT the grammar', () {
    test('a metric value is accepted on an imperial project', () {
      // DR-144 §11.143.5: an explicitly united value is unambiguous
      // whichever system the project is set to, and refusing it would be
      // the parser enforcing a preference the value has overridden.
      expect(_read('2.4m').nm, 2400000000);
    });

    test('an imperial value is accepted on a metric project', () {
      expect(_read('36in', UnitSystem.metric).nm, 36 * Len.nmPerInch);
    });
  });

  group('refusals other than the ambiguous one', () {
    test('empty', () {
      expect(_refusal(''), contains('Type the distance'));
      expect(_refusal('   '), contains('Type the distance'));
    });

    test('zero and negative', () {
      expect(_refusal('0ft'), contains('more than zero'));
      expect(_refusal('0"'), contains('more than zero'));
      expect(_refusal('-3ft'), contains('more than zero'));
    });

    test('units named out of order, or twice', () {
      expect(_refusal('6" 3\''), contains('larger unit first'));
      expect(_refusal("3' 3'"), contains('larger unit first'));
    });

    test('systems mixed', () {
      expect(_refusal("3' 20mm"), contains('mix feet and inches'));
    });

    test('nonsense, with an example in the units of the open project', () {
      expect(_refusal('over there'), contains('is not a distance'));
      expect(_refusal('over there'), contains('36in'));
      expect(
        _refusal('over there', UnitSystem.metric),
        contains('2.4m'),
      );
    });

    test('a number with no unit INSIDE a longer string is malformed rather '
        'than ambiguous', () {
      // `3 6` is not one number with an unnamed unit, so it does not get
      // the two-readings sentence: there is no pair of readings to name.
      expect(_refusal('3 6'), contains('is not a distance'));
      expect(_refusal("3' 6"), contains('is not a distance'));
    });

    test('a trailing decimal point does not silently read as the whole', () {
      expect(_refusal('3.ft'), contains('is not a distance'));
    });

    test('a word beginning with a unit spelling is not read as that unit', () {
      // `mister` must not parse as `m` plus junk, which would refuse with
      // the wrong sentence at best and accept at worst.
      expect(_refusal('3 mister'), contains('is not a distance'));
    });

    test('an absurd magnitude refuses rather than wrapping int64', () {
      // AN OVERFLOW GUARD, not a claim about how large a plan may be. A
      // wrapped multiply could land positive and be reported as a real
      // length.
      final reason = _refusal('99999999999999999999999ft');
      expect(reason, contains('too large'));
    });
  });

  group('typography a word processor substitutes', () {
    test('primes and smart quotes read as feet and inches', () {
      const expected = 42 * Len.nmPerInch;
      expect(_read('3′ 6″').nm, expected);
      expect(_read('3’ 6”').nm, expected);
    });

    test('a non-breaking space is still a space', () {
      expect(_read('3 ft').nm, 3 * 12 * Len.nmPerInch);
    });
  });

  group('the result type', () {
    test('a read carries a value and refuses to be null', () {
      final result = parseDistanceEntry('36in', UnitSystem.imperial);
      expect(result, isA<DistanceRead>());
      expect((result as DistanceRead).value.nm, greaterThan(0));
    });

    test('equality is by value, so a case can compare two parses', () {
      expect(
        parseDistanceEntry('36in', UnitSystem.imperial),
        parseDistanceEntry("3'", UnitSystem.imperial),
      );
      expect(
        parseDistanceEntry('36', UnitSystem.imperial),
        parseDistanceEntry(' 36 ', UnitSystem.imperial),
      );
    });
  });
}
