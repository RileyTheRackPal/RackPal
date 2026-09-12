// The producer `OffRackPlacement.mountNote` never had (DR-130 §11.129).
//
// ═════════════════════════════════════════════════════════════════════
// THE FIELD WAS SHIPPED, SEEDED AND SERIALIZED, AND UNREACHABLE
// ═════════════════════════════════════════════════════════════════════
// DR-125 dispositioned the cabinet head end as "expressible as
// `OffRackPlacement` with a `mountNote`, but crude". Censused before
// pricing: the crude option was not available either.
//
// `mountNote` is modelled, written under its own key by the codec and
// read back by it, and **nothing a person can reach ever wrote one**.
// The single occurrence in `commands/` is `location_commands.dart`
// carrying it across a location clear so the note is not destroyed,
// which is a preserver rather than a producer. No widget rendered it, no
// schedule printed it. Its only writers were `apps/rackpal/tool/
// starters/`, the starter generator, which is why four seeded devices
// carry sentences like "Ceiling mount, rear of room" that no user could
// have typed.
//
// EIGHTH FIELD THIS MILESTONE WITH NO PRODUCER, and the first found by
// censusing a ruling's own escape hatch rather than by a rule firing on
// a connection that is correct.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The outcome of planning a mount-note edit.
sealed class MountNoteResult {
  const MountNoteResult();
}

/// The edit is legal; [command] writes it.
final class MountNoteReady extends MountNoteResult {
  const MountNoteReady(this.command);

  final SetMountNoteCommand command;
}

/// The edit cannot be made, and [reason] is shown to the user verbatim.
final class MountNoteRefused extends MountNoteResult {
  const MountNoteRefused(this.reason);

  final String reason;
}

/// An empty note is NOT an empty string.
///
/// G4/CR-114: unknown serializes as an absent key. A person who clears
/// the field is saying "there is no note", and the codec's
/// `if (mountNote != null)` writes nothing for a null and writes `""` for
/// an empty string, which round-trips as a note that exists and says
/// nothing. Trimming here means the two states cannot diverge.
String? normalizeMountNote(String raw) {
  final t = raw.trim();
  return t.isEmpty ? null : t;
}

/// Plans a mount-note edit for [id], or refuses it.
///
/// REFUSES ON PLACEMENT KIND AND ON NOTHING ELSE. There is no rule here
/// to break: a mount note is prose about where a box physically sits, and
/// `CR-021` holds the rule count at 28 with no entry that could refuse
/// one. The single refusal is structural, and it is the same shape
/// `planSetDeviceWidth` uses for a device that is not rail-placed: the
/// field does not exist on this placement, so the honest answer names the
/// placement rather than silently doing nothing.
MountNoteResult planSetMountNote({
  required RackDocument doc,
  required Uuid id,
  required String note,
  required DateTime now,
  required String actor,
}) {
  final device = doc.devices[id];
  if (device == null) {
    return const MountNoteRefused('That device is not in this document.');
  }
  final placement = device.placement;
  if (placement is! OffRackPlacement) {
    return MountNoteRefused(
      '${device.designator} is placed in a rack, so its position is the '
      'rack and the RU rather than a note.',
    );
  }
  return MountNoteReady(
    SetMountNoteCommand(
      id: id,
      from: placement.mountNote,
      to: normalizeMountNote(note),
      now: now,
      actor: actor,
    ),
  );
}

/// Writes `OffRackPlacement.mountNote`, replacing the whole placement and
/// carrying `locationId` and `unknown` across untouched.
///
/// Built only by [planSetMountNote]. The constructor is public because
/// `command_roundtrip_test.dart` and undo/redo need it.
final class SetMountNoteCommand extends Command<RackDocument> {
  SetMountNoteCommand({
    required this.id,
    required this.from,
    required this.to,
    required this.now,
    required this.actor,
  });

  final Uuid id;
  final String? from;
  final String? to;
  final DateTime now;
  final String actor;

  // The same cache, for the same reason, as `SetDeviceWidthCommand`'s:
  // the untouched placement fields survive because apply and revert read
  // them off the CURRENT placement, but `EntityMeta.touch()` overwrites
  // the triple with no way to recover it, and CR-117's byte round-trip
  // fails on every generated sequence containing one of these otherwise.
  DateTime? _prevUpdatedAt;
  String? _prevUpdatedBy;
  int? _prevLocalRevision;

  @override
  LabelKey get label => LabelKey.setMountNote;

  /// `meta`, and NOT `structure`.
  ///
  /// `EpochMask.structure` is documented as "placement add/remove/move/
  /// rotate/face" and `meta` as "designators, names, notes". This lives
  /// on a `Placement` and is none of the first list: nothing moves, no
  /// geometry changes, and no derived view that recomputes on
  /// `structure` would compute anything different. It is a note, and it
  /// is declared as one.
  @override
  EpochMask get touches => EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  /// Consecutive edits to ONE device's note collapse into one undo entry.
  ///
  /// This is a text field, so without a merge key a person typing
  /// "Top shelf, left" would be handed fifteen undo entries and would
  /// have to press the shortcut fifteen times to get back where they
  /// started.
  @override
  Object? get mergeKey => (SetMountNoteCommand, id);

  @override
  bool apply(RackDocument doc) {
    final d = doc.devices[id]!;
    final base = _requireOffRack(d);
    _prevUpdatedAt = d.meta.updatedAt;
    _prevUpdatedBy = d.meta.updatedBy;
    _prevLocalRevision = d.meta.localRevision;
    d.placement = base.withMountNote(to);
    d.meta.touch(now, actor);
    return true;
  }

  @override
  void revert(RackDocument doc) {
    final d = doc.devices[id]!;
    final base = _requireOffRack(d);
    d.placement = base.withMountNote(from);
    final prevAt = _prevUpdatedAt;
    final prevBy = _prevUpdatedBy;
    final prevRev = _prevLocalRevision;
    if (prevAt == null || prevBy == null || prevRev == null) {
      throw StateError('SetMountNoteCommand.revert called before apply().');
    }
    d.meta.restoreTo(
      updatedAt: prevAt,
      updatedBy: prevBy,
      localRevision: prevRev,
    );
  }

  OffRackPlacement _requireOffRack(DeviceInstance d) {
    final current = d.placement;
    if (current is OffRackPlacement) return current;
    throw StateError(
      'SetMountNoteCommand requires device $id to be off-rack; '
      'found ${current.runtimeType}.',
    );
  }
}
