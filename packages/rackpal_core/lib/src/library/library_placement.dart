// What placing a LIBRARY row costs the document (`#242`, DR-103
// §11.102.2 and §11.102.3).
//
// ═══════════════════════════════════════════════════════════════════════
// THE PALETTE LISTS ROWS THE PLACEMENT PATH CANNOT RESOLVE
// ═══════════════════════════════════════════════════════════════════════
// `buildPlaceFromCatalogCommand` opens with `resolveLatestTemplate(doc,
// catalogId)` and has resolved out of `RackDocument.templates` since M0.
// DR-102 put library rows in the palette and did not rule what happens
// when one is double-clicked, so built literally it lists rows that
// answer *"Unknown catalog template"* and name an id on screen.
//
// DR-103 §11.102.2 rules the answer, and it is not an invention: **v1 is
// copy-on-place** (AC-041). The snapshot is embedded in the document and
// `templateRef{templateId, version, contentHash}` records what was
// placed. docs/02's rejected-alternatives table is blunter: the
// alternative to an embedded snapshot is *"a live library reference"*,
// costing *"non-reproducible deliverables; drawings that change silently
// across machines"*. A device resolving out of a `.rmda` on one person's
// shelf IS that alternative. The copy is the format's standing promise;
// the only open question was where it gets paid, and it is paid here.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ID THAT IS ALREADY TAKEN IS THE COMMON CASE, NOT THE EDGE
// ═══════════════════════════════════════════════════════════════════════
// `templateIdFor` derives an id from the display name identically on
// every machine (DR-101 §11.100.1), so two people who both typed
// `HDMI Matrix 16x16` have `tpl.hdmi_matrix_16x16`, both at version 1.
// DR-102 §11.101.4 already ruled those are two ROWS; this is the same
// ruling one step later, at the moment one of them has to land in a
// document holding the other. Three cases, all decidable with no prompt
// (DR-103 §11.102.3):
//
//   * the key is free       -> copy it verbatim, version preserved;
//   * the key holds the SAME body -> copy nothing, place what is there;
//   * the key holds a DIFFERENT body -> mint a fresh id at version 1.
//
// **OVERWRITING WAS NEVER AVAILABLE.** The key is what placed devices
// resolve against, so rewriting it would change what somebody's existing
// device IS. And placing the document's version instead would silently
// hand the user the other library's device under the name they clicked.
//
// ═══════════════════════════════════════════════════════════════════════
// THE COMPARISON IS A RECOMPUTED HASH, NOT THE CLAIMED ONE
// ═══════════════════════════════════════════════════════════════════════
// `templateContentHash` (`#795`), over both bodies. Comparing the two
// `contentHash` STRINGS would answer "cannot tell" for every template
// written before `#795` and every hand-authored one, and there is no user
// to ask in the middle of a double-click. Hashing both answers the
// question actually being asked, which is whether these are the same
// device. What gets WRITTEN is still the claimed hash, never the
// recomputed one, for `buildTemplateImport`'s reason: the document must
// record what the file claimed, or AC-042's mismatch warning becomes
// unreachable.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/commands/template_snapshot_commands.dart';
import 'package:rackpal_core/src/derived/placeable_templates.dart';
import 'package:rackpal_core/src/library/template_hash.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart' show TemplateId;

/// How a library row lands in a document.
@immutable
final class LibraryPlacement {
  const LibraryPlacement({required this.snapshot, this.copy});

  /// What to place: the snapshot [copy] writes, or the one the document
  /// already held.
  final TemplateSnapshot snapshot;

  /// The command that puts [snapshot] in the document, or **null when
  /// the document already holds it**.
  ///
  /// Null is the quiet case in every sense: nothing is written, nothing
  /// is announced (DR-103 §11.102.4), and the transaction holds one
  /// command instead of two. It is also what a SECOND placement of the
  /// same library template looks like, which is why the rule needs no
  /// counter and cannot drift from what the document did.
  final SaveTemplateToProjectCommand? copy;

