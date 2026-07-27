// int64 MICROGRAMS (CR-003). Kilograms and pounds are UnitFormatter
// display formats; neither is stored.

/// A mass stored as an exact integer count of micrograms.
///
/// `1 lb = 453 592 370 µg` exactly (CR-003).
extension type const Mass(int ug) {
  /// Sums an iterable of [Mass] with exact integer arithmetic.
  factory Mass.sum(Iterable<Mass> values) {
    var total = 0;
    for (final value in values) {
      total += value.ug;
    }
    return Mass(total);
  }

  /// A mass authored in KILOGRAMS, the unit a spec sheet is written in.
  ///
  /// THE ONLY kg→µg conversion in the system, and it exists because the
  /// hand-written one shipped wrong: every seed catalog file carried its
  /// own `Mass((v * 1_000_000).round())` — copy-pasted from the neighbouring
  /// `Len` millimetre helper, where 1e6 IS the right factor — so all 48
  /// templates stored grams and the chip strip rendered a 41.7 kg UPS as a
  /// confident `0 lb`. A local literal cannot be reviewed against the unit
  /// it converts into; a named factory next to [ugPerPound] can.
  factory Mass.fromKilograms(num kilograms) =>
      Mass((kilograms * ugPerKilogram).round());

  static const Mass zero = Mass(0);

  /// Exact micrograms per pound.
  static const int ugPerPound = 453_592_370;

  /// Exact micrograms per kilogram — `1 kg = 1e9 µg`, NOT 1e6.
  static const int ugPerKilogram = 1_000_000_000;

  Mass operator +(Mass other) => Mass(ug + other.ug);
  Mass operator -(Mass other) => Mass(ug - other.ug);
  Mass operator -() => Mass(-ug);
  Mass operator *(int factor) => Mass(ug * factor);
  bool operator <(Mass other) => ug < other.ug;
  bool operator <=(Mass other) => ug <= other.ug;
  bool operator >(Mass other) => ug > other.ug;
  bool operator >=(Mass other) => ug >= other.ug;

  Mass abs() => Mass(ug.abs());
}
