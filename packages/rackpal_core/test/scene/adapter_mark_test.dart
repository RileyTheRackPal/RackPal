// DR-235 §11.234.5 and §11.234.6 (`#1001`): a cable carrying a declared
// adapter wears a bowtie on each pennant of its label pair and at a drawn
// wire's midpoint, and T0.01 explains the mark only when the set prints one
// (DR-208).
//
// THE CASE THIS FILE EXISTS FOR is `each pennant`. The model does not say
// which end an adapter sits at, so a reader at either end must see it; a
// mark on one pennant would be right half the time and look right always.
// Every case reads the BUILT scene's ops, not a call to the mark function.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'schematic_test_document.dart';

const FakeMeasurer _m = FakeMeasurer();

/// Whether [op] is the adapter mark: a six-point closed outline, filled
/// with the surface and stroked in a hue.
///
/// NARROW ON PURPOSE. The first draft matched "a filled closed path" and
/// the PLAIN fixture held eight: the audio-digital domain's filled diamond
/// glyph. A finder that matches a family's glyph proves nothing about a mark.
bool _isMark(DiagramOp op) {
  if (op is! OpPath || op.stroke == null) return false;
  if (op.fill?.argb != const SchematicPalette().bodyFill) return false;
  final c = op.p.commands;
  return c.length == 7 &&
      c.first is MoveTo &&
      c.sublist(1, 6).every((x) => x is LineTo) &&
      c.last is ClosePath;
}

/// The mark's centre: where its two tips meet, its second point.
DPt _centreOf(OpPath op) {
  final tip = op.p.commands[1] as LineTo;
  return DPt(tip.x, tip.y);
}

InlineAdapter _adapter() => InlineAdapter(
  fromConnector: const ConnectorTypeId('conn.xlr3'),
  toConnector: const ConnectorTypeId('conn.rca'),
  satisfiesRuleIds: ['CON-001'],
);

void main() {
  group('polylineMidpoint', () {
    test('halfway by LENGTH along an orthogonal trace, not by vertex', () {
      final mid = polylineMidpoint(const [DPt(0, 0), DPt(4, 0), DPt(4, 8)]);
      expect(mid.at, const DPt(4, 2));
      expect(mid.horizontal, isFalse, reason: 'it lands on the vertical leg');
    });

    test('a trace with no length answers its first point', () {
      expect(
        polylineMidpoint(const [DPt(3, 3), DPt(3, 3)]).at,
        const DPt(3, 3),
      );
    });
  });

  group('the net-label pair', () {
    test('a cable with no adapter draws no mark anywhere', () {
      final scene = buildFixtureScene(buildSchematicTestDocument());
      expect(scene.scene.ops.where(_isMark), isEmpty);
    });

    test('EACH PENNANT of a cable carrying one wears a mark, on its own '
        'leader, and nothing else changes', () {
      final plain = buildSchematicTestDocument();
      final doc = buildSchematicTestDocument();
      final link = doc.links.values.first..inlineAdapters.add(_adapter());
      final before = buildFixtureScene(plain);
      final scene = buildFixtureScene(doc);

      final labels = scene.netLabels.where((l) => l.linkId == link.id).toList();
      expect(labels, hasLength(2), reason: 'the precondition: two ends drawn');
      final marks = scene.scene.ops.where(_isMark).cast<OpPath>().toList();
      expect(marks, hasLength(2), reason: 'one per pennant');
      for (final label in labels) {
        expect(
          marks.where((l) {
            final c = _centreOf(l);
            // On the leader: between the pin and the pennant, on its line.
            return label.pennant.inflate(label.pennant.height).contains(c) &&
                !label.pennant.contains(c);
          }),
          hasLength(1),
          reason: "each pennant's own leader carries one",
        );
      }
      expect(
        scene.scene.ops.length - before.scene.ops.length,
        2,
        reason: 'two ops added, and no other op moved or appeared',
      );
    });
  });

  group('the drawn wire', () {
    test('a mark at the midpoint of the trace, and none without an '
        'adapter', () {
      final doc = buildSchematicTestDocument();
      final link = doc.links.values.first;
      final scene = buildFixtureScene(doc);
      DrawnWireLayer layer() => buildDrawnWireLayer(
        scene: scene,
        doc: doc,
        linkIds: {link.id},
        measurer: _m,
        palette: const SchematicPalette(),
      );
      expect(layer().ops.where(_isMark), isEmpty);

      link.inlineAdapters.add(_adapter());
      final drawn = layer();
      final mark = drawn.ops.where(_isMark).cast<OpPath>().single;
      expect(
        _centreOf(mark),
        polylineMidpoint(drawn.wires.single.points).at,
      );
      expect(drawn.inkBounds!.contains(_centreOf(mark)), isTrue);
    });
  });

  group('T0.01 (DR-208 §11.207.1)', () {
    final doc = buildSchematicTestDocument();
    final signal = buildFixtureScene(doc).netLabels.first.style;
    List<String> texts(LegendBlock b) =>
        b.ops.whereType<OpText>().map((t) => t.text).toList();

    test('no adapter printed, no mark row', () {
      final block = conventionsBlock(statuses: const [], hatchedPassive: false);
      expect(texts(block), isNot(contains(kLegendAdapterMeaning)));
      expect(block.ops.where(_isMark), isEmpty);
    });

    test('a printed adapter: the mark, drawn by the same function, and '
        'its meaning', () {
      final block = conventionsBlock(
        statuses: const [],
        hatchedPassive: false,
        adapter: signal,
      );
      expect(texts(block), contains(kLegendAdapterMeaning));
      expect(block.ops.where(_isMark), hasLength(1));
    });
  });
}
