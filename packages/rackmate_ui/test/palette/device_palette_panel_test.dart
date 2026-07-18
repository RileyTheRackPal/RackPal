// Widget tests for `DevicePalettePanel` (docs/04-rack-editor.md §1's
// palette spec: categories + search; docs/09-roadmap.md M1 checklist #6).
// Uses the REAL seeded catalog (`buildSeedCatalog()`), not a fake, so a
// regression in the catalog data itself (an empty category, a duplicate
// id) would also show up here.

import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

Widget _app({required void Function(String) onPlace}) => MaterialApp(
  home: Scaffold(
    body: DevicePalettePanel(
      catalog: buildSeedCatalog(),
      categoryOrder: kCatalogCategoryOrder,
      onPlace: onPlace,
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
}
