// rackpal_core/src/commands/template_fork_commands.dart — pure Dart.
//
// Door 3 of CR-054: "fork to a new template" (DR-099 §11.98).
//
// ─────────────────────────────────────────────────────────────────────────
// WHAT DOOR 3 IS FOR, AND WHY IT IS NOT DOOR 2
// ─────────────────────────────────────────────────────────────────────────
// Door 2 edits the template this device stands on and forks `version + 1`;
// the family tree is unchanged and the device is still an instance of the
// same product. Door 3 says the thing in this rack is A DIFFERENT PRODUCT
// that started life as a copy of that one. It mints a new `templateId`,
// seeds the body from the snapshot plus whatever door 1 overrode, rebinds
// this instance and clears the overrides, and records where it came from.
//
// THE FOURTH VERB STAYS DELETED. CR-054 removed "Detach instance"
// (`templateRef -> null`) because it produces a device with no lineage.
// Door 3 covers the same need with better provenance, and this file is
// where somebody would be standing when they thought of adding it back.
//
// ─────────────────────────────────────────────────────────────────────────
// THIS IS `derivedFrom`'s FIRST PRODUCER
// ─────────────────────────────────────────────────────────────────────────
// `fork_status.dart` has carried CR-062's stale-fork rule since M4-C and
// says in its own header that "nothing writes a `derivedFrom` yet", so the
// badge has had a rule and nothing to badge. That is the same shape DR-098
// found on `DeviceOverrides`, one level up, and this closes it: after a
// door-3 fork the forked template answers `ForkStatus` against the source
// it was copied from.
//
// The origin records the source version AT THE MOMENT OF THE FORK and is
// never updated afterwards, which is `TemplateOrigin`'s own rule and the
// thing that lets the badge notice the catalog moving on.
//
// ─────────────────────────────────────────────────────────────────────────
// AN UNKNOWN OVERRIDE CLEARS THE FIELD IN THE FORK
// ─────────────────────────────────────────────────────────────────────────
// "Seeded from snapshot plus overrides" has a third case DR-098 created.
// An override in the UNKNOWN state says the template's value does NOT
// govern here and the true one is not known, so a fork that copied the
// template's figure across would resurrect exactly the number the user
// disowned, in a new template where nothing records that they disowned it.
// The forked body therefore carries `null` for such a field, which is what
// an unknown is on a `TemplateBody` (G4, CR-114: absent key, and every
// rollup counts it).

import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/commands/template_snapshot_commands.dart'
    show templateSnapshotKey;
import 'package:rackpal_core/src/library/template_hash.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/persistence/json_codec.dart'
    show copyTemplateBody;
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';
import 'package:rackpal_core/src/units/rgb.dart';

/// The outcome of [buildForkTemplateFromDevice]: a ready command, or a
/// reason one could not be built.
///
/// Sealed rather than nullable, on `CatalogPlacementResult`'s precedent
/// and for its reason: a refusal the user can read beats a gesture that
/// silently does nothing.
sealed class ForkTemplateResult {
  const ForkTemplateResult();
}

final class ForkTemplateReady extends ForkTemplateResult {
  const ForkTemplateReady(this.command);
  final ForkTemplateFromDeviceCommand command;
}

final class ForkTemplateFailed extends ForkTemplateResult {
  const ForkTemplateFailed(this.reason);
  final String reason;
}

/// Builds door 3 for [deviceId], minting [newTemplateId].
///
/// [newTemplateId] IS THE CALLER'S TO ALLOCATE, deliberately. Choosing an
/// id from a display name is `templateIdFor`'s job in the app, where the
/// collision policy and the document's existing ids both live; core takes
/// the decision rather than making it, which is what keeps this file free
/// of a naming rule that would then exist in two places.
ForkTemplateResult buildForkTemplateFromDevice({
  required RackDocument doc,
  required Uuid deviceId,
  required TemplateId newTemplateId,
  required DateTime now,
  required String actor,
}) {
  final device = doc.devices[deviceId];
  if (device == null) {
    return ForkTemplateFailed('No device "${deviceId.v}".');
  }
  final ref = device.templateRef;
  final source =
      doc.templates[templateSnapshotKey(ref.templateId, ref.version)];
  if (source == null) {
    // NOTHING TO SEED FROM. A device whose snapshot does not resolve is a
    // broken document rather than an unusual one, and forking it would
    // mint a template with an empty body and a lineage pointing at
    // something absent.
    return ForkTemplateFailed(
      'The template behind ${device.designator} '
      '(${ref.templateId.v}@${ref.version}) is not in this project, so '
      'there is nothing to fork.',
    );
  }
  if (doc.templates.containsKey(templateSnapshotKey(newTemplateId, 1))) {
    return ForkTemplateFailed(
      'This project already holds a template "${newTemplateId.v}".',
    );
  }
  return ForkTemplateReady(
    ForkTemplateFromDeviceCommand(
      deviceId: deviceId,
      newTemplateId: newTemplateId,
      now: now,
      actor: actor,
    ),
  );
}

/// Mints a new template from [deviceId]'s snapshot plus its overrides,
/// rebinds the device to it, and clears the overrides.
final class ForkTemplateFromDeviceCommand extends Command<RackDocument> {
  ForkTemplateFromDeviceCommand({
    required this.deviceId,
    required this.newTemplateId,
    required this.now,
    required this.actor,
  });

  final Uuid deviceId;
  final TemplateId newTemplateId;
  final DateTime now;
  final String actor;

