// docs/04-rack-editor.md §4.1 — "Changing height, and the shrink-below-
// occupancy case", the PLANNING half. Same discipline as compaction.dart:
// this file computes what a shrink would cost and what could rescue it,
// and mutates nothing. The modal renders the plan; only Apply turns it
// into commands.
//
// THE GOVERNING PRINCIPLE, quoted because every decision below follows
// from it: "never destroy, never silently move, always name the
// casualties." Consequently NOTHING in this file removes a device, and
// every occupant that would lose its home is returned by name, with its U
// range and its link count (rule 4), for the caller to display.
//
// "ALWAYS NAME THE CASUALTIES" IS NOT "NAME THE ONES THE OCCUPANCY SCAN
// HAPPENS TO SEE" (see [DoomedKind]). `railOccupantsOnFace` deliberately
// returns only rail-placed devices whose template snapshot resolves and
// whose per-face height is > 0 — correct for the placement/collision
// callers it was factored out of, and WRONG as the sole input to a
// planner that decides whether a device is about to be left standing
// outside the rack. A device the scan skips would otherwise be invisible
// three times over: absent from [RackShrinkPlan.doomed], uncounted by
// [RackShrinkPlan.smallestFittingHeightU], and — because
// [RackShrinkPlan.hasCasualties] is what opens the modal at all — the
// reason the shrink applies with NO modal, stranding it silently. So this
// planner enumerates EVERY device the document binds to this rack and
// gives the ones the scan cannot model a deliberately conservative
// footprint, which can cost the user a smaller shrink than they hoped for
// but can never cost them a device.
//
// TRIM DIRECTION IS NOT COSMETIC (rule 5). "Trim from: Bottom shifts every
// occupant's ruIndex DOWN by the removed count", which produces a
// COMPLETELY DIFFERENT casualty set from a top trim — the devices near U1
// rather than the devices near the top. §4.1's own mockup shows one static
// list beside the radio; that is a spec simplification, and this planner
// is recomputed per direction instead.
import 'package:rackmate_core/src/commands/catalog_placement.dart';
import 'package:rackmate_core/src/commands/compaction.dart';
import 'package:rackmate_core/src/commands/device_commands.dart';
import 'package:rackmate_core/src/commands/link_count.dart';
import 'package:rackmate_core/src/model/device_instance.dart';
import 'package:rackmate_core/src/model/placement.dart';
import 'package:rackmate_core/src/model/rack.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/zero_u_channel.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Which end of the rack the removed U come off (docs/04 §4.1's "Trim
/// from: (o) Top ( ) Bottom" radio).
enum TrimFrom {
  /// The default. `heightU` drops; every `ruIndex` is untouched; occupants
  /// whose top U now exceeds the rack are the casualties.
  top,

  /// Rule 5: every occupant's `ruIndex` shifts DOWN by the removed count.
  /// Occupants that would land below U1 are the casualties.
  bottom,
}

/// How much to trust a [DoomedOccupant]'s `ruIndex`/`deviceH`, and why the
/// occupant is in the list at all.
///
/// Only [rail] occupants have an exactly known footprint. The other two
/// exist because the shrink planner refuses to let an occupant it cannot
/// model be silently skipped: it substitutes the most conservative
/// footprint it can defend and lets the occupant appear as a casualty,
/// which is strictly better than the alternative of shrinking the rack out
/// from under a device nobody was told about.
enum DoomedKind {
  /// Rail-mounted with a resolved template snapshot: `ruIndex` and
  /// `deviceH` are the exact footprint, and compaction can relocate it.
  rail,

  /// Rail-placed in this rack, but [railOccupantsOnFace] cannot resolve a
  /// footprint for it — its `templates['<id>@<version>']` snapshot is
  /// missing, or the snapshot gives it zero height on the face it claims
  /// to be mounted on. `ruIndex` is real; `deviceH` is reported as 1, the
  /// LEAST it can possibly occupy, because nothing in the document says
  /// how tall it is. Compaction never moves it (planning a relocation
  /// needs a height), but a bottom trim still renumbers it along with
  /// everyone else, since `MoveDeviceCommand` only needs the two RU
  /// indices.
  unmodelledRail,

