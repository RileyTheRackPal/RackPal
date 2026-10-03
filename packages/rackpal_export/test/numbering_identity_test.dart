// Sheet IDENTITY is not sheet NUMBERING (M6-H `#347`, CR-066, docs/08
// §2.1).
//
// The same project exported under `simple` and under `ncs`: every sheet
// keeps its id (`SHEET NO.  T2.01`), the drawing index and the legend
// reference are identical, and the ONLY thing that moves is what the title
// block prints as the sheet's number. Read back from the ink, because the
// trap this guards is a cross-reference that follows the scheme.
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

  /// Each sheet's text, whitespace collapsed, under [numbering].
  Future<List<String>> pages(String name, SheetNumbering numbering) async {
    final doc = starter(name);
    SetProjectSettingCommand<SheetNumbering>(
      field: ProjectSettingFields.sheetNumbering,
      from: doc.settings.sheetNumbering,
      to: numbering,
    ).apply(doc);
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: const JsonDocumentCodec().write(doc),
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: '$name.rppj',
        issuedAt: DateTime.utc(2026, 10),
      ),
    );
    final bytes = (result as Ok<ExportedDocument>).value.bytes;
    final cmap = parseToUnicodeCMap(bytes);
    return <String>[
      for (final body in operatorStreams(bytes))
        interpretContentStream(
          body,
          toUnicode: cmap,
        ).allText.replaceAll(RegExp(r'\s+'), ' '),
    ].where((t) => t.contains('SHEET NO.')).toList();
  }

  List<String> ids(List<String> pages) => [
    for (final p in pages)
      RegExp(r'SHEET NO\.\s+(\S+)').firstMatch(p)!.group(1)!,
  ];

  for (final name in ['whole_house', 'small_office']) {
    group(name, () {
      late List<String> simple;
      late List<String> ncs;
      setUpAll(() async {
        simple = await pages(name, SheetNumbering.simple);
        ncs = await pages(name, SheetNumbering.ncs);
      });

      test('EVERY SHEET KEEPS ITS ID, in the same order', () {
        expect(simple, hasLength(ncs.length));
        expect(ids(simple), ids(ncs));
      });

      test('ONLY THE PRINTED NUMBER MOVES: SHEET i OF n under simple, the '
          'id under ncs', () {
        final total = simple.length;
        // THE NUMBER, NOT THE NUMBER AND TITLE: the ANSI A strip prints the
        // number alone since DR-223 (row 1 has the title), so ` ·` is gone
        // there. The boundary keeps `SHEET 1 OF 14` from matching `… 140`.
        for (final (i, id) in ids(simple).indexed) {
          expect(
            simple[i],
            matches(
              RegExp(
                'SHEET ${i + 1} OF $total'
                r'(?!\d)',
              ),
            ),
            reason: id,
          );
          expect(
            ncs[i],
            matches(
              RegExp(
                'SHEET ${RegExp.escape(id)}'
                r'(?!\d)',
              ),
            ),
            reason: id,
          );
          expect(ncs[i], isNot(contains('SHEET ${i + 1} OF $total')));
        }
      });

      test('THE LEGEND REFERENCE IS THE ID UNDER BOTH (CR-023)', () {
        for (final pages in [simple, ncs]) {
          for (final (i, id) in ids(pages).indexed) {
            if (id == 'T0.01') continue;
            expect(
              pages[i],
              contains('SYMBOL LEGEND: SEE SHEET T0.01'),
              reason: id,
            );
          }
        }
      });

      test('THE DRAWING INDEX IS IDENTICAL: it lists ids, not numbers', () {
        // The cover's own text, less its title block's number line.
        String index(String cover) => cover
            .replaceAll(RegExp(r'SHEET \d+ OF \d+ ·'), '')
            .replaceAll(RegExp(r'SHEET T0\.00 ·'), '')
            .replaceAll(RegExp(r'SHEET (\d+/\d+|T0\.00) '), '');
        expect(index(ncs.first), index(simple.first));
      });
    });
  }
}
