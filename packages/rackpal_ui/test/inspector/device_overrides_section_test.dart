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

/// SCROLLS FIRST, ALWAYS. The section lives in a `SingleChildScrollView`
/// inside a 320px column, so ACCENT and BODY DEPTH sit below the fold on a
/// test-sized window. A `tap` on an off-screen widget derives an offset
/// that hits something else, the state does not change, and the assertion
/// that follows blames the feature. That is what happened when these cases
/// were first written, and it is why every driver here calls
/// `ensureVisible`.
Future<void> _tapSegment(
  WidgetTester tester,
  String field,
  String word,
) async {
  final f = _segment(field, word);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final f = find.byKey(key);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _typeInto(WidgetTester tester, Key key, String text) async {
  final f = find.byKey(key);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.enterText(f, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
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
    await _typeInto(tester, const ValueKey('override-value-MASS'), '30');

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

    await _typeInto(tester, const ValueKey('override-value-MASS'), '42');

    expect(
      _device(tester, 'UPS-1').overrides.weightState,
      isA<OverrideStated<Mass>>(),
    );
  });

  testWidgets('ACCENT offers the SAME eight swatches the builder does, '
      'from one list', (tester) async {
    // A swatch a person can pick on a template and not on an instance
    // reads as a bug in whichever surface they met second. The builder's
    // private `_swatches` is deleted and both now read
    // `kDeviceAccentSwatches`, so this asserts the count against the
    // shared list rather than against a literal eight.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _selectDevice(tester, 1);
    await _tapSegment(tester, 'ACCENT', 'Value');

    expect(
      find.byKey(const ValueKey('override-swatches-ACCENT')),
      findsOneWidget,
    );
    for (final c in kDeviceAccentSwatches) {
      expect(
        find.byKey(ValueKey('override-swatch-${c.argb}')),
        findsOneWidget,
        reason: 'swatch ${c.argb.toRadixString(16)} is missing',
      );
    }
  });

  testWidgets('PICKING AN ACCENT REPAINTS THE DEVICE BODY, which is what '
      'makes it worth having in the column rather than a modal', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _selectDevice(tester, 1);
    await _tapSegment(tester, 'ACCENT', 'Value');

    // The third swatch, chosen because the FIRST is pure black and would
    // make "did the fill change" ambiguous against a dark theme.
    final pick = kDeviceAccentSwatches[2];
    await _tapKey(tester, ValueKey('override-swatch-${pick.argb}'));

    expect(_device(tester, 'UPS-1').overrides.accentColor, pick);
    expect(
      _device(tester, 'UPS-1').overrides.accentColorState,
      OverrideStated<Rgb>(pick),
    );
  });

  testWidgets('an UNKNOWN accent resolves to nothing, exactly as an '
      'inherited one does, and the segment is where the difference is '
      'readable', (tester) async {
    // The one place two of the three states are indistinguishable ON THE
    // CANVAS, and it is deliberate: a fill has no way to draw an unknown.
    // The DOCUMENT still tells them apart, which is what this asserts.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _selectDevice(tester, 1);
    await _tapSegment(tester, 'ACCENT', 'Unknown');

    final o = _device(tester, 'UPS-1').overrides;
    expect(o.accentColorState, const OverrideUnknown<Rgb>());
    expect(
      o.resolveAccentColor(null),
      isNull,
      reason:
          'unknown resolves to null, so the layer falls through to the '
          'palette default',
    );
    expect(
      o.accentColorState,
      isNot(const OverrideInherited<Rgb>()),
      reason:
          'the document must still distinguish the two states even '
          'though the canvas cannot',
    );
  });

  testWidgets('BODY DEPTH edits, and says plainly that nothing reads it '
      'yet', (tester) async {
    // A control whose effect is invisible is what `inspector_panel.dart`'s
    // deferral warns against. The answer is not to hide the field, whose
    // value is real and round-trips, but to say where its reader is.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _selectDevice(tester, 1);
    await _tapSegment(tester, 'BODY DEPTH', 'Value');
    await _typeInto(
      tester,
      const ValueKey('override-value-BODY DEPTH'),
      '14.5',
    );

    expect(_device(tester, 'UPS-1').overrides.bodyDepth, isNotNull);
    expect(
      find.text('Read by the depth-clearance rule, which ships in M5.'),
      findsOneWidget,
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
    // docs/06 §8.2's OWN SENTENCE. An earlier draft of the widget reworded
    // it and this case pinned the rewording, so the two agreed with each
    // other and with nothing else. It now names the device, which is what
    // makes the badge a claim about a subject rather than a general notice.
    expect(badge.single, startsWith('Editing UPS-1 only.'));
    expect(badge.single, contains('template'));
  });
}
