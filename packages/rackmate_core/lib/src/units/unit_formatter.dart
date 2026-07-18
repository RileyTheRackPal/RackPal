import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';

// Display-only conversions from the exact stored integers (Len in
// nanometres, Mass in micrograms) to the strings a human reads. Every
// method here is a pure function of the exact integer value; the double
// arithmetic happens ONLY at the last step, for formatting. The stored
// value is never touched.

/// Display formatting for [Len].
extension LenFormatting on Len {
  /// e.g. `"2.50 mm"`.
  String toMillimeters({int fractionDigits = 2}) {
    final mm = nm / 1e6;
    return '${mm.toStringAsFixed(fractionDigits)} mm';
  }

  /// Feet-inches-fraction display, e.g. `"3' 6-1/2\""`.
  ///
  /// [denominator] must be a power of two that evenly divides
  /// [Len.nmPerInch] (so up to 64); the default of 16 matches shop-drawing
  /// convention. Rounds to the nearest unit fraction — this is a display
  /// helper, not a stored value.
  String toFeetInches({int denominator = 16}) {
    assert(
      denominator > 0 && Len.nmPerInch % denominator == 0,
      'denominator must evenly divide Len.nmPerInch',
    );
    final nmPerUnit = Len.nmPerInch ~/ denominator;
    final negative = nm < 0;
    final absNm = nm.abs();
    final totalUnits = (absNm + nmPerUnit ~/ 2) ~/ nmPerUnit;
    final totalInches = totalUnits ~/ denominator;
    final remainderUnits = totalUnits % denominator;
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    final sign = negative ? '-' : '';

    if (remainderUnits == 0) {
      return "$sign$feet' $inches\"";
    }
    var fracNum = remainderUnits;
    var fracDen = denominator;
    final divisor = _gcd(fracNum, fracDen);
    fracNum ~/= divisor;
    fracDen ~/= divisor;
    return "$sign$feet' $inches-$fracNum/$fracDen\"";
  }
}

/// Display formatting for [Mass].
extension MassFormatting on Mass {
  /// e.g. `"1.00 kg"`.
  String toKilograms({int fractionDigits = 2}) {
    final kg = ug / 1e9;
    return '${kg.toStringAsFixed(fractionDigits)} kg';
  }

  /// e.g. `"1.00 lb"`.
  String toPounds({int fractionDigits = 2}) {
    final lb = ug / Mass.ugPerPound;
    return '${lb.toStringAsFixed(fractionDigits)} lb';
  }
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// Namespaced entry points mirroring the extension methods above, for
/// call sites that prefer `UnitFormatter.lenToFeetInches(len)` over the
/// dot-notation form.
class UnitFormatter {
  const UnitFormatter._();

  static String lenToMillimeters(Len len, {int fractionDigits = 2}) =>
      len.toMillimeters(fractionDigits: fractionDigits);

  static String lenToFeetInches(Len len, {int denominator = 16}) =>
      len.toFeetInches(denominator: denominator);

  static String massToKilograms(Mass mass, {int fractionDigits = 2}) =>
      mass.toKilograms(fractionDigits: fractionDigits);

  static String massToPounds(Mass mass, {int fractionDigits = 2}) =>
      mass.toPounds(fractionDigits: fractionDigits);
}
