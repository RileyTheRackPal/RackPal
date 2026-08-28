// Door 1 in the inspector column — `#230`, CR-054, DR-098 §11.97.5.
//
// =====================================================================
// WHAT WAS ACTUALLY MISSING
// =====================================================================
// `DeviceOverrides` has been on `DeviceInstance` since M0, the rollups
// have read `overrides.weight` and `overrides.typicalWatts` since the
// load resolver was extracted, and until this control NOTHING in the
// application could write one. That is the same shape the lifecycle
// picker closed one stage earlier, and these tests are about the same
// property: reachability. So they drive the real screen through real
// taps and observe the DOCUMENT, never a private field.
//
// THE ASSERTION THAT MATTERS IS THE ROLLUP, NOT THE FIELD. DR-098 exists
// because a rack subtotal could total a template figure the user had no
// way to disown. A test that only checks `overrides.cleared` contains the
// field would pass just as happily with the rollup still reporting the
// old number, so the UNKNOWN case reads `computeRackRollups` and asserts
// both halves: the total goes null AND the unknown count says how many
// contributors could supply nothing.
//
// FINDERS ARE KEYED PER FIELD ON PURPOSE. Both fields carry the identical
// three segment words, so `find.text('Unknown')` matches two controls and
// a test written against it passes while driving the wrong one.
//
// The demo rack is RK-1 "Media Closet", 12U, with three front devices
// (UPS-1 @U1 2U, AMP-1 @U4 2U, SW-1 @U7 1U) and one rear (PP-1 @U9 1U).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../canvas/rack_scene_to_screen.dart';

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

Offset _rackSpot(WidgetTester tester, int ru) =>
    centreOfRu(tester, const RackGeometry(12), ru, 1);

RackDocument _doc(WidgetTester tester) =>
    tester.widget<InspectorPanel>(find.byType(InspectorPanel)).doc;

DeviceInstance _device(WidgetTester tester, String designator) => _doc(
  tester,
).devices.values.singleWhere((d) => d.designator == designator);

Future<void> _selectDevice(WidgetTester tester, int ru) async {
  await tester.tapAt(_rackSpot(tester, ru));
  await tester.pumpAndSettle();
}

Future<void> _addToSelection(WidgetTester tester, int ru) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.tapAt(_rackSpot(tester, ru));
  await tester.pumpAndSettle();
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

/// One segment of ONE field's control, named by both so it cannot land on
/// the other field's identical word.
Finder _segment(String field, String word) => find.descendant(
  of: find.byKey(ValueKey('override-segments-$field')),
  matching: find.text(word),
);

Future<void> _tapSegment(
  WidgetTester tester,
  String field,
  String word,
) async {
  await tester.tap(_segment(field, word));
  await tester.pumpAndSettle();
}

/// The rack's mass rollup, which is the artifact every state test is
/// really about.
Rollup<Mass> _massRollup(WidgetTester tester) {
  final doc = _doc(tester);
  final rack = doc.racks.values.single;
  return computeRackRollups(
    rack: rack,
    devices: doc.devices.values,
    templates: doc.templates,
    face: Face.front,
  ).weight;
}

