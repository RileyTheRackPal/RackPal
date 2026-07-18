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

  static const Mass zero = Mass(0);

  /// Exact micrograms per pound.
  static const int ugPerPound = 453_592_370;

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
