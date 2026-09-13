// docs/04-rack-editor.md §4.1's THIRD way to change rack height — "dragging
// the rack's top edge (8 px band, snaps to whole U, a '24U (+3)' readout
// follows the cursor). While dragging SMALLER, any occupied U about to be
// removed is hatched in red IN REAL TIME, so the collision is visible before
// release."
//
// WHY THIS FILE EXISTS. An adversarial review found the entire gesture
// untested: it applied THREE simultaneous mutations — `readout` returning a
// constant, `update()` storing no doomed rects at all, and an early `return`
// in `EditingOverlayPainter._paintResizePreview` — i.e. the whole live
// feedback silently absent, and every rackpal_ui test still passed. The
// controller's own state is unit-tested in resize_preview_controller_test.dart
// and the paint ops in editing_overlay_painter_test.dart; what neither could
// reach is the WIRING, which is what actually shipped broken: the band test,
// the grab-offset preservation, the per-frame doomed recomputation from the
// document, and the pointer-up hand-off into the screen's one height funnel.
//
// WHERE GRAB-OFFSET PRESERVATION IS ACTUALLY PROVED: the SUB-U NUDGE in the
// readout test, and nowhere else in this file. Not the band group, which this
// header used to imply — every gesture there moves by a whole number of U, so
// `topY = sceneCurrent.y - _dragStartScene.y` degrading to `topY =
// sceneCurrent.y` leaves both of its tests green: a 4px grab inset is 0.18 U
// and the snap absorbs it. The nudge probe is positioned so it does not.
//
// EVERY GESTURE HERE IS A REAL `TestGesture` down/moveTo/up against the real
// `RackCanvasScreen`. Nothing calls a private method, and the assertions read
// on-screen text (the readout chip lives in a root `Overlay`) and real render
// object positions — never private state.

import 'package:flutter/gestures.dart';
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

/// The screen's demo rack: 12U, front UPS-1 @U1 (2U), AMP-1 @U4 (2U),
/// SW-1 @U7 (1U), and REAR PP-1 @U9 (1U). Highest occupied U per device:
/// UPS-1 2, AMP-1 5, SW-1 7, PP-1 9 — so a candidate of 8U dooms PP-1
/// alone (and it is on the face NOT being displayed), 6U dooms SW-1 and
/// PP-1, and 10U dooms nobody.
const _geo = RackGeometry(12);

Widget _app() => MaterialApp(
  // DR-159 §11.158.3: undo and redo are GLOBAL bindings, so a
  // screen pumped without the root's map is a configuration
  // the product does not ship. See test/app_like.dart.
  shortcuts: appGlobalShortcuts(),
  home: Scaffold(body: RackCanvasScreen(measurer: _FakeMeasurer())),
);

/// A scene point expressed on screen, THROUGH THE LIVE VIEWPORT (`#710`).
///
/// This used to be `canvasOrigin + Offset(x, y)` and said so: "the viewport
/// is identity at startup, so scene (0, 0) is the canvas widget's own
/// top-left". That stopped being true when the screen started framing the
/// rack on open, and it was the assumption, not the arithmetic, that had
/// to change.
Offset _scene(WidgetTester tester, double x, double y) =>
    sceneToScreen(tester, x, y);

/// The rack's top edge, this far INSIDE §4.1's 8px band. The band is centred
/// on the edge (`|y| <= 8`), and grabbing at a non-zero offset is the
/// realistic case: it is what proves the offset is preserved rather than the
/// edge teleporting to the pointer on the first move.
///
/// SCREEN PIXELS, NOT SCENE UNITS, and `#710` is what made the difference
/// visible. `_topEdgeBandPx` is 8 SCREEN px divided by the viewport scale
/// before it is compared, exactly like the 4px click slop, so it stays 8
/// physical pixels at every zoom. While the opening view was the identity
/// transform the two units were the same number and nothing said which one
/// this was; at a fitted zoom a 4-unit scene inset is 9.6 screen px and
/// falls OUTSIDE the band it is supposed to be inside.
const double _grabInset = 4;

/// The scene x every gesture in this file presses at.
///
/// THE RACK'S HORIZONTAL CENTRE, AND IT HAS BEEN BOTH ANSWERS. It was the
/// centre once and that was wrong: the zoom HUD is a `Positioned` Card at
/// the canvas's top-left, and at identity zoom the rack's centre (x ≈ 133)
/// sat under it, so the band probe never reached `_onBeginDrag` and passed
/// identically with the 8px band widened to 40. It was moved to 220, which
/// cleared the HUD at identity.
///
/// `#710` inverted that. With the rack framed and CENTRED, scene x 220 maps
/// to screen x ≈ 1071 on a 1600px window, which is underneath the face
/// toggle in the canvas's top-RIGHT — the same defect, mirrored. The rack's
/// centre is now the one x that is clear of both, because centring is what
/// the opening view does: it puts the rack's middle at the canvas's middle,
/// as far from either corner's chrome as the geometry allows.
double get _probeX => _geo.rackWidth / 2;

