// M5-F3 — the `[ Why? ]` viewer (`#296`).
//
// THE POINT OF THESE TESTS is that the button no longer leads nowhere,
// which is a claim about CONTENT and not about a route. So they assert
// the catalogue's own words reach the screen, and that the viewer holds
// no copy of them.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, String ruleId) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WhyRuleDialog(ruleId: ruleId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('it shows the catalogue rationale, verbatim', (tester) async {
    final meta = kRulesById['SIG-001']!;
    await pump(tester, 'SIG-001');
    // VERBATIM AND WHOLE. A `contains` would pass over a truncation,
    // which is the failure mode a rationale viewer cannot afford.
    expect(find.text(meta.rationale), findsOneWidget);
  });

  testWidgets('it shows what the rule checks, and the decisions behind it', (
    tester,
  ) async {
    final meta = kRulesById['CODE-001']!;
    await pump(tester, 'CODE-001');
    expect(find.text(meta.summary), findsOneWidget);
    expect(find.text(meta.governing.join(', ')), findsOneWidget);
    expect(find.text(kWhyMatters), findsOneWidget);
    expect(find.text(kWhyChecks), findsOneWidget);
    expect(find.text(kWhyDecisions), findsOneWidget);
  });

  testWidgets('why comes before what', (tester) async {
    // The person pressed a button that asks WHY. Leading with the
    // predicate would answer a question they did not ask.
    await pump(tester, 'SIG-001');
    final why = tester.getTopLeft(find.text(kWhyMatters)).dy;
    final what = tester.getTopLeft(find.text(kWhyChecks)).dy;
    expect(why, lessThan(what));
  });

  testWidgets('an unknown rule is answered, not thrown', (tester) async {
    // CR-021: a rule not in the catalogue does not exist. A file from a
    // later version is how one arrives.
    await pump(tester, 'ZZZ-999');
    expect(find.text(whyUnknownRule('ZZZ-999')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every rule in the catalogue can be opened', (tester) async {
    // THE WHOLE CATALOGUE, not a sample. A viewer that worked for the
    // flagship and threw on LNK-020 would be the button leading nowhere
    // again, for one rule.
    for (final rule in kRuleCatalogue) {
      await pump(tester, rule.ruleId);
      expect(
        find.text(rule.rationale),
        findsOneWidget,
        reason: '${rule.ruleId} did not render its rationale',
      );
      expect(tester.takeException(), isNull);
    }
  });

  test('the viewer holds no copy of any rationale', () {
    // `#296`: "sourced from the catalogue metadata so it cannot drift
    // from the predicate". The guard is that the source file contains
    // none of the catalogue's rationale text.
    final src = File(
      'lib/src/validation/why_rule_dialog.dart',
    ).readAsStringSync();
    for (final rule in kRuleCatalogue) {
      // The first clause is enough to catch a paste.
      final head = rule.rationale.split('.').first;
      expect(
        src.contains(head),
        isFalse,
        reason: '${rule.ruleId} rationale is duplicated in the viewer',
      );
    }
  });
}
