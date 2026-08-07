// Designator/label format engine (CR-045): one grammar, one registry, one
// parser, shared by all five call sites that mint a designator or a drop
// label (device, port, link, drop field label, drop rack label).
//
// Grammar:
//   {TOKEN}        a token reference; token names are UPPER_SNAKE and must
//                  be one of kIdFormatTokens (tokens.dart).
//   {TOKEN:n}      zero-pads the rendered value to n digits (meaningful for
//                  numeric tokens only).
//   [...]          an optional segment: omitted entirely, brackets and all,
//                  if any token inside it has no value.
//   |upper         uppercases the token's rendered value.
//   |first n       takes the first n characters of the rendered value.
//   |nz            "no zero" — the token counts as having no value if its
//                  underlying numeric value is 0 (drives [...] omission
//                  the same way an absent value does).
//   {{ / }}        literal `{` / `}`.
//
// A required token (one not wrapped in `[...]`) with no value is an error,
// not a silent blank — see [MissingTokenValueException].

import 'package:meta/meta.dart';
import 'package:rackmate_core/src/idformat/tokens.dart';

/// Thrown when a pattern references a token name outside
/// [kIdFormatTokens].
final class UnrecognisedTokenException implements Exception {
  const UnrecognisedTokenException(this.token, this.pattern);

  /// The offending token name, exactly as it appeared between `{` `}`.
  final String token;

  /// The full pattern string it was found in.
  final String pattern;

  @override
  String toString() =>
      'UnrecognisedTokenException: token "$token" in pattern "$pattern" is '
      'not part of the canonical idformat vocabulary (see kIdFormatTokens).';
}

/// Thrown when a pattern's grammar itself is malformed: an unterminated
/// `{`/`[`, an unparsable zero-pad width, or an unrecognised filter name.
final class IdFormatSyntaxException implements Exception {
  const IdFormatSyntaxException(this.message);

  final String message;

  @override
  String toString() => 'IdFormatSyntaxException: $message';
}

/// Thrown by [IdFormat.render] when a *required* token — one not wrapped
/// in an optional `[...]` segment — has no entry in the token-values map.
final class MissingTokenValueException implements Exception {
  const MissingTokenValueException(this.token, this.pattern);

  final String token;
  final String pattern;

  @override
  String toString() =>
      'MissingTokenValueException: required token "$token" has no value '
      'while rendering pattern "$pattern".';
}

// --- Internal AST -----------------------------------------------------
//
// Kept private to this file (Dart privacy is per-library-file) so the
// parser/renderer stay an implementation detail behind IdFormat. The
// pattern is re-parsed on every render()/unrecognisedTokens() call rather
// than cached, which keeps IdFormat a plain, trivially const-constructible
// value type — see the class doc.

sealed class _Node {
  const _Node();
}

final class _Literal extends _Node {
  const _Literal(this.text);
  final String text;
}

abstract class _Filter {
  const _Filter();
}

final class _UpperFilter extends _Filter {
  const _UpperFilter();
}

final class _FirstFilter extends _Filter {
  const _FirstFilter(this.n);
  final int n;
}

final class _NzFilter extends _Filter {
  const _NzFilter();
}

final class _Token extends _Node {
  const _Token(this.name, this.pad, this.filters);
  final String name;
  final int? pad;
  final List<_Filter> filters;
}

final class _Optional extends _Node {
  const _Optional(this.children);
  final List<_Node> children;
}

class _ParseCursor {
  const _ParseCursor(this.nodes, this.pos);
  final List<_Node> nodes;
  final int pos;
}

List<_Node> _parsePattern(String pattern) =>
    _parseNodes(pattern, 0, inOptional: false).nodes;

