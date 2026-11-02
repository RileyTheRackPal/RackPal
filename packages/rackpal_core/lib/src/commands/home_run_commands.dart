// rackpal_core/src/commands/home_run_commands.dart — pure Dart.
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
// it does not: `70cb8d5` verified over `whole_house.rppj` that a link with
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
// builds, plus that one struct. The shape is read off `whole_house.rppj`
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
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackpal_core/src/commands/set_entity_property_command.dart';
import 'package:rackpal_core/src/derived/device_loads.dart' show hostRackOf;
import 'package:rackpal_core/src/idformat/designator_allocator.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/enums.dart'
    show MountSurface, TerminationType, Wall;
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/net.dart';
import 'package:rackpal_core/src/model/outlet.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/service.dart';
import 'package:rackpal_core/src/model/structure_body.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/util/id_gen.dart';

/// The `FracIndex` a new home-run [Link] should sort at.
/// The next `Link` order, counting what siblings in this same gesture
/// have already spent.
///
/// **[alsoUsed] IS THE FOURTH RESERVATION AND IT WAS MISSING (board
/// #691).** `buildDropsFor` already threads three of these, for labels,
/// designators and net names, because the whole line is planned against
/// ONE UNMUTATED document and a value spent by drop 3 has to be visible
/// to drop 4. Ordering was the one member of that family nobody wrote.
///
/// Measured before the fix: `LR: 3x Cat6` minted three links all at
/// `a0`, so `buildSchedule`'s `order` then `id` sort fell through to a
/// random entity id and a line's rows came out in a different order every
/// run, never the order the operator typed. It had been invisible since
/// M3-C because nothing had ever compared the typed order with the
/// printed one.
FracIndex nextLinkOrder(
  RackDocument doc, {
  Iterable<FracIndex> alsoUsed = const [],
}) => nextOrder([...doc.links.values.map((l) => l.order), ...alsoUsed]);

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
    if (l.id != exceptLinkId) ?l.structureOrigin?.rackLabel,
  ...alsoUsed,
};

/// What [resolveRackLabel] found: a label, or nothing and a reason.
///
/// TWO NULLABLE FIELDS RATHER THAN A SEALED PAIR, and DR-040 §11.39.5 is
/// why. A landing that cannot render a label is NOT a failure: the drop
/// still gets punched down and the document still records where. So the
/// caller always proceeds and the two fields answer two questions it
/// always has — what to write, and what to tell the user. A sealed union
/// would make the ordinary "no floor number yet" case look like an error
/// path and invite a caller to refuse the bind on it.
@immutable
final class RackLabelResolution {
  const RackLabelResolution({this.label, this.note});

  /// `1A-PP-101`, or NULL when the pattern could not render.
  final String? label;

  /// A sentence naming the field a person has to fill, or null when there
  /// was nothing to say.
  final String? note;
}

