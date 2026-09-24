// Smoke test for FlutterDiagramCanvas (docs/08-pdf-export.md §7.7).
//
// Builds a real `ui.PictureRecorder` + `ui.Canvas`, wraps it in a
// `FlutterDiagramCanvas` backed by a REAL `PdfFontMeasurer` (the same
// concrete `TextMeasurer` the PDF backend uses -- CR-081's entire point is
// that both backends share this one measurer), and asserts
// drawRect/drawRoundRect/drawCircle/drawPolyline/drawLine/drawText/clip/
// transform all run without throwing and produce a valid `ui.Picture` via
// `recorder.endRecording()`.
//
// Uses the real bundled Jost Regular TTF, read via `dart:io`
// `File` -- this package already depends on `rackpal_text`, and `flutter
// test` can read files from disk the same as any Dart VM. Path is
// relative to THIS package's own directory (packages/rackpal_ui), which
// is what `flutter test` (run from packages/rackpal_ui) resolves
// against -- matching rackpal_text/test/pdf_font_measurer_test.dart and
// rackpal_export/test/pdf_canvas_test.dart's own fixtures.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

void main() {
  test(
    'FlutterDiagramCanvas replays draw calls onto a real ui.Canvas without '
    'throwing, and the recording ends as a valid ui.Picture',
    () {
      final bytes = File(
        '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
      ).readAsBytesSync();

      final doc = PdfDocument();
      const fontRef = FontRef('Jost');
      final measurer = PdfFontMeasurer.fromBytes(doc, {fontRef: bytes});

      const textStyle = TextStyleSpec(
        font: fontRef,
        sizePt: 12,
        argb: 0xFF000000,
        anchor: TextAnchor.topLeft,
      );
      const stroke = Stroke(argb: 0xFF000000, widthPt: 1);
      const dashedStroke = Stroke(
        argb: 0xFF000000,
        widthPt: 1,
        dash: [4, 2],
      );
      const fill = Fill(0xFFCCCCCC);

      final recorder = ui.PictureRecorder();
      final uiCanvas = ui.Canvas(recorder);
      final canvas = FlutterDiagramCanvas(uiCanvas, measurer: measurer)
        ..save()
        ..translate(5, 5)
        ..drawRect(
          const DBox.fromLtwh(10, 10, 50, 20),
          fill: fill,
          stroke: stroke,
        )
        ..drawRoundRect(
          const DBox.fromLtwh(70, 10, 50, 20),
          const Radii.circular(4),
          fill: fill,
          stroke: stroke,
        )
        ..drawCircle(const DPt(150, 20), 8, stroke: stroke)
        ..drawEllipse(const DPt(150, 50), 12, 6, fill: fill)
        ..drawPolyline(const [
          DPt(10, 60),
          DPt(40, 80),
          DPt(70, 60),
        ], dashedStroke)
        ..drawLine(const DPt(10, 90), const DPt(100, 90), dashedStroke)
        ..clipRect(const DBox.fromLtwh(0, 0, 200, 100))
        ..drawPath(
          DiagramPath.fromSvg('M5 5 L15 5 L15 15 Z'),
          fill: fill,
          stroke: stroke,
        )
        ..drawText('AV Wa To Ty', const DPt(10, 40), textStyle)
        ..restore();

      final picture = recorder.endRecording();
      expect(picture, isNotNull);

      expect(canvas.saveCount, 0);
      expect(canvas.currentTransform, isNotNull);
    },
  );
}
