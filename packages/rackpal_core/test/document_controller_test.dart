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

  // ═══════════════════════════════════════════════════════════════════
  // DR-172: the undo depth is a setting, and a dropped step is counted
  // ═══════════════════════════════════════════════════════════════════
  // `AddDeviceCommand` declares no `mergeKey`, so every add below is its
  // own undo step and the counts are counts of edits.
  group('undo depth (canon §10.12(a), AC-058 D5, DR-172)', () {
    DocumentController withDevices(
      int count, {
      int depth = kDefaultUndoDepth,
    }) {
      final controller = DocumentController(
        _docWithRack(fixed),
        clock: FixedClock(fixed),
        undoDepth: depth,
      );
      for (var i = 1; i <= count; i++) {
        controller.run(_addDevice(fixed, id: Uuid('dev-$i'), ruIndex: i));
      }
      return controller;
    }

    test('a controller given no depth keeps the canon default of 200', () {
      expect(kDefaultUndoDepth, 200);
      expect(DocumentController(_docWithRack(fixed)).undo.maxEntries, 200);
    });

    test('past its depth the stack drops the OLDEST step, and counts it', () {
      final controller = withDevices(5, depth: 3);
      expect(controller.undo.depth, 3);
      expect(controller.undo.droppedCount, 2);

      for (var i = 0; i < 3; i++) {
        expect(controller.undoLast(), isNotNull);
      }
      expect(controller.undo.canUndo, isFalse);
      expect(
        controller.doc.devices.keys.toList(),
        [
          const Uuid('dev-1'),
          const Uuid('dev-2'),
        ],
        reason: 'the two oldest adds are beyond reach, not undone',
      );
    });

    test('resizeUndo below the depth drops the oldest at once and says how '
        'many', () {
      final controller = withDevices(5, depth: 10);

      expect(controller.resizeUndo(2), 3);

      expect(controller.undo.depth, 2);
      expect(controller.undo.maxEntries, 2);
      expect(controller.undo.droppedCount, 3);
    });

    test('when the save point goes with them, editsSinceSave becomes '
        'UNKNOWN and changes rings (G4)', () {
      final controller = withDevices(1, depth: 10)..markSaved();
      for (var i = 2; i <= 5; i++) {
        controller.run(_addDevice(fixed, id: Uuid('dev-$i'), ruIndex: i));
      }
      expect(controller.editsSinceSave, 4);
      final before = controller.changes.value;

      controller.resizeUndo(2);

      expect(
        controller.editsSinceSave,
        isNull,
        reason: 'the save point aged out, and a count would be a guess',
      );
      expect(controller.changes.value, greaterThan(before));
    });

    test('resizeUndo above the depth drops nothing and stays quiet', () {
      final controller = withDevices(5, depth: 10);
      final before = controller.changes.value;

      expect(controller.resizeUndo(500), 0);

      expect(controller.undo.depth, 5);
      expect(controller.undo.droppedCount, 0);
      expect(controller.changes.value, before);
    });

    test('the redo tail survives a resize, because it is not the oldest '
        'history', () {
      final controller = withDevices(5, depth: 10)
        ..undoLast()
        ..undoLast();
      expect(controller.undo.canRedo, isTrue);

      controller.resizeUndo(1);

      expect(controller.undo.depth, 1);
      expect(controller.redoLast(), isNotNull);
      expect(controller.doc.devices.containsKey(const Uuid('dev-4')), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // DR-187 §11.186.2: A CONSEQUENCE RIDES IN THE ENTRY ITS CAUSE MADE
  // ═══════════════════════════════════════════════════════════════════
  // The schematic's layout freeze has to land in the same undo entry as
  // the edit that would otherwise re-flow it. Written as a second `run()`
  // it was a second entry, and deleting one device then took two presses
  // of Ctrl+Z while the first one scrambled the sheet. These cases are
  // the mechanism that fixed it, tested on the controller rather than
  // through a canvas.
  group('DocumentController.addConsequence', () {
    test('the hook lands IN the entry, so one undo takes both back', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed))
        ..addConsequence(
          (tx) => tx.add(
            _MarkCommand(_rackId, 'consequence'),
          ),
        )
        ..run(_addDevice(fixed, id: const Uuid('dev-1')));

      expect(doc.racks[_rackId]!.name, 'consequence');
      expect(doc.devices, hasLength(1));

      controller.undoLast();

      expect(doc.racks[_rackId]!.name, 'DC Test Rack');
      expect(doc.devices, isEmpty);
      expect(controller.undo.canUndo, isFalse, reason: 'ONE entry, not two');
    });

    test('THE FIRST CHILD STILL NAMES THE ENTRY, so the Edit menu says what '
        'the person did and not what it cost', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed))
        ..addConsequence((tx) => tx.add(_MarkCommand(_rackId, 'consequence')))
        ..run(_addDevice(fixed, id: const Uuid('dev-1')));

      expect(controller.undo.undoLabelKey, LabelKey.addDevice.name);
    });

    test('A REFUSED EDIT ACQUIRES NO CONSEQUENCE, so a command that changed '
        'nothing still makes no history (DR-156)', () {
      final doc = _docWithRack(fixed);
      var calls = 0;
      final controller = DocumentController(doc, clock: FixedClock(fixed))
        ..addConsequence((tx) {
          calls++;
          tx.add(_MarkCommand(_rackId, 'consequence'));
        })
        ..run(_RefusingCommand());

      expect(calls, 0, reason: 'the hook is not even asked');
      expect(controller.undo.canUndo, isFalse);
      expect(doc.racks[_rackId]!.name, 'DC Test Rack');
    });

    test('the hook is told WHAT THE EDIT TOUCHES, so it can sit out the ones '
        'it does not care about', () {
      final doc = _docWithRack(fixed);
      EpochMask? seen;
      DocumentController(doc, clock: FixedClock(fixed))
        ..addConsequence((tx) => seen = tx.touches)
        ..run(_addDevice(fixed, id: const Uuid('dev-1')));

      expect(seen, isNotNull);
      expect(seen!.has(EpochMask.structure), isTrue);
      expect(seen!.has(EpochMask.sheet), isFalse);
    });

    test('A HOOK THAT ADDS NOTHING CHANGES NOTHING, which is the common case '
        'once the sheet is already frozen', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed))
        ..addConsequence((tx) {})
        ..run(_addDevice(fixed, id: const Uuid('dev-1')));

      expect(controller.undo.undoLabelKey, LabelKey.addDevice.name);
      controller.undoLast();
      expect(doc.devices, isEmpty);
    });

    test('the returned remover takes it off again, so a screen that is gone '
        'stops writing to documents it no longer shows', () {
      final doc = _docWithRack(fixed);
      final controller = DocumentController(doc, clock: FixedClock(fixed));
      final stop = controller.addConsequence(
        (tx) => tx.add(_MarkCommand(_rackId, 'consequence')),
      );
      stop();
      controller.run(_addDevice(fixed, id: const Uuid('dev-1')));

      expect(doc.racks[_rackId]!.name, 'DC Test Rack');
    });

    test('a NESTED transaction fires the hook ONCE, at the outermost commit, '
        'because that is the entry the person will undo', () {
      final doc = _docWithRack(fixed);
      var calls = 0;
      DocumentController(doc, clock: FixedClock(fixed))
        ..addConsequence((tx) => calls++)
        ..transact(null, (tx) {
          tx
            ..add(_addDevice(fixed, id: const Uuid('dev-1')))
            ..add(_addDevice(fixed, id: const Uuid('dev-2'), ruIndex: 2));
        });

      expect(calls, 1);
    });
  });
}

