// ignore_for_file: prefer_initializing_formals, the render object exposes
// public constructor parameter names that intentionally differ from the
// private backing fields they feed (those fields have public getters +
// change-notifying setters — the mutable-RenderObject pattern), so the
// shorthand `this._field` form does not apply. Same convention as
// `render_rack_canvas.dart`, which this file deliberately mirrors.

// rackmate_ui/src/canvas/schematic/render_schematic_canvas.dart
//
// The schematic's L1: ONE render object that replays ONE display list —
// `SchematicPaintPlan.ops` — under the viewport transform.
//
// ═════════════════════════════════════════════════════════════════════
// THIS FILE IS A DELIBERATE COPY OF `render_rack_canvas.dart`'s SHAPE
// ═════════════════════════════════════════════════════════════════════
// Not because the two do the same job — the rack canvas hosts a
// `RenderDeviceBox` child per device and this one hosts nothing — but
// because the schematic canvas that was deleted at `b560a50` invented a
// SECOND pattern and got all three of its load-bearing details wrong:
//
//   1. IT PAINTED ITS BACKGROUND WITHOUT ITS PAINT OFFSET while the
//      symbols got one, so the fill covered the toolbar and one symbol
//      appeared to float. Fixed structurally: there is no background draw
//      in this file at all. The sheet ground is op zero of the plan (see
//      `schematic_paint_plan.dart`), so it goes through the same one
//      matrix as everything else or it does not go through anything.
//   2. `updateRenderObject` WAS A NO-OP. Every setter was guarded with
//      `identical()` against a `final List` that the widget mutated in
//      place, so no `setState` could ever mark it needing paint and
//      twelve consecutive `fix:` commits changed nothing on screen.
//      [SchematicCanvasBody.updateRenderObject] is a plain setter
//      cascade, exactly as `RackCanvasBody`'s is, and every value it
//      assigns is `@immutable` and rebuilt whole — so `identical` means
//      "the same value", not "the same box that may have been emptied".
//   3. THE DOCUMENT NEVER REACHED IT. `main.dart` passed a hardcoded
//      empty `DiagramScene`. This widget takes a PLAN, and the only thing
//      that can build one is `buildSchematicPaintPlan` over a real
//      `SchematicScene` — and `SchematicCanvasScreen` has no scene
//      parameter for a caller to get wrong. See that file's header.
//
// `render_schematic_canvas_test.dart` pins 1 and 2 directly.
//
// ═════════════════════════════════════════════════════════════════════
// WHY A RENDER OBJECT AND NOT A CustomPainter
// ═════════════════════════════════════════════════════════════════════
// The same reason `render_rack_canvas.dart` is one: `isRepaintBoundary`
// keeps a pan/zoom repaint contained (docs/03 §7.3, "wrap the canvas as a
// whole"), and the retained clip/transform layers are held through
// `LayerHandle`s so their ref-counted lifecycle survives repaints. A raw
// cached layer gets disposed between frames and reusing it asserts.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/schematic/schematic_paint_plan.dart';
import 'package:rackmate_ui/src/canvas/viewport_controller.dart';
import 'package:rackmate_ui/src/draw/flutter_canvas.dart';
import 'package:rackmate_ui/src/draw/text_run_cache.dart';

/// scene → screen: a render object's PAINT OFFSET, then the viewport.
///
/// A FREE FUNCTION, AND THAT IS BECAUSE OF A MUTATION THAT SURVIVED.
/// [RenderSchematicCanvas] is `isRepaintBoundary`, so Flutter hands its
/// `paint` `Offset.zero` and carries the on-screen position on the layer —
/// which means dropping the offset term from the composition below changes
/// NOTHING observable through any widget test, and a deliberate mutation
/// that dropped it survived the whole suite. That is exactly the shape of
/// the defect this file exists to prevent (`b560a50`: "the background fill
/// ignored its paint offset"), so it does not get to be untested because
/// today's caller happens to pass zero.
///
/// Composed in THIS order and not the other: the offset is a SCREEN-space
/// translation applied after the viewport's scene→screen map, so it
/// pre-multiplies. Reversing them would scale the widget's own position by
/// the zoom — the sibling of the classic pan-accelerates-with-zoom bug
/// `viewport_controller.dart` documents.
@visibleForTesting
Matrix4 schematicSceneToScreen(Offset paintOffset, Matrix4 viewport) =>
    Matrix4.translationValues(paintOffset.dx, paintOffset.dy, 0)
      ..multiply(viewport);

