// THE THREE DEFECTS THAT SANK THE PREVIOUS SCHEMATIC CANVAS, each with a
// test that would have caught it (docs/m1-implementation-log.md, commit
// `b560a50`).
//
// All three are widget-level, and that is the point: none of them was
// visible from a unit test of the geometry, all three were visible the
// first time a real render object painted a real document at a real paint
// offset, and twelve consecutive `fix:` commits went past every one of
// them because nothing pumped the canvas.
//
//   1. THE DOCUMENT NEVER REACHED THE CANVAS. `main.dart` passed a
//      hardcoded empty `DiagramScene` and the canvas manufactured a symbol
//      with `Pin1`/`Pout1` ports to fill the hole. `the document reaches
//      the canvas` mounts a real document and asserts its own designators
//      are in what gets painted — and that nothing shaped like the
//      fabricated port labels is.
//   2. THE BACKGROUND IGNORED THE PAINT OFFSET while the symbols did not,
//      so it painted over the toolbar and one symbol appeared to float.
//      `every op goes through one matrix` mounts the canvas BELOW a
//      toolbar, where the paint offset is non-zero, and asserts the
//      matrix carries it — plus that the sheet ground is inside the same
//      display list rather than beside it.
//   3. `updateRenderObject` WAS A NO-OP: every setter was guarded with
//      `identical()` against a `final List` the widget mutated in place,
//      so no `setState` could ever mark it needing paint. `a new plan
//      marks the render object needing paint` calls the setter directly,
//      and `a rebuild with a new plan repaints` proves the widget path
//      reaches it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'schematic_test_document.dart';

/// A canvas mounted under a 64px toolbar, so its paint offset is NOT zero.
///
/// THE WHOLE INSTRUMENT FOR DEFECT 2. At `Offset.zero` a canvas that
/// ignores its paint offset and one that honours it are indistinguishable,
/// which is exactly why the defect survived twelve fixes — the deleted
/// canvas also lived under a toolbar, and it was the toolbar it painted
/// over.
const double kToolbarHeight = 64;

