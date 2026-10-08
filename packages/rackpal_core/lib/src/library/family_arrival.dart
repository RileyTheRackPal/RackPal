// What a device arriving from a library does to the project's signal
// families (SFE-C6, DR-245 §11.244.3).
//
// ═══════════════════════════════════════════════════════════════════════
// ARRIVAL CHANGES NOTHING ALREADY DRAWN
// ═══════════════════════════════════════════════════════════════════════
// A library carries the families its devices name (§11.244.1). Placing one
// of those devices into a project brings each named family with it,
// copy-on-place (AC-041), in DR-103 §11.102.3's three cases, which the user
// chose to apply to families as they apply to templates:
//
//   * the project has no family by that id  -> add it as it arrives;
//   * it has the SAME family                -> add nothing;
//   * it has a DIFFERENT one                -> the newcomer takes a fresh
//     id (and a numbered name if its name is taken in the domain), and the
//     arriving device's ports are pointed at it.
//
// The third case is the one that protects the drawing: the family already
// there is what existing cables resolve against, so it is never touched.
//
// ═══════════════════════════════════════════════════════════════════════
// IT HAS TO BE IDEMPOTENT, AND THAT IS WHY IT LOOKS FOR ITSELF FIRST
// ═══════════════════════════════════════════════════════════════════════
// The second placement of the same device must not mint `ctl.vantage_4`
// beside the `ctl.vantage_3` the first one made. So before minting, the
// third case looks for a family the project already holds that is the
// arriving one in everything but its id and name, and points at that.
//
// It runs BEFORE the template is planned, because pointing ports at a new
// id changes the device's body, and `planLibraryPlacement` must compare
// the body the project would actually hold. Compared against the original,
// every later placement would look like a different device and mint
// another template copy too.
//
// ═══════════════════════════════════════════════════════════════════════
// A FAMILY THAT PRINTS LIKE ONE ALREADY HERE IS PLACED, AND SAID
// ═══════════════════════════════════════════════════════════════════════
// The user chose that over refusing placement and over placing silently.
// [FamilyArrival.notice] is the sentence; the Signal families section marks
// the family until its line is changed (SFE-C7).
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/catalog/seed_registries.dart';
import 'package:rackpal_core/src/commands/clone_signal_family.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/draw/pal1.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/persistence/json_codec.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// What placing a library device does to the project's families.
@immutable
final class FamilyArrival {
  const FamilyArrival({
    this.added = const [],
    this.repointed = const {},
    this.notice,
  });

  /// Families to add, already carrying the id and name they will have.
  final List<SignalFamilyDef> added;

  /// Arriving id to the id the project will resolve it as, for every
  /// family that could not keep its own id.
  final Map<SignalFamilyId, SignalFamilyId> repointed;

  /// The sentence to show when an added family prints like one already in
  /// the project, or null.
  final String? notice;

  bool get changesNothing => added.isEmpty && repointed.isEmpty;

  /// [body] with every port pointed at the ids the project will hold.
  ///
  /// A COPY, through the codec, so the library's own body is never edited
  /// in place: it is still on the shelf and will be placed again.
  TemplateBody mapBody(TemplateBody body) {
    if (repointed.isEmpty) return body;
    final copy = templateBodyFromJson(templateBodyToJson(body));
    for (final port in copy.ports) {
      port
        ..signalFamily = repointed[port.signalFamily] ?? port.signalFamily
        ..acceptedFamilies = [
          for (final f in port.acceptedFamilies) repointed[f] ?? f,
        ];
    }
    return copy;
  }

  /// The command that adds [added], or null when there is nothing to add.
  AddArrivedFamiliesCommand? get command =>
      added.isEmpty ? null : AddArrivedFamiliesCommand(families: added);
}

/// A family's encoding without its id and display name: what makes two
/// families "the same family" for arrival.
String _shape(SignalFamilyDef f) {
  final json = signalFamilyDefToJson(f)
    ..remove('id')
    ..remove('displayName');
  return '$json';
}

/// Plans the arrival of the families [body]'s ports name, out of the ones
/// a library [carried]. Writes nothing.
///
/// [libraryName] is how the notice names where a family came from.
FamilyArrival planFamilyArrival(
  RackDocument doc,
  TemplateBody body, {
  required List<SignalFamilyDef> carried,
  required String libraryName,
}) {
  final byId = {for (final f in carried) f.id: f};
  final named = <SignalFamilyId>{
    for (final port in body.ports) ...[
      port.signalFamily,
      ...port.acceptedFamilies,
    ],
  }.where(byId.containsKey).toList()..sort((a, b) => a.v.compareTo(b.v));
  return _arrive(doc, [for (final id in named) byId[id]!], libraryName);
}

/// Plans adding [family] straight from a library a person chose it from
/// (SFE-C8, DR-245 §11.244.5), under the SAME three cases as a device
/// bringing it, so there is one set of rules for both roads in.
FamilyArrival planFamilyAdoption(
  RackDocument doc,
  SignalFamilyDef family, {
  required String libraryName,
}) => _arrive(doc, [family], libraryName);

/// Whether [doc] already holds [family]: by id and identical, or as an
/// earlier arrival of it under a fresh id. What a library offers to add is
/// what this answers no for.
bool projectHoldsFamily(RackDocument doc, SignalFamilyDef family) {
  final there = doc.registries.signalFamilies[family.id];
  if (there != null &&
      signalFamilyDefToJson(there).toString() ==
          signalFamilyDefToJson(family).toString()) {
    return true;
  }
  return doc.registries.signalFamilies.values.any(
    (f) => f.id != family.id && _shape(f) == _shape(family),
  );
}

