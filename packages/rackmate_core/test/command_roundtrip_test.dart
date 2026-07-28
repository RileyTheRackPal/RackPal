// AC-016/#24, CR-117 — THE MANDATED PROPERTY TEST. docs/03-architecture.md
// §5.1: "A command must be idempotent under alternation: apply; revert;
// apply lands in the identical state as a single apply." This generates
// 1,000 random-but-valid command sequences from a fresh `RackDocument`
// with one `Rack`, and for every command in every sequence, asserts that
// applying it and then immediately reverting it restores the document's
// JSON-serialized bytes (via the real `JsonDocumentCodec`) to BYTE
// IDENTITY with what they were immediately before — not a semantic
// comparison, the literal byte property CR-117 exists for. After each
// check, the command is re-applied for real (this is the trailing
// `apply` half of the same `apply; revert; apply` law), so the sequence
// accumulates realistic document state for later commands to reference —
// "always AddDevice before any command referencing that device's id" is
// enforced by construction: this generator only ever picks a
// device/link-referencing command when its tracked alive-id set is
// non-empty.
//
// `doc.templates` is never touched by any M0 command (AC-015 template-
// snapshot refcounting is explicitly deferred — see device_commands.dart)
// so there is nothing to assert about `templates.keys` here; noted rather
// than silently skipped.
//
// Seeded with `dart:math`'s `Random(seed)`: `_baseSeed + i` for sequence
// `i` of 1000. A failure's `reason` names the exact seed AND the step
// index/command within that sequence, so `Random(_baseSeed + i)` alone
// reproduces it.
import 'dart:convert';
import 'dart:math';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
const _baseSeed = 20260718;
const _sequenceCount = 1000;

const _rackId = Uuid('property-test-rack');
const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.property-test'),
  version: 1,
  contentHash: 'sha256:property-test',
);

EntityMeta _meta(DateTime at) =>
    EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'seed');

RackDocument _freshDocumentWithOneRack(DateTime at) {
  final doc = RackDocument(
    id: const Uuid('property-test-doc'),
    appVersion: '0.1.0',
    createdAt: at,
    modifiedAt: at,
    meta: _meta(at),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Property Test Rack',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(at),
  );
  return doc;
}

enum _StepKind {
  addDevice,
  removeDevice,
  moveDevice,
  renameDevice,
  renameRack,
  setRackHeight,
  setRackProperty,
  addLink,
  removeLink,
  setLinkJacketColor,
  setLinkPulledJacketColor,
  setLinkClass,
  clearLinkClassOverride,
}

/// The convention ids the generator draws from, plus `null` (clear) and
/// one id naming NO convention entry — a dangling id must round-trip as
/// faithfully as a resolvable one, because it is the one record that a
/// wrong colour went in the wall.
const _jacketColorIds = <JacketColorId?>[
  null,
  JacketColorId('jc.blue'),
  JacketColorId('jc.yellow'),
  JacketColorId('jc.deleted_last_year'),
];

/// Builds a `SetRackPropertyCommand` for a randomly chosen field, with a
/// randomly chosen NEW value of that field's own type.
///
/// Deliberately covers all five value shapes the table carries — String,
/// bool, enum, `Len?` and `Mass?` — because the byte property is most
/// fragile exactly where nullability meets CR-117's absent-key-not-null
/// rule: `usableDepth`/`weightCapacity` encode as an ABSENT key when null,
/// so a revert that restored `Len(0)` instead of `null` would produce a
/// semantically-equal document with different bytes, and only this test
/// would catch it.
Command _buildSetRackProperty(_SequenceState s, Random rnd) {
  final rack = s.doc.racks[_rackId]!;
  final now = s.nextNow();
  const actor = 'gen';

  T pick<T>(List<T> options, T current) {
    final others = options.where((o) => o != current).toList();
    return others.isEmpty ? current : others[rnd.nextInt(others.length)];
  }

  SetRackPropertyCommand<T> make<T>(RackField<T> field, T to) =>
      SetRackPropertyCommand<T>(
        id: _rackId,
        field: field,
        from: field.get(rack),
        to: to,
        now: now,
        actor: actor,
      );

  switch (rnd.nextInt(8)) {
    case 0:
      return make(
        RackField.designator,
        'RK-${rnd.nextInt(1000)}',
      );
    case 1:
      return make(
        RackField.locationId,
        rnd.nextBool() ? Uuid('loc-${rnd.nextInt(5)}') : null,
      );
    case 2:
      return make(
        RackField.ruNumbering,
        pick(RuNumbering.values, rack.ruNumbering),
      );
    case 3:
      return make(RackField.mirrorRearElevation, !rack.mirrorRearElevation);
    case 4:
      return make(
        RackField.widthClass,
        pick(RackWidthClass.values, rack.widthClass),
      );
    case 5:
      // Nullable Len — the absent-key case.
      return make(
        RackField.usableDepth,
        rnd.nextBool() ? Len(1000000 * (1 + rnd.nextInt(900))) : null,
      );
    case 6:
      // Nullable Mass — the other absent-key case.
      return make(
        RackField.weightCapacity,
        rnd.nextBool() ? Mass(1000000000 * (1 + rnd.nextInt(900))) : null,
      );
    default:
      // The conditional-key case: `hingeSide` is written with a bare
      // `if (r.hingeSide != null)` rather than `putIfNotNull`.
      return make(
        RackField.hingeSide,
        rnd.nextBool() ? pick(HingeSide.values, rack.hingeSide) : null,
      );
  }
}

