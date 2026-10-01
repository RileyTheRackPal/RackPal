// T0.02 reaches the PDF (M6-C `#322`, DR-214).
//
// The core tests prove the pages' items; this proves the ink, on real
// starters: every open finding's locus and rule on a T0.0x page, and the
// empty sections saying so in words.
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

  RackDocument starter(String name) =>
      (const JsonDocumentCodec().read(
                File(
                  '../../apps/rackpal/assets/starters/$name.rppj',
                ).readAsBytesSync(),
              )
              as Ok<RackDocument>)
          .value;

  /// The text of every T0.02-and-on page, in sheet order, whitespace
  /// collapsed so a wrapped message reads as one line.
  Future<String> exceptionsInk(String name) async {
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: File(
          '../../apps/rackpal/assets/starters/$name.rppj',
        ).readAsBytesSync(),
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: '$name.rppj',
        issuedAt: DateTime.utc(2026, 10),
      ),
    );
    final bytes = (result as Ok<ExportedDocument>).value.bytes;
    final cmap = parseToUnicodeCMap(bytes);
    final pages = <String, String>{
      for (final body in operatorStreams(bytes))
        if (RegExp(r'SHEET NO\.\s+(T0\.0[2-9])').firstMatch(
              interpretContentStream(body, toUnicode: cmap).allText,
            )
            case final m?)
          m.group(1)!: interpretContentStream(body, toUnicode: cmap).allText,
    };
    final ids = pages.keys.toList()..sort();
    return ids
        .map((id) => pages[id]!)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  test("WHOLE HOUSE: the open count, and every finding's rule and locus in "
      'ink (#323)', () async {
    final doc = starter('whole_house');
    final findings = evaluateDocument(doc);
    final ink = await exceptionsInk('whole_house');
    expect(ink, contains('OPEN FINDINGS (${findings.length})'));
    for (final f in findings) {
      expect(ink, contains(f.ruleId), reason: f.ruleId);
      final id = f.primaryEntityId;
      if (id != null) {
        final label = locusLabel(doc, id);
        expect(label, isNotNull, reason: f.message);
        expect(ink, contains(label), reason: f.message);
      }
    }
  });

  test('AN EMPTY SECTION SAYS SO IN WORDS, on a starter with nothing signed '
      '(#325)', () async {
    final ink = await exceptionsInk('apartment');
    expect(ink, contains('PROJECT-WIDE EXCEPTIONS (0)'));
    expect(ink, contains('ACKNOWLEDGED FINDINGS (0)'));
    expect(ink, contains(kNoProjectWide.replaceAll(RegExp(r'\s+'), ' ')));
  });
}
