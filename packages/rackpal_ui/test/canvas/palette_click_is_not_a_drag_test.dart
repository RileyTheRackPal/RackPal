// A CLICK ON A PALETTE ROW IS NOT A RELEASED DRAG (`#242`, docs/04 §3.1
// step 1).
//
// ═══════════════════════════════════════════════════════════════════════
// THE DEFECT, WHICH NOTHING ASSERTED IN EITHER DIRECTION
// ═══════════════════════════════════════════════════════════════════════
// Every pointer-down on a palette row ARMS a drag: no `PointerDeviceKind`
// branch, no gesture-outcome branch (AC-016 #23). The pointer-up then
// reaches `_commitOrNoopPaletteDrag`, which found `phase != dragging` and
// announced *"Released outside the rack — HDMI Matrix 4x4 was not placed.
// The Staging Bin is not in this build."*
//
// For a gesture the user never made. A single click on a row is docs/04
// §3.1 step 1's *"a click still means 'show details'"*, and
// `DragPreviewPhase.armed`'s own comment says it "might still just be a
// click/double-click". The second half of every DOUBLE-click reached it
// too, landing AFTER the placement and overwriting *"Placed MTX-1 at
// RK-1 U1, front."*
//
// Found while building `#242`'s copy announcement (DR-103 §11.102.4),
// which it was eating. A grep for the message found no test anywhere in
// the repository asserting it, in either direction, which is how a
// refusal for a gesture nobody made survived a milestone.
//
// ═══════════════════════════════════════════════════════════════════════
// AND THE MESSAGE ITSELF IS NOT WRONG, SO IT IS KEPT
// ═══════════════════════════════════════════════════════════════════════
// "Never silently do nothing" is about a REFUSED ACTION, and a real drag
// released outside the rack IS one: the user lifted a device, carried it
// somewhere, and let go, and the Staging Bin that should have caught it
// does not exist yet. The third case below holds that half.
import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'rack_with_palette.dart';

final DateTime _when = DateTime.utc(2026, 8, 30, 11);

const String _released = 'Released outside the rack';

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

RackDocument _blank() {
  final meta = EntityMeta(
    createdAt: _when,
    updatedAt: _when,
    updatedBy: 'test',
  );
  final doc = RackDocument(
    id: const Uuid('doc-click'),
    appVersion: '0.4.0',
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

void main() {
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

  /// The text on screen at THIS frame. The status line auto-clears after
  /// three seconds and `pumpAndSettle` runs time forward past that, so a
  /// status assertion has to read the frame rather than settle first.
  List<String> onScreen(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .toList();

  testWidgets('a single click on a palette row says NOTHING', (tester) async {
    final controller = await pump(tester);
    final before = controller.doc.devices.length;

    await tester.tap(find.widgetWithText(ListTile, 'HDMI Matrix 4x4'));
    await tester.pump();

    expect(
      onScreen(tester).where((t) => t.contains(_released)),
      isEmpty,
      reason: 'a click below the 4px slop is not a released drag',
    );
    // And it placed nothing either, which is the OTHER thing a click on a
    // row must not do (docs/04 §3.1 step 1: a click means show details).
    expect(controller.doc.devices, hasLength(before));

    await tester.pumpAndSettle();
  });

  testWidgets('a double-click places, and the placement is what is SAID', (
    tester,
  ) async {
    final controller = await pump(tester);
    final row = find.widgetWithText(ListTile, 'HDMI Matrix 4x4');
    await tester.tap(row);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(row);
    await tester.pump();

    final said = onScreen(tester);
    expect(controller.doc.devices, hasLength(1));
    expect(said.where((t) => t.contains('Placed ')), isNotEmpty);
    // THE REGRESSION. The second half of the double-click used to land
    // here and overwrite the sentence above.
    expect(said.where((t) => t.contains(_released)), isEmpty);

    await tester.pumpAndSettle();
  });

  testWidgets('a LIFTED drag released outside the rack still says so', (
    tester,
  ) async {
    // The half that is not a defect, held so the fix cannot be widened
    // into deleting the message. The pointer crosses the 4px slop and is
    // released while still over the palette, which is the escape hatch
    // docs/04 §3.1 describes and which the Staging Bin does not exist to
    // catch (docs/m1-implementation-log.md §4.2).
    final controller = await pump(tester);
    final row = find.widgetWithText(ListTile, 'HDMI Matrix 4x4');
    final start = tester.getCenter(row);

    final gesture = await tester.startGesture(start);
    await tester.pump();
    // Well past the 4px slop, and DOWN the palette rather than towards
    // the canvas, so the pointer never enters the canvas bounds.
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      onScreen(tester).where((t) => t.contains(_released)),
      isNotEmpty,
      reason: 'a real drag released outside the rack IS a refused action',
    );
    expect(controller.doc.devices, isEmpty);

    await tester.pumpAndSettle();
  });
}