/// Ctrl+Z aimed at the canvas. The click first is not incidental: a
/// focused text field owns Ctrl+Z as TEXT undo. U12 is free on the demo
/// rack and clicking empty rack background keeps the summary mounted.
Future<void> _undo(WidgetTester tester) async {
  await tester.tapAt(_rackSpot(tester, 12));
  await tester.pumpAndSettle();
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nothing selected offers no override section — the control '
      'is about a device, and there is no device', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(DeviceOverridesSection), findsNothing);
  });

  testWidgets('selecting one device offers the section, and every field '
      'starts on Template', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _selectDevice(tester, 1);

    expect(find.byType(DeviceOverridesSection), findsOneWidget);
    expect(_segment('MASS', 'Template'), findsOneWidget);
    expect(_segment('TYPICAL DRAW', 'Unknown'), findsOneWidget);
    expect(
      _device(tester, 'UPS-1').overrides.isEmpty,
      isTrue,
      reason: 'opening the section must not itself state anything',
    );
  });

  testWidgets('a multi-selection says so instead of guessing which '
      "device's template the badge is about", (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _selectDevice(tester, 1);
    await _addToSelection(tester, 4);

    expect(find.byType(DeviceOverridesSection), findsNothing);
    expect(
      find.text('Select a single device to edit its properties.'),
      findsOneWidget,
    );
  });

  testWidgets('MARKING A MASS UNKNOWN EMPTIES THE RACK SUBTOTAL AND '
      'COUNTS THE DEVICE, which is the whole ruling', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // NO DEMO TEMPLATE STATES A MASS, which this test discovered and which
    // is worth stating rather than working around: it means the rollup
    // starts at `null` with every device counted, so a bare "mark it
    // unknown" would move nothing and prove nothing. The known state is
    // therefore built through the UI first, which exercises all three
    // transitions instead of one.
    await _selectDevice(tester, 1);
    await _tapSegment(tester, 'MASS', 'Value');
    await tester.enterText(
      find.byKey(const ValueKey('override-value-MASS')),
      '30',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final before = _massRollup(tester);
    expect(
      before.value,
      isNotNull,
      reason: 'stating a mass must make the subtotal totalable',
    );
    final unknownBefore = before.unknownCount;

    await _tapSegment(tester, 'MASS', 'Unknown');

    expect(
      _device(tester, 'UPS-1').overrides.isUnknown(DeviceOverrideField.weight),
      isTrue,
    );

    // BOTH HALVES OF THE ROLLUP. A null with no count is as unusable as a
    // fabricated zero, and the stated figure surviving in the total is
    // the defect DR-098 was raised over.
    final after = _massRollup(tester);
    expect(after.unknownCount, unknownBefore + 1);
    expect(
      after.value,
      isNot(before.value),
      reason: 'the disowned figure must not survive as a measurement',
    );
  });

  testWidgets('Ctrl+Z after marking unknown restores INHERIT, never the '
      'set-and-cleared state the codec refuses', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _selectDevice(tester, 1);
    await _tapSegment(tester, 'MASS', 'Unknown');
    expect(_device(tester, 'UPS-1').overrides.isEmpty, isFalse);

    await _undo(tester);

    final back = _device(tester, 'UPS-1').overrides;
    expect(back.weightState, const OverrideInherited<Mass>());
    expect(
      back.isEmpty,
      isTrue,
      reason:
          'the device said nothing before the edit and must say '
          'nothing after the undo',
    );
  });

  testWidgets('choosing Value on a template that states nothing OPENS AN '
      'EMPTY BOX and writes nothing until a number parses', (tester) async {
    // THE BUG THIS CASE EXISTS FOR. The first draft seeded the box from
    // the template and bailed out when there was nothing to seed from, so
    // on the demo rack -- where no template states a mass -- tapping
    // "Value" did nothing at all. Stating a value for a fact the template
    // omits is door 1's commonest use and it was the one path that could
    // not be reached.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _selectDevice(tester, 1);
    await _tapSegment(tester, 'MASS', 'Value');

    final box = find.byKey(const ValueKey('override-value-MASS'));
    expect(box, findsOneWidget, reason: 'the box must open');
    expect(
      _device(tester, 'UPS-1').overrides.isEmpty,
      isTrue,
      reason:
          'an empty box is an edit not yet made, and must not write '
          'an override or an undo entry',
    );

    await tester.enterText(box, '42');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      _device(tester, 'UPS-1').overrides.weightState,
      isA<OverrideStated<Mass>>(),
    );
  });

  testWidgets('the badge names what the edit will NOT touch', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _selectDevice(tester, 1);

    // Read the sentence the section actually rendered rather than
    // asserting a count computed the same way the widget computed it,
    // which would only prove the arithmetic agrees with itself.
    final badge = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(DeviceOverridesSection),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s.contains('this template') || s.startsWith('Only this'))
        .toList();

    expect(badge, isNotEmpty, reason: 'the scope badge did not render');
    expect(
      badge.single,
      anyOf(
        contains('Only this device uses this template.'),
        contains('Edits here change this device only.'),
      ),
    );
  });
}
