// PLAN-E/2: the Plan editor's two gestures, through the real widget tree.
//
// Every case here asserts the DOCUMENT, not the controller state: what a
// pin drag is for is that the pin moved and one undo puts it back, and a
// test that pinned the live drag position would survive the command never
// running at all.

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

const _outletId = Uuid('out-1');

/// Adds one outlet, the subject the fast path arms.
void _addOutlet(DocumentController c) {
  c.doc.outlets[_outletId] = Outlet(
    id: _outletId,
    structureBodyId: const Uuid('body-1'),
    designation: 'D-014',
    order: const FracIndex('a0'),
    meta: _meta(),
  );
}

const _armedDrop = ArmedPin(outletId: _outletId, label: 'D-014');

const _roomId = Uuid('room-1');

/// A calibration that yields a factor: 100 px to 36 in, so one pixel is
/// 0.36 in and the arithmetic below is readable (`LEN-A/5`).
const _scale = PlanScale(
  a: PxPt(0, 0),
  b: PxPt(100, 0),
  distance: Len(36 * Len.nmPerInch),
);

/// Calibrates the fixture's underlay, so `roomEstimateFor` can measure.
void _calibrate(DocumentController c) =>
    c.doc.underlays[_underlayId]!.scale = _scale;

/// Pins the rack and wires one run from it to a drop in [roomId], which is
/// what makes that rack the room's DATUM (DR-147 §11.146.2 as applied by
/// `LEN-A/3`).
void _servedByRack(DocumentController c, Uuid roomId) {
  const rackId = Uuid('rk-est');
  c.doc.racks[rackId] = Rack(
    id: rackId,
    name: 'Head end',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
    planPin: const PlanPin(underlayId: _underlayId, at: PxPt(0, 0)),
  );
  const devId = Uuid('dev-est');
  c.doc.devices[devId] = DeviceInstance(
    id: devId,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('F1'),
      version: 1,
      contentHash: 'sha256:test-F1',
    ),
    designator: 'PP-1',
    name: 'patch panel',
    placement: const RailPlacement(
      rackId: rackId,
      ruIndex: 1,
      face: Face.rear,
    ),
    meta: _meta(),
  );
  const portId = Uuid('port-est');
  c.doc.ports[portId] = Port(
    id: portId,
    deviceId: devId,
    designator: 'J01',
  );
  const linkId = Uuid('link-est');
  c.doc.links[linkId] = Link(
    id: linkId,
    designator: 'W001',
    media: const MediaTypeId('media.cat6_utp'),
    order: const FracIndex('a0'),
    meta: _meta(),
    conductors: [
      Conductor(
        from: const PortEndpoint(portId),
        to: PlaceEndpoint(locationId: roomId, description: 'TV wall'),
      ),
    ],
  );
}

/// Adds one room, the subject an outline hangs on (`LEN-A/4`).
void _addRoom(DocumentController c, {RoomOutline? outline}) {
  c.doc.locations[_roomId] = Location(
    id: _roomId,
    kind: LocationKind.room,
    name: 'Great Room',
    code: 'GR',
    order: const FracIndex('a0'),
    meta: _meta(),
    planOutline: outline,
  );
}

RoomOutline? _outlineOf(DocumentController c) =>
    c.doc.locations[_roomId]?.planOutline;

/// The shape `LEN-A/8`'s cases start from. Its far corner is 500 px from
/// the rack pin at the origin, which is the figure `LEN-A/5`'s own case
/// already reads as 180 inches.
RoomOutline _triangle() => RoomOutline(
  underlayId: _underlayId,
  vertices: const [PxPt(100, 100), PxPt(400, 100), PxPt(400, 300)],
);

/// One corner dragged with a real pointer, through `CanvasIntentDetector`.
Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final pointer = TestPointer(91, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.down(from));
  // TWO MOVES, because one is what a test writes and several is what a
  // mouse sends. The count is also the subject of the one-command case.
  await tester.sendEventToBinding(pointer.move(Offset.lerp(from, to, .5)!));
  await tester.sendEventToBinding(pointer.move(to));
  await tester.sendEventToBinding(pointer.up());
  await tester.pump();
}

/// A reshape already running on the fixture's room, disposed with the test.
PlanReshapeController _reshaping() {
  final mode = PlanReshapeController()..begin(_roomId);
  addTearDown(mode.dispose);
  return mode;
}

/// The palette row for [id], resolved the way `PaletteHost` resolves it.
PlaceableTemplate _row(RackDocument doc, String id) =>
    buildPlaceableTemplates(doc).firstWhere((r) => r.id == id);

