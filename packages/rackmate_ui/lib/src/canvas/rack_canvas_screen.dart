import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, LogicalKeyboardKey;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/canvas_intent.dart';
import 'package:rackmate_ui/src/canvas/grid_painter.dart';
import 'package:rackmate_ui/src/canvas/render_device_box.dart';
import 'package:rackmate_ui/src/canvas/render_rack_canvas.dart';
import 'package:rackmate_ui/src/canvas/selection_controller.dart';
import 'package:rackmate_ui/src/canvas/viewport_controller.dart';
import 'package:rackmate_ui/src/palette/device_palette_panel.dart';

/// The rack editor canvas: the pannable/zoomable grid (L0) with a real rack
/// chassis (L1) and device bodies (L2) rendered on top, per CR-086 — the
/// chassis and each device replay their `DiagramScene` fragment through
/// `FlutterDiagramCanvas`, and each device is a `RenderDeviceBox` widget
/// that owns its own hit-testing, hover, focus and Semantics.
///
/// M1 wires the first REAL, command-routed editing loop on top of that:
/// click to select (Ctrl/Cmd+click toggles), drag a selected device to move
/// it with RU snapping, `Del`/`Backspace` to remove, `Ctrl/Cmd+Z` /
/// `Ctrl/Cmd+Shift+Z` (or `Ctrl+Y`) to undo/redo. Every mutation goes
/// through the real `DocumentController`/`Command` system
/// (docs/03 §5) — the document is only ever changed through a `Command`,
/// exercised here by a real gesture for the first time. Selection is
/// OBSERVED, not owned by the document (docs/03 §4.4): it lives in
/// [SelectionController] and never dirties the file or bumps an epoch.
///
/// The scene is (re)built only when something MEANINGFUL changes — the face,
/// the LOD tier, the theme palette, the current SELECTION, or a committed
/// structural edit (the `structure` epoch) — never per pan/zoom frame.
/// Panning and zooming inside one LOD tier is a pure repaint driven by the
/// `ViewportController` listenable (docs/03 §7.3: "no setState in the canvas
/// path"); the scene geometry is identical within a tier, so it is not
/// rebuilt.
class RackCanvasScreen extends StatefulWidget {
  const RackCanvasScreen({required this.measurer, super.key});

  /// The shared `TextMeasurer` (CR-081) used to build the scene AND to paint
  /// it, so on-screen layout matches what the PDF backend would measure. The
  /// app injects one `PdfFontMeasurer`; `rackmate_ui` never constructs one
  /// (it must not depend on `package:pdf`).
  final TextMeasurer measurer;

  @override
  State<RackCanvasScreen> createState() => _RackCanvasScreenState();
}

class _RackCanvasScreenState extends State<RackCanvasScreen> {
  /// Net pointer travel (screen px) below which a drag is treated as a click
  /// (docs/04 §3.1 step 1: "Nothing until 4 px of movement, so a click still
  /// means show details"). Compared in screen space so the slop does not
  /// shrink/grow with zoom.
  static const double _clickSlopPx = 4;

  final ViewportController _viewport = ViewportController();
  final GridCache _gridCache = GridCache();

  /// The observable selection (docs/03 §4.4) — UI-owned, never persisted.
  final SelectionController _selection = SelectionController();

  /// Focus for the canvas so its Shortcuts/Actions receive Del/undo/redo.
  final FocusNode _canvasFocus = FocusNode(debugLabel: 'rackCanvas');

  /// `/` focuses the palette search field (docs/04 §3.2, §8 keymap).
  final FocusNode _paletteSearchFocus = FocusNode(debugLabel: 'paletteSearch');

  /// The seeded catalog (docs/09-roadmap.md M1 checklist #6,
  /// docs/catalog/seed-devices.md): 30 rack-side archetypes + 18 field
  /// devices. Every entry is ALSO embedded into `_doc.templates` at
  /// document construction (see `_buildDemoDocument`) so a palette
  /// placement always resolves a real `TemplateSnapshot`.
  late final Map<String, TemplateBody> _catalog = buildSeedCatalog();

