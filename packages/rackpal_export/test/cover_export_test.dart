// T0.00 reaches the PDF (M6-A1, `#312`, DR-210).
//
// The core tests prove the cover's ops; this proves the page, on a real
// starter, in ink: a cover that is built and never exported is the defect
// a scene-level test passes.
import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

const FontRef _font = FontRef('Jost');

void main() {
  late Uint8List fontBytes;
  setUpAll(() {
    fontBytes = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
  });

  test('T0.00 IS SHEET 1, and it prints the project and the '
      'sign-off in ink', () async {
    const name = 'whole_house';
    final json = File(
      '../../apps/rackpal/assets/starters/$name.rppj',
    ).readAsBytesSync();
    final info =
        (const JsonDocumentCodec().read(json) as Ok<RackDocument>).value.info;
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: json,
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: '$name.rppj',
        issuedAt: DateTime.utc(2026, 10),
      ),
    );
    final bytes = (result as Ok<ExportedDocument>).value.bytes;
    final cmap = parseToUnicodeCMap(bytes);
    // FOUND BY ITS SHEET ID, not by stream position: the operator streams
    // include font programs, so `.first` is not page one.
    final first = [
      for (final body in operatorStreams(bytes))
        interpretContentStream(body, toUnicode: cmap).allText,
    ].singleWhere((t) => RegExp(r'SHEET NO\.\s+T0\.00').hasMatch(t));

    expect(first, contains('SHEET 1 OF'));
    expect(first, contains(info.projectName));
    expect(first, contains('ISSUED 2026-10-01'));
    expect(first, contains('APPROVED'));
    expect(first, contains('SYMBOL LEGEND: SEE SHEET T0.01'));
  });
}