/// A row for a template the document does not hold.
///
/// **THE RACE, NOT A TYPO.** The palette offered it, the drag armed, and
/// the template left the document before the drop: `PaletteHost` cannot
/// hand over a row it failed to resolve, so this is the only way the
/// refusal below is still reachable.
PlaceableTemplate _goneRow() => PlaceableTemplate(
  templateId: const TemplateId('GONE'),
  version: 1,
  contentHash: 'sha256:gone',
  body: TemplateBody(
    manufacturer: 'Test',
    model: 'gone',
    displayName: 'Gone',
  ),
  provenance: TemplateProvenance.project,
);

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
  pump(
    WidgetTester tester,
    DocumentController controller, {
    PlanPinArmController? arm,
    MarqueeController? marquee,
    PlanOutlineController? outline,
    PlanReshapeController? reshape,
  }) async {
    await tester.runAsync(() async {
      await cache.load(_member, await _png(600, 400));
    });
    final selection = SelectionController();
    final viewport = ViewportController();
    final key = GlobalKey<PlanCanvasScreenState>();
    final refusals = <String>[];
    await tester.pumpWidget(
      // A `MaterialApp` RATHER THAN A BARE `Directionality`, and the
      // reason is `PLAN-E/3`'s chip: it is a `Material` with a `Theme`
      // lookup and an `IconButton`, none of which resolve without one.
      // `Align(topLeft)` keeps the canvas at the window origin, so every
      // coordinate below is still the underlay's own pixel space.
      MaterialApp(
        home: Align(
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
              arm: arm,
              marquee: marquee,
              outline: outline,
              reshape: reshape,
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

  group('LEN-A/4: the outline draw, through the real mounting', () {
    // ═══════════════════════════════════════════════════════════════════
    // THE MOUNTING IS THE POINT, NOT THE CONTROLLER
    // ═══════════════════════════════════════════════════════════════════
    // `plan_outline_test.dart` proves the mode. What it cannot prove is
    // that a click on the canvas reaches it, and this epic has already
    // shipped a gesture that could not: the drop-table fast path was dead
    // from `PLAN-E/6` to `PLAN-F/0` because the armed branch was
    // unreachable on every mounting that supplies a band, and the canvas
    // tests predated the band and passed null.
    //
    // So every case below drives the widget.

    testWidgets('three clicks and a fourth on the first corner writes the '
        'outline', (tester) async {
      final c = _controller();
      _addRoom(c);
      final outline = PlanOutlineController()..begin(_roomId);
      await pump(tester, c, outline: outline);

      await tester.tapAt(const Offset(100, 100));
      await tester.tapAt(const Offset(400, 100));
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(_outlineOf(c), isNull, reason: 'not closed yet');

      await tester.tapAt(const Offset(100, 100));
      await tester.pump();

      expect(_outlineOf(c), isNotNull);
      expect(_outlineOf(c)!.vertices, hasLength(3));
      expect(_outlineOf(c)!.underlayId, _underlayId);
      expect(outline.isActive, isFalse, reason: 'the draw ended');
    });

    testWidgets('THE CLOSE HAS A RADIUS, so a click NEAR the first corner '
        'closes rather than adding a fourth', (tester) async {
      // Ten points of pointer travel. A person aiming at a three-point
      // dot with a mouse does not land on it.
      final c = _controller();
      _addRoom(c);
      await pump(tester, c, outline: PlanOutlineController()..begin(_roomId));

      await tester.tapAt(const Offset(100, 100));
      await tester.tapAt(const Offset(400, 100));
      await tester.tapAt(const Offset(400, 300));
      await tester.tapAt(const Offset(105, 104));
      await tester.pump();

      expect(_outlineOf(c)!.vertices, hasLength(3));
    });

    testWidgets('and a click OUTSIDE the radius is a fourth corner', (
      tester,
    ) async {
      // The negative that makes the case above mean something: a radius
      // large enough to swallow a deliberate corner would pass it.
      final c = _controller();
      _addRoom(c);
      final outline = PlanOutlineController()..begin(_roomId);
      await pump(tester, c, outline: outline);

      await tester.tapAt(const Offset(100, 100));
      await tester.tapAt(const Offset(400, 100));
      await tester.tapAt(const Offset(400, 300));
      await tester.tapAt(const Offset(130, 100));
      await tester.pump();

      expect(_outlineOf(c), isNull);
      expect(outline.vertices, hasLength(4));
    });

    testWidgets('the write is ONE undoable command', (tester) async {
      final c = _controller();
      _addRoom(c);
      await pump(tester, c, outline: PlanOutlineController()..begin(_roomId));

      for (final at in const [
        Offset(100, 100),
        Offset(400, 100),
        Offset(400, 300),
        Offset(100, 100),
      ]) {
        await tester.tapAt(at);
      }
      await tester.pump();
      expect(_outlineOf(c), isNotNull);

      c.undo.undo(c.doc);
      expect(_outlineOf(c), isNull);
    });

    testWidgets('RIGHT-CLICK TAKES ONE CORNER BACK and leaves the draw '
        'running', (tester) async {
      final c = _controller();
      _addRoom(c);
      final outline = PlanOutlineController()..begin(_roomId);
      await pump(tester, c, outline: outline);

      await tester.tapAt(const Offset(100, 100));
      await tester.tapAt(const Offset(400, 100));
      expect(outline.vertices, hasLength(2));

      final gesture = await tester.startGesture(
        const Offset(400, 100),
        buttons: kSecondaryButton,
      );
      await gesture.up();
      await tester.pump();

      expect(outline.vertices, hasLength(1));
      expect(outline.isActive, isTrue);
    });

    testWidgets('Esc cancels the whole draw, which is what it already '
        'means on this canvas', (tester) async {
      final c = _controller();
      _addRoom(c);
      final outline = PlanOutlineController()..begin(_roomId);
      await pump(tester, c, outline: outline);

      await tester.tapAt(const Offset(100, 100));
      await tester.tapAt(const Offset(400, 100));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(outline.isActive, isFalse);
      expect(outline.vertices, isEmpty);
      expect(_outlineOf(c), isNull);
    });

    testWidgets('the chip is up while the draw runs, and it is the ONLY '
        'chip', (tester) async {
      final c = _controller();
      _addRoom(c);
      _addOutlet(c);
      await pump(
        tester,
        c,
        outline: PlanOutlineController()..begin(_roomId),
        arm: PlanPinArmController()..arm(_armedDrop),
      );

      // TWO CHIPS STACKED IN ONE CORNER WOULD BE TWO INSTRUCTIONS
      // COMPETING, and the one the next click obeys is the draw.
      expect(find.byKey(PlanOutlineChip.chipKey), findsOneWidget);
      expect(find.byKey(PlanPinArmChip.chipKey), findsNothing);
    });

    testWidgets('AND THE DRAW OUTRANKS AN ARMED PIN on the click itself, '
        'not only on the chip', (tester) async {
      // The chip case above would pass against a canvas that drew the
      // right chrome and pinned the armed drop anyway.
      final c = _controller();
      _addRoom(c);
      _addOutlet(c);
      final outline = PlanOutlineController()..begin(_roomId);
      await pump(
        tester,
        c,
        outline: outline,
        arm: PlanPinArmController()..arm(_armedDrop),
      );

      await tester.tapAt(const Offset(100, 100));
      await tester.pump();

      expect(outline.vertices, hasLength(1));
      expect(c.doc.outlets[_outletId]!.planPin, isNull);
    });

    // ═══════════════════════════════════════════════════════════════
    // LEN-A/5: CLOSING A ROOM FILLS ITS ESTIMATE, IN ONE UNDO ENTRY
    // ═══════════════════════════════════════════════════════════════
    // Ruled by the user: the figure lands automatically, marked as
    // computed, and never over a value a person entered.

    testWidgets('closing an outline WRITES the derived estimate, marked '
        'as computed', (tester) async {
      final c = _controller();
      _addRoom(c);
      _calibrate(c);
      _servedByRack(c, _roomId);
      await pump(tester, c, outline: PlanOutlineController()..begin(_roomId));

      for (final at in const [
        Offset(100, 100),
        Offset(400, 100),
        Offset(400, 300),
        Offset(100, 100),
      ]) {
        await tester.tapAt(at);
      }
      await tester.pump();

      // 400 by 300 px from the rack pin at (0, 0) is 500 px, at 0.36 in.
      expect(
        c.doc.locations[_roomId]!.estimatedRunLengthFromRack,
        const Len(180 * Len.nmPerInch),
      );
      expect(
        c.doc.locations[_roomId]!.estimatedRunLengthOrigin,
        RunLengthOrigin.computedFromPlan,
      );
    });

    testWidgets('ONE UNDO TAKES BOTH BACK, because it was one act', (
      tester,
    ) async {
      // Two entries would make Ctrl+Z remove the estimate and leave the
      // shape: a state the person never asked for and did not create.
      final c = _controller();
      _addRoom(c);
      _calibrate(c);
      _servedByRack(c, _roomId);
      await pump(tester, c, outline: PlanOutlineController()..begin(_roomId));

      for (final at in const [
        Offset(100, 100),
        Offset(400, 100),
        Offset(400, 300),
        Offset(100, 100),
      ]) {
        await tester.tapAt(at);
      }
      await tester.pump();

      c.undo.undo(c.doc);
      expect(_outlineOf(c), isNull);
      expect(c.doc.locations[_roomId]!.estimatedRunLengthFromRack, isNull);
      expect(c.doc.locations[_roomId]!.estimatedRunLengthOrigin, isNull);
    });

    testWidgets('A TYPED FIGURE SURVIVES THE DRAW, which is the case the '
        'auto-fill is not allowed to win', (tester) async {
      final c = _controller();
      _addRoom(c);
      _calibrate(c);
      _servedByRack(c, _roomId);
      // THROUGH THE REAL WRITER, not the model's `@internal` setters:
      // those are package-private, and reaching past them would also let
      // this case set a pair the product cannot produce.
      c.run(
        SetRoomEstimateCommand.typed(
          locationId: _roomId,
          length: const Len(999 * Len.nmPerInch),
        ),
      );
      await pump(tester, c, outline: PlanOutlineController()..begin(_roomId));

      for (final at in const [
        Offset(100, 100),
        Offset(400, 100),
        Offset(400, 300),
        Offset(100, 100),
      ]) {
        await tester.tapAt(at);
      }
      await tester.pump();

      expect(_outlineOf(c), isNotNull, reason: 'the shape still landed');
      expect(
        c.doc.locations[_roomId]!.estimatedRunLengthFromRack,
        const Len(999 * Len.nmPerInch),
      );
      expect(
        c.doc.locations[_roomId]!.estimatedRunLengthOrigin,
        RunLengthOrigin.typed,
      );
    });

    testWidgets('and an UNMEASURABLE plan writes the shape and no figure', (
      tester,
    ) async {
      // No calibration, so `roomEstimateFor` refuses. The outline is
      // still a thing the person drew and is still theirs.
      final c = _controller();
      _addRoom(c);
      _servedByRack(c, _roomId);
      await pump(tester, c, outline: PlanOutlineController()..begin(_roomId));

      for (final at in const [
        Offset(100, 100),
        Offset(400, 100),
        Offset(400, 300),
        Offset(100, 100),
      ]) {
        await tester.tapAt(at);
      }
      await tester.pump();

      expect(_outlineOf(c), isNotNull);
      expect(c.doc.locations[_roomId]!.estimatedRunLengthFromRack, isNull);
    });

    testWidgets('a FINISHED outline draws even where no draw mode is '
        'offered', (tester) async {
      // Otherwise a saved shape is invisible until somebody presses a
      // button that is not there.
      final c = _controller();
      _addRoom(
        c,
        outline: RoomOutline(
          underlayId: _underlayId,
          vertices: const [PxPt(10, 10), PxPt(90, 10), PxPt(90, 60)],
        ),
      );
      await pump(tester, c);

      expect(find.byKey(PlanOutlineLayer.layerKey), findsOneWidget);
    });

    testWidgets('and an outline on ANOTHER underlay does not', (
      tester,
    ) async {
      final c = _controller();
      _addRoom(
        c,
        outline: RoomOutline(
          underlayId: const Uuid('other-underlay'),
          vertices: const [PxPt(10, 10), PxPt(90, 10), PxPt(90, 60)],
        ),
      );
      await pump(tester, c);

      expect(find.byKey(PlanOutlineLayer.layerKey), findsNothing);
    });
  });

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

  group('the fast path (PLAN-E/3, DR-141)', () {
    testWidgets('an armed click pins the armed OUTLET where it landed', (
      tester,
    ) async {
      final c = _controller();
      _addOutlet(c);
      final arm = PlanPinArmController()..arm(_armedDrop);
      final h = await pump(tester, c, arm: arm);

      await tester.tapAt(const Offset(410, 260));
      await tester.pump();

      expect(c.doc.outlets[_outletId]!.planPin!.at, const PxPt(410, 260));
      expect(h.selection.ids, {_outletId});
    });

    testWidgets('THE MODE OUTLIVES THE PIN, so the chip is still up', (
      tester,
    ) async {
      // DR-141 §11.140.2, asserted through the real screen rather than
      // only on the controller: a one-shot arm would leave no chip here.
      final c = _controller();
      _addOutlet(c);
      final arm = PlanPinArmController()..arm(_armedDrop);
      await pump(tester, c, arm: arm);

      await tester.tapAt(const Offset(410, 260));
      await tester.pump();

      expect(arm.isActive, isTrue);
      expect(arm.armed, isNull);
      expect(find.byKey(PlanPinArmChip.chipKey), findsOneWidget);
    });

    testWidgets('a click while the mode is on but nothing armed still '
        'CLEARS, rather than doing nothing', (tester) async {
      // The state DR-141 creates deliberately. A click here has no pin to
      // place, so it must fall back to the ordinary meaning of a click on
      // empty plan; silently doing nothing is the no-op docs/04 §3.4
      // forbids.
      final c = _controller(pinnedAt: const PxPt(300, 200));
      _addOutlet(c);
      final arm = PlanPinArmController();
      final h = await pump(tester, c, arm: arm);
      await tester.tapAt(const Offset(300, 200));
      await tester.pump();
      expect(h.selection.ids, isNotEmpty);

      await tester.tapAt(const Offset(60, 40));
      await tester.pump();

      expect(h.selection.ids, isEmpty);
      expect(c.doc.outlets[_outletId]!.planPin, isNull);
    });

    testWidgets('a click that HITS a pin selects it rather than pinning the '
        'armed drop on top', (tester) async {
      // An armed mode may not repurpose a click that already meant
      // something. The user was pointing at that device for a reason.
      final c = _controller(pinnedAt: const PxPt(300, 200));
      _addOutlet(c);
      final arm = PlanPinArmController()..arm(_armedDrop);
      final h = await pump(tester, c, arm: arm);

      await tester.tapAt(const Offset(300, 200));
      await tester.pump();

      expect(h.selection.ids, {const Uuid('dev-1')});
      expect(c.doc.outlets[_outletId]!.planPin, isNull);
      expect(arm.armed, _armedDrop, reason: 'still armed for the next click');
    });

    testWidgets('an outlet deleted while armed is REFUSED, not pinned onto '
        'nothing', (tester) async {
      // The mode outlives the pin by design, so it also outlives an outlet
      // removed in another tab while it was armed.
      final c = _controller();
      final arm = PlanPinArmController()..arm(_armedDrop);
      final h = await pump(tester, c, arm: arm);

      await tester.tapAt(const Offset(410, 260));
      await tester.pump();

      expect(h.refusals.single, contains('not in the project any more'));
      expect(arm.armed, isNull, reason: 'the dead subject is cleared');
      expect(arm.isActive, isTrue);
    });

    testWidgets('ONE undo puts the pinned outlet back', (tester) async {
      final c = _controller();
      _addOutlet(c);
      final arm = PlanPinArmController()..arm(_armedDrop);
      await pump(tester, c, arm: arm);

      await tester.tapAt(const Offset(410, 260));
      await tester.pump();
      expect(c.doc.outlets[_outletId]!.planPin, isNotNull);

      c.undo.undo(c.doc);
      expect(c.doc.outlets[_outletId]!.planPin, isNull);
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
      h.key.currentState!.armPaletteDrag(_row(c.doc, 'F1'), down);
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
      h.key.currentState!.armPaletteDrag(_row(c.doc, 'F1'), down);
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();

      expect(c.doc.devices, isEmpty);
      expect(h.refusals, isEmpty);
    });

    testWidgets('A ROW WHOSE TEMPLATE HAS GONE is refused by name, and '
        'nothing is made', (tester) async {
      // WHAT THIS CASE IS ABOUT CHANGED AT `#885`, and it is worth saying
      // why rather than quietly renaming it. It used to pass the string
      // `'NOPE'` as a `rowKey`, which the canvas handed straight to
      // `buildPlaceOnPlanCommand` as a `catalogId`: a row that does not
      // exist. `PaletteHost` resolves the key now and simply does not
      // call an arm for a row it cannot find, so "an unknown row" is
      // unrepresentable from the product's own surface.
      //
      // What IS still reachable is the race the refusal was really for:
      // the row was offered, the drag was armed, and the template left
      // the document before the drop. A hand-built row is exactly that
      // state, and the sentence it gets is the same one.
      final c = _controller();
      final h = await pump(tester, c);

      final pointer = TestPointer(9, PointerDeviceKind.mouse);
      final down = pointer.down(const Offset(-40, 10));
      await tester.sendEventToBinding(down);
      h.key.currentState!.armPaletteDrag(_goneRow(), down);
      await tester.sendEventToBinding(pointer.move(const Offset(100, 100)));
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();

      expect(c.doc.devices, isEmpty);
      expect(h.refusals.single, contains('Unknown catalog template'));
    });

    testWidgets('A LIBRARY ROW IS COPIED INTO THE PROJECT AND THEN PLACED, '
        'in one undo step', (tester) async {
      // ═════════════════════════════════════════════════════════════════
      // COPY-ON-PLACE IS A PROPERTY OF PLACEMENT (DR-103 §11.102.2)
      // ═════════════════════════════════════════════════════════════════
      // Not of the surface the placement was started from. A library row
      // is not in the document, so dragging one onto a floorplan is a
      // copy AND an add, exactly as it is on the rails. Without this the
      // row would come back "Unknown catalog template", blaming the
      // catalog for a copy nobody made, and `#885` would have put a
      // palette in the Plan view that half its rows refuse.
      final c = _controller();
      final h = await pump(tester, c);
      final row = PlaceableTemplate(
        templateId: const TemplateId('LIB1'),
        version: 1,
        contentHash: 'sha256:lib1',
        body: TemplateBody(
          manufacturer: 'Shelf',
          model: 'lib1',
          displayName: 'Shelf Speaker',
          typePrefix: 'SPK',
        ),
        provenance: const LibraryProvenance(
          libraryId: 'lib-a',
          libraryName: 'Library A',
        ),
      );

      final pointer = TestPointer(11, PointerDeviceKind.mouse);
      final down = pointer.down(const Offset(-40, 10));
      await tester.sendEventToBinding(down);
      h.key.currentState!.armPaletteDrag(row, down);
      await tester.sendEventToBinding(pointer.move(const Offset(180, 120)));
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();

      expect(h.refusals, isEmpty, reason: 'the copy is what makes it place');
      final device = c.doc.devices.values.single;
      expect(
        (device.placement as OffRackPlacement).planPin!.at,
        const PxPt(180, 120),
      );
      expect(
        c.doc.templates.values.map((t) => t.templateId.v),
        contains('LIB1'),
        reason: 'the template was copied into the project (DR-103)',
      );

      c.undo.undo(c.doc);
      await tester.pump();
      expect(
        c.doc.devices,
        isEmpty,
        reason:
            'ONE undo takes back both halves, because they are one '
            'transaction',
      );
      expect(
        c.doc.templates.values.map((t) => t.templateId.v),
        isNot(contains('LIB1')),
      );
    });
  });

  group('PLAN-E/5: Esc, the whole keyboard this surface has', () {
    testWidgets('DISMISSES THE ARM MODE FIRST, and leaves the selection', (
      tester,
    ) async {
      // DR-141's order. The mode is the thing on screen saying it is on,
      // and an Esc that took the selection with it would remove something
      // the user did not ask about on a keystroke meaning "stop the last
      // thing".
      final c = _controller(pinnedAt: const PxPt(300, 200));
      _addOutlet(c);
      final arm = PlanPinArmController()..arm(_armedDrop);
      final h = await pump(tester, c, arm: arm);
      h.selection.apply([const Uuid('dev-1')], SelectMode.replace);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(arm.isActive, isFalse);
      expect(
        h.selection.ids,
        {const Uuid('dev-1')},
        reason: 'one Esc, one rung',
      );
    });

    testWidgets('clears the selection when nothing is armed', (tester) async {
      final c = _controller(pinnedAt: const PxPt(300, 200));
      final h = await pump(tester, c);
      h.selection.apply([const Uuid('dev-1')], SelectMode.replace);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(h.selection.ids, isEmpty);
    });

    testWidgets('FALLS THROUGH when there is nothing to cancel', (
      tester,
    ) async {
      // THE GATE IS THE BINDING, not an early return in the callback.
      // `Action.consumesKey` defaults to true and maps a run to
      // `handled` whatever the body did, so a screen that declined
      // INSIDE its callback would still eat the key and a dialog behind
      // this canvas would stop closing. Only `isActionEnabled == false`
      // yields `ignored`.
      //
      // Asserted by putting a handler ABOVE the screen and watching it
      // receive the key, which is the only way to see a fall-through
      // from outside.
      var reachedTheAncestor = false;
      final c = _controller();
      await tester.runAsync(() async {
        await cache.load(_member, await _png(600, 400));
      });
      final selection = SelectionController();
      await tester.pumpWidget(
        MaterialApp(
          home: Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) {
                    reachedTheAncestor = true;
                    return null;
                  },
                ),
              },
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 600,
                  height: 400,
                  child: PlanCanvasScreen(
                    controller: c,
                    underlay: _underlay(),
                    images: cache.resolver,
                    measurer: const _ZeroMeasurer(),
                    selection: selection,
                    viewport: ViewportController(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Nothing armed, nothing selected.
      expect(selection.ids, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(reachedTheAncestor, isTrue);
    });
  });

  group('PLAN-E/4: a row dragged out of the unpinned strip', () {
    const rackId = Uuid('rk-1');

    /// The document DR-140 is about: a rack with no pin, which nothing in
    /// any of PLAN-E's chapters could give one until this gesture.
    DocumentController withRack() {
      final c = _controller();
      c.doc.racks[rackId] = Rack(
        id: rackId,
        name: 'Head end',
        designator: 'RK-1',
        heightU: 42,
        order: const FracIndex('a0'),
        meta: _meta(),
      );
      return c;
    }

    /// Arms [carrier]/[entityId] from off-canvas and releases at [at].
    Future<void> dragOut(
      WidgetTester tester,
      PlanCanvasScreenState state,
      PinCarrier carrier,
      Uuid entityId, {
      required Offset at,
      int pointerId = 30,
      Future<void> Function()? beforeRelease,
    }) async {
      final pointer = TestPointer(pointerId, PointerDeviceKind.mouse);
      // The strip sits BELOW the canvas, so the down starts off it. The
      // binding has to see the down for the same reason the palette case
      // says: a route added for a pointer it never saw receives nothing.
      final down = pointer.down(const Offset(300, 460));
      await tester.sendEventToBinding(down);
      state.armCarrierDrag(carrier, entityId, down);
      await tester.sendEventToBinding(pointer.move(at));
      await beforeRelease?.call();
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();
    }

    testWidgets('PINS A RACK, which no gesture in this epic could do', (
      tester,
    ) async {
      // DR-140 §11.139 in one case. `Rack.planPin` shipped at PLAN-C and
      // `SetPlanPinCommand` has accepted `PinCarrier.rack` just as long:
      // the model and the writer were ready and nothing could press the
      // button. Without a rack pin `PLN-003` fires and NO length on the
      // plan derives at all.
      final c = withRack();
      final h = await pump(tester, c);
      expect(c.doc.racks[rackId]!.planPin, isNull);

      await dragOut(
        tester,
        h.key.currentState!,
        PinCarrier.rack,
        rackId,
        at: const Offset(210, 45),
      );

      final pin = c.doc.racks[rackId]!.planPin;
      expect(pin!.underlayId, _underlayId);
      expect(pin.at, const PxPt(210, 45));
      expect(h.selection.ids, {rackId});
    });

    testWidgets('is ONE command, so one undo takes the pin back off', (
      tester,
    ) async {
      final c = withRack();
      final h = await pump(tester, c);

      await dragOut(
        tester,
        h.key.currentState!,
        PinCarrier.rack,
        rackId,
        at: const Offset(120, 200),
        pointerId: 31,
      );
      expect(c.doc.racks[rackId]!.planPin, isNotNull);

      c.undoLast();
      expect(
        c.doc.racks[rackId]!.planPin,
        isNull,
        reason: 'one gesture, one entry on the stack',
      );
    });

    testWidgets('pins an OUTLET and an OFF-RACK DEVICE by the same path', (
      tester,
    ) async {
      // The strip lists three kinds of carrier and the row carries which
      // one it is, so this asserts the writer is chosen from the row
      // rather than assumed.
      final c = _controller();
      _addOutlet(c);
      c.doc.devices[const Uuid('dev-9')] = DeviceInstance(
        id: const Uuid('dev-9'),
        kind: DeviceKind.offRackPassive,
        templateRef: const TemplateRef(
          templateId: TemplateId('F1'),
          version: 1,
          contentHash: 'sha256:test-F1',
        ),
        designator: 'SPK-9',
        name: 'speaker',
        placement: const OffRackPlacement(),
        meta: _meta(),
      );
      final h = await pump(tester, c);

      await dragOut(
        tester,
        h.key.currentState!,
        PinCarrier.outlet,
        _outletId,
        at: const Offset(80, 90),
        pointerId: 32,
      );
      await dragOut(
        tester,
        h.key.currentState!,
        PinCarrier.offRackDevice,
        const Uuid('dev-9'),
        at: const Offset(400, 300),
        pointerId: 33,
      );

      expect(c.doc.outlets[_outletId]!.planPin!.at, const PxPt(80, 90));
      expect(
        (c.doc.devices[const Uuid('dev-9')]!.placement as OffRackPlacement)
            .planPin!
            .at,
        const PxPt(400, 300),
      );
    });

    testWidgets('a release OUTSIDE the canvas leaves it exactly where it '
        'was, and says nothing', (tester) async {
      // Doubly a no-op for a strip row: the carrier is already in the
      // document, so dropping it nowhere leaves it in the strip, which is
      // what the user can see. Nothing honest to announce.
      final c = withRack();
      final h = await pump(tester, c);

      final pointer = TestPointer(34, PointerDeviceKind.mouse);
      final down = pointer.down(const Offset(300, 460));
      await tester.sendEventToBinding(down);
      h.key.currentState!.armCarrierDrag(PinCarrier.rack, rackId, down);
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();

      expect(c.doc.racks[rackId]!.planPin, isNull);
      expect(h.refusals, isEmpty);
    });

    testWidgets('a carrier DELETED under the pointer is refused by name, '
        'and no dead command is pushed', (tester) async {
      // The strip is built from a document another tab can edit
      // mid-gesture. `SetPlanPinCommand` answers a missing entity by
      // returning without writing, which is right for the command and
      // wrong here: `run` would push an entry whose apply did nothing and
      // whose revert THROWS, so the next undo fails on a step that undid
      // nothing.
      final c = withRack();
      final h = await pump(tester, c);

      await dragOut(
        tester,
        h.key.currentState!,
        PinCarrier.rack,
        rackId,
        at: const Offset(210, 45),
        pointerId: 35,
        beforeRelease: () async => c.doc.racks.remove(rackId),
      );

      expect(h.refusals.single, contains('not in the project any more'));
      // AND THE UNDO STACK IS UNTOUCHED, which is the half a refusal
      // message would hide.
      expect(c.undo.canUndo, isFalse);
    });
  });

  group('A BAND ARMED BY A CLICK MUST NOT SWALLOW THE CLICK', () {
    // ═══════════════════════════════════════════════════════════════════
    // THE REGRESSION `PLAN-E/6` SHIPPED AND NOTHING SAW
    // ═══════════════════════════════════════════════════════════════════
    // `beginDrag` arms the band on every press that misses a pin, so
    // `MarqueeController.isActive` is true from the instant of a plain
    // click. `commitDrag` asked exactly that and returned, which put the
    // armed-pin and click-to-clear branches out of reach on any mounting
    // that supplies a band. `PlanEditorScreen` supplies one and every case
    // in this file predated it and passed null, so DR-141's whole fast
    // path was dead in the app with a green suite.
    //
    // The two other adoptions ask whether the POINTER MOVED and were
    // right from the start. These cases pin that question rather than the
    // controller's state.
    //
    // **ONLY THE FIRST CASE IS LOAD-BEARING AGAINST THE DEFECT**, measured
    // by restoring it: the other three stay green with the condition
    // mutated back, because a sweep clears the selection too and `end`
    // clears the band as surely as `cancel` does. They are here for the
    // regression's neighbours rather than for the regression, and saying
    // which is which is the point of this paragraph.

    testWidgets('AN ARMED CLICK STILL PINS WITH A BAND SUPPLIED', (
      tester,
    ) async {
      final c = _controller();
      _addOutlet(c);
      final arm = PlanPinArmController()..arm(_armedDrop);
      addTearDown(arm.dispose);
      final marquee = MarqueeController();
      addTearDown(marquee.dispose);
      await pump(tester, c, arm: arm, marquee: marquee);

      await tester.tapAt(const Offset(300, 200));
      await tester.pump();

      expect(
        c.doc.outlets[_outletId]!.planPin?.at,
        const PxPt(300, 200),
        reason: 'DR-141: an armed click on empty plan pins the drop',
      );
    });

    testWidgets('a click on empty plan still CLEARS with a band supplied', (
      tester,
    ) async {
      final c = _controller(pinnedAt: const PxPt(300, 200));
      final marquee = MarqueeController();
      addTearDown(marquee.dispose);
      final h = await pump(tester, c, marquee: marquee);

      await tester.tapAt(const Offset(300, 200));
      await tester.pump();
      expect(h.selection.ids, isNotEmpty);

      await tester.tapAt(const Offset(60, 40));
      await tester.pump();
      expect(h.selection.ids, isEmpty);
    });

    testWidgets('and the band is not left armed for the next gesture to '
        'inherit', (tester) async {
      final c = _controller();
      final marquee = MarqueeController();
      addTearDown(marquee.dispose);
      await pump(tester, c, marquee: marquee);

      await tester.tapAt(const Offset(300, 200));
      await tester.pump();

      expect(marquee.isActive, isFalse);
    });

    testWidgets('A REAL SWEEP STILL SWEEPS, which is what makes the fix a '
        'fix and not a deletion', (tester) async {
      final c = _controller(pinnedAt: const PxPt(300, 200));
      final marquee = MarqueeController();
      addTearDown(marquee.dispose);
      final h = await pump(tester, c, marquee: marquee);

      final pointer = TestPointer(77, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.down(const Offset(100, 100)));
      await tester.sendEventToBinding(pointer.move(const Offset(200, 150)));
      await tester.sendEventToBinding(pointer.move(const Offset(400, 260)));
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();

      expect(
        h.selection.ids,
        {const Uuid('dev-1')},
        reason: 'the band caught the pin it was drawn around',
      );
      expect(marquee.isActive, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // LEN-A/8: DRAGGING A CORNER, THROUGH THE REAL MOUNTING
  // ═════════════════════════════════════════════════════════════════════
  // `#865` asks for the gesture proved "through the real mounting rather
  // than through a constructor the product never calls, which is the
  // failure this epic already shipped once at PLAN-E/6". So the controller
  // below is handed to a real canvas and every corner is dragged with a
  // real pointer through `CanvasIntentDetector`.
  group('LEN-A/8: the reshape drag', () {
    testWidgets('A CORNER DRAGS, and the rest of the shape stays put', (
      tester,
    ) async {
      final c = _controller();
      _addRoom(c, outline: _triangle());
      await pump(tester, c, reshape: _reshaping());

      await _drag(tester, const Offset(100, 100), const Offset(150, 160));

      expect(_outlineOf(c)!.vertices, const [
        PxPt(150, 160),
        PxPt(400, 100),
        PxPt(400, 300),
      ]);
    });

    testWidgets('ONE COMMAND FOR THE WHOLE DRAG, not one per frame', (
      tester,
    ) async {
      // A corner dragged across a room is forty frames. Forty entries
      // would make the person who dragged it once press Ctrl+Z forty
      // times to put it back.
      final c = _controller();
      _addRoom(c, outline: _triangle());
      await pump(tester, c, reshape: _reshaping());
      final before = c.undo.depth;

      await _drag(tester, const Offset(100, 100), const Offset(150, 160));

      expect(c.undo.depth, before + 1);
    });

    testWidgets('and UNDO PUTS THE CORNER BACK rather than removing the '
        'outline', (tester) async {
      final c = _controller();
      _addRoom(c, outline: _triangle());
      await pump(tester, c, reshape: _reshaping());

      await _drag(tester, const Offset(100, 100), const Offset(150, 160));
      c.undo.undo(c.doc);

      final back = _outlineOf(c);
      expect(back, isNotNull, reason: 'the outline is still there');
      expect(back!.vertices.first, const PxPt(100, 100));
    });

    testWidgets('THE EDIT MENU NAMES A RESHAPE, which the transaction now '
        'asks the command for (`#866`, DR-156 §11.155.2)', (tester) async {
      // WRITTEN AS A WORKAROUND AND KEPT AS A REGRESSION. When this case
      // shipped at `LEN-A/8` the canvas passed `reshapeRoomOutline` by
      // hand, because `transact` read its label before `apply` ran and a
      // bare `run` would have said "Undo Draw Room Outline" to somebody
      // who drew nothing. DR-156 moved that read to commit time and the
      // hand-written label is gone; this case did not change, because the
      // artifact it asserts did not.
      final c = _controller();
      _addRoom(c, outline: _triangle());
      await pump(tester, c, reshape: _reshaping());

      await _drag(tester, const Offset(100, 100), const Offset(150, 160));

      expect(c.undo.undoLabelKey, LabelKey.reshapeRoomOutline.name);
    });

    testWidgets('a corner put back where it started is NOT AN EDIT', (
      tester,
    ) async {
      // The pointer travelled, so `_moved` is true; nothing changed, so
      // an entry here is one the user has to press through twice to reach
      // the edit they meant.
      final c = _controller();
      _addRoom(c, outline: _triangle());
      await pump(tester, c, reshape: _reshaping());
      final before = c.undo.depth;

      await _drag(tester, const Offset(100, 100), const Offset(100, 100));

      expect(c.undo.depth, before);
    });

    testWidgets('THE NEAREST CORNER WINS, not the first one in the list', (
      tester,
    ) async {
      // Two corners of a small room are both inside ten points at a
      // fitted zoom. Taking the first would hand somebody the corner they
      // were not pointing at, on an ordering they cannot see.
      final c = _controller();
      _addRoom(
        c,
        outline: RoomOutline(
          underlayId: _underlayId,
          vertices: const [PxPt(100, 100), PxPt(108, 100), PxPt(400, 300)],
        ),
      );
      await pump(tester, c, reshape: _reshaping());

      await _drag(tester, const Offset(105, 100), const Offset(200, 250));

      expect(_outlineOf(c)!.vertices, const [
        PxPt(100, 100),
        PxPt(200, 250),
        PxPt(400, 300),
      ]);
    });

    testWidgets('A TWO-VERTEX OUTLINE OFFERS NO HANDLES, which is `#863` '
        'avoided rather than met', (tester) async {
      // `RoomOutline` HOLDS a degenerate shape because a decoder must
      // read whatever is on disk (CR-093), and `SetRoomOutlineCommand`
      // refuses to WRITE one. A drag offered here would build a
      // transaction whose only child declined to apply, and undoing that
      // entry throws.
      final c = _controller();
      _addRoom(
        c,
        outline: RoomOutline(
          underlayId: _underlayId,
          vertices: const [PxPt(100, 100), PxPt(400, 100)],
        ),
      );
      await pump(tester, c, reshape: _reshaping());
      final before = c.undo.depth;

      await _drag(tester, const Offset(100, 100), const Offset(150, 160));

      expect(c.undo.depth, before, reason: 'nothing was written');
      expect(_outlineOf(c)!.vertices, const [PxPt(100, 100), PxPt(400, 100)]);
    });

    testWidgets('A COMMITTED DRAG DOES NOT END THE MODE, so the second '
        'corner costs no button press', (tester) async {
      // The difference between this lifetime and the draw's, which is
      // consumed by its own close. A room has as many corners as it has
      // and somebody correcting one is usually correcting its neighbour.
      final c = _controller();
      _addRoom(c, outline: _triangle());
      final mode = _reshaping();
      await pump(tester, c, reshape: mode);

      await _drag(tester, const Offset(100, 100), const Offset(150, 160));
      expect(mode.isActive, isTrue, reason: 'still reshaping');

      await _drag(tester, const Offset(400, 100), const Offset(420, 140));

      expect(_outlineOf(c)!.vertices, const [
        PxPt(150, 160),
        PxPt(420, 140),
        PxPt(400, 300),
      ]);
    });

    testWidgets('AN OUTLINE ON ANOTHER PLAN IS NOT THIS CANVAS’S to '
        'reshape', (tester) async {
      final c = _controller();
      _addRoom(
        c,
        outline: RoomOutline(
          underlayId: const Uuid('ul-elsewhere'),
          vertices: const [PxPt(100, 100), PxPt(400, 100), PxPt(400, 300)],
        ),
      );
      await pump(tester, c, reshape: _reshaping());
      final before = c.undo.depth;

      await _drag(tester, const Offset(100, 100), const Offset(150, 160));

      expect(c.undo.depth, before);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // LEN-A/8: THE MODE TAKES THE WHOLE CANVAS, WHICH IS WHAT IT BUYS
  // ═════════════════════════════════════════════════════════════════════
  // Ruled by the user on 2026-09-11 against making every finished corner
  // draggable all the time. These are the cases that would be impossible
  // to write if it were: each one is a gesture that DOES something on this
  // canvas and must do nothing while a reshape runs.
  group('LEN-A/8: a reshape swallows the canvas', () {
    testWidgets('a click on a pin does not select it', (tester) async {
      final c = _controller(pinnedAt: const PxPt(300, 200));
      _addRoom(c, outline: _triangle());
      final h = await pump(tester, c, reshape: _reshaping());

      await tester.tapAt(const Offset(300, 200));
      await tester.pump();

      expect(h.selection.ids, isEmpty);
    });

    testWidgets('A PIN UNDER A CORNER DOES NOT MOVE, which is the tie the '
        'mode exists to avoid', (tester) async {
      // A plate pinned within the grab radius of a room corner is the
      // collision that made "every corner draggable all the time" cost
      // somebody a gesture they can see sitting there.
      final c = _controller(pinnedAt: const PxPt(100, 100));
      _addRoom(c, outline: _triangle());
      await pump(tester, c, reshape: _reshaping());

      await _drag(tester, const Offset(100, 100), const Offset(200, 220));

      expect(_placementOf(c)!.planPin!.at, const PxPt(100, 100));
      expect(_outlineOf(c)!.vertices.first, const PxPt(200, 220));
    });

    testWidgets('and no band opens on bare plan', (tester) async {
      final c = _controller();
      _addRoom(c, outline: _triangle());
      final marquee = MarqueeController();
      addTearDown(marquee.dispose);
      await pump(tester, c, marquee: marquee, reshape: _reshaping());

      final pointer = TestPointer(92, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.down(const Offset(50, 350)));
      await tester.sendEventToBinding(pointer.move(const Offset(200, 380)));
      await tester.sendEventToBinding(pointer.up());
      await tester.pump();

      expect(marquee.isActive, isFalse);
    });

    testWidgets('nor does a click on bare plan clear the selection', (
      tester,
    ) async {
      final c = _controller(pinnedAt: const PxPt(300, 200));
      _addRoom(c, outline: _triangle());
      final mode = PlanReshapeController();
      addTearDown(mode.dispose);
      final h = await pump(tester, c, reshape: mode);

      // Select it BEFORE the mode starts, which is the state a person
      // arrives in: they clicked the drop, then pressed Reshape.
      await tester.tapAt(const Offset(300, 200));
      await tester.pump();
      expect(h.selection.ids, isNotEmpty);

      mode.begin(_roomId);
      await tester.pump();
      await tester.tapAt(const Offset(50, 350));
      await tester.pump();

      expect(h.selection.ids, isNotEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // LEN-A/8: THE FIGURE FOLLOWS THE SHAPE (§11.49.7)
  // ═════════════════════════════════════════════════════════════════════
  group('LEN-A/8: a reshape re-derives what the shape produced', () {
    testWidgets('THE ESTIMATE MOVES WITH THE CORNER, marked as computed', (
      tester,
    ) async {
      // A reshape that left the old figure behind would leave a room
      // quoting a wall that has moved.
      final c = _controller();
      _addRoom(c, outline: _triangle());
      _calibrate(c);
      _servedByRack(c, _roomId);
      await pump(tester, c, reshape: _reshaping());

      // (480, 360) is 600 px from the rack pin at the origin, at 0.36 in
      // the pixel: 216 inches, up from the 180 the triangle started at.
      await _drag(tester, const Offset(400, 300), const Offset(480, 360));

      expect(
        c.doc.locations[_roomId]!.estimatedRunLengthFromRack,
        const Len(216 * Len.nmPerInch),
      );
      expect(
        c.doc.locations[_roomId]!.estimatedRunLengthOrigin,
        RunLengthOrigin.computedFromPlan,
      );
    });

    testWidgets('ONE UNDO TAKES BOTH BACK, because it was one act', (
      tester,
    ) async {
      final c = _controller();
      _addRoom(c, outline: _triangle());
      _calibrate(c);
      _servedByRack(c, _roomId);
      await pump(tester, c, reshape: _reshaping());

      await _drag(tester, const Offset(400, 300), const Offset(480, 360));
      c.undo.undo(c.doc);

      expect(_outlineOf(c)!.vertices.last, const PxPt(400, 300));
      expect(
        c.doc.locations[_roomId]!.estimatedRunLengthFromRack,
        isNull,
        reason: 'the room had no estimate before the drag',
      );
    });

    testWidgets('A TYPED FIGURE SURVIVES THE RESHAPE, which is the case '
        'the auto-fill is not allowed to win', (tester) async {
      final c = _controller();
      _addRoom(c, outline: _triangle());
      _calibrate(c);
      _servedByRack(c, _roomId);
      // THROUGH THE REAL WRITER, not the model's `@internal` setters.
      c.run(
        SetRoomEstimateCommand.typed(
          locationId: _roomId,
          length: const Len(42 * Len.nmPerInch),
        ),
      );
      await pump(tester, c, reshape: _reshaping());

      await _drag(tester, const Offset(400, 300), const Offset(480, 360));

      expect(
        c.doc.locations[_roomId]!.estimatedRunLengthFromRack,
        const Len(42 * Len.nmPerInch),
      );
      expect(
        c.doc.locations[_roomId]!.estimatedRunLengthOrigin,
        RunLengthOrigin.typed,
      );
      expect(
        _outlineOf(c)!.vertices.last,
        const PxPt(480, 360),
        reason: 'the SHAPE still moved; only the figure is protected',
      );
    });
  });
  group('`#878`: Delete takes the selection off the plan (DR-162)', () {
    // ═══════════════════════════════════════════════════════════════════
    // THE MOUNTING IS THE POINT, AGAIN
    // ═══════════════════════════════════════════════════════════════════
    // `plan_commands_test.dart` proves `ClearPlanPinCommand` applies and
    // reverts. What it cannot prove is that a key reaches it, and that
    // gap is the whole of `#878`: the command shipped at `PLAN-C` with a
    // real revert, its own `LabelKey` and four test constructions, and
    // nothing in any `lib/` built one for months.

    Future<void> pressDelete(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
    }

    testWidgets('a selected pin goes, and the CARRIER stays', (tester) async {
      // §11.161.2, which is what makes the key safe rather than merely
      // consistent with the other two canvases.
      final c = _controller(pinnedAt: const PxPt(120, 90));
      final h = await pump(tester, c);
      h.selection.apply([const Uuid('dev-1')], SelectMode.replace);
      await tester.pumpAndSettle();

      await pressDelete(tester);

      expect(_placementOf(c)!.planPin, isNull);
      expect(
        c.doc.devices.containsKey(const Uuid('dev-1')),
        isTrue,
        reason:
            'the device is still in the project. On the rack this key '
            'would have removed it, which is the cost DR-162 §11.161.1 '
            'states rather than hides',
      );
    });

    testWidgets('Backspace does the same thing', (tester) async {
      final c = _controller(pinnedAt: const PxPt(120, 90));
      final h = await pump(tester, c);
      h.selection.apply([const Uuid('dev-1')], SelectMode.replace);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(_placementOf(c)!.planPin, isNull);
    });

    testWidgets('one undo puts it back where it was', (tester) async {
      final c = _controller(pinnedAt: const PxPt(120, 90));
      final h = await pump(tester, c);
      h.selection.apply([const Uuid('dev-1')], SelectMode.replace);
      await tester.pumpAndSettle();

      await pressDelete(tester);
      c.undo.undo(c.doc);
      await tester.pumpAndSettle();

      expect(_placementOf(c)!.planPin?.at, const PxPt(120, 90));
      expect(_placementOf(c)!.planPin?.underlayId, _underlayId);
    });

    testWidgets('a MARQUEE of two pins is ONE undo step', (tester) async {
      // §11.161.3. Undoing a marquee clear one pin at a time is not
      // undoing a marquee clear.
      final c = _controller(pinnedAt: const PxPt(120, 90));
      _addOutlet(c);
      // THROUGH THE COMMAND, because `Outlet.planPin`'s setter is
      // `@internal` to `rackpal_core` (AC-013) and a package that reached
      // past it would be writing a field the product cannot.
      c.run(
        SetPlanPinCommand(
          carrier: PinCarrier.outlet,
          entityId: _outletId,
          pin: const PlanPin(underlayId: _underlayId, at: PxPt(300, 200)),
        ),
      );
      final h = await pump(tester, c);
      h.selection.apply([
        const Uuid('dev-1'),
        _outletId,
      ], SelectMode.replace);
      await tester.pumpAndSettle();

      final before = c.undo.depth;
      await pressDelete(tester);

      expect(_placementOf(c)!.planPin, isNull);
      expect(c.doc.outlets[_outletId]!.planPin, isNull);
      expect(c.undo.depth, before + 1);

      c.undo.undo(c.doc);
      expect(_placementOf(c)!.planPin?.at, const PxPt(120, 90));
      expect(c.doc.outlets[_outletId]!.planPin?.at, const PxPt(300, 200));
    });

    testWidgets('a selection holding NO pin leaves the document alone', (
      tester,
    ) async {
      // The action is DISABLED rather than running an empty transaction,
      // which is `#863`: a transaction whose only child declines to apply
      // leaves an undo entry that throws on the next Ctrl+Z.
      final c = _controller();
      _addOutlet(c);
      final h = await pump(tester, c);
      h.selection.apply([_outletId], SelectMode.replace);
      await tester.pumpAndSettle();

      final before = c.undo.depth;
      await pressDelete(tester);

      expect(c.undo.depth, before);
      expect(c.doc.outlets[_outletId]!.planPin, isNull);
    });

    testWidgets('A PIN ON ANOTHER PAGE IS NOT REACHED', (tester) async {
      // The canvas shows one underlay, and the drop table and the strip
      // both select by ENTITY, so a carrier pinned on a page that is not
      // on screen can be in the selection. Clearing it from here would be
      // an edit to a drawing nobody is looking at.
      final c = _controller();
      _addOutlet(c);
      // A REAL SECOND PAGE. `SetPlanPinCommand` refuses a pin naming an
      // underlay the document does not hold, which is its own first line
      // and which the first draft of this case tripped over: pinning to
      // an invented id wrote nothing, so the case passed while proving
      // that a pin nobody had set was not cleared.
      const otherPage = Uuid('ul-2');
      c.doc.underlays[otherPage] = PlanUnderlay(
        id: otherPage,
        name: 'Level 2',
        imageMember: 'underlays/ul-2.png',
        format: PlanImageFormat.png,
        pixelWidth: 600,
        pixelHeight: 400,
        contentHash: 'sha256:test-2',
        order: const FracIndex('a1'),
        meta: _meta(),
      );
      c.run(
        SetPlanPinCommand(
          carrier: PinCarrier.outlet,
          entityId: _outletId,
          pin: const PlanPin(underlayId: otherPage, at: PxPt(10, 10)),
        ),
      );
      expect(
        c.doc.outlets[_outletId]!.planPin,
        isNotNull,
        reason: 'the control: the pin is actually set before Delete runs',
      );
      final h = await pump(tester, c);
      h.selection.apply([_outletId], SelectMode.replace);
      await tester.pumpAndSettle();

      await pressDelete(tester);

      expect(
        c.doc.outlets[_outletId]!.planPin,
        isNotNull,
        reason: 'that pin is on `Level 2`, which is not the open page',
      );
    });

    testWidgets('and the selection SURVIVES, so it can be dragged back', (
      tester,
    ) async {
      // Deliberately unlike the rack canvas, which clears its selection
      // after a delete because there is nothing left to select. Here the
      // carrier is still in the project and is now a row in the unpinned
      // strip.
      final c = _controller(pinnedAt: const PxPt(120, 90));
      final h = await pump(tester, c);
      h.selection.apply([const Uuid('dev-1')], SelectMode.replace);
      await tester.pumpAndSettle();

      await pressDelete(tester);

      expect(h.selection.ids, [const Uuid('dev-1')]);
    });
  });
  group('`#878`: the canvas takes focus when it is touched', () {
    // ═══════════════════════════════════════════════════════════════════
    // IT NEVER DID, AND `autofocus` HID IT FROM EVERY CASE ABOVE
    // ═══════════════════════════════════════════════════════════════════
    // `rack_canvas_screen.dart` calls `_canvasFocus.requestFocus()` in
    // eight places. This canvas called it in NONE and relied on
    // `autofocus: true`, which wins only while nothing else has claimed
    // focus: true in every case in this file, where the canvas is the
    // whole tree, and false the moment a person clicks anything else
    // first. `Shortcuts` sits above the focus node, so a canvas without
    // focus never sees a key.
    //
    // **WHICH MEANS `Esc` HAS NEVER WORKED HERE AFTER ONE CLICK
    // ELSEWHERE.** `planCancel` shipped at `PLAN-E/5` as this scope's only
    // binding and is green in its own cases, all of which autofocus.
    testWidgets('a press on the canvas takes focus back from a sibling', (
      tester,
    ) async {
      final c = _controller(pinnedAt: const PxPt(300, 200));
      final elsewhere = FocusNode(debugLabel: 'elsewhere');
      addTearDown(elsewhere.dispose);

      await tester.runAsync(() async {
        await cache.load(_member, await _png(600, 400));
      });
      final selection = SelectionController();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Column(
              children: [
                // THE SIBLING IS THE POINT. Without something else able to
                // hold focus, `autofocus` answers for the canvas and the
                // case proves nothing.
                Focus(
                  focusNode: elsewhere,
                  autofocus: true,
                  child: const SizedBox(width: 600, height: 40),
                ),
                SizedBox(
                  width: 600,
                  height: 400,
                  child: PlanCanvasScreen(
                    controller: c,
                    underlay: _underlay(),
                    images: cache.resolver,
                    measurer: const _ZeroMeasurer(),
                    selection: selection,
                    viewport: ViewportController(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        elsewhere.hasFocus,
        isTrue,
        reason: 'the sibling autofocused, which is the state under test',
      );

      // The canvas sits 40 pixels down, so the pin is at 200 + 40.
      await tester.tapAt(const Offset(300, 240));
      await tester.pumpAndSettle();

      expect(selection.ids, {const Uuid('dev-1')});
      expect(
        elsewhere.hasFocus,
        isFalse,
        reason:
            'a press on a canvas moves focus to it, which is what makes '
            'the keyboard work after a click anywhere else',
      );

      // AND THE KEY LANDS, which is the whole reason focus matters.
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(_placementOf(c)!.planPin, isNull);
    });
  });
}
