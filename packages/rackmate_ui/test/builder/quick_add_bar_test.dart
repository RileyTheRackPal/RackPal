// M4-G1's gate: the docked bar, and the invariant that IS the feature.
//
// docs/06 §9.3 names two things that make the thirteen-step count real
// rather than a demo, and the first is "focus never leaves Quick Add
// during steps 6 to 13". That is what the middle group here asserts,
// and it is asserted by checking the FocusNode after a commit rather
// than by checking that a commit happened: a bar that adds sixteen
// ports and then drops focus has failed the criterion while passing
// every test about ports.
//
// THE SUMMARY SENTENCE IS TESTED WITHOUT A WIDGET, in the last group,
// because `describeQuickAddPlan` is pure. On-screen copy is the half of
// this repository's UI that widget tests have historically been worst
// at seeing, and a string assertion beats a `find.textContaining`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

TemplateBody _body() =>
    TemplateBody(manufacturer: 'Generic', model: 'M', displayName: 'D');

void main() {
  final registries = buildSeedRegistries();

  /// Pumps a bar over a live body, applying what it hands back the way
  /// the grid's `transact` does.
  Future<TemplateBody> pumpBar(
    WidgetTester tester, {
    TemplateBody? over,
  }) async {
    final body = over ?? _body();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => QuickAddBar(
              body: body,
              registries: registries,
              onRun: (commands) => setState(() {
                for (final c in commands) {
                  c.apply(body);
                }
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return body;
  }

  Finder barField() => find.byType(TextField);

  group('the bar is docked and it adds (M4-G1)', () {
    testWidgets('focus lands here on entering the section', (tester) async {
      await pumpBar(tester);
      expect(
        tester.widget<TextField>(barField()).focusNode?.hasFocus,
        isTrue,
      );
    });

    testWidgets('Enter adds the ports the command names', (tester) async {
      final body = await pumpBar(tester);
      await tester.enterText(barField(), '16 hdbt out "HDBT OUT {n:2}"');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(body.ports, hasLength(16));
      expect(body.banks.single.label, 'HDBT Outputs');
      expect(body.ports.first.label, 'HDBT OUT 01');
    });

    testWidgets('and the field clears, so the next command is pure typing', (
      tester,
    ) async {
      await pumpBar(tester);
      await tester.enterText(barField(), '4 hdmi in');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(tester.widget<TextField>(barField()).controller?.text, isEmpty);
    });

    testWidgets('FOCUS RETURNS AFTER THE ADD, which is the invariant', (
      tester,
    ) async {
      // A bar that adds sixteen ports and then drops focus has failed
      // docs/06 §9.3 while passing every test about ports.
      await pumpBar(tester);
      await tester.enterText(barField(), '16 hdmi in');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
        tester.widget<TextField>(barField()).focusNode?.hasFocus,
        isTrue,
        reason: 'consecutive banks must be pure typing',
      );
    });

    testWidgets('eight commands in a row build the 68-port template', (
      tester,
    ) async {
      // docs/06 §9.1's steps 6 to 13, typed one after another with no
      // mouse and no re-focusing between them. This is the closest a
      // widget test gets to the drill M4-Q measures.
      final body = await pumpBar(tester);
      const steps = <String>[
        '16 hdmi in "HDMI IN {n:2}"',
        '16 hdbt out "HDBT OUT {n:2}"',
        '16 hdmi out "MIRROR {n:2}" @Mirror Outputs',
        '16 ir35 out "IR OUT {n:2}"',
        '1 rj45 in "LAN" @Control',
        '1 de9 bi "RS-232" @Control',
        '1 ir35 in "IR IN" @Control',
        '1 c14 in',
      ];
      for (final step in steps) {
        await tester.enterText(barField(), step);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
      }

      expect(body.ports, hasLength(68));
      expect(body.banks, hasLength(6));
      expect(
        tester.widget<TextField>(barField()).focusNode?.hasFocus,
        isTrue,
        reason: 'focus never left across eight commands',
      );
    });

    testWidgets('the Add button is dead until the command parses', (
      tester,
    ) async {
      await pumpBar(tester);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.enterText(barField(), '16 hdmi in');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('Enter on an unparseable command adds nothing', (tester) async {
      final body = await pumpBar(tester);
      await tester.enterText(barField(), '16 wibble in');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(body.ports, isEmpty);
    });
  });

  group('designed errors reach the surface (AC-050 / A2.4)', () {
    testWidgets('the message is shown, not an exception', (tester) async {
      await pumpBar(tester);
      await tester.enterText(barField(), '16 wibble in');
      await tester.pump();
      expect(find.textContaining('not a connector'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the repair chip is offered and applying it types it', (
      tester,
    ) async {
      await pumpBar(tester);
      await tester.enterText(barField(), 'hdmi in');
      await tester.pump();

      final chip = find.widgetWithText(ActionChip, '16 hdmi in');
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pump();

      expect(
        tester.widget<TextField>(barField()).controller?.text,
        '16 hdmi in',
      );
    });

    testWidgets('a half-typed quote is NOT an error under the hands', (
      tester,
    ) async {
      // The bar parses on every keystroke. Refusing mid-word would paint
      // red while the user is still typing the label.
      await pumpBar(tester);
      await tester.enterText(barField(), '16 hdmi in "HDMI IN');
      await tester.pump();
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });

  group('the summary line, which is what stops a 16-port typo', () {
    test('it names the resolved family and the derived bank', () {
      final plan =
          parseQuickAdd(registries, '16 hdbt out "HDBT OUT {n:2}"')
              as QuickAddPlan;
      final text = describeQuickAddPlan(registries, _body(), plan);

      expect(text, contains('16 ports'));
      expect(text, contains('HDBaseT (5Play)'));
      expect(text, contains('RJ45 (8P8C)'));
      expect(text, contains('output'));
      expect(text, contains('rear'));
      expect(text, contains('bank "HDBT Outputs" (new)'));
      expect(text, contains('HDBT OUT 01'));
      expect(text, contains('HDBT OUT 16'));
    });

    test('"(new)" disappears once the bank exists', () {
      final body = _body()
        ..banks.add(
          BankDef(
            key: 'c',
            label: 'Control',
            abbr: 'C',
            order: const FracIndex('a0'),
          ),
        );
      final plan =
          parseQuickAdd(registries, '1 rj45 in @Control') as QuickAddPlan;
      final text = describeQuickAddPlan(registries, body, plan);
      expect(text, contains('bank "Control"'));
      expect(text, isNot(contains('(new)')));
    });

    test('an unresolved family SAYS SO rather than going quiet', () {
      // `4 xlr in` is legal and leaves the family blank; a summary that
      // simply omitted it would read as a complete command.
      final plan = parseQuickAdd(registries, '4 xlr in') as QuickAddPlan;
      final text = describeQuickAddPlan(registries, _body(), plan);
      expect(text, contains('signal not set'));
    });

    test('it counts PORTS, so both reports 48 for a 24-way panel', () {
      final plan =
          parseQuickAdd(registries, '24 rj45 pass both "{n:2}"')
              as QuickAddPlan;
      final text = describeQuickAddPlan(registries, _body(), plan);
      expect(text, contains('48 ports'));
      expect(text, contains('front and rear'));
    });

    test('directions read as trade words, never as enum names', () {
      // M4-D found twenty-six strings citing the corpus at the user and
      // dropdowns showing raw Dart identifiers. `sink` would be that.
      final plan = parseQuickAdd(registries, '16 hdmi in') as QuickAddPlan;
      final text = describeQuickAddPlan(registries, _body(), plan);
      expect(text, contains('input'));
      expect(text, isNot(contains('sink')));
    });
  });
}
