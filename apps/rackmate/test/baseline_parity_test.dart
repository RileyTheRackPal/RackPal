// apps/rackmate/test/baseline_parity_test.dart
//
// THE stop-the-line parity gate (docs/08-pdf-export.md §11.2 "Baseline
// parity" / §11.3 "If the parity test does not pass, stop"; CR-081, CR-082,
// CR-085, CR-086, AC-007).
//
// WHY THIS TEST LIVES HERE. apps/rackmate is the only package in the
// workspace permitted to depend on rackmate_export (the PDF backend) and
// rackmate_ui (the Flutter backend) at the same time — everywhere else they
// are siblings that may not import each other (docs/03-architecture.md §7.1).
// It needs a real dart:ui text layout, so it runs under `flutter test`, not
// `dart test`.
//
// WHAT IT ACTUALLY PROVES, AND HOW IT COULD FAIL (this matters — the project
// has a cautionary tale, PAL-1, of a check that "passed" three times while a
// real defect shipped underneath it because it read a summary instead of
// exercising real code). This test does NOT compare two independently
// hard-coded numbers, and it does NOT mock the transform math. For each
// fixture it:
//
//   * runs the REAL PdfDiagramCanvas.drawText against a REAL PdfGraphics,
//     serialises the document, and recovers the baseline the PDF backend
//     ACTUALLY emitted by reading the text matrix (`cm`) and text-position
//     (`Td`) operators straight out of the (uncompressed) page content
//     stream. The recovered diagram-space baseline is `M_text · (Td)` — the
//     exact bytes a PDF viewer will consume. A sign error in drawText's local
//     counter-flip, or flipping `-o.y` to `+o.y`, changes those bytes and
//     moves the recovered baseline (docs/08-pdf-export.md §11.1 item 4 — the
//     class of bug this is built to catch).
//
//   * runs the REAL FlutterDiagramCanvas.drawText against a recording
//     dart:ui Canvas that captures the actual `translate` and the actual
//     `Offset` the backend hands to `TextPainter.paint` (i.e. the real
//     `o.y - baselineOffset`), plus the real Skia-laid-out Paragraph. The
//     baseline the Flutter backend ACTUALLY places is
//     `translate.dy + paintOffset.dy + paragraph.alphabeticBaseline`
//     (alphabeticBaseline == what computeDistanceToActualBaseline returns —
//     verified against the installed Flutter 3.44.4 SDK). A sign error in the
//     backend's paint offset moves that number.
//
// The two numbers are derived INDEPENDENTLY from the two backends' real
// output. When both backends are correct they agree to well under a
// hundredth of a point (they must — both anchor via the one shared
// PdfFontMeasurer and the one shared anchorOffset helper), and the assertion
// passes. If EITHER backend's own transform/anchor arithmetic is wrong, the
// two numbers diverge and the assertion fails. That is the whole point.
//
// HONEST LIMITS, stated plainly (honesty policy):
//   * The cross-backend gate detects a divergence introduced by ONE backend.
//     A bug in a genuinely shared component (anchorOffset, the measurer)
//     shifts BOTH backends equally and would slip past a pure parity check —
//     by design, since parity is about backend agreement, not about the
//     shared helper's own correctness. anchorOffset/PdfFontMeasurer are
//     covered by their own package tests. To keep this gate from being
//     merely self-consistent, each fixture ALSO pins the PDF baseline to the
//     shared contract (`at + anchorOffset`) and confirms the global Y-flip is
//     actually present in the emitted `cm` (d == -1 about boxHeight), so a
//     regression that moved BOTH backends off the contract in lockstep would
//     still be caught on the PDF side.
//   * The Flutter reconstruction is algebraically insensitive to which font
//     Skia loaded (the paragraph's own baseline cancels out of the placement
//     by construction — that cancellation is exactly why the backend is
//     correct). So a *separate* assertion pins the real Skia line width to
//     PdfFont.stringMetrics' advance, which DOES depend on the right font
//     being loaded and on kerning staying disabled (§7.6 divergence #7).

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_export/rackmate_export.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

