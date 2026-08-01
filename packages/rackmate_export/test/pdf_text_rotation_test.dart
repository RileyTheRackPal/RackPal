// #96-A/1 — the PDF backend turns text the same way the IR says, ON PAPER.
//
// ═══════════════════════════════════════════════════════════════════════
// THE COUNTER-FLIP IS WHY THIS NEEDS A TEST AND NOT A READING
// ═══════════════════════════════════════════════════════════════════════
// `PdfDiagramCanvas.drawText` negates the angle:
//
//     ..multiply(Matrix4.identity()..setEntry(1, 1, -1.0))
//     ..multiply(Matrix4.rotationZ(-s.rotationRad)),
//
// and the negation is CORRECT — the local frame has just been flipped to
// Y-up, and a rotation expressed in a Y-down frame reverses handedness when
// you flip it. But "correct" there is an argument, and the argument was
// never checked against paper. `design-pdf-export.md`'s open-questions list
// is explicit about the cost: *"Sign errors here are invisible until
// someone rotates a label."*
//
// Nothing in the product rotated one until #96-A, so this is the first
// commit that could close the question, and it does it BEFORE the symbol
// layer depends on the answer.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY `midLeft` AND NOT `baselineLeft`
// ═══════════════════════════════════════════════════════════════════════
// The interpreter recovers a text run's BASELINE ORIGIN and not its
// direction. Under `baselineLeft` the anchor offset is (0, 0), so rotating
// about the anchor leaves the baseline origin exactly where it was and all
// three runs below would report the same point — a test that passed whether
// or not rotation did anything at all.
//
// `midLeft` has a non-zero vertical offset, so the rotation MOVES the
// baseline origin, and moves it in OPPOSITE horizontal directions for the
// two quarter turns. That is the sign, visible in a number the harness can
// actually read.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_export/rackmate_export.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

const double _boxW = 300;
const double _boxH = 200;
const FontRef _fontRef = FontRef('Jost');

/// Distinct strings so the interpreter can tell the three runs apart.
const String _flat = 'FLAT';
const String _ccw = 'ANTI';
const String _cw = 'CLOCK';

/// One anchor for all three, so every difference below is the rotation.
const DPt _at = DPt(150, 100);

TextStyleSpec _style(double rotationRad) => TextStyleSpec(
  font: _fontRef,
  sizePt: 12,
  argb: 0xFF000000,
  anchor: TextAnchor.midLeft,
  rotationRad: rotationRad,
);

/// Diagram Y (top-left origin, Y down) as PDF user-space Y (Y up).
double _userY(double diagramY) => _boxH - diagramY;

