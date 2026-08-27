// `#728`, DR-076 §11.75.2 — the layout is a value a rebuild can hold.
//
// ═══════════════════════════════════════════════════════════════════════
// THE GATE IS EQUALITY, NOT TIMING (§11.75.5)
// ═══════════════════════════════════════════════════════════════════════
// A rebuild that reuses a held layout must produce the SAME display list
// a whole rebuild would. A cache that is faster and different does not
// announce itself: it ships as a golden diff nobody can read, on a
// drawing an installer builds from.
//
// So the load-bearing case here compares op digests, not milliseconds.
// The timing lives in `schematic_perf_test.dart`, which is where the
// budget is argued; this file is about the answer being the same one.
//
// WHAT THIS DELIBERATELY DOES NOT TEST is that reusing a layout after a
// STRUCTURAL change is safe, because it is not: §11.75.2 puts that key on
// the `structure` epoch and the parameter stays dumb on purpose. A test
// asserting a stale layout produces a good scene would be asserting a
// defect as intended behaviour.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'op_digest.dart';
import 'schematic_fixture.dart';

final class _Measurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.5,
    ascent: style.sizePt * 0.8,
    descent: style.sizePt * 0.2,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

void main() {
  group('a held layout produces the same scene (DR-076 §11.75.5)', () {
    test('op for op, on the shipped fixture', () {
      final doc = readSchematicFixture();
      final measurer = _Measurer();

      final whole = buildSchematicScene(doc: doc, measurer: measurer);
      final held = buildSchematicScene(
        doc: doc,
        measurer: measurer,
        reuseLayout: whole.layout,
      );

      expect(
        digestOps(held.scene.ops),
        digestOps(whole.scene.ops),
        reason:
            'the display list is the artifact; a rebuild that reuses the '
            'layout must produce the one a whole rebuild would',
      );
    });

    test('and the same symbol positions, fragments and labels', () {
      // The op digest is the artifact, but these four are what the rest
      // of the product reads OFF the scene, and a digest match with a
      // moved symbol would mean the digest had stopped covering them.
      final doc = readSchematicFixture();
      final measurer = _Measurer();
      final whole = buildSchematicScene(doc: doc, measurer: measurer);
      final held = buildSchematicScene(
        doc: doc,
        measurer: measurer,
        reuseLayout: whole.layout,
      );

      expect(held.positions, whole.positions);
      expect(held.layers, whole.layers);
      expect(held.scene.fragments, whole.scene.fragments);
      expect(held.netLabels.length, whole.netLabels.length);
      expect(held.scene.bounds, whole.scene.bounds);
    });

    test('a WIRE edit under a held layout moves NO symbol, and a full '
        'rebuild moves nearly all of them', () {
      // ═══════════════════════════════════════════════════════════════
      // THIS IS NOT ONLY A SPEED FINDING (DR-011.4, DR-076 §11.75.2)
      // ═══════════════════════════════════════════════════════════════
      // Measured on the shipped fixture: adding ONE cable and rebuilding
      // the scene from scratch moves 88 of 91 symbols. The new edge
      // changes what Sugiyama's ordering sweep sees, and the two label
      // measurements that feed its params change with it, so the whole
      // sheet reshuffles under the cursor of the person who just drew a
      // wire.
      //
      // DR-011.4 already forbids that: "committing a link must not
      // re-lay-out the sheet". Holding the layout is therefore the
      // CORRECT path and not merely the cheap one, which is why this
      // case asserts both halves — the full rebuild's churn is the
      // reason the held one exists.
      final doc = readSchematicFixture();
      final measurer = _Measurer();
      final before = buildSchematicScene(doc: doc, measurer: measurer);

      final source = doc.links.values.first;
      doc.links[const Uuid('lnk-new')] = Link(
        id: const Uuid('lnk-new'),
        designator: 'W900',
        media: source.media,
        order: const FracIndex('zz'),
        meta: source.meta,
        conductors: [
          Conductor(
            from: source.conductors.first.from,
            to: const OpenEndpoint('probe'),
          ),
        ],
      );

      final whole = buildSchematicScene(doc: doc, measurer: measurer);
      final held = buildSchematicScene(
        doc: doc,
        measurer: measurer,
        reuseLayout: before.layout,
      );

      var movedByWhole = 0;
      var movedByHeld = 0;
      for (final e in before.positions.entries) {
        if (whole.positions[e.key] != e.value) movedByWhole++;
        if (held.positions[e.key] != e.value) movedByHeld++;
      }

      expect(
        movedByHeld,
        0,
        reason:
            'a cable drawn must not move a symbol, which is DR-011.4 and '
            'is what holding the layout buys',
      );
      expect(
        movedByWhole,
        greaterThan(before.positions.length ~/ 2),
        reason:
            'and the full rebuild does move them, which is the defect '
            'the hold exists to prevent rather than an incidental cost',
      );
      expect(
        held.netLabels.length,
        whole.netLabels.length,
        reason: 'the new cable is still drawn either way',
      );
    });

    test('the layout it hands back is the one it used', () {
      final doc = readSchematicFixture();
      final scene = buildSchematicScene(doc: doc, measurer: _Measurer());
      for (final entry in scene.positions.entries) {
        expect(scene.layout.positions[entry.key.v], entry.value);
      }
      expect(scene.layout.crossings, scene.crossings);
    });
  });
  group('a held symbol tier produces the same scene (`#729`)', () {
    // ═══════════════════════════════════════════════════════════════════
    // THE SECOND TIER, AND THE SAME GATE
    // ═══════════════════════════════════════════════════════════════════
    // Symbols are a contiguous PREFIX of the display list, because the
    // label stage runs after every symbol so a pennant is never
    // overpainted. Holding that prefix is what takes a wires-only rebuild
    // down to the label work; the property that makes it legal is that
    // the scene comes out identical.
    test('op for op, against a whole rebuild', () {
      final doc = readSchematicFixture();
      final measurer = _Measurer();
      final whole = buildSchematicScene(doc: doc, measurer: measurer);
      final held = buildSchematicScene(
        doc: doc,
        measurer: measurer,
        reuseSymbols: whole.symbolTier,
      );

      expect(digestOps(held.scene.ops), digestOps(whole.scene.ops));
      expect(held.scene.fragments, whole.scene.fragments);
      expect(held.scene.bounds, whole.scene.bounds);
      expect(held.scene.minTextSizePt, whole.scene.minTextSizePt);
      expect(held.positions, whole.positions);
      expect(held.domainFragments, whole.domainFragments);
    });

    test('a WIRE edit under a held tier matches one under a held layout', () {
      // The reference is a HELD LAYOUT, never a fresh one: DR-011.4
      // forbids a cable moving a symbol, so a full re-layout is not the
      // behaviour either path is trying to reproduce (§11.75.2).
      final doc = readSchematicFixture();
      final measurer = _Measurer();
      final before = buildSchematicScene(doc: doc, measurer: measurer);

      final source = doc.links.values.first;
      doc.links[const Uuid('lnk-new')] = Link(
        id: const Uuid('lnk-new'),
        designator: 'W900',
        media: source.media,
        order: const FracIndex('zz'),
        meta: source.meta,
        conductors: [
          Conductor(
            from: source.conductors.first.from,
            to: const OpenEndpoint('probe'),
          ),
        ],
      );

      final byLayout = buildSchematicScene(
        doc: doc,
        measurer: measurer,
        reuseLayout: before.layout,
      );
      final byTier = buildSchematicScene(
        doc: doc,
        measurer: measurer,
        reuseSymbols: before.symbolTier,
      );

      expect(
        digestOps(byTier.scene.ops),
        digestOps(byLayout.scene.ops),
        reason:
            'the tier holds what the layout would have rebuilt identically, '
            'so the cheaper path must draw the same sheet',
      );
      expect(byTier.netLabels.length, byLayout.netLabels.length);
      expect(
        byTier.netLabels.length,
        greaterThan(before.netLabels.length),
        reason: 'and the new cable is drawn, which is the point of rebuilding',
      );
    });

    test('the tier it hands back is the one it drew', () {
      final doc = readSchematicFixture();
      final scene = buildSchematicScene(doc: doc, measurer: _Measurer());
      expect(scene.symbolTier.symbols, scene.symbols);
      expect(scene.symbolTier.layers, scene.layers);
      expect(scene.symbolTier.positions, scene.positions);
      expect(scene.symbolTier.layout, same(scene.layout));
      expect(
        scene.symbolTier.ops.length,
        lessThan(scene.scene.ops.length),
        reason: 'the tier is the PREFIX; the labels are the rest',
      );
    });

    test('reusing a tier twice gives the same scene both times', () {
      // The copy the scene build makes of `ops` and `fragments` is what
      // this pins: appending labels to the tier's own lists would make
      // the second reuse draw the first one's labels twice.
      final doc = readSchematicFixture();
      final measurer = _Measurer();
      final first = buildSchematicScene(doc: doc, measurer: measurer);
      final a = buildSchematicScene(
        doc: doc,
        measurer: measurer,
        reuseSymbols: first.symbolTier,
      );
      final b = buildSchematicScene(
        doc: doc,
        measurer: measurer,
        reuseSymbols: first.symbolTier,
      );
      expect(digestOps(b.scene.ops), digestOps(a.scene.ops));
      expect(b.scene.ops.length, a.scene.ops.length);
    });
  });
}
