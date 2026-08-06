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
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart'
    show MountSurface, TerminationType, Wall;
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/net.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/service.dart';
import 'package:rackmate_core/src/model/structure_body.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/util/id_gen.dart';

/// The `FracIndex` a new home-run [Link] should sort at.
FracIndex nextLinkOrder(RackDocument doc) =>
    nextOrder(doc.links.values.map((l) => l.order));

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
}) {
  final outlet = doc.outlets[outletId];
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

  final usedLabels = <String>{
    for (final l in doc.links.values)
      if (l.structureOrigin case final o?) o.fieldLabel,
    ...alsoUsedLabels,
  };
  if (usedLabels.contains(trimmedLabel)) {
    return AddHomeRunRefused(
      '$trimmedLabel is already used by another drop. Field labels are '
      'unique project-wide (CR-113).',
    );
  }

  final trimmedRackLabel = rackLabel?.trim();
  if (trimmedRackLabel != null && trimmedRackLabel.isNotEmpty) {
    final usedRackLabels = <String>{
      for (final l in doc.links.values)
        if (l.structureOrigin?.rackLabel case final r?) r,
    };
    if (usedRackLabels.contains(trimmedRackLabel)) {
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
