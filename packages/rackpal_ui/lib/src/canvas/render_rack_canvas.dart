// ignore_for_file: prefer_initializing_formals, the render object exposes
// public constructor parameter names that intentionally differ from the
// private backing fields they feed (those fields have public getters +
// change-notifying setters — the mutable-RenderObject pattern), so the
// shorthand `this._field` form does not apply. Same convention as
// rackpal_core's entity classes.

// rackpal_ui/src/canvas/render_rack_canvas.dart
//
// The L1+L2 layers of the render pipeline (docs/03-architecture.md §7.2):
// one `RenderRackCanvas` that paints the rack CHASSIS fragment itself and
// hosts one `RenderDeviceBox` child per device (CR-086). The device
// children are positioned in SCENE space; the whole canvas is put under the
// viewport transform once, so pan/zoom moves and scales everything without
// any per-child screen-space math.
//
// The load-bearing detail (docs/03 §7.2, transcribed): each child is laid
// out with TIGHT constraints derived from its own scene size, with
// `parentUsesSize: false`, so every device is its own relayout boundary and
// moving device A can never dirty device B's layout.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';
import 'package:rackpal_ui/src/draw/flutter_canvas.dart';
import 'package:rackpal_ui/src/draw/text_run_cache.dart';

/// Parent data for a device child: its scene-space size (which becomes its
/// tight layout constraints) and scene-space offset (where the parent paints
/// and hit-tests it, under the viewport transform).
class RackParentData extends ContainerBoxParentData<RenderBox> {
  Size sceneSize = Size.zero;
  Offset sceneOffset = Offset.zero;
}

/// The `Positioned`-analogue for [RackCanvasBody]: carries a device child's
/// scene-space rect into its [RackParentData] (mirrors how `Positioned`
/// feeds `Stack`).
class RackDevicePlacement extends ParentDataWidget<RackParentData> {
  const RackDevicePlacement({
    required this.sceneOffset,
    required this.sceneSize,
    required super.child,
    super.key,
  });

  final Offset sceneOffset;
  final Size sceneSize;

  @override
  void applyParentData(RenderObject renderObject) {
    final pd = renderObject.parentData! as RackParentData;
    var changed = false;
    if (pd.sceneOffset != sceneOffset) {
      pd.sceneOffset = sceneOffset;
      changed = true;
    }
    if (pd.sceneSize != sceneSize) {
      pd.sceneSize = sceneSize;
      changed = true;
    }
    if (changed) {
      final parent = renderObject.parent;
      if (parent is RenderObject) parent.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => RackCanvasBody;
}

/// The multi-child widget that owns the chassis + device children. Its
/// children are [RackDevicePlacement]-wrapped device widgets (typically
/// `DeviceBox`).
class RackCanvasBody extends MultiChildRenderObjectWidget {
  const RackCanvasBody({
    required this.scene,
    required this.viewport,
    required this.measurer,
    required this.rackId,
    required super.children,
    super.key,
  });

  /// The composed scene; the chassis is `fragmentFor(rackId)`.
  final DiagramScene scene;
  final ViewportController viewport;
  final TextMeasurer measurer;

  /// The rack entity id (`Uuid.v`) — the chassis fragment key.
  final String rackId;

  @override
  RenderRackCanvas createRenderObject(BuildContext context) => RenderRackCanvas(
    scene: scene,
    viewport: viewport,
    measurer: measurer,
    rackId: rackId,
  );

  @override
  void updateRenderObject(BuildContext context, RenderRackCanvas renderObject) {
    renderObject
      ..scene = scene
      ..viewport = viewport
      ..measurer = measurer
      ..rackId = rackId;
  }
}

/// Paints the rack chassis (from the shared IR) and its device-box children,
/// all under the [ViewportController] transform. A repaint boundary, so a
/// pan/zoom repaint stays contained (docs/03 §7.3: "wrap the canvas as a
/// whole").
class RenderRackCanvas extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, RackParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, RackParentData> {
  RenderRackCanvas({
    required DiagramScene scene,
    required ViewportController viewport,
    required TextMeasurer measurer,
    required String rackId,
  }) : _scene = scene,
       _viewport = viewport,
       _measurer = measurer,
       _rackId = rackId;

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

  // A MUTATED TRANSFORM LAYER WAS TRIED HERE AND REVERTED (`#707`).
  // See `render_schematic_canvas.dart`'s note of the same name: it broke
  // the app, and the widget cases that were supposed to protect it were
  // asserting on a field the listener itself had just written.
  //
  // The symptom HERE was the more informative of the two. The rack's
  // content moved with the pan and its chrome did not, which is what a
  // layer mutated behind the framework's back looks like: the siblings
  // that still repaint through `markNeedsPaint` moved, and the ones the
  // mutation was steering did not agree with them.

  /// scene → screen: this render object's paint offset, then the viewport.
  Matrix4 _sceneToScreen(Offset offset) =>
      Matrix4.translationValues(offset.dx, offset.dy, 0)
        ..multiply(_viewport.transform);

  TextMeasurer _measurer;
  TextMeasurer get measurer => _measurer;
  set measurer(TextMeasurer value) {
    if (identical(_measurer, value)) return;
    _measurer = value;
    markNeedsPaint();
  }

  String _rackId;
  String get rackId => _rackId;
  set rackId(String value) {
    if (_rackId == value) return;
    _rackId = value;
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
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! RackParentData) {
      child.parentData = RackParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  // Transcribed verbatim from docs/03 §7.2: fill the viewport, then lay each
  // child out at TIGHT constraints of its own scene size so it is a relayout
  // boundary. Do not change the constraint tightness — it is load-bearing.
  @override
  void performLayout() {
    size = constraints.biggest;
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as RackParentData;
      // `parentUsesSize: false` is kept EXPLICIT (it is the default, hence
      // the ignore) because it is the load-bearing detail of docs/03 §7.2:
      // each child is its own relayout boundary, so moving one device can
      // never dirty another's layout.
      // ignore: avoid_redundant_argument_values
      child.layout(BoxConstraints.tight(pd.sceneSize), parentUsesSize: false);
      child = pd.nextSibling;
    }
  }

  // Retained layers held through LayerHandles (NOT raw fields), so their
  // ref-counted lifecycle is correct across repaints — a raw cached layer
  // gets disposed between frames and reusing it asserts.
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
    final matrix = _sceneToScreen(offset);
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      Offset.zero,
      matrix,
      _paintScene,
      oldLayer: _transformLayer.layer,
    );
  }

