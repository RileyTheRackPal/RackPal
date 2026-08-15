// THE LABEL PATTERN LANGUAGE (M4-H, docs/06 §4.2), AND ITS DESIGNED
// PARSE ERRORS.
//
// ═════════════════════════════════════════════════════════════════════
// SIX TOKENS, AND SIX IS THE SPECIFICATION RATHER THAN A STARTING POINT
// ═════════════════════════════════════════════════════════════════════
// Roadmap §2's M4 Risks names generalising this grammar as THE SCOPE
// HAZARD OF THE MILESTONE, in those words, and board #179 repeats it.
// So the parser below REFUSES what it does not document rather than
// falling back to something plausible. `{n@2:2}` is not "padding plus
// grouping", it is an error with a message, because the moment two
// modifiers compose, someone reasonably expects three to.
//
// The six: `{n}` sequential, `{n:2}` zero-padded, `{n@k}` increment
// every k, `{A}` alpha, `{L,R}` cycling literal set, `{rev}` descending.
//
// ═════════════════════════════════════════════════════════════════════
// PARSE ERRORS ARE DESIGNED, NOT THROWN (AC-050 / A2.4)
// ═════════════════════════════════════════════════════════════════════
// "An exception reaching the user is a failed requirement, not a bug"
// (board #218). [parseLabelPattern] therefore returns a RESULT rather
// than throwing: either a compiled [LabelPattern] or a
// [LabelPatternFailure] carrying the offending SPAN, a one-line
// explanation, and a suggested repair the surface renders as a chip.
//
// The span is a character range into the ORIGINAL string, so the bar can
// underline exactly what it is complaining about. An error that says
// "invalid pattern" and highlights nothing is the failure mode this
// class exists to avoid.
//
// ═════════════════════════════════════════════════════════════════════
// WHY EXPANSION TAKES A COUNT AND NOT ONLY AN INDEX
// ═════════════════════════════════════════════════════════════════════
// `{rev}` is descending: docs/06 §4.2's own example is 16, 15, 14 for a
// sixteen-port bank. A descending sequence cannot be computed from a
// row's index alone, it needs to know how many rows there are. Passing
// the count to every expansion keeps the signature uniform instead of
// making one token special.

import 'package:meta/meta.dart';

/// A parsed label pattern, or the reason it could not be parsed.
@immutable
sealed class LabelPatternResult {
  const LabelPatternResult();
}

/// One compiled pattern, ready to expand for each row of a Quick Add.
@immutable
final class LabelPattern extends LabelPatternResult {
  const LabelPattern(this.source, this._parts);

  /// The pattern as the user typed it, kept so a surface can round-trip
  /// what it was given rather than a re-rendering of it.
  final String source;

  final List<_Part> _parts;

  /// True when the pattern varies by row. A pattern with no tokens
  /// produces the same string for every port, which is legal (a bank of
  /// identical `SPEAKER` labels) but is worth a caller knowing about:
  /// the Quick Add summary line says "16 ports named SPEAKER" rather
  /// than implying a sequence.
  bool get isSequenced => _parts.any((p) => p is! _Literal);

  /// Expands for one row. [index] is zero-based; [count] is how many
  /// rows the whole add will produce, which only `{rev}` reads.
  ///
  /// [start] and [step] seed `{n}` and `{n@k}`. They default to the
  /// values docs/06 §4.2's table assumes and are parameters rather than
  /// constants because Quick Add's field mode will expose them.
  String expand(int index, int count, {int start = 1, int step = 1}) {
    final out = StringBuffer();
    for (final part in _parts) {
      out.write(part.render(index, count, start, step));
    }
    return out.toString();
  }

  /// Expands every row at once, which is what a Quick Add commit wants.
  List<String> expandAll(int count, {int start = 1, int step = 1}) => [
    for (var i = 0; i < count; i++) expand(i, count, start: start, step: step),
  ];
}

/// A pattern that did not parse, with everything a surface needs to
/// explain itself: WHERE, WHAT, and WHAT TO DO.
///
/// Returned by `parseLabelPattern`, never thrown.
@immutable
final class LabelPatternFailure extends LabelPatternResult {
  const LabelPatternFailure({
    required this.source,
    required this.start,
    required this.end,
    required this.message,
    required this.repair,
  });