/// The widget that paints one [SchematicPaintPlan].
///
/// It has no `scene` parameter and no `children`. Both absences are the
/// point: a caller cannot hand this an empty scene (it cannot hand it a
/// scene at all), and there is no second drawing path beside the plan that
/// could pick up a different transform.
final class SchematicCanvasBody extends LeafRenderObjectWidget {
  const SchematicCanvasBody({
    required this.plan,
    required this.viewport,
    required this.measurer,
    super.key,
  });

  final SchematicPaintPlan plan;
  final ViewportController viewport;

  /// The shared `TextMeasurer` (CR-081) — the same instance the plan was
  /// BUILT with, so what is measured on screen is what was measured into
  /// the display list.
  final TextMeasurer measurer;

  @override
  RenderSchematicCanvas createRenderObject(BuildContext context) =>
      RenderSchematicCanvas(
        plan: plan,
        viewport: viewport,
        measurer: measurer,
      );

  // A PLAIN SETTER CASCADE. See the file header, defect 2 — this is the
  // method the deleted canvas made inert.
  @override
  void updateRenderObject(
    BuildContext context,
    RenderSchematicCanvas renderObject,
  ) {
    renderObject
      ..plan = plan
      ..viewport = viewport
      ..measurer = measurer;
  }
}

/// Replays the plan. Nothing else.
final class RenderSchematicCanvas extends RenderBox {
  RenderSchematicCanvas({
    required SchematicPaintPlan plan,
    required ViewportController viewport,
    required TextMeasurer measurer,
  }) : _plan = plan,
       _viewport = viewport,
       _measurer = measurer;

