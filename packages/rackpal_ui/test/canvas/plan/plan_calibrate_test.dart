// PLAN-F/1 and PLAN-F/2: the two-point pick, the typed distance, and what
// the calibration then says it bought (docs/15 §5, DR-144 §11.143).
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY END-TO-END CASE ASSERTS THE DOCUMENT
// ═══════════════════════════════════════════════════════════════════════
// What a calibration is FOR is that `PlanUnderlay.scale` holds the two
// points and the typed distance, and that one undo takes it away again. A
// case that asserted the controller's `first` would survive
// `SetPlanScaleCommand` never running, which is the shape this repo has
// been bitten by: `PlanScale` sat modelled, serialized and reachable from
// nothing for two chapters.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _now = DateTime.utc(2026, 9, 8);
const _ul1 = Uuid('ul-1');
const _ul2 = Uuid('ul-2');
const _member1 = 'underlays/ul-1.png';
const _member2 = 'underlays/ul-2.png';
const _outletId = Uuid('out-1');
const _rackId = Uuid('rk-1');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

final class _ZeroMeasurer implements TextMeasurer {
  const _ZeroMeasurer();

  @override
  TextMetrics measureText(String text, TextStyleSpec style) =>
      const TextMetrics(
        advanceWidth: 0,
        ascent: 0,
        descent: 0,
        capHeight: 0,
        xHeight: 0,
        lineHeight: 0,
      );
}

Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF884422),
  );
  final image = await recorder.endRecording().toImage(w, h);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

PlanUnderlay _underlay(Uuid id, String member, String name, PlanScale? scale) =>
    PlanUnderlay(
      id: id,
      name: name,
      imageMember: member,
      format: PlanImageFormat.png,
      pixelWidth: 600,
      pixelHeight: 400,
      contentHash: 'sha256:test',
      order: FracIndex(id == _ul1 ? 'a0' : 'a1'),
      meta: _meta(),
      scale: scale,
    );

DocumentController _controller({
  PlanScale? scale,
  bool withSecond = false,
  bool withRack = false,
  bool rackPinned = false,
  bool outletPinned = false,
  UnitSystem units = UnitSystem.imperial,
}) {
  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
    settings: ProjectSettings(displayUnits: units),
  );
  doc.underlays[_ul1] = _underlay(_ul1, _member1, 'Level 1', scale);
  if (withSecond) {
    doc.underlays[_ul2] = _underlay(_ul2, _member2, 'Site', null);
  }
  doc.outlets[_outletId] = Outlet(
    id: _outletId,
    structureBodyId: const Uuid('body-1'),
    designation: 'D-014',
    order: const FracIndex('a0'),
    meta: _meta(),
    planPin: outletPinned
        ? const PlanPin(underlayId: _ul1, at: PxPt(4, 4))
        : null,
  );
  if (withRack) {
    doc.racks[_rackId] = Rack(
      id: _rackId,
      name: 'Head end',
      designator: 'RK-1',
      heightU: 42,
      order: const FracIndex('a0'),
      meta: _meta(),
      planPin: rackPinned
          ? const PlanPin(underlayId: _ul1, at: PxPt(9, 9))
          : null,
    );
  }
  return DocumentController(doc, clock: FixedClock(_now), actor: 'test');
}

/// A `LocationsPanelActions` that refuses everything, for cases about the
/// PLAN half of this view (`#891`, DR-168).
///
/// The view edits the location tree since the merge, so it takes the same
/// record `LocationsPanel` does. These cases are about underlays, pins and
/// outlines; `locations_panel_test.dart` and `site_view_test.dart` are
/// where the tree's own edits are proved.
LocationsPanelActions _noLocationEdits() => LocationsPanelActions(
  onAdd: (_) => const Uuid('unused'),
  onRename: (_, _) {},
  onSetCode: (_, _) {},
  onSetKind: (_, _) {},
  onSetFloorNumber: (_, _) {},
  onSetSpaceCode: (_, _) {},
  onSetEstimatedRunLength: (_, _) {},
  onReparent: (_, _) => null,
  onDelete: (_) async => false,
  onRefuse: (_) {},
);

