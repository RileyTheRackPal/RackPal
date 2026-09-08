// ignore_for_file: prefer_initializing_formals, the render object exposes
// public constructor parameters that feed private backing fields with
// change-notifying setters -- the mutable-RenderObject pattern, and the
// third file in this package to carry this waiver for that reason. See
// `render_rack_canvas.dart` and `render_schematic_canvas.dart`.

// rackpal_ui/src/canvas/plan/render_plan_canvas.dart
//
// The Plan view's L1: ONE render object that replays ONE display list --
// `buildPlanScene`'s -- under the viewport transform.
//
// ═════════════════════════════════════════════════════════════════════
// THE THIRD COPY OF THE SAME FORTY LINES, AND PLAN-E/1 COUNTED IT
// ═════════════════════════════════════════════════════════════════════
// `RenderRackCanvas` takes a `DiagramScene` plus a `rackId` and hosts one
// `RenderDeviceBox` child per device. `RenderSchematicCanvas` takes a
// `SchematicPaintPlan`. Neither will accept "replay this display list
// under this viewport", so a third canvas needs a third render object --
// which is the piece the feasibility study's list of already-existing
// machinery never mentioned (docs/12 §5.9.7.4).
//
// COPIED RATHER THAN GENERALISED, DELIBERATELY. The schematic's own header
// records why the second one was a copy: the canvas deleted at `b560a50`
// invented a SECOND pattern and got all three of its load-bearing details
// wrong. The shared part here is the clip layer, the transform layer, the
// `LayerHandle` lifecycle, the viewport listener and the paint-offset
// composition; the typed part -- what is replayed, and whether there are
// children -- is genuinely different in all three. **A fourth is the
// moment to extract a base**, and this note is where that decision starts.
//
// ═════════════════════════════════════════════════════════════════════
// `debugSceneToScreen` IS NOT OPTIONAL HERE, AND PLAN-E/1 MEASURED WHY
// ═════════════════════════════════════════════════════════════════════
// The spike at `plan_canvas_reuse_spike_test.dart` ran one mutation that
// SURVIVED: dropping the paint offset out of the transform below leaves
// every widget case green. That is `b560a50`'s shipped defect reproduced
// on the first attempt, and it is invisible for a structural reason --
// this object is `isRepaintBoundary`, so Flutter hands `paint` an
// `Offset.zero` and carries the on-screen position on the layer, and a
// widget test does not composite at all.
//
// So the matrix the last paint ACTUALLY used is exposed, and
// `render_plan_canvas_test.dart` places this body below a toolbar and
// asserts the offset is in it. Without that, "the plan draws in the right
// place" is a claim no test in this package can make.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';
import 'package:rackpal_ui/src/draw/flutter_canvas.dart';
import 'package:rackpal_ui/src/draw/text_run_cache.dart';

/// scene -> screen: a render object's PAINT OFFSET, then the viewport.
///
/// A FREE FUNCTION, for `schematicSceneToScreen`'s reason exactly: the
/// composition is the thing a mutation can silently drop, so it is
/// reachable by a test on its own terms rather than only through a paint.
///
/// Composed in THIS order and not the other: the offset is a SCREEN-space
/// translation applied after the viewport's scene->screen map, so it
/// pre-multiplies. Reversing them would scale the widget's own position by
/// the zoom, which is the sibling of the pan-accelerates-with-zoom bug
/// `viewport_controller.dart` documents.
@visibleForTesting
Matrix4 planSceneToScreen(Offset paintOffset, Matrix4 viewport) =>
    Matrix4.translationValues(paintOffset.dx, paintOffset.dy, 0)
      ..multiply(viewport);

/// The widget that paints one plan scene.
///
/// It has no `children` and no way to be handed an empty scene by
/// accident: `buildPlanScene` always emits the underlay as op zero, so a
/// scene reaching here has a picture in it or the document has no underlay
/// and this widget is not built at all.
final class PlanCanvasBody extends LeafRenderObjectWidget {
  const PlanCanvasBody({
    required this.scene,
    required this.viewport,
    required this.measurer,
    required this.images,
    super.key,
  });

  final DiagramScene scene;
  final ViewportController viewport;

  /// The shared `TextMeasurer` (CR-081). No op in a plan scene draws text
  /// today, and this is still required rather than optional: the callouts
  /// arrive at PLAN-H, and a canvas that acquires a text op and no
  /// measurer would fail at paint time rather than at the call site.
  final TextMeasurer measurer;

