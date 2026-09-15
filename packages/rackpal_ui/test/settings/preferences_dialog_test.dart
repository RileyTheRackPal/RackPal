// Edit > Preferences (DR-172): the undo depth field refuses what the ruling
// refuses, applies on Enter or Close, and discards on Escape or a click
// outside, so a half-typed depth never drops anybody's history.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart'
    show kMaxUndoDepth, kMinUndoDepth;
import 'package:rackpal_ui/rackpal_ui.dart';

const ValueKey<String> _field = ValueKey('preferences.undoDepth');

/// Opens the dialog over a bare app and returns every depth it applies.
Future<List<int>> _open(WidgetTester tester, {int undoDepth = 200}) async {
  final applied = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPreferencesDialog(
              context,
              undoDepth: undoDepth,
              onUndoDepthChanged: applied.add,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return applied;
}

void main() {
  testWidgets('it opens on the depth in force, with the range in its help', (
    tester,
  ) async {
    await _open(tester, undoDepth: 350);

    expect(find.text('Preferences'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(_field)).controller!.text,
      '350',
    );
    expect(find.text(kUndoDepthHelp), findsOneWidget);
    expect(kUndoDepthHelp, contains('$kMinUndoDepth to $kMaxUndoDepth'));
  });

  for (final (typed, message) in [
    ('49', 'Between 50 and 1000.'),
    ('1001', 'Between 50 and 1000.'),
    ('lots', 'Whole numbers only.'),
    ('', 'Whole numbers only.'),
  ]) {
    testWidgets('refuses [$typed] on Close, applies nothing, and stays open', (
      tester,
    ) async {
      final applied = await _open(tester);

      await tester.enterText(find.byKey(_field), typed);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(applied, isEmpty);
      expect(find.text('Preferences'), findsOneWidget);
    });
  }

  testWidgets('Enter applies an accepted depth once, and closes', (
    tester,
  ) async {
    final applied = await _open(tester);

    await tester.enterText(find.byKey(_field), '500');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(applied, [500]);
    expect(find.text('Preferences'), findsNothing);
  });

  testWidgets('Close with the depth unchanged applies nothing', (tester) async {
    final applied = await _open(tester);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(applied, isEmpty);
    expect(find.text('Preferences'), findsNothing);
  });

  testWidgets('Escape discards what was typed, so a half-typed depth drops '
      'nothing', (tester) async {
    final applied = await _open(tester);

    await tester.enterText(find.byKey(_field), '60');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(applied, isEmpty);
    expect(find.text('Preferences'), findsNothing);
  });

  testWidgets('a click outside the dialog discards it too', (tester) async {
    final applied = await _open(tester);

    await tester.enterText(find.byKey(_field), '60');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(applied, isEmpty);
    expect(find.text('Preferences'), findsNothing);
  });
}
