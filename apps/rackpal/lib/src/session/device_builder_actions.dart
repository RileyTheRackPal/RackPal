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
// project's own embedded snapshots — which have been in every `.rmpj`
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
import 'dart:async';

import 'package:rackpal/src/storage/prefs_store.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// Wires the builder's Save to a live [DocumentController].
///
/// [editing] is the id of the template being re-saved, or null when the
/// builder is authoring a new one. **The distinction decides whether a
/// save FORKS A VERSION or MINTS AN ID**, which is CR-050's rule: editing
/// a published template does not mutate it, it forks `version + 1` and
/// every earlier version stays resolvable, so the devices already placed
/// from v1 keep resolving to v1.
///
/// ══════════════════════════════════════════════════════════════════════
/// THE SECOND `Save` IN ONE SESSION FORKS. IT DOES NOT MINT A SECOND ID.
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
        if (portColumnPackNamed(name) case final pack?) pack,
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
    onSave: (body) {
      final doc = controller.doc;
      final templateId = authored ??= templateIdFor(doc, body.displayName);
      final version = nextTemplateVersion(doc, templateId);

      controller.run(
        SaveTemplateToProjectCommand(
          templateId: templateId,
          version: version,
          // A PLACEHOLDER HASH, AND IT IS LABELLED AS ONE. AC-042 cut the
          // cryptographic apparatus and kept `contentHash` because it is
          // "three lines and it is what makes the embedded-snapshot
          // argument true" — but the three lines are a real sha256 over
          // the canonical encoding, and that is a job with its own
          // question: which bytes, sorted how? Writing a fake that LOOKS
          // like a sha256 would be worse than writing one that plainly is
          // not, because a mismatch is a warning badge (AC-042) and a
          // badge that fires on every template teaches people to ignore
          // it.
          //
          // THE QUESTION NOW HAS AN ANSWER AND THE JOB HAS AN OWNER,
          // which it did not when this said "the `.rmdx` codec task owns
          // it (M4-M, #184)". That task is M4-M2 (`#235`) and it shipped
          // WITHOUT making the hash real, deliberately: the hasher is
          // shared with every `.rmpj` snapshot, so doing it inside one
          // file format's codec would leave the placeholder in the other.
          // It is `#795`. The bytes are DR-100 §11.99's, which is the
          // half that was genuinely open: `encodeCanonicalJsonBytes` over
          // `templateBodyToJson`, the pair that is now the single
          // authority on a `TemplateBody`'s shape.
          contentHash: 'unhashed:${templateId.v}@$version',
          body: body,
          capturedAt: controller.clock.nowUtc(),
        ),
      );
      return null;
    },
  );
}