  // Four hand-built demo devices (see _buildDemoDocument) still seed the
  // INITIAL rack contents — kept for continuity with earlier stages rather
  // than deleted, per this stage's task brief ("existing demo devices can
  // stay… your call"). The catalog above is what the palette adds FROM.
  //
  // Wrapped in the REAL DocumentController — THE one mutation entry point
  // (docs/03 §5.4). Every move/delete/undo/redo/place below runs through it.
  late final DocumentController _controller =
      DocumentController(_buildDemoDocument(_catalog));
  RackDocument get _doc => _controller.doc;
  late final Rack _rack = _doc.racks.values.first;
  late final RackGeometry _geo = RackGeometry(_rack.heightU);

  Face _face = Face.front;
  late LodLevel _lod = LodLevel.forScale(_viewport.scale);

  /// The scene most recently built in [build]. The intent handler hit-tests
  /// and reads device layouts against exactly what is on screen, so it must
  /// see the current build's scene; cached here rather than threaded through
  /// the pointer-agnostic `CanvasIntentHandler` interface.
  RackScene? _rackScene;

  late final _RackCanvasHandler _handler = _RackCanvasHandler(this);

  // ── per-drag scratch state (one primary pointer at a time) ────────────
  String? _dragDeviceId; // device hit at beginDrag, or null (empty canvas)
  DPt _dragStartScene = const DPt(0, 0);
  double _dragStartScale = 1;
  bool _dragModifierToggle = false; // Ctrl/Cmd held at beginDrag → toggle
  bool _dragMoved = false; // crossed the click→drag threshold
  int _dragDeviceHeightU = 0; // hit device's U height (0 if none)
  double _dragDeviceStartTopY = 0; // hit device's scene-space top edge

  @override
  void initState() {
    super.initState();
    _viewport.addListener(_onViewportChanged);
    // A committed structural edit (add/remove/move touches `structure`) and a
    // selection change both mean "rebuild the scene / repaint chrome"; both
    // fire at human speed, never on the pan/zoom hot path.
    _selection.addListener(_onEditorChanged);
    _controller.epochs.structure.addListener(_onEditorChanged);
  }

  @override
  void dispose() {
    _viewport
      ..removeListener(_onViewportChanged)
      ..dispose();
    _selection
      ..removeListener(_onEditorChanged)
      ..dispose();
    _controller.epochs.structure.removeListener(_onEditorChanged);
    _gridCache.dispose();
    _canvasFocus.dispose();
    _paletteSearchFocus.dispose();
    super.dispose();
  }

  /// Rebuilds the scene only when zoom crosses an LOD tier boundary — a few
  /// times across the whole zoom range, never per frame. Pan/zoom within a
  /// tier repaints via the viewport listenable without a rebuild.
  void _onViewportChanged() {
    final next = LodLevel.forScale(_viewport.scale);
    if (next != _lod) setState(() => _lod = next);
  }

  /// A selection change or a committed structural edit — rebuild so the new
  /// selection chrome and any add/remove/move show up. Never called during
  /// build (selection/document mutate only from gestures and key actions).
  void _onEditorChanged() {
    if (mounted) setState(() {});
  }

  void _cycleFace() {
    // Front → Rear (docs/04 §2.2 cycles Front → Rear → Both; Both is
    // deferred with rear-mirroring, so this stage toggles the two faces).
    setState(() => _face = _face == Face.front ? Face.rear : Face.front);
  }

  // ── the command-routed editing loop ───────────────────────────────────

  DeviceLayout? _layoutFor(String deviceId) {
    for (final layout in _rackScene?.devices ?? const <DeviceLayout>[]) {
      if (layout.deviceId.v == deviceId) return layout;
    }
    return null;
  }