/// One generated sequence's mutable bookkeeping: which ids currently
/// exist in [doc], so the generator only ever builds a command that
/// references an id known to be alive right now.
final class _SequenceState {
  _SequenceState(this.doc);

  final RackDocument doc;
  final List<Uuid> aliveDeviceIds = [];
  final List<Uuid> aliveLinkIds = [];
  final Map<Uuid, Uuid> linkNetIds = {};
  var _tick = 0;

  /// A fresh, strictly-advancing instant each call — never
  /// `DateTime.now()` (this package's injectable-clock policy), and
  /// distinct per command so redo-vs-original-apply timestamp bugs
  /// would actually show up if introduced.
  DateTime nextNow() => DateTime.utc(2026).add(Duration(seconds: _tick++));

  List<_StepKind> availableKinds() => [
    _StepKind.addDevice,
    if (aliveDeviceIds.isNotEmpty) _StepKind.removeDevice,
    if (aliveDeviceIds.isNotEmpty) _StepKind.moveDevice,
    if (aliveDeviceIds.isNotEmpty) _StepKind.renameDevice,
    _StepKind.renameRack,
    _StepKind.setRackHeight,
    _StepKind.setRackProperty,
    _StepKind.addLink,
    if (aliveLinkIds.isNotEmpty) _StepKind.removeLink,
    if (aliveLinkIds.isNotEmpty) _StepKind.setLinkJacketColor,
    if (aliveLinkIds.isNotEmpty) _StepKind.setLinkPulledJacketColor,
    if (aliveLinkIds.isNotEmpty) _StepKind.setLinkClass,
    if (aliveLinkIds.isNotEmpty) _StepKind.clearLinkClassOverride,
  ];
}

