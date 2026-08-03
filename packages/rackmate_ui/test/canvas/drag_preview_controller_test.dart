// Pure-logic unit tests for DragPreviewController's arm/lift/enter/exit/
// evaluate/commit/cancel state machine (docs/04-rack-editor.md §3.1) — no
// widgets, no pointer routing, just the controller's own transitions and
// invariants. Full pointer+keyboard gesture integration lives in
// rack_canvas_screen_test.dart's "drag from palette to rails" group.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

DragPreviewController _armed() => DragPreviewController()
  ..arm(
    subjectId: 'V01',
    deviceH: 2,
    face: Face.front,
    displayName: 'Test Amp',
    badge: '2U',
    sourceKinds: {PointerDeviceKind.mouse},
  );

void main() {
  test('arm sets phase to armed and stores the catalog/device metadata', () {
    final drag = _armed();
    expect(drag.phase, DragPreviewPhase.armed);
    expect(drag.subjectId, 'V01');
    expect(drag.deviceH, 2);
    expect(drag.face, Face.front);
    expect(drag.displayName, 'Test Amp');
    expect(drag.badge, '2U');
    expect(drag.isInProgress, isTrue);
    expect(drag.isSourceEngaged, isFalse);
    expect(drag.isDragging, isFalse);
  });

  test('lift only transitions from armed, and only forward', () {
    final drag = DragPreviewController();
    drag.lift(); // no-op: never armed.
    expect(drag.phase, DragPreviewPhase.none);

    final armed = _armed()..lift();
    expect(armed.phase, DragPreviewPhase.lifted);
    expect(armed.isSourceEngaged, isTrue);

    armed.lift(); // already lifted -- no-op, not an error.
    expect(armed.phase, DragPreviewPhase.lifted);
  });

  test('enterCanvas only transitions from lifted', () {
    final drag = _armed();
    drag.enterCanvas(); // still just armed -- no-op.
    expect(drag.phase, DragPreviewPhase.armed);

    drag.lift();
    drag.enterCanvas();
    expect(drag.phase, DragPreviewPhase.dragging);
    expect(drag.isDragging, isTrue);
  });

  test('exitCanvas falls back to lifted and clears the scene cursor and '
      'evaluation, without ending the gesture', () {
    final drag = _armed()
      ..lift()
      ..enterCanvas()
      ..updateEvaluation(
        const DPt(10, 20),
        const DragPreviewEvaluation(ruIndex: 4, blocked: false),
      );
    expect(drag.sceneCursor, isNotNull);
    expect(drag.evaluation, isNotNull);

    drag.exitCanvas();
    expect(drag.phase, DragPreviewPhase.lifted);
    expect(drag.sceneCursor, isNull);
    expect(drag.evaluation, isNull);
    expect(drag.isInProgress, isTrue); // the gesture is still alive.
  });

  test('updateEvaluation only applies while dragging', () {
    final drag = _armed()..lift();
    drag.updateEvaluation(
      const DPt(0, 0),
      const DragPreviewEvaluation(ruIndex: 1, blocked: false),
    );
    expect(drag.evaluation, isNull); // not dragging yet -- ignored.

    drag.enterCanvas();
    drag.updateEvaluation(
      const DPt(1, 2),
      const DragPreviewEvaluation(ruIndex: 5, blocked: true, reason: 'x'),
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
        const DragPreviewEvaluation(
          ruIndex: 3,
          blocked: true,
          reason: 'Occupied by SW-1 (U3-U3).',
        ),
      );

    drag.beginBlockedRelease();
    expect(drag.phase, DragPreviewPhase.none);
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
        const DragPreviewEvaluation(ruIndex: 2, blocked: false),
      );

    drag.reset();
    expect(drag.phase, DragPreviewPhase.none);
    expect(drag.subjectId, isNull);
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
        const DragPreviewEvaluation(ruIndex: 1, blocked: true, reason: 'x'),
      )
      ..beginBlockedRelease();
    expect(drag.releaseLingering, isTrue);

    drag.reset();
    expect(drag.releaseLingering, isFalse);
    expect(drag.isInProgress, isFalse);
  });

  test('reset on an already-clear controller does not notify listeners '
      '(no spurious rebuild)', () {
    final drag = DragPreviewController();
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

  test('isSourceEngaged is true for both lifted and dragging, false for '
      'armed/none', () {
    final drag = _armed();
    expect(drag.isSourceEngaged, isFalse);
    drag.lift();
    expect(drag.isSourceEngaged, isTrue);
    drag.enterCanvas();
    expect(drag.isSourceEngaged, isTrue);
    drag.reset();
    expect(drag.isSourceEngaged, isFalse);
  });

  group('shared with the move gesture (docs/04 §3.3)', () {
    test('liftIntoCanvas goes armed -> dragging in one step, skipping '
        'lifted (a move drag is grabbed INSIDE the canvas)', () {
      final drag = _armed()..liftIntoCanvas();
      expect(drag.phase, DragPreviewPhase.dragging);
      expect(drag.isDragging, isTrue);
      // It composes the two legal transitions rather than assigning a
      // phase directly, so it inherits their guards: calling it on a
      // controller that was never armed must do nothing at all.
      final never = DragPreviewController()..liftIntoCanvas();
      expect(never.phase, DragPreviewPhase.none);
    });

    test('isShowingGhost requires BOTH a live/lingering phase AND an '
        'evaluation -- the one predicate the painter and the chip overlay '
        'share', () {
      final drag = _armed();
      expect(drag.isShowingGhost, isFalse); // armed, no evaluation
      drag.liftIntoCanvas();
      expect(
        drag.isShowingGhost,
        isFalse,
        reason:
            'dragging but nothing evaluated yet -- there is no ruIndex '
            'to draw a ghost at',
      );
      drag.updateEvaluation(
        const DPt(0, 100),
        const DragPreviewEvaluation(ruIndex: 4, blocked: true, reason: 'x'),
      );
      expect(drag.isShowingGhost, isTrue);

      // A blocked release freezes the ghost (still shown for its 1.2s)
      // while releasing the SOURCE back to full strength immediately --
      // the device is no longer being dragged, only the verdict lingers.
      drag.beginBlockedRelease();
      expect(drag.isShowingGhost, isTrue);
      expect(drag.isSourceEngaged, isFalse);
      expect(drag.isDragging, isFalse);

      drag.reset();
      expect(drag.isShowingGhost, isFalse);
    });

    test('exitCanvas clears the evaluation, so a backed-out drag stops '
        'showing a ghost', () {
      final drag = _armed()
        ..liftIntoCanvas()
        ..updateEvaluation(
          const DPt(0, 100),
          const DragPreviewEvaluation(ruIndex: 4, blocked: false),
        );
      expect(drag.isShowingGhost, isTrue);
      drag.exitCanvas();
      expect(drag.isShowingGhost, isFalse);
      expect(drag.evaluation, isNull);
    });
  });
}
