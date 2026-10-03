// T6.10 and T6.15 read back from the PDF (M6-K `#978`, `#979`, `#981`,
// DR-222), and AC-018's fourth clause, PRINTS (`#574`).
//
// AC-018: an unbound end "still schedules, prints, gets a W number and gets
// a label". `apps/rackpal/test/starters/unbound_endpoint_ac018_test.dart`
// holds the other three over Whole House and named PRINTS as owed until a
// Pull Sheet existed. It is asserted HERE rather than there because the
// PDF text reader is this package's test support; that file's header points
// here.
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
        fileName: 'schedules.rppj',
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

  String pagesIn(Map<String, String> all, int from, int to) => [
    for (final e in all.entries)
      if (e.key.startsWith('T6.') &&
          int.parse(e.key.substring(3)) >= from &&
          int.parse(e.key.substring(3)) <= to)
        e.value,
  ].join('\n');

  bool isUnbound(Endpoint e) => e is! PortEndpoint;

  test(
    'AC-018 PRINTS (#574): every Whole House run with an unbound end is '
    'on the printed Pull Sheet, with its W number and its open end',
    () async {
      final doc = starter('whole_house');
      final unbound = [
        for (final link in doc.links.values)
          if (link.conductors.any((c) => isUnbound(c.from) || isUnbound(c.to)))
            link,
      ];
      expect(unbound, isNotEmpty, reason: 'precondition: the starter has some');
      final all = await pages(doc);
      final pull = pagesIn(all, 10, 14);
      expect(pull, isNotEmpty, reason: 'precondition: a Pull Sheet printed');
      for (final link in unbound) {
        expect(pull, contains(link.designator), reason: link.designator);
      }
      // THE OPEN END'S OWN WORDS, as the TO cell wraps them: `Rack end not
      // yet` and `terminated` are two runs on the page, so the whole phrase
      // is never one string in the ink.
      expect(pull, contains('Rack end not yet'));
    },
  );

  test('WHOLE HOUSE: the Pull Sheet runs T6.10 then T6.11, and the '
      'Termination Schedule is T6.15, with all fifteen landed runs', () async {
    final doc = starter('whole_house');
    final all = await pages(doc);
    expect(all.keys, containsAll(['T6.10', 'T6.11', 'T6.15']));
    final term = pagesIn(all, 15, 19);
    final landed = [
      for (final link in doc.links.values)
        if (link.conductors.first.to is PortEndpoint) link.designator,
    ];
    expect(landed, hasLength(15), reason: 'precondition: as shipped');
    for (final w in landed) {
      expect(term, contains(w));
    }
    for (final head in ['FIELD TERM', 'RACK TERM', 'FAR END']) {
      expect(term, contains(head));
    }
    expect(term, contains('12 runs landing in no rack'));
  });

  test('APARTMENT, no cables: both schedules print, and say so', () async {
    final all = await pages(starter('apartment'));
    expect(all['T6.10'], contains(kNoCablesText));
    expect(all['T6.15'], contains(kNoCablesText));
  });
}