  /// Mounted in one of this rack's 0U vertical channels. It has no
  /// `ruIndex` of its own, so the U range reported is its CHANNEL's span —
  /// the range that must survive for the device to still have a home. A
  /// channel whose `channelId` resolves to nothing in the rack is reported
  /// as spanning the whole rack, which makes any shrink name it rather
  /// than guess.
  ///
  /// IMMOVABLE IN BOTH SENSES: no command in this system renumbers a
  /// `ZeroUChannel` (see `Rack.zeroUChannels`' own access-control note), so
  /// a 0U occupant can be neither compacted nor shifted. That is why a
  /// bottom trim of any size strands one — see [_diesUnderPlainTrim].
  zeroU,
}

/// One occupant a shrink would leave without a home — never deleted, only
/// named (rule 3: "DELETION IS NOT OFFERED").
final class DoomedOccupant {
  const DoomedOccupant({
    required this.deviceId,
    required this.designator,
    required this.name,
    required this.ruIndex,
    required this.deviceH,
    required this.face,
    required this.linkCount,
    this.kind = DoomedKind.rail,
  });

  final Uuid deviceId;
  final String designator;

  /// §4.1's "description" column.
  final String name;
  final int ruIndex;
  final int deviceH;
  final Face face;

  /// Rule 4's cost signal. See `linkCountForDevice`.
  final int linkCount;

  /// What [ruIndex]/[deviceH] actually mean for this occupant.
  final DoomedKind kind;

  /// The highest U this occupant currently holds.
  int get topRu => ruIndex + deviceH - 1;

  @override
  String toString() =>
      'DoomedOccupant($designator U$ruIndex-U$topRu ${face.name}, '
      '$linkCount link(s)${kind == DoomedKind.rail ? '' : ', ${kind.name}'})';
}

/// What "Compact first, then shrink" would actually buy — §4.1 option 1.
/// Only ever non-null when compaction rescues at least one casualty AND
/// leaves the rack able to shrink at all, since rule 1 says the option
/// "appears ONLY when compaction actually helps".
final class CompactionRescue {
  const CompactionRescue({
    required this.moves,
    required this.rescued,
    required this.stillDoomed,
    required this.freedU,
    required this.achievableHeightU,
  });

  /// The NET relocation of each affected device: for [TrimFrom.top] this
  /// is the compaction alone; for [TrimFrom.bottom] it is the compaction
  /// COMPOSED WITH the uniform downward shift, collapsed into one move per
  /// device. Deliberately not two hops — a device should appear once in
  /// the preview and once in the undo entry, at its final home.
  final List<CompactionMove> moves;

  /// Casualties compaction saves. Never empty (see the class doc).
  final List<DoomedOccupant> rescued;

  /// Casualties compaction cannot save at the requested height.
  final List<DoomedOccupant> stillDoomed;

  /// §4.1's "Removes 6U of gaps." — the CONTIGUOUS run of U the compaction
  /// hands back at the end being trimmed, across BOTH faces at once.
  ///
  /// EXPLICITLY NOT THE SUM OF THE PER-FACE [CompactionPlan.freedU]s.
  /// That field is itself a contiguous run at one end of one face, which
  /// is not an additive quantity: a rack whose front frees 3U and whose
  /// rear frees 3U has NOT gained 6U of anything, because the rack top can
  /// only come down as far as the taller of the two faces still reaches.
  /// Summing them reports an impossible number — up to 10U of gaps removed
  /// from a 12U rack — on the one tile whose entire job is to state the
  /// true cost before Apply.
  ///
  /// The cross-face combination is the drop in the rack's own lossless
  /// floor, and it is computed by the SAME function that produces
  /// [RackShrinkPlan.smallestFittingHeightU] and [achievableHeightU], run
  /// over the pre- and post-compaction positions, so the three numbers on
  /// the modal cannot disagree. Their exact relationship, which
  /// rack_shrink_test.dart asserts over an exhaustive sweep:
  ///
  ///     achievableHeightU ==
  ///         max(plan.toHeightU, plan.smallestFittingHeightU - freedU)
  ///
  /// Floored at 0. That floor is believed unreachable and is kept as
  /// defence, not as a live case: compaction can only worsen the rack's
  /// floor on a document whose placements OVERLAP, and the device it
  /// pushes past the old extremum thereby becomes the new extremum — so
  /// it is doomed both before and after, while every occupant that could
  /// have been rescued sits below the old extremum and is therefore not
  /// doomed at any height where a rescue exists. `rescued` comes back
  /// empty and there is no `CompactionRescue` to put a number on. The
  /// clamp survives because "Removes -2U of gaps" is not a sentence a
  /// modal may print, and that argument rests on `_lowestFit`/`_highestFit`
  /// details this class does not own.
  final int freedU;

