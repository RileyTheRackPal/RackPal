// THE KEYS A TEXT FIELD ON THIS SCREEN MUST KEEP, AND THE ONES THE CANVAS
// MUST KEEP — asserted against real key events, which is the thing this
// suite had never once done.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS FILE EXISTS
// ═══════════════════════════════════════════════════════════════════════
// `RackCanvasScreen` wraps its whole three-column `Row` in a `Shortcuts`
// widget, so the palette filter and the five `RackInspector` fields are
// DESCENDANTS of it, while `DefaultTextEditingShortcuts` — the only thing
// in Flutter that turns `Backspace` into a `DeleteCharacterIntent` — is
// installed by `WidgetsApp` at the ROOT. `FocusManager` dispatches key
// events LEAF -> ROOT, so this screen's map was consulted FIRST and text
// editing LAST. Fourteen bare bindings sat in front of six text fields.
//
// The user-visible result: a typo in the palette filter could not be
// corrected or cleared, which made the palette useless for the rest of the
// session — and if a device happened to be selected, that same `Backspace`
// silently DELETED IT FROM THE RACK as an undoable command.
//
// It shipped because the suite was STRUCTURALLY BLIND, not merely thin.
// `tester.enterText` is `showKeyboard` + `testTextInput.enterText` and
// emits NO key events; `receiveAction` likewise. Every `sendKeyEvent` in
// this package fired while the CANVAS had focus. The intersection "real key
// event + text field focused" was empty across the whole repository, and
// `grep -rn backspace` matched exactly one production line and zero tests.
// So every test passed, for nine days, while the feature was unusable.
//
// `tester.sendKeyEvent` DOES reproduce it faithfully — it goes through
// `HardwareKeyboard` -> `FocusManager` -> the real focus chain — so all of
// this is gateable, and always was. That is the point of the file.
//
// NOTE ON `_paletteFieldSees`: `sendKeyEvent` never inserts characters in
// `flutter_test` (there is no engine to synthesise a `WM_CHAR`), so text is
// always seeded with `enterText` and `sendKeyEvent` is used ONLY for the
// editing keys under test. A helper that "types" via `sendKeyEvent` would
// type nothing and pass vacuously.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'rack_scene_to_screen.dart';
import 'rack_with_palette.dart';

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

/// Counts the key events that escape the screen entirely.
///
/// The screen is mounted UNDER this `Focus`, so anything it declines
/// arrives here. That is the direct observable for "the key fell through",
/// which is the property under test — as opposed to "the action did not
/// run", which a body guard also satisfies while still destroying the key.
class _KeyEscapeCounter extends StatelessWidget {
  const _KeyEscapeCounter({required this.seen, required this.child});

  final List<LogicalKeyboardKey> seen;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent) seen.add(event.logicalKey);
      return KeyEventResult.ignored;
    },
    child: child,
  );
}

Finder get _searchField => find.byType(TextField);

TextEditingController _searchController(WidgetTester tester) =>
    tester.widget<TextField>(_searchField).controller!;

/// Click empty canvas — the focus a real user gets by looking at the window.
Future<void> _focusCanvas(WidgetTester tester) async {
  await tester.tapAt(emptyCanvasPoint(tester));
  await tester.pump();
}

/// Focus the filter and seed it with [text].
Future<void> _focusSearch(WidgetTester tester, String text) async {
  await tester.tap(_searchField);
  await tester.pump();
  await tester.enterText(_searchField, text);
  await tester.pump();
}

int _deviceCount(WidgetTester tester) =>
    tester.allRenderObjects.whereType<RenderDeviceBox>().length;

/// The live overlay painter — the one object that holds both the caret
/// controller and the viewport, so caret questions can be asked of the
/// thing that actually draws it rather than of a reconstruction.
EditingOverlayPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((c) => c.painter)
    .whereType<EditingOverlayPainter>()
    .single;

const _tallRackId = Uuid('rack-tall');
final _when = DateTime.utc(2026, 7, 28);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

