// Not one of the two AC-014/AC-016 tests this stage's task explicitly
// mandates (epoch_mask_test.dart, command_roundtrip_test.dart) — an
// additional smoke test for `DocumentController` itself, since it is the
// other half of this stage's deliverable (docs/03-architecture.md §5.4)
// and the two mandated tests both exercise `Command.apply`/`revert`
// directly, never through `run`/`transact`/`undo`/`redo`. Covers:
// commit bumping `sequence`/`stateId`, `isDirty`/`markSaved`, nested
// `transact()` flattening into one undo entry, rollback on a mid-
// transaction failure, and the §5.4 coalescing policy actually firing
// through `run()` (this is what caught `Transaction` needing to forward
// `mergeKey`/`mergeWith` to a single child — see transaction.dart).
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _rackId = Uuid('dc-rack-1');
const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.dc-test'),
  version: 1,
  contentHash: 'sha256:dc-test',
);

EntityMeta _meta(DateTime at) =>
    EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'seed');

RackDocument _docWithRack(DateTime at) {
  final doc = RackDocument(
    id: const Uuid('dc-test-doc'),
    appVersion: '0.1.0',
    createdAt: at,
    modifiedAt: at,
    meta: _meta(at),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'DC Test Rack',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(at),
  );
  return doc;
}

AddDeviceCommand _addDevice(DateTime at, {Uuid? id, int ruIndex = 1}) =>
    AddDeviceCommand(
      id: id,
      kind: DeviceKind.rackDevice,
      templateRef: _templateRef,
      designator: 'DEV-1',
      name: 'Device 1',
      placement: RailPlacement(
        rackId: _rackId,
        ruIndex: ruIndex,
        face: Face.front,
      ),
      now: at,
      actor: 'tester',
    );

void main() {
  final fixed = DateTime.utc(2026);

  group('DocumentController — commit/undo/redo/isDirty', () {
    test('run() commits, bumps sequence/stateId, marks the doc dirty', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed));

      expect(controller.isDirty, isFalse);
      expect(doc.sequence, 0);

      controller.run(_addDevice(fixed));

      expect(doc.devices, hasLength(1));
      expect(doc.sequence, 1);
      expect(controller.isDirty, isTrue);
      expect(controller.undo.canUndo, isTrue);
      expect(controller.undo.canRedo, isFalse);

      controller.markSaved();
      expect(controller.isDirty, isFalse);

      controller.undoLast();
      expect(doc.devices, isEmpty);
      expect(controller.undo.canRedo, isTrue);
      // stateId only ever advances (CR-094) — undoing back to the saved
      // CONTENT does not undo the STATE-ID counter, so this correctly
      // (conservatively) still reads as dirty rather than risk a false
      // "nothing to save" after an undo/redo dance.
      expect(controller.isDirty, isTrue);

      controller.redoLast();
      expect(doc.devices, hasLength(1));
    });

    test('nested transact() calls flatten into one undo entry', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed));

      controller.transact(LabelKey.addDevice, (tx) {
        tx.add(_addDevice(fixed));
        // A transact() call while one is already open must reuse the
        // SAME outer entry rather than pushing a second one.
        controller.transact(LabelKey.renameEntity, (inner) {
          final deviceId = doc.devices.keys.single;
          inner.add(
            RenameEntityCommand(
              targetKind: RenameTargetKind.device,
              id: deviceId,
              from: 'Device 1',
              to: 'Device 1 renamed',
              now: fixed,
              actor: 'tester',
            ),
          );
        });
      });

      expect(doc.devices.values.single.name, 'Device 1 renamed');

      controller.undoLast();

      expect(doc.devices, isEmpty); // both the add AND the rename undone
      expect(controller.undo.canUndo, isFalse); // exactly one entry existed
    });

    test('a failed transaction rolls back every already-applied child', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed));
      const deviceId = Uuid('dc-dev-boom');

      expect(
        () => controller.transact(LabelKey.addDevice, (tx) {
          tx.add(_addDevice(fixed, id: deviceId));
          throw StateError('simulated failure mid-transaction');
        }),
        throwsStateError,
      );

      expect(doc.devices, isEmpty); // the add was rolled back
      expect(controller.undo.canUndo, isFalse); // nothing was committed
    });

    test(
      'two MoveDeviceCommand.run() calls within the merge window coalesce '
      'into one undo entry',
      () {
        final doc = _docWithRack(fixed);
        final controller = DocumentController(doc, clock: FixedClock(fixed));
        const deviceId = Uuid('dc-dev-move');

        controller
          ..run(_addDevice(fixed, id: deviceId))
          ..run(
            MoveDeviceCommand(
              id: deviceId,
              fromRuIndex: 1,
              toRuIndex: 2,
              fromFace: Face.front,
              toFace: Face.front,
              now: fixed,
              actor: 'tester',
            ),
          )
          ..run(
            MoveDeviceCommand(
              id: deviceId,
              fromRuIndex: 2,
              toRuIndex: 3,
              fromFace: Face.front,
              toFace: Face.front,
              now: fixed,
              actor: 'tester',
            ),
          );

        final moved = doc.devices[deviceId]!.placement as RailPlacement;
        expect(moved.ruIndex, 3);

        // Exactly two undo entries should exist: the add, and the TWO
        // merged moves as one. Undoing once must land back at ruIndex 1
        // (both moves at once), not 2 (only the second move).
        controller.undoLast();
        final reverted = doc.devices[deviceId]!.placement as RailPlacement;
        expect(reverted.ruIndex, 1);
        expect(controller.undo.canUndo, isTrue); // the add is still there

        controller.undoLast();
        expect(doc.devices, isEmpty);
        expect(controller.undo.canUndo, isFalse);
      },
    );
  });
}
