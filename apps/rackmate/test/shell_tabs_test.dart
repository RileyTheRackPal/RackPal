// The app shell's three-tab strip, and what each tab may show.
//
// NO TAB IS UNBUILT ANY MORE. The Schedule left this file's unbuilt loop at
// M2-B and the Schematic leaves it at M2-E, so `UnbuiltView` no longer
// appears anywhere in the app. The properties this file defends did not
// leave with it — they changed direction, and the change is the point:
//
//   * the unbuilt Schematic had to draw NO device from the document;
//   * the built one has to draw THE DOCUMENT'S devices AND NOTHING ELSE.
//
// The `Pin1`/`Pout1` half is unchanged in both worlds and stays asserted
// verbatim: the deleted canvas manufactured those labels because
// `main.dart` handed it a hardcoded EMPTY scene, and a tab that draws a
// port belonging to no device is the same lie whether or not the tab is
// finished. `the Schematic tab is built now` below is where that lives.
//
// WHAT THIS FILE IS DEFENDING. The build that preceded it opened the
// Schematic tab onto one hardcoded symbol — a grey box with ports labelled
// `Pin1` and `Pout1` — that corresponded to no device in any document,
// under a toolbar whose `New Wire` button was wired to `setState(() {})`.
// The Schedule tab showed `No connections yet · Create links in the
// Schematic tab`, instructing the user to use a tab that cannot create a
// link. These tests are what stops either from coming back, and they are
// deliberately about the PROPERTY (nothing is fabricated, nothing is
// offered) rather than about the current wording.
//
// THE SCHEDULE HAS LEFT THIS FILE'S UNBUILT LOOP, and that is the point of
// M2-B rather than a weakening of it. It now renders
// `rackmate_core/derived/schedule.dart` — a tested derivation over the
// document's real `Link`s — so it is entitled to draw a table, to show a
// designator and to offer the two controls §3.1 and §3.6 specify. What it
// is still NOT entitled to do is claim the user has not wired anything, and
// `the Schedule tab is built now` group at the bottom holds that line
// (plus the two deleted strings, which are lies wherever they are put).
//
// ── WHAT THE THREE PROOFS BECAME AT M2-E, AND WHY ─────────────────────────
// This file used to carry three independent proofs that the unbuilt tab
// bodies FABRICATE NOTHING. Two survive with their direction reversed and
// one is deliberately retired, which is the honest bookkeeping for a tab
// that started existing:
//
//   1. RECORDED CANVAS OPS — RETIRED. It asserted
//      `paintsExactlyCountTimes(#drawCircle, 0)` over the tab body,
//      because a symbol's pins are circles and every wire is a path. The
//      built Schematic draws both ON PURPOSE, so a zero count is no longer
//      a property of anything; keeping it would have meant keeping the
//      Schematic incapable of drawing. Its replacement is stronger and
//      lives one layer down: `rackmate_ui`'s
//      `render_schematic_canvas_test.dart` asserts what the canvas paints
//      op by op, against a real document.
//   2. RENDERED TEXT — KEPT, INVERTED. No string on the tab may read as a
//      port label in the deleted placeholder's shape (`Pin1`/`Pout1`), and
//      on a document that HAS ports the tab must show that document's own
//      designators. Read off the DISPLAY LIST rather than the widget tree,
//      because a schematic designator is an `OpText` and not a `Text` —
//      see the test's own note.
//   3. NOTHING TAPPABLE — KEPT, INVERTED. The rule was "no control,
//      because a control that does nothing is a promise". The built tab
//      offers §11.2's filter bar, so the rule becomes "every control it
//      offers does something", asserted by clicking one and watching the
//      sheet change.
//
// The tab STRIP itself keeps three tabs spelled exactly as
// docs/05-schematic-editor.md §12 (line 780) spells them; that is a
// separate test, and it is the reason the tabs existed at all while they
// were unbuilt rather than being removed as docs/09 M1 read alone would
// have them.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackmate/src/session/starter_projects.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'session/session_fakes.dart';

/// The demo seed's designators (`rack_canvas_screen.dart`'s
/// `_buildDemoDocument`).
///
/// None of them may appear on the Schematic OF THAT DOCUMENT, and the
/// reason is a fact about the fixture rather than about the tab: those four
/// templates declare no `PortDef`, and docs/05 §3 makes a symbol its pins.
/// A document that DOES declare ports has its designators asserted PRESENT
/// instead — see `on a document that HAS ports`.
final _designator = RegExp(r'\b(AMP-1|UPS-1|SW-1|PP-1|demo-rack)\b');

