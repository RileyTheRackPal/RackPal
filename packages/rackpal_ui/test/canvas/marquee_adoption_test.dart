// PLAN-E/6: CR-102's band on a real canvas (DR-139 §11.138).
//
// ═══════════════════════════════════════════════════════════════════════
// THE PRODUCT'S FIRST MULTI-SELECTION, ASSERTED AS A COUNT
// ═══════════════════════════════════════════════════════════════════════
// `PLAN-E/1` censused the mechanism and found that **every `SelectMode`
// call in `lib/` passes exactly one id**: `SelectionController` holds a
// `Set<Uuid>` and no gesture had ever put more than one thing in it.
// So the case that matters is not "a band appears" but "a band over two
// devices leaves TWO selected", which is the shape this repo's own
// `0 pathways` status bar got wrong by pinning the flattering number.
//
// `marquee_test.dart` in core owns the geometry. What is here is the
// adoption: that a drag on empty canvas reaches it at all, that the
// selection it produces lands, and that the gestures already on this
// canvas still work.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

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

Widget _app() => MaterialApp(
  home: Scaffold(body: RackCanvasScreen(measurer: _FakeMeasurer())),
);

/// Every device the elevation currently draws as selected.
///
/// READ OFF THE RENDER OBJECTS, not off a controller this test cannot
/// reach: the artifact is what a person sees highlighted, and a count
/// taken from the controller would pass just as well if the paint path
/// dropped every id but one.
Set<String> _selected(WidgetTester tester) => {
  for (final r in tester.allRenderObjects.whereType<RenderDeviceBox>())
    if (r.selected) r.deviceId,
};

Rect _rectOf(WidgetTester tester, String id) => tester.getRect(
  find.descendant(
    of: find.byKey(ValueKey(id)),
    matching: find.byType(DeviceBox),
  ),
);

/// A band that fully contains UPS-1 and only CLIPS AMP-1.
///
/// ═══════════════════════════════════════════════════════════════════════
/// DERIVED FROM THE RECTS, NOT FROM WHICH U IS "HIGHER"
/// ═══════════════════════════════════════════════════════════════════════
/// The rack numbers bottom-up (`RuNumbering.bottomUpFromOne`), so AMP-1 at
/// U4 is ABOVE UPS-1 at U1 on screen and screen Y runs the other way. A
/// first draft wrote the band as `ups.top - 6` down to `amp.center.dy` and
/// produced an INVERTED rectangle that caught nothing, which read as the
/// window rule being broken.
///
/// The assertion below states the dependency rather than assuming it, so a
/// renumbering breaks this helper by name instead of breaking two cases
/// mysteriously.
Rect _containsOneClipsOther(WidgetTester tester) {
  final ups = _rectOf(tester, 'dev-ups');
  final amp = _rectOf(tester, 'dev-amp');
  expect(
    amp.bottom,
    lessThan(ups.top),
    reason: 'AMP-1 (U4) sits above UPS-1 (U1); this helper depends on it',
  );
  return Rect.fromLTRB(
    (ups.left < amp.left ? ups.left : amp.left) - 6,
    // Halfway INTO AMP-1, so it is clipped and not contained.
    amp.center.dy,
    (ups.right > amp.right ? ups.right : amp.right) + 6,
    ups.bottom + 6,
  );
}

void main() {
  group('the rack elevation adopts the band', () {
    testWidgets('A WINDOW OVER TWO DEVICES SELECTS TWO', (tester) async {
      // The whole point of the chapter, and the first time this product
      // has held two ids in a selection through any gesture.
      await tester.pumpWidget(_app());
      await tester.pump();

      final ups = _rectOf(tester, 'dev-ups');
      final amp = _rectOf(tester, 'dev-amp');
      final band = ups.expandToInclude(amp).inflate(6);

      final g = await tester.startGesture(band.topLeft);
      await g.moveTo(band.bottomRight);
      await tester.pump();
      await g.up();
      await tester.pump();

      expect(_selected(tester), {'dev-ups', 'dev-amp'});
    });

    testWidgets('a WINDOW that only CLIPS a device leaves it alone', (
      tester,
    ) async {
      // The half that makes the previous case mean something. A band that
      // swallowed everything would pass under either convention, so this
      // one contains UPS-1 and clips AMP-1.
      await tester.pumpWidget(_app());
      await tester.pump();

      final band = _containsOneClipsOther(tester);

      final g = await tester.startGesture(band.topLeft);
      await g.moveTo(band.bottomRight);
      await tester.pump();
      await g.up();
      await tester.pump();

      expect(_selected(tester), {'dev-ups'});
    });

    testWidgets('and a CROSS over the same band takes both', (tester) async {
      // Right to left. Same rectangle, opposite direction, different
      // answer, which is the only way the window/cross rule is tested.
      await tester.pumpWidget(_app());
      await tester.pump();

      final band = _containsOneClipsOther(tester);

      final g = await tester.startGesture(band.topRight);
      await g.moveTo(band.bottomLeft);
      await tester.pump();
      await g.up();
      await tester.pump();

      expect(_selected(tester), {'dev-ups', 'dev-amp'});
    });

    testWidgets('a sweep that catches nothing DESELECTS', (tester) async {
      // What makes an empty band a deselect rather than a no-op with a
      // stuck rectangle. It is also the behaviour that expired
      // canvas_exclusivity_test.dart's unstated premise.
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.tapAt(centreOfRu(tester, const RackGeometry(12), 1, 2));
      await tester.pump();
      expect(_selected(tester), isNotEmpty);

      final empty = emptyCanvasPoint(tester);
      final g = await tester.startGesture(empty);
      await g.moveBy(const Offset(30, 20));
      await tester.pump();
      await g.up();
      await tester.pump();

      expect(_selected(tester), isEmpty);
    });

    testWidgets('A CLICK ON EMPTY CANVAS STILL DOES NOT DRAW A BAND', (
      tester,
    ) async {
      // The band arms past the 4px slop, not on contact, so a click that
      // clears the selection never flashes a rectangle. Asserted through
      // the band's own key rather than by eye.
      await tester.pumpWidget(_app());
      await tester.pump();

      final g = await tester.startGesture(emptyCanvasPoint(tester));
      await g.moveBy(const Offset(1, 1));
      await tester.pump();

      expect(find.byKey(MarqueeBand.bandKey), findsNothing);
      await g.up();
      await tester.pump();
    });

    testWidgets('the band is UP during the drag and GONE after it', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final g = await tester.startGesture(emptyCanvasPoint(tester));
      await g.moveBy(const Offset(60, -40));
      await tester.pump();
      expect(find.byKey(MarqueeBand.bandKey), findsOneWidget);

      await g.up();
      await tester.pump();
      expect(find.byKey(MarqueeBand.bandKey), findsNothing);
    });

    testWidgets('DRAGGING A SELECTED DEVICE STILL MOVES IT', (tester) async {
      // The regression this chapter could most easily have caused: the
      // band begins on empty canvas and nowhere else, so a grab on a
      // device is still a move.
      await tester.pumpWidget(_app());
      await tester.pump();
      const geo = RackGeometry(12);
      await tester.tapAt(centreOfRu(tester, geo, 1, 2));
      await tester.pump();

      final g = await tester.startGesture(centreOfRu(tester, geo, 1, 2));
      await g.moveBy(sceneDelta(tester, 0, -10 * RackGeometry.unitsPerRu));
      await tester.pump();

      expect(find.text('U11-U12'), findsOneWidget, reason: 'the ghost is live');
      await g.up();
      await tester.pump();
    });
  });
}
