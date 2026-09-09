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

DocumentController _controller({
  bool withUnderlay = true,
  bool withSecond = false,
  bool withRack = true,
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
