// PdfDiagramCanvas's shape primitives, ON THE PAGE (docs/08-pdf-export.md
// §7.7).
//
// ─────────────────────────────────────────────────────────────────────────
// `expect(pdfBytes, isNotEmpty)` WAS NOT A TEST OF ANYTHING
// ─────────────────────────────────────────────────────────────────────────
// This file used to build the document below and assert only that the
// saved bytes were non-empty. Measured: a painter that constructs the
// canvas and draws NOTHING AT ALL — no `drawRect`, no `drawCircle`, no
// `drawPolyline` — saves to 3019 non-empty bytes, because an embedded
// TrueType subset alone clears any such threshold. So every mutation that
// merely kept the canvas from throwing survived: `drawPolyline` as a
// no-op, `drawCircle` at radius 0, the dropped `-o.y` counter-flip in
// `drawText`, `boxHeight` ignored in the construction `cm`.
//
// `drawPolyline` in particular has NO other content-stream-level coverage
// anywhere in the repository — `stroke_scaling_test` covers `drawRect`
// widths, `symbol_layer_pdf_test` covers circles and colours,
// `elevation_true_scale_test` covers path hulls — so a broken polyline
// reached paper with a green suite.
//
// This file therefore reads back what each call put on the page, in PDF
// USER SPACE, through the same interpreter the dimensional gate uses. The
// page is 200 x 100 with ZERO margins so the widget box IS the page box
// and every expectation below is an absolute position computed from the
// draw call's own literals and the 100 pt flip — which is what makes the
// `boxHeight` mutation visible at all.

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

/// The painter's box, and so the whole page.
const double _boxW = 200;
const double _boxH = 100;

const FontRef _fontRef = FontRef('Jost');

const TextStyleSpec _textStyle = TextStyleSpec(
  font: _fontRef,
  sizePt: 12,
  argb: 0xFF000000,
  anchor: TextAnchor.topLeft,
);

const String _label = 'AV Wa To Ty';
const DPt _labelAt = DPt(10, 40);

const Stroke _stroke = Stroke(argb: 0xFF000000, widthPt: 1);
const Fill _fill = Fill(0xFFCCCCCC);

/// Diagram Y (top-left origin, Y down) as PDF user-space Y (Y up).
///
/// The ONE line of arithmetic the construction `cm` is supposed to do.
double _userY(double diagramY) => _boxH - diagramY;

