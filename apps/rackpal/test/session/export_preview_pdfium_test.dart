// The export preview through the REAL pdfium (M6-I4, `#355`, DR-230): the
// generated file, its ID and date rewritten in place by M6-I5, is a file
// pdfium opens and renders page by page.
//
// The controller and the dialog are tested against closures; this is the
// one test that the bytes and the binary agree, on the precedent of
// `plan_import_pdfium_test.dart`.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rackpal/src/session/export_runner.dart';
import 'package:rackpal/src/session/pdf_rasteriser.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';

void main() {
  test('every page of Whole House renders at its own proportions', () async {
    final outcome = await runExportInline(
      ExportRequest(
        documentJson: File(
          'assets/starters/whole_house.rppj',
        ).readAsBytesSync(),
        fontBytes: <FontRef, Uint8List>{
          const FontRef('Jost'): File(
            'assets/fonts/Jost-Regular.ttf',
          ).readAsBytesSync(),
        },
        fileName: 'whole_house.rppj',
        issuedAt: DateTime.utc(2026, 10, 4),
      ),
    ).result;
    final exported = (outcome! as Ok<ExportedDocument>).value;
    for (final (i, sheet) in exported.sheets.indexed) {
      const width = 400;
      final height = (width * sheet.heightPt / sheet.widthPt).round();
      final png = pdfiumRenderPng(
        exported.bytes,
        i,
        width: width,
        height: height,
      );
      final image = img.decodePng((png as Ok<Uint8List>).value)!;
      expect((image.width, image.height), (width, height), reason: sheet.ncsId);
    }
  });
}
