// `#914`, DR-187: the schematic holds its layout, and `Tidy sheet` is the
// way back out.
//
// The pair is tested together because neither is safe alone. The freeze
// writes `SheetItem` rows that DR-011.4 refused to write (canon §12.38),
// so what is asserted here is that it writes them ONLY when something is
// owed, never over a position somebody already placed, and that a tidy
// puts the document back to the shape it had before any of it.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _now = DateTime.utc(2026, 9, 22, 10);

const _a = Uuid('dev-a');
const _b = Uuid('dev-b');
const _c = Uuid('dev-c');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.t'),
  version: 1,
  contentHash: 'sha256:tpl.t',
);

DeviceInstance _device(Uuid id, String designator) => DeviceInstance(
  id: id,
  kind: DeviceKind.rackDevice,
  templateRef: _templateRef,
  designator: designator,
  name: 'Device $designator',
  placement: const OffRackPlacement(),
  meta: _meta(),
);

/// Three devices and no sheet: the state every document is in until
/// something freezes it (§11.186.2's *"a document nobody has edited still
/// carries no items at all"*).
RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('doc-sheet'),
    appVersion: '0.6.59',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.devices[_a] = _device(_a, 'AMP-1');
  doc.devices[_b] = _device(_b, 'DEC-1');
  doc.devices[_c] = _device(_c, 'SWT-1');
  return doc;
}

StoreSymbolPositionsCommand _store(Map<Uuid, Pt> positions) =>
    StoreSymbolPositionsCommand(
      positions: positions,
      now: _now,
      actor: 'test',
    );

Map<Uuid, SheetItem> _itemsByTarget(RackDocument doc) => {
  for (final item in schematicSheetOf(doc)?.items.values ?? const <SheetItem>[])
    item.targetId: item,
};

