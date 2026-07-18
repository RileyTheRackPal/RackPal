I'll research this thoroughly. Let me start by loading the web tools and running parallel searches.I'll research this thoroughly across all seven areas. Let me run parallel searches to build a current picture.Let me dig into the packages and specific technical areas.Two newer packages surfaced that weren't in the brief. Let me evaluate them.vyuh_node_flow looks strongest so far. Now the core rendering and hit-testing questions.Let me verify a load-bearing API claim and read the two most relevant deep-dive articles.Confirmed an important correction: Flutter has no public stroke-to-fill-path API. Let me nail down desktop input and spatial indexing.Flutter 3.41 is current and Impeller isn't yet default on Windows — important for a desktop-first app. Final round.# RackMate Canvas Architecture — Deep Technical Research

**Verified against:** Flutter 3.41 (stable, Feb 2026), Dart 3.12. Package data pulled from pub.dev July 2026.

---

## 0. Executive recommendation (read this first)

**Build the canvas. Adopt nothing.** Then three architectural calls that everything else follows from:

1. **Hybrid rendering**: `CustomPainter` for wires/grid/ports (the 800-edge problem), real widgets for the ~200 device bodies via a `MultiChildRenderObjectWidget`. Not pure-canvas, not pure-widget.
2. **Hand-rolled `Matrix4` viewport.** `InteractiveViewer` is wrong for this app — reasoning in §2, and it's not close.
3. **Store logical units as `int` millimetres × RU integers.** Never store device pixels. Never store doubles for positions.

One correction to your brief up front: **the "stroke-widening trick" you mention does not exist in Flutter.** Skia's `getFillPath` is not exposed through `dart:ui`, and Impeller [now strokes by iterating the original curve](https://github.com/flutter/flutter/pull/167422) rather than materialising an outline path, so it's unlikely to ever be exposed. Wire hit-testing must be manual distance math. Details in §3 — this is load-bearing for your architecture and worth knowing before you design around it.

