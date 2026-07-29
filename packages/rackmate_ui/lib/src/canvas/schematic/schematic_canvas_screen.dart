// rackmate_ui/src/canvas/schematic/schematic_canvas_screen.dart
//
// The Schematic tab: docs/05 §11's sheet, with §11.2's domain filter bar
// above it and §11.4's `Alt`-hover and focus over it.
//
// ═════════════════════════════════════════════════════════════════════
// THE SCREEN HAS NO `scene` PARAMETER, AND THAT IS THE FIX
// ═════════════════════════════════════════════════════════════════════
// The schematic canvas deleted at `b560a50` was handed its scene by
// `main.dart`, which passed a HARDCODED EMPTY `DiagramScene`
// (`fragments: {}`, `rackId: ''`). The document therefore never reached
// the canvas at all — and on an empty scene the code MANUFACTURED a fake
// symbol with dummy `Pin1`/`Pout1` ports, so the screen looked populated
// while showing nothing that was in any document. Twelve consecutive
// `fix:` commits never touched the call site.
//
// This screen takes a `DocumentController` and NOTHING ELSE that could
// carry a drawing. `buildSchematicScene(doc: _controller.doc, …)` runs
// HERE, over the live document, and the only way to reach the canvas is
// through it. There is no parameter a caller can get wrong, no empty-scene
// branch to fall into, and no code path anywhere in this package that
// manufactures a symbol — a symbol on a canvas that is in no document
// would be a fabrication (G4), which is the ruling `unbuilt_view.dart`'s
// header records and which survives the tab becoming real.
// `schematic_canvas_screen_test.dart`'s first test mounts this screen over
// a document and asserts the document's own designators are in the
// painted display list.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT THE `UnbuiltView` THAT STOOD HERE SAID, AND WHAT SURVIVES OF IT
// ═════════════════════════════════════════════════════════════════════
// The panel this screen replaces said: "Nothing here is derived from your
// document. No sheet is laid out, no symbol is placed on one, no wire is
// routed between two pins and no net label is drawn — and nothing in this
// build creates a connection, so a document edited here holds zero Links.
// The gap is the view, not the data."
//
// Four of those five clauses are now FALSE and the panel is gone rather
// than softened, on the same rule that retired the Schedule's: the one
// surface in the app whose purpose is accuracy about what exists must be
// the first thing to change when something starts existing.
//
// THE FIFTH CLAUSE IS STILL TRUE, and it is carried forward verbatim in
// meaning into [kNoLinksDetail] below: NOTHING IN THIS BUILD CREATES A
// CONNECTION. Drag-to-connect is a different M2 roadmap item (checklist
// item 3), and `apps/rackmate/test/unbuilt_copy_accuracy_test.dart` scans
// both UI packages and the app for a caller of `AddLinkCommand` — so that
// sentence is asserted against the code, not asserted by a comment.
//
// ═════════════════════════════════════════════════════════════════════
// THE EXCLUSIVITY RULE, AND WHY THIS SCREEN NEEDS NO ARBITER OF ITS OWN
// ═════════════════════════════════════════════════════════════════════
// `rack_canvas_screen.dart` carries a `_liveGesture` field because FOUR
// preview-then-commit interactions coexist there and two of them arrive
// through different pointer routes (a palette drag armed from a sibling
// widget and tracked through the global `pointerRouter`, versus a canvas
// drag delivered by `CanvasIntentDetector`). That file has been bitten
// three separate times by a second entry point re-initialising state a
// live interaction still owned.
//
// THIS SCREEN HAS EXACTLY ONE POINTER ROUTE — the detector's — and no
// preview-then-commit interaction at all: nothing here mutates the
// document. So the cross-route half of the rule has nothing to arbitrate,
// and `CanvasIntentDetector` enforces the rest structurally (a second
// canvas pointer never reaches `beginDrag`). That is stated rather than
// left silent, because "this screen has no exclusivity guard" and "this
// screen forgot its exclusivity guard" look identical from outside, and
// the second is the bug that recurred three times next door. The moment
// drag-to-connect lands here, this paragraph stops being true and the
// arbiter has to arrive with it.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT THIS SCREEN DELIBERATELY DOES NOT DO
// ═════════════════════════════════════════════════════════════════════
//  * CREATE, EDIT OR DELETE ANYTHING. No `Command` is constructed in this
//    file. M2's checklist item 3 (drag-to-connect, chain-draw, pinning on
//    manual move, `Tidy sheet`) is a separate item and is not smuggled in
//    behind a filter bar.
//  * GHOST FILTERED-OUT DOMAINS. §11.2 makes Ghost the default and Hide
//    the alternative; the ghost alpha is **VERIFY** in §6.6 and AC-058/D11
//    requires a measured value. See `schematic_filter.dart`'s header —
//    this is a flagged corpus conflict, not a quiet choice.
//  * DIM DEVICES WITH NO VISIBLE LINKS to 25%, or drop their pins to
//    ticks (§11.2's last bullet), or dim the unfocused subgraph to 10%
//    (§11.4). All three are recolourings of SYMBOL ops, and a recolour is
//    a rebuild of the very fragments M2-D publishes so they can be
//    replayed untouched. They want a palette-level mechanism, not a
//    per-frame op rewrite on the path §11.2 bans `saveLayer` from.
//  * ISOLATE (`Shift+F`). §11.4 requires the router to RE-RUN ON THE
//    SUBGRAPH, which is a second layout of a second graph. `F` is bound;
//    `Shift+F` is left unbound rather than bound to something weaker,
//    because a key that half-works is the thing this app's keymap ruling
//    exists to prevent.
//  * BIND `L`, `W`, `-`, `=`, `Ctrl+Shift+U` or `Ctrl+Shift+R`. Every one
//    of them needs a capability this stage does not build (a manual
//    drawn-mode override, wire creation, symbol collapse, pinning,
//    direction reversal). See `app_shell.dart`'s header: a partial keymap
//    reads as a whole one.

