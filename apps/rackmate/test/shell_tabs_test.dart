// The app shell's three-tab strip, and what the two unbuilt tabs may show.
//
// WHAT THIS FILE IS DEFENDING. The build that preceded it opened the
// Schematic tab onto one hardcoded symbol — a grey box with ports labelled
// `Pin1` and `Pout1` — that corresponded to no device in any document,
// under a toolbar whose `New Wire` button was wired to `setState(() {})`.
// The Schedule tab showed `No connections yet · Create links in the
// Schematic tab`, instructing the user to use a tab that cannot create a
// link. Both are now `UnbuiltView`. These tests are what stops either from
// coming back, and they are deliberately about the PROPERTY (nothing is
// fabricated, nothing is offered) rather than about the current wording.
//
// THE THREE INDEPENDENT PROOFS that the tab bodies fabricate nothing:
//
//   1. RECORDED CANVAS OPS. `paintsExactlyCountTimes(#drawCircle, 0)` and
//      the same for `#drawPath`/`#drawLine` over the tab body's real paint
//      — the WHOLE tab body (`_tabBody`), which is the difference between
//      this proof working and this proof being a guaranteed pass; see that
//      function's own comment. A symbol's pins are circles and Béziers and
//      a wire is a path, so a re-added drawing fails here even though it is
//      not a widget and has no text. This is the assertion that survives a
//      rewrite, and `THE CONTROL for the three op counts` proves the same
//      scope and matcher do see those ops on a tab that draws.
//   2. RENDERED TEXT. No string under the tab body may read as a device
//      designator or as a port label, which pins the exact `Pin1`/`Pout1`
//      regression by name as well as by shape.
//   3. NOTHING TAPPABLE. No widget in the tab body is a button, a field or
//      a gesture detector, and no node in the PANEL's semantics subtree
//      offers `SemanticsAction.tap` — two scopes because `getSemantics`
//      cannot be pointed at a `TabBarView` (it owns no semantics node, so
//      the search reaches the Scaffold's and picks up the tab strip). So
//      the tab cannot grow an affordance that does nothing.
//
// The tab STRIP itself keeps three tabs spelled exactly as
// docs/05-schematic-editor.md §12 (line 780) spells them; that is a
// separate test, and it is the reason the unbuilt tabs exist at all rather
// than being removed as docs/09 M1 read alone would have them.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackmate/main.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// The demo seed's designators (`rack_canvas_screen.dart`'s
/// `_buildDemoDocument`). None of them may appear on an unbuilt tab.
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

List<SemanticsNode> _semanticsSubtree(SemanticsNode root) {
  final out = <SemanticsNode>[root];
  root.visitChildren((child) {
    out.addAll(_semanticsSubtree(child));
    return true;
  });
  return out;
}

