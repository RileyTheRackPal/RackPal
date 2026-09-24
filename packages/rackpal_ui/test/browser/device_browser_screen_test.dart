// `#243`, M4-O1, DR-104 §11.103.2/.3/.6: the browser the Device Manager
// tab was always named for.
//
// THE CASE THAT WOULD HAVE SHIPPED BROKEN IS `the New button exists`.
// DR-104's first draft said `Project ▸ New device template…` keeps
// working; there IS no Project menu, and this tab was the only route to
// authoring a template. So a browser without that button does not add a
// surface, it REMOVES the ability to author a device. The ruling was
// corrected and this file holds the correction.
// Fixture values that equal a constructor default are written anyway:
// a `TemplateBody` here stands for a piece of equipment, and one that went
// silent on a question changes meaning when the default moves, which
// `mountMethod`'s did once (`#246`). DR-195, canon 11.194.
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final DateTime _when = DateTime.utc(2026, 8, 30, 12);

TemplateBody _body({
  String name = 'Thing',
  String category = kCatVideo,
  int frontU = 1,
  bool passthrough = false,
  List<PortDef> ports = const [],
}) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: name,
  category: category,
  typePrefix: 'THG',
  frontU: frontU,
  side: OccupancySide.front,
  mountMethod: MountMethod.rackEars,
  isPassthrough: passthrough,
  ports: ports,
);

PortDef _port(String family, {String connector = 'conn.rj45'}) => PortDef(
  key: PortKey('p-$family'),
  label: 'P',
  order: const FracIndex('a0'),
  connector: ConnectorTypeId(connector),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  position: const PanelPosition(
    ruOffset: 0,
    xTwelfth: 0,
    xFineNm: Len.zero,
    yFineNm: Len.zero,
  ),
);

PlaceableTemplate _row(
  String id,
  TemplateBody body, {
  TemplateProvenance provenance = TemplateProvenance.project,
}) => PlaceableTemplate(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'unhashed:$id@1',
  body: body,
  provenance: provenance,
);

/// Three rows with different facts, so every chip has something to keep
/// and something to drop.
List<PlaceableTemplate> _rows() => [
  _row(
    'tpl.matrix',
    _body(
      name: 'Signal Router',
      ports: [_port('video.hdmi.2_0', connector: 'conn.hdmi_a')],
    ),
  ),
  _row(
    'tpl.switch',
    _body(name: 'Edge Switch', ports: [_port('net.poe')]),
  ),
  _row(
    'tpl.panel',
    _body(name: 'Patch Panel', passthrough: true),
    provenance: const LibraryProvenance(
      libraryId: 'shop-kit',
      libraryName: 'Shop Kit',
    ),
  ),
];

Widget _app({
  List<PlaceableTemplate>? rows,
  VoidCallback? onNew,
  void Function(TemplateId)? onEdit,
  RackDocument? document,
  Set<String> favourites = const <String>{},
  void Function(String)? onToggleFavourite,
  void Function(TemplateId)? onRemove,
}) => MaterialApp(
  home: Scaffold(
    body: DeviceBrowserScreen(
      templates: rows ?? _rows(),
      document: document,
      registries: buildSeedRegistries(),
      favourites: favourites,
      onToggleFavourite: onToggleFavourite,
      onNew: onNew ?? () {},
      onEdit: onEdit,
      onRemove: onRemove,
    ),
  ),
);

/// A row for one of the 48 the build ships, which DR-158 §11.157.3 puts
/// out of reach. Read from the catalog rather than spelled, so a renamed
/// archetype fails here instead of quietly making this a test about an id
/// nobody ships.
PlaceableTemplate _seededRow() => _row(
  kSeedCatalogIds.first,
  _body(name: 'Shipped Thing'),
  provenance: TemplateProvenance.seeded,
);

RackDocument _doc() {
  final meta = EntityMeta(
    createdAt: _when,
    updatedAt: _when,
    updatedBy: 'test',
  );
  return RackDocument(
    id: const Uuid('doc-243'),
    appVersion: '0.4.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: meta,
  );
}

