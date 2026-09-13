// The Plan tab, opened in the app for the first time (`#878`, DR-162).
//
// ═════════════════════════════════════════════════════════════════════
// NOTHING HAD EVER OPENED IT, WHICH IS WHY THIS FILE IS SHORT
// ═════════════════════════════════════════════════════════════════════
// `shell_tabs_test.dart` asserts `Plan` is IN THE TAB STRIP and never
// switches to it, which is the same index-not-route gap `#877` found on
// the Outlets tab. So these two cases are the first thing in the product's
// own test suite to put the Plan editor on screen.
//
// ═════════════════════════════════════════════════════════════════════
// THE TAB SWITCH RUNS INSIDE `runAsync`, AND IT HAS TO
// ═════════════════════════════════════════════════════════════════════
// `_planTab` starts the underlay's image decode during BUILD, and
// `instantiateImageCodec` never completes inside `testWidgets`' fake-async
// zone. A plain `tap` therefore paints a canvas whose resolver answers
// null and `FlutterDiagramCanvas` raises `MissingImageError` rather than
// drawing nothing. Switching inside `runAsync` is what lets the decode
// land. `.okf/practices/a-test-that-hangs-is-worse-than-one-that-fails.md`
// is the general form.
//
// ═════════════════════════════════════════════════════════════════════
// AND NO POINTER GESTURE REACHES THIS TAB HERE, WHICH IS `#882`
// ═════════════════════════════════════════════════════════════════════
// Measured while writing `#878`: at this mounting a tap on a pin does not
// select it, a drag on a pin does not move it, and a drag on the rail's
// reorder grip does not reorder. All three work in `rackpal_ui`'s own
// suites, and `signposting_test.dart` taps the RACK canvas successfully in
// this same harness, so it is specific to this tab rather than a general
// limit on driving a canvas from an app test.
//
// Whether that is a product defect or an artifact of how this tab is
// hosted is NOT settled, and it is not guessed at here. `#878`'s two
// gestures are proved in `plan_canvas_screen_test.dart` and
// `plan_editor_screen_test.dart`; what this file pins is the half that
// does not need a pointer.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:rackpal/src/session/app_shell.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'session_fakes.dart';

final _when = DateTime.utc(2026, 9, 13);
const _underlayId = Uuid('ul-1');
const _rackId = Uuid('rk-1');
const _member = 'underlays/ul-1.png';

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

Uint8List _png(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(x, y, 200, 30, 30);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// One floorplan page and one rack, pinned or not.
///
/// A RACK RATHER THAN A DEVICE. docs/15 §3.4 calls the rack pin the
/// mandatory one, `PLN-003` fires without it and no length on the plan
/// derives, so it is the pin somebody is most likely to have put in the
/// wrong room.
RackDocument _project({bool pinned = true}) {
  final doc = RackDocument(
    id: const Uuid('doc-878'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    registries: buildSeedRegistries(),
  );
  doc.underlays[_underlayId] = PlanUnderlay(
    id: _underlayId,
    name: 'Level 1',
    imageMember: _member,
    format: PlanImageFormat.png,
    pixelWidth: 600,
    pixelHeight: 400,
    contentHash: 'sha256:test',
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Head end',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
    planPin: pinned
        ? const PlanPin(underlayId: _underlayId, at: PxPt(120, 90))
        : null,
  );
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

  Future<RackDocument> openPlan(
    WidgetTester tester, {
    bool pinned = true,
  }) async {
    final built = await buildTestApp(
      measurer,
      document: _project(pinned: pinned),
    );
    built.session.services.session.addMember(_member, _png(600, 400));
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text(ShellView.plan.label));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    return built.session.services.session.document;
  }

  testWidgets('the tab opens onto a real canvas with the plan drawn', (
    tester,
  ) async {
    // IT PAINTS, which is the load-bearing half. A canvas whose resolver
    // answers null raises `MissingImageError` during paint, so reaching
    // the end of this case at all is the assertion.
    final doc = await openPlan(tester);

    expect(find.byType(PlanEditorScreen), findsOneWidget);
    expect(find.byType(PlanCanvasScreen), findsOneWidget);
    expect(find.byType(PlanCanvasBody), findsOneWidget);
    expect(
      pinsOnUnderlay(doc, _underlayId),
      hasLength(1),
      reason: 'the rack pin is on the page the tab opened',
    );
  });

  testWidgets('THE UNPINNED STRIP IS THE PROOF A CLEARED PIN IS SAFE', (
    tester,
  ) async {
    // DR-162 §11.161.2 is what makes `Delete` on this canvas safe rather
    // than merely consistent with the other two, and the claim is about
    // this mounting: the carrier reappears at the bottom of the VIEW.
    // Asserted here by running the command the key runs, because no
    // pointer gesture reaches this tab (see the header, `#882`).
    final doc = await openPlan(tester);
    expect(
      find.text('RK-1'),
      findsNothing,
      reason: 'pinned, so the strip has nothing to say about it',
    );

    tester
        .state<AppShellState>(find.byType(AppShell))
        .widget
        .services
        .session
        .controller
        .run(ClearPlanPinCommand(carrier: PinCarrier.rack, entityId: _rackId));
    await tester.pumpAndSettle();

    expect(doc.racks[_rackId]!.planPin, isNull);
    expect(
      doc.racks.containsKey(_rackId),
      isTrue,
      reason: 'the rack is still in the project',
    );
    expect(
      find.text('RK-1'),
      findsOneWidget,
      reason:
          'and it is now a row in the unpinned strip, three inches below '
          'where the pointer was',
    );
  });
}
