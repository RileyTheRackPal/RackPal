// The builder shell and its metadata form. Board #199 and #200, M4-D/1
// and M4-D/2, AC-049.
//
// WHAT THESE ASSERT is the ruling, not the layout. AC-049 is a claim
// about what may block a save and what may not, so the tests drive the
// three required fields and the many optional ones and watch the Save
// button. None of them pins a pixel, a pane width or a label's wording:
// docs/06 §2's 200px rail is a specification for a person, and a test
// that pinned it would fail on the first honest restyle while catching
// nothing.
//
// THE TWO THAT WOULD HAVE CAUGHT REAL DEFECTS are grouped last. Both
// were found by writing the test and watching it fail against code that
// looked finished: undo left the text boxes showing the old value, and
// the RU-height clause of `_canSave` was `frontU >= 0`, which is a gate
// that always passes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

TemplateBody _blank() => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: '',
);

/// Pumps the screen and hands back the bodies it saved.
Future<List<TemplateBody>> _pump(
  WidgetTester tester, {
  TemplateBody? template,
  String? refuseWith,
}) async {
  // THE APP'S OWN MINIMUM, not the 800x600 default. `kMinWindowWidth` is
  // 1000 and `kMinWindowHeight` is 720 (`prefs_store.dart`), enforced
  // through `WindowChrome.setMinimumSize`, so a narrower surface is a
  // state no user can reach and a test at 800 would be pinning a
  // requirement the product does not have. The header still wraps rather
  // than throwing below it; see its own comment.
  tester.view.physicalSize = const Size(1000, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final saved = <TemplateBody>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeviceBuilderScreen(
          template: template ?? _blank(),
          actions: DeviceBuilderActions(
            onSave: (b) {
              if (refuseWith != null) return refuseWith;
              saved.add(b);
              return null;
            },
          ),
        ),
      ),
    ),
  );
  return saved;
}

Finder _saveButton() => find.widgetWithText(FilledButton, 'Save');

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_saveButton()).onPressed != null;

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label), text);
  await tester.pump();
}

void main() {
  group('AC-049: three fields block Save and nothing else does', () {
    testWidgets('a blank template cannot be saved', (tester) async {
      await _pump(tester);

      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('the three fields together enable it', (tester) async {
      await _pump(tester);

      await _type(tester, 'Display name *', 'HDMI Matrix 16x16');
      expect(_saveEnabled(tester), isFalse, reason: 'one of three');
      await _type(tester, 'Designator prefix *', 'MTX');
      expect(_saveEnabled(tester), isFalse, reason: 'two of three');
      await _type(tester, 'RU height (front) *', '4');

      expect(_saveEnabled(tester), isTrue);
    });

    testWidgets('and a template with EXACTLY those three saves, which is '
        'the whole ruling: it is not incomplete, it is a template', (
      tester,
    ) async {
      final saved = await _pump(tester);

      await _type(tester, 'Display name *', 'Blank Panel');
      await _type(tester, 'Designator prefix *', 'BLK');
      await _type(tester, 'RU height (front) *', '1');
      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved, hasLength(1));
      expect(saved.single.displayName, 'Blank Panel');
      expect(saved.single.model, isEmpty, reason: 'never asked for');
      expect(saved.single.bodyDepth, isNull, reason: 'unknown, not zero');
      expect(saved.single.power.typicalWatts, isNull);
    });

    testWidgets('losing one of the three disables it again', (tester) async {
      await _pump(tester);
      await _type(tester, 'Display name *', 'X');
      await _type(tester, 'Designator prefix *', 'MTX');
      await _type(tester, 'RU height (front) *', '2');
      expect(_saveEnabled(tester), isTrue);

      await _type(tester, 'Display name *', '   ');

      expect(_saveEnabled(tester), isFalse, reason: 'whitespace is not a name');
    });
  });

  group('the rail offers only sections that exist', () {
    testWidgets('four, not the seven docs/06 §3 lists: Ports, Panel Layout '
        'and Notes belong to milestones that have not run', (tester) async {
      await _pump(tester);

      for (final s in BuilderSection.values) {
        expect(find.widgetWithText(ListTile, s.label), findsOneWidget);
      }
      expect(find.widgetWithText(ListTile, 'Ports'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Panel Layout'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Notes'), findsNothing);
    });
  });

  group('the change class reaches a surface at last', () {
    testWidgets('says nothing on an untouched template', (tester) async {
      await _pump(tester);

      expect(find.text('Safe'), findsNothing);
      expect(find.text('Breaking'), findsNothing);
    });

    testWidgets('shows Safe for a rename, which is docs/06 §7.2 verbatim', (
      tester,
    ) async {
      await _pump(tester, template: _blank()..displayName = 'Old');

      await _type(tester, 'Display name *', 'New');

      expect(find.text('Safe'), findsOneWidget);
    });

    testWidgets('shows Breaking when the occupancy moves', (tester) async {
      final body = _blank()
        ..displayName = 'Matrix'
        ..typePrefix = 'MTX'
        ..frontU = 4;
      await _pump(tester, template: body);

      await _type(tester, 'RU height (front) *', '2');

      expect(find.text('Breaking'), findsOneWidget);
    });
  });

  group('the session is a copy, so cancelling really cancels', () {
    testWidgets('editing never touches the template handed in (CR-106)', (
      tester,
    ) async {
      final original = _blank()..displayName = 'Untouched';

      await _pump(tester, template: original);
      await _type(tester, 'Display name *', 'Edited in the builder');

      expect(original.displayName, 'Untouched');
    });

    testWidgets('a refusal from the app is shown and the save point does '
        'not move', (tester) async {
      await _pump(tester, refuseWith: 'A template already uses MTX-1.');

      await _type(tester, 'Display name *', 'X');
      await _type(tester, 'Designator prefix *', 'MTX');
      await _type(tester, 'RU height (front) *', '1');
      await tester.tap(_saveButton());
      await tester.pump();

      expect(find.text('A template already uses MTX-1.'), findsOneWidget);
      expect(find.text('Unsaved'), findsOneWidget);
    });
  });

  group('the two defects this file was written to catch', () {
    testWidgets('UNDO MOVES THE TEXT BOX, not only the model: a controller '
        'seeded once never hears about a change it did not cause, so undo '
        'looked like a button that did nothing', (tester) async {
      await _pump(tester, template: _blank()..displayName = 'Original');

      await _type(tester, 'Display name *', 'Typed over');
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Original'))
            .controller
            ?.text,
        'Original',
      );
    });

    testWidgets('A ZERO RU HEIGHT DOES NOT SATISFY THE RULING ON ITS OWN. '
        '`frontU` is a non-nullable int defaulting to 0, so a gate reading '
        '"not negative" always passes and a new template saves as a 0U '
        'device', (tester) async {
      await _pump(tester);

      await _type(tester, 'Display name *', 'Rack PDU');
      await _type(tester, 'Designator prefix *', 'PDU');
      await _type(tester, 'RU height (front) *', '0');

      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('unless the template says it MEANS zero, which docs/06 §3.2 '
        'spells as side: zeroUVertical', (tester) async {
      final pdu = _blank()..side = OccupancySide.zeroUVertical;
      await _pump(tester, template: pdu);

      await _type(tester, 'Display name *', 'Rack PDU');
      await _type(tester, 'Designator prefix *', 'PDU');
      await _type(tester, 'RU height (front) *', '0');

      expect(_saveEnabled(tester), isTrue);
    });
  });
}
