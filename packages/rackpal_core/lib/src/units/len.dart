// int64 NANOMETRES. The load-bearing unit choice for every persisted
// length in RackPal (CR-001).

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

  /// A length authored in MILLIMETRES, the unit a spec sheet is written in.
  ///
  /// Named for the same reason `Mass.fromKilograms` is: the seed catalog
  /// used to carry nine copies of this conversion and nine copies of the
  /// mass one side by side, and the mass copies were wrong by 1000x for
  /// exactly as long as nobody could review the literal against its unit.
  factory Len.fromMillimetres(num millimetres) =>
      Len((millimetres * nmPerMillimetre).round());

  /// A length authored in INCHES, which is what a US installer types for a
  /// device depth.
  ///
  /// Here for the same reason as [Len.fromMillimetres] and
  /// `Mass.fromPounds`: door 1's inspector has to turn a typed `14.5` into
  /// nanometres when the project is on imperial units, and a
  /// `* 25_400_000` at the call site is a literal no reviewer can check
  /// against the unit it claims to convert.
  ///
  /// NOT for rack geometry. RU pitch and panel clearances are CR-001
  /// integer arithmetic over exact constants; this is a display-entry
  /// helper and rounds to the nearest nanometre.
  factory Len.fromInches(num inches) => Len((inches * nmPerInch).round());

  static const Len zero = Len(0);

  /// Exact nanometres per inch.
  static const int nmPerInch = 25_400_000;

  /// Exact nanometres per millimetre.
  static const int nmPerMillimetre = 1_000_000;

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
