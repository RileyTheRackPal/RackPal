// What a DOCUMENT can place, plus what the LOADED LIBRARIES offer, which
// is still not the same question as what this build ships. M4-S, DR-077
// §11.76.1, board `#733`; widened at `#241` by DR-102 §11.101.3.
//
// ═════════════════════════════════════════════════════════════════════
// A PROJECT HAS ONE SHELF AND IT IS `doc.templates`
// ═════════════════════════════════════════════════════════════════════
// `blank_document.dart` writes all 50 seeded archetypes into that map at
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
//
// ═════════════════════════════════════════════════════════════════════
// A TEMPLATE IN TWO SOURCES IS TWO ROWS (DR-102 §11.101.4)
// ═════════════════════════════════════════════════════════════════════
// The document and every loaded library are merged into ONE list, each
// row tagged with which shelf it came from, and an id present in more
// than one appears **once per source**. That is not the duplicate-row
// defect DR-077 §11.76.2 closed: that was one template appearing twice
// with no way to tell the copies apart, and this is two templates that
// happen to share a name, each answering for a different shelf.
//
// It is near-certain rather than exotic. `templateIdFor` derives an id
// from the display name identically on every machine (DR-101 §11.100.1),
// so two people who both typed `HDMI Matrix 16x16` have
// `tpl.hdmi_matrix_16x16` in both libraries. Hiding one would be the
// defect that function's own header refuses, reached through the palette
// instead of through an import.
//
// **THE COMPARATOR THEREFORE ENDS ON THE SOURCE, NOT ON THE ID.** The id
// alone stopped being unique across rows the moment libraries joined, and
// `List.sort` is not stable in Dart, so an id-only comparator would make
// the palette's order depend on map iteration. `(id, sourceRank,
// sourceKey)` is total by construction: one row per id per source.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/builder/fork_status.dart'
    show latestTemplateVersions;
import 'package:rackpal_core/src/catalog/seed_catalog.dart'
    show kSeedCatalogIds;
import 'package:rackpal_core/src/derived/device_loads.dart' show templateKey;
import 'package:rackpal_core/src/library/loaded_library.dart';
import 'package:rackpal_core/src/library/rmdx_codec.dart'
    show DeviceTemplateFile;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart' show TemplateId;

/// Where a placeable template came from, as far as THIS build can tell.
///
/// **A SEALED CLASS RATHER THAN AN ENUM PLUS A NULLABLE `libraryId`**,
/// which DR-102 §11.101.5 rules in terms and which is worth restating at
/// the place it binds: an enum beside a nullable field is a two-field
/// invariant no constructor can enforce and no `switch` can exhaust, and
/// `Outcome`, `FileContent` and `FsOp` already spell exactly this shape
/// here. A `LibraryProvenance` cannot exist without a library, and a
/// `SeededProvenance` cannot accidentally carry one.
sealed class TemplateProvenance {
  const TemplateProvenance();

  /// The two document variants, so a call site that means "seeded" reads
  /// as `TemplateProvenance.seeded` rather than as a constructor call.
  /// Typed as the concrete variants deliberately: nothing about the
  /// convenience should hide which class it is.
  static const SeededProvenance seeded = SeededProvenance();
  static const ProjectProvenance project = ProjectProvenance();

  /// Which SOURCE this is, as a stable string.
  ///
  /// The palette's chip identity (`#242`, DR-103 §11.102.6) and the
  /// comparator's final tiebreak, spelled once so the two cannot come to
  /// disagree about what counts as one source.
  String get sourceKey;

  /// Display order between rows that share a template id: the document's
  /// own row first, then libraries. Arbitrary but fixed, because the only
  /// requirement is that two calls agree.
  int get sourceRank;
}

/// One of the archetypes this build ships ([kSeedCatalogIds]).
final class SeededProvenance extends TemplateProvenance {
  const SeededProvenance();

  @override
  String get sourceKey => 'catalog';

  @override
  int get sourceRank => 0;
}

/// Authored in this project, or arriving with the file. Not "authored by
/// the person at the keyboard": a project mailed from another shop
/// carries its templates with it (AC-041), and this build cannot tell the
/// two apart, so the name says which SHELF and not which author.
final class ProjectProvenance extends TemplateProvenance {
  const ProjectProvenance();

  @override
  String get sourceKey => 'project';

  @override
  int get sourceRank => 1;
}

/// Offered by a library on the shelf, and not (yet) in this project.
///
/// **BOTH FIELDS, BECAUSE THEY ARE TWO FACTS.** [libraryId] is the shelf
/// identity a chip is keyed on and is unique; [libraryName] is what the
/// manifest calls itself and is not. Two libraries may both be called
/// `Shop Kit`, and a badge showing the name while the filter keys on the
/// id is the only combination that is both readable and correct. This is
/// `submittedBy`'s handle-and-id split (DR-033) applied one level down,
/// for the same reason.
@immutable
final class LibraryProvenance extends TemplateProvenance {
  const LibraryProvenance({required this.libraryId, required this.libraryName});

  final String libraryId;
  final String libraryName;

  @override
  String get sourceKey => 'library:$libraryId';

  @override
  int get sourceRank => 2;

  @override
  bool operator ==(Object other) =>
      other is LibraryProvenance &&
      other.libraryId == libraryId &&
      other.libraryName == libraryName;

  @override
  int get hashCode => Object.hash(libraryId, libraryName);

  @override
  String toString() => 'LibraryProvenance($libraryId)';
}

/// One row of what [buildPlaceableTemplates] found.
@immutable
final class PlaceableTemplate {
  const PlaceableTemplate({
    required this.templateId,
    required this.version,
    required this.contentHash,
    required this.body,
    required this.provenance,
  });