void main() {
  late RackDocument doc;
  late SchematicScene scene;

  setUp(() {
    doc = buildSchematicTestDocument();
    scene = buildFixtureScene(doc);
  });

  SchematicPaintPlan planFor({SchematicViewFilter? filter}) {
    final f = filter ?? const SchematicViewFilter();
    return buildSchematicPaintPlan(
      scene: scene,
      doc: doc,
      filter: f,
      scope: resolveDrawnScope(
        scene: scene,
        filter: f,
        altHoveredDeviceId: null,
        focusedDeviceIds: const <String>{},
        designatorOf: (id) => id,
      ),
      measurer: const FakeMeasurer(),
      palette: const SchematicPalette(),
      groundArgb: 0xFFF8F8F8,
    );
  }

  Future<ViewportController> pump(
    WidgetTester tester,
    SchematicPaintPlan plan, {
    ViewportController? viewport,
  }) async {
    final vp = viewport ?? ViewportController();
    addTearDown(vp.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const SizedBox(height: kToolbarHeight, child: Placeholder()),
            Expanded(
              child: SchematicCanvasBody(
                plan: plan,
                viewport: vp,
                measurer: const FakeMeasurer(),
              ),
            ),
          ],
        ),
      ),
    );
    return vp;
  }

  RenderSchematicCanvas renderObjectIn(WidgetTester tester) =>
      tester.renderObject<RenderSchematicCanvas>(
        find.byType(SchematicCanvasBody),
      );

  group('1 — the document reaches the canvas', () {
    testWidgets('what gets painted is the DOCUMENT, not a manufactured '
        'symbol', (tester) async {
      await pump(tester, planFor());
      final painted = renderObjectIn(tester).plan.ops;

      expect(
        painted,
        isNotEmpty,
        reason:
            'the canvas is replaying an empty list — this is the '
            'b560a50 failure exactly',
      );
      final texts = painted.whereType<OpText>().map((t) => t.text).toSet();
      for (final designator in kFixtureDesignators) {
        if (designator == kFixturePortlessDesignator) continue;
        expect(texts, contains(designator));
      }
      expect(
        texts.where((t) => RegExp(r'^P?(in|out)\d+$').hasMatch(t)),
        isEmpty,
        reason: 'the deleted canvas drew ports labelled Pin1 / Pout1',
      );
    });

    testWidgets('a canvas with a real plan paints without throwing', (
      tester,
    ) async {
      await pump(tester, planFor());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('2 — the ground is painted INSIDE the clip and INSIDE the '
      'transform', () {
    // ── WHAT "PAINT OFFSET" MEANS UNDER A REPAINT BOUNDARY ──────────────
    // This render object is `isRepaintBoundary`, so Flutter hands `paint`
    // `Offset.zero` and carries the on-screen position on the layer
    // instead. The offset TERM is therefore normally zero, which is
    // precisely why "the fill ignored the paint offset" is invisible to
    // any test that only reads coordinates: zero composed and zero
    // dropped look the same.
    //
    // So these assert the two structural properties that make the defect
    // unreachable rather than merely absent today, over the RECORDED
    // CANVAS CALLS (the same instrument `shell_tabs_test.dart` uses):
    //   * a clip of the canvas's own box is pushed FIRST, so nothing this
    //     object paints can land on the toolbar above it whatever
    //     transform it gets; and
    //   * the sheet ground is emitted AFTER the transform. The deleted
    //     canvas emitted its fill BEFORE — outside it — while the symbols
    //     went inside, which is the whole of the defect and is exactly
    //     what an ordering assertion catches.

    testWidgets('the clip comes first, the transform second, and the sheet '
        'ground third', (tester) async {
      final plan = planFor();
      await pump(tester, plan);
      final size = tester.getSize(find.byType(SchematicCanvasBody));
      // THE ORDER IS THE ASSERTION, not the rect's coordinates: the
      // deleted canvas emitted its fill BEFORE the transform. The rect's
      // VALUE is pinned op-for-op in `the sheet ground is op ZERO` below —
      // asserting it here as well would compare a `Rect` this test
      // rebuilt from `DBox` doubles against one `FlutterDiagramCanvas`
      // rebuilt from the same doubles a different way, which differs in
      // the last ULP and prints identically.
      expect(
        find.byType(SchematicCanvasBody),
        paints
          ..clipRect(rect: Offset.zero & size)
          ..transform()
          ..rect(),
      );
    });

    testWidgets('the recorded transform is exactly translate(offset) × '
        'viewport', (tester) async {
      // Pan first: `translate(offset) * viewport` must show the viewport
      // term. Getting the multiply order backwards is the classic
      // hand-rolled-viewport bug (`viewport_controller.dart`'s header).
      final vp = await pump(tester, planFor());
      vp.panBy(const Offset(30, -12));
      await tester.pump();
      final matrix = renderObjectIn(tester).debugSceneToScreen!;
      expect(matrix.storage[12], 30);
      expect(matrix.storage[13], -12);
      // …and a transform really is pushed, inside the clip, on the
      // recorded canvas. (The VALUE is asserted through
      // `debugSceneToScreen` above rather than through
      // `paints..transform(matrix4:)`, which compares a `Matrix4` against
      // the raw `Float64List` the canvas records and therefore never
      // matches — a trap worth naming, since it fails as a mismatch
      // rather than as an error.)
      expect(
        find.byType(SchematicCanvasBody),
        paints
          ..clipRect()
          ..transform(),
      );
    });

    test('the composition itself carries the offset, at an offset a '
        'repaint boundary can never produce', () {
      // THE ASSERTION THE WIDGET TESTS ABOVE CANNOT MAKE. A repaint
      // boundary is always painted at `Offset.zero`, so a version of the
      // render object that DROPPED the offset term passes every widget
      // test in this file — a mutation that did exactly that survived the
      // suite, which is why `schematicSceneToScreen` exists as a free
      // function. Here it is driven with the offset a non-boundary would
      // get.
      final viewport = Matrix4.identity()
        ..setEntry(0, 0, 2)
        ..setEntry(1, 1, 2)
        ..setEntry(0, 3, 7)
        ..setEntry(1, 3, 11);
      final m = schematicSceneToScreen(const Offset(37, 64), viewport);
      // A scene point maps through the viewport FIRST and is then moved by
      // the widget's own position: (5,5) → (2·5+7, 2·5+11) → +(37,64).
      expect(m.storage[0], 2);
      expect(m.storage[5], 2);
      expect(m.storage[12], 7 + 37);
      expect(m.storage[13], 11 + 64);
    });

    testWidgets('the sheet ground is op ZERO of the plan, so there is no '
        'second draw to get the offset wrong', (tester) async {
      final plan = planFor();
      await pump(tester, plan);
      final painted = renderObjectIn(tester).plan.ops;
      expect(painted.first, isA<OpRect>());
      expect((painted.first as OpRect).r, plan.ground);
    });
  });

  group('3 — updateRenderObject is not a no-op', () {
    testWidgets('a new plan marks the render object needing paint', (
      tester,
    ) async {
      await pump(tester, planFor());
      final ro = renderObjectIn(tester);
      expect(ro.debugNeedsPaint, isFalse);

      ro.plan = planFor(
        filter: SchematicViewFilter(
          visibleDomains: <SignalDomainId>{
            scene.domainFragments.keys.first,
          },
          explicit: true,
        ),
      );
      expect(
        ro.debugNeedsPaint,
        isTrue,
        reason:
            'the setter accepted a new plan and asked for no repaint — '
            'this is the guard that made twelve fixes invisible',
      );
    });

    testWidgets('the SAME plan asks for no repaint, so the guard is a real '
        'guard and not an unconditional markNeedsPaint', (tester) async {
      final plan = planFor();
      await pump(tester, plan);
      final ro = renderObjectIn(tester)..plan = plan;
      expect(ro.debugNeedsPaint, isFalse);
    });

    testWidgets('rebuilding the widget with a new plan changes what is '
        'painted', (tester) async {
      // The WIDGET path, which is where defect 3 actually lived: the
      // setters were fine in isolation and `updateRenderObject` never
      // reached them with a value that differed.
      final vp = ViewportController();
      addTearDown(vp.dispose);
      Future<void> mount(SchematicPaintPlan plan) => tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              const SizedBox(height: kToolbarHeight, child: Placeholder()),
              Expanded(
                child: SchematicCanvasBody(
                  plan: plan,
                  viewport: vp,
                  measurer: const FakeMeasurer(),
                ),
              ),
            ],
          ),
        ),
      );

      await mount(planFor());
      expect(renderObjectIn(tester).plan.ops.whereType<OpPolyline>(), isEmpty);

      await mount(
        planFor(
          filter: SchematicViewFilter(
            visibleDomains: <SignalDomainId>{scene.domainFragments.keys.first},
            explicit: true,
          ),
        ),
      );
      expect(
        renderObjectIn(tester).plan.ops.whereType<OpPolyline>(),
        isNotEmpty,
        reason: 'the render object is still holding the first plan',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the viewport drives repaints without a setState', () {
    testWidgets('panning marks the canvas needing paint', (tester) async {
      // docs/03 §7.3: "no setState in the canvas path". The render object
      // subscribes to the `ViewportController` in `attach`, so a pan is a
      // pure repaint.
      final vp = await pump(tester, planFor());
      final ro = renderObjectIn(tester);
      expect(ro.debugNeedsPaint, isFalse);
      vp.panBy(const Offset(5, 5));
      expect(ro.debugNeedsPaint, isTrue);
    });
  });
}
