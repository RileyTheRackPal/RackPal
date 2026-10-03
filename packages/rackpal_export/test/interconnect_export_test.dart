// T6.01…, the interconnect sheets, read off the PDF (DR-225, M6-D2).
//
// THE ARTIFACT, NOT THE MECHANISM: every assertion here is on text a
// reader of the printed sheet could find, recovered from the page's own
// content stream.

import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

void main() {
  late ExportedDocument exported;
  late RackDocument doc;
  late Map<String, String> pageOf;

  setUpAll(() async {
    final bytes = File(
      '../../apps/rackpal/assets/starters/whole_house.rppj',
    ).readAsBytesSync();
    doc = (const JsonDocumentCodec().read(bytes) as Ok<RackDocument>).value;
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: bytes,
        fontBytes: <FontRef, Uint8List>{
          const FontRef('Jost'): File(
            '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
          ).readAsBytesSync(),
        },
        fileName: 'whole_house.rppj',
        issuedAt: DateTime.utc(2026, 10, 3),
      ),
    );
    exported = (result as Ok<ExportedDocument>).value;
    final cmap = parseToUnicodeCMap(exported.bytes);
    pageOf = <String, String>{
      for (final body in operatorStreams(exported.bytes))
        if (RegExp(r'SHEET NO\.\s+(T\d\.\d\d)').firstMatch(
              interpretContentStream(body, toUnicode: cmap).allText,
            )
            case final m?)
          m.group(1)!: interpretContentStream(body, toUnicode: cmap).allText,
    };
  });

  test('Whole House prints T6.01 for RF and T6.02 for Network, each naming '
      'its domain where a plan names its floor', () {
    expect(pageOf['T6.01'], contains('Whole House — Analog Video & RF'));
    expect(pageOf['T6.02'], contains('Whole House — Network'));
    expect(pageOf['T6.01'], contains('INTERCONNECT'));
    expect(pageOf.keys.where((id) => id.startsWith('T6.0')), hasLength(2));
  });

  test('every cable a sheet draws prints its tag pill: all twelve PP-1 runs, '
      'including the eleven a collapsed bank used to hide (§11.224.7)', () {
    final net = pageOf['T6.02']!;
    final rf = pageOf['T6.01']!;
    for (final link in doc.links.values) {
      final c = link.conductors.first;
      final landed = c.from is PortEndpoint || c.to is PortEndpoint;
      final family = link.services.first.signalFamily.v;
      final page = family.startsWith('rf.') ? rf : net;
      expect(
        page.contains('${link.designator} ·'),
        landed && (family.startsWith('rf.') || family.startsWith('net.')),
        reason: '${link.designator} ($family)',
      );
    }
  });

  test("a sheet draws its own devices and nobody else's", () {
    // PP-1 and LIU-1 are the Network sheet's; SPL-1 is RF's. A device on
    // both would be CR-074's all-devices sheet arriving one box at a time.
    expect(pageOf['T6.02'], allOf(contains('PP-1'), contains('LIU-1')));
    expect(pageOf['T6.02'], isNot(contains('SPL-1')));
    expect(pageOf['T6.01'], contains('SPL-1'));
    expect(pageOf['T6.01'], isNot(contains('PP-1')));
  });

  test('Network prints under the floor and SAYS so, and stays drawn: net '
      'labels miss the floor too, so no note and no fallback notice '
      '(DR-225 §11.224.4)', () {
    expect(
      exported.notices,
      contains(
        allOf(startsWith('T6.02:'), contains('below the 6 pt legibility')),
      ),
    );
    expect(
      exported.notices.where((n) => n.contains('shown as net labels')),
      isEmpty,
    );
    expect(pageOf['T6.02'], isNot(contains(kInterconnectNoteLines.first)));
    expect(pageOf['T6.02'], contains('W002 ·'), reason: 'still drawn');
  });

  test('the drawing index lists each interconnect sheet on its own row', () {
    final cover = pageOf['T0.00']!;
    expect(cover, contains('INTERCONNECT · Analog Video & RF'));
    expect(cover, contains('INTERCONNECT · Network'));
  });
}