  /// The smallest height the compacted layout actually permits WITHOUT
  /// losing anyone. Equals the requested height on full success; on
  /// partial success it is larger, and it is what makes option 1 remain
  /// lossless and therefore honestly selectable (rule 1) even though the
  /// Staging Bin the spec's partial label assumes does not exist.
  final int achievableHeightU;

  /// Rule 2's preselection test.
  bool get isFull => stillDoomed.isEmpty;
}

/// The full answer to "the user asked for [toHeightU]; what happens?"
final class RackShrinkPlan {
  const RackShrinkPlan({
    required this.rackId,
    required this.fromHeightU,
    required this.toHeightU,
    required this.trimFrom,
    required this.doomed,
    required this.shiftMoves,
    required this.rescue,
    required this.smallestFittingHeightU,
    required this.hasUnmodelledOccupants,
  });

  final Uuid rackId;
  final int fromHeightU;
  final int toHeightU;
  final TrimFrom trimFrom;

  /// How many U come off. Zero or negative for a grow — see [isShrink].
  int get removedU => fromHeightU - toHeightU;

  /// Occupants lost if the shrink is applied AS ASKED, with no rescue.
  /// Empty means the height change is safe and needs no modal at all.
  final List<DoomedOccupant> doomed;

  /// The displacement [TrimFrom.bottom] requires of every SURVIVING
  /// occupant (rule 5). Always empty for [TrimFrom.top], where "growing is
  /// always safe... existing ruIndex values are untouched" generalises: a
  /// top trim never renumbers anyone.
  final List<CompactionMove> shiftMoves;

  /// §4.1 option 1, or null when compaction would not help (rule 1).
  final CompactionRescue? rescue;

  /// §4.1 option 3, "Keep rack at 18U (smallest that fits)". Always
  /// available, always lossless — computed WITHOUT compaction, so it is
  /// the plain "don't move anything" floor.
  final int smallestFittingHeightU;

  /// Whether this rack holds at least one occupant whose footprint the
  /// rail occupancy scan cannot resolve — a 0U-channel device, or a rail
  /// device with a dangling template reference (see [DoomedKind]).
  ///
  /// Such an occupant is NOT skipped; it is planned with a conservative
  /// footprint and appears in [doomed] like any other casualty. This flag
  /// exists so a caller can say so out loud — the U range shown for those
  /// occupants is a defensible bound rather than a measurement, and a rack
  /// that reports true here may refuse a shrink that "looks" safe on the
  /// elevation, because the offending device is one `scene_builder` also
  /// declines to draw.
  final bool hasUnmodelledOccupants;

  /// Whether this is a shrink at all. Growing is always safe (§4.1) and
  /// yields an empty [doomed].
  bool get isShrink => toHeightU < fromHeightU;

  /// The modal only opens when this is true.
  bool get hasCasualties => doomed.isNotEmpty;
}