/// The `rackLabel` a drop landing on [portDesignator] of [panelDeviceId]
/// should carry (DR-040 §11.39.2 clause 3, §11.39.3).
///
/// ═════════════════════════════════════════════════════════════════════
/// THIS IS `allocateOutletRackLabel`'S FIRST CALLER, AND IT WAITED A
/// MILESTONE
/// ═════════════════════════════════════════════════════════════════════
/// That allocator shipped with M3-D/1 and had four callers, all of them in
/// its own test file. It was not uncalled, it was UNCALLABLE: the shipped
/// pattern is `{FLOOR}{SPACE}-{PANEL}{PORT:2}` and `{PANEL}` and `{PORT}`
/// are facts about a landing that nothing in the product recorded. M3-K/2
/// records the landing; this renders the label from it.
///
/// `{PANEL}` IS THE DEVICE DESIGNATOR (§11.39.3). CR-044 renders the
/// preset `1A-A12`, which is a TIA-606 example rather than a
/// specification: it names no source for the panel segment. The model has
/// exactly one identifier for a panel because **the model has no `Panel`
/// entity**, which `derived/schedule.dart` already says out loud when it
/// calls a patch panel *"a `DeviceInstance` like any other"* and sorts
/// §3.6's `rack, panel, port` on the designator. So the default preset
/// renders `1A-PP-101`, and a `panelLetter` field invented to reproduce
/// the `A` would be a fact nobody stated added to match a rendering.
///
/// `{FLOOR}` AND `{SPACE}` ARE THE PANEL'S, NEVER THE DROP'S ROOM. `1A` is
/// the telecom room; a drop pulled from a second-floor bedroom does not
/// make the panel's label say `2`. Read through the same walk the schedule
/// uses, `device.locationId ?? hostRack.locationId`, so a panel that
/// inherits its room from its rack is not treated as roomless.
RackLabelResolution resolveRackLabel({
  required RackDocument doc,
  required Uuid panelDeviceId,
  required String portDesignator,
  required Set<String> usedRackLabels,
}) {
  final panel = doc.devices[panelDeviceId];
  if (panel == null) {
    return const RackLabelResolution(
      note: 'That panel is not in this project, so no rack label was set.',
    );
  }
  final rackId = hostRackOf(panel, doc.devices);
  final locationId = panel.locationId ?? doc.racks[rackId]?.locationId;
  final location = locationId == null ? null : doc.locations[locationId];

  final allocated = allocateOutletRackLabel(
    settings: doc.settings,
    values: {
      'PANEL': panel.designator,
      'PORT': portDesignator,
      'FLOOR': ?location?.floorNumber,
      if (location?.spaceCode?.trim() case final s? when s.isNotEmpty)
        'SPACE': s,
      if (location?.code.trim() case final c? when c.isNotEmpty) 'ROOM_ABBR': c,
      'RACK': ?doc.racks[rackId]?.designator,
    },
    usedLabels: usedRackLabels,
  );

  switch (allocated) {
    case LabelAllocated(:final label):
      return RackLabelResolution(label: label);
    case LabelTokensMissing(:final tokens, :final pattern):
      // §11.39.5: the bind proceeds and the label is absent. The sentence
      // names the FIELD rather than the token, on
      // `missingTokenSentence`'s rule, because a person who has never
      // read the pattern cannot act on `{SPACE}`.
      const fields = {
        'FLOOR': 'a floor number',
        'SPACE': 'a space code',
        'PANEL': 'a designator',
        'ROOM_ABBR': 'a short code',
      };
      final named = [
        for (final t in tokens) ?fields[t],
      ];
      final what = named.isEmpty ? tokens.join(', ') : named.join(' and ');
      return RackLabelResolution(
        note:
            'The drop is landed, but its rack label needs $what on the '
            "panel's location before it can be written. The pattern is "
            '"$pattern".',
      );
  }
}

