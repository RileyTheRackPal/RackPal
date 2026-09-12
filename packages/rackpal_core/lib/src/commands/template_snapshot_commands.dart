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

/// Removes EVERY version of one template id from `RackDocument.templates`
/// (`#871`, DR-158 §11.157).
///
/// ═════════════════════════════════════════════════════════════════════
/// IT REMOVES THE TEMPLATE AND NOTHING ELSE
/// ═════════════════════════════════════════════════════════════════════
/// The devices standing on it go too (§11.157.4), and they go through one
/// `RemoveDeviceCommand` each in the same `Transaction`, not from here.
/// That is not tidiness: `RemoveDeviceCommand` already cascades links,
/// ports and orphaned nets under DR-013 §11.13.1, plans itself against
/// the aggregate as it stands when it applies, and restores every one of
/// them under the SAME ids on revert. A second implementation of that
/// inside this command would be a second thing to keep correct.
///
/// **APPLIED ALONE IT ORPHANS DEVICES, AND IT IS NOT THIS COMMAND'S JOB
/// TO REFUSE.** `planTemplateRemoval` is the answer the caller builds its
/// transaction from, and `buildRemoveTemplateCommand` is the only spelling
/// a surface should use.
///
/// ═════════════════════════════════════════════════════════════════════
/// EVERY VERSION, WHICH IS THE UNIT (§11.157.2)
/// ═════════════════════════════════════════════════════════════════════
/// CR-050 forks a version rather than mutating one, so an edited template
/// leaves earlier snapshots in the file. Removing the newest alone would
/// make the palette row vanish and come back at the previous version.
final class RemoveTemplateCommand extends Command<RackDocument> {
  RemoveTemplateCommand({required this.templateId});

  final TemplateId templateId;

  /// Every snapshot this run removed, under the key it sat at.
  ///
  /// **THE SAME OBJECTS UNDER THE SAME KEYS**, which is the discipline
  /// `RemoveDeviceCommand` holds for the links it takes: a
  /// `TemplateSnapshot` carries a `contentHash` every `TemplateRef`
  /// resolving it compares against (AC-042), so anything less than the
  /// same object makes delete-then-undo a lossy round trip through the
  /// entity CR-117's byte gate is about.
  final Map<String, TemplateSnapshot> _removed = <String, TemplateSnapshot>{};

  bool _applied = false;

  @override
  LabelKey get label => LabelKey.removeTemplateFromProject;

  /// The same mask `SaveTemplateToProjectCommand` carries, for the same
  /// two reasons read backwards: `structure` because the set of things
  /// that can be placed changed, `meta` because the template's
  /// `displayName` printed in the equipment list for every instance.
  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  /// EMPTY, on `SaveTemplateToProjectCommand`'s call: `affects` names
  /// entities a selection can hold and a template key is not one.
  @override
  Iterable<Uuid> get affects => const [];

  @override
  bool apply(RackDocument doc) {
    // Cleared, not appended to: `apply` runs again on every redo and each
    // run must describe THAT run rather than the union of all of them.
    _removed.clear();

    final keys = <String>[
      for (final entry in doc.templates.entries)
        if (entry.value.templateId == templateId) entry.key,
    ];
    for (final key in keys) {
      final snapshot = doc.templates.remove(key);
      if (snapshot != null) _removed[key] = snapshot;
    }
    _applied = true;
    // A template the document does not hold is a NO-OP and says so
    // (DR-156): returning true would put an entry on the undo stack for
    // an edit that changed nothing.
    return _removed.isNotEmpty;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('RemoveTemplateCommand.revert called before apply().');
    }
    // Insertion order moves these to the end, which is harmless:
    // `deepSortKeys` canonicalises every map before encoding, so CR-117's
    // byte round trip depends on the keys and values and never on the
    // order they were put back in.
    _removed
      ..forEach((key, snapshot) => doc.templates[key] = snapshot)
      ..clear();
    _applied = false;
  }
}
