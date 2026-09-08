// ignore_for_file: prefer_initializing_formals, the render object below
// takes public constructor parameters that feed private backing fields
// with change-notifying setters -- the mutable-RenderObject pattern, and
// the same waiver `render_rack_canvas.dart` and
// `render_schematic_canvas.dart` carry for the same reason. That the
// waiver has to be copied a third time is itself part of this file's
// finding.

// PLAN-E/1's SPIKE. A THIRD CANVAS, STOOD UP OUT OF THE EXISTING PARTS,
// TO TEST A CLAIM THAT HAD ONLY EVER BEEN READ.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THIS FILE IS FOR, AND WHY IT IS A TEST AND NOT A SCREEN
// ═══════════════════════════════════════════════════════════════════════
// The feasibility study §6 sizes the plan canvas at 2-3 weeks and calls it
// "the one most likely to be wrong in the optimistic direction. It is
// smaller than M1's canvas work only because the viewport, selection,
// hit-test, drag-preview and command machinery already exist; if any of
// those turn out to be coupled to rack or schematic semantics more tightly
// than a read suggests, that row grows first."
//
// Nothing had tested it. This file is the test: a rough third canvas that
// pans, zooms, hit-tests one rectangle and drags it, built ONLY out of
// parts that already shipped. Everything it has to declare for itself is,
// by construction, a piece that does NOT come for free, and the findings
// are written up in docs/12 §5.9.7.
//
// IT LIVES IN `test/` DELIBERATELY. DR-091 keeps the Plan view out of the
// tab strip until it is built, and a half-canvas sitting in `lib/` is the
// same untruth one layer down: it would be exported, analyzed and reachable
// while answering to no ruling. Here it is evidence, it is gated, and E/2
// deletes it when the real surface replaces it.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT CAME FOR FREE, MEASURED BY WHAT THIS FILE DOES NOT DECLARE
// ═══════════════════════════════════════════════════════════════════════
//   * `ViewportController` — pan, zoom-about-a-pivot, screen<->scene. Used
//     verbatim. It knows nothing about racks or sheets, and its own header
//     already said so ("any future editor can reuse").
//   * `CanvasIntentDetector` / `CanvasIntentHandler` — the whole pointer
//     story, including the middle-button pan, the wheel and trackpad
//     channels, the single-gesture guard and the deferred-pointer
//     adoption. Used verbatim.
//   * `hitTest` over `DiagramScene.hits` — pure, in core, nearest-hit.
//     Used verbatim.
//   * `SelectionController` — `Set<Uuid>` plus focus. Used verbatim.
//   * `FlutterDiagramCanvas` — replays a display list onto a `ui.Canvas`.
//     Used verbatim.
//
// WHAT DID NOT, AND HAD TO BE WRITTEN BELOW:
//   * A RENDER OBJECT. `RenderRackCanvas` takes a `DiagramScene` plus a
//     `rackId` and hosts one child per device; `RenderSchematicCanvas`
//     takes a `SchematicPaintPlan`. Neither will accept "replay this
//     display list under this viewport", so `_RenderSpikePlanCanvas` is a
//     third copy of the same forty lines. See §5.9.7.
//
//     AND ITS PAINT IS UNTESTABLE FROM HERE, MEASURED. Dropping the paint
//     offset out of its transform leaves all six cases below GREEN. That
//     is `b560a50`'s defect reproduced inside the spike on the first try,
//     which is why the schematic's render object carries a
//     `debugSceneToScreen` and why E/2's must too.
//   * A DRAG PREVIEW. `DragPreviewController`'s vocabulary is `deviceH`,
//     `Face`, `ruIndex` and a blocked-with-reason verdict — rack rails,
//     all of it. A pin has no U, no face and nothing to be blocked by, so
//     the spike drives its drag straight off `CanvasIntentHandler` and is
//     the better for it.
//
// The tests below are the demonstration. Each one names the property it is
// protecting, not the widget it pokes.

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// The one rectangle, as an entity id. A `PlanPin` has no id of its own —
/// it hangs off a `Placement`, an `Outlet` or a `Rack` — so a plan's
/// selection is its CARRIER's selection, which is exactly what
/// `SelectionController` already stores.
const Uuid kPinCarrier = Uuid('spike-pin-carrier');