Command _buildCommand(_StepKind kind, _SequenceState s, Random rnd, int step) {
  switch (kind) {
    case _StepKind.addDevice:
      return AddDeviceCommand(
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'DEV-$step',
        name: 'Device $step',
        placement: RailPlacement(
          rackId: _rackId,
          ruIndex: 1 + rnd.nextInt(40),
          face: Face.values[rnd.nextInt(Face.values.length)],
        ),
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.removeDevice:
      final id = s.aliveDeviceIds[rnd.nextInt(s.aliveDeviceIds.length)];
      return RemoveDeviceCommand(id: id);

    case _StepKind.moveDevice:
      final id = s.aliveDeviceIds[rnd.nextInt(s.aliveDeviceIds.length)];
      final current = s.doc.devices[id]!.placement as RailPlacement;
      return MoveDeviceCommand(
        id: id,
        fromRuIndex: current.ruIndex,
        toRuIndex: 1 + rnd.nextInt(40),
        fromFace: current.face,
        toFace: Face.values[rnd.nextInt(Face.values.length)],
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.renameDevice:
      final id = s.aliveDeviceIds[rnd.nextInt(s.aliveDeviceIds.length)];
      return RenameEntityCommand(
        targetKind: RenameTargetKind.device,
        id: id,
        from: s.doc.devices[id]!.name,
        to: 'Renamed Device $step',
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.renameRack:
      return RenameEntityCommand(
        targetKind: RenameTargetKind.rack,
        id: _rackId,
        from: s.doc.racks[_rackId]!.name,
        to: 'Renamed Rack $step',
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.setRackHeight:
      return SetRackHeightCommand(
        id: _rackId,
        fromHeightU: s.doc.racks[_rackId]!.heightU,
        toHeightU: 1 + rnd.nextInt(60),
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.setRackProperty:
      return _buildSetRackProperty(s, rnd);

    case _StepKind.addLink:
      return AddLinkCommand(
        designator: 'W${step.toString().padLeft(3, '0')}',
        media: const MediaTypeId('media.cat6a_futp'),
        order: const FracIndex('a0'),
        now: s.nextNow(),
        actor: 'gen',
      );

    case _StepKind.removeLink:
      final id = s.aliveLinkIds[rnd.nextInt(s.aliveLinkIds.length)];
      return RemoveLinkCommand(id: id, netId: s.linkNetIds[id]!);

    case _StepKind.setLinkJacketColor:
      return SetLinkJacketColorCommand(
        linkId: s.aliveLinkIds[rnd.nextInt(s.aliveLinkIds.length)],
        conventionId: _jacketColorIds[rnd.nextInt(_jacketColorIds.length)],
      );

    case _StepKind.setLinkPulledJacketColor:
      // Interleaving this with `setLinkJacketColor` above is the point:
      // the command NORMALISES an override equal to the run's current
      // convention away, so a sequence that changes the convention
      // between two identical override writes exercises a path where the
      // same command value produces different stored state. `revert()`
      // must still restore byte-exactly through all of it.
      return SetLinkPulledJacketColorCommand(
        linkId: s.aliveLinkIds[rnd.nextInt(s.aliveLinkIds.length)],
        pulledId: _jacketColorIds[rnd.nextInt(_jacketColorIds.length)],
      );

    case _StepKind.setLinkClass:
      return SetLinkClassCommand(
        linkId: s.aliveLinkIds[rnd.nextInt(s.aliveLinkIds.length)],
        linkClass: LinkClass.values[rnd.nextInt(LinkClass.values.length)],
      );

    case _StepKind.clearLinkClassOverride:
      // INTERLEAVED WITH `setLinkClass` ON PURPOSE. `linkClassLocked` is
      // an ABSENT-WHEN-FALSE key (DR-008 §11.8.2), which is the whole
      // reason the field could be added without moving `kSchemaVersion`.
      // A set/clear pair must therefore leave the document byte-identical
      // to one that never carried the key at all — and two different bugs
      // show up here as a byte diff rather than as a passing unit test:
      // an encoder that starts writing `false`, and a `revert()` that
      // restores the class but not the lock.
      return ClearLinkClassOverrideCommand(
        linkId: s.aliveLinkIds[rnd.nextInt(s.aliveLinkIds.length)],
      );
  }
}

void _reconcileTrackingAfterCommit(
  _StepKind kind,
  Command cmd,
  _SequenceState s,
) {
  switch (kind) {
    case _StepKind.addDevice:
      s.aliveDeviceIds.add((cmd as AddDeviceCommand).id);
    case _StepKind.removeDevice:
      s.aliveDeviceIds.remove((cmd as RemoveDeviceCommand).id);
    case _StepKind.addLink:
      final add = cmd as AddLinkCommand;
      s.aliveLinkIds.add(add.id);
      s.linkNetIds[add.id] = add.netId;
    case _StepKind.removeLink:
      final remove = cmd as RemoveLinkCommand;
      s.aliveLinkIds.remove(remove.id);
      s.linkNetIds.remove(remove.id);
    case _StepKind.moveDevice:
    case _StepKind.renameDevice:
    case _StepKind.renameRack:
    case _StepKind.setRackHeight:
    case _StepKind.setRackProperty:
    case _StepKind.setLinkJacketColor:
    case _StepKind.setLinkPulledJacketColor:
    case _StepKind.setLinkClass:
    case _StepKind.clearLinkClassOverride:
    // Mutate entities already tracked; no alive-id bookkeeping needed.
  }
}

void main() {
  test(
    '$_sequenceCount random command sequences: apply; revert restores '
    'byte-identical JSON (CR-117)',
    () {
      for (var i = 0; i < _sequenceCount; i++) {
        final seed = _baseSeed + i;
        final rnd = Random(seed);
        final startAt = DateTime.utc(2026);
        final doc = _freshDocumentWithOneRack(startAt);
        final state = _SequenceState(doc);

        final stepCount = 5 + rnd.nextInt(11); // 5..15 commands
        for (var step = 0; step < stepCount; step++) {
          final kinds = state.availableKinds();
          final kind = kinds[rnd.nextInt(kinds.length)];
          final cmd = _buildCommand(kind, state, rnd, step);

          final before = _codec.write(doc);
          cmd
            ..apply(doc)
            ..revert(doc);
          final afterRevert = _codec.write(doc);

          final reason =
              'seed=$seed step=$step kind=$kind '
              'command=${cmd.runtimeType} — apply;revert did not restore '
              'a byte-identical document (CR-117). Reproduce with '
              'Random($seed).';
          expect(
            utf8.decode(afterRevert),
            equals(utf8.decode(before)),
            reason: reason,
          );
          expect(afterRevert, equals(before), reason: reason);

          // Commit for real (the trailing `apply` of `apply; revert;
          // apply`), so later steps in this sequence can reference
          // whatever this command just did.
          cmd.apply(doc);
          _reconcileTrackingAfterCommit(kind, cmd, state);
        }
      }
    },
  );
}
