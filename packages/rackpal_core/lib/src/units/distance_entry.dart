// rackpal_core/src/units/distance_entry.dart — reading a distance a person
// typed (docs/15 §5, DR-144 §11.143.5, PLAN-F/1).
//
// ═══════════════════════════════════════════════════════════════════════
// A BARE NUMBER IS REFUSED, AND THAT IS THE WHOLE POINT OF THIS FILE
// ═══════════════════════════════════════════════════════════════════════
// `36` is 36 inches or 36 feet. The two differ by a factor of TWELVE, and
// the number they scale is every length the plan will ever yield. A
// guessed unit does not degrade a result the way a rounding error does: it
// produces a confident number wrong by an order of magnitude, on a drawing
// somebody is standing in a building trusting.
//
// So this parser refuses the ambiguous input and names both readings back.
// That is G4 in the one place it is cheap to break, and the refusal costs
// one keystroke.
//
// ═══════════════════════════════════════════════════════════════════════
// IT DIVERGES FROM `parseLengthCell`, DELIBERATELY, AND DR-144 SAYS SO
// ═══════════════════════════════════════════════════════════════════════
// `derived/structure_table.dart`'s length cell reads a bare number as
// WHOLE FEET and refuses everything else, including `62 ft 3`. Two parsers
// in one product disagreeing about what a bare number means is exactly the
// near-duplicate this corpus keeps finding, so §11.143.5 states the
// difference rather than leaving a reader to infer it:
//
//   * THAT column is whole feet of cable, ordered and cut in whole feet,
//     and its refusal is what keeps the stored value equal to the value
//     its own column displays.
//   * THIS field is a distance on somebody else's drawing, whose magnitude
//     is not known in advance. A door is 36 inches, a wall is 12 feet, and
//     the field cannot prefer either.
//
// The two are NOT candidates for harmonisation. A pass that unified them
// would silently give calibration a default unit, which is the defect this
// file exists to prevent.
//
// ═══════════════════════════════════════════════════════════════════════
// `displayUnits` SHAPES THE REFUSAL, NOT THE GRAMMAR
// ═══════════════════════════════════════════════════════════════════════
// An explicitly united value is unambiguous whichever system the project
// is set to, so `2.4m` is ACCEPTED on an imperial project rather than
// refused for being metric. What the unit system decides is which pair of
// readings the bare-number refusal names, and which example an unparseable
// input is offered. Refusing a united metric value would be the parser
// enforcing a preference that value has already overridden.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ARITHMETIC IS INTEGER THROUGHOUT (CR-001)
// ═══════════════════════════════════════════════════════════════════════
// Every magnitude is carried as a RATIONAL, `n/d`: `3` is `3/1`, `3.5` is
// `35/10`, `6-1/2` is `13/2`. The conversion is then
// `(n * nmPerUnit + d ~/ 2) ~/ d`, int64 from end to end, rounding half up
// on a value already known to be positive. `Len.fromInches` takes a `num`
// and would have put a `double` on this path for no benefit: the inputs a
// person types are exactly the ones a rational represents without loss.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/enums.dart';
import 'package:rackpal_core/src/units/len.dart';

/// What reading a typed distance produced.
///
/// A SEALED PAIR AND NOT `CellParse<Len>`, which is the shape beside it in
/// `derived/structure_table.dart`. `CellParsed.value` is nullable because
/// clearing a cell is a legal edit meaning UNKNOWN (G4). **Clearing is not
/// a legal calibration**: there is no scale set to unknown by typing
/// nothing, so a `CellParsed(null)` here would be a state every caller has
/// to handle and no input can produce.
sealed class DistanceEntry {
  const DistanceEntry();
}

/// The text named a distance.
@immutable
final class DistanceRead extends DistanceEntry {
  const DistanceRead(this.value);

  /// Always greater than zero: a distance of nothing spans nothing, and
  /// [parseDistanceEntry] refuses it rather than returning it.
  final Len value;

