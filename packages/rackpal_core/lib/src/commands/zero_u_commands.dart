// 0U channels, and the occupants that sit in them (`#270`, M5-C, CR-031,
// AC-044).
//
// ═════════════════════════════════════════════════════════════════════
// THE CHAIN `PLC-003` HAS BEEN WAITING ON, ALL OF IT MISSING
// ═════════════════════════════════════════════════════════════════════
// `PLC-003` refuses a `ZeroUPlacement` whose `channelId` does not resolve
// or whose offset falls outside the channel. Nothing could produce either
// state: `Rack.zeroUChannels` had no writer, no rack preset seeded one,
// and no path built a `ZeroUPlacement` outside the codec. A rule needs a
// channel to exist before an occupant can name it, so both halves land
// here.
//
// AC-044 is the scope: *"0U occupants ship in the model and render as
// plain bars, but have no drag gesture in v1. They are created and edited
// from the inspector."* `catalog_placement.dart` already refuses a 0U
// template with a sentence pointing at exactly this path.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT IS NOT HERE, MEASURED RATHER THAN OMITTED
// ═════════════════════════════════════════════════════════════════════
// SPAN. docs/04 §3 and canon §7 both describe the inspector as editing
// *"channel, start U, span"*, and there is nowhere in the model to put
// the third of those: `ZeroUPlacement` carries `channelId`,
// `offsetFromChannelStart` and `orientation`, and the seed catalog's one
// 0U device (`P01`, a vertical PDU) declares `frontU: 0, rearU: 0`. So a
// 0U occupant has a position and no extent anywhere in the format.
//
// That is a model gap and adding a field to close it is a change to
// CR-117's byte surface, which is a ruling and not a code review. It is
// also NOT `PLC-003`'s business: the rule is about the channel resolving
// and the offset landing inside it, and both are writable here. Recorded
// so the next person meets it as a known gap rather than a surprise.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackpal_core/src/derived/placement_rules.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/zero_u_channel.dart';
import 'package:rackpal_core/src/units/constants.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// What a 0U plan decided: a command to run, or a sentence saying why
/// not.
sealed class ZeroUResult {
  const ZeroUResult();
}

final class ZeroUReady extends ZeroUResult {
  const ZeroUReady(this.command);
  final Command<RackDocument> command;
}

final class ZeroURefused extends ZeroUResult {
  const ZeroURefused(this.reason, {this.ruleId});

  /// A complete sentence, on `ConnectRefused`'s contract.
  final String reason;

  /// `"PLC-003"` when a tier-1 rule refused.
  ///
  /// NULL FOR EVERYTHING ELSE HERE, AND MOST OF IT IS EVERYTHING ELSE. A
  /// channel that runs off the top of its rack, an id already in use, a
  /// channel still occupied: none of those is in docs/02 §5's catalogue,
  /// and *"a rule not listed there does not exist"* (CR-021). Giving them
  /// invented ids would put four rules in the product that no fixture
  /// pair covers and no count includes.
  final String? ruleId;
}

// ─────────────────────────────────────────────────────────────────────
// CHANNELS
// ─────────────────────────────────────────────────────────────────────

/// Plans a new 0U channel on [rackId], or refuses it.
///
/// The channel's own bounds are checked HERE and not by a rule, for the
/// reason [ZeroURefused.ruleId] gives: `PLC-003` is about an occupant's
/// offset, and a channel's `startU`/`endU` are covered by no catalogue
/// entry at all.
ZeroUResult planAddZeroUChannel({
  required RackDocument doc,
  required Uuid rackId,
  required String id,
  required ZeroUChannelSide side,
  required int startU,
  required int endU,
  String name = '',
}) {
  final rack = doc.racks[rackId];
  if (rack == null) {
    return const ZeroURefused('That rack is not in this document.');
  }
  if (id.trim().isEmpty) {
    return const ZeroURefused('A 0U channel needs an id.');
  }
  if (_channelById(rack, id) != null) {
    return ZeroURefused(
      '${rack.designator} already has a 0U channel called "$id".',
    );
  }
  if (startU > endU) {
    return ZeroURefused(
      'A 0U channel runs bottom to top, and U $startU is above U $endU.',
    );
  }
  if (startU < 1 || endU > rack.heightU) {
    return ZeroURefused(
      'A 0U channel from U $startU to U $endU does not fit '
      '${rack.designator}, which is ${rack.heightU} U.',
    );
  }
  return ZeroUReady(
    AddZeroUChannelCommand(
      rackId: rackId,
      channel: ZeroUChannel(
        id: id,
        side: side,
        startU: startU,
        endU: endU,
        name: name,
      ),
    ),
  );
}