/// The `UnbuiltView` currently on screen for [viewName].
Finder _body(String viewName) => find.ancestor(
  of: find.text('$viewName — not built'),
  matching: find.byType(UnbuiltView),
);

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
/// WHY NOT `_body(view)`. The three recorded-op assertions below used to be
/// scoped to the `UnbuiltView`, which renders an `Icon`, some `Text` and a
/// `DecoratedBox` border — those lower to `drawParagraph` and `drawRRect`,
/// so `#drawCircle` / `#drawPath` / `#drawLine` were guaranteed to be 0 for
/// any implementation of the panel and for anything else the tab might
/// paint. A `CustomPaint` added as a SIBLING of the panel, drawing a circle,
/// a line and a path — the exact fabricated-drawing regression the header
/// above says these tests defend against — passed all fifteen tests in this
/// file. Measuring the tab body is the difference between "the panel draws
/// no pins" (which it structurally cannot) and "the TAB draws no pins".
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
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.pumpWidget(RackMateApp(measurer: measurer));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('the strip is Rack / Schematic / Schedule, in that order '
      '(docs/05 §12 line 780)', (tester) async {
    await tester.pumpWidget(RackMateApp(measurer: measurer));

    final tabs = tester
        .widgetList<Tab>(find.byType(Tab))
        .map((t) => t.text)
        .toList();
    expect(tabs, ['Rack', 'Schematic', 'Schedule']);
  });

  testWidgets('the Rack tab is the one that works, and still does', (
    tester,
  ) async {
    await tester.pumpWidget(RackMateApp(measurer: measurer));

    expect(find.byType(RackCanvasScreen), findsOneWidget);
    expect(find.byType(UnbuiltView), findsNothing);
    expect(find.bySemanticsLabel(RegExp('AMP-1')), findsOneWidget);
  });

  for (final view in ['Schematic', 'Schedule']) {
    testWidgets('the $view tab says it is not built, and names M2', (
      tester,
    ) async {
      await openTab(tester, view);

      expect(_body(view), findsOneWidget);
      expect(
        find.descendant(of: _body(view), matching: find.text('NOT BUILT · M2')),
        findsOneWidget,
      );
    });

    testWidgets('the $view tab paints no pin and no wire — zero circles, '
        "zero paths, zero lines in the TAB BODY's recorded ops", (
      tester,
    ) async {
      await openTab(tester, view);

      // Scoped to the whole tab body (see `_tabBody`), so a drawing added
      // beside the panel is counted rather than stepped around. A symbol pin
      // is a circle; a Bézier pin and every wire are paths. Nothing on an
      // unbuilt tab may draw one.
      expect(_tabBody(), paintsExactlyCountTimes(#drawCircle, 0));
      expect(_tabBody(), paintsExactlyCountTimes(#drawPath, 0));
      expect(_tabBody(), paintsExactlyCountTimes(#drawLine, 0));

      // The panel really is inside the scope that was just measured — a
      // zero count over a tab body that turned out not to contain the tab
      // would prove nothing.
      expect(
        find.descendant(of: _tabBody(), matching: _body(view)),
        findsOneWidget,
      );
    });

    testWidgets('the $view tab renders no device from the document and no '
        'port label', (tester) async {
      await openTab(tester, view);

      final texts = _textsUnder(tester, _tabBody());
      expect(texts, isNotEmpty);

      expect(
        texts.where(_designator.hasMatch),
        isEmpty,
        reason: 'an unbuilt tab must not show a device that is in a rack',
      );
      expect(
        texts.where((t) => _portLabel.hasMatch(t.trim())),
        isEmpty,
        reason: 'the deleted placeholder drew ports labelled Pin1 / Pout1',
      );

      // THE CONTROL, without which the two assertions above would pass on
      // an app that renders nothing anywhere: the devices those patterns
      // look for do exist, one tab over.
      await tester.tap(find.text('Rack'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('AMP-1')), findsOneWidget);
    });

    testWidgets('the $view tab offers no control', (tester) async {
      final handle = tester.ensureSemantics();
      await openTab(tester, view);

      // SEMANTICS over the panel, deliberately and not by oversight.
      // `tester.getSemantics` walks UP to the nearest render object that
      // owns a node, and `TabBarView` does not own one — the search reaches
      // the Scaffold's, which contains the tab STRIP, whose three tabs are
      // legitimately tappable. So this half is scoped to the panel, where a
      // suppressed-widget control would still surface an action, and the
      // widget-tree half below carries the whole tab body.
      final tappable = _semanticsSubtree(tester.getSemantics(_body(view)))
          .where((n) => n.getSemanticsData().hasAction(SemanticsAction.tap))
          .map((n) => n.getSemanticsData().label)
          .toList();

      expect(
        tappable,
        isEmpty,
        reason: 'a control on an unbuilt tab is a promise; found: $tappable',
      );

      // The same claim through the WIDGET tree, over the TAB BODY: this is
      // the half that sees a control added BESIDE the panel rather than
      // inside it.
      final offenders = <String>[];
      void visit(Element element) {
        final w = element.widget;
        if (w is ButtonStyleButton ||
            w is IconButton ||
            w is MaterialButton ||
            w is InkResponse ||
            w is GestureDetector ||
            w is EditableText ||
            w is TextField ||
            w is Switch ||
            w is Checkbox ||
            w is Slider) {
          offenders.add(w.runtimeType.toString());
        }
        element.visitChildren(visit);
      }

      tester.element(_tabBody()).visitChildren(visit);
      expect(
        offenders,
        isEmpty,
        reason: 'an unbuilt tab must contain no control; found: $offenders',
      );
      handle.dispose();
    });
  }

  testWidgets('THE CONTROL for the three op counts: the same tab-body scope, '
      'on the Rack tab, records the ops it counts as zero elsewhere', (
    tester,
  ) async {
    // Without this, `paintsExactlyCountTimes(#drawCircle, 0)` on an unbuilt
    // tab could be measuring a scope that is incapable of seeing a circle —
    // which is exactly what it WAS doing when it was scoped to the
    // `UnbuiltView` panel. Here the identical finder, identical matcher and
    // a tab that really draws proves the instrument works.
    await tester.pumpWidget(RackMateApp(measurer: measurer));
    await tester.pumpAndSettle();

    expect(find.byType(RackCanvasScreen), findsOneWidget);
    expect(_tabBody(), isNot(paintsExactlyCountTimes(#drawPath, 0)));
    expect(_tabBody(), isNot(paintsExactlyCountTimes(#drawLine, 0)));
  });

  testWidgets('the Schedule tab shows no table — it is not an empty '
      'schedule, there is no schedule', (tester) async {
    await openTab(tester, 'Schedule');

    // docs/09 M1: "an empty Schedule tab that explains it is coming is a
    // lie". A zero-row table is exactly that lie rendered in Material.
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(Table), findsNothing);

    // Searched over the WHOLE app, not just the panel: the two strings the
    // deleted `_EmptyState` showed are lies wherever they are put, and the
    // second one instructs the user to use a tab that cannot do it.
    expect(find.textContaining('No connections yet'), findsNothing);
    expect(find.textContaining('Create links in the'), findsNothing);

    final texts = _textsUnder(tester, _body('Schedule')).join(' ');
    expect(texts, contains('there is no schedule'));
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
}