  @override
  bool operator ==(Object other) =>
      other is DistanceRead && other.value.nm == value.nm;

  @override
  int get hashCode => value.nm.hashCode;

  @override
  String toString() => 'DistanceRead(${value.nm}nm)';
}

/// The text did not name a distance, and [reason] is already worded for
/// the person who typed it.
@immutable
final class DistanceRefused extends DistanceEntry {
  const DistanceRefused(this.reason);

  final String reason;

  @override
  bool operator ==(Object other) =>
      other is DistanceRefused && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'DistanceRefused($reason)';
}

/// One unit this parser accepts, and how big it is.
///
/// DECLARED LARGEST FIRST, AND [index] IS LOAD-BEARING. A compound entry
/// must name its units largest first, so `3' 6"` reads and `6" 3'` is
/// refused; comparing indices is what enforces that, which is why this is
/// an enum and not a map. The declaration order is therefore a fact to
/// check, not a style: `inch` above `centimetre` because 25.4 mm is more
/// than 10 mm.
enum _Unit {
  metre(1000000000, _System.metric),
  foot(304800000, _System.imperial),
  inch(25400000, _System.imperial),
  centimetre(10000000, _System.metric),
  millimetre(1000000, _System.metric);

  const _Unit(this.nm, this.system);

  final int nm;
  final _System system;
}

enum _System { imperial, metric }

/// Spellings, longest first WITHIN each prefix family, so `inches` is not
/// read as `in` with `ches` left over and `mm` is not read as `m`.
const Map<String, _Unit> _spellings = {
  'millimetres': _Unit.millimetre,
  'millimeters': _Unit.millimetre,
  'millimetre': _Unit.millimetre,
  'millimeter': _Unit.millimetre,
  'centimetres': _Unit.centimetre,
  'centimeters': _Unit.centimetre,
  'centimetre': _Unit.centimetre,
  'centimeter': _Unit.centimetre,
  'metres': _Unit.metre,
  'meters': _Unit.metre,
  'metre': _Unit.metre,
  'meter': _Unit.metre,
  'inches': _Unit.inch,
  'inch': _Unit.inch,
  'feet': _Unit.foot,
  'foot': _Unit.foot,
  'mm': _Unit.millimetre,
  'cm': _Unit.centimetre,
  'ft': _Unit.foot,
  'in': _Unit.inch,
  'm': _Unit.metre,
  '"': _Unit.inch,
  "'": _Unit.foot,
};

/// Far beyond any building, and small enough that the int64 arithmetic
/// below cannot wrap however many terms an entry has.
///
/// **AN OVERFLOW GUARD AND NOT A DOMAIN RULE.** Nothing here claims to
/// know how large a plan may be; what it claims is that a typo of twenty
/// digits must refuse rather than wrap into a negative length that the
/// `total <= 0` check would then report as "more than zero" backwards.
const int _ceilingNm = 1000000000000000; // 1e15 nm, a million kilometres

/// A magnitude, as a rational, so nothing here needs a `double`.
@immutable
final class _Rational {
  const _Rational(this.n, this.d);
  final int n;
  final int d;
}

/// Token scan over an already normalised string.
class _Scan {
  _Scan(this.text);
  final String text;
  int at = 0;

  bool get done {
    _skipSpace();
    return at >= text.length;
  }

  void _skipSpace() {
    while (at < text.length && text.codeUnitAt(at) == _space) {
      at++;
    }
  }

