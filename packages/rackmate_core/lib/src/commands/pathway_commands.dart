// packages/rackmate_core/lib/src/commands/pathway_commands.dart — pure
// Dart. Board M3-E/4 (#591), CR-016.
//
// ═════════════════════════════════════════════════════════════════════
// THE ENTITY EXISTED FOR THREE MILESTONES AND COULD NOT BE CREATED
// ═════════════════════════════════════════════════════════════════════
// `Pathway` has been in the model since M0, is byte-round-tripped by the
// codec, is read by the schedule (`PATH`), by the Structure editor
// (`PATHWAY`, `PATHWAY KIND`) and by `structure_matrix.dart`. Nothing
// wrote one. The only writers of `doc.pathways` were
// `RemoveLocationCommand` clearing the two location references during
// DR-021's cascade.
//
// So `Link.pathwayId` could never point at anything real, every drop's
// `PATH` cell was the unknown marker by construction, and `kind` and
// `containsLineVoltage` sat at their constructor defaults where M5's
// `CODE-001` and `CODE-002` will eventually read them. This file is the
// gesture side of that gap; `PathwayField` in
// `set_entity_property_command.dart` is the editing side.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT A DELETE OWES, AND WHY IT IS NOT A CASCADE
// ═════════════════════════════════════════════════════════════════════
// DR-021 makes deleting a `Location` cascade its subtree and clear nine
// references. Deleting a `Pathway` is deliberately NOT that shape: a
// pathway is not a container and nothing lives inside it. What refers to
// one is `Link.pathwayId`, and a cable whose conduit is deleted is still
// a cable — it is a run whose route nobody has recorded, which is
// exactly the state every drop in this product has been in until now.
//
// **The reference is CLEARED, never left dangling, and the count is
// reported.** A dangling `pathwayId` would print an unknown `PATH` cell
// that looks identical to "nobody said", so the document would carry a
// broken pointer indistinguishable from an honest absence (G4). DR-021
// §11.20.2's rule, applied to a smaller graph.

import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackmate_core/src/commands/set_entity_property_command.dart'
    show PathwayField, SetEntityPropertyCommand;
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/pathway.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/util/id_gen.dart';

/// The next `order` for a new pathway.
///
/// PER DOCUMENT, not per anything: pathways are a flat list, unlike
/// `nextLocationOrder`'s per-sibling-group allocation over a tree.
FracIndex nextPathwayOrder(RackDocument doc) =>
    nextOrder(doc.pathways.values.map((p) => p.order));

/// Creates one [Pathway].
final class AddPathwayCommand extends Command {
  AddPathwayCommand({
    required this.name,
    required this.order,
    required this.now,
    required this.actor,
    this.kind = PathwayKind.conduit,
    this.containsLineVoltage = false,
    this.nominalLength,
    this.pathwayMedia,
    this.fromLocationId,
    this.toLocationId,
    this.notes,
    Uuid? id,
  }) : id = id ?? newEntityId();

  /// Minted in the CONSTRUCTOR, never in [apply] — the `Command`
  /// contract, so redo recreates the identical pathway and anything
  /// stacked on it (a `Link.pathwayId` set afterwards) still resolves.
  final Uuid id;

  /// `PW-LR-1`, or "attic run to the garage". The NAME; the designator is
  /// a separate hand-entered field under DR-026 §11.25.1 and is #157's.
  final String name;

  final FracIndex order;

  /// Defaults to `conduit`, which is the model's own default and is a
  /// guess in the way `roughInStatus.planned` is a guess rather than in
  /// the way a null length is unknown: a pathway is a physical thing
  /// somebody built, so this always has a true answer.
  final PathwayKind kind;

  /// Defaults to false, matching the model. See
  /// `Pathway.containsLineVoltage` for why this is a `bool` and not a
  /// `bool?`, and what it would take to widen it.
  final bool containsLineVoltage;

  /// Null stays UNKNOWN through this command. Defaulting it to zero would
  /// fabricate a measurement at the exact point the user is saying they
  /// have none (G4, CR-114) — `AddLocationCommand`'s reasoning for
  /// `estimatedRunLengthFromRack`, verbatim.
  final Len? nominalLength;

