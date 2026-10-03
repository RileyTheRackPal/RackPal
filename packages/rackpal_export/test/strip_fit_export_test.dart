// The compact title strip fits every starter, with the real font (M6-L
// `#982`, DR-223 §11.222.1).
//
// Measured with the real font, not the fake: row 3 overflowed the 510 pt
// portrait strip on all four starters before its repeats were dropped, and
// only a real measurer can say whether it fits now. A truncated row ends in
// an ellipsis, so "no strip text ends in `…`" is the property.
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:test/test.dart';

void main() {
  late PdfFontMeasurer measurer;
  setUpAll(() {
    final doc = pw.Document(compress: false);
    measurer = PdfFontMeasurer(<FontRef, PdfFont>{
      kSheetFont: PdfTtfFont(
        doc.document,
        ByteData.sublistView(
          File(
            '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
          ).readAsBytesSync(),
        ),
      ),
    });
  });

  for (final name in [
    'apartment',
    'home_theatre',
    'small_office',
    'whole_house',
  ]) {
    test('$name: no strip row is cut, on the portrait Pull Sheet or the '
        'landscape equipment list', () {
      final doc =
          (const JsonDocumentCodec().read(
                    File(
                      '../../apps/rackpal/assets/starters/$name.rppj',
                    ).readAsBytesSync(),
                  )
                  as Ok<RackDocument>)
              .value;
      final set = SheetSet.forRacks(
        doc.racks.values,
        pullSheets: 2,
        terminationSheets: 1,
        numbering: doc.settings.sheetNumbering,
      );
      for (final role in [SheetRole.pullSheet, SheetRole.equipmentList]) {
        final sheet = set.sheets.firstWhere((s) => s.role == role);
        expect(sheet.size.usesCompactTitleBlock, isTrue);
        final layer = buildTitleBlockLayer(
          box: SheetLayout.resolve(
            geometry: SheetGeometry(sheet.size),
            revisionRowCount: 0,
          ).titleBlockBox,
          fields: TitleBlockFields.resolve(
            info: doc.info,
            settings: doc.settings,
            sheet: sheet,
            rack: null,
            revisions: doc.revisionBlock,
            scale: DrawingScale.fitted(const SceneFactor(0)),
            fileName: '$name.rppj',
            issuedAt: DateTime.utc(2026, 10, 3),
          ),
          measurer: measurer,
          compact: true,
        );
        final cut = [
          for (final t in layer.ops.whereType<OpText>())
            if (t.text.endsWith('…')) t.text,
        ];
        expect(cut, isEmpty, reason: '${sheet.ncsId}: $cut');
      }
    });
  }
}
