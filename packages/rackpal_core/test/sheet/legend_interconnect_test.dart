// T0.01's two interconnect conventions, the tag pill and the net label
// (DR-208 §11.207.1, DR-225 §11.224.6, M6-D5 `#984`).

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../scene/schematic_test_document.dart';

const FakeMeasurer _m = FakeMeasurer();

void main() {
  final doc = buildSchematicTestDocument();
  final full = buildSchematicScene(doc: doc, measurer: _m);
  final link = doc.links.values.first;
  final label = full.netLabels.firstWhere((l) => l.linkId == link.id);
  final signal = label.style;

  List<String> texts(LegendBlock b) =>
      b.ops.whereType<OpText>().map((t) => t.text).toList();

  test('neither row prints when the set draws neither mark', () {
    final block = conventionsBlock(statuses: const [], hatchedPassive: false);
    expect(texts(block), isNot(contains(kLegendTagPillMeaning)));
    expect(texts(block), isNot(contains(kLegendNetLabelMeaning)));
    expect(block.ops.whereType<OpRoundRect>(), isEmpty);
  });

  test('the tag pill row draws a pill on a real cable, and explains it', () {
    final text = tagPillText(link, signal);
    final block = conventionsBlock(
      statuses: const [],
      hatchedPassive: false,
      tagPill: (text: text, signal: signal),
      measurer: _m,
    );
    expect(texts(block), containsAll(<String>[text, kLegendTagPillMeaning]));
    expect(texts(block), isNot(contains(kLegendNetLabelMeaning)));
    expect(block.ops.whereType<OpRoundRect>(), hasLength(1));
  });

  test("the sample pill is the drawn layer's own pill: the same box for the "
      'same cable', () {
    final wires = buildDrawnWireLayer(
      scene: full,
      doc: doc,
      linkIds: {link.id},
      measurer: _m,
      palette: const SchematicPalette(),
    );
    final drawn = wires.ops.whereType<OpRoundRect>().first.r;
    final sample = tagPillSampleOps(
      text: tagPillText(link, signal),
      pin: const DPt(0, 0),
      length: 10,
      signal: signal,
      measurer: _m,
    ).whereType<OpRoundRect>().single.r;
    // TO THE LAST FEW BITS: the two sum the same terms in a different
    // order, so they agree to 1e-14 and not bit for bit.
    expect(sample.width, closeTo(drawn.width, 1e-9));
    expect(sample.height, closeTo(drawn.height, 1e-9));
  });

  test('the net label row draws a pennant with the net name, and explains '
      'it', () {
    final block = conventionsBlock(
      statuses: const [],
      hatchedPassive: false,
      netLabel: (text: label.netName, signal: signal),
      measurer: _m,
    );
    expect(
      texts(block),
      containsAll(<String>[label.netName, kLegendNetLabelMeaning]),
    );
    expect(block.ops.whereType<OpPath>(), isNotEmpty, reason: 'the pennant');
  });

  test("the sample label is the layer's own: the pennant matches the "
      "schematic's for the same cable", () {
    final sample = netLabelSampleOps(
      pin: const DPt(0, 0),
      signal: signal,
      netName: label.netName,
      measurer: _m,
    );
    final pennant = sample.whereType<OpPath>().first;
    final onSheet = full.scene.ops.whereType<OpPath>().where(
      (p) => p.fill?.argb == pennant.fill?.argb,
    );
    // THE PENNANT'S SIZE, not its place: the sample sits at the legend's
    // origin and the sheet's on a pin, so compare extents.
    DBox box(OpPath p) => p.p.bounds;
    // Within 1e-9, for the pill's reason above.
    expect(
      onSheet.any(
        (p) =>
            (box(p).width - box(pennant).width).abs() < 1e-9 &&
            (box(p).height - box(pennant).height).abs() < 1e-9,
      ),
      isTrue,
    );
  });
}
