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

  // THIS PINNED THE DEFECT UNTIL `#998`: it asserted T6.02 printed under the
  // 6 pt floor, which it did only because the drawn sheet was laid out with
  // net-label room it never draws (DR-232). Placed by its own ink, the
  // sheet clears the floor; the clause's other halves still hold.
  test('Network prints OVER the floor, drawn, with no note and no fallback '
      'notice (DR-232, DR-225 §11.224.4)', () {
    expect(
      exported.notices.where(
        (n) => n.startsWith('T6.02:') && n.contains('below the 6 pt'),
      ),
      isEmpty,
    );
    for (final device in ['PP-1', 'LIU-1', 'W027 ·']) {
      expect(pageOf['T6.02'], contains(device), reason: device);
    }
    expect(
      exported.notices.where((n) => n.contains('shown as net labels')),
      isEmpty,
    );
    expect(pageOf['T6.02'], isNot(contains(kInterconnectNoteLines.first)));
    expect(pageOf['T6.02'], contains('W002 ·'), reason: 'still drawn');
  });

  test('the legend keys the tag pill on a real cable the set prints, and not '
      'the net label, which no sheet fell back to (DR-208, #984)', () {
    final legend = pageOf['T0.01']!;
    expect(legend, contains(kLegendTagPillMeaning));
    // RF is T6.01, so its first wire is the sample, in the sheet's words.
    expect(legend, contains('W003 ·'));
    expect(pageOf['T6.01'], contains('W003 ·'));
    expect(legend, isNot(contains(kLegendNetLabelMeaning)));
    // A block that does not fit is dropped WITH a notice; there is none,
    // so the row above is the block's and not a lucky substring.
    expect(
      exported.notices.where((n) => n.startsWith('T0.01: did not fit')),
      isEmpty,
    );
  });

  test('the drawing index lists each interconnect sheet on its own row', () {
    final cover = pageOf['T0.00']!;
    expect(cover, contains('INTERCONNECT · Analog Video & RF'));
    expect(cover, contains('INTERCONNECT · Network'));
  });

  test('DR-235 §11.234.5: the legend keys the adapter mark only when a '
      'cable the set prints carries one (DR-208)', () async {
    expect(
      pageOf['T0.01'],
      isNot(contains(kLegendAdapterMeaning)),
      reason: 'Whole House as shipped declares no adapter',
    );

    final withAdapter =
        (const JsonDocumentCodec().read(const JsonDocumentCodec().write(doc))
                as Ok<RackDocument>)
            .value;
    withAdapter.links.values
        .firstWhere((l) => l.designator == 'W003')
        .inlineAdapters
        .add(
          InlineAdapter(
            fromConnector: const ConnectorTypeId('conn.f_type'),
            toConnector: const ConnectorTypeId('conn.bnc'),
            satisfiesRuleIds: ['CON-001'],
          ),
        );
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: const JsonDocumentCodec().write(withAdapter),
        fontBytes: <FontRef, Uint8List>{
          const FontRef('Jost'): File(
            '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
          ).readAsBytesSync(),
        },
        fileName: 'whole_house.rppj',
        issuedAt: DateTime.utc(2026, 10, 3),
      ),
    );
    final bytes = (result as Ok<ExportedDocument>).value.bytes;
    final cmap = parseToUnicodeCMap(bytes);
    final legend = [
      for (final body in operatorStreams(bytes))
        interpretContentStream(body, toUnicode: cmap).allText,
    ].firstWhere((t) => RegExp(r'SHEET NO\.\s+T0\.01').hasMatch(t));
    expect(legend, contains(kLegendAdapterMeaning));
  });
}
