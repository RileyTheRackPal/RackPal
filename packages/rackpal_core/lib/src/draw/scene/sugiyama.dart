// rackpal_core/src/draw/scene/sugiyama.dart — pure Dart.
//
// Sugiyama phases 0–3 — cycle-break, layer assignment, barycentre ordering,
// coordinate assignment — over an abstract graph. It PLACES SYMBOLS and
// nothing else (docs/05-schematic-editor.md §10.2, canon §11.1.3's
// "what explicitly does NOT leave v1 scope").
//
// ── WHAT THIS FILE DELIBERATELY DOES NOT CONTAIN (DR-001, canon §11.1.3) ─
// Phase 4's per-link orthogonal trace, interval-graph channel routing,
// track ordering, the Bentley–Ottmann crossing sweep, hop arcs and junction
// staggering. Four of those left v1 scope outright and the fifth (the
// trace) belongs to `drawn` mode, which is not this stage. Nothing here
// emits a wire, a polyline, a bend or a label. If a change to this file
// starts routing an edge, it has left the ruling behind — re-read canon
// §11.1 before continuing.
//
// ── THIS IS A REBUILD, NOT A RESTORATION ────────────────────────────────
// `rackpal_ui/canvas/schematic/sugiyama.dart` was deleted at `b560a50`
// because it was dead AND wrong, and two of its defects are the reason
// specific lines below look the way they do:
//   * its layer assignment iterated a `List` with `for-in` while calling
//     `queue.add()` inside the loop, so it threw `ConcurrentModificationError`
//     on any graph with an edge. Every traversal here is an INDEXED loop
//     over a list that is not grown while it is being read, or an explicit
//     stack — see [_orientEdges].
//   * its barycentre divided by `(layerNodes.length - 1)`, producing NaN
//     for a single-node layer and then sorting on NaN comparisons, which is
//     not even a total order. Here a node with no neighbours in the
//     reference layer keeps its current index — the divisor is the
//     NEIGHBOUR count and it is never zero when it is used. See
//     [_reorderLayer], and `sugiyama_test.dart`'s "a single-node layer does
//     not produce NaN and does not reorder".
//
// ── DETERMINISM IS THE EXIT CRITERION, NOT A QUALITY GOAL ───────────────
// docs/09 M2: "the schematic re-lays-out deterministically (same input ⇒
// byte-identical display list)". Three rules make that true here and each
// one is load-bearing:
//
//   1. THE INPUT IS CANONICALISED BEFORE ANYTHING READS IT. [layoutSugiyama]
//      sorts nodes by `(sortKey, id)` and edges by the resulting node
//      indices, so two callers that describe the SAME graph in different
//      insertion orders get byte-identical output. Without this, every
//      `Map`/`Set` below would still be deterministic — Dart's default maps
//      are insertion-ordered — but insertion order would be the caller's,
//      which is exactly the dependence the criterion forbids.
//   2. NOTHING ITERATES A HASH CONTAINER. Every loop walks a `List` by
//      index or an `Iterable` derived from one. The one `Map` — the id →
//      index lookup in [layoutSugiyama] — is read by key, never iterated,
//      and the one returned ([SugiyamaLayout.positions]) is documented as
//      a lookup with [SugiyamaLayout.layers] as its ordered view.
//   3. EVERY SORT COMPARATOR IS A TOTAL ORDER, terminating in the node's
//      canonical index. Dart's `List.sort` is NOT stable, so a comparator
//      that can return 0 for two distinct nodes leaves their relative order
//      to the sort's internals — deterministic in practice, unspecified by
//      the language, and silently input-order-dependent for small lists
//      (which use insertion sort). Ties are broken explicitly instead.
//
// There is NO randomness. The deleted file took a `Random(seed ?? 42)`; a
// layout that needs entropy cannot be a golden, and a wall-clock seed
// cannot be one twice.
//
// ── EVERYTHING IS INTEGER GRID UNITS ────────────────────────────────────
// Positions in and out are `Pt{gx, gy}` — the model's INTEGER schematic
// grid (CR-004: "no sub-grid, no sx/sy, no free positioning"), which is
// also what `SheetItem.position` persists (CR-012 persists symbol
// placement, never route geometry). Barycentres are computed in `double`
// and rounded once, at [_roundNearest]; no coordinate ever leaves this file
// as a float, so accumulated rounding cannot exist.
//
// ── WHERE THIS FILE LIVES, AND THE ONE PLACE THE CORPUS DISAGREES ───────
// docs/03-architecture.md §3.1's source tree names
// `rackpal_core/lib/src/routing/sugiyama.dart`. It is here under
// `draw/scene/` instead, beside `symbol_layer.dart` and
// `symbol_hit_test.dart`, which the salvage relocated for CR-071/CR-086's
// reason: the schematic cannot be a widget-only artifact if it is to print.
// Both locations satisfy the property the rulings actually protect — this
// is `rackpal_core`, so `rackpal_export` can drive it without ever seeing
// `rackpal_ui`. The disagreement is recorded rather than resolved: if
// §3.1's tree is normative, this file and `schematic_scene.dart` move
// together and nothing else changes.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/units/pt.dart';

/// Where a node's layer is pinned by a RULE rather than by the graph.
///
/// docs/05 §10.2 phase 1 names exactly two such rules — the Structure
/// device is forced to layer 0, or to layer N when
/// `StructureBody.sheetEdge == right` (CR-072); off-rack destinations are
/// forced to the final layer. Both are expressed here as an anchor so this
/// file needs to know nothing about racks, structures or placements.
enum LayerAnchor {
  /// The graph decides — longest-path layering, unconstrained.
  none,

