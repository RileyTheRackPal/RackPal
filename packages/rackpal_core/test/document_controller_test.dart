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
import 'package:rackpal_core/rackpal_core.dart';
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
      // Still dirty, but the REASON changed with CR-094 conformance, and
      // the difference matters. It used to be dirty because `stateId`
      // only ever advanced — a counter that could never come back, so
      // every undo read as an edit. It is dirty now because this undo
      // genuinely moved the document AWAY from what was written: the save
      // point is the one-device state and the document is now empty.
      // (The old comment here defended the monotonic counter as
      // "conservative". The counter is gone; see
      // `undo back onto the save point reads CLEAN` below, which is the
      // assertion the old behaviour actually failed.)
      expect(
        controller.isDirty,
        isTrue,
        reason:
            'undone PAST the save point — the document really does '
            'differ from the bytes on disk',
      );

      controller.redoLast();
      expect(doc.devices, hasLength(1));
      // ...and redoing back ONTO the save point reads clean again. This
      // is impossible under a monotonic stateId.
      expect(controller.isDirty, isFalse);
    });

    // THE CR-094 MUTATION TEST. Revert `doc.stateId = restoreStateId` in
    // `undoLast` to `doc.stateId++` and this fails on the last line.
    test('undo back onto the save point reads CLEAN (CR-094)', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed))
        ..run(_addDevice(fixed, id: const Uuid('dev-a')))
        ..markSaved();
      expect(controller.isDirty, isFalse);
      expect(controller.editsSinceSave, 0);

      controller.run(_addDevice(fixed, id: const Uuid('dev-b'), ruIndex: 5));
      expect(controller.isDirty, isTrue);
      expect(controller.editsSinceSave, 1);

      controller.undoLast();

      expect(doc.devices, hasLength(1));
      expect(
        controller.isDirty,
        isFalse,
        reason: 'the document is once again exactly what was written',
      );
      expect(controller.editsSinceSave, 0);
    });

    test('editsSinceSave counts forward AND backward from the save '
        'point', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed));

      for (var i = 0; i < 5; i++) {
        controller.run(
          _addDevice(fixed, id: Uuid('dev-$i'), ruIndex: i + 1),
        );
      }
      controller.markSaved();
      expect(controller.editsSinceSave, 0);

      controller
        ..undoLast()
        ..undoLast();
      // Undone two steps BEHIND the save point: still two edits away
      // from the bytes on disk, and the close prompt must say so.
      expect(controller.isDirty, isTrue);
      expect(controller.editsSinceSave, 2);

      controller
        ..redoLast()
        ..redoLast()
        // A third redo is a no-op — there is nothing left to redo — and
        // must not move the state id off the save point.
        ..redoLast();
      expect(controller.isDirty, isFalse);
      expect(controller.editsSinceSave, 0);
    });

    test('editsSinceSave is null — not a guess — when the undo stack is '
        'poisoned (G4)', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed))
        ..run(_addDevice(fixed));
      expect(controller.editsSinceSave, 1);

      controller.undo.poison();

      expect(controller.isDirty, isTrue, reason: 'still unsaved');
      expect(
        controller.editsSinceSave,
        isNull,
        reason:
            'the history that knew the number is gone; the UI must '
            'omit the count rather than invent one',
      );
    });

    test('changes notifier fires on commit, undo, redo and markSaved', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed));

      var fired = 0;
      controller.changes.addListener(() => fired++);

      controller.run(_addDevice(fixed));
      expect(fired, 1);

      controller.undoLast();
      expect(fired, 2);

      controller.redoLast();
      expect(fired, 3);

      controller.markSaved();
      expect(fired, 4);

      // A no-op transaction commits nothing, so it must not pretend
      // anything changed — the title bar would flicker a `*` on and off.
      controller.transact<void>(LabelKey.addDevice, (tx) {});
      expect(fired, 4);
    });

    test('markSavedAt clears the flag for the state that was SERIALIZED, '
        'not the state at completion', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed))
        ..run(_addDevice(fixed, id: const Uuid('dev-a')));
      // What an async save captures synchronously at serialize time.
      final captured = doc.stateId;

      // The user edits across the isolate await.
      controller
        ..run(_addDevice(fixed, id: const Uuid('dev-b'), ruIndex: 5))
        ..markSavedAt(captured);

      expect(
        controller.isDirty,
        isTrue,
        reason:
            'dev-b was never written; marking it saved would let a '
            'crash take it with no recovery snapshot',
      );
      expect(controller.editsSinceSave, 1);
      expect(controller.savedStateId, captured);
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

  // The M1 canvas edit loop routes select→move→delete→undo through exactly
  // this API. These assert the command-routing correctness the whole M1
  // interaction stage rests on, plus the new selection-restore return values
  // undoLast()/redoLast() now expose for the UI SelectionController.
  group('DocumentController — command-routed edit loop (M1)', () {
    Selection sel(Iterable<String> ids, [String? focus]) => Selection(
      ids: {for (final id in ids) Uuid(id)},
      focus: focus == null ? null : Uuid(focus),
    );

    test('move-then-undo restores the device ruIndex, and undo returns '
        'the pre-move selection', () {
      final doc = _docWithRack(fixed);
      // Select, then move — the exact sequence a canvas gesture produces.
      final controller = DocumentController(doc, clock: FixedClock(fixed))
        ..run(_addDevice(fixed, id: const Uuid('dc-dev-move')))
        ..selection = sel(['dc-dev-move'], 'dc-dev-move')
        ..run(
          MoveDeviceCommand(
            id: const Uuid('dc-dev-move'),
            fromRuIndex: 1,
            toRuIndex: 5,
            fromFace: Face.front,
            toFace: Face.front,
            now: fixed,
            actor: 'tester',
          ),
        );
      const deviceId = Uuid('dc-dev-move');
      expect((doc.devices[deviceId]!.placement as RailPlacement).ruIndex, 5);

      final restored = controller.undoLast();
      expect((doc.devices[deviceId]!.placement as RailPlacement).ruIndex, 1);
      expect(restored, isNotNull);
      expect(restored!.ids, {deviceId});
      expect(restored.focus, deviceId);

      final redone = controller.redoLast();
      expect((doc.devices[deviceId]!.placement as RailPlacement).ruIndex, 5);
      expect(redone!.ids, {deviceId});
    });

    test('delete-then-undo brings the whole device back as one command', () {
      final doc = _docWithRack(fixed);
      const deviceId = Uuid('dc-dev-del');
      final controller = DocumentController(doc, clock: FixedClock(fixed))
        ..run(_addDevice(fixed, id: deviceId, ruIndex: 3));
      final before = doc.devices[deviceId];

      controller
        ..selection = sel(['dc-dev-del'], 'dc-dev-del')
        ..run(RemoveDeviceCommand(id: deviceId));
      expect(doc.devices.containsKey(deviceId), isFalse);

      final restored = controller.undoLast();
      // The SAME whole entity object comes back (RemoveDeviceCommand holds it).
      expect(doc.devices[deviceId], same(before));
      expect(restored!.ids, {deviceId});
    });

    test('a multi-device delete undoes as ONE step (transact grouping)', () {
      final doc = _docWithRack(fixed);
      const a = Uuid('dc-del-a');
      const b = Uuid('dc-del-b');
      // One transaction, two removes — the canvas's Del path for a selection.
      final controller = DocumentController(doc, clock: FixedClock(fixed))
        ..run(_addDevice(fixed, id: a))
        ..run(_addDevice(fixed, id: b, ruIndex: 5))
        ..selection = sel(['dc-del-a', 'dc-del-b'])
        ..transact(LabelKey.removeDevice, (tx) {
          tx
            ..add(RemoveDeviceCommand(id: a))
            ..add(RemoveDeviceCommand(id: b));
        });
      expect(doc.devices, isEmpty);

      // A single undo restores BOTH devices, not just one.
      controller.undoLast();
      expect(doc.devices.keys.toSet(), {a, b});
      expect(controller.undo.canUndo, isTrue); // the two adds still remain
    });

    test('undoLast/redoLast on an empty history return null', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed));
      expect(controller.undoLast(), isNull);
      expect(controller.redoLast(), isNull);
    });
  });
}
