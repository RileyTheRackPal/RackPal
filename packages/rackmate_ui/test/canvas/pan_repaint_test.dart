// A PAN REPAINTS NOTHING (`#704`).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THE ASSERTION IS A COUNT AND NOT A DURATION
// ═══════════════════════════════════════════════════════════════════════
// A timing test on a build machine measures the build machine, and the
// number it produces has to be given a threshold that is either so loose
// it never fails or so tight it fails on a busy runner. The defect is not
// "painting is slow", it is "painting happens at all": the viewport
// notified, `markNeedsPaint` ran, and the whole display list was re-issued
// for a document nobody had touched. A pan that does not increment
// `debugSceneRecordings` is a pan that did no Dart painting, at any
// document size, on any machine.
//
// THE SECOND ASSERTION IS THAT IT STILL MOVES. An optimisation that stops
// repainting AND stops the picture moving is not an optimisation, and a
// count-only test would pass for it. Every case below checks the matrix
// the canvas last painted through as well as the recording count.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'schematic/schematic_test_document.dart';

/// A REAL PLAN over the shared fixture, not a hand-rolled one. The
/// question is whether the render object re-walks a display list, and a
/// one-op plan would answer it while hiding whether the plan is the thing
/// being walked.
SchematicPaintPlan _plan({DBox? ground}) {
  final doc = buildSchematicTestDocument();
  final scene = buildFixtureScene(doc);
  const filter = SchematicViewFilter();
  return buildSchematicPaintPlan(
    scene: scene,
    doc: doc,
    filter: filter,
    scope: resolveDrawnScope(
      scene: scene,
      filter: filter,
      focusedDeviceIds: const <String>{},
      altHoveredDeviceId: null,
      designatorOf: (id) => id,
    ),
    measurer: const FakeMeasurer(),
    palette: const SchematicPalette(),
    groundArgb: ground == null ? 0xFFF8F8F8 : 0xFF00FF00,
  );
}

RenderSchematicCanvas _canvas(WidgetTester tester) =>
    tester.renderObject<RenderSchematicCanvas>(
      find.byType(SchematicCanvasBody),
    );

Future<ViewportController> _pump(WidgetTester tester) async {
  final viewport = ViewportController();
  addTearDown(viewport.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SchematicCanvasBody(
          plan: _plan(),
          viewport: viewport,
          measurer: const FakeMeasurer(),
        ),
      ),
    ),
  );
  return viewport;
}

void main() {
  testWidgets('A PAN DOES NOT REPAINT, and it still moves', (tester) async {
    final viewport = await _pump(tester);
    final canvas = _canvas(tester);

    final afterFirstFrame = canvas.debugSceneRecordings;
    expect(afterFirstFrame, greaterThan(0), reason: 'it painted once');
    final before = canvas.debugSceneToScreen!.clone();

    for (var i = 0; i < 30; i++) {
      viewport.panBy(const Offset(4, 3));
      await tester.pump();
    }

    expect(
      canvas.debugSceneRecordings,
      afterFirstFrame,
      reason: 'thirty pan frames walked the display list again',
    );
    // AND THE PICTURE MOVED. 30 pans of (4, 3) is (120, 90).
    final after = canvas.debugSceneToScreen!;
    expect(after.storage[12] - before.storage[12], closeTo(120, 0.001));
    expect(after.storage[13] - before.storage[13], closeTo(90, 0.001));
  });

  testWidgets('a ZOOM does not repaint either', (tester) async {
    // Zoom runs through the same matrix and the same layer. It is a
    // separate case because it is a post-multiply where pan is a
    // pre-multiply (`viewport_controller.dart`), so the two could be
    // wired differently by accident.
    final viewport = await _pump(tester);
    final canvas = _canvas(tester);
    final painted = canvas.debugSceneRecordings;

    for (var i = 0; i < 10; i++) {
      viewport.zoomBy(1.1, screenPivot: const Offset(200, 150));
      await tester.pump();
    }

    expect(canvas.debugSceneRecordings, painted);
    expect(canvas.debugSceneToScreen!.storage[0], greaterThan(1.0));
  });

  testWidgets('A CHANGED PLAN STILL REPAINTS, which is the half that '
      'would fail silently', (tester) async {
    // The failure mode of this optimisation is an editor whose canvas
    // stops updating. It is worth more than the optimisation, so it gets
    // its own case rather than being inferred from the pan ones.
    final viewport = ViewportController();
    addTearDown(viewport.dispose);

    Future<void> pumpWith(SchematicPaintPlan plan) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchematicCanvasBody(
            plan: plan,
            viewport: viewport,
            measurer: const FakeMeasurer(),
          ),
        ),
      ),
    );

    await pumpWith(_plan());
    final canvas = _canvas(tester);
    final painted = canvas.debugSceneRecordings;

    await pumpWith(_plan(ground: const DBox.fromLtwh(0, 0, 10, 10)));

    expect(canvas.debugSceneRecordings, greaterThan(painted));
  });

  testWidgets('THE BASE PLAN SURVIVES AN OVERLAY CHANGE (`#705`)', (
    tester,
  ) async {
    // `buildSchematicPaintPlan` ran inside `build`, so every `setState` on
    // the screen — selecting a cable, moving the pin caret, arming a wire
    // — re-emitted every symbol and every net label in the document.
    // 7,155 ops and 5.6 ms on the 300-link fixture, per keystroke.
    //
    // THE ARTIFACT IS SHARED IDENTITY, not a counter. `withOverlay` copies
    // the op list and SHARES every other field, so a `drawnWires` list
    // that is the same object across an overlay change is proof the base
    // was reused rather than rebuilt. A counter would have needed the
    // private State to be reachable; this needs nothing.
    final plan = _plan();
    final overlaid = plan.withOverlay(const <DiagramOp>[]);
    expect(
      identical(overlaid, plan),
      isTrue,
      reason:
          'an empty overlay must not even copy: it is what lets the '
          'render object short-circuit on `identical` and skip the '
          'frame entirely',
    );

    final withRing = plan.withOverlay([plan.ops.first]);
    expect(withRing.ops, hasLength(plan.ops.length + 1));
    expect(
      identical(withRing.drawnWires, plan.drawnWires),
      isTrue,
      reason: 'the base was rebuilt for a caret ring',
    );
    expect(identical(withRing.scope, plan.scope), isTrue);
    expect(withRing.ground, plan.ground);
  });

  // THE RACK CANVAS'S OWN CASE LIVES IN `render_rack_canvas_test.dart`,
  // beside the harness that already builds a rack with three devices in
  // it. It is the heavier half of `#704`: `RenderDeviceBox` is not a
  // repaint boundary, so a repaint there replays the chassis fragment AND
  // every device's.

  testWidgets('a pan AFTER a plan change is still free', (tester) async {
    // The layer is replaced on every real repaint, so the handle the pan
    // path mutates has to be the NEW one. Holding a stale layer would
    // show up here and nowhere else.
    final viewport = await _pump(tester);
    final canvas = _canvas(tester);

    viewport.panBy(const Offset(10, 10));
    await tester.pump();
    canvas.markNeedsPaint();
    await tester.pump();
    final painted = canvas.debugSceneRecordings;

    for (var i = 0; i < 10; i++) {
      viewport.panBy(const Offset(1, 1));
      await tester.pump();
    }

    expect(canvas.debugSceneRecordings, painted);
    expect(canvas.debugSceneToScreen!.storage[12], closeTo(20, 0.001));
  });
}
