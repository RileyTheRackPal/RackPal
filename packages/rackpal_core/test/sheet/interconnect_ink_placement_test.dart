// A drawn interconnect sheet placed by its own ink (`#998`, DR-232).
//
// The defect was a sheet of two devices spread over 604 units for 344 of
// body, by net-label room it never draws; the first attempt at removing it
// let one device's pill touch the next. So these assert the two things
// together: the sheet fits larger, and nothing a device draws lands on
// another device.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../scene/schematic_test_document.dart';

RackDocument _wholeHouse() =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/whole_house.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

List<InterconnectDrawing> _drawings(RackDocument doc) {
  const measurer = FakeMeasurer();
  final split = interconnectPartitionsOf(
    buildSchematicScene(
      doc: doc,
      measurer: measurer,
      expandedBanks: allBanksExpanded(doc),
    ),
  );
  final area = interconnectDrawingArea(revisionRowCount: 0, stamped: false);
  return [
    for (final p in split.partitions)
      layoutInterconnect(
        doc: doc,
        partition: p,
        measurer: measurer,
        area: area,
      ),
  ];
}

InterconnectDrawing _network(RackDocument doc) =>
    _drawings(doc).firstWhere((d) => d.partition.domain.v == 'net');

RenderedSymbol _named(InterconnectDrawing d, String designator) =>
    d.scene.symbols.firstWhere((s) => s.designator == designator);

void main() {
  test('WHOLE HOUSE’S NETWORK SHEET: the two islands sit side by side, and '
      'the sheet prints at its design size', () {
    final net = _network(_wholeHouse());
    final pp = _named(net, 'PP-1');
    final liu = _named(net, 'LIU-1');
    // SIDE BY SIDE: LIU-1 starts right of PP-1 and the two share a band.
    expect(liu.bodyRect.left, greaterThan(pp.bodyRect.right));
    expect(liu.bodyRect.top, lessThan(pp.bodyRect.bottom));
    expect(net.render, InterconnectRender.drawn);
    expect(net.factor.unitsToPoints, kInterconnectMaxFactor);
  });

  for (final (name, doc) in [
    ('Whole House', _wholeHouse),
    ('the schematic fixture', buildSchematicTestDocument),
    ('the feedback fixture', () => buildSchematicTestDocument(feedback: true)),
  ]) {
    test('NOTHING A DEVICE DRAWS LANDS ON ANOTHER DEVICE: $name, every '
        'drawn sheet', () {
      final sheets = _drawings(doc()).where(
        (d) => d.render == InterconnectRender.drawn,
      );
      expect(sheets, isNotEmpty, reason: 'control: a drawn sheet exists');
      for (final d in sheets) {
        for (final owner in d.scene.symbols) {
          final ink = d.wires.endInk[owner.id];
          if (ink == null) continue;
          for (final other in d.scene.symbols) {
            if (other.id == owner.id) continue;
            expect(
              ink.intersects(other.bodyRect),
              isFalse,
              reason:
                  '${d.partition.domain.v}: ${owner.designator}’s stubs and '
                  'pills reach ${other.designator}',
            );
          }
        }
      }
    });
  }

  test('IN A TALL NARROW AREA THE ISLANDS STACK, and LIU-1’s pill clears '
      'PP-1: the case the first attempt got wrong', () {
    final doc = _wholeHouse();
    const measurer = FakeMeasurer();
    final part = interconnectPartitionsOf(
      buildSchematicScene(
        doc: doc,
        measurer: measurer,
        expandedBanks: allBanksExpanded(doc),
      ),
    ).partitions.firstWhere((p) => p.domain.v == 'net');
    final d = layoutInterconnect(
      doc: doc,
      partition: part,
      measurer: measurer,
      area: const DBox.fromLtwh(0, 0, 300, 1200),
    );
    final pp = _named(d, 'PP-1');
    final liu = _named(d, 'LIU-1');
    expect(
      liu.bodyRect.top,
      greaterThan(pp.bodyRect.bottom),
      reason: 'stacked',
    );
    // THE RULING'S GAP, BETWEEN INKS (§11.231.1), not merely no contact.
    final gap =
        const SchematicMetrics().layout.nodeGapGu * kSchematicUnitsPerGrid;
    expect(
      d.wires.endInk[liu.id]!.top - pp.bodyRect.bottom,
      greaterThanOrEqualTo(gap),
    );
  });

  test('A LOCK HOLDS (§11.231.3): with LIU-1 locked, no island moves and '
      'LIU-1 stays where it was put', () {
    final doc = _wholeHouse();
    final liuId = doc.devices.values
        .firstWhere((d) => d.designator == 'LIU-1')
        .id;
    DocumentController(doc).run(
      SetSymbolPinnedCommand(
        positions: {liuId: const Pt(0, 200)},
        pinned: true,
        now: DateTime.utc(2026, 10, 4),
        actor: 'test',
      ),
    );
    final net = _network(doc);
    expect(net.scene.positions[liuId], const Pt(0, 200));
    final pp = _named(net, 'PP-1');
    final liu = _named(net, 'LIU-1');
    expect(
      liu.bodyRect.left > pp.bodyRect.right &&
          liu.bodyRect.top < pp.bodyRect.bottom,
      isFalse,
      reason: 'not wrapped beside PP-1 around a locked device',
    );
  });

  test('A COLUMN OF CONNECTED DEVICES keeps its order, top to bottom', () {
    for (final d in _drawings(buildSchematicTestDocument())) {
      for (final layer in d.scene.layout.layers) {
        final tops = [
          for (final id in layer)
            if (d.scene.symbols.where((s) => s.id == id).firstOrNull
                case final s?)
              s.bodyRect.top,
        ];
        expect(tops, orderedEquals([...tops]..sort()));
      }
    }
  });
}