import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show PointerDeviceKind, PointerExitEvent, PointerHoverEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyEvent, LogicalKeyboardKey;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/canvas_intent.dart';
import 'package:rackmate_ui/src/canvas/grid_painter.dart';
import 'package:rackmate_ui/src/canvas/schematic/domain_filter_bar.dart';
import 'package:rackmate_ui/src/canvas/schematic/render_schematic_canvas.dart';
import 'package:rackmate_ui/src/canvas/schematic/schematic_filter.dart';
import 'package:rackmate_ui/src/canvas/schematic/schematic_paint_plan.dart';
import 'package:rackmate_ui/src/canvas/selection_controller.dart';
import 'package:rackmate_ui/src/canvas/viewport_controller.dart';
import 'package:rackmate_ui/src/keymap/keymap.dart';

/// The headline shown when the document draws symbols but holds no cable.
///
/// A STATEMENT ABOUT THE DOCUMENT, never about the user — the same rule
/// `kNoCablesHeadline` states for the Schedule. "You have not wired
/// anything" is false whenever the build offers no way to wire anything,
/// which is exactly the case docs/09 M1 singles out as a lie.
const String kNoLinksHeadline = 'This document holds no cables.';

/// Why the sheet shows symbols and no wires, and where the gap actually is.
///
/// This is the one clause of the retired `UnbuiltView` panel that is still
/// true (see the file header), restated for a tab that now draws. It is
/// checked against the code it describes: `unbuilt_copy_accuracy_test.dart`
/// scans both UI packages and the app for a caller of `AddLinkCommand` and
/// fails if one appears.
const String kNoLinksDetail =
    'Every symbol above is laid out from your document and every cable '
    'would render as a pair of net labels the moment one existed — the '
    'layout, the labels and the domain filter are built and running. What '
    'is missing is the drawing gesture: no surface in this build creates a '
    'Link, so there is nothing to label. The gap is the gesture, not the '
    'view.';

/// What the sheet says when no device in the document can carry a cable.
const String kNoSymbolsHeadline =
    'No device in this document can carry a cable.';

/// docs/05 §3: "A symbol is a body rectangle with a header band and pins on
/// its four edges." A device whose template declares no `PortDef` has no
/// pins, can hold no `Link`, and is furniture on a wiring drawing — so it
/// is not drawn, and this says so rather than leaving a blank sheet.
const String kNoSymbolsDetail =
    'A schematic symbol is its pins, so a device is drawn here only when '
    'its template declares at least one port. Blank panels, vents and '
    'shelves carry no cable and are counted below rather than drawn. Add a '
    'device with ports in the Rack tab and it appears here.';

