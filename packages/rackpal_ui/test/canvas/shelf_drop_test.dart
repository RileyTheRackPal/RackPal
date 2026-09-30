// A palette row or a Staging Bin chip dropped onto a shelf (DR-204
// §11.203.1, `#956`).
//
// Driven through the real palette (`RackWithPalette`) and the real canvas,
// with the pointer, because the gap a drop lands in is decided from where
// the hosts are DRAWN: a test that called the planner with an `after`
// would prove the planner and not the caret.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../app_like.dart';
import 'rack_with_palette.dart';

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

final _when = DateTime.utc(2026, 9, 30);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _rack = Uuid('rack-1');
const _shelf = Uuid('dev-shelf');
const _box1 = Uuid('dev-box-1');
const _box2 = Uuid('dev-box-2');

void _template(RackDocument doc, String id, TemplateBody body) =>
    doc.templates['$id@1'] = TemplateSnapshot(
      templateId: TemplateId(id),
      version: 1,
      contentHash: 'sha256:$id',
      capturedAt: _when,
      body: body,
    );

void _device(
  RackDocument doc,
  Uuid id,
  String template,
  String designator,
  Placement placement,
) => doc.devices[id] = DeviceInstance(
  id: id,
  kind: DeviceKind.rackDevice,
  templateRef: TemplateRef(
    templateId: TemplateId(template),
    version: 1,
    contentHash: 'sha256:$template',
  ),
  designator: designator,
  name: designator,
  placement: placement,
  meta: _meta(),
);

