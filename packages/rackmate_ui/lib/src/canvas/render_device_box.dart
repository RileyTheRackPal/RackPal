// ignore_for_file: prefer_initializing_formals, the render object exposes
// public constructor parameter names (`scene`, `deviceId`, …) that
// intentionally differ from the private backing fields they feed, because
// those fields have public getters + change-notifying setters (the standard
// mutable-RenderObject pattern) — the shorthand `this._field` form does not
// apply. Same convention as rackmate_core's entity classes.

// rackmate_ui/src/canvas/render_device_box.dart
//
// The CR-086 hybrid device, made concrete (docs/03-architecture.md §7.1/7.8,
// docs/08-pdf-export.md §7.8):
//
//   "Each device is still a RenderBox child of RenderRackCanvas — it owns
//    hit-testing, focus, hover, keyboard handling and Semantics … But its
//    paint() REPLAYS that device's DiagramScene fragment through
//    FlutterDiagramCanvas; it draws nothing itself. Pixels come from the
//    shared IR; behaviour comes from the widget."
//
// [DeviceBox] is the widget that owns the behaviour (focus + hover +
// cursor + Semantics label); [RenderDeviceBox] is the leaf render object
// whose paint() is a bare fragment replay plus screen chrome — a
// hover/focus ring AND (M1 selection stage) a third, distinct SELECTED
// outline. The only body bytes it draws come from
// `scene.fragmentFor(deviceId)`.
//
// The `selected` flag is pushed DOWN from `RackCanvasScreen`'s
// `SelectionController` (selection lives in the UI, observed here, never in
// the document — docs/03 §4.4), unlike hover/focus which the widget tracks
// itself. Three visually distinct states result: hover (thin edge glow),
// focus (2px edge ring), selected (2px inset accent border, docs/04 §3.5).
//
// STILL DEFERRED, stated honestly (this stage's task brief): keyboard
// ACTIONS local to the device (arrow-nudge, etc.) are not wired here — the
// canvas owns Delete/undo/redo via a Shortcuts/Actions layer, and this
// render object's own actions map stays empty. Marquee/range-select and the
// insertion caret are also later stages.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/shake_animation.dart';
import 'package:rackmate_ui/src/draw/flutter_canvas.dart';

/// The widget that owns a device's interactive behaviour. Wraps the leaf
/// [RenderDeviceBox] in a [FocusableActionDetector] (focus + hover + mouse
/// cursor) so "behaviour comes from the widget" is literally true, and
/// leaves the Semantics label to the render object's own
/// `describeSemanticsConfiguration`.
class DeviceBox extends StatefulWidget {
  const DeviceBox({
    required this.scene,
    required this.deviceId,
    required this.measurer,
    required this.semanticLabel,
    required this.palette,
    this.selected = false,
    this.shake,
    super.key,
  });

  /// The composed rack scene; this device replays `fragmentFor(deviceId)`.
  final DiagramScene scene;

  /// The device's entity id (`Uuid.v`) — the fragment key.
  final String deviceId;

  /// The shared measurer (CR-081), injected into the replay canvas.
  final TextMeasurer measurer;

  /// Accessible label — "DES — Name, Type".
  final String semanticLabel;

  final RackPalette palette;

  /// Whether this device is in the current selection (pushed down from
  /// `RackCanvasScreen`'s `SelectionController`). Drives the third,
  /// selected chrome state. Defaults false so non-editing hosts (and the
  /// render tests) need not supply it.
  final bool selected;

  /// Optional shake-feedback source (docs/04 §3.4: a blocked keyboard
  /// nudge "shakes 3px"), shared by every device in the rack. Passed
  /// straight through to [RenderDeviceBox], which listens to it directly
  /// (see that class's own doc comment on why) so a 120ms shake repaints
  /// only the one targeted device, at animation-frame rate, without any
  /// widget rebuild at all. `null` for non-editing hosts (and most render
  /// tests), which then never shake.
  final ShakeController? shake;

  @override
  State<DeviceBox> createState() => _DeviceBoxState();
}

