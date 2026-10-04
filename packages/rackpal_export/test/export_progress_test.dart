// buildExportDocument's progress hook (M6-I2, `#353`, docs/08 §8.2): what
// an isolate sends back over its port, so the dialog can count sheets.
import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

void main() {
  test('zero when the set resolves, then one call per sheet drawn, in '
      'order, ending at the set it reports', () async {
    final heard = <(int, int)>[];
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
      onProgress: (done, sheets) => heard.add((done, sheets)),
    );
    final sheets = (result as Ok<ExportedDocument>).value.sheetCount;
    expect(heard, [for (var i = 0; i <= sheets; i++) (i, sheets)]);
  });
}