Offset _topEdgeGrab(WidgetTester tester) =>
    _scene(tester, _probeX, 0) + const Offset(0, _grabInset);

/// Where the pointer must be for the top edge to imply [heightU].
///
/// `_updateResizePreview` preserves the grab offset (`topY = pointer.y -
/// grab.y`), so the pointer sits [_grabInset] below the scene y at which the
/// rack's top edge would have to land — which is exactly the U boundary
/// `yOfBoundary` already names. Spelled through the real geometry rather than
/// re-deriving `(12 - heightU) * 22`, so this helper cannot drift from the
/// production inverse it is aiming at.
Offset _pointerFor(WidgetTester tester, int heightU) =>
    _scene(tester, _probeX, _geo.yOfBoundary(heightU)) +
    const Offset(0, _grabInset);

/// Where the pointer must be for the top edge to imply a FRACTIONAL
/// [heightU], i.e. a position between two U boundaries.
///
/// The whole-U [_pointerFor] can say nothing about the snap RULE, because
/// `round`, `ceil` and `floor` all agree on an exact boundary. This one
/// aims at deliberately off-boundary positions so they disagree.
Offset _pointerForFractional(WidgetTester tester, double heightU) =>
    _scene(
      tester,
      _probeX,
      _geo.rackHeight - heightU * RackGeometry.unitsPerRu,
    ) +
    const Offset(0, _grabInset);

/// Pans the viewport DOWN by [dy] screen px through `CanvasIntentDetector`'s
/// own middle-button pan route (a BUTTON check, not a device-kind one — see
/// canvas_intent.dart), and returns the screen y at which scene y == 0 now
/// sits.
///
/// Needed because the viewport is identity at startup, which puts the rack's
/// top edge exactly on the canvas widget's own top edge: the UPPER half of
/// §4.1's centred grab band is then off-widget and simply unreachable by a
/// pointer. Every "above the edge" probe in this file depends on this.
Future<double> _panDown(WidgetTester tester, double dy) async {
  final before = sceneToScreen(tester, 0, 0).dy;
  final start = emptyCanvasPoint(tester);
  final pan = await tester.startGesture(
    start,
    kind: PointerDeviceKind.mouse,
    buttons: kMiddleMouseButton,
  );
  await pan.moveTo(start + Offset(0, dy));
  await pan.up();
  await tester.pumpAndSettle();

  // WHERE SCENE y == 0 NOW SITS, asked of the viewport rather than derived
  // from the canvas corner (`#710`). The corner only equalled scene zero
  // while the opening view was the identity transform.
  final sceneOriginY = sceneToScreen(tester, 0, 0).dy;
  expect(
    sceneOriginY - before,
    closeTo(dy, 0.5),
    reason: 'the middle-button pan did not move the viewport by $dy',
  );
  // The pan is asserted, not assumed: a pan route that silently stopped
  // working would put every probe below back at the un-panned origin and
  // quietly turn the "above the edge" half of the band test into a second
  // copy of the "below" half. Asserted twice over, because the check above
  // is about the MATRIX and this one is about what is on screen.
  expect(
    _topOf(tester, 'dev-ups'),
    closeTo(topLeftOfRu(tester, _geo, 1, 2).dy, 0.5),
  );
  return sceneOriginY;
}

/// The rack's committed height, read the way the user reads it: off the real
/// header stepper, which the screen feeds from `_rack.heightU`. Never from
/// private state.
int _rackHeight(WidgetTester tester) =>
    tester.widget<RackHeaderBar>(find.byType(RackHeaderBar)).heightU;

Finder _device(String id) => find.descendant(
  of: find.byKey(ValueKey(id)),
  matching: find.byType(DeviceBox),
);

double _topOf(WidgetTester tester, String id) =>
    tester.getTopLeft(_device(id)).dy;