/// One empty 42U rack — the shape of the Blank project the app opens with,
/// and the shape that made the caret invisible.
///
/// 42U × 22 scene units = 924, against a canvas column ~870px tall at the
/// supported window size, so `yBottomOfU(1)` lands ~54px BELOW the last
/// visible row. Nothing about the caret was broken; it was under the fold,
/// along with the bottom of the rack.
RackDocument _blank42U() {
  final doc = RackDocument(
    id: const Uuid('doc-tall'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  );
  doc.racks[_tallRackId] = Rack(
    id: _tallRackId,
    name: 'Main Rack',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  return doc;
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

  Widget app({List<LogicalKeyboardKey>? escaped}) {
    // THE PALETTE IS THE HOST'S SINCE `#885` (DR-165), so the composition
    // is what this file has to pump: the filter these cases are about is
    // no longer inside the screen. `_KeyEscapeCounter` wraps the WHOLE
    // composition for the same reason, since "did this key escape" is a
    // question about the palette and the canvas together.
    final controller = DocumentController(buildDemoRackDocument());
    final screen = RackWithPalette(
      controller: controller,
      canvas: (key, searchFocus, dragRow) => RackCanvasScreen(
        key: key,
        measurer: _FakeMeasurer(),
        controller: controller,
        paletteSearchFocus: searchFocus,
        paletteDragRow: dragRow,
      ),
    );
    return MaterialApp(
      home: Scaffold(
        body: escaped == null
            ? screen
            : _KeyEscapeCounter(seen: escaped, child: screen),
      ),
    );
  }

  group('the palette filter keeps its editing keys', () {
    testWidgets('T1 · Backspace deletes a character', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await _focusSearch(tester, 'abc');

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(
        _searchController(tester).text,
        'ab',
        reason:
            'Backspace was consumed by the screen-level Shortcuts map '
            'before DefaultTextEditingShortcuts could turn it into a '
            'DeleteCharacterIntent — the filter cannot be corrected',
      );
    });

    testWidgets(
      'T2 · CONJUNCTION — Backspace in the filter edits the text AND does '
      'not delete the selected device',
      (tester) async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        // Select a device the way a user would, then go and type.
        await tester.tapAt(emptyCanvasPoint(tester));
        await tester.pump();
        final before = _deviceCount(tester);
        expect(before, greaterThan(0));

        await _focusSearch(tester, 'abc');
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pumpAndSettle();

        // BOTH LIMBS, DELIBERATELY IN ONE TEST. A device-count assertion
        // alone passes with the text bug present, and a text assertion
        // alone passes with the destructive bug present. Split across two
        // tests, each would look green while the other half rotted — the
        // "passes while asserting the defect" pattern this repository has
        // hit four times.
        expect(_deviceCount(tester), before, reason: 'a device was deleted');
        expect(_searchController(tester).text, 'ab');
      },
    );

    testWidgets('T2b · MIRROR — with the canvas focused, Delete still '
        'deletes the selected device', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // Click a device to select it. The demo rack has UPS-1 at U1-2.
      final box = tester.allRenderObjects.whereType<RenderDeviceBox>().first;
      await tester.tapAt(
        box.localToGlobal(box.size.center(Offset.zero)),
      );
      await tester.pumpAndSettle();
      final before = _deviceCount(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(
        _deviceCount(tester),
        before - 1,
        reason:
            'the fix must gate the binding, NOT remove it — a fix that '
            'disables _DeleteIntent outright passes T1 and T2 while '
            'destroying the delete-selection feature entirely',
      );
    });

    testWidgets('T3 · the screen declines EVERY bare binding while the '
        'filter has focus', (tester) async {
      final escaped = <LogicalKeyboardKey>[];
      await tester.pumpWidget(app(escaped: escaped));
      await tester.pumpAndSettle();
      await _focusSearch(tester, 'abc');

      // Ctrl+Z and Ctrl+Y are here too: undo is document-global, but inside
      // a text field it must be the TYPING that rewinds, not a command.
      const bare = <LogicalKeyboardKey>[
        LogicalKeyboardKey.backspace,
        LogicalKeyboardKey.delete,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.pageUp,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.slash,
      ];
      for (final key in bare) {
        escaped.clear();
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(
          escaped,
          contains(key),
          reason:
              '$key was swallowed by the canvas keymap while a text field '
              'had focus. Every entry in the screen Shortcuts map must be '
              'a gated Action whose isActionEnabled is false here; a '
              'CallbackAction consumes its key regardless of what the body '
              'does, and consumesKey => false is NOT equivalent (it yields '
              'skipRemainingHandlers, which stops dispatch just as dead)',
        );
      }
    });

    testWidgets('T3b · POSITIVE COMPANION — with the canvas focused the '
        'same keys are claimed', (tester) async {
      final escaped = <LogicalKeyboardKey>[];
      await tester.pumpWidget(app(escaped: escaped));
      await tester.pumpAndSettle();
      await _focusCanvas(tester);

      for (final key in const [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
      ]) {
        escaped.clear();
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(
          escaped,
          isNot(contains(key)),
          reason:
              'a fix that simply DELETES these bindings would satisfy T3 '
              'and break the canvas keyboard path; $key must still be '
              'claimed when the canvas owns focus',
        );
      }
    });
  });

  group('the inspector fields have the same exposure', () {
    // The user only reported the palette filter, because that is the field
    // they happened to type in. The five RackInspector fields sit in the
    // same `Row` under the same `Shortcuts`, so they were broken
    // identically and silently — and an inspector field is where a rack
    // gets RENAMED, so "Backspace deletes the selected device instead of a
    // character" was reachable from there too.
    testWidgets('T0 · Backspace edits an inspector field and does not '
        'touch the rack', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // Ctrl+Alt+U — docs/04 §4's third entry point to the RackInspector.
      await _focusCanvas(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      expect(
        fields,
        findsAtLeast(2),
        reason:
            'the RackInspector did not open, so this test would assert '
            'nothing about inspector fields',
      );

      // The Name field — the inspector's first, which Ctrl+Alt+U focuses.
      final name = fields.at(1);
      await tester.tap(name);
      await tester.pump();
      await tester.enterText(name, 'Rack A');
      await tester.pump();

      final before = _deviceCount(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(name).controller!.text,
        'Rack ',
        reason: 'the inspector field cannot be edited either',
      );
      expect(_deviceCount(tester), before, reason: 'a device was deleted');
    });
  });

  group('recovering from a bad filter without the mouse', () {
    testWidgets('Esc clears the query and returns focus to the canvas', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await _focusSearch(tester, 'nonsense');
      expect(_searchController(tester).text, 'nonsense');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_searchController(tester).text, isEmpty);
      // Focus is asserted through the caret rather than through a focus
      // node, because the caret is what the USER sees come back — and its
      // activation formula reads canvas focus directly.
      expect(
        _painter(tester).caret.active,
        isTrue,
        reason:
            'Esc must hand the keyboard back to the canvas; leaving focus '
            'in the emptied field is the focus black hole this screen has '
            'already been bitten by twice',
      );
    });

    testWidgets('/ selects the existing query so the next keystroke '
        'replaces it', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await _focusSearch(tester, 'stale');
      await _focusCanvas(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pumpAndSettle();

      expect(
        _searchController(tester).selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
        reason:
            '/ used to only requestFocus, dropping the user into a box '
            'holding a stale query they then had to clear by hand — which '
            'was impossible while Backspace was being eaten',
      );
    });

    testWidgets('AND `/` DECLINES WHILE AN INSPECTOR FIELD HAS THE '
        'KEYBOARD', (tester) async {
      // ═════════════════════════════════════════════════════════════════
      // THE GATE THAT NOTHING TESTED, FOUND BY A MUTATION AT `#885`
      // ═════════════════════════════════════════════════════════════════
      // `RackCanvasScreen` gated this binding on `!_textFieldHasFocus`
      // with a comment saying "the only thing `/` must never do is fail to
      // type a slash into a field", and the gate moved to `PaletteHost`
      // with the palette. Deleting it left every case in this file green,
      // so the sentence was a promise and not a test.
      //
      // **IT IS ASSERTED FROM AN INSPECTOR FIELD, AND THE FIRST DRAFT
      // ASSERTED IT FROM THE SEARCH BOX**, which proves nothing now: the
      // palette sits ABOVE the canvas since the hoist, so a key pressed
      // in its own field never passes through the canvas `Shortcuts` that
      // maps `/` at all. That draft passed with the gate deleted. The
      // inspector's fields are inside the canvas subtree, which is where
      // the binding is in scope and the gate is the only thing standing
      // between a person and a lost keystroke.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await _focusSearch(tester, 'cat');
      await _focusCanvas(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      expect(
        fields,
        findsAtLeast(2),
        reason:
            'the RackInspector did not open, so this case would assert '
            'nothing about a field being protected',
      );
      final name = fields.at(1);
      await tester.tap(name);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pumpAndSettle();

      // THE PALETTE'S OWN FIELD, named rather than taken by position: the
      // inspector is open, so `find.byType(TextField)` is now several and
      // `_searchController` cannot say which.
      final search = tester.widget<TextField>(fields.first).controller!;
      expect(
        search.selection,
        isNot(const TextSelection(baseOffset: 0, extentOffset: 3)),
        reason:
            'the binding declined: it did not retarget the query, which '
            'is what firing looks like, so the key belongs to the '
            'inspector field that has the keyboard',
      );
    });

    testWidgets('a zero-match Enter is announced, not silently swallowed', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await _focusSearch(tester, 'zzzznotathing');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No device matches'),
        findsOneWidget,
        reason:
            'silence here is indistinguishable from a frozen app, and it '
            'was the last signal before the palette became unusable',
      );
    });

    testWidgets('a non-empty query offers a clear button', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.clear), findsNothing);

      await _focusSearch(tester, 'abc');
      expect(
        find.byIcon(Icons.clear),
        findsOneWidget,
        reason:
            'the mouse escape hatch — two independent ways out of a bad '
            'filter, so one regressing does not strand the palette',
      );

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(_searchController(tester).text, isEmpty);
    });
  });

  group('the caret is on screen, not merely active', () {
    testWidgets('C2 · on a 42U rack the caret lands INSIDE the canvas', (
      tester,
    ) async {
      // A SHORT WINDOW ON PURPOSE. The first version of this test used the
      // 1600x1000 default and PASSED WITH THE FIX REMOVED — this harness
      // mounts the screen in a bare Scaffold with no tab strip, so its
      // canvas is taller than the real app's ~870px and a 924-unit rack
      // already fitted. It asserted nothing. The window is therefore sized
      // so the rack genuinely does not fit, and the guard below fails the
      // test rather than quietly passing if that ever stops being true.
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
          .physicalSize = const Size(
        1600,
        700,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RackCanvasScreen(
              measurer: _FakeMeasurer(),
              document: _blank42U(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _focusCanvas(tester);

      final painter = _painter(tester);
      final caret = painter.caret.caret;
      expect(caret, isNotNull, reason: 'the caret should be active here');

      final canvas = tester.getRect(find.byType(CanvasIntentDetector));
      // THE ANTI-VACUITY GUARD. Without it this test silently stops
      // exercising anything the moment the window, the header bar or the
      // scene units change.
      expect(
        painter.geo.rackHeight,
        greaterThan(canvas.height),
        reason:
            'this test is only meaningful while the rack is TALLER than the '
            'canvas — otherwise it passes with the viewport seed deleted',
      );

      // The assertion nothing in this repository made before: transform the
      // caret's SCENE position through the LIVE viewport and require it to
      // land inside the canvas rect. Asserting `caret.active` alone — which
      // is all the existing insertion_caret tests do — passes happily while
      // the line is drawn below the visible area.
      final y = painter.viewport
          .sceneToScreen(DPt(0, painter.geo.yBottomOfU(caret!.ruIndex)))
          .y;
      expect(
        y,
        inInclusiveRange(0, canvas.height),
        reason:
            'the caret is outside the canvas — this is the "I did not see '
            'a caret at any point" report. The viewport starts at identity '
            'and nothing seeded it, so a tall rack opens with U1 below the '
            'fold',
      );
    });

    testWidgets('C2b · the rack itself is on screen before anything is '
        'focused', (tester) async {
      // WHAT THIS DOES AND DOES NOT PIN, stated plainly because the
      // difference was measured rather than assumed.
      //
      // It pins the PROPERTY — the bottom of the rack is visible before the
      // user does anything — and it dies if both `_seedViewport` and
      // `_ensureCaretVisible` are removed.
      //
      // It does NOT isolate `_seedViewport`. Two mechanisms satisfy this
      // property and either alone is sufficient here, because the canvas
      // `Focus` carries `autofocus: true`, so the caret activates without a
      // tap and its scroll-into-view fires. Deleting the seed alone leaves
      // this test green; that was checked, not guessed.
      //
      // The seed's distinct job is the case this harness CANNOT reproduce:
      // autofocus silently failing to apply. `_Autofocus.applyIfValid`
      // discards the request when the enclosing scope already has a focused
      // child, and in production this screen mounts late — inside a
      // `TabBarView`, after the start card is dismissed. If that request is
      // ever dropped the caret never activates, and the seed is then the
      // only thing keeping U1 on screen. It is kept deliberately as the
      // cheaper half of a defence whose other half depends on an unverified
      // assumption.
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
          .physicalSize = const Size(
        1600,
        700,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RackCanvasScreen(
              measurer: _FakeMeasurer(),
              document: _blank42U(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final painter = _painter(tester);
      final canvas = tester.getRect(find.byType(CanvasIntentDetector));
      expect(
        painter.geo.rackHeight,
        greaterThan(canvas.height),
        reason: 'anti-vacuity guard — see C2',
      );

      final bottomY = painter.viewport
          .sceneToScreen(DPt(0, painter.geo.rackHeight))
          .y;
      expect(
        bottomY,
        inInclusiveRange(0, canvas.height),
        reason:
            'the bottom of the rack — U1, where every placement starts — is '
            'below the visible area on the first frame. The viewport begins '
            'at Matrix4.identity() and nothing but the HUD Fit button ever '
            'moved it',
      );
    });

    testWidgets('C3 · the caret survives the / hand-off and a quick-add', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await _focusCanvas(tester);
      expect(_painter(tester).caret.active, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pumpAndSettle();
      expect(
        _painter(tester).caret.active,
        isTrue,
        reason:
            'docs/04 §3.2 makes / the entry point to keyboard placement, so '
            'the caret that placement aims at must survive the hand-off — '
            'it used to go dark the instant focus left the canvas',
      );

      await tester.enterText(_searchField, 'shelf');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        _painter(tester).caret.active,
        isTrue,
        reason:
            'every placement becomes the sole selection, which switched the '
            'caret off at exactly the moment the keep-typing loop needs it '
            'to say where the NEXT device goes',
      );
    });
  });
}
