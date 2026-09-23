// rackpal_ui/src/canvas/schematic/schematic_canvas_screen.dart
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
// item 3), and `apps/rackpal/test/unbuilt_copy_accuracy_test.dart` scans
// both UI packages and the app for a caller of `AddLinkCommand` — so that
// sentence is asserted against the code, not asserted by a comment.
//
// ═════════════════════════════════════════════════════════════════════
// THE EXCLUSIVITY RULE, TAKEN UP (M2-F PHASE 1)
// ═════════════════════════════════════════════════════════════════════
// This section used to say that this screen needed no arbiter of its own,
// because it has exactly ONE pointer route (the detector's) and no
// preview-then-commit interaction at all — and it ended: "The moment
// drag-to-connect lands here, this paragraph stops being true and the
// arbiter has to arrive with it."
//
// DR-011 (canon §11.11) scopes drag-to-connect into this file, so the
// arbiter arrives NOW, one phase ahead of the gesture, rather than being
// left as a promise a later phase has to remember. `_liveGesture`,
// `_claimPointerGesture` and `_releasePointerGesture` below are ported
// from `rack_canvas_screen.dart`'s "the exclusivity rule, in one place",
// and they are LOAD-BEARING TODAY: the click/marquee path claims the
// canvas on `beginDrag` and releases it on the terminal callback, so a
// claim leaked by any future gesture refuses the next click and SAYS so
// on the status line rather than deadening the sheet in silence.
//
// WHAT IS HONESTLY DIFFERENT FROM THE RACK, and it is stated so the next
// reader does not mistake it for a port that lost something: the rack
// arbitrates between TWO pointer ROUTES (a palette drag through the
// global `pointerRouter` versus a canvas drag through the detector), and
// its `_PointerGesture` has one value per route. This screen still has
// one route, so the enum has one value and `_releasePointerGesture`'s
// "no-op for a non-holder" cannot yet be exercised by two different
// values. The rule it encodes — A REFUSED GESTURE'S TEARDOWN MUST NOT
// FREE THE WINNER'S CLAIM — is therefore held on this screen by
// `_SchematicClickHandler`'s `_owned` GESTURE TOKEN, which is where a
// refusal is actually observable. Both mechanisms are kept: the identity
// check becomes load-bearing the moment Phase 2 adds a second value, and a
// screen inheriting a rule that was got wrong three times next door does
// not get to rely on one mechanism.
//
// THAT TOKEN REPLACED A PAIR OF BOOLS, and the difference is not a tidy-up.
// `CanvasIntentHandler` orders NOTHING between two gestures' terminal
// callbacks, so a handler holding one bool for "I own the canvas" and one
// for "a refusal is outstanding" has to GUESS which begin a bare
// `commitDrag()` belongs to — and each possible guess loses either the
// winner's click or the winner's claim, while neither can count past one
// refusal. `CanvasGestureToken` (canvas_intent.dart) makes the caller mint
// one identity per `beginDrag` and hand it back on every later call, so
// attribution is an identity comparison instead. See that class's doc
// comment for the three failures it retires, and `_owned`'s for why the
// refusal latch it replaced is gone rather than fixed.
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

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show PointerDeviceKind, PointerExitEvent, PointerHoverEvent;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyEvent, LogicalKeyboardKey;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/canvas_intent.dart';
import 'package:rackpal_ui/src/canvas/grid_painter.dart';
import 'package:rackpal_ui/src/canvas/marquee_controller.dart';
import 'package:rackpal_ui/src/canvas/schematic/connect_overlay.dart';
import 'package:rackpal_ui/src/canvas/schematic/domain_filter_bar.dart';
import 'package:rackpal_ui/src/canvas/schematic/drag_ghost_layer.dart';
import 'package:rackpal_ui/src/canvas/schematic/link_hit_test.dart';
import 'package:rackpal_ui/src/canvas/schematic/pin_badge_layer.dart';
import 'package:rackpal_ui/src/canvas/schematic/pin_selection.dart';
import 'package:rackpal_ui/src/canvas/schematic/render_schematic_canvas.dart';
import 'package:rackpal_ui/src/canvas/schematic/schematic_filter.dart';
import 'package:rackpal_ui/src/canvas/schematic/schematic_paint_plan.dart';
import 'package:rackpal_ui/src/canvas/schematic/schematic_reveal.dart';
import 'package:rackpal_ui/src/canvas/schematic/spring_back_chip_card.dart';
import 'package:rackpal_ui/src/canvas/schematic/tidy_sheet_dialog.dart';
import 'package:rackpal_ui/src/canvas/selection_controller.dart';
import 'package:rackpal_ui/src/canvas/status_message_controller.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart';
import 'package:rackpal_ui/src/shell/coach_mark.dart';
import 'package:rackpal_ui/src/validation/why_rule_dialog.dart';

/// The headline shown when the document draws symbols but holds no cable.
///
/// A STATEMENT ABOUT THE DOCUMENT, never about the user — the same rule
/// `kNoCablesHeadline` states for the Schedule. "You have not wired
/// anything" is false whenever the build offers no way to wire anything,
/// which is exactly the case docs/09 M1 singles out as a lie.
const String kNoLinksHeadline = 'This document holds no cables.';

/// Why the sheet shows symbols and no wires — and, now, how to draw one.
///
/// ═════════════════════════════════════════════════════════════════════
/// THE LAST CLAUSE OF THE RETIRED `UnbuiltView` PANEL HAS EXPIRED TOO
/// ═════════════════════════════════════════════════════════════════════
/// This constant used to end "no surface in this build creates a Link, so
/// there is nothing to label. The gap is the gesture, not the view." That
/// was the one sentence of the panel that survived M2-C, M2-D and M2-E, and
/// M2-F is what makes it false: `_commitWire` runs a `ConnectPortsCommand`.
///
/// Rewritten rather than softened, on the rule that retired the panel
/// itself and the Schedule's before it — THE ONE SURFACE IN THE APP WHOSE
/// PURPOSE IS ACCURACY ABOUT WHAT EXISTS MUST BE THE FIRST THING TO CHANGE
/// WHEN SOMETHING STARTS EXISTING. `unbuilt_copy_accuracy_test.dart` holds
/// it to that: it scans both UI packages and the app for a caller of the
/// connect commands, and now fails if the copy claims nothing creates a
/// Link while something does.
///
/// It is also the only place the keyboard route is written down for the
/// user, which is deliberate. The gesture is `W`, and a coach mark that
/// teaches it is AC-048's, decided in Phase 5 — until then the panel that
/// explains an empty sheet is exactly the right place for the sentence,
/// because it is on screen precisely when the user has nothing wired.
const String kNoLinksDetail =
    'Every symbol above is laid out from your document and every cable '
    'renders as a pair of net labels — the layout, the labels and the '
    'domain filter are built and running. To draw one: use the arrow keys '
    'to put the caret on a pin, press W to start a cable, arrows or Tab to '
    'reach the other end, and Enter to commit. Esc cancels.';

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
    this.reveal,
    this.showFilterCoachMark = false,
    this.onDismissFilterCoachMark,
    super.key,
  });

  /// The shared `TextMeasurer` (CR-081), used to BUILD the scene and to
  /// paint it, so on-screen layout matches what the PDF backend would
  /// measure. The app injects one `PdfFontMeasurer`; `rackpal_ui` never
  /// constructs one.
  final TextMeasurer measurer;

  /// The document this sheet is a projection of.
  ///
  /// REQUIRED, and there is no `document` sibling and no demo seed. The
  /// rack screen carries both for historical reasons its own doc comments
  /// record; this screen was written after the app shell owned the
  /// document, so it has exactly one source and cannot be given a second.
  final DocumentController controller;

  /// CR-105's arrival: the elevation's chip parks a device here and this
  /// screen selects and frames it. Null in every host that has no rack tab
  /// to be sent from. See `schematic_reveal.dart`.
  final RevealController? reveal;

  /// Whether AC-048's coach mark is showing under the domain filter bar.
  ///
  /// DECIDED BY THE HOST, NOT HERE, and that is DR-012.4: the mark's
  /// "first" is persisted in APP-SUPPORT PREFS, per user rather than per
  /// project, and this screen has no store and no business having one.
  /// It renders what it is told and reports the dismissal back.
  final bool showFilterCoachMark;

  /// Called when the user dismisses the mark — from its own button, or by
  /// doing the thing it teaches. One callback for both, so there is a
  /// single definition of "seen".
  final VoidCallback? onDismissFilterCoachMark;

  @override
  State<SchematicCanvasScreen> createState() => _SchematicCanvasScreenState();
}

