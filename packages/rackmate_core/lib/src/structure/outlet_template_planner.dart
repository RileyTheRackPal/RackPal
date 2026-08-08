// `+ Add outlet ▾`. Board M3-C/5 (#151), DR-024 §11.23.3, docs/07 §4.3.
//
// One template plus one room becomes one `Outlet`, N `Link`s and N label
// pairs — docs/07 §4.3's own sentence: *"instantiates an
// `OutletTemplate` in one action, TV location → 2 × Cat6 + 2 × RG6 as
// one `Outlet` with four `Link`s and four label pairs."*
//
// ═════════════════════════════════════════════════════════════════════
// IT IS THE FIRST CALLER OF DR-023 STEP 2, AND THAT IS THE POINT
// ═════════════════════════════════════════════════════════════════════
// The chain is `@service=`, then the outlet template's tag, then the
// media's `shortTag`. The middle arm has been unreachable since it was
// ruled, because nothing in the product created an `Outlet` FROM a
// template: the drop DSL creates bare outlets, and the only outlets
// carrying an `outletTemplateId` are the seventeen hand-authored ones in
// the whole-house fixture. So `LR-TV-1` — DR-022's first worked example
// — could be produced only by typing `@service=tv`, which is step 1
// wearing step 2's clothes.
//
// This gesture stamps `outletTemplateId`, so the label comes out of the
// outlet rather than out of what was typed, which is what the ruling
// says it is.
//
// ═════════════════════════════════════════════════════════════════════
// IT CREATES AN OUTLET AND NEVER JOINS ONE
// ═════════════════════════════════════════════════════════════════════
// docs/07 §4.3 says *"as one `Outlet`"*, and `Outlet.outletTemplateId`
// is provenance — "what created it" (CR-108). Adding a *TV location*
// recipe onto an outlet that already exists would either overwrite that
// provenance or leave an outlet whose drops disagree with the template
// it names. The DSL's `@outlet="…"` is the gesture for adding to an
// existing plate, and it is unchanged.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT IT DOES NOT DO
// ═════════════════════════════════════════════════════════════════════
// The template's `OutletDrop.service` is NOT copied onto the Link.
// `AddHomeRunCommand` writes `structure.undetermined` and docs/07 §4.1
// says why: at rough-in a Cat6 is just a Cat6, and the DRC re-validates
// when a real family is assigned later. The template's service is the
// recipe's INTENT, and docs/02 §6.2 prints both facts in one file.
//
// AC-034/m24's template-driven location fields are not here either. A
// ceiling speaker pair should ask for `mountSurface: ceiling` and never
// for a wall compass direction; that needs a model field this class does
// not have, and DR-024 §11.23.4 keeps it out deliberately.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/home_run_commands.dart'
    show usedFieldLabels;
import 'package:rackmate_core/src/commands/structure_commands.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/structure/drop_build.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// The outcome of [planOutletFromTemplate].
sealed class OutletTemplatePlan {
  const OutletTemplatePlan();
}

/// One outlet and N drops, ready to apply as one undo entry.
@immutable
final class OutletTemplatePlanReady extends OutletTemplatePlan {
  const OutletTemplatePlanReady({
    required this.commands,
    required this.outletDesignation,
    required this.fieldLabels,
    required this.tia570Grade,
  });

  /// In application order: the outlet, then its drops. Apply them inside
  /// ONE transaction.
  final List<Command> commands;

  /// What the plate will be called in the project tree.
  final String outletDesignation;

  /// The labels these drops will carry, in order — what a confirm dialog
  /// shows before the user commits.
  final List<String> fieldLabels;

  /// The standards citation this outlet will carry, or null when the
  /// template makes no such claim (DR-024).
  final String? tia570Grade;

  int get dropCount => fieldLabels.length;
}

/// The gesture cannot be turned into drops, and here is one sentence
/// saying why.
@immutable
final class OutletTemplatePlanRefused extends OutletTemplatePlan {
  const OutletTemplatePlanRefused(this.reason);
  final String reason;
}

/// The project has no Structure device to hang an outlet on. Not an
/// error: an offer, for the same reason the drop line's is.
@immutable
final class OutletTemplatePlanNeedsStructure extends OutletTemplatePlan {
  const OutletTemplatePlanNeedsStructure();
}