  /// Everything `revert` has to put back, captured in `apply`.
  TemplateRef? _prevRef;
  DeviceOverrides? _prevOverrides;
  DateTime? _prevUpdatedAt;
  String? _prevUpdatedBy;
  int? _prevLocalRevision;

  String get key => templateSnapshotKey(newTemplateId, 1);

  @override
  LabelKey get label => LabelKey.saveTemplateToProject;

  /// `structure | meta`. A fork changes what this device IS: its body may
  /// carry a different mass and depth, so the elevation and the load
  /// gutter both move (`structure`), and T6.30 prints the new template's
  /// display name for it (`meta`).
  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  /// The DEVICE, which is a real entity a selection can hold. The new
  /// template key is not one, which is `SaveTemplateToProjectCommand`'s
  /// own reasoning and the same call it makes.
  @override
  Iterable<Uuid> get affects => [deviceId];

  @override
  bool apply(RackDocument doc) {
    final device = doc.devices[deviceId];
    if (device == null) {
      throw StateError('ForkTemplateFromDeviceCommand: no device $deviceId.');
    }
    final ref = device.templateRef;
    final source =
        doc.templates[templateSnapshotKey(ref.templateId, ref.version)];
    if (source == null) {
      throw StateError(
        'ForkTemplateFromDeviceCommand: ${ref.templateId.v}@${ref.version} '
        'is not in this project.',
      );
    }

    _prevRef = ref;
    _prevOverrides = device.overrides;
    final meta = device.meta;
    _prevUpdatedAt = meta.updatedAt;
    _prevUpdatedBy = meta.updatedBy;
    _prevLocalRevision = meta.localRevision;

    // A CODEC ROUND TRIP, NOT A HAND-WRITTEN CLONE, for M4-A's recorded
    // reason: `TemplateBody` has ~50 fields and eight growable lists, and
    // a clone drifts the first time somebody adds field 51, where the
    // forgotten field is a LIST SHARED between the copy and the original.
    final body = copyTemplateBody(source.body);
    _applyOverrides(body, device.overrides);
    body.derivedFrom = TemplateOrigin(
      templateId: ref.templateId,
      version: ref.version,
    );

    final hash = templateContentHash(body);
    doc.templates[key] = TemplateSnapshot(
      templateId: newTemplateId,
      version: 1,
      // REAL AT `#795`, over DR-100's canonical bytes. This used to be
      // `unhashed:<id>@1` with a comment explaining that no real hashing
      // existed and that inventing a scheme here would put a second
      // answer beside the one that ships. The scheme exists now and this
      // reads it rather than spelling one.
      contentHash: hash,
      body: body,
      capturedAt: now,
    );

    device
      ..templateRef = TemplateRef(
        templateId: newTemplateId,
        version: 1,
        // THE SAME VALUE as the snapshot above, from one computation:
        // a ref whose hash disagreed with the snapshot it names would be
        // a mismatch this command manufactured.
        contentHash: hash,
      )
      // THE OVERRIDES ARE NOW IN THE TEMPLATE, so keeping them would
      // apply them twice: once as the forked body's own values and again
      // as an instance statement on top. CR-054 says "overrides cleared"
      // and this is why it has to.
      ..overrides = DeviceOverrides();
    meta.touch(now, actor);
    return true;
  }

  @override
  void revert(RackDocument doc) {
    final ref = _prevRef;
    final overrides = _prevOverrides;
    final prevAt = _prevUpdatedAt;
    final prevBy = _prevUpdatedBy;
    final prevRev = _prevLocalRevision;
    if (ref == null ||
        overrides == null ||
        prevAt == null ||
        prevBy == null ||
        prevRev == null) {
      throw StateError(
        'ForkTemplateFromDeviceCommand.revert called before apply().',
      );
    }
    doc.templates.remove(key);
    final device = doc.devices[deviceId];
    if (device == null) return;
    device
      ..templateRef = ref
      ..overrides = overrides;
    device.meta.restoreTo(
      updatedAt: prevAt,
      updatedBy: prevBy,
      localRevision: prevRev,
    );
  }

  /// Folds door 1's three states onto the forked body.
  ///
  /// SET writes the value. INHERIT leaves the template's alone. UNKNOWN
  /// writes `null`, which is the case a two-state override could not have
  /// produced and the reason this is a function rather than four `??`s:
  /// copying the template's figure across for a field the user disowned
  /// would resurrect the exact number they said was wrong, in a new
  /// template where nothing records that they said so.
  static void _applyOverrides(TemplateBody body, DeviceOverrides o) {
    switch (o.weightState) {
      case OverrideStated<Mass>(:final value):
        body.weight = value;
      case OverrideUnknown<Mass>():
        body.weight = null;
      case OverrideInherited<Mass>():
        break;
    }
    switch (o.bodyDepthState) {
      case OverrideStated<Len>(:final value):
        body.bodyDepth = value;
      case OverrideUnknown<Len>():
        body.bodyDepth = null;
      case OverrideInherited<Len>():
        break;
    }
    switch (o.accentColorState) {
      case OverrideStated<Rgb>(:final value):
        body.accentColor = value;
      case OverrideUnknown<Rgb>():
        body.accentColor = null;
      case OverrideInherited<Rgb>():
        break;
    }
    switch (o.typicalWattsState) {
      case OverrideStated<int>(:final value):
        body.power.typicalWatts = value;
      case OverrideUnknown<int>():
        body.power.typicalWatts = null;
      case OverrideInherited<int>():
        break;
    }
  }
}
