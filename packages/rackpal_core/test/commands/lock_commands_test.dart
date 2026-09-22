// `#913`, DR-186: `Ctrl+L` on both canvases.
//
// The two fields these commands write have been in the format since M0 and
// M2 and had no writer at all (§11.185.0), so what is asserted here is not
// only that the write lands but that the REFUSALS hold: a locked device
// does not move, and a command that changes nothing leaves no undo entry.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _now = DateTime.utc(2026, 9, 18, 10);

const _rack = Uuid('rk-1');
const _rail = Uuid('dev-rail');
const _shelf = Uuid('dev-shelf');
const _zeroU = Uuid('dev-0u');
const _offRack = Uuid('dev-off');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.t'),
  version: 1,
  contentHash: 'sha256:tpl.t',
);

DeviceInstance _device(Uuid id, String designator, Placement placement) =>
    DeviceInstance(
      id: id,
      kind: DeviceKind.rackDevice,
      templateRef: _templateRef,
      designator: designator,
      name: 'Device $designator',
      placement: placement,
      meta: _meta(),
    );

/// One of every placement a lock can mean something for, plus one it
/// cannot.
RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('doc-lock'),
    appVersion: '0.6.59',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.racks[_rack] = Rack(
    id: _rack,
    name: 'Head end',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
    zeroUChannels: [
      ZeroUChannel(
        id: 'ch-1',
        name: 'Left',
        side: ZeroUChannelSide.frontLeft,
        startU: 1,
        endU: 12,
      ),
    ],
  );
  doc.devices[_rail] = _device(
    _rail,
    'AMP-1',
    const RailPlacement(rackId: _rack, ruIndex: 3, face: Face.front),
  );
  doc.devices[_shelf] = _device(
    _shelf,
    'DEC-1',
    const ShelfPlacement(hostDeviceId: _rail, order: FracIndex('a0')),
  );
  doc.devices[_zeroU] = _device(
    _zeroU,
    'PDU-1',
    const ZeroUPlacement(
      rackId: _rack,
      channelId: 'ch-1',
      offsetFromChannelStart: Len.zero,
      orientation: ZeroUOrientation.vertical,
    ),
  );
  doc.devices[_offRack] = _device(
    _offRack,
    'SPK-1',
    const OffRackPlacement(),
  );
  return doc;
}

