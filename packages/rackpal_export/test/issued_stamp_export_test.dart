// The ISSUED FOR CONSTRUCTION stamp reaches the PDF (M6-G5 `#346`, CR-022,
// DR-216).
//
// On real starters: Small Office opens with warnings and no error, so a
// request stamps every page; Whole House opens with errors, so the same
// request exports every page UNSTAMPED and says why. The ink is read back
// out of the content streams, so this is what a person sees.
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

  Uint8List starterBytes(String name) => File(
    '../../apps/rackpal/assets/starters/$name.rppj',
  ).readAsBytesSync();

  Future<ExportedDocument> export(
    String name, {
    required bool issuedForConstruction,
  }) async {
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: starterBytes(name),
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: '$name.rppj',
        issuedAt: DateTime.utc(2026, 10),
        issuedForConstruction: issuedForConstruction,
      ),
    );
    return (result as Ok<ExportedDocument>).value;
  }

  /// Each SHEET's text, whitespace collapsed. `operatorStreams` also
  /// yields form XObjects and empty streams, so a sheet is the stream that
  /// prints a sheet number, which every sheet's title block does.
  List<String> pagesOf(Uint8List bytes) {
    final cmap = parseToUnicodeCMap(bytes);
    return <String>[
      for (final body in operatorStreams(bytes))
        interpretContentStream(
          body,
          toUnicode: cmap,
        ).allText.replaceAll(RegExp(r'\s+'), ' '),
    ].where((t) => t.contains('SHEET NO.')).toList();
  }

  test(
    'NO OPEN ERROR: every page carries the words and the issue date',
    () async {
      final exported = await export(
        'small_office',
        issuedForConstruction: true,
      );
      expect(exported.stamped, isTrue);
      expect(exported.stampWithheld, isNull);
      final pages = pagesOf(exported.bytes);
      expect(pages, hasLength(exported.sheetCount));
      for (final (i, page) in pages.indexed) {
        expect(page, contains('ISSUED FOR CONSTRUCTION'), reason: 'page $i');
        expect(page, contains('2026-10-01'), reason: 'page $i');
      }
    },
  );

  test('OPEN ERRORS WITHHOLD THE STAMP, NEVER THE BYTES (CR-022), and the '
      'result says how many and where', () async {
    final doc =
        (const JsonDocumentCodec().read(starterBytes('whole_house'))
                as Ok<RackDocument>)
            .value;
    final errors = evaluateDocument(
      doc,
    ).where((f) => f.severity == Severity.error).length;
    expect(
      errors,
      greaterThan(1),
      reason: 'the premise: Whole House opens red',
    );

    final exported = await export('whole_house', issuedForConstruction: true);
    expect(exported.stamped, isFalse);
    expect(
      exported.stampWithheld,
      'not stamped: $errors open errors, see T0.02',
    );
    final pages = pagesOf(exported.bytes);
    expect(pages, hasLength(exported.sheetCount));
    expect(pages.where((p) => p.contains('ISSUED FOR CONSTRUCTION')), isEmpty);

    // The same pages a plain export makes: a withheld stamp reserves nothing.
    final plain = await export('whole_house', issuedForConstruction: false);
    expect(exported.sheetCount, plain.sheetCount);
  });

  test('NOT ASKED FOR: no stamp, and nothing to explain', () async {
    final exported = await export('small_office', issuedForConstruction: false);
    expect(exported.stamped, isFalse);
    expect(exported.stampWithheld, isNull);
    expect(
      pagesOf(
        exported.bytes,
      ).where((p) => p.contains('ISSUED FOR CONSTRUCTION')),
      isEmpty,
    );
  });
}