_ParseCursor _parseNodes(
  String pattern,
  int start, {
  required bool inOptional,
}) {
  final nodes = <_Node>[];
  final buf = StringBuffer();
  var pos = start;

  void flushLiteral() {
    if (buf.isNotEmpty) {
      nodes.add(_Literal(buf.toString()));
      buf.clear();
    }
  }

  while (pos < pattern.length) {
    final c = pattern[pos];
    if (c == '{') {
      if (pos + 1 < pattern.length && pattern[pos + 1] == '{') {
        buf.write('{');
        pos += 2;
        continue;
      }
      final close = pattern.indexOf('}', pos + 1);
      if (close == -1) {
        throw IdFormatSyntaxException(
          'Unterminated "{" at offset $pos in pattern "$pattern".',
        );
      }
      flushLiteral();
      nodes.add(_parseToken(pattern.substring(pos + 1, close), pattern));
      pos = close + 1;
      continue;
    }
    if (c == '}') {
      if (pos + 1 < pattern.length && pattern[pos + 1] == '}') {
        buf.write('}');
        pos += 2;
        continue;
      }
      // A lone "}" outside "{...}" parsing isn't part of the escape
      // grammar (only the doubled form is); treat it as a literal char.
      buf.write('}');
      pos += 1;
      continue;
    }
    if (c == '[') {
      flushLiteral();
      final child = _parseNodes(pattern, pos + 1, inOptional: true);
      nodes.add(_Optional(child.nodes));
      pos = child.pos;
      continue;
    }
    if (c == ']') {
      if (inOptional) {
        flushLiteral();
        return _ParseCursor(nodes, pos + 1);
      }
      // Lone "]" with no matching "[": literal, same reasoning as "}".
      buf.write(']');
      pos += 1;
      continue;
    }
    buf.write(c);
    pos += 1;
  }

  if (inOptional) {
    throw IdFormatSyntaxException(
      'Unterminated "[" (missing closing "]") in pattern "$pattern".',
    );
  }
  flushLiteral();
  return _ParseCursor(nodes, pos);
}

_Token _parseToken(String content, String pattern) {
  final parts = content.split('|');
  final head = parts.first;
  final colon = head.indexOf(':');
  final name = (colon == -1 ? head : head.substring(0, colon)).trim();

  int? pad;
  if (colon != -1) {
    final padStr = head.substring(colon + 1).trim();
    pad = int.tryParse(padStr);
    if (pad == null) {
      throw IdFormatSyntaxException(
        'Invalid zero-pad width ":$padStr" in token "{$content}" of '
        'pattern "$pattern".',
      );
    }
  }

  if (!kIdFormatTokens.contains(name)) {
    throw UnrecognisedTokenException(name, pattern);
  }

  final filters = <_Filter>[];
  for (final raw in parts.skip(1)) {
    final f = raw.trim();
    if (f == 'upper') {
      filters.add(const _UpperFilter());
    } else if (f == 'nz') {
      filters.add(const _NzFilter());
    } else if (f.startsWith('first ')) {
      final nStr = f.substring('first '.length).trim();
      final n = int.tryParse(nStr);
      if (n == null) {
        throw IdFormatSyntaxException(
          'Invalid "|first" argument "$nStr" in token "{$content}" of '
          'pattern "$pattern".',
        );
      }
      filters.add(_FirstFilter(n));
    } else {
      throw IdFormatSyntaxException(
        'Unrecognised filter "|$f" in token "{$content}" of pattern '
        '"$pattern".',
      );
    }
  }
  return _Token(name, pad, filters);
}

class _RenderOutcome {
  const _RenderOutcome({required this.text, required this.missing});
  final String text;

  /// True when this node had no value to contribute — either an absent
  /// token, or a numeric token zeroed out by `|nz`.
  final bool missing;
}

_RenderOutcome _renderNode(_Node node, Map<String, Object?> values) {
  if (node is _Literal) {
    return _RenderOutcome(text: node.text, missing: false);
  }
  if (node is _Token) {
    return _renderToken(node, values);
  }
  if (node is _Optional) {
    return _renderOptional(node, values);
  }
  throw StateError('Unreachable: unknown _Node subtype $node.');
}

_RenderOutcome _renderToken(_Token token, Map<String, Object?> values) {
  final value = values[token.name];
  if (value == null) {
    return const _RenderOutcome(text: '', missing: true);
  }

  var text = token.pad == null
      ? value.toString()
      : value.toString().padLeft(token.pad!, '0');

  for (final filter in token.filters) {
    if (filter is _UpperFilter) {
      text = text.toUpperCase();
    } else if (filter is _FirstFilter) {
      final n = filter.n;
      text = text.substring(0, n < text.length ? n : text.length);
    } else if (filter is _NzFilter) {
      if (value is int && value == 0) {
        return const _RenderOutcome(text: '', missing: true);
      }
    }
  }
  return _RenderOutcome(text: text, missing: false);
}