// ── the fixture, per §11.2 ────────────────────────────────────────────────
const String _kFixtureText = 'AV Wa To Ty'; // kerning-heavy on purpose
const String _kFamily = 'IBM Plex Sans';
const FontRef _kFont = FontRef(_kFamily);
const DPt _kAt = DPt(100, 200);
const double _kBoxHeight = 500; // the PDF page/box height we flip about

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ONE shared measurer instance, backed by the REAL bundled TTF bytes,
  // injected into BOTH backends (docs/08-pdf-export.md §7.5, CR-081).
  late Uint8List fontBytes;
  late PdfFontMeasurer measurer;

  setUpAll(() async {
    fontBytes = _loadFontBytes();

    // Register the same TTF with Flutter's engine so TextPainter rasterises
    // and lays out the SAME font PdfFont.stringMetrics measures (CR-080). If
    // this silently failed, the width-parity assertion below would catch it.
    await ui.loadFontFromList(fontBytes, fontFamily: _kFamily);

    // The measurer's PdfFont only needs SOME PdfDocument to exist (metrics
    // are document-independent); it is shared verbatim by both backends.
    final metricsDoc = PdfDocument();
    final metricsFont =
        PdfTtfFont(metricsDoc, ByteData.sublistView(fontBytes));
    measurer = PdfFontMeasurer(<FontRef, PdfFont>{_kFont: metricsFont});
  });

  group('precondition — the shared measurement seam is genuinely shared', () {
    test('both backends return byte-identical TextMetrics (same instance)',
        () {
      // If this ever fails, the interesting parity assertion below is
      // meaningless, so it is asserted first as a guard (task step 6).
      const style = TextStyleSpec(
        font: _kFont,
        sizePt: 12,
        argb: 0xFF000000,
        anchor: TextAnchor.baselineLeft,
      );

      final rec = _RecordingCanvas();
      final flutterCanvas = FlutterDiagramCanvas(rec, measurer: measurer);

      final pdfDoc = PdfDocument(compress: false);
      final pdfFont = PdfTtfFont(pdfDoc, ByteData.sublistView(fontBytes));
      final page = PdfPage(pdfDoc, pageFormat: const PdfPageFormat(400, 500));
      final pdfCanvas = PdfDiagramCanvas(
        graphics: page.getGraphics(),
        boxHeight: _kBoxHeight,
        fonts: <FontRef, PdfFont>{_kFont: pdfFont},
        measurer: measurer,
      );

      final a = flutterCanvas.measureText(_kFixtureText, style);
      final b = pdfCanvas.measureText(_kFixtureText, style);

      expect(a.advanceWidth, b.advanceWidth);
      expect(a.ascent, b.ascent);
      expect(a.descent, b.descent);
      expect(a.capHeight, b.capHeight);
      expect(a.xHeight, b.xHeight);
      expect(a.lineHeight, b.lineHeight);
      expect(a.height, b.height);
      // And a non-degenerate measurement (the real font actually measured).
      expect(a.advanceWidth, greaterThan(0));
      expect(a.ascent, greaterThan(0));
    });
  });

  group('baseline parity — screen vs print agree in diagram space', () {
    // baselineLeft isolates the "dy must be EXACTLY 0" case: any nonzero
    // drift is unambiguous. topLeft exercises the ascent/height math (dy =
    // ascent), where a dropped or doubled ascent term would show up. Two
    // sizes guard a units error that only bites at one scale (task step 2).
    for (final anchor in const [TextAnchor.baselineLeft, TextAnchor.topLeft]) {
      for (final sizePt in const [12.0, 24.0]) {
        test('$_kFixtureText @ ${sizePt}pt, $anchor', () async {
          final style = TextStyleSpec(
            font: _kFont,
            sizePt: sizePt,
            argb: 0xFF102030,
            anchor: anchor,
          );

          final m = measurer.measureText(_kFixtureText, style);
          final o = anchorOffset(anchor, m); // the shared contract point

          // ── PDF backend: recover the baseline from the emitted bytes ──
          final pdf = await _renderPdfText(
            text: _kFixtureText,
            at: _kAt,
            style: style,
            boxHeight: _kBoxHeight,
            fontBytes: fontBytes,
            measurer: measurer,
          );

          // The global Y-flip must actually be present and correct (CR-085):
          // construction cm is `1 0 0 -1 0 boxHeight`, i.e. d == -1 about
          // boxHeight. Read from real bytes, not assumed.
          expect(pdf.constructionCm[3], closeTo(-1.0, 1e-6),
              reason: 'global Y-flip (d) missing/wrong in emitted cm');
          expect(pdf.constructionCm[5], closeTo(_kBoxHeight, 1e-4),
              reason: 'global flip must be about boxHeight (§7.4)');

          // The PDF backend must place the baseline at the shared-contract
          // point `at + anchorOffset` — this pins it to the contract so a
          // regression that moved BOTH backends in lockstep is still caught.
          expect(pdf.baselineDiagramY, closeTo(_kAt.y + o.y, 1e-3),
              reason: 'PDF baseline Y != at.y + anchorOffset.y');
          expect(pdf.baselineDiagramX, closeTo(_kAt.x + o.x, 1e-3),
              reason: 'PDF baseline X != at.x + anchorOffset.x');

          // ── Flutter backend: recover the baseline it actually placed ──
          final flt = _renderFlutterText(
            text: _kFixtureText,
            at: _kAt,
            style: style,
            measurer: measurer,
          );

          // ── the gate: the two backends agree within 0.5% ──
          // Normalised against line height (the natural unit for "how far
          // off is the baseline"), per §11.2. Reported so a near-miss is
          // visible rather than a bare pass/fail.
          final diff = (pdf.baselineDiagramY - flt.baselineDiagramY).abs();
          final tol = 0.005 * m.lineHeight;
          expect(diff, lessThanOrEqualTo(tol),
              reason: 'baseline Y disagreement ${diff.toStringAsFixed(5)}pt '
                  'exceeds 0.5% of line height (${tol.toStringAsFixed(5)}pt): '
                  'pdf=${pdf.baselineDiagramY}, '
                  'flutter=${flt.baselineDiagramY}');

          // X parity too (the anchor's horizontal resolution).
          final diffX = (pdf.baselineDiagramX - flt.baselineDiagramX).abs();
          expect(diffX, lessThanOrEqualTo(0.005 * m.lineHeight),
              reason: 'baseline X disagreement: pdf=${pdf.baselineDiagramX}, '
                  'flutter=${flt.baselineDiagramX}');

          // For baselineLeft, dy MUST be exactly 0 on both — a stricter,
          // unambiguous check that no descent/ascent leaked in.
          if (anchor == TextAnchor.baselineLeft) {
            expect(pdf.baselineDiagramY, closeTo(_kAt.y, 1e-3));
            expect(flt.baselineDiagramY, closeTo(_kAt.y, 1e-3));
          }

          // ── font-identity / kerning guard (real Skia layout) ──
          // paragraph.longestLine is the real laid-out width of the run; it
          // must match PdfFont.stringMetrics' advance. This depends on the
          // RIGHT font being loaded AND on kern/liga staying disabled
          // (§7.6 #7). If FontLoader gave a fallback, or kerning crept back
          // in on "AV/Wa/To/Ty", this diverges by 1-3% and fails.
          final widthErr =
              (flt.lineWidth - m.advanceWidth).abs() / m.advanceWidth;
          expect(widthErr, lessThan(0.01),
              reason: 'Skia line width ${flt.lineWidth} disagrees with '
                  'stringMetrics advance ${m.advanceWidth} by '
                  '${(widthErr * 100).toStringAsFixed(2)}% — wrong font '
                  'loaded, or kerning not disabled (§7.6 #7)');
        });
      }
    }
  });

  group('stroke floor — neither backend ever emits width 0 (CR-082)', () {
    test('PDF clamps a sub-floor stroke to the 0.5pt signal floor', () async {
      final w = await _renderPdfLineWidth(
        stroke: const Stroke(argb: 0xFF000000, widthPt: 0),
        fontBytes: fontBytes,
        measurer: measurer,
      );
      expect(w, closeTo(0.5, 1e-6));
    });

    test('PDF clamps a sub-floor furniture stroke to the 0.25pt floor',
        () async {
      final w = await _renderPdfLineWidth(
        stroke: const Stroke(
          argb: 0xFF000000,
          widthPt: 0.001,
          hairlineFloor: true,
        ),
        fontBytes: fontBytes,
        measurer: measurer,
      );
      expect(w, closeTo(0.25, 1e-6));
    });

    test('PDF leaves an above-floor stroke unchanged (clamp only floors)',
        () async {
      final w = await _renderPdfLineWidth(
        stroke: const Stroke(argb: 0xFF000000, widthPt: 2),
        fontBytes: fontBytes,
        measurer: measurer,
      );
      expect(w, closeTo(2, 1e-6));
    });

    test('Flutter clamps a sub-floor stroke to the 0.5pt signal floor', () {
      final rec = _RecordingCanvas();
      FlutterDiagramCanvas(rec, measurer: measurer).drawLine(
        const DPt(10, 10),
        const DPt(90, 10),
        const Stroke(argb: 0xFF000000, widthPt: 0),
      );
      expect(rec.lastStrokeWidth, isNotNull);
      expect(rec.lastStrokeWidth, closeTo(0.5, 1e-6));
    });

    test('Flutter clamps a sub-floor furniture stroke to the 0.25pt floor',
        () {
      final rec = _RecordingCanvas();
      FlutterDiagramCanvas(rec, measurer: measurer).drawLine(
        const DPt(10, 10),
        const DPt(90, 10),
        const Stroke(argb: 0xFF000000, widthPt: 0.001, hairlineFloor: true),
      );
      expect(rec.lastStrokeWidth, closeTo(0.25, 1e-6));
    });
  });

  group('production wiring smoke — the real page-export path runs', () {
    test('buildDiagramScenePage renders an OpText scene end-to-end', () async {
      // Exercises the exact wiring page_wiring.dart documents (pw.Page ->
      // pw.CustomPaint -> PdfDiagramCanvas with boxHeight: size.y), so the
      // precise-extraction path above is not the only path that has ever run
      // the backend through a real document.
      final doc = pw.Document();
      final pageFont =
          PdfTtfFont(doc.document, ByteData.sublistView(fontBytes));
      const style = TextStyleSpec(
        font: _kFont,
        sizePt: 12,
        argb: 0xFF000000,
        anchor: TextAnchor.baselineLeft,
      );
      const scene = DiagramScene(
        ops: [OpText(_kFixtureText, _kAt, style)],
        bounds: DBox.fromLtwh(0, 0, 400, 300),
        hits: [],
        minTextSizePt: 12,
        fragments: {},
      );

      doc.addPage(
        buildDiagramScenePage(
          usableWidth: 400,
          usableHeight: 300,
          scene: scene,
          fonts: <FontRef, PdfFont>{_kFont: pageFont},
          measurer: measurer,
        ),
      );

      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      // A real page with an embedded font is comfortably over a few KB.
      expect(bytes.length, greaterThan(2000));
    });
  });
}

