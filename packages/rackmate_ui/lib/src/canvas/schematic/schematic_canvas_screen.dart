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

import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show PointerDeviceKind, PointerExitEvent, PointerHoverEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyEvent, LogicalKeyboardKey;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/canvas_intent.dart';
import 'package:rackmate_ui/src/canvas/grid_painter.dart';
import 'package:rackmate_ui/src/canvas/schematic/connect_overlay.dart';
import 'package:rackmate_ui/src/canvas/schematic/domain_filter_bar.dart';
import 'package:rackmate_ui/src/canvas/schematic/render_schematic_canvas.dart';
import 'package:rackmate_ui/src/canvas/schematic/schematic_filter.dart';
import 'package:rackmate_ui/src/canvas/schematic/schematic_paint_plan.dart';
import 'package:rackmate_ui/src/canvas/selection_controller.dart';
import 'package:rackmate_ui/src/canvas/status_message_controller.dart';
import 'package:rackmate_ui/src/canvas/viewport_controller.dart';
import 'package:rackmate_ui/src/keymap/keymap.dart';

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
    claimConnect: () => _claimPointerGesture(_PointerGesture.connectDrag),
    releaseConnect: () =>
        _releasePointerGesture(_PointerGesture.connectDrag),
    onConnectBegin: _beginWireAt,
    onConnectUpdate: _dragWireTo,
    onConnectCommit: _releaseWireAt,
    onConnectCancel: _cancelWire,
  );

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

  /// Whether the viewport has already been framed on this sheet.
  bool _framed = false;

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
  PinRef? _wireFrom;

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

  /// Where a POINTER drag's band currently ends when the magnet has not
  /// caught a pin — the raw cursor, in scene space. Null whenever
  /// [_pinCaret] is the band's target, which is always true of the
  /// keyboard route: a caret is already exactly on a pin, so there is no
  /// unsnapped state for it to be in.
  DPt? _freeEnd;

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
    // `wires` gets its OWN callback, and that is DR-011.4 — see
    // [_holdLayoutForEpoch]. It is the one epoch whose bump must not move
    // a symbol.
    widget.controller.epochs.wires.addListener(_onWiresChanged);
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
    widget.controller.epochs.wires.removeListener(_onWiresChanged);
    widget.controller.epochs.meta.removeListener(_onDocumentChanged);
    widget.controller.epochs.sheet.removeListener(_onDocumentChanged);
    widget.controller.epochs.style.removeListener(_onDocumentChanged);
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
    if (_wireFrom != null) {
      _wireFrom = null;
      _candidates = const <PinRef>[];
      what ??= 'Wire';
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
    final built = buildSchematicScene(
      doc: _doc,
      measurer: widget.measurer,
      palette: palette,
      netLabelStyle: NetLabelStyle(theme: theme),
      // DR-011.4 — see [_holdLayoutOnNextBuild]. A hold is a layout INPUT
      // and never a document write, which is the whole reason the ruling
      // chose this shape over pinning every symbol into CR-117's byte
      // surface.
      holdAt: _holdLayoutOnNextBuild ? _heldPositions : const <Uuid, Pt>{},
    );
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
  /// A REAL HIT TEST NOW — `SymbolHitTest`, the query `rackmate_core` ships
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
    if (_wireFrom != null) {
      _cancelWire();
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
  bool _armWireFrom(PinRef caret) {
    final scene = _scene;
    if (scene == null) return false;
    final from = _targetFor(caret);
    if (from == null) {
      _status.show('That pin is no longer in this document.');
      return false;
    }

    // EVERY OTHER PIN ON THE SHEET, RUN THROUGH THE REAL RULES. Not a
    // compatibility guess: `evaluateConnect` is TOP-001..005 and nothing
    // else, because docs/02 §5's tier table defers all six T2 rules
    // (SIG-001, DIR-001, CON-001 …) to M5 and canon §5 opens with "a rule
    // not listed here does not exist". A pin that is merely a BAD idea —
    // an HDMI output into an RJ45 jack — is therefore a candidate here,
    // and that is correct for M2: G2 and CR-017 rule that a model which
    // cannot draw a mistake cannot document reality.
    final candidates = <PinRef>[];
    for (final pin in locatePins(scene)) {
      if (pin.ref == caret) continue;
      final to = _targetFor(pin.ref);
      if (to == null) continue;
      if (evaluateConnect(_doc, from, to) is ConnectAllowed) {
        candidates.add(pin.ref);
      }
    }

    if (candidates.isEmpty) {
      // ARMING WITH NOTHING TO AIM AT IS A MODE WITH NO EXIT BUT `Esc`.
      // Refused, with the reason, rather than entered — and the sentence
      // names the pin, per DR-011.5's rule for refusals.
      _status.show(
        'No pin on this sheet can take a cable from ${_saying(caret)}.',
      );
      return false;
    }

    setState(() {
      _wireFrom = caret;
      _candidates = List<PinRef>.unmodifiable(candidates);
    });
    _status.show(
      'Wire from ${_saying(caret)} — ${candidates.length} '
      '${candidates.length == 1 ? 'pin' : 'pins'} can take it. '
      'Drag or Tab to choose, release or Enter to commit, Esc to cancel.',
    );
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
  //  * THE AMBER "would spring back" RING (§7.3). There is no spring-back
  //    tier in M2 — see `ConnectOverlayStyle.candidateArgb`.
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

  /// A press landed on [ref]: arm a wire from it, exactly as `W` does.
  ///
  /// Returns false when nothing armed — an already-full pin, or one no
  /// cable can leave — so the handler can fall back to treating the press
  /// as an ordinary click rather than starting a drag with nothing in it.
  bool _beginWireAt(PinRef ref) {
    setState(() => _pinCaret = ref);
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
    );
    if (snapped?.ref == _pinCaret && _freeEnd == null) return;
    setState(() {
      _pinCaret = snapped?.ref;
      _freeEnd = snapped == null ? scenePoint : null;
    });
    if (snapped != null) _announceCaret();
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
    if (!moved) {
      _cancelWire();
      return;
    }

    final tolerance = _snapTolerance(scene);
    final onCandidate = snapToPin(
      scene,
      scenePoint,
      tolerance: tolerance,
      among: _candidates,
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
      _wireFrom = null;
      _candidates = const <PinRef>[];
      _freeEnd = null;
    });
  }

  /// `Enter` — commit the wire in flight (docs/05 §7, DR-011.6).
  void _commitWire() {
    final from = _wireFrom;
    final to = _pinCaret;
    if (from == null || to == null) return;
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
    final ConnectPortsResult result;
    try {
      result = buildConnectPortsCommand(
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
      case ConnectPortsRefused(:final ruleId, :final message):
        // DR-011.5: T1 refuses OUTRIGHT — there is no [ Connect anyway ],
        // because docs/02:854 gives T1's escape as "None. There is nothing
        // to escape to", and M2 would otherwise ship a way to persist a
        // topology violation two milestones before M5's validation exists
        // to flag it. The rule id AND a sentence naming real designators,
        // both, because "TOP-003" alone is a log line.
        _status.show('$ruleId — $message');
      case ConnectPortsReady(:final command, :final roleMismatch):
        widget.controller.run(command);
        // THE CARET STAYS ON THE SINK. This is the M1 refutation's lesson
        // applied: the next `W` starts from where the user is looking, so
        // back-to-back cables are W-arrows-Enter, W-arrows-Enter with no
        // round trip through a selection.
        setState(() {
          _wireFrom = null;
          _candidates = const <PinRef>[];
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
        final fromSaid = '${fromTarget.deviceDesignator} '
            '${command.from.designator}';
        final toSaid = '${toTarget.deviceDesignator} '
            '${command.to.designator}';
        final warning = roleMismatch == null
            ? ''
            : ' — but $fromSaid is the "${roleMismatch.fromRole}" leg and '
                  '$toSaid is the "${roleMismatch.toRole}" leg, so this '
                  'cable carries no role';
        _status.show(
          '${command.designator} connected $fromSaid to $toSaid$warning.',
        );
    }
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
    );
    final plan = buildSchematicPaintPlan(
      scene: scene,
      doc: _doc,
      filter: _filter,
      scope: scope,
      measurer: widget.measurer,
      palette: palette,
      groundArgb: _argbOfColor(scheme.surfaceContainerLowest),
      overlayOps: overlay.ops,
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
          FocusSelectionIntent: _GatedAction<FocusSelectionIntent>(
            () => _canvasKeysEnabled,
            (_) => _toggleFocus(),
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
                (_wireFrom != null ||
                    _focused.isNotEmpty ||
                    _selection.isNotEmpty),
            (_) => _onEscape(),
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
          PreviousCandidatePinIntent:
              _GatedAction<PreviousCandidatePinIntent>(
                () => _canvasKeysEnabled && _wireFrom != null,
                (_) => _cycleCandidate(step: -1),
              ),
          MovePinCaretIntent: _GatedAction<MovePinCaretIntent>(
            () => _canvasKeysEnabled,
            (intent) => _movePinCaret(intent.direction),
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
    required this.claimConnect,
    required this.releaseConnect,
    required this.onConnectBegin,
    required this.onConnectUpdate,
    required this.onConnectCommit,
    required this.onConnectCancel,
  });

  final ViewportController viewport;
  final double slopPx;
  final void Function(DPt scenePoint) onClick;
  final VoidCallback requestFocus;

  /// Which pin a press landed on, or null for body/empty canvas. THE
  /// BRANCH POINT of this whole class — see [beginDrag].
  final PinRef? Function(DPt scenePoint) pinAt;

  /// The arbiter, for the connect gesture's own claim. SEPARATE FROM
  /// [claim] because they are separate gestures: a connect that is refused
  /// must not release a click's claim, and `_PointerGesture`'s two values
  /// are what make that an identity comparison rather than a guess.
  final bool Function() claimConnect;
  final VoidCallback releaseConnect;

  /// Arms a cable from [PinRef]; false when nothing armed (a full pin, or
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
    final wantsConnect = pin != null;
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

    if (!wantsConnect) return;
    if (onConnectBegin(pin)) {
      _connecting = true;
      return;
    }
    // THE PIN REFUSED TO ARM — full, or nothing on the sheet can take a
    // cable from it. The press is not wasted: it hands the claim back and
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
    if (_connecting) onConnectUpdate(sceneCurrent);
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
    if (travelled > slopPx) return;
    onClick(sceneEnd);
  }

  @override
  void cancel({required CanvasGestureToken gesture}) {
    if (gesture != _owned) return; // see `commitDrag`.
    final connecting = _connecting;
    _reset();
    // A POINTER-CANCEL, NOT A RELEASE: nothing was dropped anywhere, so
    // there is nothing to evaluate and nothing to write. docs/05 §7's
    // cancel, reached through the third of its doors.
    if (connecting) onConnectCancel();
  }

  void _reset() {
    _start = null;
    _travelPx = 0;
    _owned = null;
    if (_connecting) {
      releaseConnect();
    } else {
      release();
    }
    _connecting = false;
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

/// The connect gesture's chrome colours, from the theme.
///
/// THEME ROLES, NOT THE SIGNAL PALETTE. docs/05 §7 gives the illumination
/// figures in fixed hex — `#F0E442` for a compatible port, `#E69F00` for
/// one that would spring back — and those are PAL-1 colours belonging to
/// the signal taxonomy, resolved by `pal1_check.py` and the registry parity
/// gate. This overlay is a CURSOR: it is not a signal, it is not printed,
/// and borrowing a family hue for it would put chrome inside the one
/// palette three gates exist to keep honest. `primary` and `tertiary` move
/// with the user's own theme and read in both brightnesses, which is what a
/// caret needs.
ConnectOverlayStyle _connectOverlayStyle(ColorScheme scheme) =>
    ConnectOverlayStyle(
      caretArgb: _argbOfColor(scheme.primary),
      sourceArgb: _argbOfColor(scheme.tertiary),
      bandArgb: _argbOfColor(scheme.primary),
      // Quieter than the caret on purpose: a hundred of these can be on
      // screen at once and they are a FIELD, not a cursor.
      candidateArgb: _argbOfColor(scheme.primary.withValues(alpha: 0.45)),
    );

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