/// Adds one channel to a rack's list.
final class AddZeroUChannelCommand extends Command<RackDocument> {
  AddZeroUChannelCommand({required this.rackId, required this.channel});

  final Uuid rackId;

  /// HELD, not rebuilt on each apply. A `ZeroUChannel` is a sub-object
  /// with a plain `String` id and no `EntityMeta`, so there is no minted
  /// identity to keep stable and nothing for redo to recreate
  /// differently; the same object going back in is the identical bytes.
  final ZeroUChannel channel;

  @override
  LabelKey get label => LabelKey.addZeroUChannel;

  @override
  EpochMask get touches => EpochMask.rack | EpochMask.structure;

  @override
  Iterable<Uuid> get affects => [rackId];

  @override
  bool apply(RackDocument doc) {
    doc.racks[rackId]?.zeroUChannels.add(channel);
    return true;
  }

  @override
  void revert(RackDocument doc) =>
      doc.racks[rackId]?.zeroUChannels.removeWhere((c) => c.id == channel.id);
}

/// Plans the removal of a 0U channel, or refuses it.
///
/// REFUSES WHILE OCCUPIED, rather than leaving the occupant naming a
/// channel that is gone. `rack_shrink.dart` already tolerates a dangling
/// `channelId` on read, which is the right thing for a file somebody else
/// wrote; it is the wrong thing to CREATE on purpose, because no tier-3
/// rule reports it and the device would sit in the document pointing at
/// nothing with nobody ever told.
ZeroUResult planRemoveZeroUChannel({
  required RackDocument doc,
  required Uuid rackId,
  required String id,
}) {
  final rack = doc.racks[rackId];
  if (rack == null) {
    return const ZeroURefused('That rack is not in this document.');
  }
  final index = rack.zeroUChannels.indexWhere((c) => c.id == id);
  if (index < 0) {
    return ZeroURefused(
      '${rack.designator} has no 0U channel called "$id".',
    );
  }
  final occupants = occupantsOfZeroUChannel(doc, rackId, id);
  if (occupants.isNotEmpty) {
    return ZeroURefused(
      '${occupants.first.designator} is mounted in that channel. Move it '
      'out first.',
    );
  }
  return ZeroUReady(
    RemoveZeroUChannelCommand(
      rackId: rackId,
      channel: rack.zeroUChannels[index],
      index: index,
    ),
  );
}

/// Removes one channel, remembering WHERE it was.
///
/// The index matters: `zeroUChannels` is a `List`, the codec writes it in
/// order, and putting a reverted channel back on the end would leave the
/// document semantically identical and byte-different, which CR-117 does
/// not allow.
final class RemoveZeroUChannelCommand extends Command<RackDocument> {
  RemoveZeroUChannelCommand({
    required this.rackId,
    required this.channel,
    required this.index,
  });

  final Uuid rackId;
  final ZeroUChannel channel;
  final int index;

  @override
  LabelKey get label => LabelKey.removeZeroUChannel;

  @override
  EpochMask get touches => EpochMask.rack | EpochMask.structure;

  @override
  Iterable<Uuid> get affects => [rackId];

  @override
  bool apply(RackDocument doc) {
    doc.racks[rackId]?.zeroUChannels.removeWhere((c) => c.id == channel.id);
    return true;
  }

  @override
  void revert(RackDocument doc) =>
      doc.racks[rackId]?.zeroUChannels.insert(index, channel);
}

// ─────────────────────────────────────────────────────────────────────
// OCCUPANTS
// ─────────────────────────────────────────────────────────────────────

/// The U an occupant sitting at [offsetFromChannelStart] starts on.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE ARITHMETIC LIVES HERE BECAUSE THE INCLUSIVE SPAN DOES (`#876`)
/// ═══════════════════════════════════════════════════════════════════════
/// A channel's bounds are 1-based and INCLUSIVE (CR-025, and
/// `placement_rules.dart`: *"from U 1 to U 42 is 42 U of rail, not 41"*),
/// and an occupant's offset is a `Len` from the channel's start. AC-044
/// says the inspector asks for a **start U**, so something has to convert,
/// and a widget doing it would be a second place that has to know the span
/// is inclusive.
///
/// The pair is exact: `zeroUStartUOf(c, zeroUOffsetFor(c, u)) == u` for
/// every U in the channel, because `kRackUnit` is an integer number of
/// nanometres and the division truncates a value the other half built.
int zeroUStartUOf(ZeroUChannel channel, Len offsetFromChannelStart) =>
    channel.startU + offsetFromChannelStart.nm ~/ kRackUnit.nm;