  final String source;

  /// Character offsets into [source], `[start, end)`. The surface
  /// underlines exactly this range.
  final int start;
  final int end;

  /// One line, in the user's vocabulary rather than the parser's. No
  /// "unexpected token", no offsets, no grammar names.
  final String message;

  /// The suggested repair, rendered as a chip. It is the WHOLE pattern
  /// with the fix applied, not a fragment, so accepting it is one click
  /// and never a merge.
  final String repair;

  /// The offending text itself, for a surface that would rather quote
  /// than underline.
  String get span => source.substring(start, end);
}

// ─────────────────────────────────────────────────────────────────────
// PARTS
// ─────────────────────────────────────────────────────────────────────

@immutable
sealed class _Part {
  const _Part();
  String render(int index, int count, int start, int step);
}

@immutable
final class _Literal extends _Part {
  const _Literal(this.text);
  final String text;
  @override
  String render(int index, int count, int start, int step) => text;
}

/// `{n}` and `{n:w}` and `{n@k}`. One class because they are one token
/// with two optional modifiers, and splitting them into three would let
/// them drift apart.
@immutable
final class _Sequential extends _Part {
  const _Sequential({this.pad = 0, this.groupEvery = 1});

  /// Zero-pad width; `0` is no padding.
  final int pad;

  /// `{n@k}`'s k. `1` is the ordinary `{n}`.
  final int groupEvery;

  @override
  String render(int index, int count, int start, int step) {
    final value = start + (index ~/ groupEvery) * step;
    final text = value.toString();
    return pad == 0 ? text : text.padLeft(pad, '0');
  }
}

/// `{rev}`. Counts down to `start`, so a sixteen-port bank reads
/// 16 … 1 rather than 15 … 0.
@immutable
final class _Descending extends _Part {
  const _Descending();
  @override
  String render(int index, int count, int start, int step) =>
      (start + (count - 1 - index) * step).toString();
}

/// `{A}`. A, B … Z, AA, AB … the spreadsheet column sequence, because
/// that is the one every integrator already has in their fingers.
@immutable
final class _Alpha extends _Part {
  const _Alpha();
  @override
  String render(int index, int count, int start, int step) {
    var n = index;
    final out = StringBuffer();
    // Bijective base-26: there is no "zero" letter, which is why this
    // is not a plain radix conversion.
    while (true) {
      out.write(String.fromCharCode(65 + n % 26));
      n = n ~/ 26 - 1;
      if (n < 0) break;
    }
    return String.fromCharCodes(out.toString().codeUnits.reversed);
  }
}

/// `{L,R}` and `{Y,Pb,Pr}`. Cycles, so it pairs with `{n@2}` to make a
/// stereo bank: docs/06 §4.1's `ZONE {n@2} {L,R}`.
@immutable
final class _Cycle extends _Part {
  const _Cycle(this.values);
  final List<String> values;
  @override
  String render(int index, int count, int start, int step) =>
      values[index % values.length];
}

// ─────────────────────────────────────────────────────────────────────
// THE PARSER
// ─────────────────────────────────────────────────────────────────────

/// The six token names that are not a literal set, for error messages
/// and for autocomplete. Kept in one place so a chip and a completion
/// cannot disagree about what is on offer.
const kLabelPatternTokens = <String>['{n}', '{n:2}', '{n@2}', '{A}', '{rev}'];

/// Parses [source] into a [LabelPattern] or a [LabelPatternFailure].
///
/// NEVER THROWS. Every rejection carries a span and a repair.
LabelPatternResult parseLabelPattern(String source) {
  final parts = <_Part>[];
  final literal = StringBuffer();

  void flush() {
    if (literal.isNotEmpty) {
      parts.add(_Literal(literal.toString()));
      literal.clear();
    }
  }

  LabelPatternFailure fail(
    int start,
    int end,
    String message,
    String repair,
  ) => LabelPatternFailure(
    source: source,
    start: start,
    end: end,
    message: message,
    repair: repair,
  );

  var i = 0;
  while (i < source.length) {
    final ch = source[i];

    if (ch == '}') {
      // A stray close brace is nearly always a typo for a token that
      // was opened with the wrong character, so it is an error rather
      // than a literal. Being permissive here would let `HDMI n}` pass
      // silently and print a literal brace on a panel drawing.
      return fail(
        i,
        i + 1,
        'This } has no opening { to match.',
        source.replaceRange(i, i + 1, ''),
      );
    }

    if (ch != '{') {
      literal.write(ch);
      i++;
      continue;
    }

    final close = source.indexOf('}', i);
    if (close < 0) {
      return fail(
        i,
        source.length,
        'This { is never closed.',
        '$source}',
      );
    }

    final body = source.substring(i + 1, close);
    final result = _parseToken(body, i, close + 1, fail);
    if (result is LabelPatternFailure) return result;

    flush();
    parts.add(result as _Part);
    i = close + 1;
  }

  flush();
  return LabelPattern(source, parts);
}

