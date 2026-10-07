// rackpal_core/src/commands/clone_signal_family.dart: pure Dart.
//
// A SIGNAL FAMILY IS MADE BY CLONING ONE THAT SHIPS, AND ONLY THAT WAY.
// DR-122 §11.121.2, DR-243, DR-244. Board SFE-B1 (`#825`), SFE-B2
// (`#826`).
//
// ═════════════════════════════════════════════════════════════════════
// WHAT RJ-012 FEARED, AND WHERE IT ACTUALLY LIVES
// ═════════════════════════════════════════════════════════════════════
// RJ-012 refused a signal-family editor because "a hand-rolled one
// produces silently wrong validation". DR-244 §11.243.1 read the code
// rather than the ruling and found the road it travels: NO RULE READS A
// FAMILY. The rules read the port. The builder (`archetypes.dart`,
// `quick_add.dart`, `port_type_change.dart`) COPIES a family's default
// direction, topology and connector into every port made with it, and a
// wrong direction or topology copied that way is then judged confidently
// and wrongly.
//
// So the clone LOCKS what travels that road. Domain, direction and
// topology come from the parent and nothing here accepts a different
// one. The connector is free within the registry (DR-244 §11.243.3)
// because CON-001 judges a real catalog connector against the catalog's
// own mating table, so no choice of default can make it wrong.
//
// ═════════════════════════════════════════════════════════════════════
// REFUSED, NOT WARNED, AND THE SENTENCE IS WRITTEN HERE
// ═════════════════════════════════════════════════════════════════════
// A dash and weight that collide under PAL-1 are REFUSED (SFE-B2), using
// `pal1.dart`, the implementation the CI gate reads. The refusal names
// the family it collides with, because "that combination is taken"
// without saying by what leaves a person guessing. It is a sentence
// built in core so the dialog renders it verbatim: the shape M5-F2 set
// for the acknowledgement dialog and `buildSetSignalFamily` follows.
//
// The dash and weight must also be on DR-243's menu. The menu is the
// UI's, but enforcing it here makes it a fact about the document rather
// than a habit of one dialog, and it is what keeps every authored weight
// at or above the lightest shipped one (`signal_style.dart`'s print
// floor depends on that).
//
// ═════════════════════════════════════════════════════════════════════
// TWO REGISTRIES, BECAUSE A DOCUMENT MAY BE OLDER THAN THE CATALOGUE
// ═════════════════════════════════════════════════════════════════════
// A new document carries the full seed (`blank_document.dart`), but one
// written before a family shipped does not carry it: `ctl.vantage`
// arrived at DR-120. A clone checked only against the document could
// take a shipped id, or pass PAL-1 against a palette missing the family
// it collides with. So both are consulted, and the document wins where
// both hold an id, since the project copy is authoritative for the
// drawing (DR-122 §11.121.6).
import 'package:rackpal_core/src/catalog/seed_registries.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/commands/media_type_commands.dart';
import 'package:rackpal_core/src/draw/pal1.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The families a clone is judged against: the document's, then any
/// shipped family the document does not carry.
Map<SignalFamilyId, SignalFamilyDef> _families(RackDocument doc) => {
  ...buildSeedSignalFamilies(),
  ...doc.registries.signalFamilies,
};

Map<SignalDomainId, SignalDomainDef> _domains(RackDocument doc) => {
  ...buildSeedRegistries().signalDomains,
  ...doc.registries.signalDomains,
};

Map<ConnectorTypeId, ConnectorTypeDef> _connectors(RackDocument doc) => {
  ...buildSeedRegistries().connectorTypes,
  ...doc.registries.connectorTypes,
};