/// The offset that puts an occupant at [startU] in [channel].
///
/// **NOT CLAMPED.** An out-of-range U produces an out-of-range offset and
/// `planSetZeroUPosition` refuses it through `evaluatePlacement`, with
/// `PLC-003`'s own sentence naming the channel and its length. Clamping
/// here would silently move a device somewhere the person did not ask for,
/// which is docs/04 §3.4's "never silently do nothing" read from the other
/// side.
Len zeroUOffsetFor(ZeroUChannel channel, int startU) =>
    kRackUnit * (startU - channel.startU);

/// Plans a move of [id] along its channel, or into another one.
///
/// THIS IS WHERE `PLC-003` ACTUALLY FIRES. Creating a 0U occupant goes
/// through `catalog_placement.dart`, which resolves a template and
/// allocates a designator; this is the edit half AC-044 asks for, and it
/// is the one a person repeats.
ZeroUResult planSetZeroUPosition({
  required RackDocument doc,
  required Uuid id,
  required String channelId,
  required Len offsetFromChannelStart,
  required DateTime now,
  required String actor,
}) {
  final device = doc.devices[id];
  if (device == null) {
    return const ZeroURefused('That device is not in this document.');
  }
  final placement = device.placement;
  if (placement is! ZeroUPlacement) {
    return ZeroURefused(
      '${device.designator} is not mounted in a 0U channel.',
    );
  }
  final moved = ZeroUPlacement(
    rackId: placement.rackId,
    channelId: channelId,
    offsetFromChannelStart: offsetFromChannelStart,
    // CARRIED, AND THIS LINE IS WHY `#883` READ THIS FUNCTION FIRST. A
    // rebuilt placement that omits a field ERASES it, silently and on
    // every move, and the span is the one field here a person cannot see
    // being lost: the bar would simply go back to a one-U stub the next
    // time somebody retyped a start U.
    spanAlongChannel: placement.spanAlongChannel,
    orientation: placement.orientation,
    locked: placement.locked,
  );
  final verdict = evaluatePlacement(
    doc: doc,
    placement: moved,
    body: bodyFor(device, doc.templates),
    designator: device.designator,
  );
  if (verdict is PlacementRefused) {
    return ZeroURefused(verdict.message, ruleId: verdict.ruleId);
  }
  return ZeroUReady(
    SetZeroUPositionCommand(
      id: id,
      from: placement,
      to: moved,
      now: now,
      actor: actor,
    ),
  );
}

/// Plans a change to how far [id] runs along its channel (`#883`,
/// DR-166 §11.165.1).
///
/// **AC-044's THIRD FIELD**, and the one `#876` could not build: that
/// ruling has the inspector editing *"channel, start U, span"* and the
/// model had nowhere to put the third of them.
///
/// **NULL CLEARS IT BACK TO UNKNOWN**, which is a real edit and not a
/// no-op: a person who does not know how long a PDU is should be able to
/// say so, and G4's whole argument is that "not recorded" must be
/// expressible. The elevation then draws the stub again.
///
/// `PLC-003` decides whether the span fits, from `evaluatePlacement`, and
/// it is the same call the move makes: there is one predicate about an
/// occupant lying inside its channel and this is not a second copy of it.
ZeroUResult planSetZeroUSpan({
  required RackDocument doc,
  required Uuid id,
  required Len? span,
  required DateTime now,
  required String actor,
}) {
  final device = doc.devices[id];
  if (device == null) {
    return const ZeroURefused('That device is not in this document.');
  }
  final placement = device.placement;
  if (placement is! ZeroUPlacement) {
    return ZeroURefused(
      '${device.designator} is not mounted in a 0U channel.',
    );
  }
  if (span != null && span.nm <= 0) {
    return const ZeroURefused(
      'A 0U device has to be longer than nothing. Clear the field to say '
      'its length is unknown.',
    );
  }
  final resized = ZeroUPlacement(
    rackId: placement.rackId,
    channelId: placement.channelId,
    offsetFromChannelStart: placement.offsetFromChannelStart,
    spanAlongChannel: span,
    orientation: placement.orientation,
    locked: placement.locked,
  );
  final verdict = evaluatePlacement(
    doc: doc,
    placement: resized,
    body: bodyFor(device, doc.templates),
    designator: device.designator,
  );
  if (verdict is PlacementRefused) {
    return ZeroURefused(verdict.message, ruleId: verdict.ruleId);
  }
  return ZeroUReady(
    SetZeroUSpanCommand(
      id: id,
      from: placement,
      to: resized,
      now: now,
      actor: actor,
    ),
  );
}