class _SchematicCanvasScreenState extends State<SchematicCanvasScreen>
    with TickerProviderStateMixin {
  /// Net pointer travel (screen px) below which a press is a click —
  /// docs/04 §3.1 step 1's "Nothing until 4 px of movement, so a click
  /// still means show details", compared in SCREEN space so the slop does
  /// not shrink with zoom.
  static const double _clickSlopPx = 4;

  /// docs/05 §11.6's magnetic-snap figure, in SCREEN pixels: "Within 12
  /// screen px the band locks to a port's glyph centre". It is the only
  /// quantified pin-proximity figure in the corpus, so it is also what a
  /// pin's CLICK target uses — a pin you can snap to but not click would be
  /// two different pins.
  ///
  /// SCREEN px, and that is the whole reason it is not handed to
  /// `SymbolHitTestParams` as written: that field is in DIAGRAM UNITS
  /// (`symbol_hit_test.dart`'s own doc), so the conversion is
  /// `12 / viewport.scale`, recomputed whenever the zoom changes. A
  /// constant would make the target 48 screen px wide at 4× and 3 px wide
  /// at ¼×.
  static const double _portHitTolerancePx = 12;

  /// How much a pin's PERPENDICULAR offset counts against it when an arrow
  /// key picks the next caret pin — see [_movePinCaret].
  ///
  /// A STATED CHOICE, and the corpus gives no figure: docs/05 §7 says
  /// "`Tab`/arrow to a candidate port" and nothing about how an arrow
  /// chooses. 0.5 makes the pressed axis worth twice the other, so a pin
  /// directly right of the caret beats one that is equally far right but
  /// half a sheet up, while a pin slightly off-axis is still reachable
  /// without hunting. Recorded here as a choice so it is not read as a
  /// number out of the specifications.
  static const double _kCaretCrossAxisWeight = 0.5;

  final ViewportController _viewport = ViewportController();
  final GridCache _gridCache = GridCache();

  /// Selection is OBSERVED, never persisted (docs/03 §4.4) — the same
  /// controller the rack editor uses, so the two views mean the same thing
  /// by "selected".
  final SelectionController _selection = SelectionController();

  final FocusNode _canvasFocus = FocusNode(debugLabel: 'schematicCanvas');

  /// Transient status text + `SemanticsService.announce` — the channel
  /// docs/04 §3.4's "never silently stops" needs and this screen had none
  /// of. `SemanticsService.announce` is called from exactly one place in
  /// the repository (`status_message_controller.dart`), so without this
  /// field the schematic has NO announcement channel at all — which is
  /// what M2-F's "works end to end with screen-reader announcements"
  /// clause is measured against.
  final StatusMessageController _status = StatusMessageController();

  /// Which POINTER-DRIVEN gesture currently owns the canvas, or null when
  /// none does. THE one piece of state behind this screen's exclusivity
  /// rule — see the file header, and `_claimPointerGesture` below.
  _PointerGesture? _liveGesture;

  /// The pointer-agnostic click handler, HOISTED OUT OF `build`.
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// THIS FIELD IS A BUG FIX, NOT A TIDY-UP
  /// ═════════════════════════════════════════════════════════════════
  /// It was constructed inline in `_canvas()`, which `build` calls, so
  /// every rebuild produced a NEW handler. `CanvasIntentDetector` re-reads
  /// `widget.handler` on every pointer event (`canvas_intent.dart:164,
  /// 190, 201, 218, 233`) rather than capturing it at pointer-down — so a
  /// rebuild BETWEEN press and release handed the release to an object
  /// that had never seen the press. `commitDrag`'s first line is
  /// `if (start == null …) return;`, so the click was silently swallowed:
  /// no selection, no status line, nothing. `_onExit`'s `setState` and
  /// every document epoch reach that window today; a stateful connect
  /// gesture behind the same field (Phase 2) would lose a whole drag to
  /// it.
  ///
  /// `late final`, so the four bindings below are resolved ONCE against
  /// fields that are themselves `final` and never reassigned — `_viewport`
  /// and `_canvasFocus` are the instances the detector and the `Focus`
  /// widget use for the life of the `State`, and `_selectAt` /
  /// `_claimPointerGesture` / `_releasePointerGesture` are tear-offs bound
  /// to `this`. There is no captured build-time value here that a later
  /// build could make stale, which is the failure mode a careless hoist
  /// trades into.
  late final _SchematicClickHandler _handler = _SchematicClickHandler(
    viewport: _viewport,
    slopPx: _clickSlopPx,
    onClick: _selectAt,
    marquee: _marquee,
    onMarqueeCommit: _commitMarquee,
    requestFocus: _canvasFocus.requestFocus,
    claim: () => _claimPointerGesture(_PointerGesture.canvasDrag),
    release: () => _releasePointerGesture(_PointerGesture.canvasDrag),
    // ── the connect gesture's four seams (Phase 3) ──────────────────
    //
    // THE HANDLER ASKS, IT DOES NOT DECIDE. Every one of these is a
    // tear-off onto the `State`, for the same reason `onClick` is: the
    // handler owns per-DRAG state (a start point, a travel distance) and
    // the screen owns per-SHEET state (the scene, the caret, the
    // candidates, the arbiter). A handler that reached into the scene
    // would be a second place that knows where a pin is.
    pinAt: _pinAt,
    landingAt: _runEndAt,
    onLandingBegin: _armLandingFrom,
    claimConnect: () => _claimPointerGesture(_PointerGesture.connectDrag),
    releaseConnect: () => _releasePointerGesture(_PointerGesture.connectDrag),
    onConnectBegin: _beginWireAt,
    onConnectUpdate: _dragWireTo,
    onConnectCommit: _releaseWireAt,
    onConnectCancel: _cancelWire,
    // -- the symbol drag's five seams (`#918`) -----------------------
    symbolAt: _symbolAt,
    onSymbolDragBegin: _beginSymbolDrag,
    onSymbolDragUpdate: _dragSymbolTo,
    onSymbolDragCommit: _commitSymbolDrag,
    onSymbolDragCancel: _cancelSymbolDrag,
  );

  SchematicViewFilter _filter = const SchematicViewFilter();

  /// §11.4's `F`. Device ids, not `Uuid`s, because that is the key
  /// `RenderedNetLabel.deviceId` and `HitRegion.entityId` both use.
  Set<String> _focused = const <String>{};

  /// The cable the user has picked, or null — #96's first field finding.
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// A FOURTH SELECTION, AND THE THIRD ONE'S DOC EXPLAINS WHY IT IS ONE
  /// ═════════════════════════════════════════════════════════════════
  /// [_pins] already argues this screen's case for holding more than one
  /// kind of "selected": [_selection] names DEVICES and is shared with the
  /// rack and the inspector, [_pinCaret] is a CURSOR rather than a
  /// selection, and [_pins] names jacks. This names a `Link`, which is none
  /// of those and cannot be folded into any of them — `SelectionController`
  /// is keyed by device id and a link is not a device, so putting one in
  /// there would hand the inspector an id it would resolve to nothing.
  ///
  /// A `Uuid` AND NOT A `Link`. Holding the object would be a second place
  /// the document lives, and this one is held ACROSS FRAMES: an undo, or an
  /// edit from another view, can delete the link it names.
  /// [_invalidateLivePreviews] drops it when that happens, which is the same
  /// discipline [_focused] and `_altHovered` are already under.
  Uuid? _selectedLink;

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

  /// Per device, the bank keys the user has EXPANDED (`#801`, CR-103).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// SESSION STATE, NOT A DOCUMENT WRITE
  /// ═══════════════════════════════════════════════════════════════════
  /// CR-103's auto-collapse is what a device gets "on first layout", so
  /// the collapsed state is derivable from the template and the threshold
  /// and needs no storage. What a person expands is a deviation from it
  /// while they work, which is the same shape as DR-011.4's `holdAt`: a
  /// layout INPUT rather than a value in CR-117's byte surface.
  ///
  /// A NON-EMPTY ENTRY IS REMOVED RATHER THAN LEFT EMPTY, so this map's
  /// emptiness is a usable question and the scene cache key stays small.
  final Map<Uuid, Set<String>> _expandedBanks = <Uuid, Set<String>>{};

  SchematicScene? _scene;
  ({int epoch, SchematicPalette palette, SignalTheme theme})? _sceneKey;

  /// The point query over [_scene]'s symbols, held BESIDE the cached scene
  /// and rebuilt on exactly the two things it depends on: the scene, and
  /// the zoom (which sets the pin tolerance — see [_portHitTolerancePx]).
  ///
  /// `SymbolHitTest` is `@immutable` and builds its `HitRegion`s once at
  /// construction, so it cannot be re-tuned in place; a cache keyed on both
  /// inputs is what keeps a hover from rebuilding every pin region at
  /// pointer rate while still letting the tolerance track the zoom.
  SymbolHitTest? _hitTest;
  SchematicScene? _hitTestScene;
  SymbolHitTestParams? _hitTestParams;

  /// The BODY regions of [_scene]'s symbols alone — see [_deviceAt], which
  /// ranks them before it asks the pin query anything. Keyed on the scene
  /// only: unlike [_hitTest] they carry no tolerance, because a body is
  /// ranked by strict containment at every zoom.
  List<HitRegion>? _bodyRegions;
  SchematicScene? _bodyRegionsScene;

  /// CR-102's band (DR-139 §11.138, PLAN-E/6).
  ///
  /// The third and last adoption, which is what discharges that ruling:
  /// its whole content is that the gesture is uniform across views, and
  /// two out of three would have been the ruling honoured in letter.
  final MarqueeController _marquee = MarqueeController();

  /// Whether the viewport has already been framed on this sheet.
  bool _framed = false;

  /// The canvas column's size as of the last layout, or null before the
  /// first. [_revealNow] frames against it — see [_frameOnce].
  Size? _lastViewportSize;

  // ── the connect gesture's keyboard state (DR-011.2, docs/05 §7) ───────

  /// The pin under the caret, or null before the user has reached one.
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// THE CARET IS AUTHORITATIVE. THE SELECTION ONLY SEEDS IT.
  /// ═════════════════════════════════════════════════════════════════
  /// DR-011's "the order that matters" records why this is written down
  /// rather than left to whichever read happens first. M1's equivalent
  /// keyboard clause was REFUTED by the user: they hit the time target but
  /// needed a mouse, because each placement made the new device the sole
  /// selection and the caret was consulted ONLY when the selection was
  /// empty — so back-to-back `Enter`s used the caret once and then fell
  /// back to the selection forever. The mechanism read as working because
  /// its first invocation did.
  ///
  /// So: once this is non-null NOTHING re-derives it from the selection.
  /// [_seedCaret] is the only place the selection is consulted, and it runs
  /// only when this is null.
  PinRef? _pinCaret;

  /// The pin a wire is armed from — docs/05 §7's `WIRE_STICKY` — or null
  /// when no wire is in flight.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A PROPERTY RATHER THAN A FIELD, SO THE CHIP CANNOT OUTLIVE THE CABLE
  /// ═══════════════════════════════════════════════════════════════════
  /// A spring-back chip is a statement about a cable IN FLIGHT, so a chip
  /// still on screen after the gesture ended is talking about something
  /// that is over. `#278`'s first draft cleared it in `_clearWire`, which
  /// covers the cancels and the teardown and NOT the three commit paths —
  /// each of which nulls this field in a `setState` block of its own. So
  /// `[ Connect anyway ]` wrote its cable and left its own chip on the
  /// sheet, which a widget test caught and no amount of care would have.
  ///
  /// Five sites null this field today and a sixth is one feature away.
  /// Rather than patch four of them and hope, the invariant is enforced
  /// where it cannot be forgotten: **losing the cable loses the chip.**
  /// Same lesson as [_setTargets] above, arrived at the same way.
  PinRef? get _wireFrom => _wireFromPin;
  set _wireFrom(PinRef? value) {
    _wireFromPin = value;
    if (value == null) _forgetChip();
  }

  PinRef? _wireFromPin;

  /// The half-landed home run this gesture is LANDING, and which of its
  /// ends is the loose one, or null when the gesture is an ordinary
  /// connect (`#719`, DR-073).
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// LANDING IS NOT CONNECTING, AND THE WHOLE ITEM TURNS ON THAT
  /// ═════════════════════════════════════════════════════════════════
  /// `ConnectPortsCommand` CREATES a cable. A run pulled at framing stage
  /// already exists, carries a `W` number, a length, a jacket and
  /// possibly a test result, and what it lacks is a pin at one end. A
  /// connect run against it makes a SECOND cable beside the one the
  /// person is trying to finish, which is the defect `#713` was filed
  /// for. So when this is set, the commit calls `BindEndpointCommand`.
  ///
  /// [_wireFrom] IS STILL SET, and to the pin the run is ALREADY landed
  /// on. That is not a fudge to reuse the preview: a half-landed run
  /// landed onto a second pin genuinely is a cable between those two
  /// pins, so the band the overlay draws is what the document will hold
  /// one event later. Everything downstream — the magnet, the candidate
  /// rings, the caret, the teardown — therefore needs no branch at all.
  ///
  /// DR-074 §11.73.1 ADDS THE SECOND HALF. A run landed at BOTH ends may
  /// have either end dragged to a different jack, which commits
  /// `MoveEndpointCommand` instead. [RunEndGrab.moving] says which, and
  /// everything above stays true of both: the armed source is always the
  /// end this gesture is NOT writing, so the band is the cable as it will
  /// be either way.
  RunEndGrab? _landingFrom;

  /// The pins a conductor from [_wireFrom] may legally land on, in sheet
  /// order. Empty when no wire is armed.
  ///
  /// COMPUTED ONCE AT ARM TIME, not per keystroke. `evaluateConnect` reads
  /// the live conductor count off every link for every candidate, which is
  /// O(pins x links) — fine once, wasteful sixty times a second. It is safe
  /// to cache for exactly as long as the document does not move, and the
  /// moment it does [_invalidateLivePreviews] tears the whole gesture down
  /// and says so. That teardown is not a nicety here; it is what makes the
  /// cache correct.
  List<PinRef> _candidates = const <PinRef>[];

  /// The `PortSetDef` key the armed gesture is connecting AS A SET, or
  /// null when the gesture is the ordinary pin-to-pin one.
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// WHICH GESTURE YOU GET IS DECIDED BY THE PIN YOU GRABBED
  /// ═════════════════════════════════════════════════════════════════
  /// DR-011.2: "`AtomicConnectCommand` is reserved for the case where the
  /// grabbed pin belongs to a `PortSetDef` flagged `atomicConnect: true`."
  /// So this is not a mode the user enters; it is a property of the jack
  /// under the cursor, and 34 of the catalog's 257 ports have it — the
  /// stereo, speaker and balanced pairs.
  ///
  /// A pin in a set that opted OUT is an ordinary pin, not an error: the
  /// template author said this grouping is not one cable, and the
  /// pin-to-pin gesture is the one that applies.
  String? _wireFromSetKey;

  /// The bank a MULTI-DRAW is armed from, or null when the armed gesture
  /// is not one. The third value of the same three-way branch
  /// [_wireFromSetKey] holds the second of.
  String? _wireFromBankKey;

  /// What the armed multi-draw would do on every target bank the sheet
  /// draws, keyed by `(deviceId, bankKey)`.
  ///
  /// COMPUTED ONCE AT ARM TIME, for [_candidates]' reason and more so:
  /// `planMultiDraw` walks the run against a bank's every jack running
  /// `evaluateConnect`, so doing it per pointer-move would be O(pins x
  /// sources x links) sixty times a second. It is safe to cache for
  /// exactly as long as the document does not move, and
  /// [_invalidateLivePreviews] tears the gesture down the moment it does.
  Map<(String, String), MultiDrawPlan> _multiPlans =
      const <(String, String), MultiDrawPlan>{};

  /// The candidates that carry the SOURCE PIN'S OWN FAMILY — DR-012.3's
  /// magnet preference, as a set the snap can test in O(1).
  ///
  /// A SUBSET OF [_candidates], never a second list of pins: everything in
  /// here is already legal, and the family only decides which of two legal
  /// pins the band reaches for. That distinction is the whole of DR-012.5 —
  /// this is an ordering heuristic, not `SIG-001`, and the tier-2 rules
  /// that WOULD refuse an incompatible pair now live in [_springBack],
  /// one field down, which is the distinction made visible.
  Set<PinRef> _preferred = const <PinRef>{};

  /// The candidates a tier-2 rule would spring back: docs/05 §7.3's amber
  /// ring, and on release the chip.
  ///
  /// A SUBSET OF [_candidates] LIKE [_preferred] AND FOR THE OPPOSITE
  /// REASON. Both are refinements of the legal set rather than pools
  /// beside it, but [_preferred] says which legal pin the magnet reaches
  /// for FIRST and this says which one it will argue with. A pin can be
  /// in both: `snapToPin` still steers toward the source's own family,
  /// and a same-family pair can still fail `CON-001` on its connector.
  ///
  /// COMPUTED ONCE AT ARM TIME, in the walk that computes the other two.
  /// `evaluateSpringBack` runs six predicates over the registries and is
  /// nothing to do sixty times a second, and it can be cached for exactly
  /// as long as the document holds still — which is what
  /// [_invalidateLivePreviews] guarantees by tearing the whole gesture
  /// down the moment it does not.
  Set<PinRef> _springBack = const <PinRef>{};

  /// Sets the three arm-time target sets together, which is the only way
  /// they are ever set.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THREE FIELDS WITH A SUBSET INVARIANT, ASSIGNED AT NINE SITES, IS THE
  /// SHAPE THAT DRIFTS
  /// ═══════════════════════════════════════════════════════════════════
  /// [_candidates] and [_preferred] were two, maintained in step by hand
  /// across six teardowns and three arms, and it held. [_springBack] is
  /// the third, and it is the one whose staleness is VISIBLE: a leftover
  /// preferred pin only tugs the magnet a little, while a leftover amber
  /// pin tells the user a rule objects to a cable no rule has looked at.
  ///
  /// So the assignment is one call rather than three lines, and the
  /// invariant is asserted in the one place instead of being a sentence
  /// three doc comments repeat. A fourth refinement later touches this
  /// method and [_clearTargets], not nine `setState` blocks.
  ///
  /// CALL IT INSIDE `setState`, like the assignments it replaces: it
  /// writes fields and notifies nobody.
  void _setTargets({
    required List<PinRef> candidates,
    Set<PinRef> preferred = const <PinRef>{},
    Set<PinRef> springBack = const <PinRef>{},
  }) {
    assert(
      preferred.every(candidates.contains),
      'a preferred pin must be a candidate: the magnet may only reorder '
      'legal targets, never add one',
    );
    assert(
      springBack.every(candidates.contains),
      'a spring-back pin must be a candidate: docs/05:476 makes these '
      'targets DROPPABLE, so one the cable cannot reach is a tier-1 '
      'refusal wearing the tier-2 colour',
    );
    _candidates = List<PinRef>.unmodifiable(candidates);
    _preferred = Set<PinRef>.unmodifiable(preferred);
    _springBack = Set<PinRef>.unmodifiable(springBack);
  }

  /// Drops all three, for the teardowns: a commit, a cancel, and the
  /// document moving under a gesture in flight.
  void _clearTargets() {
    _candidates = const <PinRef>[];
    _preferred = const <PinRef>{};
    _springBack = const <PinRef>{};
  }

  // ── the spring-back and its chip (`#278`, CR-017, DR-114) ────────────

  /// The chip on screen, or null when no cable has just sprung back.
  SpringBackChip? _chip;

  /// The pin the chip is about, which is where it is anchored and where
  /// the refusal mark is drawn.
  ///
  /// SEPARATE FROM [_pinCaret] BECAUSE THE CARET LEFT. The band sprang
  /// back to the source and took the caret with it, which is what "sprang
  /// back" means; this remembers the pin the chip is talking about so the
  /// mark and the anchor do not go with it.
  PinRef? _chipAt;

  /// docs/05 §7's retraction: *"120 ms, `Curves.easeOutBack`."*
  ///
  /// Drives [_freeEnd] from the refused pin back to the source, reusing
  /// the UNSNAPPED-band path the pointer route already has rather than
  /// teaching the overlay a second way to draw a partial band. That path
  /// needs [_pinCaret] to be null, which it is: the caret went with the
  /// band.
  AnimationController? _springBackAnim;

  /// docs/05 §7's *"target flashes `#D55E00` twice at 90 ms"*, as four
  /// 90 ms phases: on, off, on, off, then the steady mark that stays
  /// while the chip is up.
  AnimationController? _flashAnim;

  /// The curve driving [_springBackAnim], held so it can be disposed.
  CurvedAnimation? _springBackCurve;

  /// Whether the refusal mark is drawn THIS frame. False only during the
  /// flash's two troughs.
  bool get _refusedVisible {
    final flash = _flashAnim;
    if (flash == null || !flash.isAnimating) return true;
    // Four equal phases over the controller's span; the even ones are lit.
    return (flash.value * 4).floor().isEven;
  }

  /// Where a POINTER drag's band currently ends when the magnet has not
  /// caught a pin — the raw cursor, in scene space. Null whenever
  /// [_pinCaret] is the band's target, which is always true of the
  /// keyboard route: a caret is already exactly on a pin, so there is no
  /// unsnapped state for it to be in.
  DPt? _freeEnd;

  /// #93's multi-draw selection — "N ports selected in one bank"
  /// (docs/05:484), or [PinSelection.none], which is nearly always.
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// A THIRD SELECTION ON ONE SCREEN, AND WHY IT IS NOT [_selection]
  /// ═════════════════════════════════════════════════════════════════
  /// This screen already has [_selection] (devices, `SelectionController`,
  /// shared with the rack and the inspector) and [_pinCaret] (one pin, a
  /// CURSOR rather than a selection — see its own doc on why the two must
  /// not be confused). This is neither. It names PINS, which
  /// `SelectionController` cannot hold — it is keyed by `Uuid` and a pin
  /// is a device plus a `PortKey` (CR-051), because DR-011.1 means the
  /// `Port` entity does not exist until a cable is drawn to it. There is
  /// nothing to select by id.
  ///
  /// IT DOES NOT SUBSTITUTE FOR THE CARET EITHER, which is the mistake
  /// [_pinCaret]'s doc records M1 being refuted by. The caret stays
  /// authoritative: it is what the arrows move and what a commit lands
  /// on, and this is read only by the gestures that are ABOUT a run of
  /// pins.
  PinSelection _pins = PinSelection.none;

  /// The positions the LAST built scene laid its symbols out at, and the
  /// `_sceneEpoch` those positions must be held for — DR-011.4.
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// A WIRES BUMP HOLDS THE LAYOUT; EVERY OTHER EPOCH DOES NOT
  /// ═════════════════════════════════════════════════════════════════
  /// DR-011.4: "creating a link does NOT re-lay-out the sheet. Symbol
  /// positions freeze; wires and labels rebuild." The defect it rules out
  /// is mechanical — a connect touches `EpochMask.wires`, this screen bumps
  /// [_sceneEpoch], the scene cache misses and `buildSchematicScene` runs
  /// Sugiyama over the NEW edge set, moving every symbol.
  ///
  /// The hold is scoped to the `wires` epoch precisely BECAUSE the ruling
  /// is. docs/05:747's broader rule ("auto-layout never fires as a side
  /// effect of an unrelated edit") would hold positions across every epoch,
  /// and that is a bigger change than DR-011.4 makes — a rename moves a
  /// symbol's WIDTH through §3's sizing formula, and freezing that is a
  /// decision nobody has taken. So: `wires` advanced ⇒ hold. Anything else
  /// ⇒ lay out as before.
  ///
  /// A LATCH CONSUMED BY THE NEXT SCENE BUILD, and the first draft of this
  /// was an epoch stamp that did not survive its own first test.
  /// `ConnectPortsCommand.touches` is `wires | meta` — `meta` because
  /// materialisation MINTS A DESIGNATOR — so `DocEpochs.bump` fires the
  /// wires listener, which stamped "hold for epoch 1", and then fires the
  /// meta listener, which advanced the epoch to 2. The stamp no longer
  /// matched, the hold silently did not apply, and every symbol moved on
  /// the very commit the ruling is about.
  ///
  /// A latch has no such window. Several epochs can bump in one
  /// transaction, every listener runs before any `build`, and the scene is
  /// rebuilt lazily in [_sceneFor] — so "some wires bump happened since the
  /// last layout" is exactly the question, and it is answered once and
  /// cleared where it is used.
  Map<Uuid, Pt> _heldPositions = const <Uuid, Pt>{};
  bool _holdLayoutOnNextBuild = false;

  /// Which epochs have moved since the last scene was built (DR-076
  /// §11.75.2).
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// LATCHES FOR THE REASON [_holdLayoutOnNextBuild] IS ONE
  /// ═════════════════════════════════════════════════════════════════
  /// Several epochs bump inside one transaction — `ConnectPortsCommand`
  /// declares `wires | meta` — every listener runs before any `build`,
  /// and the scene is rebuilt lazily in [_sceneFor]. So the question is
  /// "what has moved since the last layout", answered once and cleared
  /// where it is used. An epoch STAMP would lose the race the same way
  /// the first draft of the hold did.
  ///
  /// They decide what may be CARRIED OVER, never whether to rebuild:
  /// `_sceneEpoch` still misses the cache on every change, so a scene is
  /// never a commit behind.
  bool _structureDirty = false;
  bool _metaDirty = false;
  bool _wiresDirty = false;

  /// True only while THIS screen's own connect command is being applied.
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// A GESTURE'S OWN COMMIT IS NOT AN EDIT THAT INVALIDATED IT
  /// ═════════════════════════════════════════════════════════════════
  /// `controller.run` bumps the epochs synchronously, so
  /// `_onDocumentChanged` — and with it [_invalidateLivePreviews] — runs
  /// INSIDE the commit, while `_wireFrom` is still set. The teardown
  /// therefore fired on every successful cable and announced "Wire
  /// cancelled — the document changed" a beat before "W006 connected …".
  ///
  /// IT WAS INVISIBLE TO EVERY `find.text` ASSERTION, because the status
  /// LINE shows only the last message while a screen READER hears both.
  /// It shipped in Phase 2B and was caught by a test that intercepts
  /// `SystemChannels.accessibility` — the population docs/05 §7's keyboard
  /// path exists for is exactly the one that was being told its work had
  /// been thrown away.
  ///
  /// The rack states the same rule for the same reason
  /// (`rack_canvas_screen.dart`'s `_dragCommitting`): "the stale-state
  /// guard must not read a gesture's own successful commit as the edit
  /// that invalidated it". `try`/`finally` for its reason too — a command
  /// that throws must not leave the latch stuck true and the teardown
  /// permanently off.
  ///
  /// SCOPED TO THE WIRE LIMB ALONE. An edit from anywhere else must still
  /// tear the gesture down and say so; that is not a nicety, it is what
  /// makes the cached `_candidates` correct.
  bool _committingWire = false;

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
    widget.controller.epochs.structure.addListener(_onStructureChanged);
    // `wires` gets its OWN callback, and that is DR-011.4 — see
    // [_holdLayoutForEpoch]. It is the one epoch whose bump must not move
    // a symbol.
    widget.controller.epochs.wires.addListener(_onWiresChanged);
    widget.controller.epochs.meta.addListener(_onMetaChanged);
    // `sheet` and `style` COUNT AS STRUCTURE for this cache and not as
    // meta: `sheet` moves `SheetItem.pinned`/`position`, which is where a
    // symbol sits, and `style` resolves into the display list rather than
    // over it (see [_sceneFor]'s key). Neither can reuse a layout. **A
    // `sheet` bump HOLDS the one it rebuilds**, since DR-186 made pins
    // writable: see [_onSheetChanged].
    widget.controller.epochs.sheet.addListener(_onSheetChanged);
    widget.controller.epochs.style.addListener(_onStructureChanged);
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
    // CR-105's arrival. The listener catches a chip clicked while this
    // screen is already mounted; the post-frame drain catches the case
    // that made a controller necessary in the first place — a chip
    // clicked on a tab whose sibling had not been built yet, so the
    // notification had no listener at all. See `schematic_reveal.dart`.
    widget.reveal?.addListener(_onRevealRequested);
    if (widget.reveal?.pending != null) _onRevealRequested();
    // DR-187 §11.186.2. NOT an epoch listener, for the reason
    // `addConsequence` gives at length: by the time an epoch bumps, the
    // undo entry is sealed and the freeze can only be a second one.
    _stopFreezing = widget.controller.addConsequence(_freezeWithTheEdit);
  }

  void Function()? _stopFreezing;

  @override
  void dispose() {
    _stopFreezing?.call();
    _marquee.dispose();
    // THE CURVE BEFORE ITS PARENT: a `CurvedAnimation` unregisters from
    // the controller it was built on, so disposing the controller first
    // leaves it holding a dead parent.
    _springBackCurve?.dispose();
    _springBackAnim?.dispose();
    _flashAnim?.dispose();
    HardwareKeyboard.instance.removeHandler(_onRawKey);
    widget.reveal?.removeListener(_onRevealRequested);
    widget.controller.epochs.structure.removeListener(_onStructureChanged);
    widget.controller.epochs.wires.removeListener(_onWiresChanged);
    widget.controller.epochs.meta.removeListener(_onMetaChanged);
    widget.controller.epochs.sheet.removeListener(_onSheetChanged);
    widget.controller.epochs.style.removeListener(_onStructureChanged);
    _selection
      ..removeListener(_onSelectionChanged)
      ..dispose();
    _canvasFocus.dispose();
    _status.dispose();
    _viewport.dispose();
    super.dispose();
  }

  /// A `wires` bump: the same rebuild as any other, plus DR-011.4's freeze.
  ///
  /// Sets the latch and gets out of the way — see [_holdLayoutOnNextBuild]
  /// for why this may not try to name the epoch it is holding for.
  void _onWiresChanged() {
    if (!mounted) return;
    _holdLayoutOnNextBuild = true;
    _wiresDirty = true;
    _onDocumentChanged();
  }

  /// A `structure`, `sheet` or `style` bump: nothing may be carried over.
  ///
  /// DR-076 §11.75.2's top tier. A device added or removed changes what
  /// Sugiyama is laying out, and a style change is resolved INTO the ops
  /// rather than applied over them, so neither a held layout nor a held
  /// symbol tier describes the sheet any more.
  void _onStructureChanged() {
    if (!mounted) return;
    _structureDirty = true;
    _onDocumentChanged();
  }

  /// Records where the symbols are, INSIDE the edit that is about to move
  /// them (DR-187 §11.186.2, `#916`).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// IT READS THE LAYOUT THAT IS STILL ON SCREEN
  /// ═══════════════════════════════════════════════════════════════════
  /// The hook runs at the tail of the transaction, so the document has
  /// already changed, but [_heldPositions] has not: it is written in
  /// `build`, one frame later. That gap is the whole mechanism. The map
  /// this hands over is the arrangement the person is looking at, and the
  /// command drops every symbol that already has a stored position, so it
  /// records only what the next layout would otherwise invent.
  ///
  /// **ONLY AN EDIT THAT WOULD RE-FLOW**, which is what the ruling says.
  /// `meta` reuses the layout (§11.75.3) and `wires` holds it (DR-011.4),
  /// so neither is an occasion to write anything; `structure` and `style`
  /// rebuild it from scratch, and those are the two this screen hands to
  /// [_onStructureChanged] for exactly that reason.
  ///
  /// **IT RIDES ON THE CANVAS, AND THAT IS A LIMIT WORTH STATING.** Only a
  /// laid-out canvas knows where the symbols are, so an edit made while
  /// the Schematic has never been opened this session records nothing:
  /// there is no arrangement yet to preserve, and the next edit after it
  /// has been looked at freezes what was seen. Nothing is written on
  /// opening one, which is the half the ruling is strict about.
  void _freezeWithTheEdit(TxnScope<RackDocument> tx) {
    if (_heldPositions.isEmpty) return;
    if (!tx.touches.has(EpochMask.structure | EpochMask.style)) return;
    // A sheet that already stores every symbol refuses this, and
    // `TxnScope.add` then keeps it out of the entry entirely (DR-156), so
    // the ordinary edit on a frozen sheet costs nothing at all.
    tx.add(
      StoreSymbolPositionsCommand(
        positions: _heldPositions,
        now: widget.controller.clock.nowUtc(),
        actor: widget.controller.actor,
      ),
    );
  }

  /// A `meta` bump: the symbols are rebuilt, the layout is not
  /// (DR-076 §11.75.3).
  ///
  /// A designator changes what a symbol PRINTS and, through docs/05 §3's
  /// width formula, how wide it is — so the symbol tier is stale. It does
  /// not change what Sugiyama was ordering, and re-running it would move
  /// symbols under the cursor of somebody who just renamed one.
  /// A `sheet` bump: a pin, an unpin, or a plan edit that is not about
  /// this canvas at all (DR-186 §11.185.3).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// IT HOLDS THE LAYOUT, AND THE REASON IS MEASURED RATHER THAN FEARED
  /// ═══════════════════════════════════════════════════════════════════
  /// It was `_onStructureChanged`, which re-lays the sheet out from
  /// scratch. **That is harmless for today's `Ctrl+L`, and the first draft
  /// of this comment said otherwise.** Measured on
  /// `schematic_scene_test.dart`'s fixture: pinning a symbol AT THE
  /// POSITION IT ALREADY HAS moves nothing at all, because the layout
  /// hands a fixed node the answer it was going to give anyway.
  ///
  /// What the same probe found is why the hold is here: pinning that
  /// symbol **24 by 8 grid units away moves all five of the others**,
  /// because a fixed node stops relaxing and everything else re-flows
  /// around it. No gesture writes a pin anywhere but where the symbol
  /// stands yet; the one that will is dragging a symbol, and a relayout
  /// on this epoch is the thing that would make that drag shuffle the
  /// sheet. Holding also stops a schematic re-laying itself out for a
  /// floorplan rotation or rename, which bump this epoch and have nothing
  /// to do with this canvas.
  void _onSheetChanged() {
    if (!mounted) return;
    _holdLayoutOnNextBuild = true;
    _structureDirty = true;
    _onDocumentChanged();
  }

  void _onMetaChanged() {
    if (!mounted) return;
    _metaDirty = true;
    _onDocumentChanged();
  }

  void _onDocumentChanged() {
    if (!mounted) return;
    String? cancelled;
    setState(() {
      _sceneEpoch++;
      cancelled = _invalidateLivePreviews();
    });
    // AFTER the `setState`, because `StatusMessageController.show` notifies
    // its own listeners and would otherwise do so from inside a build.
    final what = cancelled;
    if (what != null) _status.show('$what cancelled — the document changed.');
  }

  void _onSelectionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // ── THE EXCLUSIVITY RULE, IN ONE PLACE ────────────────────────────────
  //
  // Ported from `rack_canvas_screen.dart`'s section of the same name (see
  // this file's header for what is deliberately different). The rule is
  // stated ONCE and every entry point ASKS instead of remembering:
  //
  //  1. AT MOST ONE POINTER-DRIVEN GESTURE, arbitrated by
  //     [_claimPointerGesture] / [_releasePointerGesture] over the single
  //     [_liveGesture] field. A second gesture is REFUSED, never queued:
  //     the first pointer is still physically down and will keep delivering
  //     events only its own live state can interpret, so preemption would
  //     orphan that state permanently.
  //
  //  2. ONE TEARDOWN, [_invalidateLivePreviews], called from the one place
  //     where every live thing on this sheet can stop being true at once —
  //     a document change this screen did not cause (`_onDocumentChanged`).
  //
  // BELOW this, `CanvasIntentDetector` enforces its own half structurally:
  // a second CANVAS pointer never reaches `beginDrag` at all (it is
  // deferred and adopted when the route falls free). That is why this
  // screen's own guard is not redundant with it rather than instead of it
  // — the detector can only see pointers IT routes, and Phase 2's connect
  // gesture is armed on a pin.

  /// Claims the canvas for [gesture]. Returns false — and starts nothing —
  /// when another pointer-driven gesture is already live.
  ///
  /// A REFUSAL IS REPORTED, never silent (docs/04 §3.4's "never silently do
  /// nothing"): the user pressed something and got nothing back, which is
  /// exactly the case that principle exists for. The wording is the rack's
  /// verbatim, because a user who meets this on both canvases must not have
  /// to learn that they are two different refusals.
  bool _claimPointerGesture(_PointerGesture gesture) {
    if (_liveGesture != null) {
      _status.show('One drag at a time — finish the one in progress first.');
      return false;
    }
    _liveGesture = gesture;
    return true;
  }

  /// Releases [gesture]'s claim. A no-op when [gesture] is not the one
  /// holding it, so a refused gesture running its own teardown can never
  /// release the claim belonging to the gesture that refused it.
  void _releasePointerGesture(_PointerGesture gesture) {
    if (_liveGesture == gesture) _liveGesture = null;
  }

  /// THE ONE TEARDOWN for everything on this sheet whose premise a document
  /// change can falsify. Returns a user-facing name for what it tore down,
  /// or null when nothing was live — a scope vanishing with no explanation
  /// would be the silent no-op §3.4 forbids, so the caller reports.
  ///
  /// WHAT IS LIVE ON THIS SHEET, and it is two view scopes rather than a
  /// preview, because Phase 1 builds no preview: `_altHovered` and
  /// `_focused` are DEVICE IDS held across frames, and an undo (or an edit
  /// from another view) can delete the device either of them names. The
  /// `_focused` limb used to be an inline comprehension in
  /// `_onDocumentChanged` that dropped the id and said nothing; moving it
  /// here is what gives it a voice, and `_altHovered` — which had no
  /// pruning at all — is why it needed one: `resolveDrawnScope`'s headline
  /// falls back to the raw id when `designatorOf` cannot resolve it, so a
  /// deleted hover target used to be ANNOUNCED as a uuid.
  ///
  /// THE POINTER GESTURE STILL HAS NO LIMB HERE, and that is not an
  /// omission. Phase 1's canvas gesture captures a scene POINT and a travel
  /// distance — neither names a document entity, and `commitDrag` re-runs
  /// the hit test against the live scene — so there is nothing for a
  /// document change to make stale, and inventing a branch for it would be
  /// a stub with no behaviour behind it (the discipline
  /// `rack_canvas_screen.dart:2996` states for the validation checks).
  ///
  /// THE CONNECT GESTURE IS THE OPPOSITE CASE, which is why it has two
  /// limbs below. It captures PIN IDENTITIES that the document can delete
  /// out from under it, and — worse — [_candidates] is a set of verdicts
  /// computed against a document state that no longer exists. A stale
  /// candidate list is not merely wrong, it is wrong in the direction that
  /// says yes: a pin that filled up while the wire was armed would still be
  /// offered, and `buildConnectPortsCommand` would then refuse it at commit
  /// time with a rule id the user cannot connect to anything they did.
  /// Tearing the whole gesture down is the honest answer, and saying so is
  /// what stops it being the silent no-op docs/04 §3.4 forbids.
  String? _invalidateLivePreviews() {
    String? what;
    // THE WIRE FIRST, because it is the one the user is actively holding.
    // Dropped whole rather than repaired: re-deriving the candidates
    // against the new document would silently continue a gesture whose
    // premise — "these are the pins you may land on" — the user was shown
    // and can no longer trust.
    // ...UNLESS THIS SCREEN IS THE ONE EDITING. See [_committingWire]: a
    // cable's own commit reaches here before the gesture has been cleared,
    // and reporting that as "the document changed under you" is both wrong
    // and, to a screen reader, the last thing said before the success.
    if (_wireFrom != null && !_committingWire) {
      _wireFrom = null;
      _wireFromSetKey = null;
      // THE PLANS GO WITH IT, and they are the sharpest case for this
      // whole teardown: a `MultiDrawPlan` is N verdicts computed against
      // a document state that no longer exists, and committing a stale
      // one would write cables onto jacks that filled while the run was
      // in the air.
      _wireFromBankKey = null;
      _multiPlans = const <(String, String), MultiDrawPlan>{};
      _clearTargets();
      what ??= 'Wire';
    }
    // THE PIN RUN NEXT, AND AHEAD OF THE CARET — the ordering matters
    // because only the FIRST thing torn down is named ("what ??=", and
    // `_onDocumentChanged` shows one sentence). A run of sixteen jacks is
    // the more expensive thing to have lost and the one a user needs told
    // about; the caret is one keystroke to put back.
    //
    // A selection that outlived one of its pins would hand `planMultiDraw`
    // a source that resolves to nothing, and core would drop it in silence
    // — "sixteen cables" quietly becoming fifteen, which is the same class
    // of failure as a stale candidate list and takes the same answer.
    // `prunedAgainst` drops the WHOLE run rather than the missing pin, for
    // the reason stated there.
    if (!_pins.isEmpty) {
      final pruned = _pins.prunedAgainst(
        _bankRank(deviceId: _pins.deviceId!, bankKey: _pins.bankKey!),
      );
      if (pruned.isEmpty) {
        _pins = PinSelection.none;
        what ??= 'Jack selection';
      }
    }
    // A caret over a pin that has gone. ASKED OF THE DOCUMENT, NOT OF THE
    // SCENE, and the difference is a real bug avoided: this runs inside
    // `_onDocumentChanged`'s `setState`, where `_scene` is still the
    // PREVIOUS frame's — the rebuild is lazy, in `_sceneFor`, during
    // `build`. A scene query here would happily find a pin on a device the
    // command just deleted. `resolveConnectTarget` covers both shapes at
    // once: the device left the document, and the device stayed but its
    // template no longer declares the port.
    final caret = _pinCaret;
    if (caret != null && !_pinStillExists(caret)) {
      _pinCaret = null;
      what ??= 'Pin caret';
    }
    final hovered = _altHovered;
    if (hovered != null && !_doc.devices.containsKey(Uuid(hovered))) {
      _altHovered = null;
      what ??= 'Alt-hover';
    }
    // A FOCUS SCOPE OUTLIVES THE DEVICE IT NAMES otherwise. Deleting a
    // focused device would leave `F`'s scope pointing at an id no symbol
    // carries, and the HUD would keep announcing a hop count for a device
    // that is gone. Dropped rather than repaired: the user's question was
    // about that device.
    final kept = <String>{
      for (final id in _focused)
        if (_doc.devices.containsKey(Uuid(id))) id,
    };
    if (kept.length != _focused.length) {
      _focused = kept;
      what ??= 'Focus';
    }
    // A SELECTED CABLE THAT IS NO LONGER IN THE DOCUMENT. Reachable three
    // ways and none of them is a bug: an undo takes back the connect that
    // made it, another view deletes a device at one end and DR-013's cascade
    // takes the cable with it, or a redo re-runs a removal.
    //
    // THE ONE ROUTE THAT DOES *NOT* REACH HERE is this screen's own delete,
    // and that is arranged rather than lucky — [_deleteSelectedLink] clears
    // the field BEFORE running the command, so this limb finds nothing and
    // stays silent. Otherwise the teardown's sentence would land on top of
    // the delete's own, and the last thing a screen reader announced after a
    // successful delete would be "Cable selection was dropped".
    final selectedLink = _selectedLink;
    if (selectedLink != null && !_doc.links.containsKey(selectedLink)) {
      _selectedLink = null;
      what ??= 'Cable selection';
    }
    return what;
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
    // ═════════════════════════════════════════════════════════════════
    // WHAT MAY BE CARRIED OVER (DR-076 §11.75.2)
    // ═════════════════════════════════════════════════════════════════
    // Measured at 3,600 links, best of five: a full build is 96 ms, the
    // `holdAt` path this replaced is 90 ms, reusing the layout is 46 ms
    // and reusing the whole symbol tier is 19.6 ms.
    //
    // THE LOOK IS PART OF THE QUESTION. Palette and theme are resolved
    // INTO the ops, so a scene built under one may not lend its symbols
    // to another; when either moved, nothing is carried.
    //
    // A STRUCTURE BUMP CARRIES NOTHING EVEN WHEN WIRES MOVED WITH IT.
    // `AtomicConnectCommand` declares `structure | wires | meta`: it
    // creates a device, and a held layout has never seen it. That case
    // keeps the `holdAt` path exactly as before, so DR-011.4's freeze
    // still applies to it and this change stays additive.
    final previous = cached;
    final sameLook = _sceneKey?.palette == palette && _sceneKey?.theme == theme;
    final carry = previous != null && sameLook && !_structureDirty;
    final built = buildSchematicScene(
      doc: _doc,
      measurer: widget.measurer,
      palette: palette,
      netLabelStyle: NetLabelStyle(theme: theme),
      // `#801`. Every toggle bumps `_sceneEpoch` and sets
      // `_structureDirty`, so a tier built under a different expansion is
      // never carried: a symbol with the wrong pin count would put every
      // wire on this sheet in the wrong place.
      expandedBanks: _expandedBanks,
      // DR-011.4 — see [_holdLayoutOnNextBuild]. A hold is a layout INPUT
      // and never a document write, which is the whole reason the ruling
      // chose this shape over pinning every symbol into CR-117's byte
      // surface. It is still what a structure-and-wires commit uses.
      holdAt: _holdLayoutOnNextBuild && !carry
          ? _heldPositions
          : const <Uuid, Pt>{},
      // §11.75.3: a rename rebuilds the symbols and keeps the layout.
      reuseLayout: carry && _metaDirty ? previous.layout : null,
      // §11.75.2: a wires-only edit keeps the symbols too. Seven commands
      // declare `wires` alone — a class, a jacket colour — and eight
      // declare `wires | meta`, which lands on the line above because
      // materialising a port mints a designator.
      //
      // BOTH ARMS REQUIRE THEIR OWN FLAG, so a rebuild reached by some
      // path that set none of them carries nothing. That is the
      // conservative direction: a scene built from a stale tier is a
      // drawing that is wrong, and a scene built from scratch is only
      // slow.
      reuseSymbols: carry && _wiresDirty && !_metaDirty
          ? previous.symbolTier
          : null,
    );
    _structureDirty = false;
    _metaDirty = false;
    _wiresDirty = false;
    // Cleared HERE and not in the listener: a cache hit is not a layout,
    // and a latch cleared on a frame that reused the previous scene would
    // lose the hold before the rebuild it was set for ever happened.
    _holdLayoutOnNextBuild = false;
    _scene = built;
    _sceneKey = key;
    // Whatever this layout decided becomes what the NEXT wires bump holds.
    // Read off the scene rather than recomputed from `bodyRect`: the map
    // is what `layoutSugiyama` actually produced, and a second derivation
    // is how a hold drifts half a grid unit from the thing it froze.
    _heldPositions = built.positions;
    return built;
  }

  /// The plan without the overlay, rebuilt only when something it reads
  /// has changed (`#705`).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// EVERY `setState` ON THIS SCREEN WAS REBUILDING THE WHOLE DRAWING
  /// ═══════════════════════════════════════════════════════════════════
  /// `buildSchematicPaintPlan` ran inside `build`, so selecting a cable,
  /// moving the pin caret, arming a wire or changing the pin selection —
  /// all of which are `setState` and none of which move a symbol — emitted
  /// every symbol, every wire and every net label again. Measured on the
  /// 300-link fixture: 7,155 ops and 5.6 ms, per keystroke of `Tab`.
  ///
  /// THE KEY IS THE SCENE'S IDENTITY, AND THAT IS SOUND RATHER THAN
  /// CONVENIENT. `buildSchematicPaintPlan` reads `(scene, doc, filter,
  /// scope)`. [_sceneFor] rebuilds the scene whenever any of the five
  /// epochs this screen listens to advances, so a scene this screen is
  /// still holding is proof the document has not changed in any way the
  /// schematic reads. The other three are compared by value.
  ///
  /// The overlay is spliced on afterwards by `withOverlay`, which is a
  /// list copy. A caret move therefore costs a copy of 7,155 references
  /// instead of a layout, and when there is no overlay at all the plan is
  /// the SAME OBJECT, so `RenderSchematicCanvas.plan`'s `identical` guard
  /// short-circuits and the frame does not even repaint.
  SchematicPaintPlan? _basePlan;
  ({
    SchematicScene scene,
    SchematicViewFilter filter,
    DrawnScope? scope,
    SchematicPalette palette,
    int groundArgb,
  })?
  _basePlanKey;

  SchematicPaintPlan _basePlanFor({
    required SchematicScene scene,
    required DrawnScope? scope,
    required SchematicPalette palette,
    required int groundArgb,
  }) {
    final key = (
      scene: scene,
      filter: _filter,
      scope: scope,
      palette: palette,
      groundArgb: groundArgb,
    );
    final cached = _basePlan;
    if (cached != null && _basePlanKey == key) return cached;
    final built = buildSchematicPaintPlan(
      scene: scene,
      doc: _doc,
      filter: _filter,
      scope: scope,
      measurer: widget.measurer,
      palette: palette,
      groundArgb: groundArgb,
    );
    _basePlan = built;
    _basePlanKey = key;
    return built;
  }

  // ── input ─────────────────────────────────────────────────────────────

  /// The point query over [scene]'s symbols at the CURRENT zoom.
  ///
  /// TWO PARAMETERS, AND BOTH ARE CITATIONS. `portHitTolerance` is docs/05
  /// §11.6's 12 screen px converted into diagram units by the live scale
  /// (see [_portHitTolerancePx]); `snapGridSize` is `kSchematicUnitsPerGrid`,
  /// the sheet's own pitch, NEVER `SymbolHitTestParams`' default 20 — that
  /// default is a generic figure for a caller with no grid of its own, and
  /// a query that snapped to it would put a cursor hint between this
  /// sheet's grid lines.
  ///
  /// Nothing consumes the snap yet (Phase 1 draws no rubber band), but the
  /// parameter is not left at its default for that reason: `snapToGrid` is
  /// public on `SymbolHitTest` precisely so the wire-draw state machine and
  /// the cursor hint cannot derive it two ways, and a wrong pitch cached
  /// here would be inherited by both.
  SymbolHitTest _hitTestFor(SchematicScene scene) {
    final params = SymbolHitTestParams(
      portHitTolerance: _portHitTolerancePx / _viewport.scale,
      snapGridSize: kSchematicUnitsPerGrid,
    );
    final cached = _hitTest;
    if (cached != null &&
        identical(_hitTestScene, scene) &&
        _hitTestParams == params) {
      return cached;
    }
    final built = SymbolHitTest(symbols: scene.symbols, params: params);
    _hitTest = built;
    _hitTestScene = scene;
    _hitTestParams = params;
    return built;
  }

  /// The BODY regions of [scene]'s symbols, cached — see [_bodyRegions].
  ///
  /// Built from `symbolHitRegions`, the same function `SymbolHitTest` builds
  /// its own regions from, and filtered by the `partKey == null` test that
  /// file uses to separate bodies from pins. Not a second derivation of a
  /// symbol's rectangle: this screen must never be able to disagree with the
  /// query beside it about where a body is.
  List<HitRegion> _bodyRegionsFor(SchematicScene scene) {
    final cached = _bodyRegions;
    if (cached != null && identical(_bodyRegionsScene, scene)) return cached;
    final built = symbolHitRegions(
      scene.symbols,
    ).where((r) => r.partKey == null).toList(growable: false);
    _bodyRegions = built;
    _bodyRegionsScene = scene;
    return built;
  }

  /// The device under [scenePoint], or null.
  ///
  /// A REAL HIT TEST NOW — `SymbolHitTest`, the query `rackpal_core` ships
  /// beside the painter that draws these pins, rather than a reverse walk
  /// over `DiagramScene.hits`. Two things change and both matter:
  ///
  ///  * PINS ARE HITTABLE. The reverse walk was written under a doc comment
  ///    claiming "a pin region sits after the body it belongs to", which is
  ///    BACKWARDS: `symbolHitRegions` emits every pin FIRST and the body
  ///    LAST (`symbol_hit_test.dart:190-201`), so walking backwards found
  ///    the body first and no pin was ever reachable. The comment has been
  ///    deleted rather than corrected. `SymbolHitTest` ranks pins and
  ///    bodies in two passes for exactly this reason — a pin sits ON its
  ///    body's edge, so a body that could win would make edge pins
  ///    unclickable.
  ///  * IT IS `contains`, NOT NEAREST, that went. The walk returned the
  ///    first region containing the point; `hitTestRegions` returns the
  ///    NEAREST qualifier, which is the ruling `draw/hit_test.dart` states
  ///    and which the rack elevation has always used.
  ///
  /// This answers "WHICH DEVICE", which is all `Alt`-hover and selection
  /// ask, and Phase 1 changes neither answer. `SymbolHitResult` carries the
  /// `portKey`, the pin centre and the side as well — that is what Phase 2
  /// and 3 grab, and it is reachable through [_hitTestFor] without this
  /// method growing a second caller it does not have yet.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// CONTAINMENT FIRST, AND WHY `testPoint` ALONE IS THE WRONG QUERY HERE
  /// ═══════════════════════════════════════════════════════════════════
  /// `SymbolHitTest.testPoint`'s pin-beats-body precedence is GLOBAL: it
  /// ranks EVERY pin on the sheet with `portHitTolerance` of slop before it
  /// looks at any body, and bodies are ranked with none
  /// (`symbol_hit_test.dart:290-320`). Since the tolerance is docs/05
  /// §11.6's 12 SCREEN px divided by the live scale, it grows without bound
  /// as the user zooms out — 31 diagram units two scroll notches out of the
  /// framed view, 240 at `kMinScale` — so a NEIGHBOUR's pin outranks the
  /// body the pointer is literally inside. Measured on this repo's own
  /// fixture: a point one unit above AMP-1's bottom edge and well inside its
  /// x-span resolved to DIS-1, whose nearest pin was 26 units away, because
  /// AMP-1's own nearest pin was 39 away and lost the pin pass. At
  /// `kMinScale` the tolerance is wider than every symbol in the fixture and
  /// body containment is never consulted at all.
  ///
  /// So the two questions are separated rather than the ruling weakened. The
  /// pin pass exists so an EDGE PIN IS REACHABLE AS A PIN — half of a pin's
  /// circle lies outside its own body, and a body that could win would make
  /// that half unclickable, which is Phase 2's whole gesture. It does not
  /// exist so that a device fifty units away can win a click that landed
  /// inside a different device. A containing body therefore answers first,
  /// ranked by `hitTestRegions` with the default zero tolerance — the same
  /// nearest-hit ranking `SymbolHitTest` uses for its own body pass, so
  /// overlapping bodies still resolve to the one the cursor is most centred
  /// on — and the global pin pass answers only when the point is inside no
  /// body at all.
  ///
  /// The pin pass keeps every case it was added for: `symbol_hit_test.dart`
  /// asserts a pin is hittable AT ITS DRAWN CENTRE, and a centre on a body
  /// edge is not strictly inside it, so those queries still take the pin
  /// path here.
  String? _deviceAt(SchematicScene scene, DPt scenePoint) {
    final body = hitTestRegions(_bodyRegionsFor(scene), scenePoint);
    if (body != null) return body.entityId;
    return _hitTestFor(scene).testPoint(scenePoint).nodeId;
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

  /// CR-105's arrival: select the device the elevation's chip pointed at,
  /// and put it on screen.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// DEFERRED A FRAME, BECAUSE THE SHEET MAY NOT EXIST YET
  /// ═══════════════════════════════════════════════════════════════════
  /// This runs from `initState` as well as from the controller's
  /// notification, and in the `initState` case `_scene` is null — nothing
  /// has laid a symbol out. It also runs while the SHELL is mid-`setState`
  /// switching tabs, and `_selection.apply` notifies synchronously
  /// (`selection_controller.dart`), which would call `setState` during
  /// another widget's build. One post-frame hop answers both.
  ///
  /// A DEVICE WITH NO SYMBOL IS SAID OUT LOUD rather than silently
  /// ignored. docs/05's sheet draws a symbol only for a device whose
  /// template declares at least one port (`kNoSymbolsDetail`), and a
  /// device with no ports has no chip either — so this is unreachable from
  /// the elevation today and is still handled, because "the click did
  /// nothing" is the one outcome a navigation affordance may never
  /// produce.
  void _onRevealRequested() {
    final id = widget.reveal?.take();
    if (id == null) return;
    // `ensureVisualUpdate` IS LOAD-BEARING, not belt-and-braces.
    // `addPostFrameCallback` QUEUES a callback; it does not schedule the
    // frame that would run it. Reaching here from the controller's
    // notification rather than from `initState` means no build is in
    // flight and nothing has called `setState`, so with no frame pending
    // the callback waits for whatever happens to schedule one next — in
    // production the shell's own tab switch, which is real but is
    // somebody else's `setState` and not a contract. Measured: every
    // reveal driven through the controller did nothing at all until this
    // line existed, while the `initState` path (inside a frame already)
    // worked, which is the shape of a defect that survives to production
    // and fires intermittently.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted) return;
        _revealNow(id);
      })
      ..ensureVisualUpdate();
  }

  void _revealNow(Uuid id) {
    final scene = _scene;
    // A CABLE, since DR-193 §11.192: `F8` on a finding about a cable
    // lands here. Selected through the same method a click on its net
    // label uses, so the two cannot disagree about what "selected" means.
    if (_doc.links.containsKey(id)) {
      _canvasFocus.requestFocus();
      final drawn = scene?.netLabels.any((l) => l.linkId == id) ?? false;
      if (!drawn) {
        // Said rather than skipped: a home run not yet landed at the rack
        // has no end on this sheet, and a silent key reads as a broken one.
        _status.show(
          '${_cableSaying(id)} has no drawn end on this sheet. Land it '
          'from Structured Wiring.',
        );
        return;
      }
      _selectCable(id);
      return;
    }
    final device = _doc.devices[id];
    if (device == null) {
      _status.show('That device is no longer in this document.');
      return;
    }

    _selection.apply(<Uuid>[id], SelectMode.replace);
    _canvasFocus.requestFocus();

    final symbol = scene?.symbols.where((s) => s.id == id.v).firstOrNull;
    if (symbol == null) {
      _status.show(
        '${device.designator} carries no ports, so it is not drawn on '
        'this sheet.',
      );
      return;
    }

    // Centred rather than zoomed to fit: the user came here to WIRE this
    // device, and a viewport filled by one symbol hides every pin they
    // might reach for. `fitToContent` over a box inflated by the symbol's
    // own size keeps its neighbours on screen, which is the frame docs/05
    // §11 opens the sheet at, applied to one device instead of the sheet.
    final size = _lastViewportSize;
    if (size != null && !size.isEmpty) {
      final pad = symbol.bodyRect.width;
      _viewport.fitToContent(
        Box.fromCorners(
          Pt(
            (symbol.bodyRect.left - pad).floor(),
            (symbol.bodyRect.top - pad).floor(),
          ),
          Pt(
            (symbol.bodyRect.right + pad).ceil(),
            (symbol.bodyRect.bottom + pad).ceil(),
          ),
        ),
        size,
      );
    }
    _status.show(
      '${device.designator} selected — press W on a pin to draw a cable.',
    );
  }

  /// Reports AC-048's mark as seen, once.
  ///
  /// Guarded on `showFilterCoachMark` so the filter chips do not write a
  /// preference on every click for the rest of the product's life — the
  /// store's write is atomic but it is still a file, and this is a
  /// keyboard-rate control.
  void _dismissCoachMark() {
    if (!widget.showFilterCoachMark) return;
    widget.onDismissFilterCoachMark?.call();
  }

  /// Applies whatever CR-102's band caught (DR-139 §11.138).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE BODY REGIONS, NOT THE WHOLE SCENE
  /// ═══════════════════════════════════════════════════════════════════
  /// A schematic symbol contributes one `HitRegion` per PORT as well as
  /// one for its body, all carrying the same `entityId`. `marquee.dart`
  /// filters parts out on its own, so either set gives the right answer;
  /// this hands over the cached body list because the screen already has
  /// it and rebuilding a scene's hits to ask one question is work for
  /// nothing.
  ///
  /// A SWEEP REPLACES THE SELECTION EVEN WHEN IT CAUGHT NOTHING, which is
  /// what makes dragging across bare sheet a deselect rather than a no-op
  /// with a stuck rectangle.
  void _commitMarquee() {
    final scene = _scene;
    if (scene == null) {
      _marquee.cancel();
      return;
    }
    final caught = _marquee.endIn(_bodyRegionsFor(scene));
    setState(() {
      _selection.apply(caught.map(Uuid.new).toList(), SelectMode.replace);
    });
  }

  void _selectAt(DPt scenePoint) {
    final scene = _scene;
    if (scene == null) return;
    // ═════════════════════════════════════════════════════════════════
    // THE PENNANT IS ASKED FIRST, BECAUSE IT IS DRAWN LAST
    // ═════════════════════════════════════════════════════════════════
    // Net labels are emitted after every symbol (`schematic_paint_plan
    // .dart`'s ordering rule) and there is no z-index in the IR, so a
    // pennant overlapping a symbol body is the thing the user can SEE at
    // that point. Testing the body first would select the device through a
    // flag sitting on top of it — the pointer equivalent of the painter /
    // hit-tester desync `symbol_layer.dart`'s header records.
    //
    // NO MODIFIER BRANCH, and that is a ruling rather than an omission.
    // docs/04 §3.5's additive click model is about a SET (devices, where
    // "add to the selection" means something); a cable selection is exactly
    // one link, because the only thing it feeds today is a delete and
    // "delete these four cables" is a counted-confirmation gesture DR-013
    // rules for devices and nothing rules for cables. A `Ctrl`+click that
    // silently behaved like a plain one would be worse than one that reads
    // as plain, so the modifier is not consulted at all.
    final cable = linkAtPoint(
      scene,
      scenePoint,
      tolerance: _portHitTolerancePx / _viewport.scale,
    );
    if (cable != null) {
      _selectCable(cable);
      return;
    }
    // A CLICK OFF EVERY PENNANT DROPS THE CABLE, on the same principle a
    // click off every symbol drops the device selection below: the sheet is
    // one surface and clicking empty paper means "nothing", not "keep what
    // you had and also nothing".
    if (_selectedLink != null) setState(() => _selectedLink = null);
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

  // ── removing a cable (#96) ────────────────────────────────────────────
  //
  // THE COMMAND EXISTED AND NOTHING COULD REACH IT. `RemoveLinkCommand` has
  // been in core since M0 with a lossless revert and a thousand random
  // sequences of `command_roundtrip_test` over it, and the string appeared
  // in no file of this package — so the only way to remove a cable was to
  // delete a device at one end and let DR-013's cascade take it. That is a
  // hole rather than a ruling: nothing in the corpus says a cable is
  // permanent, and docs/05 §7 gives the connect gesture a cancel precisely
  // because a user who draws the wrong thing must be able to say so.

  /// Selects [linkId] and says what was picked.
  void _selectCable(Uuid linkId) {
    setState(() => _selectedLink = linkId);
    _status.show('${_cableSaying(linkId)} selected — Del removes it.');
  }

  /// How a sentence should NAME a cable.
  ///
  /// The designator first, because that is what the schedule prints and
  /// what an installer reads off a label. Then its two ends in CR-042's
  /// citation shape, so "W004" is anchored to something the user can see on
  /// the sheet rather than being a bare identifier.
  ///
  /// THE CONDUCTOR COUNT IS SAID WHENEVER IT IS NOT ONE, and that is the
  /// clause this method exists for. An atomic set — a stereo pair, a
  /// speaker pair, a component run — is ONE `Link` carrying N conductors
  /// across N pins, and `net_label_layer.dart` draws a pennant for
  /// `conductors.first` alone. So a user deleting what looks like the cable
  /// on `L` is also deleting the one on `R`, and the sheet has not told
  /// them. Until the bracket lands, this sentence is the only place that
  /// fact is stated.
  String _cableSaying(Uuid linkId) {
    final link = _doc.links[linkId];
    if (link == null) return 'That cable';
    final ends = <String>[];
    if (link.conductors.isNotEmpty) {
      final first = link.conductors.first;
      for (final end in <Endpoint>[first.from, first.to]) {
        if (end is! PortEndpoint) continue;
        final port = _doc.ports[end.portId];
        if (port == null) continue;
        final device = _doc.devices[port.deviceId];
        if (device == null) continue;
        ends.add('${device.designator} ${port.designator}');
      }
    }
    final where = ends.length == 2 ? ' (${ends[0]} to ${ends[1]})' : '';
    final n = link.conductors.length;
    final wide = n > 1 ? ', $n conductors' : '';
    return '${link.designator}$where$wide';
  }

  /// The cable on the pin under the caret, or null.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// ASKED OF THE DOCUMENT, NOT OF THE SCENE
  /// ═══════════════════════════════════════════════════════════════════
  /// `RenderedNetLabel` carries a `linkId` beside a device and a port key,
  /// so the scene could answer this without a document query — and it would
  /// be wrong on exactly the pin a user is most likely to be standing on
  /// when they reach for `Del`. The label layer draws `conductors.first`
  /// only, so the `R` of an atomically-connected stereo pair has a
  /// conductor in it and NO PENNANT: a scene lookup reports it free and the
  /// keyboard route would decline to delete a cable that is really there.
  /// [linksOnPort] walks conductors, so it does not care what was drawn.
  ///
  /// Null when the caret is nowhere, when the pin carries nothing, or when
  /// it carries MORE THAN ONE — a bus tap can, and picking one of them for
  /// the user is a guess about which cable they meant. The caller says so.
  Uuid? _cableOnCaret() {
    final caret = _pinCaret;
    if (caret == null) return null;
    final links = linksOnPort(
      _doc,
      derivePortId(Uuid(caret.deviceId), PortKey(caret.portKey)),
    );
    return links.length == 1 ? links.first : null;
  }

  /// `Del` / `Backspace` on the sheet — DR-013's sibling for one cable.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// NO CONFIRMATION, AND DR-013 IS WHY RATHER THAN WHY NOT
  /// ═══════════════════════════════════════════════════════════════════
  /// §11.13.2 wants a counted dialog for a device delete because it
  /// *"destroys work the user cannot see all of"* — the cables go with it
  /// and none of them is what was clicked. A cable delete is the opposite:
  /// the user picked the cable, it is one row on the schedule, and the
  /// ruling's own last sentence is that *"a device carrying nothing prompts
  /// not at all"*. A dialog here is the nag that teaches people to click
  /// through dialogs, which is the cost DR-013 names.
  ///
  /// What discharges §3.4 instead is the SENTENCE: what went, and that one
  /// keystroke brings it back.
  void _deleteSelectedLink() {
    final id = _selectedLink ?? _cableOnCaret();
    if (id == null) {
      // NOT A SILENT NO-OP (docs/04 §3.4). Three different nothings, and
      // the user can act on each: pick a flag, move the caret onto a wired
      // pin, or disambiguate a jack carrying several cables.
      final caret = _pinCaret;
      if (caret == null) {
        _status.show('Nothing selected. Click a net flag to pick a cable.');
        return;
      }
      final links = linksOnPort(
        _doc,
        derivePortId(Uuid(caret.deviceId), PortKey(caret.portKey)),
      );
      _status.show(
        links.isEmpty
            ? '${_saying(caret)} carries no cable.'
            : '${_saying(caret)} carries ${links.length} cables — click the '
                  'net flag of the one to remove.',
      );
      return;
    }
    final saying = _cableSaying(id);
    // BEFORE THE COMMAND, so `_invalidateLivePreviews` finds nothing to
    // prune and does not narrate this delete as a teardown over the top of
    // the sentence below. See its own limb for the other half of this.
    setState(() => _selectedLink = null);
    widget.controller.run(
      RemoveLinkCommand(id: id, netId: netToRemoveWith(_doc, id)),
    );
    _status.show('$saying removed. Ctrl+Z puts it back.');
  }

  // ── keyboard (docs/05 §14) ────────────────────────────────────────────

  /// Whether a `TextField` currently holds focus — `rack_canvas_screen.dart`'s
  /// own getter, verbatim, and it is a read of LIVE FOCUS rather than of
  /// widget identity precisely so it stays correct for fields that do not
  /// exist yet.
  ///
  /// THAT IS WHY IT IS HERE ON A SCREEN WITH NO TEXT FIELD. docs/04 §8's
  /// rule is "'global' never means 'including inside a text field'", and
  /// the defect it was written for was introduced by ADDING a text field to
  /// a subtree whose keymap predated it. A filter-bar search box, a net-name
  /// edit, an inspector — any of them lands inside this `Shortcuts`, and
  /// eight bare digits and three bare letters are sitting in front of it.
  bool get _textFieldHasFocus {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// The gate for keys that MEAN SOMETHING ABOUT THIS SHEET — `1`–`8`,
  /// `` ` ``, `F`. Not merely "no text field has focus": the key is only for
  /// this screen when this screen has focus.
  bool get _canvasKeysEnabled => !_textFieldHasFocus && _canvasFocus.hasFocus;

  /// `Ctrl+L` over the selected symbols (DR-186 §11.185.3).
  ///
  /// PINNED WHERE THEY STAND: the positions are [_heldPositions], which is
  /// what the last layout actually produced and what the symbols are drawn
  /// at, so pinning moves nothing. The toggle rule is the rack's: anything
  /// unpinned in the selection pins all of it, otherwise unpin all.
  void _togglePinSelection() {
    final ids = [
      for (final id in _selection.ids)
        if (_heldPositions.containsKey(id)) id,
    ];
    if (ids.isEmpty) {
      _status.show('Only a symbol on the sheet can be pinned.');
      return;
    }
    final pinned = pinnedSymbolIds(_doc);
    final pin = ids.any((id) => !pinned.contains(id));
    widget.controller.run(
      SetSymbolPinnedCommand(
        positions: {for (final id in ids) id: _heldPositions[id]!},
        pinned: pin,
        now: widget.controller.clock.nowUtc(),
        actor: widget.controller.actor,
      ),
    );
    final what = ids.length == 1
        ? (_doc.devices[ids.single]?.designator ?? ids.single.v)
        : '${ids.length} symbols';
    _status.show(
      pin
          ? 'Pinned $what. Auto-layout leaves it where it is.'
          : 'Unpinned $what.',
    );
  }

  /// `Tidy sheet` from the filter bar (DR-187 §11.186.7, `#920`).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE FREEZE IS ONLY SAFE TO SHIP BECAUSE OF THIS
  /// ═══════════════════════════════════════════════════════════════════
  /// §11.186.1 keeps a sheet's layout forever, which is what was asked
  /// for and which also means a sheet that has gone wrong stays wrong.
  /// This is the way back: every unpinned stored position is removed and
  /// the layout gets its say again. A pinned symbol is never touched
  /// (CR-068), which is the one thing pinning still means.
  ///
  /// **THE COUNT IN THE DIALOG AND THE COUNT THAT MOVES ARE ONE ANSWER**,
  /// both from `wouldReflow`, so the sentence cannot overstate the edit.
  /// It is re-read after the await rather than trusted across it: a
  /// dialog is a frame boundary and the document can change under it.
  Future<void> _tidySheet() async {
    final before = TidySheetCommand.wouldReflow(_doc);
    if (before == 0) return;
    if (!await confirmTidySheet(context, count: before)) return;
    if (!mounted) return;
    // RE-READ, not carried across the await. Nothing in the product can
    // edit the sheet while a modal is up today, so this is a guard rather
    // than a fix, and a guard that costs one map walk is worth its price.
    final now = TidySheetCommand.wouldReflow(_doc);
    if (now == 0) {
      _status.show('Nothing left to tidy.');
      return;
    }
    widget.controller.run(TidySheetCommand());
    _status.show(
      now == 1
          ? 'Tidied 1 symbol. Ctrl+Z puts it back.'
          : 'Tidied $now symbols. Ctrl+Z puts them back.',
    );
  }

  /// The body rect of every pinned symbol the last scene drew, for the
  /// badge layer. Read off the SAME set the layout honours.
  // -- dragging a symbol (`#918`, DR-187 §11.186.4 and §11.186.8) ------

  /// The symbol being dragged and where its body would land, or null.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE BODY RECT IS CAPTURED AT THE PRESS AND NEVER RE-READ
  /// ═══════════════════════════════════════════════════════════════════
  /// A drag is the one gesture during which the sheet must not move, so
  /// re-asking the scene for the symbol's box on every move would be
  /// asking a question whose answer is deliberately frozen. Holding the
  /// press-time rect also means the ghost is the symbol's real size even
  /// if a rebuild lands mid-drag from another view.
  ///
  /// **`at` IS NULL UNTIL THE FIRST MOVE PAST THE SLOP**, which is what
  /// keeps the ghost off an ordinary selection. Armed at the press with a
  /// box, it drew a dashed outline exactly over the symbol on every click,
  /// which is the flicker `_SchematicClickHandler.updateDrag`'s own
  /// comment argues against; a test caught it saying so.
  ({Uuid id, DBox from, DPt grabbedAt, DBox? at})? _symbolDrag;

  /// Arms a drag on [id]. False hands the press back to the marquee.
  ///
  /// **A SYMBOL WITH NO DRAWN POSITION CANNOT BE DRAGGED**, and refusing
  /// here rather than at the commit is what keeps the press useful: it
  /// falls through to the band and then to the click, so the device is
  /// still selected exactly as it was before this chapter.
  bool _beginSymbolDrag(Uuid id, DPt sceneStart) {
    final scene = _scene;
    if (scene == null) return false;
    if (!_heldPositions.containsKey(id)) return false;
    final symbol = scene.symbols.where((s) => s.id == id.v).firstOrNull;
    if (symbol == null) return false;
    // THE PRESS, NOT `_lastScenePointer`. That field is fed by `onHover`
    // and a touch never hovers, so a drag that grabbed from it would work
    // on a mouse and refuse on a touchscreen.
    final start = sceneStart;
    setState(() {
      _symbolDrag = (
        id: id,
        from: symbol.bodyRect,
        grabbedAt: start,
        // NO GHOST YET. The press may still turn out to be a click, and
        // the outline is a claim that something is moving.
        at: null,
      );
    });
    return true;
  }

  /// Moves the ghost. THE POINTER CARRIES THE BOX BY ITS GRAB OFFSET, not
  /// by its corner: a symbol grabbed in the middle that jumped its
  /// top-left onto the cursor would leap on the first pixel of travel.
  void _dragSymbolTo(DPt scenePoint) {
    final drag = _symbolDrag;
    if (drag == null) return;
    final dx = scenePoint.x - drag.grabbedAt.x;
    final dy = scenePoint.y - drag.grabbedAt.y;
    setState(() {
      _symbolDrag = (
        id: drag.id,
        from: drag.from,
        grabbedAt: drag.grabbedAt,
        at: DBox.fromCorners(
          DPt(drag.from.left + dx, drag.from.top + dy),
          DPt(drag.from.right + dx, drag.from.bottom + dy),
        ),
      );
    });
  }

  /// Lands the symbol and pins it (CR-068).
  ///
  /// **THE STORED POSITION IS THE LAYOUT'S ANCHOR, NOT THE BODY'S CORNER.**
  /// `_heldPositions` is what `layoutSugiyama` produced and what
  /// `storedSymbolPositions` feeds back in, so the new position has to be
  /// that same anchor moved by the drag. Deriving it from `bodyRect` would
  /// put the symbol wherever the gap between the two happens to be, which
  /// is a constant nobody stated and which a symbol with a taller header
  /// would not share.
  void _commitSymbolDrag(DPt scenePoint) {
    final drag = _symbolDrag;
    setState(() => _symbolDrag = null);
    if (drag == null) return;
    // ═══════════════════════════════════════════════════════════════════
    // THE DROP SELECTS, AND THE PRESS DELIBERATELY DOES NOT
    // ═══════════════════════════════════════════════════════════════════
    // Something has to select the symbol, because `Ctrl+Shift+U` reads the
    // SELECTION and the moment somebody wants it is right after a drag has
    // pinned something. Doing it at the press is the conventional shape
    // and is WRONG HERE: a press is not yet a gesture, and
    // `schematic_gesture_infrastructure_test.dart` proves it in a case
    // older than this chapter. A press whose canvas is unmounted under it
    // is CANCELLED, never committed, so a press that had already selected
    // would leave that selection behind after a gesture the product says
    // did not happen. It failed exactly there, on `F` drawing four wires
    // for a device nothing should have picked.
    //
    // AN ALREADY-SELECTED SYMBOL DOES NOT COLLAPSE THE SELECTION, on
    // docs/04 §3.5's click model: a plain act replaces only when it lands
    // on something that was not already in the set, so dragging one of
    // five picked symbols keeps the other four.
    if (!_selection.contains(drag.id)) {
      _selection.apply(<Uuid>[drag.id], SelectMode.replace);
    }
    final anchor = _heldPositions[drag.id];
    if (anchor == null) return;
    final to = Pt(
      anchor.gx + (scenePoint.x - drag.grabbedAt.x).round(),
      anchor.gy + (scenePoint.y - drag.grabbedAt.y).round(),
    );
    if (to == anchor) return; // DR-156: a move to where it already is.
    widget.controller.run(
      SetSymbolPinnedCommand.move(
        positions: {drag.id: to},
        now: widget.controller.clock.nowUtc(),
        actor: widget.controller.actor,
      ),
    );
    final what = _doc.devices[drag.id]?.designator ?? drag.id.v;
    _status.show('Moved $what. It is pinned now; Ctrl+Shift+U releases it.');
  }

  /// Drops the ghost with nothing written.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE FIELD IS CLEARED FIRST AND THE REBUILD IS ASKED FOR SECOND
  /// ═══════════════════════════════════════════════════════════════════
  /// A cancel can arrive while the framework is LOCKED. The canvas subtree
  /// is unmounted under a live pointer when an edit empties the sheet
  /// (`schematic_gesture_infrastructure_test.dart`'s case 2c), the
  /// detector's teardown ends the gesture, and all of that happens inside
  /// `finalizeTree`, where `setState` throws *"cannot be marked as needing
  /// to build because the framework is locked"*.
  ///
  /// **ASSIGNING THE FIELD IS ALWAYS SAFE** and is what the next build
  /// reads. The `setState` is only needed for an ORDINARY cancel, where
  /// nothing else has scheduled a rebuild; in the locked case a frame is
  /// already being built and will read the null on its way past.
  void _cancelSymbolDrag() {
    if (_symbolDrag == null) return;
    _symbolDrag = null;
    if (!mounted) return;
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      return;
    }
    setState(() {});
  }

  /// The symbol body under [scenePoint], for the gesture's fourth branch.
  ///
  /// THE BODY ONLY, deliberately narrower than [_deviceAt]: that one falls
  /// back to the layout's node box, which is padded and reaches into the
  /// gaps between symbols. Selecting through that padding is generous and
  /// right; MOVING through it would start a drag on a press that visibly
  /// landed on empty paper, and empty paper is the marquee's.
  Uuid? _symbolAt(DPt scenePoint) {
    final scene = _scene;
    if (scene == null) return null;
    final body = hitTestRegions(_bodyRegionsFor(scene), scenePoint);
    return body == null ? null : Uuid(body.entityId);
  }

  /// The selected symbols an arrow could move.
  ///
  /// A SYMBOL THE SHEET DRAWS, which is narrower than "selected": the
  /// selection is shared with the rack and the inspector and can name a
  /// device this sheet has no symbol for (a device with no ports, or one
  /// the domain filter has taken away).
  List<Uuid> _nudgeableSelection() => [
    for (final id in _selection.ids)
      if (_heldPositions.containsKey(id)) id,
  ];

  /// One grid unit in [direction], pinning what it moves (CR-068).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// ONE UNIT, AND THE UNIT IS THE ONE THE POSITION IS STORED IN
  /// ═══════════════════════════════════════════════════════════════════
  /// `Pt` is integer grid units (CR-001), so a nudge of one is the
  /// smallest move the format can hold. Anything finer would round to
  /// either nothing or the same thing, and a key that sometimes does
  /// nothing is worse than one that always moves a little.
  ///
  /// **A RUN OF PRESSES IS ONE UNDO ENTRY**, through
  /// `SetSymbolPinnedCommand`'s `mergeKey`. Five presses costing five
  /// `Ctrl+Z` would make this worse than not having it.
  void _nudgeSelection(AxisDirection direction) {
    final ids = _nudgeableSelection();
    if (ids.isEmpty) return;
    final (dx, dy) = switch (direction) {
      AxisDirection.left => (-1, 0),
      AxisDirection.right => (1, 0),
      AxisDirection.up => (0, -1),
      AxisDirection.down => (0, 1),
    };
    widget.controller.run(
      SetSymbolPinnedCommand.move(
        positions: {
          for (final id in ids)
            id: Pt(_heldPositions[id]!.gx + dx, _heldPositions[id]!.gy + dy),
        },
        now: widget.controller.clock.nowUtc(),
        actor: widget.controller.actor,
      ),
    );
    final what = ids.length == 1
        ? (_doc.devices[ids.single]?.designator ?? ids.single.v)
        : '${ids.length} symbols';
    _status.show('Nudged $what. Ctrl+Shift+U releases it to the layout.');
  }

  /// `Ctrl+Shift+U` (DR-187 §11.186.9): give the selection back to the
  /// layout.
  ///
  /// THE COUNTERPART TO A DRAG AND NOT A SECOND `Ctrl+L`. A drag pins, and
  /// `Tidy sheet` spares a pinned symbol by design (§11.186.3, CR-068), so
  /// without this the act of arranging a sheet by hand is what removes it
  /// from the reach of the one command that can lay it out again. `Ctrl+L`
  /// remains the toggle; this is the explicit release, which is the
  /// question somebody has after a drag rather than before one.
  void _unpinSelection() {
    final pinned = pinnedSymbolIds(_doc);
    final ids = [
      for (final id in _selection.ids)
        if (pinned.contains(id)) id,
    ];
    if (ids.isEmpty) {
      _status.show('Nothing pinned in the selection.');
      return;
    }
    widget.controller.run(
      SetSymbolPinnedCommand(
        // UNPINNING READS ONLY THE KEYS (`lock_commands.dart`), so the
        // positions handed over here are never stored. The symbol keeps
        // where it is until a Tidy moves it, which is that command's own
        // "does not jump when it is released".
        positions: {
          for (final id in ids) id: _heldPositions[id] ?? const Pt(0, 0),
        },
        pinned: false,
        now: widget.controller.clock.nowUtc(),
        actor: widget.controller.actor,
      ),
    );
    final what = ids.length == 1
        ? (_doc.devices[ids.single]?.designator ?? ids.single.v)
        : '${ids.length} symbols';
    _status.show('Unpinned $what. Tidy sheet can lay it out again.');
  }

  List<DBox> _pinnedBodies() {
    final pinned = pinnedSymbolIds(_doc);
    if (pinned.isEmpty) return const <DBox>[];
    return [
      for (final symbol in _scene?.symbols ?? const <RenderedSymbol>[])
        if (pinned.contains(Uuid(symbol.id))) symbol.bodyRect,
    ];
  }

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
  /// THE WIRE FIRST, THEN FOCUS, THEN THE SELECTION — outermost thing in
  /// flight first. docs/05 §7 gives `Esc` as the wire's cancel, and a user
  /// holding a half-drawn cable who pressed it and lost their FOCUS SCOPE
  /// instead would have to redo the more expensive of the two.
  ///
  /// Each rung is a separate keystroke and that is the point: also clearing
  /// the selection while cancelling a wire would take away the thing the
  /// wire was being drawn from, and the second `Esc` is free.
  void _onEscape() {
    // THE CHIP IS THE NEW TOP RUNG, ABOVE THE WIRE (`#278`, DR-114
    // §11.113.4). `schematicCancel`'s own registry note describes exactly
    // this shape — *"one more limb in the gate, which is exactly what
    // layering a key means when only isActionEnabled can decline one"* —
    // and it is why the chip binds no key of its own: a second Esc row in
    // one scope would be the collision `arbitrate()` exists to forbid.
    //
    // AND IT DOES NOT CANCEL THE WIRE UNDERNEATH. A gesture that
    // hesitated has not ended, so Esc here closes the chip and hands the
    // keyboard back to a cable that is still armed. The NEXT Esc cancels
    // it, which is what Esc has always meant on this canvas.
    if (_chip != null) {
      _dismissChip();
      _status.show(
        'Chip dismissed. The cable is still in hand — Tab to another '
        'jack, or Esc again to let it go.',
      );
      return;
    }
    if (_wireFrom != null) {
      _cancelWire();
      return;
    }
    // THE PIN RUN IS THE SECOND RUNG, ABOVE THE FOCUS SCOPE. Innermost
    // first, which is the rule this ladder already follows: a run of jacks
    // is what the user built most recently and most locally, and a `F`
    // scope is the more expensive of the two to rebuild — the same
    // argument that puts the wire above both.
    if (!_pins.isEmpty) {
      final count = _pins.length;
      setState(() => _pins = PinSelection.none);
      _status.show(
        count == 1 ? 'Jack deselected.' : '$count selected jacks deselected.',
      );
      return;
    }
    // THE CABLE SELECTION, BELOW THE PIN RUN AND ABOVE THE FOCUS SCOPE.
    // Same rule as the two rungs around it — most recent and cheapest to
    // rebuild goes first. A cable selection is one click to put back; a run
    // of sixteen jacks is sixteen, and an `F` scope is a navigation.
    if (_selectedLink != null) {
      final saying = _cableSaying(_selectedLink!);
      setState(() => _selectedLink = null);
      _status.show('$saying deselected.');
      return;
    }
    if (_focused.isNotEmpty) {
      setState(() => _focused = const <String>{});
      return;
    }
    if (_selection.isNotEmpty) _selection.clear();
  }

  // ── the connect gesture, by keyboard (docs/05 §7, DR-011) ─────────────
  //
  // BUILT AND DRIVEN FIRST, NOT LAST. DR-011's "the order that matters":
  // M1's equivalent clause was refuted by the user, who hit the time target
  // and still needed a mouse. The failure was not that the keyboard path
  // was missing — it was there — but that the caret was subordinate to the
  // selection, so it worked once and then quietly stopped. Everything below
  // is arranged so the caret is the thing that moves and the selection is
  // never consulted after it exists.
  //
  // WHAT IS NOT HERE, and belongs to the phase that has a pointer:
  // magnetic snap (docs/05 §7.6 is a POINTER figure — "within 12 screen px
  // the band locks"; a caret is already exactly on a pin), the 35% canvas
  // dim, compatible-port illumination, and auto-pan. A keyboard user's
  // equivalent of illumination is that `Tab` only ever reaches a candidate,
  // which is stronger: it cannot land on a pin that would refuse.

  /// Whether [ref] still names a pin this document has.
  ///
  /// `resolveConnectTarget` and not a scene lookup — see
  /// [_invalidateLivePreviews], which calls this while `_scene` is still
  /// the previous frame's.
  bool _pinStillExists(PinRef ref) =>
      resolveConnectTarget(
        _doc,
        deviceId: Uuid(ref.deviceId),
        portKey: ref.portKey,
      ) !=
      null;

  ConnectTarget? _targetFor(PinRef ref) => resolveConnectTarget(
    _doc,
    deviceId: Uuid(ref.deviceId),
    portKey: ref.portKey,
  );

  /// How a sentence names a pin — "AVR-1 J03 HDMI IN 2".
  ///
  /// `ConnectTarget.citation` is the designator pair CR-042 fixes, and the
  /// PortDef's own label is the silkscreen a person can find on the back of
  /// the box. Both, because a screen reader is the only view some users
  /// have of this sheet and "AVR-1 J03" alone does not say what kind of
  /// jack it is.
  String _saying(PinRef ref) {
    final target = _targetFor(ref);
    if (target == null) return '${ref.deviceId} ${ref.portKey}';
    final label = target.def.label.trim();
    return label.isEmpty ? target.citation : '${target.citation} $label';
  }

  /// The caret, seeded if it has none — the ONLY place the selection is
  /// consulted (see [_pinCaret]).
  ///
  /// The selection's focused device first, then any selected device, then
  /// the first pin on the sheet. A sheet with symbols always yields
  /// something, so an arrow key never does nothing on a drawn sheet.
  PinRef? _seedCaret(SchematicScene scene) {
    final existing = _pinCaret;
    if (existing != null) return existing;
    final pins = locatePins(scene);
    if (pins.isEmpty) return null;
    final preferred = <String>[
      if (_selection.focus case final id?) id.v,
      for (final id in _selection.ids) id.v,
    ];
    for (final deviceId in preferred) {
      for (final pin in pins) {
        if (pin.ref.deviceId == deviceId) return pin.ref;
      }
    }
    return pins.first.ref;
  }

  /// Moves the caret one pin in [direction] — docs/05 §7's "arrow to a
  /// candidate port".
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// NEAREST IN DIRECTION, NOT NEXT IN A LIST
  /// ═══════════════════════════════════════════════════════════════════
  /// The user is looking at a sheet, so an arrow has to mean the thing an
  /// arrow means on a sheet. A pin qualifies when it lies strictly on the
  /// pressed side of the caret along that axis, and the winner is the one
  /// whose distance — dominant axis first, then the perpendicular — is
  /// least. The perpendicular term is what stops a pin four symbols away
  /// but perfectly level from beating the pin immediately right of the
  /// caret, and it is weighted lower than the primary axis so "right" does
  /// not silently become "nearest in any direction".
  ///
  /// WHILE A WIRE IS ARMED THE POOL IS THE CANDIDATES, so an arrow cannot
  /// land on a pin that would be refused. That is the keyboard's form of
  /// docs/05 §7's "compatible ports illuminate": a sighted user is shown
  /// which pins are reachable, and a keyboard user simply cannot reach the
  /// others.
  void _movePinCaret(AxisDirection direction) {
    final scene = _scene;
    if (scene == null) return;
    // ═══════════════════════════════════════════════════════════════════
    // THE CARET WINS WHILE ONE EXISTS, AND THAT IS THE WHOLE
    // DISCRIMINATOR (DR-187 §11.186.10, `#919`)
    // ═══════════════════════════════════════════════════════════════════
    // §11.186.4 gave the arrows a second job and said the canvas can tell
    // the two modes apart. It can, but NOT by asking whether a connect is
    // in flight, which is what the clause first said: the arrows are also
    // how a pin is reached BEFORE anything is armed (docs/05 §7's "arrow
    // to a candidate port"), so "no wire in flight" is true for half of
    // the connect route itself.
    //
    // **A CARET ON SCREEN IS THE MODE.** Pins are what the person is
    // working with, so the arrows stay theirs; `Esc` clears the caret and
    // hands them back. With no caret and a symbol selected, they nudge.
    // With no caret and nothing selected they fall through to the seeding
    // below, because there is nothing to nudge and a key that does
    // nothing is the silent no-op docs/04 §3.4 forbids.
    //
    // **THE ROUTE TO A CARET IS STILL ONE KEY**: `W` seeds and arms in one
    // press and always did (see [_beginWire]), so nothing was taken away.
    if (_pinCaret == null && _nudgeableSelection().isNotEmpty) {
      _nudgeSelection(direction);
      return;
    }
    final seeded = _seedCaret(scene);
    if (seeded == null) {
      _status.show('This sheet draws no pin to put a caret on.');
      return;
    }
    if (seeded != _pinCaret) {
      // The seeding press itself lands the caret rather than also moving
      // it: the user has not seen where it is yet.
      setState(() => _pinCaret = seeded);
      _announceCaret();
      return;
    }

    final pool = _wireFrom == null
        ? locatePins(scene)
        : <LocatedPin>[
            for (final ref in _candidates)
              if (locatePin(scene, ref) case final pin?) pin,
          ];
    final from = locatePin(scene, seeded);
    if (from == null || pool.isEmpty) return;

    LocatedPin? best;
    var bestCost = double.infinity;
    for (final pin in pool) {
      if (pin.ref == seeded) continue;
      final dx = pin.centre.x - from.centre.x;
      final dy = pin.centre.y - from.centre.y;
      final (along, across) = switch (direction) {
        AxisDirection.left => (-dx, dy),
        AxisDirection.right => (dx, dy),
        AxisDirection.up => (-dy, dx),
        AxisDirection.down => (dy, dx),
      };
      if (along <= 0) continue; // not on the pressed side.
      final cost = along + across.abs() * _kCaretCrossAxisWeight;
      if (cost < bestCost) {
        bestCost = cost;
        best = pin;
      }
    }

    if (best == null) {
      // NEVER SILENT (docs/04 §3.4). The edge of the sheet in one
      // direction is a perfectly ordinary place to be, and a key that
      // did nothing without saying so is the defect that rule exists for.
      _status.show(
        _wireFrom == null
            ? 'No pin that way — ${_saying(seeded)} is the last one.'
            : 'No candidate pin that way from ${_saying(seeded)}.',
      );
      return;
    }
    setState(() => _pinCaret = best!.ref);
    _announceCaret();
  }

  /// Whether landing [grab] on [target] would duplicate a port pair the
  /// cable already carries — `TOP-002`, from the surface's side.
  ///
  /// THE SAME PREDICATE `buildBindEndpointCommand` APPLIES, and a second
  /// spelling of it is what DR-011.5's rule exists to prevent: a set that
  /// offered a pin the command then refused would be the defect that
  /// ruling is about. It is duplicated in SHAPE and not in DECISION,
  /// because the command's copy is the one that binds and this one only
  /// decides whether to draw a ring.
  bool _bindWouldDuplicate(RunEndGrab grab, ConnectTarget target) {
    final link = _doc.links[grab.linkId];
    if (link == null || link.conductors.isEmpty) return false;
    final conductor = link.conductors.first;
    final anchor = switch (grab.end) {
      LinkEnd.field => conductor.to,
      LinkEnd.rack => conductor.from,
    };
    if (anchor is! PortEndpoint) return false;
    for (final other in link.conductors) {
      if (identical(other, conductor)) continue;
      final ends = {
        other.from,
        other.to,
      }.whereType<PortEndpoint>().map((e) => e.portId).toSet();
      if (ends.contains(anchor.portId) && ends.contains(target.portId)) {
        return true;
      }
    }
    return false;
  }

  /// The `ConnectTarget` for [grab]'s anchor: the end this landing is NOT
  /// writing, which is the other half of the cable being completed.
  ///
  /// THE SAME READING `_armLandingFrom` TAKES, and deliberately not a
  /// second one. That method's own note says the anchor is what
  /// `_runEndAt` already settled and that re-deriving it off the
  /// conductor runs in opposite directions for the two ends; this asks
  /// the grab, as it does.
  ConnectTarget? _anchorTargetOf(RunEndGrab grab) {
    final port = _doc.ports[grab.anchorPortId];
    final key = port?.templatePortKey;
    if (port == null || key == null) return null;
    return _targetFor(PinRef(deviceId: port.deviceId.v, portKey: key.v));
  }

  /// Cycles the caret through [_candidates] — `Tab` / `Shift+Tab`.
  void _cycleCandidate({required int step}) {
    if (_wireFrom == null || _candidates.isEmpty) return;
    final at = _candidates.indexOf(_pinCaret ?? _candidates.first);
    final next =
        (at < 0 ? 0 : (at + step) % _candidates.length + _candidates.length) %
        _candidates.length;
    setState(() => _pinCaret = _candidates[next]);
    _announceCaret();
  }

  /// docs/05 §7.9's live resolution line, spoken.
  ///
  /// `MTX-1 J09 HDMI OUT 3 → AVR-1 J03 HDMI IN 2 · OK` is the corpus's own
  /// example; the length estimate it also shows needs a `Link` to measure
  /// and there is none yet, so it is left off rather than invented (G4).
  void _announceCaret() {
    final caret = _pinCaret;
    if (caret == null) return;
    final from = _wireFrom;
    if (from == null) {
      _status.show(_saying(caret));
      return;
    }
    _status.show(
      '${_saying(from)} → ${_saying(caret)} · OK · '
      'Enter to commit, Esc to cancel',
    );
  }

  // ── #93's pin selection (docs/05:484, DR-012.2) ───────────────────────

  /// The bank [ref] is in, or null when its `PortDef` declares none.
  ///
  /// ASKED OF THE DOCUMENT, NOT OF THE SCENE, for [_pinStillExists]'s
  /// reason: this runs from `_invalidateLivePreviews` where [_scene] is
  /// still the previous frame's. `SymbolPort` carries a `bankKey` too and
  /// it is the right source for a scene-only consumer — this screen simply
  /// is not one.
  String? _bankKeyOf(PinRef ref) => _targetFor(ref)?.def.bankKey;

  /// [bankKey]'s port keys in DR-012.2 rank order.
  ///
  /// `portsInBank` and never a sort written here — `multi_draw.dart`
  /// exports it precisely so the gesture and the commit cannot disagree
  /// about what "the next pin" means.
  List<String> _bankRank({required String deviceId, required String bankKey}) =>
      <String>[
        for (final t in portsInBank(
          _doc,
          deviceId: Uuid(deviceId),
          bankKey: bankKey,
        ))
          t.def.key.v,
      ];

  /// What a sentence calls the bank a selection is in.
  String _bankSaying(PinSelection sel) => bankLabelFor(
    _doc,
    deviceId: Uuid(sel.deviceId!),
    bankKey: sel.bankKey!,
  );

  /// Starts a run at [ref] — the anchor a later `Shift` extends from.
  ///
  /// Returns false when the pin is in no bank, which is the one pin a run
  /// cannot start on. Silent on that path: this is called from the press
  /// on EVERY pin, and a sentence about banks on every ordinary
  /// pin-to-pin press would be noise on the one gesture users perform
  /// sixty times an hour.
  bool _anchorPinSelection(PinRef ref) {
    // ═════════════════════════════════════════════════════════════════
    // A PRESS ON A PIN ALREADY IN THE RUN KEEPS THE RUN
    // ═════════════════════════════════════════════════════════════════
    // That press IS how a multi-draw drag begins — the pointer has to
    // grab the run somewhere — so re-anchoring here would destroy the
    // selection the gesture is about before the gesture could read it.
    // The whole of #93 arrived stillborn on this line: the run was built,
    // the press dropped it to one pin, `isMultiple` went false, and every
    // drag fell through to an ordinary pin-to-pin cable. Found by the
    // suite, not by reading — every unit test at both ends was green.
    //
    // It is also what every selection UI does: pressing a selected item
    // drags the selection, and only a press OUTSIDE it replaces.
    if (_pins.contains(ref)) return true;
    final bank = _bankKeyOf(ref);
    if (bank == null) {
      if (!_pins.isEmpty) setState(() => _pins = PinSelection.none);
      return false;
    }
    setState(() => _pins = PinSelection.at(ref, bankKey: bank));
    return true;
  }

  /// `Shift`+click — extend the run from its anchor to [ref].
  void _extendPinSelectionTo(PinRef ref) {
    final bank = _bankKeyOf(ref);
    if (bank == null) {
      _status.show(
        '${_saying(ref)} is in no bank, so there is no run to select along.',
      );
      return;
    }
    final rank = _bankRank(deviceId: ref.deviceId, bankKey: bank);
    setState(() {
      _pins = _pins.extendTo(ref, bankKey: bank, rank: rank);
      _pinCaret = ref;
    });
    _announcePinSelection();
  }

  /// `Shift`+↑/↓ — the keyboard half of [_extendPinSelectionTo].
  ///
  /// Seeds from the caret when there is no run yet, so the gesture is
  /// reachable without a prior click: arrows to a jack, `Shift`+↓ seven
  /// times, and the matrix's eight outputs are selected.
  void _extendPinSelection({required int by}) {
    final scene = _scene;
    if (scene == null) return;
    final caret = _seedCaret(scene);
    if (caret == null) {
      _status.show('This sheet draws no pin to select.');
      return;
    }
    var from = _pins;
    if (from.isEmpty || !from.contains(caret)) {
      final bank = _bankKeyOf(caret);
      if (bank == null) {
        _status.show(
          '${_saying(caret)} is in no bank, so there is no run to select '
          'along.',
        );
        return;
      }
      from = PinSelection.at(caret, bankKey: bank);
    }
    final rank = _bankRank(deviceId: from.deviceId!, bankKey: from.bankKey!);
    final next = from.step(by: by, rank: rank);
    // NOT A SILENT NO-OP (docs/04 §3.4). `step` refuses to wrap, so the
    // ends of a bank are reachable states a user will sit in, and a key
    // that did nothing and said nothing there is the failure that rule
    // names.
    if (identical(next, from) && !from.isEmpty) {
      setState(() {
        _pins = from;
        _pinCaret = PinRef(deviceId: from.deviceId!, portKey: from.head!);
      });
      _status.show(
        'That is the ${by > 0 ? 'last' : 'first'} jack in '
        '${_bankSaying(from)}.',
      );
      return;
    }
    setState(() {
      _pins = next;
      _pinCaret = PinRef(deviceId: next.deviceId!, portKey: next.head!);
    });
    _announcePinSelection();
  }

  /// Says what the run is, and what can be done with it.
  ///
  /// THE ONE-PIN SENTENCE TEACHES THE GESTURE, which is the only place
  /// multi-draw is discoverable at all: it has no button, no menu item and
  /// no coach mark. AC-048's mark was spent on the domain filter (DR-012.4)
  /// and adding a second one to the same sheet would make the first a nag.
  void _announcePinSelection() {
    final sel = _pins;
    if (sel.isEmpty) return;
    if (!sel.isMultiple) {
      _status.show(
        '${_saying(sel.refs.first)} — Shift+click or Shift+↑↓ to select a '
        'run of ${_bankSaying(sel)}.',
      );
      return;
    }
    _status.show(
      '${sel.length} jacks selected in ${_bankSaying(sel)} — drag them onto '
      'another bank to draw ${sel.length} cables at once.',
    );
  }

  // ── #93's multi-draw gesture (docs/05:484, DR-012.2) ──────────────────

  /// Arms a MULTI-DRAW from the run in [_pins] — N cables, one undo entry.
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// EVERY TARGET BANK IS PLANNED HERE, NOT ON THE DROP
  /// ═════════════════════════════════════════════════════════════════
  /// The pointer needs to know which pins it may land on BEFORE it moves
  /// — that is what [_candidates] is for on every other gesture — and for
  /// multi-draw "may land on" is a question about a BANK, not a pin. So
  /// each bank the sheet draws is planned once, and a pin is a candidate
  /// exactly when its bank's plan would make at least one cable. The
  /// plans are then reused for the live preview and for the commit, so
  /// what the user is SHOWN and what is WRITTEN come from one object
  /// rather than from two runs of the same function.
  ///
  /// NO DR-012.3 FAMILY PREFERENCE, for the reason `_armSetFrom` gives
  /// for the set gesture: the magnet orders PINS by the family the cable
  /// carries, and a run of N pins is not one cable with one family.
  bool _armMultiDrawFrom(PinRef caret, {bool announce = true}) {
    final scene = _scene;
    final sel = _pins;
    if (scene == null || !sel.isMultiple) return false;

    final plans = <(String, String), MultiDrawPlan>{};
    final candidates = <PinRef>[];
    for (final pin in locatePins(scene)) {
      final bank = _bankKeyOf(pin.ref);
      if (bank == null) continue;
      // THE SOURCE BANK IS NOT A TARGET. `planMultiDraw` would happily
      // pair a run against its own bank's free jacks — every TOP rule it
      // consults is about a PAIR of pins, and none of them says "not the
      // bank you came from". Excluded here rather than there because it
      // is a fact about this gesture, not about the plan.
      if (pin.ref.deviceId == sel.deviceId && bank == sel.bankKey) continue;
      final key = (pin.ref.deviceId, bank);
      final plan = plans.putIfAbsent(
        key,
        () => planMultiDraw(
          _doc,
          fromDeviceId: Uuid(sel.deviceId!),
          fromBankKey: sel.bankKey!,
          sources: sel.portKeys,
          toDeviceId: Uuid(pin.ref.deviceId),
          toBankKey: bank,
        ),
      );
      if (!plan.isEmpty) candidates.add(pin.ref);
    }

    if (candidates.isEmpty) {
      if (announce) {
        _status.show(
          'No bank on this sheet can take ${sel.length} cables from '
          '${_bankSaying(sel)}.',
        );
      }
      return false;
    }

    setState(() {
      _wireFrom = caret;
      _wireFromBankKey = sel.bankKey;
      // NO TIER-2 VERDICT ON A MULTI-DRAW, AND IT IS A GAP RATHER THAN A
      // RULING. A bank run aims at a BANK, and `planMultiDraw` decides
      // which source lands on which member only once a target bank is
      // chosen — so at arm time there is no pin PAIR to ask
      // `evaluateSpringBack` about, and an amber ring would have to mean
      // "one of the N cables this bank would make might object", which is
      // not a thing a ring on one pin can say. The commit path checks it
      // per pair, where the pairing exists.
      _setTargets(candidates: candidates);
      _multiPlans = Map<(String, String), MultiDrawPlan>.unmodifiable(plans);
    });
    if (announce) {
      // ONE SENTENCE, COMPOSED — never two `show` calls. Every `show`
      // is a `SemanticsService.announce`, so a second one here would put
      // two messages on the accessibility channel for one keystroke,
      // which is the defect `_committingWire` exists to prevent arriving
      // through another door (see `_armWireFrom`'s note on the chain).
      //
      // The set clause is the disclosure the branch order owes: see
      // `_armWireFrom`, where multi-draw is ruled to beat DR-011.2's
      // atomic set because an explicit selection outranks a property of
      // the jack — on condition that the cost is said out loud.
      final sets = <PinRef>[
        for (final ref in sel.refs)
          if (_atomicSetFor(ref) != null) ref,
      ];
      final note = sets.isEmpty
          ? ''
          : ' Note: ${sets.length} of these jacks are declared as cable '
                'SETS, and multi-draw makes one separate cable per jack.';
      _status.show(
        '${sel.length} cables from ${_bankSaying(sel)} — drop on a target '
        'bank. Enter or release to commit, Esc to cancel.$note',
      );
    }
    return true;
  }

  /// The plan for the bank [ref] is in, or null when it is in none or its
  /// bank was not planned.
  MultiDrawPlan? _planFor(PinRef ref) {
    final bank = _bankKeyOf(ref);
    if (bank == null) return null;
    return _multiPlans[(ref.deviceId, bank)];
  }

  /// docs/05:484's "all N bands", as pin pairs the overlay can trace.
  ///
  /// Empty whenever the caret is not over a planned bank, which INCLUDES
  /// an unsnapped pointer drag over empty paper. Sixteen bands converging
  /// on a cursor would be sixteen cables to a place no jack is; the
  /// selection rings already say what is in hand.
  List<(PinRef, PinRef)> _multiDrawBands() {
    if (_wireFromBankKey == null) return const <(PinRef, PinRef)>[];
    final caret = _pinCaret;
    if (caret == null) return const <(PinRef, PinRef)>[];
    final plan = _planFor(caret);
    if (plan == null) return const <(PinRef, PinRef)>[];
    return <(PinRef, PinRef)>[
      for (final pair in plan.pairs)
        (
          PinRef(
            deviceId: pair.from.deviceId.v,
            portKey: pair.from.def.key.v,
          ),
          PinRef(deviceId: pair.to.deviceId.v, portKey: pair.to.def.key.v),
        ),
    ];
  }

  /// Commits the armed multi-draw onto [to]'s bank — N `Link`s, ONE undo
  /// entry (docs/05:484).
  void _commitMultiDraw(PinRef to) {
    final plan = _planFor(to);
    if (plan == null || plan.isEmpty) {
      _clearWire();
      _status.show('That bank can take none of these cables.');
      return;
    }
    final commands = buildMultiDrawCommands(
      doc: _doc,
      plan: plan,
      media: kUnstatedMedia,
      now: widget.controller.clock.nowUtc(),
      actor: widget.controller.actor,
    );
    if (commands.isEmpty) {
      _clearWire();
      _status.show('That bank can take none of these cables.');
      return;
    }

    // ONE `transact`, WHICH IS HOW "ONE UNDO ENTRY" HAPPENS.
    // `buildMultiDrawCommands` returns a LIST and not a `Transaction`
    // deliberately — core does not know what is selected, and a
    // `Transaction` carries the selection before and after. This is the
    // seam its doc comment names.
    _committingWire = true;
    try {
      widget.controller.transact(LabelKey.multiDraw, (tx) {
        for (final command in commands) {
          tx.add(command);
        }
      });
    } finally {
      _committingWire = false;
    }

    final targetBank = bankLabelFor(
      _doc,
      deviceId: Uuid(to.deviceId),
      bankKey: _bankKeyOf(to)!,
    );
    final designators = <String>[
      for (final c in commands)
        if (c is ConnectPortsCommand) c.designator,
    ];
    final named = designators.isEmpty
        ? ''
        : designators.length == 1
        ? '${designators.first} '
        : '${designators.first}–${designators.last} ';
    // THE RUN IS SPENT. Those jacks now carry cables, and leaving them
    // selected would invite the same gesture again onto a bank that has
    // just filled — a second undo entry the user did not mean to make.
    setState(() {
      _pinCaret = to;
      _wireFrom = null;
      _wireFromBankKey = null;
      _clearTargets();
      _multiPlans = const <(String, String), MultiDrawPlan>{};
      _pins = PinSelection.none;
    });
    // THE UNPAIRED ARE SAID OUT LOUD, and they were WRITTEN NOWHERE —
    // `multi_draw.dart`'s header rules that a multi-draw surplus mints
    // nothing, because an unpaired source would be a whole `Link` with
    // its own `W` number pulled to nowhere. So this sentence is the only
    // record the user gets, exactly as §11.8.3's open-end warning is.
    final left = plan.unpaired.isEmpty
        ? ''
        : ' — ${plan.unpaired.length} '
              '${plan.unpaired.length == 1 ? 'jack' : 'jacks'} found no '
              'free partner and ${plan.unpaired.length == 1 ? 'was' : 'were'} '
              'left unwired';
    _status.show(
      '$named connected ${plan.linkCount} '
      '${plan.linkCount == 1 ? 'cable' : 'cables'} to $targetBank$left.',
    );
  }

  /// The ATOMIC set [ref] belongs to, or null when it belongs to none or
  /// to one that has opted out.
  ///
  /// Null is the overwhelmingly normal answer: DR-011.2's arithmetic is
  /// that 223 of the catalog's 257 ports carry no `setKey` at all, which
  /// is why the gesture is pin-to-pin and this is the special case.
  ResolvedPortSet? _atomicSetFor(PinRef ref) {
    final target = _targetFor(ref);
    final key = target?.setKey;
    if (target == null || key == null) return null;
    final set = resolvePortSet(_doc, target.deviceId, key);
    if (set == null || !set.def.atomicConnect) return null;
    return set;
  }

  /// Arms a SET gesture from [caret]'s set — one cable, N conductors.
  ///
  /// Candidates are every pin belonging to a set that `planAtomicConnect`
  /// says this one may join. A pin PER MEMBER rather than one per set, so
  /// dropping on any member of the target pair works — which is what a
  /// user aiming at a stereo pair will do.
  bool _armSetFrom(PinRef caret, ResolvedPortSet from, {bool announce = true}) {
    final scene = _scene;
    if (scene == null) return false;

    final candidates = <PinRef>[];
    for (final pin in locatePins(scene)) {
      final to = _atomicSetFor(pin.ref);
      if (to == null) continue;
      if (to.deviceId == from.deviceId && to.def.key == from.def.key) continue;
      final planned = planAtomicConnect(
        _doc,
        fromDeviceId: from.deviceId,
        fromSetKey: from.def.key,
        toDeviceId: to.deviceId,
        toSetKey: to.def.key,
      );
      if (planned is AtomicConnectReady) candidates.add(pin.ref);
    }

    if (candidates.isEmpty) {
      if (announce) {
        _status.show(
          'No set on this sheet can take the ${from.def.label} from '
          '${_saying(caret)}.',
        );
      }
      return false;
    }

    setState(() {
      _wireFrom = caret;
      _wireFromSetKey = from.def.key;
      // NO FAMILY PREFERENCE ON A SET GESTURE. DR-012.3's magnet orders
      // PINS by the family the cable carries; a set connects as a whole
      // and its members' families are the set's, so there is no second
      // group to prefer. Left empty rather than filled with everything,
      // which would read as a preference that happens to be universal.
      //
      // NO TIER-2 VERDICT EITHER, for the multi-draw's reason in a
      // smaller frame: a set connects N members at once and
      // `evaluateSpringBack` answers about ONE pair, so a ring on the
      // set's anchor pin would be a verdict about whichever member the
      // ring happened to be drawn on. Checked per member at commit.
      _setTargets(candidates: candidates);
    });
    if (announce) {
      _status.show(
        '${from.def.label} from ${_saying(caret)} — one cable, '
        '${from.members.length} conductors. '
        '${candidates.length} target '
        '${candidates.length == 1 ? 'pin' : 'pins'}. '
        'Enter or release to commit, Esc to cancel.',
      );
    }
    return true;
  }

  /// Commits the armed SET gesture — AC-053's "one gesture producing one
  /// `Link` with N `Conductor`s".
  void _commitSet(PinRef from, PinRef to, String fromSetKey) {
    final fromTarget = _targetFor(from);
    final toSet = _atomicSetFor(to);
    if (fromTarget == null || toSet == null) {
      _cancelWire();
      return;
    }
    final result = planAtomicConnect(
      _doc,
      fromDeviceId: fromTarget.deviceId,
      fromSetKey: fromSetKey,
      toDeviceId: toSet.deviceId,
      toSetKey: toSet.def.key,
    );

    switch (result) {
      case null:
        _clearWire();
        _status.show('That set is no longer in this document.');
      case AtomicConnectRefused(:final ruleId, :final message):
        // DR-011.5, identically to the pin path: T1 refuses outright and
        // nothing is written.
        _clearWire();
        _status.show('$ruleId — $message');
      case AtomicConnectNotAtomic(:final setKey):
        // NOT A REFUSAL, and it must not read like one — no rule was
        // broken. The template author said this grouping is not one
        // cable, so the answer is what the user should do instead.
        _clearWire();
        _status.show(
          'The "$setKey" group wires one pin at a time — put the caret on '
          'a pin and press W.',
        );
      case AtomicConnectReady(:final plan):
        final command = buildAtomicConnectCommand(
          doc: _doc,
          plan: plan,
          // DR-011.3: the SET'S OWN family, from the pin the user grabbed.
          signalFamily: fromTarget.signalFamily,
          media: kUnstatedMedia,
          now: widget.controller.clock.nowUtc(),
          actor: widget.controller.actor,
        );
        _committingWire = true;
        try {
          widget.controller.run(command);
        } finally {
          _committingWire = false;
        }
        setState(() {
          _pinCaret = to;
          _wireFrom = null;
          _wireFromSetKey = null;
          _clearTargets();
        });
        // OPEN ENDS ARE SAID OUT LOUD. §11.8.3 chose "connect what fits
        // and warn" against a recommendation to refuse, and recorded the
        // cost: validation does not exist until M5, so a half-connected
        // run LOOKS COMPLETE on the schedule. This sentence is the warn.
        final open = plan.openCount == 0
            ? ''
            : ' — ${plan.openCount} of its '
                  '${plan.conductors.length} conductors has no partner and '
                  'ends open';
        final roles = plan.roleMismatches.isEmpty
            ? ''
            : ' — and ${plan.roleMismatches.length} pair declares opposite '
                  'roles, so check polarity';
        _status.show(
          '${command.designator} connected ${toSet.def.label}: one cable, '
          '${plan.pairedCount} paired '
          '${plan.pairedCount == 1 ? 'conductor' : 'conductors'}'
          '$open$roles.',
        );
    }
  }

  /// `W` — arm a wire from the pin under the caret (docs/05 §14).
  void _beginWire() {
    final scene = _scene;
    if (scene == null) return;
    final caret = _seedCaret(scene);
    if (caret == null) {
      _status.show('This sheet draws no pin to start a cable from.');
      return;
    }
    setState(() => _pinCaret = caret);
    _armWireFrom(caret);
  }

  /// Arms a wire from [caret], or says why it cannot. THE ONE ARMING PATH
  /// — `W` and a pointer press both land here, so the two drivers cannot
  /// disagree about what a legal start is or about what the user is told
  /// when there is none.
  ///
  /// Returns whether a wire is now in flight.
  bool _armWireFrom(PinRef caret, {bool announce = true}) {
    final scene = _scene;
    if (scene == null) return false;
    final from = _targetFor(caret);
    if (from == null) {
      if (announce) _status.show('That pin is no longer in this document.');
      return false;
    }

    // ═════════════════════════════════════════════════════════════════
    // THREE GESTURES, ONE ARMING PATH, AND THE ORDER IS A RULING
    // ═════════════════════════════════════════════════════════════════
    // MULTI-DRAW FIRST, and it beats the atomic set. DR-011.2 decides
    // between set and pin-to-pin BY THE JACK — a property of the
    // hardware, which the user did not choose. A run of N selected jacks
    // is the opposite: an explicit act, performed with a modifier, on
    // pins the user picked one at a time. An explicit choice outranks an
    // implicit one.
    //
    // WHAT THAT COSTS, STATED RATHER THAN HIDDEN. A run made of
    // `atomicConnect` pins — A01's `srcIn` is sixteen such, eight stereo
    // pairs — will be drawn as N SEPARATE `Link`s where the template
    // author declared each pair to be one cable. That is a different bill
    // of materials, which is the exact distinction DR-012.2 exists to
    // keep. It is allowed, because the alternative is a press that
    // refuses a gesture the user explicitly asked for and leaves them no
    // way to perform it; and it is ANNOUNCED, because a silent choice
    // between two bills of materials is the harm the ruling names. Undo
    // is one keystroke.
    //
    // THIS PAIRING IS NOT IN THE CORPUS. docs/05:484 says nothing about a
    // run of set pins, and the sentence below is a consequence of two
    // existing rulings rather than a third. If it ever needs arguing
    // with, it wants a DR of its own.
    //
    // A run that can reach no bank FALLS THROUGH to the ordinary gestures
    // rather than dead-ending: the caret is still on a pin, and a
    // pin-to-pin cable from it is very likely what the user wants next.
    // `_armMultiDrawFrom` has already said why the run could not go.
    if (_pins.isMultiple &&
        _pins.contains(caret) &&
        _armMultiDrawFrom(caret, announce: announce)) {
      return true;
    }

    // THE BRANCH DR-011.2 RULES, and it is decided by the jack rather than
    // by a mode: a pin in a set flagged `atomicConnect: true` arms the
    // whole set. Everything else — 223 of the catalog's 257 ports — is
    // pin-to-pin.
    //
    // ═════════════════════════════════════════════════════════════════
    // UNLESS THE PIN IS ALREADY SPOKEN FOR. DR-014.
    // ═════════════════════════════════════════════════════════════════
    // A set that is already ONE CABLE cannot be connected as a set again —
    // every member is full, so `planAtomicConnect` meets `TOP-003` at the
    // grabbed position for every candidate and `_armSetFrom` finds nothing
    // to aim at. That is what the field report was: *"the Right analog
    // audio channels can't have connections made once the left channel is
    // made."* The document was right and the gesture had no way to say
    // "this half goes somewhere else now".
    //
    // So a FULL member falls through to pin-to-pin, where DR-014's split
    // lives. Nothing is lost by falling through: the set gesture had no
    // legal outcome from this pin, and `isPortFull` is exactly the
    // predicate `planSetSplit`'s first condition uses — asked through core
    // rather than counted here, because a surface that compared conductor
    // counts to `maxConnections` itself would report every bus tap in the
    // catalog as full (`effectiveMaxConnections`).
    //
    // AN UNWIRED MEMBER STILL ARMS THE SET, which is DR-011.2 untouched
    // and is the overwhelmingly normal case. A set is one cable the first
    // time and splittable afterwards.
    final set = _atomicSetFor(caret);
    if (set != null && !isPortFull(_doc, from)) {
      return _armSetFrom(caret, set, announce: announce);
    }

    // EVERY OTHER PIN ON THE SHEET, RUN THROUGH THE REAL RULES, AND NOW
    // THROUGH BOTH TIERS. `evaluateConnect` is TOP-001..005 and decides
    // whether a pin is a CANDIDATE at all; `evaluateSpringBack` is the
    // six T2 rules and decides what colour its ring is. A pin that is
    // merely a BAD idea — an HDMI output into an RJ45 jack — is still a
    // candidate, because G2 and CR-017 rule that a model which cannot
    // draw a mistake cannot document reality. It now wears amber while
    // being one, which is the whole of docs/05:476: *"they remain
    // droppable, the chip and `[ Connect anyway ]` are what handles
    // them."*
    //
    // AND THE SAME WALK COMPUTES DR-012.3's PREFERRED SET, because the
    // question — does this pin carry the source's family? — needs
    // `ConnectTarget.acceptsFamily`, which reads `PortDef.acceptedFamilies`
    // and therefore needs the DOCUMENT. `SymbolPort` carries only the
    // declared `family`, so the magnet could not answer it from the scene.
    // Computed once here for the same reason the candidates are: it is
    // O(pins x links) and the document cannot move while the wire is armed.
    //
    // AND THE SPLIT IS ASKED PER CANDIDATE, NOT ONCE — DR-014's fourth
    // condition is "a DIFFERENT device", so whether this pin can be freed
    // depends on which pin is being aimed at. One answer computed for the
    // caret and reused would either offer a pin the commit then refuses,
    // or hide one it would have taken. Same complexity class as the walk
    // already had (O(pins x links)), and `planSplitsFor` allocates
    // nothing — which is why the commit builder is not called here.
    final candidates = <PinRef>[];
    final preferred = <PinRef>{};
    final springBack = <PinRef>{};
    for (final pin in locatePins(scene)) {
      if (pin.ref == caret) continue;
      final to = _targetFor(pin.ref);
      if (to == null) continue;
      final freeing = <ConductorRef>{
        for (final split in planSplitsFor(_doc, from, to)) split.conductor,
      };
      if (evaluateConnect(_doc, from, to, freeing: freeing) is ConnectAllowed) {
        candidates.add(pin.ref);
        if (to.acceptsFamily(from.signalFamily)) preferred.add(pin.ref);
        // TIER 2 IS ASKED ONLY OF PINS TIER 1 ALLOWED, which is the tier
        // order made structural: a pin the model refuses outright has no
        // business also carrying a trade opinion, and DR-112 §11.111
        // rules that the two tiers answer different questions rather
        // than one being a stronger version of the other.
        //
        // `ontoLink: null`, AND IT IS NOT A SHORTCUT. That parameter is
        // how a declared `InlineAdapter` clears `CON-001` and `SIG-002`
        // and how a `passiveSplit` net clears `DIR-001` — all three read
        // an EXISTING link. This gesture always mints a new one
        // (`buildSplitConnectCommands` returns a plain connect, or a
        // split that still creates its own Link), so there is no link
        // yet to carry an adapter and null is the true answer rather
        // than a missing one.
        if (evaluateSpringBack(_doc, from, to) is SpringBackChip) {
          springBack.add(pin.ref);
        }
      }
    }

    if (candidates.isEmpty) {
      // ARMING WITH NOTHING TO AIM AT IS A MODE WITH NO EXIT BUT `Esc`.
      // Refused, with the reason, rather than entered — and the sentence
      // names the pin, per DR-011.5's rule for refusals.
      if (announce) {
        _status.show(
          'No pin on this sheet can take a cable from ${_saying(caret)}.',
        );
      }
      return false;
    }

    setState(() {
      _wireFrom = caret;
      _setTargets(
        candidates: candidates,
        preferred: preferred,
        springBack: springBack,
      );
    });
    // SILENT WHEN A CHAIN RE-ARMS IT. The chain composes ONE sentence
    // covering the commit and the re-arm; announcing here as well would
    // put two messages on the accessibility channel for one keystroke —
    // the same defect [_committingWire] exists to stop, arriving through
    // the other door.
    if (announce) {
      _status.show(
        'Wire from ${_saying(caret)} — ${candidates.length} '
        '${candidates.length == 1 ? 'pin' : 'pins'} can take it. '
        'Drag or Tab to choose, release or Enter to commit, Esc to cancel.',
      );
    }
    return true;
  }

  // ── the connect gesture, by pointer (docs/05 §7's WIRE_DRAG) ──────────
  //
  // THE SAME STATE, A SECOND DRIVER. `_wireFrom`, `_pinCaret` and
  // `_candidates` are exactly the fields the keyboard route sets; the
  // pointer sets them from a press, a move and a release instead of from
  // `W`, arrows and `Enter`. That is the whole reason the keyboard was
  // built first: it forced the state to be a model of the GESTURE rather
  // than a model of the mouse, so this phase adds a driver and not a
  // parallel implementation.
  //
  // WHAT DOCS/05 §7 ASKS FOR THAT THIS DOES NOT BUILD, each with its
  // reason, because a list of unbuilt items is worth more than silence:
  //
  //  * THE 35% CANVAS DIM (§7.1). It is a recolouring of every symbol op,
  //    and this file's own header already rules on that class: "all three
  //    are recolourings of SYMBOL ops, and a recolour is a rebuild of the
  //    very fragments M2-D publishes so they can be replayed untouched.
  //    They want a palette-level mechanism, not a per-frame op rewrite on
  //    the path §11.2 bans `saveLayer` from." The dim is the fourth member
  //    of that family and takes the same answer.
  //  * THE 900 ms BREATHING PULSE on the compatible ring (§7.2). The ring
  //    itself is drawn and so is §7.3's amber one, but neither breathes,
  //    which leaves "amber, no pulse" and "yellow, pulsing" differing by
  //    the one channel that exists. A pulse wants a ticker driving a
  //    per-frame recolour on a canvas whose whole discipline is that a
  //    frame is a replay of published fragments, so it is the same
  //    family as the dim above it and takes the same answer.
  //  * TYPE-WEIGHTED SNAP (§7.6). DR-011.8, unruled — see [snapToPin].
  //  * AUTO-PAN (§7.7) and COLLAPSED-BANK EXPANSION (§7.8). No bank
  //    collapse exists to expand, and auto-pan is a comfort on a gesture
  //    that can already be driven entirely from the keyboard.

  /// The pin under [scenePoint] within the live snap radius, or null.
  ///
  /// Used for the PRESS — "did this drag start on a pin?" — where the pool
  /// is every pin on the sheet, unlike the magnet during the drag, whose
  /// pool is the candidates.
  PinRef? _pinAt(DPt scenePoint) {
    final scene = _scene;
    if (scene == null) return null;
    return snapToPin(
      scene,
      scenePoint,
      tolerance: _portHitTolerancePx / _viewport.scale,
      among: [for (final pin in locatePins(scene)) pin.ref],
    )?.ref;
  }

  /// A press landed on a net-label pennant: is there a run END to write
  /// here, which one, and does writing it LAND the run or MOVE it
  /// (`#719` / DR-073, `#725` / DR-074)?
  ///
  /// Null unless every one of these holds, and each exclusion hands the
  /// press back to the ordinary click that selects the cable:
  ///
  ///  * it is a HOME RUN. `buildBindEndpointCommand` and
  ///    `buildMoveEndpointCommand` both refuse anything with no
  ///    `StructureOrigin`, so a patch cable's pennant must not arm a
  ///    gesture whose every commit is refused, which is `#711`'s defect
  ///    drawn on purpose.
  ///  * AT LEAST ONE end is on a pin. A run landed nowhere draws no
  ///    pennant, so that case is unreachable here and the guard is a
  ///    statement rather than a filter.
  ///
  /// ═════════════════════════════════════════════════════════════════════
  /// THE TWO CASES READ THE PENNANT IN OPPOSITE DIRECTIONS
  /// ═════════════════════════════════════════════════════════════════════
  /// A HALF-LANDED run draws ONE pennant, at the end that has a pin, and
  /// pressing it means "finish the OTHER end" — there is nothing else it
  /// could mean, and DR-068 §11.67.1's speaker run is why the loose end
  /// may be either (a run drawn at its amplifier waits for a field end;
  /// one drawn at its wall plate waits for a rack end).
  ///
  /// A FULLY LANDED run draws TWO, and pressing one means "move THIS
  /// end". That is the opposite reading, and it is why this asks
  /// [netLabelAtPoint] rather than `linkAtPoint`: both pennants carry the
  /// same link id, and an answer that cannot tell them apart would move
  /// whichever end the code happened to name first — silently, on a
  /// cable somebody else has to find in a rack.
  ///
  /// EITHER WAY THE ANCHOR IS THE END NOT BEING WRITTEN, which is one
  /// rule rather than two: the preview band then spans the pins the
  /// document will hold one event later (DR-073 §11.72.2).
  RunEndGrab? _runEndAt(DPt scenePoint) {
    final scene = _scene;
    if (scene == null) return null;
    final label = netLabelAtPoint(
      scene,
      scenePoint,
      tolerance: _portHitTolerancePx / _viewport.scale,
    );
    if (label == null) return null;
    final link = _doc.links[label.linkId];
    if (link == null || link.structureOrigin == null) return null;
    if (link.conductors.isEmpty) return null;
    final conductor = link.conductors.first;
    final from = conductor.from;
    final to = conductor.to;
    final fromLanded = from is PortEndpoint;
    final toLanded = to is PortEndpoint;
    if (!fromLanded && !toLanded) return null;

    if (fromLanded != toLanded) {
      // Promoted by the `is` tests above; `to` still needs its cast
      // because only one of the two is promoted on this branch.
      final anchor = fromLanded ? from : (to as PortEndpoint);
      return RunEndGrab(
        linkId: label.linkId,
        end: fromLanded ? LinkEnd.rack : LinkEnd.field,
        anchorPortId: anchor.portId,
        moving: false,
      );
    }

    // WHICH PENNANT IS THIS. Resolved through the same `ConnectTarget`
    // walk every other pin question uses, so a pennant and a pin agree
    // about what port they are on.
    final pinned = _targetFor(
      PinRef(deviceId: label.deviceId, portKey: label.portKey),
    );
    if (pinned == null) return null;
    final portId = pinned.portId;
    if (portId == (from as PortEndpoint).portId) {
      return RunEndGrab(
        linkId: label.linkId,
        end: LinkEnd.field,
        anchorPortId: (to as PortEndpoint).portId,
        moving: true,
      );
    }
    if (portId == (to as PortEndpoint).portId) {
      return RunEndGrab(
        linkId: label.linkId,
        end: LinkEnd.rack,
        anchorPortId: from.portId,
        moving: true,
      );
    }
    return null;
  }

  /// A press landed on a pennant with a loose end: arm the landing.
  ///
  /// THE SOURCE IS THE PIN THE RUN IS ALREADY ON, so the preview band is
  /// the cable this gesture is about to complete. See [_landingFrom].
  ///
  /// THE CANDIDATES ARE THE FREE PINS, and that is a DIFFERENT question
  /// from `evaluateConnect`'s. A bind's only occupancy rule is
  /// `TOP-003` — one cable per punchdown position — asked through
  /// `portConductorCount` rather than answered again here, because
  /// `buildBindEndpointCommand` asks it the same way and two copies would
  /// let the ring say yes where the commit says no.
  bool _armLandingFrom(RunEndGrab grab) {
    final scene = _scene;
    if (scene == null) return false;
    final link = _doc.links[grab.linkId];
    if (link == null) return false;
    // THE ANCHOR THE GRAB NAMED, which is the end this gesture is NOT
    // writing. Reading it off the conductor again here would be a second
    // answer to a question `_runEndAt` already settled, and the two
    // readings run in opposite directions for the two cases.
    final port = _doc.ports[grab.anchorPortId];
    final key = port?.templatePortKey;
    if (port == null || key == null) return false;
    final source = PinRef(deviceId: port.deviceId.v, portKey: key.v);

    // ═════════════════════════════════════════════════════════════════
    // THE CANDIDATE SET NARROWS WITH THE COMMAND (DR-116 §11.115.5)
    // ═════════════════════════════════════════════════════════════════
    // This used to be occupancy alone. DR-116 rules that a bind consults
    // both tiers, and DR-011.5's surviving tier-1 half is what forces the
    // surface to keep up: *"a pin the gesture OFFERS is never then
    // refused"* by tier 1. So a pin `buildBindEndpointCommand` would now
    // refuse is not offered.
    //
    // `TOP-001` IS THE `pin.ref != source` LINE and always was, which is
    // the one piece of tier 1 this set already had by accident: the
    // anchor pin is excluded, so a conductor cannot be landed on itself.
    // It is named now rather than left as a bare inequality.
    //
    // TIER-2 PINS STAY OFFERED and wear the amber ring, which is
    // docs/05:476's *"they remain droppable"* reaching the second
    // gesture. That set is computed in the same walk for [_springBack]'s
    // stated reason: one pass decides and records together.
    final anchorTarget = _anchorTargetOf(grab);
    final free = <PinRef>[];
    final springBack = <PinRef>{};
    for (final pin in locatePins(scene)) {
      if (pin.ref == source) continue; // TOP-001
      final t = _targetFor(pin.ref);
      if (t == null) continue;
      if (portConductorCount(_doc, t.portId) != 0) continue; // TOP-003
      if (_bindWouldDuplicate(grab, t)) continue; // TOP-002
      free.add(pin.ref);
      if (anchorTarget != null &&
          evaluateSpringBack(
                _doc,
                anchorTarget,
                t,
                // The one gesture where this parameter earns its keep: a
                // bind completes an EXISTING cable, so an adapter already
                // declared on it clears `CON-001` and `SIG-002`.
                ontoLink: grab.linkId,
              )
              is SpringBackChip) {
        springBack.add(pin.ref);
      }
    }
    if (free.isEmpty) {
      // THE PIN THIS RUN IS LEAVING IS NOT FREE, because this cable is
      // still in it: `portConductorCount` counts it, exactly as
      // `buildMoveEndpointCommand` does. So a move offers the same set a
      // landing does, minus the hole it is moving out of, and a sheet
      // with nowhere to go says so before the drag starts.
      _status.show(
        grab.moving
            ? 'Every other jack on this sheet already has a cable, so '
                  '${link.designator} has nowhere to move.'
            : 'Every jack on this sheet already has a cable, so '
                  '${link.designator} has nowhere to land.',
      );
      return false;
    }

    setState(() {
      _wireFrom = source;
      _landingFrom = grab;
      // NO PREFERRED SET. DR-012.3's magnet ranks candidates by whether
      // they accept the SOURCE's family, which is a question about a
      // cable being created. This one exists already and its family is
      // whatever it was pulled as.
      //
      // THE AMBER RING IS HERE NOW, which `#811` and DR-116 §11.115.3
      // settled. The comment this replaces said a bind's rules were its
      // own and that painting a tier-2 verdict over a set that never saw
      // tier 1 would mix two vocabularies on one ring. Both halves are
      // answered rather than argued with: the set above now DOES see
      // tier 1, and DR-116 rules that a rule is a statement about the
      // resulting state rather than about the gesture, so there was never
      // a second vocabulary.
      _setTargets(candidates: free, springBack: springBack);
    });
    _status.show(
      grab.moving
          ? 'Moving ${link.designator}. Drop it on a free jack, or press Esc.'
          : 'Landing ${link.designator}. Drop it on a free jack, or press '
                'Esc.',
    );
    return true;
  }

  /// A press landed on [ref]: arm a wire from it, exactly as `W` does.
  ///
  /// Returns false when nothing armed — an already-full pin, or one no
  /// cable can leave — so the handler can fall back to treating the press
  /// as an ordinary click rather than starting a drag with nothing in it.
  bool _beginWireAt(PinRef ref) {
    // ═════════════════════════════════════════════════════════════════
    // `Shift` ON THE PRESS IS A SELECTION, NOT A CABLE — #93
    // ═════════════════════════════════════════════════════════════════
    // Returning false hands the press back to the ordinary click claim,
    // which is exactly right: extending a run is a click-shaped act with
    // no drag in it, and treating it as a refused arm reuses the path
    // `beginDrag` already has for "this pin cannot start a cable".
    if (HardwareKeyboard.instance.isShiftPressed) {
      _extendPinSelectionTo(ref);
      return false;
    }
    // ═══════════════════════════════════════════════════════════════
    // A PRESS ON A VECTOR PIN EXPANDS ITS BANK (`#801`, CR-103)
    // ═══════════════════════════════════════════════════════════════
    // AT THE PRESS AND NOT THE RELEASE, which the first draft got wrong.
    // A release only reaches `_releaseWireAt` when `_armWireFrom` claimed
    // the press, and a pin the wire rules refuse never arms: the click
    // then falls through the ordinary claim and the expansion never ran.
    // The press is the one place both paths pass through.
    //
    // IT TAKES THE CLICK RATHER THAN SHARING IT, because SELECTING a
    // collapsed pin means nothing: it stands for up to forty-eight ports
    // and a selection of it can be neither read nor wired. Until this
    // existed those ports had no pin, no hit region and no way to be
    // connected at all, which is what turning collapse on otherwise
    // costs.
    //
    // THE CARET IS SET FIRST, and it has to be: `B` collapses the bank the
    // caret is in, and a press that expanded without leaving one would
    // give a person no way back from the gesture they just made. The
    // bank's representative port is a real pin once expanded, so the
    // caret lands somewhere true.
    setState(() => _pinCaret = ref);
    final scene = _scene;
    if (scene != null) {
      final pin = _drawnPin(scene, ref);
      final bank = pin?.bankKey;
      if (pin != null && pin.isCollapsed && bank != null) {
        _toggleBankExpansion(ref.deviceId, bank);
        return false;
      }
    }
    // THE ANCHOR IS SET BY THE ORDINARY PRESS, before anything is armed.
    // Without it `Shift`+click has nothing to extend FROM, and there is
    // no second gesture that could set one — a modifier-free press on a
    // pin is the only thing a user does before reaching for `Shift`.
    // It costs an unarmed press nothing: a selection of one is not a
    // multi-draw (`PinSelection.isMultiple`).
    _anchorPinSelection(ref);
    return _armWireFrom(ref);
  }

  /// How far from a pin the band still locks onto it, in DIAGRAM UNITS.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// `Ctrl` SUPPRESSES THE MAGNET — AND IT GOVERNS THE DROP TOO
  /// ═══════════════════════════════════════════════════════════════════
  /// docs/05 §14: "Ctrl held during draw | Suppress magnetic snap". Read
  /// as affecting only the PREVIEW it would be a decoration: the band
  /// would stop jumping while the release still went wherever the magnet
  /// said, so the one gesture the modifier exists for — aiming at a pin
  /// that has a neighbour 3 px away — would still land on the neighbour.
  /// So the suppressed radius is used by the drag and the release alike.
  ///
  /// SUPPRESSED IS NOT ZERO. A magnet-less drop still has to hit
  /// something, and the honest target is the pin's own drawn glyph: what
  /// you are literally on, rather than what is merely nearest. The radius
  /// is READ OFF THE SCENE (`SymbolPort.size`, the circle the painter
  /// actually drew) instead of being restated as a constant — the
  /// painter/hit-tester desync `symbol_layer.dart`'s header records began
  /// as exactly that kind of second copy.
  ///
  /// Unsuppressed it is docs/05 §11.6's 12 SCREEN px, converted by the
  /// live scale for the reason [_portHitTolerancePx] gives.
  double _snapTolerance(SchematicScene scene) {
    final suppressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!suppressed) return _portHitTolerancePx / _viewport.scale;
    for (final symbol in scene.symbols) {
      for (final port in symbol.allPorts) {
        return port.size / 2;
      }
    }
    return 0;
  }

  /// The pointer moved to [scenePoint] while a wire is armed.
  void _dragWireTo(DPt scenePoint) {
    final scene = _scene;
    if (scene == null || _wireFrom == null) return;
    final snapped = snapToPin(
      scene,
      scenePoint,
      tolerance: _snapTolerance(scene),
      among: _candidates,
      preferred: _preferred,
    );
    if (snapped?.ref == _pinCaret && _freeEnd == null) return;
    setState(() {
      _pinCaret = snapped?.ref;
      _freeEnd = snapped == null ? scenePoint : null;
    });
    if (snapped != null) _announceCaret();
  }

  /// The drawn pin [ref] names, or null when the scene has none.
  ///
  /// A COLLAPSED PIN CARRIES A REAL `PortKey` (the bank's first port), so
  /// this resolves for a vector pin exactly as it does for an ordinary
  /// one. That is `SymbolPort.key`'s own stated reason for not being a
  /// synthesised `bank:` string.
  SymbolPort? _drawnPin(SchematicScene scene, PinRef ref) {
    for (final symbol in scene.symbols) {
      if (symbol.id != ref.deviceId) continue;
      for (final port in symbol.allPorts) {
        if (port.key == ref.portKey) return port;
      }
    }
    return null;
  }

  /// The device and bank the pin caret sits in, or null.
  ///
  /// NULL FOR A PIN WITH NO BANK, and for a bank the threshold would
  /// never collapse, because `B` on those has nothing to say and an
  /// enabled action that does nothing is a key a person presses twice.
  ({String deviceId, String bankKey})? _caretBank() {
    final scene = _scene;
    final caret = _pinCaret;
    if (scene == null || caret == null) return null;
    final pin = _drawnPin(scene, caret);
    final bank = pin?.bankKey;
    if (pin == null || bank == null) return null;
    if (pin.isCollapsed) return (deviceId: caret.deviceId, bankKey: bank);
    // Expanded: only offer to put it away if collapse would actually take
    // it, which is the same question `layOutSymbolEdges` asks.
    final open = _expandedBanks[Uuid(caret.deviceId)] ?? const <String>{};
    if (!open.contains(bank)) return null;
    return (deviceId: caret.deviceId, bankKey: bank);
  }

  /// CR-103's user half: put a bank away, or get it back (`#801`).
  ///
  /// BUMPS THE EPOCH AND DIRTIES THE STRUCTURE, because the symbol's pin
  /// count changes and every wire that lands on it moves. A carried tier
  /// here would draw the new sheet with the old symbols.
  void _toggleBankExpansion(String deviceId, String bankKey) {
    final id = Uuid(deviceId);
    final open = _expandedBanks[id] ?? const <String>{};
    final wasOpen = open.contains(bankKey);
    setState(() {
      final next = open.toSet();
      if (wasOpen) {
        next.remove(bankKey);
      } else {
        next.add(bankKey);
      }
      if (next.isEmpty) {
        _expandedBanks.remove(id);
      } else {
        _expandedBanks[id] = next;
      }
      _structureDirty = true;
      _sceneEpoch++;
    });
    // THE KEY IS NAMED ON THE WAY OUT, not only on the way in. A person
    // who expanded a bank by clicking it has no way to guess how to put
    // it back, and this canvas has no modifier left to spend on it.
    _status.show(
      wasOpen
          ? 'Collapsed $bankKey. Click the pin to expand it again.'
          : 'Expanded $bankKey. Press B to collapse it again.',
    );
  }

  /// The pointer came up at [scenePoint].
  ///
  /// THREE OUTCOMES, AND ALL THREE ARE docs/05 §7's OWN. Released on a
  /// candidate: commit. Released on a pin the rules refuse: the refusal,
  /// with its id and its sentence, and nothing written. Released on empty
  /// canvas: cancel — "`Esc`, right-click, or a click on empty canvas.
  /// All three abort with no model mutation and no undo entry."
  void _releaseWireAt(DPt scenePoint, {required bool moved}) {
    final scene = _scene;
    final from = _wireFrom;
    if (scene == null || from == null) return;
    setState(() => _freeEnd = null);

    // ═════════════════════════════════════════════════════════════════
    // A TAP ON A PIN IS NOT A CABLE. IT IS PICKING ONE UP AND PUTTING IT
    // BACK DOWN.
    // ═════════════════════════════════════════════════════════════════
    // Without this, a press-and-release inside the 4 px click slop
    // committed — and to a NEIGHBOUR, because the source pin is not in its
    // own candidate set and the magnet's radius is wider than the 2 gu pin
    // pitch at the framed zoom. So a single click on a jack silently
    // cabled it to the pin above it. Measured, not theorised: the first
    // run of this phase's suite produced "W006 connected MTX-1 J05 to
    // MTX-1 J05" from one `tapAt`.
    //
    // The rack's own rule for the mirror case is the authority — "a
    // sub-threshold press has no preview to cancel and STAYS A CLICK"
    // (`rack_canvas_screen.dart:1041`) — and this is its other half: a
    // sub-threshold press that DID arm a preview cancels it, because the
    // user never dragged anywhere.
    //
    // AND SINCE #93 THE TAP ALSO MEANS SOMETHING, which changes what is
    // said here. `_beginWireAt` set the anchor on the way in, so the
    // gesture that just happened was "pick this jack" — reporting a
    // cancelled cable would name the one thing the user did NOT do and
    // stay silent about the one they did.
    if (!moved) {
      _clearWire();
      if (_pins.isEmpty) {
        _status.show('Cable from ${_saying(from)} cancelled.');
      } else {
        _announcePinSelection();
      }
      return;
    }

    final tolerance = _snapTolerance(scene);
    final onCandidate = snapToPin(
      scene,
      scenePoint,
      tolerance: tolerance,
      among: _candidates,
      preferred: _preferred,
    );
    if (onCandidate != null) {
      setState(() => _pinCaret = onCandidate.ref);
      _commitWire();
      return;
    }

    // Not a candidate — but was it a PIN? The difference matters to the
    // user: dropping on a jack that cannot take the cable deserves the
    // rule that says why, and dropping on the paper is just a cancel.
    final onAnyPin = snapToPin(
      scene,
      scenePoint,
      tolerance: tolerance,
      among: [for (final pin in locatePins(scene)) pin.ref],
    );
    final target = onAnyPin == null ? null : _targetFor(onAnyPin.ref);
    final source = _targetFor(from);
    if (target != null && source != null) {
      final verdict = evaluateConnect(_doc, source, target);
      if (verdict is ConnectRefused) {
        _clearWire();
        _status.show('${verdict.ruleId} — ${verdict.message}');
        return;
      }
    }
    _cancelWire();
  }

  /// Writes [grab]'s end onto [to]: a LANDING when the run is waiting for
  /// that end, a MOVE when it already has one (`#719` / DR-073, `#725` /
  /// DR-074 §11.73.1).
  ///
  /// TWO COMMANDS AND ONE GESTURE, which is the ruling's split reached
  /// from the surface: `BindEndpointCommand` records a punchdown that has
  /// happened, `MoveEndpointCommand` says the recorded one was wrong, and
  /// the Edit menu names them differently because they are different acts.
  ///
  /// THE RACK LABEL IS ALLOCATED ONLY FOR A RACK END, which is DR-068
  /// §11.67.2 on the write side: the rack label is derived from the
  /// panel position, so the write is the only moment it can be known; the
  /// field label names the wall plate and landing a speaker says nothing
  /// about what the plate is called. A move re-derives it unless a person
  /// typed it, which `buildMoveEndpointCommand` decides rather than this.
  void _commitLanding(RunEndGrab grab, PinRef to, {bool overriding = false}) {
    final target = _targetFor(to);
    if (target == null) {
      _cancelWire();
      _status.show('That jack is no longer in this document.');
      return;
    }
    final link = _doc.links[grab.linkId];
    if (link == null) {
      _clearWire();
      _status.show('That cable is no longer in this project.');
      return;
    }

    // ═════════════════════════════════════════════════════════════════
    // TIER 2 ON THE BIND TOO (`#811`, DR-116 §11.115.3)
    // ═════════════════════════════════════════════════════════════════
    // DR-116: a rule is a statement about the RESULTING STATE, not about
    // the gesture that produced it. An HDBaseT run landed on a switch
    // port is the same 100 W hazard whichever gesture put it there, and
    // this one used to write it in silence.
    //
    // THE PAIR IS THE ANCHOR AND THE TARGET, because that is the cable
    // this gesture completes: the loose end is being given a port, and
    // the conductor's other end is already fixed. `evaluateSpringBack`
    // reads two `ConnectTarget`s and does not care which gesture
    // assembled them.
    //
    // `ontoLink: grab.linkId`, UNLIKE THE CONNECT GESTURE, and this is
    // the one place that parameter earns its keep. A bind completes an
    // EXISTING cable, so an `InlineAdapter` already declared on it
    // clears `CON-001` and `SIG-002`, and a `passiveSplit` net clears
    // `DIR-001` — exactly the cases the connect gesture passes null for
    // because it is minting a link that cannot yet carry any of them.
    if (!overriding) {
      final from = _anchorTargetOf(grab);
      if (from != null) {
        final verdict = evaluateSpringBack(
          _doc,
          from,
          target,
          ontoLink: grab.linkId,
        );
        if (verdict is SpringBackChip) {
          _springBackOff(to, verdict);
          return;
        }
      }
    }

    // EXCLUDES THIS RUN'S OWN LABEL, which matters only for a move: the
    // name it is about to give up is still on the document, and a scan
    // that counted it would allocate a suffixed variant to dodge a label
    // nobody else holds.
    final used = usedRackLabels(
      _doc,
      exceptLinkId: grab.moving ? grab.linkId : null,
    );
    final String? label;
    if (grab.end == LinkEnd.rack) {
      label = resolveRackLabel(
        doc: _doc,
        panelDeviceId: target.deviceId,
        // THE NUMBER ON THE PART, not the designator this product
        // allocated (DR-040 §11.39.8).
        portDesignator: target.portDesignator,
        usedRackLabels: used,
      ).label;
    } else {
      label = null;
    }
    final port = PortMaterialisation.of(
      target,
      designator: target.portDesignator,
    );

    if (grab.moving) {
      final built = buildMoveEndpointCommand(
        doc: _doc,
        linkId: grab.linkId,
        port: port,
        rackLabel: label,
        usedRackLabels: used,
        now: widget.controller.clock.nowUtc(),
        actor: widget.controller.actor,
        end: grab.end,
      );
      switch (built) {
        case MoveEndpointRefused(:final reason):
          _clearWire();
          _status.show(reason);
        case MoveEndpointReady(:final command, :final keptRackLabel):
          _clearWire();
          widget.controller.run(command);
          // THE KEPT LABEL IS SAID OUT LOUD (§11.73.2). A person who
          // moved a drop and sees the old name needs to know it survived
          // because they typed it, rather than because the move
          // half-failed.
          _status.show(
            keptRackLabel == null
                ? '${link.designator} moved to ${target.citation}.'
                : '${link.designator} moved to ${target.citation}. Its rack '
                      'label $keptRackLabel was typed by hand, so it stayed.',
          );
      }
      return;
    }

    final built = buildBindEndpointCommand(
      doc: _doc,
      linkId: grab.linkId,
      port: port,
      rackLabel: label,
      usedRackLabels: used,
      now: widget.controller.clock.nowUtc(),
      actor: widget.controller.actor,
      end: grab.end,
    );
    switch (built) {
      case BindEndpointRefused(:final reason):
        _clearWire();
        _status.show(reason);
      case BindEndpointReady(:final command):
        _clearWire();
        widget.controller.run(command);
        _status.show('${link.designator} landed on ${target.citation}.');
    }
  }

  /// `Esc` while a wire is in flight — docs/05 §7's cancel.
  ///
  /// "All three abort with no model mutation and no undo entry" (docs/05
  /// §7). Nothing has been written, so there is nothing to undo; the caret
  /// stays where it is, because the user's next act is usually to aim
  /// somewhere else from the same place.
  void _cancelWire() {
    if (_wireFrom == null) return;
    final from = _wireFrom!;
    _clearWire();
    _status.show('Cable from ${_saying(from)} cancelled.');
  }

  /// Drops the in-flight wire WITHOUT a message — for the callers that
  /// have a more specific thing to say (a refusal, a commit) and would
  /// otherwise overwrite it with a generic one.
  void _clearWire() {
    setState(() {
      // THE CHIP GOES WITH THE GESTURE, and this line is what does it:
      // nulling `_wireFrom` runs its setter, which forgets the chip. See
      // that property for why the invariant lives there rather than in
      // each of the five places a gesture can end.
      _wireFrom = null;
      _landingFrom = null;
      _wireFromSetKey = null;
      _wireFromBankKey = null;
      _multiPlans = const <(String, String), MultiDrawPlan>{};
      _clearTargets();
      _freeEnd = null;
    });
  }

  /// The cable sprang back off [at], and this is the chip that says why.
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// THE GESTURE IS NOT OVER, WHICH IS DR-114 §11.113.4
  /// ═════════════════════════════════════════════════════════════════
  /// CR-017's binding sentence is *"the gesture may HESITATE; the
  /// document may not lie"*, and a gesture that hesitated has not ended.
  /// So [_wireFrom] is untouched, the candidate rings stay lit, and the
  /// user is back where they were one frame before the release. That is
  /// what makes `[ Pick a different port ]` a real button rather than a
  /// relabelled Cancel.
  ///
  /// THE CARET GOES WITH THE BAND, and that is what "sprang back" means
  /// rather than a shortcut. A caret left sitting on the refused pin
  /// would keep the band drawn to it, which says the cable is still
  /// aimed there — the one thing that just stopped being true. It lands
  /// on NOTHING rather than on the source: `_cycleCandidate` reads
  /// `_pinCaret ?? _candidates.first`, so Tab picks up from the top of a
  /// candidate list that is still the right one.
  ///
  /// NOTHING IS WRITTEN. This is the half of CR-017 that does not bend.
  void _springBackOff(PinRef at, SpringBackChip chip) {
    final source = _wireFrom;
    final scene = _scene;
    if (source == null || scene == null) return;
    final from = locatePin(scene, source);
    final to = locatePin(scene, at);

    // THE CURVE BEFORE ITS PARENT, as in [dispose]: a `CurvedAnimation`
    // unregisters from the controller it was built on.
    _springBackCurve?.dispose();
    _springBackCurve = null;
    _springBackAnim?.dispose();
    _flashAnim?.dispose();

    // docs/05 §7: 120 ms, `Curves.easeOutBack`. The overshoot is the
    // point of that curve and it is right here: a band that eases to a
    // stop reads as a decision, and one that springs past and settles
    // reads as a rejection, which is what happened.
    final retract = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    final flash = AnimationController(
      vsync: this,
      // Four 90 ms phases: lit, dark, lit, dark. docs/05 §7's "flashes
      // twice at 90 ms" is two flashes, and a flash is a pair.
      duration: const Duration(milliseconds: 360),
    );
    _springBackAnim = retract;
    _flashAnim = flash;

    if (from != null && to != null) {
      // HELD IN A FIELD AND DISPOSED, not created and dropped. A
      // `CurvedAnimation` registers with its parent and is exactly what
      // `leak_tracker_flutter_testing` flags, and docs/11 runs that
      // tracker on every canvas widget test — so an escaped one fails
      // the suite rather than quietly costing memory.
      final curve = CurvedAnimation(parent: retract, curve: Curves.easeOutBack);
      _springBackCurve = curve;
      retract
        ..addListener(() {
          if (!mounted) return;
          final t = curve.value;
          setState(() {
            // 1 at the refused pin, 0 at the source. `easeOutBack`
            // overshoots below zero on the way in, which pulls the band a
            // little PAST the source before it settles — the visual
            // recoil the curve was chosen for.
            _freeEnd = DPt(
              from.centre.x + (to.centre.x - from.centre.x) * (1 - t),
              from.centre.y + (to.centre.y - from.centre.y) * (1 - t),
            );
          });
        })
        ..addStatusListener((status) {
          if (status != AnimationStatus.completed || !mounted) return;
          setState(() => _freeEnd = null);
        });
    }

    flash.addListener(() {
      if (mounted) setState(() {});
    });

    setState(() {
      _chip = chip;
      _chipAt = at;
      // THE CARET DROPS, THE SOURCE HOLDS. See this method's doc.
      _pinCaret = null;
      _freeEnd = from == null || to == null ? null : to.centre;
    });
    retract.forward();
    flash.forward();

    // THE RULE ID AND THE SENTENCE, LIKE EVERY OTHER REFUSAL ON THIS
    // SCREEN. The chip is the surface, and the status line is what a
    // screen reader following the gesture hears; DR-011.5's rule for a
    // refusal is the id AND a sentence naming real designators, and a
    // chip that were the only carrier would be invisible to the
    // accessibility channel this screen has used throughout.
    _status.show('${chip.ruleId} — ${chip.headline} ${chip.explanation}');
  }

  /// Drops the chip and its animations WITHOUT a `setState`.
  ///
  /// Every caller is already inside one: the `_wireFrom` setter runs from
  /// the `setState` blocks that end a gesture, and [_dismissChip] wraps
  /// its own. A notify here would be a second rebuild for one act.
  void _forgetChip() {
    if (_chip == null && _chipAt == null) return;
    _springBackAnim?.stop();
    _flashAnim?.stop();
    _chip = null;
    _chipAt = null;
  }

  /// `[ Pick a different port ]`, and what `Esc` does while a chip is up.
  ///
  /// Closes the chip and leaves everything else exactly as it is: the
  /// wire armed, the candidates lit, the caret free. The refusal mark
  /// goes with the chip, because it existed to say what the chip was
  /// about.
  void _dismissChip() {
    if (_chip == null) return;
    setState(() {
      _forgetChip();
      _freeEnd = null;
    });
  }

  /// A remedy chip was pressed (CR-015, DR-115).
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// THE ONLY BUTTON ON THIS CHIP THAT WRITES A DEVICE
  /// ═════════════════════════════════════════════════════════════════
  /// `[ Connect anyway ]` makes a cable and `[ Pick a different port ]`
  /// makes nothing; this mints a `DeviceInstance`. That is why the chip
  /// autofocuses `[ Pick a different port ]` rather than this: the key
  /// that opened the chip is the `Enter` the user pressed to commit, and
  /// a mutation under a reflex is how a hesitation becomes an edit.
  ///
  /// ONE UNDO ENTRY, LABELLED FOR WHAT IT DID. `LabelKey.connectPorts`
  /// would put "Undo connect" in the Edit menu for a gesture that also
  /// placed a device, which is the same defect DR-014's split label
  /// exists to avoid: a user who reads that and takes it at its word
  /// expects one cable to disappear and nothing else.
  void _applyRemedy(SpringBackRemedy remedy) {
    final from = _wireFrom;
    final fromTarget = from == null ? null : _targetFor(from);
    if (fromTarget == null) {
      _dismissChip();
      _status.show("That cable's source pin is no longer in this document.");
      return;
    }
    switch (remedy) {
      case SpringBackRemedy.insertHdbasetReceiver:
        late InsertReceiverResult result;
        // See [_committingWire]: this writes the document, so the
        // teardown that fires on a `structure` bump must not read it as
        // somebody else's edit and announce a cancellation.
        _committingWire = true;
        try {
          widget.controller.transact(LabelKey.insertRemedyDevice, (tx) {
            result = insertHdbasetReceiver(
              tx,
              doc: _doc,
              from: fromTarget,
              now: widget.controller.clock.nowUtc(),
              actor: widget.controller.actor,
            );
          });
        } finally {
          _committingWire = false;
        }
        switch (result) {
          case InsertReceiverRefused(:final reason):
            // THE CHIP STAYS UP. The user asked for a fix and did not get
            // one, so closing the chip would leave them looking at a
            // sheet with no cable and no explanation of either failure.
            _status.show(reason);
          case InsertReceiverDone(
            :final receiverDesignator,
            :final landedOn,
          ):
            _clearWire();
            _status.show(
              'Inserted $receiverDesignator and landed the run on its '
              '$landedOn. Its HDMI output is open — drag from it to the '
              'display (DR-115).',
            );
        }

      // ═════════════════════════════════════════════════════════════
      // `CON-001` — DECLARE THE ADAPTER, AND MAKE THE CABLE IT SITS IN
      // ═════════════════════════════════════════════════════════════
      // DR-128 §11.127.2. The rule's own catalogue summary promises
      // that "declaring the adapter clears it", and until DR-128
      // nothing in the tree could declare one: `InlineAdapter`'s only
      // writer was the JSON decoder.
      //
      // TWO COMMANDS, ONE UNDO ENTRY, and the cable comes first because
      // the adapter is a value ON it. This gesture is mid-draw, so
      // there is no Link yet to carry anything — which is exactly why
      // `evaluateSpringBack` was called with `ontoLink: null` and why
      // the rule fired in the first place.
      case SpringBackRemedy.declareAdapter:
        final at = _chipAt;
        final toTarget = at == null ? null : _targetFor(at);
        if (toTarget == null) {
          _dismissChip();
          _status.show("That cable's far pin is no longer in this document.");
          return;
        }
        // ASKED BEFORE ANYTHING IS WRITTEN, on `insert_receiver.dart`'s
        // argument: the chip is a frame old, and a port override in
        // between can make the two connectors agree. Declaring an
        // adapter needs the link to exist, so a refusal discovered
        // AFTER the connect would leave a bare cable behind for
        // somebody who asked for an adapter. The only precondition that
        // can fail here is the connectors matching; a duplicate is
        // impossible on a Link one command old.
        if (fromTarget.def.connector == toTarget.def.connector) {
          _status.show(
            '${fromTarget.citation} and ${toTarget.citation} both take '
            '${fromTarget.def.connector.v} now, so no adapter is needed.',
          );
          return;
        }
        late String outcome;
        _committingWire = true;
        try {
          // `declareInlineAdapter` AND NOT `insertRemedyDevice`: no
          // device is minted, and the Edit menu has to name the act the
          // person actually took. They pressed "Declare an adapter".
          widget.controller.transact(LabelKey.declareInlineAdapter, (tx) {
            final built = buildSplitConnectCommands(
              doc: _doc,
              from: fromTarget,
              to: toTarget,
              media: kUnstatedMedia,
              now: widget.controller.clock.nowUtc(),
              actor: widget.controller.actor,
            );
            switch (built) {
              case SplitConnectRefused(:final ruleId, :final message):
                outcome = '$ruleId — $message';
              case SplitConnectReady(:final commands, :final connect):
                for (final command in commands) {
                  tx.add(command);
                }
                final adapter = buildDeclareAdapterCommand(
                  doc: _doc,
                  linkId: connect.id,
                  from: fromTarget,
                  to: toTarget,
                  ruleId: SpringBackRule.connectorsDoNotMate.id,
                );
                switch (adapter) {
                  case DeclareAdapterRefused(:final message):
                    outcome = message;
                  case DeclareAdapterReady(:final command):
                    tx.add(command);
                    outcome =
                        'Declared a ${fromTarget.def.connector.v} to '
                        '${toTarget.def.connector.v} adapter on the cable. '
                        'Name the part in the inspector so it reaches the '
                        'bill of materials.';
                }
            }
          });
        } finally {
          _committingWire = false;
        }
        _clearWire();
        _status.show(outcome);

      // ═════════════════════════════════════════════════════════════
      // `SIG-002` — MINT THE CONVERTER AND WIRE IT IN BETWEEN
      // ═════════════════════════════════════════════════════════════
      // DR-128 §11.127.3/.4. CR-015's test read the other way from
      // `CON-001`'s: a family mismatch is answered by electronics, an
      // installer pulls two cables to one, so it is a DEVICE.
      //
      // NO CONNECT HERE. `insertSignalConverter` makes BOTH cables
      // itself, because the converter goes BETWEEN the two pins rather
      // than on the cable between them, and it refuses before writing
      // anything rather than half way through.
      case SpringBackRemedy.insertConverter:
        final at = _chipAt;
        final toTarget = at == null ? null : _targetFor(at);
        if (toTarget == null) {
          _dismissChip();
          _status.show("That cable's far pin is no longer in this document.");
          return;
        }
        late InsertConverterResult converted;
        _committingWire = true;
        try {
          widget.controller.transact(LabelKey.insertRemedyDevice, (tx) {
            converted = insertSignalConverter(
              tx,
              doc: _doc,
              from: fromTarget,
              to: toTarget,
              now: widget.controller.clock.nowUtc(),
              actor: widget.controller.actor,
            );
          });
        } finally {
          _committingWire = false;
        }
        switch (converted) {
          case InsertConverterRefused(:final message):
            // THE CHIP STAYS UP, for the reason the `SIG-001` arm gives:
            // the user asked for a fix and did not get one.
            _status.show(message);
          case InsertConverterDone(:final designator, :final displayName):
            _clearWire();
            _status.show(
              'Inserted $designator, a $displayName, and ran a cable to '
              'each side. It states no wattage, because nothing has said '
              'what it draws.',
            );
        }
    }
  }

  /// `Enter` — commit the wire in flight (docs/05 §7, DR-011.6).
  ///
  /// [overriding] is `[ Connect anyway ]`: the same commit with tier 2
  /// skipped, and NOT a second path. CR-017's override writes exactly the
  /// cable the ordinary gesture would have written, so a separate builder
  /// here would be two ways to make one Link, differing by whichever one
  /// somebody forgot to update.
  void _commitWire({bool overriding = false}) {
    final from = _wireFrom;
    final to = _pinCaret ?? (overriding ? _chipAt : null);
    if (from == null || to == null) return;
    // LANDING FIRST, because it is not a connect at all. See
    // [_landingFrom]: the run exists, so completing it must MOVE an end
    // rather than create a second cable beside it.
    if (_landingFrom case final grab?) {
      // THE OVERRIDE TRAVELS, which is `#811`'s half of DR-116: a bind
      // that springs back must offer the same way through as a connect
      // does, or `[ Connect anyway ]` would be a button that reopens the
      // chip it was pressed on.
      _commitLanding(grab, to, overriding: overriding);
      return;
    }
    // The same three-way branch [_armWireFrom] took, read back off the
    // field each limb set. Multi-draw first, for the reason stated there.
    if (_wireFromBankKey != null) {
      _commitMultiDraw(to);
      return;
    }
    final setKey = _wireFromSetKey;
    if (setKey != null) {
      _commitSet(from, to, setKey);
      return;
    }
    final fromTarget = _targetFor(from);
    final toTarget = _targetFor(to);
    if (fromTarget == null || toTarget == null) {
      _cancelWire();
      _status.show("That cable's pins are no longer in this document.");
      return;
    }

    // ═════════════════════════════════════════════════════════════════
    // THE BUILDER THROWS ON PURPOSE, AND A KEYSTROKE MAY NOT CRASH
    // ═════════════════════════════════════════════════════════════════
    // `allocatePortDesignatorFor`'s own doc: it "THROWS where
    // `ConnectTarget.plannedDesignator` falls back to null", because a
    // `Port` written with a fabricated or blank designator is a wrong
    // identifier on a termination schedule (G4) and there is no weaker
    // answer that is safe. That is right for core and it makes this call
    // site the one that has to catch.
    //
    // IT IS REACHABLE FROM A FILE, not only from a bug.
    // `ProjectSettings.portDesignatorFormat` is a persisted, user-editable
    // pattern with three live failure modes — canon's own commercial
    // `{DEV_BLOCK}{PORT_SEQ:2}` preset throws because reserve-block
    // allocation is not implemented, a hand-edited file can carry a
    // syntactically broken pattern, and one with no sequence token
    // exhausts. Every one of those is a problem with a SETTING, and none
    // of them is a reason a `W`-arrows-`Enter` should take the app down.
    //
    // Reported, never swallowed: the sentence says which setting, because
    // that is the only thing the user can act on.
    final SplitConnectResult result;
    try {
      // DR-014: the same builder for both, because from the user's side
      // there is one gesture. `buildSplitConnectCommands` plans the splits
      // (usually none) and returns a plain connect when there are none, so
      // the ordinary cable is unchanged in behaviour, in undo label and in
      // what it writes.
      result = buildSplitConnectCommands(
        doc: _doc,
        from: fromTarget,
        to: toTarget,
        // DR-011.4's sibling ruling, argued in `connect_commands.dart`:
        // nothing in this document can say what cable this is, and G4
        // forbids guessing one from the signal family.
        media: kUnstatedMedia,
        now: widget.controller.clock.nowUtc(),
        actor: widget.controller.actor,
      );
    } on Exception catch (error) {
      _cancelWire();
      _status.show(
        "This project's port designator format cannot number "
        '${fromTarget.citation} or ${toTarget.citation}, so the cable was '
        'not made: $error',
      );
      return;
    }

    switch (result) {
      case SplitConnectRefused(:final ruleId, :final message):
        // DR-011.5: T1 refuses OUTRIGHT — there is no [ Connect anyway ],
        // because docs/02:854 gives T1's escape as "None. There is nothing
        // to escape to", and M2 would otherwise ship a way to persist a
        // topology violation two milestones before M5's validation exists
        // to flag it. The rule id AND a sentence naming real designators,
        // both, because "TOP-003" alone is a log line.
        //
        // DR-014 does not soften this. A refusal here has already been
        // evaluated WITH whatever splits were available, so the pin really
        // is full and no conductor was lifted — `buildSplitConnectCommands`
        // returns no commands at all on this arm, splits included.
        _status.show('$ruleId — $message');
      case SplitConnectReady(
        :final commands,
        :final connect,
        :final splits,
        :final roleMismatch,
      ):
        // ═════════════════════════════════════════════════════════════
        // TIER 2, AFTER TIER 1 AND BEFORE ANYTHING RUNS (CR-017, `#278`)
        // ═════════════════════════════════════════════════════════════
        // INSIDE THIS ARM ON PURPOSE, AND THE FIRST DRAFT HAD IT ABOVE
        // THE BUILDER. That put tier 2 ahead of tier 1, so a pin the
        // MODEL refuses would have shown a trade opinion instead of
        // `TOP-003`. DR-112 §11.111 is the ruling the order comes from:
        // the tiers answer different questions, and tier 1's is whether
        // the document would mean anything at all. It goes first.
        //
        // The draft's stated reason for going early was that a built
        // command would "have to be thrown away", which is not a cost:
        // `buildSplitConnectCommands` returns a VALUE and writes nothing
        // until `run`. Nothing is thrown away except an object.
        //
        // `ontoLink: null` for the arm-time walk's reason: this gesture
        // always mints a new Link, so there is none yet to carry an
        // adapter that would clear the rule.
        //
        // SKIPPED WHOLE WHEN OVERRIDING rather than evaluated and
        // ignored. docs/02 §5.2 gives the override as *"creates the Link
        // and files a T3 finding"*, and the finding is COMPUTED
        // (CR-021): it appears on the next pass over a document that now
        // holds the cable. There is nothing to file and nothing to
        // remember, which is M5-B1's ruling paying off rather than a gap.
        if (!overriding) {
          final verdict = evaluateSpringBack(_doc, fromTarget, toTarget);
          if (verdict is SpringBackChip) {
            _springBackOff(to, verdict);
            return;
          }
        }
        final command = connect;
        // See [_committingWire]. `try`/`finally` because a command that
        // throws must not leave the latch stuck true.
        _committingWire = true;
        try {
          // ONE UNDO ENTRY EITHER WAY, AND TWO DIFFERENT LABELS.
          // A plain connect keeps `LabelKey.connectPorts` and its single
          // `run`, so nothing about the ordinary cable moved. A split is a
          // `transact` under `LabelKey.splitSet` — the Edit menu must not
          // offer "Undo connect" for a gesture that also took a conductor
          // out of an existing cable, because a user who reads that and
          // takes it at its word expects one cable to disappear.
          if (splits.isEmpty) {
            widget.controller.run(command);
          } else {
            widget.controller.transact(LabelKey.splitSet, (tx) {
              for (final child in commands) {
                tx.add(child);
              }
            });
          }
        } finally {
          _committingWire = false;
        }
        // THE CARET STAYS ON THE SINK. This is the M1 refutation's lesson
        // applied: the next `W` starts from where the user is looking, so
        // back-to-back cables are W-arrows-Enter, W-arrows-Enter with no
        // round trip through a selection.
        setState(() {
          _pinCaret = to;
          _wireFrom = null;
          _wireFromSetKey = null;
          _clearTargets();
        });
        // ═══════════════════════════════════════════════════════════
        // THE DESIGNATORS THE COMMAND WROTE, NOT THE ONES RESOLVE-TIME
        // GUESSED
        // ═══════════════════════════════════════════════════════════
        // `ConnectTarget.plannedDesignator` is computed per target, each
        // against the document as it stands — so TWO unmaterialised pins
        // on ONE device both plan the same next free J-number, and a
        // sentence built from the two citations reported "W006 connected
        // MTX-1 J05 to MTX-1 J05" for a perfectly good loopback between
        // two different jacks. Only the builder resolves that, by passing
        // the first end's answer as `alsoUsed` to the second.
        //
        // So the message reads `PortMaterialisation.designator`, which is
        // what `apply()` actually stamped on the port. The planned value
        // keeps its job — naming a pin in a REFUSAL, where no command was
        // built and there is nothing better to say.
        final fromSaid =
            '${fromTarget.deviceDesignator} '
            '${command.from.designator}';
        final toSaid =
            '${toTarget.deviceDesignator} '
            '${command.to.designator}';
        final warning = roleMismatch == null
            ? ''
            : ' — but $fromSaid is the "${roleMismatch.fromRole}" leg and '
                  '$toSaid is the "${roleMismatch.toRole}" leg, so this '
                  'cable carries no role';
        final chained = _chainOnFrom(toTarget, command.signalFamily);
        _status.show(
          '${command.designator} connected $fromSaid to $toSaid'
          '${_splitSaying(splits)}$warning.$chained',
        );
    }
  }

  /// The clause naming what DR-014 just took apart, or `''` when nothing
  /// was split — which is every ordinary cable.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// IT NAMES THE BILL OF MATERIALS, BECAUSE DR-012.2 SAYS IT MUST
  /// ═══════════════════════════════════════════════════════════════════
  /// One `Link` with N `Conductor`s and N `Link`s are DIFFERENT BILLS OF
  /// MATERIALS — DR-012.2's whole subject — and a split moves one
  /// conductor across that line: the installer's pull sheet gains a row
  /// and an existing row loses a path. A silent choice between the two is
  /// the harm that ruling exists to prevent, so the count is the point of
  /// the sentence and "split from W001" alone does not discharge it.
  ///
  /// ONE CLAUSE, NOT A SECOND MESSAGE. `_status.show` overwrites, so two
  /// calls would leave a screen reader having heard only the last — the
  /// same defect `_chainOnFrom` composes its clause to avoid, and for the
  /// same reason.
  String _splitSaying(List<SetSplit> splits) {
    if (splits.isEmpty) return '';
    String one(SetSplit split) {
      final after = split.conductorsAfter;
      return '${split.linkDesignator}, which now carries $after '
          '${after == 1 ? 'conductor' : 'conductors'} instead of '
          '${split.conductorsBefore}';
    }

    return ', split out of ${splits.map(one).join(' and out of ')}';
  }

  /// docs/05:482's CHAIN-DRAW: `Shift` held at commit re-arms the gesture
  /// from the sink device's matching output, so `ATV-1 → MTX-1`,
  /// `MTX-1 → DA-1`, `DA-1 → TV` is three gestures with no round trip
  /// through idle. docs/05 calls it "the highest-throughput gesture in the
  /// editor".
  ///
  /// Returns the CLAUSE to append to the commit announcement, so a screen
  /// reader hears one sentence rather than two — "…connected AVR-1 J03,
  /// and re-armed from MTX-1 J07" is what happened; two messages, the
  /// second overwriting the first on the status line, is not.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// AFTER THE COMMIT AND AFTER THE TEARDOWN, WHICH IS THE ONLY ORDER
  /// THAT WORKS
  /// ═══════════════════════════════════════════════════════════════════
  /// `controller.run` bumps the epochs synchronously, so the scene is
  /// rebuilt and [_candidates] is invalidated during the commit. Re-arming
  /// BEFORE that would compute a candidate set against a document that is
  /// one cable out of date — and the pin it just filled would still be in
  /// it.
  ///
  /// "MATCHING" IS DR-012.1, AND ITS DEFINITION IS IN CORE, not here:
  /// [chainOutputFor] is the same-family, first-free, template-ordered
  /// query, and it is a document question rather than a screen one.
  String _chainOnFrom(ConnectTarget sink, SignalFamilyId family) {
    if (!HardwareKeyboard.instance.isShiftPressed) return '';
    final next = chainOutputFor(
      _doc,
      deviceId: sink.deviceId,
      family: family,
    );
    if (next == null) {
      // THE CHAIN ENDS, AND IT SAYS SO. DR-012.1: a device with no free
      // output of that family is where a chain legitimately stops, and a
      // `Shift` that silently did nothing would be the no-op docs/04 §3.4
      // forbids — arriving at the end of a gesture the user believed was
      // continuing.
      return ' The chain ends: ${sink.deviceDesignator} has no free '
          'output for this signal.';
    }
    final ref = PinRef(
      deviceId: next.deviceId.v,
      portKey: next.portKey.v,
    );
    setState(() => _pinCaret = ref);
    // Through the ONE arming path, so a chained re-arm cannot disagree
    // with `W` about what a legal start is or about what the candidates
    // are. It reports its own failure if the new source has no target.
    if (!_armWireFrom(ref, announce: false)) {
      return ' The chain ends: nothing on this sheet can take a cable from '
          '${_saying(ref)}.';
    }
    return ' Chained: now drawing from ${_saying(ref)}, '
        '${_candidates.length} '
        '${_candidates.length == 1 ? 'pin' : 'pins'} can take it.';
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
    // The gesture in flight, resolved against the scene that is about to
    // be painted — never against a remembered geometry. A caret ring that
    // is one frame behind the symbol it is on is a cursor that lies.
    final overlay = buildConnectOverlay(
      scene: scene,
      style: _connectOverlayStyle(scheme),
      scale: _viewport.scale,
      caret: _pinCaret,
      source: _wireFrom,
      freeEnd: _freeEnd,
      candidates: _candidates,
      springBack: _springBack,
      refused: _chipAt,
      refusedVisible: _refusedVisible,
      selected: _pins.refs,
      pairs: _multiDrawBands(),
      selectedLink: _selectedLink,
    );
    final plan = _basePlanFor(
      scene: scene,
      scope: scope,
      palette: palette,
      groundArgb: _argbOfColor(scheme.surfaceContainerLowest),
    ).withOverlay(overlay.ops);

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
        // EVERY ENTRY HERE IS GATED, and none of them may go back to being
        // a `CallbackAction`. `Action.consumesKey` defaults to true and
        // `toKeyEventResult` maps that to `KeyEventResult.handled`
        // REGARDLESS of what the callback returns or does — so the four
        // `CallbackAction`s that stood here consumed `1`–`8`, `` ` ``, `F`
        // and `Esc` even on the frame where their bodies declined to act.
        // Overriding `consumesKey => false` is not the escape hatch either
        // (it yields `skipRemainingHandlers`, which halts dispatch just as
        // dead); only `isActionEnabled == false` yields `ignored`. See
        // `_GatedAction`'s doc comment, docs/04:450, and
        // `keymap_arbitration_test.dart`, which already lists
        // `schematicCancel` among the bindings that MUST be a real gated
        // `Action` and would have failed the moment anything else in the
        // app claimed `Esc`.
        //
        // THE `Esc` GATE IS THE ONE THAT CHANGES BEHAVIOUR TODAY, and it is
        // the reason this item is Phase 1 rather than Phase 2. `Esc` is a
        // LAYERED key (docs/04 §8: "cancel drag, exit mode, clear
        // selection"), and a layer can only decline it by being disabled.
        // With nothing focused and nothing selected this screen has no
        // meaning for `Esc`, so it must fall through to whatever is behind
        // it — a dialog, the shell — instead of being eaten. Phase 2's
        // connect mode joins that ladder ABOVE these two limbs by widening
        // this one predicate.
        actions: <Type, Action<Intent>>{
          SoloDomainIntent: _GatedAction<SoloDomainIntent>(
            () => _canvasKeysEnabled,
            (intent) => _soloByIndex(intent.index),
          ),
          ShowAllDomainsIntent: _GatedAction<ShowAllDomainsIntent>(
            () => _canvasKeysEnabled,
            (_) => _showAllDomains(),
          ),
          // `Ctrl+L` (DR-186 §11.185.3): a symbol is pinned where the layout
          // put it. Disabled with nothing selected, so it falls through.
          ToggleLockIntent: _GatedAction<ToggleLockIntent>(
            () => _canvasKeysEnabled && _selection.isNotEmpty,
            (_) => _togglePinSelection(),
          ),
          // `Ctrl+Shift+U` (DR-187 §11.186.9). Gated on the SELECTION and
          // not on anything being pinned: a chord that fell through when
          // the selection held nothing pinned would be a key that works
          // sometimes, and the status line saying so is the feedback
          // docs/04 §3.4 asks for instead of a silent no-op.
          UnpinSelectionIntent: _GatedAction<UnpinSelectionIntent>(
            () => _canvasKeysEnabled && _selection.isNotEmpty,
            (_) => _unpinSelection(),
          ),
          FocusSelectionIntent: _GatedAction<FocusSelectionIntent>(
            () => _canvasKeysEnabled,
            (_) => _toggleFocus(),
          ),
          // `#801`, CR-103. GATED ON THE CARET BEING IN A COLLAPSIBLE
          // BANK, not merely on the canvas having keys: a disabled action
          // falls through, so `B` over a pin with no bank stays available
          // to whatever is behind this canvas rather than being eaten.
          ToggleBankExpansionIntent: _GatedAction<ToggleBankExpansionIntent>(
            () => _canvasKeysEnabled && _caretBank() != null,
            (_) {
              final where = _caretBank();
              if (where != null) {
                _toggleBankExpansion(where.deviceId, where.bankKey);
              }
            },
          ),
          SchematicCancelIntent: _GatedAction<SchematicCancelIntent>(
            // THE WIRE IS THE NEW TOP RUNG, and this predicate is the whole
            // of how it joins the ladder — exactly as Phase 1 predicted it
            // would ("Phase 2's connect mode joins that ladder ABOVE these
            // two limbs by widening this one predicate"). With nothing in
            // flight, nothing focused and nothing selected, `Esc` still has
            // no meaning here and must fall through to the layer behind it.
            () =>
                _canvasKeysEnabled &&
                (_chip != null ||
                    _wireFrom != null ||
                    !_pins.isEmpty ||
                    _selectedLink != null ||
                    _focused.isNotEmpty ||
                    _selection.isNotEmpty),
            (_) => _onEscape(),
          ),
          DeleteSelectionIntent: _GatedAction<DeleteSelectionIntent>(
            // ENABLED WHENEVER THERE IS A CARET, not only when a cable is
            // selected, and the difference is the keyboard route: a user who
            // has never touched the mouse has no selected cable and is
            // standing on a pin. `_deleteSelectedLink` reads the caret when
            // the selection is empty, so gating on the selection alone would
            // make `Del` a mouse-only key on a canvas whose whole connect
            // gesture was built keyboard-first (DR-011.6).
            //
            // CONSUMING IT WITH NOTHING TO DELETE IS SAFE HERE, which is not
            // true of most keys on this screen: `rack` is a SIBLING scope
            // rather than an ancestor and `global` binds no `Delete`, so
            // there is nothing behind this to fall through to. And it is not
            // silent — every one of the three nothings gets a sentence,
            // which is what docs/04 §3.4 asks for.
            () =>
                _canvasKeysEnabled &&
                (_selectedLink != null || _pinCaret != null),
            (_) => _deleteSelectedLink(),
          ),
          BeginWireIntent: _GatedAction<BeginWireIntent>(
            // Re-arming from a different pin mid-flight would silently
            // discard the cable in hand; `Esc` first is one keystroke and
            // is the documented cancel.
            () => _canvasKeysEnabled && _wireFrom == null,
            (_) => _beginWire(),
          ),
          CommitWireIntent: _GatedAction<CommitWireIntent>(
            // `Enter` is a framework chord (`ActivateIntent`) and the rack
            // owns it too, so this must decline it whenever there is no
            // cable to commit — a consumed `Enter` on an idle sheet is a
            // button somewhere that stopped working.
            () => _canvasKeysEnabled && _wireFrom != null && _pinCaret != null,
            (_) => _commitWire(),
          ),
          NextCandidatePinIntent: _GatedAction<NextCandidatePinIntent>(
            // ARMED ONLY — see the binding's note. An idle sheet hands
            // `Tab` back to focus traversal, or a keyboard-only user could
            // enter this canvas and never leave it.
            () => _canvasKeysEnabled && _wireFrom != null,
            (_) => _cycleCandidate(step: 1),
          ),
          PreviousCandidatePinIntent: _GatedAction<PreviousCandidatePinIntent>(
            () => _canvasKeysEnabled && _wireFrom != null,
            (_) => _cycleCandidate(step: -1),
          ),
          MovePinCaretIntent: _GatedAction<MovePinCaretIntent>(
            () => _canvasKeysEnabled,
            (intent) => _movePinCaret(intent.direction),
          ),
          ExtendPinSelectionIntent: _GatedAction<ExtendPinSelectionIntent>(
            // NOT gated on a wire, and not gated on a run existing: this
            // is how a run is STARTED from the keyboard, and gating it on
            // its own output is the "worked once then quietly stopped"
            // shape DR-011 records M1 being refuted by. It is gated while
            // a cable is in flight, though — extending the source run
            // under an armed wire would change what the wire is drawn
            // from without redrawing its band or its candidates.
            () => _canvasKeysEnabled && _wireFrom == null,
            (intent) => _extendPinSelection(by: intent.step),
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
                // EVERY FILTER GESTURE RETIRES THE MARK, not just the
                // `Got it` button: a user who narrows a domain without
                // reading the hint has learnt the thing it teaches, and
                // showing it to them again on the next project would make
                // it a nag — which is the half of DR-012.4 that ruled out
                // leaving it unpersisted.
                onSolo: (id) {
                  _dismissCoachMark();
                  setState(() => _filter = _filter.solo(id));
                },
                onToggle: (id) {
                  _dismissCoachMark();
                  setState(() => _filter = _filter.toggle(id));
                },
                onShowAll: () {
                  _dismissCoachMark();
                  _showAllDomains();
                },
                onShowNone: () {
                  _dismissCoachMark();
                  setState(() => _filter = _filter.showNone());
                },
                // NOT behind `_dismissCoachMark`: the mark teaches the
                // domain filter, and tidying the sheet is not evidence
                // that anybody has read it.
                tidyCount: TidySheetCommand.wouldReflow(_doc),
                onTidySheet: () => unawaited(_tidySheet()),
              ),
              if (widget.showFilterCoachMark)
                CoachMark(
                  headline: kCoachMarkSchematicFilterText,
                  detail: kCoachMarkSchematicFilterDetail,
                  onDismiss: _dismissCoachMark,
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
                unlandedHomeRuns: unlandedHomeRunIds(_doc).length,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The chip, placed beside the pin it is about.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// CLAMPED INTO THE VIEWPORT, BECAUSE THE ANCHOR CAN BE OFF-SCREEN
  /// ═══════════════════════════════════════════════════════════════════
  /// The pin is wherever the sheet put it and the user is wherever they
  /// panned to, so a chip placed at the raw projected point is a chip
  /// that can land entirely outside the canvas — on the very gesture
  /// whose whole subject is telling the user something. Both axes are
  /// clamped to the canvas box, so it is always readable and always as
  /// near the pin as the box allows.
  ///
  /// ABOVE THE PIN WHERE THERE IS ROOM, below it where there is not. The
  /// chip is up to three lines and a button row; hanging it below by
  /// default would cover the candidate rings the user is about to Tab
  /// through, which are the affordance the chip is handing them back to.
  Widget _chipAnchor(BoxConstraints constraints, SpringBackChip chip) {
    const width = 360.0;
    // A generous estimate rather than a measurement: this only decides
    // WHICH SIDE of the pin the chip hangs from, and the clamp below
    // catches the case where the guess was wrong by making it fit
    // anyway. Measuring would need a layout pass this placement cannot
    // wait for.
    const estimatedHeight = 150.0;
    const gap = 12.0;

    final scene = _scene;
    final at = _chipAt;
    final pin = scene == null || at == null ? null : locatePin(scene, at);
    final anchor = pin == null
        ? DPt(constraints.maxWidth / 2, constraints.maxHeight / 2)
        : _viewport.sceneToScreen(pin.centre);

    final above = anchor.y - estimatedHeight - gap;
    final top = above >= 0 ? above : anchor.y + gap;
    return Positioned(
      left: (anchor.x - width / 2).clamp(
        0.0,
        math.max(0, constraints.maxWidth - width),
      ),
      top: top.clamp(0.0, math.max(0, constraints.maxHeight - estimatedHeight)),
      width: width,
      child: SpringBackChipCard(
        chip: chip,
        // `[ Connect anyway ]` IS THE SAME COMMIT with tier 2 skipped —
        // see [_commitWire]'s `overriding`. Not a second builder.
        onConnectAnyway: () => _commitWire(overriding: true),
        onPickAnother: _dismissChip,
        onRemedy: _applyRemedy,
        // `[ Why? ]` (`#875`). DR-114 §11.113.3 made the button optional
        // and absent when this is null, and `#296` built both the viewer
        // and the `RuleMeta.rationale` under it. Nothing supplied it, so
        // the deeper explanation this chip's own header promises was
        // reachable from nowhere.
        onWhy: () {
          // NOT AWAITED, and not wrapped: the viewer is read-only, so
          // nothing here depends on it closing.
          showWhyRuleDialog(context: context, ruleId: chip.ruleId);
        },
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
              // THE FIELD, NOT A FRESH INSTANCE. See `_handler`'s own doc
              // comment: the detector re-reads this on every pointer event,
              // so constructing one here handed the release to an object
              // that had never seen the press.
              handler: _handler,
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
                  // CR-102's band, over the sheet and hit-testing nothing.
                  // SCREEN CHROME AND NEVER A SCENE OP: `buildSchematic
                  // Scene` feeds the PDF as well as this display (CR-086),
                  // so a band in the scene would print.
                  MarqueeBand(
                    marquee: _marquee,
                    viewport: _viewport,
                    color: scheme.primary,
                  ),
                  // §11.186.8's ghost, UNDER the pin badges and over the
                  // band, for the band's reason: a scene op would print.
                  DragGhostLayer(
                    box: _symbolDrag?.at,
                    viewport: _viewport,
                    color: scheme.primary,
                  ),
                  // DR-186 §11.185.3's 📌, over the sheet and hit-testing
                  // nothing, for the band's reason: a scene op would print.
                  PinBadgeLayer(
                    symbols: _pinnedBodies(),
                    viewport: _viewport,
                    color: scheme.onSurface,
                  ),
                  // The transient status line, where the rack canvas puts
                  // its own (`rack_canvas_screen.dart`'s bottom-left
                  // `IgnorePointer`/`AnimatedBuilder` pair). NO static help
                  // text under it: the rack's slot doubles as a keymap
                  // reminder, and this screen already states what it is not
                  // showing in `_SchematicStatusStrip` — a second permanent
                  // sentence over the sheet would be chrome, not feedback.
                  //
                  // `IgnorePointer`, so the line can never intercept a
                  // press meant for the canvas underneath it — which on a
                  // screen whose whole subject is a refused gesture would be
                  // a memorable way to refuse one.
                  // THE CHIP, OVER THE SHEET AND UNDER THE STATUS LINE.
                  // Anchored at the pin the cable sprang back off, which
                  // is what `design-ux-schematic.md §2.1` asks for: *"an
                  // inline chip appears anchored at the target"*. The
                  // refusal mark under it is drawn by the overlay, so the
                  // chip and the pin it is about are joined by a colour
                  // rather than by a leader line the canvas would have to
                  // route.
                  if (_chip case final chip?) _chipAnchor(constraints, chip),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _status,
                        builder: (context, _) {
                          final text = _status.text;
                          if (text == null) return const SizedBox.shrink();
                          return Text(
                            text,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          );
                        },
                      ),
                    ),
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
    // Recorded on every layout, not only the first: [_revealNow] needs a
    // viewport to frame against and runs long after `_framed` is true.
    _lastViewportSize = viewportSize;
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

/// Turns a pointer press into either a CLICK or a CABLE, decided once at
/// the press by what is under it.
///
/// ═════════════════════════════════════════════════════════════════════
/// THE BRANCH IS AT `beginDrag`, AND IT CANNOT BE ANYWHERE ELSE
/// ═════════════════════════════════════════════════════════════════════
/// A press on a pin draws a cable; a press anywhere else selects. Deciding
/// that at RELEASE — "did this end on a pin?" — would mean every drag
/// across the sheet was potentially a cable, so nothing could be previewed
/// until it was already over, which is the one thing a rubber band is for.
/// Deciding it per-move would let one gesture change identity under the
/// user's finger.
///
/// So the decision is made once, from the press point, and the gesture
/// keeps that identity for its whole life — which is also what lets the
/// two paths take SEPARATE claims from the screen's arbiter
/// (`_PointerGesture.canvasDrag` vs `.connectDrag`) rather than sharing
/// one and having to remember which they are.
///
/// A PIN THAT CANNOT ARM FALLS BACK TO A CLICK. [onConnectBegin] returns
/// false for a full pin or one no cable can leave, and the press then
/// behaves exactly as it did before Phase 3 — it selects the device. The
/// alternative, a dead press that does nothing because it landed 3 px
/// inside a jack, is the silent no-op docs/04 §3.4 forbids.
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
/// ONE INSTANCE PER `State`, held in `_handler` and NEVER constructed in
/// `build` — the per-drag state below is why. See that field's doc comment
/// for the defect that made the hoist a fix rather than a tidy-up.
final class _SchematicClickHandler implements CanvasIntentHandler {
  _SchematicClickHandler({
    required this.viewport,
    required this.slopPx,
    required this.onClick,
    required this.requestFocus,
    required this.claim,
    required this.release,
    required this.pinAt,
    required this.landingAt,
    required this.onLandingBegin,
    required this.claimConnect,
    required this.releaseConnect,
    required this.onConnectBegin,
    required this.onConnectUpdate,
    required this.onConnectCommit,
    required this.onConnectCancel,
    required this.marquee,
    required this.onMarqueeCommit,
    required this.symbolAt,
    required this.onSymbolDragBegin,
    required this.onSymbolDragUpdate,
    required this.onSymbolDragCommit,
    required this.onSymbolDragCancel,
  });

  final ViewportController viewport;
  final double slopPx;
  final void Function(DPt scenePoint) onClick;
  final VoidCallback requestFocus;

  /// Which pin a press landed on, or null for body/empty canvas. THE
  /// BRANCH POINT of this whole class — see [beginDrag].
  final PinRef? Function(DPt scenePoint) pinAt;

  /// A home run whose pennant is under the scene point, and which end of
  /// it a press would write (`#719`, `#725`). Asked ONLY when [pinAt]
  /// found nothing, so a pin always wins: a pennant sits beside its pin
  /// and the boxes touch, and DR-073 §11.72.4 makes the rarer act give
  /// way to the commoner one.
  final RunEndGrab? Function(DPt scenePoint) landingAt;

  /// Arms a landing or a move. Same contract as [onConnectBegin]: false
  /// hands the press back to the ordinary click claim.
  final bool Function(RunEndGrab grab) onLandingBegin;

  /// The arbiter, for the connect gesture's own claim. SEPARATE FROM
  /// [claim] because they are separate gestures: a connect that is refused
  /// must not release a click's claim, and `_PointerGesture`'s two values
  /// are what make that an identity comparison rather than a guess.
  final bool Function() claimConnect;
  final VoidCallback releaseConnect;

  /// Arms a cable from a `PinRef`; false when nothing armed (a full pin, or
  /// one no cable can leave), in which case the press stays a click.
  final bool Function(PinRef ref) onConnectBegin;
  final void Function(DPt scenePoint) onConnectUpdate;

  /// `moved` is whether the gesture ever left the click slop — see
  /// `_releaseWireAt`, where a tap on a pin is a cancel and not a cable.
  final void Function(DPt scenePoint, {required bool moved}) onConnectCommit;
  final VoidCallback onConnectCancel;

  /// Asks the screen's arbiter for the canvas; false means another
  /// pointer-driven gesture is already live and this one starts NOTHING.
  /// The refusal is reported by the arbiter, not swallowed here.
  /// CR-102's band (DR-139 §11.138, PLAN-E/6).
  ///
  /// A press that answers NO PIN and NO LANDING is either a click or a
  /// marquee, and this class already knows which by the time it commits:
  /// under the slop it is a click, over it, it was a drag. That drag did
  /// nothing before this chapter.
  final MarqueeController marquee;

  /// Applies whatever the band caught. The screen owns the selection.
  final VoidCallback onMarqueeCommit;

  /// The symbol BODY under a press, or null (DR-187 §11.186.4, `#918`).
  ///
  /// ASKED LAST OF THE FOUR, and the order is the whole arbitration: a pin
  /// sits ON a symbol and a pennant beside one, so either answering first
  /// keeps the gesture it already had. What this steals is only from the
  /// MARQUEE, which is the one gesture that was doing nothing useful on a
  /// symbol body: a band begun on a symbol could only ever catch that
  /// symbol and whatever it was dragged over.
  final Uuid? Function(DPt scenePoint) symbolAt;

  /// Arms a symbol drag; false hands the press back to the marquee, on
  /// [onConnectBegin]'s contract exactly.
  ///
  /// **THE PRESS POINT IS PASSED AND NOT LOOKED UP.** The screen's
  /// `_lastScenePointer` comes from `onHover`, and a touch or a stylus
  /// never hovers: reading it here would make the gesture work on a mouse
  /// and refuse silently on a touchscreen, which is AC-016 #23's rule
  /// arrived at through the back door.
  final bool Function(Uuid id, DPt sceneStart) onSymbolDragBegin;
  final void Function(DPt scenePoint) onSymbolDragUpdate;
  final void Function(DPt scenePoint) onSymbolDragCommit;
  final VoidCallback onSymbolDragCancel;

  final bool Function() claim;

  /// Gives the claim back. Called on exactly the paths that took it.
  final VoidCallback release;

  DPt? _start;
  double _travelPx = 0;

  /// The ONE gesture whose [beginDrag] this handler GRANTED and whose
  /// terminal callback has not arrived yet — "the gesture the claim is
  /// being held for" — or null when the handler holds no claim.
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// THE WHOLE ARBITRATION IS THIS FIELD, AND IT IS A TOKEN, NOT A BOOL
  /// ═════════════════════════════════════════════════════════════════
  /// A refused begin is still a begin as far as the caller is concerned, so
  /// `CanvasIntentHandler`'s "exactly one of commitDrag/cancel PER
  /// beginDrag" owes it a terminal callback too — and that callback must
  /// not be mistaken for the WINNER's, or it clears [_start] and calls
  /// [release], handing the canvas away from a pointer that is still
  /// physically down. That is the "a refused gesture's teardown frees the
  /// winner's claim" failure `_releasePointerGesture`'s identity check
  /// exists to prevent, arriving through the one door that check cannot see
  /// (both gestures carry the same `_PointerGesture` value while this
  /// screen has one route).
  ///
  /// THIS WAS TWO BOOLS — `_owns` plus a `_refusedPending` latch — and two
  /// bools cannot answer the question. `_owns` said THAT a gesture was live
  /// but never WHICH, so with a refusal outstanding a bare `commitDrag()`
  /// had to be GUESSED at, and each guess lost something the other kept:
  /// spending the latch first ate the winner's own release (its click
  /// vanished and its claim leaked), checking ownership first freed the
  /// winner's claim on the refused gesture's teardown instead, and a bool
  /// cannot count, so a second simultaneous refusal fell through whichever
  /// branch was left and ran [_reset] under the live winner. Nothing in
  /// `CanvasIntentHandler` orders two gestures' terminals, so no ordering
  /// rule could have been right.
  ///
  /// With one token per begin (`CanvasGestureToken`, minted by the caller)
  /// the question stops being "which of my outstanding gestures is this?"
  /// and becomes "is this THE one holding the claim?" — an identity
  /// comparison with no ordering and no counting in it. Every other token
  /// is a callback this handler owes a NO-OP: a refused begin's, a repeat,
  /// or one from a detector that was unmounted and replaced mid-press.
  /// A REFUSAL THEREFORE NEEDS NO LATCH AT ALL, which is why there is none
  /// here — the state a latch would have had to be cleared out of
  /// (`rack_canvas_screen.dart:1743`'s `_dragRefused = false`, whose
  /// omission let a refusal outlive its own gesture) does not exist.
  CanvasGestureToken? _owned;

  /// Whether the gesture [_owned] names is a CABLE rather than a click.
  ///
  /// Set once in [beginDrag] and read by the other three callbacks, so a
  /// gesture cannot change identity halfway through — see the class doc.
  bool _connecting = false;

  /// The symbol this gesture is moving, or null (`#918`).
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// IT SHARES THE CANVAS CLAIM RATHER THAN TAKING A THIRD
  /// ═════════════════════════════════════════════════════════════════
  /// `_PointerGesture` exists to arbitrate between gestures that can be
  /// LIVE AT THE SAME TIME on two pointers. A symbol drag and a marquee
  /// are the two halves of one branch: [beginDrag] picks between them from
  /// the press point and the loser never starts, so no press can ever hold
  /// both and a third token would be a distinction with no case behind it.
  /// A cable is different and does have its own, because a refused connect
  /// releases a claim while a click is still live.
  ///
  /// Set once, beside [_connecting], for the same reason.
  Uuid? _movingSymbol;

  @override
  void beginDrag(
    DPt sceneStart,
    Set<PointerDeviceKind> sourceKinds, {
    required CanvasGestureToken gesture,
  }) {
    // THE PIN QUESTION IS ASKED BEFORE EITHER CLAIM, because the answer
    // decides WHICH claim to ask for. It reads the scene and nothing else,
    // so it is safe to ask while another gesture holds the canvas.
    final pin = pinAt(sceneStart);
    // A PENNANT ONLY WHEN NO PIN ANSWERED. The two hit boxes touch, and a
    // press on a jack must always mean the jack: landing a run is the
    // rarer act and must never steal the commoner one (`#719`).
    final landing = pin == null ? landingAt(sceneStart) : null;
    final wantsConnect = pin != null || landing != null;
    if (!(wantsConnect ? claimConnect() : claim())) {
      // NOTHING IS TOUCHED, and nothing is remembered either. `_start` and
      // `_travelPx` belong to the gesture that owns the canvas and is still
      // mid-flight; re-initialising them here is verbatim the defect that bit
      // `rack_canvas_screen.dart` three times. This gesture is still owed a
      // terminal callback, and [_owned] is what will decline it.
      return;
    }
    _owned = gesture;
    // The keyboard bindings above are focus-scoped, so a click on the
    // sheet has to bring focus with it or `1`–`8` would work only until
    // the user touched a filter-bar button.
    requestFocus();
    _start = sceneStart;
    _travelPx = 0;
    _connecting = false;
    _movingSymbol = null;

    if (!wantsConnect) {
      // NEITHER A PIN NOR A PENNANT. A press on a symbol BODY moves it
      // (`#918`); anywhere else is a click or a band.
      final symbol = symbolAt(sceneStart);
      if (symbol != null && onSymbolDragBegin(symbol, sceneStart)) {
        // NO BAND IS ARMED. A marquee begun here would have to be
        // cancelled on the first move, and a controller that is armed and
        // then abandoned is exactly the state `commitDrag`'s own comment
        // records the rack canvas inheriting.
        _movingSymbol = symbol;
        return;
      }
      // Arming here rather than at the first move keeps the band's origin
      // exactly where the pointer went down; `MarqueeController.begin`
      // gives it no extent until something moves, so a click still draws
      // nothing.
      marquee.begin(sceneStart);
      return;
    }
    if (pin != null ? onConnectBegin(pin) : onLandingBegin(landing!)) {
      _connecting = true;
      return;
    }
    // THE ARM REFUSED. A full pin, one no cable can leave, or a run whose
    // sheet has no free jack to land it on (`#719`). The press is not
    // wasted: it hands the claim back and
    // takes the ordinary one, so it still selects on release exactly as a
    // press on the device body would. Two claims are never held at once,
    // because this runs before any pointer movement can arrive.
    releaseConnect();
    if (!claim()) {
      // Vanishingly unlikely (nothing else can have taken the canvas
      // between two synchronous lines) but not impossible to write, and a
      // gesture that proceeded without a claim is the leak this whole
      // arbiter exists to prevent.
      _owned = null;
      _start = null;
    }
  }

  @override
  void updateDrag(
    DPt sceneCurrent,
    DPt sceneDelta, {
    required CanvasGestureToken gesture,
  }) {
    // THE TOKEN, not `_owned != null`: a refused gesture's own moves would
    // otherwise be added to the WINNER's travel and turn its click into a
    // drag — the same misattribution as the terminal callbacks, arriving
    // once per frame instead of once per gesture.
    if (gesture != _owned) return;
    // Accumulated in SCREEN pixels — `slopPx` is a screen figure, and
    // comparing it against a scene delta would make the threshold 20×
    // stricter at 20× zoom.
    final scale = viewport.scale;
    _travelPx +=
        math.sqrt(sceneDelta.x * sceneDelta.x + sceneDelta.y * sceneDelta.y) *
        scale;
    // NO SLOP ON THE BAND. A click's 4 px threshold exists so that a press
    // that wobbles is still a click; a cable is already committed to being
    // a cable by where it started, and holding its band still for the
    // first 4 px would read as the gesture not having begun.
    if (_connecting) {
      onConnectUpdate(sceneCurrent);
      return;
    }
    if (_movingSymbol != null) {
      // THE SLOP APPLIES HERE AND NOT TO THE CABLE, and the asymmetry is
      // the same one the band has: a press on a symbol is USUALLY a
      // click, so a ghost that appeared on a 1 px wobble would flicker
      // under every selection. A cable is committed to being a cable by
      // where it started and has nothing to be mistaken for.
      if (_travelPx > slopPx) onSymbolDragUpdate(sceneCurrent);
      return;
    }
    // THE BAND WIDENS WITH THE POINTER. It has no slop of its own for the
    // reason stated above: `MarqueeController` withholds the extent until
    // the first update, so a press that never moves never shows one.
    if (marquee.isActive) marquee.update(sceneCurrent);
  }

  @override
  void commitDrag(DPt sceneEnd, {required CanvasGestureToken gesture}) {
    // ONE COMPARISON, AND IT IS ORDER-INDEPENDENT. A terminal for the gesture
    // holding the claim is acted on whenever it arrives — before or after any
    // number of refused gestures' own teardowns — and a terminal for anything
    // else is the no-op it is owed. See [_owned].
    if (gesture != _owned) return;
    final start = _start;
    final travelled = _travelPx;
    final connecting = _connecting;
    final moving = _movingSymbol;
    // BEFORE the outcome, so the claim's life is exactly the pointer's.
    // `CanvasIntentDetector` adopts any deferred pointer strictly after
    // this method returns — so a second finger inherits a canvas that is
    // already free.
    _reset();
    if (start == null) return;
    if (connecting) {
      // THE SAME SLOP THE CLICK USES, handed on rather than re-derived:
      // one threshold decides whether a press was a drag at all, and two
      // copies of it is how a tap becomes a cable on one path and a click
      // on the other.
      onConnectCommit(sceneEnd, moved: travelled > slopPx);
      return;
    }
    if (moving != null) {
      // UNDER THE SLOP IT WAS A CLICK, which is the behaviour a press on a
      // symbol has always had and which `#918` must not take away: the
      // commonest thing anybody does to a symbol is select it. The drag
      // is cancelled rather than committed at zero distance, so no undo
      // entry is made for a selection.
      if (travelled > slopPx) {
        onSymbolDragCommit(sceneEnd);
      } else {
        onSymbolDragCancel();
        onClick(sceneEnd);
      }
      return;
    }
    if (travelled > slopPx) {
      // A DRAG ON EMPTY SHEET IS THE MARQUEE, and it did nothing at all
      // before this chapter. The band is ended even when it caught
      // nothing, which is what makes an empty sweep a deselect.
      onMarqueeCommit();
      return;
    }
    // A CLICK, so the band never had an extent; end it anyway rather than
    // leaving the controller armed for the next gesture to inherit, which
    // is the defect the rack canvas's own adoption hit.
    marquee.cancel();
    onClick(sceneEnd);
  }

  @override
  void cancel({required CanvasGestureToken gesture}) {
    if (gesture != _owned) return; // see `commitDrag`.
    final connecting = _connecting;
    final moving = _movingSymbol;
    _reset();
    marquee.cancel();
    // A POINTER-CANCEL, NOT A RELEASE: nothing was dropped anywhere, so
    // there is nothing to evaluate and nothing to write. docs/05 §7's
    // cancel, reached through the third of its doors.
    if (connecting) onConnectCancel();
    // THE GHOST HAS TO GO EVEN THOUGH NOTHING IS WRITTEN. It is screen
    // state rather than document state, so unlike the cable there is no
    // command to decline: a cancel that only skipped the write would
    // leave a dashed rectangle on the sheet with no pointer under it.
    if (moving != null) onSymbolDragCancel();
  }

  void _reset() {
    _start = null;
    _travelPx = 0;
    _owned = null;
    if (_connecting) {
      releaseConnect();
    } else {
      // THE SYMBOL DRAG COMES BACK THROUGH HERE, because it took the
      // canvas claim and not the connect one. See [_movingSymbol].
      release();
    }
    _connecting = false;
    _movingSymbol = null;
  }
}

/// The pointer-driven gestures this screen arbitrates between (see the
/// "exclusivity rule" section in `_SchematicCanvasScreenState`).
///
/// TWO VALUES SINCE PHASE 3, WHICH IS WHEN THE IDENTITY CHECK STARTED
/// EARNING ITS KEEP. Phase 1's version of this enum had one value and its
/// own comment said so: "the rack's two values are its two pointer ROUTES,
/// and this screen still has one. Phase 2's connect gesture is armed on a
/// pin and tracked separately, which is the second value — and the moment
/// it exists `_releasePointerGesture`'s identity check starts doing work no
/// latch in the handler can do for it."
///
/// That moment is now. A connect drag and a click/marquee drag are two
/// different claims on one canvas, so `_releasePointerGesture`'s "a no-op
/// when the gesture is not the one holding it" is no longer a rule about a
/// case that cannot arise — it is what stops a refused connect's teardown
/// from freeing the claim a live click is holding, and vice versa.
enum _PointerGesture {
  /// The press/click (and, when it lands, the marquee) delivered by
  /// `CanvasIntentDetector`.
  canvasDrag,

  /// A press that landed ON A PIN and armed a cable — docs/05 §7's
  /// `WIRE_DRAG`.
  connectDrag,
}

/// A real [Action] whose enablement is a predicate evaluated FRESH ON EVERY
/// KEYPRESS — `rack_canvas_screen.dart`'s `_GatedAction`, ported.
///
/// ═════════════════════════════════════════════════════════════════════
/// WHY A `CallbackAction` CANNOT DO THIS
/// ═════════════════════════════════════════════════════════════════════
/// `Action.consumesKey` defaults to `true` and `toKeyEventResult` maps that
/// to `KeyEventResult.handled` REGARDLESS OF WHAT THE CALLBACK RETURNS OR
/// DOES. The key is consumed before the body runs, so an early `return`
/// inside a handler stops the ACTION and still destroys the KEY.
///
/// Overriding `consumesKey => false` is ALSO not equivalent, which is the
/// counter-intuitive part: `toKeyEventResult` then returns
/// `skipRemainingHandlers`, which breaks the dispatch loop just as dead as
/// `handled`. Only `isActionEnabled == false` yields `ignored` and lets the
/// event continue up the chain — which is the ONE mechanism by which a key
/// can be LAYERED, i.e. by which this screen can decline `Esc` and let the
/// layer behind it answer.
///
/// The `enabled` predicate is a closure rather than a captured bool because
/// `ShortcutManager` re-reads `isActionEnabled` on every keypress; a
/// snapshot taken at build time would be stale the moment focus moved.
///
/// THE ONE DIFFERENCE FROM THE RACK'S COPY: its runner is a `VoidCallback`,
/// because every intent it gates is payload-free. `SoloDomainIntent` is
/// not — it carries the digit that was pressed — so the runner here takes
/// the intent. Nothing else about the shape moves.
class _GatedAction<T extends Intent> extends Action<T> {
  _GatedAction(this._enabled, this._run);

  final bool Function() _enabled;
  final void Function(T intent) _run;

  @override
  bool get isActionEnabled => _enabled();

  @override
  void invoke(T intent) => _run(intent);
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
    required this.unlandedHomeRuns,
  });

  final SchematicScene scene;
  final SchematicPaintPlan plan;
  final int deviceCount;

  /// Home runs whose RACK end is not punched down (DR-072 §11.71).
  ///
  /// SEPARATE FROM `unlabelledLinkIds` BELOW, which folds "nobody landed
  /// this" together with "this device has no symbol". Two problems, two
  /// fixes, and only one of them is something a person can go and do.
  final int unlandedHomeRuns;

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
    // FIRST OF THE EXCEPTIONS, because it is the only one on this strip
    // that names a job rather than a limitation of the drawing.
    if (unlandedHomeRuns > 0) {
      notes.add('$unlandedHomeRuns home runs not landed at the rack');
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

/// The connect gesture's chrome colours, from the theme.
///
/// THEME ROLES, BECAUSE EVERY COLOUR IN HERE IS CHROME. A caret, a source
/// ring, a band and a selection all mark WHERE THE USER IS or WHAT THEY
/// PICKED. That is a cursor: not a signal, never printed, and it has to
/// read against whatever theme its owner chose, which `primary`,
/// `tertiary` and `secondary` do in both brightnesses.
///
/// THE ONE COLOUR THAT IS NOT CHROME IS DELIBERATELY NOT A FIELD HERE.
/// [kSpringBackRingArgb] states what a RULE decided, so DR-114 §11.113.2
/// fixes it at docs/05 §8's `#E69F00` rather than letting a theme move it,
/// and gives it no knob so nobody can pass `scheme.error` and make the
/// product's verdict colour a preference.
///
/// THIS COMMENT USED TO REFUSE THE FIXED HEXES WHOLESALE, on the ground
/// that `#F0E442` and `#E69F00` are both *"PAL-1 colours belonging to the
/// signal taxonomy"*. §11.113.1 measured that and it is half wrong:
/// `#F0E442` is **PAL-2's** reserved selection-and-focus colour and is
/// *"never a cable"*, so docs/05 specified the candidate ring in it
/// precisely because it is reserved for this use, and refusing it was
/// obedience to a rule the corpus does not have. Only the second half
/// held, and §8's own severity table crosses that line on purpose with
/// shape and badge as the discriminator rather than hue.
ConnectOverlayStyle _connectOverlayStyle(ColorScheme scheme) =>
    ConnectOverlayStyle(
      caretArgb: _argbOfColor(scheme.primary),
      sourceArgb: _argbOfColor(scheme.tertiary),
      bandArgb: _argbOfColor(scheme.primary),
      // Quieter than the caret on purpose: a hundred of these can be on
      // screen at once and they are a FIELD, not a cursor.
      candidateArgb: _argbOfColor(scheme.primary.withValues(alpha: 0.45)),
      // The DEVICE selection's own colour, because a run of jacks is a
      // selection and reads as one — the same role `scheme.secondary`
      // plays for a selected symbol. Deliberately not the caret's
      // `primary` or the source's `tertiary`: a selected pin is neither
      // the cursor nor the thing a cable is currently leaving.
      selectionArgb: _argbOfColor(scheme.secondary),
    );

/// The theme-derived symbol palette.
///
/// `SchematicPalette` is packed ARGB and never a Flutter `Color`, which is
/// what keeps every piece of geometry in `rackpal_core` where the PDF
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
