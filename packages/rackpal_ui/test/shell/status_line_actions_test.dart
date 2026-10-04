// The status line's actions (M6-I4, `#355`, CR-100): an export's Open and
// Show in folder, after the message and after the notices link.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

void main() {
  testWidgets('each action is a button after the message, in order, and '
      'pressing one calls it', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellStatusLine(
            message: 'Exported 16 sheets · 64 KB · 2 notices',
            notices: const ['a.', 'b.'],
            noticeLabel: '2 notices',
            actions: [
              (label: 'Open', onPressed: () => pressed.add('Open')),
              (
                label: 'Show in folder',
                onPressed: () => pressed.add('Show in folder'),
              ),
            ],
          ),
        ),
      ),
    );
    final labels = [
      for (final b in tester.widgetList<TextButton>(find.byType(TextButton)))
        (b.child! as Text).data,
    ];
    expect(labels, ['2 notices', 'Open', 'Show in folder']);
    await tester.tap(find.text('Show in folder'));
    await tester.tap(find.text('Open'));
    expect(pressed, ['Show in folder', 'Open']);
  });

  testWidgets('no actions, no buttons: every other status is unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ShellStatusLine(message: 'Saved.')),
      ),
    );
    expect(find.byType(TextButton), findsNothing);
  });
}
