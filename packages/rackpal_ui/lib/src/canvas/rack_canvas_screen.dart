import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        LogicalKeyboardKey,
        SystemMouseCursors;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/canvas_intent.dart';
import 'package:rackpal_ui/src/canvas/compaction_preview_bar.dart';
import 'package:rackpal_ui/src/canvas/compaction_preview_controller.dart';
import 'package:rackpal_ui/src/canvas/device_doors_menu.dart';
import 'package:rackpal_ui/src/canvas/drag_preview_controller.dart';
import 'package:rackpal_ui/src/canvas/editing_overlay_painter.dart';
import 'package:rackpal_ui/src/canvas/grid_painter.dart';
import 'package:rackpal_ui/src/canvas/insertion_caret.dart';
import 'package:rackpal_ui/src/canvas/marquee_controller.dart';
import 'package:rackpal_ui/src/canvas/port_chip.dart';
import 'package:rackpal_ui/src/canvas/rack_header_bar.dart';
import 'package:rackpal_ui/src/canvas/rack_metrics_row.dart';
import 'package:rackpal_ui/src/canvas/render_device_box.dart';
import 'package:rackpal_ui/src/canvas/render_rack_canvas.dart';
import 'package:rackpal_ui/src/canvas/resize_preview_controller.dart';
import 'package:rackpal_ui/src/canvas/schematic/schematic_reveal.dart';
import 'package:rackpal_ui/src/canvas/selection_controller.dart';
import 'package:rackpal_ui/src/canvas/shake_animation.dart';
import 'package:rackpal_ui/src/canvas/staging_bin_overlay.dart';
import 'package:rackpal_ui/src/canvas/staging_bin_strip.dart';
import 'package:rackpal_ui/src/canvas/status_message_controller.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';
import 'package:rackpal_ui/src/canvas/viewport_hud.dart';
import 'package:rackpal_ui/src/inspector/add_zero_u_channel_dialog.dart'
    show zeroUChannelLabel;
import 'package:rackpal_ui/src/inspector/delete_device_dialog.dart';
import 'package:rackpal_ui/src/inspector/inspector_panel.dart';
import 'package:rackpal_ui/src/inspector/new_rack_dialog.dart';
import 'package:rackpal_ui/src/inspector/shrink_rack_dialog.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart';
import 'package:rackpal_ui/src/shell/no_racks_view.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';
import 'package:rackpal_ui/src/validation/acknowledge_finding_dialog.dart';
import 'package:rackpal_ui/src/validation/add_outlets_choice_dialog.dart';
import 'package:rackpal_ui/src/validation/validation_drawer.dart';

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
/// Breathing room, in screen pixels, between the rack and the edge of the
/// canvas column — used both when the viewport is first seeded and when the
/// caret is scrolled back into view, so a caret that has just been chased
/// onto the screen does not sit flush against the edge it came in from.
const double _kViewportMargin = 24;

/// The band of canvas the floating chrome owns, in screen pixels: the zoom
/// HUD, the face toggle and the header row are all pinned at `top: 12` and
/// stand about 60px tall.
///
/// THE OPENING VIEW FRAMES BELOW THIS, and `#710` is why the constant
/// exists. A rack centred in the RAW canvas puts its top edge under that
/// chrome, and docs/04 §4.1's drag-to-resize is an 8px grab band centred on
/// exactly that edge — so the gesture became unreachable, which nine widget
/// cases reported as soon as the framing changed.
const double _kTopChromeInset = 84;

class RackCanvasScreen extends StatefulWidget {
  const RackCanvasScreen({
    required this.measurer,
    this.clock = const SystemClock(),
    this.document,
    this.controller,
    this.paletteSearchFocus,
    this.paletteDragRow,
    this.onRevealInSchematic,
    this.onEditTemplate,
    this.presets,
    this.onSaveAsPreset,
    this.reveal,
    super.key,
  });

  /// A device or rack to show, parked by the shell's `F8` (DR-193
  /// §11.192).
  ///
  /// A PENDING REQUEST RATHER THAN A CALLBACK, for `RevealController`'s
  /// own reason: this screen is a page of a `TabBarView` and may not be
  /// built at the moment the key is pressed. A device switches the rack
  /// on screen to its own before it is selected; a rack is switched to and
  /// its settings opened. Null is legal and is what every widget test
  /// that builds this screen alone supplies.
  final RevealController? reveal;

  /// The palette's search field, LENT by `PaletteHost` (`#885`, DR-165
  /// §11.164.3).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THIS SCREEN NO LONGER OWNS A PALETTE, AND THAT IS THE WHOLE TICKET
  /// ═══════════════════════════════════════════════════════════════════
  /// It owned the only `DevicePalettePanel` in the tree, along with the
  /// row list, its memo, its index, the search field and three
  /// parameters (`libraries`, `unreadableLibraries`, `favourites`) that
  /// existed solely to feed it. All of that is `PaletteHost`'s, so the
  /// Plan view can place a device through the same column: docs/15 §6's
  /// first gesture row had a command and a public `armPaletteDrag` and
  /// no palette on screen to start one.
  ///
  /// **WHAT STAYS IS THE CARET'S RULE**, which is this canvas's own.
  /// `_recomputeCaret` counts the palette filter as canvas focus,
  /// because arming a placement from the search box is a placement
  /// gesture and the caret must stay lit across the hand-off. Reading
  /// `.hasFocus` off a borrowed node keeps that rule in one place; a
  /// notifier reporting focus upward plus a copy of the rule in the host
  /// would be two things that can disagree about one fact.
  ///
  /// **NULL IS LEGAL AND MEANS NO PALETTE**, which is what a render test
  /// or a screenshot harness mounts. The caret then activates on canvas
  /// focus alone, which is the truth in that tree.
  final FocusNode? paletteSearchFocus;

  /// Which palette row this screen is dragging out, WRITTEN for the host
  /// (`#885`, DR-165).
  ///
  /// **INJECTED RATHER THAN OWNED**, for the same reason the focus node
  /// is borrowed: `PaletteHost` needs it while it builds and this screen
  /// is its child, so a notifier created here would be one frame late for
  /// the whole gesture. It replaces a field, a hand-written equality
  /// compare and a screen-wide `setState`; `ValueNotifier` already
  /// refuses to fire on an equal value, so the coarse filter this needed
  /// is the type rather than the code.
  final ValueNotifier<String?>? paletteDragRow;

  /// The shared `TextMeasurer` (CR-081) used to build the scene AND to paint
  /// it, so on-screen layout matches what the PDF backend would measure. The
  /// app injects one `PdfFontMeasurer`; `rackpal_ui` never constructs one
  /// (it must not depend on `package:pdf`).
  final TextMeasurer measurer;

  /// Injected into this screen's `DocumentController`, mirroring
  /// `DocumentController`'s own `Clock` constructor parameter (docs/03
  /// §5.4: "do not call DateTime.now() directly"). Defaults to the real
  /// `SystemClock()` for production; tests inject a `FixedClock` (or a
  /// small mutable fake) to deterministically exercise the 400ms
  /// arrow-key-nudge merge window without a real sleep.
  final Clock clock;

  /// The document to edit, instead of the built-in demo seed. TESTS ONLY,
  /// and a sibling of [clock] for exactly the same reason that one exists:
  /// some behaviour is only reachable from a document shape the seed cannot
  /// express, and faking it is better than not testing it.
  ///
  /// The case that forced it is §4.1's real-time shrink hatch. Its truthfulness
  /// depends on occupants `boltedOccupantsOnFace` cannot model — a 0U-channel
  /// device, or a rail device whose `templates['<id>@<version>']` snapshot is
  /// missing (see core's `DoomedKind`). Both are "reachable by loading a file
  /// and none by in-app authoring today", so no sequence of gestures against
  /// the demo seed can produce one, and a hatch test without one cannot fail.
  @visibleForTesting
  final RackDocument? document;

  /// The `DocumentController` this screen edits through, when something
  /// ABOVE it owns the document.
  ///
  /// WHY THIS EXISTS. Until the persistence layer landed, the screen was
  /// the only thing in the app that had a document, so it built its own
  /// controller over a demo seed. Save, autosave, the dirty marker in the
  /// window title and the close-while-dirty prompt are all properties of
  /// THE DOCUMENT, not of one tab, so they belong to the app shell — and
  /// the shell can only own them if it owns the controller.
  ///
  /// Null keeps the previous behaviour exactly: the screen builds its own
  /// controller over [document] or the demo seed. Every existing test and
  /// the whole `rackpal_ui` suite therefore stay untouched.
  ///
  /// REPLACING THE DOCUMENT IS A NEW STATE, not a rebuild: [clock] and the
  /// controller are read into `late final` fields, and the rack, geometry
  /// and scene caches are all derived from the document identity. The app
  /// passes a `ValueKey` over the controller so Ctrl+N / Ctrl+O construct
  /// a fresh `State` rather than leaving stale derived data behind.
  final DocumentController? controller;

  /// CR-105's signpost, taken by whoever owns the view strip: "clicking it
  /// switches to the schematic with that device selected."
  ///
  /// ══════════════════════════════════════════════════════════════════
  /// NULL SUPPRESSES THE CHIP ENTIRELY, AND THAT IS THE HONEST DEFAULT
  /// ══════════════════════════════════════════════════════════════════
  /// This screen cannot switch tabs; only the shell can. A chip drawn
  /// without a listener would be a control that answers a click by doing
  /// nothing — the exact failure mode `unbuilt_view.dart` and the
  /// Schedule's retired panel were both written against. So a host that
  /// has nowhere to send the user gets no signpost, which is true rather
  /// than merely quiet.
  ///
  /// It is also why the chip is not simply "information about port
  /// occupancy": CR-105 defines it as the affordance, and the count is
  /// what the affordance is labelled with.
  final void Function(Uuid deviceId)? onRevealInSchematic;

  /// Door 2 (CR-054, DR-099 §11.98): open this template in the Device
  /// Manager for editing, which forks `version + 1` on save.
  ///
  /// OPTIONAL, because the shell owns the six-view stack and the Device
  /// Manager's single draft, and this screen is mounted bare in widget
  /// tests. Null means the row refuses out loud rather than doing nothing.
  final void Function(TemplateId templateId)? onEditTemplate;

  /// What this screen's Preset dropdown and New rack dialog list: the seeded
  /// presets you have not hidden, then yours (DR-176 §11.175.2).
  ///
  /// READ ON EVERY BUILD, NOT CAPTURED, because a preset saved from this
  /// screen's own inspector has to reach this screen's own dropdown: the
  /// shell saves it and rebuilds this widget with the new map. Null means
  /// the seeded presets alone, which is every widget test that mounts this
  /// screen bare.
  final Map<String, RackPreset>? presets;

  /// Save as preset... (DR-176 §11.175.2), handed the rack the inspector
  /// shows. NULL HIDES THE BUTTON, for [onRevealInSchematic]'s reason: a
  /// host with nowhere to keep a preset, whether a widget test or a
  /// degraded session, gets no control that would answer by doing nothing.
  final ValueChanged<Rack>? onSaveAsPreset;

  @override
  State<RackCanvasScreen> createState() => RackCanvasScreenState();
}

