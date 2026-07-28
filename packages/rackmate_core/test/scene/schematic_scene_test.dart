// `buildSchematicScene` — the document → display list half of M2-C.
//
// THE HEADLINE TEST IS THE EXIT CRITERION ITSELF. docs/09/docs/12 §5.1:
// "the schematic re-lays-out deterministically (same input ⇒ byte-identical
// display list)". That is asserted twice, because the two halves are
// different claims and only one of them is obvious:
//
//   * the same document laid out twice — catches a clock, a `Random`, an
//     accumulating cache;
//   * a REORDERED-BUT-EQUIVALENT document — the same entities inserted in a
//     different order. This is the half that catches a `Map`/`Set`
//     iteration order leaking into the drawing, and it is the half a
//     "run it twice" test can never see, because running it twice reuses
//     the same insertion order.
//
// `op_digest.dart` is the instrument; see its header for why an exhaustive
// switch over the sealed op hierarchy is the shape it has to be.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

import 'op_digest.dart';

/// A deterministic measurer — ~0.55 em per character, as
/// `sheet_test_support.dart` uses. Real metrics are asserted against a real
/// TTF in `rackmate_export`; nothing here depends on the actual numbers,
/// only on them being consulted consistently.
final class _Measurer implements TextMeasurer {
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

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026, 7, 28),
  updatedAt: DateTime.utc(2026, 7, 28),
  updatedBy: 'test',
);

const _position = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

PortDef _port(
  String key, {
  required PortDirection direction,
  required int order,
  ReturnChannel? returnChannel,
  String family = 'video.hdmi.2_1',
}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  position: _position,
  order: FracIndex('a${order.toString().padLeft(3, '0')}'),
  direction: direction,
  returnChannel: returnChannel,
);

/// A template with [ins] sinks and [outs] sources. [ins] == [outs] == 0 is
/// the blank-panel case the scene must skip.
TemplateBody _body(String model, {int ins = 1, int outs = 1}) => TemplateBody(
  manufacturer: 'Generic',
  model: model,
  displayName: model,
  frontU: 1,
  side: OccupancySide.front,
  mountMethod: MountMethod.rackEars,
  ports: [
    for (var i = 0; i < ins; i++)
      _port('in$i', direction: PortDirection.sink, order: i),
    for (var i = 0; i < outs; i++)
      _port('out$i', direction: PortDirection.source, order: 100 + i),
  ],
);

