// M2-F PHASE 5 — CR-105's elevation signpost, driven through the screen.
//
// CR-105: "a device with unconnected ports shows a port-count chip
// (`🔗 0/12`) in the elevation, and clicking it switches to the schematic
// with that device selected." That ruling exists because
// `critique-ux-simplicity.md` found the first session's worst cliff at the
// 4:00 mark: a full rack and no visible way to wire it. So the thing under
// test is not a decoration — it is the only affordance in the elevation
// that names the wiring surface at all.
//
// ═══════════════════════════════════════════════════════════════════════
// THE TWO CLAIMS THAT NEED HOLDING DOWN
// ═══════════════════════════════════════════════════════════════════════
//   1. THE CHIP AND ITS HIT TARGET ARE THE SAME RECTANGLE. They are drawn
//      by `RenderDeviceBox` and hit-tested by `RackCanvasScreen`, in
//      different coordinate frames, from one function. A chip you can see
//      and not click is invisible to any test that only asks "is it
//      drawn", so the tests below click at MEASURED corners of the pill
//      rather than at a device's centre.
//   2. NO LISTENER, NO CHIP. This screen cannot switch tabs; only the
//      shell can. A signpost that answers a click by doing nothing is the
//      failure `unbuilt_view.dart` and the Schedule's retired panel were
//      both written against, so `onRevealInSchematic == null` must draw
//      nothing at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'rack_scene_to_screen.dart';

final class _FakeMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

const _rackId = Uuid('rack-chip');
const _amp = Uuid('dev-amp');
const _blank = Uuid('dev-blank');
final _when = DateTime.utc(2026, 8, 2);
const _geo = RackGeometry(12);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

PortDef _port(String key, String order) => PortDef(
  key: PortKey(key),
  label: key,
  connector: const ConnectorTypeId('conn.xlr3'),
  signalFamily: const SignalFamilyId('audio.analog.balanced'),
  face: Face.rear,
  position: _pos,
  order: FracIndex(order),
  maxConnections: 4,
);

/// A 12U rack with a 2U amplifier that declares four ports and a 1U blank
/// panel that declares none.
///
/// THE BLANK PANEL IS THE CONTROL, and it is not a hypothetical: a rack
/// full of vents, shelves and blanking plates is what a real elevation
/// looks like. A chip on one would point at a schematic that will not draw
/// it (`kNoSymbolsDetail`), which is a signpost to nowhere.
RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('doc-chip'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Chip Rack',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.templates['tpl.amp@1'] = TemplateSnapshot(
    templateId: const TemplateId('tpl.amp'),
    version: 1,
    contentHash: 'sha256:tpl.amp',
    capturedAt: _when,
    body: TemplateBody(
      manufacturer: 'Demo',
      model: 'tpl.amp',
      displayName: 'Amplifier',
      frontU: 2,
      ports: [
        for (var i = 1; i <= 4; i++) _port('out.$i', 'a$i'),
      ],
    ),
  );
  doc.templates['tpl.blank@1'] = TemplateSnapshot(
    templateId: const TemplateId('tpl.blank'),
    version: 1,
    contentHash: 'sha256:tpl.blank',
    capturedAt: _when,
    body: TemplateBody(
      manufacturer: 'Demo',
      model: 'tpl.blank',
      displayName: 'Blank panel',
      frontU: 1,
    ),
  );
  doc.devices[_amp] = DeviceInstance(
    id: _amp,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.amp'),
      version: 1,
      contentHash: 'sha256:tpl.amp',
    ),
    designator: 'AMP-1',
    name: 'Amplifier',
    placement: const RailPlacement(
      rackId: _rackId,
      ruIndex: 4,
      face: Face.front,
    ),
    meta: _meta(),
  );
  doc.devices[_blank] = DeviceInstance(
    id: _blank,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.blank'),
      version: 1,
      contentHash: 'sha256:tpl.blank',
    ),
    designator: 'BLK-1',
    name: 'Blank',
    placement: const RailPlacement(
      rackId: _rackId,
      ruIndex: 8,
      face: Face.front,
    ),
    meta: _meta(),
  );
  return doc;
}