  /// Which `isPathwayOnly` medium this conduit is (CR-109, DR-035
  /// §11.34.2).
  final MediaTypeId? pathwayMedia;

  /// The room this pathway serves (DR-035 §11.34.2).
  ///
  /// `from` IS THE ROOM AND NOT THE RACK, which DR-035 §11.34.3 sets for
  /// the first time: these two fields shipped at M0 with no reader that
  /// established an order, and docs/08 §3.2 reads every schedule row
  /// `FROM — ROOM` then `TO — RACK`, so this is the product's existing
  /// convention rather than a new one.
  ///
  /// NULL IS LEGAL AND IS WHAT `+ Add pathway` PRODUCES. Somebody who
  /// pressed a button on a list named no room, and inventing one is the
  /// failure DR-032 §11.31.2 refused one field over (§11.34.5).
  final Uuid? fromLocationId;

  /// Where the pathway goes, when anybody has said.
  ///
  /// SET BY NO GESTURE TODAY, and that is G4 rather than an omission: a
  /// conduit's far end is the rack in the ordinary case and this project
  /// may hold no rack at all, so nothing may write one on a guess.
  final Uuid? toLocationId;

  final String? notes;

  final DateTime now;
  final String actor;

  @override
  LabelKey get label => LabelKey.addPathway;

  /// `structure` because a pathway is part of how the building is put
  /// together, `meta` because its name prints on the Pull Sheet's `PATH`
  /// column for every run through it.
  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  void apply(RackDocument doc) {
    doc.pathways[id] = Pathway(
      id: id,
      name: name,
      order: order,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
      kind: kind,
      containsLineVoltage: containsLineVoltage,
      nominalLength: nominalLength,
      pathwayMedia: pathwayMedia,
      fromLocationId: fromLocationId,
      toLocationId: toLocationId,
      notes: notes,
    );
  }

  @override
  void revert(RackDocument doc) {
    doc.pathways.remove(id);
  }
}

/// Deletes one [Pathway] and clears every `Link` that named it.
///
/// NOT A CASCADE. See the file header: nothing lives inside a pathway,
/// so no other entity is destroyed. What happens is that runs through it
/// go back to having no recorded route.
final class RemovePathwayCommand extends Command {
  RemovePathwayCommand({required this.id, required this.now});

  final Uuid id;
  final DateTime now;

  /// Captured on [apply] so [revert] restores the exact object rather
  /// than rebuilding an equal one. `EntityMeta` carries a revision, and a
  /// rebuilt pathway with a fresh one is what breaks CR-117's byte round
  /// trip.
  Pathway? _removed;

  /// The links whose `pathwayId` this cleared, so undo can put each one
  /// back. A set would lose nothing today, but a list keeps the restore
  /// deterministic if the same link is ever cleared twice by a merged
  /// command.
  final List<Uuid> _clearedLinks = [];

  @override
  LabelKey get label => LabelKey.removePathway;