class _DeviceBoxState extends State<DeviceBox> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // FocusableActionDetector = Focus + hover tracking + mouse cursor, the
    // idiomatic "this thing owns focus/hover/keyboard" widget. The hover and
    // focus flags flow into the render object, which repaints the chrome —
    // a per-device rebuild at human speed, never on the pan/zoom hot path.
    // `shake` is deliberately NOT threaded through a widget rebuild the same
    // way (see `RenderDeviceBox.shake`'s doc comment): `RenderDeviceBox`
    // listens to it directly, exactly like `RenderRackCanvas` already does
    // for `viewport` in this same file family.
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (h) => setState(() => _hovered = h),
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      child: _DeviceBoxLeaf(
        scene: widget.scene,
        deviceId: widget.deviceId,
        measurer: widget.measurer,
        semanticLabel: widget.semanticLabel,
        palette: widget.palette,
        hovered: _hovered,
        focused: _focused,
        selected: widget.selected,
        shake: widget.shake,
      ),
    );
  }
}

class _DeviceBoxLeaf extends LeafRenderObjectWidget {
  const _DeviceBoxLeaf({
    required this.scene,
    required this.deviceId,
    required this.measurer,
    required this.semanticLabel,
    required this.palette,
    required this.hovered,
    required this.focused,
    required this.selected,
    required this.shake,
  });

  final DiagramScene scene;
  final String deviceId;
  final TextMeasurer measurer;
  final String semanticLabel;
  final RackPalette palette;
  final bool hovered;
  final bool focused;
  final bool selected;
  final ShakeController? shake;

  @override
  RenderDeviceBox createRenderObject(BuildContext context) => RenderDeviceBox(
    scene: scene,
    deviceId: deviceId,
    measurer: measurer,
    semanticLabel: semanticLabel,
    palette: palette,
    hovered: hovered,
    focused: focused,
    selected: selected,
    shake: shake,
  );

  @override
  void updateRenderObject(BuildContext context, RenderDeviceBox renderObject) {
    renderObject
      ..scene = scene
      ..deviceId = deviceId
      ..measurer = measurer
      ..semanticLabel = semanticLabel
      ..palette = palette
      ..hovered = hovered
      ..focused = focused
      ..selected = selected
      ..shake = shake;
  }
}

/// A leaf render box that draws NOTHING of its own beyond replaying its
/// device's `DiagramScene` fragment (CR-086), plus a screen-chrome
/// hover/focus ring. Sized entirely by its parent's tight constraints
/// (`RenderRackCanvas` lays it out at the device's scene size), so it is its
/// own relayout boundary.
class RenderDeviceBox extends RenderBox {
  RenderDeviceBox({
    required DiagramScene scene,
    required String deviceId,
    required TextMeasurer measurer,
    required String semanticLabel,
    required RackPalette palette,
    bool hovered = false,
    bool focused = false,
    bool selected = false,
    ShakeController? shake,
  }) : _scene = scene,
       _deviceId = deviceId,
       _measurer = measurer,
       _semanticLabel = semanticLabel,
       _palette = palette,
       _hovered = hovered,
       _focused = focused,
       _selected = selected,
       _shake = shake;

  DiagramScene _scene;
  DiagramScene get scene => _scene;
  set scene(DiagramScene value) {
    if (identical(_scene, value)) return;
    _scene = value;
    markNeedsPaint();
  }

  String _deviceId;
  String get deviceId => _deviceId;
  set deviceId(String value) {
    if (_deviceId == value) return;
    _deviceId = value;
    markNeedsPaint();
  }

  TextMeasurer _measurer;
  TextMeasurer get measurer => _measurer;
  set measurer(TextMeasurer value) {
    if (identical(_measurer, value)) return;
    _measurer = value;
    markNeedsPaint();
  }

  String _semanticLabel;
  String get semanticLabel => _semanticLabel;
  set semanticLabel(String value) {
    if (_semanticLabel == value) return;
    _semanticLabel = value;
    markNeedsSemanticsUpdate();
  }

  RackPalette _palette;
  RackPalette get palette => _palette;
  set palette(RackPalette value) {
    if (_palette == value) return;
    _palette = value;
    markNeedsPaint();
  }

  bool _hovered;
  bool get hovered => _hovered;
  set hovered(bool value) {
    if (_hovered == value) return;
    _hovered = value;
    markNeedsPaint();
  }

