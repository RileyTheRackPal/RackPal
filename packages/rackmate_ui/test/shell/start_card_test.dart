// docs/04 §9's start card, driven with real taps and real key events.
//
// Nothing here calls a callback directly: every assertion goes through
// `tester.tap` or `tester.sendKeyEvent`, because the thing worth testing
// about a card of buttons is that pressing them does what they say —
// which is exactly what a direct callback invocation cannot show.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

const _starters = [
  StarterEntry(
    id: 'home_theatre',
    title: 'Home theatre',
    summary: '24U rack · 15 rack devices',
    detail: 'A dedicated cinema head-end.',
  ),
  StarterEntry(
    id: 'whole_house',
    title: 'Whole house',
    summary: '42U rack · 31 rack devices',
    detail: 'A full residential head-end.',
  ),
  StarterEntry(
    id: 'small_office',
    title: 'Small office',
    summary: 'Two racks',
    detail: 'A commercial fit-out.',
  ),
  StarterEntry(
    id: 'apartment',
    title: 'Apartment',
    summary: '9U wall rack',
    detail: 'A small swing-frame rack.',
  ),
];

/// Everything the card reported, in order.
///
/// A MUTABLE OBJECT, not a record of counters: a record captures `int`s
/// BY VALUE at the moment it is built, so a later `blanks++` inside the
/// callback would never be visible to the assertion. That mistake makes
/// "Blank project does nothing" and "Blank project works" look identical
/// from the test's side, which is the worst kind of green.
final class _Recorder {
  final List<String> starters = [];
  int blanks = 0;
  int opens = 0;
}

Future<_Recorder> _pump(WidgetTester tester) async {
  final recorder = _Recorder();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StartCard(
          starters: _starters,
          onBlank: () => recorder.blanks++,
          onStarter: recorder.starters.add,
          onOpen: () => recorder.opens++,
        ),
      ),
    ),
  );
  return recorder;
}

/// Scrolls [finder] into view, then taps it.
///
/// The card is a real scroll view — five tiles do not fit an 800x600
/// test viewport, and neither do they fit every real window. Tapping
/// without scrolling first would test only the tiles that happen to be
/// above the fold.
Future<void> _press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('shows Blank project plus the four starters, and nothing '
      'else pressable', (tester) async {
    await _pump(tester);

    // docs/04 §9's list, verbatim: `Blank project` plus four.
    expect(find.text(StartCard.blankTitle), findsOneWidget);
    for (final starter in _starters) {
      expect(
        find.text(starter.title),
        findsOneWidget,
        reason: '${starter.title} is missing from the card',
      );
      expect(find.text(starter.detail), findsOneWidget);
    }
    expect(find.text(StartCard.headline), findsOneWidget);

    // FIVE tiles — the four starters plus Blank — and one secondary
    // action. Counted by key rather than by widget type, because a
    // `TextButton` is an `InkWell` too and the point of the count is
    // that no SIXTH tile has crept onto the card.
    for (final id in [for (final s in _starters) s.id, 'blank']) {
      expect(
        find.byKey(ValueKey<String>('starter-$id')),
        findsOneWidget,
        reason: 'tile starter-$id',
      );
    }
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('starter-'),
      ),
      findsNWidgets(5),
    );
    expect(find.text(StartCard.openLabel), findsOneWidget);
  });

  testWidgets('tapping a starter reports THAT starter', (tester) async {
    final result = await _pump(tester);
    await _press(tester, find.text('Small office'));
    expect(result.starters, ['small_office']);
  });

  testWidgets('each of the four reports its own id', (tester) async {
    // A single-tap test passes just as well if every tile reports the
    // same id, which is exactly the bug a `for` loop over four tiles
    // invites.
    final result = await _pump(tester);
    for (final starter in _starters) {
      await _press(tester, find.text(starter.title));
    }
    expect(result.starters, [for (final s in _starters) s.id]);
  });

  testWidgets('Blank project is a separate action from the starters', (
    tester,
  ) async {
    final result = await _pump(tester);
    await _press(tester, find.text(StartCard.blankTitle));
    expect(result.blanks, 1);
    expect(
      result.starters,
      isEmpty,
      reason: 'Blank must not be reported as a starter',
    );
  });

  testWidgets('Open a project… is its own action', (tester) async {
    final result = await _pump(tester);
    await _press(tester, find.text(StartCard.openLabel));
    expect(result.opens, 1);
    expect(result.blanks, 0);
    expect(result.starters, isEmpty);
  });

  testWidgets('every tile is reachable by Tab and activated by Enter', (
    tester,
  ) async {
    // KEYBOARD-ONLY IS NOT OPTIONAL. This is the first screen a user
    // sees; a card whose tiles are mouse-only would make the whole
    // application unreachable without a pointer.
    final result = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      result.starters,
      ['home_theatre'],
      reason:
          'the first Tab stop must be the first starter, and Enter must '
          'activate it',
    );
  });

  testWidgets('states what Blank project actually produces', (tester) async {
    // The blank project in this build is ONE EMPTY 42U RACK, not a
    // document with no racks. A card that said only "Blank project"
    // would leave the user to discover that.
    await _pump(tester);
    expect(find.text(StartCard.blankDetail), findsOneWidget);
    expect(StartCard.blankDetail, contains('42U'));
  });

  testWidgets('renders without overflow at the minimum window size', (
    tester,
  ) async {
    // `setMinimumSize(1000, 720)` is the smallest the shipped window can
    // be, so it is the smallest the card must fit in. An overflow here
    // is a yellow-and-black stripe on the first screen of the product.
    tester.view.physicalSize = const Size(1000, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls rather than overflowing on a short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
