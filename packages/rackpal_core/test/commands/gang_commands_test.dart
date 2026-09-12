// M3-H/1 (#166) and DR-047. The five gestures that make `Outlet.gangs`
// reachable, and the invariants they exist to hold: one link end in one
// cell, a resize that loses keystones says so first, and an opening
// somebody brushed is not an opening nobody has fitted.
//
// Every case asserts the DOCUMENT after apply and after revert, not the
// command's internal before-values. A test that pinned `_vacated`
// directly would survive the move being deleted.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 11);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _outletId = Uuid('22222222-2222-4222-8222-222222222222');
const _bodyId = Uuid('11111111-1111-4111-8111-111111111111');
const _linkA = Uuid('33333333-3333-4333-8333-333333333333');
const _linkB = Uuid('44444444-4444-4444-8444-444444444444');

RackDocument _doc({List<Gang>? gangs}) {
  final doc = RackDocument(
    id: const Uuid('doc-gang'),
    appVersion: 'test',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  );
  doc.outlets[_outletId] = Outlet(
    id: _outletId,
    structureBodyId: _bodyId,
    designation: 'WP-1',
    order: const FracIndex('a0'),
    meta: _meta(),
    gangs: gangs,
  );
  return doc;
}

Outlet _outletOf(RackDocument doc) => doc.outlets[_outletId]!;

