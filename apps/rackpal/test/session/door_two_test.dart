// Door 2 of CR-054, in the shell — `#231`, DR-099 §11.98.
//
// =====================================================================
// WHY THESE ARE HERE AND NOT IN `rackpal_ui`
// =====================================================================
// Door 2's whole substance is routing: it takes the user to the Device
// Manager with a template loaded, and it REFUSES when that one draft has
// unsaved work. Both halves are the shell's, which owns the six-view stack
// and the single builder. `rackpal_ui` can only assert that the canvas
// hands a template id to a callback, which it does.
//
// =====================================================================
// THE GUARD IS ABOUT SOMETHING THAT CANNOT BE UNDONE
// =====================================================================
// `TemplateEditSession` is `late final` inside the builder's State, so
// handing that screen a different template is IGNORED. Loading one means a
// new `key`, which destroys the State and the draft with it. There is
// nothing for `Ctrl+Z` to reach and nothing on disk to reopen, so DR-099
// §11.98.4 refuses rather than prompting: a discard dialog is the shape
// people dismiss by reflex.
//
// The user is still TAKEN to the Device Manager, because "finish it first"
// is useless without showing them what "it" is.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal/src/session/app_shell.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../rack_scene_to_screen.dart';
import 'session_fakes.dart';

void main() {
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('Jost'): bytes,
    });
  });

  // The supported window: docs/04 §1 treats anything under 1080px as the
  // unbuilt tablet-collapse case.
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

  /// Opens the app on the demo document and lands on the Device Manager.
  /// Opens the Device Manager tab, which since `#243` is the BROWSER.
  Future<void> openDeviceManager(WidgetTester tester) async {
    await tester.pumpWidget((await buildTestApp(measurer)).app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Device Manager'));
    await tester.pumpAndSettle();
  }

  /// Opens the tab and then starts a new template.
  ///
  /// **THE SECOND TAP IS `#243` AND NOT CEREMONY.** The tab used to BE
  /// the blank builder; DR-104 §11.103.2 made it the browser and moved
  /// the new-template entry point onto the browser's own button, which
  /// is load-bearing because no menu route to authoring one exists.
  Future<void> openNewTemplate(WidgetTester tester) async {
    await openDeviceManager(tester);
    await tester.tap(find.text(kBrowserNewTemplateLabel));
    await tester.pumpAndSettle();
  }

  testWidgets('the Device Manager opens on the BROWSER since `#243`', (
    tester,
  ) async {
    // It opened on a blank builder until DR-104 §11.103.2: a *manager*
    // that showed one editor and no list. The blank draft did not go
    // away, it moved behind the browser's own New button.
    await openDeviceManager(tester);
    expect(find.byType(DeviceBrowserScreen), findsOneWidget);
    expect(find.byType(DeviceBuilderScreen), findsNothing);
  });

  testWidgets('New device template… still gives a BLANK draft', (
    tester,
  ) async {
    await openNewTemplate(tester);

    final screen = tester.widget<DeviceBuilderScreen>(
      find.byType(DeviceBuilderScreen),
    );
    expect(screen.template.displayName, isEmpty);
    // DR-056: `Generic` is the trade's word for unspecified and is
    // pre-filled; `model` is not.
    expect(screen.template.manufacturer, 'Generic');
    expect(screen.template.model, isEmpty);
  });

  testWidgets('a CLEAN draft is not a reason to refuse anything', (
    tester,
  ) async {
    // The regression this guards: the builder reports its dirty state on
    // open, and a shell that assumed "dirty until told otherwise" would
    // refuse door 2 on a freshly launched app.
    await openNewTemplate(tester);

    final screen = tester.widget<DeviceBuilderScreen>(
      find.byType(DeviceBuilderScreen),
    );
    expect(
      screen.onDirtyChanged,
      isNotNull,
      reason: 'the shell cannot ask the session, so the builder must push',
    );
    expect(find.text('Unsaved'), findsNothing);
  });

  testWidgets('EDITING THE DRAFT MARKS IT UNSAVED, which is what door 2 '
      'reads before it swaps the key', (tester) async {
    await openNewTemplate(tester);

    // The display-name field is the first thing the metadata form offers
    // and typing in it is the smallest real edit.
    final name = find.byType(TextField).first;
    await tester.enterText(name, 'Something');
    await tester.pumpAndSettle();

    expect(
      find.text('Unsaved'),
      findsOneWidget,
      reason: 'the session is dirty and the builder says so',
    );
  });

  testWidgets('THE VIEW STRIP ORDER IS READ, NOT ASSUMED', (tester) async {
    // Door 2 switches to `ShellView.deviceManager.index`. If a view were
    // ever inserted before it, a hardcoded `1` would send the user to
    // Locations and nothing would fail. This is that assumption, asserted.
    await tester.pumpWidget((await buildTestApp(measurer)).app);
    await tester.pumpAndSettle();

    final tabs = tester
        .widgetList<Tab>(find.byType(Tab))
        .map((t) => t.text)
        .toList();
    expect(
      tabs[ShellView.deviceManager.index],
      'Device Manager',
      reason: "door 2's destination is derived from this ordinal",
    );
  });

  group('THE WHOLE DOOR, from the rack canvas to the Device Manager', () {
    /// Right-clicks the device occupying [ru] on the Rack tab.
    Future<void> rightClickDevice(WidgetTester tester, int ru) async {
      await tester.tap(find.text('Rack'));
      await tester.pumpAndSettle();
      // The demo rack is 12U; `RackGeometry` puts U1 at the bottom.
      const geo = RackGeometry(12);
      final y = geo.rackHeight - (ru - 0.5) * RackGeometry.unitsPerRu;
      final spot = sceneToScreen(tester, geo.rackWidth / 2, y);
      final g = await tester.startGesture(spot, buttons: kSecondaryButton);
      await g.up();
      await tester.pumpAndSettle();
    }

    testWidgets('OPENS THE DEVICE MANAGER ON THAT TEMPLATE, which is the '
        'whole of door 2', (tester) async {
      final built = await buildTestApp(measurer);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();

      await rightClickDevice(tester, 4);
      expect(
        find.text('Edit the template…'),
        findsOneWidget,
        reason: 'the three doors did not open on the shell-hosted canvas',
      );
      await tester.tap(find.text('Edit the template…'));
      await tester.pumpAndSettle();

      final screen = tester.widget<DeviceBuilderScreen>(
        find.byType(DeviceBuilderScreen),
      );
      expect(
        screen.template.displayName,
        isNotEmpty,
        reason: 'the builder opened on the blank draft, not the template',
      );
      // WHICH template, not merely "a" template. Read off the SESSION
      // rather than the widget tree: the Rack tab's inspector is gone by
      // now, because `TabBarView` builds its pages lazily and we have
      // navigated away from it.
      final amp = built
          .session
          .services
          .controller
          .session
          .document
          .devices
          .values
          .singleWhere(
            (d) => d.designator == 'AMP-1',
          );
      final expected = resolveLatestTemplate(
        built.session.services.controller.session.document,
        amp.templateRef.templateId.v,
      )!;
      expect(screen.template.displayName, expected.body.displayName);
    });

    testWidgets('A DIRTY DRAFT REFUSES, keeps the draft, and still takes '
        'the user there (DR-099 §11.98.4)', (tester) async {
      await tester.pumpWidget((await buildTestApp(measurer)).app);
      await tester.pumpAndSettle();

      // Dirty the one draft. THE `New device template…` TAP IS LOAD-
      // BEARING SINCE `#243`: the tab is the browser now, and its first
      // `TextField` is the SEARCH BOX, so typing straight after the tab
      // tap would have filtered a list and dirtied nothing, leaving this
      // case asserting a refusal that could never fire.
      await tester.tap(find.text('Device Manager'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kBrowserNewTemplateLabel));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Half finished');
      await tester.pumpAndSettle();
      expect(find.text('Unsaved'), findsOneWidget);

      await rightClickDevice(tester, 4);
      await tester.tap(find.text('Edit the template…'));
      await tester.pumpAndSettle();

      expect(
        find.text('Finish or discard this template first.'),
        findsOneWidget,
        reason: 'no discard prompt: a dropped draft has no recovery path',
      );
      final screen = tester.widget<DeviceBuilderScreen>(
        find.byType(DeviceBuilderScreen),
      );
      expect(
        screen.template.displayName,
        isEmpty,
        reason:
            'the refusal must not have loaded the template anyway; an '
            'empty display name is the blank draft still standing',
      );
      expect(
        find.text('Unsaved'),
        findsOneWidget,
        reason:
            'THE DRAFT SURVIVES. This is the entire point of the guard: '
            'the session is an in-memory deep copy and a swapped key '
            'destroys it with nothing to undo and nothing on disk',
      );
    });
  });
}