/// Creates one home run: a [Link] carrying a [StructureOrigin], a field end
/// that is deliberately NOT a live port, and a rack end that may or may not
/// have landed yet.
final class AddHomeRunCommand extends Command<RackDocument> {
  AddHomeRunCommand({
    required this.structureBodyId,
    required this.outletId,
    required this.fieldLabel,
    required this.designator,
    required this.netName,
    required this.order,
    required this.media,
    required this.fieldEnd,
    required this.now,
    required this.actor,
    this.boxless = false,
    this.rackEnd,
    this.rackLabel,
    this.terminationField,
    this.terminationRack,
    this.wall,
    this.mountSurface,
    this.mountHeightAff,
    this.pathwayId,
    this.signalFamily,
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

  /// This run comes out of no box, so it has no `Outlet` (`#718`).
  /// Carried onto the `StructureOrigin` verbatim.
  final bool boxless;
  final Uuid? outletId;

  /// The signal family this run carries, or null for "nobody has said"
  /// (DR-025 §11.24). Null becomes `structure.undetermined`, which is
  /// docs/07 §4.1's first-class, encouraged state: at rough-in a Cat6 is
  /// just a Cat6.
  ///
  /// **§11.24.6: THE FAMILY IS STORED TWICE AND BOTH ARE WRITTEN HERE.**
  /// `Service.signalFamily` is what the palette and the DRC read; docs/05
  /// §5 is explicit that colour resolves from it and never from the
  /// `Link`. `Net.signalFamily` is written, serialised, and read by
  /// nothing but the codec today. A command that set one and not the
  /// other would leave the file carrying two answers to one question in
  /// the one place nothing would notice, which is CR-107's failure in
  /// miniature. Both or neither.
  final SignalFamilyId? signalFamily;

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

  /// How the wall-plate end is finished. NULL IS UNKNOWN (G4, CR-114):
  /// a drop entered at rough-in has no answer, and `unterminated` is a
  /// decision rather than an absence. See `StructureOrigin`.
  final TerminationType? terminationField;

  /// How the RACK end is finished (DR-046). Null is UNSPECIFIED and is
  /// never inferred from [terminationField].
  final TerminationType? terminationRack;
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
  Iterable<Uuid> get affects => [id, netId, ?outletId];

  /// ONE PLACE THE DEFAULT LIVES, so the Net and the Service cannot
  /// drift apart. See [signalFamily].
  SignalFamilyId get _family =>
      signalFamily ?? const SignalFamilyId('structure.undetermined');

  @override
  bool apply(RackDocument doc) {
    final meta = EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor);
    doc.nets[netId] = Net(
      id: netId,
      name: netName,
      signalFamily: _family,
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
          signalFamily: _family,
          netId: netId,
        ),
      ],
      // ONE conductor, field end FIRST. That is the order whole_house uses
      // and the order `_endOf` reads.
      conductors: [
        Conductor(
          from: fieldEnd,
          to: rackEnd ?? const OpenEndpoint(kUnlandedEndDescription),
        ),
      ],
      structureOrigin: StructureOrigin(
        structureBodyId: structureBodyId,
        outletId: outletId,
        // FORWARDED, and the line beneath `signalFamily`'s own warning in
        // this file says why it is worth a comment: a parameter that
        // parsed, planned and then vanished at the last hop is a defect
        // this project has shipped more than once, most recently as
        // `#711`. The test asserts the flag off the DOCUMENT, not off
        // the command.
        boxless: boxless,
        fieldLabel: fieldLabel,
        terminationField: terminationField,
        terminationRack: terminationRack,
        rackLabel: rackLabel,
        wall: wall,
        mountSurface: mountSurface,
        mountHeightAff: mountHeightAff,
      ),
    );
    return true;
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
  required String fieldLabel,
  required String designator,
  required String netName,
  required MediaTypeId media,
  required Endpoint fieldEnd,
  required DateTime now,
  required String actor,
  Endpoint? rackEnd,
  String? rackLabel,
  TerminationType? terminationField,
  TerminationType? terminationRack,
  Uuid? pathwayId,
  SignalFamilyId? signalFamily,

  /// The box this run comes out of. Null ONLY with `structureBodyId`
  /// given instead, which is `#718`'s boxless run.
  Uuid? outletId,

  /// Required when `outletId` is null, and ignored otherwise: with a box
  /// the outlet is the authority on which body owns the run, and reading
  /// a caller's copy instead would let the two disagree.
  Uuid? structureBodyId,

  /// Orders already spent by earlier drops in THIS gesture (#691).
  Iterable<FracIndex> alsoUsedOrders = const [],
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
  // ═════════════════════════════════════════════════════════════════
  // A RUN WITH NO BOX (`#718`, DR-070)
  // ═════════════════════════════════════════════════════════════════
  // A ceiling speaker has no low-voltage box, so it has no `Outlet`, and
  // demanding one made the Outlets page list a plate for a speaker that
  // has none. The two facts the outlet used to supply then have to come
  // from somewhere: which Structure body owns the run, and where on the
  // wall it sits. The first is the caller's to state; the second does
  // not exist, and is left unknown rather than invented (G4).
  //
  // EXACTLY ONE OF THE TWO IS REQUIRED, and saying neither or both is a
  // caller bug rather than a user error, so it refuses in words that
  // name the API and not the job.
  if ((outletId == null) == (structureBodyId == null)) {
    return const AddHomeRunRefused(
      'A home run names an outlet, or a Structure body when it comes out '
      'of no box. Give exactly one.',
    );
  }