void main() {
  group('a gang can be added, and a new one has chosen no part', () {
    test('+ Add gang produces a gang with no strap, not a 1-port', () {
      final doc = _doc();
      AddGangCommand(outletId: _outletId).apply(doc);
      expect(_outletOf(doc).gangs, hasLength(1));
      // NOT Strap(1,1). A default part is a purchase nobody made (G4).
      expect(_outletOf(doc).gangs.single.fitting, isNull);
    });

    test('a gang added with a size gets exactly that strap', () {
      final doc = _doc();
      AddGangCommand(outletId: _outletId, width: 2, height: 3).apply(doc);
      expect((_outletOf(doc).gangs.single.fitting! as Strap).cellCount, 6);
    });

    test('apply; revert; apply lands where a single apply lands', () {
      final doc = _doc();
      final cmd = AddGangCommand(outletId: _outletId, width: 1, height: 2)
        ..apply(doc)
        ..revert(doc);
      expect(_outletOf(doc).gangs, isEmpty);
      cmd.apply(doc);
      expect(_outletOf(doc).gangs, hasLength(1));
      expect((_outletOf(doc).gangs.single.fitting! as Strap).cellCount, 2);
    });
  });

  group('removing a gang takes its cells and undo brings them back', () {
    test('a removed gang restores with every occupant it held', () {
      final strap = Strap(width: 1, height: 3);
      strap.cells[0] = const LinkEndOccupant(_linkA);
      strap.cells[2] = const BlankInsert();
      final doc = _doc(
        gangs: [
          Gang(),
          Gang(fitting: strap),
        ],
      );

      final cmd = RemoveGangCommand(outletId: _outletId, index: 1)..apply(doc);
      expect(_outletOf(doc).gangs, hasLength(1));

      cmd.revert(doc);
      final restored = _outletOf(doc).gangs[1].fitting! as Strap;
      // The cells cannot be rebuilt from anything else in the document:
      // structureOrigin says WHICH OUTLET and never which cell.
      expect(restored.cells[0], const LinkEndOccupant(_linkA));
      expect(restored.cells[2], const BlankInsert());
      expect(restored.undecidedCount, 1);
    });

    test('a gang index that does not exist changes nothing', () {
      final doc = _doc(gangs: [Gang()]);
      RemoveGangCommand(outletId: _outletId, index: 7).apply(doc);
      expect(_outletOf(doc).gangs, hasLength(1));
    });
  });

  group('shrinking a strap loses cells, and the count is askable first', () {
    test('occupantsLostByResize counts before anything is committed', () {
      final strap = Strap(width: 2, height: 3);
      strap.cells[0] = const LinkEndOccupant(_linkA);
      strap.cells[4] = const BlankInsert();
      strap.cells[5] = const ConductorOccupant(ConductorRef(_linkB, 0));
      final gang = Gang(fitting: strap);

      // 2x3 -> 1x2 keeps cells 0 and 1; 4 and 5 go.
      expect(occupantsLostByResize(gang, 1, 2), 2);
      // Widening loses nothing.
      expect(occupantsLostByResize(gang, 2, 3), 0);
      // The document is untouched by asking.
      expect(strap.cells, hasLength(3));
    });

    test('the shrink drops the out-of-range cells and undo restores them', () {
      final strap = Strap(width: 2, height: 3);
      strap.cells[0] = const LinkEndOccupant(_linkA);
      strap.cells[5] = const BlankInsert();
      final doc = _doc(gangs: [Gang(fitting: strap)]);

      final cmd = SetStrapSizeCommand(
        outletId: _outletId,
        index: 0,
        width: 1,
        height: 2,
      )..apply(doc);
      final after = _outletOf(doc).gangs[0].fitting! as Strap;
      expect(after.cellCount, 2);
      expect(after.cells[0], const LinkEndOccupant(_linkA));
      expect(after.cells.containsKey(5), isFalse);

      cmd.revert(doc);
      final back = _outletOf(doc).gangs[0].fitting! as Strap;
      expect(back.cellCount, 6);
      expect(back.cells[5], const BlankInsert());
    });

    test('a strap can be un-chosen back to undecided', () {
      final doc = _doc(gangs: [Gang(fitting: Strap(width: 1, height: 1))]);
      SetStrapSizeCommand(
        outletId: _outletId,
        index: 0,
        width: null,
        height: null,
      ).apply(doc);
      expect(_outletOf(doc).gangs[0].fitting, isNull);
    });
  });

  group('one link end lands in exactly one cell', () {
    test('assigning a jack that sits elsewhere VACATES the old cell', () {
      final doc = _doc(gangs: [Gang(fitting: Strap(width: 2, height: 3))]);
      SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 0,
        cellIndex: 0,
        occupant: const LinkEndOccupant(_linkA),
      ).apply(doc);

      final move = SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 0,
        cellIndex: 4,
        occupant: const LinkEndOccupant(_linkA),
      )..apply(doc);

      final strap = _outletOf(doc).gangs[0].fitting! as Strap;
      // ONE cell, not two. A plate drawing showing LR-DATA-1 twice is
      // wrong in the way a printed sheet is wrong: silently.
      expect(strap.cells[4], const LinkEndOccupant(_linkA));
      expect(strap.cells.containsKey(0), isFalse);

      move.revert(doc);
      expect(strap.cells[0], const LinkEndOccupant(_linkA));
      expect(strap.cells.containsKey(4), isFalse);
    });

    test('the move reaches across gangs of the same outlet', () {
      final doc = _doc(
        gangs: [
          Gang(fitting: Strap(width: 1, height: 1)),
          Gang(fitting: Strap(width: 1, height: 1)),
        ],
      );
      SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 0,
        cellIndex: 0,
        occupant: const LinkEndOccupant(_linkA),
      ).apply(doc);
      SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 1,
        cellIndex: 0,
        occupant: const LinkEndOccupant(_linkA),
      ).apply(doc);

      expect((_outletOf(doc).gangs[0].fitting! as Strap).cells, isEmpty);
      expect(
        (_outletOf(doc).gangs[1].fitting! as Strap).cells[0],
        const LinkEndOccupant(_linkA),
      );
    });

    test('TWO BLANKS ARE TWO PARTS and neither displaces the other', () {
      final doc = _doc(gangs: [Gang(fitting: Strap(width: 2, height: 3))]);
      for (final cell in [4, 5]) {
        SetCellOccupantCommand(
          outletId: _outletId,
          gangIndex: 0,
          cellIndex: cell,
          occupant: const BlankInsert(),
        ).apply(doc);
      }
      // Uniqueness is a fact about a LINK END. A blank has no link end,
      // and a six-port strap with two blanks in it is two purchases.
      expect((_outletOf(doc).gangs[0].fitting! as Strap).cells, hasLength(2));
    });

    test('two conductors of one link are two occupants, not a duplicate', () {
      final doc = _doc(gangs: [Gang(fitting: Strap(width: 2, height: 2))]);
      SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 0,
        cellIndex: 0,
        occupant: const ConductorOccupant(ConductorRef(_linkB, 0)),
      ).apply(doc);
      SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 0,
        cellIndex: 1,
        occupant: const ConductorOccupant(ConductorRef(_linkB, 1)),
      ).apply(doc);
      // A 16/2 speaker drop is two posts. Collapsing them would make the
      // most common speaker plate in the building undrawable.
      expect((_outletOf(doc).gangs[0].fitting! as Strap).cells, hasLength(2));
    });
  });

  group('clearing a cell and blanking it are different gestures', () {
    test('null clears back to UNDECIDED, which is not a blank', () {
      final doc = _doc(gangs: [Gang(fitting: Strap(width: 1, height: 2))]);
      SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 0,
        cellIndex: 0,
        occupant: const LinkEndOccupant(_linkA),
      ).apply(doc);

      final clear = SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 0,
        cellIndex: 0,
        occupant: null,
      )..apply(doc);

      final strap = _outletOf(doc).gangs[0].fitting! as Strap;
      expect(strap.cells.containsKey(0), isFalse);
      expect(strap.undecidedCount, 2);
      // And the artifact that matters: an undecided cell orders no part.
      expect(
        computePlateFill(_outletOf(doc), const <Link>[]).blanksFitted,
        0,
      );

      clear.revert(doc);
      expect(strap.cells[0], const LinkEndOccupant(_linkA));
    });

    test('a cell index outside the strap changes nothing', () {
      final doc = _doc(gangs: [Gang(fitting: Strap(width: 1, height: 1))]);
      SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 0,
        cellIndex: 9,
        occupant: const BlankInsert(),
      ).apply(doc);
      expect((_outletOf(doc).gangs[0].fitting! as Strap).cells, isEmpty);
    });

    test('a gang with no strap accepts nothing', () {
      final doc = _doc(gangs: [Gang()]);
      SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 0,
        cellIndex: 0,
        occupant: const BlankInsert(),
      ).apply(doc);
      expect(_outletOf(doc).gangs[0].fitting, isNull);
    });
  });

  group('the whole plate survives a write and a read', () {
    test('commanded gangs round-trip byte-exactly (CR-117)', () {
      const codec = JsonDocumentCodec();
      final doc = _doc();
      AddGangCommand(outletId: _outletId, width: 2, height: 3).apply(doc);
      AddGangCommand(outletId: _outletId).apply(doc);
      SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 0,
        cellIndex: 3,
        occupant: const LinkEndOccupant(_linkA),
      ).apply(doc);
      SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 0,
        cellIndex: 5,
        occupant: const BlankInsert(),
      ).apply(doc);

      final first = codec.write(doc);
      final reread = codec.read(first);
      expect(reread, isA<Ok<RackDocument>>());
      expect(codec.write((reread as Ok<RackDocument>).value), equals(first));
    });
  });

  group('a pass-through is fitted, and it is not an absence (DR-047)', () {
    test('it replaces a strap and undo brings every keystone back', () {
      final doc = _doc(gangs: [Gang(fitting: Strap(width: 2, height: 3))]);
      SetCellOccupantCommand(
        outletId: _outletId,
        gangIndex: 0,
        cellIndex: 4,
        occupant: const LinkEndOccupant(_linkA),
      ).apply(doc);

      final cmd = SetGangPassThroughCommand(
        outletId: _outletId,
        index: 0,
        style: PassThroughStyle.brush,
      )..apply(doc);
      expect(
        _outletOf(doc).gangs.single.fitting,
        const PassThrough(PassThroughStyle.brush),
      );

      // THE SAME COMMAND OBJECT REVERTS, never a fresh one. A second
      // instance holds no before-value and would no-op while the case
      // passed, which is exactly how an earlier undo case in this file
      // asserted nothing.
      cmd.revert(doc);
      final back = _outletOf(doc).gangs.single.fitting! as Strap;
      expect(back.cellCount, 6);
      expect(back.cells[4], const LinkEndOccupant(_linkA));
    });

    test('fitting a strap over a brush reverts to the brush, not to null', () {
      // The difference between `GangFitting? _before` and `Strap? _before`,
      // and it is the whole reason SetStrapSizeCommand changed: undoing
      // "I fitted a 2-port here" over a brushed opening must give the
      // brush back rather than a blank question mark.
      final doc = _doc(
        gangs: [Gang(fitting: const PassThrough(PassThroughStyle.bullNose))],
      );
      final cmd = SetStrapSizeCommand(
        outletId: _outletId,
        index: 0,
        width: 1,
        height: 2,
      )..apply(doc);
      expect(_outletOf(doc).gangs.single.fitting, isA<Strap>());

      cmd.revert(doc);
      expect(
        _outletOf(doc).gangs.single.fitting,
        const PassThrough(PassThroughStyle.bullNose),
      );
    });

    test('un-choosing a brushed gang takes it back to undecided', () {
      final doc = _doc(
        gangs: [Gang(fitting: const PassThrough(PassThroughStyle.brush))],
      );
      SetStrapSizeCommand(
        outletId: _outletId,
        index: 0,
        width: null,
        height: null,
      ).apply(doc);
      // A DIFFERENT STATE FROM THE BRUSH, and that is the ruling: nobody
      // has said, versus somebody said "a hole".
      expect(_outletOf(doc).gangs.single.fitting, isNull);
    });

    test('a brush loses no occupants, and the count says so', () {
      final brushed = Gang(
        fitting: const PassThrough(PassThroughStyle.brush),
      );
      expect(occupantsLostByPassThrough(brushed), 0);
      expect(occupantsLostByResize(brushed, 1, 1), 0);

      final full = Gang(
        fitting: Strap(width: 1, height: 2)
          ..cells[0] = const LinkEndOccupant(_linkA)
          ..cells[1] = const LinkEndOccupant(_linkB),
      );
      expect(occupantsLostByPassThrough(full), 2);
    });

    test('it round-trips byte for byte, and it is a new key (CR-117)', () {
      const codec = JsonDocumentCodec();
      final doc = _doc(
        gangs: [
          Gang(fitting: const PassThrough(PassThroughStyle.bullNose)),
          Gang(fitting: Strap(width: 1, height: 1)),
        ],
      );
      final first = codec.write(doc);
      final reread = codec.read(first);
      expect(reread, isA<Ok<RackDocument>>());
      expect(codec.write((reread as Ok<RackDocument>).value), equals(first));
      // THE STRAP KEY IS UNTOUCHED, which is why kSchemaVersion does not
      // move: no document in existence carries `passThrough`.
      expect(String.fromCharCodes(first), contains('"passThrough"'));
      expect(String.fromCharCodes(first), contains('"strap"'));
    });

    test('a gang claiming BOTH a strap and a pass-through is refused', () {
      // One opening holds one part. Malformed rather than
      // forward-compatible, like a 3-wide strap.
      //
      // THE FIXTURE IS BUILT BY DECODING RATHER THAN BY STRING SURGERY,
      // and the first draft of this case is why: the file is written with
      // a 2-space indent (CR-091), so a `replaceFirst('"strap":{', …)`
      // matched nothing, mutated nothing, and the case passed against an
      // untouched document while asserting a refusal.
      const codec = JsonDocumentCodec();
      final doc = _doc(gangs: [Gang(fitting: Strap(width: 1, height: 1))]);
      final json =
          jsonDecode(utf8.decode(codec.write(doc))) as Map<String, Object?>;
      final outlets =
          (json['document']! as Map<String, Object?>)['outlets']!
              as Map<String, Object?>;
      final outlet = outlets.values.single! as Map<String, Object?>;
      final gangs = outlet['gangs']! as List<Object?>;
      (gangs.single! as Map<String, Object?>)['passThrough'] = {
        'style': 'brush',
      };

      final result = codec.read(
        Uint8List.fromList(utf8.encode(jsonEncode(json))),
      );
      expect(result, isA<Err<RackDocument>>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // DR-156's SWEEP BROKE THIS ONE AND NOTHING CAUGHT IT
  // ═══════════════════════════════════════════════════════════════════
  // `SetStrapSizeCommand` with a null width and height "takes the gang
  // back to undecided", which its own doc calls a state a person can get
  // back to. The DR-156 sweep read that branch's early `return;` as a
  // refusal, like the twenty-three others, and it was the one that had
  // already written: the strap came off, the transaction dropped the
  // command, nothing repainted and Ctrl+Z had nothing to take back.
  //
  // Every case here reads the CONTROLLER rather than calling `apply`
  // directly, because calling `apply` is exactly what could not see it.
  group('DR-156 regression: un-choosing a fitting is a change', () {
    test('CLEARING A STRAP REACHES THE UNDO STACK, and one Ctrl+Z puts it '
        'back', () {
      final doc = _doc(gangs: [Gang(fitting: Strap(width: 2, height: 1))]);
      final controller = DocumentController(doc)
        ..run(
          SetStrapSizeCommand(
            outletId: _outletId,
            index: 0,
            width: null,
            height: null,
          ),
        );

      expect(
        _outletOf(doc).gangs[0].fitting,
        isNull,
        reason: 'the strap really did come off',
      );
      expect(
        controller.undo.canUndo,
        isTrue,
        reason: 'and the act reached the stack, which is what broke',
      );

      controller.undo.undo(doc);
      expect(_outletOf(doc).gangs[0].fitting, isA<Strap>());
    });

    test('and it wakes `structure`, so the plate repaints', () {
      final doc = _doc(gangs: [Gang(fitting: Strap(width: 2, height: 1))]);
      final controller = DocumentController(doc);
      final before = controller.epochs.structure.value;

      controller.run(
        SetStrapSizeCommand(
          outletId: _outletId,
          index: 0,
          width: null,
          height: null,
        ),
      );

      expect(controller.epochs.structure.value, greaterThan(before));
    });

    test('A REFUSAL STILL REFUSES, so the fix is not "always true"', () {
      // The gang index does not exist: nothing is written and nothing
      // reaches the stack.
      final doc = _doc(gangs: [Gang(fitting: Strap(width: 2, height: 1))]);
      final controller = DocumentController(doc)
        ..run(
          SetStrapSizeCommand(
            outletId: _outletId,
            index: 7,
            width: null,
            height: null,
          ),
        );

      expect(controller.undo.canUndo, isFalse);
      expect(_outletOf(doc).gangs[0].fitting, isA<Strap>());
    });
  });
}