/// docs/05 §11's sheet.
final class SchematicCanvasScreen extends StatefulWidget {
  const SchematicCanvasScreen({
    required this.measurer,
    required this.controller,
    super.key,
  });

  /// The shared `TextMeasurer` (CR-081), used to BUILD the scene and to
  /// paint it, so on-screen layout matches what the PDF backend would
  /// measure. The app injects one `PdfFontMeasurer`; `rackmate_ui` never
  /// constructs one.
  final TextMeasurer measurer;

  /// The document this sheet is a projection of.
  ///
  /// REQUIRED, and there is no `document` sibling and no demo seed. The
  /// rack screen carries both for historical reasons its own doc comments
  /// record; this screen was written after the app shell owned the
  /// document, so it has exactly one source and cannot be given a second.
  final DocumentController controller;

  @override
  State<SchematicCanvasScreen> createState() => _SchematicCanvasScreenState();
}

class _SchematicCanvasScreenState extends State<SchematicCanvasScreen> {
  /// Net pointer travel (screen px) below which a press is a click —
  /// docs/04 §3.1 step 1's "Nothing until 4 px of movement, so a click
  /// still means show details", compared in SCREEN space so the slop does
  /// not shrink with zoom.
  static const double _clickSlopPx = 4;

  final ViewportController _viewport = ViewportController();
  final GridCache _gridCache = GridCache();

  /// Selection is OBSERVED, never persisted (docs/03 §4.4) — the same
  /// controller the rack editor uses, so the two views mean the same thing
  /// by "selected".
  final SelectionController _selection = SelectionController();

  final FocusNode _canvasFocus = FocusNode(debugLabel: 'schematicCanvas');

  SchematicViewFilter _filter = const SchematicViewFilter();

  /// §11.4's `F`. Device ids, not `Uuid`s, because that is the key
  /// `RenderedNetLabel.deviceId` and `HitRegion.entityId` both use.
  Set<String> _focused = const <String>{};

  /// The symbol under an `Alt`-held cursor, or null. TRANSIENT BY
  /// CONSTRUCTION — §11.4: "No click, no mode, no state". It is cleared by
  /// the pointer leaving, by `Alt` coming up, and by any rebuild that finds
  /// `Alt` no longer down.
  String? _altHovered;

  /// The last pointer position IN SCENE SPACE, so releasing or pressing
  /// `Alt` over a stationary cursor can re-answer "what is under it".
  /// Without it, `Alt` would only take effect on the next mouse move.
  DPt? _lastScenePointer;

  /// Bumped by every epoch this sheet reads. The scene cache's key — see
  /// [_sceneFor].
  int _sceneEpoch = 0;

  SchematicScene? _scene;
  ({int epoch, SchematicPalette palette, SignalTheme theme})? _sceneKey;

  /// Whether the viewport has already been framed on this sheet.
  bool _framed = false;

  RackDocument get _doc => widget.controller.doc;

  @override
  void initState() {
    super.initState();
    // Every epoch the schematic reads, and no others. `structure` moves
    // devices and placements, `wires` moves Links/Services/Nets, `meta`
    // moves designators and names (which SIZE a symbol through §3's width
    // formula), `sheet` moves `SheetItem.pinned`/`position` (CR-068's
    // pinned layout), `style` moves the registries and the per-family
    // colour overrides. Missing any one of them would leave the sheet a
    // commit behind in a way no test that only edits devices could see.
    widget.controller.epochs.structure.addListener(_onDocumentChanged);
    widget.controller.epochs.wires.addListener(_onDocumentChanged);
    widget.controller.epochs.meta.addListener(_onDocumentChanged);
    widget.controller.epochs.sheet.addListener(_onDocumentChanged);
    widget.controller.epochs.style.addListener(_onDocumentChanged);
    _selection.addListener(_onSelectionChanged);
    // `Alt` is a MODIFIER, and Flutter delivers no hover event when only a
    // modifier changes. Without this hook, holding `Alt` over a symbol the
    // cursor was already on would do nothing until the mouse moved — which
    // reads as "Alt-hover is broken" rather than as "move the mouse".
    //
    // A RAW HANDLER, and the registration is the leak risk `rack_canvas_
    // screen.dart` names: it is removed in `dispose` on the one exit path
    // this screen has.
    HardwareKeyboard.instance.addHandler(_onRawKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onRawKey);
    widget.controller.epochs.structure.removeListener(_onDocumentChanged);
    widget.controller.epochs.wires.removeListener(_onDocumentChanged);
    widget.controller.epochs.meta.removeListener(_onDocumentChanged);
    widget.controller.epochs.sheet.removeListener(_onDocumentChanged);
    widget.controller.epochs.style.removeListener(_onDocumentChanged);
    _selection
      ..removeListener(_onSelectionChanged)
      ..dispose();
    _canvasFocus.dispose();
    _viewport.dispose();
    super.dispose();
  }