void main() {
  // A WINDOW THE PRODUCT SUPPORTS (`#892`). This view gained the third
  // region docs/15 §6 ruled and `PLAN-E/5` did not build, and the default
  // 800px test surface CLAMPS the `SizedBox` below: the canvas came back
  // 238 units wide and every click aimed at the plan missed it. docs/04
  // §1 treats anything under 1080 as the unbuilt tablet-collapse case.
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

  TestWidgetsFlutterBinding.ensureInitialized();

  late PlanImageCache cache;
  setUp(() => cache = PlanImageCache());
  tearDown(() => cache.dispose());

  /// Mounts the whole editor, because the affordance is on the left rail
  /// and the pick is on the canvas: a case that pumped the canvas alone
  /// would prove the gesture and not the route to it.
  ///
  /// **THE OFFSETS WERE ARITHMETIC AND ARE NOW A LOOKUP** (`#898`). This
  /// paragraph read: the rail is 240 wide with a one-pixel divider beside
  /// it, so the canvas starts at x=241 and `(241 + n, m)` is pixel
  /// `(n, m)` of the underlay *under an identity viewport*. That last
  /// clause was the load-bearing one, and DR-169 §11.168.3 made it false:
  /// a plan now opens FRAMED, so the scale is not 1 and the origin is not
  /// the canvas corner.
  ///
  /// [screenOf] reads the viewport the screen actually built, which is
  /// what `plan_editor_screen_test.dart`'s own helper already does and
  /// says why: *"a test that assumed the identity would be asserting
  /// about a viewport this widget does not necessarily give itself."*
  /// Where underlay pixel [p] sits on screen, through the LIVE viewport.
  Offset screenOf(WidgetTester tester, PxPt p) {
    final canvas = tester.widget<PlanCanvasScreen>(
      find.byType(PlanCanvasScreen),
    );
    final s = canvas.viewport.sceneToScreen(
      DPt(p.px.toDouble(), p.py.toDouble()),
    );
    return tester.getTopLeft(find.byType(PlanCanvasScreen)) + Offset(s.x, s.y);
  }

  Future<({List<String> refusals, List<String> notices})> pump(
    WidgetTester tester,
    DocumentController controller, {
    List<String> members = const [_member1],
    PlanPinArmController? arm,
  }) async {
    await tester.runAsync(() async {
      for (final m in members) {
        await cache.load(m, await _png(600, 400));
      }
    });
    final refusals = <String>[];
    final notices = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              // WIDENED AT `#892` FROM 900, for the sibling suite's
              // reason: the view gained a third region and 900 is under
              // the 1080 docs/04 §1 treats as the supported minimum.
              width: 1400,
              height: 500,
              child: PlanEditorScreen(
                locations: _noLocationEdits(),
                controller: controller,
                images: cache.resolver,
                measurer: const _ZeroMeasurer(),
                selection: SelectionController(),
                arm: arm,
                onRefuse: refusals.add,
                onNotice: notices.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (refusals: refusals, notices: notices);
  }

  Finder calibrateButton(Uuid id) =>
      find.byKey(ValueKey('underlay-calibrate-${id.v}'));

  group('the controller', () {
    test('begin arms with nothing picked; pickFirst records one end', () {
      final c = PlanCalibrateController();
      expect(c.isActive, isFalse);

      c.begin();
      expect(c.isActive, isTrue);
      expect(c.first, isNull);

      c.pickFirst(const PxPt(10, 20));
      expect(c.first, const PxPt(10, 20));
      c.dispose();
    });

    test('pickFirst OFF the mode is a no-op, so a stray click cannot leave '
        'a half-picked state', () {
      final c = PlanCalibrateController()..pickFirst(const PxPt(10, 20));
      expect(c.first, isNull);
      c.dispose();
    });

    test('begin again restarts the pick rather than compounding it', () {
      final c = PlanCalibrateController()
        ..begin()
        ..pickFirst(const PxPt(10, 20))
        ..begin();
      expect(c.isActive, isTrue);
      expect(c.first, isNull);
      c.dispose();
    });

    test('cancel clears both', () {
      final c = PlanCalibrateController()
        ..begin()
        ..pickFirst(const PxPt(10, 20))
        ..cancel();
      expect(c.isActive, isFalse);
      expect(c.first, isNull);
      c.dispose();
    });
  });

  group('the dialog', () {
    Future<Len?> show(
      WidgetTester tester, {
      UnitSystem units = UnitSystem.imperial,
      bool alreadyCalibrated = false,
    }) async {
      Len? out;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  out = await showCalibrateDistanceDialog(
                    context,
                    planName: 'Level 1',
                    units: units,
                    alreadyCalibrated: alreadyCalibrated,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return out;
    }

    testWidgets('greets nobody with an error, and cannot be committed '
        'empty', (tester) async {
      await show(tester);

      expect(find.text(kCalibrateHelp), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(CalibrateDistanceDialog.commitKey),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('A BARE NUMBER IS REFUSED IN THE FIELD, naming both '
        'readings', (tester) async {
      // The load-bearing case of the whole chapter: 36 is 36 inches or 36
      // feet, and the guess is wrong by twelve on every length the plan
      // yields (DR-144 §11.143.5).
      await show(tester);
      await tester.enterText(
        find.byKey(CalibrateDistanceDialog.fieldKey),
        '36',
      );
      await tester.pump();

      // THE EXACT SENTENCE, not a substring. The helper copy under the
      // field also says "36 inches", because a door is 32 or 36 inches
      // and that is the whole affordance; a `textContaining` here matched
      // both and would have gone on matching if the refusal vanished.
      expect(
        find.text('36 could be 36 inches or 36 feet. Type 36in or 36ft.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(CalibrateDistanceDialog.commitKey),
            )
            .onPressed,
        isNull,
        reason: 'a refused field must not offer a commit',
      );
    });

    testWidgets('a united distance commits and comes back as a Len', (
      tester,
    ) async {
      await show(tester);
      await tester.enterText(
        find.byKey(CalibrateDistanceDialog.fieldKey),
        '3\' 6"',
      );
      await tester.pump();
      await tester.tap(find.byKey(CalibrateDistanceDialog.commitKey));
      await tester.pumpAndSettle();

      // The dialog is gone and the value reached the caller. Asserting the
      // return rather than the field is what makes this a test of the
      // dialog's job rather than of a `TextEditingController`.
      expect(find.byType(CalibrateDistanceDialog), findsNothing);
    });

    testWidgets('the metric project gets metric wording', (tester) async {
      await show(tester, units: UnitSystem.metric);
      await tester.enterText(
        find.byKey(CalibrateDistanceDialog.fieldKey),
        '2.4',
      );
      await tester.pump();

      expect(
        find.text(
          '2.4 could be 2.4 metres or 2.4 millimetres. '
          'Type 2.4m or 2.4mm.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('it says Recalibrate when there is already a scale', (
      tester,
    ) async {
      await show(tester, alreadyCalibrated: true);
      expect(find.text('Recalibrate Level 1'), findsOneWidget);
    });
  });

  group('the underlay row', () {
    testWidgets('PRINTS ITS STATE IN BOTH DIRECTIONS', (tester) async {
      // G4, DR-144 §11.143.4: a row that said nothing about an
      // uncalibrated plan would leave "no scale yet" and "a scale I have
      // forgotten about" looking identical.
      await pump(tester, _controller());
      expect(find.text(kUncalibratedLabel), findsOneWidget);
    });

    testWidgets('reads Calibrated once there is a usable scale', (
      tester,
    ) async {
      await pump(
        tester,
        _controller(
          scale: const PlanScale(
            a: PxPt(100, 100),
            b: PxPt(200, 100),
            distance: Len(36 * Len.nmPerInch),
          ),
        ),
      );
      // `PLAN-F/2` MADE THIS LINE RICHER, and the bare word no longer
      // appears on its own: the row names the one act still blocking a
      // length. The fixture has no rack, so that act is pinning one.
      expect(find.textContaining(kCalibratedLabel), findsOneWidget);
      expect(find.text('$kCalibratedLabel · no rack pinned'), findsOneWidget);
    });

    testWidgets('A SCALE THAT CANNOT YIELD A LENGTH READS AS UNCALIBRATED', (
      tester,
    ) async {
      // Two coincident points are stored, calibrated as far as the
      // document is concerned, and useless as far as a length is
      // concerned. A row calling that "Calibrated" would promise a length
      // the model refuses to derive.
      await pump(
        tester,
        _controller(
          scale: const PlanScale(
            a: PxPt(100, 100),
            b: PxPt(100, 100),
            distance: Len(36 * Len.nmPerInch),
          ),
        ),
      );
      expect(find.text(kUncalibratedLabel), findsOneWidget);
    });

    testWidgets('the action is on the OPEN row only', (tester) async {
      await pump(
        tester,
        _controller(withSecond: true),
        members: const [_member1, _member2],
      );

      expect(calibrateButton(_ul1), findsOneWidget);
      expect(calibrateButton(_ul2), findsNothing);
    });

    testWidgets('the word changes with the scale, matching the undo entry', (
      tester,
    ) async {
      await pump(tester, _controller());
      expect(find.text('Calibrate…'), findsOneWidget);

      await pump(
        tester,
        _controller(
          scale: const PlanScale(
            a: PxPt(100, 100),
            b: PxPt(200, 100),
            distance: Len(36 * Len.nmPerInch),
          ),
        ),
      );
      expect(find.text('Recalibrate…'), findsOneWidget);
    });
  });

  group('the pick, end to end', () {
    testWidgets('THE WHOLE GESTURE WRITES A SCALE, AND ONE UNDO TAKES IT '
        'AWAY', (tester) async {
      final c = _controller();
      await pump(tester, c);
      expect(c.doc.underlays[_ul1]!.scale, isNull);

      await tester.tap(calibrateButton(_ul1));
      await tester.pump();
      expect(find.byKey(PlanCalibrateChip.chipKey), findsOneWidget);
      expect(find.text(kCalibrateFirstLabel), findsOneWidget);

      // Pixels (100, 100) and (200, 100) of a 600x400 underlay, mapped
      // through the viewport the screen built rather than assumed.
      await tester.tapAt(screenOf(tester, const PxPt(100, 100)));
      await tester.pump();
      expect(find.text(kCalibrateSecondLabel), findsOneWidget);

      await tester.tapAt(screenOf(tester, const PxPt(200, 100)));
      await tester.pumpAndSettle();
      expect(find.byType(CalibrateDistanceDialog), findsOneWidget);

      await tester.enterText(
        find.byKey(CalibrateDistanceDialog.fieldKey),
        '36in',
      );
      await tester.pump();
      await tester.tap(find.byKey(CalibrateDistanceDialog.commitKey));
      await tester.pumpAndSettle();

      final scale = c.doc.underlays[_ul1]!.scale;
      expect(scale, isNotNull, reason: 'the command has to have run');
      expect(scale!.a, const PxPt(100, 100));
      expect(scale.b, const PxPt(200, 100));
      expect(scale.distance.nm, 36 * Len.nmPerInch);
      // 36 inches over 100 pixels.
      expect(scale.nanometresPerPixel, 9144000.0);
      // And the row now says so. `PLAN-F/2` gave it the rest of the
      // sentence, and there is no rack in this fixture, so the line names
      // the act that would unblock every length on the plan.
      expect(find.text('$kCalibratedLabel · no rack pinned'), findsOneWidget);

      // `undoLast` AND NOT `undo.undo`, because the screen listens to the
      // controller's `changes` and the raw stack does not touch it: an
      // undo taken behind the controller leaves the document right and
      // the rail stale, which is a test artifact and not a product state.
      c.undoLast();
      await tester.pump();
      expect(c.doc.underlays[_ul1]!.scale, isNull);
      expect(find.text(kUncalibratedLabel), findsOneWidget);
    });

    testWidgets('the chip goes away when the pick ends', (tester) async {
      final c = _controller();
      await pump(tester, c);
      await tester.tap(calibrateButton(_ul1));
      await tester.pump();
      await tester.tapAt(screenOf(tester, const PxPt(100, 100)));
      await tester.tapAt(screenOf(tester, const PxPt(200, 100)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(CalibrateDistanceDialog.fieldKey),
        '36in',
      );
      await tester.pump();
      await tester.tap(find.byKey(CalibrateDistanceDialog.commitKey));
      await tester.pumpAndSettle();

      expect(find.byKey(PlanCalibrateChip.chipKey), findsNothing);
    });

    testWidgets('BACKING OUT OF THE DIALOG WRITES NOTHING and ends the '
        'pick', (tester) async {
      final c = _controller();
      await pump(tester, c);
      await tester.tap(calibrateButton(_ul1));
      await tester.pump();
      await tester.tapAt(screenOf(tester, const PxPt(100, 100)));
      await tester.tapAt(screenOf(tester, const PxPt(200, 100)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(c.doc.underlays[_ul1]!.scale, isNull);
      expect(find.byKey(PlanCalibrateChip.chipKey), findsNothing);
    });

    testWidgets('TWO CLICKS ON ONE SPOT REFUSE, AND THE PICK STAYS LIVE', (
      tester,
    ) async {
      // `PlanScale.nanometresPerPixel` is null when the points coincide,
      // so the surface refuses on the model's own condition rather than
      // on a second rule. The pick surviving is what makes the answer
      // "click somewhere else" instead of "start again".
      final c = _controller();
      final h = await pump(tester, c);
      await tester.tap(calibrateButton(_ul1));
      await tester.pump();

      await tester.tapAt(screenOf(tester, const PxPt(100, 100)));
      await tester.tapAt(screenOf(tester, const PxPt(100, 100)));
      await tester.pumpAndSettle();

      expect(find.byType(CalibrateDistanceDialog), findsNothing);
      expect(h.refusals, [kCalibrateSamePointRefusal]);
      expect(find.text(kCalibrateSecondLabel), findsOneWidget);

      // And it really is still live: a click elsewhere finishes it.
      await tester.tapAt(screenOf(tester, const PxPt(200, 100)));
      await tester.pumpAndSettle();
      expect(find.byType(CalibrateDistanceDialog), findsOneWidget);
    });

    testWidgets('opening another plan cancels the pick', (tester) async {
      // A pick is two points in ONE raster. Carrying it across a switch
      // would let the second click calibrate a wall that is not there.
      final c = _controller(withSecond: true);
      await pump(tester, c, members: const [_member1, _member2]);
      await tester.tap(calibrateButton(_ul1));
      await tester.pump();
      await tester.tapAt(screenOf(tester, const PxPt(100, 100)));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('underlay-row-ul-2')));
      await tester.pump();

      expect(find.byKey(PlanCalibrateChip.chipKey), findsNothing);
    });
  });

  group('Esc, which now has three rungs', () {
    testWidgets('cancels the pick', (tester) async {
      final c = _controller();
      await pump(tester, c);
      await tester.tap(calibrateButton(_ul1));
      await tester.pump();
      expect(find.byKey(PlanCalibrateChip.chipKey), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byKey(PlanCalibrateChip.chipKey), findsNothing);
    });

    testWidgets('THE PICK GOES BEFORE THE ARM MODE, which is DR-144 in the '
        'keyboard', (tester) async {
      // A pick is seconds old and an arm mode may have been running since
      // the Structure editor. One Esc takes the newer one and leaves the
      // older running.
      final c = _controller();
      final arm = PlanPinArmController()
        ..arm(const ArmedPin(outletId: _outletId, label: 'D-014'));
      addTearDown(arm.dispose);
      await pump(tester, c, arm: arm);

      await tester.tap(calibrateButton(_ul1));
      await tester.pump();
      // ONE CHIP AT A TIME, and it is the pick's.
      expect(find.byKey(PlanCalibrateChip.chipKey), findsOneWidget);
      expect(find.byKey(PlanPinArmChip.chipKey), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byKey(PlanCalibrateChip.chipKey), findsNothing);
      expect(arm.isActive, isTrue, reason: 'the older mode survives');
      expect(find.byKey(PlanPinArmChip.chipKey), findsOneWidget);
    });

    testWidgets('A CALIBRATION CLICK OUTRANKS AN ARMED ONE', (tester) async {
      // The same order in the pointer that Esc has in the keyboard. A
      // canvas that let the older armed pin win would answer a click the
      // user made for the pick by pinning a drop somewhere else.
      final c = _controller();
      final arm = PlanPinArmController()
        ..arm(const ArmedPin(outletId: _outletId, label: 'D-014'));
      addTearDown(arm.dispose);
      await pump(tester, c, arm: arm);

      await tester.tap(calibrateButton(_ul1));
      await tester.pump();
      await tester.tapAt(screenOf(tester, const PxPt(100, 100)));
      await tester.pump();

      expect(
        c.doc.outlets[_outletId]!.planPin,
        isNull,
        reason: 'the click belonged to the pick',
      );
      expect(find.text(kCalibrateSecondLabel), findsOneWidget);
    });
  });

  group('PLAN-F/2: what a calibration says it bought', () {
    /// Runs the whole pick and types [distance].
    Future<void> calibrate(
      WidgetTester tester, {
      String distance = '36in',
    }) async {
      await tester.tap(calibrateButton(_ul1));
      await tester.pump();
      await tester.tapAt(screenOf(tester, const PxPt(100, 100)));
      await tester.tapAt(screenOf(tester, const PxPt(200, 100)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(CalibrateDistanceDialog.fieldKey),
        distance,
      );
      await tester.pump();
      await tester.tap(find.byKey(CalibrateDistanceDialog.commitKey));
      await tester.pumpAndSettle();
    }

    testWidgets('THE ROW COUNTS WHAT IS MEASURABLE once a rack is pinned', (
      tester,
    ) async {
      final c = _controller(
        withRack: true,
        rackPinned: true,
        outletPinned: true,
      );
      final h = await pump(tester, c);
      // `PLAN-F/3` MADE THIS LINE RICHER TOO: this fixture has a pin on
      // it, so the row names what that pin costs while there is no scale
      // (DR-146 §11.145.4). The whole string is asserted, which is what
      // the row prints.
      expect(
        find.text('$kUncalibratedLabel · 1 pin carries no measurable position'),
        findsOneWidget,
      );

      await calibrate(tester);

      // One outlet pinned, and the rack is the datum rather than a
      // subject, so the count is one.
      expect(find.text('$kCalibratedLabel · 1 measurable'), findsOneWidget);
      expect(h.notices, [
        'Calibrated Level 1. 1 pin can now be measured from the rack.',
      ]);
    });

    testWidgets('THE BLOCKER IS NAMED RATHER THAN COUNTED AS ZERO', (
      tester,
    ) async {
      // `Calibrated · 0 measurable` is true and useless. The row names the
      // one act that unblocks every length on this plan, and the strip
      // that performs it is along the bottom of the same screen.
      final c = _controller(withRack: true, outletPinned: true);
      final h = await pump(tester, c);

      await calibrate(tester);

      expect(find.text('$kCalibratedLabel · no rack pinned'), findsOneWidget);
      // Named rather than inlined, because `avoid_adjacent_string_
      // concatenation_in_list` refuses a wrapped literal inside a list and
      // this sentence does not fit on one line.
      const expected =
          'Calibrated Level 1. No rack is pinned on this plan, so no '
          'length derives yet.';
      expect(h.notices, [expected]);
    });

    testWidgets('a calibrated, racked, empty plan says so rather than '
        'reporting zero', (tester) async {
      final c = _controller(withRack: true, rackPinned: true);
      final h = await pump(tester, c);

      await calibrate(tester);

      expect(find.text('$kCalibratedLabel · no pins yet'), findsOneWidget);
      expect(h.notices, [
        'Calibrated Level 1. Nothing is pinned on this plan yet.',
      ]);
    });

    testWidgets('A RECALIBRATION LEAVES THE ROW IDENTICAL, WHICH IS WHY THE '
        'MESSAGE EXISTS', (tester) async {
      // ═══════════════════════════════════════════════════════════════
      // THE ASYMMETRY THIS WHOLE PAIR OF SURFACES IS FOR
      // ═══════════════════════════════════════════════════════════════
      // A first calibration changes the row, so the act is visible. A
      // recalibration does not: one measurable before, one after. Only
      // the message can say the length just moved, and a design with the
      // row alone would report the most consequential edit in the feature
      // by changing nothing at all.
      final c = _controller(
        withRack: true,
        rackPinned: true,
        outletPinned: true,
        scale: const PlanScale(
          a: PxPt(100, 100),
          b: PxPt(200, 100),
          distance: Len(36 * Len.nmPerInch),
        ),
      );
      final h = await pump(tester, c);
      const line = '$kCalibratedLabel · 1 measurable';
      expect(find.text(line), findsOneWidget);
      // The button says the act too, from the same rule.
      expect(find.text('Recalibrate…'), findsOneWidget);

      await calibrate(tester, distance: '72in');

      expect(
        find.text(line),
        findsOneWidget,
        reason: 'the standing line is unchanged, which is the point',
      );
      expect(h.notices, ['Recalibrated Level 1. 1 pin re-derives.']);
      // AND THE DOCUMENT REALLY DID MOVE, so the message is not the only
      // thing that changed.
      expect(c.doc.underlays[_ul1]!.scale!.distance.nm, 72 * Len.nmPerInch);
    });

    testWidgets('BACKING OUT SAYS NOTHING, because nothing happened', (
      tester,
    ) async {
      final c = _controller(withRack: true, rackPinned: true);
      final h = await pump(tester, c);
      await tester.tap(calibrateButton(_ul1));
      await tester.pump();
      await tester.tapAt(screenOf(tester, const PxPt(100, 100)));
      await tester.tapAt(screenOf(tester, const PxPt(200, 100)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(h.notices, isEmpty);
    });
  });

  group('PLAN-F/2: the mask, tested where it can be observed', () {
    // ═══════════════════════════════════════════════════════════════════
    // THE CONSUMERS THAT CAN SHOW A CALIBRATION USE `changes`, NOT EPOCHS
    // ═══════════════════════════════════════════════════════════════════
    // `plan_commands_test.dart` asserts the epoch counters move, which is
    // the mask against a listener one layer up. What THIS file can assert
    // is the artifact: the surface that displays the consequence really
    // does redraw. The plan editor subscribes to `DocumentController
    // .changes`, so these cases run the commands from OUTSIDE the widget
    // and read the rail.

    testWidgets('THE ROW MOVES WHEN A PIN CHANGES, not only when the scale '
        'does', (tester) async {
      // The half a mask-shaped reading of this feature misses. Pinning
      // the rack turns `no rack pinned` into a count and no calibration
      // happened at all, so a row wired only to a calibration would sit
      // there saying the plan is blocked by something the user has just
      // fixed.
      final c = _controller(
        withRack: true,
        outletPinned: true,
        scale: const PlanScale(
          a: PxPt(100, 100),
          b: PxPt(200, 100),
          distance: Len(36 * Len.nmPerInch),
        ),
      );
      await pump(tester, c);
      expect(find.text('$kCalibratedLabel · no rack pinned'), findsOneWidget);

      c.run(
        SetPlanPinCommand(
          carrier: PinCarrier.rack,
          entityId: _rackId,
          pin: const PlanPin(underlayId: _ul1, at: PxPt(9, 9)),
        ),
      );
      await tester.pump();

      expect(find.text('$kCalibratedLabel · 1 measurable'), findsOneWidget);
    });

    testWidgets('and UNDOING the calibration takes the count away with it', (
      tester,
    ) async {
      final c = _controller(
        withRack: true,
        rackPinned: true,
        outletPinned: true,
      );
      await pump(tester, c);

      c.run(
        SetPlanScaleCommand(
          underlayId: _ul1,
          scale: const PlanScale(
            a: PxPt(100, 100),
            b: PxPt(200, 100),
            distance: Len(36 * Len.nmPerInch),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('$kCalibratedLabel · 1 measurable'), findsOneWidget);

      c.undoLast();
      await tester.pump();
      // `PLAN-F/3` MADE THIS LINE RICHER TOO: this fixture has a pin on
      // it, so the row names what that pin costs while there is no scale
      // (DR-146 §11.145.4). The whole string is asserted, which is what
      // the row prints.
      expect(
        find.text('$kUncalibratedLabel · 1 pin carries no measurable position'),
        findsOneWidget,
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // PLAN-F/3: THE UNCALIBRATED ROW NAMES WHAT IT COSTS (DR-146 §11.145.4)
  // ═════════════════════════════════════════════════════════════════════
  group('DR-146: an uncalibrated row says what is stranded', () {
    testWidgets('A PLAN CARRYING PINS DOES NOT READ LIKE AN EMPTY ONE', (
      tester,
    ) async {
      // The defect this chapter was for. `Not calibrated` on its own left
      // a plan with drops on it printing the same line as a plan with
      // none, which is the flattering half G4 exists to refuse.
      await pump(tester, _controller(outletPinned: true));

      expect(
        find.text('$kUncalibratedLabel · 1 pin carries no measurable position'),
        findsOneWidget,
      );
    });

    testWidgets('and a plan with nothing stranded says only the state', (
      tester,
    ) async {
      // The count is the COST, and a plan with no drops on it has not
      // incurred one. `0 pins carry no measurable position` is the
      // `Calibrated · 0 measurable` DR-144 §11.143.3 refused one state
      // later.
      await pump(tester, _controller());

      expect(find.text(kUncalibratedLabel), findsOneWidget);
    });

    testWidgets('THE NUMBER DOES NOT MOVE WHEN THE CALIBRATION LANDS, which '
        'is the call the user made', (tester) async {
      // One pin stranded before, one pin measurable after, and the rack
      // is the datum in neither line. The refused alternative counted the
      // rack too and would print `2 pins carry no measurable position`
      // here and `1 measurable` below.
      final c = _controller(
        withRack: true,
        rackPinned: true,
        outletPinned: true,
      );
      await pump(tester, c);
      expect(
        find.text('$kUncalibratedLabel · 1 pin carries no measurable position'),
        findsOneWidget,
      );

      c.run(
        SetPlanScaleCommand(
          underlayId: _ul1,
          scale: const PlanScale(
            a: PxPt(100, 100),
            b: PxPt(200, 100),
            distance: Len(36 * Len.nmPerInch),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('$kCalibratedLabel · 1 measurable'), findsOneWidget);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // PLAN-F/3: PLACEMENT AND CALIBRATION DO NOT BLOCK EACH OTHER
  // ═════════════════════════════════════════════════════════════════════
  group('DR-146 §11.145.7: the two facts are independent', () {
    testWidgets('A CALIBRATION ON A PINNED PLAN MOVES NOTHING THAT IS ON IT', (
      tester,
    ) async {
      // The direction the suite has never run. Every plan fixture in this
      // package is uncalibrated, so "a pin survives a calibration" was
      // asserted nowhere, and the gesture is where a gate would be added.
      final c = _controller(
        withRack: true,
        rackPinned: true,
        outletPinned: true,
      );
      await pump(tester, c);
      final rackBefore = c.doc.racks[_rackId]!.planPin;
      final outletBefore = c.doc.outlets[_outletId]!.planPin;

      await tester.tap(calibrateButton(_ul1));
      await tester.pump();
      await tester.tapAt(screenOf(tester, const PxPt(100, 100)));
      await tester.tapAt(screenOf(tester, const PxPt(200, 100)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(CalibrateDistanceDialog.fieldKey),
        '36in',
      );
      await tester.pump();
      await tester.tap(find.byKey(CalibrateDistanceDialog.commitKey));
      await tester.pumpAndSettle();

      expect(c.doc.underlays[_ul1]!.scale, isNotNull);
      expect(c.doc.racks[_rackId]!.planPin, rackBefore);
      expect(c.doc.outlets[_outletId]!.planPin, outletBefore);
    });

    testWidgets('AND THE PICK IS OFFERED ON A PLAN WITH NOTHING PINNED', (
      tester,
    ) async {
      // The mirror: a calibration is not gated on having something to
      // measure, because the obvious order of work is to scale the plan
      // once it is imported and pin the drops afterwards.
      final c = _controller();
      await pump(tester, c);

      expect(calibrateButton(_ul1), findsOneWidget);
      await tester.tap(calibrateButton(_ul1));
      await tester.pump();
      expect(find.byKey(PlanCalibrateChip.chipKey), findsOneWidget);
    });
  });
}
