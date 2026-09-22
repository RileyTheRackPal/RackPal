import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/pt.dart';

// docs/02-data-model.md §4.3. Every variant's fields are `final` in the
// spec — a placement change replaces the whole object
// (`d.placement = RailPlacement(...)`, docs/03-architecture.md §5.2)
// rather than mutating one in place.

/// Which face of the rack a device is mounted on. Reconciles the
/// "RackFace" name used in docs/03-architecture.md's `MoveDeviceCommand`
/// example with docs/02-data-model.md's "Face" — the data model doc wins
/// on naming (per this package's own governing instructions); treat
/// "RackFace" anywhere else in the corpus as this same type.
enum Face { front, rear }

/// Whether a device is mounted as designed or turned end-for-end in the
/// rack. The resolved port face is `templateFace XOR reversed` (AC-023).
enum ChassisRotation { normal, reversed }

/// Spatial orientation of a device in a 0U vertical rail channel.
///
/// Named `ZeroUOrientation` rather than bare `Orientation` because
/// `Sheet` needs an unrelated *page* orientation (portrait/landscape) —
/// colliding two different concepts on one enum name is exactly what
/// docs/02-data-model.md §4.8 warns against. See `PageOrientation` in
/// sheet.dart.
///
/// M0 MINIMAL SHAPE: the spec declares `Orientation orientation` on
/// `ZeroUPlacement` without enumerating values; `horizontal`/`vertical` is
/// the obvious minimal reading for "which way a 0U-mounted device faces
/// in its channel".
enum ZeroUOrientation { horizontal, vertical }

/// Where a `DeviceInstance` sits — a sealed union of five mutually
/// exclusive placement kinds. Elevation X/Y is NEVER stored; it is always
/// derived from `(Placement, rail geometry, face)` (CR-006).
sealed class Placement {
  const Placement({this.unknown = const <String, Object?>{}});

  /// Forward-compat / passthrough for fields this reader does not model
  /// (DR-019 §11.18.2(5)). Without it a build that predates a later
  /// placement field silently DROPS that field on save, and under DR-006's
  /// shared-file reality two builds touching one project is ordinary.
  ///
  /// ON THE BASE, NOT ON EACH VARIANT, because the passthrough is a fact
  /// about being a `Placement` rather than about being a rail or a shelf,
  /// and five copies of one field is how the copies stop agreeing.
  ///
  /// A `const` EMPTY DEFAULT, WHICH IS A DELIBERATE DEVIATION FROM THE
  /// `Port` PRECEDENT. `port.dart` writes `unknown ?? {}` in an initialiser
  /// list, giving every instance a fresh MUTABLE map. That is right for
  /// `Port`, which is a mutable entity; it is wrong here twice over. This
  /// file's own header states that a placement change REPLACES the whole
  /// object rather than mutating one in place, so nothing should be adding
  /// keys to a live placement's bag. And `unknown ?? {}` cannot be `const`,
  /// which would have cost every `const RailPlacement(...)` in the fixtures
  /// and tests its constness for a field none of them set. A shared const
  /// empty map is both the honest shape and the one with no blast radius.
  ///
  /// RESERVED CONTAINER, NOT A HARVESTER. Nothing collects unrecognised
  /// SIBLING keys: what survives a round trip is what a writer deliberately
  /// put in this bag, which is the contract `codec_split_test.dart` already
  /// asserts for `Port`. Harvesting siblings would be a different format
  /// and would need its own ruling (roadmap §8.3).
  final Map<String, Object?> unknown;
}

/// Mounted to the rack's vertical rails, on one face, at one RU.
final class RailPlacement extends Placement {
  const RailPlacement({
    required this.rackId,
    required this.ruIndex,
    required this.face,
    this.startTwelfth = 0,
    this.spanTwelfths = 12,
    this.depthOffsetFromFront,
    this.chassisRotation = ChassisRotation.normal,
    this.locked = false,
    super.unknown,
  });

  final Uuid rackId;

  /// 1-based, bottom origin, always — regardless of display numbering
  /// (CR-025, CR-026).
  final int ruIndex;
  final Face face;

  /// 0..11. v1 UI only ever produces Full(0,12) / Left(0,6) / Right(6,6);
  /// free lateral drag is v1.2 (CR-030).
  final int startTwelfth;

  /// 1..12.
  final int spanTwelfths;
  final Len? depthOffsetFromFront;
  final ChassisRotation chassisRotation;
  final bool locked;