class RackCanvasScreenState extends State<RackCanvasScreen>
    with TickerProviderStateMixin {
  /// Net pointer travel (screen px) below which a drag is treated as a click
  /// (docs/04 §3.1 step 1: "Nothing until 4 px of movement, so a click still
  /// means show details"). Compared in screen space so the slop does not
  /// shrink/grow with zoom.
  static const double _clickSlopPx = 4;

  /// docs/04 §4.1's grab band for the drag-the-top-edge gesture: "8 px
  /// band". SCREEN pixels, like [_clickSlopPx] — divided by the viewport
  /// scale before it is compared in scene space, exactly as
  /// `EditingOverlayPainter` compensates its own nominal px strokes, so the
  /// band stays 8 physical pixels at 0.2x and at 4x rather than becoming
  /// unusably thin or swallowing the whole top U.
  static const double _topEdgeBandPx = 8;

  final ViewportController _viewport = ViewportController();
  final GridCache _gridCache = GridCache();

  /// The observable selection (docs/03 §4.4) — UI-owned, never persisted.
  final SelectionController _selection = SelectionController();

  /// Focus for the canvas so its Shortcuts/Actions receive Del/undo/redo.
  final FocusNode _canvasFocus = FocusNode(debugLabel: 'rackCanvas');

  /// The insertion caret (docs/04 §3.4) — UI-owned, observed, sibling to
  /// [_selection] in every respect (see insertion_caret.dart's header).
  final CaretController _caret = CaretController();

  /// Drives the blocked-nudge shake (docs/04 §3.4). Needs `this` as its
  /// `TickerProvider`, hence `TickerProviderStateMixin` above.
  late final ShakeController _shake = ShakeController(vsync: this);

  /// Transient status-line text + `SemanticsService.sendAnnouncement` for
  /// nudge-blocked / placement-confirmed feedback (docs/04 §3.4's "never
  /// silently stops").
  late final StatusMessageController _status = StatusMessageController(
    view: () => mounted ? View.of(context) : null,
  );

  /// The drag-from-palette-to-rails state machine (docs/04 §3.1). See
  /// drag_preview_controller.dart's header and the "palette drag" section
  /// below for the full arm/track/commit mechanism.
  final DragPreviewController _paletteDrag = DragPreviewController();

  /// The move-a-placed-device state machine (docs/04 §3.3) — the SAME
  /// controller type as [_paletteDrag], driving the SAME painter through
  /// the SAME evaluation function, because §3.3 step 3 is literally "Same
  /// checks and same blocked rendering as §3.1".
  ///
  /// A SECOND INSTANCE rather than one shared between the gestures: the
  /// two are armed from different places (a sibling palette row vs. a hit
  /// inside the canvas) and tracked through different plumbing (the global
  /// `pointerRouter` vs. `CanvasIntentDetector`'s own `Listener`), so two
  /// simultaneous pointers — one on a palette row, one on a placed device
  /// — are physically possible on a touch device. One shared instance
  /// would let each clobber the other's live evaluation mid-flight;
  /// separate instances make that structurally impossible, and cost only
  /// the painter checking two sources instead of one (at most one can ever
  /// report `isShowingGhost` per frame — see `EditingOverlayPainter`'s own
  /// `_activeDrag`).
  final DragPreviewController _moveDrag = DragPreviewController();

  /// docs/04 §3.6's compaction preview — the THIRD preview-then-commit
  /// interaction on this screen, and deliberately not a third
  /// `DragPreviewController` (see compaction_preview_controller.dart's
  /// header for why the shapes genuinely differ).
  final CompactionPreviewController _compaction = CompactionPreviewController();

  /// True only for the instant `_applyCompaction` is inside its
  /// `transact`. The stale-plan guard below fires on ANY document sequence
  /// bump, and an apply is itself a bump — without this latch the preview
  /// would report its own successful application as a concurrent edit that
  /// invalidated it.
  bool _applyingCompaction = false;

  /// docs/04 §4.1's drag-the-top-edge preview — the THIRD preview-then-commit
  /// interaction on this screen after the two drags and the compaction, and
  /// deliberately its own controller type (see
  /// resize_preview_controller.dart's header).
  final ResizePreviewController _resize = ResizePreviewController();

  /// True for the whole life of one top-edge drag: set in `_onBeginDrag`
  /// when the grab lands in the 8px band, cleared in `_resetDrag`. It is
  /// what makes the resize and the select/move gestures mutually exclusive
  /// AT THE SOURCE rather than by the two handlers each checking a condition
  /// the other might disagree about.
  bool _resizeDrag = false;

  /// The move drag's screen-space chip has a resize sibling: the "24U (+3)"
  /// readout that follows the cursor (§4.1). Same `OverlayEntry` lifecycle,
  /// same reason (it is screen-space text tracking a global pointer
  /// position, so it cannot live in the scene-space painter).
  OverlayEntry? _resizeOverlayEntry;

  /// THE MODAL-STORM LATCH (docs/04 §4.1 leaves this problem unaddressed).
  /// A held stepper ratcheting down through occupied territory, or a drag
  /// that commits while a previous modal is still closing, must not open one
  /// modal per event. `_requestHeight` refuses to open a second one while
  /// this is set, and the header stepper's hold-repeat halts on the same
  /// signal — the repeat stopping IS the feedback, and the modal is already
  /// on screen, so nothing about it is silent.
  bool _shrinkDialogOpen = false;

  /// Which POINTER-DRIVEN gesture currently owns the canvas, or null when
  /// none does. THE one piece of state behind this screen's exclusivity
  /// rule — see the "the exclusivity rule, in one place" section below for
  /// why it is one field consulted by every entry point rather than a
  /// condition each entry point re-derives.
  _PointerGesture? _liveGesture;

  /// Which of the two things the 320px inspector column shows (docs/04 §4's
  /// "REPLACES the Selection section" — see inspector_panel.dart's header
  /// for how that is implemented given there was no Selection section).
  InspectorTarget _inspectorTarget = InspectorTarget.selection;

  /// Focused by `Ctrl+Alt+U` so the keyboard entry point lands on the
  /// inspector's first field rather than nowhere.
  final FocusNode _inspectorFirstFieldFocus = FocusNode(
    debugLabel: 'inspectorFirstField',
  );

  /// docs/04 §4's seeded rack presets, built once (`buildRackPresets()`
  /// returns a fresh map per call by contract, so a caller cannot mutate a
  /// shared singleton). Used only when the host passes no presets.
  late final Map<String, RackPreset> _seedPresets = buildRackPresets();

  /// What every Preset surface on this screen lists. See
  /// [RackCanvasScreen.presets] on why this is read, never captured.
  Map<String, RackPreset> get _presets => widget.presets ?? _seedPresets;

  /// The `CanvasIntentDetector`'s own `RenderBox`, looked up on every
  /// palette-drag pointer move to test "is the pointer inside the canvas
  /// widget" and to project a global pointer position into scene space —
  /// see `_handlePaletteDragMove`. A `GlobalKey` (not a field cached from
  /// `build`) because the render object can be recreated across rebuilds;
  /// every use null-checks defensively (a mid-drag resize/hot-reload
  /// degrades to "outside canvas" rather than throwing — see this stage's
  /// final report's OPEN RISKS).
  final GlobalKey _canvasBoxKey = GlobalKey(debugLabel: 'rackCanvasBox');

  /// The pointer id currently armed/tracked for a palette drag (docs/04
  /// §3.1), or null. Tracked here (not inside [DragPreviewController],
  /// which holds only UI-observable STATE, not plumbing) so the same
  /// pointer id can be unsubscribed from `GestureBinding`'s router on
  /// every exit path (commit, blocked no-op, Esc cancel, pointer-cancel,
  /// `dispose`).
  int? _armPointer;
  Offset _armGlobalStart = Offset.zero;

  /// The pending 1.2s "reason chip persists" timer after a blocked
  /// release (docs/04 §3.1 step 5) — cancelled/replaced defensively so a
  /// second blocked drag started within the window can't have its own
  /// linger cut short by the first one's leftover timer.
  Timer? _blockedReleaseTimer;

  /// The floating cursor-card / RU-range-chip / reason-chip widgets
  /// (docs/04 §3.1 steps 2/4/5) — screen-space, so `Overlay`, not
  /// `EditingOverlayPainter` (which is scene-space and owns the ghost/
  /// snap-line/hatch instead). Inserted on lift, removed on every drag-end
  /// path.
  OverlayEntry? _paletteDragOverlayEntry;

  /// Staging Bin overlay entry — shown when a palette drag exits canvas bounds,
  /// indicating where items will be placed (in the staging bin).
  OverlayEntry? _stagingBinOverlayEntry;

  /// The move-drag's own 1.2s blocked-release timer and screen-space chip
  /// overlay — siblings of [_blockedReleaseTimer]/[_paletteDragOverlayEntry]
  /// with identical lifecycles, kept SEPARATE for the same reason
  /// [_moveDrag] itself is (see its doc comment): two concurrent pointers
  /// must not share one timer slot or one `OverlayEntry`.
  Timer? _moveBlockedReleaseTimer;
  OverlayEntry? _moveDragOverlayEntry;

  // Coarse (non-per-frame) change tracking for `_paletteDrag`, so a
  // Screen-level `setState` (needed only to re-render the palette's
  // dimmed row, since `draggingCatalogId` is an ordinary constructor
  // argument rebuilt through `build()`) fires on a PHASE transition only —
  // never on the high-frequency per-move scene-cursor/evaluation updates,
  // which `EditingOverlayPainter`/the overlay widgets read by listening to
  // `_paletteDrag` directly (the same repaint-not-rebuild precedent
  // `ShakeController`/`RenderDeviceBox` already established).
  bool _lastPaletteDragInProgress = false;

  /// The row the live palette drag was armed with (`#885`).
  ///
  /// `DragPreviewController.subjectId` still carries the `rowKey`,
  /// because that is what the palette matches to dim a row; this is the
  /// same drag's ROW, kept so the commit does not have to resolve a key
  /// against a list this screen no longer owns.
  PlaceableTemplate? _armedPaletteRow;

  /// The staged device a Staging Bin chip drag was armed with, when the
  /// drag came from the bin rather than the palette (`#964`). Exactly one
  /// of this and [_armedPaletteRow] is set by an arm.
  Uuid? _armedStagedId;

  /// The same coarse filter for `_moveDrag`: the id of the device that
  /// should currently paint at 30% opacity in place (docs/04 §3.3 step 1),
  /// or null. A `setState` fires only when this VALUE changes — i.e. once
  /// when a move-drag crosses the 4px threshold and once when it ends —
  /// never on the per-frame evaluation updates, which reach
  /// `EditingOverlayPainter` by it listening to `_moveDrag` directly.
  String? _lastMoveDragSourceId;

  /// The seeded catalog (docs/09-roadmap.md M1 checklist #6,
  /// docs/catalog/seed-devices.md): 30 rack-side archetypes + 19 field
  /// devices, embedded into `_doc.templates` at document construction
  /// (see `_buildDemoDocument`).
  ///
  /// **SEED DATA FOR A DEMO DOCUMENT, AND NOTHING ELSE NOW.** It was also
  /// what the palette listed, which is what made a template authored in
  /// the Device Builder unplaceable: it saved into the document and the
  /// palette was reading a constant beside it (DR-077 §11.76.1, docs/12
  /// §5.3.8). The palette reads `PaletteHost`'s own memo since `#885`; a
  /// body needed for a message or a gesture is resolved out of the
  /// document.
  late final Map<String, TemplateBody> _catalog = buildSeedCatalog();

  /// What the palette lists: the DOCUMENT's own shelf, newest version of
  /// each id, remembered until the document moves.
  ///
  /// `buildPlaceableTemplates` is O(templates) and the palette rebuilds
  /// on every drag phase, hover and status message, so this is
  /// `ScheduleScreen`'s memo used for `ScheduleScreen`'s reason. This
  /// screen qualifies for it: it owns the `DocumentController` that
  /// maintains `stateId`, so a save moves the key and the palette shows
  /// the new template without a reopen.
  ///
  /// **THE ROW LIST, ITS MEMO AND ITS INDEX MOVED TO `PaletteHost`**
  /// (`#885`, DR-165 §11.164.2), along with the `rowKey` lookup that
  /// resolved every palette callback. This screen is handed a
  /// `PlaceableTemplate` now, so the string that could name the wrong
  /// thing never reaches it.

  // Four hand-built demo devices (see _buildDemoDocument) still seed the
  // INITIAL rack contents — kept for continuity with earlier stages rather
  // than deleted, per this stage's task brief ("existing demo devices can
  // stay… your call"). The catalog above is what the palette adds FROM.
  //
  // Wrapped in the REAL DocumentController — THE one mutation entry point
  // (docs/03 §5.4). Every move/delete/undo/redo/place below runs through it.
  late final DocumentController _controller =
      widget.controller ??
      DocumentController(
        widget.document ?? buildDemoRackDocument(catalog: _catalog),
        clock: widget.clock,
      );
  RackDocument get _doc => _controller.doc;

  /// WHICH rack this canvas is editing — one at a time, deliberately.
  ///
  /// This was `late final Rack _rack = _doc.racks.values.first`, a field
  /// that was correct for exactly as long as no surface could create a
  /// second rack. `AddRackCommand` (docs/04 §9's New-rack dialog, wired to
  /// `Ctrl+Alt+N` below) makes a second rack reachable, and a canvas pinned
  /// to `values.first` would have answered that by drawing the OLD rack —
  /// a Create button whose result is invisible, which is worse than no
  /// button at all.
  ///
  /// ONE RACK AT A TIME IS THE SCOPE, AND IT IS NOT THE SPEC'S. docs/04 §8
  /// binds `←`/`→` to "move selection to the adjacent rack" and §9 has
  /// `Tab` moving "between racks", both of which presuppose a canvas that
  /// LAYS OUT several racks side by side. That layout does not exist
  /// (docs/12-milestone-board.md and docs/m1-implementation-log.md both
  /// record multi-rack layout as unbuilt) and building it is not what the
  /// M1 exit clause asks for. What is built here is an ACTIVE rack that the
  /// user can change — via the header's overflow menu, and automatically
  /// when they create one — so every rack in the document is reachable,
  /// editable and exportable. `scene_builder.dart` already filters devices
  /// by `placement.rackId`, `computeRackRollups` is already rack-scoped and
  /// `SheetSet.forRacks` already emits 2N+1 sheets, so nothing downstream
  /// had to be taught about the second rack; only this screen did.
  /// Null means "whichever rack sorts first", which is the state this
  /// screen mounts in and returns to when the rack it was showing goes
  /// away. Never `late`: a rack-less document is a state this screen now
  /// has to survive (see [_activeRack]), and `racks.keys.first` on one
  /// throws before the first frame.
  Uuid? _activeRackId;

  /// The active rack, the first one when [_activeRackId] names a rack that
  /// is no longer in the document, or NULL when the document holds no racks
  /// at all.
  ///
  /// THE FALLBACK IS THE WHOLE MECHANISM, not a belt-and-braces second
  /// one. Undoing an `AddRackCommand` deletes the very rack this screen is
  /// showing; a `sequence` listener that repointed [_activeRackId] at that
  /// moment was written first and then DELETED, because a mutation test
  /// showed it changed nothing observable — this line already handles it,
  /// and two mechanisms for one condition means one of them is untested by
  /// construction. Leaving the id dangling is also better behaviour: `redo`
  /// brings the rack back and the canvas returns to it, where a repoint
  /// would have stranded the user on RK-1.
  ///
  /// NULL IS REACHABLE, AND THE COMMENT THAT SAID OTHERWISE WAS WRONG. It
  /// used to read: *"`racks` cannot be empty here: the app shell renders
  /// `NoRacksView` instead of this screen for a rack-less document, and the
  /// only thing in this build that removes a rack is undoing an add, which
  /// by construction leaves whatever was there before."* The second half is
  /// exactly what this changeset falsified: `NoRacksView`'s new "New rack…"
  /// button creates the FIRST rack of a rack-less document, so what was
  /// "there before" is nothing, and `Ctrl+Z` then empties `racks` while this
  /// screen is mounted and listening. The `rack` epoch listener fires
  /// synchronously, before any ancestor can swap `NoRacksView` back in, so
  /// there is no frame in which "the shell renders something else" protects
  /// anything. Reproduced as `Bad state: No element`; pinned by
  /// `rack_creation_test.dart`'s "undoing the creation of the ONLY rack".
  Rack? get _activeRack {
    final id = _activeRackId;
    if (id != null) {
      final named = _doc.racks[id];
      if (named != null) return named;
    }
    return _doc.racks.isEmpty ? null : _doc.racks.values.first;
  }

  /// The active rack, for the code that only runs when there IS one.
  ///
  /// TWO GUARDS MAKE THIS TOTAL, and they are named rather than assumed.
  /// [build] returns [_racklessPanel] when [_activeRack] is null, so the
  /// canvas subtree — and with it every gesture handler, every `Shortcuts`
  /// binding and every painter below — does not exist while the document
  /// holds no racks. [_recomputeCaret] is the ONE reader that runs from a
  /// listener rather than from that subtree, and it checks [_activeRack]
  /// itself.
  Rack get _rack => _activeRack!;

  /// Derived geometry for the CURRENT rack height, memoised on that height.
  ///
  /// Was `late final RackGeometry _geo = RackGeometry(_rack.heightU)` — a
  /// once-and-never-again value, computed on the assumption (true until
  /// docs/04 §4.1's height editing landed) that a rack's height never
  /// changes. It does now, so every consumer — drag evaluation, the caret
  /// clamp, the overlay painter, `fitToContent`, the RU-range chip — would
  /// otherwise have gone on using a stale height after a resize.
  ///
  /// A memoised GETTER rather than a field re-assigned from the epoch
  /// listener, because the getter cannot go stale by construction: there is
  /// no ordering to get wrong between "the command mutated heightU" and
  /// "somebody read `_geo`". `RackGeometry` is an immutable single-`int`
  /// value type, so the cache exists purely to keep IDENTITY stable within a
  /// height — which is what stops `EditingOverlayPainter.shouldRepaint`'s
  /// `geo != old.geo` from being pointlessly true on every build. (It also
  /// has real `==`/`hashCode` as of this stage, so that comparison would be
  /// correct either way; the cache just avoids the allocation.)
  RackGeometry? _geoCache;
  RackGeometry get _geo {
    final cached = _geoCache;
    if (cached != null && cached.heightU == _rack.heightU) return cached;
    return _geoCache = RackGeometry(_rack.heightU);
  }

  /// The device the LAST quick-add placed and auto-selected, while that
  /// selection is still exactly what the placement left behind — docs/04
  /// §9's keep-typing loop, and nothing wider.
  ///
  /// WHY A FIELD AND NOT A PREDICATE OVER THE SELECTION. "The selection is
  /// one device that a quick-add once placed" is not the same question as
  /// "the selection is still the one that quick-add made": a user who
  /// clicks away and then clicks back has made a decision, and a rule that
  /// could not tell the two apart would silently resume caret-targeting on
  /// the strength of invisible history. So this is cleared by the first
  /// selection change the screen did not itself cause.
  Uuid? _lastQuickAddId;

  bool get _selectionIsLastQuickAdd {
    final id = _lastQuickAddId;
    return id != null && _selection.length == 1 && _selection.contains(id);
  }

  Face _face = Face.front;
  late LodLevel _lod = LodLevel.forScale(_viewport.scale);

  /// The scene most recently built in [build]. The intent handler hit-tests
  /// and reads device layouts against exactly what is on screen, so it must
  /// see the current build's scene; cached here rather than threaded through
  /// the pointer-agnostic `CanvasIntentHandler` interface.
  RackScene? _rackScene;

  /// CR-102's band (DR-139 §11.138, PLAN-E/6).
  ///
  /// OWNED HERE rather than passed in, unlike the plan canvas: this screen
  /// lays out its own canvas, palette and inspector, so nothing above it
  /// needs a handle on the band. The plan canvas is a REGION whose host
  /// stacks the band over it, which is why that one takes a controller.
  final MarqueeController _marquee = MarqueeController();

  /// True when THIS gesture began the band.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// SCOPED TO THE GESTURE, LIKE `_resizeDrag`, AND A TEST SAID WHY
  /// ═══════════════════════════════════════════════════════════════════
  /// The first draft asked `_marquee.isActive` in `_onUpdateDrag`, which
  /// is a question about the CONTROLLER and not about this drag. A second
  /// canvas pointer is DEFERRED rather than killed (`canvas_exclusivity_
  /// test.dart` rule 1), so it inherits the route when the first gesture
  /// ends; with a band left live it inherited the band too, and its
  /// move-drag stopped moving the device. That case failed, which is what
  /// turned this from a tidy field into a necessary one.
  bool _marqueeDrag = false;

  /// CR-105's chip content for every device, as of the last [build].
  ///
  /// CACHED FOR THE SAME REASON `_rackScene` IS: the pointer path decides
  /// whether a press landed on a chip, and it must answer against the
  /// counts the frame actually drew. Recomputing from `_doc` at press time
  /// would be the same numbers today and the first thing to diverge the
  /// moment anything defers a rebuild.
  Map<Uuid, PortFill> _portFill = const <Uuid, PortFill>{};

  late final _RackCanvasHandler _handler = _RackCanvasHandler(this);

  // ── per-drag scratch state (one primary pointer at a time) ────────────
  String? _dragDeviceId; // device hit at beginDrag, or null (empty canvas)
  DPt _dragStartScene = const DPt(0, 0);
  double _dragStartScale = 1;
  bool _dragModifierToggle = false; // Ctrl/Cmd held at beginDrag → toggle
  bool _dragMoved = false; // crossed the click→drag threshold

  /// The device whose CR-105 chip this gesture pressed on, or null.
  ///
  /// Decided ONCE at `beginDrag`, exactly like `_dragPlacement` and for
  /// the same reason its doc gives: the press and the release must be
  /// governed by one condition rather than two that can drift. A press on
  /// a chip followed by a drag is not a click and reveals nothing.
  Uuid? _dragChipDeviceId;
  int _dragDeviceHeightU = 0; // hit device's U height (0 if none)
  double _dragDeviceStartTopY = 0; // hit device's scene-space top edge

  /// The hit device's rail placement at grab time, or null when the drag
  /// did not start on a movable, rail-placed, ALREADY-SELECTED device.
  /// Non-null is precisely the condition under which a live move preview
  /// arms and a `MoveDeviceCommand` can eventually run — computed ONCE at
  /// `beginDrag` so the preview and the commit can never disagree about
  /// whether this gesture is a move at all.
  RailPlacement? _dragPlacement;

  /// Whether the move drag is currently off the rack, so the status line
  /// says so once rather than on every pointer move (DR-205).
  bool _moveWillStage = false;

  /// Off the rack: outside the chassis the scene drew, left, right, above
  /// or below. The canvas pans, so the canvas's own bounds are not the
  /// rack's.
  bool _isOffRack(DPt scene) {
    final chassis = _rackScene?.chassisBounds;
    return chassis != null && !chassis.contains(scene);
  }

  /// The pointer kinds `CanvasIntentDetector` reported at `beginDrag`,
  /// carried into the drag preview purely as INFORMATION (matching the
  /// palette drag's own `sourceKinds`). Nothing branches on it — doing so
  /// for editing semantics is forbidden (AC-016 #23) — but recording it
  /// honestly beats arming with an empty set that claims the gesture came
  /// from nowhere.
  Set<PointerDeviceKind> _dragSourceKinds = const {};

  /// Set by `Esc` mid-move-drag (docs/04 §3.3 step 4: "`Esc` mid-drag
  /// reverts"). The pointer is still physically down at that moment and
  /// `CanvasIntentDetector` will keep delivering `updateDrag` and,
  /// eventually, `commitDrag` for it — there is no way to un-route a
  /// gesture that detector owns — so this latch makes every remaining
  /// callback for the cancelled drag a no-op until the pointer is
  /// released. (The palette drag needs no equivalent: it is tracked
  /// through the global `pointerRouter`, which `_cancelPaletteDrag` can
  /// and does unsubscribe outright.)
  bool _dragCancelled = false;

  /// True for the remainder of the ONE key dispatch in which
  /// `_onRawKeyDuringPaletteDrag` cancelled a palette drag — see that method
  /// and `_onEscape` for why the two handlers both see the same `Esc`.
  bool _escConsumedByPaletteDrag = false;

  /// Set when `_onBeginDrag` could not CLAIM the screen because another
  /// pointer-driven gesture was already live (a palette drag, armed from a
  /// sibling widget through a separate pointer route, is the only such case
  /// reachable — `CanvasIntentDetector`'s own single-gesture guard already
  /// stops a second CANVAS pointer from ever getting here).
  ///
  /// A SIBLING OF [_dragCancelled], not a duplicate of it. Both make every
  /// remaining callback for a still-down pointer a no-op, but they differ in
  /// what they must NOT do: a cancelled drag had a preview and tears it
  /// down, whereas a refused one never armed anything, so running the usual
  /// teardown would reach into the OTHER gesture's live state.
  bool _dragRefused = false;

  /// True only for the duration of `_onCommitDrag` — the sibling of
  /// [_applyingCompaction], for the same reason and with the same shape. The
  /// stale-state guard fires on ANY document sequence bump, and a drag's own
  /// commit IS a bump, delivered while the gesture still holds its
  /// exclusivity claim; without this latch a successful move or resize would
  /// be read as the concurrent edit that invalidated it.
  ///
  /// HONEST NOTE, because a mutation removing this one survives: no CURRENT
  /// canvas commit path needs it. `_commitOrNoopMoveDrag` resets `_moveDrag`
  /// and `_commitResizeDrag` cancels `_resize` BEFORE running their command,
  /// so by the time the bump arrives the guard finds nothing live to cancel
  /// and only sets a `_dragCancelled` that `_resetDrag` clears one statement
  /// later. It is kept because that safety is an ORDERING COINCIDENCE across
  /// three call sites rather than a property, and this same file already
  /// contains a commit path with the opposite ordering: `_applyCompaction`
  /// deliberately runs its `transact` BEFORE `_compaction.cancel()`, which is
  /// exactly why [_applyingCompaction] had to exist. A latch that makes the
  /// guard's precondition explicit costs one bool; rediscovering this the
  /// third time would not.
  bool _dragCommitting = false;

  @override
  void initState() {
    super.initState();
    _viewport.addListener(_onViewportChanged);
    // A committed structural edit (add/remove/move touches `structure`) and a
    // selection change both mean "rebuild the scene / repaint chrome"; both
    // fire at human speed, never on the pan/zoom hot path.
    // `_forgetQuickAddSelection` is registered on `_selection` ONLY — not
    // on the epochs — because it must react to selection changes and to
    // nothing else. Folding it into `_onEditorChanged` would have closed
    // the keep-typing window on the placement's own `structure` epoch bump,
    // which fires before the selection is even set.
    _selection
      ..addListener(_onEditorChanged)
      ..addListener(_forgetQuickAddSelection);
    _controller.epochs.structure.addListener(_onEditorChanged);
    // THE FIRST-EVER `rack` EPOCH SUBSCRIPTION. `SetRackHeightCommand` and
    // `SetEntityPropertyCommand` both touch `EpochMask.rack`, and until this
    // stage nothing on this screen listened to it — so a height change
    // would have mutated the document and repainted NOTHING, and an
    // inspector edit would have left the panel showing the old value.
    _controller.epochs.rack.addListener(_onEditorChanged);
    // `meta` carries designator/name edits (`RenameEntityCommand`,
    // `SetEntityPropertyCommand(designator)`), which the header bar and the
    // inspector both display.
    _controller.epochs.meta.addListener(_onEditorChanged);
    // `wires` since the full-tree review (`#932`). DR-171 counts a device's
    // consumed outlets from the cords drawn to it (§11.170.4), and the
    // findings drawer judges cables, and `build` derives both. So a
    // wires-only commit, a cord removed or its undo, changed the chip and
    // repainted nothing. The app hid it only because `AppShell` rebuilds the
    // whole tree on every commit, which is a performance accident and not a
    // dependency this screen may borrow. `rack_canvas_epochs_test.dart`
    // mounts the screen without the shell to keep that honest.
    _controller.epochs.wires.addListener(_onEditorChanged);
    // Bumped by EVERY commit, undo and redo (CR-094) — the one signal broad
    // enough to catch "the document moved under an open compaction
    // preview", whatever moved it. See `_onDocumentSequenceChanged`.
    _controller.epochs.sequence.addListener(_onDocumentSequenceChanged);
    // The caret's activation formula (docs/04 §3.4) has "canvas has focus"
    // as one of its three inputs — a plain FocusNode is not itself a
    // ChangeNotifier the caret can merge into its own repaint listenable,
    // so the screen bridges it explicitly.
    _caret.addListener(_ensureCaretVisible);
    _canvasFocus.addListener(_onFocusChanged);
    // THE PALETTE FILTER COUNTS AS CANVAS FOCUS FOR THE CARET — see
    // `_recomputeCaret`. Without this listener that widening would be inert,
    // because nothing else fires when focus moves between the two.
    widget.paletteSearchFocus?.addListener(_onFocusChanged);
    // The palette drag's phase feeds the caret's `dragInProgress` input
    // AND the palette's own dimmed-row rendering — see the field's own
    // doc comment for why this is coarse-filtered rather than a repaint
    // on every frame.
    _paletteDrag.addListener(_onPaletteDragChanged);
    // Same coarse filter for the move drag — see `_lastMoveDragSourceId`.
    _moveDrag.addListener(_onMoveDragChanged);
    // Seed the caret immediately rather than waiting for the first focus/
    // selection event, so it has a sensible (if inactive) position from
    // the very first frame.
    _recomputeCaret();
    // DR-193: a request parked before this page was built is taken on its
    // first frame; one parked afterwards arrives through the listener.
    widget.reveal?.addListener(_onRevealRequested);
    if (widget.reveal?.pending != null) _onRevealRequested();
  }

  /// Takes a parked reveal and answers it after the frame, on
  /// `SchematicCanvasScreen._onRevealRequested`'s reasoning, including its
  /// `ensureVisualUpdate`: a callback queued with no frame pending waits
  /// for somebody else's `setState`.
  void _onRevealRequested() {
    final id = widget.reveal?.take();
    if (id == null) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) _revealEntity(id);
      })
      ..ensureVisualUpdate();
  }

  /// Shows [id]: a rack by switching to it and opening its settings, a
  /// device by switching to the rack it is in and selecting it.
  void _revealEntity(Uuid id) {
    if (_doc.racks.containsKey(id)) {
      _switchRack(id, announce: false);
      _showRackInspector();
      _canvasFocus.requestFocus();
      return;
    }
    final device = _doc.devices[id];
    if (device == null) return;
    final rackId = rackIdOfDevice(_doc, device);
    if (rackId != null && rackId != _activeRackId) {
      _switchRack(rackId, announce: false);
    }
    _revealFinding(id);
    _canvasFocus.requestFocus();
    setState(() {});
  }

  @override
  void dispose() {
    widget.reveal?.removeListener(_onRevealRequested);
    _marquee.dispose();
    _viewport
      ..removeListener(_onViewportChanged)
      ..dispose();
    _selection
      ..removeListener(_onEditorChanged)
      ..removeListener(_forgetQuickAddSelection)
      ..dispose();
    _controller.epochs.structure.removeListener(_onEditorChanged);
    _controller.epochs.rack.removeListener(_onEditorChanged);
    _controller.epochs.meta.removeListener(_onEditorChanged);
    _controller.epochs.wires.removeListener(_onEditorChanged);
    _controller.epochs.sequence.removeListener(_onDocumentSequenceChanged);
    _compaction.dispose();
    // A top-edge drag in flight at dispose time (as with the other two
    // previews: unusual in production, real in a widget test that pumps a
    // new tree mid-drag) must not leave an orphaned `OverlayEntry`.
    _removeResizeOverlay();
    _resize.dispose();
    _inspectorFirstFieldFocus.dispose();
    _caret.removeListener(_ensureCaretVisible);
    _canvasFocus.removeListener(_onFocusChanged);
    _caret.dispose();
    _shake.dispose();
    _status.dispose();
    // A palette drag in flight when the screen is disposed (unusual in
    // production; real in a widget test that pumps a new tree mid-drag)
    // must not leak a global pointer route, a global keyboard handler, or
    // a pending Timer.
    _blockedReleaseTimer?.cancel();
    _stopTrackingPalettePointer();
    _removePaletteEscHandler();
    _removePaletteDragOverlay();
    // The Staging Bin overlay is a THIRD `OverlayEntry` this screen owns
    // and it was the one this list forgot — a palette drag disposed while
    // the pointer was outside the canvas left it in the root overlay
    // forever, which is precisely the leak the three comments above were
    // written to prevent.
    _removeStagingBinOverlay();
    _paletteDrag
      ..removeListener(_onPaletteDragChanged)
      ..dispose();
    // Likewise for a move drag in flight at dispose time (same reasoning:
    // unusual in production, real in a widget test that pumps a new tree
    // mid-drag) — no leaked Timer, no orphaned OverlayEntry.
    _moveBlockedReleaseTimer?.cancel();
    _removeMoveDragOverlay();
    _moveDrag
      ..removeListener(_onMoveDragChanged)
      ..dispose();
    _gridCache.dispose();
    _canvasFocus.dispose();
    // RELEASED, NOT DISPOSED. The node belongs to `PaletteHost`, which
    // outlives a tab change; disposing a borrowed node here would leave
    // the palette with a dead field the moment somebody opened the Plan
    // tab and came back.
    widget.paletteSearchFocus?.removeListener(_onFocusChanged);
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
    _recomputeCaret();
    if (mounted) setState(() {});
  }

  /// The canvas gained or lost Flutter focus — one of the caret's three
  /// activation inputs (docs/04 §3.4).
  void _onFocusChanged() => _recomputeCaret();

  /// The rack this screen has already framed, so [_seedViewport] runs once
  /// per rack rather than once per layout pass. Height is part of the key:
  /// a 9U rack resized to 42U moves U1 by 726 scene units, which is off the
  /// bottom of any window this app supports.
  ({Uuid id, int heightU})? _seededFor;

  /// Where each rack was last left, for THIS session (DR-066).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A VIEWPORT IS A WAY OF LOOKING, NOT A FACT ABOUT THE DOCUMENT
  /// ═══════════════════════════════════════════════════════════════════
  /// So it lives here and nowhere else: not in the `.rppj`, which is
  /// under CR-117's byte round-trip and where a pan would dirty the file
  /// and prompt a save; and not in preferences, which would let a bad
  /// view outlive the restart that is currently how you escape one.
  /// `design-ux-schematic.md` already states the same rule for the theme:
  /// "the switch is view-only, never persisted in the document".
  ///
  /// KEYED BY RACK, AND THE HEIGHT IS PART OF THE VALUE RATHER THAN THE
  /// KEY. A resize moves U1 by up to 726 scene units, so a view
  /// remembered at 9U is meaningless at 42U; storing the height beside
  /// the matrix lets the restore decline and re-frame instead.
  final _rememberedViews = <Uuid, ({Matrix4 transform, int heightU})>{};

  /// Frames the rack on first sight, and restores it on every return.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THIS USED TO NUDGE U1 INTO VIEW AND LEAVE THE ZOOM AT 1.0
  /// ═══════════════════════════════════════════════════════════════════
  /// It existed because scene space is bottom-origin for racks
  /// (`yBottomOfU(1) == rackHeight`), so on a 42U rack the caret painted
  /// at scene y = 924 in a column about 870px tall: active, painting, and
  /// below the fold. The minimum-delta nudge fixed that and nothing else.
  ///
  /// The old comment argued that scale had to stay at 1.0 because
  /// docs/04 §2.1 fixes "zoom 1.0 = 1U is 22px", and that fitting would
  /// "trade a documented constant for an undocumented one". THAT WAS
  /// OVERSTATED, and re-reading §2.1 is what settled it: the line defines
  /// what 1.0 MEANS. It does not say the editor opens at it, any more
  /// than defining a metre commits a map to being printed at 1:1. So
  /// framing the whole rack is compatible with the corpus rather than a
  /// departure from it.
  ///
  /// ON EVERY RETURN, RESTORE. Switching to RK-2 and back should not cost
  /// you the place you were working, which is the whole of
  /// [_rememberedViews].
  ///
  /// ON FIRST SIGHT, FIT AND CENTRE (`#710`). You cannot judge an
  /// elevation you can only see two thirds of, and the first thing anyone
  /// does on opening a rack is look at the whole of it.
  ///
  /// THIS MOVED SCENE (0,0) OFF THE CANVAS CORNER AND 66 WIDGET CASES
  /// ASSUMED IT WAS THERE. They turned a scene rect into a tap position
  /// by adding the canvas origin, which is only the identity transform
  /// wearing a disguise. They now route through the live viewport, which
  /// is both correct and framing-agnostic: the next change to the opening
  /// view costs nothing in test edits.
  ///
  /// Runs from `LayoutBuilder` but defers the mutation to a post-frame
  /// callback: `ViewportController` is a `ChangeNotifier` and notifying
  /// during layout would rebuild its listeners mid-pass.
  void _seedViewport(Size viewportSize) {
    if (viewportSize.isEmpty || _activeRack == null) return;
    final key = (id: _rack.id, heightU: _rack.heightU);
    if (_seededFor == key) return;

    // REMEMBER THE OUTGOING RACK BEFORE ANYTHING MOVES. Read here rather
    // than in the callback below: by the time that runs the new rack has
    // been framed and the matrix is no longer the one being left.
    final leaving = _seededFor;
    if (leaving != null && leaving.id != key.id) {
      _rememberedViews[leaving.id] = (
        transform: _viewport.transform.clone(),
        heightU: leaving.heightU,
      );
    }
    _seededFor = key;

    final geo = _geo;
    final remembered = _rememberedViews[key.id];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (remembered != null && remembered.heightU == key.heightU) {
        _viewport.setTransform(remembered.transform);
        return;
      }
      // The whole rack, centred, with `fitToContent`'s own 10% margin.
      // Scene space is bottom-origin for racks, so this is also what puts
      // U1 — where placement starts and where the caret seeds — reliably
      // on screen, which is what the nudge this replaced existed for.
      //
      // ═══════════════════════════════════════════════════════════════
      // CENTRED IN THE SPACE THAT IS ACTUALLY FREE, NOT IN THE BOX
      // ═══════════════════════════════════════════════════════════════
      // The canvas carries floating chrome pinned at `top: 12`: the zoom
      // HUD, the face toggle and the header row, together occupying about
      // y 12–72. Centring in the raw box put the rack's TOP EDGE at y ≈ 56
      // on a 1000px canvas — underneath all three.
      //
      // That is not cosmetic. docs/04 §4.1's drag-to-resize is an 8px grab
      // band CENTRED ON THAT EDGE, so the edge landing under a `Card` made
      // a shipped gesture unreachable: the pointer never reached
      // `_onBeginDrag` at all. Nine widget cases caught it, which is the
      // one part of this evening that worked the way it should.
      //
      // So the rack is framed into the canvas MINUS that band and then
      // pushed down past it, which centres it in the space a pointer can
      // actually reach.
      final free = Size(
        viewportSize.width,
        math.max(1, viewportSize.height - _kTopChromeInset),
      );
      _viewport
        ..fitToContent(
          Box.fromLtwh(0, 0, geo.rackWidth.ceil(), geo.rackHeight.ceil()),
          free,
        )
        ..panBy(const Offset(0, _kTopChromeInset));
    });
  }

  /// Keeps the caret inside the viewport as it moves.
  ///
  /// `CaretController.moveTo`/`moveBy` are pure model updates — they never
  /// touch the viewport — so on a rack taller than the window the arrow keys
  /// happily walk the caret straight off the top or bottom edge and the user
  /// is then driving something they cannot see. Pans by the MINIMUM delta
  /// that brings the caret line back inside, so an already-visible caret
  /// never causes the canvas to jump.
  void _ensureCaretVisible() {
    final active = _caret.caret;
    if (active == null) return;

    // NOT WHILE THE VIEWPORT BELONGS TO A DIFFERENT RACK (`#710`).
    //
    // The caret listener fires from `setState`, before the layout pass in
    // which [_seedViewport] frames the incoming rack — so for one moment
    // `_rack` (and therefore `_geo`) is the new rack while `_viewport`
    // still holds the old one's matrix. Asking where U1 is across that
    // mismatch returns a screen y for the WRONG rack: switching a 12U view
    // to a 42U rack put U1 at y = 2960 on a 1000px canvas, so this method
    // "rescued" a caret that was never lost by panning nearly two thousand
    // pixels — and [_seedViewport] then filed that wreckage as where the
    // OUTGOING rack was left, breaking DR-066's restore in the one gesture
    // it exists for.
    //
    // Declining costs nothing: the framing pass is one layout away and it
    // puts the whole rack, caret included, on screen by construction.
    if (_seededFor != (id: _rack.id, heightU: _rack.heightU)) return;

    final box = _canvasBoxKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || box.size.isEmpty) return;

    final y = _viewport
        .sceneToScreen(DPt(0, _geo.yBottomOfU(active.ruIndex)))
        .y;
    // Raw bounds to DECIDE, inset bounds to CORRECT — see `_seedViewport`.
    // Deciding on the inset bound would pan the canvas by a couple of
    // pixels whenever the caret reached the top of a rack that fits
    // perfectly well, which is motion with no cause and would have moved
    // the coordinate frame under every pointer test in this package.
    if (y >= 0 && y <= box.size.height) return;
    _viewport.panBy(
      Offset(
        0,
        y < 0 ? _kViewportMargin - y : box.size.height - _kViewportMargin - y,
      ),
    );
  }

  /// Closes the keep-typing transparency window (see [_lastQuickAddId]) on
  /// the first selection change this screen did not itself make: a click, a
  /// Ctrl+click, a marquee, `Esc`, a Delete, or an undo restoring the
  /// selection it captured. All of them are decisions about what is
  /// selected, and docs/04 §3.4's "the caret conceptually doesn't exist
  /// once something is selected" applies to every one of them.
  /// NO LATCH FOR THE SCREEN'S OWN SELECTION WRITE. There was one — a
  /// `_settingQuickAddSelection` bool raised around
  /// `_finalizeCatalogPlacement`'s `_selection.apply(...)` so this listener
  /// would not close the window that method was about to open. It was
  /// DELETED because it could not be observed: `apply` notifies
  /// synchronously, so this listener ran and cleared `_lastQuickAddId`
  /// mid-`apply` — and the very next statement assigned `_lastQuickAddId`
  /// again. Neutralising the guard changed nothing in 19 tests across the
  /// two keyboard files. Dead state whose doc comment described a hazard
  /// the statement order already precludes is worse than no state: it reads
  /// as a mechanism somebody is relying on.
  void _forgetQuickAddSelection() => _lastQuickAddId = null;

  /// THE STALE-STATE GUARD (docs/04 §3.6, and §3.3 step 4 by extension).
  ///
  /// EVERY preview on this screen holds positions captured against a
  /// document snapshot and then waits — a compaction preview until the user
  /// Applies or Cancels, a move drag until the pointer comes up, a resize
  /// drag likewise. If anything mutates the document in between (Ctrl+Z, a
  /// palette placement, a keyboard nudge, a device delete), each of those
  /// captures describes a world that no longer exists:
  ///
  ///  * a `CompactionMove.fromRuIndex` becomes a fabrication, so Apply would
  ///    issue `MoveDeviceCommand`s whose "from" was never true;
  ///  * `_dragPlacement.ruIndex` — captured ONCE at `beginDrag` — becomes
  ///    one too, so `_commitOrNoopMoveDrag` would commit a `MoveDeviceCommand
  ///    (fromRuIndex: <a U the device never occupied>)`;
  ///  * `_resize.originalHeightU` becomes a baseline the rack no longer has,
  ///    so the "24U (+3)" readout states a delta against a vanished height.
  ///
  /// In all three cases `revert()` would faithfully restore the fabricated
  /// value, so the corruption SURVIVES an undo. That is the whole reason
  /// this guard exists, and it is why it now covers all of them rather than
  /// the compaction preview alone: the compaction case was merely the one
  /// that got noticed first, not the only one that had it.
  ///
  /// Cancelling (rather than silently re-planning, or blocking undo
  /// outright) is the honest option: a re-plan would swap different ghosts
  /// under a user who is mid-decision and might then Apply something they
  /// never previewed, and refusing `Ctrl+Z` would deny a documented shortcut
  /// to protect a preview that has committed nothing and costs nothing to
  /// re-open. Nothing is lost by cancelling — no command has run — and the
  /// status line says so, so it is not a silent disappearance either.
  ///
  /// This is the same bug class as the two stale-`Timer` bugs this file has
  /// already been bitten by (see `_onPaletteArmDrag`'s and `_armMovePreview`'s
  /// own notes), and it gets the same treatment: an explicit guard with a
  /// regression test, not a hope that the window is too narrow to hit.
  void _onDocumentSequenceChanged() {
    if (_applyingCompaction) return; // our own commit — expected.
    if (_compaction.isActive && _doc.sequence == _compaction.documentSequence) {
      return; // the plan was captured against exactly this document.
    }
    final what = _invalidateLivePreviews();
    if (what == null) return; // nothing was live — an ordinary edit.
    _status.show('$what cancelled — the rack changed.');
    if (mounted) setState(() {});
  }

  /// Feeds the screen's live selection/focus/rack/palette-drag state into
  /// [CaretController.recompute] (docs/04 §3.4's activation formula: the
  /// caret and an in-flight palette drag are mutually exclusive, docs/04
  /// §3.1).
  void _recomputeCaret() {
    // THE ONE READER THAT RUNS WITHOUT THE CANVAS SUBTREE. This is reached
    // from the `rack`/`structure` epoch listeners and from the selection
    // listener, all of which fire SYNCHRONOUSLY inside `controller.run` /
    // `undo` — before any rebuild, therefore before [build] has had the
    // chance to notice the document no longer has a rack. See [_activeRack]:
    // undoing the creation of the FIRST rack is the case that gets here.
    // Nothing to recompute against, and nothing on screen to recompute FOR
    // (build renders [_racklessPanel]); the caret re-seeds itself against
    // whatever rack appears next, because `CaretController.recompute`
    // compares `caret.rackId` to the rack it is handed.
    if (_activeRack == null) return;
    _caret.recompute(
      // A JUST-QUICK-ADDED DEVICE DOES NOT COUNT AS A SELECTION HERE.
      // `_finalizeCatalogPlacement` makes every placement the sole
      // selection (docs/04 §3.1 step 6), which switched the caret OFF at
      // the exact moment the keep-typing loop needs it most: place, caret
      // vanishes, type the next template, and there is no longer anything
      // on screen saying where it will land. The screen already computes
      // this transparency window for caret TARGETING
      // (`_selectionIsLastQuickAdd`, read by `_placeFromCatalog`); it was
      // simply never applied to caret ACTIVATION, so the caret aimed
      // somewhere it refused to draw.
      selectionEmpty: _selection.isEmpty || _selectionIsLastQuickAdd,
      // THE PALETTE FILTER COUNTS. docs/04 §3.4 says "whenever the canvas
      // has focus", written before `/` existed. Taken literally it makes
      // the documented §3.2 flow self-defeating: `/` moves focus to the
      // filter, which extinguishes the caret that the placement about to
      // happen is aimed at. The caret must stay lit across the hand-off it
      // is the whole point of.
      //
      // NARROW ON PURPOSE — this names one sibling node, rather than
      // wrapping the `Row` in a `FocusScope` and asking whether focus is
      // anywhere within it. The inspector's five text fields are in that
      // `Row` too, and typing a rack name is not a placement gesture.
      canvasHasFocus:
          _canvasFocus.hasFocus ||
          (widget.paletteSearchFocus?.hasFocus ?? false),
      // EITHER drag suppresses the caret (docs/04 §3.4: the caret and an
      // in-flight drag are mutually exclusive) — in practice a move drag
      // already implies a non-empty selection, which suppresses it anyway,
      // but the caret's activation formula should state the real rule
      // rather than lean on a coincidence.
      dragInProgress: _paletteDrag.isInProgress || _moveDrag.isInProgress,
      rack: _rack,
      smartDefaultRuIndex: findLowestFreeRu(
        rack: _rack,
        devices: _doc.devices.values,
        face: _face,
        templates: _doc.templates,
        deviceH: 1,
      ),
    );
  }

  /// Front → Rear (docs/04 §2.2 cycles Front → Rear → Both; Both is
  /// deferred with rear-mirroring, so this stage toggles the two faces).
  ///
  /// A FACE CHANGE INVALIDATES EVERY LIVE PREVIEW, and that is not a
  /// nicety. A compaction plan is computed for ONE face (see this section's
  /// header: "a previewed operation should act on the elevation you are
  /// actually looking at"); `_paintCompactionGhosts` has no face filter, so
  /// after a toggle it paints front-face ghosts on top of unrelated rear
  /// devices, `RenderDeviceBox.fadeOpacity` dims nothing (the movers are not
  /// rendered on this face), and Apply then relocates devices the user was
  /// shown no preview of — the consent gate docs/04 §3.6's "never apply
  /// silently" rests on, bypassed. The two device drags are face-bound in
  /// the same way (`DragPreviewController.face` is fixed at arm time). The
  /// stale-state guard above cannot help here: it fires on a `doc.sequence`
  /// bump, and a face change is pure UI state.
  ///
  /// The resize preview is NOT face-bound (its hatch is computed across both
  /// faces on purpose — see resize_preview_controller.dart's header) and is
  /// torn down anyway, because ONE invalidation path with one rule is worth
  /// more than an exemption that has to be re-derived every time somebody
  /// adds a preview.
  void _cycleFace() {
    final what = _invalidateLivePreviews();
    if (what != null) {
      _status.show('$what cancelled — the elevation changed.');
    }
    setState(() => _face = _face == Face.front ? Face.rear : Face.front);
  }

  // ── THE EXCLUSIVITY RULE, IN ONE PLACE ────────────────────────────────
  //
  // FOUR preview-then-commit interactions coexist on this screen: the
  // palette drag (§3.1), the move drag (§3.3), the compaction preview
  // (§3.6) and the top-edge resize (§4.1). This file has now been bitten
  // THREE separate times by the same failure — a second entry point
  // re-initialising state a live interaction still owned: `_onPaletteArmDrag`
  // being re-armed by a second pointer, its blocked-release `Timer` firing
  // against a drag it no longer owned, and `_armMovePreview` inheriting that
  // second bug verbatim. Three recurrences in one file is the code saying
  // that re-asserting the rule at each entry point is too easy to get wrong.
  //
  // So the rule is stated ONCE, here, in two halves, and every entry point
  // ASKS instead of remembering:
  //
  //  1. AT MOST ONE POINTER-DRIVEN GESTURE, arbitrated by
  //     [_claimPointerGesture] / [_releasePointerGesture] over the single
  //     [_liveGesture] field. A second gesture is REFUSED, never allowed to
  //     preempt: the first pointer is still physically down and will keep
  //     delivering events only its own live state can interpret, so
  //     preemption would orphan that state permanently. The compaction
  //     preview is the exception that proves the rule — it has no pointer
  //     of its own, so a new gesture can and does take the screen from it.
  //
  //  2. ONE TEARDOWN, [_invalidateLivePreviews], called from the two places
  //     where every live preview's premise stops being true at once: a
  //     document mutation the preview did not cause
  //     (`_onDocumentSequenceChanged`) and a face change (`_cycleFace`).
  //
  // BELOW this, `CanvasIntentDetector` enforces its own half structurally: a
  // second CANVAS pointer never reaches `_onBeginDrag` at all, so half of
  // rule 1 is a property of the routing rather than a check this screen has
  // to keep passing. What remains here is genuinely cross-route (a palette
  // drag is armed from a sibling widget and tracked through the global
  // `pointerRouter`), which no single detector can see.
  //
  // BELT AND BRACES, deliberately kept: `EditingOverlayPainter`'s own
  // precedence chain still exists. It is cheap, and a screen bitten three
  // times by this class does not get to rely on one mechanism.

  /// Claims the screen for [gesture]. Returns false — and starts nothing —
  /// when another pointer-driven gesture is already live.
  ///
  /// A REFUSAL IS REPORTED, never silent (docs/04 §3.4's "never silently do
  /// nothing"): the user pressed something and got nothing back, which is
  /// exactly the case that principle exists for. There is no shake, because
  /// nothing was ever armed for this pointer — there is no ghost or device
  /// to shake, and shaking the OTHER gesture's would blame the wrong one.
  bool _claimPointerGesture(_PointerGesture gesture) {
    if (_liveGesture != null) {
      _status.show('One drag at a time — finish the one in progress first.');
      return false;
    }
    _liveGesture = gesture;
    // The compaction preview has no pointer of its own, so it is the one
    // interaction a new gesture may take the screen from. (§3.6's floating
    // bar keeps its own Apply/Cancel buttons for the deliberate paths, and
    // those live ABOVE the detector in the Stack, so clicking them never
    // reaches a claim.)
    _cancelCompaction();
    return true;
  }

  /// Releases [gesture]'s claim. A no-op when [gesture] is not the one
  /// holding it, so a refused gesture running its own teardown can never
  /// release the claim belonging to the gesture that refused it.
  void _releasePointerGesture(_PointerGesture gesture) {
    if (_liveGesture == gesture) _liveGesture = null;
  }

  /// THE ONE TEARDOWN for every live preview and in-flight gesture.
  ///
  /// Returns a user-facing name for what it cancelled, or null when nothing
  /// was live — a preview vanishing with no explanation would be exactly the
  /// silent no-op §3.4 forbids, so the callers all report. At most one of
  /// the four can be live at a time (rule 1 above), so a single name is
  /// always enough; all four are nevertheless checked rather than
  /// short-circuited, because a teardown is the wrong place to lean on an
  /// invariant asserted somewhere else.
  ///
  /// THE PALETTE case uses `isSourceEngaged` rather than `isInProgress`: an
  /// `armed`-but-not-yet-lifted palette drag has captured nothing from the
  /// document at all (its snap and its verdict are recomputed every frame,
  /// and its commit re-runs `buildPlaceFromCatalogCommand` against the live
  /// document), so there is nothing stale about it and cancelling it would
  /// emit a status line for an interaction the user never started.
  ///
  /// THE CANVAS case cannot use that test, and the difference is the whole
  /// reason it is one branch keyed on the CLAIM instead of two keyed on the
  /// previews. `_onBeginDrag` captures `_dragPlacement`, `_dragDeviceId` and
  /// `_dragDeviceStartTopY` at pointer-DOWN — before the 4px threshold, and
  /// therefore before any preview exists. A `Ctrl+Z` in that window shows
  /// nothing to cancel, and then the very next 4px of movement arms
  /// `_armMovePreview` from those already-stale captures and commits a
  /// `MoveDeviceCommand` whose `fromRuIndex` the device never had. Keying on
  /// "is a canvas gesture live" rather than "is a canvas preview visible"
  /// closes that window.
  ///
  /// WHAT IT MAY NOT DO IN THAT WINDOW IS CANCEL THE CLICK, and this is where
  /// the first version of the guard over-corrected. `_dragCancelled` makes
  /// `_commitDragBody` return before `_handleClick`, so a press that had not
  /// yet become a drag — an ordinary click, or one that hesitated — was
  /// swallowed whole by any concurrent mutation: press AMP-1, `Ctrl+Z`,
  /// release, and the device is not selected and the inspector never switches
  /// to the rack. A silent no-op, produced by a guard whose entire purpose is
  /// to prevent silent corruption.
  ///
  /// THE PRECISE RULE, therefore: a sub-threshold press has no PREVIEW to
  /// cancel, so it is not cancelled — only its stale CAPTURE is dropped.
  /// Clearing `_dragPlacement` disarms `_armMovePreview` (which returns early
  /// without one) as thoroughly as the latch did, so the next 4px can no
  /// longer arm from a placement that has become a lie, while the release
  /// still resolves as the click it always was. `_handleClick` is safe to
  /// leave alive because of what it reads and what it writes: `_dragDeviceId`
  /// and `_dragStartScene`, mutating only the non-undoable `_selection` and
  /// `_inspectorTarget`. It has no captured `fromRuIndex` to fabricate.
  /// (`_dragDeviceId` is re-validated here too: a mutation that DELETED the
  /// pressed device turns the press into a click on the rack background,
  /// which is the truth, rather than a selection of a ghost id.)
  ///
  /// A sub-threshold RESIZE press needs nothing dropped at all — it captured
  /// only `_dragStartScene`, and `_armResizePreview` reads `_rack.heightU`
  /// live at arm time — so it simply carries on against the new document.
  ///
  /// [_dragCommitting] excludes the gesture's OWN commit: `_onCommitDrag`
  /// runs the `MoveDeviceCommand`/`SetRackHeightCommand` while the claim is
  /// still held (the release is what eventually calls `_resetDrag`), and
  /// without the latch a successful drag would report itself as a concurrent
  /// edit that invalidated it — exactly what `_applyingCompaction` already
  /// does for the compaction preview's own Apply.
  String? _invalidateLivePreviews() {
    String? what;
    if (_compaction.isActive) {
      _compaction.cancel();
      what ??= 'Compaction preview';
    }
    if (_paletteDrag.isSourceEngaged) {
      _cancelPaletteDrag();
      what ??= 'Placement drag';
    }
    if (_liveGesture == _PointerGesture.canvasDrag && !_dragCommitting) {
      if (_dragMoved) {
        // Past the 4px threshold: a preview really is on screen. Named BEFORE
        // the teardown, which clears the very state the name is derived from.
        if (_moveDrag.isSourceEngaged) what ??= 'Move';
        if (_resize.isActive) what ??= 'Resize preview';
        _cancelMoveDrag();
        _cancelResizePreview();
        // The pointer is still physically down and `CanvasIntentDetector`
        // will keep delivering for it; the same latch `Esc` uses makes every
        // remaining callback a no-op, so neither the release nor a later
        // threshold crossing can resurrect the gesture from a capture that no
        // longer describes the document.
        _dragCancelled = true;
      } else {
        // Sub-threshold: nothing is armed and nothing is on screen, so there
        // is nothing to cancel and nothing to name. Drop the one capture that
        // has gone stale and let the press stay a click (see this method's
        // doc for why that is the whole distinction).
        _dragPlacement = null;
        final pressed = _dragDeviceId;
        if (pressed != null && !_doc.devices.containsKey(Uuid(pressed))) {
          _dragDeviceId = null;
        }
      }
    }
    return what;
  }

  // ── compaction, preview-then-accept (docs/04 §3.6) ────────────────────
  //
  // "Compact Down and Compact Up ship; they never apply silently. Each opens
  // a preview overlay — proposed positions as solid ghosts, current
  // positions dimmed to 25%, and a floating bar 'Compact Up — 4 devices move
  // — 3U freed [Apply] [Cancel]'. Enter applies as one undo entry, Esc
  // cancels. Locked placements are immovable anchors."
  //
  // THE PLANNING IS ENTIRELY CORE (`planCompaction`, pure Dart, mutating
  // nothing); this screen owns only the preview's lifecycle. That split is
  // what makes preview-then-accept possible without a speculative
  // apply-then-undo, which would have polluted the undo stack with an entry
  // the user never asked for.
  //
  // AFFORDANCE, chosen and stated: the rack header's overflow menu. §3.6
  // requires the two commands to ship while leaving `Ctrl+B` RESERVED AND
  // UNBOUND (AC-045), so they need a non-keyboard home, and compaction is a
  // per-rack operation — hanging it off the rack's own chrome puts it where
  // its subject is. `Ctrl+B` is NOT bound here or anywhere.
  //
  // ONE FACE, deliberately: the currently displayed one. A previewed
  // operation should act on the elevation you are actually looking at.
  // (`planRackShrink` unions both faces, because a shrink is a physical
  // change to the whole rack — see compaction.dart's header for the full
  // statement of that asymmetry.)

  void _beginCompaction(CompactDirection direction) {
    // PREVIEW EXCLUSIVITY, through the ONE teardown (see the exclusivity
    // section above) rather than three hand-listed cancels that a fourth
    // preview would have to remember to join.
    //
    // THIS TEARDOWN CURRENTLY FINDS NOTHING, EVERY TIME, and that is worth
    // writing down because the opposite is the obvious reading and has been
    // filed as a defect once already ("a gesture torn down here vanishes with
    // no status line"). All three things `_invalidateLivePreviews` can report
    // are unreachable from here, for three different reasons:
    //
    //  * A CANVAS GESTURE. This method's only entry point is
    //    `_onRackHeaderAction`, i.e. the header's `PopupMenuButton` — a
    //    Navigator ROUTE. `NavigatorState._afterNavigation` calls
    //    `_cancelActivePointers()` on every push, which dispatches a real
    //    `PointerCancelEvent` for every pointer still down. So the two-finger
    //    case (A mid-drag, B opening the menu) has already lost A to
    //    `_onCancelDrag` — the deliberately silent "nothing was released, so
    //    nothing was attempted-and-refused" path — before the menu item is
    //    even tapped, let alone before this line runs.
    //  * A PALETTE DRAG. Same cancel; it handles `PointerCancelEvent` on its
    //    own `pointerRouter` route and calls `_cancelPaletteDrag` itself.
    //  * AN OPEN COMPACTION PREVIEW. It has no pointer, so nothing cancels
    //    it — but `RackHeaderBar.compactionEnabled` is wired to
    //    `!_compaction.isActive`, so the two menu items that reach this
    //    method are DISABLED for exactly as long as one is open.
    //
    // canvas_exclusivity_test.dart pins the first and third; the second
    // follows the first's mechanism.
    //
    // THE REPORT BELOW IS THEREFORE DEFENCE, NOT A LIVE PATH, and it is kept
    // for the reason [_dragCommitting] gives at length about its own
    // unreachable case: every argument above is a property of OTHER code —
    // a Flutter widget's pointer bookkeeping and one `enabled:` expression in
    // a sibling file — not of this method. A call site that silently relies
    // on three such coincidences is one refactor away from being the silent
    // no-op it was accused of being, and honouring `_invalidateLivePreviews`'
    // documented contract ("the callers all report") costs one local.
    //
    // The name is threaded through both exits below rather than shown here,
    // because `_status` holds ONE line and the empty-plan branch has its own
    // thing to say — a bare `show` here would simply be overwritten by it a
    // few statements later.
    final cancelled = _invalidateLivePreviews();

    final plan = planCompaction(
      rack: _rack,
      devices: _doc.devices.values,
      face: _face,
      templates: _doc.templates,
      direction: direction,
    );
    if (!_compaction.show(plan, documentSequence: _doc.sequence)) {
      // §3.4's "never silently do nothing": an empty plan is a real answer
      // ("already packed"), and the user gets told rather than watching the
      // menu close on nothing. A torn-down gesture is prefixed rather than
      // dropped — the preview did NOT open here, so "…— the compaction
      // preview opened" would be a false explanation.
      final prefix = cancelled == null ? '' : '$cancelled cancelled. ';
      _status.show(
        '${prefix}Nothing to compact on the ${_face.name} face of '
        '${_rack.designator}.',
      );
      return;
    }
    if (cancelled != null) {
      // Named by what REPLACED it, which is the one phrasing that reads
      // correctly for every value `cancelled` can take — including
      // 'Compaction preview', where "…— the compaction preview opened" would
      // have been a sentence about itself.
      final label = direction == CompactDirection.down ? 'Down' : 'Up';
      _status.show('$cancelled cancelled — Compact $label previewed instead.');
    }
    // The canvas must own focus for `Enter`/`Esc` to reach this screen's
    // own bindings — otherwise a focused palette row would claim `Enter`
    // for its own place-this-device handler while the bar sat there
    // apparently offering to Apply.
    _canvasFocus.requestFocus();
    setState(() {}); // dim the moving devices (§3.6's "25%").
  }

  /// §3.6: "Enter applies as one undo entry." Displacements only — a
  /// compaction never changes the rack itself, so there is no height command
  /// to order against (that ordering constraint belongs to §4.1's shrink
  /// path, which is pass 3).
  void _applyCompaction() {
    final plan = _compaction.plan;
    if (plan == null) return;

    // selectionBefore for the undo entry = the live selection (docs/03
    // §4.4); a compaction leaves the selection unchanged, so selectionAfter
    // matches — the same convention the move-drag commit and the keyboard
    // nudge already use.
    _controller.selection = _selection.snapshot();
    _applyingCompaction = true;
    try {
      _controller.transact(LabelKey.compactRack, (tx) {
        for (final c in compactionCommands(
          plan,
          now: _controller.clock.nowUtc(),
          actor: _controller.actor,
        )) {
          tx.add(c);
        }
      });
    } finally {
      // A `finally` rather than a trailing assignment: if a command throws,
      // `transact` rolls back and rethrows, and a latch left stuck true
      // would permanently disable the stale-plan guard for the rest of the
      // session.
      _applyingCompaction = false;
    }

    final freed = plan.freedU;
    final n = plan.moves.length;
    _compaction.cancel();
    _status.show(
      'Compacted ${_rack.designator}: '
      '${n == 1 ? '1 device' : '$n devices'} moved, ${freed}U freed.',
    );
    setState(() {});
  }

  /// §3.6: "Esc cancels." No command, no document mutation.
  void _cancelCompaction() {
    if (!_compaction.isActive) return;
    _compaction.cancel();
    setState(() {});
  }

  // ── rack configuration (docs/04 §4) ───────────────────────────────────

  /// The rack header's overflow menu (docs/04 §3.6's compaction affordance
  /// and §4's third inspector entry point).
  void _onRackHeaderAction(RackHeaderAction action) {
    switch (action) {
      case RackHeaderAction.compactDown:
        _beginCompaction(CompactDirection.down);
      case RackHeaderAction.compactUp:
        _beginCompaction(CompactDirection.up);
      case RackHeaderAction.rackSettings:
        _showRackInspector();
      case RackHeaderAction.newRack:
        unawaited(_showNewRackDialog());
    }
  }

  /// Every rack in the document, in the order the elevation sheets will
  /// print them — `SheetSet.forRacks`' comparator exactly (`Rack.order`,
  /// ties broken by id), restated here rather than approximated with map
  /// iteration order so the switcher's list and the PDF's sheet order
  /// cannot disagree.
  List<RackChoice> get _rackChoices {
    final racks = _doc.racks.values.toList()
      ..sort((a, b) {
        final byOrder = a.order.v.compareTo(b.order.v);
        return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
      });
    return [
      for (final r in racks) (id: r.id, designator: r.designator, name: r.name),
    ];
  }

  // ── which rack is being edited (docs/04 §9's New-rack dialog) ─────────

  /// Makes [id] the rack this canvas edits.
  ///
  /// EVERY LIVE PREVIEW DIES FIRST, for the same reason `_cycleFace` tears
  /// them down: a compaction plan, a move drag and a resize drag all hold
  /// positions captured against a DIFFERENT rack, and applying one after
  /// the switch would move devices the user was shown no preview of. The
  /// selection is cleared for the same reason it is not carried across a
  /// face change — a selected device that is not on this elevation has no
  /// chrome to draw and no nudge that means anything.
  void _switchRack(Uuid id, {bool announce = true}) {
    if (!_doc.racks.containsKey(id)) return;
    final was = _activeRackId;
    _invalidateLivePreviews();
    _activeRackId = id;
    _selection.clear();
    // The caret re-seeds itself on a rack change (`CaretController.recompute`
    // compares `caret.rackId` to the rack it is given), so this is the whole
    // of the caret's migration.
    _recomputeCaret();
    _inspectorTarget = InspectorTarget.selection;
    if (announce && was != id) {
      _status.show('Editing ${_rack.designator} — ${_rack.name}.');
    }
    if (mounted) setState(() {});
  }

  /// docs/04 §9's New-rack dialog, reached by `Ctrl+Alt+N` (§8's keymap) or
  /// the rack header's overflow menu.
  ///
  /// The command is built and run by [showNewRack] — the ONE rack-creation
  /// path, shared with the app shell's rack-less panel. All this method
  /// adds is what a CANVAS owes afterwards: show the rack that was just
  /// created, because a Create that leaves the old rack on screen is a
  /// button whose result is invisible.
  Future<void> _showNewRackDialog() async {
    final outcome = await showNewRack(
      context: context,
      controller: _controller,
      presets: _presets,
    );
    if (!mounted) return;
    switch (outcome) {
      case NewRackCreated(:final command):
        _switchRack(command.id, announce: false);
        _status.show(
          'Created ${command.designator} — ${command.name}, '
          '${command.heightU}U.',
        );
      case NewRackCancelled():
        break; // Cancel really is nothing at all.
      case NewRackRefused(:final reason):
        _status.show(reason);
    }
  }

  /// Opens the `RackInspector` (§4's three entry points all land here).
  void _showRackInspector({bool focusFirstField = false}) {
    setState(() => _inspectorTarget = InspectorTarget.rack);
    if (focusFirstField) {
      // After the frame that actually builds the panel — the focus node has
      // no attached widget until then.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _inspectorFirstFieldFocus.requestFocus();
      });
    }
  }

  /// One `SetEntityPropertyCommand` per inspector edit — or nothing at all
  /// when the value is unchanged, which `buildSetEntityProperty` reports by
  /// returning null so a no-op never pushes an empty undo entry (§3.4's
  /// "never silently do nothing" read in the other direction: an edit that
  /// changed nothing should not LOOK like it did).
  void _setRackProperty<T>(EntityField<Rack, T> field, T value) {
    final command = buildSetEntityProperty<Rack, T>(
      doc: _doc,
      id: _rack.id,
      field: field,
      to: value,
      now: _controller.clock.nowUtc(),
      actor: _controller.actor,
    );
    if (command == null) return;
    _controller.selection = _selection.snapshot();
    _controller.run(command);
  }

  /// Sets `lifecycleStatus` on every SELECTED device as ONE undo entry
  /// (board M3-A/7).
  ///
  /// The whole selection, not the focused device: the control sits under
  /// "5 devices selected", and one that edited one of the five would be a
  /// trap. `buildSetEntityProperty` returns null for a device already in
  /// that state, so a mixed selection changes only the ones that differ
  /// and a uniform one produces no transaction at all rather than an empty
  /// undo entry (§3.4 read the other way: an edit that changed nothing
  /// should not LOOK like it did).
  void _setSelectionLifecycle(LifecycleStatus status) {
    final commands = [
      for (final id in _selection.ids)
        if (_doc.devices.containsKey(id))
          if (buildSetEntityProperty(
                doc: _doc,
                id: id,
                field: DeviceField.lifecycleStatus,
                to: status,
                now: _controller.clock.nowUtc(),
                actor: _controller.actor,
              )
              case final command?)
            command,
    ];
    if (commands.isEmpty) return;
    _controller.selection = _selection.snapshot();
    _controller.transact(LabelKey.setEntityProperty, (tx) {
      for (final command in commands) {
        tx.add(command);
      }
    });
  }

  /// §3's `Width position`, on every rail-placed device in the selection
  /// (CR-030, `#269`).
  ///
  /// GOES THROUGH `planSetDeviceWidth` RATHER THAN BUILDING THE COMMAND,
  /// which is the whole point of `PLC-002` having a writer at last. The
  /// dropdown offers only CR-030's three positions, so the LATERAL rule
  /// cannot refuse anything picked here; `PLC-001` still can, because a
  /// device sitting outside its rack (reachable by import or a hand
  /// edit, DR-112) may not have any placement written for it until it is
  /// back inside.
  ///
  /// A REFUSED DEVICE IS SKIPPED AND SAID OUT LOUD, on docs/04 §3.4's
  /// rule that a refusal never silently stops. The rest of the selection
  /// still moves: holding back four legal edits because a fifth device is
  /// out of bounds would punish the user for a fault they did not make
  /// here and cannot see from this control.
  void _setSelectionWidth(WidthPosition position) {
    final commands = <SetDeviceWidthCommand>[];
    String? refusal;
    for (final id in _selection.ids) {
      if (!_doc.devices.containsKey(id)) continue;
      final planned = planSetDeviceWidth(
        doc: _doc,
        id: id,
        startTwelfth: position.startTwelfth,
        spanTwelfths: position.spanTwelfths,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      );
      switch (planned) {
        case WidthChangeReady(:final command):
          commands.add(command);
        case WidthChangeRefused(:final reason):
          refusal ??= reason;
      }
    }
    if (refusal != null) _status.show(refusal);
    if (commands.isEmpty) return;
    _controller.selection = _selection.snapshot();
    _controller.transact(LabelKey.setDeviceWidth, (tx) {
      for (final command in commands) {
        tx.add(command);
      }
    });
  }

  /// DR-130 (`#839`): writes `OffRackPlacement.mountNote` on the one
  /// selected off-rack device.
  ///
  /// NOT WRAPPED IN A TRANSACTION, for `_setDeviceOverride`'s reason
  /// below: the control renders only for a single off-rack selection, so
  /// a transaction around one command adds an undo frame that says
  /// nothing.
  ///
  /// THE COMMAND ITSELF COLLAPSES THE KEYSTROKES. `SetMountNoteCommand`
  /// declares a `mergeKey` over the device id, so typing a sentence is
  /// one undo entry rather than one per character. That is why the field
  /// can afford to commit on every change instead of on submit, which
  /// loses the note when the panel is dismissed by clicking away.
  /// Runs a planned 0U channel edit, or shows its refusal (`#876`,
  /// DR-163 §11.162.3).
  ///
  /// **THE PLANNER DECIDED, THIS ONLY DISPATCHES.** Both outcomes are its
  /// words: a `ZeroURefused` carries a sentence naming the rack, the
  /// numbers, or the occupant that is in the way, and printing it
  /// unchanged is what docs/04 §3.4's "never silently do nothing" asks
  /// for.
  void _runZeroU(ZeroUResult result) {
    switch (result) {
      case ZeroUReady(:final command):
        _controller.run(command);
      case ZeroURefused(:final reason):
        _status.show(reason);
    }
  }

  /// Moves a 0U occupant to [channelId] at [startU] (`#876`).
  ///
  /// **THE SIGNATURE COMES FROM THE SESSION**, which is `#879`'s lesson:
  /// `planSetZeroUPosition` records who moved the device and when, and a
  /// surface that invented either would write a signature that is not the
  /// person's. The section hands over three plain values for that reason.
  ///
  /// The channel lookup here is not a second validation: it is what turns
  /// a START U into the `Len` the model stores, and it CANNOT be done
  /// without the channel. A missing one is a stale panel rather than a
  /// refusable edit, so it says so and stops.
  void _moveZeroUOccupant(Uuid deviceId, String channelId, int startU) {
    final placement = _doc.devices[deviceId]?.placement;
    if (placement is! ZeroUPlacement) return;
    final rack = _doc.racks[placement.rackId];
    ZeroUChannel? channel;
    for (final c in rack?.zeroUChannels ?? const <ZeroUChannel>[]) {
      if (c.id == channelId) channel = c;
    }
    if (channel == null) {
      _status.show('That rack has no 0U channel "$channelId".');
      return;
    }
    _runZeroU(
      planSetZeroUPosition(
        doc: _doc,
        id: deviceId,
        channelId: channelId,
        offsetFromChannelStart: zeroUOffsetFor(channel, startU),
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      ),
    );
  }

  /// Sets how far a 0U occupant runs, or clears it to UNKNOWN (`#883`,
  /// DR-166 §11.165.1).
  ///
  /// **TWO PLAIN VALUES AND A SIGNATURE FROM THE SESSION**, on
  /// `_moveZeroUOccupant`'s reasoning: `planSetZeroUSpan` records who
  /// resized the device and when, and a panel that invented either would
  /// write a signature that is not the person's.
  ///
  /// The U-to-`Len` conversion happens HERE and not in the row, because
  /// the model stores a length and the field edits rack units: one place
  /// does that arithmetic, the same way `zeroUOffsetFor` does it for the
  /// start.
  void _resizeZeroUOccupant(Uuid deviceId, int? spanU) {
    _runZeroU(
      planSetZeroUSpan(
        doc: _doc,
        id: deviceId,
        span: spanU == null ? null : kRackUnit * spanU,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      ),
    );
  }

  /// Puts [catalogId] into this rack's channel [channelId] (`#884`,
  /// DR-164 §11.163).
  ///
  /// **THE OCCUPANT LANDS AT THE CHANNEL START** (§11.163.3), not at a
  /// first free offset. A 0U occupant has no extent anywhere in the
  /// format, which `zero_u_commands.dart` records as a known model gap, so
  /// there is no overlap to compute and "free" has no meaning here. The
  /// person retypes the start U on the row the placement produces.
  ///
  /// **AND IT DOES NOT GO THROUGH `_finalizeCatalogPlacement`**
  /// (§11.163.4), which every other placement on this screen does. That
  /// method requests CANVAS FOCUS and makes the placed device the sole
  /// selection in one breath, and pairing those here would aim the
  /// keyboard at the canvas with a device the elevation never draws
  /// selected (`#883`). `Delete` is the sharp end: `_deleteSelection`
  /// removes an unwired device with no confirmation at all, so the next
  /// keystroke would destroy something nobody can see.
  ///
  /// **THE FIRST VERSION OF THIS COMMENT GAVE THE WRONG REASON.** It said
  /// selecting would swap the inspector to a device panel. It would not:
  /// `_inspectorTarget` is moved by canvas gestures and never by
  /// `_selection.apply`. A mutation found it, because the case asserting
  /// the panel stayed passed with the mutation applied.
  void _addZeroUOccupant(String channelId, String catalogId) {
    ZeroUChannel? channel;
    for (final c in _rack.zeroUChannels) {
      if (c.id == channelId) channel = c;
    }
    if (channel == null) {
      // A STALE PANEL RATHER THAN A REFUSABLE EDIT, on
      // `_moveZeroUOccupant`'s reasoning: the channel is gone from under
      // an open dialog, so there is nothing to refuse and nothing to
      // place.
      _status.show('That rack has no 0U channel "$channelId".');
      return;
    }
    final result = buildPlaceFromCatalogCommand(
      doc: _doc,
      catalogId: catalogId,
      targetRack: _rack,
      now: _controller.clock.nowUtc(),
      actor: _controller.actor,
      // VERTICAL, because a 0U channel is a vertical rail and the one 0U
      // archetype that ships is a vertical PDU. `ZeroUOrientation` exists
      // for a horizontal occupant in a channel and nothing in v1 produces
      // one; when something does, it is a control on this picker rather
      // than a guess made here.
      zeroU: (
        channelId: channelId,
        offsetFromChannelStart: const Len(0),
        orientation: ZeroUOrientation.vertical,
      ),
    );
    switch (result) {
      case CatalogPlacementReady(:final command):
        _controller.run(command);
        _status.show(
          'Placed ${command.designator} in ${zeroUChannelLabel(channel)}.',
        );
      case CatalogPlacementFailed(:final reason):
        _status.show(reason);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // THE STAGING BIN (DR-205, CR-032, `#961`)
  // ═══════════════════════════════════════════════════════════════════
  // The bin is a query over the document (`stagedDevices`), so there is
  // nothing here to keep in step: the strip is rebuilt from the document
  // like every other surface on this screen.

  /// The strip's chips, each with the return it offers or why it cannot.
  List<StagedChip> _stagedChips() => [
    for (final d in stagedDevices(_doc)) _stagedChipFor(d),
  ];

  StagedChip _stagedChipFor(DeviceInstance d) {
    final body = bodyFor(d, _doc.templates);
    final h = body == null ? 0 : math.max(body.frontU, body.rearU);
    final plan = planReturnFromStaging(
      doc: _doc,
      id: d.id,
      now: _controller.clock.nowUtc(),
      actor: _controller.actor,
    );
    return StagedChip(
      id: d.id,
      designator: d.designator,
      heightLabel: h > 0 ? '${h}U' : '',
      returnLabel: switch (plan) {
        // CR-032's own words. It was `↩ RK-1 U21` for one gate run, and
        // the glyph gate refused it: `↩` is not in the bold weight.
        PlacementPlanReady(:final command) =>
          'Return to ${_whereLabel(command.to)}',
        PlacementPlanRefused() => null,
      },
      returnRefusal: switch (plan) {
        PlacementPlanRefused(:final reason) => reason,
        PlacementPlanReady() => null,
      },
    );
  }

  /// `RK-1 U21`, or the shelf's designator, for a return chip and for the
  /// status line after one is pressed.
  String _whereLabel(Placement to) => switch (to) {
    RailPlacement(:final rackId, :final ruIndex) =>
      '${_doc.racks[rackId]?.designator ?? 'rack'} U$ruIndex',
    ShelfPlacement(:final hostDeviceId) =>
      _doc.devices[hostDeviceId]?.designator ?? 'its shelf',
    _ => 'its place',
  };

  /// `U`: every selected device to the bin, in ONE undo entry.
  void _stageSelection() {
    final now = _controller.clock.nowUtc();
    final ready = <ReplacePlacementCommand>[];
    String? refusal;
    for (final id in _selection.ids) {
      switch (planStageDevice(
        doc: _doc,
        id: id,
        now: now,
        actor: _controller.actor,
      )) {
        case PlacementPlanReady(:final command):
          ready.add(command);
        case PlacementPlanRefused(:final reason):
          refusal ??= reason;
      }
    }
    if (ready.isEmpty) {
      if (refusal != null) _status.show(refusal);
      return;
    }
    _controller.transact(LabelKey.stageDevice, (tx) {
      for (final command in ready) {
        tx.add(command);
      }
    });
    final what = ready.length == 1
        ? (_doc.devices[ready.single.id]?.designator ?? 'The device')
        : '${ready.length} devices';
    _status.show(
      '$what sent to the Staging Bin, wiring kept. Ctrl+Z to undo.',
    );
  }

  /// The staging commands for a Shrink Rack decision (DR-205 §11.204.6).
  ///
  /// A refusal here is unreachable, because the dialog offers the bin only
  /// when `binRefusals` is empty, and it is DROPPED rather than thrown: the
  /// device then stays on the rail above the new top, which the load
  /// gutter counts as undrawn. That is a visible state, where a throw
  /// halfway through the transaction would be a crash.
  List<ReplacePlacementCommand> _stageCommands(List<Uuid> ids) => [
    for (final id in ids)
      if (planStageDevice(
            doc: _doc,
            id: id,
            now: _controller.clock.nowUtc(),
            actor: _controller.actor,
          )
          case PlacementPlanReady(:final command))
        command,
  ];

  void _returnFromStaging(Uuid id) {
    switch (planReturnFromStaging(
      doc: _doc,
      id: id,
      now: _controller.clock.nowUtc(),
      actor: _controller.actor,
    )) {
      case PlacementPlanReady(:final command):
        _controller.run(command);
        _status.show(
          'Returned ${_doc.devices[id]?.designator ?? 'the device'} to '
          '${_whereLabel(command.to)}.',
        );
      case PlacementPlanRefused(:final reason):
        _status.show(reason);
    }
  }

  /// A chip dragged onto the rails and released on a free U (`#964`). The
  /// planner re-runs the checks the live drag just showed, as a palette
  /// release does, so a same-frame edit is refused in words rather than
  /// overlapped.
  void _placeStagedOnRail(Uuid id, int ruIndex, Face face) {
    switch (planPlaceStagedOnRail(
      doc: _doc,
      id: id,
      rack: _rack,
      ruIndex: ruIndex,
      face: face,
      now: _controller.clock.nowUtc(),
      actor: _controller.actor,
    )) {
      case PlacementPlanReady(:final command):
        _controller.run(command);
        _selection.apply([id], SelectMode.replace);
        _status.show(
          'Placed ${_doc.devices[id]?.designator ?? 'the device'} at '
          '${_whereLabel(command.to)}, ${face.name}, wiring kept.',
        );
      case PlacementPlanRefused(:final reason):
        _status.show(reason);
    }
  }

  /// A chip click selects the device, as a click on the rack would.
  void _selectStaged(Uuid id) {
    _selection.apply([id], SelectMode.replace);
    if (_inspectorTarget != InspectorTarget.selection) {
      setState(() => _inspectorTarget = InspectorTarget.selection);
    }
  }

  void _setMountNote(String note) {
    final id = _soleSelectedDeviceId;
    if (id == null) return;
    final planned = planSetMountNote(
      doc: _doc,
      id: id,
      note: note,
      now: DateTime.now().toUtc(),
      actor: _controller.actor,
    );
    switch (planned) {
      case MountNoteReady(:final command):
        _controller.run(command);
      case MountNoteRefused(:final reason):
        _status.show(reason);
    }
  }

  /// The one selected device, or null when the selection is not exactly
  /// one that still exists. The mount-note control renders on the same
  /// condition, so this agreeing with it is what keeps the callback from
  /// writing to a device the user is not looking at.
  Uuid? get _soleSelectedDeviceId {
    final live = [
      for (final id in _selection.ids)
        if (_doc.devices.containsKey(id)) id,
    ];
    return live.length == 1 ? live.single : null;
  }

  /// Door 1: one override field on the ONE selected device (CR-054,
  /// DR-098 §11.97.5).
  ///
  /// NOT WRAPPED IN A TRANSACTION, unlike `_setSelectionLifecycle` above,
  /// and the difference is the scope rather than an inconsistency. That
  /// one edits every selected device and wraps N commands so the Edit menu
  /// offers one thing to undo. This edits exactly one device by
  /// construction, since the section renders only for a single selection,
  /// so a transaction around a single command would add an undo frame that
  /// says nothing.
  ///
  /// `buildSetEntityProperty` returns null when the value is unchanged,
  /// which is what keeps re-pressing the segment already lit out of the
  /// undo stack.
  void _setDeviceOverride<T>(
    EntityField<DeviceInstance, OverrideValue<T>> field,
    OverrideValue<T> value,
  ) {
    final ids = [
      for (final id in _selection.ids)
        if (_doc.devices.containsKey(id)) id,
    ];
    if (ids.length != 1) return;
    final command = buildSetEntityProperty(
      doc: _doc,
      id: ids.single,
      field: field,
      to: value,
      now: _controller.clock.nowUtc(),
      actor: _controller.actor,
    );
    if (command == null) return;
    _controller.selection = _selection.snapshot();
    _controller.run(command);
  }

  /// M4-L4 (`#233`): one fact on one port of one device.
  ///
  /// THE DESIGNATOR IS ALLOCATED HERE AND HANDED OVER, because the command
  /// materialises inside `apply` and must not allocate there (DR-011.1).
  /// The section reads it off `ConnectTarget.plannedDesignator`, which is
  /// the same number the connect gesture would have written.
  void _setPortFact(
    Uuid deviceId,
    PortKey portKey,
    PortFactField field,
    Object? value,
    String designatorIfMaterialised,
  ) {
    _controller.selection = _selection.snapshot();
    _controller.run(
      SetPortFactCommand(
        deviceId: deviceId,
        portKey: portKey,
        field: field,
        value: value,
        designatorIfMaterialised: designatorIfMaterialised,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      ),
    );
  }

  /// Rebuilds so the inspector's Height field re-reads the rack's real
  /// height, whatever its own buffer currently says.
  ///
  /// A REBUILD IS THE WHOLE MECHANISM, and that is the point.
  /// `_InspectorTextField` already re-reads the model in `didUpdateWidget`
  /// — the re-sync that stops an undo from leaving the panel displaying a
  /// value the document no longer holds. What it cannot do is run when
  /// nothing rebuilds, and TWO height paths resolve without committing
  /// anything:
  ///
  ///  * §4.1's modal, CANCELLED — no command, no epoch bump, no rebuild
  ///    anywhere. The buffer kept the rejected height, so the panel stated a
  ///    fact the document did not hold; and since a blur commits, the next
  ///    click anywhere re-fired `onRequestHeight` with it and re-opened the
  ///    modal the user had just cancelled. On a loop, until they manually
  ///    retyped the old value. Cancel has to leave zero trace.
  ///  * CR-038's clamp — the rack lands on 60 while the field says 99, and
  ///    the same blur loop follows.
  ///
  /// NO FOCUS OVERRIDE IS NEEDED, which is worth stating because it looks
  /// like it should be: this field opens the modal, so "still focused when
  /// the answer arrives" is the obvious worry. It cannot happen. The field's
  /// two commit paths are `_onFocusChanged` (fires ON focus loss) and
  /// `onSubmitted` — and `EditableText._finalizeEditing` calls
  /// `focusNode.unfocus()` BEFORE invoking `onSubmitted`, on every platform.
  /// So the field is always unfocused by the time this runs, and
  /// `didUpdateWidget`'s ordinary gate lets the re-sync through. An override
  /// was written for this and deleted again: no reachable scenario could
  /// kill a mutation that removed it.
  void _resyncInspectorHeight() {
    if (!mounted) return;
    setState(() {});
  }

  /// `name` is the one rack identity field that already had a command
  /// before this stage — reused unchanged rather than duplicated into the
  /// `RackField` table.
  void _renameRack(String name) {
    if (name == _rack.name) return;
    _controller.selection = _selection.snapshot();
    _controller.run(
      RenameEntityCommand(
        targetKind: RenameTargetKind.rack,
        id: _rack.id,
        from: _rack.name,
        to: name,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      ),
    );
  }

  /// THE ONE HEIGHT FUNNEL (docs/04 §4.1: "Three ways to set height, ALL
  /// producing one ResizeRackCommand"). ALL FOUR entry points call this and
  /// nothing else, which is what makes it structurally impossible for any
  /// path to shrink past occupancy without §4.1's modal:
  ///
  ///  1. the header stepper's 400ms-then-8/s hold-repeat (`_stepHeight`);
  ///  2. the inspector field, committing on blur or Enter;
  ///  3. the drag-the-top-edge gesture's commit (`_onCommitDrag`);
  ///  4. applying a rack preset (`_applyPreset`), whose height is not
  ///     exempt just because it arrived with eight other fields.
  ///
  /// SHRINK-BELOW-OCCUPANCY OPENS THE MODAL (§4.1: "never destroy, never
  /// silently move, always name the casualties"). Pass 2 REFUSED here and
  /// said so on the status line, which honoured the first two clauses and as
  /// much of the third as one line can; this pass replaces that branch with
  /// the real conversation. Note what did NOT change: this method still
  /// never silently clamps to `smallestFittingHeightU`. Taking a height the
  /// user did not ask for is a decision only the user gets to make, and now
  /// the modal is where they make it.
  ///
  /// Growing is always safe (§4.1: "new U appear at the top and existing
  /// ruIndex values are untouched"), so it never reaches the modal — a grow
  /// yields an empty `doomed` list from the planner without a special case.
  _HeightOutcome _requestHeight(int target, {RackPreset? preset}) {
    final clamped = target.clamp(1, kMaxRackHeightU); // CR-038
    if (clamped == _rack.heightU) {
      // A genuine no-op as far as the DOCUMENT is concerned — the value
      // already IS what was asked for. Silent on purpose: §3.4's "never
      // silently do nothing" is about REFUSING an action, and nothing was
      // refused here. (The stepper cannot reach this at all: its buttons
      // disable at the bounds.)
      //
      // NOT a no-op for the inspector, though, and this is the one outcome
      // where that matters. Typing `99` at a rack already sitting at CR-038's
      // 60U clamps to 60, finds 60 == 60, and runs no command — so nothing
      // rebuilds, the buffer keeps saying `99`, and the next blur commits it
      // again, reporting "clamped to 60U" forever. The two OTHER outcomes
      // need no such call: an applied height bumps an epoch and rebuilds on
      // its own, and the modal re-syncs when it resolves. Verified by
      // mutation — a resync here is killable, one on the applied path is not.
      _resyncInspectorHeight();
      return _HeightOutcome.unchanged;
    }

    final plan = planRackShrink(
      doc: _doc,
      rackId: _rack.id,
      toHeightU: clamped,
    );

    if (!plan.hasCasualties) {
      _controller.selection = _selection.snapshot();
      if (preset != null) {
        _runPresetTransaction(preset, toHeightU: clamped, moves: const []);
      } else {
        _controller.run(
          SetRackHeightCommand(
            id: _rack.id,
            fromHeightU: _rack.heightU,
            toHeightU: clamped,
            now: _controller.clock.nowUtc(),
            actor: _controller.actor,
          ),
        );
      }
      return _HeightOutcome.applied;
    }

    // See `_shrinkDialogOpen`: one modal at a time, whatever is generating
    // the requests.
    if (!_shrinkDialogOpen) {
      _shrinkDialogOpen = true;
      unawaited(_openShrinkDialog(clamped, preset: preset));
    }
    return _HeightOutcome.deferredToModal;
  }

  /// docs/04 §4.1's modal, and rule 6's single undo entry.
  ///
  /// The dialog DECIDES (it pops a `ShrinkDecision`: a height and a list of
  /// displacements); this method is what turns that into commands, because
  /// running commands is the screen's job everywhere else in this file and
  /// making the dialog an exception would put document mutation somewhere a
  /// reader would not look for it.
  Future<void> _openShrinkDialog(int target, {RackPreset? preset}) async {
    try {
      final decision = await showDialog<ShrinkDecision>(
        context: context,
        builder: (_) => ShrinkRackDialog(
          doc: _doc,
          rackId: _rack.id,
          requestedHeightU: target,
        ),
      );
      // Cancel / `Esc` / a barrier tap: no command, no mutation, and the
      // rack keeps the height it had. The `finally` below is what makes
      // "keeps the height it had" true on SCREEN as well as in the document
      // — see `_resyncInspectorHeight`.
      if (decision == null || !mounted) return;

      // CR-038, as a BACKSTOP. `resolveShrink` already clamps every height
      // it returns (shrink_rack_dialog.dart's `_withinBounds`, which is
      // where it belongs — the tile has to SHOW the same number Apply
      // USES). This second clamp is not redundancy for its own sake: this
      // is the one place a popped `ShrinkDecision` becomes a command, and
      // `SetRackHeightCommand` does not clamp while `Rack.heightU`'s setter
      // asserts `[1, 60]`, so the conversion states the bound itself rather
      // than trusting a value that arrived from a dialog.
      final toHeightU = decision.toHeightU.clamp(1, kMaxRackHeightU);

      _controller.selection = _selection.snapshot();
      if (preset != null) {
        _runPresetTransaction(
          preset,
          toHeightU: toHeightU,
          moves: decision.moves,
          staged: decision.staged,
        );
      } else {
        // RULE 6, verbatim: "Apply is ONE undo entry covering the resize and
        // every displacement." ORDER MATTERS — every displacement first, the
        // height change LAST, so no intermediate state has an occupant
        // standing above the rack top. `Transaction.revert` runs children in
        // REVERSE, so undo restores the height before the positions, which
        // is the correct unwinding of exactly that ordering.
        _controller.transact(LabelKey.resizeRack, (tx) {
          // STAGED FIRST (DR-205 §11.204.6): it frees the U the casualties
          // held before anything moves into them, and a staged device is
          // no longer rail-placed, so no displacement below can name one.
          _stageCommands(decision.staged).forEach(tx.add);
          for (final c in shrinkDisplacementCommands(
            decision.moves,
            now: _controller.clock.nowUtc(),
            actor: _controller.actor,
          )) {
            tx.add(c);
          }
          // NO PHANTOM UNDO ENTRY, the same guard `_runPresetTransaction`
          // has always had on its own height write. Two of §4.1's options
          // legitimately resolve to the height the rack ALREADY has —
          // `keepSmallest` whenever the tallest occupant already reaches the
          // rack top (or a bottom trim whose lowest occupant sits at U1),
          // and `compactFirst` whenever the rescue is only partial. Adding
          // the command anyway pushed a `SetRackHeightCommand(N -> N)`:
          // `DocumentController._commit` only skips a push for an EMPTY
          // child list, so the document went dirty and gained an undo entry
          // whose Ctrl+Z visibly does nothing — for the one option the user
          // chose precisely because it changes nothing. With this guard AND
          // an empty `moves` list the transaction has no children at all, so
          // `_commit` skips it outright; `decision.summary` still reports,
          // so the choice is acknowledged rather than swallowed.
          if (toHeightU != _rack.heightU) {
            tx.add(
              SetRackHeightCommand(
                id: _rack.id,
                fromHeightU: _rack.heightU,
                toHeightU: toHeightU,
                now: _controller.clock.nowUtc(),
                actor: _controller.actor,
              ),
            );
          }
        });
      }
      _status.show(decision.summary);
    } finally {
      // A `finally` rather than a trailing assignment: a latch left stuck
      // true would permanently disable every future height change on this
      // screen.
      _shrinkDialogOpen = false;
      // EVERY resolution, including Cancel and including an Apply that
      // chose a height other than the one typed. The modal is the one path
      // where the inspector's buffer can outlive the request that came from
      // it — see `_resyncInspectorHeight` for the full mechanism.
      _resyncInspectorHeight();
    }
  }

  /// docs/04 §4: applying a preset is a fan-out of writes to ordinary
  /// `Rack` fields (a rack has no `presetRef` — see rack_presets.dart), so
  /// it is N `SetEntityPropertyCommand`s plus one `SetRackHeightCommand` in
  /// ONE `Transaction`, giving one undo entry.
  ///
  /// ATOMIC OR NOTHING, and the height goes through the SAME funnel as every
  /// other height change. Pass 2 refused a preset outright when its height
  /// would displace occupants — applying the eight other fields and quietly
  /// skipping the height would leave the rack claiming to be a "Wall box 6U"
  /// at 12U, the exact partial state the one-undo-entry requirement exists to
  /// prevent. This pass keeps the atomicity and replaces the refusal with
  /// §4.1's modal: `_requestHeight` decides, and either outcome still lands
  /// as ONE transaction containing the property writes AND the height.
  ///
  /// A CONSEQUENCE WORTH STATING: if the user resolves that modal with
  /// "keep at the smallest that fits", the rack ends up carrying the
  /// preset's other properties at a height the preset does not name. That is
  /// an informed choice, not a silent partial — they were shown the
  /// requested height, the casualties and the alternative before choosing —
  /// and the inspector's Preset dropdown immediately reads "Custom",
  /// because `matchingPresetId` compares heightU too. The rack never claims
  /// to be something it is not.
  void _applyPreset(RackPreset preset) {
    final targetHeight = preset.heightU.clamp(1, kMaxRackHeightU); // CR-038
    if (targetHeight != _rack.heightU) {
      // The funnel runs the whole transaction (properties + height) on the
      // safe path, and hands `preset` to the modal on the shrink path so the
      // eventual Apply carries the property writes with it.
      final outcome = _requestHeight(targetHeight, preset: preset);
      if (outcome != _HeightOutcome.applied) return;
      _status.show('Applied ${preset.displayName} to ${_rack.designator}.');
      return;
    }
    // Same height already — nothing for the funnel to decide, so the
    // property writes stand alone.
    _controller.selection = _selection.snapshot();
    _runPresetTransaction(preset, toHeightU: null, moves: const []);
    _status.show('Applied ${preset.displayName} to ${_rack.designator}.');
  }

  /// The preset's property writes, plus any displacement and height change,
  /// as ONE `Transaction` — one undo entry however the height was resolved.
  ///
  /// [toHeightU] null means "the height is already right"; [moves] is
  /// non-empty only when §4.1's modal chose an option that displaces
  /// occupants, and is ordered before the height change for the same reason
  /// `_openShrinkDialog` orders its own.
  void _runPresetTransaction(
    RackPreset preset, {
    required int? toHeightU,
    required List<CompactionMove> moves,
    List<Uuid> staged = const [],
  }) {
    _controller.transact(LabelKey.applyRackPreset, (tx) {
      void set<T>(EntityField<Rack, T> field, T value) {
        final command = buildSetEntityProperty<Rack, T>(
          doc: _doc,
          id: _rack.id,
          field: field,
          to: value,
          now: _controller.clock.nowUtc(),
          actor: _controller.actor,
        );
        if (command != null) tx.add(command);
      }

      // Deliberately NOT every field: a preset states the facts that define
      // the archetype and never touches identity (name/designator/location)
      // or display preferences (ruNumbering/mirrorRearElevation). Picking
      // "Floor enclosure 27U" must not silently reset the user's RU
      // numbering.
      set(RackField.formFactor, preset.formFactor);
      set(RackField.widthClass, preset.widthClass);
      set(RackField.railType, preset.railType);
      set(RackField.usableDepth, preset.usableDepth);
      set(RackField.weightCapacity, preset.weightCapacity);
      set(RackField.isSwingFrame, preset.isSwingFrame);
      set(RackField.hingeSide, preset.hingeSide);

      // Staged before anything moves, as `_openShrinkDialog` orders it.
      _stageCommands(staged).forEach(tx.add);
      for (final c in shrinkDisplacementCommands(
        moves,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      )) {
        tx.add(c);
      }

      if (toHeightU != null && toHeightU != _rack.heightU) {
        tx.add(
          SetRackHeightCommand(
            id: _rack.id,
            fromHeightU: _rack.heightU,
            toHeightU: toHeightU,
            now: _controller.clock.nowUtc(),
            actor: _controller.actor,
          ),
        );
      }
    });
  }

  /// docs/04 §4.1's header stepper, way one. One tick of the hold-repeat.
  ///
  /// Returns whether the repeat may continue — false the instant a step
  /// stops taking effect, which is what stops a held `-` from opening a
  /// modal per tick as it ratchets down into occupied territory (see
  /// `_shrinkDialogOpen` and `RackHeightStep`).
  ///
  /// EACH TICK IS AN ORDINARY `_controller.run`, and that is the whole
  /// mechanism behind "a held stepper is ONE undo entry": `run` wraps its
  /// single child in a `Transaction`, `Transaction.mergeKey` forwards a lone
  /// child's key, `SetRackHeightCommand.mergeKey` is `(SetRackHeightCommand,
  /// id)`, and `UndoStack.mergeWindow` is 400ms against a 125ms tick — so
  /// the merge chain never lapses mid-hold. No new timing constant is
  /// introduced here, and none is needed.
  bool _stepHeight(int delta) =>
      _requestHeight(_rack.heightU + delta) == _HeightOutcome.applied;

  // ── the command-routed editing loop ───────────────────────────────────

  DeviceLayout? _layoutFor(String deviceId) {
    for (final layout in _rackScene?.devices ?? const <DeviceLayout>[]) {
      if (layout.deviceId.v == deviceId) return layout;
    }
    return null;
  }

  void _onBeginDrag(DPt sceneStart, Set<PointerDeviceKind> kinds) {
    // THE EXCLUSIVITY RULE, asked rather than restated (see that section):
    // the claim cancels an open compaction preview — which has no pointer,
    // so a canvas gesture may take the screen from it — and REFUSES
    // outright while a palette drag is live, since that gesture's pointer is
    // still down and re-initialising the per-drag fields below would orphan
    // its preview for the rest of the session.
    //
    // `_dragRefused` (not an early `return` alone) because
    // `CanvasIntentDetector` has already routed this pointer to us and will
    // keep delivering `updateDrag`/`commitDrag` for it; there is no way to
    // decline a gesture that detector owns.
    _dragRefused = false;
    if (!_claimPointerGesture(_PointerGesture.canvasDrag)) {
      _dragRefused = true;
      return;
    }
    // Take canvas focus so Del/undo/redo/Esc shortcuts land here, not on a
    // device's FocusableActionDetector (or nothing).
    _canvasFocus.requestFocus();
    _dragSourceKinds = kinds;
    _dragStartScene = sceneStart;
    _dragStartScale = _viewport.scale;
    _dragMoved = false;
    _dragCancelled = false;
    _resizeDrag = false;
    _dragModifierToggle =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // docs/04 §4.1's third way to change height, and it is tested BEFORE the
    // device hit-test so a resize can never also select or move a device.
    //
    // THE TRADE-OFF, stated rather than discovered: a device occupying the
    // topmost U shares its own top edge with the rack's, so the 8px band
    // wins there and that device becomes hard to grab along that one edge.
    // It is still grabbable across the whole rest of its body, and the rack
    // top edge has exactly one gesture while a device has several — so the
    // band goes to the interaction that has nowhere else to live.
    if (_isTopEdgeGrab(sceneStart)) {
      _resizeDrag = true;
      _dragDeviceId = null;
      _dragDeviceHeightU = 0;
      _dragPlacement = null;
      _dragChipDeviceId = null;
      return; // skip the hit-test entirely.
    }

    // CR-105's chip, tested before the device hit-test — see [_chipAt].
    // It does NOT return early: the press still selects the device it sits
    // on, because the chip is a corner of that device and a click there
    // that left the selection alone would read as the rack forgetting
    // what was just pressed.
    _dragChipDeviceId = _chipAt(sceneStart);

    final scene = _rackScene?.scene;
    // Nearest-hit against the CURRENT scene (draw/hit_test.dart) — device
    // bodies only this stage, so exact containment; a small tolerance would
    // matter once wires exist.
    final region = scene == null ? null : hitTest(scene, sceneStart);
    _dragDeviceId = region?.entityId;
    // CR-102's band begins on EMPTY CANVAS and nowhere else (DR-139
    // §11.138). The comment in `_commitDragBody` reserved this gesture and
    // called it deferred; this is where the deferral ends. A drag that hit
    // a device is a move or a click, and a canvas where both could start
    // would have to guess which from how far the pointer travelled.
    if (region == null) {
      _marqueeDrag = true;
      _marquee.begin(sceneStart);
    }
    _dragDeviceHeightU = 0;
    _dragPlacement = null;
    final layout = region == null ? null : _layoutFor(region.entityId);
    if (layout != null) {
      _dragDeviceStartTopY = layout.rect.top;
      _dragDeviceHeightU = (layout.rect.height / RackGeometry.unitsPerRu)
          .round();
    }

    // Decide ONCE, here, whether this gesture can become a move — the same
    // gate `_onCommitDrag` used to apply on its own at release time, hoisted
    // so the LIVE PREVIEW and the eventual commit are governed by one
    // condition rather than two that could drift. Move only a device that is
    // BOTH hit at grab time AND already selected; single-device move: if
    // several are selected, dragging one moves just that one (multi-device
    // drag remains deferred, docs/m1-implementation-log.md §3.3).
    final deviceId = _dragDeviceId;
    if (deviceId != null && _dragDeviceHeightU > 0) {
      final id = Uuid(deviceId);
      final placement = _doc.devices[id]?.placement;
      if (placement is RailPlacement && _selection.contains(id)) {
        _dragPlacement = placement;
      }
    }
  }

  void _onUpdateDrag(DPt sceneCurrent, DPt sceneDelta) {
    if (_dragRefused) return; // never claimed the screen; nothing is armed.
    if (_dragCancelled) return; // Esc already reverted this drag.
    if (!_dragMoved) {
      final dx = sceneCurrent.x - _dragStartScene.x;
      final dy = sceneCurrent.y - _dragStartScene.y;
      final movedScreenPx = math.sqrt(dx * dx + dy * dy) * _dragStartScale;
      if (movedScreenPx < _clickSlopPx) return;
      // docs/04 §3.3 step 1: "Grab the body; 4 px threshold." Only NOW does
      // the source device fade and the ghost appear — below the threshold
      // this is still potentially a click ("a click still means show
      // details"). The resize preview arms on the SAME threshold, so a click
      // on the rack's top edge stays a click.
      _dragMoved = true;
      if (_resizeDrag) {
        _armResizePreview();
      } else {
        _armMovePreview();
      }
    }
    if (_marqueeDrag) {
      // PAST THE SLOP, deliberately: this line sits below the threshold
      // check above, so a click on bare canvas never flashes a band.
      _marquee.update(sceneCurrent);
      return;
    }
    if (_resizeDrag) {
      _updateResizePreview(sceneCurrent);
      return;
    }
    _updateMovePreview(sceneCurrent);
  }

  void _onCommitDrag(DPt sceneEnd) {
    // See [_dragCommitting]: the commands this method runs bump the document
    // sequence while the gesture still holds its claim, and the stale-state
    // guard must not read a gesture's own successful commit as the edit that
    // invalidated it. `try`/`finally` rather than a trailing assignment, for
    // the same reason `_applyCompaction` uses one: a command that throws
    // must not leave the latch stuck true and the guard permanently off.
    _dragCommitting = true;
    try {
      _commitDragBody(sceneEnd);
    } finally {
      _dragCommitting = false;
    }
  }

  void _commitDragBody(DPt sceneEnd) {
    if (_dragRefused) {
      // Nothing was armed for this pointer and nothing may be committed for
      // it — in particular NOT `_handleClick`, whose `_dragDeviceId` was
      // never populated, and not the resize teardown, which would tear down
      // the preview belonging to the gesture that refused this one.
      _resetDrag();
      return;
    }
    if (_dragCancelled) {
      // Esc already reverted; the pointer-up that finally arrives must not
      // resurrect the move (docs/04 §3.3 step 4) or the resize.
      _cancelResizePreview();
      _resetDrag();
      return;
    }
    if (_resizeDrag) {
      _commitResizeDrag(sceneEnd);
      _resetDrag();
      return;
    }
    final deviceId = _dragDeviceId;
    if (!_dragMoved) {
      _handleClick(deviceId);
    } else if (_moveDrag.isDragging) {
      _commitOrNoopMoveDrag(sceneEnd);
    } else if (_marqueeDrag) {
      // LEFT-DRAG-ON-EMPTY IS THE MARQUEE, and this branch is where the
      // comment that stood here said "deferred, docs/04 §3.5". A sweep
      // REPLACES the selection even when it caught nothing, which is what
      // makes dragging across bare canvas a deselect rather than a no-op
      // with a stuck band.
      // THE SCENE MAY BE NULL on a frame where nothing has been built,
      // and a `!` here would crash a gesture that is legal on an empty
      // rack. Ending the band regardless is what keeps it from sticking.
      final scene = _rackScene?.scene;
      if (scene == null) {
        _marquee.cancel();
      } else {
        final caught = _marquee.end(scene);
        _selection.apply(caught.map(Uuid.new).toList(), SelectMode.replace);
      }
    }
    // else — a drag on an unselected device: a no-op, and intentionally not
    // a gesture (select first, then drag).
    _resetDrag();
  }

  void _onCancelDrag() {
    if (_dragRefused) {
      _resetDrag(); // see `_onCommitDrag`: nothing of ours to tear down.
      return;
    }
    // A pointer-cancel (not an Esc): tear the live preview down with no
    // command and no lingering chip — nothing was released, so nothing was
    // attempted-and-refused.
    _cancelMoveDrag();
    _cancelResizePreview();
    _resetDrag();
  }

  /// THE ONE EXIT for a canvas gesture — reached from every `commitDrag`
  /// and `cancel` branch, which is why it is also where the exclusivity
  /// claim is released.
  void _resetDrag() {
    _dragDeviceId = null;
    _dragChipDeviceId = null;
    _dragDeviceHeightU = 0;
    _dragMoved = false;
    _dragCancelled = false;
    _dragRefused = false;
    _dragPlacement = null;
    _resizeDrag = false;
    // THE BAND DIES WITH THE GESTURE THAT MADE IT. Every path out of a
    // drag reaches here, including the early returns above `_commitDragBody`
    // that skip the commit branches entirely.
    _marqueeDrag = false;
    _marquee.cancel();
    _releasePointerGesture(_PointerGesture.canvasDrag);
  }

  void _handleClick(String? deviceId) {
    // CR-105, and it runs BEFORE the selection branches below rather than
    // instead of them: the chip is a corner of a device, so pressing it
    // selects that device AND signposts the schematic. The reveal is last
    // because the host may replace this screen's tab on the spot, and a
    // selection applied after that would land on a `State` that is on its
    // way out.
    final chip = _dragChipDeviceId;
    if (chip != null) {
      _selection.apply([chip], SelectMode.replace);
      if (_inspectorTarget != InspectorTarget.selection) {
        setState(() => _inspectorTarget = InspectorTarget.selection);
      }
      widget.onRevealInSchematic?.call(chip);
      return;
    }
    if (deviceId == null) {
      _selection.clear(); // click on empty canvas clears the selection
      // docs/04 §4's SECOND inspector entry point: "click the rack header or
      // its EMPTY BACKGROUND". Inside the rack body but not on a device is
      // that background; outside it is genuinely empty canvas and means
      // "deselect", nothing more. Tested against the existing `_geo` extent
      // rather than a new hit region — `rack_layer.dart` emits no hit
      // regions of its own, so there is nothing else to ask.
      final start = _dragStartScene;
      final insideRack =
          start.x >= 0 &&
          start.x <= _geo.rackWidth &&
          start.y >= 0 &&
          start.y <= _geo.rackHeight;
      setState(() {
        _inspectorTarget = insideRack
            ? InspectorTarget.rack
            : InspectorTarget.selection;
      });
      return;
    }
    // Clicking a device is what puts the inspector back on the selection —
    // the other half of §4's "REPLACES the Selection section".
    if (_inspectorTarget != InspectorTarget.selection) {
      setState(() => _inspectorTarget = InspectorTarget.selection);
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

  // ── CR-054's three doors, on the first right-click in the product ─────
  //
  // `onSecondaryTap` occurred ZERO times in this package before this. The
  // secondary button was being routed into `beginDrag` like any other, so a
  // right-press armed a marquee on empty canvas and a MOVE on a device;
  // CR-102 had already reserved it ("right-drag is reserved for the context
  // menu, which is a platform expectation on desktop") and nothing noticed
  // because nothing bound it. `CanvasIntentDetector` now consumes it.
  //
  // ON A DEVICE ONLY. docs/04 §5 also specifies an empty-U menu (`Insert
  // device…`, `Insert 1U blank`, and three more), and that is not this
  // task: offering a menu with one working row and four that are not built
  // is worse than offering none, and the empty-U menu has no board item yet.
  Future<void> _onSecondaryTap(DPt scene, Offset global) async {
    final built = _rackScene?.scene;
    final region = built == null ? null : hitTest(built, scene);
    final deviceId = region?.entityId;
    if (deviceId == null) return;

    final id = Uuid(deviceId);
    final device = _doc.devices[id];
    if (device == null) return;

    // SELECT IT FIRST, so the menu is unambiguous about its subject and so
    // door 1 has nothing left to do but return: the override section renders
    // for a single selection already (DR-098 §11.97.5).
    if (_inspectorTarget != InspectorTarget.selection) {
      setState(() => _inspectorTarget = InspectorTarget.selection);
    }
    _selection.apply([id], SelectMode.replace);
    _canvasFocus.requestFocus();

    final door = await showDeviceDoorsMenu(
      context: context,
      globalPosition: global,
      designator: device.designator,
    );
    if (door == null || !mounted) return;

    switch (door) {
      case DeviceDoor.thisDeviceOnly:
        // Nothing to run. The device is selected and the inspector is on
        // the selection, which IS door 1.
        break;
      case DeviceDoor.editTemplate:
        _openTemplateForEditing(device);
      case DeviceDoor.forkToNew:
        _forkToNewTemplate(device);
    }
  }

  /// Door 2. Routing lives in the app shell, which owns the six-view stack
  /// and the Device Manager's single draft, so this hands off rather than
  /// reaching across the layer.
  void _openTemplateForEditing(DeviceInstance device) {
    final open = widget.onEditTemplate;
    if (open == null) {
      // A HONEST REFUSAL RATHER THAN A DEAD ROW. `RackCanvasScreen` is
      // constructed directly in widget tests with no shell around it, and a
      // menu item that silently does nothing there is one somebody debugs
      // for an hour.
      _status.show('The Device Manager is not available from here.');
      return;
    }
    open(device.templateRef.templateId);
  }

  /// Door 3. Mints an id and runs the fork; the command refuses with a
  /// sentence when it cannot (a snapshot that does not resolve, an id
  /// already taken).
  void _forkToNewTemplate(DeviceInstance device) {
    final name = templateNameFor(_doc, device);
    final result = buildForkTemplateFromDevice(
      doc: _doc,
      deviceId: device.id,
      // SEEDED FROM THE DEVICE'S OWN NAME, not the template's, because the
      // fork is about THIS thing in the rack. `templateIdFor` suffixes a
      // collision rather than joining an existing id.
      newTemplateId: templateIdFor(_doc, '$name fork'),
      now: _controller.clock.nowUtc(),
      actor: _controller.actor,
    );
    switch (result) {
      case ForkTemplateFailed(:final reason):
        _status.show(reason);
      case ForkTemplateReady(:final command):
        _controller.selection = _selection.snapshot();
        _controller.run(command);
        _status.show(
          deviceDoorScopeText(
            door: DeviceDoor.forkToNew,
            designator: device.designator,
            others: 0,
            templateName: name,
          ),
        );
    }
  }

  // ── dragging the rack's top edge (docs/04 §4.1, way three) ────────────
  //
  // "Dragging the rack's top edge (8 px band, snaps to whole U, a '24U (+3)'
  // readout follows the cursor). While dragging SMALLER, any occupied U
  // about to be removed is hatched in red IN REAL TIME, so the collision is
  // visible before release. Growing is always safe: new U appear at the top
  // and existing ruIndex values are untouched."
  //
  // ROUTED THROUGH `CanvasIntentHandler`, like the move drag and unlike the
  // palette drag. The grab starts INSIDE the canvas subtree, so
  // `CanvasIntentDetector` already owns the pointer and delivers the whole
  // begin/update/commit/cancel sequence — no `pointerRouter`, no `Overlay`
  // -based arming, and (docs/04 §3's hard constraint) no `Draggable`/
  // `DragTarget`. Nothing here branches on `PointerDeviceKind` (AC-016 #23).
  //
  // NO COMMAND RUNS DURING THE DRAG. The gesture accumulates a candidate
  // height and hands exactly one integer to `_requestHeight` at pointer-up,
  // which is what makes §4.1's "ALL producing one ResizeRackCommand" true
  // for this path and why dragging across occupied territory cannot open a
  // modal per frame.
  //
  // GEOMETRY DURING THE DRAG IS THE ORIGINAL. The model has not changed, so
  // `_geo` and every `DeviceLayout` are still at the pre-drag height and the
  // doomed rects are valid as drawn. The candidate top-edge line is the one
  // thing drawn at the NEW height, and `RackGeometry.yOfBoundary` expresses
  // it against the current geometry without needing a second `RackGeometry`.

  /// The device whose CR-105 chip contains the scene point [p], or null.
  ///
  /// ══════════════════════════════════════════════════════════════════
  /// THE SAME `portChipRect` THE FRAME PAINTED THROUGH
  /// ══════════════════════════════════════════════════════════════════
  /// `RenderDeviceBox` draws the pill from this function in the device's
  /// LOCAL frame; this reads it back in SCENE space by adding the layout's
  /// top-left. Nothing here re-derives the rectangle, which is why a chip
  /// that is suppressed for not fitting (`portChipRect` returns null) is
  /// also not clickable, with no second condition to keep in step.
  ///
  /// It is tested BEFORE the device hit-test in [_onBeginDrag], the same
  /// precedence `_isTopEdgeGrab` takes and for a sharper reason: the chip
  /// sits inside its own device's body, so a device hit-test that ran
  /// first would swallow every press on it.
  Uuid? _chipAt(DPt p) {
    if (widget.onRevealInSchematic == null) return null;
    for (final layout in _rackScene?.devices ?? const <DeviceLayout>[]) {
      final fill = _portFill[layout.deviceId];
      if (fill == null || !fill.hasUnconnected) continue;
      final local = portChipRect(
        deviceWidth: layout.rect.width,
        deviceHeight: layout.rect.height,
        label: fill.label,
        measurer: widget.measurer,
      );
      if (local == null) continue;
      final left = layout.rect.left + local.left;
      final top = layout.rect.top + local.top;
      if (p.x >= left &&
          p.x <= left + local.width &&
          p.y >= top &&
          p.y <= top + local.height) {
        return layout.deviceId;
      }
    }
    return null;
  }

  /// Whether [p] lands in §4.1's 8px grab band on the rack's top edge.
  ///
  /// The band is CENTRED on the edge (`|y| <= band`), so it is reachable
  /// from the empty canvas above the rack as well as from inside the top U —
  /// a user aiming at a boundary does not know which side of it they are on.
  bool _isTopEdgeGrab(DPt p) {
    final band = _topEdgeBandPx / _viewport.scale;
    return p.y.abs() <= band && p.x >= 0 && p.x <= _geo.rackWidth;
  }

  void _armResizePreview() {
    // PREVIEW EXCLUSIVITY: arming is unconditional, and now for a reason
    // that actually covers every case. `_onBeginDrag` cannot have reached
    // the band test at all without CLAIMING the screen, which cancels a
    // compaction preview and refuses outright while a PALETTE drag is live;
    // a move drag cannot coexist because the band test short-circuits the
    // hit-test in that same method.
    //
    // WHAT THIS COMMENT USED TO SAY, and why it was wrong: it enumerated
    // "compaction, and a move drag cannot coexist" and omitted the palette
    // drag entirely. That gesture is armed from a SIBLING widget through a
    // completely separate pointer route, so nothing in this method's
    // reasoning applied to it and both previews genuinely ran at once — with
    // `EditingOverlayPainter`'s resize-first precedence blanking the palette
    // drag's ghost, snap line and blocked hatch while it was still live and
    // still evaluating, so a release committed a placement no feedback had
    // ever been shown for.
    _resize.begin(_rack.heightU);
    _insertResizeOverlay();
  }

  /// One frame of the live resize (§4.1's readout + real-time hatch).
  void _updateResizePreview(DPt sceneCurrent) {
    if (!_resize.isActive) return;
    // THE GRAB OFFSET IS PRESERVED, exactly as the move drag preserves it:
    // the top edge sits at scene y == 0, so the offset between the pointer
    // and the edge at grab time is `_dragStartScene.y`, and the edge's
    // candidate position is the pointer minus that. Without this, grabbing
    // the band 7px below the edge would teleport the edge up to the pointer
    // on the first move event.
    final topY = sceneCurrent.y - _dragStartScene.y;
    // ONE core inverse, not UI-side RU math — `heightForTopEdgeY` snaps to
    // whole U and clamps to CR-038's [1, 60] (rack_geometry.dart).
    final candidate = _geo.heightForTopEdgeY(topY);
    _resize.update(
      candidateHeightU: candidate,
      cursorGlobal: _sceneToGlobal(sceneCurrent),
      doomedRects: _doomedRectsFor(candidate),
    );
  }

  /// The scene rects §4.1 hatches in red: every occupant, ON EITHER FACE,
  /// whose highest U would fall outside a rack of [candidateHeightU].
  ///
  /// ASKED OF `planRackShrink` — THE SAME FUNCTION THE RELEASE WILL ASK, and
  /// that identity is the entire point rather than a convenience. §4.1's
  /// promise is that "any occupied U about to be removed is hatched in red IN
  /// REAL TIME, so the collision is visible BEFORE release", which is only
  /// true if the preview and the commit agree on who the occupants ARE. They
  /// did not. This method used to run its own scan over
  /// `boltedOccupantsOnFace`, and that primitive deliberately returns only
  /// rail-placed devices whose template snapshot resolves to a positive
  /// height on the face they claim — correct for the placement/collision
  /// callers it was factored out of, and wrong here. `planRackShrink` was
  /// fixed to enumerate the rest (a device with a dangling
  /// `templates['<id>@<version>']` ref, a 0U-channel occupant — see
  /// `DoomedKind`); this scan was not, so a drag over exactly those occupants
  /// painted a clean unhatched preview and a `12U (-12)` chip with no warning
  /// line, and then the release opened §4.1's modal naming a casualty the
  /// whole gesture had insisted did not exist.
  ///
  /// So there is now ONE occupant enumeration for this gesture instead of
  /// two that could drift — the same consolidation `_evaluateDrop` gives the
  /// two device drags (one verdict function feeding both the live ghost and
  /// the commit), and the same one core made internally when it routed
  /// `smallestFittingHeightU`, `achievableHeightU` and `freedU` through a
  /// single `_losslessFloor`. `planRackShrink` is a pure read whose own doc
  /// declares it "Safe to call on every tick of a drag", and `TrimFrom.top`
  /// is both its default and what `_requestHeight` will pass, so the plan
  /// this frame draws is the plan that release will act on.
  ///
  /// Reading the DOCUMENT rather than the rendered layouts is also the only
  /// way to see the REAR face while the front is displayed, and the only way
  /// to see an occupant `scene_builder` declines to draw at all (see
  /// resize_preview_controller.dart's header for why both matter).
  List<DBox> _doomedRectsFor(int candidateHeightU) {
    if (candidateHeightU >= _rack.heightU) return const []; // growing is safe
    final plan = planRackShrink(
      doc: _doc,
      rackId: _rack.id,
      toHeightU: candidateHeightU,
    );
    return [
      for (final o in plan.doomed) _geo.deviceRect(o.ruIndex, o.deviceH),
    ];
  }

  /// Pointer-up on a top-edge drag: hand the candidate to the ONE height
  /// funnel and tear the preview down.
  void _commitResizeDrag(DPt sceneEnd) {
    if (!_dragMoved) {
      // Never crossed the 4px threshold, so this was a CLICK on the rack's
      // top edge. The top edge is rack chrome, so it opens the inspector —
      // the same thing clicking the rack's empty background does (§4's
      // second entry point), stated here rather than left to
      // `_handleClick(null)`, whose inside-the-rack test would call a grab
      // 2px ABOVE the edge "outside" and deselect instead.
      _selection.clear();
      setState(() => _inspectorTarget = InspectorTarget.rack);
      return;
    }
    // Re-evaluate at the exact release point first: `CanvasIntentDetector`
    // reports pointer-up at a position that need not equal the last move
    // event's, and the height committed must be the one last shown.
    _updateResizePreview(sceneEnd);
    final candidate = _resize.candidateHeightU;
    _cancelResizePreview();
    _requestHeight(candidate);
  }

  /// Tears the resize preview down with no command — `Esc`, pointer-cancel,
  /// commit, or another interaction claiming the screen.
  void _cancelResizePreview() {
    _removeResizeOverlay();
    _resize.cancel();
  }

  void _insertResizeOverlay() {
    if (_resizeOverlayEntry != null) return;
    _resizeOverlayEntry = OverlayEntry(
      builder: (context) => _ResizePreviewOverlay(controller: _resize),
    );
    Overlay.of(context, rootOverlay: true).insert(_resizeOverlayEntry!);
  }

  void _removeResizeOverlay() {
    _resizeOverlayEntry?.remove();
    _resizeOverlayEntry = null;
  }

  // ── moving a placed device, with live feedback (docs/04 §3.3) ─────────
  //
  // THE MECHANISM, stated once. Unlike the palette drag (§3.1, further
  // below), this gesture starts INSIDE the canvas subtree, so it needs no
  // `pointerRouter` and no `Overlay`-based arming: it is already a plain
  // `CanvasIntentHandler` begin/update/commit/cancel sequence delivered by
  // `CanvasIntentDetector`. What §3.3 step 3 demands — "Same checks and
  // same blocked rendering as §3.1" — is delivered by sharing, not
  // cloning:
  //
  //   * the per-frame verdict comes from `_evaluateDrop`, the SAME function
  //     the palette drag calls (extent check first, then occupancy via
  //     core's `findBlockingOccupant`);
  //   * the ghost / snap-line / 45° hatch come from the SAME
  //     `EditingOverlayPainter._paintGhost`, fed by a `DragPreviewController`
  //     that is the same type the palette drag uses;
  //   * the RU-range and reason chips come from the SAME
  //     `_DragPreviewOverlay` widget;
  //   * a blocked release is the SAME no-op + 120ms `ShakeController` shake
  //     + 1.2s chip linger.
  //
  // The one thing that is NOT shared is the commit: a palette drag builds an
  // `AddDeviceCommand` via `buildPlaceFromCatalogCommand`, a move builds a
  // `MoveDeviceCommand`. That is the actual difference between the two
  // gestures, and it is the only difference left in the code.
  //
  // WHAT THIS REPLACED, honestly: `_handleMove` + a private
  // `_rangeFreeOnFace` that derived occupancy by inverting each RENDERED
  // device layout's Y back into RU indices — a second occupancy query and a
  // second inverse-Y derivation living alongside core's `findBlockingOccupant`
  // and `RackGeometry.ruIndexForTopY`. Both are gone; occupancy is now asked
  // of the DOCUMENT MODEL through the one core function every other surface
  // (keyboard nudge, quick-add, palette drag) already used.
  //
  // STILL DEFERRED for this gesture, unchanged (docs/m1-implementation-log.md
  // §3.3): step 2 (cross-rack drag past 60px beyond a rail — only one rack
  // exists in the demo document, so there is no neighbour to jump to), step 5
  // (`Ctrl` = duplicate), step 6 (`Alt` = insert-and-push), step 7
  // (`Ctrl+Shift` = swap), and multi-device drag.

  /// docs/04 §3.3 step 1, once past the 4px threshold: the source device
  /// drops to 30% opacity IN PLACE (via `_lastMoveDragSourceId` →
  /// `DeviceBox.dragSource`) and the ghost goes live.
  void _armMovePreview() {
    final deviceId = _dragDeviceId;
    final placement = _dragPlacement;
    if (deviceId == null || placement == null) return;

    // A new drag starting is reason enough to stop honouring the PREVIOUS
    // drag's blocked-release linger timer. Left pending, it would fire
    // (up to 1.2s later) against the `_moveDrag`/overlay this new drag now
    // owns: `reset()` would wipe the live evaluation mid-gesture, the chips
    // would vanish, and — because `_onCommitDrag` gates on
    // `_moveDrag.isDragging` — the release would then commit NOTHING, a
    // silent failed move. Exactly the bug class already fixed on the
    // palette side (see `_onPaletteArmDrag`'s own note); the same guard
    // belongs here for the same reason.
    _moveBlockedReleaseTimer?.cancel();
    _moveBlockedReleaseTimer = null;

    final device = _doc.devices[Uuid(deviceId)];
    // A LOCKED DEVICE DOES NOT LIFT (DR-186 §11.185.1). Refused at the
    // threshold, where the drag would first become visible, with the same
    // shake and status line a blocked nudge uses (docs/04 §3.4: never a
    // silent no-op). `_dragRefused` is what keeps the rest of this pointer
    // from arming, committing or reading as a click.
    if (placement.locked) {
      _dragRefused = true;
      _shake.trigger(Uuid(deviceId));
      _status.show(lockedRefusal(device?.designator ?? deviceId));
      return;
    }
    _moveDrag
      ..arm(
        subjectId: deviceId,
        deviceH: _dragDeviceHeightU,
        face: placement.face,
        displayName: device?.name ?? '',
        badge: '${_dragDeviceHeightU}U',
        sourceKinds: _dragSourceKinds,
      )
      // No pre-canvas-entry stage exists for this gesture — the grab
      // happened inside the canvas — so `armed -> dragging` directly.
      ..liftIntoCanvas();
    _insertMoveDragOverlay();
  }

  /// One frame of the live move preview (docs/04 §3.3 steps 1/3).
  ///
  /// The snapped RU comes from the device's ORIGINAL top edge plus the
  /// vertical drag delta — "the grab offset preserved" (§3.3 step 1) —
  /// through `RackGeometry.ruIndexForTopY`, the one inverse geometry.
  ///
  /// A DELIBERATE, STATED DEVIATION from §3.3 step 1's literal wording: the
  /// ghost is drawn HARD-SNAPPED to that RU, not free-floating under the
  /// cursor. §3.3 step 3 requires the same rendering as §3.1, and §3.1 step
  /// 4's ghost is explicitly hard-quantised ("Snap is instant"); a
  /// free-floating ghost would need a second ghost-painting path and would
  /// let the preview sit somewhere the commit would never place the device.
  /// The grab offset is still fully preserved — it is what feeds the
  /// snap — so a grab near a device's bottom edge still tracks differently
  /// from a grab near its top, which is the behaviour that wording exists to
  /// protect.
  void _updateMovePreview(DPt sceneCurrent) {
    if (!_moveDrag.isDragging) return;
    final deviceId = _dragDeviceId;
    final placement = _dragPlacement;
    if (deviceId == null || placement == null) return;

    // OFF THE RACK, THE RELEASE STAGES (DR-205). No ghost, because there
    // is no U it would land at, and the status line says what the release
    // will do, once, on the way out.
    if (_isOffRack(sceneCurrent)) {
      if (!_moveWillStage) {
        _moveWillStage = true;
        final who = _doc.devices[Uuid(deviceId)]?.designator ?? 'it';
        _status.show(
          'Release to send $who to the Staging Bin, wiring kept.',
        );
      }
      _moveDrag
        ..updateCursorGlobal(_sceneToGlobal(sceneCurrent))
        ..clearEvaluation(sceneCurrent);
      return;
    }
    _moveWillStage = false;

    final newTopY = _dragDeviceStartTopY + (sceneCurrent.y - _dragStartScene.y);
    final ruIndex = _geo.ruIndexForTopY(newTopY, _dragDeviceHeightU);
    _moveDrag
      ..updateCursorGlobal(_sceneToGlobal(sceneCurrent))
      ..updateEvaluation(
        sceneCurrent,
        _evaluateDrop(
          ruIndex,
          _dragDeviceHeightU,
          placement.face,
          // A device never blocks its own move against its OWN current
          // placement (core's `findBlockingOccupant` takes this exact
          // parameter for exactly this reason).
          exceptId: Uuid(deviceId),
        ),
      );
  }

  /// docs/04 §3.3 step 4 ("Pointer up commits one `MoveDeviceCommand`") and
  /// step 3's inherited §3.1-step-5 blocked behaviour.
  ///
  /// The verdict committed to is the SAME `DragPreviewEvaluation` object the
  /// ghost last drew — re-evaluated one final time at the exact release
  /// point first, because `CanvasIntentDetector` reports pointer-up at a
  /// position that need not equal the last move event's. That refresh runs
  /// through `_updateMovePreview` (hence `_evaluateDrop`), so "commit reads
  /// the last live-evaluated state" stays literally true: there is no second
  /// code path deciding whether the move is legal.
  void _commitOrNoopMoveDrag(DPt sceneEnd) {
    final deviceId = _dragDeviceId;
    final placement = _dragPlacement;
    if (deviceId == null || placement == null) {
      _cancelMoveDrag();
      return;
    }

    _updateMovePreview(sceneEnd);
    // A release off the rack sends the device to the bin with its id,
    // ports and links (DR-205; the user: "should also keep wiring").
    if (_isOffRack(sceneEnd)) {
      _moveWillStage = false;
      _cancelMoveDrag();
      switch (planStageDevice(
        doc: _doc,
        id: Uuid(deviceId),
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      )) {
        case PlacementPlanReady(:final command):
          _controller.run(command);
          _status.show(
            '${_doc.devices[command.id]?.designator ?? 'The device'} sent to '
            'the Staging Bin, wiring kept. Ctrl+Z to undo.',
          );
        case PlacementPlanRefused(:final reason):
          _status.show(reason);
      }
      return;
    }
    final evaluation = _moveDrag.evaluation;

    if (evaluation == null || evaluation.blocked) {
      // docs/04 §3.1 step 5, inherited by §3.3 step 3: "Release while
      // blocked is a no-op with a 120ms shake and the chip persisting
      // 1.2s." Deliberately NOT the old silent refusal — docs/04 §3.4's
      // "silent no-ops are the most common source of 'the app is broken'"
      // applies to a refused drop exactly as it does to a refused nudge.
      // The GHOST shakes, not the device: the device never moved, and it
      // has already snapped back to full opacity (`beginBlockedRelease`
      // clears the phase, so `isSourceEngaged` goes false this same frame).
      _shake.trigger(kDragGhostShakeId);
      _moveDrag.beginBlockedRelease();
      _moveBlockedReleaseTimer?.cancel();
      _moveBlockedReleaseTimer = Timer(
        const Duration(milliseconds: 1200),
        () {
          _moveDrag.reset();
          _removeMoveDragOverlay();
          _moveBlockedReleaseTimer = null;
        },
      );
      return;
    }

    _removeMoveDragOverlay();
    _moveDrag.reset();

    if (evaluation.ruIndex == placement.ruIndex) {
      return; // Genuine no-op: dropped back where it started.
    }

    // selectionBefore for the undo entry = the live selection (docs/03 §4.4);
    // a move leaves the selection unchanged, so selectionAfter matches.
    _controller.selection = _selection.snapshot();
    _controller.run(
      MoveDeviceCommand(
        id: Uuid(deviceId),
        fromRuIndex: placement.ruIndex,
        toRuIndex: evaluation.ruIndex,
        fromFace: placement.face,
        toFace: placement.face,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      ),
    );
  }

  /// Tears down a move preview with no command and no lingering chip — the
  /// `Esc` revert (docs/04 §3.3 step 4) and the pointer-cancel path.
  void _cancelMoveDrag() {
    _moveBlockedReleaseTimer?.cancel();
    _moveBlockedReleaseTimer = null;
    _removeMoveDragOverlay();
    _moveDrag.reset();
  }

  /// A scene point as a GLOBAL screen offset, for the screen-space chips
  /// (`_DragPreviewOverlay` positions from global coordinates, since the
  /// palette drag — its other caller — tracks raw global pointer positions).
  /// Null-safe against a detached/rebuilt canvas render object, exactly as
  /// `_handlePaletteDragMove` is.
  Offset _sceneToGlobal(DPt scene) {
    final screen = _viewport.sceneToScreen(scene);
    final local = Offset(screen.x, screen.y);
    final box = _canvasBoxKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return local;
    return box.localToGlobal(local);
  }

  /// Whether primary focus is inside a text field ANYWHERE — the palette
  /// filter, one of the five `RackInspector` fields, or anything added
  /// later.
  ///
  /// Asked of `FocusManager.instance.primaryFocus` rather than of any node
  /// this screen owns, because the point is to catch fields this screen has
  /// never heard of. `EditableText` builds its `Focus` as a DESCENDANT of
  /// itself, so the focused node's context is inside the `EditableText`
  /// subtree and the ancestor walk finds it; the `is EditableText` limb
  /// covers the case where the focused context IS the `EditableText`
  /// element.
  ///
  /// This is a read of live focus, not of widget identity, so it stays
  /// correct for fields that do not exist yet — which is the property that
  /// matters, since the defect it closes was introduced by adding a text
  /// field to a subtree whose keymap predated it.
  /// **THE PREDICATE MOVED TO `keymap.dart`** (`#885`, DR-165), because
  /// `PaletteHost` gates `/` on the same question and two spellings would
  /// answer differently the first time either grew a case.
  bool get _textFieldHasFocus => aTextFieldHasFocus();

  /// SECOND LINE OF DEFENCE, deliberately redundant with the
  /// `isActionEnabled` gate on `DeleteSelectionIntent`.
  ///
  /// This is the only keyboard action on the screen that DESTROYS DOCUMENT
  /// STATE, and it was the only one with no focus guard at all while its
  /// three siblings (`_dispatchVertical`, `_onHome`, `_onEnd`) each had
  /// one. That asymmetry is exactly how a single `Backspace` typed into the
  /// palette filter came to delete a device from the rack.
  ///
  /// The gate in the action map is what makes the KEY fall through to the
  /// text field; this guard is what makes the COMMAND not run. They are not
  /// the same mechanism (see `_GatedAction`'s doc on why a body guard alone
  /// cannot save the key), and a refactor that drops one must not silently
  /// drop both.
  Future<void> _deleteSelection() async {
    if (!_canvasFocus.hasFocus) return;
    final ids = _selection.ids.where(_doc.devices.containsKey).toList();
    if (ids.isEmpty) return;

    // ═════════════════════════════════════════════════════════════════
    // DR-013 §11.13.2 — ASK BEFORE DESTROYING WORK THE USER CANNOT SEE
    // ═════════════════════════════════════════════════════════════════
    // The plans are computed HERE and handed to the dialog, then thrown
    // away: `RemoveDeviceCommand.apply` re-plans against the document it
    // is applied to, which is the only thing that can be right if
    // anything moved while the dialog was open. What the plan is used for
    // here is the SENTENCE — and both come from `planDeviceRemoval`, so
    // the number the user agreed to is the number the command removes.
    //
    // A device carrying nothing shows no dialog at all
    // (`confirmDeviceRemoval` returns true without building one), so the
    // ordinary delete of an unwired device is exactly as immediate as it
    // was before this ruling.
    final plans = <DeviceRemovalPlan>[
      for (final id in ids) planDeviceRemoval(_doc, id),
    ];
    final proceed = await confirmDeviceRemoval(
      context,
      plans: plans,
      designators: <Uuid, String>{
        for (final id in ids) id: _doc.devices[id]?.designator ?? id.v,
      },
    );
    if (!proceed || !mounted) return;

    // RE-READ AFTER THE AWAIT. The document is not frozen while a dialog
    // is open — an autosave cannot change it, but an undo from a menu or
    // a second window could — so the ids are filtered again rather than
    // trusted across the suspension point.
    final live = ids.where(_doc.devices.containsKey).toList();
    if (live.isEmpty) return;

    _controller.selection = _selection.snapshot(); // before = current selection
    // One transaction so a multi-device delete is a SINGLE undo entry, not N
    // (docs/04 §3.5: "undo restores device and links as one command").
    // EACH COMMAND NOW CARRIES ITS OWN LINKS: DR-013 §11.13.1 makes the
    // cascade part of `RemoveDeviceCommand` itself, which is what the
    // "deferred" note that used to sit here was waiting for.
    _controller.transact(LabelKey.removeDevice, (tx) {
      for (final id in live) {
        tx.add(RemoveDeviceCommand(id: id));
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

  // ── the insertion caret + keyboard nudge (docs/04 §3.4) ───────────────
  //
  // SCOPE (stated once, matching docs/m1-implementation-log.md): this stage
  // builds Up/Down/Home/End/PgUp/PgDn for BOTH the no-selection case (moves
  // the caret) and the with-selection case (nudges the focused device, ±1U
  // for Up/Down, ±10U for PgUp/PgDn, with the existing 400ms
  // `UndoStack.mergeWindow` coalescing every `MoveDeviceCommand.mergeWith`
  // already provides — docs/03-architecture.md §5.4 names exactly this
  // "arrow-key nudges" as that window's intended consumer, so no second,
  // nudge-specific timing constant is introduced here even though
  // docs/04-rack-editor.md's own text says "500ms" — see this stage's
  // final report for the discrepancy).
  //
  // OUT OF SCOPE, explicitly: Shift+Up/Down (extend selection to the
  // adjacent occupant) and Alt+Up/Down (swap with the adjacent occupant,
  // re-pack on unequal heights) both need multi-select/re-pack logic this
  // codebase doesn't have yet. Ctrl+Up/Down (jump to the next free slot,
  // skipping occupied space) is ALSO deferred this stage — a directional
  // occupancy search distinct from the two behaviours above, and not
  // required to make quick-add-by-typing or drag-drop work. Because every
  // binding below is a BARE `SingleActivator` (no modifiers),
  // `SingleActivator`'s exact-modifier matching means Shift/Ctrl/Alt+Up/
  // Down simply do not fire these actions at all — they fall through
  // unhandled, which is the deferral mechanism, not an oversight.
  //
  // Multi-device nudge is also out of scope: [_nudgeSelectedTo] acts on
  // `_selection.focus` (the single focused device) even when several are
  // selected, matching drag-move's existing single-device restriction
  // (`_onCommitDrag`'s own comment). This isn't just consistency for its
  // own sake — `Transaction.mergeWith` only merges when BOTH sides have
  // exactly one child (transaction.dart), so an N-child transaction per
  // keypress could never coalesce across repeated presses, breaking the
  // "holding Down is one undo entry" guarantee for anything but a single
  // selected device.

  /// The focused selection's rail placement, or null if there is no
  /// focused selection or it is not rail-placed (e.g. an off-rack field
  /// device — nudging is meaningless for those).
  RailPlacement? _selectedRailPlacement() {
    final id = _selection.focus;
    if (id == null) return null;
    final placement = _doc.devices[id]?.placement;
    return placement is RailPlacement ? placement : null;
  }

  /// Up/Down (±1) and PgUp/PgDn (±10) share one dispatcher: move the caret
  /// when nothing is selected, else nudge the focused device by the same
  /// delta.
  ///
  /// The real guard is the `isActionEnabled` gate in the action map; this
  /// body check is kept as its second line of defence.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE SENTENCE THAT USED TO BE HERE WAS FALSE, AND IT COST A RELEASE
  /// ═══════════════════════════════════════════════════════════════════
  /// It read: "The palette SEARCH field needs no such guard —
  /// `EditableText`'s own key handling consumes arrow keys as text-cursor
  /// movement before they ever bubble this far."
  ///
  /// `EditableText` INSTALLS NO KEY HANDLER ON ITS FOCUS NODE. Nothing in
  /// it inspects a `KeyEvent`. Text editing keys reach it as *Intents*
  /// dispatched by `DefaultTextEditingShortcuts`, which `WidgetsApp`
  /// installs at the ROOT of the app — an ANCESTOR of this screen. Since
  /// `FocusManager` walks LEAF -> ROOT, text editing is the LAST thing
  /// consulted, not the first. The sentence had the order exactly
  /// backwards.
  ///
  /// What it licensed: fourteen bare bindings over a subtree containing six
  /// text fields. `Backspace` in the palette filter deleted a rack device
  /// instead of a character, `Ctrl+Z` rewound a document command instead of
  /// the typing, `Home`/`End`/arrows/`PgUp`/`PgDn` went dead, and `/` could
  /// not be typed at all. The filter box could not be corrected once
  /// mistyped, which made the palette unusable for the rest of the session.
  ///
  /// The correct rule is stated in `_GatedAction`'s doc comment and,
  /// independently and correctly, in `app_shell.dart`'s header for `Ctrl+S`
  /// — cross-referenced deliberately so the two cannot drift apart again.
  void _dispatchVertical(int delta) {
    if (!_canvasFocus.hasFocus) return;
    if (_selection.isEmpty) {
      _caret.moveBy(delta);
      return;
    }
    final placement = _selectedRailPlacement();
    if (placement == null) return;
    _nudgeSelectedTo(placement.ruIndex + delta);
  }

  void _onArrowUp() => _dispatchVertical(1);
  void _onArrowDown() => _dispatchVertical(-1);
  void _onPageUp() => _dispatchVertical(10);
  void _onPageDown() => _dispatchVertical(-10);

  /// `Esc` inside the palette filter: clear the query and hand focus back to
  /// the canvas.
  ///
  /// Field-local, and deliberately NOT routed through `RackCancelIntent` —
  /// that binding is gated OFF while a text field has focus, precisely so
  /// `Esc` cannot reach across and clear the canvas selection out from under
  /// someone who is typing. This is the other half of that decision: having
  /// taken `Esc` away from the canvas here, the field owes the user
  /// something for it, and "empty the filter, give the keyboard back" is the
  /// action that makes the palette recoverable without the mouse.
  ///
  /// Returning focus to the canvas also re-lights the insertion caret for
  /// free, through `_onFocusChanged`.
  void focusCanvas() => _canvasFocus.requestFocus();

  /// Says [message] on this canvas's status line (`#885`, DR-165).
  ///
  /// **THE PALETTE'S REFUSALS STILL LAND HERE.** "No device matches" was
  /// `onRefuse: _status.show` when this screen owned the palette, and a
  /// hoist that quietly rerouted it to a snack bar would have moved a
  /// sentence the user reads mid-keystroke into a surface that covers the
  /// thing they are typing into. The host asks the OPEN canvas where its
  /// refusals go, exactly as it asks it to place and to arm.
  void showStatus(String message) => _status.show(message);

  /// `Esc` (docs/04 §3.3 step 4): reverts an in-flight move drag — the
  /// source device returns to full opacity at its original U, the ghost and
  /// chips disappear, and NO command runs. Latches [_dragCancelled] so the
  /// still-down pointer's remaining `updateDrag`/`commitDrag` callbacks
  /// cannot resurrect the move (see that field's own doc comment).
  ///
  /// A no-op when neither is in flight — including during a PALETTE drag,
  /// which cancels through its own raw keyboard hook and consumes the key
  /// before it ever reaches this binding.
  ///
  /// ALSO CANCELS AN OPEN COMPACTION PREVIEW (docs/04 §3.6: "Esc cancels").
  /// The two cannot both be live — `_beginCompaction` tears down any
  /// in-flight drag first — so the order below is for readability, not
  /// arbitration.
  ///
  /// ── AND, WITH NOTHING IN FLIGHT, IT CLEARS THE SELECTION ─────────────
  ///
  /// docs/04 §8's keymap has always said so — "`Esc` · cancel drag, exit
  /// mode, **clear selection** · global" — and the third limb was the one
  /// this file did not implement. Its absence is what
  /// `docs/12-milestone-board.md` §3.2 clause 3 records as the reason the
  /// keyboard-only drill fails: `_placeFromCatalog` suppresses caret
  /// targeting while anything is selected, every placement selects what it
  /// just placed, and there was no key that could un-select it. So a
  /// keyboard user could reach the caret exactly once and then had to touch
  /// the mouse to get back to it.
  ///
  /// LAST, not first. Esc is a cancel key before it is a deselect key: a
  /// user with a device selected who starts a move drag and panics wants
  /// the drag reverted, not their selection quietly emptied. The FOUR
  /// in-flight cases below therefore each return, and this runs only when
  /// none of them did.
  ///
  /// THE FOURTH IS THE PALETTE DRAG, and it is the one that does not look
  /// like the others. It cancels through its own raw keyboard hook, whose
  /// `return true` reads as "consumed" and is not — Flutter runs the raw
  /// handlers and the `Shortcuts` dispatch for the SAME keypress and ORs
  /// their verdicts (see `_onRawKeyDuringPaletteDrag`). So by the time this
  /// method runs the drag has already been torn down and `_paletteDrag` is
  /// reset, which is why the guard is a latch and not `_paletteDrag
  /// .isInProgress`. Measured, not reasoned: a 2-device selection plus a
  /// palette drag plus one `Esc` used to cancel the drag AND report
  /// "Selection cleared (2 devices)."
  ///
  /// AND IT REPORTS (§3.4's "never silently do nothing"): clearing says so
  /// on the status line — which `StatusMessageController` also pushes
  /// through `SemanticsService.sendAnnouncement`, so a screen-reader user hears
  /// the mode change rather than inferring it. Esc with nothing selected
  /// and nothing in flight is the one silent case, and deliberately: a
  /// cancel key that scolds you for having nothing to cancel is noise, and
  /// unlike a refused ACTION nothing was asked for here.
  void _onEscape() {
    // A live top-edge drag goes first: it is the only one of the three whose
    // pointer may still be physically down while the OTHER two are provably
    // not (the band test short-circuits the hit-test, and `_beginCompaction`
    // tears down any drag). `_dragCancelled` makes every remaining callback
    // for that still-down pointer a no-op, exactly as it does for a move.
    if (_resize.isActive) {
      _dragCancelled = true;
      _cancelResizePreview();
      return;
    }
    if (_compaction.isActive) {
      _cancelCompaction();
      return;
    }
    if (_moveDrag.isInProgress) {
      _dragCancelled = true;
      _cancelMoveDrag();
      return;
    }
    if (_escConsumedByPaletteDrag) return;
    _clearSelectionFromKeyboard();
  }

  /// docs/04 §8's third `Esc` limb. Separate from [_onEscape] so the rack
  /// switcher and any future mode-exit can reuse it, and so the one thing
  /// it must get right — reactivating the caret — is stated once.
  ///
  /// The caret comes back on its own: `_selection`'s listener runs
  /// `_onEditorChanged`, which runs `_recomputeCaret`, whose activation
  /// formula is `selection empty AND canvas focus AND no drag`. It comes
  /// back AT ITS PREVIOUS POSITION, because the caret is sticky (see
  /// `CaretController`) — which is precisely what makes the next
  /// `/`-search-Enter land where the user left off rather than at
  /// lowest-free-U.
  void _clearSelectionFromKeyboard() {
    if (_selection.isEmpty) return;
    final n = _selection.length;
    _selection.clear();
    _status.show(
      n == 1 ? 'Selection cleared.' : 'Selection cleared ($n devices).',
    );
  }

  void _onHome() {
    if (!_canvasFocus.hasFocus) return;
    if (_selection.isEmpty) {
      _caret.moveTo(1);
      return;
    }
    _nudgeSelectedTo(1); // clamped up to a fitting position inside
  }

  void _onEnd() {
    if (!_canvasFocus.hasFocus) return;
    if (_selection.isEmpty) {
      _caret.moveTo(_rack.heightU);
      return;
    }
    _nudgeSelectedTo(_rack.heightU); // clamped down to a fitting position
  }

  /// `Ctrl+L` over the selection (DR-186 §11.185.2).
  ///
  /// THE TOGGLE RULE IS HERE, where the selection is: anything unlocked in
  /// it locks all of it, and a selection already all locked unlocks. A
  /// per-device toggle would turn a mixed selection into its own inverse.
  /// Devices with no rack position are left out rather than refused, and a
  /// selection of nothing BUT those says so.
  void _toggleLockSelection() {
    final lockable = _lockableSelection;
    if (lockable.isEmpty) {
      _status.show('Only a device in a rack has a position to lock.');
      return;
    }
    _setLockSelection(
      lock: lockable.any(
        (id) => placementLocked(_doc.devices[id]!.placement) == false,
      ),
    );
  }

  /// The selected devices a lock means something for: those with a rack
  /// position (DR-186 §11.185.1). ONE list for the key and the checkbox,
  /// so the two cannot disagree about which devices they would touch.
  List<Uuid> get _lockableSelection => [
    for (final id in _selection.ids)
      if (_doc.devices[id] case final d?
          when placementLocked(d.placement) != null)
        id,
  ];

  /// Sets the lock on every selected device that has a rack position, as
  /// one undo entry. `Ctrl+L` computes [lock] from the selection; the
  /// inspector's checkbox computes it the same way and passes it here.
  void _setLockSelection({required bool lock}) {
    final lockable = _lockableSelection;
    if (lockable.isEmpty) return;
    _controller.selection = _selection.snapshot();
    _controller.run(
      SetPlacementLockedCommand(deviceIds: lockable, locked: lock),
    );
    final what = lockable.length == 1
        ? _doc.devices[lockable.single]!.designator
        : '${lockable.length} devices';
    _status.show(lock ? 'Locked $what.' : 'Unlocked $what.');
  }

  /// Nudges the focused selection to [targetRu] — one more
  /// `MoveDeviceCommand.run()` call, which is exactly what the existing,
  /// already-tested merge machinery coalesces within the 400ms window
  /// (`document_controller_test.dart`'s "two MoveDeviceCommand.run() calls
  /// within the merge window coalesce" case is this same mechanism).
  ///
  /// Three distinct outcomes, on purpose (docs/04 §3.4: "a nudge that
  /// would collide never silently stops"):
  ///  * the target clamps back to the CURRENT position (a rack-extent
  ///    boundary, e.g. nudging Up from the top U) — a genuine no-op,
  ///    nothing was attempted, so no shake/status;
  ///  * the target is free — runs the move;
  ///  * the target is occupied by another device — a real attempted-and-
  ///    refused move: shakes the selection and reads the blocker's
  ///    designator on the status line, never silently doing nothing.
  void _nudgeSelectedTo(int targetRu) {
    final id = _selection.focus;
    if (id == null) return;
    final placement = _doc.devices[id]?.placement;
    if (placement is! RailPlacement) return;
    final layout = _layoutFor(id.v);
    if (layout == null) return; // not visible on the current face
    final deviceH = (layout.rect.height / RackGeometry.unitsPerRu).round();
    final clampedTarget = targetRu.clamp(1, _geo.maxRuIndexFor(deviceH));
    if (clampedTarget == placement.ruIndex) return; // genuine no-op

    // A LOCKED DEVICE REFUSES THE NUDGE BY NAME (DR-186 §11.185.1), in the
    // "attempted and refused" branch below and after the boundary no-op
    // above: at the top of the rack there was nothing to refuse.
    if (placement.locked) {
      _shake.trigger(id);
      _status.show(lockedRefusal(_doc.devices[id]?.designator ?? id.v));
      return;
    }

    final blocker = findBlockingOccupant(
      rack: _rack,
      devices: _doc.devices.values,
      face: placement.face,
      templates: _doc.templates,
      ruStart: clampedTarget,
      deviceH: deviceH,
      exceptId: id,
    );
    if (blocker != null) {
      _shake.trigger(id);
      _status.show('Blocked by ${blocker.designator}');
      return;
    }

    // selectionBefore for the undo entry = the live selection (docs/03
    // §4.4); a nudge leaves the selection unchanged, so selectionAfter
    // matches — same convention as the move-drag commit.
    _controller.selection = _selection.snapshot();
    _controller.run(
      MoveDeviceCommand(
        id: id,
        fromRuIndex: placement.ruIndex,
        toRuIndex: clampedTarget,
        fromFace: placement.face,
        toFace: placement.face,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      ),
    );
  }

  // ── palette placement (docs/09-roadmap.md M1 checklist #6; docs/04 §3.2
  // "the faster paths") — CLICK-TO-ADD (double-click / row-focused Enter),
  // PLUS this stage's new search-box Enter, all funnelled through this one
  // method. NOT the full drag-from-palette-to-rails gesture of §3.1
  // (arm/lift/enter-canvas/snap/evaluate/commit with live blocked-drop
  // feedback), which is a separate follow-up stage. Every trigger inserts
  // at the insertion caret when one exists, else at the lowest fitting
  // free U on the demo rack (§3.2's pre-existing "faster paths" fallback,
  // unchanged) — see the caret-targeting note below for exactly what
  // "exists" means here.

  void placeFromPalette(PlaceableTemplate row) {
    // DR-103 §11.102.2: a library row is COPIED INTO THE PROJECT and then
    // placed. The plan is computed here, before anything is committed,
    // precisely so the refusals below can still happen with the document
    // untouched.
    final plan = row.provenance is LibraryProvenance
        ? planLibraryPlacement(
            _doc,
            row,
            capturedAt: _controller.clock.nowUtc(),
          )
        : null;
    final catalogId = plan?.templateId ?? row.id;

    // selectionBefore for the undo entry = the live selection, same
    // convention as the move-drag commit/_deleteSelection.
    _controller.selection = _selection.snapshot();

    // CARET TARGETING — a deliberate, explained deviation from gating this
    // on `_caret.active` (which also requires literal current canvas
    // focus): all three placement triggers (double-click, row-focused
    // Enter, search-box Enter) necessarily fire while focus is on a
    // PALETTE widget, not the canvas — `/`-then-type-then-Enter is docs/04
    // §3.2's own headline "populate a rack by pure typing" flow, and by
    // the time `Enter` lands here the canvas lost Flutter focus the
    // moment `/` moved it to the search field. Gating on `_caret.active`
    // would make quick-add fall back to lowest-free-U on every single
    // placement in practice, defeating "the caret advances past it" (the
    // one thing this stage adds over the pre-existing lowest-free-U
    // path). [CaretController.stickyCaret] is the SAME position without
    // that focus gate; the only thing that should suppress caret-
    // targeting is an ACTUAL selection existing (docs/04 §3.4: the caret
    // conceptually doesn't exist once something is selected), which is
    // checked explicitly here rather than folded into `active`.
    //
    // THE GAP THIS USED TO DOCUMENT AGAINST ITSELF, now closed. It read:
    // because a freshly-placed device becomes the sole selection a few
    // lines below (docs/04 §3.1 step 6), `_selection.isEmpty` is false
    // immediately after EVERY placement — so two Enters back-to-back used
    // the caret for the FIRST placement only and the second fell back to
    // lowest-free-U. docs/12-milestone-board.md §3.2 clause 3 records that
    // as the code naming its own defect, and the user's 2026-07-27 drill
    // as the measurement of it.
    //
    // TWO THINGS FIXED IT, and they are separate. `Esc` now clears the
    // selection (docs/04 §8's third limb — see `_onEscape`), which is what
    // lets a keyboard user get BACK to the caret at all. And the rule
    // below distinguishes a selection the USER made from one THIS METHOD
    // just made: docs/04 §3.4's "the caret conceptually doesn't exist once
    // something is selected" is about a user's selection — a device
    // auto-selected by the placement the user is in the middle of
    // repeating is not a decision to stop using the caret. Without that
    // second half, §9's own measured path ("nine `/ query ⏎` cycles,
    // roughly 25 seconds … `Enter` from palette search places at the caret
    // and advances it") would need an `Esc` wedged into every cycle.
    //
    // `_lastQuickAddId` is cleared by the very next selection change this
    // screen did not itself cause (`_forgetQuickAddSelection`), so a click,
    // a Ctrl+click, an undo's selection restore or an `Esc` all end the
    // transparency immediately — it can only ever describe the placement
    // that is still, untouched, on screen.
    // ── AND WHAT HAPPENS WHEN THE CARET'S U IS TAKEN ─────────────────────
    //
    // A LOOP THAT PLACES ONE DEVICE AND THEN JAMS IS NOT A LOOP. Measured
    // on the demo rack (12U; UPS-1 U1-2, AMP-1 U4-5, SW-1 U7): four
    // consecutive `/ query ⏎` cycles placed ONE device at U3 and then
    // refused three times running, because the caret had advanced to U4 and
    // caret-targeting stayed live for every subsequent cycle. That is
    // strictly worse than the behaviour it replaced, which fell back to
    // lowest-free-U on every cycle after the first and so placed four — and
    // it is worse on exactly the everyday case, adding gear to a rack that
    // already has some in it.
    //
    // So a caret-targeted quick-add INSIDE the keep-typing loop retries at
    // docs/04 §3.2's "lowest fitting free U" — the same fallback the
    // no-caret path has always used. It is not a silent redirect: the
    // refusal that made it necessary is read out in front of the placement
    // ("Occupied by AMP-1 (U4-U5). Placed BP-2 at RK-1 U6, front."), so the
    // user is told both that the caret's slot was taken and where the device
    // actually went, which is what §3.4's "never silently do nothing" asks
    // for. The caret then advances past what was placed, so the cycle after
    // this one aims somewhere real.
    //
    // ONLY INSIDE THE LOOP. When the user put the caret where it is —
    // arrows, Home, End, PgUp/PgDn with nothing selected — an occupied
    // target is an aimed shot that missed, and the honest answer is the
    // loud refusal below, not a device somewhere they did not point at.
    // `_selectionIsLastQuickAdd` is exactly the difference: it is true only
    // while the selection is still the untouched result of THIS method's
    // own previous placement, which is the only way the caret can be
    // sitting where it is because the SCREEN advanced it.
    final inKeepTypingLoop = _selectionIsLastQuickAdd;
    final targetRu = (_selection.isEmpty || inKeepTypingLoop)
        ? _caret.stickyCaret?.ruIndex
        : null;

    final now = _controller.clock.nowUtc();
    CatalogPlacementResult attempt(int? explicitRuIndex) =>
        buildPlaceFromCatalogCommand(
          doc: _doc,
          catalogId: catalogId,
          targetRack: _rack,
          now: now,
          actor: _controller.actor,
          explicitRuIndex: explicitRuIndex,
          using: plan?.snapshot,
        );

    var result = attempt(targetRu);
    String? caretRefusal;
    if (result is CatalogPlacementFailed &&
        targetRu != null &&
        inKeepTypingLoop) {
      final fallback = attempt(null);
      if (fallback is CatalogPlacementReady) {
        caretRefusal = result.reason;
        result = fallback;
      }
      // A fallback that ALSO fails (the rack is full) leaves `result` as
      // the caret refusal, which is the more specific of the two reasons.
    }

    if (result is CatalogPlacementReady) {
      _finalizeCatalogPlacement(
        result.command,
        catalogId,
        fromQuickAdd: true,
        caretRefusal: caretRefusal,
        plan: plan,
        row: row,
      );
    } else if (result is CatalogPlacementFailed) {
      _status.show(result.reason);
      // FOCUS COMES BACK EVEN WHEN NOTHING WAS PLACED. The success path has
      // always done this (`_finalizeCatalogPlacement`), and the refusal path
      // did not — so a refused quick-add left primary focus on the route's
      // modal scope, where the palette search box's `TextInputAction.done`
      // had dropped it. From there NOTHING worked: `Esc` did not reach
      // `_onEscape` at all (the `Shortcuts` subtree was out of the focus
      // chain), arrows moved nothing, and Tab found nothing to land on;
      // only a mouse click on the canvas restored the keyboard. A refusal
      // that costs the user their keyboard is the clause-3 defect wearing a
      // different hat.
      _canvasFocus.requestFocus();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.reason)));
      }
    }
  }

  /// The shared tail of EVERY successful catalog placement — quick-add
  /// (double-click / row-Enter / search-box Enter, §3.2) AND the
  /// drag-from-palette commit (§3.1, added this stage): run the command,
  /// take canvas focus, make the new device the sole selection, and
  /// announce it on the status line (+ `SemanticsService.sendAnnouncement`, via
  /// `StatusMessageController`) — docs/04 §3.1 step 6's "becomes sole
  /// selection, status bar announces" applies identically to both entry
  /// points, so this is the ONE place that does it.
  ///
  /// [fromQuickAdd] separates §3.2's keyboard/click quick-add from §3.1's
  /// drag-from-palette commit, and it governs two things.
  ///
  ///  * **The caret advances past what was placed** (docs/04 §3.2) for
  ///    EVERY quick-add, including one that fell back to lowest-free-U.
  ///    This used to be conditional on the caret having been CONSUMED, on
  ///    the reasoning that a fallback placement "has nothing to do with
  ///    where the caret sits". That was true one placement at a time and
  ///    false as a loop: it left the caret pointing at wherever it had been
  ///    before, so the placement after a fallback aimed somewhere unrelated
  ///    to anything on screen. The caret's job is to say where the next one
  ///    goes; after a placement, that is just past the placement.
  ///  * **The transparency window opens** (see `_lastQuickAddId`).
  ///
  /// A drag commit does NEITHER: dragging is a deliberate, mouse-chosen
  /// position unrelated to the caret's keyboard-flow bookkeeping (docs/04
  /// §3.1 says nothing about the caret at all), and a drag is by definition
  /// not a keep-typing loop. A deliberate scope choice, stated rather than
  /// silently assumed.
  ///
  /// [caretRefusal] is the reason the caret's own U could not be used, when
  /// the keep-typing loop fell back to lowest-free-U (see
  /// `_placeFromCatalog`). It is READ OUT IN FRONT of the placement rather
  /// than dropped, because a device that lands somewhere other than where
  /// the caret was pointing is precisely the thing a user must not have to
  /// notice for themselves.
  /// [plan] is non-null only for a row a LIBRARY offered (DR-103
  /// §11.102.2). When it carries a copy, the copy and the placement go
  /// into ONE `transact`, so the whole gesture is one `Ctrl+Z`:
  /// `DocumentController.transact` applies each child on `add`, so the
  /// placement command sees the template the copy just wrote.
  ///
  /// [row] is what the user actually clicked, and it is a separate
  /// argument from [plan] because the ANNOUNCEMENT names the library,
  /// which only the row knows.
  void _finalizeCatalogPlacement(
    AddDeviceCommand command,
    String catalogId, {
    required bool fromQuickAdd,
    String? caretRefusal,
    LibraryPlacement? plan,
    PlaceableTemplate? row,
  }) {
    final copy = plan?.copy;
    if (copy == null) {
      _controller.run(command);
    } else {
      // NAMED EXPLICITLY AND NOT DEFERRED, which is deliberate: this
      // transaction's first child is the library COPY and its second is
      // the add, and the act a person performed is the add. DR-156
      // §11.155.2's null would name it after the copy. `AddDeviceCommand`
      // has a static label, so nothing here was ever affected by `#866`.
      _controller.transact(command.label, (tx) {
        tx
          ..add(copy)
          ..add(command);
      });
    }
    // Return focus to the canvas so the brand-new selection can
    // immediately respond to Delete/undo/the arrow-key nudge without an
    // extra click — mirrors `_onBeginDrag`'s existing `requestFocus()` for
    // canvas-native gestures.
    _canvasFocus.requestFocus();
    // The freshly-placed device becomes the sole selection (docs/04 §3.1
    // step 6) — a plain UI-selection update, not itself undoable (docs/03
    // §4.4: selection is observed, never document state).
    //
    // ORDER IS THE MECHANISM. `SelectionController.apply` notifies
    // synchronously, so `_forgetQuickAddSelection` runs INSIDE the line
    // below and clears `_lastQuickAddId`; the line after it is what opens
    // the window. Assigning before applying would open a window the apply
    // then closed. See `_forgetQuickAddSelection` for the latch that used
    // to sit here and why it was deleted.
    _selection.apply([command.id], SelectMode.replace);
    _lastQuickAddId = fromQuickAdd ? command.id : null;
    // AND RECOMPUTE AGAIN, because the line above is what the caret's
    // activation now depends on and it was assigned too late to be seen.
    // The `_selection.apply` on the previous line notifies SYNCHRONOUSLY,
    // so the `_recomputeCaret` it triggers has already run and observed
    // `_lastQuickAddId` at its OLD value — null, or the previous
    // placement's id. Without this second call the transparency window
    // opens after the only reader of it has finished reading, and the
    // caret stays dark for the whole keep-typing loop.
    //
    // The ordering above cannot simply be swapped: `_forgetQuickAddSelection`
    // runs inside `apply` and clears `_lastQuickAddId`, so assigning first
    // would have the apply wipe it. Hence a second recompute rather than a
    // reordering.
    _recomputeCaret();

    // DR-103 §11.102.4: ONCE PER TEMPLATE, NEVER PER PLACEMENT, and the
    // trigger is the copy having actually happened rather than a counter.
    // A second placement of the same library row copies nothing, so it
    // says nothing, and the rule cannot drift out of step with what the
    // document did because it IS what the document did.
    final copied = copy == null || row == null
        ? ''
        : 'Added ${row.body.displayName} from '
              '${row.library?.libraryName ?? 'a library'}. ';
    final prefix = '$copied${caretRefusal == null ? '' : '$caretRefusal '}';
    final placement = command.placement;
    if (placement is RailPlacement) {
      // THE REF THE COMMAND BUILT, not a key spelled again here: the
      // command resolved a version (DR-077 §11.76.3) and the height in
      // this sentence must be that version's, not v1's.
      final body = _doc.templates[templateKeyFor(command.templateRef)]?.body;
      final placedH = body == null
          ? 1
          : (placement.face == Face.front ? body.frontU : body.rearU);
      final rangeEnd = placement.ruIndex + placedH - 1;
      _status.show(
        '${prefix}Placed ${command.designator} at ${_rack.designator} '
        'U${placement.ruIndex}'
        '${placedH > 1 ? '-U$rangeEnd' : ''}, ${placement.face.name}.',
      );
      // "the caret advances past it" (docs/04 §3.2) — see [fromQuickAdd].
      if (fromQuickAdd) {
        _caret.moveTo((placement.ruIndex + placedH).clamp(1, _rack.heightU));
      }
    } else {
      _status.show('${prefix}Placed ${command.designator}.');
    }
  }

  // ── drag from palette to rails (docs/04 §3.1) ─────────────────────────
  //
  // THE MECHANISM, stated once (docs/04 §3's hard constraint: no
  // `Draggable`/`DragTarget` — hand-rolled `Listener`/pointer routing
  // only, consistent with `CanvasIntentHandler`'s existing
  // beginDrag/updateDrag/commitDrag/cancel shape):
  //
  //  1. ARM — `DevicePalettePanel`'s new `onArmDrag` fires on a plain
  //     pointer-down on a palette row (`_onPaletteArmDrag`, below), from a
  //     `Listener` wrapped OUTSIDE `CanvasIntentDetector`'s own subtree —
  //     the drag starts in a sibling widget, so it can never be
  //     `CanvasIntentDetector`'s own job. From here on, the ENTIRE rest of
  //     the gesture is tracked via `GestureBinding.instance.pointerRouter`
  //     — a global, pointer-id-keyed event bus that keeps delivering
  //     events for this exact pointer regardless of which widget (palette,
  //     divider, canvas, or nothing at all) is physically under it. This
  //     is the one Flutter primitive that can "follow a drag that started
  //     in a sibling widget" without `Draggable`; `Overlay`/`OverlayEntry`
  //     (for the cursor card / reason chip) is the other — see
  //     `_insertPaletteDragOverlay`.
  //  2. TRACK — every subsequent event for that pointer id reaches
  //     `_onPaletteGlobalPointerEvent`, which projects the raw global
  //     position into the CANVAS's own coordinate space via
  //     `_canvasBoxKey`'s `RenderBox` (`globalToLocal`, valid even when the
  //     position is outside that box's rect) and drives
  //     `DragPreviewController`'s phase machine (`_handlePaletteDragMove`).
  //  3. EVALUATE — every frame the pointer is inside the canvas widget's
  //     bounds, `_evaluateDrop` runs CR-017's two BLOCKING checks,
  //     first-failure-wins, and caches the verdict on `_paletteDrag`.
  //  4. COMMIT — a `PointerUpEvent` reads that SAME cached verdict
  //     (`_commitOrNoopPaletteDrag`): valid -> one
  //     `buildPlaceFromCatalogCommand` + `_finalizeCatalogPlacement` (the
  //     exact same placement mechanism quick-add uses); blocked -> a
  //     no-op with a 120ms ghost shake and the reason chip persisting
  //     1.2s; outside the canvas entirely -> a no-op (SCOPE DECISION: no
  //     Staging Bin exists — see the class-level scope note below).
  //  5. CANCEL — `Esc` during an in-flight drag is handled via a RAW
  //     `HardwareKeyboard.instance.addHandler` hook
  //     (`_onRawKeyDuringPaletteDrag`), registered only while a drag is in
  //     flight, because Flutter focus may be anywhere (or nowhere)
  //     specific while the pointer that armed this gesture is still down
  //     — the existing `Shortcuts`-based bindings cannot be trusted to
  //     reach whatever needs to hear it. This is the keyboard analogue of
  //     the pointer router: a global, focus-independent event bus, used
  //     ONLY while a palette drag is in flight.
  //
  // SCOPE DECISION (restated verbatim from this stage's task brief, and
  // in docs/m1-implementation-log.md's §3.1 row): only the two BLOCKING
  // CR-017 checks (front U range free; fits within rack extent) are
  // evaluated live. The five advisory/warning checks — opposite-face
  // occupancy, depth-interval fit (RCK-012), clearance above/below,
  // mount-method compatibility, half-rack-on-bare-rails — are NOT
  // implemented, not even as inert stubs: no validation/finding engine
  // (`derived/validation.dart`) exists anywhere in this codebase, and
  // building one is a separate, later M1 roadmap item ("chip strip + Rack
  // Vitals + validation rules"). The Staging Bin / `StagedPlacement` this
  // stage's escape-hatch text describes for "dragging outside any rack"
  // also does not exist (docs/m1-implementation-log.md roadmap item 4:
  // "Not started") — dropping outside the canvas widget's bounds is
  // simply a no-op here (see `_commitOrNoopPaletteDrag`).
  //
  // ONLY RACK-MOUNTABLE TEMPLATES ARM A DRAG (`frontU > 0 || rearU > 0`,
  // checked in `_onPaletteArmDrag`) — a deliberate scope narrowing, not an
  // oversight: docs/04 §3.1 is specifically "drag from palette to RAILS",
  // and a field/off-rack device (`mountMethod: notInRack`) has no rails to
  // snap to or evaluate against. Those templates stay click/double-click
  // -only (Part 1's unchanged behaviour); nothing regresses for them.

  /// docs/04 §3.1 step 1: "Arm — pointer down on a palette row."
  void armPaletteDrag(PlaceableTemplate row, PointerDownEvent event) {
    // THE "CAN THIS ROW ARM AT ALL" TESTS COME FIRST, before the claim: a
    // press on a field-device row is not a gesture, so it must not take the
    // screen from an open compaction preview for a drag that was never going
    // to start. (A subsequent click/double-click on that row places the
    // device, which runs a command, which the stale-state guard turns into
    // that same cancel — through the one path, at the moment it is true.)
    // OUT OF THE PALETTE'S OWN ROW, at the version it is offering. This
    // read `resolveLatestTemplate(_doc, catalogId)` until `#242`, which
    // was already once-fixed (from the seeded catalog, which silently
    // refused to arm a drag on every authored template) and was about to
    // break the same way again for the same reason: a library row is not
    // in the document, so the document lookup would answer null and a
    // drag from a library row would refuse to start, silently. The row
    // the palette drew is the answer, and now it is what is consulted.
    //
    // **HANDED IN SINCE `#885`** (DR-165 §11.164.2): `PaletteHost` owns
    // the list and resolves the key, so the string that could name the
    // wrong template never reaches this screen at all.
    _armedPaletteRow = row;
    _armedStagedId = null;
    final body = row.body;
    // Field devices: click/double-click-only, see above.
    final mountable = body.frontU > 0 || body.rearU > 0;
    if (!mountable) return;
    _armDrag(
      subjectId: row.rowKey,
      body: body,
      displayName: body.displayName,
      event: event,
    );
  }

  /// A Staging Bin chip, dragged out onto the rails (DR-205 §11.204.3,
  /// `#964`).
  ///
  /// THE PALETTE'S OWN DRAG, not a second one: the same ghost, the same
  /// live evaluation (`_evaluateDrop`), the same blocked shake and the same
  /// Esc, because a chip dragged to U5 and a palette row dragged to U5 are
  /// asking the rack the same question. Only the release differs, in
  /// `_commitOrNoopPaletteDrag`: this one moves an existing device, keeping
  /// its id and its wiring, where a palette release mints one.
  ///
  /// A device with no rack height does not arm, exactly as a field row
  /// does not: it has no rails to snap to, and it waits for a shelf target
  /// (`#956`).
  void armStagedDrag(Uuid id, PointerDownEvent event) {
    final device = _doc.devices[id];
    final body = device == null ? null : bodyFor(device, _doc.templates);
    if (device == null || body == null) return;
    if (body.frontU <= 0 && body.rearU <= 0) return;
    _armedPaletteRow = null;
    _armedStagedId = id;
    _armDrag(
      subjectId: 'staged:${id.v}',
      body: body,
      displayName: device.designator,
      event: event,
    );
  }

  /// The half of arming both sources share: the claim, the controller and
  /// the global pointer route.
  void _armDrag({
    required String subjectId,
    required TemplateBody body,
    required String displayName,
    required PointerDownEvent event,
  }) {
    // THE EXCLUSIVITY RULE, asked rather than restated (see that section).
    // This subsumes the hand-written concurrent-arm guard that used to live
    // here — `_liveGesture` is set for the whole life of a palette drag and
    // released in `_stopTrackingPalettePointer`, the same single place
    // `_armPointer` is cleared, so the two can never disagree. It ALSO now
    // refuses while a CANVAS gesture (a move drag or a top-edge resize) is
    // live, which the old guard did not: those are tracked through a
    // different route entirely, so both previews used to run at once.
    //
    // Arming again during a previous drag's 1.2s blocked-release linger
    // stays legitimate and stays allowed: `beginBlockedRelease` leaves the
    // pointer up, so `_stopTrackingPalettePointer` has already released the
    // claim even though `releaseLingering` is still true.
    if (!_claimPointerGesture(_PointerGesture.paletteDrag)) return;

    final face = body.frontU > 0 ? Face.front : Face.rear;
    final deviceH = face == Face.front ? body.frontU : body.rearU;

    // FIX (stale blocked-release timer): a new drag starting — even a
    // legitimate sequential one arming during the PREVIOUS drag's blocked-
    // release linger — is reason enough to stop honoring that previous
    // drag's lingering-chip timer. Left pending, it would fire later
    // against the shared `_paletteDrag`/overlay this NEW drag now owns,
    // force-resetting its live state and (independently) skipping past the
    // keyboard-handler removal on `_commitOrNoopPaletteDrag`'s early
    // return — see that method's own fix.
    _blockedReleaseTimer?.cancel();
    _blockedReleaseTimer = null;

    _armPointer = event.pointer;
    _armGlobalStart = event.position; // PointerEvent.position is always global.
    _paletteDrag.arm(
      // THE `rowKey`, not the template id: a template id can name two
      // rows (DR-102 §11.101.4). `subjectId` is opaque to
      // `DragPreviewController`, which is why a staged chip's
      // `staged:<id>` needed no change there either.
      subjectId: subjectId,
      deviceH: deviceH,
      face: face,
      displayName: displayName,
      badge: '${deviceH}U',
      sourceKinds: {event.kind},
    );
    HardwareKeyboard.instance.addHandler(_onRawKeyDuringPaletteDrag);
    GestureBinding.instance.pointerRouter.addRoute(
      event.pointer,
      _onPaletteGlobalPointerEvent,
    );
  }

  /// Every subsequent event for the armed pointer, regardless of which
  /// widget is physically under it (see the section header above).
  void _onPaletteGlobalPointerEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _paletteDrag.updateCursorGlobal(event.position);
      _handlePaletteDragMove(event.position);
    } else if (event is PointerUpEvent) {
      _paletteDrag.updateCursorGlobal(event.position);
      _handlePaletteDragMove(event.position);
      _commitOrNoopPaletteDrag();
      _stopTrackingPalettePointer();
    } else if (event is PointerCancelEvent) {
      _cancelPaletteDrag();
      _stopTrackingPalettePointer();
    }
  }

  /// docs/04 §3.1 steps 2-5: lift (past 4px), enter/exit the canvas
  /// widget's bounds, and — while inside — snap + evaluate every frame.
  void _handlePaletteDragMove(Offset globalPosition) {
    if (_paletteDrag.phase == DragPreviewPhase.none) return; // ended already.

    if (_paletteDrag.phase == DragPreviewPhase.armed) {
      final dx = globalPosition.dx - _armGlobalStart.dx;
      final dy = globalPosition.dy - _armGlobalStart.dy;
      if (math.sqrt(dx * dx + dy * dy) < _clickSlopPx) return;
      _paletteDrag.lift();
      _insertPaletteDragOverlay();
    }

    final box = _canvasBoxKey.currentContext?.findRenderObject();
    final insideCanvas =
        box is RenderBox &&
        box.attached &&
        (Offset.zero & box.size).contains(box.globalToLocal(globalPosition));

    final wasDragging = _paletteDrag.phase == DragPreviewPhase.dragging;
    if (insideCanvas && _paletteDrag.phase == DragPreviewPhase.lifted) {
      _paletteDrag.enterCanvas();
    } else if (!insideCanvas && wasDragging) {
      _paletteDrag.exitCanvas();
    }

    // Staging Bin: show when outside canvas, hide when inside
    // NOT FOR A CHIP DRAGGED OUT OF THE BIN: releasing that one off the
    // rack leaves it where it already is, and a chip saying "Release to
    // add to the Staging Bin" over it would promise a move to where the
    // device already sits.
    final isOutsideCanvas =
        _armedStagedId == null &&
        !insideCanvas &&
        _paletteDrag.phase == DragPreviewPhase.lifted;
    if (isOutsideCanvas) {
      _insertStagingBinOverlay();
    } else if (!isOutsideCanvas && _stagingBinOverlayEntry != null) {
      _removeStagingBinOverlay();
    }

    if (_paletteDrag.phase == DragPreviewPhase.dragging) {
      final canvasBox = box! as RenderBox;
      final local = canvasBox.globalToLocal(globalPosition);
      final scene = _viewport.screenToScene(DPt(local.dx, local.dy));
      final deviceH = _paletteDrag.deviceH;
      final ruIndex = _geo.ruIndexForCursorY(scene.y, deviceH);
      _paletteDrag.updateEvaluation(
        scene,
        _evaluateDrop(ruIndex, deviceH, _paletteDrag.face),
      );
    }
  }

  /// CR-017's two BLOCKING checks (docs/04 §3.1 step 5), first-failure-
  /// wins in the SAME order `buildPlaceFromCatalogCommand`'s
  /// `explicitRuIndex` path checks them (catalog_placement.dart): fits
  /// within the rack extent FIRST, then front U range free on this face.
  ///
  /// THE ONE EVALUATOR for BOTH drag gestures — the palette drag (§3.1) and
  /// the move-a-placed-device drag (§3.3, whose step 3 is literally "Same
  /// checks ... as §3.1"). The only per-gesture input is [exceptId]: a move
  /// must not be blocked by the device being moved, a palette placement has
  /// no such device. Everything else — which checks, in which order, with
  /// which wording — is identical by construction rather than by review.
  /// This order must match that function's exactly — not just reuse the
  /// same `findBlockingOccupant` call — because `RackGeometry.
  /// maxRuIndexFor` can clamp a candidate `ruIndex` for an over-tall device
  /// down into a range that ALSO happens to be occupied; checking
  /// occupancy before extent in that situation would report "Occupied by
  /// X" for the whole drag while the commit-time function (extent-first)
  /// would instead say "Needs NU, only MU free at top" for that exact same
  /// ruIndex/deviceH/rack state — the live drag disagreeing with what
  /// committing at that instant would actually do, which is exactly what
  /// this evaluator exists to prevent (docs/04's "commit reads the last
  /// live-evaluated state" only holds if the two never disagree in the
  /// first place). Reuses `findBlockingOccupant` exactly as keyboard-nudge
  /// and quick-add's `explicitRuIndex` path do (catalog_placement.dart's
  /// own doc comment: "so both surfaces report the exact same occupant for
  /// the exact same range") — no new core function is added.
  DragPreviewEvaluation _evaluateDrop(
    int ruIndex,
    int deviceH,
    Face face, {
    Uuid? exceptId,
  }) {
    final overflow = ruIndex + deviceH - 1 > _rack.heightU;
    if (overflow) {
      final freeAtTop = (_rack.heightU - ruIndex + 1).clamp(0, _rack.heightU);
      return DragPreviewEvaluation(
        ruIndex: ruIndex,
        blocked: true,
        reason: 'Needs ${deviceH}U, only ${freeAtTop}U free at top.',
      );
    }

    final blocker = findBlockingOccupant(
      rack: _rack,
      devices: _doc.devices.values,
      face: face,
      templates: _doc.templates,
      ruStart: ruIndex,
      deviceH: deviceH,
      exceptId: exceptId,
    );
    if (blocker != null) {
      final blockerPlacement = blocker.placement;
      final start = blockerPlacement is RailPlacement
          ? blockerPlacement.ruIndex
          : ruIndex;
      final snapshot = _doc.templates[_templateKeyOf(blocker)];
      final h = snapshot == null
          ? 1
          : (face == Face.front ? snapshot.body.frontU : snapshot.body.rearU);
      final end = start + h - 1;
      return DragPreviewEvaluation(
        ruIndex: ruIndex,
        blocked: true,
        reason: 'Occupied by ${blocker.designator} (U$start-U$end).',
        blockingRect: _layoutFor(blocker.id.v)?.rect,
      );
    }

    return DragPreviewEvaluation(ruIndex: ruIndex, blocked: false);
  }

  /// `"$templateId@$version"` — the SAME key format
  /// `catalog_placement.dart`'s own private `_templateKey` computes,
  /// duplicated here as a one-line UI-side lookup (matching
  /// `_placeFromCatalog`'s own existing inline `catalogTemplateKey(...)`
  /// pattern) rather than exporting a new core symbol for it.
  String _templateKeyOf(DeviceInstance device) =>
      '${device.templateRef.templateId.v}@${device.templateRef.version}';

  /// docs/04 §3.1 step 6 (valid) / step 5 (blocked) / the outside-canvas
  /// SCOPE DECISION (no-op) — a `PointerUpEvent` on the armed pointer.
  void _commitOrNoopPaletteDrag() {
    // FIX (Esc-handler leak): removed UNCONDITIONALLY, first, before the
    // null-catalogId early return below — that early return fires when a
    // stale blocked-release timer already reset `_paletteDrag` out from
    // under a still-live second drag (see `_onPaletteArmDrag`'s own fix),
    // and it used to skip past every branch's own removeHandler call,
    // leaking `_onRawKeyDuringPaletteDrag` onto `HardwareKeyboard.instance`
    // forever (it would then swallow every future Esc keypress in the
    // app). `_removePaletteEscHandler` is idempotent, so calling it here
    // AND (redundantly, harmlessly) nowhere else below is correct.
    _removePaletteEscHandler();

    final rowKey = _paletteDrag.subjectId;
    if (rowKey == null) return;

    if (_paletteDrag.phase != DragPreviewPhase.dragging) {
      // Released while still armed/lifted — outside the canvas widget's
      // bounds entirely. docs/04 §3.1's escape hatch wants this to create a
      // `StagedPlacement`, and it CANNOT yet: no command produces one and
      // no surface lists the bin, so a device dropped there would vanish
      // with no way to get it back (docs/m1-implementation-log.md §4.2).
      // So it stays a no-op — but a no-op that SAYS SO, per "never
      // silently do nothing". The Staging Bin chip that was on screen a
      // moment ago says the same thing while the pointer is still down;
      // this is the same claim at the moment of release.
      //
      // ── EXCEPT WHEN THE POINTER NEVER MOVED, and that exception is a
      // DEFECT FIX rather than a new rule (`#242`) ──────────────────────
      //
      // `armed` is not a released drag. `DragPreviewPhase.armed`'s own
      // comment says what it is: below the 4px slop, "might still just be
      // a click/double-click", because docs/04 §3.1 step 1 requires that
      // "nothing until 4 px of movement, so a click still means 'show
      // details'". Every pointer-down on a palette row arms (AC-016 #23,
      // no gesture-outcome branch), so a plain CLICK on a row reached
      // here and announced *"Released outside the rack — HDMI Matrix 4x4
      // was not placed. The Staging Bin is not in this build."* for a
      // gesture the user never made. So did the second half of every
      // DOUBLE-click, which is how it was found: it landed after the
      // placement and overwrote *"Placed MTX-1 at RK-1 U1, front."*, and
      // then DR-103 §11.102.4's copy announcement on top of that.
      //
      // "Never silently do nothing" is about a REFUSED ACTION. A press
      // that never became a drag was not an action, and narrating it is
      // the same noise the rule exists to prevent, pointed the other way.
      final lifted = _paletteDrag.phase == DragPreviewPhase.lifted;
      final row = _armedPaletteRow;
      final staged = _armedStagedId;
      _removePaletteDragOverlay();
      _removeStagingBinOverlay();
      _paletteDrag.reset();
      // A BIN CHIP RELEASED OFF THE RACK stays in the bin, and says so
      // only when it was really dragged: a click on a chip arms too.
      if (staged != null) {
        if (lifted) {
          _status.show(
            '${_doc.devices[staged]?.designator ?? 'The device'} stays in '
            'the Staging Bin.',
          );
        }
        return;
      }
      if (!lifted || row == null) return;
      // ── THE STAGING BIN IS BUILT (DR-205), so a release off the rack
      // stages the device rather than narrating a no-op. docs/04 §3.1:
      // *"dropping there creates a `StagedPlacement`"*. The same library
      // plan and the same finalising path a placement uses, so a library
      // row copies once and the new device becomes the selection.
      final plan = row.provenance is LibraryProvenance
          ? planLibraryPlacement(
              _doc,
              row,
              capturedAt: _controller.clock.nowUtc(),
            )
          : null;
      final command = buildAddStagedCommand(
        doc: _doc,
        catalogId: plan?.templateId ?? row.id,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
        using: plan?.snapshot,
      );
      if (command == null) {
        _status.show('That template is no longer in this project.');
        return;
      }
      _finalizeCatalogPlacement(
        command,
        plan?.templateId ?? row.id,
        fromQuickAdd: false,
        plan: plan,
        row: row,
      );
      _status.show('${command.designator} is in the Staging Bin.');
      return;
    }

    final evaluation = _paletteDrag.evaluation;
    if (evaluation == null || evaluation.blocked) {
      // Blocked release (docs/04 §3.1 step 5 verbatim): "Release while
      // blocked is a no-op with a 120ms shake and the chip persisting
      // 1.2s."
      _shake.trigger(kDragGhostShakeId);
      _paletteDrag.beginBlockedRelease();
      _blockedReleaseTimer?.cancel();
      _blockedReleaseTimer = Timer(const Duration(milliseconds: 1200), () {
        _paletteDrag.reset();
        _removePaletteDragOverlay();
        _blockedReleaseTimer = null;
      });
      return;
    }

    // Valid commit — reads the ruIndex this frame's live evaluation
    // already verified free, then calls the SAME
    // `buildPlaceFromCatalogCommand` quick-add uses (one placement
    // mechanism, two entry points). Constructed fresh at commit time
    // (rather than reusing a cached `AddDeviceCommand` object) so the
    // command's `now`/minted id reflect the actual moment of commit, not
    // some earlier frame — the verdict being committed to (the ruIndex/
    // blocked flag) is still exactly what was last shown, per docs/04's
    // "commit reads the last live-evaluated state".
    _controller.selection = _selection.snapshot();
    if (_armedStagedId case final staged?) {
      final face = _paletteDrag.face;
      _removePaletteDragOverlay();
      _paletteDrag.reset();
      _placeStagedOnRail(staged, evaluation.ruIndex, face);
      return;
    }
    // THE SAME PLAN THE QUICK-ADD PATH USES (DR-103 §11.102.2), because
    // dragging a library row onto the rails is the same act as
    // double-clicking it. One placement mechanism, two entry points, and
    // the copy-on-place rule is a property of the first rather than of
    // either entry.
    // THE ROW THIS DRAG WAS ARMED WITH. It used to be re-resolved out of
    // this screen's own index from `subjectId`; the index is
    // `PaletteHost`'s now, and re-asking would mean asking a second
    // owner. Null is unreachable after an arm and is handled rather than
    // asserted, on this file's habit: a projection can be one row short
    // for a frame and that is not a crash.
    final row = _armedPaletteRow;
    if (row == null) {
      _removePaletteDragOverlay();
      _paletteDrag.reset();
      return;
    }
    final plan = row.provenance is LibraryProvenance
        ? planLibraryPlacement(
            _doc,
            row,
            capturedAt: _controller.clock.nowUtc(),
          )
        : null;
    final result = buildPlaceFromCatalogCommand(
      doc: _doc,
      catalogId: plan?.templateId ?? row.id,
      targetRack: _rack,
      now: _controller.clock.nowUtc(),
      actor: _controller.actor,
      explicitRuIndex: evaluation.ruIndex,
      using: plan?.snapshot,
    );
    _removePaletteDragOverlay();
    _paletteDrag.reset();

    if (result is CatalogPlacementReady) {
      _finalizeCatalogPlacement(
        result.command,
        plan?.templateId ?? row.id,
        fromQuickAdd: false,
        plan: plan,
        row: row,
      );
    } else if (result is CatalogPlacementFailed) {
      // Unreachable in practice (this frame's own evaluation just said
      // valid) but handled honestly rather than assumed impossible — a
      // genuine same-frame TOCTOU would land here rather than silently
      // doing nothing.
      _status.show(result.reason);
    }
  }

  /// `Esc` during an in-flight palette drag (docs/04's escape hatches:
  /// "Esc cancels, ghost fades ... palette row restores"). Registered via
  /// `HardwareKeyboard.instance.addHandler` — see the section header for
  /// why a raw, focus-independent hook is needed here specifically.
  ///
  /// RETURNING `true` DOES NOT STOP THE `Shortcuts` BINDING. It reads like
  /// it should, and it does not: `KeyEventManager` combines the two verdicts
  /// with `handled = keyMessageHandler!(message) || handled`, so the raw
  /// handlers and the focus-scoped dispatch BOTH run for the same keypress —
  /// this one first, because `HardwareKeyboard.handleKeyEvent` is called
  /// before `keyMessageHandler`. That is why the latch below exists: without
  /// it, one `Esc` cancelled the drag AND fell through to `_onEscape`'s
  /// deselect limb, emptying a selection the user had built before the drag
  /// ever started.
  bool _onRawKeyDuringPaletteDrag(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    // Latched only when there is genuinely a drag (or a lingering blocked
    // release) to cancel — the SAME predicate `_cancelPaletteDrag` early-
    // returns on, so the latch and the cancel can never disagree. A stale
    // registration of this hook (the leak class `_removePaletteEscHandler`
    // documents) would otherwise swallow one perfectly ordinary deselect.
    _escConsumedByPaletteDrag =
        _paletteDrag.subjectId != null || _paletteDrag.releaseLingering;
    // Lowered by a microtask rather than by whoever reads it, so its
    // lifetime is EXACTLY this one key event and cannot be extended by a
    // reader that never runs. The whole key dispatch — this handler, then
    // `Shortcuts`, then `_onEscape` — is synchronous inside one platform
    // message, and microtasks drain after it, so the latch is up for the
    // rest of this event and down before the next one. A latch cleared by
    // `_onEscape` instead would stay up forever the moment an `Esc` cancels
    // a drag while the canvas does not have focus, and would then silently
    // swallow the NEXT deselect.
    scheduleMicrotask(() => _escConsumedByPaletteDrag = false);
    _cancelPaletteDrag();
    return true;
  }

  /// Idempotent — `HardwareKeyboard.removeHandler` is a documented safe
  /// no-op when [_onRawKeyDuringPaletteDrag] is not currently registered
  /// (it just tries to remove it from an internal list). Every method that
  /// might end a palette drag's lifecycle (commit/no-op, Esc cancel,
  /// `dispose`) calls this UNCONDITIONALLY as its very first step, rather
  /// than only on the branches that "know" they're ending a drag — this is
  /// what closes the leak class where an early return (state already
  /// cleared by a stale blocked-release timer, or a drag that had already
  /// ended) used to skip past handler removal entirely, leaving this hook
  /// registered forever and silently swallowing every subsequent Esc
  /// keypress in the app.
  void _removePaletteEscHandler() {
    HardwareKeyboard.instance.removeHandler(_onRawKeyDuringPaletteDrag);
  }

  void _cancelPaletteDrag() {
    // See `_removePaletteEscHandler`'s own doc comment: called first and
    // unconditionally so this method removing itself (it is reached FROM
    // `_onRawKeyDuringPaletteDrag`, the very handler being removed) still
    // happens even when the early return below fires — e.g. a stale
    // blocked-release timer already reset `_paletteDrag` while this raw Esc
    // hook was still registered on a since-ended drag.
    _removePaletteEscHandler();

    if (_paletteDrag.subjectId == null && !_paletteDrag.releaseLingering) {
      return;
    }
    _removePaletteDragOverlay();
    // Esc pressed while the pointer was OUTSIDE the canvas: the drag is
    // over, so the Staging Bin chip must go with the ghost. Without this
    // it survived the cancel and stayed on screen until the next drag.
    _removeStagingBinOverlay();
    _stopTrackingPalettePointer();
    _blockedReleaseTimer?.cancel();
    _blockedReleaseTimer = null;
    _paletteDrag.reset();
  }

  /// THE ONE EXIT for a palette gesture — pointer-up, pointer-cancel, `Esc`
  /// and `dispose` all funnel through it, which is why it is also where the
  /// exclusivity claim is released (the sibling of `_resetDrag`'s own).
  void _stopTrackingPalettePointer() {
    final pointer = _armPointer;
    if (pointer != null) {
      GestureBinding.instance.pointerRouter.removeRoute(
        pointer,
        _onPaletteGlobalPointerEvent,
      );
      _armPointer = null;
    }
    _releasePointerGesture(_PointerGesture.paletteDrag);
  }

  void _insertPaletteDragOverlay() {
    if (_paletteDragOverlayEntry != null) return;
    _paletteDragOverlayEntry = OverlayEntry(
      builder: (context) => _DragPreviewOverlay(
        controller: _paletteDrag,
        viewport: _viewport,
        geo: _geo,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_paletteDragOverlayEntry!);
  }

  void _removePaletteDragOverlay() {
    _paletteDragOverlayEntry?.remove();
    _paletteDragOverlayEntry = null;
  }

  /// docs/04 §3.1's escape hatch, honestly: the chip that appears while a
  /// palette drag is outside every rack. It says what releasing here will
  /// actually do — see [StagingBinOverlay] and `_commitOrNoopPaletteDrag`.
  ///
  /// The overlay positions itself off `controller.cursorGlobal`, so it
  /// needs nothing from the screen but the controller.
  void _insertStagingBinOverlay() {
    if (_stagingBinOverlayEntry != null) return;
    _stagingBinOverlayEntry = OverlayEntry(
      builder: (context) => StagingBinOverlay(controller: _paletteDrag),
    );
    Overlay.of(context, rootOverlay: true).insert(_stagingBinOverlayEntry!);
  }

  void _removeStagingBinOverlay() {
    _stagingBinOverlayEntry?.remove();
    _stagingBinOverlayEntry = null;
  }

  /// The move drag's RU-range + reason chips (docs/04 §3.3 step 3's
  /// inherited §3.1 chrome). The SAME widget the palette drag uses, minus
  /// the pre-canvas-entry cursor card: a move drag never has a pre-entry
  /// stage (it is grabbed inside the canvas), so there is nothing for that
  /// card to represent — see [_DragPreviewOverlay.showCursorCard].
  void _insertMoveDragOverlay() {
    if (_moveDragOverlayEntry != null) return;
    _moveDragOverlayEntry = OverlayEntry(
      builder: (context) => _DragPreviewOverlay(
        controller: _moveDrag,
        viewport: _viewport,
        geo: _geo,
        showCursorCard: false,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_moveDragOverlayEntry!);
  }

  void _removeMoveDragOverlay() {
    _moveDragOverlayEntry?.remove();
    _moveDragOverlayEntry = null;
  }

  /// Coarse (non-per-frame) reaction to `_paletteDrag` — see that field's
  /// own doc comment for why this is filtered rather than a screen-wide
  /// `setState` on every evaluate/cursor update.
  void _onPaletteDragChanged() {
    final inProgress = _paletteDrag.isInProgress;
    if (inProgress != _lastPaletteDragInProgress) {
      _lastPaletteDragInProgress = inProgress;
      _recomputeCaret();
    }
    // PUBLISHED, NOT REBUILT. Only the palette ever read this, and the
    // palette is `PaletteHost`'s now. `ValueNotifier` does the equality
    // filter the hand-written compare used to do.
    widget.paletteDragRow?.value = _paletteDrag.isSourceEngaged
        ? _paletteDrag.subjectId
        : null;
  }

  /// The same coarse filter for `_moveDrag`: rebuild ONLY when which device
  /// should paint at 30% opacity changes (docs/04 §3.3 step 1), i.e. once at
  /// drag start and once at drag end — never on the per-frame evaluation
  /// updates, which `EditingOverlayPainter` and `_DragPreviewOverlay` pick
  /// up by listening to `_moveDrag` directly.
  void _onMoveDragChanged() {
    final sourceId = _moveDrag.isSourceEngaged ? _moveDrag.subjectId : null;
    if (sourceId != _lastMoveDragSourceId) {
      _lastMoveDragSourceId = sourceId;
      if (mounted) setState(() {});
    }
  }

  /// What this screen draws for a document with no racks in it.
  ///
  /// It is `NoRacksView` — the SAME panel the app shell shows, wired to the
  /// SAME `showNewRack`, rather than a second empty state that could drift
  /// from it. Reaching it at all is new: until the shell's rack-less panel
  /// grew a Create button, no sequence of edits could take a mounted canvas
  /// down to zero racks (see [_activeRack]).
  ///
  /// AN EMPTY RACK CANVAS HERE WOULD BE A LIE — rails and a ruler for a rack
  /// that is not in the document, which is exactly what `no_racks_view.dart`
  /// was written to avoid.
  Widget _racklessPanel() => NoRacksView(
    documentName: _doc.info.projectName,
    onNewRack: () => unawaited(_showNewRackDialog()),
  );

  @override
  Widget build(BuildContext context) {
    if (_activeRack == null) return _racklessPanel();
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

    // CR-105's counts, computed once per build beside the scene and for
    // the same reason: the pointer path reads them back, so they have to
    // be the ones this frame drew. Cheap next to `buildRackScene` — one
    // pass over the conductors plus a set lookup per pin (`port_fill.dart`).
    _portFill = widget.onRevealInSchematic == null
        ? const <Uuid, PortFill>{}
        : portFillByDevice(_doc);

    // Shortcuts/Actions + an autofocused Focus give the canvas Del/Backspace
    // (delete the selection) and Ctrl/Cmd+Z / Ctrl/Cmd+Shift+Z / Ctrl+Y
    // (undo/redo). SingleActivator's exact-modifier match keeps Ctrl+Z and
    // Ctrl+Shift+Z mutually exclusive, so redo never also fires undo.
    //
    // ══════════════════════════════════════════════════════════════════
    // THE KEYS ARE DECLARED IN `keymap.dart`, NOT HERE (macOS debt D7)
    // ══════════════════════════════════════════════════════════════════
    // Eighteen `SingleActivator` literals used to sit in this map, five of
    // them hard-coding `control: true`. They are now sixteen rows in
    // `kKeymap` under `KeyScope.rack`, and `keymapShortcuts` resolves the
    // primary modifier per platform — `Ctrl` on Windows, `Cmd` on macOS —
    // through `defaultTargetPlatform`.
    //
    // SIXTEEN, NOT EIGHTEEN, and the two that went are the point of the
    // exercise rather than a loss. This map carried BOTH
    // `SingleActivator(keyZ, control: true)` and
    // `SingleActivator(keyZ, meta: true)` (and the same pair with
    // `shift`), because somebody had already anticipated macOS and paid
    // for it in duplicate literals — a per-file, hand-rolled D7. One
    // `primary` row now says what two said. See `kKeymap`'s undo entry for
    // what that removes on Windows and why nothing else moves.
    //
    // WHAT THIS FILE STILL OWNS is the `Actions` map below: the registry
    // declares what a key MEANS, this screen decides when it is ALLOWED
    // to mean it. That division is load-bearing — see `_GatedAction`.
    return Shortcuts(
      shortcuts: keymapShortcuts(KeyScope.rack),
      child: Actions(
        // EVERY ENTRY HERE IS GATED. Not one may be a `CallbackAction`: see
        // `_GatedAction`'s doc comment for why a `CallbackAction` swallows
        // its key even when its body declines to act, and why this screen's
        // `Shortcuts` sits in front of six text fields rather than behind
        // them. The three predicates in use, and the reason each binding
        // gets the one it does:
        //
        //   `_canvasFocus.hasFocus`  — the key MEANS something about the
        //       rack. Stricter than "no text field has focus", and it has
        //       to be: from canvas focus, one `Tab` lands on a plain
        //       (non-text) `FocusNode` in the palette, where a text-only
        //       test would still let `Delete` destroy a device.
        //
        //   `!_textFieldHasFocus`    — the key is DOCUMENT-GLOBAL. Undo and
        //       redo must keep working from the palette, the inspector and
        //       the toolbar; scoping them to the canvas would reintroduce
        //       the exact defect app_shell.dart's header post-mortems for
        //       `Ctrl+S` ("The document is global; its keys have to be
        //       too").
        //
        //   a mode test                — the key cancels or applies something
        //       that is currently in flight, and is meaningless otherwise.
        actions: <Type, Action<Intent>>{
          // DESTRUCTIVE. Canvas focus, not merely "not a text field" — see
          // the Tab case above. `_deleteSelection` repeats this guard in
          // its own body as a deliberate second line of defence.
          DeleteSelectionIntent: _GatedAction<DeleteSelectionIntent>(
            () => _canvasFocus.hasFocus,
            _deleteSelection,
          ),
          // `Ctrl+L` (DR-186 §11.185.2). DOCUMENT-WIDE LIKE UNDO, not
          // canvas-focused like Delete: it destroys nothing, and a person
          // who has just ticked a field in the inspector means the
          // selection that inspector is showing. Disabled with nothing
          // selected, so the key falls through rather than being eaten.
          ToggleLockIntent: _GatedAction<ToggleLockIntent>(
            () => !_textFieldHasFocus && _selection.isNotEmpty,
            _toggleLockSelection,
          ),
          // `U` (DR-205): a PLAIN letter, so gated off in a text field like
          // every other one here, and off with nothing selected so the key
          // falls through.
          StageSelectionIntent: _GatedAction<StageSelectionIntent>(
            () => !_textFieldHasFocus && _selection.isNotEmpty,
            _stageSelection,
          ),
          // Document-global: a rack rename typed in the inspector and an
          // undo pressed from the palette are both legitimate.
          //
          // THE REACH CAUGHT UP WITH THE GATE AT DR-159 §11.158.3. This
          // comment used to end "and `Ctrl+Z` still reaches nothing at
          // all on the Schematic and Schedule tabs", which was a count
          // written when the strip had four; DR-091 reordered and
          // extended it and `PLAN-E/5` added Plan, and it moved neither
          // time. It was six of seven by the time a person hit it.
          //
          // **THIS HANDLER STAYS, AND IT IS NOT A DUPLICATE OF THE GLOBAL
          // ONE** (§11.158.4). Flutter resolves an `Action` from the
          // focused context upward, so this wins whenever focus is inside
          // this screen, and it does something the shell's fallback
          // cannot: `undoLast` returns the selection as it was, and
          // restoring it is what makes undoing a delete put the selection
          // back instead of leaving somebody staring at an empty
          // inspector.
          UndoIntent: _GatedAction<UndoIntent>(
            () => !_textFieldHasFocus,
            _undo,
          ),
          RedoIntent: _GatedAction<RedoIntent>(
            () => !_textFieldHasFocus,
            _redo,
          ),
          // `FocusPaletteSearchIntent` IS NOT HANDLED HERE ANY MORE
          // (`#885`, DR-165 §11.164.4). The keymap still maps `/` to it
          // in this scope, and the intent now bubbles to `PaletteHost`,
          // which is the only thing in the tree holding the field. Its
          // gate travelled with it: the one thing `/` must never do is
          // fail to type a slash into a field.
          // Each of these already tested `_canvasFocus.hasFocus` in its own
          // body. The test MOVES to the gate — same condition, but now it
          // releases the key instead of eating it, so a focused header
          // stepper gets its own Up/Down and a text field gets its own
          // Home/End.
          CaretUpIntent: _GatedAction<CaretUpIntent>(
            () => _canvasFocus.hasFocus,
            _onArrowUp,
          ),
          CaretDownIntent: _GatedAction<CaretDownIntent>(
            () => _canvasFocus.hasFocus,
            _onArrowDown,
          ),
          CaretHomeIntent: _GatedAction<CaretHomeIntent>(
            () => _canvasFocus.hasFocus,
            _onHome,
          ),
          CaretEndIntent: _GatedAction<CaretEndIntent>(
            () => _canvasFocus.hasFocus,
            _onEnd,
          ),
          CaretPageUpIntent: _GatedAction<CaretPageUpIntent>(
            () => _canvasFocus.hasFocus,
            _onPageUp,
          ),
          CaretPageDownIntent: _GatedAction<CaretPageDownIntent>(
            () => _canvasFocus.hasFocus,
            _onPageDown,
          ),
          // Esc is a MODE key first and a deselect key second, so canvas
          // focus alone would be wrong: a compaction preview started from
          // the rack header's overflow menu must still be cancellable while
          // that menu holds focus. The palette-drag limb needs no clause
          // here — that case is served by the raw `HardwareKeyboard` hook
          // (`_onRawKeyDuringPaletteDrag`), which runs ahead of the focus
          // chain and returns false for every key but Escape.
          //
          // WHY A `Shortcuts` BINDING SUFFICES FOR THE MOVE DRAG when the
          // PALETTE drag needed that raw hook, since the asymmetry reads
          // like an inconsistency: a palette drag is armed from a sibling
          // widget while Flutter focus may be anywhere (or nowhere), so no
          // focus-scoped binding could be trusted to hear the key. A move
          // drag has the opposite guarantee — `_onBeginDrag` calls
          // `_canvasFocus.requestFocus()` as its very first statement, so
          // the canvas provably owns focus for the whole gesture. Using the
          // ordinary binding here keeps this out of the
          // handler-registration leak class those raw hooks live in, at the
          // cost of one deliberately-stated asymmetry.
          //
          // WITH NOTHING IN FLIGHT IT CLEARS THE SELECTION — docs/04 §8's
          // third limb, "cancel drag, exit mode, clear selection" — and it
          // does NOT deselect when the same keypress just cancelled a
          // palette drag (see `_onEscape`).
          RackCancelIntent: _GatedAction<RackCancelIntent>(
            () =>
                _resize.isActive ||
                _compaction.isActive ||
                _moveDrag.isInProgress ||
                (!_textFieldHasFocus && _canvasFocus.hasFocus),
            _onEscape,
          ),
          // `Ctrl+Alt` is `AltGr` on Windows, so on layouts where AltGr+U /
          // AltGr+N is a printable character these bindings would eat it.
          // Gating on `!_textFieldHasFocus` means the character survives
          // wherever it could actually be typed. (The collision remains
          // when the canvas has focus; see docs/04 §8.)
          RackSettingsIntent: _GatedAction<RackSettingsIntent>(
            () => !_textFieldHasFocus,
            () => _showRackInspector(focusFirstField: true),
          ),
          NewRackIntent: _GatedAction<NewRackIntent>(
            () => !_textFieldHasFocus,
            () => unawaited(_showNewRackDialog()),
          ),
          // F7 / F8 / Shift+F8 ARE NOT HANDLED HERE ANY MORE (DR-193
          // §11.192). They were, and only here, so on four views of six
          // the keys the keymap calls global did nothing. The shell handles
          // them at the app root now, with ONE cursor over the findings,
          // and reaches this screen through `reveal` when a finding is
          // fixed on the Rack view. A handler kept here would win whenever
          // this canvas had focus and walk a second cursor.
          // NOT a `CallbackAction`. See the class's own doc comment: a
          // CallbackAction returning null still reports the key as HANDLED,
          // which would swallow every `Enter` in the palette search box and
          // on every focusable palette row.
          ApplyCompactionIntent: _ApplyCompactionAction(this),
        },
        // ═══════════════════════════════════════════════════════════════
        // A COLUMN, BECAUSE docs/04 §1 PUTS THE DRAWER UNDER ALL THREE
        // ═══════════════════════════════════════════════════════════════
        // The validation drawer is a horizontal band across the shell,
        // not a fourth column, so it wraps the palette/canvas/inspector
        // row rather than joining it. That is why `#847` needed neither
        // the unbuilt `PanelHost` seam nor a share of the inspector's
        // 320 px: the decision had been made in the layout table and
        // simply never built (DR-133 §11.132.2).
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // THE PALETTE COLUMN IS `PaletteHost`'s (`#885`,
                  // DR-165 §11.164.1). It stood here, 280px wide, and it
                  // was the only one in the tree, so the Plan tab had a
                  // built gesture and nothing on screen to start it.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                        // docs/04 §1's STAGING BIN, under the canvas and
                        // only while it holds something (DR-205).
                        if (_stagedChips() case final chips
                            when chips.isNotEmpty) ...[
                          const Divider(height: 1),
                          StagingBinStrip(
                            chips: chips,
                            selectedIds: _selection.ids.toSet(),
                            onSelect: _selectStaged,
                            onReturn: _returnFromStaging,
                            onArmDrag: armStagedDrag,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  // docs/04 §1's 320px inspector column, the FOURTH
                  // column, added this stage. §4's `RackInspector` and
                  // the minimal selection summary share it; see
                  // inspector_panel.dart's header for how "the
                  // RackInspector REPLACES the Selection section" is
                  // honoured given there was no Selection section to
                  // replace.
                  SizedBox(
                    width: 320,
                    child: InspectorPanel(
                      target: _inspectorTarget,
                      rack: _rack,
                      doc: _doc,
                      presets: _presets,
                      selectedIds: _selection.ids.toSet(),
                      focusedId: _selection.focus,
                      onSetProperty: _setRackProperty,
                      onRename: _renameRack,
                      onRequestHeight: _requestHeight,
                      onApplyPreset: _applyPreset,
                      onSaveAsPreset: widget.onSaveAsPreset,
                      onRefuse: _status.show,
                      onSetLifecycle: _setSelectionLifecycle,
                      onSetWidth: _setSelectionWidth,
                      onSetOverride: _setDeviceOverride,
                      onSetPortFact: _setPortFact,
                      onSetMountNote: _setMountNote,
                      onSetLocked: (lock) => _setLockSelection(lock: lock),
                      onZeroU: _runZeroU,
                      onMoveZeroU: _moveZeroUOccupant,
                      onAddZeroUDevice: _addZeroUOccupant,
                      onResizeZeroU: _resizeZeroUOccupant,
                      firstFieldFocus: _inspectorFirstFieldFocus,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // THE HOST `DrcPanel` NEVER HAD (`#847`, DR-133). Everything
            // M5-F built has been real, tested and unreachable since it
            // shipped, and nothing outside that widget file called
            // `evaluateDocument` or `groupFindings` at all.
            ValidationDrawer(
              findings: _findings,
              groups: groupFindings(
                _doc,
                _findings,
                by: _drcGrouping,
                severities: _drcSeverities,
                includeAcknowledged: _drcIncludeAcknowledged,
              ),
              grouping: _drcGrouping,
              onGroupingChanged: (FindingGrouping g) =>
                  setState(() => _drcGrouping = g),
              expanded: _drcExpanded,
              onExpandedChanged: (bool v) => setState(() => _drcExpanded = v),
              height: _drcHeight,
              onHeightChanged: (double h) => setState(() => _drcHeight = h),
              onReveal: _revealFinding,
              // ═══════════════════════════════════════════════════════
              // SUPPLIED SINCE `#875`, AND THE THIRD TIME ROUND FOR THIS
              // FEATURE
              // ═══════════════════════════════════════════════════════
              // DR-128 §11.127.5 said the panel "renders it as a button"
              // and it did not; DR-129 §11.128.4 recorded that and built
              // the button. This is the SAME defect one layer up: the
              // button existed, the dialogs existed, the commands
              // existed with real reverts and their own suites, and THIS
              // MOUNT — the only one in the product — passed none of the
              // three callbacks. Each is nullable and documented as
              // "null shows no button rather than a dead one", so
              // nothing rendered, nothing failed, and acknowledging a
              // finding was unreachable from anywhere.
              severityFilter: _drcSeverities,
              onSeverityFilterChanged: (s) => setState(
                // THE EMPTY SET MEANS "no filter", not "hide everything".
                // `DrcPanel`'s chips deselect down to none, and a person
                // who has turned every chip off has asked to stop
                // filtering rather than to see an empty panel.
                () => _drcSeverities = s.isEmpty ? null : s,
              ),
              includeAcknowledged: _drcIncludeAcknowledged,
              onIncludeAcknowledgedChanged: (v) =>
                  setState(() => _drcIncludeAcknowledged = v),
              onAcknowledge: (f) => unawaited(_acknowledgeFinding(f)),
              onWithdraw: _withdrawAcknowledgement,
              onRemedy: (f) => unawaited(_applyFindingRemedy(f)),
            ),
          ],
        ),
      ),
    );
  }

  /// Every finding on the CURRENT document, severity resolved and
  /// acknowledgements applied.
  ///
  /// RECOMPUTED ON BUILD, which is honest for M5 and is not the end
  /// state. `evaluateDocument` walks the whole document, and the epoch
  /// machinery exists so a derived view can recompute only when the
  /// epochs it reads bump. Wiring this to `wires`/`structure`/`meta` is
  /// real work with a real payoff and it is NOT this chapter: `#847` is
  /// about the panel being reachable at all, and a correctness problem
  /// would be a worse thing to ship than a performance one. Filed.
  List<Finding> get _findings => evaluateDocument(_doc);

  FindingGrouping _drcGrouping = FindingGrouping.severity;

  /// docs/05 §8's two filters, which were built and unreachable until
  /// `#875`. Null means "every severity", which is not the same as the
  /// empty set: an empty set would hide everything, and a filter whose
  /// default hid the findings would be a panel that opens onto nothing.
  Set<Severity>? _drcSeverities;
  bool _drcIncludeAcknowledged = true;
  bool _drcExpanded = false;
  double _drcHeight = kDrawerAutoHeight;

  /// Selects the entity a finding points at, so "reveal" means the same
  /// thing here as it does everywhere else in this screen.
  /// CR-019's acknowledgement, at whichever of its two scopes the
  /// person chose (`#875`).
  ///
  /// **A RE-CHECK OF THE VERDICT WAS WRITTEN HERE AND DELETED**, on
  /// `.okf/practices/a-guard-the-model-makes-unreachable.md`. It survived
  /// being mutated away, which is the finding: `_AcknowledgeDialog`
  /// computes `evaluateAcknowledgement` from the same three inputs and
  /// makes its confirm `onPressed` null on a refusal, so a choice that
  /// comes back from it is allowed by construction. That invariant is
  /// pinned where it lives, by
  /// `acknowledge_finding_dialog_test.dart`'s *"a project-wide mute is
  /// refused until a reason is written"*, rather than re-asked here where
  /// nothing could cover it.
  Future<void> _acknowledgeFinding(Finding finding) async {
    final choice = await showAcknowledgeFindingDialog(
      context: context,
      finding: finding,
    );
    if (choice == null || !mounted) return;

    final fingerprint = choice.projectWide
        ? kProjectWideFingerprint
        : finding.targetFingerprint;

    _controller.run(
      AcknowledgeFindingCommand(
        ruleId: finding.ruleId,
        targetFingerprint: fingerprint,
        reason: choice.reason,
        demotedTo: choice.demotedTo,
        // NULL FOR A PROJECT-WIDE MUTE, which is the command's own
        // contract: "a project-wide mute is about no entity at all", so
        // clicking its row must not select the rack that happened to
        // raise the finding first.
        targetEntityId: choice.projectWide ? null : finding.primaryEntityId,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      ),
    );
    setState(() {});
  }

  /// Takes one back. Never both directions on one row: `DrcPanel` offers
  /// whichever matches the state, because a row offering both would be
  /// asking which way the state already is.
  void _withdrawAcknowledgement(FindingRow row) {
    final acknowledgement = row.acknowledgement;
    if (acknowledgement == null) return;
    _controller.run(UnacknowledgeFindingCommand(id: acknowledgement.id));
    setState(() {});
  }

  /// PWR-003's remedy: give the rack somewhere to plug things in
  /// (`#875`, DR-128 §11.127.5).
  ///
  /// **IT ASKS ONLY WHEN THE RACK HAS NOTHING.** `addOutletsToRack`
  /// extends distribution that already exists without a question, and
  /// returns an `AddOutletsChoice` when there is none, because a strip on
  /// a shelf and a 0U vertical PDU are two different jobs and the
  /// difference is the installer's to make.
  ///
  /// **AN UNANSWERED CHOICE WRITES NOTHING.** The first transaction adds
  /// no child in that case, and `TxnScope.add` drops a command that
  /// changed nothing (DR-156 §11.155.1), so an empty one leaves no undo
  /// entry to press `Ctrl+Z` past.
  Future<void> _applyFindingRemedy(Finding finding) async {
    final rackId = finding.primaryEntityId;
    if (rackId == null || !_doc.racks.containsKey(rackId)) return;

    final first = _runRemedy(rackId, null);
    switch (first) {
      case AddOutletsDone():
        setState(() {});
      case AddOutletsRefused(:final message):
        _status.show(message);
      case AddOutletsChoice(:final question):
        final source = await showAddOutletsChoiceDialog(
          context: context,
          question: question,
        );
        if (source == null || !mounted) return;
        // RE-CHECKED AFTER THE AWAIT, on `_deleteSelection`'s rule: the
        // document is not frozen while a dialog is open.
        if (!_doc.racks.containsKey(rackId)) return;
        final second = _runRemedy(rackId, source);
        if (second is AddOutletsRefused) {
          _status.show(second.message);
        } else {
          setState(() {});
        }
    }
  }

  /// One attempt, in one transaction, so the shelf and the strip and the
  /// 0U channel a remedy mints are all ONE undo entry.
  AddOutletsResult _runRemedy(Uuid rackId, OutletSource? source) {
    return _controller.transact(
      LabelKey.insertRemedyDevice,
      (tx) => addOutletsToRack(
        tx,
        doc: _doc,
        rackId: rackId,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
        source: source,
      ),
    );
  }

  void _revealFinding(Uuid id) {
    // A FINDING'S LOCUS IS NOT ALWAYS A DEVICE: it can be a rack, a net
    // or a circuit, and selecting one of those here would be a silent
    // no-op that looks like a broken row. Only devices are revealed, and
    // the rest simply do not offer the gesture (`DrcPanel` already draws
    // a row with no locus as untappable).
    if (!_doc.devices.containsKey(id)) return;
    _selection.apply([id], SelectMode.replace);
    if (_inspectorTarget != InspectorTarget.selection) {
      setState(() => _inspectorTarget = InspectorTarget.selection);
    }
  }

  /// CR-105's chip for [id], or null when this device is not signposted.
  ///
  /// [PortFill.hasUnconnected] is the whole rule: a device with every pin
  /// wired has nothing to point at, and one with no pins at all is
  /// furniture rather than "unwired" (a blank panel, a vent, a shelf —
  /// `kNoSymbolsDetail` already says the schematic will not draw it).
  PortFill? _chipFor(Uuid id) {
    final fill = _portFill[id];
    return fill != null && fill.hasUnconnected ? fill : null;
  }

  /// Chip colours from the theme rather than from `RackPalette` — see
  /// `port_chip.dart`'s header for why they must not join the type the
  /// PDF backend reads.
  PortChipStyle _portChipStyle(ColorScheme scheme) => PortChipStyle(
    fillArgb: scheme.secondaryContainer.toARGB32(),
    strokeArgb: scheme.outline.toARGB32(),
    textArgb: scheme.onSecondaryContainer.toARGB32(),
  );

  Widget _deviceBox(
    DeviceLayout d,
    RackScene rackScene,
    RackPalette palette,
    ColorScheme scheme,
  ) {
    final chip = _chipFor(d.deviceId);
    return DeviceBox(
      scene: rackScene.scene,
      deviceId: d.deviceId.v,
      measurer: widget.measurer,
      // CR-105's count reaches a screen reader through the LABEL rather
      // than through a semantic action — see `portChipSemantics` for why
      // a fake action would be worse than the gap it papers over. It is
      // appended only when the chip is drawn, so what is announced and
      // what is on screen say the same thing.
      semanticLabel: chip == null
          ? d.semanticLabel
          : '${d.semanticLabel} — ${portChipSemantics(chip)}',
      palette: palette,
      selected: _selection.contains(d.deviceId),
      // DR-186 §11.185.2's padlock, read off the placement on every build
      // so the badge and the refusals below can never disagree.
      locked: switch (_doc.devices[d.deviceId]?.placement) {
        final Placement p => placementLocked(p) ?? false,
        null => false,
      },
      portChip: chip,
      portChipStyle: _portChipStyle(scheme),
      // Two in-place fades, one knob (see `RenderDeviceBox.fadeOpacity`):
      //  * §3.3 step 1 — the device being move-dragged drops to 30 %,
      //    "showing the vacated U", while its full-opacity ghost follows
      //    the cursor;
      //  * §3.6 — while a compaction preview is open, every device it
      //    proposes to move dims to 25 % at its CURRENT position, with
      //    the solid ghost at the proposed one.
      // Mutually exclusive by the screen's preview-exclusivity invariant
      // (opening either cancels the other), so the order below is
      // readability, not arbitration.
      fadeOpacity: _lastMoveDragSourceId == d.deviceId.v
          ? RenderDeviceBox.dragSourceOpacity
          : (_compaction.moves(d.deviceId.v)
                ? RenderDeviceBox.compactionSourceOpacity
                : null),
      shake: _shake,
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
        _seedViewport(viewportSize);
        return ColoredBox(
          color: scheme.surface,
          child: Stack(
            children: [
              Positioned.fill(
                child: CanvasIntentDetector(
                  onSecondaryTap: _onSecondaryTap,
                  key: _canvasBoxKey,
                  viewport: _viewport,
                  // The editing handler consumes primary drags (select /
                  // move). Panning is via scroll, trackpad, or middle-mouse
                  // drag; primary-drag-on-empty IS THE MARQUEE as of
                  // PLAN-E/6, which is what this comment said was
                  // reserved and deferred.
                  handler: _handler,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // CR-102's band, over everything and hit-testing
                      // nothing. SCREEN CHROME AND NEVER A SCENE OP:
                      // `buildRackScene` feeds the PDF as well as this
                      // display (CR-086), so a band in the scene prints.
                      // It is LAST in the stack so it draws on top of the
                      // devices it is sweeping.
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
                              child: _deviceBox(d, rackScene, palette, scheme),
                            ),
                        ],
                      ),
                      // The insertion caret (docs/04 §3.4) AND the drag
                      // ghost/snap-line/blocked-occupant hatch — for BOTH
                      // the palette drag (docs/04 §3.1) and the move drag
                      // (§3.3 step 3: "same blocked rendering as §3.1"),
                      // which is why both controllers are handed to ONE
                      // painter rather than each getting its own. All
                      // mutually exclusive per frame (see
                      // editing_overlay_painter.dart's header).
                      // Scene-space, painted LAST so it sits on top of the
                      // chassis and every device, mirroring GridPainter's
                      // viewport-transform replay pattern.
                      // `IgnorePointer`-wrapped: purely visual, never a hit
                      // target.
                      IgnorePointer(
                        child: CustomPaint(
                          painter: EditingOverlayPainter(
                            viewport: _viewport,
                            caret: _caret,
                            geo: _geo,
                            dragPreviews: [_paletteDrag, _moveDrag],
                            compaction: _compaction,
                            resize: _resize,
                            shake: _shake,
                            style: EditingOverlayStyle(
                              caretColor: scheme.tertiary,
                              rulerHighlight: scheme.tertiary.withValues(
                                alpha: 0.20,
                              ),
                              errorColor: scheme.error,
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      MarqueeBand(
                        marquee: _marquee,
                        viewport: _viewport,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: ViewportHud(
                  viewport: _viewport,
                  fitTooltip: 'Fit the rack',
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
              // docs/04 §4's rack header — screen-space chrome, a sibling of
              // the zoom HUD rather than part of the scene (see
              // rack_header_bar.dart's header for why). Centred at the top,
              // between the zoom HUD on the left and the face toggle on the
              // right.
              //
              // §5's 20px CHIP STRIP SITS DIRECTLY UNDER IT, matching §2.1's
              // "32px header, sticky / 20px chip strip" stack. It is a
              // sibling here rather than a child of `RackHeaderBar` on
              // purpose: docs/m1-implementation-log.md flags that widget as
              // mid-rework (the hold-repeat stepper landed there; the `⚠n`
              // findings rollup is still to come), and threading a fifth
              // concern through it would collide with that. Stacking the two
              // gets §5's placement without touching the header at all.
              //
              // It used to be a `Positioned.fill` + `Align.bottomCenter`
              // 36px bar floating over the canvas, which put an OPAQUE
              // container across the bottom of the rack — absorbing every
              // pointer event aimed at the lowest RUs — and pushed the
              // status-message stub from `bottom: 12` to `bottom: 48` to
              // get out of its way. Both are undone here.
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RackHeaderBar(
                        designator: _rack.designator,
                        name: _rack.name,
                        heightU: _rack.heightU,
                        onHeaderTap: _showRackInspector,
                        compactionEnabled: !_compaction.isActive,
                        onAction: _onRackHeaderAction,
                        // docs/04 §4.1's first way to change height. Returns
                        // whether the hold-repeat may continue — see
                        // `_stepHeight`.
                        onStep: _stepHeight,
                        racks: _rackChoices,
                        activeRackId: _rack.id,
                        onSelectRack: _switchRack,
                      ),
                      RackMetricsRow(
                        // Derived, not asserted: `computeRackRollups` is the
                        // one place these four numbers exist (see
                        // rack_metrics_row.dart's header for the literal
                        // `ruFree: 0` this replaces). Recomputed per build,
                        // which is exactly as often as the rack's contents
                        // can have changed — every structural edit already
                        // rebuilds this screen through `_onEditorChanged`.
                        rollups: computeRackRollups(
                          rack: _rack,
                          devices: _doc.devices.values,
                          templates: _doc.templates,
                          face: _face,
                          // The cords drawn in THIS document, so a cord
                          // drawn on the schematic moves the outlet chip
                          // (DR-171 §11.170.4).
                          landings: PortLandings.of(_doc),
                        ),
                        units: _doc.settings.displayUnits,
                      ),
                    ],
                  ),
                ),
              ),
              // docs/04 §3.6's floating Apply/Cancel bar. Renders nothing
              // when no preview is open, so it can live here permanently.
              // Above the `CanvasIntentDetector` in the Stack, so clicking
              // its buttons never also begins a canvas gesture (which would
              // cancel the very preview being applied — see `_onBeginDrag`).
              Positioned(
                bottom: 56,
                left: 0,
                right: 0,
                child: Center(
                  child: CompactionPreviewBar(
                    controller: _compaction,
                    onApply: _applyCompaction,
                    onCancel: _cancelCompaction,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: IgnorePointer(
                  // A minimal transient-message stub (docs/04 §3.4's
                  // "never silently stops"), NOT the full always-visible
                  // status bar of §1 (cursor context / zoom / selection
                  // rollup / project counts — still not-started, see
                  // docs/m1-implementation-log.md). While `_status` has a
                  // message (nudge-blocked / placement-confirmed), it
                  // replaces the static help text; otherwise the help text
                  // shows as before.
                  child: AnimatedBuilder(
                    animation: _status,
                    builder: (context, _) => Text(
                      _status.text ??
                          'Click to select  ·  Ctrl/Cmd+click toggles  ·  '
                              'drag a selected device to move  ·  Del '
                              'removes  ·  Ctrl/Cmd+Z / +Shift+Z undo/redo  '
                              '·  ↑↓ nudge/caret, Home/End/PgUp/PgDn  ·  '
                              'scroll or middle-drag to pan  ·  '
                              'Ctrl/Cmd+scroll to zoom',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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

/// The pointer-driven gestures this screen arbitrates between (see
/// `RackCanvasScreenState`'s "the exclusivity rule, in one place").
///
/// TWO VALUES, NOT FOUR, and the grouping is the point. The move drag and the
/// top-edge resize are ONE value because they are the same pointer arriving
/// through the same `CanvasIntentDetector` route — `_onBeginDrag` decides
/// which of the two it is AFTER claiming, and only one of them can exist per
/// gesture. The compaction preview is not here at all: it has no pointer, so
/// it can never be the thing a new gesture would collide with, only the thing
/// a new gesture takes the screen from.
enum _PointerGesture {
  /// docs/04 §3.1 — armed on a palette row, tracked through the global
  /// `pointerRouter`.
  paletteDrag,

  /// docs/04 §3.3 (move) or §4.1 (top-edge resize) — grabbed inside the
  /// canvas, delivered by `CanvasIntentDetector`.
  canvasDrag,
}

/// What `_requestHeight` did with a request (docs/04 §4.1).
///
/// A three-valued answer rather than a bool, because the header stepper's
/// hold-repeat needs to tell "the height moved, keep going" from BOTH "there
/// was nothing to do" and "a modal is now on screen waiting for the user" —
/// and the last of those must stop the repeat dead (see `_shrinkDialogOpen`).
enum _HeightOutcome {
  /// A `SetRackHeightCommand` ran (possibly inside a preset transaction).
  applied,

  /// The rack was already at that height. Nothing ran, nothing was refused.
  unchanged,

  /// The shrink would strand an occupant, so §4.1's modal is open (or was
  /// already open). Nothing has been committed yet, and may never be.
  deferredToModal,
}

// ── keyboard actions + the pointer-agnostic editing handler ────────────────
//
// THE INTENTS THAT USED TO BE DECLARED HERE ARE IN `keymap.dart`.
// Fourteen private classes stood at this point in the file —
// `_DeleteIntent`, `_UndoIntent`, `_ArrowUpIntent` and eleven siblings —
// and their privacy was exactly what made CR-101's "one `Intent` registry"
// impossible: an intent a registry cannot name is a binding a generated
// table cannot list. They are public now, declared beside the keys they
// answer to, and this file keeps what is genuinely local to it — the
// ACTIONS, and the gating that decides when each key is allowed to mean
// what the registry says it means.

/// `Enter` -> apply the compaction preview, IF one is open.
///
/// A REAL `Action` SUBCLASS, NOT A `CallbackAction`, and the difference is
/// the whole point. `Enter` is bound BARE at the screen level, inside the
/// same `Shortcuts` subtree as the palette search box (whose `onSubmitted`
/// is docs/04 §3.2's headline "type, press Enter" placement flow) and every
/// focusable palette row (whose own `Enter` handler places the focused
/// template). A `CallbackAction` that merely returned null when no preview
/// was open would still report the key as HANDLED — `ShortcutManager`
/// consults `isActionEnabled`, not the return value — and would therefore
/// swallow every `Enter` in the palette for the entire session.
///
/// Overriding [isActionEnabled] makes `ShortcutManager.handleKeypress`
/// return `KeyEventResult.ignored` instead, so the key falls through to
/// whatever else wants it.
///
/// This paragraph used to continue "In practice the palette's own handlers
/// sit BELOW this in the focus chain and claim `Enter` first anyway". That
/// is HALF FALSE and the false half is the dangerous one. It holds for
/// `_PaletteRow`, which really does install `Focus(onKeyEvent:)`
/// (device_palette_panel.dart). It does NOT hold for the SEARCH FIELD:
/// `EditableText` installs no key handler at all, and its `Enter` arrives
/// as `performAction` over the text-input connection rather than through
/// the focus chain. The `isActionEnabled` override is not a belt-and-braces
/// guarantee behind a handler that would have caught it — it is the ONLY
/// thing standing between this binding and every `Enter` in the filter box.
class _ApplyCompactionAction extends Action<ApplyCompactionIntent> {
  _ApplyCompactionAction(this._state);

  final RackCanvasScreenState _state;

  @override
  bool get isActionEnabled =>
      _state._compaction.isActive && !_state._textFieldHasFocus;

  @override
  void invoke(ApplyCompactionIntent intent) => _state._applyCompaction();
}

/// A real [Action] whose enablement is a predicate evaluated FRESH ON EVERY
/// KEYPRESS — the general form of the mechanism [_ApplyCompactionAction]
/// documents, applied to every other binding on this screen.
///
/// ═════════════════════════════════════════════════════════════════════
/// WHY EVERY BINDING NEEDS THIS AND NOT JUST `Enter`
/// ═════════════════════════════════════════════════════════════════════
/// This screen's `Shortcuts` wraps the whole three-column `Row`, so the
/// palette filter and the five `RackInspector` fields are all DESCENDANTS
/// of it, while `DefaultTextEditingShortcuts` — the only thing in Flutter
/// that turns `Backspace` into a `DeleteCharacterIntent` — is installed by
/// `WidgetsApp` at the ROOT. Key events are dispatched LEAF -> ROOT
/// (`FocusManager._dispatchKeyEvent`), so this screen's map is consulted
/// FIRST and the text machinery LAST. Fourteen bare bindings therefore sat
/// in front of six text fields.
///
/// A `CallbackAction` cannot fix it, and neither can returning early from
/// the callback body: `Action.consumesKey` defaults to `true` and
/// `toKeyEventResult` maps that to `KeyEventResult.handled` REGARDLESS OF
/// WHAT THE CALLBACK RETURNS OR DOES. The key is consumed before the body
/// runs, so `if (!_canvasFocus.hasFocus) return;` inside a handler stops
/// the ACTION and still destroys the KEY.
///
/// Overriding `consumesKey => false` is ALSO not equivalent, which is the
/// counter-intuitive part: `toKeyEventResult` then returns
/// `skipRemainingHandlers`, which breaks the dispatch loop just as dead as
/// `handled`. Only `isActionEnabled == false` yields `ignored` and lets the
/// event continue up the chain. Verified by execution, both ways.
///
/// The `enabled` predicate is a closure rather than a captured bool because
/// `ShortcutManager` re-reads `isActionEnabled` on every keypress; a
/// snapshot taken at build time would be stale the moment focus moved.
class _GatedAction<T extends Intent> extends Action<T> {
  _GatedAction(this._enabled, this._run);

  final bool Function() _enabled;
  final VoidCallback _run;

  @override
  bool get isActionEnabled => _enabled();

  @override
  void invoke(T intent) => _run();
}

/// Routes the pointer-agnostic `CanvasIntent` sequence into the screen's
/// select / move logic (docs/03 §4.4). A thin adapter: it holds no state of
/// its own and never branches on `PointerDeviceKind` (the editing-semantics
/// rule), forwarding each call to the `State` that owns the controllers.
///
/// THE `gesture` TOKEN IS DROPPED HERE, and that is a statement about this
/// screen rather than about the token. `CanvasGestureToken` exists so a
/// handler serving MORE THAN ONE CALLER can attribute a terminal callback to
/// the begin it belongs to; this screen has exactly one caller for this
/// interface — `CanvasIntentDetector`, which routes one pointer at a time —
/// so at most one begin is ever outstanding and `_dragRefused` (a bool
/// cleared as the first line of `_onBeginDrag`) is sufficient. The rack's
/// SECOND pointer route, the palette drag, goes through the global
/// `pointerRouter` and never reaches this class at all, which is why its
/// refusals arrive here strictly one at a time.
class _RackCanvasHandler implements CanvasIntentHandler {
  _RackCanvasHandler(this._state);

  final RackCanvasScreenState _state;

  @override
  void beginDrag(
    DPt sceneStart,
    Set<PointerDeviceKind> sourceKinds, {
    required CanvasGestureToken gesture,
  }) => _state._onBeginDrag(sceneStart, sourceKinds);

  @override
  void updateDrag(
    DPt sceneCurrent,
    DPt sceneDelta, {
    required CanvasGestureToken gesture,
  }) => _state._onUpdateDrag(sceneCurrent, sceneDelta);

  @override
  void commitDrag(DPt sceneEnd, {required CanvasGestureToken gesture}) =>
      _state._onCommitDrag(sceneEnd);

  @override
  void cancel({required CanvasGestureToken gesture}) => _state._onCancelDrag();
}

// ── temporary demo data (see the field comment above) ─────────────────────

/// Builds the demo-seeded document this screen falls back to.
///
/// PUBLIC AS OF THE PERSISTENCE STAGE, and only because the app shell now
/// owns the document: the shell needs SOMETHING to open with until the
/// start card and the four starter projects land, and it must be the same
/// something the screen used to seed itself with, or the app's behaviour
/// would change the moment the controller moved up a layer.
///
/// THIS IS A SEAM WITH A SHORT LIFE. docs/04 §9 says first launch shows a
/// start card — `Blank project` plus four real `.rppj` starters — not
/// a demo rack. When those land, the shell opens one of them instead and
/// this returns to being the screen's private fallback for tests.
RackDocument buildDemoRackDocument({Map<String, TemplateBody>? catalog}) =>
    _buildDemoDocument(catalog ?? buildSeedCatalog());

RackDocument _buildDemoDocument(Map<String, TemplateBody> catalog) {
  final now = DateTime.utc(2026, 7, 18);
  EntityMeta meta() =>
      EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'demo');

  // THE HASH IS COMPUTED ONCE PER TEMPLATE AND READ BACK BY THE REF
  // (`#795`). These used to be two hand-spelled strings, `sha256:demo-$id`
  // in both places, which agreed because they were the same expression
  // rather than because either described the body. A real hash cannot be
  // spelled twice, so `snapshot()` records it here and `device()` reads
  // it: a ref and the snapshot it names cannot disagree.
  final hashes = <String, String>{};

  TemplateSnapshot snapshot(
    String id, {
    required int frontU,
    required String displayName,
    int rearU = 0,
  }) {
    final body = TemplateBody(
      manufacturer: 'Demo',
      model: id,
      displayName: displayName,
      frontU: frontU,
      rearU: rearU,
      side: rearU > 0
          ? (frontU > 0 ? OccupancySide.both : OccupancySide.rear)
          : OccupancySide.front,
    );
    final hash = templateContentHash(body);
    hashes[id] = hash;
    return TemplateSnapshot(
      templateId: TemplateId(id),
      version: 1,
      contentHash: hash,
      capturedAt: now,
      body: body,
    );
  }

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
      // READ BACK, never re-derived. Every caller places a device from a
      // template `snapshot()` already minted, so the `!` is the
      // assertion: a demo device naming a template nobody seeded is a
      // defect in the seed rather than a case to tolerate.
      contentHash: hashes[templateId]!,
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

  // NO LOCATIONS. Three were seeded here — Main House, Media Closet,
  // Living Room — and their own comment said why: the `Location` dropdown
  // had nothing to list, "the project Locations panel (CR-112) and the
  // '+ New…' creation flow remain out of scope, so these are seeded rather
  // than creatable". M3-B built the panel (board #145), so the reason is
  // spent and this is board #143 collecting on it.
  //
  // A SEEDED ROOM IS NOT THE SAME KIND OF THING AS A SEEDED RACK. Every
  // other line of this document is scaffolding for a screen that needs
  // something to draw; a location is a fact about a BUILDING, and three of
  // them appearing in a document nobody typed them into is the one shape
  // this seed could take that a user would have to disprove. `Ctrl+N`
  // already gives a project with no locations (`blank_document.dart` seeds
  // none), so the demo agreeing with it is the whole change.

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
      // REAL AT `#795`, matching `blank_document.dart`'s seeding.
      contentHash: templateContentHash(entry.value),
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

// ── the drag screen-space chrome (docs/04 §3.1, and §3.3 step 3) ──────────
//
// The cursor card (pre-canvas-entry), the RU-range chip ("U19-U20", pinned
// to the ghost's top-right), and the reason chip (blocked-only) are all
// ordinary floating TEXT widgets, hence `Overlay`/`OverlayEntry` rather
// than `EditingOverlayPainter` (which owns the scene-space ghost/snap-
// line/hatch instead — see that file's header for the split). Positioned
// directly from the tracked GLOBAL pointer position, matching this app's
// actual root-overlay wiring (`apps/rackpal/lib/main.dart`:
// `MaterialApp` -> `Scaffold` -> `RackCanvasScreen`, no offsetting
// ancestor between the root `Overlay` and the window) — the same
// simplifying assumption this package's own widget tests already make via
// `_canvasOrigin(tester)` treating a `RenderBox`'s global top-left as
// directly usable in gesture coordinates.
//
// ONE widget serves both drag gestures, since §3.3 step 3 asks for §3.1's
// rendering verbatim; the only per-gesture knob is [showCursorCard].

/// The floating chrome for an in-flight drag — a palette drag (docs/04
/// §3.1) or a move drag (§3.3). A single `OverlayEntry`'s builder,
/// listening to [controller] (+ [viewport], so zoom/pan repositions the
/// RU-range chip, which is anchored to the ghost's SCENE-space top-right
/// corner).
class _DragPreviewOverlay extends StatelessWidget {
  const _DragPreviewOverlay({
    required this.controller,
    required this.viewport,
    required this.geo,
    this.showCursorCard = true,
  });

  final DragPreviewController controller;
  final ViewportController viewport;
  final RackGeometry geo;

  /// Whether the pre-canvas-entry cursor card (docs/04 §3.1 step 2) may be
  /// shown at all. True for a palette drag, which really does spend time
  /// lifted-but-not-yet-over-the-canvas. FALSE for a move drag: it is
  /// grabbed inside the canvas and goes straight to `dragging`, so a cursor
  /// card could only ever appear as a glitch — this makes that structural,
  /// not merely improbable.
  final bool showCursorCard;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // The whole overlay is non-hit-testing for CLICKS (the drag itself
      // is tracked via the global pointer router, never this widget's own
      // gesture callbacks) — but `MouseRegion`'s hover/cursor tracking is
      // a separate mechanism from hit-test "handling" pointer EVENTS, so
      // `ignoring: false` on just that one region (below) still shows a
      // live cursor while `IgnorePointer` here stops the floating text
      // from ever intercepting a click meant for whatever's underneath.
      child: AnimatedBuilder(
        animation: Listenable.merge([controller, viewport]),
        builder: (context, _) {
          if (!controller.isInProgress) return const SizedBox.shrink();
          final cursor = controller.cursorGlobal;
          if (cursor == null) return const SizedBox.shrink();

          // The SAME predicate `EditingOverlayPainter` uses to decide
          // whether a ghost is on screen, so the scene-space ghost and
          // these screen-space chips can never disagree about it.
          final showGhostChrome = controller.isShowingGhost;
          final evaluation = controller.evaluation;
          final blocked = evaluation?.blocked ?? false;

          // docs/04 §3.1: cursor is "grabbing" while a valid drop is live,
          // "forbidden" whenever releasing right now would do nothing —
          // blocked, or not even over the canvas yet.
          final cursorShape = (controller.isDragging && !blocked)
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.forbidden;

          var chipAnchor = cursor;
          if (showGhostChrome && evaluation != null) {
            final rect = geo.deviceRect(evaluation.ruIndex, controller.deviceH);
            final topRightScene = DPt(rect.right, rect.top);
            final topRightScreen = viewport.sceneToScreen(topRightScene);
            chipAnchor = Offset(topRightScreen.x, topRightScreen.y);
          }

          return Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(cursor: cursorShape, opaque: false),
              ),
              if (!showGhostChrome && showCursorCard)
                Positioned(
                  left: cursor.dx + 16,
                  top: cursor.dy + 16,
                  child: _CursorCard(
                    displayName: controller.displayName,
                    badge: controller.badge,
                  ),
                )
              else if (showGhostChrome && evaluation != null) ...[
                Positioned(
                  left: chipAnchor.dx + 8,
                  top: chipAnchor.dy - 14,
                  child: _RuRangeChip(
                    ruIndex: evaluation.ruIndex,
                    deviceH: controller.deviceH,
                  ),
                ),
                if (blocked && evaluation.reason != null)
                  Positioned(
                    left: cursor.dx + 16,
                    top: cursor.dy + 24,
                    child: _ReasonChip(message: evaluation.reason!),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A stable handle on the cursor card below.
///
/// Three widgets legitimately render the SAME device name during one
/// palette drag — the palette row, this card, and the Staging Bin chip —
/// so a test that counts occurrences of that string proves nothing about
/// which three it found, and silently changes meaning every time a fourth
/// surface starts showing it. Tests scope through this key instead
/// (`StagingBinOverlay.chipKey` is its counterpart).
const Key kDragCursorCardKey = ValueKey('drag-cursor-card');

/// docs/04 §3.1 step 2: "A 180x40px cursor card (icon, name, '2U' badge)."
class _CursorCard extends StatelessWidget {
  const _CursorCard({required this.displayName, required this.badge});

  final String displayName;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: kDragCursorCardKey,
      elevation: 4,
      borderRadius: BorderRadius.circular(6),
      color: scheme.surfaceContainerHigh,
      child: Container(
        width: 180,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              Icons.drag_indicator,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 6),
            Chip(
              label: Text(badge),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

/// docs/04 §3.1 step 4: "a 'U19-U20' chip pins to the ghost's top-right."
class _RuRangeChip extends StatelessWidget {
  const _RuRangeChip({required this.ruIndex, required this.deviceH});

  final int ruIndex;
  final int deviceH;

  @override
  Widget build(BuildContext context) {
    final end = ruIndex + deviceH - 1;
    final label = deviceH > 1 ? 'U$ruIndex-U$end' : 'U$ruIndex';
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(4),
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onTertiaryContainer,
            fontWeight: kConsoleEmphasis,
          ),
        ),
      ),
    );
  }
}

/// docs/04 §4.1's resize readout: "a '24U (+3)' readout follows the cursor".
///
/// A sibling of [_RuRangeChip] in every respect — screen-space floating text
/// positioned from a tracked GLOBAL pointer position, hence an `OverlayEntry`
/// rather than the scene-space `EditingOverlayPainter` (which owns the red
/// hatch and the candidate top-edge line instead). The split is the same one
/// the drag chrome already follows.
///
/// The SECOND line is not in the spec and is here for a reason stated in
/// resize_preview_controller.dart: the red hatch cannot distinguish a device
/// you can see from one on the face you cannot, so when a shrink is about to
/// strand occupants the chip says how many. Without it, hatching a rear-face
/// device's U on a front elevation would paint red across apparently empty
/// rack with no explanation.
class _ResizePreviewOverlay extends StatelessWidget {
  const _ResizePreviewOverlay({required this.controller});

  final ResizePreviewController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.isActive) return const SizedBox.shrink();
          final cursor = controller.cursorGlobal;
          if (cursor == null) return const SizedBox.shrink();
          final doomed = controller.doomedCount;
          // The same valid/blocked colour language the drag ghost uses, so
          // "this is going to cost you" reads identically across gestures.
          final blocked = doomed > 0;
          return Stack(
            children: [
              Positioned(
                left: cursor.dx + 16,
                top: cursor.dy + 16,
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(4),
                  color: blocked
                      ? scheme.errorContainer
                      : scheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.readout,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: blocked
                                ? scheme.onErrorContainer
                                : scheme.onTertiaryContainer,
                            fontWeight: kConsoleEmphasis,
                          ),
                        ),
                        if (blocked)
                          Text(
                            doomed == 1
                                ? '1 device would lose its U'
                                : '$doomed devices would lose their U',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onErrorContainer,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// docs/04 §3.1 step 5: "a 28px reason chip states the message."
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(4),
      color: scheme.errorContainer,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.onErrorContainer),
        ),
      ),
    );
  }
}