/// Every device the document binds to this rack, with the footprint the
/// planner will reason about. See [DoomedKind] for the three cases and
/// why none of them may be dropped.
///
/// `modelled` occupants participate in compaction (they are exactly the
/// ones `planCompaction` will see when it runs its own scan); `shiftable`
/// ones can be renumbered by a `MoveDeviceCommand`.
///
/// DEVICES ON A SHELF ARE DELIBERATELY ABSENT. A `ShelfPlacement` child
/// holds no rack U of its own — it rides its host, whose own rail
/// placement IS enumerated here. If the host is doomed the host is named,
/// and since rule 3 never deletes the host, the child never loses its
/// home independently. There is no invisible casualty to find.
typedef _Occupant = ({
  DeviceInstance device,
  int ruIndex,
  int deviceH,
  Face face,
  DoomedKind kind,
});

bool _modelled(_Occupant o) => o.kind == DoomedKind.rail;
bool _shiftable(_Occupant o) => o.kind != DoomedKind.zeroU;

/// Plans the height change of [rackId] to [toHeightU] under [trimFrom].
///
/// Reads the whole document because rule 4's link counts need `ports` and
/// `links`, not just the rack. Mutates nothing. Safe to call on every tick
/// of a drag or a held stepper — it is a pure read.
///
/// A GROW, or a shrink that loses nobody, still returns a plan; its
/// [RackShrinkPlan.doomed] is simply empty and the caller runs the plain
/// `SetRackHeightCommand` without opening anything.
RackShrinkPlan planRackShrink({
  required RackDocument doc,
  required Uuid rackId,
  required int toHeightU,
  TrimFrom trimFrom = TrimFrom.top,
}) {
  final rack = doc.racks[rackId];
  if (rack == null) {
    throw ArgumentError.value(rackId, 'rackId', 'no such rack in document');
  }
  final fromHeightU = rack.heightU;
  final removed = fromHeightU - toHeightU;

  final occupants = _rackOccupants(doc, rack);

  final doomed = <DoomedOccupant>[];
  final shiftMoves = <CompactionMove>[];
  for (final o in occupants) {
    if (_diesUnderPlainTrim(o, trimFrom, toHeightU, removed)) {
      doomed.add(_doom(doc, o));
    } else if (trimFrom == TrimFrom.bottom && removed > 0) {
      // Survivors of a bottom trim all renumber. A non-shiftable occupant
      // can never reach here: [_diesUnderPlainTrim] dooms it outright for
      // any `removed > 0`, precisely because there is no command that
      // would carry it down with everyone else.
      assert(_shiftable(o), 'a non-shiftable survivor cannot be renumbered');
      shiftMoves.add(
        CompactionMove(
          deviceId: o.device.id,
          designator: o.device.designator,
          fromRuIndex: o.ruIndex,
          toRuIndex: o.ruIndex - removed,
          deviceH: o.deviceH,
          face: o.face,
        ),
      );
    }
  }

  return RackShrinkPlan(
    rackId: rackId,
    fromHeightU: fromHeightU,
    toHeightU: toHeightU,
    trimFrom: trimFrom,
    doomed: List.unmodifiable(doomed),
    shiftMoves: List.unmodifiable(shiftMoves),
    rescue: doomed.isEmpty
        ? null
        : _planRescue(
            doc: doc,
            rack: rack,
            occupants: occupants,
            doomed: doomed,
            toHeightU: toHeightU,
            trimFrom: trimFrom,
          ),
    smallestFittingHeightU: _losslessFloor(
      occupants: occupants,
      ruOf: (o) => o.ruIndex,
      fromHeightU: fromHeightU,
      trimFrom: trimFrom,
    ),
    hasUnmodelledOccupants: occupants.any((o) => !_modelled(o)),
  );
}