/// Scene-space size of the spike's pin box, in diagram points.
const double kPinSize = 40;

void main() {
  group('PLAN-E/1: a third canvas out of the shipped parts', () {
    testWidgets("the wheel pans it, and the pan is the viewport's own", (
      tester,
    ) async {
      final host = _SpikeHost();
      await tester.pumpWidget(host.build());

      final before = host.viewport.screenToScene(const DPt(400, 300));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pump();

      final after = host.viewport.screenToScene(const DPt(400, 300));
      // Down-scroll moves content up, so the scene point under a FIXED
      // screen point moves down the scene by the scroll delta.
      expect(after.y - before.y, closeTo(120, 0.001));
      expect(after.x - before.x, closeTo(0, 0.001));
    });

    testWidgets('a pinch zooms it, and the point under the fingers stays put', (
      tester,
    ) async {
      final host = _SpikeHost();
      await tester.pumpWidget(host.build());

      const focus = Offset(250, 200);
      final pinned = host.viewport.screenToScene(const DPt(250, 200));

      final p = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(p.panZoomStart(focus));
      await tester.sendEventToBinding(
        p.panZoomUpdate(focus, scale: 2),
      );
      await tester.sendEventToBinding(p.panZoomEnd());
      await tester.pump();

      expect(host.viewport.scale, closeTo(2, 0.001));
      final still = host.viewport.screenToScene(const DPt(250, 200));
      expect(still.x, closeTo(pinned.x, 0.001));
      expect(still.y, closeTo(pinned.y, 0.001));
    });

    testWidgets('a click inside the pin selects its carrier; outside clears', (
      tester,
    ) async {
      final host = _SpikeHost();
      await tester.pumpWidget(host.build());

      // The pin sits at scene (100,100)-(140,140); the identity viewport
      // and the top-left alignment make that its screen rect too.
      await tester.tapAt(const Offset(120, 120));
      await tester.pump();
      expect(host.selection.ids, {kPinCarrier});
      expect(host.selection.focus, kPinCarrier);

      await tester.tapAt(const Offset(500, 400));
      await tester.pump();
      expect(host.selection.ids, isEmpty);
      expect(host.selection.focus, isNull);
    });

    testWidgets(
      'the hit lands on the pin under a panned viewport AND a widget offset',
      (tester) async {
        // ═══════════════════════════════════════════════════════════════
        // THE INPUT HALF OF A DEFECT CLASS THIS REPOSITORY HAS SHIPPED
        // ═══════════════════════════════════════════════════════════════
        // `render_schematic_canvas.dart` records a canvas that painted
        // part of its content through its paint offset and part without,
        // and that NOTHING in a widget tree could tell apart while the
        // canvas sat at the window's origin. A hit-test has the same trap:
        // a canvas at (0,0) under an identity viewport makes screen, local
        // and scene coordinates all agree, so a handler reading
        // `event.position` instead of `event.localPosition` would pass
        // every naive case. So this drops the canvas below a 60px toolbar
        // AND pans, and clicks where the pin actually is on screen.
        //
        // IT COVERS THE INPUT PATH AND NOT THE PAINT PATH, and the
        // difference was MEASURED rather than assumed: dropping the paint
        // offset term out of [_RenderSpikePlanCanvas.paint] leaves all six
        // of these cases green. That is the finding docs/12 §5.9.7 records
        // as the third render object's price.
        final host = _SpikeHost(toolbarHeight: 60);
        await tester.pumpWidget(host.build());

        host.viewport.panBy(const Offset(30, -20));
        await tester.pump();

        // scene (120,120) -> local (150,100) -> global (150,160).
        await tester.tapAt(const Offset(150, 160));
        await tester.pump();
        expect(host.selection.ids, {kPinCarrier});
      },
    );

    testWidgets('dragging the pin moves it by the SCENE delta, not the screen '
        'one', (tester) async {
      // The property a zoomed canvas gets wrong when a drag is plumbed in
      // screen space: at 2x, 100 screen pixels is 50 scene units. The
      // rack's own `DragPreviewController` cannot be asked this question —
      // its evaluation is an `ruIndex` — so the spike drives the drag
      // straight off `CanvasIntentHandler`, which reports scene points.
      final host = _SpikeHost();
      await tester.pumpWidget(host.build());

      host.viewport.zoomBy(2, screenPivot: Offset.zero);
      await tester.pump();
      expect(host.viewport.scale, closeTo(2, 0.001));

      // The pin's scene top-left (100,100) is at screen (200,200) now.
      final gesture = await tester.startGesture(const Offset(240, 240));
      await gesture.moveBy(const Offset(100, 60));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(host.pinBox.left, closeTo(150, 0.001));
      expect(host.pinBox.top, closeTo(130, 0.001));
      // And the drag selected what it grabbed, on the way past.
      expect(host.selection.ids, {kPinCarrier});
    });

    testWidgets('a drag that starts on empty canvas moves nothing', (
      tester,
    ) async {
      final host = _SpikeHost();
      await tester.pumpWidget(host.build());

      final gesture = await tester.startGesture(const Offset(500, 400));
      await gesture.moveBy(const Offset(100, 60));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(host.pinBox.left, closeTo(100, 0.001));
      expect(host.pinBox.top, closeTo(100, 0.001));
      expect(host.selection.ids, isEmpty);
    });
  });
}

