// `Help ▸ Open diagnostics folder…` (DR-194, `#941`), driven through the
// REAL menu bar of the real app, because a menu item proved by calling its
// handler has never been proved reachable (`copy-outlives-the-route-it-
// names`, in the KB).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal/src/session/app_shell.dart';
import 'package:rackpal/src/storage/data_root.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';

import 'session_fakes.dart';

void main() {
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('Jost'): bytes,
    });
  });

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

  Future<List<String>> openHelpAndChoose(
    WidgetTester tester, {
    bool shown = true,
    DataRoot? dataRoot,
  }) async {
    final asked = <String>[];
    final built = await buildTestApp(
      measurer,
      dataRoot: dataRoot,
      folderRevealer: (folder) async {
        asked.add(folder);
        return shown;
      },
    );
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kOpenDiagnosticsLabel));
    await tester.pumpAndSettle();
    return asked;
  }

  testWidgets('it opens the folder the log is written to', (tester) async {
    final asked = await openHelpAndChoose(tester);

    expect(
      asked,
      [r'C:\data\diagnostics'],
      reason:
          'the same join main.dart makes when it opens the log, so the '
          'menu shows the folder the log is actually in',
    );
  });

  testWidgets('a folder the OS would not show is SAID, with its path', (
    tester,
  ) async {
    await openHelpAndChoose(tester, shown: false);

    expect(
      find.text(diagnosticsNotShownNotice(r'C:\data\diagnostics')),
      findsOneWidget,
    );
  });

  testWidgets('with no data root there is no log, and the item is disabled '
      'rather than hidden', (tester) async {
    final asked = await openHelpAndChoose(
      tester,
      dataRoot: const DataRootUnusable(
        attemptedPath: r'E:\RackPal',
        portable: true,
        cause: 'read-only',
      ),
    );

    expect(asked, isEmpty);
    expect(
      tester
          .widget<MenuItemButton>(
            find.widgetWithText(MenuItemButton, kOpenDiagnosticsLabel),
          )
          .onPressed,
      isNull,
    );
  });
}
