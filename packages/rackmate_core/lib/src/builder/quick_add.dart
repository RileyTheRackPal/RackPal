// QUICK ADD'S MINI-DSL (M4-G, docs/06 §4.1), THE PARSER AND THE PLAN.
//
// ═════════════════════════════════════════════════════════════════════
// THE GRAMMAR, AND WHAT "ORDER-INSENSITIVE" ACTUALLY MEANS
// ═════════════════════════════════════════════════════════════════════
//   <qty> <type token> [<type token>…] [in|out|bi|bus|pass]
//         [front|rear|both] ["<label pattern>"] [@<bank>]
//
// docs/06 §4.1 says everything but qty and connector is optional and
// order-insensitive, so this parser classifies each token by WHAT IT IS
// rather than by where it sits. Only the quantity is positional, and
// only because a leading integer is the one token whose meaning depends
// on being first.
//
// ═════════════════════════════════════════════════════════════════════
// A TYPE TOKEN RESOLVES TO A PAIR, NOT TO A CONNECTOR (DR-060 §11.59.4)
// ═════════════════════════════════════════════════════════════════════
// The grammar in §4.1 reads `<qty> <connector|alias> [<family|alias>]`,
// which is one token per registry. It is not how resolution works and
// the ruling explains why: `hdbt` names a family and yields its default
// connector, `xlr` names a connector and NO family, and `c13` names both
// but disagrees with its family's default about which connector.
//
// So each type token is resolved by both registries independently, and
// the results are merged widest-first: the first token to name a family
// wins the family, the first to name a connector wins the connector. A
// second token therefore REFINES rather than replaces, which is what
// makes `16 rj45 hdbaset out` mean an HDBaseT port on an 8P8C rather
// than an argument between two tokens.
//
// ═════════════════════════════════════════════════════════════════════
// THIS FILE PLANS AND DOES NOT COMMIT
// ═════════════════════════════════════════════════════════════════════
// [parseQuickAdd] answers a [QuickAddPlan] or a [QuickAddFailure]; it
// never touches a `TemplateBody`. The plan is what the docked bar's
// summary line reads to say "16 ports, HDBaseT, rear, bank HDBT Outputs
// (new)" BEFORE the user presses Enter, and building the ports is a
// separate step over the same plan. A parser that committed as it went
// could not offer that preview, and the preview is what stops a typo
// costing sixteen ports and an undo.
//
// Parse failures are designed, never thrown, for the reason board #218
// gives: an exception reaching the user is a failed requirement.

import 'package:meta/meta.dart';
import 'package:rackmate_core/src/builder/label_pattern.dart';
import 'package:rackmate_core/src/model/placement.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/structure/drop_line_planner.dart'
    show resolveConnectorToken, resolveSignalFamilyToken;
import 'package:rackmate_core/src/units/ids.dart';

/// A parsed Quick Add command, or the reason it could not be parsed.
@immutable
sealed class QuickAddResult {
  const QuickAddResult();
}

/// What a command WILL create, resolved but not yet committed.
@immutable
final class QuickAddPlan extends QuickAddResult {
  const QuickAddPlan({
    required this.source,
    required this.quantity,
    required this.connector,
    required this.family,
    required this.direction,
    required this.face,
    required this.bothFaces,
    required this.passthrough,
    required this.labelPattern,
    required this.bankName,
  });

  final String source;

  /// How many ports the command names. `both` doubles the ports created
  /// but NOT this number, which stays what the user typed: a 24-port
  /// passthrough panel is 24 positions and 48 ports, and saying "48" in
  /// the summary would read as a miscount.
  final int quantity;

  /// UNKNOWN IS A REAL ANSWER (G4, CR-114). `xlr` names a connector and
  /// no family; a bare `16 out` names neither. The plan carries the gap
  /// rather than a guess, and the grid's validation dot marks it.
  final ConnectorTypeId? connector;
  final SignalFamilyId? family;

  /// Null means "the family's `defaultDirection`", which is resolved at
  /// build time so a plan and its ports cannot disagree.
  final PortDirection? direction;

  /// Null means rear, which is where the overwhelming majority of rack
  /// device I/O lives.
  final Face? face;

  /// `both`: one port on each face per position, auto-paired.
  final bool bothFaces;

  /// `pass`: the positions form a passthrough panel.
  final bool passthrough;

  /// Null means the ports are unlabelled, which is legal and visible.
  final LabelPattern? labelPattern;