/// The three cases over [arriving], sorted by id by every caller.
FamilyArrival _arrive(
  RackDocument doc,
  List<SignalFamilyDef> arriving,
  String libraryName,
) {
  if (arriving.isEmpty) return const FamilyArrival();
  final byId = {for (final f in arriving) f.id: f};
  final named = byId.keys.toList()..sort((a, b) => a.v.compareTo(b.v));

  final shipped = buildSeedSignalFamilies();
  final held = doc.registries.signalFamilies;
  final added = <SignalFamilyDef>[];
  final repointed = <SignalFamilyId, SignalFamilyId>{};

  bool idTaken(SignalFamilyId id) =>
      held.containsKey(id) ||
      shipped.containsKey(id) ||
      added.any((f) => f.id == id);
  bool nameTaken(SignalDomainId domain, String name) => [
    ...held.values,
    ...added,
  ].any((f) => f.domain == domain && f.displayName == name);

  for (final id in named) {
    final arriving = byId[id]!;
    final there = held[id];
    if (there == null && !shipped.containsKey(id)) {
      added.add(arriving);
      continue;
    }
    if (there != null &&
        signalFamilyDefToJson(there).toString() ==
            signalFamilyDefToJson(arriving).toString()) {
      continue;
    }
    // CASE THREE, after looking for an earlier arrival of this same family.
    final earlier = held.values.where(
      (f) => f.id != id && _shape(f) == _shape(arriving),
    );
    if (earlier.isNotEmpty) {
      repointed[id] =
          (earlier.toList()..sort((a, b) => a.id.v.compareTo(b.id.v))).first.id;
      continue;
    }
    final prefix = id.v.split('.').first;
    final base = id.v.substring(prefix.length + 1);
    var n = 2;
    var fresh = SignalFamilyId('$prefix.${base}_$n');
    while (idTaken(fresh)) {
      n++;
      fresh = SignalFamilyId('$prefix.${base}_$n');
    }
    var name = arriving.displayName;
    var m = 2;
    while (nameTaken(arriving.domain, name)) {
      name = '${arriving.displayName} $m';
      m++;
    }
    added.add(
      SignalFamilyDef(
        id: fresh,
        displayName: name,
        domain: arriving.domain,
        defaultConnector: arriving.defaultConnector,
        defaultDirection: arriving.defaultDirection,
        defaultTopology: arriving.defaultTopology,
        aliases: arriving.aliases,
        shortTag: arriving.shortTag,
        dashOverride: arriving.dashOverride,
        lineWeightPermilleOverride: arriving.lineWeightPermilleOverride,
        glyphOverride: arriving.glyphOverride,
        clonedFrom: arriving.clonedFrom,
      ),
    );
    repointed[id] = fresh;
  }

  // PAL-1 over what is being added, against the project as it will be.
  final sentences = <String>[];
  if (added.isNotEmpty) {
    final palette = pal1EntriesOf(
      Registries(
        signalDomains: {
          ...buildSeedRegistries().signalDomains,
          ...doc.registries.signalDomains,
        },
        signalFamilies: {...held, for (final f in added) f.id: f},
      ),
    );
    for (final f in added) {
      final entry = palette.where((e) => e.familyId == f.id).firstOrNull;
      if (entry == null) continue;
      final hits = pal1ViolationsOf(entry, palette);
      if (hits.isEmpty) continue;
      sentences.add(
        '${f.displayName} (from $libraryName): '
        '${cloneCollisionSentence(doc, hits)}',
      );
    }
  }
  return FamilyArrival(
    added: added,
    repointed: repointed,
    notice: sentences.isEmpty
        ? null
        : '${sentences.join(' ')} Change its line in Project settings, '
              'Signal families.',
  );
}

/// Adds families a library device brought with it (DR-245 §11.244.3).
///
/// AN ADD NEVER REPLACES, on `#935`'s lesson: [planFamilyArrival] only
/// plans an id nothing holds, but two placements built before either
/// applies could carry the same one, and the second must not overwrite the
/// first or delete it on undo.
final class AddArrivedFamiliesCommand extends Command<RackDocument> {
  AddArrivedFamiliesCommand({required List<SignalFamilyDef> families})
    : families = List.unmodifiable(families);

  final List<SignalFamilyDef> families;

  @override
  LabelKey get label => LabelKey.addArrivedFamilies;

  /// `meta`, on `CloneSignalFamilyCommand`'s reasoning: a family draws
  /// nothing until a port uses it, and the port that will is placed by the
  /// next command in the same transaction.
  @override
  EpochMask get touches => EpochMask.meta;

  @override
  Iterable<Uuid> get affects => const [];

  final List<SignalFamilyId> _added = [];

  @override
  bool apply(RackDocument doc) {
    _added.clear();
    for (final f in families) {
      if (doc.registries.signalFamilies.containsKey(f.id)) continue;
      doc.registries.signalFamilies[f.id] = f;
      _added.add(f.id);
    }
    return _added.isNotEmpty;
  }

  @override
  void revert(RackDocument doc) {
    for (final id in _added) {
      doc.registries.signalFamilies.remove(id);
    }
    _added.clear();
  }
}
