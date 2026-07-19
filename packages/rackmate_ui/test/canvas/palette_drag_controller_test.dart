// Pure-logic unit tests for PaletteDragController's arm/lift/enter/exit/
// evaluate/commit/cancel state machine (docs/04-rack-editor.md §3.1) — no
// widgets, no pointer routing, just the controller's own transitions and
// invariants. Full pointer+keyboard gesture integration lives in
// rack_canvas_screen_test.dart's "drag from palette to rails" group.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

PaletteDragController _armed() => PaletteDragController()
  ..arm(
    catalogId: 'V01',
    deviceH: 2,
    face: Face.front,
    displayName: 'Test Amp',
    badge: '2U',
    sourceKinds: {PointerDeviceKind.mouse},
  );

void main() {
  test('arm sets phase to armed and stores the catalog/device metadata', () {
    final drag = _armed();
    expect(drag.phase, PaletteDragPhase.armed);
    expect(drag.catalogId, 'V01');
    expect(drag.deviceH, 2);
    expect(drag.face, Face.front);
    expect(drag.displayName, 'Test Amp');
    expect(drag.badge, '2U');
    expect(drag.isInProgress, isTrue);
    expect(drag.isLifted, isFalse);
    expect(drag.isDragging, isFalse);
  });

  test('lift only transitions from armed, and only forward', () {
    final drag = PaletteDragController();
    drag.lift(); // no-op: never armed.
    expect(drag.phase, PaletteDragPhase.none);

    final armed = _armed()..lift();
    expect(armed.phase, PaletteDragPhase.lifted);
    expect(armed.isLifted, isTrue);

    armed.lift(); // already lifted -- no-op, not an error.
    expect(armed.phase, PaletteDragPhase.lifted);
  });

  test('enterCanvas only transitions from lifted', () {
    final drag = _armed();
    drag.enterCanvas(); // still just armed -- no-op.
    expect(drag.phase, PaletteDragPhase.armed);

    drag.lift();
    drag.enterCanvas();
    expect(drag.phase, PaletteDragPhase.dragging);
    expect(drag.isDragging, isTrue);
  });

  test('exitCanvas falls back to lifted and clears the scene cursor and '
      'evaluation, without ending the gesture', () {
    final drag = _armed()
      ..lift()
      ..enterCanvas()
      ..updateEvaluation(
        const DPt(10, 20),
        const PaletteDragEvaluation(ruIndex: 4, blocked: false),
      );
    expect(drag.sceneCursor, isNotNull);
    expect(drag.evaluation, isNotNull);

    drag.exitCanvas();
    expect(drag.phase, PaletteDragPhase.lifted);
    expect(drag.sceneCursor, isNull);
    expect(drag.evaluation, isNull);
    expect(drag.isInProgress, isTrue); // the gesture is still alive.
  });

  test('updateEvaluation only applies while dragging', () {
    final drag = _armed()..lift();
    drag.updateEvaluation(
      const DPt(0, 0),
      const PaletteDragEvaluation(ruIndex: 1, blocked: false),
    );
    expect(drag.evaluation, isNull); // not dragging yet -- ignored.

    drag.enterCanvas();
    drag.updateEvaluation(
      const DPt(1, 2),
      const PaletteDragEvaluation(ruIndex: 5, blocked: true, reason: 'x'),
    );
    expect(drag.evaluation?.ruIndex, 5);
    expect(drag.evaluation?.blocked, isTrue);
    expect(drag.sceneCursor, const DPt(1, 2));
  });

  test('beginBlockedRelease freezes phase=none but keeps isInProgress true '
      'via releaseLingering, and keeps the frozen evaluation', () {
    final drag = _armed()
      ..lift()
      ..enterCanvas()
      ..updateEvaluation(
        const DPt(0, 0),
        const PaletteDragEvaluation(
          ruIndex: 3,
          blocked: true,
          reason: 'Occupied by SW-1 (U3-U3).',
        ),
      );

    drag.beginBlockedRelease();
    expect(drag.phase, PaletteDragPhase.none);
    expect(drag.releaseLingering, isTrue);
    expect(drag.isInProgress, isTrue); // still suppresses the caret.
    expect(drag.isDragging, isFalse); // ghost is frozen, not "live" anymore.
    // The frozen state survives so the ghost/chip have something to keep
    // showing during the 1.2s linger.
    expect(drag.evaluation?.ruIndex, 3);
    expect(drag.evaluation?.reason, contains('SW-1'));
  });

  test('reset clears everything and isInProgress becomes false', () {
    final drag = _armed()
      ..lift()
      ..enterCanvas()
      ..updateEvaluation(
        const DPt(1, 1),
        const PaletteDragEvaluation(ruIndex: 2, blocked: false),
      );

    drag.reset();
    expect(drag.phase, PaletteDragPhase.none);
    expect(drag.catalogId, isNull);
    expect(drag.deviceH, 0);
    expect(drag.sceneCursor, isNull);
    expect(drag.evaluation, isNull);
    expect(drag.releaseLingering, isFalse);
    expect(drag.isInProgress, isFalse);
  });

  test('reset after beginBlockedRelease also clears the linger', () {
    final drag = _armed()
      ..lift()
      ..enterCanvas()
      ..updateEvaluation(
        const DPt(0, 0),
        const PaletteDragEvaluation(ruIndex: 1, blocked: true, reason: 'x'),
      )
      ..beginBlockedRelease();
    expect(drag.releaseLingering, isTrue);

    drag.reset();
    expect(drag.releaseLingering, isFalse);
    expect(drag.isInProgress, isFalse);
  });

  test('reset on an already-clear controller does not notify listeners '
      '(no spurious rebuild)', () {
    final drag = PaletteDragController();
    var notifications = 0;
    drag.addListener(() => notifications++);
    drag.reset();
    expect(notifications, 0);
  });

  test('updateCursorGlobal stores the raw global position regardless of '
      'phase (needed for the cursor card before canvas entry)', () {
    final drag = _armed();
    drag.updateCursorGlobal(const Offset(100, 200));
    expect(drag.cursorGlobal, const Offset(100, 200));
  });

  test('isLifted is true for both lifted and dragging, false for armed/none', () {
    final drag = _armed();
    expect(drag.isLifted, isFalse);
    drag.lift();
    expect(drag.isLifted, isTrue);
    drag.enterCanvas();
    expect(drag.isLifted, isTrue);
    drag.reset();
    expect(drag.isLifted, isFalse);
  });
}
