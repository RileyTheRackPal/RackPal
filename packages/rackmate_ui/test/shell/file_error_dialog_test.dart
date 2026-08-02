// The one dialog every storage failure reaches the user through.
//
// It is presentational, so these tests are about the CONTRACT with the
// app layer: the actions it was given are the buttons it renders, the id
// it returns is the id it was given, and a dismissal resolves to
// something rather than to null — because a null would have to be
// interpreted at the call site, and an unhandled interpretation is how a
// refused save becomes silence.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

const _view = FileErrorView(
  title: 'Could not save Smith.rmpj',
  detail: r'The folder \\NAS\jobs is not available right now.',
  reassurance: 'Your changes are safe and still open.',
  actions: [
    FileErrorAction(id: 'saveAs', label: 'Save As…', isPrimary: true),
    FileErrorAction(id: 'retry', label: 'Try again'),
    FileErrorAction(id: 'cancel', label: 'Cancel'),
  ],
);

final class _Result {
  String? pressed;
}

Future<_Result> _open(WidgetTester tester, [FileErrorView view = _view]) async {
  final result = _Result();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async =>
              result.pressed = await showFileErrorDialog(context, view),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('FileErrorDialog', () {
    testWidgets('renders the title, the detail and the reassurance', (
      tester,
    ) async {
      await _open(tester);
      expect(find.text('Could not save Smith.rmpj'), findsOneWidget);
      expect(
        find.text(r'The folder \\NAS\jobs is not available right now.'),
        findsOneWidget,
      );
      // The line that answers the question the user actually has, which
      // no errno ever does.
      expect(
        find.text('Your changes are safe and still open.'),
        findsOneWidget,
      );
    });

    testWidgets('one button per action, primary rendered as the default', (
      tester,
    ) async {
      await _open(tester);
      expect(find.widgetWithText(FilledButton, 'Save As…'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Try again'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    });

    testWidgets('returns the pressed action id, not its label', (
      tester,
    ) async {
      final result = await _open(tester);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      // A STABLE identifier, so copy can be reworded without silently
      // rerouting the caller's switch.
      expect(result.pressed, 'retry');
    });

    testWidgets('Esc resolves to the dismiss action rather than null', (
      tester,
    ) async {
      final result = await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(result.pressed, 'cancel');
    });

    testWidgets('clicking outside is not a decision', (tester) async {
      await _open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('a view with no reassurance shows none', (tester) async {
      await _open(
        tester,
        const FileErrorView(
          title: 'That is not a RackMate file.',
          detail: 'holiday-photos.json does not contain a project.',
          actions: [
            FileErrorAction(id: 'ok', label: 'OK', isPrimary: true),
          ],
        ),
      );
      expect(
        find.text('Your changes are safe and still open.'),
        findsNothing,
      );
      expect(find.byType(TextButton), findsNothing);
      expect(find.widgetWithText(FilledButton, 'OK'), findsOneWidget);
    });

    test('dismissActionId is the LAST action', () {
      // By construction the app layer's last action is always the least
      // destructive one, so a dismissal can never mean "overwrite".
      expect(_view.dismissActionId, 'cancel');
    });
  });

  group('ReadOnlyBanner', () {
    testWidgets('states why, and offers the one way forward', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(home: ReadOnlyBanner(onSaveCopy: () => pressed++)),
      );

      expect(find.text(ReadOnlyBanner.message), findsOneWidget);
      // The user is blocked from OVERWRITING, not from working — so the
      // banner must carry an action, not just a fact.
      await tester.tap(find.text('Save a copy…'));
      expect(pressed, 1);
    });

    testWidgets('is NOT dismissible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ReadOnlyBanner(onSaveCopy: () {})),
      );
      // The fact it states changes what Ctrl+S does. A dismissed banner
      // would leave that difference unexplained.
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });

  group('ShellWarningBanner', () {
    testWidgets('is dismissible, because the user cannot act on it', (
      tester,
    ) async {
      var dismissed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ShellWarningBanner(
            message: 'Autosave is off.',
            onDismiss: () => dismissed++,
          ),
        ),
      );
      expect(find.text('Autosave is off.'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      expect(dismissed, 1);
    });
  });

  group('NoRacksView', () {
    testWidgets('names the document, and its one button creates a rack', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: NoRacksView(
            documentName: 'Smith Residence',
            onNewRack: () => pressed++,
          ),
        ),
      );

      expect(find.text('Smith Residence contains no racks.'), findsOneWidget);
      expect(find.text(NoRacksView.detail), findsOneWidget);
      // An empty rack canvas here would be the same lie the Schedule tab was
      // rescued from: rails and a ruler for a rack that is not in the
      // document. What the panel DOES offer is the one thing it can honour.
      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.text('New rack…'));
      await tester.pump();
      expect(pressed, 1);
    });
  });
}