/// Port labels in the shape the deleted placeholder emitted — `Pin1`,
/// `Pout1`, and the `in1`/`out1` keys behind them.
final _portLabel = RegExp(r'^P?(in|out)\d+$', caseSensitive: false);

/// Every string actually rendered below [root].
List<String> _textsUnder(WidgetTester tester, Finder root) {
  final out = <String>[];
  void visit(Element element) {
    final widget = element.widget;
    if (widget is Text) {
      final data = widget.data;
      if (data != null) out.add(data);
      final span = widget.textSpan;
      if (span != null) out.add(span.toPlainText());
    } else if (widget is RichText) {
      out.add(widget.text.toPlainText());
    }
    element.visitChildren(visit);
  }

  tester.element(root).visitChildren(visit);
  return out;
}

// `_semanticsSubtree` and `_body` LIVED HERE and went with the unbuilt
// Schematic panel at M2-E. Both existed to walk an `UnbuiltView` — one
// asserting no node in it offered `SemanticsAction.tap`, the other finding
// the panel by its own heading — and the app no longer renders one. They
// are deleted rather than kept for a future unbuilt view, because a helper
// with no caller is a helper nobody notices has stopped working; the
// widget itself is still exported and still has its own test.

/// THE TAB BODY — everything the open tab puts on screen, not just the
/// panel inside it.
///
/// `TabBarView` builds only the page it is showing (a settled `PageView`
/// with `allowImplicitScrolling: false` keeps no neighbours alive), so once
/// a tab is open this is exactly that tab's content and nothing else. The
/// sibling `leaving the rack editor and coming back` test is the standing
/// proof of the laziness: with `Schematic` open, `AMP-1` — which the Rack
/// tab renders — is not in the tree at all.
///
/// WHY THE WHOLE BODY AND NOT THE PANEL INSIDE IT. The recorded-op
/// assertions this scope was written for are retired (see the header,
/// proof 1), but the reasoning survives for the TEXT assertions that
/// remain: scoping them to one panel measured a subtree that could not
/// contain the regression. A `CustomPaint` added as a SIBLING of the panel,
/// drawing a circle, a line and a path — the exact fabricated-drawing
/// regression this file defends against — once passed all fifteen tests
/// here. Measuring the tab body is the difference between "the panel
/// fabricates nothing" (which it structurally cannot) and "the TAB
/// fabricates nothing".
Finder _tabBody() => find.byType(TabBarView);

