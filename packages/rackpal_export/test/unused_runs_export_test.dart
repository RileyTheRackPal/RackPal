// T6.20 read back from the PDF (M6-E1 `#332`, DR-220).
//
// The sheet is asserted on its ink, on the real starter: an audit that
// reads code cannot see what the page prints (docs/12 §4.33). Whole House
// carries twelve runs open at the rack and fifteen landed, so the page
// must name the first twelve and none of the others.
import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

const FontRef _font = FontRef('Jost');
final RegExp _sheetNo = RegExp(r'SHEET NO\.\s+(T\d\.\d+)');

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

  Future<Map<String, String>> pages(RackDocument doc) async {
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: const JsonDocumentCodec().write(doc),
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: 'unused.rppj',
        issuedAt: DateTime.utc(2026, 10, 2),
      ),
    );
    final bytes = (result as Ok<ExportedDocument>).value.bytes;
    final cmap = parseToUnicodeCMap(bytes);
    return {
      for (final body in operatorStreams(bytes))
        if (_sheetNo.firstMatch(
              interpretContentStream(body, toUnicode: cmap).allText,
            )
            case final m?)
          m.group(1)!: interpretContentStream(body, toUnicode: cmap).allText,
    };
  }

  test('WHOLE HOUSE: T6.20 names its twelve open runs and none of the '
      'fifteen landed ones', () async {
    final doc = starter('whole_house');
    final open = <String>{};
    final landed = <String>{};
    for (final link in doc.links.values) {
      (link.conductors.first.to is OpenEndpoint ? open : landed).add(
        link.designator,
      );
    }
    expect(open, hasLength(12), reason: 'precondition: as shipped');
    expect(landed, hasLength(15), reason: 'precondition: as shipped');

    final page = (await pages(doc))['T6.20']!;
    expect(page, contains('UNUSED HOME RUNS (12)'));
    expect(page, contains(kOpenEndKey));
    for (final head in [
      'CABLE ID',
      'OPEN',
      'RACK LBL',
      'FIELD LBL',
      'OUTLET',
      'FIELD END',
      'MEDIA',
      'LEN (FT)',
      'PATHWAY',
      'ROUGH-IN',
    ]) {
      expect(page, contains(head), reason: 'column head $head');
    }
    for (final w in open) {
      expect(page, contains(w), reason: '$w is open at the rack');
    }
    for (final w in landed) {
      expect(page, isNot(contains(w)), reason: '$w is landed');
    }
    expect(page, contains('GREAT ROOM · 2 runs'));
    expect(page, contains('Great Room TV wall, F-barrel 2'));
  });

  test('A RUN COILED AT THE ROOM prints ROOM and its open field end', () async {
    final doc = starter('whole_house');
    final link = doc.links.values.firstWhere(
      (l) => l.conductors.first.to is PortEndpoint,
    );
    link.conductors = [
      for (final c in link.conductors)
        Conductor(
          from: const OpenEndpoint('coil above the ceiling'),
          to: c.to,
          role: c.role,
          pairNumber: c.pairNumber,
          colorCode: c.colorCode,
        ),
    ];
    final page = (await pages(doc))['T6.20']!;
    expect(page, contains('UNUSED HOME RUNS (13)'));
    expect(page, contains(link.designator));
    expect(page, contains('$kOpenFieldEndPrefix coil above the ceiling'));
    // NOT `contains('ROOM')`, which every band title satisfies (`GREAT
    // ROOM`). The OPEN cell is asserted on the model, where it is one
    // value: `unused_home_runs_test.dart`.
  });

  test('A STARTER WITH NO CABLES has no T6.20', () async {
    expect((await pages(starter('apartment'))).keys, isNot(contains('T6.20')));
  });
}