  /// Null means "derive it from family and direction" (M4-H3), done at
  /// build time because the derivation needs the family this may not
  /// have resolved.
  final String? bankName;

  /// How many `PortDef`s a build will actually produce.
  int get portCount => bothFaces ? quantity * 2 : quantity;

  /// The labels this plan will apply, in order. Empty when unlabelled.
  List<String> get labels =>
      labelPattern?.expandAll(quantity) ?? const <String>[];
}

/// A command that did not parse. Same three fields as
/// [LabelPatternFailure] and for the same reason: a surface underlines
/// [start]..[end], shows [message], and offers [repair] as a chip.
@immutable
final class QuickAddFailure extends QuickAddResult {
  const QuickAddFailure({
    required this.source,
    required this.start,
    required this.end,
    required this.message,
    required this.repair,
  });

  final String source;
  final int start;
  final int end;
  final String message;
  final String repair;

  String get span => source.substring(start, end);
}

/// One lexed token and where it came from, so a failure can underline
/// the token rather than guess at an offset.
@immutable
final class _Token {
  const _Token(this.text, this.start, this.end, {this.quoted = false});
  final String text;
  final int start;
  final int end;
  final bool quoted;
}

const _kDirections = <String, PortDirection>{
  'in': PortDirection.sink,
  'out': PortDirection.source,
  'bi': PortDirection.bidirectional,
  'bus': PortDirection.busNode,
  'pass': PortDirection.passive,
};

const _kFaces = <String, Face?>{
  'front': Face.front,
  'rear': Face.rear,
  // `both` is a face KEYWORD that resolves to no single face, which is
  // why this map is nullable rather than a second lookup.
  'both': null,
};

/// Parses one Quick Add command against [registries].
///
/// NEVER THROWS.
QuickAddResult parseQuickAdd(Registries registries, String source) {
  QuickAddFailure fail(int start, int end, String message, String repair) =>
      QuickAddFailure(
        source: source,
        start: start,
        end: end,
        message: message,
        repair: repair,
      );

  final tokens = _lex(source);
  if (tokens.isEmpty) {
    return fail(
      0,
      source.length,
      'Type a quantity and a port type, '
          'such as 16 hdmi in.',
      '16 hdmi in',
    );
  }

  // QUANTITY IS THE ONE POSITIONAL TOKEN. A leading integer is the only
  // token whose meaning depends on where it sits, and requiring it
  // first is what lets everything after it be order-insensitive.
  final first = tokens.first;
  final quantity = int.tryParse(first.text);
  if (quantity == null) {
    return fail(
      first.start,
      first.end,
      'A command starts with how many ports to add, such as 16.',
      '16 ${source.trim()}',
    );
  }
  if (quantity < 1) {
    return fail(
      first.start,
      first.end,
      'A quantity must be at least 1.',
      source.replaceRange(first.start, first.end, '1'),
    );
  }

  ConnectorTypeId? connector;
  SignalFamilyId? family;
  PortDirection? direction;
  Face? face;
  var bothFaces = false;
  var passthrough = false;
  LabelPattern? pattern;
  String? bankName;
  final unresolved = <_Token>[];

  for (var i = 1; i < tokens.length; i++) {
    final token = tokens[i];
    final lower = token.text.toLowerCase();

    // A QUOTED TOKEN IS ALWAYS A LABEL, even when its text would match
    // a keyword. `"out"` is a label reading OUT; `out` is a direction.
    // Quoting is the user's own disambiguator and honouring it costs
    // nothing.
    if (token.quoted) {
      final parsed = parseLabelPattern(token.text);
      if (parsed is LabelPatternFailure) {
        // The pattern's span is relative to the pattern; shift it into
        // the command so the bar underlines the right characters. The
        // +1 is the opening quote.
        return fail(
          token.start + 1 + parsed.start,
          token.start + 1 + parsed.end,
          parsed.message,
          source.replaceRange(
            token.start + 1,
            token.end - 1,
            parsed.repair,
          ),
        );
      }
      pattern = parsed as LabelPattern;
      continue;
    }

    if (lower.startsWith('@')) {
      // `@bank` runs to the end of the bare words that follow, because
      // bank names have spaces: `@Mirror Outputs`, `@HDBT Outputs`. It
      // stops at a quoted string or at anything that classifies, which
      // is what makes `24 rj45 @Ports "{n:2}"` work.
      final words = <String>[token.text.substring(1)];
      var j = i + 1;
      while (j < tokens.length &&
          !tokens[j].quoted &&
          _isBankWord(registries, tokens[j].text)) {
        words.add(tokens[j].text);
        j++;
      }
      i = j - 1;
      bankName = words.where((w) => w.isNotEmpty).join(' ');
      if (bankName.isEmpty) {
        return fail(
          token.start,
          token.end,
          'The @ needs a bank name after it, such as @Control.',
          source.replaceRange(token.start, token.end, '@Control'),
        );
      }
      continue;
    }

    if (_kDirections.containsKey(lower)) {
      direction = _kDirections[lower];
      if (lower == 'pass') passthrough = true;
      continue;
    }

    if (_kFaces.containsKey(lower)) {
      if (lower == 'both') {
        bothFaces = true;
      } else {
        face = _kFaces[lower];
      }
      continue;
    }

    // A TYPE TOKEN REFINES AND NEVER REPLACES (DR-060 §11.59.4). Both
    // registries answer; the first token to name each half wins it.
    final familyHit = resolveSignalFamilyToken(registries, token.text);
    final connectorHit = resolveConnectorToken(registries, token.text);
    if (familyHit == null && connectorHit == null) {
      unresolved.add(token);
      continue;
    }
    family ??= familyHit?.id;
    connector ??= connectorHit?.id ?? familyHit?.defaultConnector;
  }

  if (unresolved.isNotEmpty) {
    final bad = unresolved.first;
    return fail(
      bad.start,
      bad.end,
      '"${bad.text}" is not a connector, a signal family, a direction '
      'or a face. Quote it to use it as a label.',
      source.replaceRange(bad.start, bad.end, '"${bad.text}"'),
    );
  }

  // A COMMAND THAT NAMES NO TYPE AT ALL IS REFUSED. Everything else may
  // be unknown, because unknown is a real state a port can hold, but a
  // command with neither a connector nor a family has not said what to
  // add and is far more likely a typo than an intention.
  if (connector == null && family == null) {
    return fail(
      first.start,
      source.length,
      'Name a connector or a signal family, such as hdmi or hdbt.',
      '$quantity hdmi in',
    );
  }

  return QuickAddPlan(
    source: source,
    quantity: quantity,
    connector: connector,
    family: family,
    direction: direction,
    face: face,
    bothFaces: bothFaces,
    passthrough: passthrough,
    labelPattern: pattern,
    bankName: bankName,
  );
}

