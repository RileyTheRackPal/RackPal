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

// Fixture values that equal a constructor default are written anyway:
// a `TemplateBody` here stands for a piece of equipment, and one that went
// silent on a question changes meaning when the default moves, which
// `mountMethod`'s did once (`#246`). DR-195, canon 11.194.
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/gestures.dart' show PointerDownEvent, kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

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
  String? draggingRowKey,
  RackDocument? document,
  Set<String> favourites = const <String>{},
}) => MaterialApp(
  home: Scaffold(
    body: DevicePalettePanel(
      templates: buildPlaceableTemplates(document ?? _seeded()),
      // `#244`: the registries only ever WIDEN the search, and passing
      // the real seeded set means these cases exercise the alias chain
      // that ships rather than one this file invented.
      registries: buildSeedRegistries(),
      favourites: favourites,
      categoryOrder: kCatalogCategoryOrder,
      onPlace: onPlace,
      onArmDrag: onArmDrag,
      draggingRowKey: draggingRowKey,
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

  testWidgets('double-tapping a row invokes onPlace with its row key', (
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

    expect(placed, 'catalog/V01@1');
  });

  group('drag-from-palette arming (docs/04 §3.1, added this stage)', () {
    testWidgets('a pointer-down on a row fires onArmDrag with its row '
        'key, without interfering with double-tap-to-place', (tester) async {
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
      expect(armed, everyElement('catalog/V01@1'));
      // double-tap still placed: the Listener did not steal the gesture
      // arena from GestureDetector.onDoubleTap.
      expect(placed, 'catalog/V01@1');
    });

    testWidgets('draggingRowKey dims + outlines only the matching row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(onPlace: (_) {}, draggingRowKey: 'catalog/V01@1'),
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

    testWidgets('no draggingRowKey means no row is dimmed', (tester) async {
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

    // `#242` widened this: it used to report the TEMPLATE ID, which was
    // unambiguous only while every row came from the document. A row key
    // names the source too, because an id can now name two rows (DR-102
    // §11.101.4).
    testWidgets('placing it reports its row key, source included', (
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

      expect(placed, 'project/tpl.custom_matrix_24x24@1');
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
  // ═══════════════════════════════════════════════════════════════════
  // `#244`, DR-104 §11.103.5 — the search reads PORTS, not only text.
  // ═══════════════════════════════════════════════════════════════════
  group('search over port signal families', () {
    /// Types [q] and returns the display names still on screen.
    Future<List<String>> search(WidgetTester tester, String q) async {
      await tester.enterText(find.byType(TextField), q);
      await tester.pumpAndSettle();
      return tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title! as Text).data ?? '')
          .toList();
    }

    testWidgets('hdbaset surfaces a device whose NAME lacks the word', (
      tester,
    ) async {
      await tester.pumpWidget(_app(onPlace: (_) {}));
      await tester.pumpAndSettle();

      final hits = await search(tester, 'hdbaset');
      expect(hits, isNotEmpty);
      // THE ASSERTION THAT MAKES THIS MEAN ANYTHING. A hit whose name
      // contains the query would pass against the old name-only matcher,
      // so at least one hit must have been found through a PORT.
      expect(
        hits.any((n) => !n.toLowerCase().contains('hdbaset')),
        isTrue,
        reason: 'a row reached through its ports rather than its name',
      );
    });

    testWidgets('hdbt lands too, through DR-060 s authored alias', (
      tester,
    ) async {
      await tester.pumpWidget(_app(onPlace: (_) {}));
      await tester.pumpAndSettle();
      expect(await search(tester, 'hdbt'), isNotEmpty);
    });

    testWidgets('a query matching nothing still says so', (tester) async {
      // The widening must not have made everything match everything.
      await tester.pumpWidget(_app(onPlace: (_) {}));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzzznotathing');
      await tester.pumpAndSettle();
      expect(find.textContaining('No devices match'), findsOneWidget);
    });
  });

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

  // ═══════════════════════════════════════════════════════════════════
  // `#245`, DR-104 §11.103.4 — docs/06 §7.1: "favourites pin to the top
  // of the browser AND to the palette".
  // ═══════════════════════════════════════════════════════════════════
  group('the pinned Favourites group', () {
    testWidgets('is ABSENT when nothing is starred', (tester) async {
      // Not empty, absent. A heading that appears for everyone would
      // change the surface `#251`'s stopwatch drill measures, and it is
      // the same rule `This project` already follows (DR-077 §11.76.2).
      await tester.pumpWidget(_app(onPlace: (_) {}));
      await tester.pumpAndSettle();
      expect(find.text(kFavouritesGroupTitle), findsNothing);
    });

    testWidgets('appears above This project once something is starred', (
      tester,
    ) async {
      final doc = _seeded();
      _author(doc);
      await tester.pumpWidget(
        _app(
          onPlace: (_) {},
          document: doc,
          favourites: const {'tpl.custom_matrix_24x24'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(kFavouritesGroupTitle), findsOneWidget);
      expect(find.text(kProjectGroupTitle), findsOneWidget);
      // ABOVE, and asserted by geometry rather than by document order,
      // because a `ListView`'s child order is not what a person sees if
      // anything ever reorders it.
      expect(
        tester.getTopLeft(find.text(kFavouritesGroupTitle)).dy,
        lessThan(tester.getTopLeft(find.text(kProjectGroupTitle)).dy),
      );
    });

    testWidgets('a starred SEEDED row pins too, not only authored ones', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(onPlace: (_) {}, favourites: const {'V01'}),
      );
      await tester.pumpAndSettle();
      expect(find.text(kFavouritesGroupTitle), findsOneWidget);
    });

    testWidgets('a starred id this project does not hold shows no group', (
      tester,
    ) async {
      // G4 on a preference: absent is absent, never a broken heading.
      await tester.pumpWidget(
        _app(onPlace: (_) {}, favourites: const {'tpl.not_here'}),
      );
      await tester.pumpAndSettle();
      expect(find.text(kFavouritesGroupTitle), findsNothing);
    });

    testWidgets('a search FLATTENS it away, like every pinned group', (
      tester,
    ) async {
      // The pinned group is browse-state only: a row appearing twice in
      // a search makes the match count wrong and Enter-on-the-top-match
      // ambiguous (DR-077 §11.76.2).
      await tester.pumpWidget(
        _app(onPlace: (_) {}, favourites: const {'V01'}),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'matrix');
      await tester.pumpAndSettle();
      expect(find.text(kFavouritesGroupTitle), findsNothing);
    });
  });
}