/// One `{...}` body. [from] and [to] are the token's span in the whole
/// source, including the braces, so every failure underlines the token
/// rather than an offset inside it.
Object _parseToken(
  String body,
  int from,
  int to,
  LabelPatternFailure Function(int, int, String, String) fail,
) {
  if (body.isEmpty) {
    return fail(
      from,
      to,
      'Empty {}. Write a token such as {n}, or a set such as {L,R}.',
      '{n}',
    );
  }

  // A literal set is anything containing a comma, checked FIRST so that
  // `{n,m}` reads as a two-value set rather than as a broken `{n}`.
  // That is the permissive reading and it is the right one: a set is
  // the only token whose contents are user vocabulary.
  if (body.contains(',')) {
    final values = body.split(',');
    if (values.any((v) => v.isEmpty)) {
      final cleaned = values.where((v) => v.isNotEmpty).join(',');
      return fail(
        from,
        to,
        'This set has an empty value.',
        cleaned.isEmpty ? '{n}' : '{$cleaned}',
      );
    }
    return _Cycle(values);
  }

  if (body == 'rev') return const _Descending();
  if (body == 'A') return const _Alpha();
  if (body == 'n') return const _Sequential();

  // MODIFIERS DO NOT COMPOSE, AND THE REFUSAL IS THE FEATURE. Roadmap
  // §2's M4 Risks names generalising this grammar as the milestone's
  // scope hazard: a parser that quietly accepts two modifiers has
  // promised three.
  //
  // THIS CHECK IS BEFORE THE TWO MODIFIER BRANCHES AND MUST STAY THERE.
  // It sat after them in the first draft and was unreachable, because
  // `{n@2:2}` matched `n@` and failed inside it, reporting `"2:2" is
  // not a whole number` -- a true sentence about the wrong problem.
  // Caught by the test asserting the MESSAGE rather than the refusal.
  if (body.startsWith('n') && body.contains('@') && body.contains(':')) {
    return fail(
      from,
      to,
      'Use either : for padding or @ for repeats, not both.',
      '{n:2}',
    );
  }

  if (body.startsWith('n:')) {
    final width = body.substring(2);
    final parsed = int.tryParse(width);
    if (parsed == null || parsed < 1) {
      return fail(
        from,
        to,
        width.isEmpty
            ? 'The : in {n:} needs a width, such as {n:2}.'
            : 'A width must be a whole number of at least 1, not "$width".',
        '{n:2}',
      );
    }
    return _Sequential(pad: parsed);
  }

  if (body.startsWith('n@')) {
    final every = body.substring(2);
    final parsed = int.tryParse(every);
    if (parsed == null || parsed < 1) {
      return fail(
        from,
        to,
        every.isEmpty
            ? 'The @ in {n@} needs a number, such as {n@2}.'
            : 'A repeat count must be a whole number of at least 1, '
                  'not "$every".',
        '{n@2}',
      );
    }
    return _Sequential(groupEvery: parsed);
  }

  final suggestion = _closestToken(body);
  return fail(
    from,
    to,
    '"$body" is not a pattern token. '
    'Try ${kLabelPatternTokens.join(', ')}, or a set such as {L,R}.',
    suggestion,
  );
}

/// The nearest documented token, for the repair chip. Deliberately
/// crude: a first-character match beats an edit distance nobody can
/// predict, and a wrong-but-plausible chip is worse than an obvious one.
String _closestToken(String body) {
  final lower = body.toLowerCase();
  if (lower.startsWith('r')) return '{rev}';
  if (lower.startsWith('a')) return '{A}';
  return '{n}';
}