  void _onBeginDrag(DPt sceneStart, Set<PointerDeviceKind> kinds) {
    // Take canvas focus so Del/undo/redo shortcuts land here, not on a
    // device's FocusableActionDetector (or nothing).
    _canvasFocus.requestFocus();
    _dragStartScene = sceneStart;
    _dragStartScale = _viewport.scale;
    _dragMoved = false;
    _dragModifierToggle = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    final scene = _rackScene?.scene;
    // Nearest-hit against the CURRENT scene (draw/hit_test.dart) — device
    // bodies only this stage, so exact containment; a small tolerance would
    // matter once wires exist.
    final region = scene == null ? null : hitTest(scene, sceneStart);
    _dragDeviceId = region?.entityId;
    _dragDeviceHeightU = 0;
    final layout = region == null ? null : _layoutFor(region.entityId);
    if (layout != null) {
      _dragDeviceStartTopY = layout.rect.top;
      _dragDeviceHeightU =
          (layout.rect.height / RackGeometry.unitsPerRu).round();
    }
  }

  void _onUpdateDrag(DPt sceneCurrent, DPt sceneDelta) {
    if (_dragMoved) return; // already a drag; nothing to recompute until commit
    final dx = sceneCurrent.x - _dragStartScene.x;
    final dy = sceneCurrent.y - _dragStartScene.y;
    final movedScreenPx = math.sqrt(dx * dx + dy * dy) * _dragStartScale;
    if (movedScreenPx >= _clickSlopPx) _dragMoved = true;
  }

  void _onCommitDrag(DPt sceneEnd) {
    final deviceId = _dragDeviceId;
    if (!_dragMoved) {
      _handleClick(deviceId);
    } else if (deviceId != null &&
        _dragDeviceHeightU > 0 &&
        _selection.contains(Uuid(deviceId))) {
      // Move only a device that is BOTH hit at grab time AND already
      // selected (task brief). Single-device move: if several are selected,
      // dragging one moves just that one (multi-device drag is deferred).
      _handleMove(deviceId, sceneEnd);
    }
    // else — a drag on empty canvas, or on an unselected device: a no-op this
    // stage. Left-drag-on-empty is reserved for marquee (deferred, docs/04
    // §3.5); grab-to-move-an-unselected-device is intentionally not a gesture
    // (select first, then drag).
    _resetDrag();
  }

  void _onCancelDrag() => _resetDrag();

  void _resetDrag() {
    _dragDeviceId = null;
    _dragDeviceHeightU = 0;
    _dragMoved = false;
  }

  void _handleClick(String? deviceId) {
    if (deviceId == null) {
      _selection.clear(); // click on empty canvas clears the selection
      return;
    }
    final id = Uuid(deviceId);
    if (_dragModifierToggle) {
      // Ctrl/Cmd+click toggles this one id: subtract if present, else add.
      _selection.apply(
        [id],
        _selection.contains(id) ? SelectMode.subtract : SelectMode.add,
      );
    } else {
      _selection.apply([id], SelectMode.replace);
    }
  }

  void _handleMove(String deviceId, DPt sceneEnd) {
    final device = _doc.devices[Uuid(deviceId)];
    final placement = device?.placement;
    if (placement is! RailPlacement) return;

    // New top edge = the device's original top + the vertical drag delta, so
    // the grab offset is preserved; then snapped + rack-clamped through the
    // ONE inverse geometry (rack_geometry.ruIndexForTopY).
    final newTopY = _dragDeviceStartTopY + (sceneEnd.y - _dragStartScene.y);
    final candidate = _geo.ruIndexForTopY(newTopY, _dragDeviceHeightU);
    if (candidate == placement.ruIndex) return; // no net move

    // SIMPLIFICATION (task brief): a target RU range already occupied by
    // ANOTHER device on this face refuses the move SILENTLY — no clamp to a
    // free slot, no push. Live blocked-drop / collision feedback during the
    // drag is a later stage (docs/04 §3.1). The candidate is already clamped
    // to the rack extent, so this only guards inter-device overlap.
    if (!_rangeFreeOnFace(candidate, _dragDeviceHeightU, Uuid(deviceId))) {
      return;
    }

    // selectionBefore for the undo entry = the live selection (docs/03 §4.4);
    // a move leaves the selection unchanged, so selectionAfter matches.
    _controller.selection = _selection.snapshot();
    _controller.run(
      MoveDeviceCommand(
        id: Uuid(deviceId),
        fromRuIndex: placement.ruIndex,
        toRuIndex: candidate,
        fromFace: placement.face,
        toFace: placement.face,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      ),
    );
  }