  bool _focused;
  bool get focused => _focused;
  set focused(bool value) {
    if (_focused == value) return;
    _focused = value;
    markNeedsPaint();
  }

  bool _selected;
  bool get selected => _selected;
  set selected(bool value) {
    if (_selected == value) return;
    _selected = value;
    markNeedsPaint();
  }

  /// The shared shake-feedback source (docs/04 §3.4's blocked-nudge
  /// "shakes 3px"), or null for hosts that never shake (non-editing hosts,
  /// most render tests). Listened to DIRECTLY here — attach/detach a
  /// listener that just calls [markNeedsPaint], exactly like
  /// `RenderRackCanvas` already does for its own `viewport` field in this
  /// same file family — rather than pushed down through a widget rebuild.
  /// This matters because a shake runs for 120ms at animation-frame rate:
  /// routing it through `DeviceBox`'s `State.build()` (the way
  /// hovered/focused/selected are) would need an extra widget layer
  /// (e.g. `AnimatedBuilder`) around this leaf for every device — which
  /// silently doubles this device's count in `WidgetTester.allRenderObjects`
  /// (it maps EVERY element to its nearest render object, so if an extra
  /// ancestor Element is now in play, this same `RenderDeviceBox` gets
  /// listed once per ancestor rather than once per device), unrelated to
  /// production behaviour but real damage to any test built on that API's
  /// implicit "one entry per device" assumption — this was caught by
  /// `rack_canvas_screen_test.dart`'s existing "sole selection" assertion
  /// the first time this was wired the other way. Listening here avoids
  /// both problems: no extra widget, and a strictly cheaper repaint-only
  /// (never a rebuild) path.
  ShakeController? _shake;
  ShakeController? get shake => _shake;
  set shake(ShakeController? value) {
    if (identical(_shake, value)) return;
    if (attached) _shake?.removeListener(markNeedsPaint);
    _shake = value;
    if (attached) _shake?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _shake?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _shake?.removeListener(markNeedsPaint);
    super.detach();
  }

  // Sized entirely by the parent's tight constraints (the device's scene
  // size). No intrinsic content drives layout.
  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  // The device is a real hit target (that is the whole point of it being a
  // widget). Nothing consumes the hit this stage; drag/select land later.
  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    // CR-086: pixels come from the IR. Replay the device's own fragment,
    // translated to this child's paint offset (the parent has already put
    // the canvas in scene space, so `offset` is the device's scene
    // top-left) PLUS the current shake offset, if any (docs/04 §3.4) — a
    // paint-time-only nudge, so hit-testing/layout stay put. Read fresh
    // from `_shake` on every paint (not cached) since `_shake`'s own
    // listener only ever calls `markNeedsPaint`, never stores a value.
    // This is the doc's RenderDeviceBox.paint snippet, with the two honest
    // additions it elides: the translate that positions the
    // local-coordinate fragment, and the shake.
    final shakeOffset = _shake?.offsetFor(Uuid(_deviceId)) ?? Offset.zero;
    final paintOffset = offset + shakeOffset;
    final canvas = FlutterDiagramCanvas(context.canvas, measurer: _measurer)
      ..save()
      ..translate(paintOffset.dx, paintOffset.dy);
    _scene.fragmentFor(_deviceId).replay(canvas);
    canvas.restore();

    if (_focused || _hovered) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _focused ? 2.0 : 1.5
        ..color = Color(_focused ? _palette.focus : _palette.hover);
      context.canvas.drawRect((paintOffset & size).deflate(0.75), ring);
    }

    // The third state (docs/04 §3.5: "a 2px outline per member"), drawn AS
    // WELL AS any hover/focus ring and at a different inset (1.5px inside the
    // body) so a selected-and-focused device shows both borders distinctly
    // rather than one masking the other. Selection is chrome, so like the
    // hover/focus rings it is screen-space and not part of the shared IR.
    if (_selected) {
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Color(_palette.selection);
      context.canvas.drawRect((paintOffset & size).deflate(1.5), outline);
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // A real Semantics node for the device — the honest accessibility story
    // the hybrid render architecture exists to make possible (docs/04 §9).
    config
      ..isSemanticBoundary = true
      ..label = _semanticLabel
      ..textDirection = TextDirection.ltr;
  }
}