/// THE occupant enumeration for shrink planning — see [_Occupant].
///
/// Ordered face-major (front, then rear), ascending by `ruIndex`, ties
/// broken by device id, so `doomed` and `shiftMoves` are reproducible
/// across runs and do not depend on `Map` iteration order.
List<_Occupant> _rackOccupants(RackDocument doc, Rack rack) {
  final out = <_Occupant>[];
  final modelled = <Uuid>{};
  for (final face in Face.values) {
    for (final o in railOccupantsOnFace(
      rack: rack,
      devices: doc.devices.values,
      face: face,
      templates: doc.templates,
    )) {
      modelled.add(o.device.id);
      out.add((
        device: o.device,
        ruIndex: o.ruIndex,
        deviceH: o.deviceH,
        face: face,
        kind: DoomedKind.rail,
      ));
    }
  }

  for (final d in doc.devices.values) {
    if (modelled.contains(d.id)) continue;
    switch (d.placement) {
      // Rail-placed here, yet the scan did not return it on either face:
      // its template snapshot is missing, or it resolves to zero height on
      // the face it claims. Its RU index is real; its height is not
      // knowable, so claim the least it can possibly occupy.
      case RailPlacement(:final rackId, :final ruIndex, :final face)
          when rackId == rack.id:
        out.add((
          device: d,
          ruIndex: ruIndex,
          deviceH: 1,
          face: face,
          kind: DoomedKind.unmodelledRail,
        ));
      case ZeroUPlacement(:final rackId, :final channelId)
          when rackId == rack.id:
        final channel = _channelById(rack, channelId);
        out.add((
          device: d,
          ruIndex: channel == null ? 1 : _channelBottom(channel),
          deviceH: channel == null
              ? rack.heightU
              : _channelTop(channel) - _channelBottom(channel) + 1,
          face: channel == null
              ? Face.front
              : _faceOfChannelSide(channel.side),
          kind: DoomedKind.zeroU,
        ));
      case _:
        break;
    }
  }

  out.sort((a, b) {
    final byFace = a.face.index.compareTo(b.face.index);
    if (byFace != 0) return byFace;
    final byRu = a.ruIndex.compareTo(b.ruIndex);
    return byRu != 0 ? byRu : a.device.id.v.compareTo(b.device.id.v);
  });
  return out;
}

ZeroUChannel? _channelById(Rack rack, String channelId) {
  for (final c in rack.zeroUChannels) {
    if (c.id == channelId) return c;
  }
  return null;
}

// Normalised, because `startU`/`endU` are plain mutable ints on a decoded
// sub-object with no validation behind them (json_codec's `_decodeRack` is
// explicitly the non-validating path). An inverted or sub-1 channel is
// read as the range it spans, not trusted to be well ordered.
int _channelBottom(ZeroUChannel c) =>
    _atLeastOne(c.startU < c.endU ? c.startU : c.endU);
int _channelTop(ZeroUChannel c) =>
    _atLeastOne(c.startU > c.endU ? c.startU : c.endU);

Face _faceOfChannelSide(ZeroUChannelSide side) => switch (side) {
  ZeroUChannelSide.frontLeft || ZeroUChannelSide.frontRight => Face.front,
  ZeroUChannelSide.rearLeft || ZeroUChannelSide.rearRight => Face.rear,
};

/// Whether [o] loses its home under a plain (no-compaction) trim.
bool _diesUnderPlainTrim(
  _Occupant o,
  TrimFrom trimFrom,
  int toHeightU,
  int removed,
) => switch (trimFrom) {
  // The rack top comes down onto it.
  TrimFrom.top => o.ruIndex + o.deviceH - 1 > toHeightU,
  // The floor comes up under it. `removed <= 0` is a grow, which shifts
  // nobody and kills nobody. A non-shiftable occupant (a 0U channel
  // device) dies for ANY removal: a bottom trim renumbers every surviving
  // occupant down, and there is no command that renumbers a
  // `ZeroUChannel`, so leaving it addressed to a U range the rack no
  // longer numbers the same way is exactly the silent stranding this
  // planner exists to prevent.
  TrimFrom.bottom =>
    removed > 0 && (!_shiftable(o) || o.ruIndex - removed < 1),
};

DoomedOccupant _doom(RackDocument doc, _Occupant o) => DoomedOccupant(
  deviceId: o.device.id,
  designator: o.device.designator,
  name: o.device.name,
  ruIndex: o.ruIndex,
  deviceH: o.deviceH,
  face: o.face,
  linkCount: linkCountForDevice(doc, o.device.id),
  kind: o.kind,
);

