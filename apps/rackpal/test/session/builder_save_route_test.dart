// What the Device Builder's `Save` writes, driven through the REAL shell
// (`#950`, DR-202, DR-077 §11.76.3).
//
// =====================================================================
// WHY THIS FILE EXISTS WHEN `device_builder_actions_test.dart` DOES
// =====================================================================
// That file calls ONE `DeviceBuilderActions` twice, and it passed from
// `#778` (2026-08-26, the builder became a view) to `#950` while the
// product minted `tpl.foo_2` on every second Save. The shell called
// `buildDeviceBuilderActions` inside `build`, so every
// rebuild made a fresh closure whose remembered id was null again, and a
// save IS a rebuild. The test held the closure still; the app never did.
// This one presses the button the user pressed.

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

  Finder field(String label) => find.widgetWithText(TextField, label);

  /// Opens a new template and fills AC-049's three.
  Future<TestSession> authorOne(WidgetTester tester) async {
    final built = await buildTestApp(measurer);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Device Manager'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kBrowserNewTemplateLabel));
    await tester.pumpAndSettle();
    await tester.enterText(field('Display name *'), 'Zone Amp 8');
    await tester.enterText(field('Designator prefix *'), 'AMP');
    await tester.enterText(field('RU height (front) *'), '2');
    await tester.pumpAndSettle();
    return built.session;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  RackDocument docOf(TestSession session) =>
      session.services.controller.session.document;

  Iterable<String> authoredKeys(TestSession session) => docOf(
    session,
  ).templates.keys.where((k) => k.startsWith('tpl.zone_amp_8'));

  testWidgets('A SECOND SAVE ON A NEW TEMPLATE WRITES THE SAME TEMPLATE, not '
      'a second one beside it', (tester) async {
    final session = await authorOne(tester);
    await save(tester);
    await tester.enterText(field('RU height (front) *'), '3');
    await tester.pumpAndSettle();
    await save(tester);

    expect(
      authoredKeys(session),
      ['tpl.zone_amp_8@1'],
      reason:
          'the shell rebuilt the save closure and it forgot the id it '
          'minted, so the second Save authored tpl.zone_amp_8_2',
    );
    // DR-202 §11.201.1: nothing is placed from @1, so the save replaced
    // it rather than forking a body nobody resolves.
    expect(docOf(session).templates['tpl.zone_amp_8@1']!.body.frontU, 3);
  });

  testWidgets('A NEW TEMPLATE NEVER SHOWS A CHANGE CLASS, because no device '
      'can be affected by it', (tester) async {
    await authorOne(tester);
    // Blank to a 2U device is `frontU` changed, which the classifier calls
    // breaking. Breaking to whom: nothing is placed from a template that
    // does not exist yet.
    expect(find.text('Breaking'), findsNothing);
    expect(find.textContaining('placed'), findsNothing);
    await save(tester);
    await tester.enterText(field('RU height (front) *'), '3');
    await tester.pumpAndSettle();
    expect(find.textContaining('Breaking'), findsNothing);
  });
}