/// Card titles currently on screen, in order.
List<String> _names(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where(
      (d) =>
          d.startsWith('Signal') ||
          d.startsWith('Edge') ||
          d.startsWith('Patch'),
    )
    .toList();

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  group('it lists what the project can place', () {
    testWidgets('every row gets a card', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(_names(tester), hasLength(3));
    });

    testWidgets('the card draws a glyph mark, not an elevation strip', (
      tester,
    ) async {
      // DR-104 §11.103.3's substitution, and the widget it reuses is the
      // one M4-R/5 built for the builder's own picker.
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(DeviceGlyphMark), findsNWidgets(3));
    });

    testWidgets('a library row carries its library name as the tag', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Shop Kit'), findsWidgets);
      expect(find.text(kProjectRowTag), findsWidgets);
    });

    testWidgets('the count is shown even when nothing is filtered', (
      tester,
    ) async {
      // "48 devices" and "3 of 48" are the same control answering the
      // same question; one that appears only sometimes cannot be learned.
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('3 devices'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // THE CORRECTION. DR-104 said a menu route existed. It does not.
  // ═══════════════════════════════════════════════════════════════════
  group('the New device template entry point', () {
    testWidgets('the button is there', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text(kBrowserNewTemplateLabel), findsOneWidget);
    });

    testWidgets('pressing it calls onNew', (tester) async {
      // LOAD-BEARING: this tab was the ONLY route to authoring a
      // template, so a browser whose button does nothing removes the
      // capability rather than adding a surface.
      var started = 0;
      await tester.pumpWidget(_app(onNew: () => started++));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kBrowserNewTemplateLabel));
      await tester.pumpAndSettle();
      expect(started, 1);
    });
  });

  group('opening the editor', () {
    testWidgets('double-tapping a card reports its template id', (
      tester,
    ) async {
      TemplateId? opened;
      await tester.pumpWidget(_app(onEdit: (id) => opened = id));
      await tester.pumpAndSettle();
      final card = find.ancestor(
        of: find.text('Signal Router'),
        matching: find.byType(InkWell),
      );
      await tester.tap(card.first);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(card.first);
      await tester.pumpAndSettle();
      expect(opened, const TemplateId('tpl.matrix'));
    });

    testWidgets('with no onEdit the card is inert rather than broken', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final card = find.ancestor(
        of: find.text('Signal Router'),
        matching: find.byType(InkWell),
      );
      await tester.tap(card.first);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(card.first);
      await tester.pumpAndSettle();
      // No exception, and the browser is still showing.
      expect(_names(tester), hasLength(3));
    });
  });

  group('the sidebar narrows', () {
    testWidgets('Has HDMI keeps only the HDMI device', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Has HDMI'));
      await tester.pumpAndSettle();
      expect(_names(tester), ['Signal Router']);
    });

    testWidgets('Has PoE keeps only the switch', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Has PoE'));
      await tester.pumpAndSettle();
      expect(_names(tester), ['Edge Switch']);
    });

    testWidgets('two chips NARROW, they do not widen', (tester) async {
      // Every lit chip must hold, which is what a person ticking two
      // boxes is asking for. An `any` here would show both devices and
      // read as the filter being broken.
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Has HDMI'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Has PoE'));
      await tester.pumpAndSettle();
      expect(_names(tester), isEmpty);
      expect(find.text(kBrowserNoMatchesTitle), findsOneWidget);
    });

    testWidgets('an empty result offers a way out', (tester) async {
      // A filter with no visible reset is a surface a person gets stuck
      // in; the palette's own search grew a clear affordance for this.
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Has HDMI'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Has PoE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(_names(tester), hasLength(3));
    });

    testWidgets('the source chips narrow to one library', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Shop Kit'));
      await tester.pumpAndSettle();
      expect(_names(tester), ['Patch Panel']);
    });
  });

  group('the search is #244s, not a second one', () {
    testWidgets('a port family finds a device its NAME does not mention', (
      tester,
    ) async {
      // `Edge Switch` has a `net.poe` port and the word `poe` is absent
      // from every text field, so this can only pass through the port.
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'poe');
      await tester.pumpAndSettle();
      expect(_names(tester), ['Edge Switch']);
    });

    testWidgets('a plain name still works', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'patch');
      await tester.pumpAndSettle();
      expect(_names(tester), ['Patch Panel']);
    });
  });

  group('used in this project', () {
    testWidgets('the card says so, and only when it is true', (tester) async {
      final doc = _doc();
      doc.devices[const Uuid('d1')] = DeviceInstance(
        id: const Uuid('d1'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('tpl.matrix'),
          version: 1,
          contentHash: 'unhashed:tpl.matrix@1',
        ),
        designator: 'MTX-1',
        name: 'Signal Router',
        placement: const OffRackPlacement(),
        meta: EntityMeta(
          createdAt: _when,
          updatedAt: _when,
          updatedBy: 'test',
        ),
      );
      await tester.pumpWidget(_app(document: doc));
      await tester.pumpAndSettle();
      expect(find.textContaining('used 1×'), findsOneWidget);
    });

    testWidgets('the Used here chip keeps only what is placed', (
      tester,
    ) async {
      final doc = _doc();
      doc.devices[const Uuid('d1')] = DeviceInstance(
        id: const Uuid('d1'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('tpl.panel'),
          version: 1,
          contentHash: 'unhashed:tpl.panel@1',
        ),
        designator: 'PP-1',
        name: 'Patch Panel',
        placement: const OffRackPlacement(),
        meta: EntityMeta(
          createdAt: _when,
          updatedAt: _when,
          updatedBy: 'test',
        ),
      );
      await tester.pumpWidget(_app(document: doc));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Used here'));
      await tester.pumpAndSettle();
      expect(_names(tester), ['Patch Panel']);
    });
  });

  group('grid and list are the same rows', () {
    testWidgets('switching layout keeps every row', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(_names(tester), hasLength(3));
      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pumpAndSettle();
      expect(_names(tester), hasLength(3));
    });

    testWidgets('a filter survives the layout switch', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Has HDMI'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pumpAndSettle();
      expect(_names(tester), ['Signal Router']);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // `#245`, DR-104 §11.103.4 — the star, and where a favourite goes.
  // ═══════════════════════════════════════════════════════════════════
  group('favourites', () {
    testWidgets('no onToggleFavourite means no star at all', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star_border), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('every card gets an outlined star when none are set', (
      tester,
    ) async {
      await tester.pumpWidget(_app(onToggleFavourite: (_) {}));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star_border), findsNWidgets(3));
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('a starred row draws a FILLED star, not a tinted one', (
      tester,
    ) async {
      // CR-078's "hue is never used alone" applied off the canvas: a
      // star that differed only in colour fails on a greyscale print and
      // for a person who cannot see the difference.
      await tester.pumpWidget(
        _app(favourites: const {'tpl.switch'}, onToggleFavourite: (_) {}),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    });

    testWidgets('pressing it reports the template id', (tester) async {
      final toggled = <String>[];
      await tester.pumpWidget(_app(onToggleFavourite: toggled.add));
      await tester.pumpAndSettle();
      final star = find.descendant(
        of: find.ancestor(
          of: find.text('Edge Switch'),
          matching: find.byType(Card),
        ),
        matching: find.byIcon(Icons.star_border),
      );
      await tester.tap(star);
      await tester.pumpAndSettle();
      expect(toggled, ['tpl.switch']);
    });

    testWidgets('a favourite PINS TO THE TOP of the browser', (tester) async {
      // docs/06 §7.1. `_rows()` hands the list over in its own order,
      // matrix then switch then panel, so the switch is in the MIDDLE
      // until it is starred. (The first draft of this case asserted it
      // was last, on an assumption that the fixture came through
      // `buildPlaceableTemplates`'s id sort. It does not, and the test
      // said so.)
      await tester.pumpWidget(_app(onToggleFavourite: (_) {}));
      await tester.pumpAndSettle();
      expect(_names(tester), ['Signal Router', 'Edge Switch', 'Patch Panel']);

      await tester.pumpWidget(
        _app(favourites: const {'tpl.switch'}, onToggleFavourite: (_) {}),
      );
      await tester.pumpAndSettle();
      expect(_names(tester), ['Edge Switch', 'Signal Router', 'Patch Panel']);
    });

    testWidgets('pinning is STABLE: the rest keep their order', (
      tester,
    ) async {
      // A partition, not a sort. Re-sorting on a boolean would need a
      // tiebreak to stay total, and the incoming order already is.
      await tester.pumpWidget(_app(onToggleFavourite: (_) {}));
      await tester.pumpAndSettle();
      final before = _names(tester);
      await tester.pumpWidget(
        _app(favourites: const {'tpl.switch'}, onToggleFavourite: (_) {}),
      );
      await tester.pumpAndSettle();
      final after = _names(tester);
      expect(after.first, 'Edge Switch');
      expect(
        after.sublist(1),
        before.where((n) => n != 'Edge Switch').toList(),
      );
    });

    testWidgets('a starred id this project does not hold is simply absent', (
      tester,
    ) async {
      // G4's shape on a preference. A star survives a project that has
      // never seen the template, and must not become a broken row.
      await tester.pumpWidget(
        _app(
          favourites: const {'tpl.not_here'},
          onToggleFavourite: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      expect(_names(tester), hasLength(3));
    });

    testWidgets('the star survives the list layout', (tester) async {
      await tester.pumpWidget(
        _app(favourites: const {'tpl.switch'}, onToggleFavourite: (_) {}),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(_names(tester).first, 'Edge Switch');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // `#871`, DR-158 §11.157 — removing a template from THIS project
  // ═══════════════════════════════════════════════════════════════════
  group('`#871`: the remove control', () {
    Finder removeFor(String id) =>
        find.byKey(ValueKey(DeviceBrowserScreen.removeKeyFor(id)));

    /// Presses it, and then lets the GESTURE ARENA settle.
    ///
    /// **A BARE `pumpAndSettle` IS NOT ENOUGH HERE AND THE REASON IS NOT
    /// OBVIOUS.** The card's `InkWell` carries `onDoubleTap` whenever
    /// [onEdit] is non-null, so a `DoubleTapGestureRecognizer` joins the
    /// arena and holds it open for its own timeout; the inner tap cannot
    /// win until that expires. `pumpAndSettle` returns as soon as no
    /// frame is scheduled, which is immediately, so the press simply
    /// never lands and the test reads as "the button is wired to
    /// nothing".
    ///
    /// **THIS FILE'S FIXTURE HID IT.** `_app` defaulted `onEdit` to null,
    /// which builds NO double-tap recognizer, so every press in this
    /// group passed while the same press through the real shell did
    /// nothing. A fixture's default is not a proof: these cases now pass
    /// a real `onEdit` so the arena they exercise is the shipped one.
    Future<void> press(WidgetTester tester, Finder button) async {
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    testWidgets('a `This project` row offers it', (tester) async {
      await tester.pumpWidget(_app(onRemove: (_) {}));
      await tester.pumpAndSettle();
      expect(removeFor('tpl.matrix'), findsOneWidget);
    });

    testWidgets("a LIBRARY row does not: it names somebody else's shelf", (
      tester,
    ) async {
      await tester.pumpWidget(_app(onRemove: (_) {}));
      await tester.pumpAndSettle();
      expect(
        removeFor('tpl.panel'),
        findsNothing,
        reason:
            'this project does not hold it, so there is nothing here '
            'to remove',
      );
    });

    testWidgets('and a SEEDED row does not — §11.157.3', (tester) async {
      final rows = [..._rows(), _seededRow()];
      await tester.pumpWidget(_app(rows: rows, onRemove: (_) {}));
      await tester.pumpAndSettle();

      expect(removeFor('tpl.matrix'), findsOneWidget);
      expect(
        removeFor(kSeedCatalogIds.first),
        findsNothing,
        reason:
            'the seeded 48 are what the build ships, and a '
            'per-project hole in them is carried in the file forever',
      );
    });

    testWidgets('no callback, no control anywhere', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(removeFor('tpl.matrix'), findsNothing);
    });

    testWidgets('pressing it reports WHICH template', (tester) async {
      final asked = <TemplateId>[];
      // A REAL `onEdit`, which is what puts the double-tap recognizer in
      // the arena. See `press`.
      await tester.pumpWidget(_app(onEdit: (_) {}, onRemove: asked.add));
      await tester.pumpAndSettle();

      await press(tester, removeFor('tpl.switch'));

      expect(
        asked,
        [const TemplateId('tpl.switch')],
        reason:
            'the browser reports the id and the host does the work; a '
            'control wired to nothing is exactly the shape `#870` found',
      );
    });

    testWidgets('and it survives the switch to the LIST layout', (
      tester,
    ) async {
      // THE CARD AND THE ROW ARE ONE CONTROL IN TWO LAYOUTS, which is
      // why they share a key. A remove that only existed on the grid
      // would be missing for anybody who prefers the list, and nothing
      // else in this file would notice.
      final asked = <TemplateId>[];
      await tester.pumpWidget(_app(onEdit: (_) {}, onRemove: asked.add));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pumpAndSettle();

      expect(removeFor('tpl.matrix'), findsOneWidget);
      expect(removeFor('tpl.panel'), findsNothing);

      await press(tester, removeFor('tpl.matrix'));
      expect(asked, [const TemplateId('tpl.matrix')]);
    });
  });
}