_RenderOutcome _renderOptional(_Optional node, Map<String, Object?> values) {
  final buf = StringBuffer();
  for (final child in node.children) {
    final outcome = _renderNode(child, values);
    if (outcome.missing) {
      // Omitted entirely — brackets and all — and this resolves itself:
      // it does not make an *enclosing* optional segment missing too.
      return const _RenderOutcome(text: '', missing: false);
    }
    buf.write(outcome.text);
  }
  return _RenderOutcome(text: buf.toString(), missing: false);
}

/// A designator/label format string (CR-045) — e.g. what
/// `ProjectSettings.deviceDesignatorFormat` holds.
///
/// [IdFormat] is a plain, immutable value wrapping [pattern]; [pattern] is
/// exactly what gets persisted, so `IdFormat(x).pattern == x` always holds
/// and there is nothing else to round-trip. The grammar is parsed fresh on
/// every [render]/[unrecognisedTokens] call rather than cached, which is
/// what lets the constructor stay `const`.
@immutable
final class IdFormat {
  const IdFormat(this.pattern);

  /// The raw format string, e.g. `"{TYPE_PREFIX}{SEP}{SEQ}"`.
  final String pattern;

  /// Renders this pattern against [tokenValues] (token name -> value;
  /// numeric tokens as [int], everything else as [String]).
  ///
  /// Throws [UnrecognisedTokenException] or [IdFormatSyntaxException] if
  /// [pattern] itself is invalid, and [MissingTokenValueException] if a
  /// required (non-optional) token has no entry in [tokenValues].
  String render(Map<String, Object?> tokenValues) {
    final nodes = _parsePattern(pattern);
    final buf = StringBuffer();
    for (final node in nodes) {
      final outcome = _renderNode(node, tokenValues);
      if (outcome.missing) {
        // Only a bare (non-optional) _Token can reach here missing.
        throw MissingTokenValueException((node as _Token).name, pattern);
      }
      buf.write(outcome.text);
    }
    return buf.toString();
  }

  /// Token names [render] will THROW on if its `tokenValues` has no entry
  /// for them — that is, every token not wrapped in an optional `[...]`
  /// segment, in the order they appear.
  ///
  /// EXACTLY THE THROW SITE'S OWN CONDITION, derived from the same parse
  /// rather than from a second reading of the grammar: [render] can only
  /// raise [MissingTokenValueException] from a bare top-level token,
  /// because a token inside `[...]` resolves the segment away instead. So
  /// this walks the top level and nothing else, and the two cannot drift.
  ///
  /// WHY A CALLER WANTS THIS RATHER THAN A `try`/`catch`. The exception
  /// names the FIRST missing token, so a caller repairing one learns about
  /// the next only on the next attempt. A label is authored during a
  /// sixty-drop entry session (M3's exit criterion); telling someone about
  /// one missing fact at a time, sixty times, is the difference between a
  /// message and an obstacle.
  ///
  /// Duplicates are collapsed: a pattern naming `{SEQ}` twice is missing
  /// one thing, not two.
  List<String> requiredTokens() {
    final found = <String>[];
    for (final node in _parsePattern(pattern)) {
      if (node is _Token && !found.contains(node.name)) found.add(node.name);
    }
    return found;
  }

  /// Token names referenced in [pattern] that are not part of
  /// [kIdFormatTokens] — the registry-validation entry point (CR-045: "one
  /// registry"). Returns an empty list when every referenced token is
  /// recognised; a non-empty pattern-syntax problem elsewhere (e.g. an
  /// unterminated `[`) does not stop this from reporting known-bad names,
  /// since it scans independently of the strict recursive-descent parser
  /// used by [render].
  List<String> unrecognisedTokens() {
    final found = <String>[];
    final regex = RegExp(
      r'\{\{|\}\}|\{([A-Za-z_][A-Za-z0-9_]*)(?::\d+)?(?:\|[^{}]*)?\}',
    );
    for (final match in regex.allMatches(pattern)) {
      final name = match.group(1);
      if (name != null &&
          !kIdFormatTokens.contains(name) &&
          !found.contains(name)) {
        found.add(name);
      }
    }
    return found;
  }

  @override
  String toString() => pattern;

  @override
  bool operator ==(Object other) =>
      other is IdFormat && other.pattern == pattern;

  @override
  int get hashCode => pattern.hashCode;
}
