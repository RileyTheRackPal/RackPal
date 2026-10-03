// draw/sheet/interconnect_sheet.dart — T6.01…, rendered drawn (DR-001
// §11.1.2, DR-225).

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../scene/schematic_test_document.dart';
import 'sheet_test_support.dart' show testRack;

({SheetSet set, List<InterconnectDrawing> drawings}) _resolve(
  RackDocument doc,
) {
  const measurer = FakeMeasurer();
  final split = interconnectPartitionsOf(
    buildSchematicScene(
      doc: doc,
      measurer: measurer,
      expandedBanks: allBanksExpanded(doc),
    ),
  );
  final area = interconnectDrawingArea(
    revisionRowCount: revisionBodyRowCount(doc.revisionBlock),
    stamped: false,
  );
  final drawings = [
    for (final p in split.partitions)
      layoutInterconnect(
        doc: doc,
        partition: p,
        measurer: measurer,
        area: area,
      ),
  ];
  final set = SheetSet.forRacks(
    <Rack>[testRack()],
    interconnectDomains: [
      for (final p in split.partitions) doc.registries.signalDomains[p.domain]!,
    ],
  );
  return (set: set, drawings: drawings);
}

void main() {
  test('every link in a partition gets a drawn wire, and no sheet draws a '
      'link from another domain (DR-001 §11.1.2: a partition IS a filter)', () {
    final doc = buildSchematicTestDocument();
    for (final d in _resolve(doc).drawings) {
      expect(
        d.wires.wires.map((w) => w.linkId).toSet(),
        d.partition.linkIds.toSet(),
        reason: d.partition.domain.v,
      );
      expect(d.wires.unroutableLinkIds, isEmpty);
    }
  });

  test('the sheet replays the schematic builders: its symbol ops and wire '
      "ops are the subset scene's own, bracketed once", () {
    final doc = buildSchematicTestDocument();
    final r = _resolve(doc);
    final sheets = r.set.sheets
        .where((s) => s.role == SheetRole.interconnect)
        .toList();
    expect(sheets, hasLength(r.drawings.length));
    for (var i = 0; i < sheets.length; i++) {
      final d = r.drawings[i];
      final built = buildInterconnectSheet(
        sheet: sheets[i],
        drawing: d,
        info: ProjectInfo(),
        settings: ProjectSettings(),
        revisions: const <RevisionEntry>[],
        fileName: 'test.rppj',
        issuedAt: DateTime.utc(2026, 10, 3),
        measurer: const FakeMeasurer(),
      );
      final ops = built.scene.ops;
      for (final op in d.wires.ops) {
        expect(ops.where((o) => identical(o, op)), hasLength(1));
      }
      // NO NET LABEL ON A DRAWN SHEET: a pennant is an `OpPath`, and the
      // symbol layer and the wire layer emit none.
      final labelOps = d.scene.scene.ops.sublist(d.scene.symbolTier.ops.length);
      for (final op in labelOps) {
        expect(ops.any((o) => identical(o, op)), isFalse);
      }
    }
  });

  test('a drawing that fits is never enlarged past its design size', () {
    final doc = buildSchematicTestDocument();
    for (final d in _resolve(doc).drawings) {
      expect(d.factor.unitsToPoints, lessThanOrEqualTo(kInterconnectMaxFactor));
    }
  });

  test('the drawing, at its fit, lies inside the drawing area', () {
    final doc = buildSchematicTestDocument();
    for (final d in _resolve(doc).drawings) {
      final s = d.factor.unitsToPoints;
      expect(d.content.width * s, lessThanOrEqualTo(d.area.width + 1e-9));
      expect(d.content.height * s, lessThanOrEqualTo(d.area.height + 1e-9));
    }
  });

  test('a locked device keeps its position on its sheet; an unlocked one '
      'with a stored position is laid out again (§11.224.3)', () {
    final doc = buildSchematicTestDocument();
    final full = buildSchematicScene(doc: doc, measurer: const FakeMeasurer());
    final part = interconnectPartitionsOf(full).partitions.first;
    final locked = part.deviceIds.first;
    final loose = part.deviceIds.last;
    // Store a position for BOTH, as DR-187 does on any edit, then unpin
    // one: it keeps its stored position and loses its lock.
    final at = DateTime.utc(2026, 10, 3);
    DocumentController(doc)
      ..run(
        SetSymbolPinnedCommand(
          positions: {locked: const Pt(500, 500), loose: const Pt(900, 900)},
          pinned: true,
          now: at,
          actor: 'test',
        ),
      )
      ..run(
        SetSymbolPinnedCommand(
          positions: {loose: const Pt(900, 900)},
          pinned: false,
          now: at,
          actor: 'test',
        ),
      );
    expect(storedSymbolPositions(doc)[loose], const Pt(900, 900));

    final d = layoutInterconnect(
      doc: doc,
      partition: part,
      measurer: const FakeMeasurer(),
      area: interconnectDrawingArea(revisionRowCount: 0, stamped: false),
    );
    expect(d.scene.positions[locked], const Pt(500, 500));
    expect(d.scene.positions[loose], isNot(const Pt(900, 900)));
  });
}
