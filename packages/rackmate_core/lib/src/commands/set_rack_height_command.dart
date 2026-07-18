import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Changes `Rack.heightU`. See `MoveDeviceCommand` (device_commands.dart)
/// for why `revert()` restores `EntityMeta` via `restoreTo` rather than
/// calling `touch` again.
final class SetRackHeightCommand extends Command {
  SetRackHeightCommand({
    required this.id,
    required this.fromHeightU,
    required this.toHeightU,
    required this.now,
    required this.actor,
  });

  final Uuid id;
  final int fromHeightU;
  final int toHeightU;
  final DateTime now;
  final String actor;

  DateTime? _prevUpdatedAt;
  String? _prevUpdatedBy;
  int? _prevLocalRevision;

  @override
  LabelKey get label => LabelKey.setRackHeight;

  @override
  EpochMask get touches => EpochMask.rack;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  Object? get mergeKey => (SetRackHeightCommand, id);

  @override
  void apply(RackDocument doc) {
    final r = doc.racks[id]!;
    _prevUpdatedAt = r.meta.updatedAt;
    _prevUpdatedBy = r.meta.updatedBy;
    _prevLocalRevision = r.meta.localRevision;
    r
      ..heightU = toHeightU
      ..meta.touch(now, actor);
  }

  @override
  void revert(RackDocument doc) {
    final r = doc.racks[id]!;
    final prevAt = _prevUpdatedAt;
    final prevBy = _prevUpdatedBy;
    final prevRev = _prevLocalRevision;
    if (prevAt == null || prevBy == null || prevRev == null) {
      throw StateError('SetRackHeightCommand.revert called before apply().');
    }
    r
      ..heightU = fromHeightU
      ..meta.restoreTo(
        updatedAt: prevAt,
        updatedBy: prevBy,
        localRevision: prevRev,
      );
  }

  @override
  Command? mergeWith(Command next) => switch (next) {
    SetRackHeightCommand(
      id: final n,
      toHeightU: final h,
      now: final mergedNow,
      actor: final mergedActor,
    )
        when n == id =>
      // See MoveDeviceCommand.mergeWith's comment (device_commands.dart):
      // carries THIS command's already-captured "before" meta snapshot
      // forward, since the merged command is a fresh object that never
      // itself has apply() called on it before a possible revert().
      (SetRackHeightCommand(
          id: id,
          fromHeightU: fromHeightU,
          toHeightU: h,
          now: mergedNow,
          actor: mergedActor,
        )
        .._prevUpdatedAt = _prevUpdatedAt
        .._prevUpdatedBy = _prevUpdatedBy
        .._prevLocalRevision = _prevLocalRevision),
    _ => null,
  };
}
