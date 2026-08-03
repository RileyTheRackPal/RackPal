// Widget tests for `DevicePalettePanel` (docs/04-rack-editor.md §1's
// palette spec: categories + search; docs/09-roadmap.md M1 checklist #6).
// Uses the REAL seeded catalog (`buildSeedCatalog()`), not a fake, so a
// regression in the catalog data itself (an empty category, a duplicate
// id) would also show up here.

import 'package:flutter/gestures.dart' show PointerDownEvent, kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

Widget _app({
  required void Function(String) onPlace,
  void Function(String, PointerDownEvent)? onArmDrag,
  String? draggingCatalogId,
}) => MaterialApp(
  home: Scaffold(
    body: DevicePalettePanel(
      catalog: buildSeedCatalog(),
      categoryOrder: kCatalogCategoryOrder,
      onPlace: onPlace,
      onArmDrag: onArmDrag,
      draggingCatalogId: draggingCatalogId,
    ),
  ),
);

void main() {
  testWidgets('lists every category with at least one row, scrolling to '
      'reach the ones below the fold (the ListView is lazily built, like '
      'any real one)', (tester) async {
    await tester.pumpWidget(_app(onPlace: (_) {}));
    await tester.pumpAndSettle();

    for (final category in kCatalogCategoryOrder) {
      await tester.scrollUntilVisible(
        find.text(category),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.text(category),
        findsOneWidget,
        reason: '$category header missing from the palette',
      );
    }
    // The flagship template's row is reachable once scrolled back up.
    await tester.scrollUntilVisible(
      find.text('HDMI/HDBaseT Matrix 8x8'),
      -2000,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('HDMI/HDBaseT Matrix 8x8'), findsOneWidget);
  });

  testWidgets('search filters across every category to matching rows only', (
    tester,
  ) async {
    await tester.pumpWidget(_app(onPlace: (_) {}));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'patch panel');
    await tester.pumpAndSettle();

    expect(find.text('Patch Panel, 24-port'), findsOneWidget);
    // A non-matching template from a different category is gone.
    expect(find.text('HDMI/HDBaseT Matrix 8x8'), findsNothing);
    // Category headers are gone too — search flattens to one result list.
    expect(find.text(kCatAudio), findsNothing);
  });

  testWidgets('search also matches by catalog id and type prefix', (
    tester,
  ) async {
    await tester.pumpWidget(_app(onPlace: (_) {}));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'F01');
    await tester.pumpAndSettle();
    expect(find.text('Display (flat panel)'), findsOneWidget);
  });

  testWidgets('an empty search shows a "no match" message, not a blank list', (
    tester,
  ) async {
    await tester.pumpWidget(_app(onPlace: (_) {}));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz-no-such-device');
    await tester.pumpAndSettle();
    expect(find.textContaining('No devices match'), findsOneWidget);
  });

  testWidgets('double-tapping a row invokes onPlace with its catalog id', (
    tester,
  ) async {
    String? placed;
    await tester.pumpWidget(_app(onPlace: (id) => placed = id));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'HDMI/HDBaseT Matrix 8x8');
    await tester.pumpAndSettle();

    // Scoped to the ListTile so it can't match the search field's own
    // (identical) text.
    final row = find.widgetWithText(ListTile, 'HDMI/HDBaseT Matrix 8x8');
    expect(row, findsOneWidget);

    await tester.tap(row);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(placed, 'V01');
  });

  group('drag-from-palette arming (docs/04 §3.1, added this stage)', () {
    testWidgets('a pointer-down on a row fires onArmDrag with its catalog '
        'id, without interfering with double-tap-to-place', (tester) async {
      final armed = <String>[];
      String? placed;
      await tester.pumpWidget(
        _app(
          onPlace: (id) => placed = id,
          onArmDrag: (id, _) => armed.add(id),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'HDMI/HDBaseT Matrix 8x8');
      await tester.pumpAndSettle();
      final row = find.widgetWithText(ListTile, 'HDMI/HDBaseT Matrix 8x8');

      // A stationary double-tap ALSO arms (any pointer-down does, per
      // AC-016 -- no PointerDeviceKind/gesture-outcome branch), but never
      // crosses this widget's own concern (that's RackCanvasScreen's 4px
      // slop, exercised in rack_canvas_screen_test.dart) and must not
      // suppress the existing double-tap place.
      await tester.tap(row);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(armed, isNotEmpty);
      expect(armed, everyElement('V01'));
      expect(placed, 'V01'); // double-tap still placed -- Listener didn't
      // steal the gesture arena from GestureDetector.onDoubleTap.
    });

    testWidgets('draggingCatalogId dims + outlines only the matching row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(onPlace: (_) {}, draggingCatalogId: 'V01'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'HDMI/HDBaseT Matrix 8x8');
      await tester.pumpAndSettle();
      final draggingRow = find.widgetWithText(
        ListTile,
        'HDMI/HDBaseT Matrix 8x8',
      );
      expect(draggingRow, findsOneWidget);
      // The dimmed row sits inside an Opacity(0.40) ancestor; a plain row
      // (searched for below) has no such ancestor.
      final dimmedOpacity = tester
          .widgetList<Opacity>(
            find.ancestor(of: draggingRow, matching: find.byType(Opacity)),
          )
          .where((o) => o.opacity == 0.40);
      expect(dimmedOpacity, isNotEmpty);
    });

    testWidgets('no draggingCatalogId means no row is dimmed', (tester) async {
      await tester.pumpWidget(_app(onPlace: (_) {}));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'HDMI/HDBaseT Matrix 8x8');
      await tester.pumpAndSettle();
      final row = find.widgetWithText(ListTile, 'HDMI/HDBaseT Matrix 8x8');
      final dimmedOpacity = tester
          .widgetList<Opacity>(
            find.ancestor(of: row, matching: find.byType(Opacity)),
          )
          .where((o) => o.opacity == 0.40);
      expect(dimmedOpacity, isEmpty);
    });
  });
}
