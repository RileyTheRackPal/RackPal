// ExportedDocument.sheets (M6-I4, `#355`, DR-230): the list the preview
// pages through. Page `i` of the bytes must be `sheets[i]`, or the preview
// labels one sheet with another's name.
import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

final RegExp _sheetNo = RegExp(r'SHEET NO\.\s+(T\d\.\d+)');

void main() {
  late ExportedDocument exported;

  setUpAll(() async {
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: File(
          '../../apps/rackpal/assets/starters/whole_house.rppj',
        ).readAsBytesSync(),
        fontBytes: <FontRef, Uint8List>{
          const FontRef('Jost'): File(
            '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
          ).readAsBytesSync(),
        },
        fileName: 'whole_house.rppj',
        issuedAt: DateTime.utc(2026, 10, 4),
      ),
    );
    exported = (result as Ok<ExportedDocument>).value;
  });

  test('one entry per page, in the order the PAGES carry their numbers', () {
    final cmap = parseToUnicodeCMap(exported.bytes);
    final printed = [
      for (final body in operatorStreams(exported.bytes))
        if (_sheetNo.firstMatch(
              interpretContentStream(body, toUnicode: cmap).allText,
            )
            case final m?)
          m.group(1)!,
    ];
    expect(exported.sheets, hasLength(exported.sheetCount));
    expect(exported.sheets.map((s) => s.ncsId), printed);
  });

  test('each is named as the drawing index names it, at its own paper', () {
    ExportedSheet of(String id) =>
        exported.sheets.firstWhere((s) => s.ncsId == id);
    expect(exported.sheets.first.title, 'COVER AND DRAWING INDEX');
    expect(of('T2.01').title, 'RACK ELEVATION — FRONT · RK-1');
    expect((of('T2.01').widthPt, of('T2.01').heightPt), (792.0, 1224.0));
    expect((of('T6.30').widthPt, of('T6.30').heightPt), (792.0, 612.0));
  });
}