/// Renames the rack, so a consequence is visible in the document without
/// a second fixture.
final class _MarkCommand extends Command<RackDocument> {
  _MarkCommand(this.rackId, this.name);

  final Uuid rackId;
  final String name;
  String? _before;

  @override
  LabelKey get label => LabelKey.renameEntity;

  @override
  EpochMask get touches => EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [rackId];

  @override
  bool apply(RackDocument doc) {
    final rack = doc.racks[rackId];
    if (rack == null || rack.name == name) return false;
    _before = rack.name;
    rack.name = name;
    return true;
  }

  @override
  void revert(RackDocument doc) {
    final before = _before;
    if (before == null) throw StateError('_MarkCommand.revert before apply().');
    doc.racks[rackId]!.name = before;
  }
}

/// Changes nothing and says so, which `RemoveDeviceCommand` does not: it
/// returns `true` even when the id names no device, so it cannot stand in
/// for a refusal here.
final class _RefusingCommand extends Command<RackDocument> {
  @override
  LabelKey get label => LabelKey.renameEntity;

  @override
  EpochMask get touches => EpochMask.structure;

  @override
  Iterable<Uuid> get affects => const [];

  @override
  bool apply(RackDocument doc) => false;

  @override
  void revert(RackDocument doc) =>
      throw StateError('_RefusingCommand.revert before apply().');
}