  /// Forced to layer 0, the left edge of the sheet.
  first,

  /// Forced to the last layer, the right edge of the sheet.
  ///
  /// UNCONDITIONAL. Whether a given device DESERVES the last layer — docs/05
  /// §10.2 phase 1 says "off-rack DESTINATIONS", and a wall plate that feeds
  /// a projector is not one — is a question about racks and links, which
  /// this file knows nothing about. `schematic_scene.dart` answers it and
  /// hands down the decision.
  last,
}

/// One symbol to place.
///
/// [widthGu] / [heightGu] are the symbol's own extent in grid units, and
/// the caller must compute them from the SAME formulas the symbol layer
/// draws with, or the layout will reserve a box the drawing does not fit
/// in. `schematic_scene.dart` derives both once and hands them to both
/// sides, which is what stops the two drifting.
@immutable
final class LayoutNode {
  const LayoutNode({
    required this.id,
    required this.sortKey,
    required this.widthGu,
    required this.heightGu,
    this.anchor = LayerAnchor.none,
    this.pinnedAt,
  });

  /// Stable identity — a device `Uuid.v` in practice. Also the final
  /// tie-break in every comparator here, so it must be unique.
  final String id;

  /// The total order that SEEDS phase 2 and BREAKS EVERY TIE in it
  /// (docs/05 §10.2: "Initial order and final tie-break are `ruIndex`, then
  /// UUID"). Opaque to this file: it is compared, never parsed.
  final String sortKey;

  final int widthGu;
  final int heightGu;
  final LayerAnchor anchor;

  /// The user's own placement, when they have made one (`SheetItem.pinned`,
  /// CR-068: "auto-layout never moves a pinned symbol"). Non-null means
  /// THIS EXACT `Pt` is the output — the node still takes part in layering
  /// and ordering so unpinned symbols arrange themselves around it, but no
  /// phase may move it.
  final Pt? pinnedAt;
}

/// One directed signal edge — a `Link`, in practice.
///
/// Direction is the caller's statement, not an inference: a `Link`'s
/// direction is `Conductor.from → Conductor.to`, which the schematic's own
/// `Reverse direction` gesture (docs/05 §9) exists to flip. This file never
/// second-guesses it.
@immutable
final class LayoutEdge {
  const LayoutEdge({
    required this.id,
    required this.from,
    required this.to,
    this.preferReversed = false,
  });

  /// Stable identity — a link `Uuid.v` in practice. Reported back in
  /// [SugiyamaLayout.reversedEdgeIds].
  final String id;

  final String from;
  final String to;

  /// docs/05 §10.2 phase 0: "bias the heuristic to reverse edges whose
  /// family declares a return channel". An eARC run from a display back to
  /// the AVR is the cycle in a real house, and it is the edge whose
  /// reversal costs the reader nothing — the forward HDMI path is the one
  /// they follow. See [_orientEdges] for how the bias is made exact rather
  /// than probabilistic.
  final bool preferReversed;
}

/// The knobs docs/05 §10.2 leaves to the implementation.
///
/// The two spacings are STATED CHOICES, not citations: §10 fixes the
/// pipeline and §3 fixes the symbol, but no document in the corpus gives a
/// gutter or a row gap. They are expressed in grid units so they scale with
/// `kGridUnit` (CR-004) rather than with whatever the sheet is scaled to.
@immutable
final class SugiyamaParams {
  const SugiyamaParams({
    this.layerGutterGu = 12,
    this.nodeGapGu = 4,
    this.maxOrderingSweeps = 8,
    this.priorityIterations = 3,
  });

  /// Clear space between one layer's widest symbol and the next layer's
  /// left edge — 12 gu = 30 mm. This is the empty vertical channel docs/05
  /// §10.1 says the layering buys, and the reason a v1.2 channel router
  /// would have somewhere to put its tracks.
  final int layerGutterGu;

  /// Clear space between two symbols stacked in one layer — 4 gu = 10 mm.
  final int nodeGapGu;

  /// docs/05 §10.2 phase 2: "forward and backward until crossings stop
  /// decreasing, capped at 8 iterations".
  final int maxOrderingSweeps;

  /// docs/05 §10.2 phase 3: "Sugiyama's priority method, 3 iterations".
  final int priorityIterations;
}

/// The output of [layoutSugiyama].
@immutable
final class SugiyamaLayout {
  const SugiyamaLayout({
    required this.positions,
    required this.layers,
    required this.reversedEdgeIds,
    required this.nonForwardEdgeIds,
    required this.crossings,
    required this.dummyCount,
  });

  /// Every node's top-left corner, in integer grid units.
  ///
  /// Looked up, never iterated — see the file header's determinism rule 2.
  /// [layers] is the ordered view.
  final Map<String, Pt> positions;

  /// Node ids by layer, each layer in its final top-to-bottom order.
  /// Dummy nodes are not in here; they exist only inside the algorithm.
  final List<List<String>> layers;

  /// Edges phase 0 turned around to break a cycle, in canonical edge
  /// order. docs/05 §10.2: "Reversed edges are flagged and still render
  /// their arrowhead at the true sink" — this is that flag, and the
  /// renderer that consumes it is M2-D's.
  final List<String> reversedEdgeIds;

  /// Edges that do NOT run left-to-right in the final layering, because a
  /// rule or a pin overrode the graph — an in-edge to a Structure device
  /// forced to layer 0 (CR-072), or any edge touching a symbol the user
  /// pinned (CR-068).
  ///
  /// REPORTED RATHER THAN PREVENTED, and not an error: both overrides are
  /// deliberate, and a drawing that honoured the graph instead would be
  /// moving a symbol the user placed. They are excluded from crossing
  /// minimisation (they have no gutter to cross) and named here so a
  /// caller can say so rather than a reader wondering why one arrow points
  /// backwards.
  final List<String> nonForwardEdgeIds;

