import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/pt.dart';

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
  const Placement();
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
  const OffRackPlacement({this.locationId, this.mountNote});

  final Uuid? locationId;
  final String? mountNote;
}

/// The device has not been placed anywhere yet — this variant *is* the
/// Staging Bin; there is no separate unplaced-devices entity (CR-032).
final class StagedPlacement extends Placement {
  const StagedPlacement({
    this.lastRackId,
    this.lastRuIndex,
    this.lastFace,
    this.schematicHint,
  });

  final Uuid? lastRackId;
  final int? lastRuIndex;
  final Face? lastFace;

  /// Consumed ONCE, when the first `SheetItem` is created for this device
  /// (CR-069); not touched again after that.
  final Pt? schematicHint;
}
