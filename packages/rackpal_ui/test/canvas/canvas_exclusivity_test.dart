// Widget tests for `RackCanvasScreen`'s EXCLUSIVITY and INVALIDATION rules —
// the two halves of "only one interaction may be live, and every live one
// dies the moment its premise does" (see that file's own "the exclusivity
// rule, in one place" section).
//
// WHY A FILE OF ITS OWN. Four preview-then-commit interactions coexist on
// that screen (palette drag §3.1, move drag §3.3, compaction preview §3.6,
// top-edge resize §4.1) and every previous stage found the same defect again
// in a new pair of them: a second pointer re-initialising state a live
// interaction still owned, or a live interaction outliving the document
// snapshot it was computed against. The per-gesture files each test ONE
// gesture working; nothing tested the gestures against EACH OTHER. These do.
//
// EVERY CASE HERE IS DRIVEN BY REAL, SIMULTANEOUS POINTERS — two
// `TestGesture`s with distinct pointer ids, overlapping in time — and real
// `sendKeyEvent` sequences. A test that called `_onBeginDrag` twice by hand
// would prove nothing about whether the routing can even deliver that.

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../app_like.dart';

import 'rack_scene_to_screen.dart';

final class _FakeMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

// The demo rack is 12U: UPS-1 @U1 (2U), AMP-1 @U4 (2U), SW-1 @U7 (1U) on the
// front, PP-1 @U9 (1U) on the rear.
const _geo = RackGeometry(12);

Widget _app() => MaterialApp(
  // DR-159 §11.158.3: undo and redo are GLOBAL bindings, so a
  // screen pumped without the root's map is a configuration
  // the product does not ship. See test/app_like.dart.
  shortcuts: appGlobalShortcuts(),
  home: Scaffold(body: RackCanvasScreen(measurer: _FakeMeasurer())),
);

Offset _centreOf(WidgetTester tester, int ru, int deviceH) =>
    centreOfRu(tester, _geo, ru, deviceH);

Finder _device(String id) => find.descendant(
  of: find.byKey(ValueKey(id)),
  matching: find.byType(DeviceBox),
);

/// The leaf render object, located by its own deviceId getter — see
/// rack_canvas_screen_test.dart's copy.
RenderDeviceBox _render(WidgetTester tester, String id) =>
    tester.allRenderObjects.whereType<RenderDeviceBox>().firstWhere(
      (r) => r.deviceId == id,
    );

double _topOf(WidgetTester tester, String id) =>
    tester.getTopLeft(_device(id)).dy;

/// Where a device's top edge WOULD be if it sat at [ru] on the 12U demo
/// rack.
double _expectedTop(WidgetTester tester, int ru, int deviceH) =>
    topLeftOfRu(tester, _geo, ru, deviceH).dy;

/// A point inside docs/04 §4.1's 8px top-edge grab band.
///
/// Scene y == 0 IS the rack's top edge, so a couple of screen pixels below
/// where scene y == 0 LANDS is inside the band. The band is 8 SCREEN px,
/// so the offset stays in screen units while the anchor comes through the
/// viewport (`#710`): x == 200 in scene units is within the rack's own
/// width and clear of the floating chrome, all of which is at y >= 12.
Offset _topEdgeGrab(WidgetTester tester) =>
    sceneToScreen(tester, 200, 0) + const Offset(0, 2);

/// Searches the palette and returns the matching row's centre.
Future<Offset> _paletteRow(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'Blank Panel');
  await tester.pumpAndSettle();
  final row = find.widgetWithText(ListTile, 'Blank Panel, 1U');
  expect(row, findsOneWidget);
  return tester.getCenter(row);
}

/// See rack_canvas_screen_test.dart's own copy: the palette row's
/// double-tap recogniser starts an internal timer on every pointer-down
/// that the binding insists has resolved before a test ends.
Future<void> _settleDoubleTap(WidgetTester tester) =>
    tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));

