// Sugiyama phases 0–3, tested as an algorithm — no document, no drawing.
//
// The two named tests at the top exist because the DELETED implementation
// (`b560a50`) failed exactly there and shipped behind zero tests: it threw
// `ConcurrentModificationError` on any graph with an edge, and it divided
// by zero on a single-node layer. Neither of those is a hypothetical
// regression; both are the regression.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

LayoutNode _n(
  String id, {
  int width = 20,
  int height = 16,
  LayerAnchor anchor = LayerAnchor.none,
  Pt? pinnedAt,
  String? sortKey,
}) => LayoutNode(
  id: id,
  sortKey: sortKey ?? id,
  widthGu: width,
  heightGu: height,
  anchor: anchor,
  pinnedAt: pinnedAt,
);

LayoutEdge _e(
  String from,
  String to, {
  String? id,
  bool returnChannel = false,
}) => LayoutEdge(
  id: id ?? '$from>$to',
  from: from,
  to: to,
  preferReversed: returnChannel,
);

/// Which layer [id] landed in.
int _layerOf(SugiyamaLayout layout, String id) {
  for (var l = 0; l < layout.layers.length; l++) {
    if (layout.layers[l].contains(id)) return l;
  }
  fail('$id is in no layer');
}

void main() {
  group('phase 0 — cycle breaking', () {
    test('a graph WITH AN EDGE lays out at all — the deleted implementation '
        'threw ConcurrentModificationError here', () {
      final layout = layoutSugiyama(
        nodes: [_n('a'), _n('b')],
        edges: [_e('a', 'b')],
      );
      expect(layout.layers.length, 2);
      expect(layout.positions.length, 2);
    });

    test('a two-cycle is broken by reversing exactly one of its edges', () {
      final layout = layoutSugiyama(
        nodes: [_n('a'), _n('b')],
        edges: [_e('a', 'b'), _e('b', 'a')],
      );
      expect(layout.reversedEdgeIds.length, 1);
      // Broken means LAYERED: a surviving cycle cannot produce two layers
      // from longest-path layering.
      expect(layout.layers.length, 2);
      expect(layout.nonForwardEdgeIds, isEmpty);
    });

    test('a three-cycle is broken and every node still gets a layer', () {
      final layout = layoutSugiyama(
        nodes: [_n('a'), _n('b'), _n('c')],
        edges: [_e('a', 'b'), _e('b', 'c'), _e('c', 'a')],
      );
      expect(layout.reversedEdgeIds.length, 1);
      expect(layout.positions.keys.toList()..sort(), ['a', 'b', 'c']);
    });

    test('THE RETURN CHANNEL is the edge reversed, not the forward path — '
        'and that holds whichever end sorts first (docs/05 §10.2 phase 0)', () {
      // AVR → display on HDMI, display → AVR on eARC. The eARC edge is the
      // one a reader does not follow, so it is the one that must turn
      // around. A single biased DFS gets this right only when the AVR
      // happens to be visited first, which is why the implementation holds
      // the return channels back to a second pass.
      final avrFirst = layoutSugiyama(
        nodes: [
          _n('avr', sortKey: '0'),
          _n('tv', sortKey: '1'),
        ],
        edges: [
          _e('avr', 'tv', id: 'hdmi'),
          _e('tv', 'avr', id: 'earc', returnChannel: true),
        ],
      );
      expect(avrFirst.reversedEdgeIds, ['earc']);

      final tvFirst = layoutSugiyama(
        nodes: [
          _n('avr', sortKey: '1'),
          _n('tv', sortKey: '0'),
        ],
        edges: [
          _e('avr', 'tv', id: 'hdmi'),
          _e('tv', 'avr', id: 'earc', returnChannel: true),
        ],
      );
      expect(tvFirst.reversedEdgeIds, ['earc']);
    });

    test('a cycle with NO return channel still breaks, and the bias costs '
        'nothing when there is nothing to prefer', () {
      final layout = layoutSugiyama(
        nodes: [_n('a'), _n('b')],
        edges: [
          _e('a', 'b', id: 'x'),
          _e('b', 'a', id: 'y'),
        ],
      );
      expect(layout.reversedEdgeIds, ['y']);
    });
  });

  group('phase 1 — layer assignment', () {
    test('longest-path layering puts a chain of four on four layers', () {
      final layout = layoutSugiyama(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [_e('a', 'b'), _e('b', 'c'), _e('c', 'd')],
      );
      expect(layout.layers.length, 4);
      expect(_layerOf(layout, 'a'), 0);
      expect(_layerOf(layout, 'd'), 3);
    });

    test('LONGEST path, not shortest: a node reachable by two routes takes '
        'the later layer', () {
      // a→b→c and a→c. `c` must sit at layer 2, or the a→c edge would have
      // to cross backwards over `b`.
      final layout = layoutSugiyama(
        nodes: [_n('a'), _n('b'), _n('c')],
        edges: [_e('a', 'b'), _e('b', 'c'), _e('a', 'c')],
      );
      expect(_layerOf(layout, 'c'), 2);
    });

    test('CR-072: a first-anchored Structure device sits on layer 0 and its '
        'successors move right rather than being crossed', () {
      // Without the anchor `str` would land at layer 1, behind `src`.
      final layout = layoutSugiyama(
        nodes: [
          _n('src'),
          _n('str', anchor: LayerAnchor.first),
          _n('sink'),
        ],
        edges: [_e('src', 'str'), _e('str', 'sink')],
      );
      expect(_layerOf(layout, 'str'), 0);
      expect(_layerOf(layout, 'sink'), greaterThan(0));
      // The in-edge now runs leftwards, and that is REPORTED rather than
      // repaired — repairing it would mean moving the anchored symbol.
      expect(layout.nonForwardEdgeIds, ['src>str']);
    });

    test('an off-rack DESTINATION is forced to the last layer', () {
      final layout = layoutSugiyama(
        nodes: [
          _n('a'),
          _n('b'),
          _n('c'),
          _n('tv', anchor: LayerAnchor.last),
        ],
        edges: [_e('a', 'b'), _e('b', 'c'), _e('a', 'tv')],
      );
      expect(layout.layers.length, 3);
      expect(_layerOf(layout, 'tv'), 2);
    });

    test('a last-anchor is UNCONDITIONAL here — whether a device deserves '
        'one is the SCENE BUILDER decision, and the backwards edge it can '
        'cause is reported', () {
      // This file knows nothing about racks, so it cannot know that a wall
      // plate feeding a projector is not a "destination". It honours the
      // anchor and names the edge that ends up running leftwards.
      final layout = layoutSugiyama(
        nodes: [
          _n('a'),
          _n('wallplate', anchor: LayerAnchor.last),
          _n('b'),
          _n('c'),
        ],
        edges: [
          _e('a', 'wallplate'),
          _e('wallplate', 'b'),
          _e('b', 'c'),
        ],
      );
      expect(_layerOf(layout, 'wallplate'), layout.layers.length - 1);
      expect(layout.nonForwardEdgeIds, ['wallplate>b']);
    });

    test('a pinned symbol takes the layer nearest its gx', () {
      // Pitch is widest node + gutter = 20 + 12 = 32 gu, so gx 70 is
      // nearest layer 2 (64) rather than layer 1 (32) or 3 (96).
      final layout = layoutSugiyama(
        nodes: [
          _n('a'),
          _n('b'),
          _n('c'),
          _n('d'),
          _n('pinned', pinnedAt: const Pt(70, 5)),
        ],
        edges: [_e('a', 'b'), _e('b', 'c'), _e('c', 'd')],
      );
      expect(_layerOf(layout, 'pinned'), 2);
    });

    test('CR-068: a pinned symbol comes out at EXACTLY its own Pt — no '
        'phase may move it', () {
      const at = Pt(70, 137);
      final layout = layoutSugiyama(
        nodes: [
          _n('a'),
          _n('b'),
          _n('c'),
          _n('pinned', pinnedAt: at),
          _n('crowd1'),
          _n('crowd2'),
        ],
        edges: [
          _e('a', 'b'),
          _e('b', 'c'),
          _e('a', 'crowd1'),
          _e('a', 'crowd2'),
          _e('crowd1', 'pinned'),
        ],
      );
      expect(layout.positions['pinned'], at);
    });
  });

  group('phase 2 — within-layer ordering', () {
    test('A SINGLE-NODE LAYER does not produce NaN and does not reorder — '
        'the deleted implementation divided by (length - 1)', () {
      // One node in layer 0, one in layer 1: both layers are single-node,
      // which is the divide-by-zero the deleted file hit on every graph.
      final layout = layoutSugiyama(
        nodes: [_n('a'), _n('b')],
        edges: [_e('a', 'b')],
      );
      expect(layout.layers, [
        ['a'],
        ['b'],
      ]);
      for (final p in layout.positions.values) {
        expect(p.gx.isFinite, isTrue);
        expect(p.gy.isFinite, isTrue);
      }
    });

    test('a node with NO neighbours in the reference layer holds its place '
        'instead of drifting to one end', () {
      // `lonely` has no edges at all, so its barycentre is undefined. It
      // sorts LAST by rack order and must stay there. Defaulting an
      // undefined barycentre to 0 — the obvious wrong fix for the deleted
      // implementation's NaN — would tie it with `p` and pull it to index
      // 1, i.e. an isolated symbol would migrate to the top of its column
      // for no reason a reader could see.
      final layout = layoutSugiyama(
        nodes: [
          _n('p', sortKey: '0'),
          _n('q', sortKey: '1'),
          _n('lonely', sortKey: '9'),
          _n('x', sortKey: '3'),
          _n('y', sortKey: '4'),
        ],
        edges: [_e('p', 'y'), _e('q', 'x')],
      );
      expect(layout.layers[0], ['p', 'q', 'lonely']);
      expect(layout.layers[1], ['y', 'x']);
    });

    test('the barycentre sweep REDUCES crossings against the initial rack '
        'order', () {
      // Two layers wired to cross completely in sort-key order: the top
      // layer reads t1..t4 and each feeds the OPPOSITE bottom node.
      final layout = layoutSugiyama(
        nodes: [
          for (var i = 1; i <= 4; i++) _n('t$i', sortKey: 'a$i'),
          for (var i = 1; i <= 4; i++) _n('b$i', sortKey: 'b$i'),
        ],
        edges: [
          for (var i = 1; i <= 4; i++) _e('t$i', 'b${5 - i}'),
        ],
      );
      expect(layout.crossings, 0);
      expect(layout.layers[1], ['b4', 'b3', 'b2', 'b1']);
    });

    test('PARALLEL EDGES ARE KEPT AND COUNTED TWICE — two cables between one '
        'pair pull harder than one', () {
      // `x` has one edge from p and one from q; `y` has TWO from p and one
      // from q. Collapsing the parallel pair would give both a barycentre
      // of 0.5 and leave the order to the tie-break; keeping it puts `y`
      // above `x`.
      final layout = layoutSugiyama(
        nodes: [
          _n('p', sortKey: '0'),
          _n('q', sortKey: '1'),
          _n('x', sortKey: '2'),
          _n('y', sortKey: '3'),
        ],
        edges: [
          _e('p', 'x', id: 'px'),
          _e('q', 'x', id: 'qx'),
          _e('p', 'y', id: 'py1'),
          _e('p', 'y', id: 'py2'),
          _e('q', 'y', id: 'qy'),
        ],
      );
      expect(layout.layers[1], ['y', 'x']);
    });
  });

  group('phase 3 — coordinate assignment', () {
    test('no two symbols in a layer overlap', () {
      final layout = layoutSugiyama(
        nodes: [
          _n('hub'),
          for (var i = 0; i < 12; i++) _n('leaf$i', height: 16 + i),
        ],
        edges: [for (var i = 0; i < 12; i++) _e('hub', 'leaf$i')],
      );
      final heights = <String, int>{
        for (var i = 0; i < 12; i++) 'leaf$i': 16 + i,
      };
      final row = layout.layers[1];
      for (var i = 1; i < row.length; i++) {
        final above = layout.positions[row[i - 1]]!;
        final below = layout.positions[row[i]]!;
        expect(
          below.gy,
          greaterThanOrEqualTo(above.gy + heights[row[i - 1]]!),
          reason: '${row[i - 1]} and ${row[i]} overlap',
        );
      }
    });

    test('a pinned symbol is a WALL IN THE MIDDLE of its layer: neighbours '
        'above it are stopped by it rather than pushed through it', () {
      // The pin sorts BETWEEN `leaf2` and `leaf3`, which is the only
      // arrangement that exercises both guards: the initial separation pass
      // must not shove the pin down to clear `leaf2`, and the priority
      // pass — where every leaf wants the same y, the hub's centre — must
      // clamp the ones above the pin instead of walking them through it.
      // A pin at the head of its layer tests neither.
      final layout = layoutSugiyama(
        nodes: [
          _n('hub', height: 60),
          _n('pin', pinnedAt: const Pt(32, 30), height: 40, sortKey: 'z25'),
          for (var i = 0; i < 6; i++) _n('leaf$i', sortKey: 'z$i'),
        ],
        edges: [
          for (var i = 0; i < 6; i++) _e('hub', 'leaf$i'),
          _e('hub', 'pin'),
        ],
      );
      expect(layout.positions['pin'], const Pt(32, 30));
      for (var i = 0; i < 6; i++) {
        final leaf = layout.positions['leaf$i']!;
        final clear = leaf.gy >= 30 + 40 || leaf.gy + 16 <= 30;
        expect(
          clear,
          isTrue,
          reason: 'leaf$i at ${leaf.gy} overlaps the pinned symbol',
        );
      }
      // And the layer is still ORDERED, top to bottom, with no overlaps
      // anywhere in it. Clamping the pin alone is not enough: a node that
      // walks past the wall lands on whatever is on the other side of it,
      // so the two claims are checked together.
      final heights = <String, int>{
        'pin': 40,
        for (var i = 0; i < 6; i++) 'leaf$i': 16,
      };
      final row = layout.layers[1];
      for (var i = 1; i < row.length; i++) {
        expect(
          layout.positions[row[i]]!.gy,
          greaterThanOrEqualTo(
            layout.positions[row[i - 1]]!.gy + heights[row[i - 1]]!,
          ),
          reason: '${row[i - 1]} and ${row[i]} overlap or are out of order',
        );
      }
    });

    test('every coordinate is an integer grid unit (CR-004) — nothing '
        'leaves this layout as a float', () {
      final layout = layoutSugiyama(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d'), _n('e')],
        edges: [_e('a', 'c'), _e('b', 'c'), _e('a', 'd'), _e('b', 'e')],
      );
      // `Pt` is int-typed, so this asserts the API shape rather than the
      // values: the point is that no `double` is reachable from here.
      for (final p in layout.positions.values) {
        expect(p.gx, isA<int>());
        expect(p.gy, isA<int>());
      }
    });
  });

  group('determinism (the M2 exit criterion)', () {
    test('a SHUFFLED description of the same graph lays out identically', () {
      // THE GRAPH IS CHOSEN TO BE ORDER-SENSITIVE, because most graphs are
      // not and a test built on one of those passes without canonicalisation
      // and proves nothing. Two components exist purely to make the cycle
      // breaker's answer depend on input order:
      //
      //   * `t0→t1→t2→t0` — a three-cycle with no return channel. WHICH
      //     edge closes it depends on which node the DFS roots at, i.e. on
      //     NODE order.
      //   * `a→b`, `a→c`, `b↔c` — which of the 2-cycle's edges is a back
      //     edge depends on whether `a` is explored towards `b` or `c`
      //     first, i.e. on EDGE order.
      //
      // Both must come out the same under every permutation.
      final nodes = [
        for (var i = 0; i < 14; i++) _n('n$i', height: 16 + (i % 5)),
        _n('t0', sortKey: 'y0'),
        _n('t1', sortKey: 'y1'),
        _n('t2', sortKey: 'y2'),
        _n('ca', sortKey: 'z0'),
        _n('cb', sortKey: 'z1'),
        _n('cc', sortKey: 'z2'),
      ];
      final edges = <LayoutEdge>[
        for (var i = 0; i < 13; i++) _e('n$i', 'n${i + 1}'),
        _e('n0', 'n7', id: 'skip1'),
        _e('n2', 'n11', id: 'skip2'),
        _e('n13', 'n4', id: 'back', returnChannel: true),
        _e('n5', 'n9', id: 'skip3'),
        _e('t0', 't1', id: 't01'),
        _e('t1', 't2', id: 't12'),
        _e('t2', 't0', id: 't20'),
        // Deliberately NOT in canonical order in the input.
        _e('ca', 'cc', id: 'ac'),
        _e('cb', 'cc', id: 'bc'),
        _e('cc', 'cb', id: 'cb'),
        _e('ca', 'cb', id: 'ab'),
      ];

      final forward = layoutSugiyama(nodes: nodes, edges: edges);
      final reversed = layoutSugiyama(
        nodes: nodes.reversed.toList(),
        edges: edges.reversed.toList(),
      );
      // A rotation as well as a reversal: a reversal alone would pass for
      // an implementation that happened to sort descending.
      final rotated = layoutSugiyama(
        nodes: [...nodes.skip(5), ...nodes.take(5)],
        edges: [...edges.skip(9), ...edges.take(9)],
      );

      expect(_describe(reversed), _describe(forward));
      expect(_describe(rotated), _describe(forward));
    });

    test('the same input twice is the same output twice', () {
      List<LayoutNode> nodes() => [for (var i = 0; i < 9; i++) _n('n$i')];
      List<LayoutEdge> edges() => [
        for (var i = 0; i < 8; i++) _e('n$i', 'n${(i + 3) % 9}'),
      ];
      expect(
        _describe(layoutSugiyama(nodes: nodes(), edges: edges())),
        _describe(layoutSugiyama(nodes: nodes(), edges: edges())),
      );
    });
  });

  group('total, not throwing', () {
    test('an empty graph is an empty layout', () {
      final layout = layoutSugiyama(nodes: [], edges: []);
      expect(layout.layers, isEmpty);
      expect(layout.positions, isEmpty);
      expect(layout.crossings, 0);
    });

    test('a self-link and an edge naming an unknown node are dropped, not '
        'thrown on', () {
      final layout = layoutSugiyama(
        nodes: [_n('a'), _n('b')],
        edges: [
          _e('a', 'a', id: 'loopThrough'),
          _e('a', 'ghost', id: 'dangling'),
          _e('a', 'b', id: 'real'),
        ],
      );
      expect(layout.layers.length, 2);
      expect(layout.reversedEdgeIds, isEmpty);
      expect(layout.nonForwardEdgeIds, isEmpty);
    });

    test('a graph with no edges at all reads in rack order on one layer', () {
      final layout = layoutSugiyama(
        nodes: [
          _n('c', sortKey: '2'),
          _n('a', sortKey: '0'),
          _n('b', sortKey: '1'),
        ],
        edges: [],
      );
      expect(layout.layers, [
        ['a', 'b', 'c'],
      ]);
    });
  });

  group('dummy nodes', () {
    test('an edge spanning three layers gets two dummies, so every edge '
        'crosses exactly one gutter', () {
      final layout = layoutSugiyama(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [_e('a', 'b'), _e('b', 'c'), _e('c', 'd'), _e('a', 'd')],
      );
      expect(layout.layers.length, 4);
      expect(layout.dummyCount, 2);
    });

    test('a graph whose edges all span one layer needs none', () {
      final layout = layoutSugiyama(
        nodes: [_n('a'), _n('b')],
        edges: [_e('a', 'b')],
      );
      expect(layout.dummyCount, 0);
    });
  });
}

/// Everything the layout decided, as one comparable string.
String _describe(SugiyamaLayout layout) {
  final out = StringBuffer()
    ..writeln('crossings ${layout.crossings}')
    ..writeln('dummies ${layout.dummyCount}')
    ..writeln('reversed ${layout.reversedEdgeIds.join(',')}')
    ..writeln('nonForward ${layout.nonForwardEdgeIds.join(',')}');
  for (var l = 0; l < layout.layers.length; l++) {
    for (final id in layout.layers[l]) {
      out.writeln('$l $id ${layout.positions[id]}');
    }
  }
  return out.toString();
}