void main() {
  // A REALISTIC WINDOW, for the same reason rack_compaction_test.dart sets
  // one: at the default 800x600 the canvas column (window minus the 280px
  // palette and the 320px inspector) is narrower than the rack, so the
  // centred `RackHeaderBar` — a `Positioned(top: 12)` sibling of the canvas —
  // lands directly on top of the rack's own top U. A probe aimed just below
  // the 8px band then hits the header's `+` stepper button instead of the
  // canvas, which grows the rack and looks exactly like a band-test failure.
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

  group('the 8px grab band (§4.1)', () {
    testWidgets('a drag STARTING INSIDE the band arms the resize preview and '
        'shows the readout chip', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await tester.startGesture(_topEdgeGrab(tester));
      await tester.pump();
      // Below the 4px threshold nothing is armed — a click on the top edge
      // is still a click.
      expect(find.textContaining('U ('), findsNothing);

      await gesture.moveTo(_pointerFor(tester, 10));
      await tester.pump();

      expect(find.text('10U (-2)'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('THE BAND IS 8px AND CENTRED ON THE EDGE: 7.5px either side '
        'arms, 8.5px either side does not', (tester) async {
      // WHAT THIS USED TO BE, and why a 75% regression walked through it. It
      // pressed 4px inside the band (arms) and 20px below it (does not),
      // which brackets the band into (8, 20] and nothing tighter: widening
      // `_topEdgeBandPx` from 8 to 14 — a visibly fatter grab target that
      // swallows most of the top U — passed, because 4 is still inside 14
      // and 20 is still outside it. It also only ever pressed at POSITIVE
      // scene y, so `_isTopEdgeGrab`'s `p.y.abs()` — the "band is CENTRED
      // on the edge" behaviour that production comment calls load-bearing —
      // was never exercised here at all.
      //
      // So: four probes, straddling BOTH edges of the band, in the same
      // column, differing only in y. That brackets the half-band into
      // [7.5, 8.5) on each side, which no integer change to the constant
      // survives, and the two negative-y probes are the first thing in this
      // file that would notice `.abs()` being dropped.
      //
      // The differential discipline the predecessor established is kept and
      // doubled: each "does not arm" probe is paired with an "arms" probe
      // 1px away, so a probe that stopped reaching live canvas (the zoom-HUD
      // trap in [_probeX]) fails the paired arm rather than passing
      // vacuously.
      await tester.pumpWidget(_app());
      await tester.pump();

      // Scene y < 0 is off-widget until the viewport moves; see [_panDown].
      final originY = await _panDown(tester, 120);
      Offset at(double sceneY) => Offset(
        sceneToScreen(tester, _probeX, 0).dx,
        originY + sceneY,
      );

      /// One probe: press at [sceneY], drag down 44px (exactly 2U, and well
      /// past the 4px click slop), and report whether the resize preview
      /// armed. Always leaves the rack at 12U.
      Future<bool> armsAt(double sceneY) async {
        final start = at(sceneY);
        final g = await tester.startGesture(start);
        await g.moveTo(start + const Offset(0, 44));
        await tester.pump();
        final armed = find.textContaining('U (').evaluate().isNotEmpty;
        if (armed) await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await g.up();
        await tester.pumpAndSettle();
        expect(
          _rackHeight(tester),
          12,
          reason: 'probe at sceneY=$sceneY committed a height',
        );
        return armed;
      }

      expect(
        await armsAt(7.5),
        isTrue,
        reason: '7.5px BELOW the edge is inside an 8px band',
      );
      expect(
        await armsAt(8.5),
        isFalse,
        reason:
            '8.5px below the edge is outside an 8px band — if this arms, '
            'the band got wider than §4.1 says',
      );
      expect(
        await armsAt(-7.5),
        isTrue,
        reason:
            '7.5px ABOVE the edge is inside a band CENTRED on it. A band '
            'that only reached downward would fail here, and a user aiming '
            'at the boundary does not know which side of it they are on',
      );
      expect(
        await armsAt(-8.5),
        isFalse,
        reason: '8.5px above the edge is outside an 8px band',
      );
    });
  });

  group('the readout (§4.1: "a 24U (+3) readout follows the cursor")', () {
    testWidgets('it SNAPS TO THE NEAREST WHOLE U — the half-way point is '
        'where it flips — signs the delta in both directions, and reads '
        'bare at the identity position', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await tester.startGesture(_topEdgeGrab(tester));
      await gesture.moveTo(_pointerFor(tester, 10));
      await tester.pump();
      expect(find.text('10U (-2)'), findsOneWidget);

      // A SUB-U nudge: 8px is well past the 4px drag threshold but only
      // ~0.36 RU, so the snapped height must not move. This is what "snaps
      // to whole U" means, and a regression to a continuous height would
      // show some other number here. It is ALSO this file's only assertion
      // that the grab offset is preserved (`topY = pointer.y - grab.y`):
      // dropping that term shifts the implied height by the 4px inset,
      // which is 0.18 U, and 9.64 - 0.18 falls below the half-way point.
      await gesture.moveTo(_pointerFor(tester, 10) + const Offset(0, 8));
      await tester.pump();
      expect(
        find.text('10U (-2)'),
        findsOneWidget,
        reason: 'a sub-U nudge must not change the snapped height',
      );

      // THE SNAP RULE ITSELF, straddling the half-way point. Every other
      // probe in this test lands on an EXACT U boundary, where `round`,
      // `ceil` and `floor` all agree — which is why this test used to pass
      // with `heightForTopEdgeY`'s `.round()` changed to `.ceil()`, i.e.
      // with the gesture snapping UP from any fractional position, a
      // visibly different drag. These two probes sit 0.1 U either side of
      // 9.5 and disagree under every rounding mode but the right one:
      // `ceil` would read 10U at both, `floor` 9U at both, `truncate` 9U at
      // both.
      await gesture.moveTo(_pointerForFractional(tester, 9.6));
      await tester.pump();
      expect(
        find.text('10U (-2)'),
        findsOneWidget,
        reason: '9.6U is nearer 10 than 9 — a floor/truncate would say 9U',
      );

      await gesture.moveTo(_pointerForFractional(tester, 9.4));
      await tester.pump();
      expect(
        find.text('9U (-3)'),
        findsOneWidget,
        reason: '9.4U is nearer 9 than 10 — a ceil would say 10U',
      );
      expect(find.text('10U (-2)'), findsNothing);

      // ...and it settles on the exact boundary too.
      await gesture.moveTo(_pointerFor(tester, 9));
      await tester.pump();
      expect(find.text('9U (-3)'), findsOneWidget);
      expect(find.text('10U (-2)'), findsNothing);

      // GROWING signs the other way...
      await gesture.moveTo(_pointerFor(tester, 15));
      await tester.pump();
      expect(find.text('15U (+3)'), findsOneWidget);

      // ...and the identity position is bare: a "(+0)" would be noise, and
      // the drag genuinely IS at its starting height there. Two matches
      // because the header stepper still reads the uncommitted 12U — which
      // is itself the point: a mutation spelling the identity readout
      // "12U (+0)" would drop this to one.
      await gesture.moveTo(_pointerFor(tester, 12));
      await tester.pump();
      expect(find.text('12U'), findsNWidgets(2));
      expect(find.textContaining('(+0)'), findsNothing);
      expect(find.textContaining('(-0)'), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the chip FOLLOWS THE CURSOR — it is repositioned per move '
        'event, not pinned where the drag began', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await tester.startGesture(_topEdgeGrab(tester));
      await gesture.moveTo(_pointerFor(tester, 10));
      await tester.pump();
      final firstChip = tester.getTopLeft(find.text('10U (-2)'));

      // Move SIDEWAYS by a large amount and down by less than one U, so the
      // readout TEXT is unchanged and only the position can have moved. A
      // regression that stopped passing `cursorGlobal` would leave the chip
      // exactly where it was (or hide it) while the text still matched.
      await gesture.moveTo(_pointerFor(tester, 10) + const Offset(60, 3));
      await tester.pump();
      final secondChip = tester.getTopLeft(find.text('10U (-2)'));

      expect(secondChip.dx - firstChip.dx, closeTo(60, 0.5));
      expect(secondChip.dy - firstChip.dy, closeTo(3, 0.5));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('the real-time red hatch (§4.1: visible BEFORE release)', () {
    testWidgets('dragging smaller names the doomed count LIVE, and it counts '
        "the REAR face's occupant while the FRONT is displayed", (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await tester.startGesture(_topEdgeGrab(tester));

      // 10U stranded nobody — the tallest occupant tops out at U9.
      await gesture.moveTo(_pointerFor(tester, 10));
      await tester.pump();
      expect(find.textContaining('would lose'), findsNothing);

      // 8U dooms PP-1 (U9) ALONE — and PP-1 is on the REAR face, which is
      // not the elevation being displayed. Counting it is the deliberate
      // both-faces call resize_preview_controller.dart's header defends:
      // hatching only the visible face would let a user drag straight past
      // a rear device seeing nothing at all.
      await gesture.moveTo(_pointerFor(tester, 8));
      await tester.pump();
      expect(find.text('8U (-4)'), findsOneWidget);
      expect(find.text('1 device would lose its U'), findsOneWidget);

      // 6U additionally dooms SW-1 (U7) — the count is recomputed per frame
      // from the document, not captured once at grab time.
      await gesture.moveTo(_pointerFor(tester, 6));
      await tester.pump();
      expect(find.text('2 devices would lose their U'), findsOneWidget);
      expect(find.text('1 device would lose its U'), findsNothing);

      // Dragging back UP retracts the warning — "in real time" cuts both
      // ways, and a stale hatch would overstate the cost.
      await gesture.moveTo(_pointerFor(tester, 10));
      await tester.pump();
      expect(find.textContaining('would lose'), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('release: the ONE height funnel (§4.1)', () {
    testWidgets('a lossless drag commits exactly one undoable height change, '
        'and NOTHING is committed while the drag is live', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await tester.startGesture(_topEdgeGrab(tester));
      await gesture.moveTo(_pointerFor(tester, 10));
      await tester.pump();

      // "NOTHING HERE IS EVER COMMITTED" — not one command per frame, not
      // one per U crossed.
      expect(_rackHeight(tester), 12);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(_rackHeight(tester), 10);
      // "existing ruIndex values are untouched" — a TOP trim renumbers
      // nobody. Asserted against the NEW 10U geometry: the scene's origin is
      // the rack's top edge, so every device's on-screen y necessarily shifts
      // when the rack gets shorter. Landing exactly on `RackGeometry(10)`'s
      // U1 slot is what proves UPS-1 is still AT U1 rather than merely still
      // on screen.
      const after = RackGeometry(10);
      expect(
        _topOf(tester, 'dev-ups'),
        closeTo(topLeftOfRu(tester, after, 1, 2).dy, 0.5),
      );

      // ONE undo entry for the whole gesture.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(_rackHeight(tester), 12);
    });

    testWidgets("a drag BELOW occupancy routes into §4.1's modal instead of "
        'committing, and Cancel leaves the rack untouched', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await tester.startGesture(_topEdgeGrab(tester));
      await gesture.moveTo(_pointerFor(tester, 6));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // The gesture hands its candidate to the SAME funnel the stepper and
      // the inspector field use, so it gets the same conversation.
      expect(find.byType(ShrinkRackDialog), findsOneWidget);
      expect(_rackHeight(tester), 12);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(_rackHeight(tester), 12);
    });

    testWidgets('...and choosing option 3 through the REAL modal resizes the '
        'REAL document to the smallest fitting height, stranding nobody', (
      tester,
    ) async {
      // The end-to-end §4.1 loop, all three surfaces in one gesture: the
      // top-edge drag (way three) hands 6U to the funnel, the modal refuses
      // to strand anyone, and `keepSmallest` lands the rack at the height
      // that actually fits. The finding this closes noted that the ONLY
      // widget test reaching Apply relied on `compactFirst` being
      // preselected, so this switch arm — the always-available one — had
      // never been exercised against a document at all.
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await tester.startGesture(_topEdgeGrab(tester));
      await gesture.moveTo(_pointerFor(tester, 6));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // PP-1 (rear, U9) is the tallest occupant, so 9U is the smallest
      // height that strands nobody.
      final option3 = find.text('Keep rack at 9U (smallest that fits)');
      expect(option3, findsOneWidget);
      await tester.tap(option3);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(_rackHeight(tester), 9);

      // THE DOCUMENT, not the plan: every front-face device is still at the
      // U it started on, positioned against the NEW 9U geometry. A top trim
      // renumbers nobody, and 9U fits all of them.
      const after = RackGeometry(9);
      void expectAt(String id, int ru, int h) => expect(
        _topOf(tester, id),
        closeTo(topLeftOfRu(tester, after, ru, h).dy, 0.5),
      );
      expectAt('dev-ups', 1, 2);
      expectAt('dev-amp', 4, 2);
      expectAt('dev-sw', 7, 1);

      // Rule 6: the whole Apply is ONE undo entry.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(_rackHeight(tester), 12);
    });

    testWidgets('a press on the top edge that never crosses the threshold is '
        'a CLICK: it opens the rack inspector and resizes nothing', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await tester.startGesture(_topEdgeGrab(tester));
      await gesture.moveBy(const Offset(0, 2)); // under the 4px slop
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_rackHeight(tester), 12);
      expect(find.textContaining('U ('), findsNothing);
      // §4's second inspector entry point: the top edge is rack chrome.
      expect(find.byType(RackInspectorPanel), findsOneWidget);
    });

    testWidgets('Esc mid-drag cancels the preview and commits no height', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await tester.startGesture(_topEdgeGrab(tester));
      await gesture.moveTo(_pointerFor(tester, 6));
      await tester.pump();
      expect(find.text('6U (-6)'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('6U (-6)'), findsNothing);
      expect(_rackHeight(tester), 12);

      // ...and the release that follows a cancel must not resurrect it.
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_rackHeight(tester), 12);
      expect(find.byType(ShrinkRackDialog), findsNothing);
    });
  });
}
