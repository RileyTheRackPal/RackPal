// What survives `#704`'s revert (`#707`).
//
// ═══════════════════════════════════════════════════════════════════════
// THIS FILE USED TO ASSERT THAT A PAN REPAINTS NOTHING, AND IT WAS WRONG
// ═══════════════════════════════════════════════════════════════════════
// `#704` made the viewport listener mutate the retained `TransformLayer`
// instead of marking the render object needing paint, so a pan would cost
// no Dart painting. Four cases here went green and the app broke: the
// schematic stopped panning altogether and the rack's chrome stayed put
// while its content moved.
//
// THE CASES WERE VACUOUS AND THE SHAPE IS WORTH REMEMBERING. The listener
// assigned `debugSceneToScreen = matrix` and then mutated the layer; the
// cases asserted that `debugSceneToScreen` had moved. That is a field the
// listener had just written. It moved whether or not anything reached the
// compositor, and a widget test never composites, so nothing in this
// package could have caught it.
//
// WHAT IS LEFT IS THE PART THAT DOES NOT NEED A COMPOSITOR: `#705`'s
// claim that the base plan survives a change to the connect overlay. That
// one is about object identity, which a widget test can see perfectly
// well, and it is asserted below.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'schematic/schematic_test_document.dart';

/// A REAL PLAN over the shared fixture, not a hand-rolled one.
SchematicPaintPlan _plan() {
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
    groundArgb: 0xFFF8F8F8,
  );
}

void main() {
  test('THE BASE PLAN SURVIVES AN OVERLAY CHANGE (`#705`)', () {
    // `buildSchematicPaintPlan` ran inside `build`, so every `setState` on
    // the screen — selecting a cable, moving the pin caret, arming a wire
    // — re-emitted every symbol and every net label in the document.
    // 7,155 ops and 5.6 ms on the 300-link fixture, per keystroke.
    //
    // THE ARTIFACT IS SHARED IDENTITY. `withOverlay` copies the op list
    // and SHARES every other field, so a `drawnWires` list that is the
    // same object across an overlay change is proof the base was reused
    // rather than rebuilt.
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
}
