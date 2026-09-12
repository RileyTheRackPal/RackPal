// rackpal_core/src/derived/template_removal.dart — what removing a device
// template from a project costs, counted before it costs it (`#871`,
// DR-158 §11.157).
//
// ═══════════════════════════════════════════════════════════════════════
// THREE NUMBERS IN THREE UNITS, AND THEY ARE NOT SUMMED
// ═══════════════════════════════════════════════════════════════════════
// DR-158 §11.157.5, which is `LocationRemovalPlan`'s rule restated for the
// fourth plan to need it. A **snapshot** is an archived version of the
// template and is invisible to the person; a **device** is a thing that
// leaves the project; a **cable** is a row that leaves the schedule, which
// is the deliverable and is what makes DR-013 §11.13.2 expensive.
//
// ═══════════════════════════════════════════════════════════════════════
// THE UNIT IS THE TEMPLATE ID, NOT THE SNAPSHOT (§11.157.2)
// ═══════════════════════════════════════════════════════════════════════
// Every version goes. The product addresses ids everywhere a person can
// see one: `buildPlaceableTemplates` reduces to the newest per id, a
// placement gesture carries an id and never a version (DR-077 §11.76.3),
// and `countDevicesOnTemplate` counts by id. A removal that took one
// snapshot would make a palette row vanish and then silently come back at
// the previous version.
//
// ═══════════════════════════════════════════════════════════════════════
// AND THE DEVICE PLANS ARE CARRIED, NOT RE-DERIVED
// ═══════════════════════════════════════════════════════════════════════
// The cascade is performed by one `RemoveDeviceCommand` per device
// (§11.157.6), and each of those plans itself against the aggregate as it
// stands when it applies. What this plan carries is the same question
// asked of the document as it is NOW, which is what the confirmation is
// answered about. `cablesAcrossPlans` is the union rather than a sum,
// because a cable running between two of these devices is in both their
// plans and goes once (`#873`).
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/catalog/seed_catalog.dart'
    show kSeedCatalogIds;
import 'package:rackpal_core/src/commands/template_snapshot_commands.dart'
    show templateSnapshotKey;
import 'package:rackpal_core/src/derived/device_removal.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Why a template cannot be removed from a project, or null when it can.
///
/// **A SENTENCE AND NOT A FLAG.** The caller that hides a control and the
/// caller that refuses a gesture both need to say WHY, and a bool makes
/// each of them write that sentence again.
enum TemplateRemovalRefusal {
  /// No version of this id is in the document at all.
  notInProject,

  /// It is one of the seeded catalog templates (DR-158 §11.157.3). Those
  /// are what the build ships and are identical in every project, so a
  /// per-project hole in them is a difference carried in the file
  /// forever, found later by somebody who did not make it.
  seeded,
}

/// What removing one device template takes with it.
///
/// Ids and plans only, on [DeviceRemovalPlan]'s rule: *"a plan is a
/// question, not a clipboard"*. `RemoveTemplateCommand` captures the
/// snapshots it removes across its own apply/revert boundary.
@immutable
final class TemplateRemovalPlan {
  const TemplateRemovalPlan({
    required this.templateId,
    required this.snapshotKeys,
    required this.devicePlans,
    this.refusal,
  });

  final TemplateId templateId;

  /// Every `RackDocument.templates` key this removes, newest first.
  ///
  /// More than one whenever the template has been edited: CR-050 forks a
  /// version rather than mutating, and every earlier one stays in the
  /// file so the devices placed at it keep resolving.
  final List<String> snapshotKeys;

  /// One plan per device standing on this template, in document order.
  final List<DeviceRemovalPlan> devicePlans;

  /// Why this must not happen, or null when it may.
  final TemplateRemovalRefusal? refusal;

  bool get isRemovable => refusal == null;

  /// How many archived versions go. Invisible to the person, and said
  /// only when it is more than one.
  int get snapshotCount => snapshotKeys.length;

  /// How many placed devices go with it (DR-158 §11.157.4).
  int get deviceCount => devicePlans.length;

  /// How many cables those devices take with them under DR-013 §11.13.1.
  ///
  /// A UNION (`#873`): a cable between two of these devices is in both
  /// their plans and is removed once.
  int get cableCount => cablesAcrossPlans(devicePlans);

  /// Whether the gesture destroys anything beyond the template itself.
  bool get takesDevices => devicePlans.isNotEmpty;

  /// **ALWAYS TRUE FOR A REMOVABLE TEMPLATE**, which is where this
  /// departs from `UnderlayRemovalPlan`, `DeviceRemovalPlan` and
  /// `LocationRemovalPlan` (DR-158 §11.157.5). DR-013 §11.13.2 exempts
  /// the *consequence-free* delete, and this is not one: authoring a
  /// template is minutes of work that exists nowhere else in the project,
  /// so removing an unused one still destroys something no route but undo
  /// brings back. The prompt is shorter when nothing stands on it. It is
  /// not absent.
  bool get needsConfirmation => isRemovable;
}

/// What removing every version of [templateId] from [doc] would take.
///
/// Returns a plan carrying a [TemplateRemovalPlan.refusal] rather than
/// throwing, for
/// `planUnderlayRemoval`'s reason: a caller asking about a template that
/// is already gone is asking a reasonable question, and so is a surface
/// deciding whether to offer the control at all.
TemplateRemovalPlan planTemplateRemoval(
  RackDocument doc,
  TemplateId templateId,
) {
  final versions = <int>[
    for (final snapshot in doc.templates.values)
      if (snapshot.templateId == templateId) snapshot.version,
  ]..sort((a, b) => b.compareTo(a));

  final keys = <String>[
    for (final version in versions) templateSnapshotKey(templateId, version),
  ];

  final deviceIds = <Uuid>[
    for (final entry in doc.devices.entries)
      if (entry.value.templateRef.templateId == templateId) entry.key,
  ];

  final TemplateRemovalRefusal? refusal;
  if (kSeedCatalogIds.contains(templateId.v)) {
    // CHECKED BEFORE EMPTINESS, so a seeded id says "seeded" rather than
    // "not in this project" in the one case where both are true. The
    // second sentence would send somebody looking for a template they
    // can see in the palette.
    refusal = TemplateRemovalRefusal.seeded;
  } else if (keys.isEmpty) {
    refusal = TemplateRemovalRefusal.notInProject;
  } else {
    refusal = null;
  }

  return TemplateRemovalPlan(
    templateId: templateId,
    snapshotKeys: List<String>.unmodifiable(keys),
    devicePlans: List<DeviceRemovalPlan>.unmodifiable([
      for (final id in deviceIds) planDeviceRemoval(doc, id),
    ]),
    refusal: refusal,
  );
}
