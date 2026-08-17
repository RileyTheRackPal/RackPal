// The inspector's lifecycle picker — board M3-A/7, CR-064.
//
// =====================================================================
// WHAT WAS ACTUALLY MISSING
// =====================================================================
// `LifecycleStatus` has been on `DeviceInstance` since M0, the elevation
// draws a DIFFERENT BORDER for each of its five values, and until this
// control nothing in the application could change the value: every device
// the app created got `new_` and stayed there, so four of those five
// borders were reachable only by hand-editing a file. These tests are
// about that reachability, so they drive the real screen through real
// taps and observe the DOCUMENT, never a private field.
//
// TWO PROPERTIES CARRY THE REST:
//  * every edit is exactly ONE undo entry, whether it touched one device
//    or four (the same law `rack_inspector_panel_test.dart` asserts for
//    every rack field);
//  * the option words come from `lifecycleLabel`, the SAME function that
//    prints the word on T6.30, so the screen and the sheet cannot drift.
//
// The demo rack is RK-1 "Media Closet", 12U, with three front devices
// (UPS-1 @U1 2U, AMP-1 @U4 2U, SW-1 @U7 1U) and one rear (PP-1 @U9 1U).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

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

/// The screen centre of [ru] on the 12U demo rack, THROUGH THE LIVE
/// VIEWPORT — the screen frames the whole rack on first sight (`#710`), so
/// scene (0, 0) is not the canvas's corner.
Offset _rackSpot(WidgetTester tester, int ru) =>
    centreOfRu(tester, const RackGeometry(12), ru, 1);

/// The live document, read through `InspectorPanel` because it is the one
/// inspector widget mounted in BOTH targets — `RackInspectorPanel` is not
/// in the tree while the selection summary is showing, which is exactly
/// when these tests run.
RackDocument _doc(WidgetTester tester) =>
    tester.widget<InspectorPanel>(find.byType(InspectorPanel)).doc;

DeviceInstance _device(WidgetTester tester, String designator) => _doc(
  tester,
).devices.values.singleWhere((d) => d.designator == designator);

Future<void> _selectDevice(WidgetTester tester, int ru) async {
  await tester.tapAt(_rackSpot(tester, ru));
  await tester.pumpAndSettle();
}

/// Ctrl+click, which the screen treats as "toggle this one id".
Future<void> _addToSelection(WidgetTester tester, int ru) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.tapAt(_rackSpot(tester, ru));
  await tester.pumpAndSettle();
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

final Finder _picker = find.byType(
  DropdownButtonFormField<LifecycleStatus>,
);

Future<void> _pick(WidgetTester tester, String option) async {
  await tester.tap(_picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

/// Ctrl+Z aimed at the canvas. The click first is not incidental: any
/// focused text field owns Ctrl+Z as TEXT undo. U12 is free on the demo
/// rack (highest occupied is U9), and clicking empty rack background
/// keeps the selection summary mounted.
Future<void> _undo(WidgetTester tester) async {
  await tester.tapAt(_rackSpot(tester, 12));
  await tester.pumpAndSettle();
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nothing selected offers no picker — the control is about a '
      'device, and there is no device', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_picker, findsNothing);
  });

  testWidgets('selecting a device offers the picker, reading NEW', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _selectDevice(tester, 1);

    expect(_picker, findsOneWidget);
    expect(_device(tester, 'UPS-1').lifecycleStatus, LifecycleStatus.new_);
    expect(find.text('NEW'), findsWidgets);
  });

  testWidgets('the options are exactly what T6.30 prints, so the screen '
      'and the sheet cannot drift', (tester) async {
    // The anti-drift property the board item asks for by name. If someone
    // gives the enum a sixth value, or reworded a label for the sheet
    // alone, this fails.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _selectDevice(tester, 1);

    await tester.tap(_picker);
    await tester.pumpAndSettle();

    for (final status in LifecycleStatus.values) {
      expect(
        find.text(lifecycleLabel(status)),
        findsWidgets,
        reason: '$status is not offered in the picker',
      );
    }
  });

  testWidgets('picking a status writes it, and Ctrl+Z puts it back', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _selectDevice(tester, 1);

    await _pick(tester, 'EXISTING');
    expect(_device(tester, 'UPS-1').lifecycleStatus, LifecycleStatus.existing);

    await _undo(tester);
    expect(
      _device(tester, 'UPS-1').lifecycleStatus,
      LifecycleStatus.new_,
      reason:
          'an edit with no undo entry behind it is a bug, not a '
          'simplification',
    );
  });

  testWidgets('DESIGN INTENT is reachable, which is the state the board '
      'item is named for', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _selectDevice(tester, 4);

    await _pick(tester, 'DESIGN INTENT');

    expect(
      _device(tester, 'AMP-1').lifecycleStatus,
      LifecycleStatus.designIntent,
    );
  });

  testWidgets('a multi-selection is edited as ONE undo entry, not one per '
      'device', (tester) async {
    // The reason the control acts on the selection rather than the
    // focused device: it sits under "3 devices selected". Three separate
    // undo entries would make the user press Ctrl+Z three times to
    // reverse one gesture.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _selectDevice(tester, 1);
    await _addToSelection(tester, 4);
    await _addToSelection(tester, 7);

    expect(find.text('3 devices selected'), findsOneWidget);

    await _pick(tester, 'FUTURE');
    for (final designator in ['UPS-1', 'AMP-1', 'SW-1']) {
      expect(
        _device(tester, designator).lifecycleStatus,
        LifecycleStatus.future,
        reason: '$designator was left behind',
      );
    }

    await _undo(tester);
    for (final designator in ['UPS-1', 'AMP-1', 'SW-1']) {
      expect(
        _device(tester, designator).lifecycleStatus,
        LifecycleStatus.new_,
        reason:
            'one Ctrl+Z must reverse the whole gesture, not a third '
            'of it ($designator)',
      );
    }
  });

  testWidgets('a DISAGREEING selection shows no value rather than naming '
      "one device's state", (tester) async {
    // Showing UPS-1's status while AMP-1 differs would invite the user to
    // believe both match it, and the next thing they do is act on that.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _selectDevice(tester, 1);
    await _pick(tester, 'REMOVED');

    await _addToSelection(tester, 4);
    await tester.pumpAndSettle();

    expect(find.text('2 devices selected'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<LifecycleStatus>>(_picker)
          .initialValue,
      isNull,
      reason: 'a mixed selection has no one value to show',
    );
    expect(find.text('Mixed'), findsOneWidget);
  });

  testWidgets('setting a selection to the status it already holds pushes '
      'NO undo entry', (tester) async {
    // docs/04 §3.4 read the other way: an edit that changed nothing must
    // not LOOK like it did. Proved by undoing afterwards and finding the
    // PREVIOUS gesture reversed rather than an empty entry consumed.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _selectDevice(tester, 1);
    await _pick(tester, 'EXISTING');

    await _selectDevice(tester, 1);
    await _pick(tester, 'EXISTING');

    await _undo(tester);
    expect(
      _device(tester, 'UPS-1').lifecycleStatus,
      LifecycleStatus.new_,
      reason:
          'the no-op pushed an empty undo entry, so one Ctrl+Z was '
          'swallowed by it',
    );
  });
}
