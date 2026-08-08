// M3-C/2, #148 — `Project ▸ Structure…` reaches the editor, and what is
// typed into it lands in the real document.
//
// WHY THIS FILE EXISTS SEPARATELY FROM THE WIDGET TESTS. Those drive
// `StructureEditorScreen` against a harness that stands in for the app.
// This drives the APP: the real menu, the real `DocumentController`, the
// real clock and actor, and the real undo stack. A perfect wiring nothing
// opens is the shape M2-F found on `doc.ports` and M3-A/1 found on
// `StructureBody` — a mechanism no gesture reaches — and it is the shape
// this project has produced twice.
//
// IT ALSO PINS WHAT LEFT. `Add drops…` and `Add outlet…` were on the
// Project menu only until this editor existed; both said so in their own
// doc comments. A test that only checked the new item would let one of
// them quietly survive as a second route to the same surface.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackmate/src/session/blank_document.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'session_fakes.dart';

final _when = DateTime.utc(2026, 8, 8);

/// A REAL BLANK PROJECT, not `buildDemoRackDocument`. The demo document
/// leaves `registries` at its empty default, so `Cat6` resolves to no
/// media type and every quick-add line is refused: the editor would be
/// reachable and useless, and a test driving it would prove the wrong
/// thing. `buildBlankDocument` is what `File ▸ New` produces, seeded the
/// DR-010 way.
RackDocument _project({List<(String, String)> rooms = const []}) {
  final doc = buildBlankDocument(now: _when, appVersion: '0.1.0');
  for (final (name, code) in rooms) {
    AddLocationCommand(
      name: name,
      code: code,
      order: nextLocationOrder(doc),
      now: _when,
      actor: 'test',
    ).apply(doc);
  }
  return doc;
}

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

  /// The editor's quick-add field, and not the palette's search box one
  /// tab behind it.
  final quickAdd = find.descendant(
    of: find.byType(StructureEditorScreen),
    matching: find.byType(TextField),
  );

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Structure…'));
    await tester.pumpAndSettle();
  }

  testWidgets('Project ▸ Structure… opens the editor (AC-048)', (
    tester,
  ) async {
    final built = await buildTestApp(measurer, document: _project());
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    await openEditor(tester);
    expect(find.byType(StructureEditorScreen), findsOneWidget);
    // AC-048: it OPENS IN TABLE MODE. The columns are the proof, and
    // they are there before a single drop exists.
    for (final id in kStructureDefaultColumns) {
      expect(find.text(structureColumnHeader(id)), findsOneWidget);
    }
  });

  testWidgets('the two temporary items it replaces are gone', (tester) async {
    final built = await buildTestApp(measurer, document: _project());
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    expect(find.text('Locations…'), findsOneWidget);
    expect(find.text('Structure…'), findsOneWidget);
    expect(find.text('Add drops…'), findsNothing);
    expect(find.text('Add outlet…'), findsNothing);
  });

  testWidgets('a line typed there lands in the real document', (tester) async {
    // THE WHOLE ROUND TRIP: menu, quick-add bar, real controller. It also
    // pins that the app's actor reaches `EntityMeta`, which is the defect
    // `DropEntryActions.onCommit` exists to prevent — the preview plans
    // with `actor: 'preview'` and those values must never be the ones
    // that land.
    final built = await buildTestApp(
      measurer,
      document: _project(rooms: [('Living Room', 'LR')]),
    );
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    final doc = built.session.services.session.document;

    await openEditor(tester);
    expect(doc.structures, isEmpty, reason: 'a new project has no body');

    // SCOPED TO THE EDITOR. The rack tab's palette search is a
    // `TextField` too, and it is still in the tree behind this dialog.
    await tester.enterText(quickAdd, 'Living Room: 2x Cat6, 1x RG6');
    await tester.pumpAndSettle();

    // TWO PRESSES OF ONE KEY, AND THAT IS THE DESIGN. A blank project has
    // no Structure device, so the first `Enter` takes the panel's offer
    // and creates one; the line is kept, not cleared, so the second
    // `Enter` commits it. `Enter` is the only commit and a refusal never
    // costs the typing, which is `drop_entry_panel.dart`'s whole loop.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(doc.structures, hasLength(1));
    expect(buildStructureTable(doc).dropCount, 0);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(buildStructureTable(doc).dropCount, 3);
    expect(
      doc.links.values.map((l) => l.meta.updatedBy),
      isNot(contains('preview')),
    );
  });

  testWidgets('and the table it is typed into shows the rows', (tester) async {
    final built = await buildTestApp(
      measurer,
      document: _project(rooms: [('Kitchen', 'KIT')]),
    );
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    await openEditor(tester);
    expect(find.text(kNoDropsHeadline), findsOneWidget);

    await tester.enterText(quickAdd, 'Kitchen: 2x Cat6');
    await tester.pumpAndSettle();
    // The first press creates the Structure body, the second commits.
    // See the previous test.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // The band, and the empty state gone: the editor rebuilt on the live
    // document rather than on the one it opened with.
    expect(find.text('KITCHEN (KIT)'), findsOneWidget);
    expect(find.text(kNoDropsHeadline), findsNothing);
  });

  testWidgets('Add outlet opens the template picker over it (DR-024)', (
    tester,
  ) async {
    final built = await buildTestApp(measurer, document: _project());
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    await openEditor(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Add outlet'));
    await tester.pumpAndSettle();

    expect(find.byType(OutletTemplatePicker), findsOneWidget);
    // The nine seeded templates are what it offers (CR-108, M3-C/4).
    expect(find.text('TV location'), findsOneWidget);
  });
}