void main() {
  late RecoveredStream page;
  late double dy;

  setUpAll(() async {
    final fontBytes = File(
      '../../apps/rackmate/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();

    final doc = pw.Document(compress: false);
    final fonts = <FontRef, PdfFont>{
      _fontRef: PdfTtfFont(doc.document, ByteData.sublistView(fontBytes)),
    };
    final measurer = PdfFontMeasurer(fonts);

    // THE OFFSET THE ROTATION ACTS ON, from the shared helper rather than
    // from a literal: `anchorOffset(midLeft, m).y` is `ascent - height / 2`,
    // and both backends compute the run's position through this same
    // function. A number typed in here would be asserting the test's
    // arithmetic instead of the backend's.
    dy = anchorOffset(
      TextAnchor.midLeft,
      measurer.measureText(_flat, _style(0)),
    ).y;

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(_boxW, _boxH, marginAll: 0),
        build: (context) => pw.CustomPaint(
          size: const PdfPoint(_boxW, _boxH),
          painter: (PdfGraphics graphics, PdfPoint size) {
            PdfDiagramCanvas(
              graphics: graphics,
              boxHeight: size.y,
              fonts: fonts,
              measurer: measurer,
            )
              ..save()
              ..drawText(_flat, _at, _style(0))
              ..drawText(_ccw, _at, _style(-math.pi / 2))
              ..drawText(_cw, _at, _style(math.pi / 2))
              ..restore()
              ..dispose();
          },
        ),
      ),
    );

    final pdfBytes = Uint8List.fromList(await doc.save());
    page = interpretContentStream(
      // `Tf` (set font) rather than a show operator: the `pdf` package emits
      // text through `TJ` (array-form show) as well as `Tj`, so keying on
      // one of them finds the stream only by luck. Any page carrying text
      // sets a font first.
      extractOperatorStream(pdfBytes, mustContain: 'Tf'),
      toUnicode: parseToUnicodeCMap(pdfBytes),
    );
  });

  RecoveredText run(String text) =>
      page.texts.firstWhere((t) => t.text.replaceAll(' ', '') == text);

  group('the page carries all three runs', () {
    test('and the anchor offset is non-zero, or the test proves nothing', () {
      expect(page.texts, hasLength(3));
      // THE PRECONDITION THIS FILE'S HEADER ARGUES FOR. If `midLeft` ever
      // became a zero-offset anchor, every assertion below would hold for a
      // backend that ignored rotation entirely.
      expect(dy.abs(), greaterThan(0.5));
    });
  });

  group('the unrotated run is the baseline the others are measured from', () {
    test('it sits at the anchor, dropped by the anchor offset', () {
      final flat = run(_flat);
      expect(flat.baselineX, closeTo(_at.x, 0.01));
      expect(flat.baselineY, closeTo(_userY(_at.y + dy), 0.01));
    });
  });

  group('the two quarter turns move the origin OPPOSITE ways', () {
    // Rotating (0, dy) about the anchor by t, in the Y-DOWN diagram frame
    // where positive is clockwise:
    //     -pi/2  ->  (+dy,  0)
    //     +pi/2  ->  (-dy,  0)
    // Both land level with the anchor and differ only in which side.

    test('anticlockwise puts the origin to the RIGHT of the anchor', () {
      final ccw = run(_ccw);
      expect(ccw.baselineX, closeTo(_at.x + dy, 0.01));
      expect(ccw.baselineY, closeTo(_userY(_at.y), 0.01));
    });

    test('clockwise puts it to the LEFT', () {
      final cw = run(_cw);
      expect(cw.baselineX, closeTo(_at.x - dy, 0.01));
      expect(cw.baselineY, closeTo(_userY(_at.y), 0.01));
    });

    test('so the sign is observable: the two are not the same point, and '
        'they straddle the unrotated one', () {
      // The assertion a sign error fails. Negating the angle in
      // `PdfDiagramCanvas` swaps these two; dropping the negation
      // ALTOGETHER also swaps them, because the Y-flip already reversed
      // handedness. Either way this fails and the two above fail with it.
      final ccw = run(_ccw);
      final cw = run(_cw);
      expect(ccw.baselineX, greaterThan(_at.x));
      expect(cw.baselineX, lessThan(_at.x));
      expect(ccw.baselineX - _at.x, closeTo(_at.x - cw.baselineX, 0.01));
    });
  });

  group('paper agrees with the bounds canvas', () {
    test('an anticlockwise run climbs the page on BOTH, which is what a '
        'top-edge port label needs', () {
      // THE CROSS-BACKEND CLAIM, stated as one assertion rather than left
      // implicit across two files. `BoundsCanvas` is what page fitting and
      // clipping read; the PDF is what prints. A label that climbed on one
      // and descended on the other would scale-to-fit correctly and then
      // print into the symbol body.
      final ink = (BoundsCanvas(measurer: _CoreMeasurer())
            ..drawText(_ccw, _at, _style(-math.pi / 2)))
          .bounds!;
      // Diagram space: "up" is a SMALLER y, and the ink must reach above
      // the anchor.
      expect(ink.top, lessThan(_at.y));

      // PDF user space: "up" is a LARGER y. The anticlockwise run's origin
      // is level with the anchor and its glyphs advance upward from there,
      // so the run's own baseline sits at or above the flat run's.
      expect(run(_ccw).baselineY, greaterThan(run(_flat).baselineY));
    });
  });
}

/// A pure-Dart measurer for the `BoundsCanvas` half of the cross-check.
///
/// DELIBERATELY NOT `PdfFontMeasurer`: the claim is about DIRECTION, and
/// tying the bounds side to the same font subset would make this a test of
/// one measurer used twice. Any positive-metric measurer must produce a box
/// that reaches above the anchor.
final class _CoreMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.6,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}