// ── font asset loading ────────────────────────────────────────────────────

Uint8List _loadFontBytes() {
  // `flutter test` runs with CWD = the package root (apps/rackmate).
  const rel = 'assets/fonts/IBMPlexSans-Regular.ttf';
  for (final candidate in <String>[
    rel,
    'apps/rackmate/$rel', // in case a runner is rooted at the repo top
  ]) {
    final f = File(candidate);
    if (f.existsSync()) return f.readAsBytesSync();
  }
  throw StateError(
    'Could not find $rel from CWD ${Directory.current.path}. The parity '
    'gate needs the real bundled IBM Plex Sans Regular TTF.',
  );
}

// ── PDF backend: render + recover the emitted baseline from bytes ─────────

class _PdfBaseline {
  _PdfBaseline({
    required this.baselineDiagramX,
    required this.baselineDiagramY,
    required this.constructionCm,
    required this.textCm,
    required this.td,
  });

  final double baselineDiagramX;
  final double baselineDiagramY;
  final List<double> constructionCm; // the global-flip cm (6 values)
  final List<double> textCm; // M_text (6 values)
  final List<double> td; // the Td operands (o.x, -o.y)
}

Future<_PdfBaseline> _renderPdfText({
  required String text,
  required DPt at,
  required TextStyleSpec style,
  required double boxHeight,
  required Uint8List fontBytes,
  required TextMeasurer measurer,
}) async {
  // A fresh, UNCOMPRESSED document per render so the single content stream is
  // unambiguous and its operators are readable ASCII.
  final doc = PdfDocument(compress: false);
  final font = PdfTtfFont(doc, ByteData.sublistView(fontBytes));
  final page = PdfPage(
    doc,
    pageFormat: PdfPageFormat(400, boxHeight),
  );
  // The REAL backend call under test, then dispose() to balance the
  // constructor's saveContext.
  PdfDiagramCanvas(
    graphics: page.getGraphics(),
    boxHeight: boxHeight,
    fonts: <FontRef, PdfFont>{style.font: font},
    measurer: measurer,
  )
    ..drawText(text, at, style)
    ..dispose();

  final bytes = await doc.save();
  final stream = _operatorStream(bytes, mustContain: 'BT');

  final btIdx = stream.indexOf('BT');
  final cms =
      _cmRe.allMatches(stream).where((mt) => mt.end <= btIdx).toList();
  if (cms.length < 2) {
    throw StateError(
      'expected the construction flip cm and the text cm before BT, found '
      '${cms.length}. Stream:\n$stream',
    );
  }
  // M_text is always the last cm before BT (drawText emits it right before
  // drawString); the global-flip cm is the one before it. Selecting by
  // position (not `.first`) stays correct even if a future page setup ever
  // prepends its own transform.
  final gCm = _sixNums(cms[cms.length - 2]);
  final mCm = _sixNums(cms.last);

  final textBlock =
      RegExp('BT(.*?)ET', dotAll: true).firstMatch(stream)!.group(1)!;
  final tdM = _tdRe.firstMatch(textBlock);
  if (tdM == null) {
    throw StateError('no Td text-position operator found in:\n$textBlock');
  }
  final tdX = double.parse(tdM.group(1)!);
  final tdY = double.parse(tdM.group(2)!);

  // The emitted text matrix maps the text-space point (tdX, tdY) into DIAGRAM
  // space (it is concatenated AFTER the global flip, so its output is the
  // flip's input = diagram units). This is independent of any outer
  // pre-translation, so it is the same number the production CustomPaint path
  // would place. Standard PDF affine: x' = a*x + c*y + e ; y' = b*x + d*y + f.
  final a = mCm[0];
  final b = mCm[1];
  final c = mCm[2];
  final d = mCm[3];
  final e = mCm[4];
  final f = mCm[5];
  final baselineDiagramX = a * tdX + c * tdY + e;
  final baselineDiagramY = b * tdX + d * tdY + f;

  return _PdfBaseline(
    baselineDiagramX: baselineDiagramX,
    baselineDiagramY: baselineDiagramY,
    constructionCm: gCm,
    textCm: mCm,
    td: <double>[tdX, tdY],
  );
}

