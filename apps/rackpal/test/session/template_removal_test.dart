// `#871`, DR-158 §11.157 — removing a device template from the project,
// through the real mounting.
//
// =====================================================================
// WHY THESE ARE HERE AND NOT IN `rackpal_ui`
// =====================================================================
// The browser reports WHICH template a person pressed the control on and
// nothing else. Everything past that is the shell's: it owns the
// `DocumentController`, it builds the plan, it puts the question, and it
// runs the transaction. `rackpal_ui` can assert the button fires a
// callback, which `device_browser_screen_test.dart` does; only here can
// anything assert that pressing it removes a template.
//
// That distinction is the whole of `#870` and `#872`: a control wired to
// a callback nobody connected renders, tests green, and does nothing.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'session_fakes.dart';

/// The demo document's own authored templates. `ups` carries one device,
/// which makes it the smallest case that cascades.
const _ups = TemplateId('ups');

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

  Finder removeFor(String id) =>
      find.byKey(ValueKey(DeviceBrowserScreen.removeKeyFor(id)));

  /// Presses the remove control, and then lets the GESTURE ARENA settle.
  ///
  /// **A BARE `pumpAndSettle` IS NOT ENOUGH AND THE REASON IS NOT
  /// OBVIOUS.** The browser card's `InkWell` carries `onDoubleTap`, which
  /// the shell always supplies, so a `DoubleTapGestureRecognizer` is in
  /// the arena and holds it open for its own timeout; the inner tap
  /// cannot win until that expires. `pumpAndSettle` returns as soon as no
  /// frame is scheduled, which is immediately, so the press never lands
  /// and the whole thing reads exactly like a button wired to nothing.
  /// That is `#872`'s shape arriving as a false positive, from the other
  /// side.
  Future<void> press(WidgetTester tester, Finder button) async {
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  /// Opens the app on the demo document, lands on the browser and
  /// narrows it to [query].
  ///
  /// **THE SEARCH IS NOT CEREMONY.** The browser lists the 48 seeded
  /// archetypes plus the demo document's four, in a lazily built grid, so
  /// a row late in the alphabet is not in the widget tree at all until
  /// something brings it on screen. Narrowing first is also what a person
  /// does: nobody scrolls fifty cards to find the one they just made.
  Future<TestSession> openDeviceManager(
    WidgetTester tester, {
    String query = 'Rack UPS',
  }) async {
    final built = await buildTestApp(measurer);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Device Manager'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pumpAndSettle();
    return built.session;
  }

  testWidgets('the control is THERE, on an authored row and not a seeded '
      'one', (tester) async {
    await openDeviceManager(tester);

    expect(
      removeFor('ups'),
      findsOneWidget,
      reason: 'the demo document authored it, so it is a `This project` row',
    );
  });

  testWidgets('and it is NOT there on a seeded row — §11.157.3', (
    tester,
  ) async {
    final seeded = kSeedCatalogIds.first;
    await openDeviceManager(tester, query: seeded);

    expect(
      find.byType(DeviceBrowserScreen),
      findsOneWidget,
      reason:
          'the control renders, so findsNothing below means the row '
          'refused it rather than that nothing was on screen',
    );
    expect(
      removeFor(seeded),
      findsNothing,
      reason:
          'the seeded 48 are what the build ships, and a per-project '
          'hole in them is a difference carried in the file forever',
    );
  });

  testWidgets('it ASKS first, and writes nothing until it is answered', (
    tester,
  ) async {
    final session = await openDeviceManager(tester);
    final doc = session.services.controller.session.document;
    final templatesBefore = doc.templates.length;
    final devicesBefore = doc.devices.length;

    await press(tester, removeFor('ups'));

    expect(find.byType(RemoveTemplateDialog), findsOneWidget);
    expect(
      find.text('This also deletes the 1 device placed from it.'),
      findsOneWidget,
    );
    expect(doc.templates, hasLength(templatesBefore));
    expect(doc.devices, hasLength(devicesBefore));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(doc.templates, hasLength(templatesBefore));
    expect(doc.devices, hasLength(devicesBefore));
  });

  testWidgets('confirming removes the template AND the device standing on '
      'it', (tester) async {
    final session = await openDeviceManager(tester);
    final doc = session.services.controller.session.document;

    await press(tester, removeFor('ups'));
    await tester.tap(find.byKey(RemoveTemplateDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(doc.templates.containsKey('ups@1'), isFalse);
    expect(
      doc.devices.values.where((d) => d.templateRef.templateId == _ups),
      isEmpty,
      reason:
          'a device whose snapshot is gone has no body to draw, which '
          'is what CR-054 forbids',
    );
    // The controls the removal did not touch.
    expect(doc.templates.containsKey('amp@1'), isTrue);
    expect(
      doc.devices.values.any((d) => d.templateRef.templateId.v == 'amp'),
      isTrue,
    );
  });

  testWidgets('the row is GONE from the browser afterwards', (tester) async {
    await openDeviceManager(tester);

    await press(tester, removeFor('ups'));
    await tester.tap(find.byKey(RemoveTemplateDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Rack UPS 1500VA'),
      findsNothing,
      reason:
          'the browser lists what the document can place, so a '
          'removed template leaves no row behind',
    );

    // And the control: widen the search and the amplifier is still there.
    await tester.enterText(find.byType(TextField).first, 'amplifier');
    await tester.pumpAndSettle();
    expect(find.text('16-channel amplifier'), findsOneWidget);
  });

  // UNDO IS PRESSED ON THE RACK TAB, AND THAT IS A DEFECT THIS CASE
  // DOCUMENTS RATHER THAN ACCEPTS (`#874`). `UndoIntent` has exactly one
  // handler in the whole tree, inside `RackCanvasScreen`'s own
  // `Shortcuts`, and the application has one menu, `File`, with no Undo
  // item. So `Ctrl+Z` on the Device Manager reaches nothing, and this
  // dialog's own "Undo puts everything back" is true of the stack and
  // unreachable from where the person is standing. Walking to the Rack
  // tab is what a person would have to do today.
  testWidgets('and Ctrl+Z puts the template AND the device back, as ONE '
      'entry', (tester) async {
    final session = await openDeviceManager(tester);
    final doc = session.services.controller.session.document;
    final templatesBefore = doc.templates.keys.toSet();
    final devicesBefore = doc.devices.keys.toSet();

    await press(tester, removeFor('ups'));
    await tester.tap(find.byKey(RemoveTemplateDialog.confirmKey));
    await tester.pumpAndSettle();
    expect(doc.templates.keys.toSet(), isNot(templatesBefore));

    await tester.tap(find.text('Rack'));
    await tester.pumpAndSettle();
    // AND THE CANVAS HAS TO BE FOCUSED. The binding is gated on the rack
    // canvas's own focus, so arriving on the tab is not enough: the
    // browser's search field still holds focus inside the `IndexedStack`.
    // A person clicks the rack before they reach for Ctrl+Z; a test has
    // to as well.
    await tester.tap(find.byType(RackCanvasScreen));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(
      doc.templates.keys.toSet(),
      templatesBefore,
      reason:
          'a per-project snapshot is project data, so removing one is '
          'a document edit and IS undoable (DR-158 §11.157.1)',
    );
    expect(doc.devices.keys.toSet(), devicesBefore);
  });
}
