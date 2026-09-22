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
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// A `LocationsPanelActions` that refuses everything, for cases about the
/// PLAN half of this view (`#891`, DR-168).
///
/// The view edits the location tree since the merge, so it takes the same
/// record `LocationsPanel` does. These cases are about underlays, pins and
/// outlines; `locations_panel_test.dart` and `site_view_test.dart` are
/// where the tree's own edits are proved.
LocationsPanelActions _noLocationEdits() => LocationsPanelActions(
  onAdd: (_) => const Uuid('unused'),
  onRename: (_, _) {},
  onSetCode: (_, _) {},
  onSetKind: (_, _) {},
  onSetFloorNumber: (_, _) {},
  onSetSpaceCode: (_, _) {},
  onSetEstimatedRunLength: (_, _) {},
  onReparent: (_, _) => null,
  onDelete: (_) async => false,
  onRefuse: (_) {},
);

void main() {
  // A WINDOW THE PRODUCT SUPPORTS (`#892`). This view gained the third
  // region docs/15 §6 ruled and `PLAN-E/5` did not build, and the default
  // 800px test surface CLAMPS the `SizedBox` below: the canvas came back
  // 238 units wide and every click aimed at the plan missed it. docs/04
  // §1 treats anything under 1080 as the unbuilt tablet-collapse case.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

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
                locations: _noLocationEdits(),
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

  // ═══════════════════════════════════════════════════════════════════
  // `#870`: A FLOORPLAN PAGE CAN BE REMOVED, WHICH IT COULD NOT
  // ═══════════════════════════════════════════════════════════════════
  // `RemovePlanUnderlayCommand` shipped at `PLAN-C/6` with a real revert,
  // a pin cascade, a room-outline cascade and seven tests, and NOTHING IN
  // ANY `lib/` EVER BUILT ONE. The only way to not have a page was to
  // never have imported it, so a wrong page picked out of a multi-page
  // PDF was permanent for the life of the project.
  //
  // These press the real button, because a test that called the command
  // would assert exactly what was already true for four months.
  group('#870: removing a floorplan page', () {
    Finder removeFor(Uuid id) =>
        find.byKey(ValueKey('underlay-remove-${id.v}'));

    testWidgets('LOAD-BEARING: the button exists on the open row and the '
        'page goes', (tester) async {
      final c = _controller();
      await pump(tester, c);
      expect(c.doc.underlays, hasLength(1));

      await tester.tap(removeFor(_ul1));
      await tester.pumpAndSettle();

      expect(c.doc.underlays, isEmpty);
    });

    testWidgets('A BARE PAGE IS NOT ASKED ABOUT, because a prompt for a '
        'consequence-free delete teaches people to click through prompts', (
      tester,
    ) async {
      final c = _controller();
      await pump(tester, c);

      await tester.tap(removeFor(_ul1));
      await tester.pump();

      expect(find.byType(RemoveUnderlayDialog), findsNothing);
      expect(c.doc.underlays, isEmpty);
    });

    testWidgets('AND UNDO PUTS THE PAGE BACK', (tester) async {
      final c = _controller();
      await pump(tester, c);

      await tester.tap(removeFor(_ul1));
      await tester.pumpAndSettle();
      c.undo.undo(c.doc);

      expect(c.doc.underlays, hasLength(1));
    });

    testWidgets('A PAGE CARRYING A PIN SAYS SO FIRST, and Cancel leaves it '
        'alone', (tester) async {
      final c = _controller()
        // THROUGH THE REAL WRITER, not the model's `@internal` setter: a
        // fixture built by reaching past the package boundary is a state
        // the product cannot produce, and the analyzer says so.
        ..run(
          SetPlanPinCommand(
            carrier: PinCarrier.rack,
            entityId: _rackId,
            pin: const PlanPin(underlayId: _ul1, at: PxPt(10, 10)),
          ),
        );
      await pump(tester, c);

      await tester.tap(removeFor(_ul1));
      await tester.pumpAndSettle();
      expect(find.byType(RemoveUnderlayDialog), findsOneWidget);
      expect(find.textContaining('1 item loses its position'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(c.doc.underlays, hasLength(1), reason: 'Cancel means cancel');
      expect(c.doc.racks[_rackId]!.planPin, isNotNull);
    });

    testWidgets('and confirming clears the pin with the page, in ONE undo '
        'entry', (tester) async {
      final c = _controller()
        // THROUGH THE REAL WRITER, not the model's `@internal` setter: a
        // fixture built by reaching past the package boundary is a state
        // the product cannot produce, and the analyzer says so.
        ..run(
          SetPlanPinCommand(
            carrier: PinCarrier.rack,
            entityId: _rackId,
            pin: const PlanPin(underlayId: _ul1, at: PxPt(10, 10)),
          ),
        );
      await pump(tester, c);

      await tester.tap(removeFor(_ul1));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RemoveUnderlayDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(c.doc.underlays, isEmpty);
      expect(c.doc.racks[_rackId]!.planPin, isNull);

      c.undo.undo(c.doc);
      expect(c.doc.underlays, hasLength(1));
      expect(
        c.doc.racks[_rackId]!.planPin,
        isNotNull,
        reason: 'one Ctrl+Z restores the page AND what was on it',
      );
    });

    testWidgets('THE COUNT THE DIALOG SHOWS IS THE COUNT THE COMMAND '
        'CLEARS, which is why both read one object', (tester) async {
      final c = _controller(withRoom: true)
        // THROUGH THE REAL WRITER, not the model's `@internal` setter: a
        // fixture built by reaching past the package boundary is a state
        // the product cannot produce, and the analyzer says so.
        ..run(
          SetPlanPinCommand(
            carrier: PinCarrier.rack,
            entityId: _rackId,
            pin: const PlanPin(underlayId: _ul1, at: PxPt(10, 10)),
          ),
        )
        ..run(
          SetRoomOutlineCommand(
            locationId: _roomId,
            outline: RoomOutline(
              underlayId: _ul1,
              vertices: const [PxPt(1, 1), PxPt(9, 1), PxPt(9, 6)],
            ),
          ),
        );
      await pump(tester, c);

      await tester.tap(removeFor(_ul1));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 item loses its position'), findsOneWidget);
      expect(find.textContaining('1 room outline is erased'), findsOneWidget);

      await tester.tap(find.byKey(RemoveUnderlayDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(c.doc.racks[_rackId]!.planPin, isNull);
      expect(c.doc.locations[_roomId]!.planOutline, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // `#911`, DR-184: A FLOORPLAN TURNS IN QUARTER TURNS
  // ═════════════════════════════════════════════════════════════════════
  // Every case is a GESTURE on the editor, because the defect this guards
  // is a surface that turns the picture and not the marks, or the marks
  // and not the pointer. A case that ran the command against a document
  // could see neither.
  // ═════════════════════════════════════════════════════════════════════
  // `#912`, DR-185: A PAGE SAYS ITS NAME AND THE FLOOR IT SHOWS
  // ═════════════════════════════════════════════════════════════════════
  group('#912, DR-185: Edit plan', () {
    Finder edit(Uuid id) => find.byKey(ValueKey('underlay-edit-${id.v}'));

    /// Picks [label] out of the dialog's Shows dropdown.
    Future<void> choosePlace(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(EditPlanDialog.showsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('the pencil is on the OPEN row and nowhere else', (
      tester,
    ) async {
      final c = _controller(withSecond: true);
      await pump(tester, c, members: const [_member1, _member2]);

      expect(edit(_ul1), findsOneWidget);
      expect(edit(_ul2), findsNothing);
    });

    testWidgets('LOAD-BEARING: a new name and a floor land together, the '
        'row says so, and ONE undo takes both back', (tester) async {
      // `_ul2` is the plan with no floor, which is what every imported plan
      // was before this ruling. Opened first, then named and placed.
      final c = _controller(withSecond: true);
      await pump(tester, c, members: const [_member1, _member2]);
      await tester.tap(find.text('Site'));
      await tester.pump();

      await tester.tap(edit(_ul2));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(EditPlanDialog.nameKey),
        'Level 1 lighting',
      );
      await choosePlace(tester, 'Level 1');
      await tester.tap(find.byKey(EditPlanDialog.confirmKey));
      await tester.pumpAndSettle();

      final plan = c.doc.underlays[_ul2]!;
      expect(plan.name, 'Level 1 lighting');
      expect(plan.locationId, _level1);
      // THE ROOM LINE PRINTS AT LAST. `_UnderlayRow.room` could never be
      // non-null before, because nothing wrote the field it reads.
      final row = find.byKey(ValueKey('underlay-row-${_ul2.v}'));
      expect(
        find.descendant(of: row, matching: find.text('Level 1 lighting')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Level 1')),
        findsOneWidget,
      );

      c.undo.undo(c.doc);
      expect(plan.name, 'Site');
      expect(plan.locationId, isNull);
    });

    testWidgets('Cancel changes nothing and leaves no undo entry', (
      tester,
    ) async {
      final c = _controller();
      await pump(tester, c);

      await tester.tap(edit(_ul1));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(EditPlanDialog.nameKey), 'Changed');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(c.doc.underlays[_ul1]!.name, 'Level 1');
      expect(c.undo.undoLabelKey, isNull);
    });

    testWidgets('a blank name cannot be saved', (tester) async {
      final c = _controller();
      await pump(tester, c);

      await tester.tap(edit(_ul1));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(EditPlanDialog.nameKey), '   ');
      await tester.pump();

      final save = tester.widget<FilledButton>(
        find.byKey(EditPlanDialog.confirmKey),
      );
      expect(save.onPressed, isNull);
    });
  });

  group('#911, DR-184: turning a plan', () {
    Finder right(Uuid id) =>
        find.byKey(ValueKey('underlay-rotate-right-${id.v}'));
    Finder left(Uuid id) =>
        find.byKey(ValueKey('underlay-rotate-left-${id.v}'));

    /// The middle of the canvas, which is what the view turns about.
    Offset canvasCentre(WidgetTester tester) =>
        tester.getCenter(find.byType(PlanCanvasScreen));

    /// Drags the rack out of the strip and drops it at [at].
    Future<void> dropRackAt(WidgetTester tester, Offset at) async {
      final pointer = TestPointer(51, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.down(
          tester.getCenter(find.byKey(UnpinnedStrip.rowKey(_rackId))),
        ),
      );
      await tester.sendEventToBinding(pointer.move(at));
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();
    }

    Future<void> chord(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    testWidgets('the two buttons are on the OPEN row and nowhere else', (
      tester,
    ) async {
      // DR-144 §11.143.4's host, and the same rule `Calibrate…` and
      // `Remove…` follow: a button on a closed row would turn a picture
      // nobody can see.
      final c = _controller(withSecond: true);
      await pump(tester, c, members: const [_member1, _member2]);

      expect(right(_ul1), findsOneWidget);
      expect(left(_ul1), findsOneWidget);
      expect(right(_ul2), findsNothing);
      expect(left(_ul2), findsNothing);
    });

    testWidgets('LOAD-BEARING: Rotate right turns the plan, the Edit menu '
        'says so, and one undo turns it back', (tester) async {
      final c = _controller();
      await pump(tester, c);

      await tester.tap(right(_ul1));
      await tester.pump();
      expect(c.doc.underlays[_ul1]!.rotationQuarterTurns, 1);
      expect(c.undo.undoLabelKey, LabelKey.rotatePlanClockwise.name);

      await tester.tap(left(_ul1));
      await tester.tap(left(_ul1));
      await tester.pump();
      expect(c.doc.underlays[_ul1]!.rotationQuarterTurns, 3);

      c.undo.undo(c.doc);
      expect(c.doc.underlays[_ul1]!.rotationQuarterTurns, 0);
    });

    testWidgets('THE KEYS ARE ACROBAT’S: Ctrl+Shift+Plus turns right and '
        'Ctrl+Shift+Minus turns left', (tester) async {
      final c = _controller();
      await pump(tester, c);
      // The canvas takes focus on mount; a click on empty plan is what a
      // person does anyway before reaching for a key.
      await tester.tapAt(canvasCentre(tester));
      await tester.pump();

      await chord(tester, LogicalKeyboardKey.equal);
      expect(c.doc.underlays[_ul1]!.rotationQuarterTurns, 1);

      await chord(tester, LogicalKeyboardKey.minus);
      await chord(tester, LogicalKeyboardKey.minus);
      expect(c.doc.underlays[_ul1]!.rotationQuarterTurns, 3);
    });

    testWidgets('A RACK DROPPED ON A TURNED PLAN IS UNDER THE POINTER, and a '
        'click there finds it', (tester) async {
      // The screen-to-pixel half of the map. A canvas that stored the
      // scene point as the pixel would draw this rack a quarter turn
      // away from where it was dropped, and the click would miss.
      final c = _controller();
      final selection = await pump(tester, c);
      await tester.tap(right(_ul1));
      await tester.pump();

      final at = canvasCentre(tester) + const Offset(70, -40);
      await dropRackAt(tester, at);
      expect(c.doc.racks[_rackId]!.planPin, isNotNull);

      selection.clear();
      await tester.tapAt(at);
      await tester.pump();
      expect(selection.ids, {_rackId});
    });

    testWidgets('THE VIEW TURNS ABOUT THE CANVAS CENTRE (§11.183.5): a rack '
        'at the centre is still at the centre', (tester) async {
      // Panned first, so the canvas centre is NOT the picture's centre.
      // Without that, a view that re-fitted on every turn would also leave
      // the middle of the picture in the middle, and this would pass for
      // the option the user declined.
      final c = _controller();
      final selection = await pump(tester, c);
      tester
          .widget<PlanCanvasScreen>(find.byType(PlanCanvasScreen))
          .viewport
          .panBy(const Offset(90, -35));
      await tester.pump();

      final centre = canvasCentre(tester);
      await dropRackAt(tester, centre);

      await tester.tap(right(_ul1));
      await tester.pump();

      selection.clear();
      await tester.tapAt(centre);
      await tester.pump();
      expect(selection.ids, {_rackId});
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
              // WIDENED AT `#892` FROM 900. The view gained the third
              // region docs/15 §6 ruled and `PLAN-E/5` did not build, so
              // 900 left the canvas 338 wide and the clicks below fell
              // off it. docs/04 §1 treats anything under 1080 as the
              // unbuilt tablet-collapse case, so 900 was never a window
              // this product supports.
              width: 1400,
              height: 700,
              child: PlanEditorScreen(
                locations: _noLocationEdits(),
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

  /// Selects [id] in the rail's location tree.
  ///
  /// **THE OUTLINE ACTS MOVED TO THE INSPECTOR AT `#892`** (DR-168): they
  /// were three buttons on every row of a read-only room list, and they
  /// are now the SELECTED room's, beside its other properties. So a case
  /// about drawing an outline has to say which room first, which is one
  /// tap and is what a person does.
  Future<void> selectRoom(WidgetTester tester, Uuid id) async {
    await tester.tap(find.byKey(ValueKey(id.v)));
    await tester.pumpAndSettle();
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

  group('LEN-A/4: the outline acts, which moved at `#892`', () {
    // ═════════════════════════════════════════════════════════════════
    // THE ROOM LIST IS GONE AND ITS JOB IS SPLIT (DR-168)
    // ═════════════════════════════════════════════════════════════════
    // `_RoomList` showed the open underlay's location SUBTREE, each row
    // with Draw, Reshape and Clear. The merged view's rail is the
    // project's whole tree, and a room's outline is one of its
    // properties, so the three acts moved to the inspector beside the
    // rest of them.
    //
    // TWO CASES WENT WITH THE LIST rather than being rewritten, and both
    // are named here so nobody looks for them: one asserted the list
    // showed the subtree and not the bare location, which is a question
    // about a list that no longer exists, and one asserted the empty
    // state of that list. What replaced both is per-room and is the case
    // below: the selected room says whether IT has an outline on THIS
    // plan.
    testWidgets('THE RAIL LISTS THE WHOLE PROJECT TREE, not the subtree '
        'of the open plan', (tester) async {
      // The deliberate change. `_RoomList` showed the underlay's location
      // subtree, because it was a list ABOUT that underlay; the rail is
      // the project's tree, because the view is about the project and a
      // floorplan is one thing in it. A room outside the open plan's
      // subtree is still selectable, and its outline acts simply do not
      // offer to draw on a plan it is not on.
      await pump(tester, _controller(withRoom: true));

      expect(find.text('Great Room'), findsOneWidget);
      expect(find.byKey(const ValueKey('site-add-room')), findsOneWidget);
    });

    testWidgets('the outline state prints in BOTH directions (G4)', (
      tester,
    ) async {
      await pump(tester, _controller(withRoom: true));
      await selectRoom(tester, _roomId);
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
      await selectRoom(tester, _roomId);
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

      await selectRoom(tester, _roomId);

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

      debugPrint(
        'PROBE canvas rect: '
        '${tester.getRect(find.byType(PlanCanvasScreen))}',
      );
      debugPrint(
        'PROBE chip still up: '
        '${find.byKey(PlanOutlineChip.chipKey).evaluate().length}',
      );
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

      await selectRoom(tester, _roomId);

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

      await selectRoom(tester, _roomId);

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
      await selectRoom(tester, _roomId);
      expect(reshapeFor(_roomId), findsNothing);

      await pump(
        tester,
        _controller(withRoom: true, outline: triangle()),
      );
      await selectRoom(tester, _roomId);
      expect(reshapeFor(_roomId), findsOneWidget);
    });

    testWidgets('starting a DRAW ends a live reshape, and starting a '
        'RESHAPE ends a live draw', (tester) async {
      // The canvas depends on this: a reshape swallows every press, so a
      // draw left running underneath one could not take a corner until
      // the reshape ended, which is a mode nobody can get back to.
      final c = _controller(withRoom: true, outline: triangle());
      await pump(tester, c);

      await selectRoom(tester, _roomId);

      await tester.tap(reshapeFor(_roomId));
      await tester.pump();
      await selectRoom(tester, _roomId);
      await tester.tap(drawFor(_roomId));
      await tester.pump();
      expect(find.byKey(PlanOutlineChip.chipKey), findsOneWidget);
      expect(find.byKey(PlanReshapeChip.chipKey), findsNothing);

      await selectRoom(tester, _roomId);

      await tester.tap(reshapeFor(_roomId));
      await tester.pump();
      expect(find.byKey(PlanReshapeChip.chipKey), findsOneWidget);
      expect(find.byKey(PlanOutlineChip.chipKey), findsNothing);
    });

    testWidgets('CLEAR ENDS A RESHAPE OF THAT ROOM, so the chip stops '
        'naming corners the same press deleted', (tester) async {
      final c = _controller(withRoom: true, outline: triangle());
      await pump(tester, c);

      await selectRoom(tester, _roomId);

      await tester.tap(reshapeFor(_roomId));
      await tester.pump();
      expect(find.byKey(PlanReshapeChip.chipKey), findsOneWidget);

      await selectRoom(tester, _roomId);

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

      await selectRoom(tester, _roomId);

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

      await selectRoom(tester, _roomId);

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

      await selectRoom(tester, _roomId);

      await tester.tap(drawFor(_roomId));
      await tester.pump();

      expect(find.byKey(PlanOutlineChip.chipKey), findsOneWidget);
      expect(find.byKey(PlanCalibrateChip.chipKey), findsNothing);
    });
  });
  group('`#878`: the rail reorders the pages (DR-162 §11.161.4)', () {
    /// A third page, added straight to the document. It is never OPENED,
    /// so it needs no image in the cache: a rail row is text.
    void addThird(DocumentController c) {
      c.doc.underlays[const Uuid('ul-3')] = PlanUnderlay(
        id: const Uuid('ul-3'),
        name: 'Roof',
        imageMember: 'underlays/ul-3.png',
        format: PlanImageFormat.png,
        pixelWidth: 600,
        pixelHeight: 400,
        contentHash: 'sha256:test',
        order: const FracIndex('a2'),
        meta: _meta(),
      );
    }

    List<String> railOrder(DocumentController c) {
      final all = c.doc.underlays.values.toList()
        ..sort((a, b) {
          final byOrder = a.order.v.compareTo(b.order.v);
          return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
        });
      return [for (final u in all) u.name];
    }

    /// Drags the grip on [id] down by [dy], in six steps.
    ///
    /// ═════════════════════════════════════════════════════════════════
    /// `pumpAndSettle` BETWEEN THE MOVES, AND THAT IS THE WHOLE TRICK
    /// ═════════════════════════════════════════════════════════════════
    /// The first draft pumped a fixed 16ms between moves and the reorder
    /// NEVER HAPPENED, silently: the gesture ran, the list never moved a
    /// row, and the assertion failed on the document rather than on
    /// anything that named the cause. A reorderable list animates the
    /// other rows out of the way and decides the drop index from where
    /// they have got to, so a pointer that keeps moving while those
    /// animations are mid-flight is asking a list that has not finished
    /// answering the last question.
    ///
    /// `port_grid_test.dart` had the working shape already, and this is
    /// the second file to need it. `tester.drag` does not work at all:
    /// one synthetic move lands the pointer before the list has decided
    /// anything.
    ///
    /// **THE STEP IS 30 AND THE ROWS ARE 100 AND 52 PIXELS TALL.** The
    /// open row carries the two action buttons and the closed one does
    /// not, so a single move sized to "one row" would be right for one
    /// direction and wrong for the other.
    Future<void> dragRow(WidgetTester tester, Uuid id, double dy) async {
      final grip = find.byKey(ValueKey('underlay-drag-${id.v}'));
      expect(grip, findsOneWidget, reason: 'no grip on that row');
      final gesture = await tester.startGesture(tester.getCenter(grip));
      await tester.pump(const Duration(milliseconds: 50));
      for (var step = 0; step < 6; step++) {
        await gesture.moveBy(Offset(0, dy / 6));
        await tester.pumpAndSettle();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('THE GRIP IS ABSENT ON A ONE-PAGE SET', (tester) async {
      // A control that cannot do anything is the shape `#872`'s whole
      // family of findings is about, pointed at ourselves.
      await pump(tester, _controller());

      expect(find.byIcon(Icons.drag_indicator), findsNothing);
    });

    testWidgets('and present on every row once there are two', (tester) async {
      await pump(
        tester,
        _controller(withSecond: true),
        members: const [_member1, _member2],
      );

      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
    });

    testWidgets('dragging the first page below the second reorders them', (
      tester,
    ) async {
      final c = _controller(withSecond: true);
      await pump(tester, c, members: const [_member1, _member2]);
      expect(railOrder(c), ['Level 1', 'Site']);

      await dragRow(tester, _ul1, 180);

      expect(railOrder(c), ['Site', 'Level 1']);
    });

    testWidgets('ONE FIELD WRITE, NEVER A RENUMBER (§11.161.5)', (
      tester,
    ) async {
      // The property that makes this cheap and makes undo one step. A
      // reorder that rewrote every page's order would touch three rows
      // to move one, and `orderBetween` exists precisely so it does not.
      final c = _controller(withSecond: true);
      addThird(c);
      await pump(tester, c, members: const [_member1, _member2]);
      final before = {
        for (final u in c.doc.underlays.values) u.id: u.order.v,
      };

      await dragRow(tester, _ul1, 180);

      final moved = [
        for (final u in c.doc.underlays.values)
          if (u.order.v != before[u.id]) u.name,
      ];
      expect(moved, ['Level 1'], reason: 'exactly one row changed its order');
    });

    testWidgets('one undo puts the pages back', (tester) async {
      final c = _controller(withSecond: true);
      await pump(tester, c, members: const [_member1, _member2]);

      await dragRow(tester, _ul1, 180);
      expect(railOrder(c), ['Site', 'Level 1']);

      c.undo.undo(c.doc);
      await tester.pumpAndSettle();
      expect(railOrder(c), ['Level 1', 'Site']);
    });

    testWidgets('THE OPEN PAGE STAYS OPEN when the rail is reordered', (
      tester,
    ) async {
      // Reordering is a change to the SET, not to what somebody is
      // looking at, and a canvas that switched pictures under a drag
      // would be the surprise this gesture must not have.
      final c = _controller(withSecond: true);
      await pump(tester, c, members: const [_member1, _member2]);

      await dragRow(tester, _ul1, 180);

      expect(find.byType(PlanCanvasScreen), findsOneWidget);
      expect(
        find.byKey(ValueKey('underlay-row-${_ul1.v}')),
        findsOneWidget,
      );
    });
  });
}
