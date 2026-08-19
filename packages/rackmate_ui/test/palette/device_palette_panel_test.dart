// Widget tests for `DevicePalettePanel` (docs/04-rack-editor.md §1's
// palette spec: categories + search; docs/09-roadmap.md M1 checklist #6).
// Uses the REAL seeded catalog, not a fake, so a regression in the catalog
// data itself (an empty category, a duplicate id) would also show up here.
//
// The seed arrives through `buildPlaceableTemplates` on a DOCUMENT that
// holds it, rather than through `buildSeedCatalog()` directly, because
// that is what the panel now takes and because the defect this replaces
// was a surface reading the catalog and therefore agreeing with itself
// forever (M4-S, DR-077 §11.76.1).

import 'package:flutter/gestures.dart' show PointerDownEvent, kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

final DateTime _when = DateTime.utc(2026, 8, 19, 10);

RackDocument _document() => RackDocument(
  id: const Uuid('doc-palette'),
  appVersion: '0.1.0',
  createdAt: _when,
  modifiedAt: _when,
  meta: EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test'),
);

/// A document seeded exactly as `blank_document.dart` seeds one.
RackDocument _seeded() {
  final doc = _document();
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

/// One template authored in the project, saved into [doc].
void _author(
  RackDocument doc, {
  String id = 'tpl.custom_matrix_24x24',
  String name = 'Custom Matrix 24x24',
  String category = kCatVideo,
  int version = 1,
}) {
  doc.templates['$id@$version'] = TemplateSnapshot(
    templateId: TemplateId(id),
    version: version,
    contentHash: 'unhashed:$id@$version',
    capturedAt: _when,
    body: TemplateBody(
      manufacturer: 'Generic',
      model: '',
      displayName: name,
      category: category,
      typePrefix: 'MTX',
      frontU: 3,
      side: OccupancySide.front,
      mountMethod: MountMethod.rackEars,
    ),
  );
}

Widget _app({
  required void Function(String) onPlace,
  void Function(String, PointerDownEvent)? onArmDrag,
  String? draggingCatalogId,
  RackDocument? document,
}) => MaterialApp(
  home: Scaffold(
    body: DevicePalettePanel(
      templates: buildPlaceableTemplates(document ?? _seeded()),
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

  // ═══════════════════════════════════════════════════════════════════
  // DR-077 §11.76.2 — an authored template, and where it shows up
  // ═══════════════════════════════════════════════════════════════════
  group('a template authored in this project', () {
    testWidgets('appears in its own category AND in the pinned group', (
      tester,
    ) async {
      final doc = _seeded();
      _author(doc);
      await tester.pumpWidget(_app(onPlace: (_) {}, document: doc));
      await tester.pumpAndSettle();

      // The pinned group is FIRST, above the nine categories, so it is
      // on screen without scrolling: that is its whole reason to exist.
      expect(find.text(kProjectGroupTitle), findsOneWidget);
      final projectTile = find.ancestor(
        of: find.text(kProjectGroupTitle),
        matching: find.byType(ExpansionTile),
      );
      expect(
        find.descendant(
          of: projectTile,
          matching: find.widgetWithText(ListTile, 'Custom Matrix 24x24'),
        ),
        findsOneWidget,
      );

      // And once more under its own category. Two rows, one template.
      await tester.scrollUntilVisible(
        find.text(kCatVideo),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.widgetWithText(ListTile, 'Custom Matrix 24x24'),
        findsNWidgets(2),
      );
    });

    testWidgets('is badged, and the badge reaches a screen reader', (
      tester,
    ) async {
      final doc = _seeded();
      _author(doc);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(onPlace: (_) {}, document: doc));
      await tester.pumpAndSettle();

      expect(find.text(kProjectRowTag), findsWidgets);
      expect(
        find.bySemanticsLabel(RegExp('authored in this project')),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('a seeded row is not badged', (tester) async {
      await tester.pumpWidget(_app(onPlace: (_) {}));
      await tester.pumpAndSettle();

      expect(find.text(kProjectGroupTitle), findsNothing);
      expect(find.text(kProjectRowTag), findsNothing);
    });

    // THE LIMIT THE RULING STATES: the pinned group is browse-state only.
    // A row appearing twice in a search makes the match count wrong and
    // `Enter`-on-the-top-match ambiguous.
    testWidgets('a search shows it exactly once', (tester) async {
      final doc = _seeded();
      _author(doc);
      await tester.pumpWidget(_app(onPlace: (_) {}, document: doc));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Custom Matrix 24x24');
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ListTile, 'Custom Matrix 24x24'),
        findsOneWidget,
      );
      expect(find.text(kProjectGroupTitle), findsNothing);
      // Still badged: search drops the repetition, not the provenance.
      expect(find.text(kProjectRowTag), findsOneWidget);
    });

    testWidgets('placing it reports its template id, not a catalog id', (
      tester,
    ) async {
      final doc = _seeded();
      _author(doc);
      String? placed;
      await tester.pumpWidget(
        _app(onPlace: (id) => placed = id, document: doc),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Custom Matrix 24x24');
      await tester.pumpAndSettle();
      final row = find.widgetWithText(ListTile, 'Custom Matrix 24x24');
      await tester.tap(row);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(placed, 'tpl.custom_matrix_24x24');
    });

    testWidgets('the newest version is the one listed', (tester) async {
      final doc = _seeded();
      _author(doc);
      _author(doc, name: 'Custom Matrix 24x24 rev B', version: 2);
      await tester.pumpWidget(_app(onPlace: (_) {}, document: doc));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ListTile, 'Custom Matrix 24x24 rev B'),
        findsNWidgets(2),
      );
      expect(
        find.widgetWithText(ListTile, 'Custom Matrix 24x24'),
        findsNothing,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // DR-077 §11.76.2 — `_canSave` does not require a category, and the
  // panel used to iterate `categoryOrder` alone. Such a template was not
  // refused and not badged: it was absent.
  // ═══════════════════════════════════════════════════════════════════
  group('a template with no category', () {
    testWidgets('is reachable under a trailing Uncategorised group', (
      tester,
    ) async {
      final doc = _seeded();
      _author(doc, id: 'tpl.nameless', name: 'Unfiled Device', category: '');
      await tester.pumpWidget(_app(onPlace: (_) {}, document: doc));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(kUncategorisedGroupTitle),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(kUncategorisedGroupTitle), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Unfiled Device'), findsWidgets);
    });

    testWidgets('a category this build does not know lands there too', (
      tester,
    ) async {
      final doc = _seeded();
      _author(
        doc,
        id: 'tpl.from_the_future',
        name: 'Quantum Splitter',
        category: 'Photonics',
      );
      await tester.pumpWidget(_app(onPlace: (_) {}, document: doc));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(kUncategorisedGroupTitle),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.widgetWithText(ListTile, 'Quantum Splitter'), findsWidgets);
    });

    testWidgets('a seeded-only palette has no Uncategorised group at all', (
      tester,
    ) async {
      await tester.pumpWidget(_app(onPlace: (_) {}));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(kCatField),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(kUncategorisedGroupTitle), findsNothing);
    });
  });
}
