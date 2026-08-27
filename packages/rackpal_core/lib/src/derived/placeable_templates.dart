// What a DOCUMENT can place, which is not the same question as what this
// build ships. M4-S, DR-077 §11.76.1, board `#733`.
//
// ═════════════════════════════════════════════════════════════════════
// A PROJECT HAS ONE SHELF AND IT IS `doc.templates`
// ═════════════════════════════════════════════════════════════════════
// `blank_document.dart` writes all 48 seeded archetypes into that map at
// creation, `SaveTemplateToProjectCommand` writes an authored body into
// the same map, and `buildPlaceFromCatalogCommand` has always resolved
// from it. The seeded catalog is therefore a CONTRIBUTOR to a document's
// shelf rather than a second shelf beside it, and a palette built from
// `buildSeedCatalog()` was reading a constant while standing next to the
// answer. That is the whole of §5.3.8's finding, and this function is
// what replaces the constant.
//
// ═════════════════════════════════════════════════════════════════════
// THE LATEST VERSION OF EACH ID, NOT EVERY VERSION
// ═════════════════════════════════════════════════════════════════════
// A document legitimately holds several versions of one template at once
// (CR-050): editing a published template forks `version + 1` and every
// earlier version stays resolvable, because the devices placed from v1
// resolve v1 forever through their own `TemplateRef`. A palette is asking
// a different question -- what would I place if I placed one NOW -- and
// its answer is the newest. `builder/fork_status.dart` already computes
// exactly this reduction for CR-062's badge, so it is reused rather than
// spelled a second time.
//
// ═════════════════════════════════════════════════════════════════════
// PROVENANCE IS DERIVED AND IS NEVER STORED
// ═════════════════════════════════════════════════════════════════════
// "Did this build ship this id" is a fact about the running application,
// not about the file, so it needs no model field, no codec change, and
// cannot touch CR-117's byte round-trip. A document from a build with a
// different catalog answers this question against THIS build's catalog,
// which is the honest answer to "is this one of mine or one of ours".
//
// NOTHING IS FILTERED OUT. A 0U occupant and a field device are both
// placeable rows in the palette today, refused at placement time with a
// sentence naming the actual reason (`catalog_placement.dart`), and
// silently dropping them here would move that refusal to a place with no
// voice.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/builder/fork_status.dart'
    show latestTemplateVersions;
import 'package:rackpal_core/src/catalog/seed_catalog.dart'
    show kSeedCatalogIds;
import 'package:rackpal_core/src/derived/device_loads.dart' show templateKey;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart' show TemplateId;

/// Where a placeable template came from, as far as THIS build can tell.
enum TemplateProvenance {
  /// One of the archetypes this build ships ([kSeedCatalogIds]).
  seeded,

  /// Authored in this project, or arriving with the file. Not "authored
  /// by the person at the keyboard": a project mailed from another shop
  /// carries its templates with it (AC-041), and this build cannot tell
  /// the two apart, so the name says which SHELF and not which author.
  project,
}

/// One row of what [buildPlaceableTemplates] found.
@immutable
final class PlaceableTemplate {
  const PlaceableTemplate({
    required this.templateId,
    required this.version,
    required this.body,
    required this.provenance,
  });

  final TemplateId templateId;

  /// The newest version of [templateId] the document holds.
  final int version;

  final TemplateBody body;

  final TemplateProvenance provenance;

  /// The id a placement gesture carries, and the palette's row key.
  String get id => templateId.v;

  /// The `RackDocument.templates` key this row resolves to.
  String get key => templateKey(templateId.v, version);

  /// Whether this template was authored rather than shipped -- the one
  /// question the palette's badge asks, spelled once so that a `==`
  /// against an enum value is not written at four call sites.
  bool get isProjectAuthored => provenance == TemplateProvenance.project;
}

/// The newest snapshot of [templateId] in [doc], or null when no version
/// of it is there.
///
/// **WHAT "PLACE THIS TEMPLATE" MEANS** (DR-077 §11.76.3). A gesture
/// carries an id and not a version, because a person picking a row means
/// the template as it stands. Devices already placed are unaffected: each
/// carries its own version in its `TemplateRef`, which is the guarantee
/// CR-050 exists to make.
///
/// Behaviour is identical to the `"$id@1"` this replaced wherever only v1
/// exists, which is every seeded id in every project, so this is a
/// widening rather than a change.
///
/// A LINEAR SCAN, not a `latestTemplateVersions` map, because the caller
/// wants one id: building a map of every id to answer about one is the
/// reduction done backwards. Placement is a gesture, never a frame.
TemplateSnapshot? resolveLatestTemplate(RackDocument doc, String templateId) {
  TemplateSnapshot? best;
  for (final snapshot in doc.templates.values) {
    if (snapshot.templateId.v != templateId) continue;
    if (best == null || snapshot.version > best.version) best = snapshot;
  }
  return best;
}

/// Every template [doc] can place, newest version of each id, in a total
/// and deterministic order.
///
/// Ordered by template id, which is unique across the returned rows by
/// construction (one row per id), so the comparator needs no tiebreak to
/// be total -- see §8.4. Two calls on one document return equal lists.
List<PlaceableTemplate> buildPlaceableTemplates(RackDocument doc) {
  final latest = latestTemplateVersions(doc.templates);
  final rows = <PlaceableTemplate>[];
  for (final entry in latest.entries) {
    final snapshot = doc.templates[templateKey(entry.key.v, entry.value)];
    // Unreachable through `latestTemplateVersions`, which reads the same
    // map, and not asserted away: this file is a projection and a
    // projection that throws on a hand-edited document takes the palette
    // down with it. A missing snapshot is one row absent, not a crash.
    if (snapshot == null) continue;
    rows.add(
      PlaceableTemplate(
        templateId: entry.key,
        version: entry.value,
        body: snapshot.body,
        provenance: kSeedCatalogIds.contains(entry.key.v)
            ? TemplateProvenance.seeded
            : TemplateProvenance.project,
      ),
    );
  }
  rows.sort((a, b) => a.id.compareTo(b.id));
  return rows;
}
