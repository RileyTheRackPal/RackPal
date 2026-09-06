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
}

/// Mounted in a rack's 0U vertical channel (a cable-management rail),
/// inspector-edited only in v1 (AC-044).
final class ZeroUPlacement extends Placement {
  const ZeroUPlacement({
    required this.rackId,
    required this.channelId,
    required this.offsetFromChannelStart,
    required this.orientation,
    this.locked = false,
    super.unknown,
  });

  final Uuid rackId;
  final String channelId;
  final Len offsetFromChannelStart;
  final ZeroUOrientation orientation;
  final bool locked;
}

/// Not in any rack — a wall-mounted speaker, an off-rack passive splitter,
/// a hardwired device.
final class OffRackPlacement extends Placement {
  const OffRackPlacement({this.locationId, this.mountNote, super.unknown});

  final Uuid? locationId;

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