And one environment finding that matters for a desktop-first product: **Impeller is not the default on Windows yet.** It is stable on iOS/Android as of 3.38, and the [2026 roadmap](https://docs.flutter.dev/perf/impeller) targets macOS/Windows/Linux during 2026. Windows desktop still renders through Skia today. Budget your frame costs against Skia, and re-benchmark when Impeller lands — the `saveLayer` and path-stroking numbers will shift meaningfully.

---

## 1. Rendering approach

### The scale question, answered

200 nodes / 800 wires is **comfortably within budget** — but only if you avoid the two naive extremes.

**Widget-per-node for everything** dies on the wires. 800 wire widgets means 800 × (build + layout + paint) per frame, plus 800 `RenderObject`s in the tree. Layout is the killer: wires are position-dependent on two nodes each, so any node drag dirties layout across the tree.

**Pure single `CustomPainter` for everything** works for wires but makes device bodies miserable: you hand-roll text layout, hit-testing, focus, hover, and accessibility for every label and button on every device. For an app with a device *builder*, where devices have editable labels and port lists, this is a large amount of self-inflicted work.

### The hybrid: `MultiChildRenderObjectWidget`

This is the approach serious Flutter node editors converge on, and it's what [plugfox's high-performance canvas writeup](https://plugfox.dev/high-performance-canvas-rendering/) argues for. Devices are real widgets (text, buttons, hover states, semantics all free). Wires, grid, ports, and selection chrome are painted directly into the same canvas, interleaved in z-order with the children.

```dart
class RackCanvas extends MultiChildRenderObjectWidget {
  const RackCanvas({
    super.key,
    required this.viewport,   // Listenable<Matrix4>
    required this.wires,      // wire model, painted not widgetised
    required super.children,  // one child per device
  });

  final ViewportController viewport;
  final WireModel wires;

  @override
  RenderRackCanvas createRenderObject(BuildContext context) =>
      RenderRackCanvas(viewport: viewport, wires: wires);

  @override
  void updateRenderObject(BuildContext context, RenderRackCanvas ro) {
    ro..viewport = viewport..wires = wires;
  }
}

class RenderRackCanvas extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, RackParentData>,
         RenderBoxContainerDefaultsMixin<RenderBox, RackParentData> {

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! RackParentData) child.parentData = RackParentData();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    // Devices are laid out at their intrinsic size at scene coords.
    // No parent-driven layout dependency => dragging one node
    // does NOT dirty layout for the others.
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as RackParentData;
      child.layout(BoxConstraints.tight(pd.sceneSize), parentUsesSize: false);
      child = pd.nextSibling;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.transform(viewport.matrix.storage);   // one transform for the scene
    _paintStaticLayer(canvas);                   // cached Picture: grid + rack rails
    _paintWires(canvas);                         // cached Picture when idle
    defaultPaint(context, offset);               // device widgets
    _paintOverlay(canvas);                       // selection, snap guides, live wire
    canvas.restore();
  }
}
```

The critical property in `performLayout`: children get **tight constraints from their own model size**, not from siblings. Dragging device A cannot dirty device B's layout. Combined with `parentUsesSize: false`, Flutter's relayout boundary logic keeps drags to paint-only.

### Actual per-frame costs

Hard numbers, since you asked for them:

| Operation | Cost | Source / note |
|---|---|---|
| `Canvas.drawCircle` (simple primitive) | **~2 µs** raster thread | [tst.sh measurement](https://notes.tst.sh/flutter/efficient-painter/) — linear O(n) |
| `Canvas.drawPath` (short orthogonal polyline, stroked) | ~2–5 µs | scales with segment count + stroke tessellation |
| `saveLayer` | **~1 ms** worst case | [Flutter perf docs](https://docs.flutter.dev/perf/best-practices) — offscreen alloc + render target switch |
| `TextPainter.layout` (short label, cold) | ~0.3–1 ms | [flutter#92173](https://github.com/flutter/flutter/issues/92173); line-breaking dominates |
| `TextPainter.paint` (warm, laid out) | ~10–20 µs | just `canvas.drawParagraph` |

Run the arithmetic for RackMate: 800 wires × ~4 µs ≈ **3.2 ms** of raster time. Your 60fps budget is 16.6 ms. That fits, but it's ~20% of the budget spent on wires alone — which is exactly why the caching in the next section matters, and why you should not treat 800 wires as free.

The two things that will actually kill you:

- **`saveLayer` at ~1ms is catastrophic at any repetition.** Three of them and you've blown a third of your frame. `saveLayer` is triggered implicitly by `Canvas.clipPath` with anti-aliasing + save, by opacity on a subtree, and by blend modes. For "dim unselected wires," do **not** use an opacity layer — bake alpha into the `Paint.color` per wire. Turn on `checkerboardOffscreenLayers` in DevTools and drive it to zero.
- **Text layout is ~100× the cost of text paint.** With ~200 devices × ~8 port labels = 1600 labels, cold layout is 0.5–1.6 *seconds*. This must be cached and is non-negotiable. §7.

### Caching static layers

Three-tier structure. This is the single highest-leverage optimisation in the whole design.

```dart
class LayerCache {
  ui.Picture? _picture;
  Object? _key;               // invalidation token

  ui.Picture get(Object key, void Function(Canvas) draw, Rect cullRect) {
    if (_picture != null && _key == key) return _picture!;
    _picture?.dispose();
    final rec = ui.PictureRecorder();
    draw(Canvas(rec, cullRect));
    _key = key;
    return _picture = rec.endRecording();
  }

  void dispose() { _picture?.dispose(); _picture = null; }
}
```

- **Tier 1 — grid + rack rails.** Invalidate on RU count / zoom-decade change only. A `Picture` here is near-free to replay.
- **Tier 2 — settled wires.** Invalidate on topology or node-position commit. During a drag, split: re-record the (few) wires attached to the dragged node each frame, replay the cached `Picture` for the other ~780. This is the whole ballgame for drag smoothness.
- **Tier 3 — live overlay.** Never cached: selection halo, rubber band, in-flight wire, snap guides.

Two subtleties worth knowing:

`Picture` **caches drawing instructions, not pixels.** Replaying still costs GPU time proportional to content — it saves the Dart-side command-building, not rasterisation. For a genuinely static layer that is expensive to *rasterise*, promote it to a texture with `Picture.toImageSync()` (synchronous, returns `ui.Image`, no await) and `drawImage` it. Trade-off: it's resolution-locked, so you must re-bake on significant zoom change. For a grid, `toImageSync` + re-bake per zoom decade is the right call; for wires, stay with `Picture` since they must stay crisp.

`RepaintBoundary` vs `Picture` are **complementary, not alternatives**. `RepaintBoundary` cuts the tree at a compositing layer so a repaint in one subtree doesn't force another — [it can promote a static complex subtree to a cached raster layer](https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html). But it operates at *widget* granularity. Inside your one big canvas, `Picture` is the only tool with the right granularity. Use `RepaintBoundary` around the canvas widget as a whole, and around sidebars/palettes so canvas repaints don't touch them. Don't wrap individual device widgets in `RepaintBoundary` — 200 compositing layers costs more than it saves.

---

## 2. Pan / zoom

### Don't use `InteractiveViewer`

I want to be direct here because the brief asks which "serious diagram apps" use: essentially none of them use `InteractiveViewer`, and the reasons are structural rather than stylistic.

`InteractiveViewer` is designed for viewing a *child widget*. It gives you a `TransformationController` wrapping a `Matrix4`, and [updates listeners on change](https://api.flutter.dev/flutter/widgets/InteractiveViewer/transformationController.html). What it does not give you:

- **No zoom-to-cursor.** It scales about the gesture focal point, which for a scroll-wheel `PointerSignal` it does not receive at all. Wheel zoom over a fixed cursor point is the single most-used interaction in a desktop diagram editor and you must implement it yourself regardless.
- **It owns the gesture arena.** It installs its own `ScaleGestureRecognizer`, which fights marquee-select, node dragging, and wire-drawing. You end up passing `panEnabled: false` and reimplementing pan — at which point you've written the controller anyway, minus the control.
- **`boundaryMargin` is the wrong model** for infinite-canvas-with-fit-to-content.
- **Child-based sizing** doesn't fit a scene defined by a model rather than a widget's intrinsic size.

Write ~150 lines instead and own it:

```dart
class ViewportController extends ChangeNotifier {
  Matrix4 _m = Matrix4.identity();
  Matrix4 get matrix => _m;

  double get scale => _m.getMaxScaleOnAxis();

  Offset toScene(Offset screen) {
    final inv = Matrix4.inverted(_m);
    final v = inv.transform3(vm.Vector3(screen.dx, screen.dy, 0));
    return Offset(v.x, v.y);
  }

  Offset toScreen(Offset scene) {
    final v = _m.transform3(vm.Vector3(scene.dx, scene.dy, 0));
    return Offset(v.x, v.y);
  }

  /// Zoom keeping [focalScreen] pinned to the same scene point.
  void zoomAt(Offset focalScreen, double factor) {
    final target = (scale * factor).clamp(0.05, 32.0);
    final applied = target / scale;                 // re-derive after clamp
    if ((applied - 1.0).abs() < 1e-9) return;
    final scenePt = toScene(focalScreen);
    _m = _m.clone()
      ..translate(scenePt.dx, scenePt.dy)
      ..scale(applied)
      ..translate(-scenePt.dx, -scenePt.dy);
    notifyListeners();
  }

  void panBy(Offset screenDelta) {
    _m = _m.clone()..leftTranslate(screenDelta.dx, screenDelta.dy);
    notifyListeners();
  }

  void fitTo(Rect contentScene, Size viewport, {double pad = 48}) {
    if (contentScene.isEmpty) return;
    final s = math.min(
      (viewport.width  - pad * 2) / contentScene.width,
      (viewport.height - pad * 2) / contentScene.height,
    ).clamp(0.05, 32.0);
    final c = contentScene.center;
    _m = Matrix4.identity()
      ..translate(viewport.width / 2, viewport.height / 2)
      ..scale(s)
      ..translate(-c.dx, -c.dy);
    notifyListeners();
  }
}
```

Note `leftTranslate` in `panBy` — pan deltas arrive in *screen* space and must be applied on the left (pre-multiplied in screen coords), whereas the zoom pivot uses right-multiplied `translate` in scene space. Getting this backwards produces pan that speeds up with zoom, which is the classic bug in hand-rolled viewports.

Drive repaints by passing the controller as `repaint:` to your painter or `markNeedsPaint()` in the render object — **never** `setState`. That keeps pan/zoom on the paint phase, skipping build and layout entirely.

### Zoom-independent visuals

Anything the *user touches or reads* must be constant in **screen** pixels; anything that represents *physical reality* scales with the scene. This distinction is the whole design rule:

```dart
// Scene-scaled: rack rails, device outlines, RU boundaries — real dimensions.
// Screen-constant: stroke widths, port dots, handles, hit slop, labels.
final inv = 1.0 / viewport.scale;

final wirePaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2.0 * inv        // renders as exactly 2 device px at any zoom
  ..color = cableType.color
  ..isAntiAlias = true;

const handleScreenPx = 7.0;
canvas.drawRect(
  Rect.fromCenter(center: portScene,
                  width: handleScreenPx * inv, height: handleScreenPx * inv),
  handlePaint,
);
```

Since you're painting inside a transformed canvas, multiply by `inv`. Hit-slop follows the same rule: a 6-screen-pixel tolerance becomes `6 * inv` scene units when testing against scene geometry (§3).

### Crisp text across zoom

This is where naive implementations look bad, and there's a real trap. Text inside a scaled canvas is rasterised by Skia/Impeller at the transformed size — **it does stay sharp**, it does not blur like a bitmap. The problem is different: every distinct scale is a **glyph-atlas cache miss**. Zooming continuously regenerates glyph rasters every frame and tanks the raster thread.

Two mitigations, both worth doing:

1. **Quantise text scale.** Snap the scale used for label rendering to a ladder (e.g. `0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0`), pick the nearest rung, and apply the small residual as a canvas scale around the label. Glyph atlas entries then hit for the vast majority of frames.
2. **Level-of-detail.** Below ~0.4 scale, port labels are illegible anyway — skip them entirely and draw the port as a coloured tick. Below ~0.2, draw devices as filled RU blocks with no internal detail. This is both a legibility win and a large performance win, and it's what `vyuh_node_flow` ships as a headline feature.

For labels that must never scale (reference designators, "U12" rulers), draw them **outside** the transform: compute screen position via `toScreen()` and paint in a second untransformed pass.

---

## 3. Hit-testing

### Screen → scene

`Matrix4.inverted(m)` throws on singular matrices; your matrix is always invertible if you clamp scale away from zero (done above). Cache the inverse — invalidate it in `notifyListeners`, don't recompute per hit-test:

```dart
Matrix4? _invCache;
Matrix4 get _inv => _invCache ??= Matrix4.inverted(_m);
// in every mutator: _invCache = null;
```

### Wires: the honest answer

Restating the correction, with the reasoning: `Path.contains()` [only works on closed paths](https://github.com/flutter/flutter/issues/96010) — a stroked polyline is not closed and `contains` returns false everywhere along it. And Flutter exposes **no** stroke-to-fill-path API. The community workaround of "build a closed path from rects + circles along the segments" is strictly worse than just doing the math.

`PathMetrics` is also the wrong tool despite seeming apt. You *can* walk a path with `computeMetrics()` and sample `getTangentForOffset()`, but sampling densely enough for accurate hit-testing means many samples per wire per test, allocating `PathMetric` objects each time — far slower than closed-form distance, and approximate anyway.

**Do closed-form point-to-segment distance.** Your wires are orthogonal polylines (per your schematic aesthetic), which makes this trivial and fast:

```dart
double _distSqToSegment(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx, dy = b.dy - a.dy;
  final lenSq = dx * dx + dy * dy;
  if (lenSq == 0) return (p - a).distanceSquared;
  var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq;
  t = t.clamp(0.0, 1.0);
  return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distanceSquared;
}

/// [tolScene] = desired screen tolerance / viewport.scale
Wire? hitWire(Offset scenePt, double tolScene) {
  final tolSq = tolScene * tolScene;
  final probe = Rect.fromCircle(center: scenePt, radius: tolScene);
  Wire? best; var bestSq = double.infinity;

  for (final id in _index.queryIds(probe)) {   // spatial index, see below
    final w = _wires[id]!;
    final pts = w.routedPoints;                // cached orthogonal polyline
    for (var i = 0; i < pts.length - 1; i++) {
      final d = _distSqToSegment(scenePt, pts[i], pts[i + 1]);
      if (d < bestSq && d <= tolSq) { bestSq = d; best = w; }
    }
  }
  return best;   // nearest wins — correct behaviour at crossings
}
```

Note it returns the **nearest** hit, not the first. At a wire crossing — which in a schematic-styled diagram is constant — first-hit picks arbitrarily and feels broken. Nearest-hit feels correct.

If you later add bezier wires, subdivide to a polyline once at route time (flatness-based, ~8–16 segments) and cache it in `routedPoints`. Then this same code handles both. Never hit-test the analytic curve.

### Spatial indexing: yes, but narrowly

At 800 wires × ~4 segments = 3200 segment tests per mouse-move, at maybe 20ns each ≈ **64 µs**. That is genuinely fine for click. It is *not* fine for **hover**, which fires on every mouse-move at 60–144 Hz while you're also painting — and hover-highlight of wires is essential UX for a wiring planner.

So: index it, but keep it simple.

- **[`r_tree` 0.9.x](https://pub.dev/packages/r_tree)** — last updated Feb 2026, actively maintained, indexes rectangles, good for static-ish data with bulk load. Best fit if wires are mostly settled.
- **[`expandable_quadtree`](https://pub.dev/packages/expandable_quadtree)** — quadtree that grows its bounds dynamically, which suits an infinite canvas where you don't know extents up front.
- **Or ~120 lines of your own uniform spatial hash.** Honestly the best choice at this scale: bucket segment AABBs into a `Map<int, List<int>>` keyed by grid cell. Insert/remove is O(1), rebuild on drag-commit is trivial, no dependency, no impedance mismatch with your model. R-trees earn their complexity at 10⁵+ objects; you have 10³.

My recommendation: **start with brute-force + an AABB reject** (`if (!w.bounds.inflate(tol).contains(p)) continue;` — that alone kills 95% of candidates), profile hover, and add the spatial hash only if hover shows up in the timeline. Do not import an R-tree on day one.

---

## 4. Desktop input

### `Listener` vs `GestureDetector` — use both, for different things

`GestureDetector` participates in the **gesture arena**, which introduces disambiguation delay and can lose to competing recognizers. For precise mouse work you want raw events. But the arena is what makes trackpad gestures work. So: `Listener` for wheel/precision, `GestureDetector` (or raw recognizers) for trackpad and touch.

Critically: **`GestureDetector` does not receive scroll-wheel events at all.** Wheel arrives as a `PointerSignalEvent`, only via `Listener.onPointerSignal`.

### Wheel zoom and the macOS/Windows split

This is genuinely messy and the docs undersell it. Since Flutter 3.3, [trackpad gestures generate `PointerPanZoom*` events](https://docs.flutter.dev/release/breaking-changes/trackpad-gestures) rather than synthetic scrolls:

| Input | Windows | macOS | Web |
|---|---|---|---|
| Mouse wheel | `PointerScrollEvent` (discrete, ~±120 quantum) | `PointerScrollEvent` | `PointerScrollEvent` |
| Trackpad 2-finger scroll | `PointerScrollEvent` (precision, small deltas) | `PointerPanZoomUpdateEvent` | `PointerScrollEvent` |
| Trackpad pinch | — | `PointerPanZoomUpdateEvent` (`.scale`) | `PointerScaleEvent` (ctrl+wheel emulation) |

And there is a known limitation you should design around rather than fight: **[Flutter cannot reliably distinguish mouse wheel from trackpad scroll](https://github.com/flutter/flutter/issues/88175)** on desktop. Heuristics on delta magnitude are fragile. The pragmatic convention, which matches Figma/Illustrator and is what users already expect:

```dart
Listener(
  onPointerSignal: (e) {
    if (e is PointerScrollEvent) {
      final ctrl = HardwareKeyboard.instance.isControlPressed ||
                   HardwareKeyboard.instance.isMetaPressed;
      if (ctrl) {
        viewport.zoomAt(e.localPosition, math.exp(-e.scrollDelta.dy * 0.002));
      } else if (HardwareKeyboard.instance.isShiftPressed) {
        viewport.panBy(Offset(-e.scrollDelta.dy, 0));   // shift = horizontal
      } else {
        viewport.panBy(-e.scrollDelta);                  // bare wheel = pan
      }
    } else if (e is PointerScaleEvent) {                 // web pinch
      viewport.zoomAt(e.localPosition, e.scale);
    }
  },
  onPointerPanZoomStart:  (e) => _tpBase = viewport.scale,
  onPointerPanZoomUpdate: (e) {                          // macOS trackpad
    viewport.panBy(e.panDelta);
    if (e.scale != 1.0) {
      viewport.zoomAt(e.localPosition, (_tpBase * e.scale) / viewport.scale);
    }
  },
  child: ...,
)
```

`math.exp(-delta * k)` rather than linear scaling gives **multiplicatively symmetric** zoom — three notches up then three down returns to exactly where you started. Linear stepping drifts, and users notice.

Make bare-wheel-pan-vs-zoom a **preference**. CAD users overwhelmingly expect bare wheel = zoom; Figma-natives expect pan. You will get complaints either way, so make it a setting on day one.

### Hover cursors

```dart
MouseRegion(
  cursor: switch (_hoverTarget) {
    HoverPort()   => SystemMouseCursors.precise,
    HoverWire()   => SystemMouseCursors.click,
    HoverDevice() => SystemMouseCursors.grab,
    HoverEdgeNS() => SystemMouseCursors.resizeUpDown,
    _             => _spacePanning ? SystemMouseCursors.grabbing
                                   : SystemMouseCursors.basic,
  },
  onHover: (e) => _updateHover(viewport.toScene(e.localPosition)),
  child: ...,
)
```

Throttle `_updateHover` to one hit-test per frame — bind it to a `Ticker` or guard with a dirty flag. Raw `onHover` can fire well above frame rate on high-polling-rate mice (1000 Hz gaming mice are common), and doing a spatial query per event is pure waste.

### Right-click context menus

Desktop-native menus, not Material popups. Use `ContextMenuController` (Flutter's own, stable since 3.7) or the `super_context_menu` package if you want true platform-native menus on Windows/macOS. Detect via `Listener.onPointerDown` checking `e.buttons & kSecondaryMouseButton != 0`, hit-test the scene point, and build the menu from what's under the cursor (device → Properties/Duplicate/Delete; wire → Change Cable Type/Reroute/Delete; empty → Paste/Add Device/Fit).

### Marquee select and modifiers

```dart
// on pointer down with primary button on empty canvas:
_marqueeStart = viewport.toScene(e.localPosition);
// on move: _marqueeEnd = ...; repaint overlay only
// on up:
final rect = Rect.fromPoints(_marqueeStart!, _marqueeEnd!);
final hits = _index.queryIds(rect).where((id) => /* full-containment vs intersect */);

final mode = HardwareKeyboard.instance.isShiftPressed  ? SelectMode.add
           : HardwareKeyboard.instance.isAltPressed    ? SelectMode.subtract
           : SelectMode.replace;
selection.apply(hits, mode);
```

Follow the CAD convention users already have muscle memory for: **left-to-right drag = full containment; right-to-left = intersection**. It costs you one `if` and reads as polish.

### Keyboard: `Shortcuts` / `Actions` / `Intent`

Use the real system rather than a `RawKeyboardListener` switch — it gives you focus scoping, menu-bar integration, and user-remappable bindings for free.

```dart
Shortcuts(
  shortcuts: <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): const UndoIntent(),
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): const RedoIntent(),
    const SingleActivator(LogicalKeyboardKey.keyA, control: true): const SelectAllIntent(),
    const SingleActivator(LogicalKeyboardKey.delete): const DeleteSelectionIntent(),
    const SingleActivator(LogicalKeyboardKey.digit0, control: true): const ZoomFitIntent(),
    const SingleActivator(LogicalKeyboardKey.equal, control: true): const ZoomInIntent(),
    for (final k in _arrowKeys)
      SingleActivator(k): NudgeIntent(k, fine: false),
    for (final k in _arrowKeys)
      SingleActivator(k, shift: true): NudgeIntent(k, fine: true),
  },
  child: Actions(
    actions: <Type, Action<Intent>>{
      UndoIntent: CallbackAction<UndoIntent>(onInvoke: (_) => history.undo()),
      NudgeIntent: CallbackAction<NudgeIntent>(onInvoke: (i) => _nudge(i)),
      // ...
    },
    child: Focus(autofocus: true, child: canvas),
  ),
)
```

Use `SingleActivator` over `LogicalKeySet` — it handles modifier-key laterality correctly and expresses intent more precisely. For cross-platform Cmd-vs-Ctrl, `SingleActivator(..., meta: Platform.isMacOS, control: !Platform.isMacOS)` or wrap in a small helper.

### Palette drag-and-drop

**Don't use `Draggable`/`DragTarget`.** They're built for widget-to-widget hand-off with widget-space coordinates, and you need the drop point in *scene* coordinates with live snapping feedback as you drag over the rack. Roll it with `Listener`: on palette pointer-down record the template; on move, if the pointer is over the canvas, convert to scene coords and paint a ghost device in the overlay layer with snap preview; on up, commit through the undo stack. You get correct coordinates, live RU snapping, and a proper undo entry — none of which `Draggable` gives you.

---

## 5. Snapping, alignment, and units

### Store integers, render doubles

Your model is a rack. Racks are quantised by nature — this is a gift, take it:

```dart
/// Vertical position is EXACT. Never a double.
class DevicePlacement {
  final String deviceId;      // stable UUID
  final int rackU;            // 0-based from bottom; exact integer
  final int heightU;          // 1U, 2U, 4U...
  final RackFace face;        // front | rear
}

/// Horizontal / free-floating geometry in integer tenths of a millimetre.
/// int64 in Dart, exact arithmetic, JSON-safe, diffable, no float drift.
class ScenePoint {
  final int xTenthMm;
  final int yTenthMm;
}
```

Rendering converts once at paint time: `sceneX = xTenthMm * 0.1 * pxPerMm`. Storing doubles for positions is the mistake that produces `173.99999999999997` in your `.rackmate` JSON, breaks equality checks, makes diffs noisy, and makes cloud sync conflict resolution miserable. Integers cost you nothing here and solve all of it — and given your `.rackmate` format is explicitly cloud-ready with change-tracking, this pays for itself immediately.

Rack constants worth naming: EIA-310 1U = 44.45 mm = **444 tenths-mm exactly**. 19" rail width = 482.6 mm = 4826. Both exact in integer tenths — no rounding anywhere in the vertical axis.

### Snap priority

Snapping is a *priority cascade*, not a set of independent rules. Run in order, take the first hit, and give each a tolerance in **screen** pixels converted to scene:

1. **Port snap** (12 screen px) — magnetic; a wire endpoint near a compatible port locks to it. Weight by type compatibility: an HDMI wire prefers an HDMI port even if an RJ45 port is marginally nearer. This is the single biggest usability win in the whole editor.
2. **RU snap** (always, vertical) — devices cannot occupy fractional U. Not a tolerance, a hard quantisation.
3. **Alignment guides** (6 screen px) — edges/centres of nearby devices; draw the classic red/magenta guide line while active.
4. **Grid snap** (fallback) — for free-floating annotation and wire waypoints.

Compute guide candidates only from devices within the viewport plus a margin — not all 200.

---

## 6. Package evaluation

Honest assessment. All data from pub.dev, July 2026.

| Package | Latest | Published | Likes / Points | Typed ports | Orthogonal routing | Undo | Verdict |
|---|---|---|---|---|---|---|---|
| [`vyuh_node_flow`](https://pub.dev/packages/vyuh_node_flow) | 0.27.3 | ~5 mo | 151 / 160 | Yes (+validation) | Bezier/smoothstep/**step** | Partial | **Best of breed** |
| [`fl_nodes`](https://pub.dev/packages/fl_nodes) | 0.5.0+1 | ~9 mo | 60 / 130 | Yes | No | Some | Interesting, immature |
| [`flutter_flow_chart`](https://pub.dev/packages/flutter_flow_chart) | 4.1.1 | ~7 mo | 196 / 160 | **No** | "rectangular" arrows only | **No** | Wrong shape |
| [`diagram_editor`](https://pub.dev/packages/diagram_editor) | 1.0.0 | ~4 mo | — | Type-safe data, not typed *ports* | No | **No** | Framework, not editor |
| [`graphview`](https://pub.dev/packages/graphview) | 1.5.1 | ~9 mo | — | No | No | No | **Visualisation only — no editing** |
| `node_editor` | — | stale | low | Some | No | No | Skip |
| `boardview` | — | stale | — | N/A | N/A | N/A | Kanban, irrelevant |
| `xml_flow` | — | — | — | — | — | — | Not a node editor |

Notes on the two that deserve real consideration:

**`vyuh_node_flow`** is legitimately good: verified publisher (vyuh.tech), MIT, 60fps claims, 20+ keyboard shortcuts, minimap, LOD rendering, group nodes, typed ports with connection validation, JSON serialisation, step (orthogonal) routing. If you were building a generic workflow editor I would tell you to use it.

**`fl_nodes`** ships a fragment shader for its grid (`packages/fl_nodes/shaders/grid.frag`) — a genuinely clever technique worth stealing regardless of adoption: an infinite grid drawn in one GPU draw call at any zoom, with zero CPU cost and no re-baking. Consider lifting that idea for Tier-1 of your layer cache.

### Build, don't adopt — and here's the actual reason

The version numbers tell the story: `0.27.3`, `0.5.0+1`, `1.0.0`. Every one of these is pre-1.0 or barely past it, single-maintainer, and moving. RackMate's canvas *is* the product — not a feature of it. Taking a hard dependency there means every roadmap item you have (rack-aware RU snapping, front/rear faces, the Structure device, cable-type colour semantics, PDF export geometry, wiring-schedule generation) requires either forking or upstream cooperation.

But the deeper mismatch is conceptual. **RackMate is not a node graph.** Node editors model *free-floating nodes in unconstrained 2D*. Your devices are constrained to integer RU slots in a fixed-width column, with a front/rear dimension that no node editor has any concept of. Your "nodes" don't move in x at all. Adopting a node-editor package means fighting its core layout assumption on every single feature — you'd spend more effort suppressing its behaviour than writing your own.

**What to do instead:** read `vyuh_node_flow`'s source (MIT — you can legitimately learn from and adapt it) for its port-connection validation model, its LOD thresholds, and its keyboard-shortcut taxonomy. Lift `fl_nodes`' shader-grid trick. Write your own ~2500-line canvas that knows what a rack unit is. For a developer with your background, that's a couple of weeks and you own the thing your product lives or dies by.

---

## 7. Text and accessibility

### `TextPainter` caching is mandatory

Given the ~1600-label figure from §1 and ~0.5ms cold layout each, this is not optional:

```dart
class LabelCache {
  final _cache = <_Key, TextPainter>{};

  TextPainter get(String text, TextStyle style, {double maxWidth = double.infinity}) {
    final key = _Key(text, style, maxWidth);
    return _cache.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      return tp;
    });
  }

  void evictUnused(Set<_Key> live) {
    _cache.removeWhere((k, tp) {
      if (live.contains(k)) return false;
      tp.dispose();            // REQUIRED — TextPainter holds native resources
      return true;
    });
  }
}
```

Three things that matter here:

- `TextPainter` **must be disposed** — it holds a native `ui.Paragraph`. Leaking these leaks native memory that Dart GC won't reclaim. [Dispose from `State.dispose`/`RenderObject.dispose`.](https://api.flutter.dev/flutter/painting/TextPainter-class.html)
- `TextPainter.layout` has [internal caching](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/painting/text_painter.dart) keyed on min/max width — calling `layout()` repeatedly with identical constraints early-returns. But it doesn't help across *instances*, hence the cache above.
- **Cache key must include the `TextStyle`.** Style changes (theme, zoom-driven font size) must miss. This is why you quantise text scale (§2) — with a scale ladder your key space stays small; with continuous scale every zoom frame is a total cache miss and you've built a cache that never hits.

Bound the cache (LRU, ~2000 entries) and evict per frame against the visible set.

### Semantics for a canvas

Because devices are real widgets in the hybrid architecture, they carry semantics **for free** — this is a significant and underrated argument for the hybrid over pure-canvas.

For canvas-painted content (wires, ports), implement [`CustomPainter.semanticsBuilder`](https://api.flutter.dev/flutter/rendering/CustomPainter/semanticsBuilder.html):

```dart
@override
SemanticsBuilderCallback get semanticsBuilder => (Size size) => [
  for (final w in visibleWires)
    CustomPainterSemantics(
      rect: w.screenBounds,
      properties: SemanticsProperties(
        label: '${w.cableType.name} cable, '
               '${w.fromDevice} ${w.fromPort} to ${w.toDevice} ${w.toPort}',
        button: true,
      ),
    ),
];

@override
bool shouldRebuildSemantics(covariant WirePainter old) =>
    old.topologyVersion != topologyVersion;   // NOT delegating to shouldRepaint
```

Override `shouldRebuildSemantics` explicitly rather than letting it [default to `shouldRepaint`](https://api.flutter.dev/flutter/rendering/CustomPainter/shouldRebuildSemantics.html) — otherwise every pan rebuilds the entire semantics tree, which is expensive and pointless since panning doesn't change what anything *is*.

Pragmatically: a wiring canvas is inherently visual, and the accessible surface that actually matters for RackMate is the **wiring schedule** — a real, navigable, screen-reader-friendly `DataTable` that you're building anyway for PDF export. Make that a first-class alternative view, not an afterthought. It's better accessibility than heroic canvas semantics, and it's free.

---

## 8. Concrete stack

```yaml
dependencies:
  flutter: {sdk: flutter}
  vector_math: ^2.2.0        # Matrix4 (transitively available via flutter)
  uuid: ^4.5.1               # stable IDs for cloud-ready model
  pdf: ^3.11.x               # PDF export — pure Dart, no native dep
  printing: ^5.13.x          # print/preview/share
  collection: ^1.19.x
  super_context_menu: ^0.9.x # optional: native platform context menus

dev_dependencies:
  flutter_test: {sdk: flutter}
```

Deliberately **not** included: any node-editor package (§6), any spatial-index package (start brute-force, §3), `InteractiveViewer` (it's in the SDK; just don't use it).

For PDF: the `pdf` package's `CustomPaint` widget takes a raw PDF graphics stream, so you can emit **vector** wire geometry rather than rasterising the canvas. Structure your painting code so the wire-routing pass emits an abstract path list that both the screen painter and the PDF painter consume. Vector output means infinitely zoomable, printable, and searchable-text schedules — a real quality differentiator for a document users hand to installers on site.

### Build order

1. `ViewportController` + wheel/trackpad input + a grid painter. Get pan/zoom feeling *right* — this is the foundation everything sits on and it's cheap to iterate on early.
2. Integer unit model + `.rackmate` schema with `schemaVersion` + UUIDs.
3. `RenderRackCanvas` hybrid with device widgets, RU snapping.
4. Ports + typed connections + the snap cascade.
5. Orthogonal wire router + `LayerCache` tiers.
6. Undo/redo as a command stack (do this **before** the feature surface grows — retrofitting undo is one of the genuinely painful refactors).
7. Marquee, shortcuts, context menus.
8. PDF export (vector diagram + schedule table).

---

## Sources

- [High-Performance Canvas Rendering — plugfox.dev](https://plugfox.dev/high-performance-canvas-rendering/)
- [Efficient Painter — notes.tst.sh](https://notes.tst.sh/flutter/efficient-painter/)
- [Flutter performance best practices (`saveLayer` cost)](https://docs.flutter.dev/perf/best-practices)
- [Impeller rendering engine — status & 2026 roadmap](https://docs.flutter.dev/perf/impeller)
- [Flutter 3.38.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.38.0)
- [Trackpad gestures breaking change](https://docs.flutter.dev/release/breaking-changes/trackpad-gestures)
- [`RepaintBoundary` API](https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html)
- [`TextPainter` API](https://api.flutter.dev/flutter/painting/TextPainter-class.html) · [source](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/painting/text_painter.dart)
- [`CustomPainter.semanticsBuilder`](https://api.flutter.dev/flutter/rendering/CustomPainter/semanticsBuilder.html) · [`CustomPainterSemantics`](https://api.flutter.dev/flutter/rendering/CustomPainterSemantics-class.html)
- [`PathMetrics`](https://api.flutter.dev/flutter/dart-ui/PathMetrics-class.html) · [`InteractiveViewer.transformationController`](https://api.flutter.dev/flutter/widgets/InteractiveViewer/transformationController.html)
- [flutter#96010 — hit-testing non-closed paths](https://github.com/flutter/flutter/issues/96010) · [flutter#92173 — `paragraph.layout()` cost](https://github.com/flutter/flutter/issues/92173) · [flutter#88175 — mouse vs trackpad indistinguishable](https://github.com/flutter/flutter/issues/88175) · [flutter#167422 — Impeller direct stroking](https://github.com/flutter/flutter/pull/167422)
- pub.dev: [vyuh_node_flow](https://pub.dev/packages/vyuh_node_flow) · [fl_nodes](https://pub.dev/packages/fl_nodes) · [flutter_flow_chart](https://pub.dev/packages/flutter_flow_chart) · [diagram_editor](https://pub.dev/packages/diagram_editor) · [graphview](https://pub.dev/packages/graphview) · [r_tree](https://pub.dev/packages/r_tree) · [expandable_quadtree](https://pub.dev/packages/expandable_quadtree)