void main() {
  late Uint8List fontBytes;
  late Uint8List pdfBytes;
  late RecoveredStream page;
  late TextMetrics labelMetrics;

  setUpAll(() async {
    fontBytes = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();

    // UNCOMPRESSED, so the one content stream is readable operator text,
    // and ZERO MARGINS, so the CustomPaint box is the page and user-space
    // coordinates are absolute rather than offset by a layout the test
    // does not control.
    final doc = pw.Document(compress: false);
    // ONE embedded face, measured and drawn with. `PdfFontMeasurer
    // .fromBytes` would register a SECOND copy of Jost in the same
    // document, and two embedded fonts mean two /ToUnicode maps — which
    // `parseToUnicodeCMap` refuses outright rather than merging, so the
    // text below could not be read back at all.
    final fonts = <FontRef, PdfFont>{
      _fontRef: PdfTtfFont(doc.document, ByteData.sublistView(fontBytes)),
    };
    final measurer = PdfFontMeasurer(fonts);
    labelMetrics = measurer.measureText(_label, _textStyle);

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(_boxW, _boxH, marginAll: 0),
        build: (context) => pw.CustomPaint(
          size: const PdfPoint(_boxW, _boxH),
          painter: (graphics, size) {
            PdfDiagramCanvas(
                graphics: graphics,
                boxHeight: size.y, // size.y, NOT page height -- §7.4
                fonts: fonts,
                measurer: measurer,
              )
              ..save()
              ..drawRect(
                const DBox.fromLtwh(10, 10, 50, 20),
                fill: _fill,
                stroke: _stroke,
              )
              ..drawRoundRect(
                const DBox.fromLtwh(70, 10, 50, 20),
                const Radii.circular(4),
                fill: _fill,
              )
              ..drawCircle(const DPt(150, 20), 8, stroke: _stroke)
              ..drawPolyline(const [
                DPt(10, 60),
                DPt(40, 80),
                DPt(70, 60),
              ], _stroke)
              ..drawText(_label, _labelAt, _textStyle)
              ..restore()
              ..dispose();
          },
        ),
      ),
    );

    pdfBytes = Uint8List.fromList(await doc.save());
    page = interpretContentStream(
      extractOperatorStream(pdfBytes, mustContain: ' re '),
      toUnicode: parseToUnicodeCMap(pdfBytes),
    );
  });

  group('the recovery found the page it is about', () {
    test('the document saved, and the interpreter got real geometry out of '
        'it', () {
      // The floor the old assertion set, kept — and then made to mean
      // something by everything below. A painter that draws NOTHING also
      // clears `isNotEmpty` and `length > 2000`; it does not clear this.
      expect(pdfBytes, isNotEmpty);
      expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');
      expect(page.paths.length, greaterThanOrEqualTo(5));
      expect(page.texts, hasLength(1));
      // ...and the shapes are not all the same shape, which is what a
      // broken CTM walk looks like.
      expect(
        page.paths.map((p) => '${p.left},${p.bottom},${p.width}').toSet(),
        hasLength(greaterThan(3)),
      );
    });
  });

  group('every primitive reaches the page where it was asked to', () {
    test('drawRect lands at its literal rectangle, FILLED AND STROKED', () {
      // A `re` per paint operation: `drawRect` emits the rectangle once for
      // the fill and once for the stroke, so two of them is the proof that
      // BOTH paints happened rather than an implementation detail.
      final rects = page.rects
          .where((r) => (r.width - 50).abs() < 1e-6)
          .toList();
      expect(rects, hasLength(2), reason: 'fill and stroke are two paints');

      for (final r in rects) {
        expect(r.left, closeTo(10, 1e-6));
        expect(r.right, closeTo(60, 1e-6));
        // Diagram y 10..30, top-left origin, Y down -> user space 70..90.
        expect(r.bottom, closeTo(_userY(30), 1e-6));
        expect(r.top, closeTo(_userY(10), 1e-6));
      }
    });

    test('drawRoundRect lands at its literal rectangle, as CURVES', () {
      // A rounded rect lowers to `m`/`l`/`c` and emits no `re` at all, so
      // it is identified by its 17-point path rather than by its size —
      // which `drawRect` above shares.
      final rounded = page.paths.where((p) => p.pointCount == 17).toList();
      expect(rounded, hasLength(1), reason: 'fill only, so one paint');

      final r = rounded.single;
      expect(r.left, closeTo(70, 1e-6));
      expect(r.right, closeTo(120, 1e-6));
      expect(r.bottom, closeTo(_userY(30), 1e-6));
      expect(r.top, closeTo(_userY(10), 1e-6));
      // The corner radius is INSIDE the box, not added to it: a rounded
      // rect that grew by its radius would be 58 x 28 here.
      expect(r.width, closeTo(50, 1e-6));
      expect(r.height, closeTo(20, 1e-6));
    });

    test('drawCircle emits a circle of the RADIUS IT WAS GIVEN', () {
      // radius 8 at (150, 20) is a 16 x 16 box. A `drawCircle` that
      // emitted radius 0 — or that passed the diameter — still produces a
      // valid PDF and still clears every byte-count assertion.
      final circle = page.pathSized(16, 16);
      expect(circle.left, closeTo(142, 1e-6));
      expect(circle.right, closeTo(158, 1e-6));
      expect(circle.bottom, closeTo(_userY(28), 1e-6));
      expect(circle.top, closeTo(_userY(12), 1e-6));
      // Four cubic segments: `PdfGraphics.drawEllipse`'s own construction.
      expect(circle.pointCount, greaterThanOrEqualTo(12));
    });

    test('drawPolyline emits EVERY vertex — its only content-stream '
        'coverage in the repository', () {
      // (10,60) (40,80) (70,60) is a 60 x 20 hull. A no-op `drawPolyline`
      // leaves the page otherwise intact and every other assertion here
      // green, which is exactly how it survived.
      final line = page.pathSized(60, 20);
      expect(line.pointCount, 3, reason: 'a vertex was dropped or added');
      expect(line.left, closeTo(10, 1e-6));
      expect(line.right, closeTo(70, 1e-6));
      expect(line.bottom, closeTo(_userY(80), 1e-6));
      expect(line.top, closeTo(_userY(60), 1e-6));
      // Stroked, not filled: the width in force is the 1 pt stroke at
      // CTM scale 1.
      expect(line.lineWidthPt, closeTo(1, 1e-6));
    });

    test('drawText puts the BASELINE below a topLeft anchor, not above '
        'it', () {
      // ==================================================================
      // THE `-o.y` COUNTER-FLIP, WHICH HAS NO OTHER TEST HERE.
      // ==================================================================
      // `anchorOffset(topLeft, m)` is `(0, ascent)` — the offset from the
      // anchor DOWN to the baseline. The local frame the glyphs are drawn
      // in has already been flipped Y-up, so the sign must be negated on
      // the way into `drawString`. Drop the negation and the text is drawn
      // one full ascent ABOVE its anchor instead of below it: every label
      // on every sheet climbs out of the box it belongs to, and the page
      // still renders.
      final text = page.texts.single;
      expect(text.text, _label);
      expect(text.sizePt, closeTo(12, 1e-6));
      expect(text.baselineX, closeTo(_labelAt.x, 1e-6));

      final anchorUserY = _userY(_labelAt.y); // 60
      expect(
        text.baselineY,
        closeTo(anchorUserY - labelMetrics.ascent, 1e-4),
        reason: 'the baseline is one ascent BELOW the topLeft anchor',
      );
      // Stated separately as a pure direction claim, so the assertion
      // above cannot be satisfied by an ascent that is itself zero.
      expect(labelMetrics.ascent, greaterThan(1));
      expect(text.baselineY, lessThan(anchorUserY));
    });
  });

  group('the ONE global flip is absorbed at construction (§7.4)', () {
    test('boxHeight is what maps diagram Y to paper Y, and every shape '
        'agrees on it', () {
      // The construction `cm` is `1 0 0 -1 0 boxHeight`. Ignore the
      // `boxHeight` term and every mark on the page slides by 100 pt — off
      // the paper here, and by exactly the page margin on a real sheet,
      // which §7.4 calls out as "plausible enough to ship".
      //
      // Asserted as an INVARIANT across all five primitives rather than on
      // one of them: diagram Y + user Y == boxHeight, for the top edge of
      // every shape whose diagram top is known.
      final rect = page.rects.firstWhere((r) => (r.width - 50).abs() < 1e-6);
      final roundRect = page.paths.firstWhere((p) => p.pointCount == 17);
      final tops = <String, (double diagramTop, double userTop)>{
        'rect': (10, rect.top),
        'roundRect': (10, roundRect.top),
        'circle': (12, page.pathSized(16, 16).top),
        'polyline': (60, page.pathSized(60, 20).top),
      };
      for (final entry in tops.entries) {
        expect(
          entry.value.$1 + entry.value.$2,
          closeTo(_boxH, 1e-6),
          reason: entry.key,
        );
      }

      // ...and nothing is drawn off the paper, which a wrong flip origin
      // would do wholesale.
      for (final p in page.paths) {
        expect(p.bottom, greaterThanOrEqualTo(-1));
        expect(p.top, lessThanOrEqualTo(_boxH + 1));
      }
    });
  });
}
