// The Export notices dialog and the status line's link (M6-M `#983`,
// DR-224).
//
// The shell test in the app drives the real menu to the real dialog; this
// holds the edges that route cannot reach cheaply: grouping by sheet, a
// line with nothing to read, a line whose end is not the count, and Copy.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: child)),
);

void main() {
  test('notices group by the sheet they name, in the order raised, and a '
      'set-wide one under its own heading', () {
    final groups = groupExportNotices(const [
      'T6.10: 4 pathways have no designator.',
      'T0.00: Smallest text is 6 pt.',
      'T6.10: another.',
      'The equipment list needs 12 pages.',
    ]);
    expect(groups.map((g) => g.heading), [
      'T6.10',
      'T0.00',
      kSetWideNoticesHeading,
    ]);
    expect(groups.first.notices, [
      '4 pathways have no designator.',
      'another.',
    ]);
    expect(groups.last.notices, ['The equipment list needs 12 pages.']);
  });

  testWidgets('a status line with no notices has no link', (tester) async {
    await _pump(tester, const ShellStatusLine(message: 'Saved.'));
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('Saved.'), findsOneWidget);
  });

  testWidgets('A LINE THAT DOES NOT END WITH THE COUNT gets no link, rather '
      'than one on the wrong words', (tester) async {
    await _pump(
      tester,
      const ShellStatusLine(
        message: 'Saved.',
        notices: ['T0.00: something'],
        noticeLabel: '1 notice',
      ),
    );
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('the count is the link, and Copy puts every notice on the '
      'clipboard, one per line', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    const notices = ['T0.00: Smallest text is 6 pt.', 'T6.10: four.'];
    await _pump(
      tester,
      const ShellStatusLine(
        message: 'Exported 8 sheets · 22 KB · 2 notices',
        notices: notices,
        noticeLabel: '2 notices',
      ),
    );
    expect(find.text('Exported 8 sheets · 22 KB · '), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '2 notices'));
    await tester.pumpAndSettle();
    expect(find.text('Smallest text is 6 pt.'), findsOneWidget);
    expect(find.text('T6.10'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Copy'));
    await tester.pump();
    expect(copied, notices.join('\n'));
  });
}
