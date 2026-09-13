// `#242`, DR-102 §11.101.3 and DR-103 §11.102: a library on the shelf
// reaches the palette, and a row from it can actually be PLACED.
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY CASE DRIVES THE LIVE SCREEN, for `palette_reads_the_document`'s
// REASON
// ═══════════════════════════════════════════════════════════════════════
// That file's header says it: the defect it closed was a surface holding
// a stale copy, and a test that hands a widget a prepared list cannot
// tell that apart from a surface that reads afresh. The same applies
// here twice over, because the palette's row list is MEMOISED on the
// document and a library arriving is not a document change. So the
// library is handed to a MOUNTED screen and the test pumps.
//
// ═══════════════════════════════════════════════════════════════════════
// THE CASE THAT WOULD HAVE SHIPPED BROKEN
// ═══════════════════════════════════════════════════════════════════════
// `buildPlaceFromCatalogCommand` resolves out of `doc.templates`, and a
// library template is not in the document. Built literally, DR-102's
// palette lists library rows that refuse on double-click with "Unknown
// catalog template". Every assertion below about a device actually
// appearing in `doc.devices` is that defect's absence.
import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'rack_with_palette.dart';

final DateTime _when = DateTime.utc(2026, 8, 30, 10);

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

TemplateBody _body({
  String name = 'Shop Matrix 24x24',
  int frontU = 3,
  String category = kCatVideo,
}) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: name,
  category: category,
  typePrefix: 'MTX',
  frontU: frontU,
  side: OccupancySide.front,
  mountMethod: MountMethod.rackEars,
);

DeviceTemplateFile _entry({
  String id = 'tpl.shop_matrix_24x24',
  int version = 1,
  String contentHash = 'sha256:from-the-file',
  TemplateBody? body,
}) => DeviceTemplateFile(
  templateId: TemplateId(id),
  version: version,
  contentHash: contentHash,
  body: body ?? _body(),
);

LoadedLibrary _library({
  String id = 'shop-kit',
  String name = 'Shop Kit',
  List<DeviceTemplateFile>? templates,
}) => LoadedLibrary(
  id: id,
  name: name,
  templates: templates ?? [_entry()],
);

