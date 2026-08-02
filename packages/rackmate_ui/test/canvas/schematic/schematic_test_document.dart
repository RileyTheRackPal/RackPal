// The document every schematic test in this directory draws.
//
// A REAL DOCUMENT, from the REAL seed catalog and the REAL seeded
// registries — not a hand-built graph. That is the whole point of it: the
// canvas deleted at `b560a50` failed because a hardcoded EMPTY scene
// reached it and it then MANUFACTURED a symbol, and a test whose fixture
// was invented inside the test would be exactly as detached from a
// document as that canvas was. Every template here is one `buildSeedCatalog`
// ships, every port key is read off that template rather than typed, and
// every signal family is one `buildSeedRegistries` seeds, so a family that
// stops resolving fails these tests rather than quietly rendering slate.
//
// THREE DOMAINS, deliberately, and never eight: `schematic_paint_plan_test`
// asserts "replay the others, rebuild the one" by ARITHMETIC over the
// domains present, and a fixture with one domain could not tell a plan that
// replayed the rest from a plan that dropped them.
//
// ONE ZERO-PORT DEVICE, so `SchematicScene.unsymbolisedDeviceIds` is
// non-empty and the status strip's count has something true to say.

import 'package:rackmate_core/rackmate_core.dart';

/// A `TextMeasurer` with plausible metrics and no font file.
///
/// The schematic's geometry needs WIDTHS, not glyphs: §3's symbol width
/// formula is a text measurement, and `net_label_layer`'s pennant is as
/// wide as its text. A linear model of advance width exercises every
/// formula that consumes one.
final class FakeMeasurer implements TextMeasurer {
  const FakeMeasurer();

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

/// The designators this fixture places, in rack order.
const List<String> kFixtureDesignators = <String>[
  'MTX-1',
  'AMP-1',
  'SW-1',
  'BLK-1',
  'DIS-1',
];

/// The device that carries no port and therefore no symbol.
const String kFixturePortlessDesignator = 'BLK-1';

/// The three domains this fixture puts on the sheet.
const List<String> kFixtureDomains = <String>[
  'audio.digital',
  'net',
  'video.digital',
];

/// Builds the fixture. Every id is derived from a counter and every
/// timestamp is a fixed UTC instant, so two calls produce documents that
/// lay out identically — which is what the determinism assertions need.
///
/// [feedback] adds a SIXTH link closing the graph into a cycle, and is off
/// by default so the shape every other test in this directory reads stays
/// exactly as it was. See its own note at the call site.
RackDocument buildSchematicTestDocument({bool feedback = false}) {
  final catalog = buildSeedCatalog();
  final at = DateTime.utc(2026, 7, 28, 9);
  EntityMeta meta() =>
      EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test');

  var seed = 0;
  Uuid nextId() {
    seed++;
    return Uuid('0190e0aa-0000-7000-8000-${seed.toString().padLeft(12, '0')}');
  }

  final doc = RackDocument(
    id: const Uuid('0190e0aa-0000-7000-8000-000000000000'),
    appVersion: '0.1.0+build.1',
    createdAt: at,
    modifiedAt: at,
    meta: meta(),
    info: ProjectInfo(projectName: 'SCHEMATIC FIXTURE'),
    // WITHOUT THESE, EVERY FAMILY RESOLVES TO SLATE. DR-010 seeds the
    // registries on a new document; a fixture that omitted them would put
    // every stub in the unresolved bucket and no domain chip would have a
    // count, which is a state this suite must be able to tell APART from
    // a filter bug.
    registries: buildSeedRegistries(),
  );

  const rackId = Uuid('0190e0aa-0000-7000-8000-000000000fff');
  doc.racks[rackId] = Rack(
    id: rackId,
    name: 'HEAD END',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: meta(),
  );

  TemplateRef refTo(String id) => TemplateRef(
    templateId: TemplateId(id),
    version: 1,
    contentHash: 'sha256:seed-$id',
  );

  final byDesignator = <String, DeviceInstance>{};
  void place(
    String catalogId,
    String designator,
    int ru, {
    bool offRack = false,
  }) {
    final body = catalog[catalogId];
    if (body == null) throw StateError('seed catalog has no "$catalogId"');
    doc.templates[catalogTemplateKey(catalogId)] = TemplateSnapshot(
      templateId: TemplateId(catalogId),
      version: 1,
      contentHash: 'sha256:seed-$catalogId',
      body: body,
      capturedAt: at,
    );
    final device = DeviceInstance(
      id: nextId(),
      kind: offRack ? DeviceKind.offRackPassive : DeviceKind.rackDevice,
      templateRef: refTo(catalogId),
      designator: designator,
      name: body.displayName,
      placement: offRack
          ? const OffRackPlacement()
          : RailPlacement(rackId: rackId, ruIndex: ru, face: Face.front),
      meta: meta(),
    );
    doc.devices[device.id] = device;
    byDesignator[designator] = device;
  }

  place('V03', 'MTX-1', 10);
  place('A01', 'AMP-1', 8);
  place('N01', 'SW-1', 6);
  // X01 is a blank panel: zero ports, so no symbol. See the file header.
  place('X01', kFixturePortlessDesignator, 4);
  place('F01', 'DIS-1', 0, offRack: true);

  final cursors = <String, int>{};
  final taken = <String, Set<String>>{};

  /// The next unused template port on [designator], materialised as a real
  /// `Port` row. Ports are LAZILY MATERIALISED (AC-006), so this is the
  /// same thing the app does when a cable is made.
  Port claim(String designator) {
    final device = byDesignator[designator]!;
    final body = catalog[device.templateRef.templateId.v]!;
    final seen = taken.putIfAbsent(designator, () => <String>{});
    for (final def in body.ports) {
      if (!seen.add(def.key.v)) continue;
      final id = derivePortId(device.id, def.key);
      final index = (cursors[designator] ?? 0) + 1;
      cursors[designator] = index;
      final port = Port(
        id: id,
        deviceId: device.id,
        designator: 'J${index.toString().padLeft(2, '0')}',
        templatePortKey: def.key,
      );
      doc.ports[id] = port;
      return port;
    }
    throw StateError('"$designator" ran out of ports');
  }

  var w = 0;
  void wire(String from, String to, String family) {
    w++;
    final a = claim(from);
    final b = claim(to);
    final netId = nextId();
    doc.nets[netId] = Net(
      id: netId,
      name: 'N${w.toString().padLeft(3, '0')}',
      signalFamily: SignalFamilyId(family),
      meta: meta(),
    );
    final id = nextId();
    doc.links[id] = Link(
      id: id,
      designator: 'W${w.toString().padLeft(3, '0')}',
      media: const MediaTypeId('media.cat6'),
      order: FracIndex('a${w.toString().padLeft(4, '0')}'),
      meta: meta(),
      conductors: [
        Conductor(from: PortEndpoint(a.id), to: PortEndpoint(b.id)),
      ],
      // `Service` is what carries the family and the net (CR-011, docs/05
      // §5: colour "resolves from `Service.signalFamily`, never from the
      // `Link`"), so the fixture wires one per link rather than leaning on
      // the port-family fallback.
      services: [
        Service(
          id: 'svc-$w',
          signalFamily: SignalFamilyId(family),
          netId: netId,
        ),
      ],
    );
  }

  wire('MTX-1', 'DIS-1', 'video.hdmi.2_0');
  wire('SW-1', 'MTX-1', 'net.ethernet');
  wire('MTX-1', 'AMP-1', 'audio.spdif_coax');
  wire('SW-1', 'AMP-1', 'net.ethernet');
  // TWO LINKS BETWEEN ONE PAIR OF SYMBOLS, and this row is the whole
  // reason the fixture is not four links. `wire_trace.dart`'s comb exists
  // because N links leaving one symbol's edge for symbols in the same
  // layer would otherwise turn at ONE x and be drawn on top of each other
  // — and a fixture with at most one link per pair cannot tell a working
  // comb from no comb at all, because every corridor lands on a different
  // midpoint anyway. A mutation that deleted the comb survived until this
  // row existed.
  wire('MTX-1', 'AMP-1', 'audio.spdif_coax');

  // ═══════════════════════════════════════════════════════════════════
  // THE CYCLE, AND THE ONE ROUTING SHAPE THE FIVE ABOVE CANNOT REACH
  // ═══════════════════════════════════════════════════════════════════
  // The five links already produce BACKWARD EDGES, which is worth saying
  // plainly because it is easy to assume a DAG produces none: `claim` hands
  // out the next unused TEMPLATE port, so a link's two ends can both land
  // on left edges, and then their escapes point away from each other and
  // the staircase's midpoint corridor lands between them — inside a body.
  // W001, W003 and W005 are all like that, and they are what makes
  // `wire_trace_test.dart`'s "no wire crosses a body it terminates on"
  // able to fail on the default fixture.
  //
  // What five acyclic links cannot produce is a backward MIXED pair — one
  // end on a side edge, the other on a top or bottom edge — because on a
  // DAG the layering puts every top-pin end on the forward side of its
  // partner. This closes the graph, AMP-1 back to SW-1, so the layering has
  // to break a cycle and the edge it picks is drawn against the layer
  // order. That is the real shape (an AVR's output feeding a matrix
  // upstream of it), not a contrivance, and it is the only thing here that
  // reaches `_detour`'s mixed branch through the whole layer rather than
  // through a hand-built box.
  if (feedback) wire('AMP-1', 'SW-1', 'net.ethernet');

  return doc;
}

/// The fixture's scene, laid out with [FakeMeasurer].
SchematicScene buildFixtureScene(RackDocument doc) =>
    buildSchematicScene(doc: doc, measurer: const FakeMeasurer());

/// The fixture device whose designator is [designator].
DeviceInstance deviceNamed(RackDocument doc, String designator) =>
    doc.devices.values.firstWhere((d) => d.designator == designator);