  /// M2-G's laid-out-run cache, owned here rather than by the canvas.
  ///
  /// A `FlutterDiagramCanvas` is built once per paint, so a cache held
  /// there would never survive to be hit. This one lives as long as the
  /// render object repainting through it, and is released in [dispose] —
  /// see `text_run_cache.dart` for the measurement that sized it.
  final TextRunCache _runs = TextRunCache();

  @override
  void dispose() {
    _runs.clear();
    _clipLayer.layer = null;
    _transformLayer.layer = null;
    super.dispose();
  }

  /// How many times the scene has actually been replayed.
  ///
  /// THE ARTIFACT `#704` IS ABOUT. A pan that does not increment this is a
  /// pan that did no Dart painting, which is a claim a timing test on a
  /// build machine cannot make.
  @visibleForTesting
  int debugSceneRecordings = 0;

  void _paintScene(PaintingContext context, Offset offset) {
    // `offset` is Offset.zero here; the canvas is in scene space.
    debugSceneRecordings++;
    // The schematic's twin: see `render_schematic_canvas.dart`'s note.
    // `#704` removed the Dart cost of a pan and left the RASTER cost, and
    // an elevation zoomed in is a lot of fill. The picture does not change
    // while the viewport moves, so a pan should re-project a cached
    // texture rather than re-fill every chassis and every device.
    context.setIsComplexHint();
    // L1 — chassis: replay its absolute fragment as the background.
    if (_scene.fragments.containsKey(_rackId)) {
      final canvas = FlutterDiagramCanvas(
        context.canvas,
        measurer: _measurer,
        runs: _runs,
        // THE ZOOM IS IN `_paintTransformed`'s LAYER, above this picture
        // (`#906`, DR-170), so the canvas has to be told it.
        outerScale: _viewport.scale,
      );
      _scene.fragmentFor(_rackId).replay(canvas);
    }
    // L2 — device children, each painted at its scene offset (the device's
    // own paint translates its local fragment; see RenderDeviceBox.paint).
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as RackParentData;
      context.paintChild(child, pd.sceneOffset);
      child = pd.nextSibling;
    }
  }

  // The background itself is not an interactive target — but children are,
  // and the ancestor input Listener still pans over empty rack space.
  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final pd = child.parentData! as RackParentData;
      final childTransform = Matrix4.copy(_viewport.transform)
        ..translateByDouble(pd.sceneOffset.dx, pd.sceneOffset.dy, 0, 1);
      final isHit = result.addWithPaintTransform(
        transform: childTransform,
        position: position,
        hitTest: (r, transformed) => child!.hitTest(r, position: transformed),
      );
      if (isHit) return true;
      child = pd.previousSibling;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final pd = child.parentData! as RackParentData;
    transform
      ..multiply(_viewport.transform)
      ..translateByDouble(pd.sceneOffset.dx, pd.sceneOffset.dy, 0, 1);
  }
}
