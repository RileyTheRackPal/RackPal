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
  if (from.clonedFrom case final grand?) {
    final name = families[grand]?.displayName ?? grand.v;
    return CloneSignalFamilyRefused(
      '${from.displayName} is itself a clone. Clone the family it came '
      'from, $name, instead.',
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

  // A SECOND FAMILY WITH THE SAME NAME IN ONE DOMAIN IS REFUSED, because
  // the family picker shows and resolves a family by its printed label
  // (`signalFamilyCellLabel`: domain tag and name). A clone named
  // `Cresnet` in Control would print exactly as the real one, and the
  // picker could not tell a person which of the two they were choosing.
  for (final f in families.values) {
    if (f.domain == from.domain &&
        f.displayName.trim().toLowerCase() == name.toLowerCase()) {
      return CloneSignalFamilyRefused(
        '${domain.displayName} already has a family called '
        '${f.displayName} (${f.id.v}). A new one needs its own name.',
      );
    }
  }

  final menu = cloneMenu();
  final onMenu =
      menu.weights.contains(weightPermille) &&
      menu.dashes.any((d) => d.join(',') == dashPermille.join(','));
  if (!onMenu) {
    return const CloneSignalFamilyRefused(
      'That dash and weight are not among the ones a new family can use.',
    );
  }

  final id = signalFamilyIdFor(doc, parent, name);
  final palette = _palette(doc);
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
      cloneCollisionSentence(doc, collisions),
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
        clonedFrom: from.id,
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════
// WHAT THE CLONE DIALOG READS, SO IT AND THE COMMAND CANNOT DISAGREE
// ═════════════════════════════════════════════════════════════════════
// The dialog (SFE-C1/C2) draws every option with its verdict BEFORE the
// person chooses, and the builder above refuses AFTER. If each computed
// its own menu, palette or sentence, a swatch could read free and then be
// refused, or read taken for a reason the refusal never gives. So the
// four things the dialog needs live here, beside the builder that uses
// the same ones.

/// Everything a clone is judged against: the document's families and any
/// shipped family it lacks, through `pal1EntriesOf`, which sorts by id so
/// a refusal names the same families in the same order every time.
List<Pal1Entry> _palette(RackDocument doc) => pal1EntriesOf(
  Registries(signalDomains: _domains(doc), signalFamilies: _families(doc)),
);

/// DR-243's menu: one dash per class at the shipped weights, from the
/// SHIPPED palette, so a document's own clones cannot reshape it.
Pal1Vocabulary cloneMenu() =>
    pal1ClassVocabulary(pal1EntriesOf(buildSeedRegistries()));

/// What a new family in [domain] can still take, every option with its
/// blockers, or null when [doc] has no such domain.
Pal1Headroom? cloneHeadroom(RackDocument doc, SignalDomainId domain) {
  final d = _domains(doc)[domain];
  if (d == null) return null;
  return pal1Headroom(
    palette: _palette(doc),
    domain: d,
    vocabulary: cloneMenu(),
  );
}

/// The families a person may clone FROM: the shipped ones, never a clone.
///
/// DR-122 §11.121.2 says a family is *"derived from a shipped family"*. A
/// clone of a clone would inherit the same locked fields, so it is not
/// dangerous; it is refused because the ruling says shipped, and because
/// "clone of Vantage, clone of Cresnet" is a chain a person reading the
/// picker should never have to follow.
Registries cloneableFamilies(RackDocument doc) => Registries(
  signalDomains: _domains(doc),
  signalFamilies: {
    for (final f in _families(doc).values)
      if (f.clonedFrom == null) f.id: f,
  },
);

/// The domain a clone of a family in [domain] draws in, from the same
/// document-then-seed union the builder judges against, or null.
SignalDomainDef? cloneDomain(RackDocument doc, SignalDomainId domain) =>
    _domains(doc)[domain];

/// The connector types a clone may take as its default (DR-244 §11.243.3),
/// sorted by display name then id so a menu built from it holds still.
List<ConnectorTypeDef> cloneConnectorTypes(RackDocument doc) =>
    _connectors(doc).values.toList()..sort((a, b) {
      final byName = a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      );
      return byName != 0 ? byName : a.id.v.compareTo(b.id.v);
    });

/// Why the family [id] prints like another in [doc], or null when it does
/// not (DR-245 §11.244.3).
///
/// The Signal families section marks a family with this until its line is
/// changed. COMPUTED, NEVER STORED: a mark kept in the file would outlive
/// the clash the day the other family changed, and this cannot.
String? familyPrintClash(RackDocument doc, SignalFamilyId id) {
  final palette = _palette(doc);
  final entry = palette.where((e) => e.familyId == id).firstOrNull;
  if (entry == null) return null;
  final hits = pal1ViolationsOf(entry, palette);
  return hits.isEmpty ? null : cloneCollisionSentence(doc, hits);
}

/// One sentence naming every family [collisions] involves.
String cloneCollisionSentence(
  RackDocument doc,
  List<Pal1Violation> collisions,
) => _collisionSentence(collisions, _families(doc), _domains(doc));

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
