// A generic rename, usable on either of the two entity kinds M0 gives a
// user-facing `name` field with an @internal setter: DeviceInstance and
// Rack. Not modelled as two separate command classes (RenameDeviceCommand
// / RenameRackCommand) because the shape is identical and the only thing
// that differs is which map to look the id up in — a small discriminator
// enum reads more honestly than either duplicating the class or reaching
// for reflection this package cannot use anyway (pure Dart, no dart:mirrors).
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Which entity map [RenameEntityCommand.id] is looked up in.
enum RenameTargetKind { device, rack }

/// Renames a [RenameTargetKind.device] or [RenameTargetKind.rack]. See
/// `MoveDeviceCommand` (device_commands.dart) for why `revert()` restores
/// the target's `EntityMeta` via `restoreTo` rather than calling `touch`
/// again — the same reasoning applies here verbatim.
final class RenameEntityCommand extends Command {
  RenameEntityCommand({
    required this.targetKind,
    required this.id,
    required this.from,
    required this.to,
    required this.now,
    required this.actor,
  });

  final RenameTargetKind targetKind;
  final Uuid id;
  final String from;
  final String to;
  final DateTime now;
  final String actor;

  DateTime? _prevUpdatedAt;
  String? _prevUpdatedBy;
  int? _prevLocalRevision;

  @override
  LabelKey get label => LabelKey.renameEntity;

  @override
  EpochMask get touches => EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  Object? get mergeKey => (RenameEntityCommand, targetKind, id);

  void _setName(RackDocument doc, String name) {
    switch (targetKind) {
      case RenameTargetKind.device:
        doc.devices[id]!.name = name;
      case RenameTargetKind.rack:
        doc.racks[id]!.name = name;
    }
  }

  ({DateTime updatedAt, String updatedBy, int localRevision}) _metaTriple(
    RackDocument doc,
  ) {
    final meta = switch (targetKind) {
      RenameTargetKind.device => doc.devices[id]!.meta,
      RenameTargetKind.rack => doc.racks[id]!.meta,
    };
    return (
      updatedAt: meta.updatedAt,
      updatedBy: meta.updatedBy,
      localRevision: meta.localRevision,
    );
  }

  void _touch(RackDocument doc) {
    switch (targetKind) {
      case RenameTargetKind.device:
        doc.devices[id]!.meta.touch(now, actor);
      case RenameTargetKind.rack:
        doc.racks[id]!.meta.touch(now, actor);
    }
  }

  void _restoreMeta(RackDocument doc) {
    final prevAt = _prevUpdatedAt;
    final prevBy = _prevUpdatedBy;
    final prevRev = _prevLocalRevision;
    if (prevAt == null || prevBy == null || prevRev == null) {
      throw StateError('RenameEntityCommand.revert called before apply().');
    }
    switch (targetKind) {
      case RenameTargetKind.device:
        doc.devices[id]!.meta.restoreTo(
          updatedAt: prevAt,
          updatedBy: prevBy,
          localRevision: prevRev,
        );
      case RenameTargetKind.rack:
        doc.racks[id]!.meta.restoreTo(
          updatedAt: prevAt,
          updatedBy: prevBy,
          localRevision: prevRev,
        );
    }
  }

  @override
  void apply(RackDocument doc) {
    final triple = _metaTriple(doc);
    _prevUpdatedAt = triple.updatedAt;
    _prevUpdatedBy = triple.updatedBy;
    _prevLocalRevision = triple.localRevision;
    _setName(doc, to);
    _touch(doc);
  }

  @override
  void revert(RackDocument doc) {
    _setName(doc, from);
    _restoreMeta(doc);
  }

  @override
  Command? mergeWith(Command next) => switch (next) {
    RenameEntityCommand(
      targetKind: final k,
      id: final n,
      to: final newTo,
      now: final mergedNow,
      actor: final mergedActor,
    )
        when k == targetKind && n == id =>
      // See MoveDeviceCommand.mergeWith's comment (device_commands.dart):
      // carries THIS command's already-captured "before" meta snapshot
      // forward, since the merged command is a fresh object that never
      // itself has apply() called on it before a possible revert().
      (RenameEntityCommand(
          targetKind: targetKind,
          id: id,
          from: from,
          to: newTo,
          now: mergedNow,
          actor: mergedActor,
        )
        .._prevUpdatedAt = _prevUpdatedAt
        .._prevUpdatedBy = _prevUpdatedBy
        .._prevLocalRevision = _prevLocalRevision),
    _ => null,
  };
}
