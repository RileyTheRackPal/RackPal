// `File ▸ Sheet set…`, in the shell (`#969`, DR-209 §11.208).
//
// `sheet_set_dialog_test.dart` proves the dialog emits the right command to
// whatever `onEdit` it was handed. This proves the route a person takes:
// the menu item exists, opens the dialog over the SESSION's document, and
// the edit lands on the document's undo stack under its own name.
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

  testWidgets('File ▸ Sheet set… edits the legend, and Edit undoes it', (
    tester,
  ) async {
    final built = await buildTestApp(measurer);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    final doc = built.session.services.session.document;
    expect(doc.info.legendAbbreviations, isNull, reason: 'precondition');

    await tester.tap(find.widgetWithText(SubmenuButton, 'File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kSheetSetLabel));
    await tester.pumpAndSettle();
    expect(find.byKey(kSheetSetListKey), findsOneWidget);

    await tester.enterText(find.byKey(meaningFieldKey(0)), 'rack unit');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(
      doc.info.legendAbbreviations?.first,
      const LegendAbbreviation('RU', 'rack unit'),
      reason: 'the dialog edits the session document, not a copy',
    );

    await tester.tap(find.widgetWithText(SubmenuButton, 'Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo Edit legend notes'));
    await tester.pumpAndSettle();
    expect(doc.info.legendAbbreviations, isNull, reason: 'back to the seed');
  });
}
