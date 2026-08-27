// #96-A/2 — top and bottom port labels must not overprint each other.
//
// ═══════════════════════════════════════════════════════════════════════
// THE DEFECT, AND WHY ONLY TWO EDGES HAD IT
// ═══════════════════════════════════════════════════════════════════════
// Found in the field, on the built product: *"a bunch of the port labels
// for ports along the top/bottom of a device block currently overlap each
// other causing readability issues."*
//
// Pins on the top and bottom edges are spaced along X, one `portPitch`
// apart. Their labels ran along X too, so any label wider than one pitch
// overlapped its neighbour. The left and right edges were never affected
// and not by luck: there the pins are spaced along Y while the text runs
// along X, so the axes are perpendicular and the labels cannot collide
// however long they get.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ASSERTION IS GEOMETRIC, NOT A GOLDEN
// ═══════════════════════════════════════════════════════════════════════
// A golden would have caught this too — by changing, which is exactly what
// it did NOT do, because the overlap was there from the first golden and
// every regeneration since agreed with it. Goldens defend against CHANGE;
// they say nothing about whether the thing they froze was ever right.
//
// So this measures the emitted ops and asserts a property: within one edge
// of one symbol, no two label boxes intersect. That is false before the
// quarter turn and true after it, on real catalog templates rather than a
// fixture invented here.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// Plausible metrics, no font file. Advance width is what this test is
/// about, so it is linear in the string length and nothing here can pass by
/// measuring every label as zero-width.
final class _Measurer implements TextMeasurer {
  const _Measurer();

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

/// Every label box a symbol emits, grouped by the edge its pin is on.
///
/// Measured ONE OP AT A TIME through `BoundsCanvas`, which is how the box a
/// label really occupies — rotation included — is obtained without this test
/// re-deriving the rotation itself. A test that computed its own boxes could
/// agree with a broken layer.
RenderedSymbol _geometryOf(TemplateBody body, {required String designator}) {
  // THE SCENE'S OWN NUMBERS, not this file's. `buildSchematicScene` sizes
  // every symbol from `SchematicMetrics` scaled by `kSchematicUnitsPerGrid`,
  // and a test that invented a pitch would be asserting that labels do not
  // overlap at SOME spacing rather than at the one the product draws.
  const metrics = SchematicMetrics();
  final upg = kSchematicUnitsPerGrid;
  return buildSymbolGeometry(
    id: 'dev-1',
    designator: designator,
    name: body.displayName,
    ports: body.ports,
    banks: body.banks,
    headerHeight: metrics.headerHeightGu * upg,
    portSize: metrics.portSizeGu * upg,
    portPitch: metrics.pinPitchGu * upg,
  );
}

/// Every emitted port label, paired with the pin it belongs to.
///
/// ═══════════════════════════════════════════════════════════════════════
/// MATCHED BY EMISSION ORDER, NOT BY LABEL TEXT
/// ═══════════════════════════════════════════════════════════════════════
/// The obvious keying — a `Map<String, OpText>` on the label — is unsound on
/// the shipped catalog and this test found out the hard way. **N03 carries
/// 24 DUPLICATE LABEL TEXTS on its top edge**, so a text-keyed map collapsed
/// 48 ports onto 24 ops and every one of those ports looked up the SAME box.
/// The result was 24 "overlapping pairs" that were one box compared with
/// itself: a failure reporting a real catalog oddity as a layout defect.
///
/// `buildSymbolLayer` walks `symbol.allPorts` and emits exactly one text op
/// per port with a non-empty label, in that order. Zipping the two is
/// therefore exact, and it does not care whether two pins are called the
/// same thing.
List<(SymbolPort, OpText)> _labelledPins(
  RenderedSymbol symbol,
  TextMeasurer measurer,
) {
  final build = buildSymbolLayer(
    symbol,
    palette: const SchematicPalette(),
    measurer: measurer,
  );
  // Port labels are the text ops at `RackTextSizes.type`; the header's
  // designator and instance name are emitted at other sizes.
  final ops = build.ops
      .whereType<OpText>()
      .where((o) => o.style.sizePt == RackTextSizes.type)
      .toList();
  final pins = symbol.allPorts.where((p) => p.label.isNotEmpty).toList();
  expect(
    ops,
    hasLength(pins.length),
    reason:
        'the zip below assumes one text op per labelled pin, in allPorts '
        'order — ${symbol.designator} broke that assumption',
  );
  return <(SymbolPort, OpText)>[
    for (var i = 0; i < pins.length; i++) (pins[i], ops[i]),
  ];
}

/// The box one label actually occupies, rotation included.
///
/// Measured through `BoundsCanvas` rather than derived here: a test that
/// computed its own rotated box could agree with a broken layer, and the
/// whole question is where the ink lands.
DBox _boxOf(OpText op, TextMeasurer measurer) => (BoundsCanvas(
  measurer: measurer,
)..drawText(op.text, op.at, op.style)).bounds!;

Map<SymbolSide, List<DBox>> _labelBoxesByEdge(
  TemplateBody body, {
  required String designator,
}) {
  const measurer = _Measurer();
  final symbol = _geometryOf(body, designator: designator);
  final pairs = _labelledPins(symbol, measurer);

  final out = <SymbolSide, List<DBox>>{
    for (final side in SymbolSide.values) side: <DBox>[],
  };
  for (final (port, op) in pairs) {
    out[port.side]!.add(_boxOf(op, measurer));
  }
  return out;
}

/// Pairs of [boxes] that intersect, as index pairs.
///
/// A SHARED EDGE IS NOT AN OVERLAP. `DBox.intersects` is inclusive on both
/// bounds, so two boxes merely touching would be reported — and touching is
/// what perfectly-pitched neighbours legitimately do. The comparison is
/// therefore strict on both axes.
List<(int, int)> _overlaps(List<DBox> boxes) {
  final hits = <(int, int)>[];
  for (var i = 0; i < boxes.length; i++) {
    for (var j = i + 1; j < boxes.length; j++) {
      final a = boxes[i];
      final b = boxes[j];
      final overlapX = a.left < b.right && b.left < a.right;
      final overlapY = a.top < b.bottom && b.top < a.bottom;
      if (overlapX && overlapY) hits.add((i, j));
    }
  }
  return hits;
}

void main() {
  late Map<String, TemplateBody> catalog;

  setUpAll(() {
    catalog = buildSeedCatalog();
  });

  /// Templates carrying at least [min] pins on [side].
  ///
  /// DERIVED FROM THE CATALOG, not listed: `symbolSideForPort` sends the
  /// `ctl` and `net` families to the top edge and `power` to the bottom, and
  /// which templates that reaches is a property of the catalog data. A
  /// hardcoded list would silently stop covering the edge the moment a
  /// template's families changed.
  List<MapEntry<String, TemplateBody>> withPinsOn(
    SymbolSide side, {
    int min = 2,
  }) => catalog.entries.where((e) {
    var n = 0;
    final banks = <String, BankDef>{
      for (final b in e.value.banks) b.key: b,
    };
    for (final port in e.value.ports) {
      final key = port.bankKey;
      final bank = key == null ? null : banks[key];
      if (symbolSideForPort(port, bank: bank) == side) n++;
    }
    return n >= min;
  }).toList();

  group('0 — the catalog actually exercises both edges', () {
    test('several templates carry two or more pins on the top edge, and on '
        'the bottom', () {
      // THE COVERAGE ASSERTION. Every claim below is vacuous on a template
      // with fewer than two pins on the edge in question, so the corpus is
      // checked before it is used.
      expect(
        withPinsOn(SymbolSide.top),
        isNotEmpty,
        reason: 'nothing would exercise the top edge',
      );
      expect(
        withPinsOn(SymbolSide.bottom),
        isNotEmpty,
        reason: 'nothing would exercise the bottom edge',
      );
    });
  });

  group('1 — no two labels on one edge overprint, on any seed template', () {
    test('across the whole catalog, every edge of every symbol is clear', () {
      final offenders = <String>[];
      for (final entry in catalog.entries) {
        final boxes = _labelBoxesByEdge(
          entry.value,
          designator: entry.key,
        );
        for (final side in SymbolSide.values) {
          final hits = _overlaps(boxes[side]!);
          if (hits.isNotEmpty) {
            offenders.add(
              '${entry.key} ${side.name}: ${hits.length} overlapping '
              'pair(s) of ${boxes[side]!.length} labels',
            );
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'port labels overprint each other on:\n  ${offenders.join('\n  ')}',
      );
    });
  });

  group('2 — the turn is what fixed it, and the left edge never needed it', () {
    test('top and bottom labels are TALLER than they are wide; left and '
        'right are the other way round', () {
      // The shape assertion behind the overlap one. A quarter turn is
      // exactly the claim that the run's long axis moved from X to Y, and
      // a layer that stopped rotating would fail here with a message about
      // the geometry rather than about a pair of indices.
      for (final side in <SymbolSide>[SymbolSide.top, SymbolSide.bottom]) {
        final template = withPinsOn(side).first;
        final boxes = _labelBoxesByEdge(
          template.value,
          designator: template.key,
        )[side]!;
        expect(boxes, isNotEmpty, reason: '${template.key} ${side.name}');
        for (final box in boxes) {
          expect(
            box.height,
            greaterThan(box.width),
            reason: '${template.key} ${side.name} label is not turned',
          );
        }
      }

      final flat = withPinsOn(SymbolSide.left).first;
      final leftBoxes = _labelBoxesByEdge(
        flat.value,
        designator: flat.key,
      )[SymbolSide.left]!;
      expect(leftBoxes, isNotEmpty);
      for (final box in leftBoxes) {
        expect(
          box.width,
          greaterThan(box.height),
          reason: '${flat.key} left label should NOT be turned',
        );
      }
    });
  });

  group('3 — a turned label points INTO the body', () {
    test('top labels hang below their pin and bottom labels above theirs', () {
      // ── THE DIRECTION REVERSED, AND THE REASON IS ON THE OTHER SIDE ──
      // #96-A sent these OUTWARD, and outward is the strip a net-label
      // pennant occupies, where its leader runs, and where a drawn wire
      // escapes. Four kinds of ink competing for one band, and the pin
      // label is the one that loses: the smallest type on the sheet and
      // the only one of the four a reader cannot identify from its shape.
      // The field sent a screenshot of exactly that.
      //
      // Inside the body nothing else draws at all, so the strip is
      // uncontested by construction. The body reserves it —
      // `RenderedSymbol.labelBandTop` — and the header band sits below it.
      //
      // THE ROTATION HALF OF THE FIX, and it is what this test guards. The
      // anchor is `midLeft` on both edges now; the SIGN of the rotation is
      // what sends a top run down and a bottom run up. Flip either sign and
      // the labels read back out across the wires again — which no overlap
      // test would notice, because they would still not overlap EACH
      // OTHER.
      const measurer = _Measurer();
      for (final side in <SymbolSide>[SymbolSide.top, SymbolSide.bottom]) {
        final template = withPinsOn(side).first;
        final symbol = _geometryOf(template.value, designator: template.key);

        for (final (port, op) in _labelledPins(symbol, measurer)) {
          if (port.side != side) continue;
          final centre = symbolPortCentreLocal(symbol, port);
          final box = _boxOf(op, measurer);
          if (side == SymbolSide.top) {
            expect(
              box.top,
              greaterThanOrEqualTo(centre.y),
              reason:
                  '${template.key} ${port.label} reaches out of the body, '
                  'into the net-label band',
            );
          } else {
            expect(
              box.bottom,
              lessThanOrEqualTo(centre.y),
              reason:
                  '${template.key} ${port.label} reaches out of the body, '
                  'into the net-label band',
            );
          }
        }
      }
    });
  });
}
