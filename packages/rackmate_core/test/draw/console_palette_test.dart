// DR-090, canon §11.89. These turn the ruling's numbers into a gate.
//
// A palette written down in a document is a palette that drifts, and this
// corpus has already paid for that four times in a week. Every figure DR-090
// quotes is recomputed here from `contrast.dart`, which is the project's ONE
// definition of relative luminance (DR-080 §11.79.4), so the ruling and the
// constants cannot disagree without something failing.
//
// The interesting case is §11.89.6, which cannot be tested here at all: "hue
// is never the only cue" is a property of a WIDGET, not of a colour, and no
// assertion over ARGB integers can see it. It is named in the last group so
// that its absence is deliberate rather than an oversight, and #770 carries
// the display-list gate that could actually check it.

import 'dart:math' as math;

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

/// WCAG contrast ratio, from the project's single luminance definition.
double _contrast(int a, int b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// CIE76 dE*ab. Used only to assert that two tokens are TELLABLE APART,
/// which a contrast ratio cannot answer: two colours can share a luminance
/// and differ wildly, or differ in luminance and still read as one hue.
double _deltaE(int a, int b) {
  List<double> lab(int argb) {
    double lin(int c) {
      final v = c / 255.0;
      return v <= 0.04045
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4) as double;
    }

    final r = lin((argb >> 16) & 0xFF);
    final g = lin((argb >> 8) & 0xFF);
    final b = lin(argb & 0xFF);
    final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
    double f(double t) =>
        t > 0.008856 ? math.pow(t, 1 / 3) as double : 7.787 * t + 16 / 116;
    final fx = f(x);
    final fy = f(y);
    final fz = f(z);
    return <double>[116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
  }

  final p = lab(a);
  final q = lab(b);
  var sum = 0.0;
  for (var i = 0; i < 3; i++) {
    sum += (p[i] - q[i]) * (p[i] - q[i]);
  }
  return math.sqrt(sum);
}

void main() {
  group('AA on Card, the darkest surface text sits on', () {
    test('every live text tier clears 4.5:1', () {
      for (final (name, argb) in <(String, int)>[
        ('Primary', kConsolePrimaryText),
        ('Control', kConsoleControlText),
        ('Active', kConsoleActive),
        ('Secondary', kConsoleSecondaryText),
        ('Non-critical', kConsoleNonCriticalText),
      ]) {
        expect(
          _contrast(argb, kConsoleCard),
          greaterThanOrEqualTo(4.5),
          reason: '$name fails AA on Card',
        );
      }
    });

    test('the two disabled tokens are BELOW it, and deliberately', () {
      // WCAG exempts disabled controls, and a disabled label that measured
      // like a live one would stop reading as disabled. If either of these
      // ever clears 4.5 the tier has lost its job.
      expect(_contrast(kConsoleInactiveInk, kConsoleCard), lessThan(4.5));
      expect(_contrast(kConsoleInactiveSurface, kConsoleCard), lessThan(2.0));
    });
  });

  group('the token set, not the tokens', () {
    test('Secondary and Non-critical are tellable apart', () {
      // The failure this pins: lightening both to the AA floor left them
      // dE 0.87, below the just-noticeable difference, which is one colour
      // wearing two names. Each token passed its own constraint.
      expect(
        _deltaE(kConsoleSecondaryText, kConsoleNonCriticalText),
        greaterThan(3.0),
      );
    });

    test('Non-critical stays the brighter of the two, as specified', () {
      expect(
        relativeLuminance(kConsoleNonCriticalText),
        greaterThan(relativeLuminance(kConsoleSecondaryText)),
      );
    });
  });

  group('the status ladder', () {
    test('is in ascending greyscale luminance', () {
      for (var i = 1; i < kConsoleStatusLadder.length; i++) {
        expect(
          relativeLuminance(kConsoleStatusLadder[i]),
          greaterThan(relativeLuminance(kConsoleStatusLadder[i - 1])),
          reason: 'entry $i is out of order',
        );
      }
    });

    test('separates by at least PAL-1 floor of 0.10 at every step', () {
      for (var i = 1; i < kConsoleStatusLadder.length; i++) {
        final gap =
            relativeLuminance(kConsoleStatusLadder[i]) -
            relativeLuminance(kConsoleStatusLadder[i - 1]);
        expect(gap, greaterThanOrEqualTo(0.10), reason: 'gap $i is $gap');
      }
    });

    test('only CRITICAL takes light ink', () {
      // Asserted through `prefersLightInk` rather than restated, so the
      // palette cannot disagree with the function the renderer uses.
      expect(prefersLightInk(kConsoleCritical), isTrue);
      for (final argb in <int>[
        kConsoleWarning,
        kConsoleCaution,
        kConsoleNotice,
        kConsoleNominal,
      ]) {
        expect(prefersLightInk(argb), isFalse);
      }
    });

    test('CRITICAL is a fill and never ink', () {
      expect(_contrast(kConsoleCritical, kConsoleCard), lessThan(4.5));
      expect(
        _contrast(kConsoleControlText, kConsoleCritical),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('what is NOT tested here', () {
    test('the second-cue rule is a widget property, not a colour one', () {
      // §11.89.6 says a status marker must carry a cue that survives its
      // colour being deleted. Nothing in this file can see a marker. The
      // check belongs on the display list and is #770's.
      expect(kConsoleStatusLadder, hasLength(5));
    });
  });
}
