// What importing a `.rmdx` into a project MEANS (DR-101 §11.100, `#236`).
//
// ==================================================================
// THE DECISION IS HERE AND THE DIALOG IS NOT
// ==================================================================
// [planTemplateImport] answers "is there a collision, and if so with
// what?"; [buildTemplateImport] turns an answer into a command. The
// question in between is a HUMAN's (DR-101 §11.100.3) and this file does
// not ask it, which is `session_prompts.dart`'s split applied one layer
// down: the branches are testable here without pumping a widget, and the
// dialog is tested separately with real taps.
//
// ==================================================================
// WHY A COLLISION IS COMMON RATHER THAN RARE
// ==================================================================
// `templateIdFor` derives the id FROM THE DISPLAY NAME, identically in
// every project on every machine, so `HDMI Matrix 16x16` is
// `tpl.hdmi_matrix_16x16` for everybody. **A colliding id therefore means
// "somebody typed the same name", not "this template came back."**
//
// Three candidate discriminators were checked against the tree and all
// three fail (DR-101 §11.100.2): `derivedFrom` is written by door 3 only,
// so a door-2 fork carries no lineage; `contentHash` is a placeholder
// everywhere until `#795`; and a `.rmdx` carries ONE version rather than
// a chain, so a stranger who iterated their own same-named device to `@4`
// is indistinguishable from yours returning at `@4`. There is no signal
// in the file, which is why the person is asked.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/template_snapshot_commands.dart';
import 'package:rackpal_core/src/library/rmdx_codec.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The two things a person may mean when an imported id already exists.
enum TemplateImportResolution {
  /// Keep the id; the import becomes `nextTemplateVersion`.
  ///
  /// The send-it-back-fixed flow: placement resolves the newest version,
  /// so devices already placed from an earlier one keep resolving to it
  /// (CR-050) and a stale-fork badge appears where it should (CR-062).
  newVersion,

  /// Take a suffixed id from [templateIdFor]; the import is its own
  /// template at version 1.
  ///
  /// The policy `templateIdFor`'s own header already rules for the local
  /// case: *"two devices a user happened to name the same thing are two
  /// devices, and silently merging them would put one template's ports on
  /// the other's instances."*
  separateTemplate,
}

/// What the incumbent is, when there is one.
final class TemplateImportCollision {
  const TemplateImportCollision({
    required this.templateId,
    required this.incumbentDisplayName,
    required this.incumbentLatestVersion,
  });

  final TemplateId templateId;

  /// **Carried so the dialog can print it, and it is not always the same
  /// as the incoming file's name.** The id is a slug of the name, so
  /// `HDMI Matrix 16x16` and `HDMI matrix 16X16` collide while reading
  /// differently, and a prompt that showed only the incoming name would
  /// leave the user comparing a string against itself.
  final String incumbentDisplayName;

  final int incumbentLatestVersion;
}

/// A read `.rmdx`, and what standing it has in this document.
final class TemplateImportPlan {
  const TemplateImportPlan({required this.file, this.collision});

  final DeviceTemplateFile file;

  /// Null when the id is free, in which case no question is asked.
  final TemplateImportCollision? collision;

  bool get collides => collision != null;
}

/// Whether [file]'s id is already in use in [doc], and by what.
TemplateImportPlan planTemplateImport(
  RackDocument doc,
  DeviceTemplateFile file,
) {
  var latest = 0;
  String? name;
  for (final s in doc.templates.values) {
    if (s.templateId != file.templateId) continue;
    if (s.version >= latest) {
      latest = s.version;
      name = s.body.displayName;
    }
  }
  if (name == null) return TemplateImportPlan(file: file);
  return TemplateImportPlan(
    file: file,
    collision: TemplateImportCollision(
      templateId: file.templateId,
      incumbentDisplayName: name,
      incumbentLatestVersion: latest,
    ),
  );
}

/// The command that lands [plan] in the document.
///
/// [resolution] is required exactly when [TemplateImportPlan.collides],
/// and is the human's answer. Passing one for a plan that does not
/// collide is a programmer error rather than a silent no-op, because the
/// only way to get there is to have asked a question nobody was owed.
///
/// **THE FILE'S OWN VERSION IS PRESERVED WHEN THE ID IS FREE**, rather
/// than reset to 1. A `.rmdx` exported at `@3` lands at `@3`, so a later
/// `@4` of the same template slots in above it and the version chain
/// keeps meaning what it means everywhere else. Sparse versions are
/// already legal: `latestTemplateVersions` and `buildPlaceableTemplates`
/// both read the maximum rather than counting.
///
/// **`derivedFrom` IS LEFT EXACTLY AS THE FILE WROTE IT**, on either
/// branch, and DR-101 does not rule otherwise. Overwriting it on the
/// separate-template branch was considered and declined: it would record
/// this import as the origin and destroy whatever lineage the author
/// actually had. A `TemplateOrigin` pointing at a template not present in
/// this installation is already a case the model handles, and
/// `resolveForkStatus` answers UNKNOWN for it rather than "not stale",
/// which is G4's shape and the honest answer.
Command<RackDocument> buildTemplateImport(
  RackDocument doc,
  TemplateImportPlan plan, {
  required DateTime capturedAt,
  TemplateImportResolution? resolution,
}) {
  final file = plan.file;
  assert(
    plan.collides == (resolution != null),
    'a resolution is owed exactly when the id collides',
  );
  final (TemplateId id, int version) = switch (resolution) {
    null => (file.templateId, file.version),
    TemplateImportResolution.newVersion => (
      file.templateId,
      nextTemplateVersion(doc, file.templateId),
    ),
    TemplateImportResolution.separateTemplate => (
      templateIdFor(doc, file.body.displayName),
      1,
    ),
  };
  return SaveTemplateToProjectCommand(
    templateId: id,
    version: version,
    // CARRIED, NOT RECOMPUTED. Nothing in this repository computes a
    // sha256 yet (`#795`), and AC-042's mismatch warning cannot fire
    // until it does, because a placeholder never mismatches. Recomputing
    // a fake here would put a second answer beside the one that ships.
    contentHash: file.contentHash,
    body: file.body,
    capturedAt: capturedAt,
  );
}