  final TemplateId templateId;

  /// The newest version of [templateId] on the SOURCE this row came from.
  final int version;

  /// What this row's source CLAIMS the body hashes to.
  ///
  /// Carried, never recomputed, for `buildTemplateImport`'s stated
  /// reason: recomputing would make every row verify by construction and
  /// AC-042's mismatch warning unreachable. Copy-on-place writes this
  /// value into the document verbatim (DR-103 §11.102.2), so what the
  /// project records is what the file claimed.
  final String contentHash;

  final TemplateBody body;

  final TemplateProvenance provenance;

  /// The id a placement gesture carries.
  String get id => templateId.v;

  /// A key unique across the whole merged list, which [id] no longer is.
  ///
  /// The palette's row key and the identity a `ValueKey` in a rebuilt
  /// list needs: two rows can share [id] and differ only by source
  /// (DR-102 §11.101.4), and a `ValueKey(id)` over both is the duplicate-
  /// key crash a `ListView` reports as a framework error.
  String get rowKey => '${provenance.sourceKey}/${templateKey(id, version)}';

  /// The `RackDocument.templates` key this row resolves to, or **null
  /// when the document does not hold it**.
  ///
  /// **NULLABLE ON PURPOSE** (DR-103 §11.102.8). This was a non-null
  /// `key` that spelled `"$id@$version"` unconditionally, which was
  /// correct for exactly as long as every row came from the document.
  /// A library row has no entry to resolve, and a getter that cheerfully
  /// spells one anyway is a lookup key that silently misses:
  /// `library_import.dart` calls `doc.templates[row.key]` in precisely
  /// that shape. Typing it `String?` is what made the compiler name every
  /// reader on the day library rows started existing.
  ///
  /// DERIVED rather than passed in, so it cannot drift from the source
  /// tag beside it. A document row's key is in `doc.templates` by
  /// construction: [buildPlaceableTemplates] read the row out of that map
  /// a moment earlier.
  String? get documentKey =>
      provenance is LibraryProvenance ? null : templateKey(id, version);

  /// Whether this template was authored in this project rather than
  /// shipped with the build -- the one question the palette's badge asks.
  ///
  /// **A LIBRARY ROW ANSWERS FALSE**, and that is not an oversight: the
  /// shelf it names is not this project's, and `exportableLibraryTemplates`
  /// filters on this getter to decide what a `.rmda` export packs. A
  /// library's templates re-exported out of a project that has never
  /// placed one would be a pack of somebody else's work.
  bool get isProjectAuthored => provenance is ProjectProvenance;

  /// Which library offered this row, or null for a document row.
  LibraryProvenance? get library {
    final p = provenance;
    return p is LibraryProvenance ? p : null;
  }
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

/// Every template [doc] can place, plus everything [libraries] offer,
/// newest version of each id **per source**, in a total and deterministic
/// order.
///
/// [libraries] defaults to empty, which is the pre-`#241` behaviour
/// exactly: every existing caller that has no shelf to read keeps
/// answering for the document alone, and a session whose data root is
/// unusable is one of them rather than a special case
/// (`library_directory.dart`).
///
/// Two calls with the same document and the same libraries return equal
/// lists. See this file's header for why the comparator ends on the
/// source rather than on the id.
List<PlaceableTemplate> buildPlaceableTemplates(
  RackDocument doc, {
  List<LoadedLibrary> libraries = const [],
}) {
  final rows = <PlaceableTemplate>[];

  final latest = latestTemplateVersions(doc.templates);
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
        contentHash: snapshot.contentHash,
        body: snapshot.body,
        provenance: kSeedCatalogIds.contains(entry.key.v)
            ? TemplateProvenance.seeded
            : TemplateProvenance.project,
      ),
    );
  }

  for (final library in libraries) {
    final provenance = LibraryProvenance(
      libraryId: library.id,
      libraryName: library.name,
    );
    // THE SAME REDUCTION, PER LIBRARY, and it is not decoration: a
    // `.rmda` can legitimately hold two versions of one template, since
    // `#240`'s export packs whatever the project held and CR-050 keeps
    // every earlier version resolvable. A library offering `@1` and `@3`
    // as two palette rows would ask the user a version question the
    // document's own rows never ask them.
    for (final entry in _newestPerId(library.templates)) {
      rows.add(
        PlaceableTemplate(
          templateId: entry.templateId,
          version: entry.version,
          contentHash: entry.contentHash,
          body: entry.body,
          provenance: provenance,
        ),
      );
    }
  }

  rows.sort((a, b) {
    final byId = a.id.compareTo(b.id);
    if (byId != 0) return byId;
    final byRank = a.provenance.sourceRank.compareTo(b.provenance.sourceRank);
    if (byRank != 0) return byRank;
    // The tiebreak that makes this TOTAL: two libraries can both offer
    // the id, and their shelf ids are unique because they are file names
    // in one directory.
    return a.provenance.sourceKey.compareTo(b.provenance.sourceKey);
  });
  return rows;
}

/// The newest entry for each `templateId` in [entries], in no order.
///
/// A local reduction rather than `latestTemplateVersions`, which takes a
/// `Map<String, TemplateSnapshot>` keyed the document's way. A library
/// holds a LIST and has no such keys, and inventing them here to reuse
/// one loop would put a second spelling of `"$id@$version"` in a file
/// that already imports the real one.
Iterable<DeviceTemplateFile> _newestPerId(List<DeviceTemplateFile> entries) {
  final best = <TemplateId, DeviceTemplateFile>{};
  for (final entry in entries) {
    final held = best[entry.templateId];
    if (held == null || entry.version > held.version) {
      best[entry.templateId] = entry;
    }
  }
  return best.values;
}