/// How many paths [box] emits when it paints. `drawRoundRect` on
/// `FlutterDiagramCanvas` is implemented as a path, so this counts the
/// device body plus whatever chrome is on top of it.
int _pathDraws(RenderDeviceBox box) {
  final canvas = TestRecordingCanvas();
  box.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return canvas.invocations
      .where((i) => i.invocation.memberName == #drawPath)
      .length;
}

RenderDeviceBox _render(WidgetTester tester, Uuid id) =>
    tester.allRenderObjects.whereType<RenderDeviceBox>().firstWhere(
      (r) => r.deviceId == id.v,
    );

/// The chip's rect in SCENE space for the device at [ru] of height
/// [heightU], reconstructed the way the screen's hit test reconstructs it:
/// the device's layout rect plus `portChipRect`'s local answer.
DBox _chipSceneRect(int ru, int heightU, String label) {
  final device = _geo.deviceRect(ru, heightU);
  final local = portChipRect(
    deviceWidth: device.width,
    deviceHeight: device.height,
    label: label,
    measurer: _FakeMeasurer(),
  )!;
  return DBox.fromLtwh(
    device.left + local.left,
    device.top + local.top,
    local.width,
    local.height,
  );
}

void main() {
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

  late List<Uuid> revealed;
  late RackDocument doc;

  Widget app({bool withHost = true}) {
    revealed = <Uuid>[];
    return MaterialApp(
      home: Scaffold(
        body: RackCanvasScreen(
          measurer: _FakeMeasurer(),
          document: doc,
          onRevealInSchematic: withHost ? revealed.add : null,
        ),
      ),
    );
  }

  setUp(() => doc = _doc());

  group('1 — which devices are signposted', () {
    testWidgets('a device with unwired ports carries the chip', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(
        _render(tester, _amp).portChip,
        const PortFill(connected: 0, total: 4),
      );
      expect(_render(tester, _amp).portChip!.label, '0/4');
    });

    testWidgets('a blank panel carries none — furniture, not "unwired"', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(_render(tester, _blank).portChip, isNull);
    });

    testWidgets('NO HOST, NO CHIP — a control that could do nothing is not '
        'drawn', (tester) async {
      // The claim `RackCanvasScreen.onRevealInSchematic`'s own doc makes.
      // This screen cannot switch tabs, so without a listener the chip
      // would be a click target with no destination.
      await tester.pumpWidget(app(withHost: false));
      await tester.pumpAndSettle();
      expect(_render(tester, _amp).portChip, isNull);
    });

    testWidgets('wiring every port retires it', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(_render(tester, _amp).portChip, isNotNull);

      // Two loopback cables across the amplifier's own four jacks — legal
      // (only pin-to-ITSELF is refused, TOP-001) and the deterministic way
      // to fill every pin on a one-device fixture.
      for (final (a, b) in [('out.1', 'out.2'), ('out.3', 'out.4')]) {
        final built = buildConnectPortsCommand(
          doc: doc,
          from: resolveConnectTarget(doc, deviceId: _amp, portKey: a)!,
          to: resolveConnectTarget(doc, deviceId: _amp, portKey: b)!,
          media: kUnstatedMedia,
          now: _when,
          actor: 'test',
        );
        (built as ConnectPortsReady).command.apply(doc);
      }
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        _render(tester, _amp).portChip,
        isNull,
        reason: 'nothing left to signpost',
      );
    });
  });

  group('2 — the chip and its hit target are one rectangle', () {
    testWidgets('clicking inside the pill reveals that device', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final chip = _chipSceneRect(4, 2, '0/4');
      await tester.tapAt(
        scenePoint(
          tester,
          Offset(chip.left + chip.width / 2, chip.top + chip.height / 2),
        ),
      );
      await tester.pumpAndSettle();

      expect(revealed, [_amp]);
    });

    testWidgets('clicking the same device AWAY from the pill does not', (
      tester,
    ) async {
      // The control that makes the previous test mean something: without
      // it, a hit test that returned the device for any point on its body
      // would pass both.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final device = _geo.deviceRect(4, 2);
      await tester.tapAt(
        scenePoint(tester, Offset(device.left + 8, device.top + 6)),
      );
      await tester.pumpAndSettle();

      expect(revealed, isEmpty);
    });

    testWidgets('a click just outside the pill edge does not reveal', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final chip = _chipSceneRect(4, 2, '0/4');
      await tester.tapAt(
        scenePoint(tester, Offset(chip.left - 3, chip.top + chip.height / 2)),
      );
      await tester.pumpAndSettle();
      expect(revealed, isEmpty);
    });

    testWidgets('the click also selects the device it sits on', (tester) async {
      // The chip is a corner of a device. A click there that left the
      // selection alone would read as the rack forgetting what was
      // pressed.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final chip = _chipSceneRect(4, 2, '0/4');
      await tester.tapAt(
        scenePoint(
          tester,
          Offset(chip.left + chip.width / 2, chip.top + chip.height / 2),
        ),
      );
      await tester.pumpAndSettle();

      expect(_render(tester, _amp).selected, isTrue);
    });

    testWidgets('a DRAG from the pill reveals nothing', (tester) async {
      // Decided once at press and read at release, like `_dragPlacement`:
      // a press that turns into a drag is not a click, and arriving on
      // another tab mid-drag would be a memorable way to lose a gesture.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final chip = _chipSceneRect(4, 2, '0/4');
      final start = scenePoint(
        tester,
        Offset(chip.left + chip.width / 2, chip.top + chip.height / 2),
      );
      final drag = await tester.startGesture(start);
      await tester.pump();
      await drag.moveBy(const Offset(0, 60));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(revealed, isEmpty);
    });
  });

  group('3 — it is actually drawn', () {
    testWidgets('the pill reaches the canvas, and only when there is a chip', (
      tester,
    ) async {
      // WITHOUT THIS TEST THE WHOLE FILE PASSES ON A CHIP THAT IS NEVER
      // PAINTED. Every assertion above reads `RenderDeviceBox.portChip` or
      // the hit test, both of which are true of a field that nothing
      // draws. So this one replays the render object into a recording
      // canvas and counts: `FlutterDiagramCanvas.drawRoundRect` emits
      // paths, and the pill plus its two link glyphs are strictly more of
      // them than the device body alone.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final withChip = _pathDraws(_render(tester, _amp));

      await tester.pumpWidget(app(withHost: false));
      await tester.pumpAndSettle();
      final without = _pathDraws(_render(tester, _amp));

      expect(withChip, greaterThan(without));
    });
  });

  group('4 — what a screen reader is told', () {
    testWidgets('the count is on the device label, and only when the chip is '
        'drawn', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(
        _render(tester, _amp).semanticLabel,
        contains('0 of 4 ports connected'),
      );
      expect(
        _render(tester, _blank).semanticLabel,
        isNot(contains('ports connected')),
        reason: 'a device with no chip must not announce one',
      );
    });

    testWidgets('and it disappears with the chip when the host is absent', (
      tester,
    ) async {
      await tester.pumpWidget(app(withHost: false));
      await tester.pumpAndSettle();
      expect(
        _render(tester, _amp).semanticLabel,
        isNot(contains('ports connected')),
        reason: 'what is announced and what is on screen must agree',
      );
    });
  });

  group('5 — portChipRect', () {
    test('it refuses a body too small to hold the pill', () {
      // The painter and the hit test both take null for "no chip", so a
      // suppressed chip is also not clickable with no second condition to
      // keep in step.
      expect(
        portChipRect(
          deviceWidth: 20,
          deviceHeight: 22,
          label: '0/4',
          measurer: _FakeMeasurer(),
        ),
        isNull,
      );
      expect(
        portChipRect(
          deviceWidth: 223,
          deviceHeight: 12,
          label: '0/4',
          measurer: _FakeMeasurer(),
        ),
        isNull,
      );
    });

    test('it sits bottom-right, clear of the U-height badge', () {
      // `device_layer.dart` puts the designator top-left and the badge
      // top-right; the chip takes the only free corner.
      final rect = portChipRect(
        deviceWidth: 223,
        deviceHeight: 44,
        label: '0/12',
        measurer: _FakeMeasurer(),
      )!;
      expect(rect.right, closeTo(223 - kPortChipInset, 0.001));
      expect(rect.bottom, closeTo(44 - kPortChipInset, 0.001));
      expect(rect.height, kPortChipHeight);
    });

    test('a longer count makes a wider pill', () {
      double widthFor(String label) => portChipRect(
        deviceWidth: 223,
        deviceHeight: 44,
        label: label,
        measurer: _FakeMeasurer(),
      )!.width;
      expect(widthFor('0/128'), greaterThan(widthFor('0/4')));
    });
  });

  // CHROME IS ITS AUTHORED WIDTH AT EVERY ZOOM (`#906`, DR-170 §11.169).
  // Measured before the fix, painting the rack canvas at the zoom it opens
  // at (3.02x in this harness) and at 12.1x: the chip's 1-pixel outline at
  // 3.0 and 12.1 physical pixels, the hover ring at 4.5 and 18.1, and the
  // selection outline at 6.0 and 24.2, against docs/04's 2.
  group('chrome keeps its authored width on screen at every zoom (`#906`)', () {
    /// Every stroke one paint of the rack canvas makes, in order, as
    /// `(drawn as a rect, physical width)`.
    List<(bool, double)> rackStrokes(WidgetTester tester) {
      final canvas = TestRecordingCanvas();
      // THE PARENT, NOT THE BOX: the zoom is the rack canvas's transform
      // layer, and a box painted alone would never see it.
      tester.allRenderObjects.whereType<RenderRackCanvas>().single.paint(
        TestRecordingPaintingContext(canvas),
        Offset.zero,
      );
      final out = <(bool, double)>[];
      final saved = <double>[];
      var scale = 1.0;
      for (final call in canvas.invocations) {
        final inv = call.invocation;
        switch (inv.memberName) {
          case #save:
            saved.add(scale);
          case #restore:
            scale = saved.removeLast();
          case #transform:
            scale *= (inv.positionalArguments[0] as List<double>)[0];
          case #scale:
            scale *= inv.positionalArguments[0] as double;
          case #drawRect || #drawPath:
            final paint = inv.positionalArguments[1] as Paint;
            if (paint.style == PaintingStyle.stroke) {
              out.add((
                inv.memberName == #drawRect,
                paint.strokeWidth * scale,
              ));
            }
        }
      }
      return out;
    }

    testWidgets('zoomed out, no rack line paints thinner than its floor, and '
        'a signal line stops at half a pixel', (tester) async {
      // §11.169.3 on the rack. Before the fix the floor was decided in scene
      // units, so at 0.1x the chassis's 0.5-unit rails painted at a
      // twentieth of a pixel. This case is also the only one that sees the
      // chassis canvas: the rings and the chip are drawn by the boxes.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final rack = tester.allRenderObjects.whereType<RenderRackCanvas>().single;
      rack.viewport.zoomBy(0.1 / rack.viewport.scale, screenPivot: Offset.zero);
      await tester.pump();
      expect(rack.viewport.scale, closeTo(0.1, 1e-9));

      final widths = [for (final (_, width) in rackStrokes(tester)) width];
      expect(widths, isNotEmpty, reason: 'the rack has to be painted');
      final thinnest = widths.fold(
        double.infinity,
        (a, b) => a < b ? a : b,
      );
      expect(thinnest, greaterThanOrEqualTo(0.25 - 1e-4));
      expect(
        widths.where((w) => (w - 0.5).abs() < 1e-3),
        isNotEmpty,
        reason: 'the half-pixel signal floor has to have engaged somewhere',
      );
    });

    testWidgets('the rings and the chip paint at the same width at the '
        'opening zoom and at four times it', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final rack = tester.allRenderObjects.whereType<RenderRackCanvas>().single;
      expect(
        _render(tester, _amp).portChip,
        isNotNull,
        reason: 'the chip has to be drawn at all',
      );

      List<(bool, double)> strokes() => rackStrokes(tester);

      /// The rings (the only `drawRect` strokes) and the chip's strokes, as
      /// PHYSICAL widths.
      ///
      /// THE CHIP IS FOUND BY PAINTING WITHOUT IT, NOT BY ITS COLOUR. The
      /// first version picked strokes in the chip style's colour and swept
      /// in the device body's own outline, which shares that colour and is
      /// right to scale. So the rack is painted with the chip and again
      /// without it, and the run of strokes only the first paint made is the
      /// chip's.
      ({List<double> rings, List<double> chip}) painted() {
        final box = _render(tester, _amp)
          ..hovered = true
          ..selected = true;
        final withChip = strokes();
        final fill = box.portChip;
        box.portChip = null;
        final without = strokes();
        box.portChip = fill;
        var prefix = 0;
        while (prefix < without.length && withChip[prefix] == without[prefix]) {
          prefix++;
        }
        final chipCount = withChip.length - without.length;
        return (
          rings: [
            for (final (isRect, width) in withChip)
              if (isRect) width,
          ],
          chip: [
            for (final (_, width) in withChip.sublist(
              prefix,
              prefix + chipCount,
            ))
              width,
          ],
        );
      }

      final atOpen = painted();
      rack.viewport.zoomBy(4, screenPivot: Offset.zero);
      await tester.pump();
      final atFour = painted();

      expect(atOpen.rings, hasLength(2), reason: 'hover and selection');
      expect(atOpen.chip, isNotEmpty, reason: "the chip's outline");
      expect(atFour.rings, hasLength(atOpen.rings.length));
      expect(atFour.chip, hasLength(atOpen.chip.length));
      for (var i = 0; i < atOpen.rings.length; i++) {
        expect(atFour.rings[i], closeTo(atOpen.rings[i], 1e-4));
      }
      final style = _render(tester, _amp).portChipStyle!;
      for (final width in [...atOpen.chip, ...atFour.chip]) {
        expect(
          width,
          closeTo(style.strokeWidth, 1e-4),
          reason: "the chip is its own style's width in physical pixels",
        );
      }
    });
  });
}
