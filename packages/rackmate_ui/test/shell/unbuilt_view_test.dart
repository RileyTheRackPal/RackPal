// The unbuilt-state panel's contract (docs/09-roadmap.md M1's "an empty
// Schedule tab that explains it is coming is a lie", reconciled with
// docs/05-schematic-editor.md §12's three-tab strip).
//
// THE LOAD-BEARING TEST IN THIS FILE IS `offers nothing tappable`. Most of
// the rest is about wording, and wording can be argued about (the exception
// is the short-window test at the bottom, which is about whether the last
// line of that wording can be READ at all).
// What cannot be argued about is that a view which does not work must not
// offer a control, because a control is a promise. The view this panel
// replaced shipped a `New Wire` button wired to `setState(() {})` and an
// enabled chain-mode toggle over a canvas that read no document; twelve
// consecutive "fix:" commits went into the pipeline behind them, which did
// not exist. So the panel is checked TWICE and independently: once through
// the rendered SEMANTICS subtree (what an assistive technology, and the
// user, is actually offered) and once through the WIDGET subtree (which
// catches a control whose semantics were suppressed).
//
// Neither check is a type-name assertion about `UnbuiltView`'s internals —
// both walk whatever is really on screen, so they keep working if the panel
// is restyled and fail the moment it grows a button.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

const _panel = UnbuiltView(
  viewName: 'Schematic',
  milestone: 'M2',
  absent: 'There is no symbol, no pin and no wire.',
  why: 'The strip is fixed at three tabs by docs/05 §12.',
  reference: 'docs/05-schematic-editor.md',
);

Future<void> _pumpPanel(WidgetTester tester, [UnbuiltView panel = _panel]) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: panel)),
  );
}

/// Every `SemanticsNode` at or below [root], in tree order.
List<SemanticsNode> _semanticsSubtree(SemanticsNode root) {
  final out = <SemanticsNode>[root];
  root.visitChildren((child) {
    out.addAll(_semanticsSubtree(child));
    return true;
  });
  return out;
}

/// Widgets that hand the user something to press or type into. Kept
/// deliberately concrete: a control that is none of these still trips the
/// semantics check, and one that suppresses its semantics still trips this.
///
/// `Listener` and `RawGestureDetector` are NOT on this list, and that is a
/// considered omission rather than an oversight: the panel's own
/// `SingleChildScrollView` builds both (a `Scrollable` is a
/// `RawGestureDetector` over a `Listener`), and a viewport that can scroll
/// long prose is not a control the way a button is — it promises nothing.
/// Anything of theirs that DID promise something would carry a tap action
/// and be caught by the sibling semantics test.
bool _isInteractive(Widget w) =>
    w is ButtonStyleButton ||
    w is IconButton ||
    w is MaterialButton ||
    w is InkResponse ||
    w is GestureDetector ||
    w is EditableText ||
    w is TextField ||
    w is Switch ||
    w is Checkbox ||
    w is Slider ||
    (w is Semantics && w.properties.onTap != null);

