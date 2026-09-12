// PLAN-E/5: the layout, and the wiring that makes four chapters true
// (docs/15 §6, DR-143 §11.142, DR-140 §11.139).
//
// ═══════════════════════════════════════════════════════════════════════
// THE LOAD-BEARING CASE IS THE ONE THAT DRAGS A RACK OUT OF THE STRIP
// ═══════════════════════════════════════════════════════════════════════
// Every other case here is layout. That one is the whole epic's point:
// `Rack.planPin` shipped at PLAN-C, `SetPlanPinCommand` has accepted
// `PinCarrier.rack` just as long, `armCarrierDrag` shipped at PLAN-E/4,
// and until this screen existed nothing could hand the one to the other.
// Without a rack pin `PLN-003` fires and no length on the plan derives.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _now = DateTime.utc(2026, 9, 8);
const _ul1 = Uuid('ul-1');
const _ul2 = Uuid('ul-2');
const _member1 = 'underlays/ul-1.png';
const _member2 = 'underlays/ul-2.png';
const _rackId = Uuid('rk-1');
const _level1 = Uuid('loc-l1');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

final class _ZeroMeasurer implements TextMeasurer {
  const _ZeroMeasurer();

  @override
  TextMetrics measureText(String text, TextStyleSpec style) =>
      const TextMetrics(
        advanceWidth: 0,
        ascent: 0,
        descent: 0,
        capHeight: 0,
        xHeight: 0,
        lineHeight: 0,
      );
}

Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF884422),
  );
  final image = await recorder.endRecording().toImage(w, h);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

PlanUnderlay _underlay(
  Uuid id,
  String member,
  String name, {
  Uuid? at,
  PlanScale? scale,
}) => PlanUnderlay(
  id: id,
  name: name,
  locationId: at,
  imageMember: member,
  format: PlanImageFormat.png,
  pixelWidth: 600,
  pixelHeight: 400,
  contentHash: 'sha256:test',
  order: FracIndex(id == _ul1 ? 'a0' : 'a1'),
  meta: _meta(),
  scale: scale,
);

/// 36 inches over 100 pixels, which is `PLAN-F/1`'s own example.
const _usable = PlanScale(
  a: PxPt(100, 100),
  b: PxPt(200, 100),
  distance: Len(36 * Len.nmPerInch),
);

const _roomId = Uuid('room-1');

