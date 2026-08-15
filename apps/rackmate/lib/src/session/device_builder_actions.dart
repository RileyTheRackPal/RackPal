// What `Save` MEANS in the Device Builder. M4-D, docs/06 §7.1.
//
// The builder in `rackmate_ui` decides nothing about storage and runs no
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
// template authored here is therefore placeable immediately and travels
// with the file, and does NOT appear in another project until M4-N. The
// builder says that above the Save button rather than letting somebody
// find out by opening a second job.
import 'dart:async';

import 'package:rackmate/src/storage/prefs_store.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// A stable-ish template id derived from the display name.
///
/// **DERIVED FROM THE SPELLING RATHER THAN MINTED AS A UUID**, which is
/// `mediaTypeIdFor`'s call and made here for the same reason: this id is
/// written into every `TemplateRef` that resolves the device, it is the
/// left half of the `"$templateId@$version"` key, and it is read by a
/// person diffing two `.rmpj` files. `tpl.hdmi_matrix_16x16` tells that
/// reader what the device is; `tpl.9f3c-...` tells them to go and look it
/// up.
///
/// Collisions get a numeric suffix rather than joining an existing id:
/// two devices a user happened to name the same thing are two devices,
/// and silently merging them would put one template's ports on the
/// other's instances.
TemplateId templateIdFor(RackDocument doc, String displayName) {
  final slug = displayName
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final base = slug.isEmpty ? 'device' : slug;

  final taken = {for (final s in doc.templates.values) s.templateId};
  var candidate = TemplateId('tpl.$base');
  var n = 2;
  while (taken.contains(candidate)) {
    candidate = TemplateId('tpl.${base}_$n');
    n++;
  }
  return candidate;
}

/// Wires the builder's Save to a live [DocumentController].
///
/// [editing] is the id of the template being re-saved, or null when the
/// builder is authoring a new one. **The distinction decides whether a
/// save FORKS A VERSION or MINTS AN ID**, which is CR-050's rule: editing
/// a published template does not mutate it, it forks `version + 1` and
/// every earlier version stays resolvable, so the devices already placed
/// from v1 keep resolving to v1.
DeviceBuilderActions buildDeviceBuilderActions({
  required DocumentController controller,
  PrefsStore? prefs,
  TemplateId? editing,
}) => DeviceBuilderActions(
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
    final templateId = editing ?? templateIdFor(doc, body.displayName);
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
        // question (which bytes? sorted how?) that the `.rmdx` codec
        // task owns (M4-M, #184). Writing a fake that LOOKS like a
        // sha256 would be worse than writing one that plainly is not,
        // because a mismatch is a warning badge (AC-042) and a badge
        // that fires on every template teaches people to ignore it.
        contentHash: 'unhashed:${templateId.v}@$version',
        body: body,
        capturedAt: controller.clock.nowUtc(),
      ),
    );
    return null;
  },
);