  SchematicPaintPlan _plan;
  SchematicPaintPlan get plan => _plan;
  set plan(SchematicPaintPlan value) {
    // `identical` is SAFE HERE and was not safe in the deleted canvas,
    // because `SchematicPaintPlan` is `@immutable` and is rebuilt whole by
    // `buildSchematicPaintPlan` on every change. The failure mode this
    // guard reproduced there — a `final List` refilled in place, so the
    // reference never changed and neither did the screen — cannot occur
    // against a value nothing mutates.
    if (identical(_plan, value)) return;
    _plan = value;
    _dropPicture();
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

  // ═══════════════════════════════════════════════════════════════════
  // A MUTATED TRANSFORM LAYER WAS TRIED HERE AND REVERTED (`#707`)
  // ═══════════════════════════════════════════════════════════════════
  // `#704` replaced this object's `markNeedsPaint` viewport listener with
  // one that mutated the retained `TransformLayer` and called
  // `requestVisualUpdate`, so a pan would cost no Dart painting at all.
  // It shipped to the branch with four green widget cases and BROKE THE
  // APP: the schematic stopped panning entirely and the rack's chrome
  // stayed put while its content moved.
  //
  // THE TESTS WERE VACUOUS AND IT IS WORTH SAYING HOW. The listener
  // assigned `debugSceneToScreen = matrix` and then mutated the layer;
  // the tests asserted that `debugSceneToScreen` had moved. That is a
  // field the listener had just written, so it moved whether or not
  // anything reached the compositor. A widget test does not composite, so
  // nothing in this package could have caught it. `M4-F0`'s `Enter` that
  // moved nowhere was the same shape and this is the second time.
  //
  // The defect `#704` describes is real and measured: 30 pan frames
  // produced 31 full recordings. It is not the defect the user was
  // feeling — a pan is smooth zoomed out and abysmal zoomed in at an
  // identical op count, which is raster cost, not Dart cost. So the cure
  // was risky, unproven and aimed at the wrong half, and it goes back
  // until there is an instrument that can see the difference.
  TextMeasurer _measurer;
  TextMeasurer get measurer => _measurer;
  set measurer(TextMeasurer value) {
    if (identical(_measurer, value)) return;
    _measurer = value;
    _dropPicture();
    markNeedsPaint();
  }

  /// The display list, recorded once (`#708`).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// WHY THIS AND NOT `#704`'s MUTATED LAYER
  /// ═══════════════════════════════════════════════════════════════════
  /// Both attack the same measured defect: the viewport notifies on every
  /// pointer move of a drag, `markNeedsPaint` runs, and every op in the
  /// plan is re-issued for a document nobody has touched.
  ///
  /// `#704` stopped the repaint by steering the retained `TransformLayer`
  /// by hand, and broke the app: the schematic stopped panning and the
  /// rack's chrome parted company with its content. It could not be
  /// tested here because a widget test does not composite.
  ///
  /// THIS NEVER LEAVES `paint`. The listener still calls
  /// `markNeedsPaint`, `paint` still runs on every pan, the clip and the
  /// transform are still pushed by the framework in the usual way, and
  /// the canvas is still drawn under them. The ONLY change is that the
  /// scene arrives as one recorded picture instead of 4,155 live calls.
  /// There is no state the framework does not know about, so the failure
  /// mode that broke `#704` has nowhere to live.
  ///
  /// AND IT IS THE HALF THE RASTER THREAD WANTED TOO. A `ui.Picture`
  /// marked complex is what the engine's raster cache can promote to a
  /// texture; 4,155 individual draw calls are not. Both bars were pinned,
  /// and this is the one change that speaks to both.
  ///
  /// INVALIDATED BY THE TWO THINGS THAT CHANGE WHAT IS DRAWN, and by
  /// nothing else: a new plan and a new measurer. The viewport is
  /// deliberately absent from that list, because the ops are recorded in
  /// SCENE space and the matrix lives in a layer above them.
  ui.Picture? _picture;

  void _dropPicture() {
    _picture?.dispose();
    _picture = null;
  }

  /// The scene→screen matrix the last paint actually used.
  ///
  /// EXPOSED FOR ONE TEST AND ONE DEFECT. `b560a50`'s canvas painted part
  /// of its content through the paint offset and part of it without, and
  /// nothing in the widget tree could tell the two apart — the difference
  /// only shows on a canvas that is not at the window's origin. This is
  /// what lets `render_schematic_canvas_test.dart` place the body below a
  /// toolbar and assert that the matrix carries the offset.
  @visibleForTesting
  Matrix4? debugSceneToScreen;

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
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  // Retained layers held through LayerHandles (NOT raw fields) — see the
  // file header.
  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();
  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paintTransformed,
      oldLayer: _clipLayer.layer,
    );
  }

  void _paintTransformed(PaintingContext context, Offset offset) {
    // ONE matrix, used by everything, because there is only one draw below.
    // The composition itself lives in [schematicSceneToScreen] so it can be
    // tested at a non-zero offset — see that function's own doc.
    final matrix = schematicSceneToScreen(offset, _viewport.transform);
    debugSceneToScreen = matrix;
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      Offset.zero,
      matrix,
      _paintScene,
      oldLayer: _transformLayer.layer,
    );
  }

  /// How many times the plan has actually been walked.
  ///
  /// NOT A VACUOUS ASSERTION, and `#704`'s were. This counts inside
  /// [_record], which is the work itself, and the picture it produces is
  /// drawn through the framework's own canvas on every single frame. So
  /// "the count did not move" cannot be true of a canvas that stopped
  /// drawing: a canvas that stopped drawing would fail every other case
  /// in this file first.
  @visibleForTesting
  int debugSceneRecordings = 0;

  void _paintScene(PaintingContext context, Offset offset) {
    // `offset` is Offset.zero here; the canvas is in scene space.
    //
    // ASK THE ENGINE TO KEEP THE RASTER TOO. A `ui.Picture` marked
    // complex is something the engine's raster cache can promote to a
    // texture; 4,155 individual draw calls are not. Both bars of the
    // performance overlay were pinned, and this line and the picture
    // above it are aimed at one each.
    //
    // NO `setWillChangeHint`: it means the opposite, and would tell the
    // engine not to bother caching the thing this is trying to cache.
    context.setIsComplexHint();
    context.canvas.drawPicture(_picture ??= _record());
  }

  ui.Picture _record() {
    debugSceneRecordings++;
    final recorder = ui.PictureRecorder();
    final canvas = FlutterDiagramCanvas(
      ui.Canvas(recorder),
      measurer: _measurer,
      runs: _runs,
    );
    for (final op in _plan.ops) {
      op.replay(canvas);
    }
    return recorder.endRecording();
  }

  /// M2-G's laid-out-run cache, owned here rather than by the canvas.
  ///
  /// THE BIGGEST OF THE THREE, and the one the measurement was taken for:
  /// `schematic_perf_test.dart`'s M2-G census counts 2 374 text runs over a
  /// working set of 703 on the 300-link fixture, so a pan — which
  /// re-records this picture on every frame — repeats 1 671 layouts it
  /// already did. See `text_run_cache.dart`.
  final TextRunCache _runs = TextRunCache();

  @override
  void dispose() {
    _runs.clear();
    // NATIVE MEMORY, so it is released here beside the text runs rather
    // than left to the collector — the same rule `GridCache.dispose`
    // follows for the picture it owns.
    _dropPicture();
    _clipLayer.layer = null;
    _transformLayer.layer = null;
    super.dispose();
  }

  // Not an interactive target itself: pointer routing belongs to the
  // ancestor `CanvasIntentDetector`, which is opaque and therefore already
  // receives everything over this box. Returning true here would put a
  // second claimant in front of it for no gain.
  @override
  bool hitTestSelf(Offset position) => false;
}
