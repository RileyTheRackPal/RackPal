// M4-S, DR-077 §11.76.1, board `#737`. The task the exit criterion rests
// on: a template authored in this project is IN THE PALETTE and can be
// placed, without reopening anything.
//
// EVERY CASE HERE DRIVES A COMMAND THROUGH A LIVE CONTROLLER rather than
// handing the screen a prepared document. The defect being closed was a
// surface holding a `late final` copy of a constant, and a test that
// builds its document first and pumps once cannot tell that apart from a
// surface that reads the document afresh. The save has to happen while
// the screen is already on screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'rack_with_palette.dart';

final DateTime _when = DateTime.utc(2026, 8, 19, 10);

final class _FakeMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

TemplateBody _authoredBody({
  String name = 'Custom Matrix 24x24',
  int frontU = 3,
  String category = kCatVideo,
  MountMethod mount = MountMethod.rackEars,
}) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: name,
  category: category,
  typePrefix: 'MTX',
  frontU: frontU,
  side: frontU > 0 ? OccupancySide.front : OccupancySide.none,
  mountMethod: mount,
);

/// An EMPTY 42U rack with the seed catalog embedded, exactly as
/// `blank_document.dart` builds one.
///
/// Not `buildDemoRackDocument`: its four hand-built devices occupy the U
/// the insertion caret opens on, so a placement here would be refused for
/// a real and correct reason ("Occupied by AMP-1 (U4-U5)") that has
/// nothing to do with what these cases are about. The first draft of this
/// file asserted a device count against that rack and read the refusal as
/// a missing feature.
RackDocument _blank() {
  final meta = EntityMeta(
    createdAt: _when,
    updatedAt: _when,
    updatedBy: 'test',
  );
  final doc = RackDocument(
    id: const Uuid('doc-737'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: meta,
  );
  doc.racks[const Uuid('rk-1')] = Rack(
    id: const Uuid('rk-1'),
    name: 'Rack 1',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: meta,
  );
  for (final entry in buildSeedCatalog().entries) {
    doc.templates['${entry.key}@1'] = TemplateSnapshot(
      templateId: TemplateId(entry.key),
      version: 1,
      contentHash: 'sha256:seed-${entry.key}',
      capturedAt: _when,
      body: entry.value,
    );
  }
  return doc;
}

/// The command the Device Builder's `Save` runs, nothing more.
void _save(
  DocumentController c,
  TemplateBody body, {
  String id = 'tpl.custom_matrix_24x24',
}) {
  final templateId = TemplateId(id);
  final version = nextTemplateVersion(c.doc, templateId);
  c.run(
    SaveTemplateToProjectCommand(
      templateId: templateId,
      version: version,
      contentHash: 'unhashed:$id@$version',
      body: body,
      capturedAt: _when,
    ),
  );
}

void main() {
  // A window big enough that the palette, the canvas and the inspector
  // all lay out: several assertions below are about a row being on
  // screen, and an overflowing test window makes that a lie.
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

  Future<DocumentController> pump(WidgetTester tester) async {
    final controller = DocumentController(_blank(), clock: FixedClock(_when));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RackWithPalette(
            controller: controller,
            canvas: (key, searchFocus, dragRow) => RackCanvasScreen(
              key: key,
              measurer: _FakeMeasurer(),
              controller: controller,
              clock: FixedClock(_when),
              paletteSearchFocus: searchFocus,
              paletteDragRow: dragRow,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('a template saved while the canvas is open appears in the '
      'palette with no reopen', (tester) async {
    final controller = await pump(tester);
    // A seeded document has nothing authored in it, so the pinned group
    // is absent rather than empty.
    expect(find.text(kProjectGroupTitle), findsNothing);
    expect(find.widgetWithText(ListTile, 'Custom Matrix 24x24'), findsNothing);

    _save(controller, _authoredBody());
    await tester.pumpAndSettle();

    expect(find.text(kProjectGroupTitle), findsOneWidget);
    expect(
      find.widgetWithText(ListTile, 'Custom Matrix 24x24'),
      findsWidgets,
    );
  });

  testWidgets('placing it lands a real device in the rack', (tester) async {
    final controller = await pump(tester);
    _save(controller, _authoredBody());
    await tester.pumpAndSettle();

    final before = controller.doc.devices.length;
    // The keyboard route docs/04 §3.2 specifies: `/`, type, Enter. The
    // `/` press is load-bearing, because it is what puts focus back in
    // the field and therefore what makes `receiveAction` reach a live
    // text client (see `keyboard_only_placement_test.dart`).
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Custom Matrix 24x24');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(controller.doc.devices.length, before + 1);
    final placed = controller.doc.devices.values.last;
    expect(
      placed.templateRef.templateId,
      const TemplateId('tpl.custom_matrix_24x24'),
    );
    expect(placed.templateRef.version, 1);
    expect(placed.placement, isA<RailPlacement>());
  });

  testWidgets('a second save re-lists it at the newer version', (tester) async {
    final controller = await pump(tester);
    _save(controller, _authoredBody());
    await tester.pumpAndSettle();
    _save(controller, _authoredBody(name: 'Custom Matrix 24x24 rev B'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ListTile, 'Custom Matrix 24x24 rev B'),
      findsWidgets,
    );
    expect(find.widgetWithText(ListTile, 'Custom Matrix 24x24'), findsNothing);
  });

  testWidgets('undoing the save takes the row away again', (tester) async {
    final controller = await pump(tester);
    _save(controller, _authoredBody());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Custom Matrix 24x24'), findsWidgets);

    controller.undoLast();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Custom Matrix 24x24'), findsNothing);
  });

  testWidgets('an authored template with no category is still reachable', (
    tester,
  ) async {
    final controller = await pump(tester);
    _save(
      controller,
      _authoredBody(name: 'Unfiled Device', category: ''),
      id: 'tpl.unfiled_device',
    );
    await tester.pumpAndSettle();

    // It is in the pinned group, which is on screen without scrolling —
    // so an uncategorised template is findable even before anybody
    // reaches the trailing group at the bottom of the list.
    expect(
      find.widgetWithText(ListTile, 'Unfiled Device'),
      findsWidgets,
    );
  });

  testWidgets('an authored rack-mountable row arms a drag, as a seeded one '
      'does', (tester) async {
    final controller = await pump(tester);
    _save(controller, _authoredBody());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Custom Matrix 24x24');
    await tester.pumpAndSettle();
    final row = find.widgetWithText(ListTile, 'Custom Matrix 24x24');
    expect(row, findsOneWidget);

    // Past the 4px lift threshold: the row dims, which is the screen
    // saying it accepted the arm (docs/04 §3.1 step 2).
    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();

    final dimmed = tester
        .widgetList<Opacity>(
          find.ancestor(of: row, matching: find.byType(Opacity)),
        )
        .where((o) => o.opacity == 0.40);
    expect(dimmed, isNotEmpty, reason: 'the authored row never lifted');

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