/// Writes how far a 0U occupant runs along its channel (`#883`).
///
/// **A SECOND COMMAND AND NOT A FLAG ON THE FIRST**, because the two are
/// different acts with different undo labels: `Move 0U device` and
/// `Resize 0U device` are what a person reads in the Edit menu, and a
/// single command covering both would have to pick one of those names and
/// be wrong half the time. Everything else is identical to
/// `SetZeroUPositionCommand`, deliberately: same meta cache for the same
/// CR-117 reason, same `mergeKey` shape so a retyped span coalesces.
final class SetZeroUSpanCommand extends Command<RackDocument> {
  SetZeroUSpanCommand({
    required this.id,
    required this.from,
    required this.to,
    required this.now,
    required this.actor,
  });

  final Uuid id;
  final ZeroUPlacement from;
  final ZeroUPlacement to;
  final DateTime now;
  final String actor;

  DateTime? _prevUpdatedAt;
  String? _prevUpdatedBy;
  int? _prevLocalRevision;

  @override
  LabelKey get label => LabelKey.setZeroUSpan;

  @override
  EpochMask get touches => EpochMask.structure;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  Object? get mergeKey => (SetZeroUSpanCommand, id);

  @override
  bool apply(RackDocument doc) {
    final d = doc.devices[id]!;
    _prevUpdatedAt = d.meta.updatedAt;
    _prevUpdatedBy = d.meta.updatedBy;
    _prevLocalRevision = d.meta.localRevision;
    d.placement = to;
    d.meta.touch(now, actor);
    return true;
  }

  @override
  void revert(RackDocument doc) {
    final d = doc.devices[id]!..placement = from;
    final prevAt = _prevUpdatedAt;
    final prevBy = _prevUpdatedBy;
    final prevRev = _prevLocalRevision;
    if (prevAt == null || prevBy == null || prevRev == null) {
      throw StateError('SetZeroUSpanCommand.revert called before apply().');
    }
    d.meta.restoreTo(
      updatedAt: prevAt,
      updatedBy: prevBy,
      localRevision: prevRev,
    );
  }
}

/// Writes a 0U occupant's channel and offset.
final class SetZeroUPositionCommand extends Command<RackDocument> {
  SetZeroUPositionCommand({
    required this.id,
    required this.from,
    required this.to,
    required this.now,
    required this.actor,
  });

  final Uuid id;
  final ZeroUPlacement from;
  final ZeroUPlacement to;
  final DateTime now;
  final String actor;

  // The same meta cache as `MoveDeviceCommand`'s, for the same reason:
  // `touch()` cannot be undone by another `touch()`, and CR-117's byte
  // property fails on every sequence containing one otherwise.
  DateTime? _prevUpdatedAt;
  String? _prevUpdatedBy;
  int? _prevLocalRevision;

  @override
  LabelKey get label => LabelKey.setZeroUPosition;

  @override
  EpochMask get touches => EpochMask.structure;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  Object? get mergeKey => (SetZeroUPositionCommand, id);

  @override
  bool apply(RackDocument doc) {
    final d = doc.devices[id]!;
    _prevUpdatedAt = d.meta.updatedAt;
    _prevUpdatedBy = d.meta.updatedBy;
    _prevLocalRevision = d.meta.localRevision;
    d.placement = to;
    d.meta.touch(now, actor);
    return true;
  }

  @override
  void revert(RackDocument doc) {
    final d = doc.devices[id]!..placement = from;
    final prevAt = _prevUpdatedAt;
    final prevBy = _prevUpdatedBy;
    final prevRev = _prevLocalRevision;
    if (prevAt == null || prevBy == null || prevRev == null) {
      throw StateError('SetZeroUPositionCommand.revert called before apply().');
    }
    d.meta.restoreTo(
      updatedAt: prevAt,
      updatedBy: prevBy,
      localRevision: prevRev,
    );
  }
}

ZeroUChannel? _channelById(Rack rack, String id) {
  for (final c in rack.zeroUChannels) {
    if (c.id == id) return c;
  }
  return null;
}

/// Every device mounted in [channelId] of [rackId].
///
/// Public because the inspector needs to say "AMP-1 is in this channel"
/// before offering to delete it, and a second implementation of the walk
/// is how the dialog and the refusal come to disagree.
List<DeviceInstance> occupantsOfZeroUChannel(
  RackDocument doc,
  Uuid rackId,
  String channelId,
) {
  final out = <DeviceInstance>[];
  for (final d in doc.devices.values) {
    final p = d.placement;
    if (p is ZeroUPlacement && p.rackId == rackId && p.channelId == channelId) {
      out.add(d);
    }
  }
  // Total, ending in the id, because the inspector names the FIRST
  // occupant in a refusal and a comparator two entries can tie in makes
  // that sentence depend on map iteration order.
  out.sort((a, b) => a.id.v.compareTo(b.id.v));
  return out;
}
