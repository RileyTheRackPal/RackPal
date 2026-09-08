// PLAN-E/2: the Plan editor's two gestures, through the real widget tree.
//
// Every case here asserts the DOCUMENT, not the controller state: what a
// pin drag is for is that the pin moved and one undo puts it back, and a
// test that pinned the live drag position would survive the command never
// running at all.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _now = DateTime.utc(2026, 9, 8);
const _underlayId = Uuid('ul-1');
const _member = 'underlays/ul-1.png';

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

PlanUnderlay _underlay({Uuid? locationId}) => PlanUnderlay(
  id: _underlayId,
  name: 'Level 1',
  locationId: locationId,
  imageMember: _member,
  format: PlanImageFormat.png,
  pixelWidth: 600,
  pixelHeight: 400,
  contentHash: 'sha256:test',
  order: const FracIndex('a0'),
  meta: _meta(),
);

/// A document with one field template in the catalog and, optionally, one
/// already-pinned off-rack device.
DocumentController _controller({PxPt? pinnedAt}) {
  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.underlays[_underlayId] = _underlay();
  doc.templates[catalogTemplateKey('F1')] = TemplateSnapshot(
    templateId: const TemplateId('F1'),
    version: 1,
    contentHash: 'sha256:test-F1',
    capturedAt: _now,
    body: TemplateBody(
      manufacturer: 'Test',
      model: 'speaker',
      displayName: 'speaker',
      typePrefix: 'SPK',
    ),
  );
  if (pinnedAt != null) {
    doc.devices[const Uuid('dev-1')] = DeviceInstance(
      id: const Uuid('dev-1'),
      kind: DeviceKind.offRackPassive,
      templateRef: const TemplateRef(
        templateId: TemplateId('F1'),
        version: 1,
        contentHash: 'sha256:test-F1',
      ),
      designator: 'SPK-1',
      name: 'speaker',
      placement: OffRackPlacement(
        planPin: PlanPin(underlayId: _underlayId, at: pinnedAt),
      ),
      meta: _meta(),
    );
  }
  return DocumentController(doc, clock: FixedClock(_now), actor: 'test');
}