  bool get copies => copy != null;

  /// The id `buildPlaceFromCatalogCommand` should be asked for, which is
  /// **not always the row's**: case three mints a fresh one.
  String get templateId => snapshot.templateId.v;

  /// Whether the id changed on the way in, which is the one outcome a
  /// caller might want to say out loud beyond the copy itself.
  bool renamedFrom(PlaceableTemplate row) =>
      snapshot.templateId != row.templateId;
}

/// Decides what placing [row] costs [doc]. Writes nothing.
///
/// **A PLAN, NOT AN EFFECT**, on `planTemplateImport`'s split: every
/// branch above is testable without a controller, a rack or a widget, and
/// the caller decides whether to run the transaction. It matters more
/// here than there, because the placement it precedes can still be
/// refused for a full rack and the copy must not have happened by then
/// (DR-103 §11.102.2).
///
/// Passing a row whose provenance is not a library is a programmer error:
/// a document row is already in the document and needs no plan. It is an
/// `assert` rather than a refusal for `buildTemplateImport`'s reason, the
/// only way to reach it being to have asked a question nobody was owed.
LibraryPlacement planLibraryPlacement(
  RackDocument doc,
  PlaceableTemplate row, {
  required DateTime capturedAt,
}) {
  assert(
    row.provenance is LibraryProvenance,
    'a document row is already in the document',
  );

  final held = doc.templates[templateSnapshotKey(row.templateId, row.version)];
  if (held != null) {
    if (templateContentHash(held.body) == templateContentHash(row.body)) {
      // CASE TWO. The document already holds this exact template, so
      // there is nothing to copy and nothing to say. This is also every
      // placement after the first.
      return LibraryPlacement(snapshot: held);
    }
    // CASE THREE. Same id and version, different device. A fresh id at
    // version 1, exactly as `buildTemplateImport`'s `separateTemplate`
    // resolution does, because that is DR-101's non-destructive branch
    // and this is the same collision reached through the palette.
    return _copyAs(
      row,
      id: templateIdFor(doc, row.body.displayName),
      version: 1,
      capturedAt: capturedAt,
    );
  }

  // CASE ONE. **The version is preserved, not reset to 1**, for
  // `buildTemplateImport`'s stated reason: a library's `@3` lands at `@3`
  // so a later `@4` slots in above it and the chain keeps meaning what it
  // means. Sparse versions are already legal everywhere that reads them.
  return _copyAs(
    row,
    id: row.templateId,
    version: row.version,
    capturedAt: capturedAt,
  );
}

/// The copy command plus the snapshot it writes, built once so the two
/// cannot come to disagree.
///
/// **`SaveTemplateToProjectCommand`'s REVERT STAYS BOUNDED**, which is the
/// property that had to survive. Its own comment rests that on
/// `nextTemplateVersion` having guaranteed the key was free; here the
/// guarantee is established differently and just as strictly, case one
/// being reached only when the key is absent and case three minting an id
/// nothing holds. An undo therefore still cannot delete a snapshot
/// somebody else's devices resolve against.
LibraryPlacement _copyAs(
  PlaceableTemplate row, {
  required TemplateId id,
  required int version,
  required DateTime capturedAt,
}) {
  final snapshot = TemplateSnapshot(
    templateId: id,
    version: version,
    // CARRIED, NOT RECOMPUTED. See the header: the document records what
    // the file claimed, and the difference between that and what the
    // body IS is the whole of AC-042.
    contentHash: row.contentHash,
    capturedAt: capturedAt,
    body: row.body,
  );
  return LibraryPlacement(
    snapshot: snapshot,
    copy: SaveTemplateToProjectCommand(
      templateId: id,
      version: version,
      contentHash: row.contentHash,
      body: row.body,
      capturedAt: capturedAt,
    ),
  );
}