  /// Whether `[ruStart, ruStart+deviceH-1]` is free of every OTHER device on
  /// the current face. Derived from the current scene's device layouts (which
  /// are exactly the visible devices on this face), so no template re-resolve
  /// is needed and it can never disagree with what is drawn.
  bool _rangeFreeOnFace(int ruStart, int deviceH, Uuid exceptId) {
    final endExcl = ruStart + deviceH;
    for (final layout in _rackScene?.devices ?? const <DeviceLayout>[]) {
      if (layout.deviceId == exceptId) continue;
      final otherStart =
          (_geo.heightU + 1 - layout.rect.bottom / RackGeometry.unitsPerRu)
              .round();
      final otherEndExcl =
          otherStart + (layout.rect.height / RackGeometry.unitsPerRu).round();
      if (ruStart < otherEndExcl && otherStart < endExcl) return false;
    }
    return true;
  }

  void _deleteSelection() {
    final ids = _selection.ids.toList();
    if (ids.isEmpty) return;
    _controller.selection = _selection.snapshot(); // before = current selection
    // One transaction so a multi-device delete is a SINGLE undo entry, not N
    // (docs/04 §3.5: "undo restores device and links as one command"). Links
    // are not modelled on these demo devices yet; a real delete will also
    // carry each device's Links in this same transaction (deferred).
    _controller.transact(LabelKey.removeDevice, (tx) {
      for (final id in ids) {
        if (_doc.devices.containsKey(id)) {
          tx.add(RemoveDeviceCommand(id: id));
        }
      }
      // Post-delete the selection is empty; capture it so undo restores the
      // pre-delete selection and redo restores empty.
      _selection.clear();
      _controller.selection = _selection.snapshot(); // after = {}
    });
  }

  void _undo() {
    final restore = _controller.undoLast();
    if (restore != null) _selection.restore(restore);
  }

  void _redo() {
    final restore = _controller.redoLast();
    if (restore != null) _selection.restore(restore);
  }

  // ── palette placement (docs/09-roadmap.md M1 checklist #6; docs/04 §3.2
  // "the faster paths") — CLICK-TO-ADD, not the full drag-from-palette-to-
  // rails gesture of §3.1 (arm/lift/enter-canvas/snap/evaluate/commit with
  // live blocked-drop feedback), which is this stage's explicitly deferred
  // stretch goal. Double-clicking (or pressing Enter on) a palette row
  // inserts one new instance of that catalog template at the lowest
  // fitting free U on the demo rack, exactly like §3.2's "faster paths".

