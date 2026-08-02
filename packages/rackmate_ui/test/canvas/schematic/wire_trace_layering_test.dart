// The drawn-wire layer's two field defects — the uncapped escape comb and
// the pills painted under the traces.
//
// ═════════════════════════════════════════════════════════════════════
// BOTH WERE ALREADY FIXED IN THE OTHER LAYER, AND THAT IS THE FINDING
// ═════════════════════════════════════════════════════════════════════
// `net_label_layer` capped its comb at six (`NetLabelStyle.maxCombLanes`)
// and layered its ops so no mark paints over an earlier one (96-I). Both
// fixes were written where the report came from. Neither reached
// `wire_trace.dart`, which has its own comb and its own op order for the
// same two reasons — so the field saw the identical two defects again,
// one render mode over, and every test in the suite stayed green.
//
// The lesson is in the tests as much as the code: `wire_trace_test.dart`
// asserts the ROUTE — orthogonal, deterministic, four bends — which is
// everything about where a wire GOES and nothing about how far it climbs
// or what covers what. A layer needs assertions about its output ORDER and
// its EXTENT, not only about its geometry.
//
// ═════════════════════════════════════════════════════════════════════
// N03 IS THE SYMBOL, BECAUSE THE DEFECT NEEDS A WIDE EDGE
// ═════════════════════════════════════════════════════════════════════
// 48 net ports on one edge. Below about seven the comb never reaches its
// ceiling and an uncapped version is indistinguishable from a capped one —
// the same reason `net_label_layer_test`'s two-pin fixture could not see
// the label comb climb, recorded in `net_label_comb_test.dart`'s header.

import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'schematic_test_document.dart';

final _when = DateTime.utc(2026, 8, 3);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _a = Uuid('dev-a');
const _b = Uuid('dev-b');

/// Two N03 switches, `wired` cables between their top edges pin for pin.
({RackDocument doc, int topPortCount}) _fixture({required int wired}) {
  final body = buildSeedCatalog()['N03']!;
  final doc = RackDocument(
    id: const Uuid('doc-wt'),
    appVersion: '0.2.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    registries: buildSeedRegistries(),
  );
  doc.templates['n03@1'] = TemplateSnapshot(
    templateId: const TemplateId('n03'),
    version: 1,
    contentHash: 'sha256:n03',
    capturedAt: _when,
    body: body,
  );
  var d = 0;
  for (final id in <Uuid>[_a, _b]) {
    d++;
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('n03'),
        version: 1,
        contentHash: 'sha256:n03',
      ),
      designator: 'SW-$d',
      name: body.displayName,
      placement: const OffRackPlacement(),
      meta: _meta(),
    );
  }

  // Which ports reach the top edge is catalog data — read, never assumed.
  final banks = <String, BankDef>{for (final b in body.banks) b.key: b};
  final topKeys = <String>[
    for (final p in body.ports)
      if (symbolSideForPort(
            p,
            bank: p.bankKey == null ? null : banks[p.bankKey],
          ) ==
          SymbolSide.top)
        p.key.v,
  ];

  for (var n = 0; n < wired; n++) {
    final key = PortKey(topKeys[n]);
    final pa = derivePortId(_a, key);
    final pb = derivePortId(_b, key);
    for (final (dev, pid) in <(Uuid, Uuid)>[(_a, pa), (_b, pb)]) {
      doc.ports[pid] = Port(
        id: pid,
        deviceId: dev,
        designator: 'J${n + 1}',
        templatePortKey: key,
      );
    }
    final netId = Uuid('net-$n');
    doc.nets[netId] = Net(
      id: netId,
      name: 'N${n.toString().padLeft(3, '0')}',
      signalFamily: const SignalFamilyId('net.ethernet'),
      meta: _meta(),
    );
    doc.links[Uuid('link-$n')] = Link(
      id: Uuid('link-$n'),
      designator: 'W${n.toString().padLeft(3, '0')}',
      media: const MediaTypeId('media.cat6'),
      order: FracIndex('a${n.toString().padLeft(4, '0')}'),
      meta: _meta(),
      conductors: [Conductor(from: PortEndpoint(pa), to: PortEndpoint(pb))],
      services: [
        Service(
          id: 'svc-$n',
          signalFamily: const SignalFamilyId('net.ethernet'),
          netId: netId,
        ),
      ],
    );
  }
  return (doc: doc, topPortCount: topKeys.length);
}