/// An EMPTY 42U rack with the seed catalog embedded, as
/// `blank_document.dart` builds one.
RackDocument _blank() {
  final meta = EntityMeta(
    createdAt: _when,
    updatedAt: _when,
    updatedBy: 'test',
  );
  final doc = RackDocument(
    id: const Uuid('doc-242'),
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

  Future<DocumentController> pump(
    WidgetTester tester, {
    List<LoadedLibrary> libraries = const [],
    List<UnreadableLibrary> unreadable = const [],
    DocumentController? using,
  }) async {
    final controller =
        using ?? DocumentController(_blank(), clock: FixedClock(_when));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RackWithPalette(
            controller: controller,
            libraries: libraries,
            unreadableLibraries: unreadable,
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

  /// Double-clicks the row whose title is [name], and returns **the text
  /// on screen at the placement frame**.
  ///
  /// THE RETURN VALUE EXISTS BECAUSE `pumpAndSettle` EATS THE
  /// ANNOUNCEMENT. `StatusMessageController` auto-clears after three
  /// seconds, and `pumpAndSettle` runs time forward until nothing is
  /// scheduled, so a status assertion written after one would always
  /// find nothing and read as "the code never said it". The frame is
  /// captured first and the timer drained afterwards, which also keeps
  /// the test from ending with a pending timer.
  Future<List<String>> place(WidgetTester tester, String name) async {
    final row = find.widgetWithText(ListTile, name);
    await tester.tap(row);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(row);
    await tester.pump();
    final said = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    await tester.pumpAndSettle();
    return said;
  }

  /// The palette's DEVICE rows, and neither of the two things a looser
  /// finder counts as one.
  ///
  /// Scoped to the panel, because the inspector column draws `ListTile`s
  /// too; and matched on the trailing occupancy `Chip` rather than on
  /// `ListTile`, because an `ExpansionTile`'s own header IS a `ListTile`
  /// and every category heading would otherwise be a row. The occupancy
  /// badge is one per device row and nothing else in this panel draws a
  /// bare `Chip` (`ChoiceChip` is a different class).
  Finder paletteRows() => find.descendant(
    of: find.byType(DevicePalettePanel),
    matching: find.byType(Chip),
  );

  group('a library reaches the palette', () {
    testWidgets('its templates are rows, badged with the library name', (
      tester,
    ) async {
      await pump(tester, libraries: [_library()]);
      expect(
        find.widgetWithText(ListTile, 'Shop Matrix 24x24'),
        findsOneWidget,
      );
      expect(find.text('Shop Kit'), findsWidgets);
    });

    testWidgets('no libraries means no chip row at all', (tester) async {
      // DR-103 §11.102.6's chips appear when they have a job. M4's
      // exit-criterion drill is a stopwatch on this panel and has not
      // been run; a project with no libraries must look exactly as it
      // did before `#242`.
      await pump(tester);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('one library gives All, Catalog and its own chip', (
      tester,
    ) async {
      await pump(tester, libraries: [_library()]);
      expect(find.widgetWithText(ChoiceChip, kAllSourceLabel), findsOneWidget);
      expect(
        find.widgetWithText(ChoiceChip, kCatalogSourceLabel),
        findsOneWidget,
      );
      expect(find.widgetWithText(ChoiceChip, 'Shop Kit'), findsOneWidget);
      // Nothing has been authored, so there is no `This project` source.
      expect(
        find.widgetWithText(ChoiceChip, kProjectGroupTitle),
        findsNothing,
      );
    });

    testWidgets('a library that would not decode is a DISABLED chip', (
      tester,
    ) async {
      await pump(
        tester,
        libraries: [_library()],
        unreadable: const [
          UnreadableLibrary(id: 'broken-kit', reason: 'not JSON'),
        ],
      );
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'broken-kit'),
      );
      // NAMED, NOT COUNTED, and unselectable: choosing it could only ever
      // produce an empty panel (DR-103 §11.102.7).
      expect(chip.onSelected, isNull);
      expect(chip.isEnabled, isFalse);
    });
  });

  group('the source filter narrows the panel (DR-103 §11.102.6)', () {
    testWidgets('choosing a library leaves ONLY its rows', (tester) async {
      await pump(tester, libraries: [_library()]);
      // The seeded catalog is 48 templates, so the unfiltered panel has
      // many rows. Counted rather than named: which seeded row happens
      // to be built is a fact about a lazy `ListView`, not about the
      // filter, and asserting on one is how a test comes to fail for
      // scrolling reasons.
      expect(paletteRows(), findsWidgets);
      final unfiltered = tester.widgetList(paletteRows()).length;
      expect(unfiltered, greaterThan(1));

      await tester.tap(find.widgetWithText(ChoiceChip, 'Shop Kit'));
      await tester.pumpAndSettle();

      expect(paletteRows(), findsOneWidget);
      expect(
        find.widgetWithText(ListTile, 'Shop Matrix 24x24'),
        findsOneWidget,
      );
    });

    testWidgets('All puts them back', (tester) async {
      await pump(tester, libraries: [_library()]);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Shop Kit'));
      await tester.pumpAndSettle();
      expect(paletteRows(), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, kAllSourceLabel));
      await tester.pumpAndSettle();
      expect(tester.widgetList(paletteRows()).length, greaterThan(1));
    });

    testWidgets('two libraries get one chip each, and they filter apart', (
      tester,
    ) async {
      await pump(
        tester,
        libraries: [
          _library(),
          _library(
            id: 'road-kit',
            name: 'Road Kit',
            templates: [
              _entry(
                id: 'tpl.road_amp',
                body: _body(name: 'Road Amp', category: kCatAudio),
              ),
            ],
          ),
        ],
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Road Kit'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Road Amp'), findsOneWidget);
      expect(
        find.widgetWithText(ListTile, 'Shop Matrix 24x24'),
        findsNothing,
      );
    });
  });

  group('placing a library row (DR-103 §11.102.2)', () {
    testWidgets('it lands a real device AND copies the template in', (
      tester,
    ) async {
      final controller = await pump(tester, libraries: [_library()]);
      final devicesBefore = controller.doc.devices.length;
      final templatesBefore = controller.doc.templates.length;

      await place(tester, 'Shop Matrix 24x24');

      expect(controller.doc.devices, hasLength(devicesBefore + 1));
      // COPY-ON-PLACE (AC-041). The template is in the document now, at
      // the id and version the library offered.
      expect(controller.doc.templates, hasLength(templatesBefore + 1));
      expect(
        controller.doc.templates['tpl.shop_matrix_24x24@1'],
        isNotNull,
      );
    });

    testWidgets('the whole gesture is ONE undo', (tester) async {
      // `DocumentController.transact` groups the copy and the placement.
      // Two entries would make the first Ctrl+Z leave a template behind
      // that the user never asked for and cannot see.
      final controller = await pump(tester, libraries: [_library()]);
      final devicesBefore = controller.doc.devices.length;
      final templatesBefore = controller.doc.templates.length;

      await place(tester, 'Shop Matrix 24x24');
      controller.undo.undo(controller.doc);
      await tester.pumpAndSettle();

      expect(controller.doc.devices, hasLength(devicesBefore));
      expect(controller.doc.templates, hasLength(templatesBefore));
    });

    testWidgets('the device pins the version and hash the file claimed', (
      tester,
    ) async {
      // CR-050 through copy-on-place, and AC-042's warning staying
      // reachable: what the document records is what the FILE claimed,
      // never a hash recomputed on the way in.
      final controller = await pump(
        tester,
        libraries: [
          _library(
            templates: [_entry(version: 3, contentHash: 'sha256:the-claim')],
          ),
        ],
      );
      await place(tester, 'Shop Matrix 24x24');

      final device = controller.doc.devices.values.last;
      expect(device.templateRef.version, 3);
      expect(device.templateRef.contentHash, 'sha256:the-claim');
      expect(
        controller.doc.templates['tpl.shop_matrix_24x24@3']!.contentHash,
        'sha256:the-claim',
      );
    });

    testWidgets('the copy is announced ONCE, not on every placement', (
      tester,
    ) async {
      // DR-103 §11.102.4. The trigger is the copy having happened, so the
      // second placement is silent by construction rather than by a
      // counter this screen would have to keep.
      final controller = await pump(tester, libraries: [_library()]);
      // FILTERED TO THE LIBRARY FIRST, and not for convenience. After the
      // first placement the same display name is on THREE rows: the
      // pinned `This project` group, the project row in its category, and
      // the library row beside it. A finder that cannot say which one
      // would tap whichever the tree happened to build first, and the
      // second placement here has to be the LIBRARY row or the case is
      // not the case it claims.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Shop Kit'));
      await tester.pumpAndSettle();

      const note = 'Added Shop Matrix 24x24 from Shop Kit.';
      final first = await place(tester, 'Shop Matrix 24x24');
      expect(first.where((t) => t.contains(note)), hasLength(1));
      // AND IT DID NOT REPLACE THE PLACEMENT SENTENCE. The copy note is a
      // prefix, not a substitute: a user who lost "Placed MTX-1 at RK-1
      // U1, front." would have gained a fact and lost the one they were
      // waiting for.
      expect(first.where((t) => t.contains('Placed ')), isNotEmpty);

      final second = await place(tester, 'Shop Matrix 24x24');
      expect(second.where((t) => t.contains(note)), isEmpty);
      expect(second.where((t) => t.contains('Placed ')), isNotEmpty);
      // And the second placement really did place: this must not be
      // passing because nothing happened.
      expect(controller.doc.devices, hasLength(2));
      // ...and it added no second template.
      expect(
        controller.doc.templates.keys.where(
          (k) => k.startsWith('tpl.shop_matrix_24x24'),
        ),
        hasLength(1),
      );
    });

    testWidgets('after placing, the row is ALSO a project row', (
      tester,
    ) async {
      // The template is in the document now, so `buildPlaceableTemplates`
      // answers for it twice: once from the shelf, once from the project
      // (DR-102 §11.101.4). Both are real and both are placeable.
      await pump(tester, libraries: [_library()]);
      await place(tester, 'Shop Matrix 24x24');
      expect(
        find.widgetWithText(ChoiceChip, kProjectGroupTitle),
        findsOneWidget,
      );
    });
  });

  group('a library arriving under a live screen', () {
    // The memo defect this would otherwise have. The palette's row list
    // is keyed on the DOCUMENT, and importing a library does not touch
    // the document, so a memo left alone would show a shelf that is one
    // import out of date.
    testWidgets('a shelf re-read reaches the palette with no reopen', (
      tester,
    ) async {
      final controller = await pump(tester);
      expect(
        find.widgetWithText(ListTile, 'Shop Matrix 24x24'),
        findsNothing,
      );

      await pump(tester, libraries: [_library()], using: controller);

      expect(
        find.widgetWithText(ListTile, 'Shop Matrix 24x24'),
        findsOneWidget,
      );
    });
  });
}