Future<double> _renderPdfLineWidth({
  required Stroke stroke,
  required Uint8List fontBytes,
  required TextMeasurer measurer,
}) async {
  final doc = PdfDocument(compress: false);
  final font = PdfTtfFont(doc, ByteData.sublistView(fontBytes));
  final page = PdfPage(doc, pageFormat: const PdfPageFormat(400, 500));
  // No transforms applied, so the CTM scale k == 1 and the emitted width is
  // the clamped width directly.
  PdfDiagramCanvas(
    graphics: page.getGraphics(),
    boxHeight: 500,
    fonts: <FontRef, PdfFont>{_kFont: font},
    measurer: measurer,
  )
    ..drawLine(const DPt(50, 50), const DPt(300, 50), stroke)
    ..dispose();

  final bytes = await doc.save();
  final stream = _operatorStream(bytes, mustContain: ' l ');
  final wM = _lineWidthRe.firstMatch(stream);
  if (wM == null) {
    throw StateError('no line-width (w) operator found in:\n$stream');
  }
  return double.parse(wM.group(1)!);
}

// ── Flutter backend: render against a recording canvas + recover baseline ──

class _FlutterBaseline {
  _FlutterBaseline({
    required this.baselineDiagramX,
    required this.baselineDiagramY,
    required this.lineWidth,
  });