void main() {
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('Jost'): bytes,
    });
  });

  // The supported window (docs/04 §1 treats anything under 1080px as the
  // unbuilt tablet-collapse case), matching the sibling widget_test.
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

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.pumpWidget((await buildTestApp(measurer)).app);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('the strip is Rack / Schematic / Schedule, in that order '
      '(docs/05 §12 line 780)', (tester) async {
    await tester.pumpWidget((await buildTestApp(measurer)).app);

    final tabs = tester
        .widgetList<Tab>(find.byType(Tab))
        .map((t) => t.text)
        .toList();
    expect(tabs, ['Rack', 'Schematic', 'Schedule']);
  });

  testWidgets('the Rack tab is the one that works, and still does', (
    tester,
  ) async {
    await tester.pumpWidget((await buildTestApp(measurer)).app);

    expect(find.byType(RackCanvasScreen), findsOneWidget);
    expect(find.byType(UnbuiltView), findsNothing);
    expect(find.bySemanticsLabel(RegExp('AMP-1')), findsOneWidget);
  });

  group('the Schematic tab is built now (M2-E, DR-001)', () {
    testWidgets('it is no longer an UnbuiltView, and NO tab in the strip '
        'still wears the construction glyph', (tester) async {
      await openTab(tester, 'Schematic');

      expect(find.byType(SchematicCanvasScreen), findsOneWidget);
      expect(find.byType(UnbuiltView), findsNothing);
      // Both marked tabs have now been built, so the marker is gone
      // entirely. A tab that works while still wearing "not built" is the
      // same class of untruth as the panel this replaced, pointing the
      // other way.
      expect(find.byIcon(Icons.construction_outlined), findsNothing);
      expect(find.text('NOT BUILT · M2'), findsNothing);
    });

    testWidgets('the demo document declares no ports anywhere, so the sheet '
        'says so instead of drawing a symbol nothing owns', (tester) async {
      // `buildDemoRackDocument`'s four hand-built templates carry no
      // `PortDef`, and docs/05 §3 makes a symbol ITS PINS — so there is
      // genuinely nothing to draw here, and the honest answer is to say
      // which fact is missing. This is the case that would have caught the
      // deleted canvas: it filled exactly this hole by manufacturing a box
      // with `Pin1`/`Pout1` ports.
      await openTab(tester, 'Schematic');

      final texts = _textsUnder(tester, _tabBody());
      expect(texts.join(' '), contains(kNoSymbolsHeadline));
      expect(
        texts.where(_designator.hasMatch),
        isEmpty,
        reason:
            'no device in the demo document can carry a cable, so none '
            'of them belongs on this sheet',
      );
      expect(
        texts.where((t) => _portLabel.hasMatch(t.trim())),
        isEmpty,
        reason: 'the deleted placeholder drew ports labelled Pin1 / Pout1',
      );

      // THE CONTROL, without which the assertion above would pass on an app
      // that renders nothing anywhere: those devices do exist, one tab over.
      await tester.tap(find.text('Rack'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('AMP-1')), findsOneWidget);
    });

    testWidgets('on a document that HAS ports, the sheet draws that '
        "document's own devices", (tester) async {
      // THE `b560a50` DEFECT AT THE LAYER IT ACTUALLY LIVED IN. It was not
      // the canvas that was wrong first — it was `main.dart`, which passed
      // a hardcoded empty `DiagramScene`. This test goes through the real
      // app shell, so it exercises the same seam.
      final bytes = File(kStarterProjects.first.assetPath).readAsBytesSync();
      final read = const JsonDocumentCodec().read(bytes);
      final starter = (read as Ok<RackDocument>).value;
      expect(starter.devices, isNotEmpty);

      await tester.pumpWidget(
        (await buildTestApp(measurer, document: starter)).app,
      );
      await tester.tap(find.text('Schematic'));
      await tester.pumpAndSettle();

      // READ OFF THE DISPLAY LIST, not off the widget tree. A schematic
      // designator is an `OpText` in the shared IR, not a Flutter `Text`
      // — which is exactly why `_textsUnder` sees nothing here and why a
      // test that used it would pass on an empty canvas.
      final texts = tester
          .renderObject<RenderSchematicCanvas>(
            find.byType(SchematicCanvasBody),
          )
          .plan
          .ops
          .whereType<OpText>()
          .map((t) => t.text)
          .toSet();
      final drawn = starter.devices.values
          .where((d) => texts.contains(d.designator))
          .toList();
      expect(
        drawn,
        isNotEmpty,
        reason:
            'the document did not reach the canvas — this is the '
            'hardcoded-empty-scene failure, at the shell',
      );
      expect(
        texts.where((t) => _portLabel.hasMatch(t.trim())),
        isEmpty,
        reason: 'the deleted placeholder drew ports labelled Pin1 / Pout1',
      );
    });

    testWidgets('every control the tab offers does something — the filter '
        'bar is real, and it is the only thing offered', (tester) async {
      // The unbuilt tab's rule was "no control at all, because a control
      // that does nothing is a promise". The built tab inherits the SPIRIT
      // rather than the letter: the controls it offers are §11.2's filter
      // bar, and clicking one has to change the sheet.
      //
      // ON A STARTER, not on the demo document, and the difference is a
      // fact worth stating: `buildDemoRackDocument` predates DR-010 and
      // carries EMPTY registries, so it has no signal domains and the bar
      // honestly has nothing to offer. A document with the seeded
      // registries has eight.
      final bytes = File(kStarterProjects.first.assetPath).readAsBytesSync();
      final starter =
          (const JsonDocumentCodec().read(bytes) as Ok<RackDocument>).value;
      expect(starter.registries.signalDomains, hasLength(8));

      await tester.pumpWidget(
        (await buildTestApp(measurer, document: starter)).app,
      );
      await tester.tap(find.text('Schematic'));
      await tester.pumpAndSettle();

      expect(find.byType(DomainFilterBar), findsOneWidget);
      final bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(bar.chips, hasLength(8), reason: 'docs/05 §11.2: eight chips');

      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DomainFilterBar>(find.byType(DomainFilterBar))
            .chips
            .where((c) => c.visible),
        isEmpty,
        reason: '[None] did nothing',
      );
    });
  });

  group('the Schedule tab is built now (M2-B, CR-105, AC-035)', () {
    testWidgets('it is no longer an UnbuiltView, and the strip no longer '
        'marks it under construction', (tester) async {
      await openTab(tester, 'Schedule');

      expect(find.byType(ScheduleScreen), findsOneWidget);
      expect(find.byType(UnbuiltView), findsNothing);

      // NO construction glyph left in the strip at all. This read
      // `findsOneWidget` — "the Schematic's" — until M2-E built that tab
      // too. A tab that works while still wearing the "not built" marker
      // is the same class of untruth as the panel this replaced, pointing
      // the other way.
      expect(find.byIcon(Icons.construction_outlined), findsNothing);
    });

    testWidgets('at ZERO ROWS it names the columns and blames the document, '
        'not the user', (tester) async {
      // CR-105 wants the tab "populating live from an EMPTY project", and
      // the demo document holds no Links. The header row is what makes an
      // empty schedule readable rather than blank.
      await openTab(tester, 'Schedule');

      final texts = _textsUnder(tester, _tabBody());
      expect(texts, contains('CABLE ID'));
      expect(texts, contains('FIELD LABEL'));
      expect(texts, contains('RACK LABEL'));
      expect(texts, contains(kNoCablesHeadline));

      // docs/09 M1: "an empty Schedule tab that explains it is coming is a
      // lie". The zero-row copy states an absence in the DOCUMENT and
      // names the missing gesture; it must not tell the user they have
      // not wired anything, which is false when the build offers no way
      // to wire anything.
      final joined = texts.join(' ').toLowerCase();
      for (final lie in [
        'you have not wired',
        'coming soon',
        'no connections yet',
        'create links in the',
      ]) {
        expect(joined, isNot(contains(lie)), reason: '"$lie" is not true');
      }
    });

    testWidgets('the two strings the deleted placeholder showed appear '
        'nowhere in the app', (tester) async {
      // Searched over the WHOLE app rather than the tab: they are lies
      // wherever they are put, and the second instructs the user to use a
      // tab that cannot create a link.
      await openTab(tester, 'Schedule');
      expect(find.textContaining('No connections yet'), findsNothing);
      expect(find.textContaining('Create links in the'), findsNothing);
    });

    testWidgets('it shows both of §3.1s presets and neither is invented '
        'here', (tester) async {
      await openTab(tester, 'Schedule');
      // The sheet ids come from `SchedulePreset` in core, so the tab and
      // the printed sheet cannot be given different names.
      expect(find.textContaining('T6.10'), findsOneWidget);
      expect(find.textContaining('T6.11'), findsOneWidget);
    });

    testWidgets('Ctrl+4 opens it, and Ctrl+3 does nothing (CR-071)', (
      tester,
    ) async {
      await tester.pumpWidget((await buildTestApp(measurer)).app);
      await tester.pumpAndSettle();
      expect(find.byType(RackCanvasScreen), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleScreen), findsOneWidget);

      // Ctrl+3 is the v1.1 Rear Panel view's key and is deliberately dead.
      // If it ever switched tabs, the Schedule would have been rebound to
      // an ordinal — see session_layering_test RULE 14e.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleScreen), findsOneWidget);

      // Ctrl+1 comes back to the Rack tab, which is what proves the key
      // above did nothing rather than that nothing responds to keys.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(find.byType(RackCanvasScreen), findsOneWidget);
    });
  });

  testWidgets('leaving the rack editor and coming back leaves it working', (
    tester,
  ) async {
    await openTab(tester, 'Schematic');
    expect(find.bySemanticsLabel(RegExp('AMP-1')), findsNothing);

    await tester.tap(find.text('Rack'));
    await tester.pumpAndSettle();

    expect(find.byType(UnbuiltView), findsNothing);
    expect(find.byType(RackCanvasScreen), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('AMP-1')), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  // ── #96 — a sideways scroll is a PAN, not a view switch ────────────────
  //
  // Reported from the field: horizontal wheel and two-finger sideways swipe
  // switched tabs, and using either to navigate made "the entire page jump
  // around erratically". `TabBarView` is a `PageView` and takes page-scroll
  // physics by default, so it was claiming the same gesture BOTH canvases
  // already use for panning — `CanvasIntentDetector._onPointerSignal` pans
  // by the full scroll delta, `dx` included. One gesture, two consumers, and
  // the page settling back to the nearest tab is the jump.
  //
  // canon §1.10 principle (a) is the authority for which one wins:
  // view-switching is a GLOBAL command, not a canvas gesture. The
  // affordances are the tab strip and `Ctrl+1/2/4` (CR-071), both asserted
  // still working below — a fix that disabled the gesture by disabling the
  // `TabBarView` would pass the first two tests and break the product.
  group('a horizontal gesture over the canvas never changes the view', () {
    int tabIndex(WidgetTester tester) =>
        tester.widget<TabBarView>(find.byType(TabBarView)).controller!.index;

    /// The `TabBarView`'s own scroll offset.
    ///
    /// ═══════════════════════════════════════════════════════════════════
    /// THE INDEX IS THE WRONG THING TO ASSERT, AND SAYING SO IS THE POINT
    /// ═══════════════════════════════════════════════════════════════════
    /// A `PageView` under default physics SETTLES BACK to the nearest page,
    /// so a 240 px wheel scroll on a 1400 px-wide page moves the view a
    /// quarter of the way, springs back, and leaves `TabController.index`
    /// exactly where it was. The first draft of these tests asserted the
    /// index, passed with the fix REMOVED, and would have shipped as
    /// decoration.
    ///
    /// The user's report is about the movement, not the destination —
    /// *"the entire page jumps around erratically"* — so the claim is that
    /// the page does not move AT ALL. `NeverScrollableScrollPhysics` makes
    /// `pixels` unable to leave its page offset; default physics does not.
    /// `.first` because the TAB CONTENT has scrollables of its own (the
    /// palette list, the inspector). Descendant order is outside-in, so the
    /// first is the `PageView`'s — the one the tab strip rides on and the
    /// only one this group is about.
    double pageOffset(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(TabBarView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;

    testWidgets('a sideways drag across the sheet does not move the page', (
      tester,
    ) async {
      // A GUARD, NOT THE REPRODUCTION, and the difference is measured
      // rather than assumed: this one passes with the fix REMOVED. A
      // primary-button drag goes through the gesture arena, and the canvas
      // wins it, so the `PageView` never sees the drag at all. The wheel
      // below is the case that actually broke, because
      // `Listener.onPointerSignal` does not enter the arena — the canvas
      // and the `Scrollable` both act on the same event.
      //
      // Kept anyway: it is the assertion that the arena outcome does not
      // silently invert, which is the shape half this file's history is
      // about. It is not evidence the fix works.
      await openTab(tester, 'Schematic');
      final settled = pageOffset(tester);

      // BOTH DIRECTIONS, because a `PageView` at index 1 has a neighbour
      // either way — at index 0 a leftward drag has nowhere to go.
      await tester.drag(_tabBody(), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(pageOffset(tester), settled);
      expect(tabIndex(tester), 1);

      await tester.drag(_tabBody(), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(pageOffset(tester), settled);
      expect(tabIndex(tester), 1);
    });

    testWidgets('a horizontal wheel scroll does not move the page', (
      tester,
    ) async {
      await openTab(tester, 'Schematic');
      final settled = pageOffset(tester);
      final at = tester.getCenter(_tabBody());

      // THE POINTER-SIGNAL CHANNEL, and THIS is the one that broke.
      // `Listener.onPointerSignal` does not enter the gesture arena, so the
      // canvas pans by the full delta (`dx` included) AND the `PageView`'s
      // `Scrollable` takes the same event. Measured with the fix removed:
      // one 240 px scroll left the page at 1360 of 1600 — STRANDED between
      // the Schematic and the Rack, with `pumpAndSettle` unable to recover
      // it, because a pointer-signal scroll on a `PageView` jumps the
      // offset without running the settle animation a drag would.
      //
      // That is the user's "jumps around erratically" exactly: not a tab
      // switch, a view left half-way between two tabs.
      //
      // Asserted BETWEEN the two scrolls rather than only at the end: the
      // second would otherwise undo the first, and a test that only looked
      // afterwards would call that "did not move".
      for (final dx in <double>[-240, 240]) {
        final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(at);
        await tester.sendEventToBinding(pointer.scroll(Offset(dx, 0)));
        await tester.pump();
        expect(pageOffset(tester), settled, reason: 'dx=$dx');
        await tester.pumpAndSettle();
        expect(pageOffset(tester), settled, reason: 'dx=$dx, settled');
      }
      expect(tabIndex(tester), 1);
    });

    testWidgets('and the two affordances that DO switch still switch', (
      tester,
    ) async {
      // The guard on the fix. `NeverScrollableScrollPhysics` stops the
      // gesture and leaves `TabController.animateTo` untouched; a change
      // that took the controller away instead would strand the user on
      // whichever tab opened first.
      await openTab(tester, 'Schematic');
      expect(tabIndex(tester), 1);

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(tabIndex(tester), 2);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(tabIndex(tester), 0);
      expect(find.byType(RackCanvasScreen), findsOneWidget);
    });
  });
}
