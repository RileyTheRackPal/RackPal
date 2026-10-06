// ignore_for_file: cascade_invocations, an apply/revert pair with
// assertions BETWEEN the two calls is the shape most of these tests take —
// checking the state after apply is what makes the check after revert mean
// anything. Collapsing the pair into a cascade would delete the
// intermediate assertion, which is the opposite of a simplification.
//
// `RackField`, the accessor table docs/04 §4's twelve editable rack
// properties live in. The apply/revert/byte-identity property is covered
// generically by command_roundtrip_test.dart; this file covers what is
// specific to ONE class serving twelve fields — per-field merge keys,
// per-field epoch masks, and the table's own integrity.
//
// THE FILE IS NAMED FOR THE TABLE, NOT THE COMMAND, since board #578: the
// command it used to be named for (`SetRackPropertyCommand`) was folded
// into `SetEntityPropertyCommand`, which now serves five entity kinds. The
// twelve rows, their keys, their masks and the Edit menu's word for a rack
// edit all survived that fold unchanged, and this file is what says so.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _rackId = Uuid('rack-props');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'seed',
);

RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('doc-props'),
    appVersion: '0.1.0',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Props Rack',
    designator: 'RK-1',
    heightU: 24,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  return doc;
}

Rack _rack(RackDocument doc) => doc.racks[_rackId]!;

SetEntityPropertyCommand<Rack, T> _cmd<T>(
  EntityField<Rack, T> field,
  T from,
  T to, {
  DateTime? now,
}) => SetEntityPropertyCommand<Rack, T>(
  id: _rackId,
  field: field,
  from: from,
  to: to,
  now: now ?? DateTime.utc(2026, 1, 2),
  actor: 'tester',
);