  /// A number with an optional fraction: `12`, `12.5`, `1/2`, `6-1/2`,
  /// `6 1/2`. Null when what is at the cursor is not a number.
  _Rational? number() {
    _skipSpace();
    final start = at;
    final whole = _plainInt();
    if (whole == null) {
      at = start;
      return null;
    }

    // A DECIMAL AND A FRACTION ARE MUTUALLY EXCLUSIVE. `3.5-1/2` is not
    // anything anybody means, and accepting it would be inventing grammar
    // to avoid writing a branch.
    if (at < text.length && text.codeUnitAt(at) == _dot) {
      final dot = at;
      at++;
      var frac = 0;
      var den = 1;
      var digits = false;
      while (at < text.length && _isDigit(text.codeUnitAt(at))) {
        if (den < _ceilingNm) {
          frac = frac * 10 + (text.codeUnitAt(at) - _zero);
          den *= 10;
        }
        at++;
        digits = true;
      }
      // `3.` with nothing after: rewind to before the dot so the leftover
      // is refused rather than silently read as 3.
      if (!digits) {
        at = dot;
        return _Rational(whole, 1);
      }
      return _Rational(whole * den + frac, den);
    }

    // `6-1/2` or `6 1/2`: a whole part, a separator, a fraction.
    final afterWhole = at;
    var sepSeen = false;
    var probe = at;
    while (probe < text.length &&
        (text.codeUnitAt(probe) == _space || text.codeUnitAt(probe) == _dash)) {
      probe++;
      sepSeen = true;
    }
    if (sepSeen && probe < text.length && _isDigit(text.codeUnitAt(probe))) {
      at = probe;
      final numerator = _plainInt();
      if (numerator != null &&
          at < text.length &&
          text.codeUnitAt(at) == _slash) {
        at++;
        final den = _plainInt();
        if (den != null && den > 0) {
          return _Rational(whole * den + numerator, den);
        }
      }
      at = afterWhole;
      return _Rational(whole, 1);
    }

    // A BARE FRACTION, `1/2`: the digits already read were its numerator
    // rather than a whole part.
    if (at < text.length && text.codeUnitAt(at) == _slash) {
      at++;
      final den = _plainInt();
      if (den != null && den > 0) return _Rational(whole, den);
      at = afterWhole;
      return _Rational(whole, 1);
    }
    return _Rational(whole, 1);
  }

  /// A run of digits, CLAMPED at [_ceilingNm] so a twenty-digit typo
  /// cannot wrap the accumulator before the guard downstream sees it.
  int? _plainInt() {
    final start = at;
    var v = 0;
    var any = false;
    while (at < text.length && _isDigit(text.codeUnitAt(at))) {
      if (v < _ceilingNm) v = v * 10 + (text.codeUnitAt(at) - _zero);
      at++;
      any = true;
    }
    if (!any) {
      at = start;
      return null;
    }
    return v;
  }

  /// The unit spelling at the cursor, or null.
  _Unit? unit() {
    _skipSpace();
    for (final entry in _spellings.entries) {
      if (!text.startsWith(entry.key, at)) continue;
      final end = at + entry.key.length;
      // A WORD UNIT ENDS AT A WORD BOUNDARY, so `mister` is not read as
      // `m` with junk after it and then refused with the wrong sentence.
      // The two punctuation units need no boundary.
      if (_isAlpha(entry.key.codeUnitAt(0)) &&
          end < text.length &&
          _isAlpha(text.codeUnitAt(end))) {
        continue;
      }
      at = end;
      return entry.value;
    }
    return null;
  }

  static const int _space = 0x20;
  static const int _dot = 0x2E;
  static const int _dash = 0x2D;
  static const int _slash = 0x2F;
  static const int _zero = 0x30;

  static bool _isDigit(int c) => c >= _zero && c <= 0x39;
  static bool _isAlpha(int c) => c >= 0x61 && c <= 0x7A;
}

final RegExp _whitespace = RegExp(r'\s+');