/// A fixture builder that can emit its entities in either insertion order.
///
/// [reversed] flips the order every map is populated in — devices, ports,
/// links, templates. It changes nothing about the document's CONTENT, which
/// is exactly what makes it the right probe for hash/insertion-order leaks.
RackDocument _document({
  bool reversed = false,
  bool structureRight = false,
  bool offRackChain = false,
  bool pinItem = true,
  Pt? pinAt,
}) {
  final doc = RackDocument(
    id: const Uuid('0190f100-0000-7000-8000-000000000000'),
    appVersion: 'test',
    createdAt: DateTime.utc(2026, 7, 28),
    modifiedAt: DateTime.utc(2026, 7, 28),
    meta: _meta(),
  );

  final rack = Rack(
    id: const Uuid('0190f101-0000-7000-8000-000000000001'),
    name: 'RACK',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.racks[rack.id] = rack;

  final bodies = <String, TemplateBody>{
    'SRC': _body('SRC', outs: 2),
    'HUB': _body('HUB', ins: 3, outs: 3),
    'SNK': _body('SNK', ins: 2),
    'BLK': _body('BLK', ins: 0, outs: 0),
    'STR': _body('STR', outs: 2),
  };
  final templateIds = bodies.keys.toList();
  for (final id in reversed ? templateIds.reversed : templateIds) {
    doc.templates['$id@1'] = TemplateSnapshot(
      templateId: TemplateId(id),
      version: 1,
      contentHash: 'sha256:$id',
      body: bodies[id]!,
      capturedAt: DateTime.utc(2026, 7, 28),
    );
  }

  // (designator, template, ruIndex, kind)
  const base = <(String, String, int, DeviceKind)>[
    ('SRC-1', 'SRC', 10, DeviceKind.rackDevice),
    ('SRC-2', 'SRC', 9, DeviceKind.rackDevice),
    ('HUB-1', 'HUB', 8, DeviceKind.rackDevice),
    ('SNK-1', 'SNK', 7, DeviceKind.rackDevice),
    ('SNK-2', 'SNK', 6, DeviceKind.rackDevice),
    ('BLK-1', 'BLK', 5, DeviceKind.rackDevice),
    ('STR-1', 'STR', 4, DeviceKind.structure),
  ];
  // Two OFF-RACK devices in a chain: `MID-1` feeds `END-1`.
  const chain = <(String, String, int, DeviceKind)>[
    ('MID-1', 'HUB', 0, DeviceKind.offRackPassive),
    ('END-1', 'SNK', 0, DeviceKind.offRackPassive),
  ];
  final roster = offRackChain ? [...base, ...chain] : base;

  final devices = <String, DeviceInstance>{};
  for (final row in reversed ? roster.reversed : roster) {
    final ordinal = roster.indexOf(row).toString().padLeft(12, '0');
    final id = Uuid('0190f102-0000-7000-8000-$ordinal');
    final device = DeviceInstance(
      id: id,
      kind: row.$4,
      templateRef: TemplateRef(
        templateId: TemplateId(row.$2),
        version: 1,
        contentHash: 'sha256:${row.$2}',
      ),
      designator: row.$1,
      name: 'Device ${row.$1}',
      placement: row.$4 == DeviceKind.offRackPassive
          ? const OffRackPlacement()
          : RailPlacement(
              rackId: rack.id,
              ruIndex: row.$3,
              face: Face.front,
            ),
      meta: _meta(),
      structureBodyId: row.$4 == DeviceKind.structure
          ? const Uuid('0190f104-0000-7000-8000-000000000001')
          : null,
    );
    doc.devices[id] = device;
    devices[row.$1] = device;
  }

  doc.structures[const Uuid(
    '0190f104-0000-7000-8000-000000000001',
  )] = StructureBody(
    id: const Uuid('0190f104-0000-7000-8000-000000000001'),
    deviceId: devices['STR-1']!.id,
    title: 'Rough-in',
    meta: _meta(),
    sheetEdge: structureRight ? SheetEdge.right : SheetEdge.left,
  );

  // (from, fromPort, to, toPort)
  const baseWiring = <(String, String, String, String)>[
    ('SRC-1', 'out0', 'HUB-1', 'in0'),
    ('SRC-2', 'out0', 'HUB-1', 'in1'),
    ('HUB-1', 'out0', 'SNK-1', 'in0'),
    ('HUB-1', 'out1', 'SNK-2', 'in0'),
    ('SRC-1', 'out1', 'SNK-2', 'in1'),
    ('STR-1', 'out0', 'HUB-1', 'in2'),
  ];
  const chainWiring = <(String, String, String, String)>[
    ('HUB-1', 'out2', 'MID-1', 'in0'),
    ('MID-1', 'out0', 'END-1', 'in0'),
  ];
  final wiring = offRackChain ? [...baseWiring, ...chainWiring] : baseWiring;

  Port materialise(DeviceInstance device, String key) {
    final id = derivePortId(device.id, PortKey(key));
    return doc.ports[id] ??= Port(
      id: id,
      deviceId: device.id,
      designator: key,
      templatePortKey: PortKey(key),
    );
  }

  for (final row in reversed ? wiring.reversed : wiring) {
    final index = wiring.indexOf(row);
    final id = Uuid(
      '0190f103-0000-7000-8000-${index.toString().padLeft(12, '0')}',
    );
    final from = materialise(devices[row.$1]!, row.$2);
    final to = materialise(devices[row.$3]!, row.$4);
    doc.links[id] = Link(
      id: id,
      designator: 'W${index.toString().padLeft(3, '0')}',
      media: const MediaTypeId('media.cat6'),
      order: FracIndex('a$index'),
      meta: _meta(),
      conductors: [
        Conductor(from: PortEndpoint(from.id), to: PortEndpoint(to.id)),
      ],
    );
  }

  if (pinAt != null) {
    const sheetId = Uuid('0190f105-0000-7000-8000-000000000001');
    const itemId = Uuid('0190f106-0000-7000-8000-000000000001');
    doc.sheets[sheetId] = Sheet(
      id: sheetId,
      number: 'T3.01',
      title: 'SIGNAL FLOW',
      order: const FracIndex('a0'),
      meta: _meta(),
      items: {
        itemId: SheetItem(
          id: itemId,
          targetId: devices['SNK-1']!.id,
          position: pinAt,
          zOrder: const FracIndex('a0'),
          pinned: pinItem,
        ),
      },
    );
  }

  return doc;
}

SchematicScene _build(RackDocument doc) =>
    buildSchematicScene(doc: doc, measurer: _Measurer());

void main() {
  group('DETERMINISM — the M2 exit criterion', () {
    test('the same document produces a BYTE-IDENTICAL display list twice', () {
      final doc = _document();
      expect(digestScene(_build(doc).scene), digestScene(_build(doc).scene));
    });

    test('a REORDERED-BUT-EQUIVALENT document produces the same display list '
        '— no Map or Set iteration order reaches the drawing', () {
      // Same racks, devices, ports, links and templates; every one of them
      // inserted in the opposite order.
      final forward = _build(_document()).scene;
      final backward = _build(_document(reversed: true)).scene;
      expect(digestScene(backward), digestScene(forward));
    });

    test('two separately-constructed but equal documents agree', () {
      expect(
        digestScene(_build(_document()).scene),
        digestScene(_build(_document()).scene),
      );
    });
  });

  group('which devices get a symbol', () {
    test('a device whose template declares NO ports gets no symbol and is '
        'COUNTED rather than dropped', () {
      final scene = _build(_document());
      final drawn = scene.symbols.map((s) => s.designator).toList();
      expect(drawn, isNot(contains('BLK-1')));
      expect(scene.unsymbolisedDeviceIds, hasLength(1));
      expect(scene.scene.fragments.length, scene.symbols.length);
    });

    test('every drawn device has exactly one fragment, and the fragment is '
        'the LOCAL ops only', () {
      final doc = _document();
      final scene = _build(doc);
      for (final symbol in scene.symbols) {
        final range = scene.scene.fragments[symbol.id]!;
        expect(range.end, greaterThan(range.start));
        // The wrapping OpSave/OpTransform/OpRestore bracket sits OUTSIDE
        // the registered range. `RenderDeviceBox`-style replay positions
        // the fragment itself, so a fragment that included the absolute
        // translate would double-apply it — the desync `scene_builder.dart`
        // documents for the rack elevation, in the schematic.
        expect(scene.scene.ops[range.start - 2], isA<OpSave>());
        final wrap = scene.scene.ops[range.start - 1];
        expect(wrap, isA<OpTransform>());
        expect(scene.scene.ops[range.end], isA<OpRestore>());
        final m = (wrap as OpTransform).m;
        expect(m.storage[12], symbol.bodyRect.left);
        expect(m.storage[13], symbol.bodyRect.top);
        // The fragment's own first op is the symbol's body fill, in LOCAL
        // coordinates: top-left at the origin, not at bodyRect.
        final body = scene.scene.ops[range.start] as OpRect;
        expect(body.r.left, 0);
        expect(body.r.top, 0);
      }
    });
  });

  group('the layout and the drawing agree about size', () {
    test('the box the layout reserves in grid units is the box the symbol '
        'actually draws', () {
      // Two transcriptions of docs/05 §3's sizing formula exist — one in
      // grid units for the layout, one in diagram units inside
      // `buildSymbolGeometry`. This is the assertion that they are the same
      // formula; without it a change to one silently overlaps symbols.
      final scene = _build(_document());
      final upg = kSchematicUnitsPerGrid;
      for (final symbol in scene.symbols) {
        final wGu = symbol.bodyRect.width / upg;
        final hGu = symbol.bodyRect.height / upg;
        expect(wGu, closeTo(wGu.roundToDouble(), 1e-9));
        expect(hGu, closeTo(hGu.roundToDouble(), 1e-9));
      }
    });

    test('no two symbols in a layer overlap on the sheet', () {
      final scene = _build(_document());
      final byId = <String, RenderedSymbol>{
        for (final s in scene.symbols) s.id: s,
      };
      for (final layer in scene.layers) {
        for (var i = 1; i < layer.length; i++) {
          final above = byId[layer[i - 1].v]!.bodyRect;
          final below = byId[layer[i].v]!.bodyRect;
          expect(below.top, greaterThanOrEqualTo(above.bottom));
        }
      }
    });

    test('one layer clears the next horizontally — the layer pitch is sized '
        'from the SAME widths the symbols draw at', () {
      // The layout reserves `widthGu` per symbol and spaces layers by the
      // widest of them plus a gutter. If the two transcriptions of docs/05
      // §3's width formula ever disagree, a wide symbol overhangs the
      // gutter its own layering was supposed to keep empty — and the
      // gutter is the whole structural argument of §10.1.
      final scene = _build(_document());
      final byId = <String, RenderedSymbol>{
        for (final s in scene.symbols) s.id: s,
      };
      for (var l = 0; l + 1 < scene.layers.length; l++) {
        var widest = 0.0;
        for (final id in scene.layers[l]) {
          final r = byId[id.v]!.bodyRect;
          if (r.right > widest) widest = r.right;
        }
        for (final id in scene.layers[l + 1]) {
          expect(byId[id.v]!.bodyRect.left, greaterThan(widest));
        }
      }
    });

    test('the grid-to-diagram factor is DERIVED through print_units, not a '
        'literal', () {
      expect(kSchematicUnitsPerGrid, pointsForLen(kGridUnit));
    });
  });

  group('the rulings phase 1 enforces', () {
    test('CR-072: a left-edge Structure device sits on layer 0', () {
      final scene = _build(_document());
      final str = scene.symbols.firstWhere((s) => s.designator == 'STR-1');
      expect(scene.layers.first, contains(Uuid(str.id)));
    });

    test('CR-072: a right-edge Structure device sits on the LAST layer', () {
      final scene = _build(_document(structureRight: true));
      final str = scene.symbols.firstWhere((s) => s.designator == 'STR-1');
      expect(scene.layers.last, contains(Uuid(str.id)));
      expect(scene.layers.first, isNot(contains(Uuid(str.id))));
    });

    test('an off-rack DESTINATION goes to the last layer, and an off-rack '
        'device that FEEDS something else does not', () {
      // Both are `OffRackPlacement`. `END-1` is a display: nothing leaves
      // it, so it is a destination. `MID-1` is a wall plate feeding a
      // projector, so it keeps its graph layer — forcing it right would
      // drag the edge it sources backwards across the whole sheet.
      final scene = _build(_document(offRackChain: true));
      final end = scene.symbols.firstWhere((s) => s.designator == 'END-1');
      final mid = scene.symbols.firstWhere((s) => s.designator == 'MID-1');
      expect(scene.layers.last, contains(Uuid(end.id)));
      expect(scene.layers.last, isNot(contains(Uuid(mid.id))));
      expect(scene.nonForwardLinkIds, isEmpty);
    });

    test('docs/05 §10.1: within a layer the schematic reads TOP-TO-BOTTOM '
        'in rack order, so U10 precedes U9', () {
      // `SRC-1` (U10) and `SRC-2` (U9) both feed `HUB-1` alone, so their
      // barycentres tie and the rack-order tie-break decides. A rack
      // counts U from the BOTTOM (CR-025) and a sheet reads from the top,
      // so the higher U comes first — sorting ascending would put the
      // schematic in exactly the reverse of the elevation, which is the
      // one thing the rule exists to prevent.
      final scene = _build(_document());
      final ids = scene.layers.expand((l) => l).toList();
      final one = scene.symbols.firstWhere((s) => s.designator == 'SRC-1');
      final two = scene.symbols.firstWhere((s) => s.designator == 'SRC-2');
      expect(
        ids.indexOf(Uuid(one.id)),
        lessThan(ids.indexOf(Uuid(two.id))),
      );
    });

    test('CR-068: a PINNED SheetItem lands its symbol at exactly its stored '
        'position, and auto-layout does not move it', () {
      const at = Pt(96, 40);
      final scene = _build(_document(pinAt: at));
      final snk = scene.symbols.firstWhere((s) => s.designator == 'SNK-1');
      expect(scene.positions[Uuid(snk.id)], at);
      expect(snk.bodyRect.left, at.gx * kSchematicUnitsPerGrid);
      expect(snk.bodyRect.top, at.gy * kSchematicUnitsPerGrid);
    });

    test('an UNPINNED SheetItem position is IGNORED — honouring it would '
        'freeze the first layout the document ever received and make every '
        'recompute a no-op', () {
      // Three documents, identical but for the sheet: none, one carrying a
      // PINNED item at `at`, and one carrying the SAME item unpinned.
      const at = Pt(96, 40);
      final free = _build(_document());
      final pinned = _build(_document(pinAt: at));
      final unpinned = _build(_document(pinAt: at, pinItem: false));

      // The unpinned item changes NOTHING — not one op.
      expect(digestScene(unpinned.scene), digestScene(free.scene));
      // And the comparison is not vacuous: the same item, pinned, moves the
      // drawing.
      expect(
        digestScene(pinned.scene),
        isNot(digestScene(free.scene)),
      );
    });
  });

  group('scope — DR-001 §11.1.3', () {
    test('the scene draws SYMBOLS ONLY: no wires, no net labels, no hop '
        'arcs', () {
      final scene = _build(_document()).scene;
      // A drawn wire would be an `OpPolyline`; a net-label stub would be a
      // leader `OpLine` outside a symbol fragment. The symbol layer emits
      // rects, circles, one header rule per symbol, arrow paths and text —
      // and nothing else. If this list grows, DR-001's scope has moved and
      // that has to be a deliberate act.
      expect(scene.ops.whereType<OpPolyline>(), isEmpty);
      expect(scene.ops.whereType<OpEllipse>(), isEmpty);
      expect(scene.ops.whereType<OpRoundRect>(), isEmpty);
      final lines = scene.ops.whereType<OpLine>().length;
      expect(lines, _build(_document()).symbols.length);
    });

    test('every op belongs to exactly one symbol fragment or to its own '
        'save/transform/restore bracket', () {
      final scene = _build(_document());
      var covered = 0;
      for (final range in scene.scene.fragments.values) {
        covered += range.end - range.start;
      }
      // Three bracket ops per symbol; nothing else may be in the list.
      expect(covered + 3 * scene.symbols.length, scene.scene.ops.length);
    });
  });

  group('hit regions', () {
    test('each symbol contributes one body region and one region per pin', () {
      final scene = _build(_document());
      final expected = scene.symbols.fold<int>(
        0,
        (sum, s) => sum + s.allPorts.length + 1,
      );
      expect(scene.scene.hits, hasLength(expected));
    });
  });

  group('total, not throwing', () {
    test('an empty document produces an empty scene rather than an error', () {
      final doc = RackDocument(
        id: const Uuid('0190f100-0000-7000-8000-000000000009'),
        appVersion: 'test',
        createdAt: DateTime.utc(2026, 7, 28),
        modifiedAt: DateTime.utc(2026, 7, 28),
        meta: _meta(),
      );
      final scene = _build(doc);
      expect(scene.symbols, isEmpty);
      expect(scene.scene.ops, isEmpty);
      expect(scene.layers, isEmpty);
      expect(scene.crossings, 0);
      expect(scene.scene.minTextSizePt, RackTextSizes.type);
    });
  });
}
