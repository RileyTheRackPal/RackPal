// `#243`, M4-O1, DR-104 §11.103.2/.3/.6: the browser the Device Manager
// tab was always named for.
//
// THE CASE THAT WOULD HAVE SHIPPED BROKEN IS `the New button exists`.
// DR-104's first draft said `Project ▸ New device template…` keeps
// working; there IS no Project menu, and this tab was the only route to
// authoring a template. So a browser without that button does not add a
// surface, it REMOVES the ability to author a device. The ruling was
// corrected and this file holds the correction.
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
}) => MaterialApp(
  home: Scaffold(
    body: DeviceBrowserScreen(
      templates: rows ?? _rows(),
      document: document,
      registries: buildSeedRegistries(),
      onNew: onNew ?? () {},
      onEdit: onEdit,
    ),
  ),
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
}
