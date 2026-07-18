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
// whose paint() is a bare fragment replay plus a screen-chrome hover/focus
// ring. The only bytes it draws come from `scene.fragmentFor(deviceId)`.
//
// DEFERRED, stated honestly (this stage's task brief): keyboard ACTIONS
// (arrow-nudge, delete, …) and selection are not wired — the device is
// focusable and hoverable and carries its Semantics, but the actions map is
// empty until the interaction/selection stage. Hit-testing returns true so
// the device is a hit target, but nothing consumes the hit yet (drag/select
// land later); the canvas still pans when a gesture starts over a device.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:rackmate_core/rackmate_core.dart';
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
  });

  final DiagramScene scene;
  final String deviceId;
  final TextMeasurer measurer;
  final String semanticLabel;
  final RackPalette palette;
  final bool hovered;
  final bool focused;

  @override
  RenderDeviceBox createRenderObject(BuildContext context) => RenderDeviceBox(
    scene: scene,
    deviceId: deviceId,
    measurer: measurer,
    semanticLabel: semanticLabel,
    palette: palette,
    hovered: hovered,
    focused: focused,
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
      ..focused = focused;
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
  }) : _scene = scene,
       _deviceId = deviceId,
       _measurer = measurer,
       _semanticLabel = semanticLabel,
       _palette = palette,
       _hovered = hovered,
       _focused = focused;

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
    // top-left). This is the doc's RenderDeviceBox.paint snippet, with the
    // one honest addition it elides: the translate that positions the
    // local-coordinate fragment.
    final canvas = FlutterDiagramCanvas(context.canvas, measurer: _measurer)
      ..save()
      ..translate(offset.dx, offset.dy);
    _scene.fragmentFor(_deviceId).replay(canvas);
    canvas.restore();

    if (_focused || _hovered) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _focused ? 2.0 : 1.5
        ..color = Color(_focused ? _palette.focus : _palette.hover);
      context.canvas.drawRect((offset & size).deflate(0.75), ring);
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