  /// Edge crossings in the chosen ordering, counted over the proper
  /// layering (dummies included). Phase 2's own objective, exposed because
  /// it is the only honest way to test that phase 2 does anything.
  final int crossings;

  /// How many dummy nodes the proper layering needed — one per layer an
  /// edge spans beyond the first.
  final int dummyCount;

  int get layerCount => layers.length;
}

/// Runs Sugiyama phases 0–3 over [nodes] and [edges].
///
/// Pure and total: no I/O, no clock, no randomness, no throwing. An edge
/// naming a node that is not in [nodes], and an edge whose two ends are the
/// same node, are DROPPED — a self-link is a loop-through cable, a real
/// thing to draw and a thing that can say nothing about layering, and an
/// edge into a device that has no symbol has nowhere to land. Neither is an
/// error and neither may take the layout down.
///
/// Parallel edges are KEPT and counted twice in every barycentre. Two HDMI
/// runs between the same pair of devices are two cables; a layout that
/// collapsed them would pull the pair together less than the wiring says.
SugiyamaLayout layoutSugiyama({
  required Iterable<LayoutNode> nodes,
  required Iterable<LayoutEdge> edges,
  SugiyamaParams params = const SugiyamaParams(),
}) {
  // ── canonicalisation — determinism rule 1 (see the file header) ───────
  final ordered = nodes.toList()
    ..sort((a, b) {
      final byKey = a.sortKey.compareTo(b.sortKey);
      return byKey != 0 ? byKey : a.id.compareTo(b.id);
    });
  final n = ordered.length;
  if (n == 0) {
    return const SugiyamaLayout(
      positions: <String, Pt>{},
      layers: <List<String>>[],
      reversedEdgeIds: <String>[],
      nonForwardEdgeIds: <String>[],
      crossings: 0,
      dummyCount: 0,
    );
  }

  final index = <String, int>{};
  for (var i = 0; i < n; i++) {
    index[ordered[i].id] = i;
  }

  final kept = <_Edge>[];
  for (final e in edges) {
    final from = index[e.from];
    final to = index[e.to];
    if (from == null || to == null || from == to) continue;
    kept.add(_Edge(e.id, from, to, preferReversed: e.preferReversed));
  }
  kept.sort((a, b) {
    final byFrom = a.from.compareTo(b.from);
    if (byFrom != 0) return byFrom;
    final byTo = a.to.compareTo(b.to);
    return byTo != 0 ? byTo : a.id.compareTo(b.id);
  });

  // ── phase 0 ──────────────────────────────────────────────────────────
  final oriented = _orientEdges(n, kept);

  // ── phase 1 ──────────────────────────────────────────────────────────
  final layerPitch = _layerPitch(ordered, params);
  final layerOf = _assignLayers(ordered, oriented, layerPitch);
  final layerCount = layerOf.reduce((a, b) => a > b ? a : b) + 1;

  // ── proper layering: one dummy per intermediate layer ────────────────
  final proper = _makeProper(ordered, oriented, layerOf, layerCount);

  // ── phase 2 ──────────────────────────────────────────────────────────
  final crossings = _orderLayers(proper, params);

  // ── phase 3 ──────────────────────────────────────────────────────────
  _assignCoordinates(proper, params);

  // ── result, assembled in canonical order ─────────────────────────────
  final positions = <String, Pt>{};
  final layers = <List<String>>[];
  for (var l = 0; l < layerCount; l++) {
    final ids = <String>[];
    for (final v in proper.layers[l]) {
      if (v >= n) continue; // dummy
      final node = ordered[v];
      final pinned = node.pinnedAt;
      positions[node.id] = pinned ?? Pt(layerOf[v] * layerPitch, proper.y[v]);
      ids.add(node.id);
    }
    layers.add(List<String>.unmodifiable(ids));
  }

  return SugiyamaLayout(
    positions: Map<String, Pt>.unmodifiable(positions),
    layers: List<List<String>>.unmodifiable(layers),
    reversedEdgeIds: List<String>.unmodifiable(oriented.reversedIds),
    nonForwardEdgeIds: List<String>.unmodifiable(proper.nonForwardIds),
    crossings: crossings,
    dummyCount: proper.total - n,
  );
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 0 — CYCLE BREAKING
// ═══════════════════════════════════════════════════════════════════════

/// An edge in internal (index) form.
@immutable
final class _Edge {
  const _Edge(this.id, this.from, this.to, {required this.preferReversed});

  final String id;
  final int from;
  final int to;
  final bool preferReversed;
}

/// The DAG phase 0 produced, plus which edges it had to turn around.
final class _Oriented {
  _Oriented(this.edges, this.reversedIds, this.topological);

  /// Every edge, in canonical order, oriented so the graph is acyclic.
  final List<_Edge> edges;

  final List<String> reversedIds;

  /// A topological order of [edges] — node indices, sources first. Every
  /// edge runs from an earlier entry to a later one.
  final List<int> topological;
}

/// Orients [edges] into a DAG, preferring to reverse return-channel edges.
///
/// ── WHY TWO PASSES INSTEAD OF ONE BIASED DFS ────────────────────────────
/// The textbook heuristic runs one DFS and reverses every back edge, and it
/// gives no way to say WHICH edge of a cycle should be the one turned
/// around — the answer falls out of the visitation order. docs/05 §10.2
/// asks for a specific preference ("bias the heuristic to reverse edges
/// whose family declares a return channel"), and biasing the edge order
/// inside a single DFS does not deliver it: an AVR↔display pair reached
/// from the display first reverses the HDMI edge, which is precisely the
/// arrow the reader is following.
///
/// So the return channels are held back:
///
///   1. DFS over the FORWARD edges only, reversing back edges. The result
///      is a DAG over the forward signal graph and a topological order of
///      it (reverse finishing order — the classical result: after
///      reversing back edges every edge runs from a higher finishing time
///      to a lower one).
///   2. Every return-channel edge is then measured against that order and
///      reversed only if it runs backwards in it.
///
/// Step 2 cannot introduce a cycle: after it, EVERY edge runs from a lower
/// rank to a higher one in a single total order, which is the definition of
/// a DAG. So the bias is exact rather than probabilistic — a return-channel
/// edge is reversed exactly when the forward signal path already says it
/// closes a loop — and acyclicity is a proof rather than a hope.
///
/// The DFS is iterative. A recursive one would be shorter and would blow
/// the stack on a long daisy chain of 70 V speaker taps; more to the point,
/// the deleted implementation's crash was a traversal that mutated the
/// collection it was walking, and an explicit stack makes what is being
/// mutated visible.
_Oriented _orientEdges(int n, List<_Edge> edges) {
  // Out-adjacency over FORWARD edges only, as index lists built once and
  // never grown afterwards.
  final out = List<List<int>>.generate(n, (_) => <int>[], growable: false);
  for (var i = 0; i < edges.length; i++) {
    if (!edges[i].preferReversed) out[edges[i].from].add(i);
  }

  const white = 0;
  const grey = 1;
  const black = 2;
  final colour = List<int>.filled(n, white);
  final reversed = List<bool>.filled(edges.length, false);
  final finished = <int>[];

  final stack = <int>[];
  final cursor = <int>[];
  // Roots in canonical order — the first device in rack order is where the
  // walk starts, so of a two-cycle it is the LATER edge that closes back on
  // the stack and gets turned around. Deterministic either way; this way it
  // is also explicable to someone reading the drawing.
  for (var s = 0; s < n; s++) {
    if (colour[s] != white) continue;
    colour[s] = grey;
    stack.add(s);
    cursor.add(0);
    while (stack.isNotEmpty) {
      final v = stack.last;
      final top = cursor.length - 1;
      final outs = out[v];
      if (cursor[top] < outs.length) {
        final e = outs[cursor[top]];
        cursor[top] += 1;
        final w = edges[e].to;
        if (colour[w] == grey) {
          // A back edge: it closes a cycle through the DFS stack.
          reversed[e] = true;
        } else if (colour[w] == white) {
          colour[w] = grey;
          stack.add(w);
          cursor.add(0);
        }
        // black => a forward or cross edge; it already runs the right way.
      } else {
        colour[v] = black;
        finished.add(v);
        stack.removeLast();
        cursor.removeLast();
      }
    }
  }

  // Reverse finishing order is a topological order of the forward DAG.
  final topological = List<int>.filled(n, 0);
  final rank = List<int>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final v = finished[n - 1 - i];
    topological[i] = v;
    rank[v] = i;
  }

  // Step 2: the return channels, measured against that order.
  for (var i = 0; i < edges.length; i++) {
    final e = edges[i];
    if (!e.preferReversed) continue;
    if (rank[e.from] > rank[e.to]) reversed[i] = true;
  }

  final result = <_Edge>[];
  final reversedIds = <String>[];
  for (var i = 0; i < edges.length; i++) {
    final e = edges[i];
    if (reversed[i]) {
      reversedIds.add(e.id);
      result.add(_Edge(e.id, e.to, e.from, preferReversed: e.preferReversed));
    } else {
      result.add(e);
    }
  }
  return _Oriented(result, reversedIds, topological);
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 1 — LAYER ASSIGNMENT
// ═══════════════════════════════════════════════════════════════════════

/// Grid units between the left edges of two adjacent layers.
///
/// ONE PITCH FOR THE WHOLE SHEET, sized by the widest symbol in it. A
/// per-layer pitch would give tighter gutters, and it would also make
/// "the layer nearest a pinned symbol's `gx`" (docs/05 §10.2 phase 1)
/// circular: the pinned node's layer would depend on the layer widths,
/// which depend on which layer it landed in. A uniform pitch turns that
/// rule into a division. The cost is that one wide symbol widens every
/// gutter, which is a legible drawing rather than a wrong one.
int _layerPitch(List<LayoutNode> nodes, SugiyamaParams params) {
  var widest = 0;
  for (var i = 0; i < nodes.length; i++) {
    final w = nodes[i].widthGu;
    if (w > widest) widest = w;
  }
  // Never zero: a zero pitch would stack every layer on the origin and
  // make the pinned-node division below a divide-by-zero.
  final pitch = widest + params.layerGutterGu;
  return pitch > 0 ? pitch : 1;
}

/// Longest-path layering, then the three rules that override it.
///
/// docs/05 §10.2 phase 1 states the rules and this states their PRECEDENCE,
/// which it does not:
///
///   1. The graph — longest-path layering over the DAG.
///   2. [LayerAnchor.first] — the Structure device at the left edge
///      (CR-072). Applied, then the whole graph relaxed forward again so
///      its successors move right rather than being crossed.
///   3. [LayerAnchor.last] — off-rack destinations, and a right-edge
///      Structure, at the final layer. Unconditional here; which devices
///      qualify is `schematic_scene.dart`'s call.
///   4. A PINNED symbol beats all three (CR-068). It is the user's own
///      placement and no phase here may move it.
///
/// Rules 2–4 can leave an edge pointing leftwards. That is reported by
/// [SugiyamaLayout.nonForwardEdgeIds], never silently repaired, because
/// repairing it would mean moving the symbol the rule just placed.
List<int> _assignLayers(
  List<LayoutNode> nodes,
  _Oriented oriented,
  int layerPitch,
) {
  final n = nodes.length;
  final layer = List<int>.filled(n, 0);

  // The out-adjacency used twice below — built once, never grown while
  // being read.
  final out = List<List<int>>.generate(n, (_) => <int>[], growable: false);
  for (var i = 0; i < oriented.edges.length; i++) {
    out[oriented.edges[i].from].add(i);
  }

  // [frozen] nodes are never pushed right by the relaxation. It is the
  // whole of what "forced to layer 0" means: without it the repair pass
  // below would immediately undo the anchor, because a Structure device
  // with ANY in-edge is exactly the case the anchor exists for.
  void relaxForward(List<bool>? frozen) {
    for (var i = 0; i < n; i++) {
      final v = oriented.topological[i];
      final outs = out[v];
      for (var j = 0; j < outs.length; j++) {
        final w = oriented.edges[outs[j]].to;
        if (frozen != null && frozen[w]) continue;
        final candidate = layer[v] + 1;
        if (candidate > layer[w]) layer[w] = candidate;
      }
    }
  }

  relaxForward(null);

  final anchoredFirst = List<bool>.filled(n, false);
  var forced = false;
  for (var v = 0; v < n; v++) {
    if (nodes[v].anchor == LayerAnchor.first) {
      anchoredFirst[v] = true;
      if (layer[v] != 0) {
        layer[v] = 0;
        forced = true;
      }
    }
  }
  if (forced) relaxForward(anchoredFirst);

  var last = 0;
  for (var v = 0; v < n; v++) {
    if (layer[v] > last) last = layer[v];
  }

  for (var v = 0; v < n; v++) {
    if (nodes[v].anchor == LayerAnchor.last) layer[v] = last;
  }

  for (var v = 0; v < n; v++) {
    final pinned = nodes[v].pinnedAt;
    if (pinned == null) continue;
    final nearest = _roundNearest(pinned.gx / layerPitch);
    layer[v] = nearest < 0 ? 0 : (nearest > last ? last : nearest);
  }

  return layer;
}

// ═══════════════════════════════════════════════════════════════════════
// PROPER LAYERING — dummy nodes
// ═══════════════════════════════════════════════════════════════════════

/// The working graph phases 2 and 3 operate on: real nodes 0..n-1 plus
/// dummy nodes n..total-1, every edge spanning exactly one gutter.
final class _Proper {
  _Proper({
    required this.total,
    required this.orderKey,
    required this.height,
    required this.pinnedY,
    required this.layers,
    required this.up,
    required this.down,
    required this.nonForwardIds,
  }) : y = List<int>.filled(total, 0),
       position = List<int>.filled(total, 0);

  final int total;

  /// The total order that seeds phase 2 and terminates every tie-break in
  /// phases 2 and 3.
  final List<String> orderKey;

  final List<int> height;

  /// The fixed y of a pinned node, or null. Phases 2 and 3 may never write
  /// [y] for one of these.
  final List<int?> pinnedY;

  final List<List<int>> layers;
  final List<List<int>> up;
  final List<List<int>> down;
  final List<String> nonForwardIds;

  final List<int> y;
  final List<int> position;
}

/// Splits every edge spanning more than one gutter into a chain of dummy
/// nodes, one per intermediate layer.
///
/// ── A DELIBERATE DEVIATION FROM docs/05 §10.2, FLAGGED ──────────────────
/// §10.2 puts this sentence in PHASE 3 ("Insert dummy nodes for every edge
/// spanning more than one layer, so that every edge crosses exactly one
/// gutter"). It happens here instead, between phases 1 and 2, and the
/// reason is that phase 2 is a crossing-minimisation pass: a long edge with
/// no dummies is invisible to it, so it would minimise crossings on a graph
/// that is not the one being drawn and report a crossing count that is not
/// the one on the sheet. The stated PURPOSE of the sentence — every edge
/// crosses exactly one gutter — is met either way. This is the standard
/// ordering of the algorithm and it is called out rather than assumed.
_Proper _makeProper(
  List<LayoutNode> nodes,
  _Oriented oriented,
  List<int> layerOf,
  int layerCount,
) {
  final n = nodes.length;
  final layerIndex = <int>[...layerOf];
  final orderKey = <String>[];
  final height = <int>[];
  final pinnedY = <int?>[];
  for (var v = 0; v < n; v++) {
    // '0' buckets real nodes ahead of dummies at equal barycentre; the
    // node's own sortKey and id complete the total order.
    orderKey.add('0${nodes[v].sortKey}$_keyGap${nodes[v].id}');
    height.add(nodes[v].heightGu);
    pinnedY.add(nodes[v].pinnedAt?.gy);
  }

  final up = <List<int>>[];
  final down = <List<int>>[];
  for (var v = 0; v < n; v++) {
    up.add(<int>[]);
    down.add(<int>[]);
  }

  final nonForward = <String>[];
  for (var i = 0; i < oriented.edges.length; i++) {
    final e = oriented.edges[i];
    final span = layerIndex[e.to] - layerIndex[e.from];
    if (span <= 0) {
      // A rule or a pin overrode the graph — see [SugiyamaLayout.
      // nonForwardEdgeIds]. It has no single gutter to cross, so it takes
      // no part in crossing minimisation.
      nonForward.add(e.id);
      continue;
    }
    var previous = e.from;
    for (var l = layerIndex[e.from] + 1; l < layerIndex[e.to]; l++) {
      final d = orderKey.length;
      layerIndex.add(l);
      // '1' buckets dummies after real nodes; the edge's canonical index
      // and the chain step complete the total order.
      orderKey.add('1${_pad(i)}$_keyGap${_pad(l)}');
      height.add(0);
      pinnedY.add(null);
      up.add(<int>[]);
      down.add(<int>[]);
      down[previous].add(d);
      up[d].add(previous);
      previous = d;
    }
    down[previous].add(e.to);
    up[e.to].add(previous);
  }

  final total = orderKey.length;
  final layers = List<List<int>>.generate(
    layerCount,
    (_) => <int>[],
    growable: false,
  );
  for (var v = 0; v < total; v++) {
    layers[layerIndex[v]].add(v);
  }
  for (var l = 0; l < layerCount; l++) {
    layers[l].sort((a, b) => orderKey[a].compareTo(orderKey[b]));
  }

  final proper = _Proper(
    total: total,
    orderKey: orderKey,
    height: height,
    pinnedY: pinnedY,
    layers: layers,
    up: up,
    down: down,
    nonForwardIds: nonForward,
  );
  _reindex(proper);
  return proper;
}

String _pad(int v) => v.toString().padLeft(10, '0');

/// The separator between the two halves of an order key.
///
/// IT MUST SORT BELOW EVERY CHARACTER A `sortKey` OR AN ID CAN CONTAIN, or
/// one key becomes a prefix-collision of another: with `'|'` (0x7C),
/// `'z2' + sep + id` would sort AFTER `'z25' + sep + id`, because `'5'`
/// (0x35) is below `'|'` — so a device at U25 would jump ahead of one at
/// U2 in the initial rack order for no reason anybody could see in the
/// data. A space (0x20) is below every digit, letter, dash and dot, which
/// is everything a `FracIndex`, a UUID or a padded integer can produce.
const String _keyGap = ' ';

/// Refreshes `position[v]` — v's index inside its own layer — after any
/// reordering. Everything downstream reads positions, never list indices,
/// so this is the single point where the two are reconciled.
void _reindex(_Proper g) {
  for (var l = 0; l < g.layers.length; l++) {
    final row = g.layers[l];
    for (var i = 0; i < row.length; i++) {
      g.position[row[i]] = i;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 2 — WITHIN-LAYER ORDERING
// ═══════════════════════════════════════════════════════════════════════

/// Barycentre sweeps with a median tie-break, forward and backward until
/// the crossing count stops decreasing (docs/05 §10.2 phase 2). Returns the
/// crossing count of the ordering it leaves behind.
///
/// The best ordering seen is KEPT rather than the last one computed: a
/// sweep that makes things worse is what ends the loop, and stopping
/// without rolling it back would ship exactly that worse ordering.
int _orderLayers(_Proper g, SugiyamaParams params) {
  var best = <List<int>>[
    for (final row in g.layers) <int>[...row],
  ];
  var bestCrossings = _countCrossings(g);

  for (var sweep = 0; sweep < params.maxOrderingSweeps; sweep++) {
    for (var l = 1; l < g.layers.length; l++) {
      _reorderLayer(g, l, fromAbove: true);
    }
    for (var l = g.layers.length - 2; l >= 0; l--) {
      _reorderLayer(g, l, fromAbove: false);
    }
    final crossings = _countCrossings(g);
    if (crossings >= bestCrossings) break;
    bestCrossings = crossings;
    best = <List<int>>[
      for (final row in g.layers) <int>[...row],
    ];
  }

  for (var l = 0; l < g.layers.length; l++) {
    g.layers[l]
      ..clear()
      ..addAll(best[l]);
  }
  _reindex(g);
  return bestCrossings;
}

/// Reorders one layer by the barycentre of each node's neighbours in the
/// adjacent layer.
///
/// ── THE DIVISOR IS THE NEIGHBOUR COUNT, AND IT IS NEVER ZERO ────────────
/// The deleted implementation divided by `(layerNodes.length - 1)`, which
/// is zero for a single-node layer, and then sorted on the resulting NaN.
/// NaN comparisons are not even a weak order, so `sort` was free to produce
/// anything — including different results for the same input.
///
/// Here the divisor is `refs.length`, and a node with NO neighbours in the
/// reference layer never reaches the division: it keeps its CURRENT index
/// as its key, which is the standard treatment and means an isolated symbol
/// stays where the initial `ruIndex` order put it instead of migrating to
/// one end of the layer.
void _reorderLayer(_Proper g, int layer, {required bool fromAbove}) {
  final row = g.layers[layer];
  final bary = <double>[];
  final median = <double>[];

  for (var i = 0; i < row.length; i++) {
    final v = row[i];
    final refs = fromAbove ? g.up[v] : g.down[v];
    if (refs.isEmpty) {
      final here = g.position[v].toDouble();
      bary.add(here);
      median.add(here);
      continue;
    }
    final positions = <int>[for (final u in refs) g.position[u]]..sort();
    var sum = 0;
    for (var k = 0; k < positions.length; k++) {
      sum += positions[k];
    }
    bary.add(sum / positions.length);
    median.add(positions[positions.length ~/ 2].toDouble());
  }

  final keyed = List<int>.generate(row.length, (i) => i, growable: false)
    ..sort((a, b) {
      final byBary = bary[a].compareTo(bary[b]);
      if (byBary != 0) return byBary;
      final byMedian = median[a].compareTo(median[b]);
      if (byMedian != 0) return byMedian;
      // Rack order, then id. A total order — see determinism rule 3.
      return g.orderKey[row[a]].compareTo(g.orderKey[row[b]]);
    });

  final reordered = <int>[for (final i in keyed) row[i]];
  row
    ..clear()
    ..addAll(reordered);
  for (var i = 0; i < row.length; i++) {
    g.position[row[i]] = i;
  }
}

/// Total edge crossings over every adjacent layer pair.
///
/// Barth–Jünger–Mutzel: sort the inter-layer edges by their upper
/// endpoint's position and count inversions in the lower endpoints with a
/// Fenwick tree — `O(E log V)`. The obvious pairwise loop is `O(E²)` and
/// runs eight times per sweep on the commit path; at the 300-link fixture
/// that is the difference between a budget and an excuse.
int _countCrossings(_Proper g) {
  var total = 0;
  for (var l = 0; l + 1 < g.layers.length; l++) {
    final upper = g.layers[l];
    final lowerSize = g.layers[l + 1].length;
    if (lowerSize == 0) continue;

    // Edges in upper-position order, carrying the lower position.
    final targets = <int>[];
    for (var i = 0; i < upper.length; i++) {
      final v = upper[i];
      final outs = g.down[v];
      final ends = <int>[for (final w in outs) g.position[w]]..sort();
      targets.addAll(ends);
    }

    // Inversions among `targets` — each is one crossing.
    final tree = List<int>.filled(lowerSize + 1, 0);
    var seen = 0;
    for (var k = 0; k < targets.length; k++) {
      final t = targets[k] + 1;
      // Count already-inserted targets strictly greater than this one.
      var atOrBelow = 0;
      for (var i = t; i > 0; i -= i & -i) {
        atOrBelow += tree[i];
      }
      total += seen - atOrBelow;
      for (var i = t; i <= lowerSize; i += i & -i) {
        tree[i] += 1;
      }
      seen++;
    }
  }
  return total;
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 3 — COORDINATE ASSIGNMENT
// ═══════════════════════════════════════════════════════════════════════

/// Sugiyama's priority method, [SugiyamaParams.priorityIterations]
/// iterations, priority = degree (docs/05 §10.2 phase 3).
///
/// Coordinates are integer grid units throughout. A node's y is its TOP
/// edge; barycentres are computed on CENTRES, which is what makes a tall
/// symbol line up with a short one rather than with its own top corner.
///
/// PINNED SYMBOLS CONTRIBUTE FIXED COORDINATES AND ARE EXCLUDED FROM
/// RELAXATION — §10.2's own words, and CR-068's requirement. Every write to
/// `y` below is guarded, and a pinned node also acts as a WALL that no
/// other node may be pushed through.
void _assignCoordinates(_Proper g, SugiyamaParams params) {
  // Initial packing: each layer stacked from the origin in its phase-2
  // order, then pinned nodes snapped to their own y and the separation
  // repaired around them.
  for (var l = 0; l < g.layers.length; l++) {
    final row = g.layers[l];
    var cursor = 0;
    for (var i = 0; i < row.length; i++) {
      final v = row[i];
      g.y[v] = cursor;
      cursor += g.height[v] + params.nodeGapGu;
    }
    for (var i = 0; i < row.length; i++) {
      final fixed = g.pinnedY[row[i]];
      if (fixed != null) g.y[row[i]] = fixed;
    }
    _separate(g, l, params);
  }

  for (var iteration = 0; iteration < params.priorityIterations; iteration++) {
    for (var l = 1; l < g.layers.length; l++) {
      _priorityPass(g, l, params, fromAbove: true);
    }
    for (var l = g.layers.length - 2; l >= 0; l--) {
      _priorityPass(g, l, params, fromAbove: false);
    }
  }

  _clearOfFixed(g, params);
}

/// Moves every UNFIXED node clear of every FIXED one in its layer, down and
/// out of the way (DR-187 §11.186.5, `#917`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// MEASURED, AND IT IS NOT THE COLLISION ANYBODY WOULD GUESS
/// ═══════════════════════════════════════════════════════════════════════
/// With every existing symbol fixed and a device added, the new symbol
/// landed **exactly on top of** one of them. The mechanism is neither a
/// missing separation pass nor a cross-layer collision: [_separate] pushes
/// the newcomer down off the node above it and then back UP off the node
/// below it, and when the gap between two fixed neighbours is smaller than
/// the newcomer, that second pass forces it into a space it does not fit
/// in. The priority passes then settle it onto one of them.
///
/// The rule is therefore about ROOM rather than order: a node with no fixed
/// position is never left overlapping one that has. It moves DOWN, because
/// down is where a sheet may grow without disturbing anything already on
/// it, which is the *"expanding the canvas slightly"* half of the report.
///
/// ═══════════════════════════════════════════════════════════════════════
/// A NO-OP ON A LAYOUT WITH NOTHING FIXED, BY CONSTRUCTION
/// ═══════════════════════════════════════════════════════════════════════
/// It only ever measures an unfixed node against a FIXED one, so a document
/// that stores no positions cannot reach the body of either loop. That is
/// what keeps every existing scene, golden and op-count baseline exactly as
/// it was: this pass changes a drawing only where the document has already
/// asked for part of it to hold still.
void _clearOfFixed(_Proper g, SugiyamaParams params) {
  for (final row in g.layers) {
    final fixed = [
      for (final v in row)
        if (g.pinnedY[v] != null) v,
    ];
    if (fixed.isEmpty) continue;
    // CANONICAL ORDER, so two callers describing one graph get one answer:
    // the row is already in phase 2's order, which is itself total.
    for (final v in row) {
      if (g.pinnedY[v] != null) continue;
      // Repeated, because clearing one fixed neighbour can slide this node
      // onto the next one down. It terminates: every step strictly
      // increases `y` and there are finitely many fixed nodes.
      var moved = true;
      while (moved) {
        moved = false;
        for (final f in fixed) {
          final top = g.y[v];
          final bottom = top + g.height[v];
          final fTop = g.y[f];
          final fBottom = fTop + g.height[f];
          if (top < fBottom && fTop < bottom) {
            g.y[v] = fBottom + params.nodeGapGu;
            moved = true;
          }
        }
      }
    }
  }
}

/// Restores `y[i+1] >= y[i] + height[i] + gap` down the layer and then back
/// up it, moving only unpinned nodes.
///
/// TWO PINNED NODES THAT OVERLAP STAY OVERLAPPING. The user put both of
/// them there; refusing to draw, or shoving one aside, would each be worse
/// than a drawing that shows exactly what was asked for.
void _separate(_Proper g, int layer, SugiyamaParams params) {
  final row = g.layers[layer];
  for (var i = 1; i < row.length; i++) {
    final v = row[i];
    if (g.pinnedY[v] != null) continue;
    final floor = g.y[row[i - 1]] + g.height[row[i - 1]] + params.nodeGapGu;
    if (g.y[v] < floor) g.y[v] = floor;
  }
  for (var i = row.length - 2; i >= 0; i--) {
    final v = row[i];
    if (g.pinnedY[v] != null) continue;
    final ceiling = g.y[row[i + 1]] - g.height[v] - params.nodeGapGu;
    if (g.y[v] > ceiling) g.y[v] = ceiling;
  }
}

/// One priority pass over one layer.
void _priorityPass(
  _Proper g,
  int layer,
  SugiyamaParams params, {
  required bool fromAbove,
}) {
  final row = g.layers[layer];
  if (row.isEmpty) return;

  final desired = List<int?>.filled(row.length, null);
  final priority = List<int>.filled(row.length, 0);
  for (var i = 0; i < row.length; i++) {
    final v = row[i];
    priority[i] = g.up[v].length + g.down[v].length;
    final refs = fromAbove ? g.up[v] : g.down[v];
    if (refs.isEmpty) continue;
    var sum = 0.0;
    for (final u in refs) {
      sum += g.y[u] + g.height[u] / 2;
    }
    desired[i] = _roundNearest(sum / refs.length - g.height[v] / 2);
  }

  final byPriority = List<int>.generate(row.length, (i) => i, growable: false)
    ..sort((a, b) {
      final byDegree = priority[b].compareTo(priority[a]);
      if (byDegree != 0) return byDegree;
      // A total order — see determinism rule 3.
      return g.orderKey[row[a]].compareTo(g.orderKey[row[b]]);
    });

  // Nodes already positioned in this pass are walls, exactly as pinned
  // ones are: that is what makes a HIGHER priority actually win.
  final settled = List<bool>.filled(row.length, false);
  for (var i = 0; i < row.length; i++) {
    if (g.pinnedY[row[i]] != null) settled[i] = true;
  }

  for (final i in byPriority) {
    final target = desired[i];
    settled[i] = true;
    if (target == null || g.pinnedY[row[i]] != null) continue;
    final delta = target - g.y[row[i]];
    if (delta == 0) continue;
    if (delta > 0) {
      _shiftDown(g, layer, i, delta, settled, params);
    } else {
      _shiftUp(g, layer, i, -delta, settled, params);
    }
  }
}

/// Moves `row[i]` down by at most [delta], pushing the unsettled nodes
/// below it and stopping at the first settled or pinned one.
void _shiftDown(
  _Proper g,
  int layer,
  int i,
  int delta,
  List<bool> settled,
  SugiyamaParams params,
) {
  final row = g.layers[layer];
  var room = delta;
  var needed = 0;
  for (var j = i + 1; j < row.length; j++) {
    needed += g.height[row[j - 1]] + params.nodeGapGu;
    if (settled[j]) {
      final slack = g.y[row[j]] - g.y[row[i]] - needed;
      if (slack < room) room = slack;
      break;
    }
  }
  if (room <= 0) return;
  g.y[row[i]] += room;
  for (var j = i + 1; j < row.length; j++) {
    if (settled[j]) break;
    final floor = g.y[row[j - 1]] + g.height[row[j - 1]] + params.nodeGapGu;
    if (g.y[row[j]] >= floor) break;
    g.y[row[j]] = floor;
  }
}

/// The mirror of [_shiftDown].
void _shiftUp(
  _Proper g,
  int layer,
  int i,
  int delta,
  List<bool> settled,
  SugiyamaParams params,
) {
  final row = g.layers[layer];
  var room = delta;
  var needed = 0;
  for (var j = i - 1; j >= 0; j--) {
    needed += g.height[row[j]] + params.nodeGapGu;
    if (settled[j]) {
      final slack = g.y[row[i]] - g.y[row[j]] - needed;
      if (slack < room) room = slack;
      break;
    }
  }
  if (room <= 0) return;
  g.y[row[i]] -= room;
  for (var j = i - 1; j >= 0; j--) {
    if (settled[j]) break;
    final ceiling = g.y[row[j + 1]] - g.height[row[j]] - params.nodeGapGu;
    if (g.y[row[j]] <= ceiling) break;
    g.y[row[j]] = ceiling;
  }
}

/// Rounds to the nearest integer, halves AWAY FROM ZERO.
///
/// Spelled out rather than left to `double.round()` — which does the same
/// thing — because it is the ONLY place a fractional barycentre becomes an
/// integer coordinate, and "which way does .5 go" has to have one answer
/// that a golden can be read against. A non-finite input cannot arise (see
/// [_reorderLayer] on the divisor) and is mapped to 0 rather than thrown
/// from, so a layout can never be the thing that takes a commit down.
int _roundNearest(double v) {
  if (!v.isFinite) return 0;
  return v.round();
}
