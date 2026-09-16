// Teaching a connector the word your crew uses (`#248`, RJ-012, CR-058).
//
// ═══════════════════════════════════════════════════════════════════════
// THE READER WAS ALREADY BUILT; ONLY THE WRITER WAS MISSING
// ═══════════════════════════════════════════════════════════════════════
// `resolveConnectorToken` (drop_line_planner.dart) already resolves a
// typed token by ALIAS FIRST and then by the id's tail, under
// `normaliseMediaToken`. So the Quick Add DSL, the TSV paste path and the
// archetype expander all honour aliases today. What did not exist was any
// way to add one: `ConnectorTypeDef.aliases` had readers in three
// subsystems and a writer only in the seed catalog and the codec.
//
// That is why RJ-012 lists connector aliases as shipping in v1 while a
// general registry editor is rejected. A shop whose crew says "ethernet"
// can teach the DSL that word; nobody can invent a connector type, and
// nobody can invent a signal family, a colour scheme or a validation rule
// (RJ-012, AC-011).
//
// ── WHY THE ALIAS LIVES ON THE DEF ─────────────────────────────────────
// It goes into `ConnectorTypeDef.aliases` in the DOCUMENT'S registry,
// exactly where the seed catalog puts its own. `resolveConnectorToken`
// therefore needs no second source and no precedence rule, and a `.rppj`
// stays self-describing: the project that used "ethernet" carries the
// word, so opening it on another machine resolves the same tokens.
//
// The cost is real and is accepted rather than hidden: a catalog update
// may ship new aliases for the same connector, and a document's list can
// then differ from the catalog's. Nothing reconciles them. That is
// arguably correct, since a shop's vocabulary is not the catalog's, but it
// is undefended and a future chapter may want to say so out loud.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/structure/drop_line_planner.dart'
    show normaliseMediaToken;
import 'package:rackpal_core/src/units/ids.dart';

/// Adds or removes trade spellings on one connector type.
///
/// ONE COMMAND FOR BOTH DIRECTIONS, carrying the whole before-and-after
/// list. An alias edit is a single typed write to a single registry entry,
/// which is the shape `SetPortFieldCommand` already established for the
/// builder; splitting it into add and remove would be two undo paths to
/// one field, and `port_commands.dart` argues against that in terms.
final class SetConnectorAliasesCommand extends Command<RackDocument> {
  SetConnectorAliasesCommand({
    required this.id,
    required this.from,
    required this.to,
  });

  final ConnectorTypeId id;

  /// The list as it stood, so `revert` restores it exactly rather than
  /// removing what `apply` happened to add. A connector whose aliases were
  /// already `['RJ45', 'ethernet']` before this command must come back
  /// with both.
  final List<String> from;
  final List<String> to;

  @override
  LabelKey get label => LabelKey.setConnectorAliases;

  /// `meta` alone. An alias changes what a typed token RESOLVES to, and
  /// so what a person can author next; it changes no geometry, no
  /// connection and no cable. `AddMediaTypeCommand` claims `structure`
  /// too because a cable type is part of how the building is put
  /// together, and a spelling for a connector is not.
  @override
  EpochMask get touches => EpochMask.meta;

  /// Empty, for `AddMediaTypeCommand`'s reason: a registry key is not an
  /// entity a selection can hold.
  @override
  Iterable<Uuid> get affects => const [];

  @override
  bool apply(RackDocument doc) {
    _write(doc, to);
    return true;
  }

  @override
  void revert(RackDocument doc) => _write(doc, from);

  /// REPLACES THE DEF rather than mutating its list, because
  /// `ConnectorTypeDef.aliases` is a `final List<String>` on a class with
  /// a `const` constructor: the seed catalog's entries are compile-time
  /// constants, and mutating one in place would throw on a shipped
  /// connector and succeed on an imported one.
  void _write(RackDocument doc, List<String> aliases) {
    final was = doc.registries.connectorTypes[id];
    if (was == null) return;
    doc.registries.connectorTypes[id] = ConnectorTypeDef(
      id: was.id,
      displayName: was.displayName,
      aliases: List<String>.unmodifiable(aliases),
      footprintWidth: was.footprintWidth,
      footprintHeight: was.footprintHeight,
      pitch: was.pitch,
      genderApplies: was.genderApplies,
    );
  }
}

/// Whether [token] would resolve to something OTHER than [id] already.
///
/// ═══════════════════════════════════════════════════════════════════════
/// AN ALIAS THAT COLLIDES IS WORSE THAN NO ALIAS
/// ═══════════════════════════════════════════════════════════════════════
/// `resolveConnectorToken` walks every connector's aliases in map order
/// and returns the FIRST match. Teaching `conn.xlr3` the word "ethernet"
/// would therefore not shadow `conn.rj45` predictably: which one wins
/// depends on iteration order, so the same typed token would resolve
/// differently in two documents with the same registries.
///
/// So a collision is refused at the editor rather than stored and left to
/// chance. Returning the OWNER instead of a bool is what lets the refusal
/// say which connector already has the word, which is the difference
/// between a rejection a person can act on and one they can only obey.
ConnectorTypeDef? connectorAliasConflict(
  Registries registries,
  ConnectorTypeId id,
  String token,
) {
  final want = normaliseMediaToken(token);
  if (want.isEmpty) return null;
  for (final d in registries.connectorTypes.values) {
    if (d.id == id) continue;
    for (final a in d.aliases) {
      if (normaliseMediaToken(a) == want) return d;
    }
    final tail = d.id.v.contains('.') ? d.id.v.split('.').last : d.id.v;
    if (normaliseMediaToken(tail) == want) return d;
  }
  return null;
}