RackDocument _document() {
  final doc = RackDocument(
    id: const Uuid('doc-956'),
    appVersion: '0.1.0+build.1',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    info: ProjectInfo(projectName: 'DR-204'),
    registries: buildSeedRegistries(),
  );
  doc.racks[_rack] = Rack(
    id: _rack,
    name: 'HEAD END',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  _template(
    doc,
    'tpl.shelf',
    TemplateBody(
      manufacturer: 'Demo',
      model: 'SHELF',
      displayName: 'Vented shelf',
      frontU: 2,
      side: OccupancySide.front,
      isContainer: true,
    ),
  );
  _template(
    doc,
    'tpl.box',
    TemplateBody(
      manufacturer: 'Demo',
      model: 'BOX',
      displayName: 'Cable box',
      typePrefix: 'STB',
      mountMethod: MountMethod.shelf,
      shelfWidth: const Len(120_000_000),
    ),
  );
  _template(
    doc,
    'tpl.avr',
    TemplateBody(
      manufacturer: 'Demo',
      model: 'AVR',
      displayName: 'Receiver',
      typePrefix: 'AVR',
      frontU: 2,
      side: OccupancySide.front,
    ),
  );
  _device(
    doc,
    _shelf,
    'tpl.shelf',
    'SHF-1',
    const RailPlacement(rackId: _rack, ruIndex: 4, face: Face.front),
  );
  _device(
    doc,
    _box1,
    'tpl.box',
    'STB-1',
    const ShelfPlacement(hostDeviceId: _shelf, order: FracIndex('a0')),
  );
  _device(
    doc,
    _box2,
    'tpl.box',
    'STB-2',
    const ShelfPlacement(hostDeviceId: _shelf, order: FracIndex('a1')),
  );
  return doc;
}

Future<DocumentController> _pump(
  WidgetTester tester,
  RackDocument doc,
) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = DocumentController(doc, clock: FixedClock(_when));
  await tester.pumpWidget(
    MaterialApp(
      shortcuts: appGlobalShortcuts(),
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

/// Carries a pointer from [from] to [to] in steps, pumping each, and
/// hands the gesture back still DOWN so a caller can read the live frame.
Future<TestGesture> _carry(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  const steps = 14;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump();
  }
  return gesture;
}

/// The centre of the palette row showing [name]. THE FIRST of them: the
/// palette lists a document template in more than one section, and every
/// row showing it arms the same template, so which one is grabbed does
/// not change what these tests assert.
Offset _row(WidgetTester tester, String name) =>
    tester.getCenter(find.text(name).first);

/// The midpoint of the gap between the two hosts, on their centre line.
Offset _between(WidgetTester tester) {
  final a = tester.getRect(find.byKey(ValueKey(_box1.v)));
  final b = tester.getRect(find.byKey(ValueKey(_box2.v)));
  return Offset((a.right + b.left) / 2, a.center.dy);
}

List<Uuid> _packOrder(RackDocument doc) => [
  for (final d in devicesOnShelf(doc, _shelf)) d.id,
];

/// The text on screen at THIS frame, since the status line auto-clears.
bool _onScreen(WidgetTester tester, String part) => tester
    .widgetList<Text>(find.byType(Text))
    .any((t) => (t.data ?? '').contains(part));

void main() {
  testWidgets('A SHELF-ONLY ROW dropped between two hosts lands BETWEEN '
      'them, at the gap the caret showed', (tester) async {
    final doc = _document();
    await _pump(tester, doc);

    final gesture = await _carry(
      tester,
      _row(tester, 'Cable box'),
      _between(tester),
    );
    await gesture.up();
    await tester.pump();

    final order = _packOrder(doc);
    expect(order, hasLength(3));
    expect(order.first, _box1);
    expect(order.last, _box2);
    final placed = doc.devices[order[1]]!;
    expect(placed.designator, startsWith('STB'));
    expect(_onScreen(tester, 'Placed ${placed.designator} on SHF-1.'), isTrue);
    expect(_onScreen(tester, 'rack-mountable'), isFalse);
    await tester.pump(const Duration(seconds: 4)); // the status timer
  });

  testWidgets('A RACK-EAR ROW lands on the shelf too, and the status line '
      'says it could have gone on the rails (DR-204 §11.203.2)', (
    tester,
  ) async {
    final doc = _document();
    await _pump(tester, doc);

    final gesture = await _carry(
      tester,
      _row(tester, 'Receiver'),
      _between(tester),
    );
    await gesture.up();
    await tester.pump();

    final order = _packOrder(doc);
    expect(order, hasLength(3));
    expect(doc.devices[order[1]]!.designator, startsWith('AVR'));
    expect(_onScreen(tester, 'is rack-mountable'), isTrue);
    await tester.pump(const Duration(seconds: 4)); // the status timer
  });

  testWidgets('A SHELF ROW over a shelf is aimed at the rails, not nested: '
      'one level of hosts is drawn, so a shelf on a shelf would vanish', (
    tester,
  ) async {
    final doc = _document();
    await _pump(tester, doc);
    final before = doc.devices.length;

    final gesture = await _carry(
      tester,
      _row(tester, 'Vented shelf'),
      _between(tester),
    );
    // Refused as a RAIL drop, which names the shelf as the occupant.
    expect(_onScreen(tester, 'Occupied by SHF-1'), isTrue);
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));

    expect(doc.devices.length, before);
  });

  testWidgets('a shelf-only row over BARE RAILS is refused in words and '
      'adds nothing', (tester) async {
    final doc = _document();
    await _pump(tester, doc);
    final before = doc.devices.length;

    // Well above the shelf, over empty U.
    final shelf = tester.getRect(find.byKey(ValueKey(_shelf.v)));
    final gesture = await _carry(
      tester,
      _row(tester, 'Cable box'),
      Offset(shelf.center.dx, shelf.top - shelf.height * 2),
    );
    // THE PRECONDITION: the drag reached the rails and was refused there.
    expect(_onScreen(tester, 'has no rack height'), isTrue);
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));

    expect(doc.devices.length, before);
  });

  testWidgets('A STAGED SHELF-ONLY DEVICE drags from the bin onto the shelf, '
      'first when dropped before every host', (tester) async {
    final doc = _document();
    await _pump(tester, doc);

    // STB-2 to the bin with `U`, then back onto the shelf's left end.
    await tester.tap(find.byKey(ValueKey(_box2.v)));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.pumpAndSettle();
    expect(doc.devices[_box2]!.placement, isA<StagedPlacement>());

    final a = tester.getRect(find.byKey(ValueKey(_box1.v)));
    final gesture = await _carry(
      tester,
      tester.getCenter(find.byKey(ValueKey('staged-${_box2.v}'))),
      Offset(a.left + 2, a.center.dy),
    );
    await gesture.up();
    await tester.pump();

    expect(_packOrder(doc), [_box2, _box1]);
    expect(_onScreen(tester, 'Placed STB-2 on SHF-1.'), isTrue);
    await tester.pump(const Duration(seconds: 4)); // the status timer
  });

  group('PUT A DEVICE ON THIS SHELF… (#957, DR-204 §11.203.1)', () {
    const button = ValueKey('inspector-put-on-shelf');

    /// Selects SHF-1 by its header strip, the part of a hosting shelf a
    /// click can reach that no host covers.
    Future<void> selectShelf(WidgetTester tester) async {
      final r = tester.getRect(find.byKey(ValueKey(_shelf.v)));
      await tester.tapAt(Offset(r.left + 3, r.top + 3));
      await tester.pumpAndSettle();
    }

    testWidgets('offers shelf-sitting devices first and never a shelf, and '
        'Enter from the filter puts the first match on the end', (
      tester,
    ) async {
      final doc = _document();
      await _pump(tester, doc);
      await selectShelf(tester);

      await tester.tap(find.byKey(button));
      await tester.pumpAndSettle();
      final dialog = find.byType(PutOnShelfDialog);
      expect(dialog, findsOneWidget);
      final names = tester
          .widgetList<RadioListTile<String>>(
            find.descendant(
              of: dialog,
              matching: find.byType(RadioListTile<String>),
            ),
          )
          .map((t) => t.value)
          .toList();
      expect(names, ['tpl.box', 'tpl.avr']);

      // THE KEYBOARD'S ROUTE: the filter has focus, so Enter alone places.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final order = _packOrder(doc);
      expect(order, hasLength(3));
      expect(order.take(2), [_box1, _box2], reason: 'packed at the end');
      expect(_onScreen(tester, 'on SHF-1.'), isTrue);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('typing narrows the list, and a rack-ear pick says so', (
      tester,
    ) async {
      final doc = _document();
      await _pump(tester, doc);
      await selectShelf(tester);
      await tester.tap(find.byKey(button));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(PutOnShelfDialog.filterKey), 'recei');
      await tester.pump();
      await tester.tap(find.byKey(PutOnShelfDialog.confirmKey));
      await tester.pump();

      final order = _packOrder(doc);
      expect(doc.devices[order.last]!.designator, startsWith('AVR'));
      expect(_onScreen(tester, 'is rack-mountable'), isTrue);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('is offered for a shelf and for nothing else', (tester) async {
      final doc = _document();
      await _pump(tester, doc);

      await tester.tap(find.byKey(ValueKey(_box1.v)));
      await tester.pumpAndSettle();
      expect(find.byKey(button), findsNothing, reason: 'STB-1 is no shelf');

      await selectShelf(tester);
      expect(find.byKey(button), findsOneWidget);
    });
  });

  group('DRAGGING A HOST (#958, canon §11.203.9)', () {
    /// Selects [id] and drags it from its centre to [to], answering the
    /// gesture still DOWN so a caller can read the live frame.
    Future<TestGesture> grab(WidgetTester tester, Uuid id, Offset to) async {
      final box = find.byKey(ValueKey(id.v));
      await tester.tap(box);
      await tester.pumpAndSettle();
      return _carry(tester, tester.getCenter(box), to);
    }

    testWidgets('ALONG ITS OWN SHELF it reorders, keeping the device', (
      tester,
    ) async {
      final doc = _document();
      await _pump(tester, doc);
      final a = tester.getRect(find.byKey(ValueKey(_box1.v)));

      final g = await grab(tester, _box2, Offset(a.left + 2, a.center.dy));
      await g.up();
      await tester.pump();

      expect(_packOrder(doc), [_box2, _box1]);
      expect(_onScreen(tester, 'Moved STB-2 along SHF-1.'), isTrue);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('DROPPED BACK IN ITS OWN GAP it is a no-op with no undo '
        'entry', (tester) async {
      final doc = _document();
      final controller = await _pump(tester, doc);
      final b = tester.getRect(find.byKey(ValueKey(_box2.v)));

      final g = await grab(tester, _box2, Offset(b.right - 2, b.center.dy));
      await g.up();
      await tester.pump();

      expect(_packOrder(doc), [_box1, _box2]);
      expect(controller.undo.canUndo, isFalse);
    });

    testWidgets('ONTO ANOTHER SHELF it moves there', (tester) async {
      final doc = _document();
      _device(
        doc,
        const Uuid('dev-shelf-2'),
        'tpl.shelf',
        'SHF-2',
        const RailPlacement(rackId: _rack, ruIndex: 9, face: Face.front),
      );
      await _pump(tester, doc);
      final to = tester.getCenter(find.byKey(const ValueKey('dev-shelf-2')));

      final g = await grab(tester, _box1, to);
      await g.up();
      await tester.pump();

      expect(
        (doc.devices[_box1]!.placement as ShelfPlacement).hostDeviceId,
        const Uuid('dev-shelf-2'),
      );
      expect(_onScreen(tester, 'Moved STB-1 to SHF-2.'), isTrue);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('A RACK-EAR HOST onto free rails is MOUNTED there, the AVR '
        'case', (tester) async {
      final doc = _document();
      const avr = Uuid('dev-avr');
      _device(
        doc,
        avr,
        'tpl.avr',
        'AVR-1',
        const ShelfPlacement(hostDeviceId: _shelf, order: FracIndex('a2')),
      );
      await _pump(tester, doc);
      final shelf = tester.getRect(find.byKey(ValueKey(_shelf.v)));

      final g = await grab(
        tester,
        avr,
        Offset(shelf.center.dx, shelf.top - shelf.height * 2),
      );
      await g.up();
      await tester.pump();

      expect(doc.devices[avr]!.placement, isA<RailPlacement>());
      expect(_onScreen(tester, 'Placed AVR-1 at RK-1'), isTrue);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('OFF THE RACK it goes to the Staging Bin', (tester) async {
      final doc = _document();
      await _pump(tester, doc);
      final shelf = tester.getRect(find.byKey(ValueKey(_shelf.v)));

      final g = await grab(
        tester,
        _box1,
        Offset(shelf.right + shelf.width, shelf.center.dy),
      );
      await g.up();
      await tester.pump();

      final staged = doc.devices[_box1]!.placement as StagedPlacement;
      expect(staged.lastHostDeviceId, _shelf);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('ANYWHERE ELSE ON THE RACK it is removed, the ghost says so '
        'first, and ONE Ctrl+Z brings it back', (tester) async {
      final doc = _document();
      await _pump(tester, doc);
      final shelf = tester.getRect(find.byKey(ValueKey(_shelf.v)));

      // Bare rails, and STB-1 has no rack height.
      final g = await grab(
        tester,
        _box1,
        Offset(shelf.center.dx, shelf.top - shelf.height * 2),
      );
      expect(_onScreen(tester, 'Release to remove STB-1'), isTrue);
      await g.up();
      await tester.pump();

      expect(doc.devices.containsKey(_box1), isFalse);
      expect(_onScreen(tester, 'Removed STB-1. Ctrl+Z to undo.'), isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(_packOrder(doc), [_box1, _box2]);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('WIDTH ON A SHELF (DR-204 §11.203.8)', () {
    /// Widens the fixture's boxes to 200 mm: two fit on a 19-inch shelf and
    /// a third does not.
    RackDocument wide() {
      final doc = _document();
      final box = doc.templates['tpl.box@1']!.body
        ..shelfWidth = const Len(200_000_000);
      expect(box.shelfWidth, const Len(200_000_000));
      return doc;
    }

    testWidgets('EVERY WIDTH KNOWN AND OVER: the drop is refused, naming the '
        'shelf, and nothing is added', (tester) async {
      final doc = wide();
      await _pump(tester, doc);
      final before = doc.devices.length;

      final g = await _carry(
        tester,
        _row(tester, 'Cable box'),
        _between(tester),
      );
      expect(_onScreen(tester, 'SHF-1 is full'), isTrue);
      await g.up();
      await tester.pump(const Duration(seconds: 2));

      expect(doc.devices.length, before);
    });

    testWidgets('AN UNKNOWN WIDTH IN PLAY: the drop lands, and the status '
        'line says the shelf is over-full at least by the stated widths', (
      tester,
    ) async {
      final doc = wide();
      _template(
        doc,
        'tpl.modem',
        TemplateBody(
          manufacturer: 'Demo',
          model: 'MODEM',
          displayName: 'Modem',
          typePrefix: 'MDM',
          mountMethod: MountMethod.shelf,
        ),
      );
      _device(
        doc,
        const Uuid('dev-modem'),
        'tpl.modem',
        'MDM-1',
        const ShelfPlacement(hostDeviceId: _shelf, order: FracIndex('a2')),
      );
      await _pump(tester, doc);

      final g = await _carry(
        tester,
        _row(tester, 'Cable box'),
        _between(tester),
      );
      await g.up();
      await tester.pump();

      expect(_packOrder(doc), hasLength(4));
      expect(_onScreen(tester, 'over-full by at least'), isTrue);
      expect(_onScreen(tester, '1 width not stated'), isTrue);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
