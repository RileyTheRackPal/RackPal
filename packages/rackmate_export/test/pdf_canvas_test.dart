// Smoke test for PdfDiagramCanvas (docs/08-pdf-export.md §7.7).
//
// Builds a real pw.Document/pw.Page/pw.CustomPaint, constructs a
// PdfDiagramCanvas around the real PdfGraphics the painter callback is
// handed, calls drawRect/drawText/drawRoundRect/drawPolyline on it, and
// asserts the resulting PDF bytes are non-empty. Uses the real bundled IBM
// Plex Sans Regular TTF, read via dart:io File (this package is pure Dart,
// no Flutter rootBundle) relative to this package's own directory.

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_export/rackmate_export.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:test/test.dart';

void main() {
  test(
    'PdfDiagramCanvas replays draw calls onto a real PdfGraphics without '
    'throwing, and the resulting PDF bytes are non-empty',
    () async {
      final bytes = File(
        '../../apps/rackmate/assets/fonts/Jost-Regular.ttf',
      ).readAsBytesSync();

      final doc = pw.Document();
      const fontRef = FontRef('Jost');
      final measurer = PdfFontMeasurer.fromBytes(doc.document, {
        fontRef: bytes,
      });
      final fonts = <FontRef, PdfFont>{
        fontRef: PdfTtfFont(doc.document, ByteData.sublistView(bytes)),
      };

      const textStyle = TextStyleSpec(
        font: fontRef,
        sizePt: 12,
        argb: 0xFF000000,
        anchor: TextAnchor.topLeft,
      );
      const stroke = Stroke(argb: 0xFF000000, widthPt: 1);
      const fill = Fill(0xFFCCCCCC);

      doc.addPage(
        pw.Page(
          build: (context) => pw.CustomPaint(
            size: const PdfPoint(200, 100),
            painter: (PdfGraphics graphics, PdfPoint size) {
              final canvas = PdfDiagramCanvas(
                graphics: graphics,
                boxHeight: size.y, // size.y, NOT page height -- §7.4
                fonts: fonts,
                measurer: measurer,
              );

              canvas.save();
              canvas.drawRect(
                const DBox.fromLtwh(10, 10, 50, 20),
                fill: fill,
                stroke: stroke,
              );
              canvas.drawRoundRect(
                const DBox.fromLtwh(70, 10, 50, 20),
                const Radii.circular(4),
                fill: fill,
              );
              canvas.drawCircle(const DPt(150, 20), 8, stroke: stroke);
              canvas.drawPolyline(const [
                DPt(10, 60),
                DPt(40, 80),
                DPt(70, 60),
              ], stroke);
              canvas.drawText('AV Wa To Ty', const DPt(10, 40), textStyle);
              canvas.restore();
              canvas.dispose();
            },
          ),
        ),
      );

      final pdfBytes = await doc.save();
      expect(pdfBytes, isNotEmpty);
    },
  );
}
