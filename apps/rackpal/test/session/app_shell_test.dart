// The shell, driven the way a user drives it.
//
// EVERYTHING HERE IS A REAL KEY EVENT OR A REAL TAP against the real
// `RackPalApp`, over a fake disk, a fake window and a fake file dialog.
// No production code is stubbed: the `Shortcuts`/`Actions` pair, the File
// menu, the real three-button dialog and the real recovery prompt are all
// the ones that ship. That is the difference between "the controller has
// a save method" and "Ctrl+S saves".
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal/src/session/autosave_scheduler.dart';
import 'package:rackpal/src/session/blank_document.dart';
import 'package:rackpal/src/session/export_controller.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

const _target = r'C:\jobs\Smith.rppj';

void main() {
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('Jost'): bytes,
    });
  });

  // The supported window size. docs/04 §1 treats anything under 1080 px
  // as the (unbuilt) tablet-collapse case.
  setUp(() {
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
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  /// Pumps the real app over a fake session.
  Future<TestSession> pump(
    WidgetTester tester, {
    List<String?> savePaths = const [],
    List<String?> openPaths = const [],
    FakeFileStore? fs,
    RackDocument? document,
    bool runStartupRecovery = false,
  }) async {
    final built = await buildTestApp(
      measurer,
      document: document,
      savePaths: savePaths,
      openPaths: openPaths,
      fs: fs,
      runStartupRecovery: runStartupRecovery,
    );
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    return built.session;
  }

  /// One real edit, through a real command.
  void edit(TestSession t) {
    final rack = t.services.session.document.racks.values.first;
    t.services.session.controller.run(
      SetRackHeightCommand(
        id: rack.id,
        fromHeightU: rack.heightU,
        toHeightU: rack.heightU - 1,
        now: DateTime.utc(2026),
        actor: 'test',
      ),
    );
  }

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  group('the dirty marker', () {
    testWidgets('appears in BOTH the in-app title and the OS window title', (
      tester,
    ) async {
      final t = await pump(tester);

      expect(find.text('Untitled — RackPal'), findsOneWidget);
      expect(t.chrome.titles.last, 'Untitled — RackPal');

      edit(t);
      await tester.pumpAndSettle();

      // One function computes both, so they can never disagree about
      // whether there is unsaved work.
      expect(find.text('*Untitled — RackPal'), findsOneWidget);
      expect(t.chrome.titles.last, '*Untitled — RackPal');
    });

    testWidgets('the OS title is pushed only when the STRING changes', (
      tester,
    ) async {
      final t = await pump(tester);
      final before = t.chrome.titles.length;

      // Ten notifications that do not change the rendered title.
      for (var i = 0; i < 10; i++) {
        t.services.session.setStatus('tick $i');
      }
      await tester.pumpAndSettle();

      expect(t.chrome.titles.length, before);
    });

    testWidgets('CR-094: undoing back to the save point clears it', (
      tester,
    ) async {
      final t = await pump(tester);
      edit(t);
      await tester.pumpAndSettle();
      expect(find.text('*Untitled — RackPal'), findsOneWidget);

      t.services.session.controller.undoLast();
      await tester.pumpAndSettle();

      expect(find.text('Untitled — RackPal'), findsOneWidget);
    });
  });

  group('the four keybindings', () {
    testWidgets('Ctrl+S saves, through the real save dialog seam', (
      tester,
    ) async {
      final t = await pump(tester, savePaths: [_target]);
      edit(t);
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.keyS);

      expect(t.picker.saveCalls, 1);
      expect(t.fs.state.files.containsKey(_target), isTrue);
      expect(find.text('Smith — RackPal'), findsOneWidget);
    });

    testWidgets('Ctrl+Shift+S is Save As even on a saved document', (
      tester,
    ) async {
      final t = await pump(
        tester,
        savePaths: [_target, r'C:\jobs\Copy.rppj'],
      );
      await press(tester, LogicalKeyboardKey.keyS);
      expect(t.picker.saveCalls, 1);

      await press(tester, LogicalKeyboardKey.keyS, shift: true);

      expect(t.picker.saveCalls, 2);
      expect(t.services.session.filePath, r'C:\jobs\Copy.rppj');
    });

    testWidgets('Ctrl+N replaces the document with a blank one', (
      tester,
    ) async {
      final t = await pump(tester);
      final before = t.services.session.controller;

      await press(tester, LogicalKeyboardKey.keyN);

      expect(t.services.session.controller, isNot(same(before)));
      expect(
        t.services.session.document.racks.values.single.heightU,
        kBlankProjectRackHeightU,
      );
      // v1 is single-document, single-window (CR-119): the SAME shell,
      // rebuilt, not a second window or a new tab.
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(RackCanvasScreen), findsOneWidget);
    });

    testWidgets('Ctrl+O opens through the real open dialog seam', (
      tester,
    ) async {
      final onDisk = buildBlankDocument(
        now: DateTime.utc(2026),
        appVersion: '0.1.0',
        id: const Uuid('opened'),
        rackId: const Uuid('opened-rack'),
        catalog: const {},
      )..info = ProjectInfo(projectName: 'Jones Loft');
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {_target: const JsonDocumentCodec().write(onDisk)},
      );
      final t = await pump(tester, fs: fs, openPaths: [_target]);

      await press(tester, LogicalKeyboardKey.keyO);

      expect(t.services.session.displayName, 'Jones Loft');
      expect(find.text('Jones Loft — RackPal'), findsOneWidget);
    });
  });

  group('the File menu', () {
    testWidgets('offers New / Open / Open Recent / Save / Save As', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();

      expect(find.text('New'), findsOneWidget);
      expect(find.text('Open…'), findsOneWidget);
      expect(find.text('Open Recent'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Save As…'), findsOneWidget);
      expect(find.text('Export PDF…'), findsOneWidget);
    });

    testWidgets('Export PDF… runs the export and reports on the status '
        'line', (tester) async {
      // The whole export is proved in `export_controller_test.dart` and in
      // `rackpal_export`'s own suite; what this asserts is the WIRING —
      // that the menu entry reaches the controller at all.
      final t = await pump(tester, savePaths: [r'C:\jobs\smith.pdf']);
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export PDF…'));
      await tester.pumpAndSettle();

      expect(t.fs.state.files.containsKey(r'C:\jobs\smith.pdf'), isTrue);
      expect(find.textContaining('Exported '), findsOneWidget);
    });

    testWidgets('Export for construction… runs the export WITH THE STAMP '
        'REQUESTED, and carries no accelerator (DR-216)', (tester) async {
      // WIRING, as above: the stamp's two outcomes are proved in
      // `export_controller_test.dart` and `rackpal_export`. Either one on
      // the status line proves the request carried the flag, since a plain
      // export prints neither.
      final t = await pump(tester, savePaths: [r'C:\jobs\smith.pdf']);
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      final item = tester.widget<MenuItemButton>(
        find.ancestor(
          of: find.text(kExportForConstructionLabel),
          matching: find.byType(MenuItemButton),
        ),
      );
      expect(item.shortcut, isNull);
      await tester.tap(find.text(kExportForConstructionLabel));
      await tester.pumpAndSettle();

      expect(t.fs.state.files.containsKey(r'C:\jobs\smith.pdf'), isTrue);
      expect(
        find.textContaining(RegExp('issued for construction|not stamped')),
        findsOneWidget,
      );
    });

    testWidgets('Export PDF… carries NO accelerator — the binding is a '
        'separate decision', (tester) async {
      // docs/08 §8.1 gives export Ctrl+P. `session_layering_test.dart`
      // RULE 14 counts activators in this file, so declaring one on the
      // menu item would edit that rule by stealth AND advertise a key
      // nothing listens for.
      await pump(tester);
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();

      final item = tester.widget<MenuItemButton>(
        find.ancestor(
          of: find.text('Export PDF…'),
          matching: find.byType(MenuItemButton),
        ),
      );
      expect(item.shortcut, isNull);
    });

    testWidgets('Save from the menu does the same thing as Ctrl+S', (
      tester,
    ) async {
      final t = await pump(tester, savePaths: [_target]);
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(t.fs.state.files.containsKey(_target), isTrue);
    });

    testWidgets('Open Recent says so when there is nothing to open', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Recent'));
      await tester.pumpAndSettle();

      // An empty menu that opens onto nothing is "never silently do
      // nothing" in miniature.
      expect(find.text('No recent files'), findsOneWidget);
    });

    testWidgets('a saved file appears in Open Recent', (tester) async {
      await pump(tester, savePaths: [_target]);
      await press(tester, LogicalKeyboardKey.keyS);

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Recent'));
      await tester.pumpAndSettle();

      expect(find.text('Smith'), findsOneWidget);
    });
  });

  group('close interception, through the REAL dialog', () {
    testWidgets('a clean document closes with no prompt', (tester) async {
      final t = await pump(tester);

      await t.chrome.requestClose();
      await tester.pumpAndSettle();

      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(t.chrome.destroyCalls, 1);
    });

    testWidgets('a dirty document raises the THREE-button dialog', (
      tester,
    ) async {
      final t = await pump(tester);
      edit(t);
      await tester.pumpAndSettle();

      unawaited(t.chrome.requestClose());
      await tester.pumpAndSettle();

      expect(find.byType(UnsavedChangesDialog), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Don’t Save'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(
        find.text('If you don’t save, 1 change will be lost.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(t.chrome.destroyCalls, 0);
    });

    testWidgets('Esc at the close prompt cancels and keeps the window', (
      tester,
    ) async {
      final t = await pump(tester);
      edit(t);
      await tester.pumpAndSettle();

      unawaited(t.chrome.requestClose());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(t.chrome.destroyCalls, 0);
      expect(t.services.session.isDirty, isTrue);
    });

    testWidgets('Save at the close prompt writes the file and closes', (
      tester,
    ) async {
      final t = await pump(tester, savePaths: [_target]);
      edit(t);
      await tester.pumpAndSettle();

      unawaited(t.chrome.requestClose());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(t.fs.state.files.containsKey(_target), isTrue);
      expect(t.chrome.destroyCalls, 1);
    });

    testWidgets('Don’t Save closes WITHOUT writing the file', (tester) async {
      final t = await pump(tester, savePaths: [_target]);
      edit(t);
      await tester.pumpAndSettle();

      unawaited(t.chrome.requestClose());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Don’t Save'));
      await tester.pumpAndSettle();

      expect(t.fs.state.files.containsKey(_target), isFalse);
      expect(t.chrome.destroyCalls, 1);
    });

    testWidgets('a FAILED save at the close prompt shows the error and '
        'keeps the window OPEN', (tester) async {
      // No C:\jobs on this disk, so the pre-flight refuses.
      final fs = FakeFileStore(initialDirectories: {kTestDataRoot, 'C:'});
      final t = await pump(tester, fs: fs, savePaths: [_target]);
      edit(t);
      await tester.pumpAndSettle();

      unawaited(t.chrome.requestClose());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(FileErrorDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // The single worst bug this layer can have would be closing anyway.
      expect(t.chrome.destroyCalls, 0);
      expect(t.services.session.isDirty, isTrue);
    });

    testWidgets('Ctrl+N on a dirty document runs the SAME prompt', (
      tester,
    ) async {
      final t = await pump(tester);
      edit(t);
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.keyN);

      // One implementation of "may I replace the current document",
      // called from four places, so the four cannot drift.
      expect(find.byType(UnsavedChangesDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(t.services.session.isDirty, isTrue);
    });
  });

  group('the startup recovery prompt, through the REAL dialog', () {
    testWidgets('appears on the first frame and recovers on Recover', (
      tester,
    ) async {
      final crashed = buildBlankDocument(
        now: DateTime.utc(2026),
        appVersion: '0.1.0',
        id: const Uuid('crashed'),
        rackId: const Uuid('crashed-rack'),
        catalog: const {},
      )..info = ProjectInfo(projectName: 'Smith Residence');
      final fs = FakeFileStore(
        initialDirectories: {
          kTestDataRoot,
          kTestJobsDir,
          r'C:\data\recovery',
          'C:',
        },
        initialFiles: {
          r'C:\data\recovery\crashed.rppj': const JsonDocumentCodec().write(
            crashed,
          ),
          r'C:\data\recovery\crashed.json': Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'appVersion': '0.1.0',
                'displayName': 'Smith Residence',
                'docId': 'crashed',
                'savedAt': '2026-07-26T14:32:11.000Z',
                'schemaVersion': kSchemaVersion,
                'sequence': 412,
                'unsavedEditCount': 12,
              }),
            ),
          ),
        },
      );

      final t = await pump(tester, fs: fs, runStartupRecovery: true);

      expect(find.byType(RecoveryPromptDialog), findsOneWidget);
      expect(
        find.text(
          'RackPal closed unexpectedly. '
          'Recover Smith Residence (12 unsaved changes)?',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Recover'));
      await tester.pumpAndSettle();

      expect(t.services.session.displayName, 'Smith Residence');
      // Recovered work is DIRTY until the user explicitly saves it.
      expect(find.text('*Smith Residence — RackPal'), findsOneWidget);
      expect(find.textContaining('Recovered from'), findsOneWidget);
    });
  });

  group('banners and empty states', () {
    testWidgets('a read-only document shows the banner and Ctrl+S becomes '
        'Save a copy', (tester) async {
      final t = await pump(
        tester,
        savePaths: [r'C:\jobs\Smith (copy).rppj'],
      );
      t.services.session.adopt(
        controller: t.services.session.controller,
        filePath: _target,
        openReadOnly: true,
        baseline: t.services.session.baseline,
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReadOnlyBanner), findsOneWidget);
      expect(find.text('*Smith (read-only) — RackPal'), findsNothing);
      expect(find.text('Smith (read-only) — RackPal'), findsOneWidget);

      await tester.tap(find.text('Save a copy…'));
      await tester.pumpAndSettle();

      expect(t.picker.suggestedNames.single, 'Smith (copy).rppj');
    });

    testWidgets('autosave failing MID-SESSION puts a warning on screen', (
      tester,
    ) async {
      // The warning used to be a `final String?` computed once during
      // `buildAppServices`. Persistence does not only fail at startup:
      // the volume fills, the portable stick's write-protect switch is
      // flipped, an admin revokes write access, the folder is deleted —
      // and the status bar showed nothing while autosave had been dead
      // for an hour.
      final readOnly = <String>{};
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        readOnlyPaths: readOnly,
      );
      final t = await pump(tester, fs: fs);
      expect(find.byType(ShellWarningBanner), findsNothing);

      // THE EDIT AND ITS FRAME COME FIRST, DELIBERATELY. If the document
      // changed in the same step as the failure, the session's own
      // notification would rebuild the shell and the banner would appear
      // whether or not anything listens to the warning — the listener
      // would be dead code that no test could tell was missing.
      edit(t);
      await tester.pumpAndSettle();
      expect(find.byType(ShellWarningBanner), findsNothing);

      // NOW the data root goes read-only. Nothing below touches the
      // document, so the ONLY thing that can bring the banner up is the
      // warning itself.
      final snapshot = testSnapshotPath(t.services.session.documentId);
      await fs.createDirectory(kTestRecoveryDir);
      await fs.writeBytes(snapshot, Uint8List.fromList([1]));
      readOnly.add(snapshot);

      await t.services.autosave.snapshot();
      await tester.pumpAndSettle();

      expect(find.byType(ShellWarningBanner), findsOneWidget);
      expect(find.textContaining('Autosave has stopped working'), findsOne);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byType(ShellWarningBanner), findsNothing);

      // A DISMISSAL COVERS ONE OCCURRENCE. The stick is unlocked, the
      // warning goes away — and when it is write-protected again the user
      // is told again, because the second time is the one that costs them
      // the work.
      readOnly.clear();
      t.clock.advance(const Duration(seconds: 30));
      expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);
      await tester.pumpAndSettle();
      expect(find.byType(ShellWarningBanner), findsNothing);

      readOnly.add(snapshot);
      t.clock.advance(const Duration(seconds: 30));
      edit(t);
      await t.services.autosave.snapshot();
      await tester.pumpAndSettle();

      expect(find.byType(ShellWarningBanner), findsOneWidget);
    });

    testWidgets('a document with NO racks shows an honest panel rather '
        'than crashing', (tester) async {
      final empty = RackDocument(
        id: const Uuid('rackless'),
        appVersion: '0.1.0',
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        meta: EntityMeta(
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          updatedBy: 'test',
        ),
      );
      await pump(tester, document: empty);

      // `RackCanvasScreen` reads `racks.values.first` while building its
      // state; a rack-less document is reachable the moment the app can
      // open a file.
      expect(find.byType(NoRacksView), findsOneWidget);
      expect(find.byType(RackCanvasScreen), findsNothing);
      expect(find.text('Untitled contains no racks.'), findsOneWidget);
    });

    testWidgets('…and the panel is no longer a dead end: New rack creates '
        'one and the elevation opens on it', (tester) async {
      final empty = RackDocument(
        id: const Uuid('rackless-createable'),
        appVersion: '0.1.0',
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        meta: EntityMeta(
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          updatedBy: 'test',
        ),
      );
      await pump(tester, document: empty);

      await tester.tap(find.text('New rack…'));
      await tester.pumpAndSettle();
      expect(find.byType(NewRackDialog), findsOneWidget);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // The document gained the rack…
      expect(empty.racks, hasLength(1));
      expect(empty.racks.values.single.heightU, 42);
      expect(empty.racks.values.single.designator, 'RK-1');
      // …and the shell swapped the honest panel for the real editor,
      // which is the whole point of the button.
      expect(find.byType(NoRacksView), findsNothing);
      expect(find.byType(RackCanvasScreen), findsOneWidget);
    });

    testWidgets('the status line reports a successful save', (tester) async {
      await pump(tester, savePaths: [_target]);
      await press(tester, LogicalKeyboardKey.keyS);

      expect(find.byType(ShellStatusLine), findsOneWidget);
      expect(find.text('Saved.'), findsOneWidget);
    });
  });

  group('the strip survives the shell move', () {
    testWidgets('it runs in job order (DR-091 §11.90.3)', (tester) async {
      // The group was `the three-tab strip` and this asserted `['Rack',
      // 'Schematic', 'Schedule']`. DR-091 §11.90 promoted three editors
      // that were already full-screen surfaces reached from a menu, and
      // ordered the six by the order the work is done rather than by the
      // order they were built.
      //
      // WHAT THE GROUP IS ACTUALLY FOR IS UNCHANGED: the strip survives
      // the shell move, and Ctrl+S below still resolves from the app root
      // rather than from whichever tab has focus.
      await pump(tester);
      final tabs = tester
          .widgetList<Tab>(find.byType(Tab))
          .map((t) => t.text)
          .toList();
      //
      // 6 -> 7 AT PLAN-E/5. `Plan` lands at position 6, between the
      // Schematic and the Schedule, which is §11.90.3's own table rather
      // than a fresh reading of it: "interconnect it, MARK WHERE IT
      // PHYSICALLY SITS, hand over the paperwork". DR-091 kept Plan out
      // of the strip "until it is built, rather than adding a seventh tab
      // onto nothing", and this is the chapter that earns it (DR-143).
      expect(tabs, [
        // SIX SINCE `#893` (DR-168): `Locations` and `Plan` merged into
        // `Site` at position 1, which §11.90.4 permitted by refusing to
        // freeze the view set before M6.
        'Site',
        'Device Manager',
        'Rack',
        'Structured Wiring',
        'Schematic',
        'Schedule',
      ]);
    });

    testWidgets('and Ctrl+S works from the Schedule tab, because the '
        'document is not a property of one tab', (tester) async {
      final t = await pump(tester, savePaths: [_target]);
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      // The Schedule is a real view now (M2-B) — which makes this test
      // STRONGER rather than weaker: the tab body holds focusable
      // controls, so a Ctrl+S that resolved from the focused context
      // rather than from the app root would have somewhere new to go
      // wrong.
      expect(find.byType(ScheduleScreen), findsOneWidget);

      await press(tester, LogicalKeyboardKey.keyS);

      expect(t.fs.state.files.containsKey(_target), isTrue);
    });
  });
}
