// TWO DEFECTS A USER FOUND IN THE FIRST MINUTE, AND THE GATES THAT KEEP
// THEM FIXED. M4-D follow-up.
//
// Both were reported off one screenshot each, and neither was visible to
// the nineteen tests that already covered this screen, because those
// tests drive the form the way a TEST does: `enterText` puts text into a
// field by finding it, which is not how a person gets there.
//
// ═════════════════════════════════════════════════════════════════════
// ONE: TAB WENT THROUGH THE SECTION RAIL
// ═════════════════════════════════════════════════════════════════════
// Flutter's default `ReadingOrderTraversalPolicy` orders focus by
// GEOMETRY, and the rail's tiles and the form's fields are two columns
// of similar pitch, so reading order interleaved them:
//
//   Display name -> RAIL TILE -> RAIL TILE -> Manufacturer
//
// The reporter's words were that it "breaks up that workflow", and it is
// worse than an annoyance: a `ListTile` fires `onTap` on Enter or Space,
// so somebody tabbing toward a field and typing without watching changes
// SECTION and their keystrokes go nowhere. That is almost certainly why
// the designator prefix was reported as not working at all.
//
// The test drives real `Tab` key events rather than calling `enterText`,
// because the bug lives entirely in the path between fields.
//
// ═════════════════════════════════════════════════════════════════════
// TWO: THE CORPUS LEAKED ONTO THE SCREEN
// ═════════════════════════════════════════════════════════════════════
// The designator prefix read "MTX — seeds MTX-1, MTX-2 (CR-041,
// CR-045)". A ruling id tells a user nothing they can act on, and
// "seeds" is our word rather than the trade's. docs/12 already states
// the rule for end-user documentation: *"the corpus is the source of
// truth for that document, never the source of text"*. It binds the UI
// harder, because nobody reads a form twice.
//
// The gate below is a grep over the screen's own source for ruling and
// milestone ids in string literals. It is mechanical and narrow, in
// `internal_setter_grep_test.dart`'s tradition, and it fails on the ONE
// thing that matters: a citation reaching a user.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// The builder's previews measure text to decide what fits; these tests are
/// not about that, so the proportional stub the rest of the suite uses is
/// enough. `_ProportionalMeasurer` rather than `_FakeMeasurer` deliberately:
/// it returns plausible widths, so a preview laying out against it exercises
/// the real "only if it fits" branches instead of the degenerate zero case.
final class _ProportionalMeasurer implements TextMeasurer {
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

/// A ruling, invariant or milestone id inside a Dart string literal.
///
/// ONE PATTERN, SHARED BY THE GATE AND BY THE TEST THAT PROVES THE GATE
/// CAN FAIL. A second copy would be free to drift from the first, and the
/// copy that drifts is always the one doing the checking.
final _citation = RegExp(
  r"""'[^']*\b(CR-\d|AC-\d|DR-\d|RJ-\d|G4\b|M[0-9]-[A-Z]|RCK-\d|NET-\d|CON-\d|§)""",
);

TemplateBody _blank() =>
    TemplateBody(manufacturer: 'Generic', model: '', displayName: '');

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeviceBuilderScreen(
          measurer: _ProportionalMeasurer(),
          template: _blank(),
          actions: DeviceBuilderActions(onSave: (_) => null),
        ),
      ),
    ),
  );
}

/// What the focused widget IS, in the terms a user would use.
String _focused() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return 'nothing';
  var what = 'something else';
  ctx.visitAncestorElements((e) {
    final w = e.widget;
    if (w is TextField) {
      what = 'field:${w.decoration?.labelText}';
      return false;
    }
    if (w is ListTile) {
      what = 'RAIL';
      return false;
    }
    if (w is DropdownButtonFormField) {
      what = 'dropdown';
      return false;
    }
    return true;
  });
  return what;
}