/// Plans one outlet's worth of drops from [template], mutating nothing.
///
/// [locationId] names the room; [designation] overrides the generated
/// plate name. [alsoUsedLabels] and [alsoUsedDesignators] let a caller
/// place several outlets against one document before applying any of
/// them.
OutletTemplatePlan planOutletFromTemplate({
  required RackDocument doc,
  required OutletTemplate template,
  required Uuid locationId,
  required DateTime now,
  required String actor,
  String? designation,
  Set<String> alsoUsedLabels = const {},
  Set<String> alsoUsedDesignators = const {},
  Set<String> alsoUsedDesignations = const {},
}) {
  final location = doc.locations[locationId];
  if (location == null) {
    return const OutletTemplatePlanRefused(
      'That room is not in this project any more.',
    );
  }

  if (doc.structures.isEmpty) {
    return const OutletTemplatePlanNeedsStructure();
  }
  if (doc.structures.length > 1) {
    // The drop line refuses here for the same reason and names the same
    // board item: filing drops on the wrong Structure body puts them on
    // the wrong sheet, and picking between bodies is #158 (M3-E/3).
    return const OutletTemplatePlanRefused(
      'This project has more than one Structure device, and this gesture '
      'does not say which one the outlet belongs to.',
    );
  }

  if (template.drops.isEmpty) {
    // A recipe with no drops makes a plate with no cables. Refused
    // rather than created, because an empty outlet is indistinguishable
    // from a gesture that silently failed.
    return OutletTemplatePlanRefused(
      '"${template.name}" has no drops, so there is nothing to pull.',
    );
  }

  // --- the media, all of it, before anything is allocated -------------
  //
  // RESOLVED THROUGH THE DOCUMENT'S OWN REGISTRY, not the seed. A
  // document carries the subset it references (CR-117's reason), and a
  // template naming a type this document does not have is exactly the
  // `unknown(rawId)` case §6.2 already rules on — except that here it
  // would ship a drop whose media resolves to nothing, so it refuses and
  // names the id.
  final items = <PlannedDropItem>[];
  for (final drop in template.drops) {
    final def = doc.registries.mediaTypes[drop.media];
    if (def == null) {
      return OutletTemplatePlanRefused(
        '"${template.name}" calls for ${drop.media.v}, which this project '
        'does not carry. Add that cable type first.',
      );
    }
    items.add(PlannedDropItem(media: def, count: drop.count));
  }

  // --- the outlet -----------------------------------------------------
  final bodyId = doc.structures.keys.first;
  final add = AddOutletCommand(
    structureBodyId: bodyId,
    designation: designation?.trim().isNotEmpty ?? false
        ? designation!.trim()
        : outletDesignationFor(doc, location, alsoUsed: alsoUsedDesignations),
    order: nextOutletOrder(doc),
    now: now,
    actor: actor,
    locationId: location.id,
    // PROVENANCE, and the reason DR-023 step 2 can fire at all.
    outletTemplateId: template.id,
    // DR-024 §11.23.2. Null on the six named templates, which cite no
    // standard, and a citation on the three grades.
    tia570Grade: template.tia570Grade,
  );

  // The outlet the drops will name, before it is in the document. See
  // `alsoOutlets` in `buildAddHomeRunCommand`.
  final plannedOutlet = Outlet(
    id: add.id,
    structureBodyId: bodyId,
    designation: add.designation,
    order: add.order,
    meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
    locationId: location.id,
    outletTemplateId: template.id,
    tia570Grade: template.tia570Grade,
  );

  // --- the drops ------------------------------------------------------
  final built = buildDropsFor(
    doc: doc,
    location: location,
    outlet: plannedOutlet,
    items: items,
    // DR-023 STEP 2, DIRECTLY. There is no modifier to outrank it and no
    // fall through to the media tag: the template was chosen by name
    // from a menu, so its tag is the most specific thing anyone has
    // said. A template with no tag falls to the media's, which is what
    // the three untagged grade presets do.
    serviceTag: (item) => switch (template.tag?.trim()) {
      final t? when t.isNotEmpty => t,
      _ => item.media.shortTag,
    },
    now: now,
    actor: actor,
    usedLabels: usedFieldLabels(doc, alsoUsed: alsoUsedLabels),
    usedDesignators: {
      for (final l in doc.links.values) l.designator,
      ...alsoUsedDesignators,
    },
    usedNetNames: {for (final n in doc.nets.values) n.name},
  );

  return switch (built) {
    DropBuildRefused(:final reason) => OutletTemplatePlanRefused(reason),
    DropBuildOk(:final commands, :final fieldLabels) => OutletTemplatePlanReady(
      commands: [add, ...commands],
      outletDesignation: add.designation,
      fieldLabels: fieldLabels,
      tia570Grade: template.tia570Grade,
    ),
  };
}

/// The templates a picker offers, in the order the seed declares them:
/// the six named recipes, then the three grade presets.
///
/// A LIST AND NOT THE MAP, because a `Map`'s iteration order is its
/// insertion order and a picker that re-sorted alphabetically would put
/// *AP* above *TV location* and the grades in the middle of the six.
List<OutletTemplate> offerableOutletTemplates(Registries registries) => [
  ...registries.outletTemplates.values,
];