  void _onDocumentChanged() {
    if (!mounted) return;
    setState(() {
      _sceneEpoch++;
      // A FOCUS SCOPE OUTLIVES THE DEVICE IT NAMES otherwise. Deleting a
      // focused device would leave `F`'s scope pointing at an id no symbol
      // carries, and the HUD would keep announcing a hop count for a
      // device that is gone. Dropped rather than repaired: the user's
      // question was about that device.
      _focused = <String>{
        for (final id in _focused)
          if (_doc.devices.containsKey(Uuid(id))) id,
      };
    });
  }

  void _onSelectionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// `Alt` up or down over a stationary cursor — see [initState].
  ///
  /// Returns false always: this hook OBSERVES the modifier and must not
  /// consume a key. Returning true would swallow `Alt` from every other
  /// binding in the app, including `Ctrl+Alt+N`.
  bool _onRawKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.altLeft &&
        event.logicalKey != LogicalKeyboardKey.altRight) {
      return false;
    }
    _recomputeAltHover();
    return false;
  }

  // ── the scene ─────────────────────────────────────────────────────────

  /// The laid-out sheet, rebuilt only when something it reads has changed.
  ///
  /// CACHED, unlike the rack canvas's scene, and the difference is a
  /// measurement rather than a preference: `buildRackScene` covers one rack
  /// and a handful of devices, while this runs Sugiyama phases 0–3 plus the
  /// whole net-label layer over every device and every link in the
  /// document. It must not run again because a chip was clicked, a symbol
  /// was hovered or a pointer moved — and every one of those calls
  /// `setState`.
  ///
  /// The key is the epoch counter plus the palette and theme, because
  /// those are the only two non-document inputs `buildSchematicScene`
  /// takes. A theme change therefore relays out the sheet, which is
  /// correct: hue is resolved into the display list, not applied over it.
  SchematicScene _sceneFor(SchematicPalette palette, SignalTheme theme) {
    final key = (epoch: _sceneEpoch, palette: palette, theme: theme);
    final cached = _scene;
    if (cached != null && _sceneKey == key) return cached;
    final built = buildSchematicScene(
      doc: _doc,
      measurer: widget.measurer,
      palette: palette,
      netLabelStyle: NetLabelStyle(theme: theme),
    );
    _scene = built;
    _sceneKey = key;
    return built;
  }

  // ── input ─────────────────────────────────────────────────────────────

  /// The device under [scenePoint], or null.
  ///
  /// Walks `DiagramScene.hits` BACKWARDS, so the topmost region wins — the
  /// hit list is in the scene's own paint order, and a pin region sits
  /// after the body it belongs to. Both resolve to the same `entityId`
  /// (`HitRegion.partKey` is the pin's key, `null` for a body), so this
  /// answers "which device" for either, which is what both `Alt`-hover and
  /// selection ask.
  String? _deviceAt(SchematicScene scene, DPt scenePoint) {
    final hits = scene.scene.hits;
    for (var i = hits.length - 1; i >= 0; i--) {
      if (hits[i].contains(scenePoint)) return hits[i].entityId;
    }
    return null;
  }

  void _onHover(PointerHoverEvent event) {
    _lastScenePointer = _viewport.screenToScene(
      DPt(event.localPosition.dx, event.localPosition.dy),
    );
    _recomputeAltHover();
  }

  void _onExit(PointerExitEvent event) {
    _lastScenePointer = null;
    if (_altHovered != null) setState(() => _altHovered = null);
  }

  /// §11.4's transient focus, recomputed from the two things it depends on.
  ///
  /// `setState` ONLY WHEN THE ANSWER CHANGES. A hover fires at pointer
  /// rate; rebuilding the sheet on every one of them would relay out
  /// nothing (the scene is cached) but would rebuild the paint plan —
  /// including one `buildDrawnWireLayer` — sixty times a second for a
  /// picture that did not move. The same coarse-change discipline
  /// `rack_canvas_screen.dart` applies to its drag previews.
  void _recomputeAltHover() {
    if (!mounted) return;
    final scene = _scene;
    final point = _lastScenePointer;
    final next =
        (scene == null ||
            point == null ||
            !HardwareKeyboard.instance.isAltPressed)
        ? null
        : _deviceAt(scene, point);
    if (next == _altHovered) return;
    setState(() => _altHovered = next);
  }

  void _selectAt(DPt scenePoint) {
    final scene = _scene;
    if (scene == null) return;
    final hit = _deviceAt(scene, scenePoint);
    // A MODIFIER CHECK, NOT A DEVICE-KIND CHECK (AC-016 #23). docs/04 §3.5's
    // click model: plain click replaces, Ctrl/Cmd+click adds or subtracts
    // by current membership.
    final additive =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (hit == null) {
      if (!additive) _selection.clear();
      return;
    }
    final id = Uuid(hit);
    if (!additive) {
      _selection.apply(<Uuid>[id], SelectMode.replace);
      return;
    }
    _selection.apply(
      <Uuid>[id],
      _selection.contains(id) ? SelectMode.subtract : SelectMode.add,
    );
  }

  // ── keyboard (docs/05 §14) ────────────────────────────────────────────

  void _soloByIndex(int oneBased) {
    final order = schematicDomainOrder(_doc.registries);
    if (oneBased < 1 || oneBased > order.length) return;
    setState(() => _filter = _filter.solo(order[oneBased - 1]));
  }

  void _showAllDomains() => setState(() => _filter = _filter.showAll());

  /// §11.4's `F`: focus the selection's subgraph, or leave it if focused.
  ///
  /// "`F` again or `Esc` exits" — §11.4's own words, so the key is a
  /// toggle rather than a one-way door.
  void _toggleFocus() {
    if (_focused.isNotEmpty) {
      setState(() => _focused = const <String>{});
      return;
    }
    if (_selection.isEmpty) return;
    setState(() => _focused = <String>{for (final id in _selection.ids) id.v});
  }

  /// §11.4's `Esc`, and docs/04 §8's third limb ("clear selection").
  ///
  /// FOCUS FIRST, THEN THE SELECTION. A user in focus mode who presses
  /// `Esc` is leaving the mode; also clearing the selection in the same
  /// keystroke would take away the thing they were looking at, and the
  /// second `Esc` is free.
  void _onEscape() {
    if (_focused.isNotEmpty) {
      setState(() => _focused = const <String>{});
      return;
    }
    if (_selection.isNotEmpty) _selection.clear();
  }

  // ── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final signalTheme = theme.brightness == Brightness.dark
        ? SignalTheme.dark
        : SignalTheme.light;
    final palette = _schematicPalette(scheme);
    final scene = _sceneFor(palette, signalTheme);

    final scope = resolveDrawnScope(
      scene: scene,
      filter: _filter,
      altHoveredDeviceId: _altHovered,
      focusedDeviceIds: _focused,
      designatorOf: (id) => _doc.devices[Uuid(id)]?.designator ?? id,
    );
    final plan = buildSchematicPaintPlan(
      scene: scene,
      doc: _doc,
      filter: _filter,
      scope: scope,
      measurer: widget.measurer,
      palette: palette,
      groundArgb: _argbOfColor(scheme.surfaceContainerLowest),
    );

    // THE KEYS ARE DECLARED IN `keymap.dart`, NOT HERE. Eleven
    // `SingleActivator` literals stood in this map; they are eleven rows in
    // `kKeymap` under `KeyScope.schematic`, which is what lets the
    // generated table and the collision arbitration see them at all
    // (CR-101, M7's exit criterion). None of them carries a modifier, so
    // the macOS half of the extraction (debt D7) changes nothing here —
    // but the ARBITRATION half does, and it is what now holds two claims
    // this map used to make in a comment:
    //
    //   * "there is no `Ctrl+1` collision with the app's view switch,
    //     because `SingleActivator` matches modifiers exactly" — a bare
    //     `1` and a `primary+1` are different chords, and
    //     `KeymapConflictKind.shadowsGlobal` is what fails if a `primary`
    //     ever appears on one of these rows;
    //   * "`Shift+F` (Isolate) is deliberately absent, and `F` is unbound
    //     in the rack" — canon §1.10 principle (c), now held by
    //     `KeymapConflictKind.letterCollision` rather than by two file
    //     headers agreeing with each other.
    return Shortcuts(
      shortcuts: keymapShortcuts(KeyScope.schematic),
      child: Actions(
        actions: <Type, Action<Intent>>{
          SoloDomainIntent: CallbackAction<SoloDomainIntent>(
            onInvoke: (intent) {
              _soloByIndex(intent.index);
              return null;
            },
          ),
          ShowAllDomainsIntent: CallbackAction<ShowAllDomainsIntent>(
            onInvoke: (_) {
              _showAllDomains();
              return null;
            },
          ),
          FocusSelectionIntent: CallbackAction<FocusSelectionIntent>(
            onInvoke: (_) {
              _toggleFocus();
              return null;
            },
          ),
          SchematicCancelIntent: CallbackAction<SchematicCancelIntent>(
            onInvoke: (_) {
              _onEscape();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _canvasFocus,
          autofocus: true,
          child: Column(
            children: [
              DomainFilterBar(
                chips: _chips(scene, signalTheme),
                headline: scope?.headline,
                onSolo: (id) => setState(() => _filter = _filter.solo(id)),
                onToggle: (id) => setState(() => _filter = _filter.toggle(id)),
                onShowAll: _showAllDomains,
                onShowNone: () => setState(() => _filter = _filter.showNone()),
              ),
              const Divider(height: 1),
              Expanded(
                child: scene.symbols.isEmpty
                    ? const _EmptySheet(
                        headline: kNoSymbolsHeadline,
                        detail: kNoSymbolsDetail,
                      )
                    : _canvas(scheme, plan),
              ),
              const Divider(height: 1),
              _SchematicStatusStrip(
                scene: scene,
                plan: plan,
                deviceCount: _doc.devices.length,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _canvas(ColorScheme scheme, SchematicPaintPlan plan) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _frameOnce(plan, constraints.biggest);
        return ColoredBox(
          color: scheme.surface,
          child: MouseRegion(
            onHover: _onHover,
            onExit: _onExit,
            child: CanvasIntentDetector(
              viewport: _viewport,
              handler: _SchematicClickHandler(
                viewport: _viewport,
                slopPx: _clickSlopPx,
                onClick: _selectAt,
                requestFocus: _canvasFocus.requestFocus,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: GridPainter(
                      viewport: _viewport,
                      cache: _gridCache,
                      style: GridStyle(
                        minorColor: scheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                        majorColor: scheme.outline.withValues(alpha: 0.7),
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                  SchematicCanvasBody(
                    plan: plan,
                    viewport: _viewport,
                    measurer: widget.measurer,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Frames the sheet, once.
  ///
  /// FIT, unlike the rack canvas's pan-only seeding, and the difference is
  /// a documented convention rather than a taste: docs/04 §2.1 fixes "zoom
  /// 1.0 = 1U is 22px" for the elevation, so choosing a scale there would
  /// trade a stated constant for an invented one. The schematic has no such
  /// constant — it is drawn 1:1 physical (`schematic_scene.dart`'s scale
  /// anchor) and a whole-house sheet is metres wide, so opening at 1:1 puts
  /// the reader inside one symbol with no way to know which.
  ///
  /// Deferred to a post-frame callback: `ViewportController` is a
  /// `ChangeNotifier` and notifying during layout would rebuild its
  /// listeners mid-pass.
  void _frameOnce(SchematicPaintPlan plan, Size viewportSize) {
    if (_framed || viewportSize.isEmpty) return;
    if (plan.ground.width <= 0 || plan.ground.height <= 0) return;
    _framed = true;
    final box = Box.fromCorners(
      Pt(plan.ground.left.floor(), plan.ground.top.floor()),
      Pt(plan.ground.right.ceil(), plan.ground.bottom.ceil()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewport.fitToContent(box, viewportSize);
    });
  }

  List<DomainChipData> _chips(SchematicScene scene, SignalTheme theme) {
    final counts = linksByDomain(scene);
    final order = schematicDomainOrder(_doc.registries);
    final soloed = _filter.soloedDomain;
    return <DomainChipData>[
      for (var i = 0; i < order.length; i++)
        if (_doc.registries.signalDomains[order[i]] case final def?)
          DomainChipData(
            id: def.id,
            displayName: def.displayName,
            glyph: def.glyph,
            argb: _argbOfRgb(
              theme == SignalTheme.dark ? def.colorDark : def.color,
            ),
            linkCount: counts[def.id]?.length ?? 0,
            visible: _filter.shows(def.id),
            // A CHIP IS `drawn` ONLY WHEN NOTHING ELSE IS DRIVING THE
            // SHEET. `Alt`-hover and focus outrank a solo
            // (`resolveDrawnScope`'s precedence), so a chip that kept its
            // drawn outline under an active hover would be claiming
            // authorship of wires it did not draw.
            drawn: def.id == soloed && _altHovered == null && _focused.isEmpty,
            index: i + 1,
          ),
    ];
  }
}

// THE FOUR `Intent`s THIS SCREEN BINDS ARE IN `keymap.dart` NOW. They used
// to be declared here and to carry the note "Private: they are this view's
// vocabulary and nothing outside it may dispatch them", which was a good
// rule for one file and was precisely what CR-101 rules against for the
// application: "one arbitrated table, generated from one `Intent`
// registry". A vocabulary no registry can name is a vocabulary no table
// can print.
//
// Nothing outside this screen dispatches them today, and nothing has to:
// an `Actions` map is keyed by intent TYPE and this is still the only
// screen that installs one for these four. What changed is that the
// arbitration can now SEE that `Esc` means the same thing here as it does
// in the rack and in the three dialogs — which is canon §1.10's principle
// (b), and was unverifiable while each view kept its own private copy.

/// Turns a pointer press-and-release into a click, and nothing else.
///
/// THE HANDLER EXISTS SO THAT A DRAG DOES NOT PAN. `CanvasIntentDetector`
/// pans on a primary drag when no handler is supplied; on this sheet a
/// primary drag is reserved for the marquee, exactly as it is on the rack
/// canvas, and panning is on scroll, trackpad and middle-mouse — all three
/// of which the detector routes regardless of this handler.
///
/// AC-016 #23: nothing here reads [PointerDeviceKind]. `beginDrag` is
/// GIVEN the source kinds and deliberately ignores them; the slop is the
/// same 4 px for a mouse, a finger and a stylus, because a click means the
/// same thing however it was made.
final class _SchematicClickHandler implements CanvasIntentHandler {
  _SchematicClickHandler({
    required this.viewport,
    required this.slopPx,
    required this.onClick,
    required this.requestFocus,
  });

  final ViewportController viewport;
  final double slopPx;
  final void Function(DPt scenePoint) onClick;
  final VoidCallback requestFocus;

  DPt? _start;
  double _travelPx = 0;

  @override
  void beginDrag(DPt sceneStart, Set<PointerDeviceKind> sourceKinds) {
    // The keyboard bindings above are focus-scoped, so a click on the
    // sheet has to bring focus with it or `1`–`8` would work only until
    // the user touched a filter-bar button.
    requestFocus();
    _start = sceneStart;
    _travelPx = 0;
  }

  @override
  void updateDrag(DPt sceneCurrent, DPt sceneDelta) {
    // Accumulated in SCREEN pixels — `slopPx` is a screen figure, and
    // comparing it against a scene delta would make the threshold 20×
    // stricter at 20× zoom.
    final scale = viewport.scale;
    _travelPx +=
        math.sqrt(sceneDelta.x * sceneDelta.x + sceneDelta.y * sceneDelta.y) *
        scale;
  }

  @override
  void commitDrag(DPt sceneEnd) {
    final start = _start;
    _start = null;
    if (start == null || _travelPx > slopPx) return;
    onClick(sceneEnd);
  }

  @override
  void cancel() {
    _start = null;
    _travelPx = 0;
  }
}

/// The honest-absence panel, shared by the two empty sheets.
final class _EmptySheet extends StatelessWidget {
  const _EmptySheet({required this.headline, required this.detail});

  final String headline;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything the sheet knows it is not showing, said out loud.
///
/// ═══════════════════════════════════════════════════════════════════
/// THIS STRIP IS THE G4 RULE APPLIED TO A DRAWING
/// ═══════════════════════════════════════════════════════════════════
/// M2-C and M2-D count what they cannot draw instead of dropping it —
/// `unsymbolisedDeviceIds`, `unlabelledLinkIds`, `unnamedLinkIds`,
/// `underGlyphedFamilyIds` — and every one of those counts exists so that
/// a caller can SAY so. A schematic that silently omits a device is
/// indistinguishable from one that lost it, and this is where the
/// difference becomes visible to the person looking at the sheet.
///
/// [SchematicScene.underGlyphedFamilyIds] is the one that would be easiest
/// to hide, so it is stated in full: the glyph channel is half-dead
/// because no model field selects `glyph` from `glyphAlt`, DR-010 §11.10.4
/// keeps the fix out of scope, and until it lands those families render a
/// shape this renderer cannot verify.
final class _SchematicStatusStrip extends StatelessWidget {
  const _SchematicStatusStrip({
    required this.scene,
    required this.plan,
    required this.deviceCount,
  });

  final SchematicScene scene;
  final SchematicPaintPlan plan;
  final int deviceCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // BUILT WITH `add`, NOT AS A LIST LITERAL, only because several of
    // these sentences are longer than a line and adjacent string literals
    // inside a list read as a missing comma (`no_adjacent_strings_in_list`
    // exists for exactly that confusion).
    final drawn = scene.symbols.length;
    final notes = <String>['$drawn of $deviceCount devices drawn'];
    if (scene.unsymbolisedDeviceIds.isNotEmpty) {
      notes.add(
        '${scene.unsymbolisedDeviceIds.length} without ports, so without '
        'a symbol',
      );
    }
    if (scene.unlabelledLinkIds.isNotEmpty) {
      notes.add('${scene.unlabelledLinkIds.length} cables with no drawn end');
    }
    if (scene.unnamedLinkIds.isNotEmpty) {
      notes.add('${scene.unnamedLinkIds.length} cables with no net name');
    }
    if (scene.underGlyphedFamilyIds.isNotEmpty) {
      notes.add(
        '${scene.underGlyphedFamilyIds.length} families drawn with an '
        'unverified glyph (DR-010 §11.10.4)',
      );
    }
    if (plan.unroutableLinkIds.isNotEmpty) {
      notes.add(
        '${plan.unroutableLinkIds.length} cables in scope could not be routed',
      );
    }
    if (plan.hiddenDomainRuns > 0) {
      notes.add('${plan.hiddenDomainRuns} domains hidden by the filter');
    }

    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notes.join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (scene.netLabels.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '$kNoLinksHeadline $kNoLinksDetail',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The theme-derived symbol palette.
///
/// `SchematicPalette` is packed ARGB and never a Flutter `Color`, which is
/// what keeps every piece of geometry in `rackmate_core` where the PDF
/// backend can reach it. This is the one place the two regimes meet.
SchematicPalette _schematicPalette(ColorScheme scheme) => SchematicPalette(
  headerFill: _argbOfColor(scheme.surfaceContainerHighest),
  headerRule: _argbOfColor(scheme.outlineVariant),
  bodyFill: _argbOfColor(scheme.surface),
  bodyStroke: _argbOfColor(scheme.onSurfaceVariant),
  portStroke: _argbOfColor(scheme.onSurfaceVariant),
  portFill: _argbOfColor(scheme.surface),
  designator: _argbOfColor(scheme.onSurface),
  name: _argbOfColor(scheme.onSurfaceVariant),
  portLabel: _argbOfColor(scheme.onSurfaceVariant),
  netLabelText: _argbOfColor(scheme.onSurface),
);

int _argbOfColor(Color c) =>
    (_channel(c.a) << 24) |
    (_channel(c.r) << 16) |
    (_channel(c.g) << 8) |
    _channel(c.b);

int _channel(double v) => (v * 255).round().clamp(0, 255);

/// `Rgb` → packed 0xAARRGGBB, the convention every `Fill`/`Stroke` in
/// `draw/` uses. The same three lines `signal_style.dart` keeps private;
/// duplicated rather than exported because exporting it would put a colour
/// conversion in the public surface of a package whose whole discipline is
/// that colour arrives already resolved.
int _argbOfRgb(Rgb c) => (c.a << 24) | (c.r << 16) | (c.g << 8) | c.b;