Future<void> _ctrlZ(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<void> _headerMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

/// §3.6's floating bar, asked via its Apply button — see
/// rack_compaction_test.dart for why not by its label text.
final Finder _compactionBar = find.widgetWithText(FilledButton, 'Apply');

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  group('rule 1 — at most one pointer-driven gesture', () {
    testWidgets('a second CANVAS pointer cannot orphan a live resize '
        'preview: the preview survives it and still commits on the first '
        "pointer's release", (tester) async {
      // The finding's own scenario. Finger A grabs the rack's top edge and
      // crosses the 4px threshold, arming the resize preview. Finger B taps
      // the canvas. Before the guard, B's pointer-down re-entered
      // `_onBeginDrag` and cleared `_resizeDrag`/`_dragDeviceId`, leaving
      // `_resize.isActive` stuck TRUE for the rest of the session — the red
      // hatch painted forever, every future drag ghost and compaction
      // preview suppressed by the painter's resize-first precedence, and Esc
      // swallowed by `_onEscape`'s resize-first branch.
      await tester.pumpWidget(_app());
      await tester.pump();

      final a = await tester.startGesture(_topEdgeGrab(tester), pointer: 1);
      await a.moveBy(sceneDelta(tester, 0, 3 * RackGeometry.unitsPerRu));
      await tester.pump();
      expect(
        find.text('9U (-3)'),
        findsOneWidget,
        reason: "§4.1's readout proves the preview armed",
      );

      final b = await tester.startGesture(
        emptyCanvasPoint(tester),
        pointer: 2,
      );
      await tester.pump();
      await b.up();
      await tester.pump();

      expect(
        find.text('9U (-3)'),
        findsOneWidget,
        reason: "the second pointer must not touch the first gesture's state",
      );

      await a.up();
      await tester.pump();

      // The preview came down on ITS OWN pointer's release, and the height
      // the readout promised is the height that landed.
      expect(find.text('9U (-3)'), findsNothing);
      expect(find.text('9U'), findsWidgets, reason: 'the header stepper');
      expect(
        _topOf(tester, 'dev-ups'),
        closeTo(
          topLeftOfRu(tester, const RackGeometry(9), 1, 2).dy,
          0.5,
        ),
      );
    });

    testWidgets('a top-edge grab is REFUSED while a palette drag is live — '
        'and says so — so the two previews never run at once', (tester) async {
      // The cross-route half, which no single detector can see: a palette
      // drag is armed from a SIBLING widget and tracked through the global
      // pointerRouter, so `CanvasIntentDetector`'s own single-gesture guard
      // is blind to it. Both previews used to run together, and
      // `EditingOverlayPainter`'s resize-first precedence then blanked the
      // palette drag's ghost, snap line and blocked hatch while it was still
      // live — so its release committed a placement no feedback was shown
      // for.
      await tester.pumpWidget(_app());
      await tester.pump();
      final before = tester.widgetList(find.byType(DeviceBox)).length;

      final row = await _paletteRow(tester);
      final a = await tester.startGesture(row, pointer: 1);
      await a.moveBy(const Offset(320, 0));
      await tester.pump();
      await a.moveTo(_centreOf(tester, 3, 1));
      await tester.pump();
      expect(find.text('U3'), findsOneWidget, reason: 'the RU-range chip');

      final b = await tester.startGesture(_topEdgeGrab(tester), pointer: 2);
      await b.moveBy(sceneDelta(tester, 0, 3 * RackGeometry.unitsPerRu));
      await tester.pump();

      expect(
        find.text('9U (-3)'),
        findsNothing,
        reason: 'the resize preview must not arm on top of a palette drag',
      );
      expect(find.textContaining('One drag at a time'), findsOneWidget);
      expect(
        find.text('U3'),
        findsOneWidget,
        reason: "the palette drag's own live feedback is untouched",
      );

      await b.up();
      await tester.pump();
      await a.up();
      await tester.pump();

      // The refused gesture cost the surviving one nothing: the drag still
      // placed its device, and the rack kept its height.
      expect(tester.widgetList(find.byType(DeviceBox)).length, before + 1);
      expect(find.text('12U'), findsWidgets);
      await _settleDoubleTap(tester);
    });

    testWidgets('the claim is RELEASED, not leaked: a completed palette drag '
        'leaves the canvas fully usable', (tester) async {
      // THE FAILURE MODE THE ARBITER ITSELF COULD INTRODUCE, and the one
      // this file's history says to test for explicitly: a latch left stuck
      // true. `_shrinkDialogOpen` and `_applyingCompaction` both carry doc
      // comments about it, and both use `finally` because of it. A claim
      // that outlived its gesture would refuse EVERY subsequent interaction
      // for the rest of the session — a far worse bug than the one the
      // arbiter fixes, and invisible to any test that performs one gesture.
      //
      // Found by mutation: removing the release from
      // `_stopTrackingPalettePointer` survived the whole suite, because
      // nothing anywhere did a palette drag and then anything else.
      await tester.pumpWidget(_app());
      await tester.pump();
      final before = tester.widgetList(find.byType(DeviceBox)).length;

      final row = await _paletteRow(tester);
      final drag = await tester.startGesture(row);
      await drag.moveBy(const Offset(320, 0));
      await tester.pump();
      await drag.moveTo(_centreOf(tester, 3, 1));
      await tester.pump();
      await drag.up();
      await tester.pump();
      expect(tester.widgetList(find.byType(DeviceBox)).length, before + 1);

      // NOW a canvas gesture, which must be allowed to claim the screen.
      await tester.tapAt(_centreOf(tester, 4, 2));
      await tester.pump();
      final move = await tester.startGesture(_centreOf(tester, 4, 2));
      await move.moveBy(sceneDelta(tester, 0, -6 * RackGeometry.unitsPerRu));
      await tester.pump();
      await move.up();
      await tester.pump();

      expect(
        _topOf(tester, 'dev-amp'),
        closeTo(_expectedTop(tester, 10, 2), 0.5),
        reason:
            'the canvas is still alive after the palette drag released '
            'its claim',
      );
      await _settleDoubleTap(tester);
    });

    testWidgets('a palette row press is REFUSED while a move drag is live, '
        'and the move still commits', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      final before = tester.widgetList(find.byType(DeviceBox)).length;

      // Select AMP-1 (U4-U5) — a move drag only arms on an ALREADY-selected
      // device — then grab it and drag it up to U10.
      await tester.tapAt(_centreOf(tester, 4, 2));
      await tester.pump();
      final a = await tester.startGesture(_centreOf(tester, 4, 2), pointer: 1);
      await a.moveBy(sceneDelta(tester, 0, -6 * RackGeometry.unitsPerRu));
      await tester.pump();
      expect(find.text('U10-U11'), findsOneWidget, reason: 'the ghost is live');

      final row = await _paletteRow(tester);
      final b = await tester.startGesture(row, pointer: 2);
      await b.moveBy(const Offset(320, 0));
      await tester.pump();
      await b.moveTo(_centreOf(tester, 3, 1));
      await tester.pump();

      expect(find.textContaining('One drag at a time'), findsOneWidget);

      await b.up();
      await tester.pump();
      await a.up();
      await tester.pump();

      expect(
        tester.widgetList(find.byType(DeviceBox)).length,
        before,
        reason: 'the refused palette drag placed nothing',
      );
      expect(
        _topOf(tester, 'dev-amp'),
        closeTo(_expectedTop(tester, 10, 2), 0.5),
        reason: 'the move that owned the screen still committed',
      );
      await _settleDoubleTap(tester);
    });

    testWidgets('a second canvas pointer is DEFERRED, not killed: once the '
        'first gesture ends it inherits the route and its drag really '
        'moves the device', (tester) async {
      // THE OVER-CORRECTION, at the level the user feels it. Refusing a
      // second contact WHILE the first is live is right; leaving it dead for
      // the rest of its life is not, and that is what dropping its
      // `PointerDownEvent` outright did — `_dragPointer` is only ever
      // assigned on pointer-DOWN, and the refused pointer's down was already
      // spent. Finger A scrubs, finger B lands on the selected UPS-1, A
      // lifts and frees the claim, and B — still physically down — then
      // dragged and released into a dead zone: its events matched neither
      // `_dragPointer` nor `_panPointer`, so no beginDrag, no move, no
      // click, no status line. Verified before the fix: UPS-1 stayed at U1.
      await tester.pumpWidget(_app());
      await tester.pump();

      // A move drag only arms on an ALREADY-selected device.
      await tester.tapAt(_centreOf(tester, 1, 2));
      await tester.pump();
      expect(_render(tester, 'dev-ups').selected, isTrue);

      // Finger A scrubs the empty canvas below the rack and holds.
      //
      // ═════════════════════════════════════════════════════════════════
      // THAT SCRUB IS A MARQUEE AS OF PLAN-E/6, AND IT USED TO BE INERT
      // ═════════════════════════════════════════════════════════════════
      // This gesture was `moveBy(30, 30)` into empty space, chosen because
      // a drag on bare canvas did nothing and the case is about POINTER
      // ROUTING rather than about selection. CR-102 gives that drag a
      // meaning (DR-139 §11.138): a band, and a band catching nothing
      // REPLACES the selection with nothing. So the old scrub deselected
      // UPS-1 and B had nothing to move, which is the marquee working and
      // an unstated premise expiring.
      //
      // A now sweeps UP AND RIGHT over UPS-1, which is a WINDOW that
      // contains it. The routing question is untouched (A starts on empty
      // canvas, holds the claim, then lifts) and the precondition B needs
      // is stated by the assertion below rather than assumed.
      final ups = tester.getRect(_device('dev-ups'));
      final a = await tester.startGesture(
        emptyCanvasPoint(tester),
        pointer: 1,
      );
      await a.moveTo(ups.topRight + const Offset(24, -24));
      await tester.pump();

      // Finger B lands on UPS-1 WHILE A still owns the screen, so it gets no
      // beginDrag — and must not disturb A either.
      final b = await tester.startGesture(_centreOf(tester, 1, 2), pointer: 2);
      await tester.pump();
      expect(
        _topOf(tester, 'dev-ups'),
        closeTo(_expectedTop(tester, 1, 2), 0.5),
        reason: 'nothing has moved yet — B is waiting, not driving',
      );

      // A releases. The claim falls free and B, still on the glass, inherits
      // it.
      await a.up();
      await tester.pump();
      expect(
        _render(tester, 'dev-ups').selected,
        isTrue,
        reason: "A's window swept UPS-1, so B has something to move",
      );

      await b.moveBy(sceneDelta(tester, 0, -10 * RackGeometry.unitsPerRu));
      await tester.pump();
      expect(find.text('U11-U12'), findsOneWidget, reason: "B's ghost is live");
      await b.up();
      await tester.pump();

      expect(
        _topOf(tester, 'dev-ups'),
        closeTo(_expectedTop(tester, 11, 2), 0.5),
        reason:
            'the second gesture is a real gesture once the first has '
            'properly ended — the single-gesture rule is about not running '
            'two AT ONCE, not about blackholing the second one forever',
      );
    });

    testWidgets('...and the deferral did not reopen the original hole: a '
        'second pointer landing mid-move still cannot steal the drag', (
      tester,
    ) async {
      // THE PIN AGAINST THE FIX ABOVE. These two requirements press on each
      // other: adopt too eagerly and the second contact re-initialises
      // `_dragPlacement`/`_dragDeviceId` out from under the FIRST pointer's
      // live ghost, which is the exact defect the guard was added for (and
      // which this file already caught once for the resize preview). B may
      // only ever be adopted AFTER A's commit has run.
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tapAt(_centreOf(tester, 4, 2));
      await tester.pump();

      // A grabs the selected AMP-1 (U4-U5) and drags it up to U10.
      final a = await tester.startGesture(_centreOf(tester, 4, 2), pointer: 1);
      await a.moveBy(sceneDelta(tester, 0, -6 * RackGeometry.unitsPerRu));
      await tester.pump();
      expect(find.text('U10-U11'), findsOneWidget);

      // B lands on a DIFFERENT device and stays down for the rest of A's
      // gesture. If it were adopted now, A's ghost would retarget UPS-1.
      final b = await tester.startGesture(_centreOf(tester, 1, 2), pointer: 2);
      await tester.pump();
      await a.moveBy(sceneDelta(tester, 0, -RackGeometry.unitsPerRu));
      await tester.pump();
      expect(
        find.text('U11-U12'),
        findsOneWidget,
        reason: "A's ghost is still A's — B contributed nothing to it",
      );

      await a.up();
      await tester.pump();
      expect(
        _topOf(tester, 'dev-amp'),
        closeTo(_expectedTop(tester, 11, 2), 0.5),
        reason: "A's move committed exactly what its own ghost promised",
      );
      expect(
        _topOf(tester, 'dev-ups'),
        closeTo(_expectedTop(tester, 1, 2), 0.5),
        reason: 'and UPS-1, which B was resting on, never moved',
      );

      // B is adopted only now, and it is a press on an UNSELECTED device
      // (A's commit left AMP-1 selected), so releasing it is a plain click.
      await b.up();
      await tester.pump();
      expect(_render(tester, 'dev-ups').selected, isTrue);
      expect(_render(tester, 'dev-amp').selected, isFalse);
    });
  });

  group('rule 2 — a document change invalidates every live preview', () {
    testWidgets('a mid-drag Ctrl+Z cancels the move: the release commits '
        'NOTHING rather than a MoveDeviceCommand whose fromRuIndex is a '
        'fabrication', (tester) async {
      // THE CORRUPTION THIS PREVENTS. `_dragPlacement` is captured ONCE at
      // `beginDrag`. An undo mid-drag moves the device in the document while
      // that capture still names the pre-undo U, so the release used to
      // commit `MoveDeviceCommand(fromRuIndex: <a U the device no longer
      // occupies>)`. `apply()` looks right on screen; the NEXT Ctrl+Z calls
      // `revert()`, which faithfully restores that U — a position the device
      // never held. The corruption survives undo, which is verbatim the
      // scenario `_onDocumentSequenceChanged`'s own doc comment describes.
      await tester.pumpWidget(_app());
      await tester.pump();

      // One real undoable edit first: nudge SW-1 from U7 down to U6.
      await tester.tapAt(_centreOf(tester, 7, 1));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        _topOf(tester, 'dev-sw'),
        closeTo(_expectedTop(tester, 6, 1), 0.5),
      );

      // Grab it at U6 and drag toward the free U10.
      final g = await tester.startGesture(_centreOf(tester, 6, 1));
      await g.moveBy(sceneDelta(tester, 0, -4 * RackGeometry.unitsPerRu));
      await tester.pump();
      expect(find.text('U10'), findsOneWidget, reason: 'the ghost is live');

      // Undo WHILE the pointer is still down.
      await _ctrlZ(tester);
      expect(
        _topOf(tester, 'dev-sw'),
        closeTo(_expectedTop(tester, 7, 1), 0.5),
        reason: 'the undo itself is not blocked — it really runs',
      );
      expect(find.textContaining('Move cancelled'), findsOneWidget);

      await g.up();
      await tester.pump();

      expect(
        _topOf(tester, 'dev-sw'),
        closeTo(_expectedTop(tester, 7, 1), 0.5),
        reason:
            'the release must commit nothing: the captured fromRuIndex '
            'no longer describes the document',
      );
    });

    testWidgets('a Ctrl+Z BEFORE the 4px threshold also neuters the gesture '
        '— the captures happen at pointer-down, not at arm', (tester) async {
      // THE WINDOW A "cancel the visible preview" FIX WOULD MISS, and the
      // reason the invalidation is keyed on the exclusivity CLAIM rather
      // than on `_moveDrag.isSourceEngaged`. `_dragPlacement`,
      // `_dragDeviceId` and `_dragDeviceStartTopY` are all captured in
      // `_onBeginDrag`, at pointer-DOWN. Undo in the sub-threshold window
      // and there is no ghost to cancel — and then the very next 4px arm
      // `_armMovePreview` from captures that are already lies.
      //
      // Found by mutation: dropping `_dragCancelled = true` survived the
      // above-threshold test, and asking why exposed this second window.
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tapAt(_centreOf(tester, 7, 1));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        _topOf(tester, 'dev-sw'),
        closeTo(_expectedTop(tester, 6, 1), 0.5),
      );

      // Pointer down on the device, and STAY under the 4px slop.
      final g = await tester.startGesture(_centreOf(tester, 6, 1));
      await g.moveBy(const Offset(0, -2));
      await tester.pump();

      await _ctrlZ(tester);
      expect(
        _topOf(tester, 'dev-sw'),
        closeTo(_expectedTop(tester, 7, 1), 0.5),
      );

      // NOW cross the threshold and drag on to U10.
      await g.moveBy(sceneDelta(tester, 0, -4 * RackGeometry.unitsPerRu));
      await tester.pump();
      await g.up();
      await tester.pump();

      expect(
        _topOf(tester, 'dev-sw'),
        closeTo(_expectedTop(tester, 7, 1), 0.5),
        reason:
            'the gesture must not arm — let alone commit — from a '
            'placement captured before the undo',
      );
    });

    testWidgets('...but it does NOT swallow the click: a sub-threshold press '
        'is still a click after a mid-press mutation', (tester) async {
      // THE OTHER HALF OF THE PREVIOUS TEST, and the over-correction it hid.
      // Neutering the ARM is required; neutering the CLICK is not, and
      // `_dragCancelled` did both — `_commitDragBody` returns before
      // `_handleClick`, so pressing a device and causing any document
      // mutation before release (Ctrl+Z, an arrow-key nudge, a palette
      // placement) made the click silently vanish. No selection, no status
      // line, no inspector change: the exact silent no-op docs/04 §3.4 calls
      // "the most common source of 'the app is broken'", produced by the
      // guard that exists to prevent silent corruption.
      //
      // A press that has not crossed the 4px threshold has no preview to
      // cancel. Only its stale CAPTURE is dropped, so the release resolves
      // as the click it always was.
      await tester.pumpWidget(_app());
      await tester.pump();

      // One real undoable edit to have something for Ctrl+Z to undo, on a
      // device that is NOT the one about to be pressed.
      await tester.tapAt(_centreOf(tester, 7, 1));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        _topOf(tester, 'dev-sw'),
        closeTo(_expectedTop(tester, 6, 1), 0.5),
      );
      expect(_render(tester, 'dev-amp').selected, isFalse);

      // Press AMP-1 and STAY under the 4px slop — an ordinary click that
      // hesitates.
      final g = await tester.startGesture(_centreOf(tester, 4, 2));
      await g.moveBy(const Offset(0, -2));
      await tester.pump();

      // Mutate the document mid-press. `_onBeginDrag` already took canvas
      // focus, so the shortcut lands here.
      await _ctrlZ(tester);
      expect(
        _topOf(tester, 'dev-sw'),
        closeTo(_expectedTop(tester, 7, 1), 0.5),
        reason: 'the undo really ran',
      );

      await g.up();
      await tester.pump();

      expect(
        _render(tester, 'dev-amp').selected,
        isTrue,
        reason:
            'the press never became a drag, so it is a click, and a click '
            'selects — `_handleClick` reads only `_dragDeviceId` and '
            '`_dragStartScene` and writes only the non-undoable selection, so '
            'it has no captured fromRuIndex to fabricate',
      );
      expect(_render(tester, 'dev-sw').selected, isFalse);
      expect(
        _topOf(tester, 'dev-amp'),
        closeTo(_expectedTop(tester, 4, 2), 0.5),
        reason: 'and it is still ONLY a click: nothing moved',
      );
    });

    testWidgets('a mid-drag Ctrl+Z cancels the top-edge resize, and the '
        'release does not re-apply the height the undo just removed', (
      tester,
    ) async {
      // THE STALE BASELINE, exercised against the command that actually
      // makes it stale. `_resize.originalHeightU` is captured at
      // `_armResizePreview`; undoing a PRIOR `SetRackHeightCommand` mid-drag
      // leaves it naming a height the rack no longer has. Cancelling the
      // preview resets `candidateHeightU` BACK to that stale original — so
      // a release that still ran `_commitResizeDrag` would hand
      // `_requestHeight` the pre-undo height and silently re-apply the very
      // change the user just undid.
      //
      // The undone edit is therefore a HEIGHT change, not a device nudge: a
      // first version of this test undid a nudge, and the resize's candidate
      // then happened to collapse to the rack's current height, so the
      // release was a no-op by accident and the test could not tell a fixed
      // implementation from a broken one.
      await tester.pumpWidget(_app());
      await tester.pump();

      // Way three of §4.1, used for real: drag the top edge down 2U. The
      // highest occupant is the rear PP-1 at U9, so 10U is lossless and this
      // commits one `SetRackHeightCommand` with no modal.
      final grow = await tester.startGesture(_topEdgeGrab(tester));
      await grow.moveBy(sceneDelta(tester, 0, 2 * RackGeometry.unitsPerRu));
      await tester.pump();
      expect(find.text('10U (-2)'), findsOneWidget);
      await grow.up();
      await tester.pump();
      expect(find.text('10U'), findsWidgets, reason: 'the header stepper');

      // A SECOND top-edge drag, now baselined at 10U.
      final g = await tester.startGesture(_topEdgeGrab(tester));
      await g.moveBy(sceneDelta(tester, 0, RackGeometry.unitsPerRu));
      await tester.pump();
      expect(find.text('9U (-1)'), findsOneWidget);

      await _ctrlZ(tester);
      expect(find.text('9U (-1)'), findsNothing);
      expect(find.textContaining('Resize preview cancelled'), findsOneWidget);
      expect(
        find.text('12U'),
        findsWidgets,
        reason: 'the undo itself is not blocked — it really runs',
      );

      await g.up();
      await tester.pump();

      expect(
        find.text('12U'),
        findsWidgets,
        reason:
            'the release must commit NOTHING: both the 9U it was showing '
            'and the 10U baseline it would fall back to are measured against '
            'a rack that no longer exists',
      );
      expect(
        _topOf(tester, 'dev-ups'),
        closeTo(_expectedTop(tester, 1, 2), 0.5),
        reason: 'observed through real geometry, not just the header text',
      );
    });
  });

  group('rule 2 — what CANNOT reach _beginCompaction, and why', () {
    // WHY THIS GROUP EXISTS. `_beginCompaction` calls the one teardown and
    // then reports the name it returns — and that report is dead code today,
    // deliberately. A reviewer reading that method alone concludes the
    // opposite twice over: that a two-finger "A drags, B opens the menu"
    // sequence tears A down here (it does not), and that an open preview can
    // be replaced by a second one (it cannot). Both conclusions are wrong for
    // reasons that live in OTHER files, so they are pinned here rather than
    // asserted in a comment that the next change can quietly falsify.

    testWidgets('MERELY OPENING the header menu cancels a live canvas drag — '
        'the Navigator does it, before any menu item runs', (tester) async {
      // WHY THE TWO-FINGER "compaction preview swallows a live move drag"
      // SCENARIO CANNOT HAPPEN, pinned so it is not re-derived (or re-filed)
      // from reading `_beginCompaction` alone. The compaction affordance is a
      // `PopupMenuButton`, i.e. a Navigator ROUTE, and
      // `NavigatorState._afterNavigation` calls `_cancelActivePointers()` on
      // every push — which dispatches a real `PointerCancelEvent` for every
      // pointer that is still down, finger A included.
      //
      // So A's gesture is already torn down by `_onCancelDrag` (the
      // deliberately silent "nothing was released, so nothing was
      // attempted-and-refused" path) BEFORE the menu item is even tapped, and
      // `_invalidateLivePreviews` can never find a canvas gesture or a
      // palette drag from `_beginCompaction`. The assertion below is made
      // with the menu still OPEN, so nothing in the compaction path has run
      // at all.
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tapAt(_centreOf(tester, 4, 2));
      await tester.pump();
      final a = await tester.startGesture(_centreOf(tester, 4, 2), pointer: 7);
      await a.moveBy(sceneDelta(tester, 0, -6 * RackGeometry.unitsPerRu));
      await tester.pump();
      expect(find.text('U10-U11'), findsOneWidget, reason: 'the ghost is live');

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Compact Down'), findsOneWidget, reason: 'menu is open');
      expect(
        find.text('U10-U11'),
        findsNothing,
        reason:
            'the drag is already gone, and the compaction code has not '
            'run — the route push cancelled the pointer',
      );

      await tester.tapAt(Offset.zero); // dismiss the menu, picking nothing
      await tester.pumpAndSettle();
      await a.up();
      await tester.pump();
      expect(
        _topOf(tester, 'dev-amp'),
        closeTo(_expectedTop(tester, 4, 2), 0.5),
        reason: 'a cancelled drag commits nothing',
      );
    });

    testWidgets('and an OPEN compaction preview cannot be replaced by a '
        'second one: the menu items are disabled while it is showing', (
      tester,
    ) async {
      // THE THIRD ARM. A compaction preview has no pointer of its own, so
      // the Navigator's cancel cannot touch it — it is the one thing that
      // could still be live when `_beginCompaction` runs. It cannot be,
      // because `RackHeaderBar.compactionEnabled` is wired to
      // `!_compaction.isActive`: the two menu items that reach that method
      // are disabled for exactly as long as one is open.
      //
      // Pinned here, at the screen, rather than trusted: the wiring is one
      // expression in a sibling widget, and `_beginCompaction`'s own comment
      // now leans on it.
      await tester.pumpWidget(_app());
      await tester.pump();

      await _headerMenu(tester, 'Compact Down');
      expect(_compactionBar, findsOneWidget);
      expect(find.textContaining('Compact Down — '), findsOneWidget);

      // Open the menu again and pick the OTHER direction. The item is
      // disabled, so nothing is selected and the first preview stands.
      await _headerMenu(tester, 'Compact Up');

      expect(
        find.textContaining('Compact Down — '),
        findsOneWidget,
        reason:
            'still the FIRST preview — Compact Up never ran, so '
            '`_beginCompaction` was never re-entered over a live preview',
      );
      expect(find.textContaining('Compact Up — '), findsNothing);
    });
  });

  group('rule 2 — a face change invalidates every live preview', () {
    testWidgets('cycling the face cancels an open compaction preview rather '
        'than leaving Apply offering to move devices on the elevation the '
        'user just left', (tester) async {
      // §3.6's consent gate: "they never apply silently". A plan is computed
      // for ONE face; `_paintCompactionGhosts` has no face filter, so after a
      // toggle the bar sat there offering to relocate four front devices
      // while the canvas showed the rear elevation and the ghosts landed on
      // top of unrelated rear devices. The stale-plan guard cannot catch it:
      // it fires on a `doc.sequence` bump, and a face change is pure UI
      // state.
      await tester.pumpWidget(_app());
      await tester.pump();

      await _headerMenu(tester, 'Compact Down');
      expect(_compactionBar, findsOneWidget);
      final ampBefore = _topOf(tester, 'dev-amp');

      await tester.tap(find.text('Rear'));
      await tester.pumpAndSettle();

      expect(_compactionBar, findsNothing);
      expect(
        find.textContaining('Compaction preview cancelled'),
        findsOneWidget,
      );

      // And Enter is inert now — the action is disabled, so nothing moves.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Front'));
      await tester.pumpAndSettle();
      expect(_topOf(tester, 'dev-amp'), closeTo(ampBefore, 0.5));
    });
  });
}
