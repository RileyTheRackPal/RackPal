// rackmate_core/src/commands/home_run_commands.dart — pure Dart.
//
// THE GESTURE THAT PRODUCES A DROP. Board M3-A/2 (#141), AC-018,
// requirement 6.
//
// ─────────────────────────────────────────────────────────────────────────
// WHAT WAS ACTUALLY MISSING, VERIFIED BEFORE IT WAS BUILT
// ─────────────────────────────────────────────────────────────────────────
// `Endpoint` has modelled an unbound far end since M0 and NO GESTURE COULD
// PRODUCE ONE, which made AC-018 unreachable by construction. #141's own
// instruction was to check whether the schedule needed teaching first, and
// it does not: `301136f` verified over `whole_house.rmpj` that a link with
// an unbound end already schedules, carries its `W` number and its CR-113
// field label, reaches the Pull Sheet, and is excluded from the Termination
// Schedule only with a reported count. So the work is producing the drops.
//
// (AC-018's fourth clause, "prints", is not reachable in M3 at all:
// `SheetRole` has three values and none is a cable schedule. Board #574.)
//
// ─────────────────────────────────────────────────────────────────────────
// A HOME RUN IS ONE LINK WITH A `structureOrigin`, NOT A NEW ENTITY
// ─────────────────────────────────────────────────────────────────────────
// AC-019: the origin data lives ON the `Link`, and an `Outlet` holds no
// member list — membership is keyed back through
// `Link.structureOrigin.outletId`, so there is exactly one source of truth.
// This command therefore builds the same `Link` every other connect gesture
// builds, plus that one struct. The shape is read off `whole_house.rmpj`
// rather than invented: the FIELD end is `Conductor.from` and the rack end
// is `to`, which is the order the shipped starter uses and the order the
// schedule's `_endOf` walk expects.
//
// ─────────────────────────────────────────────────────────────────────────
// THE FIELD END MAY NOT BE A LIVE PORT, AND THAT IS REFUSED, NOT CLAMPED
// ─────────────────────────────────────────────────────────────────────────
// A home run whose field end resolves to a `Port` is not a home run; it is
// an ordinary patch. Silently rewriting it into one would file a cable on
// the wrong sheet, so [buildAddHomeRunCommand] refuses and says why
// (docs/04 §3.4: never silently do nothing).
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackmate_core/src/commands/set_entity_property_command.dart';
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart'
    show MountSurface, TerminationType, Wall;
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/net.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/service.dart';
import 'package:rackmate_core/src/model/structure_body.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/util/id_gen.dart';

/// The `FracIndex` a new home-run [Link] should sort at.
FracIndex nextLinkOrder(RackDocument doc) =>
    nextOrder(doc.links.values.map((l) => l.order));

/// Every field label CR-113's project-wide uniqueness rule already spends.
///
/// ONE SCAN FOR BOTH THE CREATE AND THE EDIT PATH. A drop can acquire a
/// duplicate label two ways — by being created with one, or by being
/// renamed onto one — and two scans written independently would be two
/// chances to disagree about what "already used" means. This is the one.
///
/// [exceptLinkId] is what the edit path needs and the create path never
/// does: a link's own current label is not a collision with itself, and a
/// scan that thought otherwise would refuse every rename including one
/// that only changed case.
///
/// [alsoUsed] is the sibling reservation `buildAddHomeRunCommand` explains
/// at length: sixty drops entered in one sitting are built against ONE
/// unmutated document.
Set<String> usedFieldLabels(
  RackDocument doc, {
  Uuid? exceptLinkId,
  Set<String> alsoUsed = const {},
}) => {
  for (final l in doc.links.values)
    if (l.id != exceptLinkId)
      if (l.structureOrigin case final o?) o.fieldLabel,
  ...alsoUsed,
};

/// Every rack label in use. Unlike a field label this one is OPTIONAL, so
/// the set holds only the links that have one — an absent rack label is
/// unknown (G4, CR-114), not a value competing for uniqueness.
Set<String> usedRackLabels(
  RackDocument doc, {
  Uuid? exceptLinkId,
  Set<String> alsoUsed = const {},
}) => {
  for (final l in doc.links.values)
    if (l.id != exceptLinkId)
      if (l.structureOrigin?.rackLabel case final r?) r,
  ...alsoUsed,
};

