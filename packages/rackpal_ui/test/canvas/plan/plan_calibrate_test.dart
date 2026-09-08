// PLAN-F/1: the two-point pick and the typed distance, through the real
// widget tree (docs/15 §5, DR-144 §11.143).
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
  );
  return DocumentController(doc, clock: FixedClock(_now), actor: 'test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlanImageCache cache;
  setUp(() => cache = PlanImageCache());
  tearDown(() => cache.dispose());

  /// Mounts the whole editor, because the affordance is on the left rail
  /// and the pick is on the canvas: a case that pumped the canvas alone
  /// would prove the gesture and not the route to it.
  ///
  /// The rail is 240 wide and a `VerticalDivider(width: 1)` sits beside
  /// it, so the canvas starts at **x=241** and a point at `(241 + n, m)`
  /// is pixel `(n, m)` of the underlay under an identity viewport. The
  /// divider is one pixel and it is the difference between asserting
  /// `PxPt(100, 100)` and reading `PxPt(99, 100)` back.
  Future<List<String>> pump(
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 900,
              height: 500,
              child: PlanEditorScreen(
                controller: controller,
                images: cache.resolver,
                measurer: const _ZeroMeasurer(),
                selection: SelectionController(),
                arm: arm,
                onRefuse: refusals.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return refusals;
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
      expect(find.text(kCalibratedLabel), findsOneWidget);
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

      // Pixels (100, 100) and (200, 100) of a 600x400 underlay: see
      // `pump` for where the 241 comes from.
      await tester.tapAt(const Offset(341, 100));
      await tester.pump();
      expect(find.text(kCalibrateSecondLabel), findsOneWidget);

      await tester.tapAt(const Offset(441, 100));
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
      // And the row now says so, which is the only report the person gets.
      expect(find.text(kCalibratedLabel), findsOneWidget);

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
      await tester.tapAt(const Offset(341, 100));
      await tester.tapAt(const Offset(441, 100));
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
      await tester.tapAt(const Offset(341, 100));
      await tester.tapAt(const Offset(441, 100));
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
      final refusals = await pump(tester, c);
      await tester.tap(calibrateButton(_ul1));
      await tester.pump();

      await tester.tapAt(const Offset(341, 100));
      await tester.tapAt(const Offset(341, 100));
      await tester.pumpAndSettle();

      expect(find.byType(CalibrateDistanceDialog), findsNothing);
      expect(refusals, [kCalibrateSamePointRefusal]);
      expect(find.text(kCalibrateSecondLabel), findsOneWidget);

      // And it really is still live: a click elsewhere finishes it.
      await tester.tapAt(const Offset(441, 100));
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
      await tester.tapAt(const Offset(341, 100));
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
      await tester.tapAt(const Offset(341, 100));
      await tester.pump();

      expect(
        c.doc.outlets[_outletId]!.planPin,
        isNull,
        reason: 'the click belonged to the pick',
      );
      expect(find.text(kCalibrateSecondLabel), findsOneWidget);
    });
  });
}