OffRackPlacement? _placementOf(DocumentController c) =>
    c.doc.devices[const Uuid('dev-1')]?.placement as OffRackPlacement?;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlanImageCache cache;
  setUp(() => cache = PlanImageCache());
  tearDown(() => cache.dispose());

  /// Mounts the screen at the window's origin with an identity viewport,
  /// so a scene point, a local point and a global point all coincide and
  /// the tests can be written in the underlay's own pixels.
  Future<
    ({
      SelectionController selection,
      ViewportController viewport,
      GlobalKey<PlanCanvasScreenState> key,
      List<String> refusals,
    })
  >
  pump(WidgetTester tester, DocumentController controller) async {
    await tester.runAsync(() async {
      await cache.load(_member, await _png(600, 400));
    });
    final selection = SelectionController();
    final viewport = ViewportController();
    final key = GlobalKey<PlanCanvasScreenState>();
    final refusals = <String>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            height: 400,
            child: PlanCanvasScreen(
              key: key,
              controller: controller,
              underlay: _underlay(),
              images: cache.resolver,
              measurer: const _ZeroMeasurer(),
              selection: selection,
              viewport: viewport,
              onRefuse: refusals.add,
            ),
          ),
        ),
      ),
    );
    return (
      selection: selection,
      viewport: viewport,
      key: key,
      refusals: refusals,
    );
  }

  group('pinsOnUnderlay', () {
    test('is ordered rack first, then by id, so the display list is '
        'deterministic', () {
      // A display list is compared byte for byte (M2-C) and this list
      // decides op order, so `Map` insertion order would make the same
      // project produce two different scenes. The rack leads because it is
      // the datum and a mark drawn later is drawn on top.
      final c = _controller(pinnedAt: const PxPt(10, 10));
      c.doc.racks[const Uuid('rk-9')] = Rack(
        id: const Uuid('rk-9'),
        name: 'Rack',
        designator: 'RK-1',
        heightU: 12,
        order: const FracIndex('a0'),
        meta: _meta(),
        planPin: const PlanPin(underlayId: _underlayId, at: PxPt(5, 5)),
      );
      final pins = pinsOnUnderlay(c.doc, _underlayId);
      expect(pins.map((p) => p.carrier), [
        PlanPinCarrier.rack,
        PlanPinCarrier.device,
      ]);
    });

    test('ignores a pin that names a DIFFERENT underlay', () {
      // A document may hold several plans; drawing another plan's pins on
      // this one would put a mark where nothing is.
      final c = _controller(pinnedAt: const PxPt(10, 10));
      expect(pinsOnUnderlay(c.doc, const Uuid('ul-other')), isEmpty);
    });
  });

  group('selecting', () {
    testWidgets('a click on a pin selects its carrier', (tester) async {
      final c = _controller(pinnedAt: const PxPt(300, 200));
      final h = await pump(tester, c);

      await tester.tapAt(const Offset(300, 200));
      await tester.pump();

      expect(h.selection.ids, {const Uuid('dev-1')});
    });

    testWidgets('a click on empty plan clears the selection', (tester) async {
      final c = _controller(pinnedAt: const PxPt(300, 200));
      final h = await pump(tester, c);
      await tester.tapAt(const Offset(300, 200));
      await tester.pump();

      await tester.tapAt(const Offset(60, 40));
      await tester.pump();

      expect(h.selection.ids, isEmpty);
    });
  });

  group('dragging a pin', () {
    testWidgets('moves it, and ONE undo puts it back', (tester) async {
      // The whole obligation in one case: the document holds the new
      // position, and a single undo restores the old one. A drag that
      // wrote per frame would need as many undos as it had move events.
      final c = _controller(pinnedAt: const PxPt(300, 200));
      await pump(tester, c);

      final gesture = await tester.startGesture(const Offset(300, 200));
      await gesture.moveBy(const Offset(40, 25));
      await tester.pump();
      await gesture.moveBy(const Offset(20, 15));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(_placementOf(c)!.planPin!.at, const PxPt(360, 240));
      c.undo.undo(c.doc);
      expect(_placementOf(c)!.planPin!.at, const PxPt(300, 200));
    });

    testWidgets('keeps the grab offset, so the pin does not jump to the '
        'cursor', (tester) async {
      // Grabbed 3 right and 2 down of centre, then moved by (30, 20): the
      // pin ends 30 right and 20 down of where it WAS, at (330, 220), not
      // centred under the pointer at (333, 222).
      //
      // THE GRAB IS ONLY 3px OFF CENTRE BECAUSE THE MARKER IS SMALL. Its
      // radius is a fraction of the underlay's long side (600 / 110, so
      // about 5.5 scene units here), and an earlier draft of this case
      // grabbed 12 units out, missed the hit box entirely and asserted
      // that nothing moved -- which it dutifully did not.
      final c = _controller(pinnedAt: const PxPt(300, 200));
      await pump(tester, c);

      final gesture = await tester.startGesture(const Offset(303, 202));
      await gesture.moveBy(const Offset(30, 20));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(_placementOf(c)!.planPin!.at, const PxPt(330, 220));
    });

    testWidgets('a press that never moves writes nothing', (tester) async {
      // A click is not a zero-length drag, and a document that gained an
      // undo entry for one would fill the 200-entry cap with nothing.
      final c = _controller(pinnedAt: const PxPt(300, 200));
      await pump(tester, c);
      final before = c.doc.stateId;

      await tester.tapAt(const Offset(300, 200));
      await tester.pump();

      expect(c.doc.stateId, before);
      expect(_placementOf(c)!.planPin!.at, const PxPt(300, 200));
    });

    testWidgets('a drag from empty plan moves nothing', (tester) async {
      final c = _controller(pinnedAt: const PxPt(300, 200));
      await pump(tester, c);

      final gesture = await tester.startGesture(const Offset(60, 40));
      await gesture.moveBy(const Offset(50, 50));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(_placementOf(c)!.planPin!.at, const PxPt(300, 200));
    });
  });

  group('the palette drop', () {
    testWidgets('places the device and pins it where the pointer released', (
      tester,
    ) async {
      final c = _controller();
      final h = await pump(tester, c);
      expect(c.doc.devices, isEmpty);

      // The host arms from the palette's own `onArmDrag`; the pointer is
      // then tracked globally, because it starts over a widget this screen
      // does not own.
      final pointer = TestPointer(7, PointerDeviceKind.mouse);
      final down = pointer.down(const Offset(-40, 10));
      // THE DOWN GOES TO THE BINDING TOO. In the product the pointer lands
      // on a real palette row, so `GestureBinding` has already seen it by
      // the time `onArmDrag` fires; a route added for a pointer the
      // binding never saw receives nothing.
      await tester.sendEventToBinding(down);
      h.key.currentState!.armPaletteDrag('F1', down);
      await tester.sendEventToBinding(pointer.move(const Offset(220, 150)));
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();

      final device = c.doc.devices.values.single;
      final placement = device.placement as OffRackPlacement;
      expect(placement.planPin!.at, const PxPt(220, 150));
      expect(h.selection.ids, {device.id});
    });

    testWidgets('a release OUTSIDE the canvas places nothing, and says '
        'nothing', (tester) async {
      // docs/04 §3.1's escape hatch is the staging bin, and the bin has no
      // producer (docs/15 §6, StagedPlacement's only writer in lib/ is the
      // JSON decoder). A chip promising a bin that cannot take anything
      // would be the untruth DR-091 refuses one level up, so the release
      // is a plain no-op.
      final c = _controller();
      final h = await pump(tester, c);

      final pointer = TestPointer(8, PointerDeviceKind.mouse);
      final down = pointer.down(const Offset(-40, 10));
      await tester.sendEventToBinding(down);
      h.key.currentState!.armPaletteDrag('F1', down);
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();

      expect(c.doc.devices, isEmpty);
      expect(h.refusals, isEmpty);
    });

    testWidgets('an unknown row is REFUSED by name, and nothing is made', (
      tester,
    ) async {
      final c = _controller();
      final h = await pump(tester, c);

      final pointer = TestPointer(9, PointerDeviceKind.mouse);
      final down = pointer.down(const Offset(-40, 10));
      await tester.sendEventToBinding(down);
      h.key.currentState!.armPaletteDrag('NOPE', down);
      await tester.sendEventToBinding(pointer.move(const Offset(100, 100)));
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();

      expect(c.doc.devices, isEmpty);
      expect(h.refusals.single, contains('Unknown catalog template'));
    });
  });
}
