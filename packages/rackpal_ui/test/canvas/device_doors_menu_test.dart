// CR-054's three doors on the canvas — `#231`, `#232`, docs/06 §8.2.
//
// =====================================================================
// THIS IS THE FIRST RIGHT-CLICK IN THE PRODUCT
// =====================================================================
// `onSecondaryTap` occurred ZERO times in `rackpal_ui` and `rackpal_app`
// before this. The secondary button was routed into `beginDrag` like any
// other, so a right-press armed a marquee on empty canvas and a MOVE on a
// device. CR-102 had reserved it for the context menu since M1 and nothing
// noticed, because nothing bound it and a marquee that opens on right-press
// looks like a marquee.
//
// So the first case here is not about the menu at all: it is that right-
// pressing a device and dragging DOES NOT MOVE IT. That is the defect the
// gesture would otherwise have shipped with.
//
// The demo rack is RK-1 "Media Closet", 12U, three front devices
// (UPS-1 @U1 2U, AMP-1 @U4 2U, SW-1 @U7 1U) and one rear (PP-1 @U9 1U).

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

final List<TemplateId> _editRequests = <TemplateId>[];

Widget _app({bool withShell = true}) => MaterialApp(
  home: Scaffold(
    body: RackCanvasScreen(
      measurer: _FakeMeasurer(),
      onEditTemplate: withShell ? _editRequests.add : null,
    ),
  ),
);

Offset _rackSpot(WidgetTester tester, int ru) =>
    centreOfRu(tester, const RackGeometry(12), ru, 1);

RackDocument _doc(WidgetTester tester) =>
    tester.widget<InspectorPanel>(find.byType(InspectorPanel)).doc;

DeviceInstance _device(WidgetTester tester, String designator) => _doc(
  tester,
).devices.values.singleWhere((d) => d.designator == designator);

/// A real secondary-button press at [spot].
Future<void> _rightClick(WidgetTester tester, Offset spot) async {
  final g = await tester.startGesture(spot, buttons: kSecondaryButton);
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  setUp(_editRequests.clear);

  // THE "RIGHT-DRAG DOES NOT MOVE A DEVICE" CASE IS NOT HERE, AND THAT IS
  // DELIBERATE. Two drafts of it lived at this level and NEITHER COULD FAIL:
  // opening the menu is a modal route that swallows the subsequent pointer
  // moves, so a right-drag leaves the device where it was whether or not the
  // secondary button is consumed. Both passed with the fix reverted. The
  // property belongs to `CanvasIntentDetector` and is asserted in
  // `canvas_intent_detector_test.dart`, where a recording handler can see
  // the `begin/update/commit` that must not happen.

  testWidgets('right-clicking a device offers exactly the three doors', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _rightClick(tester, _rackSpot(tester, 1));

    expect(find.text('Edit this device only'), findsOneWidget);
    expect(find.text('Edit the template…'), findsOneWidget);
    expect(find.text('Fork to a new template'), findsOneWidget);
    // CR-054 deleted the fourth verb and it must not come back.
    expect(find.textContaining('Detach'), findsNothing);
  });

  testWidgets('the menu names the device it is about', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _rightClick(tester, _rackSpot(tester, 4));

    expect(find.text('AMP-1'), findsWidgets);
  });

  testWidgets('right-clicking SELECTS the device, so door 1 has nothing '
      'left to do', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _rightClick(tester, _rackSpot(tester, 4));
    await tester.tap(find.text('Edit this device only'));
    await tester.pumpAndSettle();

    // The override section renders for a single selection (DR-098), so its
    // presence IS door 1 having worked.
    expect(find.byType(DeviceOverridesSection), findsOneWidget);
    expect(
      find.textContaining('Editing AMP-1 only.'),
      findsOneWidget,
      reason: "docs/06 §8.2's own sentence, naming the device",
    );
  });

  testWidgets('right-clicking empty canvas offers nothing', (tester) async {
    // docs/04 §5 specifies an empty-U menu too, and it is not built. A menu
    // with one working row and four that are not is worse than none.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _rightClick(tester, _rackSpot(tester, 12));

    expect(find.text('Edit this device only'), findsNothing);
  });

  group('door 3, fork to a new template', () {
    testWidgets('MINTS A TEMPLATE AND REBINDS THE DEVICE, leaving the '
        'others where they were', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final before = _device(tester, 'AMP-1').templateRef.templateId;
      final templatesBefore = _doc(tester).templates.length;

      await _rightClick(tester, _rackSpot(tester, 4));
      await tester.tap(find.text('Fork to a new template'));
      await tester.pumpAndSettle();

      final after = _device(tester, 'AMP-1').templateRef;
      expect(after.templateId, isNot(before));
      expect(after.version, 1);
      expect(_doc(tester).templates.length, templatesBefore + 1);
    });

    testWidgets('the fork records where it came from, which nothing in this '
        'product could produce before', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final before = _device(tester, 'AMP-1').templateRef;

      await _rightClick(tester, _rackSpot(tester, 4));
      await tester.tap(find.text('Fork to a new template'));
      await tester.pumpAndSettle();

      final doc = _doc(tester);
      final ref = _device(tester, 'AMP-1').templateRef;
      final body =
          doc.templates[templateSnapshotKey(ref.templateId, ref.version)]!.body;
      expect(
        body.derivedFrom,
        TemplateOrigin(
          templateId: before.templateId,
          version: before.version,
        ),
      );
    });

    testWidgets('Ctrl+Z puts the device back on its original template', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final before = _device(tester, 'AMP-1').templateRef.templateId;
      final templatesBefore = _doc(tester).templates.length;

      await _rightClick(tester, _rackSpot(tester, 4));
      await tester.tap(find.text('Fork to a new template'));
      await tester.pumpAndSettle();

      await tester.tapAt(_rackSpot(tester, 12));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(_device(tester, 'AMP-1').templateRef.templateId, before);
      expect(
        _doc(tester).templates.length,
        templatesBefore,
        reason:
            'a template left behind by an undone fork is a shelf entry '
            'nothing points at',
      );
    });
  });

  group('door 2, edit the template', () {
    testWidgets('hands the template id to the shell', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final id = _device(tester, 'AMP-1').templateRef.templateId;

      await _rightClick(tester, _rackSpot(tester, 4));
      await tester.tap(find.text('Edit the template…'));
      await tester.pumpAndSettle();

      expect(_editRequests, <TemplateId>[id]);
    });

    testWidgets('REFUSES OUT LOUD with no shell around it, rather than '
        'doing nothing', (tester) async {
      // This screen is mounted bare in widget tests, and a menu row that
      // silently does nothing there is one somebody debugs for an hour.
      await tester.pumpWidget(_app(withShell: false));
      await tester.pumpAndSettle();

      await _rightClick(tester, _rackSpot(tester, 4));
      await tester.tap(find.text('Edit the template…'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Device Manager is not available'),
        findsOneWidget,
      );
    });
  });
}
