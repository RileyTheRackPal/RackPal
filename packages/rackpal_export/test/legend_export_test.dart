// T0.01 reaches the PDF (M6-B, `#316`, DR-207).
//
// The core tests prove the legend's ops; this proves the page. A key that
// is built and never exported, or exported with a row that never reaches
// ink, is the defect a scene-level test passes.
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

  Future<Uint8List> exportOf(String name) async {
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: File(
          '../../apps/rackpal/assets/starters/$name.rppj',
        ).readAsBytesSync(),
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: '$name.rppj',
        issuedAt: DateTime.utc(2026, 9, 30),
      ),
    );
    return (result as Ok<ExportedDocument>).value.bytes;
  }

  /// The text of the page whose sheet id is T0.01, or null.
  String? legendPage(Uint8List bytes) {
    final cmap = parseToUnicodeCMap(bytes);
    for (final body in operatorStreams(bytes)) {
      final text = interpretContentStream(body, toUnicode: cmap).allText;
      if (RegExp(r'SHEET NO\.\s+T0\.01').hasMatch(text)) return text;
    }
    return null;
  }

  test('A STARTER WITH NO CABLES exports a legend carrying all ten named '
      'types (DR-207), in ink', () async {
    final text = legendPage(await exportOf('home_theatre'));
    expect(text, isNotNull, reason: 'no T0.01 page was recovered');
    expect(text, contains('SYMBOL LEGEND'));
    for (final type in kRequirement4Types) {
      expect(text, contains(type.name), reason: type.name);
    }
  });

  test("and a starter's OWN extra family gets its row", () async {
    // Whole House carries `net.fiber_sm`, which is none of the ten.
    final text = legendPage(await exportOf('whole_house'))!;
    expect(
      text,
      contains(
        buildSeedRegistries()
            .signalFamilies[const SignalFamilyId('net.fiber_sm')]!
            .displayName,
      ),
    );
  });
}