/// A family id for a clone of [parent] named [spelling], unique against
/// the document AND the shipped catalogue.
///
/// **DERIVED FROM THE SPELLING, ON `mediaTypeIdFor`'s REASONING**
/// (DR-101): a registry key is written into every port that uses it and
/// read by a human diffing two `.rmpj` files, and `ctl.vantage` tells
/// that reader what it is where a UUID tells them to go and look. The
/// slug is `mediaSlugFor`'s, not a copy of it, so the two id rules cannot
/// drift. The prefix is the PARENT's first segment, so a clone of
/// Cresnet named Vantage is `ctl.vantage`, the id DR-120 gave the family
/// this surface exists to have made, and a clone of `rf.catv` stays
/// `rf.`. A collision takes a numeric suffix rather than overwriting.
SignalFamilyId signalFamilyIdFor(
  RackDocument doc,
  SignalFamilyId parent,
  String spelling,
) {
  final taken = _families(doc);
  final prefix = parent.v.split('.').first;
  final base = mediaSlugFor(spelling);
  var candidate = SignalFamilyId('$prefix.$base');
  var n = 2;
  while (taken.containsKey(candidate)) {
    candidate = SignalFamilyId('$prefix.${base}_$n');
    n++;
  }
  return candidate;
}

/// The outcome of [buildCloneSignalFamily].
sealed class CloneSignalFamilyResult {
  const CloneSignalFamilyResult();
}

final class CloneSignalFamilyReady extends CloneSignalFamilyResult {
  const CloneSignalFamilyReady(this.command);
  final CloneSignalFamilyCommand command;
}

/// A refusal, with the sentence a dialog shows as written.
final class CloneSignalFamilyRefused extends CloneSignalFamilyResult {
  const CloneSignalFamilyRefused(this.reason, {this.collisions = const []});

  final String reason;

  /// The PAL-1 violations behind a collision refusal, so an editor can
  /// mark the families involved. Empty for every other refusal.
  final List<Pal1Violation> collisions;
}

/// Builds the command that clones [parent], or says why it will not.
///
/// [connector] is the clone's default connector and defaults to the
/// parent's (DR-244). [dashPermille] and [weightPermille] must be an
/// option on DR-243's menu and must not collide under PAL-1.
CloneSignalFamilyResult buildCloneSignalFamily(
  RackDocument doc, {
  required SignalFamilyId parent,
  required String displayName,
  required String shortTag,
  required List<int> dashPermille,
  required int weightPermille,
  ConnectorTypeId? connector,
}) {
  final families = _families(doc);
  final from = families[parent];
  if (from == null) {
    return CloneSignalFamilyRefused(
      'There is no signal family ${parent.v} to clone.',
    );
  }
  final domain = _domains(doc)[from.domain];
  if (domain == null) {
    return CloneSignalFamilyRefused(
      '${from.displayName} names a domain, ${from.domain.v}, that this '
      'project does not have, so a clone of it would have no colour.',
    );
  }
  final name = displayName.trim();
  if (name.isEmpty) {
    return const CloneSignalFamilyRefused('A new family needs a name.');
  }
  final tag = shortTag.trim();
  if (tag.isEmpty) {
    return const CloneSignalFamilyRefused(
      'A new family needs a short tag, which is what its cables print.',
    );
  }
  final plug = connector ?? from.defaultConnector;
  if (!_connectors(doc).containsKey(plug)) {
    return CloneSignalFamilyRefused(
      '${plug.v} is not a connector type in the catalogue. A clone picks '
      'one that exists; it never adds one.',
    );
  }

  final menu = pal1ClassVocabulary(pal1EntriesOf(buildSeedRegistries()));
  final onMenu =
      menu.weights.contains(weightPermille) &&
      menu.dashes.any((d) => d.join(',') == dashPermille.join(','));
  if (!onMenu) {
    return const CloneSignalFamilyRefused(
      'That dash and weight are not among the ones a new family can use.',
    );
  }

  final id = signalFamilyIdFor(doc, parent, name);
  final domains = _domains(doc);
  // Through `pal1EntriesOf`, which sorts by id, so the refusal names the
  // same families in the same order every time.
  final palette = pal1EntriesOf(
    Registries(signalDomains: domains, signalFamilies: families),
  );
  final collisions = pal1ViolationsOf(
    Pal1Entry(
      familyId: id,
      domainId: domain.id,
      hue: domain.color,
      dashPermille: dashPermille,
      weightPermille: weightPermille,
    ),
    palette,
  );
  if (collisions.isNotEmpty) {
    return CloneSignalFamilyRefused(
      _collisionSentence(collisions, families, domains),
      collisions: collisions,
    );
  }

  return CloneSignalFamilyReady(
    CloneSignalFamilyCommand(
      family: SignalFamilyDef(
        id: id,
        displayName: name,
        domain: from.domain,
        defaultConnector: plug,
        defaultDirection: from.defaultDirection,
        defaultTopology: from.defaultTopology,
        shortTag: tag,
        // STORED AS OVERRIDES EVEN WHEN THEY EQUAL THE DOMAIN'S, so a
        // later change to the domain's base dash cannot silently restyle
        // a family whose author chose this dash by looking at it.
        dashOverride: dashPermille,
        lineWeightPermilleOverride: weightPermille,
        glyphOverride: from.glyphOverride,
      ),
    ),
  );
}