  /// This placement with [locked] set (DR-186). The one site that knows
  /// every other field, on `OffRackPlacement.withPlanPin`'s reasoning: a
  /// field added later is a compile-visible edit here rather than a silent
  /// drop at every caller that rebuilt the object by hand.
  RailPlacement withLocked({required bool locked}) {
    // READ OFF A LOCAL, which is `device_width_commands.dart`'s own
    // `_rebuild(base, ...)` shape and is not a style choice here.
    // `placement_rules_test.dart`'s PLC-002 gate reads `lib/` for a file
    // that SETS a lateral position rather than copying one, and it tells a
    // copy by the field being read back on the right-hand side. A bare
    // `startTwelfth: startTwelfth` is a copy that does not look like one,
    // and it cannot be spelled `this.startTwelfth` either, because the
    // analyzer calls that qualifier unnecessary. The gate is right to be
    // strict: the real writer in that file uses the bare spelling for a
    // PARAMETER carrying a new value, so teaching the gate to forgive it
    // would blind it to the one thing it watches.
    final base = this;
    return RailPlacement(
      rackId: base.rackId,
      ruIndex: base.ruIndex,
      face: base.face,
      startTwelfth: base.startTwelfth,
      spanTwelfths: base.spanTwelfths,
      depthOffsetFromFront: base.depthOffsetFromFront,
      chassisRotation: base.chassisRotation,
      locked: locked,
      unknown: base.unknown,
    );
  }
}

/// Hosted on top of another device (e.g. a component sitting on a shelf).
/// Containment points child -> parent only; the parent never owns a list
/// (CR-029).
final class ShelfPlacement extends Placement {
  const ShelfPlacement({
    required this.hostDeviceId,
    required this.order,
    this.lateralOffset,
    this.locked = false,
    super.unknown,
  });

  final Uuid hostDeviceId;

  /// Auto-packs left to right in v1 (AC-043).
  final FracIndex order;
  final Len? lateralOffset;
  final bool locked;

  /// This placement with [locked] set (DR-186). See
  /// [RailPlacement.withLocked].
  ShelfPlacement withLocked({required bool locked}) => ShelfPlacement(
    hostDeviceId: hostDeviceId,
    order: order,
    lateralOffset: lateralOffset,
    locked: locked,
    unknown: unknown,
  );
}

/// Mounted in a rack's 0U vertical channel (a cable-management rail),
/// inspector-edited only in v1 (AC-044).
final class ZeroUPlacement extends Placement {
  const ZeroUPlacement({
    required this.rackId,
    required this.channelId,
    required this.offsetFromChannelStart,
    required this.orientation,
    this.spanAlongChannel,
    this.locked = false,
    super.unknown,
  });

  final Uuid rackId;
  final String channelId;
  final Len offsetFromChannelStart;

  /// How far this occupant runs ALONG its channel, or **null when the
  /// file does not say** (`#883`, DR-166 §11.165.1).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE FIELD AC-044 HAS NAMED SINCE THE CRITIQUE AND NOBODY BUILT
  /// ═══════════════════════════════════════════════════════════════════
  /// That ruling puts *"channel, start U, span"* in the v1 inspector and
  /// *"renders as a plain bar"* in the v1 elevation, and neither could be
  /// finished without this: `TemplateBody` has `bodyDepth`,
  /// `chassisWidth` and `frontU`/`rearU`, both **0** for a 0U body, and
  /// no physical length anywhere. `zero_u_commands.dart` recorded the gap
  /// the day those commands were written and said closing it was a ruling
  /// rather than a code review.
  ///
  /// **A `Len`, NOT A COUNT OF U**, on [offsetFromChannelStart]'s
  /// precedent and CR-001's: the field beside it is a `Len`, the
  /// channel's own length is computed as one, and a vertical PDU is not a
  /// whole number of rack units long. The inspector edits it in U,
  /// because the channel's bounds and the start are in U, and the two
  /// converters that already do that arithmetic do it in one place.
  ///
  /// **NULL IS UNKNOWN AND NOT ZERO (G4, CR-114).** Every document that
  /// existed before `#883` is in this state, so it is the common case
  /// rather than an edge: it serializes as an ABSENT key, never an
  /// explicit null, and the elevation draws such an occupant as a one-U
  /// stub carrying the unknown marker rather than a bar whose length
  /// nothing in the file supports.
  final Len? spanAlongChannel;
  final ZeroUOrientation orientation;
  final bool locked;

  /// This placement with [locked] set (DR-186). See
  /// [RailPlacement.withLocked].
  ZeroUPlacement withLocked({required bool locked}) => ZeroUPlacement(
    rackId: rackId,
    channelId: channelId,
    offsetFromChannelStart: offsetFromChannelStart,
    orientation: orientation,
    spanAlongChannel: spanAlongChannel,
    locked: locked,
    unknown: unknown,
  );
}