/// Owns the spike's mutable state so a test can read it back after driving
/// the real widget tree. Not a pattern to copy — a spike's harness.
final class _SpikeHost {
  _SpikeHost({this.toolbarHeight = 0});

  final double toolbarHeight;
  final ViewportController viewport = ViewportController();
  final SelectionController selection = SelectionController();

  /// The one rectangle, in scene space.
  DBox pinBox = const DBox.fromLtwh(100, 100, kPinSize, kPinSize);

  Widget build() => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      // Top-left, so local == global for the gesture coordinates the tests
      // write, EXCEPT for the toolbar term they are testing.
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          children: [
            if (toolbarHeight > 0) SizedBox(height: toolbarHeight),
            Expanded(child: _SpikePlanSurface(host: this)),
          ],
        ),
      ),
    ),
  );
}

/// The spike canvas: a `CanvasIntentDetector` over a display list, with a
/// handler that hit-tests and drags. Everything here except
/// [_RenderSpikePlanCanvas] is existing machinery being wired up.
final class _SpikePlanSurface extends StatefulWidget {
  const _SpikePlanSurface({required this.host});

  final _SpikeHost host;

  @override
  State<_SpikePlanSurface> createState() => _SpikePlanSurfaceState();
}

class _SpikePlanSurfaceState extends State<_SpikePlanSurface>
    implements CanvasIntentHandler {
  _SpikeHost get _host => widget.host;

  /// The carrier grabbed by the live drag, or null when the drag started on
  /// empty canvas. `CanvasGestureToken` is what says which drag: the
  /// detector's own contract, reused rather than re-invented.
  CanvasGestureToken? _gesture;
  Uuid? _grabbed;
  DPt? _grabOffset;
  bool _moved = false;

  DiagramScene get _scene {
    final b = _host.pinBox;
    return DiagramScene(
      ops: [OpRect(b, fill: const Fill(0xFF202020))],
      bounds: b,
      hits: [HitRegion(kPinCarrier.v, b)],
      minTextSizePt: 0,
      fragments: const {},
    );
  }

  @override
  void beginDrag(
    DPt sceneStart,
    Set<PointerDeviceKind> sourceKinds, {
    required CanvasGestureToken gesture,
  }) {
    _gesture = gesture;
    _moved = false;
    final hit = hitTest(_scene, sceneStart);
    if (hit == null) {
      _grabbed = null;
      _grabOffset = null;
      return;
    }
    _grabbed = Uuid(hit.entityId);
    _grabOffset = DPt(
      sceneStart.x - _host.pinBox.left,
      sceneStart.y - _host.pinBox.top,
    );
    _host.selection.apply([_grabbed!], SelectMode.replace);
  }

  @override
  void updateDrag(
    DPt sceneCurrent,
    DPt sceneDelta, {
    required CanvasGestureToken gesture,
  }) {
    if (gesture != _gesture) return;
    final offset = _grabOffset;
    if (offset == null) return;
    _moved = true;
    setState(() {
      _host.pinBox = DBox.fromLtwh(
        sceneCurrent.x - offset.x,
        sceneCurrent.y - offset.y,
        kPinSize,
        kPinSize,
      );
    });
  }

  @override
  void commitDrag(DPt sceneEnd, {required CanvasGestureToken gesture}) {
    if (gesture != _gesture) return;
    // A press that never moved is a CLICK, and a click on empty canvas
    // clears (docs/03 §4.4's focus rule, which `SelectionController`
    // already implements — the spike only has to decide it is a click).
    if (!_moved && _grabbed == null) {
      _host.selection.apply(const [], SelectMode.replace);
    }
    _endGesture();
  }

  @override
  void cancel({required CanvasGestureToken gesture}) {
    if (gesture != _gesture) return;
    _endGesture();
  }

  void _endGesture() {
    _gesture = null;
    _grabbed = null;
    _grabOffset = null;
    _moved = false;
  }

  @override
  Widget build(BuildContext context) => CanvasIntentDetector(
    viewport: _host.viewport,
    handler: this,
    child: _SpikePlanCanvas(scene: _scene, viewport: _host.viewport),
  );
}

