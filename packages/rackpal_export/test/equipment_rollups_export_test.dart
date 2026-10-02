// T6.30's rollups reach the PDF (M6-F `#335`, DR-219).
//
// The core tests prove each section's rows against its derivation; this
// proves the ink, on a real starter: the section's band and its own header
// row print, and each row's figures are the derivation's.
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

  /// Every T6.3x page's text, in order, whitespace collapsed.
  Future<String> equipmentInk(RackDocument doc) async {
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: const JsonDocumentCodec().write(doc),
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: 'x.rppj',
        issuedAt: DateTime.utc(2026, 10),
      ),
    );
    final bytes = (result as Ok<ExportedDocument>).value.bytes;
    final cmap = parseToUnicodeCMap(bytes);
    return [
          for (final body in operatorStreams(bytes))
            interpretContentStream(body, toUnicode: cmap).allText,
        ]
        .where((t) => RegExp(r'SHEET NO\.\s+T6\.3').hasMatch(t))
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  test('WHOLE HOUSE: the footage section, its own header, and every media '
      "line's figures in ink (F2, AC-024)", () async {
    final doc = starter('whole_house');
    final footage = buildCableFootage(doc);
    final ink = await equipmentInk(doc);
    expect(ink, contains(kFootageSectionTitle));
    expect(ink, contains('LENGTH UNKNOWN'));
    expect(
      ink,
      contains('WITH WASTE (+${percentOf(doc.settings.cableWasteFactor)})'),
    );
    for (final line in footage.lines) {
      final units = doc.settings.displayUnits;
      expect(
        ink,
        contains(
          '${line.media?.displayName ?? line.mediaId.v} '
          '${line.runCount} ${line.estimatedCount} '
          '${line.footage.unknownCount} '
          '${footageText(line.footage.value, units)} '
          '${footageText(line.withWaste, units)}',
        ),
        reason: line.mediaId.v,
      );
    }
  });

  test(
    'a project with no field cable and no leads says so on the sheet',
    () async {
      final ink = await equipmentInk(starter('apartment'));
      expect(ink, contains(kFootageSectionTitle));
      expect(ink, contains(kNoFootageText));
      expect(ink, contains(kJumperSectionTitle));
      expect(ink, contains(kNoJumpersText));
    },
  );

  test('WHOLE HOUSE: a rear-support line per RCK-013 finding, in ink '
      '(F3, AC-028)', () async {
    final doc = starter('whole_house');
    final ink = await equipmentInk(doc);
    expect(ink, contains(kHardwareSectionTitle));
    for (final f in evaluateDocument(doc).where((f) => f.ruleId == 'RCK-013')) {
      final device = doc.devices[f.primaryEntityId]!.designator;
      expect(
        ink,
        contains('1 Rear rail support $device RK-1 RCK-013'),
        reason: device,
      );
    }
  });

  test('WHOLE HOUSE: the outlet map names every provider and its free '
      'count, with no cord drawn (F5, AC-026, DR-219)', () async {
    final doc = starter('whole_house');
    final ink = await equipmentInk(doc);
    expect(ink, contains(kOutletMapSectionTitle));
    expect(ink, contains(kNoOutletCordsText));
    for (final p in buildOutletMap(doc).providers) {
      expect(
        ink,
        contains(
          '${p.device.designator}: 0 of ${p.outletCount} outlets assigned, '
          '${p.outletCount} free.',
        ),
        reason: p.device.designator,
      );
    }
  });
}
