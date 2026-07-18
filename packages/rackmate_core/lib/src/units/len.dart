// int64 NANOMETRES. The load-bearing unit choice for every persisted
// length in RackMate (CR-001).

/// A length stored as an exact integer count of nanometres.
///
/// `1 in = 25 400 000 nm` · `1 U = 44 450 000 nm` · `1/32 in = 793 750 nm`
/// — all exact. That is the entire point of the type: no persisted length
/// in the file format is ever a floating-point number, so summing any
/// number of lengths — a 45U rack stack, thirty-two 1/32-inch panel gaps —
/// never accumulates rounding error (AC-001).
extension type const Len(int nm) {
  /// Sums an iterable of [Len] with exact integer arithmetic — no
  /// intermediate floating-point conversion, ever.
  factory Len.sum(Iterable<Len> values) {
    var total = 0;
    for (final value in values) {
      total += value.nm;
    }
    return Len(total);
  }

  static const Len zero = Len(0);

  /// Exact nanometres per inch.
  static const int nmPerInch = 25_400_000;

  Len operator +(Len other) => Len(nm + other.nm);
  Len operator -(Len other) => Len(nm - other.nm);
  Len operator -() => Len(-nm);
  Len operator *(int factor) => Len(nm * factor);
  bool operator <(Len other) => nm < other.nm;
  bool operator <=(Len other) => nm <= other.nm;
  bool operator >(Len other) => nm > other.nm;
  bool operator >=(Len other) => nm >= other.nm;

  Len abs() => Len(nm.abs());
}