  /// Resolves the underlay's `ImageRef` to a decoded raster. See
  /// `plan_image_cache.dart`; a reference this cannot resolve THROWS
  /// (docs/15 §7), rather than leaving a blank sheet that looks like a
  /// plan with no drops on it.
  final FlutterImageResolver images;

  @override
  RenderPlanCanvas createRenderObject(BuildContext context) => RenderPlanCanvas(
    scene: scene,
    viewport: viewport,
    measurer: measurer,
    images: images,
  );

  // A PLAIN SETTER CASCADE, on `RackCanvasBody`'s precedent and for the
  // reason `render_schematic_canvas.dart` records as its defect 2: a
  // guarded `updateRenderObject` that compared against a list mutated in
  // place was a no-op through twelve consecutive `fix:` commits.
  @override
  void updateRenderObject(
    BuildContext context,
    RenderPlanCanvas renderObject,
  ) {
    renderObject
      ..scene = scene
      ..viewport = viewport
      ..measurer = measurer
      ..images = images;
  }
}

/// Replays the plan scene. Nothing else.
final class RenderPlanCanvas extends RenderBox {
  RenderPlanCanvas({
    required DiagramScene scene,
    required ViewportController viewport,
    required TextMeasurer measurer,
    required FlutterImageResolver images,
  }) : _scene = scene,
       _viewport = viewport,
       _measurer = measurer,
       _images = images;

  DiagramScene _scene;
  DiagramScene get scene => _scene;
  set scene(DiagramScene value) {
    // `identical` is safe: `buildPlanScene` returns a fresh `DiagramScene`
    // on every call and nothing mutates one in place. That is the
    // condition `render_schematic_canvas.dart` names for this guard being
    // safe rather than inert.
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

  TextMeasurer _measurer;
  TextMeasurer get measurer => _measurer;
  set measurer(TextMeasurer value) {
    if (identical(_measurer, value)) return;
    _measurer = value;
    markNeedsPaint();
  }

  FlutterImageResolver _images;
  FlutterImageResolver get images => _images;
  set images(FlutterImageResolver value) {
    if (identical(_images, value)) return;
    _images = value;
    markNeedsPaint();
  }

  /// The scene->screen matrix the last paint actually used.
  ///
  /// EXPOSED BECAUSE A MUTATION PROVED IT HAS TO BE. See the file header:
  /// dropping the paint-offset term left every case of `PLAN-E/1`'s spike
  /// green, and this field is what lets a test place the canvas somewhere
  /// other than the window's origin and see the difference.
  @visibleForTesting
  Matrix4? debugSceneToScreen;

  /// How many times the scene has actually been replayed, on
  /// `RenderRackCanvas.debugSceneRecordings`' precedent: a pan that does
  /// not increment this did no Dart painting.
  @visibleForTesting
  int debugSceneRecordings = 0;

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

  // Held through `LayerHandle`s, not raw fields, so their ref-counted
  // lifecycle is correct across repaints: a raw cached layer is disposed
  // between frames and reusing it asserts.
  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();
  final LayerHandle<TransformLayer> _xform = LayerHandle<TransformLayer>();

  /// Owned here rather than by the canvas, because a
  /// `FlutterDiagramCanvas` is built once per paint and a cache held there
  /// would never survive to be hit.
  final TextRunCache _runs = TextRunCache();

  @override
  void dispose() {
    _runs.clear();
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
      _paintTransformed,
      oldLayer: _clip.layer,
    );
  }

  void _paintTransformed(PaintingContext context, Offset offset) {
    final matrix = planSceneToScreen(offset, _viewport.transform);
    debugSceneToScreen = matrix;
    _xform.layer = context.pushTransform(
      needsCompositing,
      Offset.zero,
      matrix,
      _paintScene,
      oldLayer: _xform.layer,
    );
  }

  void _paintScene(PaintingContext context, Offset offset) {
    debugSceneRecordings++;
    // An architect's page is a lot of fill, and the picture does not
    // change while the viewport moves. Same hint, same reason, as both
    // sibling canvases.
    context.setIsComplexHint();
    _scene.replay(
      FlutterDiagramCanvas(
        context.canvas,
        measurer: _measurer,
        runs: _runs,
        images: _images,
      ),
    );
  }

  // The plan itself is not an interactive target: hit-testing a pin goes
  // through `hitTest` over `DiagramScene.hits` in scene space, driven by
  // `CanvasIntentDetector`, exactly as `PLAN-E/1`'s spike demonstrated.
  // The ancestor `Listener` still pans over the picture.
  @override
  bool hitTestSelf(Offset position) => false;
}
