// Unit tests for CaretController: activation-rule combinations, the
// smart-default seed, move/home/end/pgup/pgdn stepping, and rack-height-
// change clamping (docs/04-rack-editor.md §3.4).

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _now = DateTime.utc(2026, 7, 18);

Rack _rack({int heightU = 12, String id = 'rk-1'}) => Rack(
  id: Uuid(id),
  name: 'Test Rack',
  designator: 'RK-1',
  heightU: heightU,
  order: const FracIndex('a0'),
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
);

void main() {
  group('activation formula (selectionEmpty && canvasHasFocus && '
      '!dragInProgress)', () {
    test('inactive until all three inputs hold', () {
      final caret = CaretController();
      final rack = _rack();

      caret.recompute(
        selectionEmpty: false,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 3,
      );
      expect(caret.active, isFalse);
      expect(caret.caret, isNull);

      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: false,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 3,
      );
      expect(caret.active, isFalse);

      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: true,
        rack: rack,
        smartDefaultRuIndex: 3,
      );
      expect(caret.active, isFalse);

      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 3,
      );
      expect(caret.active, isTrue);
      expect(caret.caret, isNotNull);
    });

    test('notifies listeners exactly when activation or position changes', () {
      final caret = CaretController();
      final rack = _rack();
      var notifications = 0;
      caret.addListener(() => notifications++);

      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 1,
      );
      expect(notifications, 1); // first seed + activation

      // Identical inputs again — no change, no notify.
      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 1,
      );
      expect(notifications, 1);

      // Selection becomes non-empty -> deactivates -> notifies once.
      caret.recompute(
        selectionEmpty: false,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 1,
      );
      expect(notifications, 2);
    });
  });

  group('smart default seeding', () {
    test('seeds at smartDefaultRuIndex the FIRST time only', () {
      final caret = CaretController();
      final rack = _rack();

      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 8,
      );
      expect(caret.caret!.ruIndex, 8);

      // A later recompute with a DIFFERENT smartDefaultRuIndex must NOT
      // reseed — the caret is sticky once established.
      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 1,
      );
      expect(caret.caret!.ruIndex, 8);
    });

    test('falls back to U1 when smartDefaultRuIndex is null (full rack)', () {
      final caret = CaretController();
      final rack = _rack();
      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: null,
      );
      expect(caret.caret!.ruIndex, 1);
    });

    test('re-seeds when the rack itself changes (different id)', () {
      final caret = CaretController();
      final rackA = _rack(id: 'rk-a');
      final rackB = _rack(id: 'rk-b');

      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rackA,
        smartDefaultRuIndex: 4,
      );
      expect(caret.caret!.rackId, rackA.id);

      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rackB,
        smartDefaultRuIndex: 9,
      );
      expect(caret.caret!.rackId, rackB.id);
      expect(caret.caret!.ruIndex, 9);
    });
  });

  group('sticky position across activation loss/regain', () {
    test('moveTo survives a focus loss and returns unchanged on regain', () {
      final caret = CaretController();
      final rack = _rack();
      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 1,
      );
      caret.moveTo(5);
      expect(caret.caret!.ruIndex, 5);

      // Focus lost -> inactive, but the underlying position is retained.
      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: false,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 1,
      );
      expect(caret.caret, isNull); // hidden while inactive
      expect(caret.stickyCaret!.ruIndex, 5); // but still tracked

      // Focus regained -> reactivates at the SAME position.
      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 1,
      );
      expect(caret.caret!.ruIndex, 5);
    });
  });

  group('moveTo / moveBy stepping and clamping', () {
    late CaretController caret;
    late Rack rack;

    setUp(() {
      caret = CaretController();
      rack = _rack();
      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 6,
      );
    });

    test('moveBy(1) / moveBy(-1) step by one U (Up/Down)', () {
      caret.moveBy(1);
      expect(caret.caret!.ruIndex, 7);
      caret.moveBy(-1);
      caret.moveBy(-1);
      expect(caret.caret!.ruIndex, 5);
    });

    test('moveBy(10) / moveBy(-10) step by ten U (PgUp/PgDn)', () {
      caret.moveBy(10);
      expect(caret.caret!.ruIndex, 12); // clamped to the rack top
      caret.moveTo(6);
      caret.moveBy(-10);
      expect(caret.caret!.ruIndex, 1); // clamped to U1
    });

    test('moveTo clamps to [1, heightU]', () {
      caret.moveTo(0);
      expect(caret.caret!.ruIndex, 1);
      caret.moveTo(999);
      expect(caret.caret!.ruIndex, 12);
    });

    test('moveTo(1) / moveTo(heightU) implement Home/End', () {
      caret.moveTo(1);
      expect(caret.caret!.ruIndex, 1);
      caret.moveTo(rack.heightU);
      expect(caret.caret!.ruIndex, 12);
    });

    test('a no-op move (already there) does not notify', () {
      var notifications = 0;
      caret.addListener(() => notifications++);
      caret.moveTo(6); // already at 6
      expect(notifications, 0);
    });
  });

  group('rack-height-change clamping', () {
    test('recompute clamps a caret that is now past a shrunk rack', () {
      final caret = CaretController();
      var rack = _rack(heightU: 20);
      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 18,
      );
      expect(caret.caret!.ruIndex, 18);

      rack = _rack(heightU: 10); // same rack id, shrunk height
      caret.recompute(
        selectionEmpty: true,
        canvasHasFocus: true,
        dragInProgress: false,
        rack: rack,
        smartDefaultRuIndex: 18,
      );
      expect(caret.caret!.ruIndex, 10); // clamped down, not re-seeded to 18
    });
  });

  group('moveTo/moveBy before any recompute', () {
    test('are safe no-ops when the caret has never been seeded', () {
      final caret = CaretController();
      expect(() => caret.moveTo(5), returnsNormally);
      expect(() => caret.moveBy(1), returnsNormally);
      expect(caret.caret, isNull);
      expect(caret.stickyCaret, isNull);
    });
  });

  group('InsertionCaret value equality', () {
    test('two carets with the same rackId/ruIndex are equal', () {
      const a = InsertionCaret(rackId: Uuid('r1'), ruIndex: 3);
      const b = InsertionCaret(rackId: Uuid('r1'), ruIndex: 3);
      const c = InsertionCaret(rackId: Uuid('r1'), ruIndex: 4);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
