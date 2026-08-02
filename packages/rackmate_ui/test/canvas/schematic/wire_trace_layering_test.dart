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
    final f = _fixture(wired: 48);
    doc = f.doc;
    expect(
      f.topPortCount,
      greaterThanOrEqualTo(48),
      reason: 'the catalog changed; this fixture needs a top edge wide '
          'enough to have TWO HALVES, or the mirroring assertion below is '
          'vacuous and the corridor assertion is only half a test',
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

  group('1 — no two cables share a corridor in the same direction', () {
    /// Every cable's escape distance at SW-1, paired with the half of that
    /// symbol its pin sits in. The escape IS the comb offset, and the half
    /// is the same test `_prefersLowLane` makes to pick a detour side — so
    /// this reads the two things the comb has to keep in step.
    (List<String> low, List<String> high) escapesByHalf() {
      final symbol = scene.symbols.firstWhere((s) => s.designator == 'SW-1');
      final middle = symbol.bodyRect.left + symbol.bodyRect.width / 2;
      final low = <String>[];
      final high = <String>[];
      for (final wire in layer.wires) {
        final ends = scene.netLabels
            .where((l) => l.linkId == wire.linkId)
            .toList();
        for (var i = 0; i < ends.length; i++) {
          if (ends[i].deviceId != symbol.id) continue;
          final pin = ends[i].pinCentre;
          final escape =
              (wire.ends[i].x - pin.x).abs() + (wire.ends[i].y - pin.y).abs();
          (pin.x < middle ? low : high).add(escape.toStringAsFixed(4));
        }
      }
      return (low, high);
    }

    test('every pin in one half of an edge gets a corridor of its own', () {
      // ── THE ASSERTION INVERTED, AND THE REASON IS ON THE OTHER SIDE ──
      // This required AT MOST SIX corridors, because an unbounded comb
      // "walked off the top of the sheet". That was true when it was
      // written: the ground was sized from the label scene and did not
      // know the wires existed. It does now (`DrawnWireLayer.inkBounds`),
      // so a taller comb grows the paper under it instead of running off
      // the edge — and what the cap bought in the meantime was FOUR cables
      // per corridor. Cables sharing a corridor share the long run out of
      // the symbol too, so a 24-cable edge drew six lines. The field
      // reported it, and collinear wires are not something hue and dash
      // can separate.
      final (low, high) = escapesByHalf();
      expect(
        low.length + high.length,
        layer.wires.length,
        reason: 'every cable must have exactly one end on SW-1',
      );
      expect(
        low.length,
        greaterThan(1),
        reason: 'the fixture must wire BOTH halves of the edge or the '
            'mirroring test below is vacuous and this one is half a test',
      );
      expect(high.length, greaterThan(1), reason: 'as above, other half');
      expect(
        low.toSet().length,
        low.length,
        reason: '${low.length} cables leave the near half sharing only '
            '${low.toSet().length} corridors, so some are drawn on one line',
      );
      expect(
        high.toSet().length,
        high.length,
        reason: '${high.length} cables leave the far half sharing only '
            '${high.toSet().length} corridors, so some are drawn on one line',
      );
    });

    test('and the two halves MIRROR, so the comb climbs half the edge', () {
      // The bound is no longer a ceiling on the count. It is that the two
      // halves leave in OPPOSITE directions (`_prefersLowLane`), so their
      // runs are on opposite sides of the body and can reuse one set of
      // heights: 48 cables climb 24 corridors, not 48.
      //
      // ASSERTED AS SET EQUALITY, which is the strongest form available and
      // the one that cannot be satisfied by accident — two halves that
      // merely happened to climb the same DISTANCE would still fail it.
      final (low, high) = escapesByHalf();
      expect(
        low.toSet(),
        high.toSet(),
        reason: 'the halves climb different corridors, so the comb is '
            'twice as tall as it needs to be',
      );
      // AND IT REALLY DOES CLIMB — a comb collapsed to one lane satisfies
      // nothing above but is worth ruling out where the heights are in hand.
      final runs = low.map(double.parse).toList()..sort();
      expect(runs.last, greaterThan(runs.first));
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
