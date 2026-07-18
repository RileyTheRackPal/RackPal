// Parts per thousand (CR-001). Power factor, line weight, slack,
// diversity, waste factor — anywhere the model needs a fractional factor
// without floating point.

/// An integer parts-per-thousand factor.
extension type const Permille(int v) {
  static const Permille zero = Permille(0);
  static const Permille whole = Permille(1000);

  Permille operator +(Permille other) => Permille(v + other.v);
  Permille operator -(Permille other) => Permille(v - other.v);
  bool operator <(Permille other) => v < other.v;
  bool operator <=(Permille other) => v <= other.v;
  bool operator >(Permille other) => v > other.v;
  bool operator >=(Permille other) => v >= other.v;

  /// Display-only fraction, e.g. `650‰ -> 0.65`. Never used for stored
  /// values — the stored value is always the exact integer.
  double toFraction() => v / 1000;
}