  Outlet? outlet;
  final Uuid ownerBodyId;
  if (outletId != null) {
    outlet = doc.outlets[outletId] ?? alsoOutlets[outletId];
    if (outlet == null) {
      return const AddHomeRunRefused('That outlet is not in this project.');
    }
    if (!doc.structures.containsKey(outlet.structureBodyId)) {
      return AddHomeRunRefused(
        'Outlet ${outlet.designation} names a Structure body this project '
        'does not carry.',
      );
    }
    ownerBodyId = outlet.structureBodyId;
  } else {
    if (!doc.structures.containsKey(structureBodyId)) {
      return const AddHomeRunRefused(
        'That Structure body is not in this project.',
      );
    }
    ownerBodyId = structureBodyId!;

    // ═══════════════════════════════════════════════════════════════
    // WITHOUT A BOX, THE FIELD END MUST SAY WHICH ROOM IT IS IN
    // ═══════════════════════════════════════════════════════════════
    // `buildScheduleEntry` reads a run's room as
    // `from.locationId ?? outlet?.locationId ?? to.locationId`, and its
    // own comment says why the last of those is a trap: "a run's room is
    // where its drop is, not where its rack is ... AC-025's 'the order
    // the tech walks the house' means nothing if every row groups under
    // the equipment room."
    //
    // With a box the outlet answers. Without one the only remaining
    // answer is the field end's, and a boxless run that did not carry a
    // location would silently sort itself into the rack's room on the
    // Pull Sheet the installer works from. Refused at creation rather
    // than papered over at render time.
    final place = fieldEnd is PlaceEndpoint ? fieldEnd : null;
    if (place?.locationId == null) {
      return const AddHomeRunRefused(
        'A run with no outlet has nothing to say which room it is in, so '
        'its field end needs a location.',
      );
    }
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
      structureBodyId: ownerBodyId,
      outletId: outletId,
      // THE FLAG IS THE STATEMENT, not the absent id. See
      // `StructureOrigin.outletId`: null alone is "nobody has said".
      boxless: outletId == null,
      fieldLabel: trimmedLabel,
      designator: designator,
      netName: netName,
      order: nextLinkOrder(doc, alsoUsed: alsoUsedOrders),
      media: media,
      fieldEnd: fieldEnd,
      terminationField: terminationField,
      terminationRack: terminationRack,
      rackEnd: rackEnd,
      rackLabel: (trimmedRackLabel?.isEmpty ?? true) ? null : trimmedRackLabel,
      // WITH a box the outlet is the authority on where it is, and
      // copying its placement onto the origin is what lets the Pull Sheet
      // print a wall and a height for a run whose far end has no device.
      // UNKNOWN WITHOUT ONE, never a default. The outlet is the
      // authority on where it is, and a run with no outlet has nobody to
      // ask; substituting a height would put a number on a schedule that
      // no one measured (G4, CR-114).
      wall: outlet?.wall,
      mountSurface: outlet?.mountSurface,
      mountHeightAff: outlet?.mountHeightAff,
      pathwayId: pathwayId ?? outlet?.pathwayId,
      // FORWARDED, and this line is why the task says to probe the chain
      // rather than read it. DR-046's own record is of a parameter that
      // parsed, planned, and then vanished here, with every layer correct
      // in isolation.
      signalFamily: signalFamily,
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

  static final terminationField = EntityField<Link, TerminationType?>(
    access: EntityAccess.link,
    key: 'origin.terminationField',
    get: (l) => _originOf(l).terminationField,
    set: (l, v) => _originOf(l).terminationField = v,
    touches: EpochMask.wires | EpochMask.meta,
  );

  /// How the RACK end is finished (DR-046 §11.45). A SECOND FIELD
  /// because there was only ever one, and both columns read it.
  static final terminationRack = EntityField<Link, TerminationType?>(
    access: EntityAccess.link,
    key: 'origin.terminationRack',
    get: (l) => _originOf(l).terminationRack,
    set: (l, v) => _originOf(l).terminationRack = v,
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
    terminationRack,
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

// ═════════════════════════════════════════════════════════════════════════
// THE ONE EDIT PATH THAT MAY SAY "A PERSON TYPED THIS" (DR-074 §11.73.2)
// ═════════════════════════════════════════════════════════════════════════
// A rack label has two authors. The allocator writes one at the moment a
// run lands, because the label is DERIVED from the position it landed in
// (DR-040 §11.39.3); a person writes one in the `RACK LBL` column, and
// CR-113 makes theirs unique project-wide. Both end up in the same string
// field, and until DR-074 nothing had to tell them apart.
//
// A MOVE IS WHAT MAKES THE DIFFERENCE MATTER. Re-deriving is right for an
// allocated label — `1A-PP-101` on a cable now sitting in position 04 names
// the wrong hole on the one column a trim tech works from — and wrong for
// somebody's own identifier, which G4 refuses to discard. So the write path
// a person drives records that it was a person, and
// `StructureOrigin.rackLabelLocked` is that record.
//
// TWO FIELDS IN ONE COMMAND, on `SetLinkClassCommand`'s precedent and not
// through `SetEntityPropertyCommand`: that command writes exactly one
// declared field and reverts it, so a lock written beside it would be a
// second mutation with no undo. `EntityField` cannot carry the pair either,
// because its `set` is called by `revert` as well and would re-lock on the
// way back out.

/// Sets a home run's `RACK LBL` and records that A PERSON set it
/// (DR-074 §11.73.2).
///
/// CLEARING THE CELL CLEARS THE LOCK TOO, and that is the half worth
/// stating out loud. A blank label means "I do not know where this lands"
/// (G4), and a locked null would say instead "nobody may ever name this",
/// which no surface can undo and no person asked for: a one-way door of
/// exactly the kind `ClearLinkClassOverrideCommand` exists to refuse. So a
/// blank hands the label back to the allocator, and the next landing
/// derives one again.
///
/// Drive this through [buildSetRackLabel], never directly: CR-113's
/// project-wide uniqueness is the builder's job, and a bare command writes
/// and returns with no way to refuse.
final class SetRackLabelCommand extends Command<RackDocument> {
  SetRackLabelCommand({
    required this.linkId,
    required this.rackLabel,
    required this.now,
    required this.actor,
  });

  final Uuid linkId;

  /// The label, ALREADY NORMALISED by the builder: trimmed, and null
  /// rather than empty.
  final String? rackLabel;

  final DateTime now;
  final String actor;

  /// The pair replaced. `_applied` carries the "has run" bit rather than a
  /// null check, matching `SetLinkClassCommand`, and here it is
  /// load-bearing twice over: null is an ordinary previous label and false
  /// is an ordinary previous lock.
  String? _previousLabel;
  bool _previousLocked = false;
  EntityMeta? _previousMeta;
  bool _applied = false;

  /// ITS OWN WORD, not `setEntityProperty`. A rack label is the identifier
  /// a trim tech reads off the cable, and "Undo edit" beside a move and a
  /// landing that both also touch it would leave three gestures sharing
  /// one sentence.
  @override
  LabelKey get label => LabelKey.setRackLabel;

  /// The same pair every `StructureOriginField` declares: the schedule
  /// prints this in the cable's own row.
  @override
  EpochMask get touches => EpochMask.wires | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [linkId];

  /// Per LINK, so typing into one cell coalesces into one undo entry and
  /// typing into the next does not merge with it. Same contract as
  /// `SetEntityPropertyCommand.mergeKey`, which this replaces for this one
  /// field.
  @override
  Object? get mergeKey => (SetRackLabelCommand, linkId);

  @override
  bool apply(RackDocument doc) {
    final link = doc.links[linkId];
    final origin = link?.structureOrigin;
    if (link == null || origin == null) return false;
    _previousLabel = origin.rackLabel;
    _previousLocked = origin.rackLabelLocked;
    _previousMeta = link.meta;
    _applied = true;
    origin
      ..rackLabel = rackLabel
      // FALSE WHEN THE CELL WAS CLEARED. See the class doc: a locked null
      // is a door that only closes.
      ..rackLabelLocked = rackLabel != null;
    link.meta = EntityMeta(
      createdAt: link.meta.createdAt,
      updatedAt: now,
      updatedBy: actor,
    );
    return _applied;
  }

  @override
  void revert(RackDocument doc) {
    final link = doc.links[linkId];
    final origin = link?.structureOrigin;
    if (link == null || origin == null) return;
    if (!_applied) {
      throw StateError('SetRackLabelCommand.revert called before apply().');
    }
    // BOTH, and the lock is the one that matters: restoring the label
    // alone would leave a re-derivable name pinned by an assertion the
    // user has just undone.
    origin
      ..rackLabel = _previousLabel
      ..rackLabelLocked = _previousLocked;
    if (_previousMeta case final meta?) link.meta = meta;
  }

  @override
  Command<RackDocument>? mergeWith(Command<RackDocument> next) {
    if (next is! SetRackLabelCommand) return null;
    if (next.linkId != linkId) return null;
    // Carries THIS command's captured "before" forward, because the merged
    // object never has apply() called on it before a possible revert().
    // Same reasoning as `SetEntityPropertyCommand.mergeWith`.
    return SetRackLabelCommand(
        linkId: linkId,
        rackLabel: next.rackLabel,
        now: next.now,
        actor: next.actor,
      )
      .._previousLabel = _previousLabel
      .._previousLocked = _previousLocked
      .._previousMeta = _previousMeta
      .._applied = _applied;
  }
}

/// The outcome of [buildSetRackLabel].
///
/// THREE ARMS, for [SetStructureOriginResult]'s stated reason: "it did
/// nothing because there was nothing to do" and "it did nothing because the
/// edit was not allowed" are different things to report.
sealed class SetRackLabelResult {
  const SetRackLabelResult();
}

final class SetRackLabelReady extends SetRackLabelResult {
  const SetRackLabelReady(this.command);
  final SetRackLabelCommand command;
}

/// The label AND the lock already say what the edit asks for.
final class SetRackLabelUnchanged extends SetRackLabelResult {
  const SetRackLabelUnchanged();
}

final class SetRackLabelRefused extends SetRackLabelResult {
  const SetRackLabelRefused(this.reason);
  final String reason;
}

/// Builds the `RACK LBL` cell's edit, refusing rather than breaking CR-113.
///
/// [alsoUsedRackLabels] exists for [buildSetStructureOriginProperty]'s
/// reason: a batch built against one unmutated document would otherwise let
/// two rows agree on a label and never notice.
///
/// A LABEL THE LINK ALREADY HOLDS IS STILL AN EDIT WHEN THE LOCK IS OFF,
/// and that is deliberate: the run may be carrying an allocated label that
/// happens to read the way the person would have typed it, and typing it is
/// them adopting it. Reporting "nothing to do" there would silently decline
/// to record the assertion, which is the call `SetLinkClassCommand` makes
/// for the same reason one field up.
SetRackLabelResult buildSetRackLabel({
  required RackDocument doc,
  required Uuid linkId,
  required String? to,
  required DateTime now,
  required String actor,
  Set<String> alsoUsedRackLabels = const {},
}) {
  final link = doc.links[linkId];
  if (link == null) {
    return const SetRackLabelRefused('That cable is not in this project.');
  }
  final origin = link.structureOrigin;
  if (origin == null) {
    return SetRackLabelRefused(
      '${link.designator} is not a home run, so it has no rack label.',
    );
  }

  final trimmed = to?.trim();
  final value = (trimmed?.isEmpty ?? true) ? null : trimmed;
  if (value != null &&
      usedRackLabels(
        doc,
        exceptLinkId: linkId,
        alsoUsed: alsoUsedRackLabels,
      ).contains(value)) {
    return SetRackLabelRefused(
      '$value is already used at the panel. Rack labels are unique where '
      'set (CR-113).',
    );
  }

  final locked = value != null;
  if (origin.rackLabel == value && origin.rackLabelLocked == locked) {
    return const SetRackLabelUnchanged();
  }

  return SetRackLabelReady(
    SetRackLabelCommand(
      linkId: linkId,
      rackLabel: value,
      now: now,
      actor: actor,
    ),
  );
}