/// The smallest height that loses NOBODY, given each occupant's position
/// as reported by [ruOf].
///
/// ONE function for three numbers on purpose. Called with the current
/// positions it is §4.1 option 3 ([RackShrinkPlan.smallestFittingHeightU]);
/// called with post-compaction positions it is
/// [CompactionRescue.achievableHeightU]; the difference between those two
/// calls is [CompactionRescue.freedU]. Computing them separately is what
/// let "Removes 10U of gaps" and "reaches 5U" appear on the same tile of
/// the same modal.
///
/// Top trim: the highest occupied U, floored at 1 (an empty rack can
/// shrink all the way to 1U). Bottom trim: the mirror — the floor may rise
/// at most to just below the LOWEST occupant, so `fromHeightU - (minRu -
/// 1)` — except that a non-shiftable occupant pins that floor at U1,
/// because no U can come off the bottom while it is there at all.
int _losslessFloor({
  required List<_Occupant> occupants,
  required int Function(_Occupant) ruOf,
  required int fromHeightU,
  required TrimFrom trimFrom,
}) {
  if (occupants.isEmpty) return 1; // no occupants at all
  var highestTop = 0;
  var lowestBottom = 1 << 30;
  for (final o in occupants) {
    final ru = ruOf(o);
    final top = ru + o.deviceH - 1;
    if (top > highestTop) highestTop = top;
    final bottom = _shiftable(o) ? ru : 1;
    if (bottom < lowestBottom) lowestBottom = bottom;
  }
  return switch (trimFrom) {
    TrimFrom.top => _atLeastOne(highestTop),
    TrimFrom.bottom => _atLeastOne(fromHeightU - (lowestBottom - 1)),
  };
}

int _atLeastOne(int v) => v < 1 ? 1 : v;

