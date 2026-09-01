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
// AND ABOUT ITS INK, which is the third thing and the one added last.
// Group 1 counted CORRIDORS for two revisions of the comb, and a count is
// a proxy: the second revision satisfied it per half of the edge while the
// sheet drew 24 doubled cables, because wires do not know about halves.
// Measuring the overlap between the drawn segments themselves is the
// assertion that cannot be satisfied by a rule that merely sounds right.
//
// ═════════════════════════════════════════════════════════════════════
// N03 IS THE SYMBOL, BECAUSE THE DEFECT NEEDS A WIDE EDGE
// ═════════════════════════════════════════════════════════════════════
// 48 net ports on one edge. Below about seven the comb never reaches its
// ceiling and an uncapped version is indistinguishable from a capped one —
// the same reason `net_label_layer_test`'s two-pin fixture could not see
// the label comb climb, recorded in `net_label_comb_test.dart`'s header.

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'schematic_test_document.dart';

final _when = DateTime.utc(2026, 8, 3);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _a = Uuid('dev-a');
const _b = Uuid('dev-b');

/// Two N03 switches, `wired` cables between their top edges pin for pin —
/// or, with [crossed], pin 01 to pin 48 and pin 02 to pin 47.
({RackDocument doc, int topPortCount}) _fixture({
  required int wired,
  bool crossed = false,
}) {
  final body = buildSeedCatalog()['N03']!;
  // OPTED OUT OF CR-103's COLLAPSE, for the reason this file's own test
  // names say out loud: "the midpoint rule would put all 48 on one" and
  // "the layer emits one trace and two pill ops per end". Collapsed, N03's
  // two 24-port banks draw one vector pin each, so there are four ends
  // rather than forty-eight and the corridor rule is never exercised.
  // `#801` did not change wire tracing; it changed how many pins this
  // fixture has. See `schematic_test_document.dart`'s note.
  for (final bank in body.banks) {
    bank.collapseInSymbol = false;
  }
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
    final far = PortKey(topKeys[crossed ? wired - 1 - n : n]);
    final pa = derivePortId(_a, key);
    final pb = derivePortId(_b, far);
    for (final (dev, pid, k) in <(Uuid, Uuid, PortKey)>[
      (_a, pa, key),
      (_b, pb, far),
    ]) {
      doc.ports[pid] = Port(
        id: pid,
        deviceId: dev,
        designator: 'J${n + 1}',
        templatePortKey: k,
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
      reason:
          'the catalog changed; this fixture needs an edge wide enough '
          'for a comb to have somewhere to go wrong, and below about seven '
          'cables every rule this file has ever held looks alike',
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

  group('1 — no two cables are drawn along one line', () {
    /// Every cable's escape distance at SW-1. The escape IS the comb
    /// offset, so this is the comb read back off the shipped layer.
    List<String> escapes() {
      final symbol = scene.symbols.firstWhere((s) => s.designator == 'SW-1');
      final out = <String>[];
      for (final wire in layer.wires) {
        final ends = scene.netLabels
            .where((l) => l.linkId == wire.linkId)
            .toList();
        for (var i = 0; i < ends.length; i++) {
          if (ends[i].deviceId != symbol.id) continue;
          final pin = ends[i].pinCentre;
          out.add(
            ((wire.ends[i].x - pin.x).abs() + (wire.ends[i].y - pin.y).abs())
                .toStringAsFixed(4),
          );
        }
      }
      return out;
    }

    test('every pin on an edge gets a corridor of its own', () {
      // ── THIS ASSERTION HAS NOW BEEN WRONG TWICE, IN OPPOSITE WAYS ────
      // FIRST it required AT MOST SIX corridors, because an unbounded comb
      // "walked off the top of the sheet". That was true when written: the
      // ground was sized from the label scene and did not know the wires
      // existed. It does now (`DrawnWireLayer.inkBounds`), so a taller comb
      // grows the paper under it — and what the cap bought meanwhile was
      // four cables per corridor.
      //
      // THEN it required the two halves of the edge to reuse ONE set of
      // heights, on the argument that `_prefersLowLane` sends them round
      // opposite sides of the body. That is true of the detour's side lane
      // and false of the ordinary staircase, which is what almost every
      // cable takes — so the assertion was enforcing the very collinearity
      // it was written to forbid, and the group below is what caught it.
      final all = escapes();
      expect(
        all.length,
        layer.wires.length,
        reason: 'every cable must have exactly one end on SW-1',
      );
      expect(
        all.toSet().length,
        all.length,
        reason:
            '${all.length} cables leave SW-1 sharing only '
            '${all.toSet().length} corridors, so some are drawn on one line',
      );
      // AND THE COMB REALLY DOES CLIMB — 48 identical escapes would fail
      // the line above, but a fixture that somehow produced one lane per
      // cable at one height would not, and is worth ruling out where the
      // heights are already in hand.
      final runs = all.map(double.parse).toList()..sort();
      expect(runs.last, greaterThan(runs.first));
    });

    test('and NO cable shares ink with another, which is the property the '
        'corridor count is only a proxy for', () {
      // ── WHAT THE FIELD ACTUALLY SEES ────────────────────────────
      // Distinct corridors is the mechanism; two wires never drawn along
      // one line is the thing being bought, and the two came apart once
      // already. The mirrored comb gave every pin a corridor "of its own"
      // WITHIN its half and the sheet still drew 24 doubled cables,
      // because the test above was counting per half and the wires do not
      // know about halves.
      //
      // So this measures the drawing: total length of collinear overlap
      // between the segments of any two different wires. Zero, on a
      // fixture of 48 cables leaving one edge — which is the densest thing
      // the seed catalog can build and the shape of the screenshot.
      double overlap(DPt a1, DPt a2, DPt b1, DPt b2) {
        double lo(double x, double y) => x < y ? x : y;
        double hi(double x, double y) => x > y ? x : y;
        final along = a1.y == a2.y && b1.y == b2.y && a1.y == b1.y;
        final down = a1.x == a2.x && b1.x == b2.x && a1.x == b1.x;
        if (!along && !down) return 0;
        final (pa, pb, qa, qb) = along
            ? (a1.x, a2.x, b1.x, b2.x)
            : (a1.y, a2.y, b1.y, b2.y);
        final left = hi(lo(pa, pb), lo(qa, qb));
        final right = lo(hi(pa, pb), hi(qa, qb));
        return right > left ? right - left : 0;
      }

      var doubled = 0.0;
      final worst = <String>[];
      for (var i = 0; i < layer.wires.length; i++) {
        for (var j = i + 1; j < layer.wires.length; j++) {
          final a = layer.wires[i].points;
          final b = layer.wires[j].points;
          var here = 0.0;
          for (var m = 1; m < a.length; m++) {
            for (var n = 1; n < b.length; n++) {
              here += overlap(a[m - 1], a[m], b[n - 1], b[n]);
            }
          }
          if (here <= 0) continue;
          doubled += here;
          if (worst.length < 5) {
            worst.add(
              '${doc.links[layer.wires[i].linkId]!.designator}/'
              '${doc.links[layer.wires[j].linkId]!.designator} '
              '${here.toStringAsFixed(0)}',
            );
          }
        }
      }
      expect(
        doubled,
        0,
        reason:
            'cables are drawn along each other for '
            '${doubled.toStringAsFixed(0)} units: ${worst.join(', ')}',
      );
    });
  });

  group('1b — a CROSSED patch does not collapse onto one corridor', () {
    // ── THE CASE THE COMB CHANGE COULD HAVE REINTRODUCED ────────────
    // Port 01 to port 48, port 02 to port 47 — a panel patched in reverse,
    // which every install has somewhere. One corridor per pin means the
    // two ends of such a cable sit at OPPOSITE ends of the comb, so their
    // escape distances always ADD UP to the same total. A corridor placed
    // at the midpoint of the two escapes therefore lands in the same place
    // for all 48, and the sheet draws one line.
    //
    // The mirrored comb this replaced happened to be immune, because it
    // gave both ends of a crossed cable the SAME index — so this fixture
    // could not have found the defect before the comb changed, and it is
    // added with the comb rather than with the corridor rule for that
    // reason.
    late DrawnWireLayer crossed;
    setUpAll(() {
      final f = _fixture(wired: 48, crossed: true);
      crossed = buildDrawnWireLayer(
        scene: buildSchematicScene(doc: f.doc, measurer: const FakeMeasurer()),
        doc: f.doc,
        linkIds: f.doc.links.keys.toSet(),
        measurer: const FakeMeasurer(),
        palette: const SchematicPalette(),
      );
    });

    test('no corridor carries more than two cables, and the midpoint rule '
        'would put all 48 on one', () {
      // ── COUNTED OFF THE HORIZONTAL RUNS, NOT OFF THE TOPMOST POINT ──
      // The first version of this test keyed on each route's lowest y and
      // the midpoint mutation survived it, because a midpoint route still
      // reaches its far ESCAPE — it just doubles back afterwards. The
      // topmost point was therefore distinct per cable while all 48 long
      // runs sat on one row. What overlaps is the run, so the run is what
      // gets counted.
      final carried = <String, int>{};
      for (final wire in crossed.wires) {
        for (var i = 1; i < wire.points.length; i++) {
          if (wire.points[i].y != wire.points[i - 1].y) continue;
          final row = wire.points[i].y.toStringAsFixed(4);
          carried[row] = (carried[row] ?? 0) + 1;
        }
      }
      expect(crossed.wires, hasLength(48));
      final busiest = carried.values.reduce((a, b) => a > b ? a : b);
      expect(
        busiest,
        lessThanOrEqualTo(2),
        reason: 'one corridor carries $busiest of the 48 cables: $carried',
      );
      // TWO IS THE HONEST ANSWER, NOT ONE, and saying so here is better
      // than letting a reader assume the bound is tight. Cable n and cable
      // 47−n are mirror images in every quantity a per-link router is
      // allowed to see — same pair of escape distances, same pair of
      // bodies, opposite pins — so nothing this file may consult can put
      // them on different rows. Separating them is channel allocation,
      // which canon §11.1.3 defers to v1.2.
      expect(
        carried.values.where((n) => n > 1),
        isNotEmpty,
        reason:
            'the pairing stopped being symmetric, so this group is no '
            'longer testing the case it was built for',
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
        reason:
            'op $lastTrace is a trace and op $firstPill is a pill — a '
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
          reason:
              '0x${argb.toRadixString(16)} is translucent; a wire under '
              'the flag body still shows through it',
        );
      }
      final hue = layer.wires.first.style.argb;
      expect(
        fills,
        isNot(contains(hue)),
        reason:
            'an opaque fill at the FULL domain hue would be a solid '
            'blob, not the 12% tint of docs/05 §11.5 against paper',
      );
    });
  });
}
