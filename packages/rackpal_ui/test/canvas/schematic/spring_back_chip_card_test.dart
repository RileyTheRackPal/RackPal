// M5-D `#278` — the reason chip, as a thing a person reads and presses.
//
// THE ASSERTIONS PRINT THE COPY THEY CHECK. A `contains` on a string this
// file also composed proves the two halves of one thought agree with each
// other and nothing else; this repo has shipped twelve green `contains`
// assertions over a line reading "1 ports". So the chip's rendered text is
// collected and compared to the RULE's own sentences, which come from
// `rackpal_core` and were written by a different concern.
//
// AND THE KEYBOARD ROUTE IS TESTED, NOT THE BUTTON LIST. A chip whose
// three buttons all exist and whose Tab order never reaches the second is
// a chip a keyboard user cannot escape, and `find.byType` cannot see the
// difference.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

void main() {
  const withRemedy = SpringBackChip(
    rule: SpringBackRule.hdbasetIntoEthernet,
    headline: 'HDBaseT output cannot terminate on an Ethernet switch port.',
    explanation:
        'HDBaseT uses Ethernet cabling but is not interoperable; PoH may '
        'damage the switch.',
    remedies: [SpringBackRemedy.insertHdbasetReceiver],
  );

  const withoutRemedy = SpringBackChip(
    rule: SpringBackRule.directionMismatch,
    headline: 'MTX-1 J05 and AMP-1 J06 are both inputs.',
    explanation:
        'Neither end drives the cable, so nothing reaches either '
        'input.',
  );

  Future<void> show(
    WidgetTester tester,
    SpringBackChip chip, {
    VoidCallback? onConnectAnyway,
    VoidCallback? onPickAnother,
    void Function(SpringBackRemedy)? onRemedy,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SpringBackChipCard(
              chip: chip,
              onConnectAnyway: onConnectAnyway ?? () {},
              onPickAnother: onPickAnother ?? () {},
              onRemedy: onRemedy,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Every string the chip actually put on screen.
  List<String> rendered(WidgetTester tester) => <String>[
    for (final text in tester.widgetList<Text>(find.byType(Text)))
      if (text.data case final data?) data,
  ];

  group('what it says', () {
    testWidgets("the rule's own two sentences reach the screen, verbatim", (
      tester,
    ) async {
      await show(tester, withRemedy);
      final onScreen = rendered(tester);
      expect(
        onScreen,
        contains(withRemedy.headline),
        reason:
            'the headline is composed by the RULE and rendered whole; a '
            'surface that reworded it would be a second voice for one rule',
      );
      expect(onScreen, contains(withRemedy.explanation));
    });

    testWidgets('the rule id is on the chip, not only in the log', (
      tester,
    ) async {
      // DR-011.5's rule for a refusal is the id AND a sentence naming real
      // designators. Tier 1's status line reads `'$ruleId — $message'`, and
      // a chip that dropped the id would leave a user who wants to change
      // the severity of this rule with nothing to look it up by.
      await show(tester, withRemedy);
      expect(rendered(tester), contains('SIG-001'));
    });

    testWidgets('the id shown is the RULE’s, across all six', (
      tester,
    ) async {
      // A LOOP OVER `values`, so a seventh rule cannot ship with a chip
      // that says SIG-001. The enum is the census; a list typed here would
      // be a second one that goes stale silently.
      for (final rule in SpringBackRule.values) {
        await show(
          tester,
          SpringBackChip(
            rule: rule,
            headline: 'headline for ${rule.id}',
            explanation: 'explanation for ${rule.id}',
          ),
        );
        expect(rendered(tester), contains(rule.id));
      }
    });
  });

  group('what it offers', () {
    testWidgets('[ Connect anyway ] is on every chip, remedy or not', (
      tester,
    ) async {
      // CR-017 admits no exception, and docs/02:854's tier-1 escape
      // ("None. There is nothing to escape to") is what tier 2 is NOT.
      for (final chip in [withRemedy, withoutRemedy]) {
        await show(tester, chip);
        expect(
          rendered(tester),
          contains(kSpringBackConnectAnyway),
          reason:
              'a tier-2 chip without the escape hatch is a tier-1 '
              'refusal wearing the wrong tier',
        );
      }
    });

    testWidgets('a rule with no remedy shows no remedy button', (
      tester,
    ) async {
      await show(tester, withoutRemedy, onRemedy: (_) {});
      expect(
        rendered(tester),
        isNot(contains(SpringBackRemedy.insertHdbasetReceiver.label)),
      );
      expect(rendered(tester), contains(kSpringBackPickAnother));
    });

    testWidgets('a host that cannot perform remedies gets no button, '
        'rather than a dead one', (tester) async {
      // DR-114 §11.113.3's reasoning for `[ Why? ]`, applied generally: a
      // button that leads nowhere is worse than an absent one, because a
      // user aims at it once per rule before learning not to.
      await show(tester, withRemedy);
      expect(
        rendered(tester),
        isNot(contains(SpringBackRemedy.insertHdbasetReceiver.label)),
      );
      await show(tester, withRemedy, onRemedy: (_) {});
      expect(
        rendered(tester),
        contains(SpringBackRemedy.insertHdbasetReceiver.label),
      );
    });

    testWidgets('[ Why? ] is NOT here, and that is DR-114 §11.113.3', (
      tester,
    ) async {
      // AC-058/D1 names the button as a defect; canon §10(g) assigns the
      // viewer to M5-F3 (`#296`). This asserts the omission so that adding
      // it back has to be a deliberate act with a ruling behind it, rather
      // than someone tidying the mockup into the code.
      //
      // IT READS THE BUTTONS, NOT EVERY STRING. A chip whose EXPLANATION
      // happened to contain the word "why" is not shipping the viewer,
      // and a test that failed on one would be pinning the copy instead
      // of the affordance.
      await show(tester, withRemedy, onRemedy: (_) {});
      //
      // `byWidgetPredicate`, NOT `byType`. `find.byType` matches the EXACT
      // runtime type and `ButtonStyleButton` is ABSTRACT, so the first
      // draft of this line found zero buttons and the "no why" loop below
      // would have passed over an empty list forever. That is the
      // vacuous-green shape `run_suite.ps1`'s own header warns about, and
      // it was caught only because the `isNotEmpty` premise was written
      // before the loop rather than after it.
      final labels = <String>[
        for (final b in tester.widgetList<Widget>(
          find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ))
          if ((b as ButtonStyleButton).child case final Text t) t.data ?? '',
      ];
      expect(
        labels,
        isNotEmpty,
        reason: 'the premise: the finder sees this chip as buttons at all',
      );
      for (final label in labels) {
        expect(label.toLowerCase(), isNot(contains('why')));
      }
      expect(labels, contains(kSpringBackConnectAnyway));
    });
  });

  group('the keyboard route', () {
    testWidgets('focus opens on [ Pick a different port ], never on a remedy', (
      tester,
    ) async {
      // THE REMEDY IS THE BETTER OUTCOME AND STILL MUST NOT BE FOCUSED.
      // SIG-001's inserts a DEVICE into the document (CR-015), and the
      // key that opened this chip was the Enter the user pressed to
      // commit. Autofocusing a mutation under a reflex is how a hesitation
      // becomes an edit.
      var remedied = 0;
      var picked = 0;
      await show(
        tester,
        withRemedy,
        onRemedy: (_) => remedied++,
        onPickAnother: () => picked++,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(remedied, 0, reason: 'the reflex must not insert a device');
      expect(picked, 1, reason: 'it dismissed the chip instead');
    });

    testWidgets('one Tab from the opening focus is [ Connect anyway ]', (
      tester,
    ) async {
      // THE ROUTE, NOT THE ROSTER. `find.byType` cannot tell a chip whose
      // Tab order reaches all four from one whose focus is trapped on the
      // first, and the second is a chip a keyboard user cannot act on.
      final pressed = <String>[];
      await show(
        tester,
        withRemedy,
        onRemedy: (r) => pressed.add(r.label),
        onPickAnother: () => pressed.add(kSpringBackPickAnother),
        onConnectAnyway: () => pressed.add(kSpringBackConnectAnyway),
      );

      // Opens on "Pick a different port"; one Tab reaches the next.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        pressed,
        [kSpringBackConnectAnyway],
        reason:
            'the override is ONE Tab from the opening focus and the remedy '
            'is two, so the escape is reachable without hunting and the '
            'button that mutates the document is the one you travel to',
      );
    });

    testWidgets('Shift+Tab from the opening focus reaches the remedy', (
      tester,
    ) async {
      // THE HALF THAT PROVES THE TRAVERSAL IS A RING. The remedy sits
      // BEFORE the opening focus precisely so a reflex cannot press it,
      // which is only defensible if the user who WANTS it is one keystroke
      // away. Measured order from a fresh mount, and it wraps:
      // `Pick a different port` -> `Connect anyway` -> the remedy -> back.
      //
      // ITS OWN TEST RATHER THAN THE TAIL OF THE ONE ABOVE, AND THE REASON
      // IS A DEFECT THIS FILE ALREADY HAD. That draft re-pumped through the
      // same `show` helper and asserted on the result. The second tree is
      // structurally identical, so Flutter REUSES the elements, `autofocus`
      // never re-runs, and focus stays wherever the previous half left it:
      // the assertion measured a traversal starting from `Connect anyway`
      // while its own sentence claimed it started from
      // `Pick a different port`. A FRESH MOUNT IS THE ONLY WAY TO KNOW
      // WHERE A TRAVERSAL BEGAN.
      final pressed = <String>[];
      await show(
        tester,
        withRemedy,
        onRemedy: (r) => pressed.add(r.label),
        onPickAnother: () => pressed.add(kSpringBackPickAnother),
        onConnectAnyway: () => pressed.add(kSpringBackConnectAnyway),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(pressed, [SpringBackRemedy.insertHdbasetReceiver.label]);
    });

    // `Esc` IS NOT TESTED HERE BECAUSE IT IS NOT BOUND HERE. The first
    // draft wrapped the chip in `CallbackShortcuts` and
    // `keymap_source_ban_test.dart` refused it: AC-058/D7 and CR-101 put
    // every keystroke in `kKeymap`, and the registry already binds Esc in
    // `KeyScope.schematic` as `schematicCancel`. A chip is one more rung
    // on that ladder, so the SCREEN dismisses it, and the assertion that
    // Esc reaches `onPickAnother` without cancelling the wire lives in the
    // screen's own suite where both halves are observable.
  });

  group('accessibility', () {
    testWidgets('the whole chip is one live region, id and both sentences', (
      tester,
    ) async {
      // The wire sprang back: something the user did was undone, and a
      // person who cannot see the ring change colour learns that from
      // this announcement or not at all.
      final handle = tester.ensureSemantics();
      await show(tester, withRemedy);
      final node = tester.getSemantics(find.byType(SpringBackChipCard));
      expect(node.label, contains('SIG-001'));
      expect(node.label, contains(withRemedy.headline));
      expect(node.label, contains(withRemedy.explanation));
      handle.dispose();
    });
  });
}