  void _placeFromCatalog(String catalogId) {
    // selectionBefore for the undo entry = the live selection, same
    // convention as _handleMove/_deleteSelection.
    _controller.selection = _selection.snapshot();
    final result = buildPlaceFromCatalogCommand(
      doc: _doc,
      catalogId: catalogId,
      targetRack: _rack,
      now: _controller.clock.nowUtc(),
      actor: _controller.actor,
    );
    if (result is CatalogPlacementReady) {
      _controller.run(result.command);
      // The freshly-placed device becomes the sole selection (docs/04
      // §3.1 step 6) — a plain UI-selection update, not itself undoable
      // (docs/03 §4.4: selection is observed, never document state).
      _selection.apply([result.command.id], SelectMode.replace);
    } else if (result is CatalogPlacementFailed && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.reason)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gridStyle = GridStyle(
      minorColor: scheme.outlineVariant.withValues(alpha: 0.55),
      majorColor: scheme.outline.withValues(alpha: 0.85),
    );
    final palette = _rackPalette(scheme);

    // Built here (not cached in a field) so a theme or face change rebuilds
    // it for free; it is cheap for one rack + a handful of devices. Cached
    // into `_rackScene` immediately so the intent handler hit-tests against
    // the SAME scene the frame paints.
    final rackScene = buildRackScene(
      rack: _rack,
      devices: _doc.devices.values,
      templates: _doc.templates,
      face: _face,
      lod: _lod,
      measurer: widget.measurer,
      palette: palette,
    );
    _rackScene = rackScene;

    // Shortcuts/Actions + an autofocused Focus give the canvas Del/Backspace
    // (delete the selection) and Ctrl/Cmd+Z / Ctrl/Cmd+Shift+Z / Ctrl+Y
    // (undo/redo). SingleActivator's exact-modifier match keeps Ctrl+Z and
    // Ctrl+Shift+Z mutually exclusive, so redo never also fires undo.
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.delete): _DeleteIntent(),
        SingleActivator(LogicalKeyboardKey.backspace): _DeleteIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            _RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): _RedoIntent(),
        // docs/04 §3.2 / §8: "/" focuses the palette search field — the
        // fastest path to populating a rack.
        SingleActivator(LogicalKeyboardKey.slash): _FocusPaletteSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _DeleteIntent: CallbackAction<_DeleteIntent>(
            onInvoke: (_) {
              _deleteSelection();
              return null;
            },
          ),
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) {
              _undo();
              return null;
            },
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) {
              _redo();
              return null;
            },
          ),
          _FocusPaletteSearchIntent: CallbackAction<_FocusPaletteSearchIntent>(
            onInvoke: (_) {
              _paletteSearchFocus.requestFocus();
              return null;
            },
          ),
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 280,
              child: DevicePalettePanel(
                catalog: _catalog,
                categoryOrder: kCatalogCategoryOrder,
                searchFocusNode: _paletteSearchFocus,
                onPlace: _placeFromCatalog,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Focus(
                focusNode: _canvasFocus,
                autofocus: true,
                child: _buildCanvas(
                  context,
                  scheme,
                  gridStyle,
                  palette,
                  rackScene,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas(
    BuildContext context,
    ColorScheme scheme,
    GridStyle gridStyle,
    RackPalette palette,
    RackScene rackScene,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = constraints.biggest;
        return ColoredBox(
          color: scheme.surface,
          child: Stack(
            children: [
              Positioned.fill(
                child: CanvasIntentDetector(
                  viewport: _viewport,
                  // The editing handler now consumes primary drags (select /
                  // move). Panning is via scroll, trackpad, or middle-mouse
                  // drag; primary-drag-on-empty is reserved for marquee
                  // (deferred), so it no longer pans.
                  handler: _handler,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: GridPainter(
                          viewport: _viewport,
                          cache: _gridCache,
                          style: gridStyle,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      RackCanvasBody(
                        scene: rackScene.scene,
                        viewport: _viewport,
                        measurer: widget.measurer,
                        rackId: rackScene.rackId.v,
                        children: [
                          for (final d in rackScene.devices)
                            RackDevicePlacement(
                              key: ValueKey(d.deviceId.v),
                              sceneOffset: Offset(d.rect.left, d.rect.top),
                              sceneSize: Size(d.rect.width, d.rect.height),
                              child: DeviceBox(
                                scene: rackScene.scene,
                                deviceId: d.deviceId.v,
                                measurer: widget.measurer,
                                semanticLabel: d.semanticLabel,
                                palette: palette,
                                selected: _selection.contains(d.deviceId),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _ViewportHud(
                  viewport: _viewport,
                  onReset: _viewport.reset,
                  onFit: () => _viewport.fitToContent(
                    Box.fromLtwh(
                      0,
                      0,
                      _geo.rackWidth.ceil(),
                      _geo.rackHeight.ceil(),
                    ),
                    viewportSize,
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: _FaceToggle(face: _face, onToggle: _cycleFace),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: Text(
                    'Click to select  ·  Ctrl/Cmd+click toggles  ·  drag a '
                    'selected device to move  ·  Del removes  ·  '
                    'Ctrl/Cmd+Z / +Shift+Z undo/redo  ·  scroll or '
                    'middle-drag to pan  ·  Ctrl/Cmd+scroll to zoom',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Theme `ColorScheme` → the core's Flutter-free `RackPalette` (packed
  /// ARGB), so the rack tracks light/dark without core importing `dart:ui`.
  RackPalette _rackPalette(ColorScheme s) {
    int argb(Color c, [double? opacity]) =>
        (opacity == null ? c : c.withValues(alpha: opacity)).toARGB32();
    return RackPalette(
      frame: argb(s.outline),
      rail: argb(s.surfaceContainerHighest),
      railStroke: argb(s.outlineVariant),
      divisionMinor: argb(s.outlineVariant, 0.30),
      divisionMajor: argb(s.outline, 0.60),
      rulerText: argb(s.onSurfaceVariant),
      rulerTextMajor: argb(s.onSurface),
      deviceFill: argb(s.surfaceContainer),
      deviceStroke: argb(s.outline),
      deviceDesignator: argb(s.onSurface),
      deviceName: argb(s.onSurfaceVariant),
      deviceType: argb(s.onSurfaceVariant, 0.80),
      deviceBadge: argb(s.onSurfaceVariant),
      hover: argb(s.primary),
      focus: argb(s.primary),
      // A different accent than hover/focus so the third (selected) state
      // reads as its own even where a device is both selected and focused.
      selection: argb(s.tertiary),
    );
  }
}

// ── keyboard intents + the pointer-agnostic editing handler ────────────────

/// Delete the current selection (`Del` / `Backspace`).
class _DeleteIntent extends Intent {
  const _DeleteIntent();
}

/// Undo the last committed transaction (`Ctrl/Cmd+Z`).
class _UndoIntent extends Intent {
  const _UndoIntent();
}

/// Redo the last undone transaction (`Ctrl/Cmd+Shift+Z`, `Ctrl+Y`).
class _RedoIntent extends Intent {
  const _RedoIntent();
}

/// Focus the palette search field (`/`).
class _FocusPaletteSearchIntent extends Intent {
  const _FocusPaletteSearchIntent();
}

/// Routes the pointer-agnostic `CanvasIntent` sequence into the screen's
/// select / move logic (docs/03 §4.4). A thin adapter: it holds no state of
/// its own and never branches on `PointerDeviceKind` (the editing-semantics
/// rule), forwarding each call to the `State` that owns the controllers.
class _RackCanvasHandler implements CanvasIntentHandler {
  _RackCanvasHandler(this._state);

  final _RackCanvasScreenState _state;

  @override
  void beginDrag(DPt sceneStart, Set<PointerDeviceKind> sourceKinds) =>
      _state._onBeginDrag(sceneStart, sourceKinds);

  @override
  void updateDrag(DPt sceneCurrent, DPt sceneDelta) =>
      _state._onUpdateDrag(sceneCurrent, sceneDelta);

  @override
  void commitDrag(DPt sceneEnd) => _state._onCommitDrag(sceneEnd);

  @override
  void cancel() => _state._onCancelDrag();
}

// ── temporary demo data (see the field comment above) ─────────────────────

RackDocument _buildDemoDocument(Map<String, TemplateBody> catalog) {
  final now = DateTime.utc(2026, 7, 18);
  EntityMeta meta() =>
      EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'demo');

  TemplateSnapshot snapshot(
    String id, {
    required int frontU,
    required String displayName,
    int rearU = 0,
  }) => TemplateSnapshot(
    templateId: TemplateId(id),
    version: 1,
    contentHash: 'sha256:demo-$id',
    capturedAt: now,
    body: TemplateBody(
      manufacturer: 'Demo',
      model: id,
      displayName: displayName,
      frontU: frontU,
      rearU: rearU,
      side: rearU > 0
          ? (frontU > 0 ? OccupancySide.both : OccupancySide.rear)
          : OccupancySide.front,
    ),
  );

  DeviceInstance device(
    String id, {
    required String designator,
    required String name,
    required String templateId,
    required int ruIndex,
    Face face = Face.front,
  }) => DeviceInstance(
    id: Uuid(id),
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(templateId),
      version: 1,
      contentHash: 'sha256:demo-$templateId',
    ),
    designator: designator,
    name: name,
    placement: RailPlacement(
      rackId: const Uuid('demo-rack'),
      ruIndex: ruIndex,
      face: face,
    ),
    meta: meta(),
  );

  final doc = RackDocument(
    id: const Uuid('demo-doc'),
    appVersion: '0.1.0',
    createdAt: now,
    modifiedAt: now,
    meta: meta(),
  );

  doc.racks[const Uuid('demo-rack')] = Rack(
    id: const Uuid('demo-rack'),
    name: 'Media Closet',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: meta(),
  );

  doc.templates['ups@1'] = snapshot(
    'ups',
    frontU: 2,
    displayName: 'Rack UPS 1500VA',
  );
  doc.templates['amp@1'] = snapshot(
    'amp',
    frontU: 2,
    displayName: '16-channel amplifier',
  );
  doc.templates['sw@1'] = snapshot(
    'sw',
    frontU: 1,
    displayName: '24-port PoE switch',
  );
  doc.templates['pp@1'] = snapshot(
    'pp',
    frontU: 0,
    rearU: 1,
    displayName: '24-port patch panel',
  );

  for (final d in [
    device(
      'dev-ups',
      designator: 'UPS-1',
      name: 'Main UPS',
      templateId: 'ups',
      ruIndex: 1,
    ),
    device(
      'dev-amp',
      designator: 'AMP-1',
      name: 'Living Room Amp',
      templateId: 'amp',
      ruIndex: 4,
    ),
    device(
      'dev-sw',
      designator: 'SW-1',
      name: 'Core Switch',
      templateId: 'sw',
      ruIndex: 7,
    ),
    device(
      'dev-pp',
      designator: 'PP-1',
      name: 'Patch Panel',
      templateId: 'pp',
      ruIndex: 9,
      face: Face.rear,
    ),
  ]) {
    doc.devices[d.id] = d;
  }

  // Embed every seeded catalog template as a version-1 TemplateSnapshot
  // (docs/09-roadmap.md M1 checklist #6) so the palette can place any of
  // them — a `buildPlaceFromCatalogCommand` call just resolves
  // `"$catalogId@1"` here rather than inserting a snapshot lazily on first
  // placement (TemplateSnapshot refcounting/eviction is AC-015, deferred
  // past M0/M1 per `AddDeviceCommand`'s own TODO).
  for (final entry in catalog.entries) {
    doc.templates[catalogTemplateKey(entry.key)] = TemplateSnapshot(
      templateId: TemplateId(entry.key),
      version: 1,
      contentHash: 'sha256:seed-${entry.key}',
      capturedAt: now,
      body: entry.value,
    );
  }

  return doc;
}

// ── chrome ─────────────────────────────────────────────────────────────────

/// Front/Rear segmented toggle (docs/04 §1's face segmented control; Both is
/// deferred with rear-mirroring, so this stage exposes the two faces only).
class _FaceToggle extends StatelessWidget {
  const _FaceToggle({required this.face, required this.onToggle});

  final Face face;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flip_to_front, size: 18),
            const SizedBox(width: 8),
            SegmentedButton<Face>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Face.front, label: Text('Front')),
                ButtonSegment(value: Face.rear, label: Text('Rear')),
              ],
              selected: {face},
              onSelectionChanged: (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small floating readout: live zoom percentage plus reset / fit controls.
class _ViewportHud extends StatelessWidget {
  const _ViewportHud({
    required this.viewport,
    required this.onReset,
    required this.onFit,
  });

  final ViewportController viewport;
  final VoidCallback onReset;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: viewport,
              builder: (context, _) => Text(
                '${(viewport.scale * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Fit the rack',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.fit_screen_outlined),
              onPressed: onFit,
            ),
            IconButton(
              tooltip: 'Reset view (100%)',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.restart_alt),
              onPressed: onReset,
            ),
          ],
        ),
      ),
    );
  }
}