/// Whether [text] belongs to the `@bank` name currently being read.
///
/// TRUE MEANS "THE PARSER HAS NO OTHER USE FOR THIS WORD". A bank name
/// may contain spaces (`@Mirror Outputs`), so the name runs on until a
/// word arrives that the grammar can classify. `24 rj45 @Ports "{n:2}"`
/// therefore stops the bank at `Ports`, because the next token is
/// quoted and the caller checks that before calling this.
bool _isBankWord(Registries registries, String text) {
  final lower = text.toLowerCase();
  if (_kDirections.containsKey(lower)) return false;
  if (_kFaces.containsKey(lower)) return false;
  if (lower.startsWith('@')) return false;
  if (int.tryParse(text) != null) return false;
  if (resolveSignalFamilyToken(registries, text) != null) return false;
  if (resolveConnectorToken(registries, text) != null) return false;
  return true;
}

/// Splits [source] into tokens, keeping double-quoted runs whole and
/// recording each token's span.
///
/// AN UNTERMINATED QUOTE IS NOT AN ERROR HERE. It runs to the end of
/// input and is treated as a label, because the bar parses on EVERY
/// KEYSTROKE and a half-typed `"HDMI IN` would otherwise paint an error
/// under the user's hands as they type it. Refusing mid-word is how a
/// live parser becomes hostile.
List<_Token> _lex(String source) {
  final out = <_Token>[];
  var i = 0;
  while (i < source.length) {
    if (source[i] == ' ' || source[i] == '\t') {
      i++;
      continue;
    }
    if (source[i] == '"') {
      final close = source.indexOf('"', i + 1);
      if (close < 0) {
        out.add(
          _Token(source.substring(i + 1), i, source.length, quoted: true),
        );
        break;
      }
      out.add(
        _Token(source.substring(i + 1, close), i, close + 1, quoted: true),
      );
      i = close + 1;
      continue;
    }
    var j = i;
    while (j < source.length &&
        source[j] != ' ' &&
        source[j] != '\t' &&
        source[j] != '"') {
      j++;
    }
    out.add(_Token(source.substring(i, j), i, j));
    i = j;
  }
  return out;
}