void main() {
  group('Tab walks the form, not the section rail', () {
    testWidgets('six stops from the first field reach only form controls', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.widgetWithText(TextField, 'Display name *'));
      await tester.pump();

      final stops = <String>[];
      for (var i = 0; i < 6; i++) {
        stops.add(_focused());
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }

      expect(
        stops,
        isNot(contains('RAIL')),
        reason:
            'reading-order traversal interleaved the rail with the form '
            'by vertical position; each pane is its own '
            'FocusTraversalGroup so that Tab finishes the form first',
      );
      expect(stops.first, 'field:Display name *');
      expect(stops[1], 'field:Manufacturer', reason: 'the next FIELD');
    });

    testWidgets('the rail is still reachable, because keyboard-only '
        'operation is a criterion and not a nicety', (tester) async {
      await _pump(tester);
      await tester.tap(find.widgetWithText(TextField, 'Display name *'));
      await tester.pump();

      // Far enough to leave the form group entirely.
      var sawRail = false;
      for (var i = 0; i < 40; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        if (_focused() == 'RAIL') {
          sawRail = true;
          break;
        }
      }

      expect(
        sawRail,
        isTrue,
        reason:
            'grouping changes the ORDER, never the reachability. Removing '
            'a stop is how a surface becomes unusable without a mouse',
      );
    });
  });

  group('nothing on this screen cites the corpus at the user', () {
    test('no ruling or milestone id appears in a string literal', () {
      final source = File(
        'lib/src/builder/device_builder_screen.dart',
      ).readAsLinesSync();

      // Comment lines are where citations BELONG: the reasoning has to
      // live beside the code or the next person re-litigates it. Only
      // what can reach a screen is checked.
      final code = [
        for (final line in source)
          if (!line.trimLeft().startsWith('//')) line,
      ].join('\n');

      final citation = _citation;
      final offenders = citation
          .allMatches(code)
          .map((m) => m.group(0))
          .toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'a ruling id on screen tells a user nothing they can act on. '
            'The citation belongs in a comment beside the control, which '
            'this check deliberately does not read',
      );
    });

    test('the check can see a citation, so it is capable of failing', () {
      // Watched, per `assert the artifact, not the mechanism`: a grep
      // that matches nothing passes for the wrong reason.
      final citation = _citation;

      expect(
        citation.hasMatch("hint: 'MTX seeds MTX-1 (CR-041, CR-045)',"),
        isTrue,
      );
      expect(
        citation.hasMatch("hint: 'Two to four letters.',"),
        isFalse,
        reason: 'and does not fire on ordinary copy',
      );
    });
  });

  group('an example is a placeholder, not a permanent second line', () {
    testWidgets('the sample name is the hint and never the helper, which '
        'is what makes it vanish once the box has a value', (tester) async {
      // ASSERTED ON THE DECORATION, not on whether the string is on
      // screen. `InputDecorator` keeps the hint widget mounted and fades
      // it to zero opacity, so `findsNothing` would fail for a reason
      // that has nothing to do with this fix. Which SLOT the example
      // occupies is the fix.
      await _pump(tester);

      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Display name *'),
      );

      expect(field.decoration?.hintText, 'HDMI Matrix 16x16');
      expect(
        field.decoration?.helperText,
        isNot('HDMI Matrix 16x16'),
        reason:
            'as a helper it stayed under the box after the user typed a '
            'name, and read as a second value',
      );
    });

    testWidgets('guidance that is still true once the field is filled '
        'stays in the helper slot', (tester) async {
      await _pump(tester);

      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Designator prefix *'),
      );

      expect(field.decoration?.hintText, 'MTX');
      expect(field.decoration?.helperText, contains('MTX-1, MTX-2'));
      expect(field.decoration?.helperText, isNot(contains('CR-')));
    });
  });

  group('the dropdowns speak the trade, not Dart', () {
    testWidgets('occupancy and mounting read as words a person uses', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.widgetWithText(ListTile, 'Physical'));
      await tester.pumpAndSettle();

      // A COLLAPSED DROPDOWN SHOWS ONLY ITS CURRENT VALUE, so these are
      // the defaults a new template carries. **The mount default moved
      // from `notInRack` to `rackEars` at `#246`** (DR-107 §11.106.2):
      // `notInRack` being the default was what let a blank template pass
      // AC-049's save gate with no RU height, because a default carries
      // no evidence that its zero was MEANT. It also opened every new
      // template in the stripped field-device form.
      expect(find.text('rackEars'), findsNothing);
      expect(find.text('none'), findsNothing);
      expect(find.text('Rack ears'), findsWidgets);
      expect(find.text('Does not sit in the rack'), findsWidgets);

      // And the whole set, once the menu is open.
      await tester.tap(find.text('Rack ears').first);
      await tester.pumpAndSettle();

      expect(find.text('Not in a rack'), findsWidgets);
      expect(find.text('rackEars'), findsNothing);
    });
  });
}