/// Not in any rack — a wall-mounted speaker, an off-rack passive splitter,
/// a hardwired device.
final class OffRackPlacement extends Placement {
  const OffRackPlacement({
    this.locationId,
    this.mountNote,
    this.planPin,
    super.unknown,
  });

  final Uuid? locationId;

  /// Where this device sits on a floorplan (docs/15 §3.4, DR-037).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A FIELD HERE, NOT A SIXTH `Placement` VARIANT
  /// ═══════════════════════════════════════════════════════════════════
  /// The sealed union's five members are MUTUALLY EXCLUSIVE ways a device
  /// is mounted (CR-032, docs/02 §4.3), and "pinned on a plan" is not one
  /// of them: a wall speaker with a pin is still off-rack in a room. A
  /// sixth variant would make the two states unrepresentable together and
  /// force every exhaustive switch in the tree to answer a question about
  /// mounting that this is not.
  ///
  /// **[locationId] remains the schedule's source of room truth and a pin
  /// never replaces it.** A plan says WHERE on a page; a location says
  /// which room, and the schedule prints the room.
  final PlanPin? planPin;

  /// Free prose about where the device physically sits when it is not in
  /// a rack: *"AV closet, top shelf"*, *"Ceiling mount, rear of room"*.
  ///
  /// **THIS HAD NO PRODUCER UNTIL DR-130** (`#839`). It was modelled,
  /// serialized, round-tripped and seeded by the starter generator, and
  /// nothing a person could reach ever wrote one, which is why DR-125
  /// priced the cabinet head end against a fallback that did not exist.
  /// `SetMountNoteCommand` is the writer.
  final String? mountNote;

  /// A copy with a different [mountNote], on `Finding.withSeverity`'s
  /// precedent (DR-128).
  ///
  /// THE VALUE IS ONE SITE RATHER THAN A COMPILE ERROR, and the
  /// difference matters: a field added to this class with a default is
  /// NOT a compile error at a longhand rebuild, it is a silent drop, and
  /// that is exactly how `evaluateDocument` lost `Finding.remedy` twice
  /// in one file. What this buys is that there is only one place to
  /// remember, not that the compiler will remember for you.
  OffRackPlacement withMountNote(String? note) => OffRackPlacement(
    locationId: locationId,
    mountNote: note,
    planPin: planPin,
    unknown: unknown,
  );

  /// A copy with a different [planPin], on [withMountNote]'s precedent.
  ///
  /// Placement variants keep all-`final` fields, so setting a pin
  /// REPLACES the placement object rather than mutating it, per this
  /// file's own header. Passing `null` clears the pin, which is what
  /// un-pinning a device is.
  OffRackPlacement withPlanPin(PlanPin? pin) => OffRackPlacement(
    locationId: locationId,
    mountNote: mountNote,
    planPin: pin,
    unknown: unknown,
  );
}

/// The device has not been placed anywhere yet — this variant *is* the
/// Staging Bin; there is no separate unplaced-devices entity (CR-032).
final class StagedPlacement extends Placement {
  const StagedPlacement({
    this.lastRackId,
    this.lastRuIndex,
    this.lastFace,
    this.schematicHint,
    super.unknown,
  });

  final Uuid? lastRackId;
  final int? lastRuIndex;
  final Face? lastFace;

  /// Consumed ONCE, when the first `SheetItem` is created for this device
  /// (CR-069); not touched again after that.
  final Pt? schematicHint;
}

/// Whether [placement] is locked, or null when it is a placement a lock
/// means nothing for (DR-186 §11.185.1).
///
/// Off-rack and staged devices have no position in a rack to hold, so
/// they answer null rather than false: a `Ctrl+L` over a selection holding
/// one of them leaves it alone rather than reporting it unlocked.
bool? placementLocked(Placement placement) => switch (placement) {
  RailPlacement(:final locked) => locked,
  ShelfPlacement(:final locked) => locked,
  ZeroUPlacement(:final locked) => locked,
  OffRackPlacement() || StagedPlacement() => null,
};

/// [placement] with its lock set, or null when a lock means nothing for
/// it. See [placementLocked].
Placement? placementWithLocked(Placement placement, {required bool locked}) =>
    switch (placement) {
      final RailPlacement p => p.withLocked(locked: locked),
      final ShelfPlacement p => p.withLocked(locked: locked),
      final ZeroUPlacement p => p.withLocked(locked: locked),
      OffRackPlacement() || StagedPlacement() => null,
    };