  /// `wires` as well as `structure | meta`, and that is the difference
  /// from [AddPathwayCommand]: creating a pathway changes no cable, and
  /// deleting one rewrites `Link.pathwayId` on every run through it.
  @override
  EpochMask get touches =>
      EpochMask.structure | EpochMask.wires | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id, ..._clearedLinks];

  @override
  void apply(RackDocument doc) {
    _removed = doc.pathways.remove(id);
    _clearedLinks.clear();
    for (final link in doc.links.values) {
      if (link.pathwayId == id) {
        _clearedLinks.add(link.id);
        link
          ..pathwayId = null
          ..meta.touch(now, 'removePathway');
      }
    }
  }

  @override
  void revert(RackDocument doc) {
    final pathway = _removed;
    if (pathway != null) doc.pathways[id] = pathway;
    for (final linkId in _clearedLinks) {
      doc.links[linkId]?.pathwayId = id;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════
// THE DESIGNATOR NEEDS A BUILDER THAT CAN REFUSE (M3-E/2, #157)
// ═════════════════════════════════════════════════════════════════════
// `PathwayField.designator` exists in the field table so a reader can
// find it, and it is the one row in that table that MUST NOT be driven
// through `buildSetEntityProperty`. That builder writes the value and
// returns; it has no way to decline. DR-026 §11.25.1 makes the
// designator UNIQUE WHERE SET, PROJECT-WIDE, on CR-113's `rackLabel`
// precedent, and a uniqueness rule enforced by a builder that cannot say
// no is a comment rather than a rule.
//
// This is the same shape M3-A/8 (#581) found for `fieldLabel` and
// `rackLabel`: two rows of a table whose other rows are safe to drive
// directly. A table sitting among tables that ARE safe, with one row
// that is not, is a trap, so the guard sits beside the entity it guards.
//
// **NULL IS NOT A COLLISION.** Two unlabelled trunks are two trunks
// nobody has labelled, which is the ordinary state of a project before
// anybody has walked it (G4, CR-114). Only a SET designator competes.

/// Every designator in use, for the uniqueness scan.
///
/// [exceptPathwayId] lets an edit ignore its own current value, so
/// retyping `T1` onto the pathway that already holds it is `Unchanged`
/// rather than a collision with itself.
///
/// [alsoUsed] is the `alsoUsedLabels` family's third member and exists
/// for the same reason: a bulk edit built against one unmutated document
/// would otherwise let two rows agree on a designator and never notice.
Set<String> usedPathwayDesignators(
  RackDocument doc, {
  Uuid? exceptPathwayId,
  Set<String> alsoUsed = const {},
}) => {
  for (final p in doc.pathways.values)
    if (p.id != exceptPathwayId)
      if (p.designator case final d?) d,
  ...alsoUsed,
};

/// The outcome of [buildSetPathwayDesignator].
///
/// THREE ARMS, on `SetStructureOriginResult`'s reasoning: a caller
/// reports "it did something", "there was nothing to do" and "the edit
/// was not allowed" three different ways, and docs/04 §3.4's *"never
/// silently do nothing"* is about telling the last two apart.
sealed class SetPathwayDesignatorResult {
  const SetPathwayDesignatorResult();
}

final class SetPathwayDesignatorReady extends SetPathwayDesignatorResult {
  const SetPathwayDesignatorReady(this.command);
  final SetEntityPropertyCommand<Pathway, String?> command;
}

/// The pathway already carries the requested designator. Distinct from a
/// refusal: nothing was wrong.
final class SetPathwayDesignatorUnchanged extends SetPathwayDesignatorResult {
  const SetPathwayDesignatorUnchanged();
}

final class SetPathwayDesignatorRefused extends SetPathwayDesignatorResult {
  const SetPathwayDesignatorRefused(this.reason);
  final String reason;
}

/// Sets one pathway's designator, refusing with a sentence rather than
/// writing a value that puts two `T1`s on one Pull Sheet.
///
/// A BLANK BOX BECOMES NULL, never `''`. Clearing it means "this trunk
/// carries no label I know of", and an empty string would be a third
/// state every reader has to guess about: G4's rule is that unknown is
/// ABSENT, not empty. It is also what makes clearing a designator always
/// legal, since null never collides.
SetPathwayDesignatorResult buildSetPathwayDesignator({
  required RackDocument doc,
  required Uuid pathwayId,
  required String? to,
  required DateTime now,
  required String actor,
  Set<String> alsoUsedDesignators = const {},
}) {
  final pathway = doc.pathways[pathwayId];
  if (pathway == null) {
    return const SetPathwayDesignatorRefused(
      'That pathway is not in this project.',
    );
  }

  final trimmed = to?.trim();
  final value = (trimmed?.isEmpty ?? true) ? null : trimmed;

  if (value != null &&
      usedPathwayDesignators(
        doc,
        exceptPathwayId: pathwayId,
        alsoUsed: alsoUsedDesignators,
      ).contains(value)) {
    return SetPathwayDesignatorRefused(
      '$value is already used by another pathway. Pathway designators are '
      'unique where set (DR-026), because two trunks with one designator '
      'is the defect the Pull Sheet column exists to prevent.',
    );
  }

  final from = PathwayField.designator.get(pathway);
  if (from == value) return const SetPathwayDesignatorUnchanged();

  return SetPathwayDesignatorReady(
    SetEntityPropertyCommand<Pathway, String?>(
      id: pathwayId,
      field: PathwayField.designator,
      from: from,
      to: value,
      now: now,
      actor: actor,
    ),
  );
}