/// Lower-cases, collapses whitespace, and maps the typographic characters
/// a word processor substitutes onto the two ASCII ones that matter.
///
/// A PRIME AND A DOUBLE PRIME ARE THE CORRECT CHARACTERS for feet and
/// inches and almost nobody types them; a smart-quote pass turns an
/// apostrophe into a right single quote. All of them map onto `'` and `"`
/// rather than being refused, because refusing there would read as the
/// parser rejecting the right answer.
String _normalise(String text) => text
    .toLowerCase()
    .replaceAll('′', "'") // prime
    .replaceAll('’', "'") // right single quotation mark
    .replaceAll('‘', "'") // left single quotation mark
    .replaceAll('″', '"') // double prime
    .replaceAll('”', '"') // right double quotation mark
    .replaceAll('“', '"') // left double quotation mark
    .replaceAll(_whitespace, ' ')
    .trim();

/// Reads a distance a person typed, in whatever unit they named.
///
/// [units] chooses the wording of a refusal and nothing else: see the file
/// header. A success is exact integer nanometres (CR-001) and is always
/// greater than zero.
DistanceEntry parseDistanceEntry(String text, UnitSystem units) {
  final imperial = units == UnitSystem.imperial;
  final t = _normalise(text);
  if (t.isEmpty) {
    return const DistanceRefused('Type the distance between the two points.');
  }

  // A LEADING MINUS IS CAUGHT HERE rather than left to the tokeniser,
  // because `-` is also the separator in `6-1/2` and a grammar accepting a
  // sign would have to disambiguate the two. There is no negative
  // distance between two points on a drawing.
  if (t.startsWith('-')) {
    return const DistanceRefused('A distance must be more than zero.');
  }

  final scan = _Scan(t);
  var total = 0;
  _Unit? previous;
  var terms = 0;

  while (!scan.done) {
    final magnitude = scan.number();
    if (magnitude == null) return _unparseable(t, imperial);
    final unit = scan.unit();
    if (unit == null) {
      // A NUMBER WITH NO UNIT. When it is the WHOLE input that is the
      // ambiguity this file exists for and it gets its own sentence; a
      // number with no unit inside a longer string is simply malformed.
      if (terms == 0 && scan.done) return _bareNumber(t, imperial);
      return _unparseable(t, imperial);
    }
    // THE SYSTEM CHECK COMES FIRST, so `5cm 3ft` is told it mixed systems
    // rather than told to reorder units it may not use together anyway.
    if (previous != null && unit.system != previous.system) {
      return const DistanceRefused(
        'Do not mix feet and inches with metric units.',
      );
    }
    if (previous != null && unit.index <= previous.index) {
      return const DistanceRefused(
        'Name the larger unit first, and each unit once, like 3\' 6".',
      );
    }
    if (magnitude.n > _ceilingNm ~/ unit.nm) return _tooLarge(t);
    previous = unit;
    terms++;
    // ROUNDED PER TERM, which is safe here and is NOT the rule
    // `PlanScale.lengthAlong` follows, because these terms are exact:
    // every denominator a drawing uses divides its unit's nanometre count
    // evenly, and a decimal is already a rational over a power of ten. The
    // half-up adjustment is for `1/3`, which nobody should type, rather
    // than for the values people do.
    total += (magnitude.n * unit.nm + magnitude.d ~/ 2) ~/ magnitude.d;
  }

  if (terms == 0) return _unparseable(t, imperial);
  if (total <= 0) {
    return const DistanceRefused('A distance must be more than zero.');
  }
  return DistanceRead(Len(total));
}

/// The refusal this file exists for, naming both readings back.
DistanceEntry _bareNumber(String text, bool imperial) => DistanceRefused(
  imperial
      ? '$text could be $text inches or $text feet. '
            'Type ${text}in or ${text}ft.'
      : '$text could be $text metres or $text millimetres. '
            'Type ${text}m or ${text}mm.',
);

DistanceEntry _unparseable(String text, bool imperial) => DistanceRefused(
  imperial
      ? '"$text" is not a distance. Type a number with its unit, '
            'like 36in or 3\' 6".'
      : '"$text" is not a distance. Type a number with its unit, '
            'like 2.4m or 900mm.',
);

DistanceEntry _tooLarge(String text) =>
    DistanceRefused('"$text" is too large to be a distance on a drawing.');