DocumentController _controller({
  bool withUnderlay = true,
  bool withSecond = false,
  bool withRack = true,
  bool withRoom = false,
  RoomOutline? outline,
  PlanScale? scale,
}) {
  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.locations[_level1] = Location(
    id: _level1,
    kind: LocationKind.floor,
    name: 'Level 1',
    code: 'L1',
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  if (withUnderlay) {
    doc.underlays[_ul1] = _underlay(
      _ul1,
      _member1,
      'Level 1',
      at: _level1,
      scale: scale,
    );
  }
  if (withRoom) {
    // A CHILD of the floor the plan depicts, which is how the trade files
    // a job and the scope DR-154 §11.153.7a widened onto.
    doc.locations[_roomId] = Location(
      id: _roomId,
      kind: LocationKind.room,
      name: 'Great Room',
      code: 'GR',
      order: const FracIndex('a1'),
      parentId: _level1,
      meta: _meta(),
      planOutline: outline,
    );
  }
  if (withSecond) {
    doc.underlays[_ul2] = _underlay(_ul2, _member2, 'Site');
  }
  if (withRack) {
    doc.racks[_rackId] = Rack(
      id: _rackId,
      name: 'Head end',
      designator: 'RK-1',
      heightU: 42,
      order: const FracIndex('a0'),
      meta: _meta(),
      locationId: _level1,
    );
  }
  return DocumentController(doc, clock: FixedClock(_now), actor: 'test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlanImageCache cache;
  setUp(() => cache = PlanImageCache());
  tearDown(() => cache.dispose());

  Future<SelectionController> pump(
    WidgetTester tester,
    DocumentController controller, {
    List<String> members = const [_member1],
  }) async {
    await tester.runAsync(() async {
      for (final m in members) {
        await cache.load(m, await _png(600, 400));
      }
    });
    final selection = SelectionController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 900,
              height: 500,
              child: PlanEditorScreen(
                controller: controller,
                images: cache.resolver,
                measurer: const _ZeroMeasurer(),
                selection: selection,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return selection;
  }

  _roomListTests();

  group('with no floorplan', () {
    testWidgets('NAMES THE ROUTE, which did not exist until this chapter', (
      tester,
    ) async {
      // DR-143 §11.142.1: the importer had no caller, so a tab saying only
      // "no plans" would have been telling the truth about a dead end.
      await pump(tester, _controller(withUnderlay: false), members: const []);

      expect(find.text(kPlanEmptyHeadline), findsOneWidget);
      expect(find.text(kPlanEmptyDetail), findsOneWidget);
      expect(find.byType(PlanCanvasScreen), findsNothing);
    });
  });

  group('with a floorplan', () {
    testWidgets('shows the canvas and the strip together', (tester) async {
      await pump(tester, _controller());

      expect(find.byType(PlanCanvasScreen), findsOneWidget);
      expect(find.byKey(UnpinnedStrip.stripKey), findsOneWidget);
    });

    testWidgets('THE STRIP COUNTS THE RACK, which is DR-140 end to end', (
      tester,
    ) async {
      // One unpinned rack and no devices: a strip built from `doc.devices`
      // reads "Nothing left to pin" here, which is the 80%-complete plan
      // this surface exists to refuse.
      await pump(tester, _controller());

      expect(find.text('1 $kUnpinnedStripCountSuffix'), findsOneWidget);
    });

    testWidgets('lists every plan, and opening one switches the canvas', (
      tester,
    ) async {
      final c = _controller(withSecond: true);
      await pump(tester, c, members: const [_member1, _member2]);

      expect(find.byKey(const ValueKey('underlay-row-ul-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('underlay-row-ul-2')), findsOneWidget);
      // The room, when the plan names one. `Site` names none and shows no
      // second line rather than reading "no location".
      expect(find.text('Level 1'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('underlay-row-ul-2')));
      await tester.pump();

      final canvas = tester.widget<PlanCanvasScreen>(
        find.byType(PlanCanvasScreen),
      );
      expect(canvas.underlay.id, _ul2);
    });
  });

  group('the gesture this whole epic was for', () {
    testWidgets('A RACK DRAGGED OUT OF THE STRIP LANDS ON THE PLAN', (
      tester,
    ) async {
      // `Rack.planPin` shipped at PLAN-C and nothing could press the
      // button. This is the button.
      final c = _controller();
      await pump(tester, c);
      expect(c.doc.racks[_rackId]!.planPin, isNull);

      final row = find.byKey(UnpinnedStrip.rowKey(_rackId));
      expect(row, findsOneWidget, reason: 'the rack is in the strip');

      final pointer = TestPointer(41, PointerDeviceKind.mouse);
      final down = pointer.down(tester.getCenter(row));
      await tester.sendEventToBinding(down);
      // The canvas is the region to the right of the 240px rail and above
      // the strip, so this lands inside it.
      await tester.sendEventToBinding(pointer.move(const Offset(500, 120)));
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();

      final pin = c.doc.racks[_rackId]!.planPin;
      expect(pin, isNotNull, reason: 'PLN-003 fires without this pin');
      expect(pin!.underlayId, _ul1);
    });

    testWidgets('and the strip then has nothing left to pin', (tester) async {
      // The count shrinking by one is the progress indicator DR-141
      // §11.140.4 says an auto-advancing chip would have had to invent.
      final c = _controller();
      await pump(tester, c);

      final pointer = TestPointer(42, PointerDeviceKind.mouse);
      final down = pointer.down(
        tester.getCenter(find.byKey(UnpinnedStrip.rowKey(_rackId))),
      );
      await tester.sendEventToBinding(down);
      await tester.sendEventToBinding(pointer.move(const Offset(500, 120)));
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();

      expect(find.text(kUnpinnedStripEmptyLabel), findsOneWidget);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // PLAN-F/3: PLACEMENT DOES NOT WAIT FOR A SCALE, IN EITHER DIRECTION
  // ═════════════════════════════════════════════════════════════════════
  // DR-146 §11.145.7: the proof is a GESTURE and not a model call. A gate
  // would be added on a surface, as a disabled strip row or a refused
  // drop, and a case that ran `SetPlanPinCommand` against a document
  // could not see one. Both cases below drag the rack out of the strip,
  // which is the same gesture the group above proves, and differ only in
  // whether the plan under it carries a scale.
  group('DR-146: placement and calibration do not block each other', () {
    /// Drags [row] out of the strip and drops it on the canvas.
    Future<void> dragToCanvas(WidgetTester tester, Finder row) async {
      final pointer = TestPointer(43, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.down(tester.getCenter(row)));
      await tester.sendEventToBinding(pointer.move(const Offset(500, 120)));
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();
    }

    testWidgets('A PIN LANDS ON AN UNCALIBRATED PLAN, AND NO LENGTH COMES '
        'WITH IT', (tester) async {
      // docs/15 §5: placement is useful on its own, because "which wall"
      // does not require a scale, and that is the feature's primary job.
      // Every fixture in this file already ran this way and none of them
      // said so, which is a property nobody would notice losing.
      final c = _controller();
      await pump(tester, c);
      expect(c.doc.underlays[_ul1]!.scale, isNull);

      await dragToCanvas(tester, find.byKey(UnpinnedStrip.rowKey(_rackId)));

      expect(c.doc.racks[_rackId]!.planPin, isNotNull);
      // AND THE PIN BOUGHT NO SCALE. The plan is exactly as uncalibrated
      // as it was, which is the half of "neither blocks the other" that a
      // fabricated 1:1 default would break silently.
      expect(c.doc.underlays[_ul1]!.scale, isNull);
      final m = planMeasurabilityOf(c.doc, c.doc.underlays[_ul1]!);
      expect(m.rackPinned, isTrue);
      expect(m.measurableCount, 0);
      expect(m.blockedBy, PlanBlocker.uncalibrated);
    });

    testWidgets('AND ON A CALIBRATED ONE, WHICH IS THE DIRECTION NO CASE '
        'HAS EVER RUN', (tester) async {
      // A scale is not a lock. The mirror of the case above, and the one
      // that would fail the day somebody gated the strip on a calibration
      // being present or absent.
      final c = _controller(scale: _usable);
      await pump(tester, c);

      await dragToCanvas(tester, find.byKey(UnpinnedStrip.rowKey(_rackId)));

      expect(c.doc.racks[_rackId]!.planPin, isNotNull);
      // AND THE PIN LEFT THE CALIBRATION ALONE, byte for byte: a pin
      // command that touched the scale would move every length on the
      // plan at once.
      expect(c.doc.underlays[_ul1]!.scale, _usable);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════
// LEN-A/4: THE ROOM LIST, AND THE REACHABILITY THIS EPIC HAS MISSED TWICE
// ═══════════════════════════════════════════════════════════════════════
// `plan_outline_test.dart` proves the mode and `plan_canvas_screen_test`
// proves a canvas click reaches it. Neither proves anybody can START one,
// which is the failure `PLAN-E/5` found across six functions and a dialog
// (DR-143) and `PLAN-E/6` shipped again in a gesture that was dead until
// `PLAN-F/0`.
//
// So the load-bearing case below presses the real button and then clicks
// the real canvas.
void _roomListTests() {
  late PlanImageCache cache;
  setUp(() => cache = PlanImageCache());
  tearDown(() => cache.dispose());

  Future<void> pump(
    WidgetTester tester,
    DocumentController c, {
    List<String> members = const [_member1],
  }) async {
    await tester.runAsync(() async {
      for (final m in members) {
        await cache.load(m, await _png(600, 400));
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 900,
              height: 700,
              child: PlanEditorScreen(
                controller: c,
                images: cache.resolver,
                measurer: const _ZeroMeasurer(),
                selection: SelectionController(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder drawFor(Uuid id) => find.byKey(ValueKey('room-draw-${id.v}'));
  Finder clearFor(Uuid id) => find.byKey(ValueKey('room-clear-${id.v}'));
  Finder reshapeFor(Uuid id) => find.byKey(ValueKey('room-reshape-${id.v}'));

  /// A triangle whose corners this file's cases drag.
  RoomOutline triangle() => RoomOutline(
    underlayId: _ul1,
    vertices: const [PxPt(100, 100), PxPt(400, 100), PxPt(400, 300)],
  );

  /// Where [p] sits on the screen, read from the viewport the REAL screen
  /// built rather than from one a test made up.
  ///
  /// A test that assumed the identity would be asserting about a viewport
  /// this widget does not necessarily give itself, which is the shape of
  /// several failures this epic has already had: measure the thing that
  /// shipped.
  Offset screenOf(WidgetTester tester, PxPt p) {
    final canvas = tester.widget<PlanCanvasScreen>(
      find.byType(PlanCanvasScreen),
    );
    final s = canvas.viewport.sceneToScreen(
      DPt(p.px.toDouble(), p.py.toDouble()),
    );
    return tester.getTopLeft(find.byType(PlanCanvasScreen)) + Offset(s.x, s.y);
  }

  Future<void> dragCorner(
    WidgetTester tester,
    PxPt from,
    PxPt to,
  ) async {
    final a = screenOf(tester, from);
    final b = screenOf(tester, to);
    final pointer = TestPointer(64, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.down(a));
    await tester.sendEventToBinding(pointer.move(Offset.lerp(a, b, .5)!));
    await tester.sendEventToBinding(pointer.move(b));
    await tester.sendEventToBinding(pointer.up());
    await tester.pump();
  }

  group('LEN-A/4: the room list', () {
    testWidgets('lists the plan’s location SUBTREE, not just its location', (
      tester,
    ) async {
      // DR-154 §11.153.7a's scope, and the same one `unpinnedCarriersFor`
      // was widened onto: an underlay depicts a floor and the rooms are
      // under it. A list of the exact location would offer an outline on
      // the floor and on none of the rooms in it.
      await pump(tester, _controller(withRoom: true));

      expect(find.text('Great Room'), findsOneWidget);
      expect(drawFor(_roomId), findsOneWidget);
      expect(drawFor(_level1), findsOneWidget);
    });

    testWidgets('a plan with no location says which fact is missing', (
      tester,
    ) async {
      final c = _controller(withSecond: true);
      await pump(tester, c, members: const [_member1, _member2]);
      // `Site` is the underlay with no location; open it.
      await tester.tap(find.text('Site'));
      await tester.pump();

      expect(find.text(kPlanNoRoomsDetail), findsOneWidget);
    });

    testWidgets('the row prints in BOTH directions (G4)', (tester) async {
      await pump(tester, _controller(withRoom: true));
      expect(find.text('No outline yet'), findsWidgets);

      await pump(
        tester,
        _controller(
          withRoom: true,
          outline: RoomOutline(
            underlayId: _ul1,
            vertices: const [PxPt(10, 10), PxPt(90, 10), PxPt(90, 60)],
          ),
        ),
      );
      expect(find.text('Outline drawn'), findsOneWidget);
    });

    testWidgets('an outline drawn on ANOTHER plan is not this row’s', (
      tester,
    ) async {
      // Offering `Clear` here would take away something the person is not
      // looking at.
      await pump(
        tester,
        _controller(
          withRoom: true,
          outline: RoomOutline(
            underlayId: _ul2,
            vertices: const [PxPt(10, 10), PxPt(90, 10), PxPt(90, 60)],
          ),
        ),
      );

      expect(clearFor(_roomId), findsNothing);
    });

    testWidgets('LOAD-BEARING: pressing Draw… then clicking the canvas '
        'writes an outline', (tester) async {
      // THE REACHABILITY PROOF. Everything else in this chapter passes
      // against a mode nobody can start.
      final c = _controller(withRoom: true);
      await pump(tester, c);

      await tester.tap(drawFor(_roomId));
      await tester.pump();
      expect(find.byKey(PlanOutlineChip.chipKey), findsOneWidget);

      final canvas = tester.getTopLeft(find.byType(PlanCanvasScreen));
      for (final at in const [
        Offset(100, 100),
        Offset(300, 100),
        Offset(300, 250),
        Offset(100, 100),
      ]) {
        await tester.tapAt(canvas + at);
      }
      await tester.pump();

      final written = c.doc.locations[_roomId]!.planOutline;
      expect(written, isNotNull);
      expect(written!.vertices, hasLength(3));
      expect(written.underlayId, _ul1);
      expect(find.byKey(PlanOutlineChip.chipKey), findsNothing);
    });

    testWidgets('Clear takes it off, and the undo puts it back', (
      tester,
    ) async {
      final c = _controller(
        withRoom: true,
        outline: RoomOutline(
          underlayId: _ul1,
          vertices: const [PxPt(10, 10), PxPt(90, 10), PxPt(90, 60)],
        ),
      );
      await pump(tester, c);

      await tester.tap(clearFor(_roomId));
      await tester.pump();
      expect(c.doc.locations[_roomId]!.planOutline, isNull);

      c.undo.undo(c.doc);
      expect(c.doc.locations[_roomId]!.planOutline, isNotNull);
    });

    testWidgets('LOAD-BEARING: pressing Reshape… then dragging a corner '
        'moves it', (tester) async {
      // THE REACHABILITY PROOF, and `#865` asks for it in terms: the
      // gesture is to be proved "through the real mounting rather than
      // through a constructor the product never calls, which is the
      // failure this epic already shipped once at PLAN-E/6". Everything
      // in `plan_canvas_screen_test.dart` passes against a mode nobody
      // can start. This is the button that starts it.
      final c = _controller(withRoom: true, outline: triangle());
      await pump(tester, c);

      await tester.tap(reshapeFor(_roomId));
      await tester.pump();
      expect(find.byKey(PlanReshapeChip.chipKey), findsOneWidget);

      await dragCorner(tester, const PxPt(100, 100), const PxPt(150, 160));

      expect(c.doc.locations[_roomId]!.planOutline!.vertices, const [
        PxPt(150, 160),
        PxPt(400, 100),
        PxPt(400, 300),
      ]);
    });

    testWidgets('Reshape… is offered only where there is a shape', (
      tester,
    ) async {
      await pump(tester, _controller(withRoom: true));
      expect(reshapeFor(_roomId), findsNothing);

      await pump(
        tester,
        _controller(withRoom: true, outline: triangle()),
      );
      expect(reshapeFor(_roomId), findsOneWidget);
    });

    testWidgets('starting a DRAW ends a live reshape, and starting a '
        'RESHAPE ends a live draw', (tester) async {
      // The canvas depends on this: a reshape swallows every press, so a
      // draw left running underneath one could not take a corner until
      // the reshape ended, which is a mode nobody can get back to.
      final c = _controller(withRoom: true, outline: triangle());
      await pump(tester, c);

      await tester.tap(reshapeFor(_roomId));
      await tester.pump();
      await tester.tap(drawFor(_roomId));
      await tester.pump();
      expect(find.byKey(PlanOutlineChip.chipKey), findsOneWidget);
      expect(find.byKey(PlanReshapeChip.chipKey), findsNothing);

      await tester.tap(reshapeFor(_roomId));
      await tester.pump();
      expect(find.byKey(PlanReshapeChip.chipKey), findsOneWidget);
      expect(find.byKey(PlanOutlineChip.chipKey), findsNothing);
    });

    testWidgets('CLEAR ENDS A RESHAPE OF THAT ROOM, so the chip stops '
        'naming corners the same press deleted', (tester) async {
      final c = _controller(withRoom: true, outline: triangle());
      await pump(tester, c);

      await tester.tap(reshapeFor(_roomId));
      await tester.pump();
      expect(find.byKey(PlanReshapeChip.chipKey), findsOneWidget);

      await tester.tap(clearFor(_roomId));
      await tester.pump();

      expect(find.byKey(PlanReshapeChip.chipKey), findsNothing);
    });

    testWidgets('SWITCHING PLANS ENDS THE DRAW, which `LEN-A/4` did not '
        'and this chapter found', (tester) async {
      // The defect, in full: this screen holds ONE outline controller for
      // all plans, on the calibration's own "cannot outlive the raster"
      // reasoning, and `_openPlan` cancelled the calibration and not the
      // draw. Two corners placed on one plan, a switch, and a third click
      // closed a shape whose first two vertices were measured on a
      // different picture. Nothing refused it, because the vertices are
      // integers and every raster has those.
      final c = _controller(withRoom: true, withSecond: true);
      await pump(tester, c, members: const [_member1, _member2]);

      await tester.tap(drawFor(_roomId));
      await tester.pump();
      final canvas = tester.getTopLeft(find.byType(PlanCanvasScreen));
      await tester.tapAt(canvas + const Offset(100, 100));
      await tester.tapAt(canvas + const Offset(300, 100));
      await tester.pump();

      await tester.tap(find.text('Site'));
      await tester.pump();

      expect(find.byKey(PlanOutlineChip.chipKey), findsNothing);
    });

    testWidgets('and switching plans ends a reshape too', (tester) async {
      final c = _controller(
        withRoom: true,
        withSecond: true,
        outline: RoomOutline(
          underlayId: _ul1,
          vertices: const [PxPt(100, 100), PxPt(400, 100), PxPt(400, 300)],
        ),
      );
      await pump(tester, c, members: const [_member1, _member2]);

      await tester.tap(reshapeFor(_roomId));
      await tester.pump();
      expect(find.byKey(PlanReshapeChip.chipKey), findsOneWidget);

      await tester.tap(find.text('Site'));
      await tester.pump();

      expect(find.byKey(PlanReshapeChip.chipKey), findsNothing);
    });

    testWidgets('and starting a draw CANCELS a live calibration, so no '
        'mode is left unreachable underneath one', (tester) async {
      final c = _controller(withRoom: true);
      await pump(tester, c);

      await tester.tap(find.byKey(ValueKey('underlay-calibrate-${_ul1.v}')));
      await tester.pump();
      expect(find.byKey(PlanCalibrateChip.chipKey), findsOneWidget);

      await tester.tap(drawFor(_roomId));
      await tester.pump();

      expect(find.byKey(PlanOutlineChip.chipKey), findsOneWidget);
      expect(find.byKey(PlanCalibrateChip.chipKey), findsNothing);
    });
  });
}
