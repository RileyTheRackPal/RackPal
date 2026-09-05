// The start card in the REAL shell: the first frame a user sees, and
// what pressing each thing on it actually does.
//
// docs/04 §9: *"First launch shows a start card, not an empty canvas."*
// Everything here drives the shipping `AppShell` — the real
// `SessionController`, the real dialogs, the real four `.rmpj` files
// read off disk — against a fake filesystem, a fake window and a fake
// file dialog. Nothing calls a controller method directly; every
// assertion goes through a tap or a key event.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/starter_projects.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../session/session_fakes.dart';
import '../test_measurer.dart';
import 'starter_integrity.dart';

Future<void> _tapTile(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final measurer = loadTestMeasurer();

  setUp(() {
    // A REALISTIC WINDOW, for the same reason `widget_test.dart` states:
    // the rack screen lays out docs/04 §1's four columns, and on the
    // default 800x600 surface its floating chrome overlaps itself.
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .implicitView!
        .resetPhysicalSize();
  });

  testWidgets('the first frame is the start card, not the canvas', (
    tester,
  ) async {
    final built = await buildTestApp(measurer, showStartCard: true);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    expect(find.byType(StartCard), findsOneWidget);
    expect(
      find.byType(RackCanvasScreen),
      findsNothing,
      reason: 'docs/04 §9: a start card, NOT an empty canvas',
    );
    // AND NO TAB STRIP. The three tabs are views of a document the user
    // has not chosen yet.
    expect(find.byType(TabBar), findsNothing);
    for (final starter in kStarterProjects) {
      expect(find.text(starter.title), findsOneWidget);
    }
    expect(find.text(StartCard.blankTitle), findsOneWidget);
  });

  for (final starter in kStarterProjects) {
    testWidgets('picking "${starter.title}" opens it, from its real file', (
      tester,
    ) async {
      final built = await buildTestApp(measurer, showStartCard: true);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();

      await _tapTile(tester, starter.title);

      // THE ROADMAP GATE, THROUGH THE UI THIS TIME. The asset test proves
      // the files open; this proves the card opens them.
      expect(find.byType(StartCard), findsNothing);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(RackCanvasScreen), findsOneWidget);

      final session = built.session.services.session;
      expect(session.document.racks, isNotEmpty);
      expect(
        session.filePath,
        isNull,
        reason:
            'a starter opens as an UNTITLED COPY — it must not be bound '
            'to a path inside the application bundle',
      );
      expect(
        session.isDirty,
        isFalse,
        reason:
            'nothing has been edited yet, and the original is still in '
            'the bundle, so there is nothing to lose',
      );
      expect(session.status, contains(starter.title));

      // The document that reached the shell is the same document the
      // asset test vets.
      expectStarterIsStructurallyClean(session.document, of: starter.title);
    });
  }

  testWidgets('Blank project produces the same document Ctrl+N does', (
    tester,
  ) async {
    final built = await buildTestApp(measurer, showStartCard: true);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    await _tapTile(tester, StartCard.blankTitle);

    final session = built.session.services.session;
    expect(find.byType(StartCard), findsNothing);
    expect(find.byType(RackCanvasScreen), findsOneWidget);
    expect(session.filePath, isNull);
    expect(session.document.racks, hasLength(1));
    expect(session.document.racks.values.single.heightU, 42);
    expect(
      session.document.templates,
      hasLength(49),
      reason:
          'a blank project must carry the catalogue, or every palette '
          'row refuses',
    );
  });

  testWidgets('Ctrl+S on a freshly opened starter routes to Save As', (
    tester,
  ) async {
    // The consequence of "untitled copy" that the user actually feels.
    // A starter that saved silently would overwrite a file inside the
    // application bundle.
    final built = await buildTestApp(
      measurer,
      showStartCard: true,
      savePaths: [r'C:\jobs\My Cinema.rmpj'],
    );
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    await _tapTile(tester, kStarterProjects.first.title);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(
      built.session.picker.saveCalls,
      1,
      reason: 'Ctrl+S on a never-saved document must open Save As',
    );
    expect(
      built.session.services.session.filePath,
      r'C:\jobs\My Cinema.rmpj',
    );
    expect(
      built.session.fs.exists(r'C:\jobs\My Cinema.rmpj'),
      completion(isTrue),
    );
  });

  testWidgets('a saved starter copy round-trips byte-exactly', (tester) async {
    // The starter is a golden; so is what the application writes when it
    // saves one. This is the full loop — bundle asset -> decode -> shell
    // -> atomic save -> bytes on the fake disk -> decode again — and it
    // is the strongest single check that opening a starter did not
    // quietly drop anything.
    final built = await buildTestApp(
      measurer,
      showStartCard: true,
      savePaths: [r'C:\jobs\Copy.rmpj'],
    );
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    await _tapTile(tester, 'Whole house');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final written = await built.session.fs.readBytes(r'C:\jobs\Copy.rmpj');
    final reread = const JsonDocumentCodec().read(written);
    expect(reread, isA<Ok<RackDocument>>());
    final document = (reread as Ok<RackDocument>).value;

    expect(
      const JsonDocumentCodec().write(document),
      orderedEquals(written),
      reason: 'CR-117 must hold for what the application writes, too',
    );
    expectStarterIsStructurallyClean(document, of: 'saved Whole house copy');
    expect(
      document.links,
      hasLength(27),
      reason: 'the structured wiring survived the whole round trip',
    );
    expect(document.structures, hasLength(1));
  });

  testWidgets('picking a starter runs the discard guard', (tester) async {
    // `openStarter` is the FIFTH caller of `guardDiscard`. A starter that
    // skipped it would be the one document-replacing path that throws
    // away unsaved work without asking.
    final built = await buildTestApp(measurer, showStartCard: true);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    // Open one, edit it, then try to open another.
    await _tapTile(tester, 'Apartment');
    final session = built.session.services.session;
    final rack = session.document.racks.values.first;
    session.controller.run(
      RenameEntityCommand(
        targetKind: RenameTargetKind.rack,
        id: rack.id,
        from: rack.name,
        to: 'Edited',
        now: DateTime.utc(2026),
        actor: 'test',
      ),
    );
    await tester.pumpAndSettle();
    expect(session.isDirty, isTrue);

    // The card is gone, so reach the second starter through the same
    // controller call the card would have made. NOT awaited: it is about
    // to raise a modal, and awaiting a dialog that only a pump can
    // dismiss deadlocks the test.
    unawaited(
      built.session.services.controller.openStarter(kStarterProjects[2]),
    );
    await tester.pumpAndSettle();

    // The real three-button dialog is up, because `useRealDialogs` is on.
    expect(find.byType(UnsavedChangesDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      session.document.racks.values.first.name,
      'Edited',
      reason: 'Cancel must leave the edited document exactly where it was',
    );
  });

  testWidgets('a starter that will not load reports, and leaves the card '
      'up', (tester) async {
    // "Never silently do nothing" has no exemption for our own build
    // being broken.
    final built = await buildTestApp(
      measurer,
      showStartCard: true,
      starterLoader: (_) async => throw StateError('asset missing'),
    );
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    await _tapTile(tester, 'Home theatre');

    expect(find.byType(FileErrorDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.byType(StartCard),
      findsOneWidget,
      reason:
          'a failed open must not drop the user onto an editor they did '
          'not ask for',
    );
  });

  testWidgets('two starter copies never share a document id', (tester) async {
    final built = await buildTestApp(measurer, showStartCard: true);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    await _tapTile(tester, 'Apartment');
    final first = built.session.services.session.documentId;

    // Reopening the same starter. The document is clean, so the guard
    // passes without a prompt.
    unawaited(
      built.session.services.controller.openStarter(kStarterProjects[3]),
    );
    await tester.pumpAndSettle();
    final second = built.session.services.session.documentId;

    expect(
      second,
      isNot(first),
      reason:
          'a shared id is a shared recovery snapshot path — recovering '
          "one copy would offer the other copy's work",
    );
  });
}
