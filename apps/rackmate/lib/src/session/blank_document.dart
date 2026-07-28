// What `Ctrl+N` produces.
//
// ==================================================================
// WHY THE BLANK PROJECT CONTAINS A RACK
// ==================================================================
// docs/04 §9 says first launch shows a start card offering `Blank
// project` plus four starters, and that "New rack is three fields — Name,
// Preset, Height". THAT DIALOG DOES NOT EXIST YET. So a blank project
// with genuinely zero racks would give the user a `Ctrl+N` that lands
// them on a panel explaining there is no way to add a rack — a working
// keystroke that produces a dead end.
//
// One 42U rack is therefore seeded, and it is a DEFAULT rather than a
// fabrication: 42U is the M1 exit criterion's own shape, the rack editor
// already has height editing, presets and rename wired through real
// commands, so every field of it is changeable by the user in this build.
// When the New-rack dialog lands, this becomes its default row and the
// seeding moves there.
//
// ==================================================================
// WHY THE SEED CATALOG IS EMBEDDED
// ==================================================================
// `buildPlaceFromCatalogCommand` resolves `doc.templates['<id>@1']` and
// REFUSES when it is missing — correctly, since a device placed against a
// template the document does not carry would lose its footprint the
// moment it was reopened elsewhere. A blank document with no templates
// would therefore have a palette where every row refuses. Embedding the
// catalog as version-1 snapshots is what the demo document already does,
// for the same reason.
import 'package:rackmate_core/rackmate_core.dart';

/// The height a blank project's one rack starts at. See the header.
const int kBlankProjectRackHeightU = 42;

/// A new, empty, never-saved project.
///
/// [now] is injected rather than read from `DateTime.now()` so a test can
/// assert byte-exact round-tripping of a freshly created document.
RackDocument buildBlankDocument({
  required DateTime now,
  required String appVersion,
  Uuid? id,
  Uuid? rackId,
  String rackDesignator = 'RK-1',
  String rackName = 'Rack 1',
  Map<String, TemplateBody>? catalog,
}) {
  final meta = EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'local');
  final doc = RackDocument(
    id: id ?? newEntityId(),
    appVersion: appVersion,
    createdAt: now,
    modifiedAt: now,
    meta: meta,
  );

  doc.racks[rackId ?? (rackId = newEntityId())] = Rack(
    id: rackId,
    name: rackName,
    designator: rackDesignator,
    heightU: kBlankProjectRackHeightU,
    order: const FracIndex('a0'),
    meta: meta,
  );

  for (final entry in (catalog ?? buildSeedCatalog()).entries) {
    doc.templates[catalogTemplateKey(entry.key)] = TemplateSnapshot(
      templateId: TemplateId(entry.key),
      version: 1,
      contentHash: 'sha256:seed-${entry.key}',
      capturedAt: now,
      body: entry.value,
    );
  }

  // The shop's cable-colour convention, copied in at CREATION rather than
  // defaulted on `ProjectSettings` — a document decoded from an older
  // file must come back with an EMPTY convention, because its author
  // never authored one. A new document has an author who is choosing it.
  // Every entry is ordinary editable data from this line onward.
  doc.settings.jacketColorConventions.addAll(
    buildDefaultJacketColorConvention(),
  );

  // The signal-domain, signal-family and connector registries, seeded at
  // CREATION for the same reason and by DR-010 §11.10.2's explicit
  // ruling. NOT a codec transform: if `write()` recomputed the referenced
  // subset instead, a document carrying an entry nothing references would
  // lose it on save and CR-117's `write(read(bytes)) == bytes` would
  // fail. Assigned wholesale rather than `addAll`ed into the constructor's
  // empty maps because a brand-new document has nothing to merge with.
  doc.registries = buildSeedRegistries();

  return doc;
}
