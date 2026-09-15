// Edit > Preferences, through the real shell (DR-172): a new undo depth
// reaches the open document at once, says so on the status line, and is
// remembered in prefs.json for the next session.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

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
      ..physicalSize = const Size(1600, 1400)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('Edit > Preferences changes the open document depth at once, '
      'says so, and remembers it', (tester) async {
    final built = await buildTestApp(measurer);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    final services = built.session.services;
    expect(services.session.controller.undo.maxEntries, kDefaultUndoDepth);

    // Edit ▸ Preferences...
    await tester.tap(find.widgetWithText(SubmenuButton, 'Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kPreferencesLabel));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('preferences.undoDepth')),
      '60',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Close'),
      ),
    );
    await tester.pumpAndSettle();

    expect(services.session.controller.undo.maxEntries, 60);
    expect(services.session.status, 'Undo history now keeps 60 steps.');
    expect(find.text('Undo history now keeps 60 steps.'), findsOneWidget);
    expect(services.prefsStore?.current.undoDepth, 60);
  });
}