void main() {
  group('a lock holds a position (DR-186 §11.185.1)', () {
    test('every placement that HAS a position takes one, and one undo puts '
        'all three back', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          SetPlacementLockedCommand(
            deviceIds: [_rail, _shelf, _zeroU],
            locked: true,
          ),
        );

      for (final id in [_rail, _shelf, _zeroU]) {
        expect(
          placementLocked(doc.devices[id]!.placement),
          isTrue,
          reason: '$id did not take the lock',
        );
      }
      expect(controller.undo.undoLabelKey, LabelKey.lockPlacement.name);

      controller.undo.undo(doc);
      for (final id in [_rail, _shelf, _zeroU]) {
        expect(placementLocked(doc.devices[id]!.placement), isFalse);
      }
    });

    test('an off-rack device is SKIPPED, not refused, so a mixed selection '
        'still locks what it can', () {
      final doc = _doc();
      DocumentController(doc).run(
        SetPlacementLockedCommand(
          deviceIds: [_rail, _offRack],
          locked: true,
        ),
      );

      expect(placementLocked(doc.devices[_rail]!.placement), isTrue);
      expect(placementLocked(doc.devices[_offRack]!.placement), isNull);
    });

    test('a selection of nothing BUT those refuses, so no undo entry is '
        'left behind', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          SetPlacementLockedCommand(deviceIds: [_offRack], locked: true),
        );
      expect(controller.undo.undoLabelKey, isNull);
    });

    test('locking what is already locked changes nothing and says so '
        '(DR-156)', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(SetPlacementLockedCommand(deviceIds: [_rail], locked: true));
      final cmd = SetPlacementLockedCommand(
        deviceIds: [_rail],
        locked: true,
      );

      expect(cmd.apply(doc), isFalse);
      expect(() => cmd.revert(doc), throwsStateError);
      expect(controller.undo.undoLabelKey, LabelKey.lockPlacement.name);
    });

    test('unlocking names the opposite act', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(SetPlacementLockedCommand(deviceIds: [_rail], locked: true))
        ..run(SetPlacementLockedCommand(deviceIds: [_rail], locked: false));
      expect(controller.undo.undoLabelKey, LabelKey.unlockPlacement.name);
    });

    test('CR-117: apply, revert, apply lands on identical bytes', () {
      final doc = _doc();
      final before = _codec.write(doc);
      final cmd = SetPlacementLockedCommand(
        deviceIds: [_rail, _shelf],
        locked: true,
      )..apply(doc);
      final applied = _codec.write(doc);
      cmd
        ..revert(doc)
        ..apply(doc);

      expect(_codec.write(doc), applied);
      final undone = SetPlacementLockedCommand(
        deviceIds: [_rail, _shelf],
        locked: true,
      );
      expect(undone.apply(doc), isFalse, reason: 'already locked');
      cmd.revert(doc);
      expect(_codec.write(doc), before);
    });
  });

  group('a locked device does not move', () {
    MoveDeviceCommand move(int to) => MoveDeviceCommand(
      id: _rail,
      fromRuIndex: 3,
      toRuIndex: to,
      fromFace: Face.front,
      toFace: Face.front,
      now: _now,
      actor: 'test',
    );

    test('MoveDeviceCommand refuses, and writes nothing', () {
      final doc = _doc();
      SetPlacementLockedCommand(deviceIds: [_rail], locked: true).apply(doc);

      final cmd = move(7);
      expect(cmd.apply(doc), isFalse);
      expect((doc.devices[_rail]!.placement as RailPlacement).ruIndex, 3);
      expect(() => cmd.revert(doc), throwsStateError);
    });

    test('and the same device moves once it is unlocked, which is what '
        'makes the refusal above about the LOCK', () {
      final doc = _doc();
      DocumentController(doc)
        ..run(SetPlacementLockedCommand(deviceIds: [_rail], locked: true))
        ..run(SetPlacementLockedCommand(deviceIds: [_rail], locked: false))
        ..run(move(7));
      expect((doc.devices[_rail]!.placement as RailPlacement).ruIndex, 7);
    });

    test('A MOVE TO WHERE IT ALREADY IS is not a move, so it is not '
        'refused: undo/redo replays it over a locked device', () {
      final doc = _doc();
      SetPlacementLockedCommand(deviceIds: [_rail], locked: true).apply(doc);
      expect(move(3).apply(doc), isTrue);
    });
  });

  group('a bottom trim asks who is locked (DR-186 §11.185.1)', () {
    test('it names the locked rail devices in THIS rack, in designator '
        'order', () {
      final doc = _doc();
      doc.devices[const Uuid('dev-rail-2')] = _device(
        const Uuid('dev-rail-2'),
        'AAA-9',
        const RailPlacement(rackId: _rack, ruIndex: 8, face: Face.front),
      );
      SetPlacementLockedCommand(
        deviceIds: [_rail, const Uuid('dev-rail-2'), _zeroU],
        locked: true,
      ).apply(doc);

      expect(
        lockedAgainstBottomTrim(doc, _rack).map((d) => d.designator),
        ['AAA-9', 'AMP-1'],
        reason: 'a 0U occupant is not shifted by a bottom trim',
      );
    });

    test('and nothing at all when the locks are elsewhere', () {
      final doc = _doc();
      SetPlacementLockedCommand(deviceIds: [_rail], locked: true).apply(doc);
      expect(lockedAgainstBottomTrim(doc, const Uuid('rk-other')), isEmpty);
    });

    test('an unlocked rack is not named', () {
      expect(lockedAgainstBottomTrim(_doc(), _rack), isEmpty);
    });
  });

  group('a pin holds a symbol (DR-186 §11.185.3)', () {
    const where = Pt(96, 40);

    test('THE FIRST PIN CREATES THE ONE SHEET, and a second pin reuses it', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          SetSymbolPinnedCommand(
            positions: {_rail: where},
            pinned: true,
            now: _now,
            actor: 'test',
          ),
        );

      final sheet = schematicSheetOf(doc);
      expect(sheet, isNotNull, reason: 'CR-073 had no producer before this');
      expect(doc.sheets, hasLength(1));
      expect(pinnedSymbolIds(doc), {_rail});
      expect(sheet!.items.values.single.position, where);

      controller.run(
        SetSymbolPinnedCommand(
          positions: {_shelf: const Pt(10, 10)},
          pinned: true,
          now: _now,
          actor: 'test',
        ),
      );
      expect(doc.sheets, hasLength(1), reason: 'exactly one, per CR-073');
      expect(pinnedSymbolIds(doc), {_rail, _shelf});
    });

    test('undo takes the sheet away again, so a document that never pinned '
        'is byte-identical to one that pinned and undid', () {
      // THE COMMAND DIRECTLY, not through the controller: every commit
      // and every undo advances the document's own `sequence` (CR-094), so
      // a round trip through the stack is byte-identical to nothing.
      final doc = _doc();
      final before = _codec.write(doc);
      SetSymbolPinnedCommand(
          positions: {_rail: where},
          pinned: true,
          now: _now,
          actor: 'test',
        )
        ..apply(doc)
        ..revert(doc);

      expect(doc.sheets, isEmpty);
      expect(_codec.write(doc), before);
    });

    test('REDO REUSES THE IDS, so anything resolved by id still resolves', () {
      final doc = _doc();
      final cmd = SetSymbolPinnedCommand(
        positions: {_rail: where},
        pinned: true,
        now: _now,
        actor: 'test',
      )..apply(doc);
      final first = schematicSheetOf(doc)!.id;
      final firstItem = schematicSheetOf(doc)!.items.keys.single;

      cmd
        ..revert(doc)
        ..apply(doc);

      expect(schematicSheetOf(doc)!.id, first);
      expect(schematicSheetOf(doc)!.items.keys.single, firstItem);
    });

    test('unpinning clears the flag and KEEPS the position, so the symbol '
        'does not jump when it is released', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          SetSymbolPinnedCommand(
            positions: {_rail: where},
            pinned: true,
            now: _now,
            actor: 'test',
          ),
        )
        ..run(
          SetSymbolPinnedCommand(
            positions: {_rail: const Pt(0, 0)},
            pinned: false,
            now: _now,
            actor: 'test',
          ),
        );

      final item = schematicSheetOf(doc)!.items.values.single;
      expect(item.pinned, isFalse);
      expect(item.position, where, reason: 'the stored position is kept');
      expect(controller.undo.undoLabelKey, LabelKey.unpinSymbol.name);
    });

    test('unpinning a document that never pinned refuses, rather than '
        'creating a sheet to hold nothing', () {
      final doc = _doc();
      final cmd = SetSymbolPinnedCommand(
        positions: {_rail: where},
        pinned: false,
        now: _now,
        actor: 'test',
      );
      expect(cmd.apply(doc), isFalse);
      expect(doc.sheets, isEmpty);
    });

    test('a device the document does not hold is skipped', () {
      final doc = _doc();
      final cmd = SetSymbolPinnedCommand(
        positions: {const Uuid('ghost'): where},
        pinned: true,
        now: _now,
        actor: 'test',
      );
      expect(cmd.apply(doc), isFalse);
      expect(doc.sheets, isEmpty);
    });
  });
}
