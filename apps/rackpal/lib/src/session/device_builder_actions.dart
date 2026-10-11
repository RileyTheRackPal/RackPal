// What `Save` MEANS in the Device Builder. M4-D, docs/06 §7.1.
//
// The builder in `rackpal_ui` decides nothing about storage and runs no
// commands; this is where a finished `TemplateBody` becomes a snapshot on
// the document's undo stack, in the shape `outlet_template_actions.dart`
// and `locations_actions.dart` established.
//
// ═════════════════════════════════════════════════════════════════════
// IT SAVES INTO THE PROJECT, AND THE LIMIT IS STATED ON SCREEN
// ═════════════════════════════════════════════════════════════════════
// docs/06 §7.1 names three storage locations and the library directory
// service is M4-N's, so the only writable one that exists is the
// project's own embedded snapshots — which have been in every `.rppj`
// since M0 and are what `TemplateRef` resolves against (CR-054). A
// template authored here therefore travels with the file, and does NOT
// appear in another project until M4-N. The builder says that above the
// Save button rather than letting somebody find out by opening a second
// job.
//
// ═════════════════════════════════════════════════════════════════════
// "PLACEABLE IMMEDIATELY" WAS A CLAIM THIS FILE MADE AND NOTHING KEPT
// ═════════════════════════════════════════════════════════════════════
// That sentence sat in this header from the day M4-D shipped, and it was
// false the whole time: the palette was built from `buildSeedCatalog()`,
// so what this file wrote could be saved, round-tripped and never
// placed. M4's exit criterion clause 2 was unperformable for eleven days
// behind a comment asserting it (docs/12 §5.3.8, DR-077 §11.76).
//
// It is true now, and by a mechanism rather than by assertion: the
// palette lists `buildPlaceableTemplates(doc)`, this document's own
// shelf. If a later change makes it false again, the failing test is
// `rackpal_ui/test/canvas/palette_reads_the_document_test.dart`.
//
// AND SINCE M4-N (`#242`) THE SHELF IS NOT ONLY THIS DOCUMENT'S. What
// this file writes can be packed into a `.rpda` and imported into
// another job, where it is a palette row tagged with the library that
// carried it and placeable from there (DR-102 §11.101.3, DR-103
// §11.102.2). That closes the OTHER half of requirement 2, "author the
// long tail once and use it EVERYWHERE": until the library subsystem
// existed, a template's only home was the project that placed it.
import 'dart:async';

