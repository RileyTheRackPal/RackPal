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

TemplateBody _blank() => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: '',
);

/// A template that already satisfies AC-049's three, so a test about
/// some other section is not also a test about the Save gate.
TemplateBody _named() => _blank()
  ..displayName = 'HDMI Matrix 16x16'
  ..typePrefix = 'MTX'
  ..frontU = 4;

/// Pumps the screen and hands back the bodies it saved.
Future<List<TemplateBody>> _pump(
  WidgetTester tester, {
  TemplateBody? template,
  String? refuseWith,
  // THE PROJECT'S REGISTRIES, which the signal-domain picker lists
  // (`#899`). Null is a real state the screen supports and its own
  // comment defends: passing empty registries would claim the project has
  // none.
  Registries? registries,
  // What devices already placed from this template stand on (DR-202
  // §11.201.2). Null is the default and the common case: nothing placed,
  // so the change class has nobody to be about.
  PlacedTemplateBaseline? placed,
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
          measurer: _ProportionalMeasurer(),
          registries: registries,
          template: template ?? _blank(),
          actions: DeviceBuilderActions(
            onSave: (b) {
              if (refuseWith != null) return refuseWith;
              saved.add(b);
              return null;
            },
            placedBaseline: () => placed,
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

/// Picks a mount in Size and mounting (DR-203), by its on-screen words.
Future<void> _chooseMount(WidgetTester tester, String label) async {
  final picker = find.widgetWithText(
    DropdownButtonFormField<MountMethod>,
    'How it mounts',
  );
  await tester.ensureVisible(picker);
  await tester.pumpAndSettle();
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

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
    testWidgets('five, not the seven docs/06 §3 lists: Panel Layout and '
        'Notes belong to milestones that have not run', (tester) async {
      // WAS FOUR UNTIL M4-E. Ports joined the rail when the grid behind
      // it existed, which is this file's whole rule rather than an
      // exception to it: a rail entry that opens nothing is the
      // `UnbuiltView` defect wearing a different hat.
      await _pump(tester);

      for (final s in BuilderSection.values) {
        expect(find.widgetWithText(ListTile, s.label), findsOneWidget);
      }
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
      final old = _blank()..displayName = 'Old';
      await _pump(
        tester,
        template: old,
        placed: (body: copyTemplateBody(old), version: 1, count: 3),
      );

      await _type(tester, 'Display name *', 'New');

      expect(find.text('Safe · 3 placed'), findsOneWidget);
    });

    testWidgets('shows Breaking when the occupancy moves', (tester) async {
      final body = _blank()
        ..displayName = 'Matrix'
        ..typePrefix = 'MTX'
        ..frontU = 4;
      await _pump(
        tester,
        template: body,
        placed: (body: copyTemplateBody(body), version: 2, count: 1),
      );

      await _type(tester, 'RU height (front) *', '2');

      expect(find.text('Breaking · 1 placed'), findsOneWidget);
    });

    testWidgets('SAYS NOTHING WHEN NOTHING IS PLACED, however breaking the '
        'edit (DR-202 §11.201.2)', (tester) async {
      // `#950`: a new template read `Breaking` the moment it had a height,
      // measured against the blank the window opened with. The verdict is
      // about devices already placed, and there are none.
      await _pump(tester);

      await _type(tester, 'Display name *', 'Matrix');
      await _type(tester, 'RU height (front) *', '4');

      expect(find.textContaining('Breaking'), findsNothing);
      expect(find.textContaining('placed'), findsNothing);
    });

    testWidgets('MEASURES AGAINST THE PLACED BODY, not the one it opened '
        'with', (tester) async {
      // Devices stand on a 4U v1; the window opened on a 2U v2 that nothing
      // uses. Renaming is safe against v2 and still breaking against v1,
      // and v1 is what those devices resolve to.
      final placed = _blank()
        ..displayName = 'Matrix'
        ..frontU = 4;
      final opened = _blank()
        ..displayName = 'Matrix'
        ..frontU = 2;
      await _pump(
        tester,
        template: opened,
        placed: (body: placed, version: 1, count: 5),
      );

      await _type(tester, 'Display name *', 'Matrix rev B');

      expect(find.text('Breaking · 5 placed'), findsOneWidget);
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

  group('the sections that carry a ruling, not just a field', () {
    Future<void> openSection(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(ListTile, label));
      await tester.pumpAndSettle();
    }

    testWidgets('AC-039: typical watts is NOT filled in from the nameplate. '
        'A fabricated number reaching a circuit-loading calculation is '
        'worse than a blank', (tester) async {
      final saved = await _pump(tester, template: _named());
      await openSection(tester, 'Power');

      await _type(tester, 'Nameplate watts', '400');
      await openSection(tester, 'Identity');
      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved.single.power.nameplateWatts, 400);
      expect(
        saved.single.power.typicalWatts,
        isNull,
        reason: 'no 30-70% guess reached the model',
      );
    });

    testWidgets('CR-114: an untouched depth saves as unknown, not as zero', (
      tester,
    ) async {
      final saved = await _pump(tester, template: _named());
      await openSection(tester, 'Physical');
      await openSection(tester, 'Identity');
      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved.single.bodyDepth, isNull);
      expect(saved.single.weight, isNull);
    });

    testWidgets('CR-114: clearing a filled depth returns it to unknown '
        'rather than to zero, which is the half a nullable box gets wrong', (
      tester,
    ) async {
      final saved = await _pump(
        tester,
        template: _named()..bodyDepth = const Len(330000000),
      );
      await openSection(tester, 'Physical');

      await _type(tester, 'Body depth', '');
      await openSection(tester, 'Identity');
      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved.single.bodyDepth, isNull);
    });

    testWidgets('CR-001: a depth typed in mm reaches the model as an exact '
        'integer count of nanometres, with no double anywhere near it', (
      tester,
    ) async {
      final saved = await _pump(tester, template: _named());
      await openSection(tester, 'Physical');

      await _type(tester, 'Body depth', '330');
      await openSection(tester, 'Identity');
      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved.single.bodyDepth, const Len(330000000));
    });

    testWidgets('CR-005: heat is shown as a derived reading and never as a '
        'box, so nothing can store a BTU figure that disagrees with the '
        'watts beside it', (tester) async {
      await _pump(tester, template: _named()..power.typicalWatts = 100);
      await openSection(tester, 'Power');
      // The reading sits below the fold: a `ListView` builds only what is
      // visible, so a bare `find` would report "not there" for a widget
      // that simply has not been scrolled to. The section pane is the
      // SECOND list on screen; the first is the rail.
      await tester.drag(find.byType(ListView).last, const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(find.textContaining('341.2'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Heat (BTU/hr)'),
        findsNothing,
        reason: 'a reading, not a field',
      );
    });

    testWidgets('DR-059: the mark defaults from the category and says so, '
        'and null is offered separately from `none`', (tester) async {
      await _pump(tester, template: _named()..category = kCatAudio);
      await openSection(tester, 'Appearance');

      expect(find.textContaining('from category (amplifier)'), findsOneWidget);
    });

    testWidgets('#756: the picker DRAWS each mark, through the geometry the '
        'elevation itself emits rather than a look-alike (CR-086)', (
      tester,
    ) async {
      await _pump(tester, template: _named()..category = kCatAudio);
      await openSection(tester, 'Appearance');

      // The closed dropdown shows the selected option, which is `null`:
      // "from category (amplifier)", drawn with the category's mark.
      final marks = find.byType(DeviceGlyphMark);
      expect(
        marks,
        findsWidgets,
        reason: 'a picker whose values ARE pictures must show the picture',
      );
      expect(
        tester.widget<DeviceGlyphMark>(marks.first).glyph,
        DeviceGlyph.amplifier,
        reason:
            'null must preview what CHOOSING it would draw, which is '
            'the resolved category default and not a blank',
      );
    });

    testWidgets('#756: the Appearance note no longer says the marks are '
        'undrawn, because they are', (tester) async {
      await _pump(tester, template: _named());
      await openSection(tester, 'Appearance');

      // PRINTED, not asserted blind: a `contains` cannot see a sentence
      // that has quietly become false, which is exactly what this note
      // was for three commits.
      final notes = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((s) => s.contains('mark'))
          .toList();
      // `print` rather than `printOnFailure`, on schematic_perf_test's
      // reasoning: copy that only surfaces when a case FAILS is copy
      // nobody reads, and the whole lesson here is that a sentence has to
      // be LOOKED at. This one goes in the log of every green run.
      // ignore: avoid_print
      print('APPEARANCE COPY: $notes');

      expect(
        notes.any((s) => s.contains('not drawn on anything yet')),
        isFalse,
        reason: 'the marks reach the elevation as of #753',
      );
      expect(
        notes.any((s) => s.contains('appear on the rack elevation')),
        isTrue,
        reason: 'and the note should say where the mark GOES',
      );
      expect(
        notes.where((s) => s.contains('photocopy')),
        hasLength(1),
        reason:
            'PRINTING THE COPY IS WHY THIS EXISTS: the replacement '
            'note originally ended on the same photocopy point as the one '
            'above it, so the section said one thing twice and nothing '
            'about what to DO. No `contains` assertion can see that',
      );
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

  group('Ctrl+Enter reaches Ports (docs/06 §9.1 step 5)', () {
    // BUILT AFTER THE DRILL AND BECAUSE OF IT. §9.1 spends step 5 on
    // this chord and the binding had never existed, so the 93-second
    // run on 2026-08-15 reached for the MOUSE there. No test in this
    // repository could have reported that; a person with a stopwatch
    // did, on the first attempt, which is what M4-Q is for.
    testWidgets('from the metadata form, with focus in a field', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(PortGrid), findsNothing);

      await _type(tester, 'Display name *', 'HDMI Matrix 16x16');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.byType(PortGrid), findsOneWidget);
    });

    testWidgets('IT DOES NOT WAIT FOR THE REQUIRED FIELDS (AC-049)', (
      tester,
    ) async {
      // AC-049 took the metadata form off the critical path. A jump
      // refused because a field is blank would put back the gate that
      // ruling removed, on the one surface a stopwatch is pointed at.
      await _pump(tester);
      expect(_saveEnabled(tester), isFalse, reason: 'nothing filled in');

      // FOCUS WITHOUT TYPING, so all three required fields stay empty.
      // The chord is only in the focus path when focus is inside the
      // builder, which is where a person tabbing through the form is.
      await tester.showKeyboard(
        find.widgetWithText(TextField, 'Display name *'),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.byType(PortGrid), findsOneWidget);
    });

    testWidgets('and a BARE Enter in the form does not jump', (tester) async {
      // `SingleActivator` matches modifiers exactly, which is what keeps
      // this chord and Quick Add's bare Enter apart.
      await _pump(tester);
      await tester.showKeyboard(
        find.widgetWithText(TextField, 'Display name *'),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(PortGrid), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // DR-157 §11.156.5: A HEIGHT IMPLIES A SIDE, AND THE FORM READS IT
  // ═══════════════════════════════════════════════════════════════════
  // `side` defaults to `none` and this form never asked for it, so a
  // person could type `4` into RU height, watch Save light, and author a
  // body that `buildPlaceFromCatalogCommand` routes OFF-RACK: created,
  // not in the rack, nothing drawn. Reported from the `PLAN-J` demo
  // (`#869`).
  //
  // A SAVE GATE WAS TRIED FIRST AND WAS WRONG. It broke the case above
  // asserting AC-049's three-field flow, and that case was right: a
  // fourth interaction is the stall AC-049 exists to prevent.
  //
  // These read the body handed to `onSave`, which is what placement
  // reads.
  //
  // DR-203 (`#951`) WIDENED THIS: the side is re-derived from every
  // occupancy edit, not only filled when blank, and the rear height
  // follows the front until somebody types it. Two cases below asserted
  // the old narrowness and now assert the ruling that replaced it.
  group('DR-157 / DR-203: the side is read off the heights', () {
    testWidgets('AC-049 STILL LIGHTS SAVE ON THREE FIELDS, which is the '
        'thing the first attempt at this broke', (tester) async {
      await _pump(tester);

      await _type(tester, 'Display name *', 'Patch Panel');
      await _type(tester, 'Designator prefix *', 'PP');
      await _type(tester, 'RU height (front) *', '2');

      expect(_saveEnabled(tester), isTrue);
    });

    testWidgets('A FRONT HEIGHT ON A NEW TEMPLATE IS THE REAR HEIGHT TOO, '
        'which is 21 of the 25 seeded rack-ear devices', (tester) async {
      // `#951`: a 2U amplifier had its height typed on Identity, typed
      // again on Physical, and `Occupies` corrected by hand.
      final saved = await _pump(tester);

      await _type(tester, 'Display name *', 'Zone Amp');
      await _type(tester, 'Designator prefix *', 'AMP');
      await _type(tester, 'RU height (front) *', '2');
      await tester.tap(_saveButton());
      await tester.pump();

      expect(
        (saved.single.frontU, saved.single.rearU, saved.single.side),
        (2, 2, OccupancySide.both),
      );
    });

    testWidgets('and a rear typed as 0 makes it front only, and stops '
        'following', (tester) async {
      final saved = await _pump(tester);

      await _type(tester, 'Display name *', 'Blank Plate');
      await _type(tester, 'Designator prefix *', 'BP');
      await _type(tester, 'RU height (front) *', '1');
      await _type(tester, 'RU height (rear)', '0');
      await _type(tester, 'RU height (front) *', '2');
      await tester.tap(_saveButton());
      await tester.pump();

      expect(
        (saved.single.frontU, saved.single.rearU, saved.single.side),
        (2, 0, OccupancySide.front),
      );
    });

    testWidgets('A 0U MOUNT LIGHTS SAVE ON ITS OWN, with no second step', (
      tester,
    ) async {
      // `#951`: `0U mount` did nothing for Save until `Occupies` said 0U.
      final saved = await _pump(
        tester,
        template: _blank()
          ..displayName = 'PDU'
          ..typePrefix = 'PDU',
      );
      expect(_saveEnabled(tester), isFalse);

      await _chooseMount(tester, '0U mount');
      expect(_saveEnabled(tester), isTrue);
      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved.single.side, OccupancySide.zeroUVertical);
      expect(saved.single.frontU, 0);
    });

    testWidgets('A HOSTED CARD CAN BE SAVED, which no template could be '
        'before DR-203', (tester) async {
      final saved = await _pump(
        tester,
        template: _blank()
          ..displayName = 'Input Card'
          ..typePrefix = 'CRD',
      );

      await _chooseMount(tester, 'Hosted in another device');
      expect(
        find.widgetWithText(TextField, 'RU height (front) *'),
        findsNothing,
      );
      expect(_saveEnabled(tester), isTrue);
      await tester.tap(_saveButton());
      await tester.pump();

      expect(
        (saved.single.frontU, saved.single.side),
        (0, OccupancySide.none),
      );
    });

    testWidgets('A DEVICE THAT SITS ON A SHELF ASKS NO HEIGHT, which is the '
        'shape of the seeded P04 power strip (`#952`)', (tester) async {
      // DR-203 first classed `shelf` as taking rack units, so this form
      // demanded a height of a strip lying on a shelf and would not save
      // it at 0. The U it sits in is the shelf's.
      final saved = await _pump(
        tester,
        template: _blank()
          ..displayName = 'Power Strip'
          ..typePrefix = 'PS',
      );

      await _chooseMount(tester, 'On a shelf');
      expect(
        find.widgetWithText(TextField, 'RU height (front) *'),
        findsNothing,
      );
      expect(_saveEnabled(tester), isTrue);
      await tester.tap(_saveButton());
      await tester.pump();

      expect(
        (saved.single.frontU, saved.single.rearU, saved.single.side),
        (0, 0, OccupancySide.none),
      );
    });

    testWidgets('A SHELF-SITTING DEVICE STATES ITS SHELF WIDTH where its '
        'height would be, and it saves (DR-204 §11.203.3)', (tester) async {
      final saved = await _pump(
        tester,
        template: _blank()
          ..displayName = 'Streamer'
          ..typePrefix = 'STR',
      );

      await _chooseMount(tester, 'On a shelf');
      final field = find.widgetWithText(TextField, 'Width on a shelf');
      expect(field, findsOneWidget, reason: 'asked once, in Size and mounting');
      await tester.ensureVisible(field);
      await tester.enterText(field, '98');
      await tester.pump();
      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved.single.shelfWidth, const Len(98_000_000));
      expect(
        saved.single.chassisWidth,
        const Len(432_000_000),
        reason: 'a different field; the rack panel default is untouched',
      );
    });

    testWidgets('HALF RACK CARRIES ITS SPAN, so the file cannot say half and '
        'full at once', (tester) async {
      final saved = await _pump(tester, template: _named());

      final width = find.widgetWithText(
        DropdownButtonFormField<WidthClass>,
        'Width',
      );
      await tester.ensureVisible(width);
      await tester.pumpAndSettle();
      await tester.tap(width);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Half rack').last);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Width in twelfths of a rack'),
        findsNothing,
      );
      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved.single.nominalSpanTwelfths, 6);
    });

    testWidgets('AND A BODY SAVED THIS WAY IS ONE A RACK WILL TAKE, which '
        'is the whole point', (tester) async {
      // The assertion the report is actually about: not "a field got a
      // value" but "the thing placement checks is now satisfied".
      final saved = await _pump(tester);

      await _type(tester, 'Display name *', 'Patch Panel');
      await _type(tester, 'Designator prefix *', 'PP');
      await _type(tester, 'RU height (front) *', '2');
      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved.single.side, isNot(OccupancySide.none));
      expect(saved.single.frontU, 2);
    });

    testWidgets('A SIDE THE HEIGHTS NO LONGER FIT IS RE-DERIVED (DR-203 '
        'replaced "never overwritten")', (tester) async {
      final saved = await _pump(
        tester,
        template: _blank()
          ..displayName = 'Rear Box'
          ..typePrefix = 'RB'
          ..frontU = 1
          ..side = OccupancySide.rear,
      );

      await _type(tester, 'RU height (front) *', '3');
      await tester.tap(_saveButton());
      await tester.pump();

      // It opened 1U front with no rear height and a side of `rear`, a
      // body the heights contradict. Front and rear disagreed as opened,
      // so the rear does not follow, and the side becomes what the
      // heights say.
      expect(
        (saved.single.frontU, saved.single.rearU, saved.single.side),
        (3, 0, OccupancySide.front),
      );
    });

    testWidgets('and `notInRack` offers no height to contradict it', (
      tester,
    ) async {
      final saved = await _pump(
        tester,
        template: _blank()
          ..displayName = 'Wall Box'
          ..typePrefix = 'WB'
          ..mountMethod = MountMethod.notInRack,
      );

      expect(
        find.widgetWithText(TextField, 'RU height (front) *'),
        findsNothing,
      );
      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved.single.side, OccupancySide.none);
    });
  });
  // ═══════════════════════════════════════════════════════════════════
  // THE SIGNAL DOMAIN, WHICH IS THE PRODUCER THE FIELD MUST NOT SHIP
  // WITHOUT (`#899`, DR-169 §11.168.5)
  // ═══════════════════════════════════════════════════════════════════
  // This repository has now recorded eight surfaces ruled, built, tested
  // and left with nothing that reaches them. A nullable model field whose
  // only writer is a codec is the same shape: it would read back exactly
  // what it was given, for ever, because nothing could give it anything.
  // ═══════════════════════════════════════════════════════════════════
  // WI-FI, THE TEMPLATE'S ONE NETWORK CAPABILITY (DR-227 §11.226.3)
  // ═══════════════════════════════════════════════════════════════════
  // Three states because "nobody said" and "no" are different facts (G4).
  // Driven by the row's key, for the primary domain's reason: Identity is
  // taller than the window, so the row is reached before any typing scrolls
  // the list.
  group('the Wi-Fi row (NET-A/2e, DR-227)', () {
    Future<void> choose(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.byKey(kBuilderWifiFieldKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kBuilderWifiFieldKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    // FROM `_named()`, which already meets AC-049's three, so nothing is
    // typed: typing reaches fields at the top of Identity, which the
    // scroll to this row has already taken out of the lazily built list.
    Future<TemplateBody> saveNamed(
      WidgetTester tester,
      List<TemplateBody> saved,
    ) async {
      await tester.ensureVisible(_saveButton());
      await tester.tap(_saveButton());
      await tester.pump();
      return saved.single;
    }

    testWidgets('Yes reaches the saved body', (tester) async {
      final saved = await _pump(tester, template: _named());
      await choose(tester, kWifiChoiceLabels[true]!);
      expect((await saveNamed(tester, saved)).wifi, isTrue);
    });

    testWidgets('STARTS UNSET AND SAVES UNSET: nobody has said, and G4 '
        'does not guess', (tester) async {
      final saved = await _pump(tester, template: _named());
      await tester.ensureVisible(find.byKey(kBuilderWifiFieldKey));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(kBuilderWifiFieldKey),
          matching: find.text(kWifiChoiceLabels[null]!),
        ),
        findsOneWidget,
      );
      expect((await saveNamed(tester, saved)).wifi, isNull);
    });

    testWidgets('No is a stated no, kept apart from unset', (tester) async {
      final saved = await _pump(tester, template: _named());
      await choose(tester, kWifiChoiceLabels[false]!);
      expect((await saveNamed(tester, saved)).wifi, isFalse);
    });

    testWidgets('a stated Yes can be put back to unset', (tester) async {
      final saved = await _pump(tester, template: _named()..wifi = true);
      await choose(tester, kWifiChoiceLabels[null]!);
      expect((await saveNamed(tester, saved)).wifi, isNull);
    });
  });

  group('the signal-domain picker (`#899`)', () {
    Registries withDomains() => buildSeedRegistries();

    testWidgets('sets the domain, and it reaches the saved body', (
      tester,
    ) async {
      final saved = await _pump(tester, registries: withDomains());

      // THE PICKER FIRST: since DR-203 the Size and mounting block makes
      // Identity taller than a 720 px window, so typing the height scrolls
      // the list and the lazily built picker at the top leaves the tree.
      await tester.tap(find.byKey(kPrimaryDomainFieldKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Network').last);
      await tester.pumpAndSettle();

      await _type(tester, 'Display name *', 'Managed Switch');
      await _type(tester, 'Designator prefix *', 'SW');
      await _type(tester, 'RU height (front) *', '1');

      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved.single.primaryDomain, const SignalDomainId('net'));
    });

    testWidgets('STARTS UNSET AND SAVES UNSET, because nobody has said '
        'and G4 does not guess', (tester) async {
      final saved = await _pump(tester, registries: withDomains());

      await _type(tester, 'Display name *', 'Mystery Box');
      await _type(tester, 'Designator prefix *', 'MB');
      await _type(tester, 'RU height (front) *', '1');
      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved.single.primaryDomain, isNull);
    });

    testWidgets('CAN BE PUT BACK TO UNSET, which is a value and not a '
        'missing one', (tester) async {
      final saved = await _pump(
        tester,
        registries: withDomains(),
        template: _blank()..primaryDomain = const SignalDomainId('net'),
      );

      // THE PICKER FIRST: since DR-203 the Size and mounting block makes
      // Identity taller than a 720 px window, so typing the height scrolls
      // the list and the lazily built picker at the top leaves the tree.
      await tester.tap(find.byKey(kPrimaryDomainFieldKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not set').last);
      await tester.pumpAndSettle();

      await _type(tester, 'Display name *', 'Managed Switch');
      await _type(tester, 'Designator prefix *', 'SW');
      await _type(tester, 'RU height (front) *', '1');

      await tester.tap(_saveButton());
      await tester.pump();

      expect(saved.single.primaryDomain, isNull);
    });

    testWidgets('WITH NO REGISTRIES IT SAYS SO rather than offering a list '
        'it made up', (tester) async {
      await _pump(tester);

      expect(find.byKey(kPrimaryDomainFieldKey), findsNothing);
      expect(
        find.textContaining('registries were not supplied'),
        findsOneWidget,
      );
    });
  });
}
