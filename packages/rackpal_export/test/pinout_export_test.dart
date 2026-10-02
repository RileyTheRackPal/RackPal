// T5.01 read back from the PDF (M6-E2c `#976`, DR-221).
//
// On its ink, on the real starters: Home Theatre's six powered receiver
// ports with the pin map the user ruled (ring +12 V, sleeve GND), and a
// recorded terminal order and a wiring exception each printing their own
// section with their own heads.
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
        fileName: 'pinout.rppj',
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

  test('HOME THEATRE: the six receiver ports, each with the ruled pin map, '
      'and the warning', () async {
    final page = (await pages(starter('home_theatre')))['T5.01']!;
    expect(page, contains('$kIrSectionTitle (6)'));
    expect(page, contains(kIrSectionNote));
    expect(
      'TIP IR · RING +12 V · SLEEVE GND'.allMatches(page).length,
      6,
      reason: 'one pin map per port',
    );
    expect(page, isNot(contains('RING GND')), reason: 'the reversed map');
    for (final port in ['IR RX 1', 'IR RX 4', 'PIGTAIL TO BLOCK']) {
      expect(page, contains(port));
    }
  });

  test('A TERMINAL ORDER AND A WIRING EXCEPTION each print their own '
      'section, after the IR one', () async {
    final doc = starter('home_theatre');
    final ctl = doc.devices.values.singleWhere((d) => d.designator == 'CTL-1');
    bodyFor(
      ctl,
      doc.templates,
    )!.ports.singleWhere((p) => p.key.v == 'com.1').terminalRoles = [
      'G',
      'TX',
      'RX',
    ];
    doc.settings.wiringStandard = WiringStandard.t568b;
    final wh = starter('whole_house');
    // Home Theatre carries no cable, so the wiring case is Whole House's.
    wh.settings.wiringStandard = WiringStandard.t568b;
    final cat6 = wh.links.values.firstWhere(
      (l) => l.media.v.startsWith('media.cat6'),
    );
    // THROUGH THE COMMAND, as the app writes it: the setter is core's.
    SetEntityPropertyCommand<Link, WiringStandard?>(
      id: cat6.id,
      field: LinkField.wiringStandard,
      from: cat6.wiringStandard,
      to: WiringStandard.t568a,
      now: DateTime.utc(2026, 10, 2),
      actor: 'test',
    ).apply(wh);

    final ht = (await pages(doc))['T5.01']!;
    expect(ht, contains('$kTerminalSectionTitle (1)'));
    expect(ht, contains('G TX RX'));
    expect(ht, contains('TX RX G'));
    expect(
      ht.indexOf(kIrSectionTitle),
      lessThan(ht.indexOf(kTerminalSectionTitle)),
    );

    final house = (await pages(wh))['T5.01']!;
    expect(house, contains('$kWiringSectionTitle (1)'));
    expect(house, contains(cat6.designator));
    expect(house, contains(kT568aKey));
    expect(house, contains(kT568bKey));
  });
}