void main() {
  testWidgets('the first thing it says is that the view is NOT BUILT', (
    tester,
  ) async {
    await _pumpPanel(tester);

    // The heading has one definition on the widget, so a test cannot pin a
    // different spelling than the one that ships.
    expect(_panel.heading, 'Schematic — not built');
    expect(find.text('Schematic — not built'), findsOneWidget);
  });

  testWidgets('it names the milestone that builds the view, and no date', (
    tester,
  ) async {
    await _pumpPanel(tester);

    // docs/09 M1: the tab may say what it is; it may not say when.
    expect(find.text('NOT BUILT · M2'), findsOneWidget);
  });

  testWidgets('it states what is absent, why the tab exists, and the docs', (
    tester,
  ) async {
    await _pumpPanel(tester);

    expect(
      find.text('There is no symbol, no pin and no wire.'),
      findsOneWidget,
    );
    expect(
      find.text('The strip is fixed at three tabs by docs/05 §12.'),
      findsOneWidget,
    );
    expect(find.text('docs/05-schematic-editor.md'), findsOneWidget);
  });

  testWidgets('offers nothing tappable — no node in its semantics subtree '
      'carries a tap action', (tester) async {
    // Disposed inline, not via addTearDown: flutter_test verifies handle
    // disposal BEFORE tear-downs run.
    final handle = tester.ensureSemantics();

    await _pumpPanel(tester);

    final nodes = _semanticsSubtree(
      tester.getSemantics(find.byType(UnbuiltView)),
    );

    // The panel is not empty of semantics — it is readable — so this is not
    // vacuously true over an empty list.
    expect(nodes.length, greaterThan(1));

    final tappable = nodes
        .where((n) => n.getSemanticsData().hasAction(SemanticsAction.tap))
        .map((n) => n.getSemanticsData().label)
        .toList();
    expect(
      tappable,
      isEmpty,
      reason: 'an unbuilt view must offer no control; found: $tappable',
    );
    handle.dispose();
  });

  testWidgets('offers nothing tappable — no interactive widget is in its '
      'subtree either', (tester) async {
    await _pumpPanel(tester);

    final offenders = <String>[];
    void visit(Element element) {
      if (_isInteractive(element.widget)) {
        offenders.add(element.widget.runtimeType.toString());
      }
      element.visitChildren(visit);
    }

    tester.element(find.byType(UnbuiltView)).visitChildren(visit);

    expect(
      offenders,
      isEmpty,
      reason: 'an unbuilt view must contain no control; found: $offenders',
    );
  });

  testWidgets('a screen reader is told the view is not built', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await _pumpPanel(tester);

    final labels = _semanticsSubtree(
      tester.getSemantics(find.byType(UnbuiltView)),
    ).map((n) => n.getSemanticsData().label).join(' ');

    // The absence is in the ANNOUNCED text, not only in the pixels: a user
    // who cannot see the greyed-out panel is told the same thing.
    expect(labels, contains('NOT BUILT · M2'));
    expect(labels, contains('Schematic — not built'));
    expect(labels, contains('There is no symbol, no pin and no wire.'));
    handle.dispose();
  });

  testWidgets('in a window too short for it, every line stays REACHABLE — '
      'the panel scrolls rather than clipping its last sentence', (
    tester,
  ) async {
    // WHAT THIS USED TO BE: `expect(find.byType(UnbuiltView), findsOneWidget)`
    // plus `takeException()`, under the comment "a RenderFlex overflow throws
    // in tests; reaching here is the assertion". The finder restated what
    // `_pumpPanel` had just done, and overflow is structurally unreachable
    // for this widget — a `Column(mainAxisSize: min)` inside a
    // `ConstrainedBox` inside a `SingleChildScrollView` cannot overflow
    // either way — so the only regression it could catch was deleting the
    // scroll view outright. It said nothing about the property the scroll
    // view is there FOR.
    const window = Rect.fromLTWH(0, 0, 420, 320);
    tester.view
      ..physicalSize = window.size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpPanel(tester);

    // 1. The window really is too short for the panel. Without this, every
    //    assertion below is about a case that never arises.
    final scrollable = find.byType(Scrollable);
    expect(scrollable, findsOneWidget);
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(
      position.maxScrollExtent,
      greaterThan(0),
      reason: '420x320 must be a window whose content does not fit',
    );

    // 2. Nothing runs off the SIDE: 520 is a maximum width, not a fixed one,
    //    so the prose reflows into 420 instead of being cut off.
    final texts = find.byType(Text);
    expect(texts, findsWidgets);
    for (var i = 0; i < texts.evaluate().length; i++) {
      final rect = tester.getRect(texts.at(i));
      expect(rect.left, greaterThanOrEqualTo(window.left));
      expect(
        rect.right,
        lessThanOrEqualTo(window.right),
        reason: 'a line of copy runs off the right edge: $rect',
      );
    }

    // 3. The LAST line — the docs reference, the one a reader needs to go
    //    anywhere from here — starts below the fold and can be scrolled to.
    //    A viewport that clips it away is exactly as unhelpful as an
    //    overflow, and throws nothing.
    final reference = find.text('docs/05-schematic-editor.md');
    expect(
      tester.getRect(reference).bottom,
      greaterThan(window.bottom),
      reason: 'the fixture assumes this line starts off-screen',
    );

    await tester.drag(scrollable, Offset(0, -position.maxScrollExtent - 20));
    await tester.pumpAndSettle();

    final scrolled = tester.getRect(reference);
    expect(scrolled.top, greaterThanOrEqualTo(window.top));
    expect(
      scrolled.bottom,
      lessThanOrEqualTo(window.bottom),
      reason: 'the reference line cannot be brought fully on screen',
    );
    expect(tester.takeException(), isNull);
  });
}
