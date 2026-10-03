// draw/sheet/interconnect_sheet.dart — the fallback to net labels and its
// note (DR-225 §11.224.4 and §11.224.5, M6-D3).
//
// NO STARTER REACHES THE FALLBACK IN ITS REAL AREA, and that is measured
// rather than assumed: `interconnect_sheet.dart`'s header gives the figures.
// So the note is proven on a real document in a deliberately narrow box
// inside a real sheet: Whole House's RF sheet, whose tag pills reach
// further sideways than its pennants do, in 220 x 300 pt.

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

InterconnectPartition _partition(RackDocument doc, String domain) =>
    interconnectPartitionsOf(
      buildSchematicScene(
        doc: doc,
        measurer: const FakeMeasurer(),
        expandedBanks: allBanksExpanded(doc),
      ),
    ).partitions.firstWhere((p) => p.domain.v == domain);

SheetDef _sheet(RackDocument doc) => SheetSet.forRacks(
  doc.racks.values,
  interconnectDomains: <SignalDomainDef>[
    doc.registries.signalDomains[const SignalDomainId('video.analog')]!,
  ],
).sheets.firstWhere((s) => s.role == SheetRole.interconnect);

void main() {
  group('chooseInterconnectRender', () {
    test('drawn whenever drawn meets the floor, whatever labels would do', () {
      for (final labels in <double>[3, 6, 9]) {
        expect(
          chooseInterconnectRender(drawnPaperPt: 6, labelsPaperPt: labels),
          InterconnectRender.drawn,
        );
      }
    });

    test('net labels only when drawn misses the floor and labels meet it', () {
      expect(
        chooseInterconnectRender(drawnPaperPt: 5.99, labelsPaperPt: 6),
        InterconnectRender.netLabels,
      );
    });

    test('DRAWN when neither meets it: a swap that reaches no floor buys '
        'nothing and costs the wires (the implementer’s clause)', () {
      expect(
        chooseInterconnectRender(drawnPaperPt: 5.18, labelsPaperPt: 5.39),
        InterconnectRender.drawn,
      );
    });
  });

  group('the fallback, on a real sheet', () {
    late RackDocument doc;
    late SheetDef sheet;
    late DBox narrow;
    late InterconnectDrawing drawing;

    setUp(() {
      doc = _wholeHouse();
      sheet = _sheet(doc);
      final frame = sheetLayoutFor(sheet, doc.revisionBlock).drawingArea;
      narrow = DBox.fromLtwh(frame.left, frame.top, 220, 300);
      drawing = layoutInterconnect(
        doc: doc,
        partition: _partition(doc, 'video.analog'),
        measurer: const FakeMeasurer(),
        area: narrow,
      );
    });

    test('the CONTROL: in its real area the RF sheet is drawn', () {
      final real = layoutInterconnect(
        doc: doc,
        partition: _partition(doc, 'video.analog'),
        measurer: const FakeMeasurer(),
        area: sheetLayoutFor(sheet, doc.revisionBlock).drawingArea,
      );
      expect(real.render, InterconnectRender.drawn);
      expect(real.fellBack, isFalse);
    });

    test('in the narrow box drawn misses the floor, labels meet it, and the '
        'sheet falls back, fitted below the note band', () {
      expect(drawing.drawnPaperPt, lessThan(kMinPrintPt));
      expect(drawing.render, InterconnectRender.netLabels);
      expect(
        drawing.factor.points(drawing.minTextPt),
        greaterThanOrEqualTo(kMinPrintPt),
      );
      expect(drawing.contentArea.top, narrow.top + kInterconnectNoteBandPt);
      expect(drawing.contentArea.bottom, narrow.bottom);
    });

    test('the built sheet prints the note in a ruled box at the upper left, '
        'the labels, and not one wire', () {
      final built = buildInterconnectSheet(
        sheet: sheet,
        drawing: drawing,
        info: doc.info,
        settings: doc.settings,
        revisions: doc.revisionBlock,
        fileName: 'whole_house.rppj',
        issuedAt: DateTime.utc(2026, 10, 3),
        measurer: const FakeMeasurer(),
      );
      final ops = built.scene.ops;
      final texts = ops.whereType<OpText>().map((t) => t.text).toList();
      for (final line in kInterconnectNoteLines) {
        expect(texts, contains(line));
      }
      // ANCHORED ON THE BOX'S OWN HEIGHT: the furniture draws a rectangle
      // from the same corner, and a finder on the corner alone found that.
      final boxes = ops.whereType<OpRect>().where(
        (r) =>
            r.r.left == narrow.left &&
            r.r.top == narrow.top &&
            r.r.height == kInterconnectNoteBandPt - kInterconnectNoteGapPt,
      );
      expect(boxes, hasLength(1));
      expect(boxes.single.r.bottom, lessThanOrEqualTo(drawing.contentArea.top));

      // The labels are the subset scene's own ops; the wires are absent.
      for (final op in drawing.scene.scene.ops) {
        expect(ops.any((o) => identical(o, op)), isTrue);
      }
      for (final op in drawing.wires.ops) {
        expect(ops.any((o) => identical(o, op)), isFalse);
      }
      expect(built.legibility.meetsHardFloor, isTrue);
    });
  });

  test('Whole House’s Network sheet stays drawn under the floor, because '
      'labels miss it too', () {
    final doc = _wholeHouse();
    final net = layoutInterconnect(
      doc: doc,
      partition: _partition(doc, 'net'),
      measurer: const FakeMeasurer(),
      area: interconnectDrawingArea(
        revisionRowCount: revisionBodyRowCount(doc.revisionBlock),
        stamped: false,
      ),
    );
    expect(net.drawnPaperPt, lessThan(kMinPrintPt));
    expect(net.render, InterconnectRender.drawn);
  });
}