  final double baselineDiagramX;
  final double baselineDiagramY;
  final double lineWidth; // real Skia longestLine of the run
}

_FlutterBaseline _renderFlutterText({
  required String text,
  required DPt at,
  required TextStyleSpec style,
  required TextMeasurer measurer,
}) {
  final rec = _RecordingCanvas();
  FlutterDiagramCanvas(rec, measurer: measurer).drawText(text, at, style);

  final tr = rec.lastTranslate;
  final po = rec.lastParagraphOffset;
  final para = rec.lastParagraph;
  if (tr == null || po == null || para == null) {
    throw StateError(
      'FlutterDiagramCanvas.drawText did not translate + drawParagraph as '
      'expected (translate=$tr, offset=$po, paragraph=$para).',
    );
  }

  // The paragraph's top-left is placed at (translate + paintOffset); its
  // alphabetic baseline sits `para.alphabeticBaseline` below that top. This
  // is the baseline the backend ACTUALLY produced — read from the real calls
  // it made and the real Skia layout, not recomputed from the anchor math.
  final baselineDiagramY = tr.dy + po.dy + para.alphabeticBaseline;
  final baselineDiagramX = tr.dx + po.dx; // glyph origin x (baseline-left)

  return _FlutterBaseline(
    baselineDiagramX: baselineDiagramX,
    baselineDiagramY: baselineDiagramY,
    lineWidth: para.longestLine,
  );
}