void main() {
  group('the freeze records what is owed (DR-187 §11.186.2)', () {
    test('THE FIRST FREEZE CREATES THE ONE SHEET and gives every symbol an '
        'UNPINNED position', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(_store({_a: const Pt(10, 20), _b: const Pt(30, 40)}));

      expect(doc.sheets, hasLength(1), reason: 'exactly one, per CR-073');
      final items = _itemsByTarget(doc);
      expect(items.keys, unorderedEquals([_a, _b]));
      expect(items[_a]!.position, const Pt(10, 20));
      expect(items[_b]!.position, const Pt(30, 40));
      expect(
        items.values.every((i) => !i.pinned),
        isTrue,
        reason: 'storing is not pinning (§11.186.3)',
      );
      expect(controller.undo.undoLabelKey, LabelKey.storeSymbolPositions.name);
    });

    test('A SYMBOL THAT ALREADY HAS A POSITION IS NOT OVERWRITTEN, which is '
        'the difference between recording a layout and moving one', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          SetSymbolPinnedCommand(
            positions: {_a: const Pt(96, 40)},
            pinned: true,
            now: _now,
            actor: 'test',
          ),
        )
        ..run(_store({_a: const Pt(0, 0), _b: const Pt(30, 40)}));

      final items = _itemsByTarget(doc);
      expect(items[_a]!.position, const Pt(96, 40));
      expect(items[_a]!.pinned, isTrue, reason: 'the pin survives a freeze');
      expect(items[_b]!.position, const Pt(30, 40));
      expect(controller.undo.undoLabelKey, LabelKey.storeSymbolPositions.name);
    });

    test('AN UNPINNED STORED POSITION COUNTS AS HELD TOO, so the second edit '
        'on a frozen sheet leaves no undo entry (DR-156)', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          _store({
            _a: const Pt(10, 20),
            _b: const Pt(30, 40),
            _c: const Pt(50, 60),
          }),
        );
      expect(controller.undo.undoLabelKey, LabelKey.storeSymbolPositions.name);

      final second = _store({_a: const Pt(1, 1), _b: const Pt(2, 2)});
      expect(second.apply(doc), isFalse);
      expect(() => second.revert(doc), throwsStateError);
      expect(_itemsByTarget(doc)[_a]!.position, const Pt(10, 20));
    });

    test('a device the document does not hold is skipped, and a freeze of '
        'nothing but ghosts refuses to create a sheet to hold them', () {
      final doc = _doc();
      final cmd = _store({const Uuid('ghost'): const Pt(10, 20)});
      expect(cmd.apply(doc), isFalse);
      expect(doc.sheets, isEmpty);
    });

    test('undo takes the sheet away again, so a document that was never '
        'frozen is byte-identical to one that froze and undid', () {
      // THE COMMAND DIRECTLY, not through the controller: every commit and
      // every undo advances the document's own `sequence` (CR-094).
      final doc = _doc();
      final before = _codec.write(doc);
      _store({_a: const Pt(10, 20), _b: const Pt(30, 40)})
        ..apply(doc)
        ..revert(doc);

      expect(doc.sheets, isEmpty);
      expect(_codec.write(doc), before);
    });

    test('an undo over a sheet that ALREADY EXISTED keeps the sheet and only '
        'removes what this command added', () {
      final doc = _doc();
      SetSymbolPinnedCommand(
        positions: {_a: const Pt(96, 40)},
        pinned: true,
        now: _now,
        actor: 'test',
      ).apply(doc);
      final before = _codec.write(doc);

      _store({_b: const Pt(30, 40)})
        ..apply(doc)
        ..revert(doc);

      expect(doc.sheets, hasLength(1));
      expect(_codec.write(doc), before);
    });

    test('REDO REUSES THE IDS, so anything resolved by id still resolves', () {
      final doc = _doc();
      final cmd = _store({_a: const Pt(10, 20), _b: const Pt(30, 40)})
        ..apply(doc);
      final sheetId = schematicSheetOf(doc)!.id;
      final itemIds = schematicSheetOf(doc)!.items.keys.toList()
        ..sort(
          (x, y) => x.v.compareTo(y.v),
        );

      cmd
        ..revert(doc)
        ..apply(doc);

      expect(schematicSheetOf(doc)!.id, sheetId);
      expect(
        schematicSheetOf(doc)!.items.keys.toList()
          ..sort((x, y) => x.v.compareTo(y.v)),
        itemIds,
      );
    });

    test('CR-117: apply, revert, apply lands on identical bytes', () {
      final doc = _doc();
      final cmd = _store({_a: const Pt(10, 20), _b: const Pt(30, 40)})
        ..apply(doc);
      final applied = _codec.write(doc);
      cmd
        ..revert(doc)
        ..apply(doc);
      expect(_codec.write(doc), applied);
    });
  });

  group('Tidy hands the sheet back to the layout (DR-187 §11.186.3)', () {
    test('every UNPINNED item goes and every PINNED one stays', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          SetSymbolPinnedCommand(
            positions: {_a: const Pt(96, 40)},
            pinned: true,
            now: _now,
            actor: 'test',
          ),
        )
        ..run(_store({_b: const Pt(30, 40), _c: const Pt(50, 60)}))
        ..run(TidySheetCommand());

      final items = _itemsByTarget(doc);
      expect(items.keys, [_a], reason: 'CR-068: a pin is never tidied away');
      expect(items[_a]!.position, const Pt(96, 40));
      expect(controller.undo.undoLabelKey, LabelKey.tidySheet.name);
    });

    test('wouldReflow COUNTS ONLY WHAT WOULD MOVE, which is the number the '
        'confirmation says out loud', () {
      final doc = _doc();
      expect(TidySheetCommand.wouldReflow(doc), 0, reason: 'no sheet yet');

      SetSymbolPinnedCommand(
        positions: {_a: const Pt(96, 40)},
        pinned: true,
        now: _now,
        actor: 'test',
      ).apply(doc);
      expect(TidySheetCommand.wouldReflow(doc), 0, reason: 'the pin is held');

      _store({_b: const Pt(30, 40), _c: const Pt(50, 60)}).apply(doc);
      expect(TidySheetCommand.wouldReflow(doc), 2);
    });

    test('a tidy with nothing to re-flow REFUSES, so the menu item leaves no '
        'undo entry on an already-tidy sheet', () {
      final doc = _doc();
      expect(TidySheetCommand().apply(doc), isFalse, reason: 'no sheet');

      SetSymbolPinnedCommand(
        positions: {_a: const Pt(96, 40)},
        pinned: true,
        now: _now,
        actor: 'test',
      ).apply(doc);
      final cmd = TidySheetCommand();
      expect(cmd.apply(doc), isFalse, reason: 'everything left is pinned');
      expect(() => cmd.revert(doc), throwsStateError);
      expect(_itemsByTarget(doc).keys, [_a]);
    });

    test('A TIDY UNDOES TO THE BYTES IT STARTED FROM, which is what makes the '
        'freeze safe to ship', () {
      final doc = _doc();
      _store({_a: const Pt(10, 20), _b: const Pt(30, 40)}).apply(doc);
      final frozen = _codec.write(doc);

      TidySheetCommand()
        ..apply(doc)
        ..revert(doc);

      expect(_codec.write(doc), frozen);
    });

    test('a tidy then a fresh freeze is the way a mess gets re-laid, and the '
        'sheet survives both', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(_store({_a: const Pt(10, 20), _b: const Pt(30, 40)}))
        ..run(TidySheetCommand())
        ..run(_store({_a: const Pt(7, 7), _b: const Pt(8, 8)}));

      expect(doc.sheets, hasLength(1), reason: 'the sheet is permanent');
      final items = _itemsByTarget(doc);
      expect(items[_a]!.position, const Pt(7, 7));
      expect(items[_b]!.position, const Pt(8, 8));
      expect(controller.undo.undoLabelKey, LabelKey.storeSymbolPositions.name);
    });
  });
}