/// §4.1 option 1. Compacts TOWARD THE END BEING KEPT — down for a top
/// trim (free U accumulates at the top, which is what a top trim consumes),
/// up for a bottom trim — on BOTH faces, then re-derives who is still
/// doomed.
///
/// Returns null when compaction rescues nobody, or when the height it can
/// reach is the height the rack already has, so rule 1's "appears ONLY
/// when compaction actually helps" is enforced by the planner rather than
/// left to the modal to remember. The second case is not hypothetical: a
/// LOCKED device at the rack top, or a 0U channel under a bottom trim,
/// pins the floor at the current height, and "Compact first, then shrink
/// to 24U" on a 24U rack is an option that does nothing while claiming to.
CompactionRescue? _planRescue({
  required RackDocument doc,
  required Rack rack,
  required List<_Occupant> occupants,
  required List<DoomedOccupant> doomed,
  required int toHeightU,
  required TrimFrom trimFrom,
}) {
  final direction = trimFrom == TrimFrom.top
      ? CompactDirection.down
      : CompactDirection.up;

  // Planned against the rack's REAL height, deliberately — see
  // planCompaction's doc comment. Packing against the target height
  // instead would strand any device too tall to fit under it, which is
  // exactly the device whose compacted position determines
  // [CompactionRescue.achievableHeightU].
  final plans = <Face, CompactionPlan>{
    for (final face in Face.values)
      face: planCompaction(
        rack: rack,
        devices: doc.devices.values,
        face: face,
        templates: doc.templates,
        direction: direction,
      ),
  };

  // Post-compaction ruIndex for every occupant. Occupants compaction
  // cannot see stay exactly where they are, which is the truth: nothing
  // moved them.
  final postRu = <Uuid, int>{for (final o in occupants) o.device.id: o.ruIndex};
  for (final face in Face.values) {
    for (final m in plans[face]!.moves) {
      postRu[m.deviceId] = m.toRuIndex;
    }
  }

  final byId = <Uuid, _Occupant>{for (final o in occupants) o.device.id: o};
  final removed = rack.heightU - toHeightU;
  final stillDoomed = <DoomedOccupant>[];
  final rescued = <DoomedOccupant>[];
  for (final d in doomed) {
    final o = byId[d.deviceId]!;
    final post = (
      device: o.device,
      ruIndex: postRu[d.deviceId]!,
      deviceH: o.deviceH,
      face: o.face,
      kind: o.kind,
    );
    final dies = _diesUnderPlainTrim(post, trimFrom, toHeightU, removed);
    (dies ? stillDoomed : rescued).add(d);
  }
  if (rescued.isEmpty) return null;

  // On full success the rack really does reach the requested height. On
  // partial success option 1 composes with option 3 and stops at the
  // smallest height the compacted layout permits — so NOBODY is displaced
  // out of the rack under either outcome, and [stillDoomed] names the
  // occupants that are the REASON the requested height is unreachable
  // rather than occupants about to be dropped.
  final preFloor = _losslessFloor(
    occupants: occupants,
    ruOf: (o) => o.ruIndex,
    fromHeightU: rack.heightU,
    trimFrom: trimFrom,
  );
  final postFloor = _losslessFloor(
    occupants: occupants,
    ruOf: (o) => postRu[o.device.id]!,
    fromHeightU: rack.heightU,
    trimFrom: trimFrom,
  );
  final achievable = stillDoomed.isEmpty ? toHeightU : postFloor;
  if (achievable >= rack.heightU) return null;

  // The net move list: compaction target, then the bottom-trim shift —
  // sized to the height actually applied, not the height requested.
  final shift = trimFrom == TrimFrom.bottom ? rack.heightU - achievable : 0;
  final moves = <CompactionMove>[];
  for (final o in occupants) {
    if (!_shiftable(o)) {
      // CURRENTLY UNREACHABLE WITH `shift != 0`, and the assert is the
      // proof rather than a hope: the only non-shiftable occupant is a 0U
      // one, a 0U occupant is doomed by EVERY bottom trim and can never be
      // rescued, so `stillDoomed` is non-empty and `achievable` is
      // `postFloor` — which the U1 floor pin in [_losslessFloor] makes
      // equal to `rack.heightU`, so the guard above has already returned
      // null. The skip stays anyway: `MoveDeviceCommand` throws a
      // StateError on a device that is not rail-placed, so if that chain
      // ever breaks the cost should be a shrink that does less, not an
      // Apply that blows up halfway through a transaction.
      assert(shift == 0, 'a 0U occupant cannot be renumbered');
      continue;
    }
    final to = postRu[o.device.id]! - shift;
    if (to == o.ruIndex) continue;
    moves.add(
      CompactionMove(
        deviceId: o.device.id,
        designator: o.device.designator,
        fromRuIndex: o.ruIndex,
        toRuIndex: to,
        deviceH: o.deviceH,
        face: o.face,
      ),
    );
  }

  final freed = preFloor - postFloor;
  return CompactionRescue(
    moves: List.unmodifiable(moves),
    rescued: List.unmodifiable(rescued),
    stillDoomed: List.unmodifiable(stillDoomed),
    freedU: freed < 0 ? 0 : freed,
    achievableHeightU: achievable,
  );
}

/// The `MoveDeviceCommand`s realising a chosen set of displacements —
/// [RackShrinkPlan.shiftMoves] for a plain bottom trim, or
/// [CompactionRescue.moves] for option 1.
///
/// Rule 6 ("Apply is ONE undo entry covering the resize and every
/// displacement") is the CALLER's composition: put these first and the
/// `SetRackHeightCommand` last in a single `Transaction`, so no
/// intermediate state has an occupant standing above the rack top.
List<MoveDeviceCommand> shrinkDisplacementCommands(
  List<CompactionMove> moves, {
  required DateTime now,
  required String actor,
}) => [
  for (final m in moves)
    MoveDeviceCommand(
      id: m.deviceId,
      fromRuIndex: m.fromRuIndex,
      toRuIndex: m.toRuIndex,
      fromFace: m.face,
      toFace: m.face,
      now: now,
      actor: actor,
    ),
];