import 'package:rackpal/src/storage/prefs_store.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// Wires the builder's Save to a live [DocumentController].
///
/// [editing] is the id of the template being re-saved, or null when the
/// builder is authoring a new one. **The distinction decides whether a
/// save WRITES A VERSION or MINTS AN ID.** Which version it writes is
/// `planTemplateSave`'s (DR-202 §11.201.1): CR-050 forks `version + 1` so
/// devices already placed from v1 keep resolving to v1, and with nothing
/// placed from the newest version there is nobody to protect, so it is
/// replaced in place.
///
/// ══════════════════════════════════════════════════════════════════════
/// THE SECOND `Save` IN ONE SESSION WRITES THE SAME ID. IT DOES NOT MINT
/// A SECOND ONE.
/// ══════════════════════════════════════════════════════════════════════
/// The builder offers a plain `[Save]` beside `[Save & Close]` precisely
/// so a person can save and keep working, so pressing it twice is the
/// ORDINARY path. With `editing` null on every call, the second press ran
/// [templateIdFor] again, found the id taken, and returned `tpl.foo_2`:
/// two templates with one display name and no way to tell them apart.
/// That was invisible for exactly as long as nothing read what `Save`
/// wrote, which is §5.3.8's finding wearing a different hat (DR-077
/// §11.76.3).
///
/// So the id is remembered ACROSS CALLS, and the memory is the closure's
/// rather than the document's: it is a fact about this authoring session,
/// and a second builder window opened later is a second session authoring
/// a second device.
///
/// **WHICH MEANS THE CALLER MUST BUILD THIS ONCE PER SESSION, and from
/// `#778` to `#950` the shell did not.** A dialog built it once per
/// opening, which is where DR-077 fixed it; `#778` (2026-08-26) made the
/// builder a view and called this inside `build`. A save is a document
/// change, a document change is a rebuild,
/// and the fresh closure's `authored` was null again: the second Save on
/// a new template minted `tpl.foo_2` exactly as before DR-077. The shell
/// now keeps the result for the life of one builder session; see
/// `AppShellState._builderActionsFor`.
///
/// **RENAMING BETWEEN SAVES DOES NOT RE-ID.** The id is derived from the
/// display name only when it is minted. A rename that re-derived it would
/// orphan every device already placed from the earlier saves, since a
/// `TemplateRef` holds the id it was placed with.
DeviceBuilderActions buildDeviceBuilderActions({
  required DocumentController controller,
  PrefsStore? prefs,
  TemplateId? editing,
}) {
  // Null until the first save mints one; see the doc comment above.
  var authored = editing;
  return DeviceBuilderActions(
    // ══════════════════════════════════════════════════════════════════
    // THE COLUMN PACKS ARE A USER PREFERENCE, NOT PROJECT STATE
    // ══════════════════════════════════════════════════════════════════
    // Which columns an installer likes to see while authoring a network
    // switch is a fact about the installer, and canon §11.12.4 already
    // ruled UI chrome out of the document by name: it would re-fire for
    // every new file and it would sit inside CR-117's byte-exact surface.
    // So this goes to `prefs.json` beside the coach marks.
    //
    // NULL WHEN THERE IS NO STORE, and that is a real state rather than a
    // test hook: a read-only data folder produces a degraded session with
    // no `prefs.json` at all. The grid then runs its auto-reveal and
    // remembers nothing, which is the honest degradation.
    rememberedPacks: (category) => {
      for (final name in prefs?.current.packsFor(category) ?? const <String>{})
        ?portColumnPackNamed(name),
    },
    onPacksRemembered: (category, packs) {
      final store = prefs;
      if (store == null) return;
      unawaited(
        store.save(
          store.current.withPacksFor(category, {
            for (final pack in packs) pack.name,
          }),
        ),
      );
    },
    // THE VERSION DEVICES STAND ON, for the change class (DR-202
    // §11.201.2). Read through `authored`, so a new template has no
    // baseline until its first Save gives it an id, and none after that
    // until something is placed from it.
    placedBaseline: () {
      final id = authored;
      if (id == null) return null;
      final doc = controller.doc;
      final placed = newestPlacedTemplateVersion(doc, id);
      if (placed == null) return null;
      final snapshot = doc.templates[templateSnapshotKey(id, placed.version)];
      // A device whose snapshot is missing is a hand-edited file, and a
      // verdict against a body we do not have would be invented.
      if (snapshot == null) return null;
      return (
        body: snapshot.body,
        version: placed.version,
        count: placed.count,
      );
    },
    onSave: (body) {
      final doc = controller.doc;
      final templateId = authored ??= templateIdFor(doc, body.displayName);
      // REPLACES the newest version while nothing is placed from it, and
      // forks `version + 1` once something is (DR-202 §11.201.1).
      final (:version, replaces: _) = planTemplateSave(doc, templateId);

      controller.run(
        SaveTemplateToProjectCommand(
          templateId: templateId,
          version: version,
          // REAL AT `#795`. AC-042 cut the cryptographic apparatus and
          // kept `contentHash` because it is "three lines and it is what
          // makes the embedded-snapshot argument true", and those three
          // lines had one open question this file used to record: which
          // bytes, sorted how? DR-100 §11.99 answered it for the file
          // format and `templateContentHash` is that answer, so the
          // product has ONE convention rather than a second one minted
          // here.
          contentHash: templateContentHash(body),
          body: body,
          capturedAt: controller.clock.nowUtc(),
        ),
      );
      return null;
    },
  );
}