/// THE PIECE THAT DID NOT COME FOR FREE.
///
/// A third copy of `render_rack_canvas.dart`'s shape, for the third time,
/// because neither existing render object will take a bare display list:
/// one wants a `rackId` and device children, the other a
/// `SchematicPaintPlan`. Kept minimal here on purpose — the finding is that
/// it had to exist at all, not what it looks like.
final class _SpikePlanCanvas extends LeafRenderObjectWidget {
  const _SpikePlanCanvas({required this.scene, required this.viewport});

  final DiagramScene scene;
  final ViewportController viewport;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSpikePlanCanvas(scene: scene, viewport: viewport);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSpikePlanCanvas renderObject,
  ) {
    renderObject
      ..scene = scene
      ..viewport = viewport;
  }
}

final class _RenderSpikePlanCanvas extends RenderBox {
  _RenderSpikePlanCanvas({
    required DiagramScene scene,
    required ViewportController viewport,
  }) : _scene = scene,
       _viewport = viewport;

  DiagramScene _scene;
  DiagramScene get scene => _scene;
  set scene(DiagramScene value) {
    if (identical(_scene, value)) return;
    _scene = value;
    markNeedsPaint();
  }

  ViewportController _viewport;
  ViewportController get viewport => _viewport;
  set viewport(ViewportController value) {
    if (identical(_viewport, value)) return;
    if (attached) _viewport.removeListener(markNeedsPaint);
    _viewport = value;
    if (attached) _viewport.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _viewport.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _viewport.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() => size = constraints.biggest;

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();
  final LayerHandle<TransformLayer> _xform = LayerHandle<TransformLayer>();

  @override
  void dispose() {
    _clip.layer = null;
    _xform.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (inner, innerOffset) {
        _xform.layer = inner.pushTransform(
          needsCompositing,
          Offset.zero,
          Matrix4.translationValues(innerOffset.dx, innerOffset.dy, 0)
            ..multiply(_viewport.transform),
          (ctx, _) => _scene.replay(
            FlutterDiagramCanvas(ctx.canvas, measurer: const _ZeroMeasurer()),
          ),
          oldLayer: _xform.layer,
        );
      },
      oldLayer: _clip.layer,
    );
  }

  @override
  bool hitTestSelf(Offset position) => false;
}

/// The spike draws one filled rect and no text; this exists because the
/// canvas's constructor requires a collaborator.
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
