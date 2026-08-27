// Widget tests for docs/04-rack-editor.md §4's RackInspector, driven
// through real taps, real text entry and real key events against
// `RackCanvasScreen`'s own `DocumentController` — never by calling private
// methods or poking the model.
//
// THE LOAD-BEARING PROPERTY, asserted for every field: an edit runs exactly
// ONE Command, and Ctrl+Z puts the old value back. A field that mutated the
// document without an undo entry is a bug, not a simplification — so every
// test here that changes something also undoes it.
//
// The demo rack is RK-1 "Media Closet", 12U, EIA-19, tapped 10-32, floor
// enclosure, with three front devices (UPS-1 @U1 2U, AMP-1 @U4 2U, SW-1 @U7
// 1U) and one rear (PP-1 @U9 1U). Highest occupied U is therefore 9, which
// is what makes the shrink-guard cases below concrete.

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

const _geo = RackGeometry(12);

Widget _app({Clock clock = const SystemClock(), RackDocument? document}) =>
    MaterialApp(
      home: Scaffold(
        body: RackCanvasScreen(
          measurer: _FakeMeasurer(),
          clock: clock,
          document: document,
        ),
      ),
    );

/// The demo document plus one real `Location`, created the way the app
/// creates one.
///
/// THE DEMO SEED HAS NO LOCATIONS as of board #143. It carried three, and
/// their own comment said they were "seeded rather than creatable" because
/// no panel could make one; M3-B built that panel, so the seed stopped
/// asserting three rooms nobody typed. A test that needs a location now
/// says so, and says it by running `AddLocationCommand` rather than by
/// hand-building a `Location`, so the fixture cannot drift from what the
/// product actually writes.
RackDocument _docWithOneLocation(String name) {
  final doc = buildDemoRackDocument();
  AddLocationCommand(
    name: name,
    code: name.substring(0, 2).toUpperCase(),
    order: nextLocationOrder(doc),
    now: DateTime.utc(2026, 7, 18),
    actor: 'test',
  ).apply(doc);
  return doc;
}

/// The live `Rack` the screen is editing, reached through the widget tree
/// rather than a private field: these tests observe the DOCUMENT, which is
/// the thing the undo guarantee is actually about.
Rack _rack(WidgetTester tester) =>
    tester.widget<RackInspectorPanel>(find.byType(RackInspectorPanel)).rack;

RackDocument _doc(WidgetTester tester) =>
    tester.widget<RackInspectorPanel>(find.byType(RackInspectorPanel)).doc;

/// The `TextField` whose `InputDecoration.labelText` is [label]. The panel
/// has several, and the palette has one of its own, so a bare
/// `find.byType(TextField)` would be ambiguous the moment the inspector is
/// showing the rack.
Finder _field(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(TextField),
);

/// What the Height field's own text buffer currently SAYS — which is a
/// different question from what the rack holds, and the whole point of the
/// modal-cancel case below. Read off the live `TextEditingController` rather
/// than by finding rendered text, because a focused field's value is in the
/// controller whether or not it happens to be painted anywhere unique.
String _heightBuffer(WidgetTester tester) =>
    tester.widget<TextField>(_field('Height (U)')).controller!.text;

/// Any `DropdownButtonFormField<T>`, whatever `T` is.
///
/// `find.byType` is INVARIANT in the generic argument, so
/// `byType(DropdownButtonFormField<Object?>)` matches none of this panel's
/// dropdowns (they are `<RailType>`, `<RackWidthClass>`, `<Uuid?>`,
/// `<String?>`, `<HingeSide?>`). Matching on the raw type name is the only
/// way to ask "is this a dropdown" without enumerating every instantiation.
final Finder _anyDropdown = find.byWidgetPredicate(
  (w) => w.runtimeType.toString().startsWith('DropdownButtonFormField<'),
);

/// The inspector's own scrollable — the panel is a `ListView`, so anything
/// below the fold is not merely off-screen but genuinely absent from the
/// element tree until scrolled to.
///
/// `.first` because every `EditableText` in the panel carries its OWN
/// internal `Scrollable` (for horizontal text scrolling), so an unqualified
/// descendant match finds a dozen. The `ListView`'s is the outermost, and
/// `find.descendant` yields matches in tree order.
Finder get _inspectorScrollable => find
    .descendant(
      of: find.byType(RackInspectorPanel),
      matching: find.byType(Scrollable),
    )
    .first;