/// A dart:ui [ui.Canvas] that records exactly the calls
/// [FlutterDiagramCanvas.drawText]/`drawLine` make, so the test can read back
/// what the REAL backend placed without pixel inspection or reimplementing
/// its math. Everything else is swallowed by [noSuchMethod].
class _RecordingCanvas implements ui.Canvas {
  ui.Offset? lastTranslate;
  double lastRotate = 0;
  ui.Paragraph? lastParagraph;
  ui.Offset? lastParagraphOffset;
  double? lastStrokeWidth;

  @override
  void save() {}

  @override
  void restore() {}

  @override
  void translate(double dx, double dy) => lastTranslate = ui.Offset(dx, dy);

  @override
  void rotate(double radians) => lastRotate = radians;

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    lastParagraph = paragraph;
    lastParagraphOffset = offset;
  }

  @override
  void drawPath(ui.Path path, ui.Paint paint) =>
      lastStrokeWidth = paint.strokeWidth;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── PDF content-stream parsing helpers ────────────────────────────────────

const String _numPat = r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?';

final RegExp _cmRe = RegExp('($_numPat)\\s+($_numPat)\\s+($_numPat)\\s+'
    '($_numPat)\\s+($_numPat)\\s+($_numPat)\\s+cm');
final RegExp _tdRe = RegExp('($_numPat)\\s+($_numPat)\\s+Td');
final RegExp _lineWidthRe = RegExp('($_numPat)\\s+w(?=\\s)');

List<double> _sixNums(RegExpMatch m) =>
    <double>[for (var i = 1; i <= 6; i++) double.parse(m.group(i)!)];

/// Returns the (uncompressed) content-operator stream containing
/// [mustContain]. Picks the SMALLEST matching `stream…endstream` body so the
/// tiny operator stream wins over the multi-hundred-KB embedded font blob (a
/// FontFile2 stream could coincidentally contain the marker bytes, but never
/// as the smallest match).
String _operatorStream(Uint8List pdfBytes, {required String mustContain}) {
  final s = String.fromCharCodes(pdfBytes); // bytes are 0..255 → latin1
  final re = RegExp(r'stream\r?\n(.*?)\r?\nendstream', dotAll: true);
  String? best;
  for (final m in re.allMatches(s)) {
    final body = m.group(1)!;
    if (body.contains(mustContain) &&
        (best == null || body.length < best.length)) {
      best = body;
    }
  }
  if (best == null) {
    throw StateError('no content stream containing "$mustContain"');
  }
  return best;
}