void main() {
  late RackDocument doc;
  late SchematicScene scene;
  late DrawnWireLayer layer;

  setUpAll(() {
    final f = _fixture(wired: 24);
    doc = f.doc;
    expect(
      f.topPortCount,
      greaterThanOrEqualTo(24),
      reason: 'the catalog changed; this fixture needs a wide top edge or '
          'every assertion below is vacuous',
    );
    scene = buildSchematicScene(doc: doc, measurer: const FakeMeasurer());
    layer = buildDrawnWireLayer(
      scene: scene,
      doc: doc,
      linkIds: doc.links.keys.toSet(),
      measurer: const FakeMeasurer(),
      palette: const SchematicPalette(),
    );
  });

  group('1 — the escape comb is BOUNDED', () {
    test('24 cables off one edge use at most six corridors, not 24', () {
      // THE MEASUREMENT IS THE ESCAPE DISTANCE, taken as the length of the
      // first segment of each wire — the run from the pin to the corner,
      // which IS the comb offset. Counting distinct values is what tells a
      // wrapped comb from an unbounded one; the uncapped version produced
      // one value per pin.
      final escapes = <String>{};
      for (final wire in layer.wires) {
        final a = wire.points[0];
        final b = wire.points[1];
        final run = (a.x - b.x).abs() + (a.y - b.y).abs();
        escapes.add(run.toStringAsFixed(4));
      }
      expect(
        escapes.length,
        lessThanOrEqualTo(const SchematicWireStyle().maxCombLanes),
        reason: 'the comb climbed to ${escapes.length} corridors. Unbounded '
            'it reaches one per pin, which is the staircase that walked off '
            'the top of the sheet',
      );
      // AND IT STILL SPREADS. A cap that collapsed to one lane would pass
      // the assertion above and put every wire on one corridor, which is
      // the defect the comb exists to prevent.
      expect(
        escapes.length,
        greaterThan(1),
        reason: 'a comb of one lane is no comb',
      );
    });

    test('the furthest escape is a small multiple of the nearest', () {
      final runs = <double>[
        for (final wire in layer.wires)
          (wire.points[0].x - wire.points[1].x).abs() +
              (wire.points[0].y - wire.points[1].y).abs(),
      ]..sort();
      // Stated as a RATIO rather than a distance so the figure survives a
      // change to `escapeGu` or `combStepGu`, and so it cannot become the
      // tautology `net_label_comb_test`'s first draft was.
      expect(
        runs.last / runs.first,
        lessThan(6),
        reason: 'nearest ${runs.first}, furthest ${runs.last} — an '
            'unbounded comb on this fixture reaches about 16x',
      );
    });
  });

  group('2 — every pill paints OVER every wire', () {
    test('no trace op follows a pill op', () {
      // THE WHOLE CLAIM, and it is about ORDER because the display list has
      // no z-index: ops paint in the order they appear. Emitted per link —
      // wire, pills, wire, pills — link N+1's trace lands on link N's flag,
      // which is what the field saw as a line struck through a net name.
      final firstPill = layer.ops.indexWhere((op) => op is! OpPolyline);
      final lastTrace = layer.ops.lastIndexWhere((op) => op is OpPolyline);
      expect(firstPill, greaterThanOrEqualTo(0), reason: 'no pills emitted');
      expect(lastTrace, greaterThanOrEqualTo(0), reason: 'no traces emitted');
      expect(
        lastTrace,
        lessThan(firstPill),
        reason: 'op $lastTrace is a trace and op $firstPill is a pill — a '
            'wire drawn after a flag is a line through its net name',
      );
    });

    test('the layer emits one trace and two pill ops per end, and loses '
        'none of them', () {
      // The reorder must MOVE ops, not drop them. Two ops per pill (the
      // stadium and its text), two pills per two-ended wire.
      final traces = layer.ops.whereType<OpPolyline>().length;
      expect(traces, doc.links.length);
      expect(layer.ops.length, traces + traces * 2 * 2);
    });
  });

  group('3 — a pill is opaque, so a wire cannot read through it', () {
    test('the pill fill is fully opaque and is NOT the raw domain hue', () {
      // Half the fix. Ordering puts the pill's outline and text over the
      // wire; it does nothing for the wire crossing the flag's BODY, which
      // a 12% fill lets straight through. `compositeOver` resolves the
      // specified 12% against the sheet at build time — the same answer
      // `net_label_layer` reached at `ff712d2`, and the reason that
      // function is public rather than transcribed here.
      final fills = <int>{
        for (final op in layer.ops.whereType<OpRoundRect>())
          if (op.fill != null) op.fill!.argb,
      };
      expect(fills, isNotEmpty);
      for (final argb in fills) {
        expect(
          argb >> 24 & 0xFF,
          255,
          reason: '0x${argb.toRadixString(16)} is translucent; a wire under '
              'the flag body still shows through it',
        );
      }
      final hue = layer.wires.first.style.argb;
      expect(
        fills,
        isNot(contains(hue)),
        reason: 'an opaque fill at the FULL domain hue would be a solid '
            'blob, not the 12% tint of docs/05 §11.5 against paper',
      );
    });
  });
}