/// Creates one home run: a [Link] carrying a [StructureOrigin], a field end
/// that is deliberately NOT a live port, and a rack end that may or may not
/// have landed yet.
final class AddHomeRunCommand extends Command {
  AddHomeRunCommand({
    required this.structureBodyId,
    required this.outletId,
    required this.fieldLabel,
    required this.designator,
    required this.netName,
    required this.order,
    required this.media,
    required this.fieldEnd,
    required this.terminationField,
    required this.now,
    required this.actor,
    this.rackEnd,
    this.rackLabel,
    this.wall,
    this.mountSurface,
    this.mountHeightAff,
    this.pathwayId,
    Uuid? id,
    Uuid? netId,
  }) : id = id ?? newEntityId(),
       netId = netId ?? newEntityId(),
       assert(
         fieldEnd is! PortEndpoint,
         'AddHomeRunCommand.fieldEnd must not be a PortEndpoint — a home '
         'run that lands on a live port is an ordinary patch. Use '
         'buildAddHomeRunCommand, which refuses this and says why.',
       );

  /// Both minted in the CONSTRUCTOR, never in [apply]: redo must recreate
  /// the identical `Link` and `Net` so a `SheetItem` or a later split still
  /// resolves.
  final Uuid id;
  final Uuid netId;

  final Uuid structureBodyId;
  final Uuid outletId;

  /// "GR-DATA-1" — on the wall plate. REQUIRED and project-unique across
  /// ALL Structure bodies (CR-113). Allocated caller-side; the allocator
  /// itself is board M3-D/1.
  final String fieldLabel;

  /// "PP1-01" — at the panel. Optional, unique when set (CR-113). Null is
  /// UNKNOWN, not "no label": a run that has been pulled but not yet
  /// dressed into a panel genuinely has no rack label, and inventing one
  /// would name a position nobody has terminated (G4, CR-114).
  final String? rackLabel;

  /// "W001". Allocated caller-side through `allocateLinkDesignatorFor`,
  /// whose `alsoUsed` is what lets a bulk entry of sixty drops avoid
  /// handing every one of them the same number.
  final String designator;
  final String netName;
  final FracIndex order;
  final MediaTypeId media;

  /// A [PlaceEndpoint] (pulled to a described place) or an [OpenEndpoint]
  /// (a coil left in a J-hook). Never a [PortEndpoint] — see the header.
  final Endpoint fieldEnd;

  /// The rack end, or NULL when the run has not landed on a port yet.
  ///
  /// NULL BECOMES AN `OpenEndpoint`, NOT AN ERROR. This is the half of
  /// AC-018 the exit criterion counts: fourteen of sixty drops have an
  /// unbound far end, and a rough-in entered in February has no patch panel
  /// to land on yet.
  final Endpoint? rackEnd;

  final TerminationType terminationField;
  final Wall? wall;
  final MountSurface? mountSurface;
  final Len? mountHeightAff;
  final Uuid? pathwayId;
  final DateTime now;
  final String actor;

  @override
  LabelKey get label => LabelKey.addHomeRun;

  /// `wires` for the link and its net; `meta` for the designator and the
  /// two labels that the schedule and the Pull Sheet print.
  @override
  EpochMask get touches => EpochMask.wires | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id, netId, outletId];

  @override
  void apply(RackDocument doc) {
    final meta = EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor);
    doc.nets[netId] = Net(
      id: netId,
      name: netName,
      signalFamily: const SignalFamilyId('structure.undetermined'),
      meta: meta,
    );
    doc.links[id] = Link(
      id: id,
      designator: designator,
      media: media,
      order: order,
      meta: meta,
      pathwayId: pathwayId,
      services: [
        Service(
          id: 'svc-1',
          signalFamily: const SignalFamilyId('structure.undetermined'),
          netId: netId,
        ),
      ],
      // ONE conductor, field end FIRST. That is the order whole_house uses
      // and the order `_endOf` reads.
      conductors: [
        Conductor(
          from: fieldEnd,
          to: rackEnd ?? const OpenEndpoint('not yet landed'),
        ),
      ],
      structureOrigin: StructureOrigin(
        structureBodyId: structureBodyId,
        outletId: outletId,
        fieldLabel: fieldLabel,
        terminationField: terminationField,
        rackLabel: rackLabel,
        wall: wall,
        mountSurface: mountSurface,
        mountHeightAff: mountHeightAff,
      ),
    );
  }

  @override
  void revert(RackDocument doc) {
    doc.links.remove(id);
    doc.nets.remove(netId);
  }
}

/// The outcome of [buildAddHomeRunCommand].
sealed class AddHomeRunResult {
  const AddHomeRunResult();
}