/// Scrolls [finder] into view inside the inspector.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: _inspectorScrollable,
  );
  await tester.pumpAndSettle();
}

/// A free U inside the rack body, on the front face and clear of the
/// floating chrome — the zoom HUD occupies the canvas's own top-left corner,
/// so a "click the empty rack background" gesture aimed at the topmost U
/// would hit the HUD instead. U3 sits between UPS-1 (U1-U2) and AMP-1
/// (U4-U5), well below it.
Offset _freeRackSpot(WidgetTester tester) => _rackSpot(tester, 12, 3);

/// The screen centre of [ru] on a rack of [heightU] — the general form of
/// [_freeRackSpot], for tests whose rack is no longer 12U.
///
/// THROUGH THE LIVE VIEWPORT (`#710`): the screen frames the whole rack on
/// first sight, so scene (0, 0) is no longer the canvas's corner and a rect
/// added to that corner aims at nothing in particular.
Offset _rackSpot(WidgetTester tester, int heightU, int ru) =>
    centreOfRu(tester, RackGeometry(heightU), ru, 1);

/// Opens the RackInspector via `Ctrl+Alt+U` (docs/04 §4's third entry
/// point) — the cheapest of the three, used as setup by tests that are
/// about a FIELD rather than about how the panel was opened.
Future<void> _openInspector(WidgetTester tester) async {
  await tester.tapAt(_freeRackSpot(tester));
  await tester.pump();
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

/// Types [value] into the field labelled [label] and commits it with Enter
/// (docs/04 §4.1's "commits on blur or Enter", applied panel-wide).
Future<void> _typeAndEnter(
  WidgetTester tester,
  String label,
  String value,
) async {
  await _reveal(tester, _field(label));
  await tester.enterText(_field(label), value);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Ctrl+Z, aimed at the CANVAS.
///
/// The click first is not incidental. `EditableText` owns `Ctrl+Z` as TEXT
/// undo, so sending it while an inspector field still holds focus rewinds
/// the text buffer and never reaches the screen's document undo at all —
/// which is production behaviour, not a test artefact, and exactly what a
/// user gets too. Clicking the rack's empty background moves focus to the
/// canvas while KEEPING the inspector on the rack target (a click outside
/// the rack would switch it to the selection summary and unmount the panel
/// these tests read the rack from).
/// [at] overrides where that focusing click lands. Needed by any test that
/// has actually CHANGED the rack's height: `_freeRackSpot` is computed
/// against the 12U demo geometry, and after a resize the old U3 centre is
/// either occupied or off the rack entirely — either of which switches the
/// inspector to the selection summary and unmounts the panel the assertions
/// read the rack from.
Future<void> _undo(WidgetTester tester, {Offset? at}) async {
  await tester.tapAt(at ?? _freeRackSpot(tester));
  await tester.pumpAndSettle();
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

/// Picks [option] from the dropdown labelled [label].
Future<void> _pickDropdown(
  WidgetTester tester,
  String label,
  String option,
) async {
  final dropdown = find.ancestor(of: find.text(label), matching: _anyDropdown);
  await _reveal(tester, dropdown);
  await tester.tap(dropdown.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

/// Taps the label [text] of a checkbox/radio tile, revealing it first.
Future<void> _tapTile(WidgetTester tester, String text) async {
  await _reveal(tester, find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  group('the three entry points (docs/04 §4)', () {
    testWidgets('the inspector starts on the SELECTION target, not the '
        'rack', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.byType(RackInspectorPanel), findsNothing);
      expect(find.text('Nothing selected'), findsOneWidget);
    });

    testWidgets('clicking the rack HEADER opens it', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.text('RK-1'));
      await tester.pumpAndSettle();
      expect(find.byType(RackInspectorPanel), findsOneWidget);
    });

    testWidgets("clicking the rack's EMPTY BACKGROUND opens it — and "
        'clicking OUTSIDE the rack does not', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      // Inside the rack body but on no device: §4's "click the rack header
      // or its empty background".
      await tester.tapAt(_freeRackSpot(tester));
      await tester.pumpAndSettle();
      expect(find.byType(RackInspectorPanel), findsOneWidget);

      // Well outside the rack's extent: that is just empty canvas, and
      // means "deselect", nothing more. Taken from the CANVAS'S OWN BOX
      // rather than from a scene coordinate past the rack's corner — the
      // rack is framed with a margin now, so "rackWidth + 120" in scene
      // units can be off the canvas widget entirely and land on the
      // inspector column instead of on empty canvas.
      await tester.tapAt(emptyCanvasPoint(tester));
      await tester.pumpAndSettle();
      expect(find.byType(RackInspectorPanel), findsNothing);
    });

    testWidgets('Ctrl+Alt+U opens it', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);
      expect(find.byType(RackInspectorPanel), findsOneWidget);
    });

    testWidgets('the overflow menu opens it via "Rack settings…"', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rack settings…'));
      await tester.pumpAndSettle();
      expect(find.byType(RackInspectorPanel), findsOneWidget);
    });

    testWidgets('clicking a DEVICE puts the column back on the selection — '
        "§4's \"REPLACES the Selection section\", in reverse", (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);
      expect(find.byType(RackInspectorPanel), findsOneWidget);

      await tester.tapAt(centreOfRu(tester, _geo, 4, 2));
      await tester.pumpAndSettle();

      expect(find.byType(RackInspectorPanel), findsNothing);
      expect(find.text('1 device selected'), findsOneWidget);
      expect(find.text('AMP-1'), findsOneWidget);
    });
  });

  group('Identity', () {
    testWidgets('Designator commits on Enter, runs ONE command, and undoes', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);
      expect(_rack(tester).designator, 'RK-1');

      await _typeAndEnter(tester, 'Designator', 'RK-7');
      expect(_rack(tester).designator, 'RK-7');
      // The header reads the same field, so this also proves the `meta`
      // epoch subscription added this stage actually repaints.
      expect(find.text('RK-7'), findsWidgets);

      await _undo(tester);
      expect(_rack(tester).designator, 'RK-1');
    });

    testWidgets('Name commits on BLUR (not only on Enter) and undoes', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await tester.enterText(_field('Name'), 'Head End');
      await tester.pump();
      // Blur by moving focus to a sibling field — no Enter anywhere.
      await tester.tap(_field('Designator'));
      await tester.pumpAndSettle();

      expect(_rack(tester).name, 'Head End');
      await _undo(tester);
      expect(_rack(tester).name, 'Media Closet');
    });

    testWidgets('an EMPTY designator is refused, reported, and reverted — '
        'never silently swallowed (§3.4)', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _typeAndEnter(tester, 'Designator', '   ');

      expect(_rack(tester).designator, 'RK-1');
      expect(find.textContaining('needs a designator'), findsOneWidget);
      // The buffer reverted too, so the box does not sit there showing a
      // value the document rejected.
      expect(
        tester.widget<TextField>(_field('Designator')).controller?.text,
        'RK-1',
      );
    });

    testWidgets('a project with no locations offers only (none), and says '
        'nothing it cannot back up', (tester) async {
      // THE STATE `Ctrl+N` PRODUCES. `blank_document.dart` seeds no
      // locations and, as of board #143, neither does the demo seed. The
      // dropdown must render that honestly rather than being disabled,
      // hidden, or seeded with a room nobody typed.
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      expect(_doc(tester).locations, isEmpty);
      expect(_rack(tester).locationId, isNull);
      expect(find.text('(none)'), findsOneWidget);
    });

    testWidgets("the Location dropdown is REAL: it lists the project's "
        'locations and writes through a command', (tester) async {
      await tester.pumpWidget(_app(document: _docWithOneLocation('Basement')));
      await tester.pump();
      await _openInspector(tester);

      expect(_rack(tester).locationId, isNull);
      await _pickDropdown(tester, 'Location', 'Basement');

      final locationId = _rack(tester).locationId;
      expect(locationId, isNotNull);
      expect(_doc(tester).locations[locationId]?.name, 'Basement');

      await _undo(tester);
      expect(_rack(tester).locationId, isNull);
    });
  });

  group('Form factor', () {
    testWidgets('Width class writes through a command and undoes', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);
      expect(_rack(tester).widthClass, RackWidthClass.eia19);

      await _pickDropdown(tester, 'Width', 'ETSI');
      expect(_rack(tester).widthClass, RackWidthClass.etsi);

      await _undo(tester);
      expect(_rack(tester).widthClass, RackWidthClass.eia19);
    });

    testWidgets('Rail type writes through a command and undoes', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _pickDropdown(tester, 'Rail type', 'M6');
      expect(_rack(tester).railType, RailType.m6);

      await _undo(tester);
      expect(_rack(tester).railType, RailType.tapped10_32);
    });

    testWidgets('Usable depth: an empty field means NULL (unknown), not '
        'zero — CR-114', (tester) async {
      // A `MutableClock` stepped past `UndoStack.mergeWindow` between the
      // two edits, deliberately. `SetEntityPropertyCommand.mergeKey` includes
      // the field key, so setting a depth and clearing it within 400ms
      // coalesce into ONE undo entry (from null, to null) — correct
      // per-property behaviour, but it would make the assertion below
      // vacuous: undo would restore null because null is where the merged
      // command started, not because clearing was undoable.
      final clock = MutableClock(DateTime.utc(2026, 7, 18));
      await tester.pumpWidget(_app(clock: clock));
      await tester.pump();
      await _openInspector(tester);
      expect(_rack(tester).usableDepth, isNull);

      await _typeAndEnter(tester, 'Usable depth (mm)', '600');
      expect(_rack(tester).usableDepth, const Len(600000000));

      clock.advance(const Duration(seconds: 1));

      // Clearing it must restore UNKNOWN, never Len.zero — a 0 mm depth is
      // a claim about the rack; an empty field is an absence of one.
      await _reveal(tester, _field('Usable depth (mm)'));
      await tester.enterText(_field('Usable depth (mm)'), '');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_rack(tester).usableDepth, isNull);

      // ...and the clear is its OWN undo entry, so one Ctrl+Z brings the
      // 600mm back rather than skipping straight past both edits.
      await _undo(tester);
      expect(_rack(tester).usableDepth, const Len(600000000));
    });

    testWidgets('two edits to the SAME field INSIDE the merge window '
        'coalesce into one undo entry (mergeKey is per-property)', (
      tester,
    ) async {
      // The other half of the same mechanism: typing 600 then correcting it
      // to 700 should not cost the user two undos.
      //
      // THE CLOCK IS ACTUALLY ADVANCED, by a duration that is a real
      // fraction of the window rather than zero. Written frozen — which is
      // how it first shipped — `UndoStack.push`'s guard evaluates
      // `0 < mergeWindow`, true for ANY positive window, so the test proved
      // mergeKey coalescing and nothing whatsoever about the window its own
      // name claims to exercise. It is the same vacuous-by-frozen-clock
      // pattern `MutableClock`'s doc comment was written to eliminate, and
      // the sibling boundary test below is the other side of it.
      final clock = MutableClock(DateTime.utc(2026, 7, 18));
      await tester.pumpWidget(_app(clock: clock));
      await tester.pump();
      await _openInspector(tester);

      await _typeAndEnter(tester, 'Usable depth (mm)', '600');
      clock.advance(const Duration(milliseconds: 200));
      await _typeAndEnter(tester, 'Usable depth (mm)', '700');
      expect(_rack(tester).usableDepth, const Len(700000000));

      await _undo(tester);
      expect(
        _rack(tester).usableDepth,
        isNull,
        reason: 'both edits belong to one entry, so one undo clears them',
      );
    });

    testWidgets('...and two edits OUTSIDE it do NOT coalesce: the window has '
        'a far side, and 500ms is on it', (tester) async {
      // The boundary itself. Without this, "inside the merge window" is an
      // unfalsifiable claim: a build in which per-property merging became
      // time-INDEPENDENT — merging two edits an hour apart — would pass the
      // test above unchanged. Here the only difference from that test is the
      // advance, 200ms -> 500ms across `UndoStack.mergeWindow`'s 400ms, and
      // the expected undo depth flips because of it.
      final clock = MutableClock(DateTime.utc(2026, 7, 18));
      await tester.pumpWidget(_app(clock: clock));
      await tester.pump();
      await _openInspector(tester);

      await _typeAndEnter(tester, 'Usable depth (mm)', '600');
      clock.advance(const Duration(milliseconds: 500));
      await _typeAndEnter(tester, 'Usable depth (mm)', '700');
      expect(_rack(tester).usableDepth, const Len(700000000));

      // TWO entries now, so the first undo lands on the 600 the other test
      // never sees.
      await _undo(tester);
      expect(
        _rack(tester).usableDepth,
        const Len(600000000),
        reason:
            '500ms is outside the 400ms window, so the second edit is '
            'its own undo entry',
      );
      await _undo(tester);
      expect(_rack(tester).usableDepth, isNull);
    });

    testWidgets('an unparseable depth is REFUSED and reported, and the '
        'model is untouched', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _typeAndEnter(tester, 'Usable depth (mm)', 'deep');
      expect(_rack(tester).usableDepth, isNull);
      expect(find.textContaining('positive number of mm'), findsOneWidget);
    });

    testWidgets('Weight capacity round-trips kilograms through exact '
        'micrograms', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _typeAndEnter(tester, 'Weight capacity (kg)', '450');
      expect(_rack(tester).weightCapacity, const Mass(450000000000));

      await _undo(tester);
      expect(_rack(tester).weightCapacity, isNull);
    });

    testWidgets('Own weight renders an em dash when unknown, never "0 kg" '
        '(CR-114)', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _reveal(tester, find.text('Own weight'));
      expect(find.text('Own weight'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      expect(find.text('0.0 kg'), findsNothing);
    });

    testWidgets('Swing frame toggles, and Hinge side is disabled until it '
        'is on', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      // Disabled == `onChanged` is null on the dropdown.
      // "Disabled" == the dropdown's `onChanged` is null. Reached through
      // the raw widget rather than a typed `tester.widget<...>` because
      // `DropdownButtonFormField` is generic and `find.byType` is invariant
      // in that argument (see `_anyDropdown`).
      Object? hingeOnChanged() {
        final w = tester.widget(
          find
              .ancestor(of: find.text('Hinge side'), matching: _anyDropdown)
              .first,
        );
        return (w as dynamic).onChanged;
      }

      await _reveal(tester, find.text('Hinge side'));
      expect(hingeOnChanged(), isNull);

      await _tapTile(tester, 'Swing frame');
      expect(_rack(tester).isSwingFrame, isTrue);
      await _reveal(tester, find.text('Hinge side'));
      expect(hingeOnChanged(), isNotNull);

      await _undo(tester);
      expect(_rack(tester).isSwingFrame, isFalse);
    });

    testWidgets('the Mount radio PRESERVES the specific form factor across '
        'a Wall -> Floor -> Wall round trip', (tester) async {
      // The spec gives a TWO-way radio over an EIGHT-value enum and does not
      // say what happens to the specific subtype. The mapping chosen here
      // preserves it, so a preset's `wallPivotCabinet` cannot be silently
      // flattened to a generic `wallFixed` by two clicks. Unit-level,
      // because the mapping is the thing under test, not the widget.
      expect(
        mountFormFactor(RackFormFactor.wallPivotCabinet, wall: true),
        RackFormFactor.wallPivotCabinet,
      );
      final toFloor = mountFormFactor(
        RackFormFactor.wallPivotCabinet,
        wall: false,
      );
      expect(toFloor, RackFormFactor.floorEnclosure);
      expect(
        mountFormFactor(toFloor, wall: true),
        RackFormFactor.wallFixed,
        reason: 'a genuine cross-category move picks the generic member',
      );
      // And within a category nothing changes at all.
      expect(
        mountFormFactor(RackFormFactor.openFrame2Post, wall: false),
        RackFormFactor.openFrame2Post,
      );
    });

    testWidgets('the Mount radio writes a command and undoes', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);
      expect(_rack(tester).formFactor, RackFormFactor.floorEnclosure);

      await _tapTile(tester, 'Wall');
      expect(_rack(tester).formFactor, RackFormFactor.wallFixed);

      await _undo(tester);
      expect(_rack(tester).formFactor, RackFormFactor.floorEnclosure);
    });
  });

  group('Display', () {
    testWidgets('RU numbering is display-only but still command-routed', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);
      expect(_rack(tester).ruNumbering, RuNumbering.bottomUpFromOne);

      await _tapTile(tester, 'Top');
      expect(_rack(tester).ruNumbering, RuNumbering.topDown);

      await _undo(tester);
      expect(_rack(tester).ruNumbering, RuNumbering.bottomUpFromOne);
    });

    testWidgets('Mirror rear elevation toggles through a command', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);
      expect(_rack(tester).mirrorRearElevation, isTrue);

      await _tapTile(tester, 'Mirror rear elevation');
      expect(_rack(tester).mirrorRearElevation, isFalse);

      await _undo(tester);
      expect(_rack(tester).mirrorRearElevation, isTrue);
    });
  });

  group('Height (docs/04 §4.1, way two of three)', () {
    testWidgets('GROWING is always safe and commits one command', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _typeAndEnter(tester, 'Height (U)', '20');
      expect(_rack(tester).heightU, 20);
      // The scene really rebuilt at the new height — this is what the
      // first-ever `epochs.rack` subscription and the memoised `_geo` buy.
      expect(find.text('20U'), findsWidgets);

      await _undo(tester);
      expect(_rack(tester).heightU, 12);
    });

    testWidgets('shrinking to a height that still fits everyone works', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      // The highest occupied U is 9 (rear PP-1), so 9U is lossless.
      await _typeAndEnter(tester, 'Height (U)', '9');
      expect(_rack(tester).heightU, 9);
    });

    testWidgets('shrinking BELOW occupancy opens §4.1’s modal, names '
        'every casualty with its link count, and commits NOTHING until '
        'Apply', (tester) async {
      // §4.1's "never destroy, never silently move, always name the
      // casualties". Pass 2 stood a status-line REFUSAL in for the modal;
      // this pass ships the modal, so the assertion moves with it — what
      // has NOT changed is that the document is untouched until the user
      // chooses, and that no option on offer deletes anything (rule 3).
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _typeAndEnter(tester, 'Height (U)', '6');

      expect(find.text('Shrink RK-1 to 6U?'), findsOneWidget);
      expect(
        _rack(tester).heightU,
        12,
        reason: 'the modal decides; nothing commits before Apply',
      );

      // Rule 4, per casualty: designator, description, U range and LINK
      // COUNT. At 6U the front SW-1 (U7) and the rear PP-1 (U9) are the two
      // that lose their U; the counts are REAL (this document has no links
      // yet, so a truthful zero — not a stub).
      expect(find.text('SW-1'), findsOneWidget);
      expect(find.text('PP-1'), findsOneWidget);
      expect(find.text('U7 front'), findsOneWidget);
      expect(find.text('U9 rear'), findsOneWidget);
      expect(find.text('0 links'), findsNWidgets(2));

      // Rule 3: "DELETION IS NOT OFFERED." (Not spelled as a bare
      // `textContaining('Remove')` — option 1's own honest label reads
      // "Removes 10U of gaps", which is about GAPS, not devices.)
      expect(find.textContaining('Delete'), findsNothing);
      expect(find.textContaining('Discard'), findsNothing);

      // Cancel really is nothing at all — no command, no mutation.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(_rack(tester).heightU, 12);
    });

    testWidgets('CANCELLING the modal leaves ZERO trace: the field re-reads '
        "the rack's real height, and the next blur does not re-open the "
        'modal', (tester) async {
      // The field's ordinary re-sync is gated on NOT having focus (so it
      // cannot eat keystrokes), and §4.1's modal defeats that gate twice
      // over: Cancel runs no command, so nothing rebuilds and
      // `didUpdateWidget` never fires at all; and a popped route restores
      // focus to the very field that pushed it, so even a rebuild would
      // decline. The buffer therefore kept the REJECTED height — the panel
      // stating a fact the document does not hold — and, because a blur
      // commits, re-fired `onRequestHeight(6)` and re-opened the modal the
      // user had just cancelled, on every click elsewhere, forever.
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _typeAndEnter(tester, 'Height (U)', '6');
      expect(find.text('Shrink RK-1 to 6U?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(_rack(tester).heightU, 12);
      expect(
        _heightBuffer(tester),
        '12',
        reason: 'the field must state the height the rack actually has',
      );

      // THE LOOP, closed. Blur the field by clicking the rack background;
      // the commit that fires sees a buffer that already agrees with the
      // model, so it is a genuine no-op.
      await tester.tapAt(_freeRackSpot(tester));
      await tester.pumpAndSettle();
      expect(
        find.text('Shrink RK-1 to 6U?'),
        findsNothing,
        reason: 'a cancelled request must not resurrect itself on blur',
      );
      expect(_rack(tester).heightU, 12);
    });

    testWidgets('an option that resolves to the CURRENT height pushes NO '
        'undo entry — Apply must not dirty a document it did not change', (
      tester,
    ) async {
      // UPS-1 sits at U1, so under a BOTTOM trim the smallest lossless
      // height is `12 - (1-1)` = 12 — the height the rack already has. The
      // Apply path used to add `SetRackHeightCommand(12 -> 12)`
      // unconditionally; `DocumentController._commit` only skips a push for
      // an EMPTY child list, so the document went dirty and gained an undo
      // entry whose Ctrl+Z visibly does nothing — for the one option the
      // user picked precisely because it changes nothing. The sibling preset
      // path (`_runPresetTransaction`) has always had this guard.
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      // A REAL undo entry first, so "did Apply push one?" is observable by
      // asking what a single Ctrl+Z actually undoes.
      await _typeAndEnter(tester, 'Name', 'Closet A');
      expect(_rack(tester).name, 'Closet A');

      await _typeAndEnter(tester, 'Height (U)', '6');
      expect(find.text('Shrink RK-1 to 6U?'), findsOneWidget);

      await tester.tap(find.text('Bottom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep rack at 12U (smallest that fits)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(_rack(tester).heightU, 12, reason: 'the option changes nothing');

      await _undo(tester);
      expect(
        _rack(tester).name,
        'Media Closet',
        reason:
            'the ONE Ctrl+Z must reach the rename — if Apply had pushed '
            'a phantom SetRackHeightCommand(12 -> 12), this undo would have '
            'been spent popping it and the name would still be "Closet A"',
      );
    });

    testWidgets("an out-of-range height clamps to CR-038's [1, 60] and "
        'says so', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _typeAndEnter(tester, 'Height (U)', '99');
      expect(_rack(tester).heightU, 60);
      expect(find.textContaining('clamped to 60U'), findsOneWidget);
      // THE FIELD MUST NOT KEEP SAYING 99. A clamp is the other way a
      // commit resolves to a value the field did not submit, and a buffer
      // left holding the rejected number re-fires `onRequestHeight(99)` on
      // the next blur — the same stranded-buffer loop the cancelled-modal
      // case above is about, reached without a modal at all.
      expect(_heightBuffer(tester), '60');

      // AND AGAIN, now that the rack IS at 60. This second submission is
      // the harder half: 99 clamps to 60, 60 equals the current height, so
      // `_requestHeight` runs NO command — nothing bumps an epoch, nothing
      // rebuilds, and only an explicit re-sync can stop the buffer keeping
      // `99` and re-firing this same refusal on every blur, forever.
      await _typeAndEnter(tester, 'Height (U)', '99');
      expect(_rack(tester).heightU, 60);
      expect(_heightBuffer(tester), '60');
    });
  });

  group('Preset', () {
    testWidgets('applying a preset is ONE undo entry covering every field '
        'it writes', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _pickDropdown(tester, 'Preset', 'Floor enclosure 18U');

      final rack = _rack(tester);
      expect(rack.heightU, 18);
      expect(rack.railType, RailType.squareCageNut);
      expect(rack.usableDepth, isNotNull);
      expect(rack.weightCapacity, isNotNull);

      // ONE Ctrl+Z must put ALL of it back — a preset that landed as N
      // separate undo entries would leave the rack in a state that is
      // neither the preset nor what preceded it.
      await _undo(tester);
      final after = _rack(tester);
      expect(after.heightU, 12);
      expect(after.railType, RailType.tapped10_32);
      expect(after.usableDepth, isNull);
      expect(after.weightCapacity, isNull);
    });

    testWidgets('a preset whose height would displace occupants routes '
        'through the SAME modal, and Cancel applies NOTHING — not even the '
        'other fields', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      // Wall box 6U cannot hold the rear PP-1 at U9. The preset's height is
      // not exempt from §4.1 just because it arrived with eight other
      // fields — it goes through the one funnel like everything else.
      await _pickDropdown(tester, 'Preset', 'Wall box 6U / 12 in');
      expect(find.text('Shrink RK-1 to 6U?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      final rack = _rack(tester);
      expect(rack.heightU, 12);
      expect(
        rack.usableDepth,
        isNull,
        reason:
            'ATOMIC OR NOTHING: the other fields must not land either — '
            'a "Wall box 6U" rack sitting at 12U is worse than no change '
            'at all',
      );
      expect(rack.railType, RailType.tapped10_32);
    });

    testWidgets('and Apply lands the preset AND the resize AND every '
        'displacement as ONE undo entry', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _pickDropdown(tester, 'Preset', 'Wall box 6U / 12 in');
      // Compaction fully rescues both casualties at 6U, so option 1 is
      // preselected (rule 2) and Apply takes it.
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      final after = _rack(tester);
      expect(after.heightU, 6, reason: 'the preset height was reachable');
      expect(after.usableDepth, isNotNull, reason: 'the preset landed too');
      // The compaction really moved the rear patch panel down out of U9.
      final pp = _doc(tester).devices[const Uuid('dev-pp')]!.placement;
      expect((pp as RailPlacement).ruIndex, 1);

      // RULE 6, through the preset path: ONE Ctrl+Z restores the height,
      // the properties AND the device positions together. The focusing
      // click must aim at the 6U rack's own free U6 — see `_undo`.
      await _undo(tester, at: _rackSpot(tester, 6, 6));
      final back = _rack(tester);
      expect(back.heightU, 12);
      expect(back.usableDepth, isNull);
      expect(back.railType, RailType.tapped10_32);
      final ppBack = _doc(tester).devices[const Uuid('dev-pp')]!.placement;
      expect((ppBack as RailPlacement).ruIndex, 9);
    });

    testWidgets('the dropdown reads "Custom" once the rack diverges from '
        'the preset it was given', (tester) async {
      // The Rack has no `presetRef`; the displayed preset is DERIVED by
      // matching values. Continuing to show "Floor enclosure 18U" after the
      // user changed its rail type would be the UI telling a story the
      // document does not.
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _pickDropdown(tester, 'Preset', 'Floor enclosure 18U');
      expect(find.text('Floor enclosure 18U'), findsWidgets);

      await _pickDropdown(tester, 'Rail type', 'M6');
      expect(find.text('Custom'), findsWidgets);
    });

    test('matchingPresetId is exact, not approximate', () {
      // Guards the derivation the widget test above exercises indirectly:
      // a "close enough" match would let the dropdown claim a preset the
      // rack does not actually match.
      final presets = buildRackPresets();
      final preset = presets['floorEnclosure18U']!;
      final now = DateTime.utc(2026, 7, 18);
      final rack = Rack(
        id: const Uuid('rk-1'),
        name: 'R',
        designator: 'RK-1',
        heightU: preset.heightU,
        order: const FracIndex('a0'),
        meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: 't'),
        formFactor: preset.formFactor,
        widthClass: preset.widthClass,
        railType: preset.railType,
        usableDepth: preset.usableDepth,
        weightCapacity: preset.weightCapacity,
      );
      expect(matchingPresetId(rack, presets), 'floorEnclosure18U');

      final off = Rack(
        id: const Uuid('rk-2'),
        name: 'R',
        designator: 'RK-2',
        heightU: preset.heightU,
        order: const FracIndex('a0'),
        meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: 't'),
        formFactor: preset.formFactor,
        widthClass: preset.widthClass,
        railType: RailType.m6, // one field off
        usableDepth: preset.usableDepth,
        weightCapacity: preset.weightCapacity,
      );
      expect(matchingPresetId(off, presets), isNull);
    });
  });

  group('Circuits', () {
    testWidgets('a real empty state, and NO [+ Add circuit] affordance', (
      tester,
    ) async {
      // No command anywhere in this codebase creates a Circuit, so a button
      // would be inert — the "silently does nothing" trap §3.4 forbids. One
      // caption line states the situation instead.
      await tester.pumpWidget(_app());
      await tester.pump();
      await _openInspector(tester);

      await _reveal(tester, find.text('No circuits on RK-1.'));
      expect(find.text('No circuits on RK-1.'), findsOneWidget);
      expect(find.textContaining('Add circuit'), findsNothing);
      expect(
        find.textContaining('arrives with the power stage'),
        findsOneWidget,
      );
    });
  });
}