/// One sentence naming every family the choice collides with.
String _collisionSentence(
  List<Pal1Violation> collisions,
  Map<SignalFamilyId, SignalFamilyDef> families,
  Map<SignalDomainId, SignalDomainDef> domains,
) {
  String who(Pal1Entry e) {
    final name = families[e.familyId]?.displayName ?? e.familyId.v;
    return '$name (${e.familyId.v})';
  }

  // Each colliding family with its OWN domain: one choice can collide in
  // two domains at once, and naming only the first would misstate the
  // second.
  String whoWhere(Pal1Entry e) {
    final domain = domains[e.domainId]?.displayName;
    return domain == null ? who(e) : '${who(e)} in $domain';
  }

  String list(Iterable<String> names) {
    final all = names.toList();
    if (all.length == 1) return all.single;
    return '${all.take(all.length - 1).join(', ')} and ${all.last}';
  }

  final within = [
    for (final v in collisions.whereType<Pal1WithinDomainDuplicate>()) who(v.a),
  ];
  if (within.isNotEmpty) {
    return '${list(within)} already draws that dash at that weight.';
  }
  final cross = collisions.whereType<Pal1CrossDomainCollision>().toList();
  if (cross.isNotEmpty) {
    return 'Printed in black and white, that line would look the same as '
        '${list(cross.map((v) => whoWhere(v.a)))}: the same dash rhythm, at '
        'weights too close to tell apart.';
  }
  final p = collisions.whereType<Pal1PeriodBelowFloor>().first;
  return 'That dash repeats every ${p.entry.periodPermille! / 1000} pt, and '
      'under ${kPal1PeriodFloorPermille / 1000} pt a print blurs it solid.';
}

/// Adds a cloned [family] to the document's registry (DR-122).
///
/// Built only by [buildCloneSignalFamily], which is where every refusal
/// lives; this command trusts what it is handed, as `AddMediaTypeCommand`
/// trusts `mediaTypeIdFor`, except in the one way that lesson taught.
final class CloneSignalFamilyCommand extends Command<RackDocument> {
  CloneSignalFamilyCommand({required this.family});

  /// Complete when built, so redo recreates the identical family and every
  /// port stacked on its id still resolves.
  final SignalFamilyDef family;

  @override
  LabelKey get label => LabelKey.cloneSignalFamily;

  /// `meta` alone, on `SetConnectorAliasesCommand`'s reasoning: a new
  /// family changes what a person can author next and draws nothing until
  /// a port uses it.
  @override
  EpochMask get touches => EpochMask.meta;

  /// Empty: a registry key is not an entity a selection can hold.
  @override
  Iterable<Uuid> get affects => const [];

  bool _added = false;

  /// Adds the family, or REFUSES when its id is already registered.
  ///
  /// **AN ADD NEVER REPLACES**, the lesson `#935` taught
  /// `AddMediaTypeCommand`: an add that overwrote, undone, would delete
  /// somebody else's family.
  @override
  bool apply(RackDocument doc) {
    if (doc.registries.signalFamilies.containsKey(family.id)) {
      _added = false;
      return false;
    }
    doc.registries.signalFamilies[family.id] = family;
    _added = true;
    return true;
  }

  @override
  void revert(RackDocument doc) {
    if (_added) doc.registries.signalFamilies.remove(family.id);
    _added = false;
  }
}