void main() {
  group('the accessor table', () {
    test('every key is unique — a duplicate would silently merge two '
        'unrelated properties into one undo entry', () {
      final keys = RackField.all.map((f) => f.key).toList();

      expect(keys.toSet(), hasLength(keys.length));
    });

    // DR-239's envelope joined docs/04 §4's twelve at `#1012`.
    test("covers §4's fields and DR-239's envelope", () {
      expect(RackField.all.map((f) => f.key).toSet(), {
        'designator',
        'locationId',
        'ruNumbering',
        'mirrorRearElevation',
        'widthClass',
        'railType',
        'formFactor',
        'usableDepth',
        'weightCapacity',
        'isSwingFrame',
        'hingeSide',
        'groundBarPresent',
        'overallDepth',
        'overallWidth',
        'overallHeight',
        'ownWeight',
        'hasFrontDoor',
        'hasRearDoor',
        'frontDoorClearance',
        'rearDoorClearance',
        'frontRailClearance',
        'rearRailClearance',
      });
    });

    test('every field declares a non-empty epoch mask', () {
      for (final f in RackField.all) {
        expect(f.touches.bits, isNot(0), reason: f.key);
      }
    });

    test('identity fields touch meta; geometry fields touch rack', () {
      expect(RackField.designator.touches.has(EpochMask.meta), isTrue);
      expect(RackField.locationId.touches.has(EpochMask.meta), isTrue);
      for (final f in [
        RackField.widthClass,
        RackField.railType,
        RackField.formFactor,
        RackField.usableDepth,
        RackField.weightCapacity,
        RackField.isSwingFrame,
        RackField.hingeSide,
        RackField.groundBarPresent,
        RackField.overallDepth,
        RackField.overallWidth,
        RackField.overallHeight,
        RackField.ownWeight,
        RackField.hasFrontDoor,
        RackField.hasRearDoor,
        RackField.frontDoorClearance,
        RackField.rearDoorClearance,
        RackField.frontRailClearance,
        RackField.rearRailClearance,
      ]) {
        expect(f.touches.has(EpochMask.rack), isTrue, reason: f.key);
      }
    });

    // THIS CASE USED TO ASSERT THE DEFECT (`#933`). It required `style` on
    // both fields, and `style` is the epoch the Schematic reads as a
    // re-layout, so a ruler preference froze the schematic into the file.
    // The artifact half, a toggle that writes no sheet, is asserted on the
    // mounted Schematic in `schematic_freeze_layout_test.dart`.
    test('the two display-only fields declare rack and nothing the '
        'Schematic re-lays out for', () {
      for (final f in [
        RackField.ruNumbering,
        RackField.mirrorRearElevation,
      ]) {
        expect(f.touches.has(EpochMask.rack), isTrue, reason: f.key);
        expect(f.touches.has(EpochMask.style), isFalse, reason: f.key);
        expect(f.touches.has(EpochMask.structure), isFalse, reason: f.key);
      }
    });

    test('get and set round-trip through a real Rack for every field', () {
      final doc = _doc();
      final rack = _rack(doc);

      // Each pair is (fresh value, a second distinct value) so the test
      // cannot pass by the field already holding the value written.
      void check<T>(EntityField<Rack, T> f, T a, T b) {
        f.set(rack, a);
        expect(f.get(rack), a, reason: '${f.key} -> a');
        f.set(rack, b);
        expect(f.get(rack), b, reason: '${f.key} -> b');
      }

      check(RackField.designator, 'RK-9', 'RK-2');
      check(RackField.locationId, const Uuid('loc-1'), null);
      check(
        RackField.ruNumbering,
        RuNumbering.topDown,
        RuNumbering.bottomUpFromOne,
      );
      check(RackField.mirrorRearElevation, false, true);
      check(
        RackField.widthClass,
        RackWidthClass.eia23,
        RackWidthClass.tenInch,
      );
      check(RackField.railType, RailType.m6, RailType.squareCageNut);
      check(
        RackField.formFactor,
        RackFormFactor.openFrame2Post,
        RackFormFactor.portableCase,
      );
      check(RackField.usableDepth, const Len(600000000), null);
      check(RackField.weightCapacity, const Mass(400000000000), null);
      check(RackField.isSwingFrame, true, false);
      check(RackField.hingeSide, HingeSide.right, null);
      check(RackField.groundBarPresent, true, false);
      check(RackField.overallDepth, const Len(1000000000), null);
      check(RackField.overallWidth, const Len(600000000), null);
      check(RackField.overallHeight, const Len(2000000000), null);
      check(RackField.ownWeight, const Mass(68000000000), null);
      check(RackField.hasFrontDoor, true, false);
      check(RackField.hasRearDoor, true, false);
      check(RackField.frontDoorClearance, const Len(600000000), null);
      check(RackField.rearDoorClearance, const Len(550000000), null);
      check(RackField.frontRailClearance, const Len(75000000), null);
      check(RackField.rearRailClearance, const Len(120000000), null);
    });
  });

  group('apply / revert', () {
    test('writes the value and restores it exactly, including the meta '
        'triple', () {
      final doc = _doc();
      final rack = _rack(doc);
      final beforeAt = rack.meta.updatedAt;
      final beforeBy = rack.meta.updatedBy;
      final beforeRev = rack.meta.localRevision;
      final cmd = _cmd(
        RackField.widthClass,
        RackWidthClass.eia19,
        RackWidthClass.etsi,
      );

      cmd.apply(doc);
      expect(rack.widthClass, RackWidthClass.etsi);
      expect(rack.meta.updatedBy, 'tester');

      cmd.revert(doc);
      expect(rack.widthClass, RackWidthClass.eia19);
      expect(rack.meta.updatedAt, beforeAt);
      expect(rack.meta.updatedBy, beforeBy);
      expect(
        rack.meta.localRevision,
        beforeRev,
        reason:
            'a revision left one higher than before apply is exactly '
            'what breaks CR-117 byte identity',
      );
    });

    test('is idempotent under alternation (apply; revert; apply)', () {
      final once = _doc();
      final thrice = _doc();

      _cmd(RackField.groundBarPresent, false, true).apply(once);
      _cmd(RackField.groundBarPresent, false, true)
        ..apply(thrice)
        ..revert(thrice)
        ..apply(thrice);

      // Two documents, one command each: `apply` alone versus
      // `apply; revert; apply`. docs/03-architecture.md §5.1's law is that
      // these land in the identical state.
      expect(_rack(thrice).groundBarPresent, _rack(once).groundBarPresent);
      expect(_rack(thrice).groundBarPresent, isTrue);
      expect(
        _rack(thrice).meta.localRevision,
        _rack(once).meta.localRevision,
        reason:
            'the meta triple must land identically too, or CR-117 '
            'byte identity fails on any sequence containing a redo',
      );
    });

    test('a nullable field round-trips through null in both directions', () {
      final doc = _doc();
      final setIt = _cmd<Len?>(
        RackField.usableDepth,
        null,
        const Len(600000000),
      );

      setIt.apply(doc);
      expect(_rack(doc).usableDepth, const Len(600000000));
      setIt.revert(doc);
      expect(
        _rack(doc).usableDepth,
        isNull,
        reason:
            'unset must survive a round trip as unset, not as zero '
            '(CR-114)',
      );

      final clearIt = _cmd<Len?>(
        RackField.usableDepth,
        const Len(600000000),
        null,
      );
      _rack(doc).usableDepth = const Len(600000000);
      clearIt.apply(doc);
      expect(_rack(doc).usableDepth, isNull);
      clearIt.revert(doc);
      expect(_rack(doc).usableDepth, const Len(600000000));
    });

    test('revert before apply throws rather than silently corrupting the '
        'meta triple', () {
      final doc = _doc();

      expect(
        () => _cmd(RackField.isSwingFrame, false, true).revert(doc),
        throwsStateError,
      );
    });
  });

  group('merge behaviour — coalescing is PER PROPERTY', () {
    test('two edits to the same field on the same rack merge, keeping the '
        'ORIGINAL from-value', () {
      final first = _cmd(RackField.designator, 'RK-1', 'RK-2');
      final second = _cmd(RackField.designator, 'RK-2', 'RK-3');

      final merged =
          first.mergeWith(second)! as SetEntityPropertyCommand<Rack, String>;

      expect(merged.from, 'RK-1');
      expect(merged.to, 'RK-3');
    });

    test('a merged command reverts all the way to the original value', () {
      final doc = _doc();
      final first = _cmd(RackField.designator, 'RK-1', 'RK-2')..apply(doc);
      final second = _cmd(RackField.designator, 'RK-2', 'RK-3')..apply(doc);
      expect(_rack(doc).designator, 'RK-3');

      first.mergeWith(second)!.revert(doc);

      expect(_rack(doc).designator, 'RK-1');
      expect(
        _rack(doc).meta.localRevision,
        0,
        reason:
            'the merged command must carry the meta snapshot captured '
            'by the FIRST command forward, not the second one',
      );
    });

    test('two DIFFERENT fields never merge', () {
      final designator = _cmd(RackField.designator, 'RK-1', 'RK-2');
      final ground = _cmd(RackField.groundBarPresent, false, true);

      expect(designator.mergeWith(ground), isNull);
      expect(designator.mergeKey == ground.mergeKey, isFalse);
    });

    test('the same field on two different racks never merges', () {
      final a = _cmd(RackField.groundBarPresent, false, true);
      final b = SetEntityPropertyCommand<Rack, bool>(
        id: const Uuid('other-rack'),
        field: RackField.groundBarPresent,
        from: false,
        to: true,
        now: DateTime.utc(2026),
        actor: 't',
      );

      expect(a.mergeWith(b), isNull);
      expect(a.mergeKey == b.mergeKey, isFalse);
    });

    test('mergeKey is equal for the same (field, rack) and distinct '
        'otherwise', () {
      expect(
        _cmd(RackField.designator, 'a', 'b').mergeKey,
        _cmd(RackField.designator, 'b', 'c').mergeKey,
      );

      final keys = {
        for (final f in RackField.all)
          SetEntityPropertyCommand<Rack, Object?>(
            id: _rackId,
            field: f,
            from: null,
            to: null,
            now: DateTime.utc(2026),
            actor: 't',
          ).mergeKey,
      };
      expect(keys, hasLength(RackField.all.length));
    });

    test('does not merge with an unrelated command type', () {
      expect(
        _cmd(RackField.designator, 'a', 'b').mergeWith(
          SetRackHeightCommand(
            id: _rackId,
            fromHeightU: 24,
            toHeightU: 12,
            now: DateTime.utc(2026),
            actor: 't',
          ),
        ),
        isNull,
      );
    });
  });

  group('buildSetEntityProperty, on a rack', () {
    test('returns null when the value is already what was asked for', () {
      final doc = _doc();

      expect(
        buildSetEntityProperty(
          doc: doc,
          id: _rackId,
          field: RackField.groundBarPresent,
          to: false,
          now: DateTime.utc(2026),
          actor: 't',
        ),
        isNull,
        reason:
            'a no-op must be distinguishable from a real edit so the '
            'caller does not push an empty undo entry',
      );
    });

    test('captures the CURRENT value as `from`', () {
      final doc = _doc();
      _rack(doc).railType = RailType.m6;

      final cmd = buildSetEntityProperty(
        doc: doc,
        id: _rackId,
        field: RackField.railType,
        to: RailType.roundClearance,
        now: DateTime.utc(2026),
        actor: 't',
      )!;

      expect(cmd.from, RailType.m6);
      expect(cmd.to, RailType.roundClearance);
    });

    test('handles the null-to-value and value-to-null transitions', () {
      final doc = _doc();

      final set = buildSetEntityProperty<Rack, Mass?>(
        doc: doc,
        id: _rackId,
        field: RackField.weightCapacity,
        to: const Mass(400000000000),
        now: DateTime.utc(2026),
        actor: 't',
      )!;
      expect(set.from, isNull);
      set.apply(doc);

      final clear = buildSetEntityProperty<Rack, Mass?>(
        doc: doc,
        id: _rackId,
        field: RackField.weightCapacity,
        to: null,
        now: DateTime.utc(2026),
        actor: 't',
      )!;
      expect(clear.from, const Mass(400000000000));
      expect(clear.to, isNull);
    });

    test('an unknown rack id throws rather than returning null — that is a '
        'caller bug, not a no-op', () {
      expect(
        () => buildSetEntityProperty(
          doc: _doc(),
          id: const Uuid('nope'),
          field: RackField.groundBarPresent,
          to: true,
          now: DateTime.utc(2026),
          actor: 't',
        ),
        throwsArgumentError,
      );
    });
  });

  group('Rack.heightU asserts CR-038 on the command path', () {
    test('rejects a height below 1 and above 60', () {
      final rack = _rack(_doc());

      expect(() => rack.heightU = 0, throwsA(isA<AssertionError>()));
      expect(() => rack.heightU = 61, throwsA(isA<AssertionError>()));
      expect(() => rack.heightU = -5, throwsA(isA<AssertionError>()));
    });

    test('accepts both ends of the legal range', () {
      final rack = _rack(_doc());

      rack.heightU = 1;
      expect(rack.heightU, 1);
      rack.heightU = 60;
      expect(rack.heightU, 60);
    });

    test('the CONSTRUCTOR does not assert — the decode path must be able '
        'to load a hostile file without crashing', () {
      expect(
        () => Rack(
          id: const Uuid('weird'),
          name: 'Out of range',
          designator: 'RK-X',
          heightU: 999,
          order: const FracIndex('a0'),
          meta: _meta(),
        ),
        returnsNormally,
      );
    });
  });
}
