// Saving a builder template into the project. M4-D, docs/06 §7.1.
//
// ═════════════════════════════════════════════════════════════════════
// WHY A DOCUMENT COMMAND AND NOT A LIBRARY WRITE
// ═════════════════════════════════════════════════════════════════════
// docs/06 §7.1 names three storage locations: the app catalog directory
// (seeded, read-only), the user library directory (writable), and
// **per-project embedded snapshots**. The library directory service is
// M4-N and does not exist; the third one has existed since M0, is
// persisted in every `.rmpj`, and is what `TemplateRef` resolves against
// (CR-054). So the builder saves there, and a template authored in a
// project lives in that project until M4-N gives it a shelf of its own.
// The builder's save dialog says so rather than implying otherwise.
//
// **This is a document edit and belongs on the document's undo stack**,
// which is not a contradiction of CR-106. The builder's own stack is
// scoped to the `TemplateBody` being edited and dies with the window;
// what a save leaves behind is a snapshot the project keeps, and undoing
// that is undoing an edit to the project. CR-106's "library operations
// are not undoable" is about acts on the SHELF (delete a template,
// import one, set a favourite) and there is no shelf here.
//
// ═════════════════════════════════════════════════════════════════════
// THE VERSION IS ALLOCATED BY THE CALLER, NOT IN `apply`
// ═════════════════════════════════════════════════════════════════════
// The `Command` contract: `apply` must be a pure function of the command
// and the aggregate, so that redo produces the identical result. A
// version chosen inside `apply` would advance again on every redo, and
// the key `"$templateId@$version"` would drift away from the
// `TemplateRef`s already pointing at it. `nextTemplateVersion` is the
// allocator, and it is a free function for exactly the reason
// `mediaTypeIdFor` is.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The document key a snapshot of [templateId] at [version] is stored
/// under. One spelling, because `catalog_placement.dart` and the codec
/// both join on it.
String templateSnapshotKey(TemplateId templateId, int version) =>
    '${templateId.v}@$version';

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
/// MOVED HERE FROM THE APP at `#232`, and the comment that sent it there
/// was wrong. It read that this belongs in the app "where the collision
/// policy and the document's existing ids both live". The collision
/// policy is `doc.templates`, which is core data, and there is no
/// app-specific knowledge in the function at all. Door 3 needs the same
/// allocation from `rackpal_ui`, which cannot import the app, and two
/// spellings of one naming rule is the drift this repository keeps paying
/// for.
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

/// The next free version for [templateId] in [doc].
///
/// **Monotonic int, never a semver** (CR-050): a semver whose components
/// are computed adds a vocabulary without adding a capability, and
/// `TemplateRef` cannot hold one. Editing a published template does not
/// mutate it; it forks `version + 1` and every earlier version stays
/// resolvable, which is what makes an embedded snapshot trustworthy.
int nextTemplateVersion(RackDocument doc, TemplateId templateId) {
  var highest = 0;
  for (final s in doc.templates.values) {
    if (s.templateId == templateId && s.version > highest) {
      highest = s.version;
    }
  }
  return highest + 1;
}

/// Writes one [TemplateSnapshot] into `RackDocument.templates`.
final class SaveTemplateToProjectCommand extends Command<RackDocument> {
  SaveTemplateToProjectCommand({
    required this.templateId,
    required this.version,
    required this.contentHash,
    required this.body,
    required this.capturedAt,
  });

  final TemplateId templateId;

  /// From [nextTemplateVersion], in the CALLER. See the file header.
  final int version;

  /// A warning-level check, never a load failure (AC-042).
  final String contentHash;

  /// **Already a copy when it gets here.** `DeviceBuilderScreen` hands
  /// over `copyTemplateBody(session.body)`, so the editor can keep
  /// editing after a plain `Save` without mutating what the document now
  /// holds. This command does not copy again, and it must not be handed
  /// a live body.
  final TemplateBody body;

  final DateTime capturedAt;

  String get key => templateSnapshotKey(templateId, version);

  @override
  LabelKey get label => LabelKey.saveTemplateToProject;

  /// `structure` because the set of things that can be placed changed,
  /// and `meta` because a template's `displayName` prints in the
  /// equipment list for every instance of it.
  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  /// EMPTY. `affects` names ENTITIES a selection can hold, and a
  /// template key is not one — the same call `AddMediaTypeCommand` makes
  /// for a registry key, and for the same reason: returning a `Uuid` cast
  /// from this key would make selection code believe a template is
  /// selectable.
  @override
  Iterable<Uuid> get affects => const [];

  @override
  bool apply(RackDocument doc) {
    doc.templates[key] = TemplateSnapshot(
      templateId: templateId,
      version: version,
      contentHash: contentHash,
      body: body,
      capturedAt: capturedAt,
    );
    return true;
  }

  /// Removes only what this command added.
  ///
  /// **Bounded, in `AddMediaTypeCommand`'s sense**: the key is
  /// `"$templateId@$version"` and [nextTemplateVersion] guarantees it was
  /// free, so a revert cannot delete a snapshot somebody else's devices
  /// resolve against. That is what makes undoing a save safe even though
  /// undoing a library DELETE would not be (CR-106).
  @override
  void revert(RackDocument doc) {
    doc.templates.remove(key);
  }
}