final class AddHomeRunReady extends AddHomeRunResult {
  const AddHomeRunReady(this.command);
  final AddHomeRunCommand command;
}

final class AddHomeRunRefused extends AddHomeRunResult {
  const AddHomeRunRefused(this.reason);
  final String reason;
}

/// Builds the command for one drop, refusing with a sentence rather than
/// throwing or quietly doing nothing (docs/04 §3.4).
///
/// [alsoUsedLabels] and [alsoUsedDesignators] exist for the same reason
/// `allocateLinkDesignatorFor`'s `alsoUsed` does: the M3 exit criterion is
/// sixty drops entered in one sitting, and a caller building them against
/// one unmutated document would otherwise hand every drop the same `W`
/// number and never notice two rows sharing a field label.
AddHomeRunResult buildAddHomeRunCommand({
  required RackDocument doc,
  required Uuid outletId,
  required String fieldLabel,
  required String designator,
  required String netName,
  required MediaTypeId media,
  required Endpoint fieldEnd,
  required TerminationType terminationField,
  required DateTime now,
  required String actor,
  Endpoint? rackEnd,
  String? rackLabel,
  Uuid? pathwayId,
  Set<String> alsoUsedLabels = const {},
  Set<String> alsoUsedDesignators = const {},
  Map<Uuid, Outlet> alsoOutlets = const {},
}) {
  // [alsoOutlets] is the third member of the `alsoUsed` family above and
  // exists for the same reason: a bulk entry builds against ONE unmutated
  // document. `Living Room: 4x Cat6` creates the outlet AND four drops in
  // one transaction, so the outlet those drops name is pending rather
  // than stored, and a lookup that could only see `doc.outlets` would
  // refuse all four with "that outlet is not in this project" — which is
  // true and useless.
  //
  // It is a LOOKUP FALLBACK, not an override: a stored outlet always
  // wins, so a caller cannot accidentally validate against a stale copy
  // of an outlet the document already has.
  final outlet = doc.outlets[outletId] ?? alsoOutlets[outletId];
  if (outlet == null) {
    return const AddHomeRunRefused('That outlet is not in this project.');
  }
  if (!doc.structures.containsKey(outlet.structureBodyId)) {
    return AddHomeRunRefused(
      'Outlet ${outlet.designation} names a Structure body this project '
      'does not carry.',
    );
  }

  // A home run's field end is by definition not a live port. Refused
  // rather than rewritten: see the file header.
  if (fieldEnd is PortEndpoint) {
    return const AddHomeRunRefused(
      'A home run cannot start at a port. Pick a place or leave the end '
      'open; a run between two ports is an ordinary connection.',
    );
  }

  final trimmedLabel = fieldLabel.trim();
  if (trimmedLabel.isEmpty) {
    // CR-113 makes it REQUIRED, and it is the only identifier an unbound
    // end has: nothing else names the run on the wall.
    return const AddHomeRunRefused('A drop needs a field label.');
  }

  final usedLabels = usedFieldLabels(doc, alsoUsed: alsoUsedLabels);
  if (usedLabels.contains(trimmedLabel)) {
    return AddHomeRunRefused(
      '$trimmedLabel is already used by another drop. Field labels are '
      'unique project-wide (CR-113).',
    );
  }

  final trimmedRackLabel = rackLabel?.trim();
  if (trimmedRackLabel != null && trimmedRackLabel.isNotEmpty) {
    if (usedRackLabels(doc).contains(trimmedRackLabel)) {
      return AddHomeRunRefused(
        '$trimmedRackLabel is already used at the panel. Rack labels are '
        'unique where set (CR-113).',
      );
    }
  }

  if (alsoUsedDesignators.contains(designator) ||
      doc.links.values.any((l) => l.designator == designator)) {
    return AddHomeRunRefused(
      '$designator is already a cable in this project. One W number is one '
      'physical cable and one schedule row.',
    );
  }

  return AddHomeRunReady(
    AddHomeRunCommand(
      structureBodyId: outlet.structureBodyId,
      outletId: outletId,
      fieldLabel: trimmedLabel,
      designator: designator,
      netName: netName,
      order: nextLinkOrder(doc),
      media: media,
      fieldEnd: fieldEnd,
      terminationField: terminationField,
      rackEnd: rackEnd,
      rackLabel: (trimmedRackLabel?.isEmpty ?? true) ? null : trimmedRackLabel,
      // The outlet is the authority on where it is. Copying its placement
      // onto the origin is what lets the Pull Sheet print a wall and a
      // height for a run whose far end has no device.
      wall: outlet.wall,
      mountSurface: outlet.mountSurface,
      mountHeightAff: outlet.mountHeightAff,
      pathwayId: pathwayId ?? outlet.pathwayId,
      now: now,
      actor: actor,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// EDITING A DROP AFTER IT EXISTS (board M3-A/8)
// ═════════════════════════════════════════════════════════════════════════
// The table below is `EntityField<Link, T>`, not
// `EntityField<StructureOrigin, T>`, and that is the honest typing rather
// than a workaround: a `StructureOrigin` is not a document-level entity, it
// has no id and no `EntityMeta` of its own, and editing one IS editing the
// `Link` that carries it (AC-019). So the id a caller passes is the LINK's,
// the meta that gets touched is the link's, and undo restores the link's
// revision.
//
// IT LIVES HERE RATHER THAN BESIDE THE OTHER TABLES, deliberately. Two of
// its six rows may not be driven straight through
// `buildSetEntityProperty`: `fieldLabel` and `rackLabel` carry CR-113's
// uniqueness, and a bare table `set` writes the value and returns with no
// way to refuse. Renaming one drop onto another drop's label would produce
// two rows an installer cannot tell apart, silently, through the ordinary
// edit path. A table sitting among tables that ARE safe to drive directly,
// with two rows that are not, is a trap; so the table and the builder that
// guards it sit together, beside the create path whose uniqueness scan they
// share.

/// Reaches a home run's origin, naming the failure rather than letting a
/// null check fire three frames deeper.
StructureOrigin _originOf(Link link) {
  final origin = link.structureOrigin;
  if (origin == null) {
    throw StateError(
      'Link ${link.designator} has no structureOrigin, so it is not a home '
      'run and has no field label to edit. Build the command through '
      'buildSetStructureOriginProperty, which refuses this and says why.',
    );
  }
  return origin;
}

/// Every editable `StructureOrigin` property, keyed by its `Link`'s id.
///
/// ALL SIX DECLARE `wires | meta`, and here that uniformity is honest
/// rather than lazy: every one of them is a fact about a cable that the
/// schedule prints in that cable's row, so a consumer watching either epoch
/// has to see all six. Contrast `OutletField`, where a designation and a
/// mounting height genuinely reach different surfaces.
///
/// Drive these through [buildSetStructureOriginProperty], never through
/// `buildSetEntityProperty` — see the block comment above.
abstract final class StructureOriginField {
  /// "GR-DATA-1", on the wall plate. REQUIRED and unique project-wide
  /// across ALL Structure bodies (CR-113).
  static final fieldLabel = EntityField<Link, String>(
    access: EntityAccess.link,
    key: 'origin.fieldLabel',
    get: (l) => _originOf(l).fieldLabel,
    set: (l, v) => _originOf(l).fieldLabel = v,
    touches: EpochMask.wires | EpochMask.meta,
  );

  /// "PP1-01", at the panel. Optional, unique WHERE SET. Null is UNKNOWN,
  /// not "no label": a run pulled but not yet dressed into a panel
  /// genuinely has none, and inventing one names a position nobody has
  /// terminated (G4, CR-114).
  static final rackLabel = EntityField<Link, String?>(
    access: EntityAccess.link,
    key: 'origin.rackLabel',
    get: (l) => _originOf(l).rackLabel,
    set: (l, v) => _originOf(l).rackLabel = v,
    touches: EpochMask.wires | EpochMask.meta,
  );

  static final wall = EntityField<Link, Wall?>(
    access: EntityAccess.link,
    key: 'origin.wall',
    get: (l) => _originOf(l).wall,
    set: (l, v) => _originOf(l).wall = v,
    touches: EpochMask.wires | EpochMask.meta,
  );

  static final mountSurface = EntityField<Link, MountSurface?>(
    access: EntityAccess.link,
    key: 'origin.mountSurface',
    get: (l) => _originOf(l).mountSurface,
    set: (l, v) => _originOf(l).mountSurface = v,
    touches: EpochMask.wires | EpochMask.meta,
  );

  /// Height above finished floor. Null is UNKNOWN, never a measured zero.
  static final mountHeightAff = EntityField<Link, Len?>(
    access: EntityAccess.link,
    key: 'origin.mountHeightAff',
    get: (l) => _originOf(l).mountHeightAff,
    set: (l, v) => _originOf(l).mountHeightAff = v,
    touches: EpochMask.wires | EpochMask.meta,
  );

  static final terminationField = EntityField<Link, TerminationType>(
    access: EntityAccess.link,
    key: 'origin.terminationField',
    get: (l) => _originOf(l).terminationField,
    set: (l, v) => _originOf(l).terminationField = v,
    touches: EpochMask.wires | EpochMask.meta,
  );

  /// Every field in the table. READ-ONLY use — see `OutletField.all`.
  static final List<EntityField<Link, Object?>> all = [
    fieldLabel,
    rackLabel,
    wall,
    mountSurface,
    mountHeightAff,
    terminationField,
  ];
}

/// The outcome of [buildSetStructureOriginProperty].
///
/// THREE ARMS, NOT TWO. `buildSetEntityProperty` collapses "nothing to do"
/// into a null return, which is fine when the only other outcome is a
/// command. Here there are three genuinely different things a caller
/// reports differently: it did something; it did nothing because there was
/// nothing to do; it did nothing because the edit was not allowed.
/// docs/04 §3.4's "never silently do nothing" is about telling the last two
/// apart.
sealed class SetStructureOriginResult {
  const SetStructureOriginResult();
}

final class SetStructureOriginReady<T> extends SetStructureOriginResult {
  const SetStructureOriginReady(this.command);
  final SetEntityPropertyCommand<Link, T> command;
}

/// The field already holds the requested value, so there is nothing to
/// push. Distinct from a refusal: nothing was wrong.
final class SetStructureOriginUnchanged extends SetStructureOriginResult {
  const SetStructureOriginUnchanged();
}

final class SetStructureOriginRefused extends SetStructureOriginResult {
  const SetStructureOriginRefused(this.reason);
  final String reason;
}

/// Builds the command that edits one [StructureOriginField] on the home run
/// carried by [linkId], refusing with a sentence rather than throwing or
/// quietly writing a value that breaks CR-113.
///
/// [alsoUsedLabels] and [alsoUsedRackLabels] exist for the same reason
/// [buildAddHomeRunCommand]'s do: a bulk edit built against one unmutated
/// document would otherwise let two rows agree on a label and never notice.
///
/// A BLANK RACK LABEL BECOMES NULL rather than an empty string. Clearing
/// the box means "I do not know where this lands", and `''` would be a
/// third state the schedule has to guess about — G4's rule is that unknown
/// is ABSENT, not empty.
SetStructureOriginResult buildSetStructureOriginProperty<T>({
  required RackDocument doc,
  required Uuid linkId,
  required EntityField<Link, T> field,
  required T to,
  required DateTime now,
  required String actor,
  Set<String> alsoUsedLabels = const {},
  Set<String> alsoUsedRackLabels = const {},
}) {
  final link = doc.links[linkId];
  if (link == null) {
    return const SetStructureOriginRefused(
      'That cable is not in this project.',
    );
  }
  if (link.structureOrigin == null) {
    return SetStructureOriginRefused(
      '${link.designator} is not a home run, so it has no wall-plate origin '
      'to edit.',
    );
  }

  var value = to;

  if (identical(field, StructureOriginField.fieldLabel)) {
    final trimmed = (to! as String).trim();
    if (trimmed.isEmpty) {
      // CR-113 makes it REQUIRED, and for an unbound far end it is the only
      // identifier the run has: nothing else names it on the wall.
      return const SetStructureOriginRefused('A drop needs a field label.');
    }
    if (usedFieldLabels(
      doc,
      exceptLinkId: linkId,
      alsoUsed: alsoUsedLabels,
    ).contains(trimmed)) {
      return SetStructureOriginRefused(
        '$trimmed is already used by another drop. Field labels are unique '
        'project-wide (CR-113).',
      );
    }
    value = trimmed as T;
  }

  if (identical(field, StructureOriginField.rackLabel)) {
    final trimmed = (to as String?)?.trim();
    if (trimmed != null &&
        trimmed.isNotEmpty &&
        usedRackLabels(
          doc,
          exceptLinkId: linkId,
          alsoUsed: alsoUsedRackLabels,
        ).contains(trimmed)) {
      return SetStructureOriginRefused(
        '$trimmed is already used at the panel. Rack labels are unique '
        'where set (CR-113).',
      );
    }
    value = ((trimmed?.isEmpty ?? true) ? null : trimmed) as T;
  }

  final from = field.get(link);
  if (from == value) return const SetStructureOriginUnchanged();

  return SetStructureOriginReady<T>(
    SetEntityPropertyCommand<Link, T>(
      id: linkId,
      field: field,
      from: from,
      to: value,
      now: now,
      actor: actor,
    ),
  );
}
