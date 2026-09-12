// LEN-A/4: the room-outline draw mode (`#860`, DR-050 §11.49), and
// `LEN-A/8`'s reshape mode beside it (`#865`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE THIRD LIFETIME, ASSERTED AGAINST THE OTHER TWO
// ═══════════════════════════════════════════════════════════════════════
// The arm mode outlives each pin; the calibration is consumed by its own
// second click; this one accumulates until the shape closes. The cases
// below pin that difference rather than restating the implementation,
// because the three controllers look alike from outside and the whole
// reason they are three classes is that they end differently.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

const _room = Uuid('0190e200-0000-7000-8000-0000000000a0');
const _underlay = Uuid('0190e200-0000-7000-8000-0000000000b0');

void _noop() {}

void main() {
  _reshapeTests();

  group('the mode', () {
    test('is off until it begins, and knows which room it is drawing', () {
      final c = PlanOutlineController();
      expect(c.isActive, isFalse);
      expect(c.locationId, isNull);

      c.begin(_room);
      expect(c.isActive, isTrue);
      expect(c.locationId, _room);
      expect(c.vertices, isEmpty);
    });

    test('beginning twice RESTARTS rather than compounding', () {
      // `PlanCalibrateController.begin`'s reasoning: somebody who has
      // placed two corners and changed their mind presses the affordance
      // again.
      final c = PlanOutlineController()
        ..begin(_room)
        ..addVertex(const PxPt(1, 1))
        ..addVertex(const PxPt(2, 2));
      expect(
        c.vertices,
        hasLength(2),
        reason: 'two corners before the restart',
      );

      c.begin(_room);
      expect(c.vertices, isEmpty);
      expect(c.isActive, isTrue);
    });

    test('a vertex added while the mode is OFF is dropped, so a stray '
        'click leaves no half-drawn state', () {
      final c = PlanOutlineController()..addVertex(const PxPt(1, 1));
      expect(c.vertices, isEmpty);
      expect(c.isActive, isFalse);
    });

    test('it notifies on every act a surface has to redraw for', () {
      var notifications = 0;
      PlanOutlineController()
        ..addListener(() => notifications++)
        ..begin(_room)
        ..addVertex(const PxPt(1, 1))
        ..removeLastVertex()
        ..cancel();

      expect(notifications, 4);
    });
  });

  group('canClose is the MODEL’s condition, not a second rule', () {
    test('three corners, because two points are a line', () {
      final c = PlanOutlineController()..begin(_room);
      expect(c.canClose, isFalse);

      c.addVertex(const PxPt(0, 0));
      expect(c.canClose, isFalse);
      c.addVertex(const PxPt(10, 0));
      expect(c.canClose, isFalse);
      c.addVertex(const PxPt(10, 10));
      expect(c.canClose, isTrue);
    });

    test('and it agrees with RoomOutline.isUsable, which is what '
        'SetRoomOutlineCommand refuses on', () {
      // LOAD-BEARING. A surface offering a close the command would
      // decline is a button that does nothing, which is the shape this
      // repository keeps finding. Asserted against the model rather than
      // against the number 3.
      final c = PlanOutlineController()..begin(_room);
      for (final at in const [PxPt(0, 0), PxPt(10, 0), PxPt(10, 10)]) {
        c.addVertex(at);
        expect(
          c.canClose,
          RoomOutline(underlayId: _underlay, vertices: c.vertices).isUsable,
          reason: '${c.vertices.length} corners',
        );
      }
    });
  });

  group('closing', () {
    test('yields the room and the shape, and ends the mode', () {
      final c = PlanOutlineController()..begin(_room);
      for (final at in const [PxPt(0, 0), PxPt(10, 0), PxPt(10, 10)]) {
        c.addVertex(at);
      }

      final closed = c.takeClosed(_underlay)!;
      expect(closed.locationId, _room);
      expect(closed.outline.underlayId, _underlay);
      expect(closed.outline.vertices, hasLength(3));
      expect(c.isActive, isFalse);
      expect(c.vertices, isEmpty);
    });

    test('the ORDER survives, because order is the shape', () {
      final c = PlanOutlineController()..begin(_room);
      for (final at in const [PxPt(5, 5), PxPt(90, 5), PxPt(90, 60)]) {
        c.addVertex(at);
      }

      expect(c.takeClosed(_underlay)!.outline.vertices, const [
        PxPt(5, 5),
        PxPt(90, 5),
        PxPt(90, 60),
      ]);
    });

    test('TOO FEW CORNERS YIELDS NULL AND LEAVES THE MODE RUNNING', () {
      // Throwing the corners away would answer a mistake with a deletion.
      // A person who clicked the first corner again with two down meant to
      // close, and the answer is that they cannot yet, not that they have
      // to start over.
      final c = PlanOutlineController()
        ..begin(_room)
        ..addVertex(const PxPt(0, 0))
        ..addVertex(const PxPt(10, 0));

      expect(c.takeClosed(_underlay), isNull);
      expect(c.isActive, isTrue);
      expect(c.vertices, hasLength(2));
    });

    test('and closing while the mode is off yields null', () {
      expect(PlanOutlineController().takeClosed(_underlay), isNull);
    });
  });

  group('right-click takes one back; Esc leaves', () {
    test('the last corner goes and the mode STAYS ON', () {
      final c = PlanOutlineController()
        ..begin(_room)
        ..addVertex(const PxPt(0, 0))
        ..addVertex(const PxPt(10, 0))
        ..removeLastVertex();

      expect(c.vertices, const [PxPt(0, 0)]);
      expect(c.isActive, isTrue);
    });

    test('STEPPING BACK TO ZERO IS STILL IN THE DRAW, which is the whole '
        'difference from Esc', () {
      final c = PlanOutlineController()
        ..begin(_room)
        ..addVertex(const PxPt(0, 0))
        ..removeLastVertex()
        ..removeLastVertex();

      expect(c.vertices, isEmpty);
      expect(c.isActive, isTrue, reason: 'right-click is not an exit');
      expect(c.locationId, _room);
    });

    test('Esc ends it and forgets the room', () {
      final c = PlanOutlineController()
        ..begin(_room)
        ..addVertex(const PxPt(0, 0))
        ..cancel();

      expect(c.isActive, isFalse);
      expect(c.vertices, isEmpty);
      expect(c.locationId, isNull);
    });
  });

  group('the vertices list is not a handle on the mode’s state', () {
    test('a caller cannot edit the draw through a read', () {
      // `acceptedFamilies`' lesson one layer up: a getter handing back the
      // live list lets a caller edit through a read.
      final c = PlanOutlineController()
        ..begin(_room)
        ..addVertex(const PxPt(0, 0));

      expect(
        () => c.vertices.add(const PxPt(9, 9)),
        throwsUnsupportedError,
      );
      expect(c.vertices, hasLength(1));
    });
  });

  group('the chip says what to do next', () {
    testWidgets('and the line changes with how far along the draw is', (
      tester,
    ) async {
      Future<String> labelFor(int count, {required bool canClose}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlanOutlineChip(
                vertexCount: count,
                canClose: canClose,
                onDismiss: () {},
              ),
            ),
          ),
        );
        return tester.widget<Text>(find.byType(Text)).data!;
      }

      expect(await labelFor(0, canClose: false), kOutlineFirstLabel);
      expect(await labelFor(2, canClose: false), kOutlineMoreLabel);
      expect(await labelFor(3, canClose: true), kOutlineCloseLabel);
    });

    testWidgets('the copy NAMES THE WAY OUT, because a mode nobody can '
        'leave is the report this project has had before', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanOutlineChip(
              vertexCount: 3,
              canClose: true,
              onDismiss: () {},
            ),
          ),
        ),
      );

      // PRINTED, NOT ASSUMED. Twelve green `contains` assertions once
      // passed over a line reading "1 ports", so the words are read off
      // the widget.
      final label = tester.widget<Text>(find.byType(Text)).data!;
      expect(label, contains('first corner'));
      expect(label, contains('Right-click'));
    });

    testWidgets('AND IT DOES NOT OVERFLOW ON A NARROW CANVAS', (
      tester,
    ) async {
      // The first draft of `kOutlineCloseLabel` overflowed this Row by 70
      // pixels at the default 800-point width, which a widget test
      // reports as a failure and a shipped build reports as a yellow
      // barber pole nobody files. Narrower than that here, because the
      // longest label is the one that breaks and a canvas can be docked.
      tester.view.physicalSize = const Size(420, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: PlanOutlineChip(
                vertexCount: 4,
                canClose: true,
                onDismiss: _noop,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('and the dismiss button reports', (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanOutlineChip(
              vertexCount: 1,
              canClose: false,
              onDismiss: () => dismissed++,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      expect(dismissed, 1);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════
// LEN-A/8: THE FOURTH LIFETIME, ASSERTED AGAINST THE THIRD
// ═══════════════════════════════════════════════════════════════════════
// The draw is consumed by its own close. This one is not consumed by
// anything but an explicit exit, because somebody correcting one corner of
// a room is usually correcting the one beside it. That difference is the
// reason there are two classes, so it is what these cases pin.
//
// The DRAG itself is not here. This controller holds no geometry at all,
// on purpose (see its own doc), so every claim about what a corner does
// lives in `plan_canvas_screen_test.dart` where a real pointer can make
// one move.
void _reshapeTests() {
  group('LEN-A/8: the reshape mode', () {
    test('is off until it begins, and knows which room it is on', () {
      final c = PlanReshapeController();
      expect(c.isActive, isFalse);
      expect(c.locationId, isNull);

      c.begin(_room);
      expect(c.isActive, isTrue);
      expect(c.locationId, _room);
    });

    test('BEGINNING ON ANOTHER ROOM SWITCHES, because the mode describes '
        'exactly one', () {
      const other = Uuid('0190e200-0000-7000-8000-0000000000a1');
      final c = PlanReshapeController()
        ..begin(_room)
        ..begin(other);

      expect(c.locationId, other);
      expect(c.isActive, isTrue);
    });

    test('Esc ends it and forgets the room', () {
      final c = PlanReshapeController()
        ..begin(_room)
        ..cancel();

      expect(c.isActive, isFalse);
      expect(c.locationId, isNull);
    });

    test('cancelling an idle mode notifies NOBODY, so a keystroke with '
        'nothing to cancel does not repaint a canvas', () {
      var notified = 0;
      final c = PlanReshapeController()..addListener(() => notified++);
      expect(c.isActive, isFalse, reason: 'nothing to cancel');

      c.cancel();
      expect(notified, 0);

      c
        ..begin(_room)
        ..cancel();
      expect(notified, 2);
    });
  });

  group('LEN-A/8: the reshape chip', () {
    testWidgets('says what to drag rather than naming the mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PlanReshapeChip(onDismiss: _noop)),
        ),
      );

      expect(find.text(kReshapeLabel), findsOneWidget);
    });

    testWidgets('the copy NAMES THE WAY OUT, because a mode nobody can '
        'leave is worse than no mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PlanReshapeChip(onDismiss: _noop)),
        ),
      );

      expect(
        tester.widget<IconButton>(find.byType(IconButton)).tooltip,
        contains('Esc'),
      );
    });

    testWidgets('AND IT DOES NOT OVERFLOW ON A NARROW CANVAS', (
      tester,
    ) async {
      // `PlanOutlineChip`'s own lesson, applied to the fourth chip before
      // it can be learned a second time: the first draft of that one
      // overflowed its Row by 70 pixels at an 800-point canvas.
      tester.view.physicalSize = const Size(420, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: PlanReshapeChip(onDismiss: _noop),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('and the dismiss button reports', (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanReshapeChip(onDismiss: () => dismissed++),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      expect(dismissed, 1);
    });
  });
}
