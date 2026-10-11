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
import 'package:rackpal_core/src/builder/label_pattern.dart';
import 'package:rackpal_core/src/builder/port_commands.dart'
    show AddBankCommand, AddPortCommand, autoPortKey;
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/structure/drop_line_planner.dart'
    show resolveConnectorToken, resolveSignalFamilyToken;
import 'package:rackpal_core/src/units/ids.dart';

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

/// Families whose token means a DIFFERENT family in one direction.
///
/// `{resolved family id: (direction that swaps it, what it becomes)}`.
/// See the note at the call site: this exists for the IR pinout hazard
/// and holds exactly one row on purpose.
///
/// THE DESTINATION CHANGED AT DR-126 §11.125 AND THE ROW DID NOT MOVE.
/// `ir35 in` used to resolve to `ctl.ir_receiver`, on the reading that an
/// IR input listens and is therefore a receiver. It is not: a matrix's
/// `IR IN` is a PASSIVE jack an emitter lead lands on, and
/// `ctl.ir_receiver` now means only the powered receiver-eye circuit. A
/// person typing `ir35 in` is describing the everyday device input, so
/// this points at `ctl.ir_direct`. Quick Add cannot author a block's RX
/// jack by token, which is correct: that is the hazard end, and reaching
/// it should cost naming the family outright.
const _kDirectionalFamilies = <String, (PortDirection, String)>{
  'ctl.ir_emitter': (PortDirection.sink, 'ctl.ir_direct'),
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

  ConnectorTypeId? namedConnector;
  ConnectorTypeId? inheritedConnector;
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
    // A NAMED CONNECTOR AND AN INHERITED ONE ARE TRACKED SEPARATELY, and
    // the reason is a defect the render/parse round-trip found. The
    // first draft wrote `connector ??= connectorHit?.id ??
    // familyHit?.defaultConnector`, which lets the FIRST token's family
    // DEFAULT occupy the slot, so no later token could ever name a
    // connector: `16 speaker euro2 out` resolved to a binding post,
    // because `speaker` claimed the slot before `euro2` was read.
    //
    // DR-060 §11.59.4's rule is "a default loses to a named one", and
    // that draft applied it WITHIN a token and not ACROSS tokens.
    family ??= familyHit?.id;
    namedConnector ??= connectorHit?.id;
    inheritedConnector ??= familyHit?.defaultConnector;
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
  // ═══════════════════════════════════════════════════════════════════
  // ONE TOKEN WHOSE FAMILY DEPENDS ON THE DIRECTION, AND THE REASON IS
  // A DESTRUCTIVE PINOUT (DR-060 §11.59.11)
  // ═══════════════════════════════════════════════════════════════════
  // `seed_registries.dart` states the hazard where the IR families are
  // declared: receivers are tip = signal, ring = +12 V, sleeve = GND
  // (DR-221 §11.220.3 corrected a reversed ring and sleeve); emitters
  // are tip = IR in, sleeve = GND. Plugging an emitter into a receiver
  // jack destroys the emitter and can damage the supply. AC-052 makes
  // `pinoutVariant` mandatory on every 3.5 mm IR port for that reason.
  //
  // docs/06 §9.1 types `ir35 out` at step 9 for emitters and
  // `1 ir35 in "IR IN"` at step 12 for the matrix's IR INPUT. THIS
  // COMMENT USED TO CALL THAT "a RECEIVER input" and DR-126 §11.125
  // establishes it is not: the matrix jack is passive, and an emitter
  // lead goes straight into it. One token, two families, and the
  // direction is what separates them: an IR port you drive is an
  // emitter, an IR port that is driven is a direct input.
  //
  // A NAMED TABLE RATHER THAN AN `if`, so a second pair is a row and not
  // a second branch. If one ever arrives this becomes a field on
  // `SignalFamilyDef`; with one entry that would be a model change, a
  // codec change and four regenerated starters to express one fact.
  final swapped = _kDirectionalFamilies[family?.v];
  if (swapped != null && direction == swapped.$1) {
    family = SignalFamilyId(swapped.$2);
    // The connector is NOT swapped with it, and a named connector must
    // still win: `16 ir35 in trs` is a person being explicit, and DR-060
    // §11.59.4 says a default loses.
    //
    // THE RE-READ IS NOW A NO-OP FOR THE ONLY ROW IN THE TABLE, and it
    // stays because it is the general rule and not the special case.
    // `ctl.ir_emitter` and `ctl.ir_direct` BOTH default to
    // `conn.3_5mm_ts` since DR-126 §11.125.4, which is the whole point of
    // that clause: the direct-connect lead is the same object at both
    // ends. Before it, the swap moved the default from TS to TRS and this
    // line carried the change; a second row in the table would need it
    // again, so deleting it would be optimising against the comment three
    // lines above.
    inheritedConnector = namedConnector == null
        ? registries.signalFamilies[family]?.defaultConnector
        : inheritedConnector;
  }

  final connector = namedConnector ?? inheritedConnector;
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

/// What a direction is called in a bank name, plural.
///
/// `bidirectional` and `passive` are BOTH "Ports" and that is not a gap
/// being papered over: nobody writes "Bidirectionals" on a rack drawing,
/// and a bank of RS-232 ports is called exactly that. `busNode` gets
/// "Bus" because a Cresnet or DALI run genuinely is one.
const _kDirectionPlural = <PortDirection, String>{
  PortDirection.sink: 'Inputs',
  PortDirection.source: 'Outputs',
  PortDirection.bidirectional: 'Ports',
  PortDirection.busNode: 'Bus',
  PortDirection.passive: 'Ports',
};

/// The bank name a plan implies, before collisions are resolved.
///
/// DR-060 §11.59.10(a): the FAMILY'S FIRST ALIAS, falling back to
/// `shortTag`, then to `displayName`. docs/06 §4.2 used to say
/// `displayName` outright, which yields "HDMI 2.0 (18 Gbps) Inputs"
/// against the "HDMI Inputs" that §4.1's own example table and §2's
/// layout sketch both print. The prose was the illustration.
///
/// A PLAN WITH NO FAMILY STILL GETS A NAME, from the connector, because
/// `16 xlr in` has to land somewhere and "Ports" alone would collide
/// with every other unfamilied bank on the first try.
String deriveBankName(Registries registries, QuickAddPlan plan) {
  final family = plan.family == null
      ? null
      : registries.signalFamilies[plan.family];
  final direction = plan.direction ?? family?.defaultDirection;
  final plural = _kDirectionPlural[direction] ?? 'Ports';
  final head = deriveTypeHead(registries, plan.family, plan.connector);
  return head.isEmpty ? plural : '$head $plural';
}

/// The word a person calls this type, uppercased: `HDMI`, `HDBT`, `IR`.
///
/// **THE HEAD OF `deriveBankName`, EXTRACTED BECAUSE A GENERATOR NEEDS IT
/// WITHOUT THE PLURAL.** The archetypes (M4-I) write silkscreen labels
/// like `HDMI IN {n:2}`, and deriving that prefix a second way is how the
/// bank in the tree comes to disagree with the text on the ports inside
/// it. Same chain, same order, one implementation.
///
/// Empty when neither half resolves, which is a real state: `16 out`
/// names no type and the caller decides what to do about it.
String deriveTypeHead(
  Registries registries,
  SignalFamilyId? family,
  ConnectorTypeId? connector,
) {
  final def = family == null ? null : registries.signalFamilies[family];
  return switch (def) {
    final f? when f.aliases.isNotEmpty => f.aliases.first.toUpperCase(),
    final f? when (f.shortTag ?? '').isNotEmpty => f.shortTag!,
    final f? => f.displayName,
    _ => connector == null ? '' : _connectorHead(registries, connector),
  };
}

/// The same first-alias rule applied to a connector, which is already
/// what `portConnectorShortLabel` prints in the grid's CONN column. Kept
/// here rather than imported so `rackpal_core`'s builder layer does not
/// depend on its own summary module for a two-line fallback.
String _connectorHead(Registries registries, ConnectorTypeId id) {
  final def = registries.connectorTypes[id];
  if (def == null) return id.v;
  return def.aliases.isEmpty
      ? def.displayName
      : def.aliases.first.toUpperCase();
}

/// The bank label a plan lands in, resolved against [body].
///
/// **AN EXPLICIT `@bank` IS RETURNED UNCHANGED AND REUSES AN EXISTING
/// BANK. ONLY A DERIVED NAME TAKES A SUFFIX.** docs/06 §4.2 states the
/// numeric suffix inside the clause about `@bank` being OMITTED, and the
/// exit criterion settles the reading: §9.1's steps 10, 11 and 12 all
/// type `@Control`, and the criterion says the finished template has SIX
/// banks. Suffixing an explicit name gives Control, Control 2 and
/// Control 3, and eight banks. Typing the same bank name twice is how a
/// person says "the same bank".
///
/// A derived name still suffixes, because two commands that happen to
/// derive one head are two commands, and the user did not name either.
///
/// The comparison is on the LABEL rather than the key: the label is what
/// the user reads, and two banks reading "HDMI Inputs" are the confusion
/// the suffix exists to prevent, whatever their keys say.
String uniqueBankName(
  Registries registries,
  TemplateBody body,
  QuickAddPlan plan,
) => uniqueBankNameAmong(
  registries,
  {for (final b in body.banks) b.label},
  plan,
);

/// [uniqueBankName] over an explicit label set.
///
/// **THE SET AND NOT THE BODY, because [QuickAddBatch] has banks in flight
/// that `body` cannot see.** Plan two of an archetype has to collide with
/// plan one's bank, whose `AddBankCommand` has not run. Extracted rather
/// than copied for the reason this file already gives twice: a second
/// derivation of one rule is where the two come to disagree.
String uniqueBankNameAmong(
  Registries registries,
  Set<String> takenLabels,
  QuickAddPlan plan,
) {
  if (plan.bankName case final named?) return named;
  final wanted = deriveBankName(registries, plan);
  if (!takenLabels.contains(wanted)) return wanted;
  for (var n = 2; ; n++) {
    final candidate = '$wanted $n';
    if (!takenLabels.contains(candidate)) return candidate;
  }
}

/// Renders a plan back into a command line.
///
/// ═════════════════════════════════════════════════════════════════════
/// THE OTHER HALF OF THE BIDIRECTIONAL BINDING (M4-G3, docs/06 §4.1)
/// ═════════════════════════════════════════════════════════════════════
/// Command mode and field mode are "bound bidirectionally", and typing
/// in command mode updating the fields is the easy direction: that is
/// just [parseQuickAdd]. THIS is the hard one, and it is what makes the
/// DSL teach itself: a user who reaches for the dropdowns because they
/// do not know the grammar watches the command line assemble itself
/// from their clicks, and learns the words by seeing them written.
///
/// ═════════════════════════════════════════════════════════════════════
/// IT ROUND-TRIPS, AND A GATE HOLDS IT TO THAT
/// ═════════════════════════════════════════════════════════════════════
/// `parseQuickAdd(registries, renderQuickAdd(registries, plan))` yields
/// a plan equal to the original on every field. Without that, editing a
/// dropdown could silently change something the user did not touch,
/// which is worse than not offering the control at all.
///
/// It is NOT byte-identical to what the user typed, and it does not try
/// to be. `16 hdmi in` renders as `16 hdmi in rear`, because the plan
/// carries the face the parser inferred, and a field-mode edit must
/// write out what the fields SHOW. Preserving the original spelling
/// would need the plan to remember its own source text, which is a
/// second representation of the same fact and the thing this pair
/// exists to avoid.
String renderQuickAdd(Registries registries, QuickAddPlan plan) {
  final parts = <String>['${plan.quantity}'];

  // THE FAMILY TOKEN COMES FIRST WHEN THERE IS ONE, because a family
  // carries a connector and the reverse is not true (DR-060 §11.59.4).
  // Rendering the connector first would produce a command whose second
  // token had to override the first, which parses correctly and reads
  // like an argument.
  final family = plan.family == null
      ? null
      : registries.signalFamilies[plan.family];
  if (family != null) {
    parts.add(_familyToken(family));
  }

  // The connector is written only when it is NOT what the family would
  // have given anyway: `16 hdmi in` rather than `16 hdmi hdmi in`. When
  // there is no family it is the only type token there is.
  final connector = plan.connector == null
      ? null
      : registries.connectorTypes[plan.connector];
  if (connector != null && connector.id != family?.defaultConnector) {
    parts.add(_connectorToken(connector));
  }

  if (plan.passthrough) {
    parts.add('pass');
  } else if (plan.direction case final d?) {
    parts.add(_kDirections.entries.firstWhere((e) => e.value == d).key);
  }

  if (plan.bothFaces) {
    parts.add('both');
  } else {
    parts.add((plan.face ?? Face.rear).name);
  }

  if (plan.labelPattern case final p?) {
    parts.add('"${p.source}"');
  }
  if (plan.bankName case final b?) {
    parts.add('@$b');
  }

  return parts.join(' ');
}

/// The shortest token that resolves back to [family].
///
/// THE FIRST ALIAS, falling back to `shortTag` then the id tail, which
/// is `deriveBankName`'s rule in lower case and for the same reason: the
/// alias list's head is the trade's own spelling. `displayName` is NOT
/// in this chain even though the resolver accepts it, because
/// `HDMI 2.0 (18 Gbps)` is not something a person types on a command
/// line and rendering it would teach the wrong vocabulary.
String _familyToken(SignalFamilyDef family) {
  if (family.aliases.isNotEmpty) return family.aliases.first.toLowerCase();
  if (family.shortTag case final t? when t.isNotEmpty) return t.toLowerCase();
  return _tail(family.id.v).toLowerCase();
}

String _connectorToken(ConnectorTypeDef connector) =>
    connector.aliases.isNotEmpty
    ? connector.aliases.first.toLowerCase()
    : _tail(connector.id.v).toLowerCase();

/// One inline completion offer.
@immutable
final class QuickAddCompletion {
  const QuickAddCompletion({required this.token, required this.suffix});

  /// The whole completed token, for a surface that wants to name it.
  final String token;

  /// What accepting inserts at the caret. Never empty: a completion
  /// that adds nothing is not offered, because ghost text showing the
  /// word already typed is noise that teaches nothing.
  final String suffix;
}

/// The completion for the token the caret sits at the end of, or null.
///
/// ═════════════════════════════════════════════════════════════════════
/// AUTOCOMPLETE IS NOT OPTIONAL, AND THE REASON IS NOT CONVENIENCE
/// ═════════════════════════════════════════════════════════════════════
/// AC-050/A2.4, restated by board #216: the discoverability argument for
/// shipping a DSL at all is void without it, so a DSL shipped without
/// autocomplete has not shipped. A user who has seen the tool once, who
/// is exactly the population M4's exit criterion names, does not know
/// that `hdbt` exists. This is how they find out.
///
/// ═════════════════════════════════════════════════════════════════════
/// THE CANDIDATE ORDER IS TOTAL, BECAUSE A GHOST THAT MOVES IS WORSE
/// THAN NO GHOST
/// ═════════════════════════════════════════════════════════════════════
/// Determinism is an invariant here as everywhere else: the same prefix
/// must offer the same word every time, or the suggestion cannot be
/// learned. Candidates are therefore sorted SHORTEST FIRST and
/// alphabetically within a length, so `in` beats `input` and the chain
/// ends in a unique string.
///
/// Shortest-first is also the right ergonomics: the short spellings are
/// the ones the grammar is built from, and a user typing `i` wants `in`
/// rather than the first entry of a map iteration.
///
/// ═════════════════════════════════════════════════════════════════════
/// WHAT IS DELIBERATELY NOT COMPLETED
/// ═════════════════════════════════════════════════════════════════════
///  * THE QUANTITY. It is a number the user is choosing, not a word
///    they are recalling.
///  * ANYTHING INSIDE QUOTES. A label is the user's own vocabulary and
///    a tool guessing at it is a tool fighting them.
///  * `@bank` NAMES. Completing them needs the `TemplateBody`, and a
///    bank list is a different offer from a token list: it is existing
///    data rather than grammar. Named here rather than half-built.
QuickAddCompletion? quickAddCompletion(
  Registries registries,
  String text,
  int caret,
) {
  if (caret < 0 || caret > text.length) return null;

  // Only at the END of a token: completing mid-word would rewrite text
  // the user is standing in the middle of.
  if (caret < text.length && text[caret] != ' ') return null;

  final tokens = _lex(text);
  if (tokens.isEmpty) return null;

  final at = tokens.where((t) => t.end == caret).firstOrNull;
  if (at == null || at.quoted) return null;
  if (identical(at, tokens.first)) return null;
  if (at.text.isEmpty || at.text.startsWith('@')) return null;

  final prefix = at.text.toLowerCase();
  final candidates =
      <String>{
            ..._kDirections.keys,
            ..._kFaces.keys,
            for (final f in registries.signalFamilies.values) ...[
              ...f.aliases,
              ?f.shortTag,
              _tail(f.id.v),
            ],
            for (final c in registries.connectorTypes.values) ...[
              ...c.aliases,
              _tail(c.id.v),
            ],
          }
          .map((c) => c.toLowerCase())
          .where((c) => c.startsWith(prefix))
          .toList()
        ..sort((a, b) {
          final byLength = a.length.compareTo(b.length);
          return byLength != 0 ? byLength : a.compareTo(b);
        });

  for (final candidate in candidates) {
    if (candidate.length > prefix.length) {
      return QuickAddCompletion(
        token: candidate,
        suffix: candidate.substring(prefix.length),
      );
    }
  }
  return null;
}

String _tail(String id) => id.contains('.') ? id.split('.').last : id;

/// Turns a plan into the commands that realise it, against [body].
///
/// RETURNS COMMANDS, NOT PORTS, and the caller runs them inside ONE
/// `transact` so sixteen ports are one `Ctrl+Z`. There is deliberately
/// no `AddPortsCommand`: `Transaction` is itself a `Command` holding
/// children and the port grid already groups its deletes that way, so a
/// batch command would be a second mechanism for a solved problem.
///
/// THE BANK COMES FIRST in the returned list, because a port naming a
/// bank that does not exist yet is a dangling reference for however long
/// the list takes to apply, and `revert` runs the list backwards.
///
/// **`both` AND `pass` CREATE THEIR PORTS AND NOT THEIR PAIRING.** A
/// `both` command makes two ports per position, front and rear, which is
/// the count `QuickAddPlan.portCount` promises. Joining them with
/// `PassthroughPairDef`s is M4-J (`#181`), which owns passthrough
/// pairing in the UI and the warning docs/06 §4.6 asks for when one half
/// is deleted. Named here rather than half-built: a pair written without
/// the delete-side handling is the dangling reference `RemovePortCommand`
/// exists to prevent.
List<Command<TemplateBody>> buildQuickAdd(
  Registries registries,
  TemplateBody body,
  QuickAddPlan plan,
) => QuickAddBatch(registries, body).add(plan);

/// The key, order and bank allocation a RUN of plans shares.
///
/// ═════════════════════════════════════════════════════════════════════
/// ONE PLAN NEEDS NO SUCH OBJECT; SIX IN ONE ACTION DO
/// ═════════════════════════════════════════════════════════════════════
/// [buildQuickAdd] used to allocate straight off `body`, which is right
/// while the one command list it returns is the only thing in flight.
/// **An archetype generator emits six plans from one button** (M4-I,
/// DR-092 §11.91.7) and none of their commands has run when the next is
/// planned, so six independent snapshots mint six ports keyed `port.1`
/// and two banks both labelled `HDMI Inputs`.
///
/// So the allocation moved out of the function and into an object the
/// caller can hold across plans, and `buildQuickAdd` became its one-plan
/// case. **That is the whole point of the shape**: an archetype that
/// constructed its own `PortDef`s would be a second copy of the bank
/// reuse rule, the label expander and the ordinal allocator, which is the
/// objection [uniqueSlugKey]'s own comment records against a third
/// derivation of a key.
///
/// **IT APPLIES NOTHING.** Commands come back unapplied exactly as they
/// always did and the caller runs them inside one `transact`. What is
/// shared here is the ALLOCATION, not the mutation.
final class QuickAddBatch {
  QuickAddBatch(this.registries, TemplateBody body)
    : _takenPortKeys = {for (final p in body.ports) p.key.v},
      _bankKeyByLabel = {for (final b in body.banks) b.label: b.key},
      _takenBankKeys = {for (final b in body.banks) b.key},
      _portOrder = nextOrder(body.ports.map((p) => p.order)),
      _bankOrder = nextOrder(body.banks.map((b) => b.order)),
      _ordinal = body.ports.length + 1;

  final Registries registries;

  final Set<String> _takenPortKeys;

  /// LABEL TO KEY, and the label is the join for `uniqueBankName`'s own
  /// stated reason: the label is what the user reads, and it is what
  /// decides whether a plan reuses a bank or mints one.
  final Map<String, String> _bankKeyByLabel;
  final Set<String> _takenBankKeys;

  FracIndex _portOrder;
  FracIndex _bankOrder;
  int _ordinal;

  /// The commands realising [plan], allocated against everything this
  /// batch has already handed out.
  ///
  /// [decorate] runs on each freshly constructed [PortDef] BEFORE it goes
  /// into its `AddPortCommand`, which is how an archetype writes the
  /// fields the DSL has no token for: PoE, an SFP form factor, a power
  /// role, an IR pinout. Writing them here rather than as trailing
  /// `SetPortFieldCommand`s keeps one command per port and keeps `revert`
  /// symmetrical: `AddPortCommand` holds the port it added, so undo takes
  /// the decorated object out and redo puts the same one back.
  /// [labels] overrides the pattern expansion with LITERAL text, one
  /// entry per port.
  ///
  /// **A PASTED CELL IS DATA, NOT A PATTERN** (M4-I3, `#222`). A sheet
  /// whose label column reads `HDMI {n}` means those characters, and
  /// running it through `parseLabelPattern` would silently expand it to
  /// `HDMI 1`. The label grammar has no escape for a literal brace and it
  /// is not getting one: roadmap §2 names generalising that grammar as
  /// this milestone's scope hazard, by name.
  ///
  /// Passed here rather than written by [decorate] because `autoPortKey`
  /// derives the port's KEY from its label, and a label arriving after
  /// construction would leave every pasted port keyed `port.<n>`.
  List<Command<TemplateBody>> add(
    QuickAddPlan plan, {
    void Function(PortDef port)? decorate,
    List<String>? labels,
  }) {
    final commands = <Command<TemplateBody>>[];

    final bankLabel = uniqueBankNameAmong(
      registries,
      _bankKeyByLabel.keys.toSet(),
      plan,
    );
    var bankKey = _bankKeyByLabel[bankLabel];
    if (bankKey == null) {
      bankKey = bankKeyAmong(_takenBankKeys, bankLabel);
      _takenBankKeys.add(bankKey);
      _bankKeyByLabel[bankLabel] = bankKey;
      commands.add(
        AddBankCommand(
          BankDef(
            key: bankKey,
            label: bankLabel,
            // The abbr is the label's own head, which is already the
            // family's display token; a separate derivation here would be
            // a third place for the same vocabulary to drift.
            abbr: bankLabel.split(' ').first,
            order: _bankOrder,
          ),
        ),
      );
      _bankOrder = nextOrder([_bankOrder]);
    }

    final family = plan.family == null
        ? null
        : registries.signalFamilies[plan.family];
    final direction =
        plan.direction ??
        family?.defaultDirection ??
        PortDirection.bidirectional;
    final expanded = labels ?? plan.labels;

    void addPort(String label, Face face) {
      // Keys and orders come off a GROWING set rather than off `body` as
      // it stands, because none of these commands has run yet.
      // Allocating all sixteen against one snapshot would mint sixteen
      // identical keys.
      final key = autoPortKey(label, taken: _takenPortKeys, ordinal: _ordinal);
      _takenPortKeys.add(key.v);
      _ordinal++;
      final port = PortDef(
        key: key,
        label: label,
        // AN UNRESOLVED HALF IS WRITTEN AS THE EMPTY ID, which is what
        // `blankPort` already does and what the grid's validation dot
        // already marks. G4's absent-key rule governs the CODEC, not
        // this constructor: `PortDef.connector` is non-nullable.
        connector: plan.connector ?? const ConnectorTypeId(''),
        signalFamily: plan.family ?? const SignalFamilyId(''),
        face: face,
        order: _portOrder,
        direction: direction,
        topology: family?.defaultTopology ?? PortTopology.p2p,
        bankKey: bankKey,
      );
      decorate?.call(port);
      commands.add(AddPortCommand(port));
      _portOrder = nextOrder([_portOrder]);
    }

    for (var i = 0; i < plan.quantity; i++) {
      final label = i < expanded.length ? expanded[i] : '';
      if (plan.bothFaces) {
        addPort(label, Face.front);
        addPort(label, Face.rear);
      } else {
        addPort(label, plan.face ?? Face.rear);
      }
    }

    return commands;
  }
}

/// A bank key that no bank in [body] already holds.
///
/// Slugged from the label on `autoPortKey`'s convention, so a reader
/// seeing `hdmi.inputs` beside `port.3` does not have to learn two.
String uniqueBankKey(TemplateBody body, String label) =>
    bankKeyAmong({for (final b in body.banks) b.key}, label);

/// [uniqueBankKey] over an explicit key set, for [QuickAddBatch]'s sake.
///
/// The FALLBACK is why this is a function rather than two call sites: a
/// label that slugs to nothing has to land on `bank.<n>`, and that string
/// written twice is the "third place for the same vocabulary to drift"
/// this file objects to two comments above.
String bankKeyAmong(Set<String> taken, String label) => uniqueSlugKey(
  label,
  taken: taken,
  fallback: 'bank.${taken.length + 1}',
);

/// [label] slugged to a key that is not already in [taken].
///
/// **EXTRACTED SO THERE IS ONE DERIVATION, NOT TWO.** `uniqueBankKey` and
/// `uniquePortSetKey` (M4-J2) mint keys for two different collections out
/// of the same vocabulary, and this file's own `abbr` comment states the
/// objection to a second copy: it would be "a third place for the same
/// vocabulary to drift". [fallback] is what an all-punctuation label
/// slugs down to, and is the only part the two callers differ on.
String uniqueSlugKey(
  String label, {
  required Set<String> taken,
  required String fallback,
}) {
  final slug = label
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '.')
      .replaceAll(RegExp(r'^\.+|\.+$'), '');
  final base = slug.isEmpty ? fallback : slug;
  if (!taken.contains(base)) return base;
  for (var n = 2; ; n++) {
    final candidate = '$base.$n';
    if (!taken.contains(candidate)) return candidate;
  }
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
