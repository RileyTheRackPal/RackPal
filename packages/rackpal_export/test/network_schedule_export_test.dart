// T6.50 read back from the PDF (NET-A/3a, `#992`, DR-048 §11.47.4,
// DR-228).
//
// Asserted on its ink, on the real starter, absent and present: no
// starter ships an address, so Whole House as shipped is the absent case
// and the same project with three devices addressed is the present one.
// The index is read too, since an AUTO sheet that is absent is absent from
// both (`auto_sheet_absent_test.dart`).
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

  RackDocument wholeHouse() =>
      (const JsonDocumentCodec().read(
                File(
                  '../../apps/rackpal/assets/starters/whole_house.rppj',
                ).readAsBytesSync(),
              )
              as Ok<RackDocument>)
          .value;

  /// Writes through the command: the fields' setters are core's own.
  void set<T>(
    RackDocument doc,
    String designator,
    EntityField<DeviceInstance, T> field,
    T to,
  ) => DocumentController(doc).run(
    buildSetEntityProperty(
      doc: doc,
      id: doc.devices.values.firstWhere((d) => d.designator == designator).id,
      field: field,
      to: to,
      now: DateTime.utc(2026, 10, 4),
      actor: 'test',
    )!,
  );

  RackDocument addressed() {
    final doc = wholeHouse();
    set(doc, 'SW-1', DeviceField.networkIp, '10.0.10.2');
    set(doc, 'SW-1', DeviceField.networkSubnet, '255.255.255.0');
    set(doc, 'SW-1', DeviceField.networkGateway, '10.0.10.1');
    set(doc, 'SW-1', DeviceField.networkVerifiedOn, DateTime.utc(2026, 10, 3));
    set(doc, 'FW-1', DeviceField.networkIp, '10.0.10.1');
    set(doc, 'AP-1', DeviceField.macAddressPrimary, '00:11:22:33:44:55');
    return doc;
  }

  Future<ExportedDocument> export(RackDocument doc) async =>
      (await buildExportDocument(
                ExportRequest(
                  documentJson: const JsonDocumentCodec().write(doc),
                  fontBytes: <FontRef, Uint8List>{_font: fontBytes},
                  fileName: 'network.rppj',
                  issuedAt: DateTime.utc(2026, 10, 4),
                ),
              )
              as Ok<ExportedDocument>)
          .value;

  Map<String, String> pagesOf(Uint8List bytes) {
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

  test('WHOLE HOUSE AS SHIPPED, nothing recorded: no page, no index row, '
      'no notice', () async {
    final exported = await export(wholeHouse());
    final pages = pagesOf(exported.bytes);
    expect(pages.keys, contains('T6.30'), reason: 'control: pages read');
    expect(pages.keys.where((id) => id.startsWith('T6.5')), isEmpty);
    expect(pages['T0.00'], isNot(contains('NETWORK/IP SCHEDULE')));
    expect(exported.notices.join('\n'), isNot(contains('network-capable')));
  });

  test('THREE DEVICES ADDRESSED: T6.50 prints them, every column head, '
      'after T6.30, and the cover indexes it', () async {
    final exported = await export(addressed());
    final pages = pagesOf(exported.bytes);
    final page = pages['T6.50']!;

    expect(page, contains('$kNetworkSheetHeading (3)'));
    expect(page, contains(networkOrderNote(NetworkOrder.designator)));
    expect(page, contains(kVerifiedKey));
    // THE SET'S FURNITURE (#993): the legend is pointed at, as on every
    // other sheet.
    expect(page, contains('SYMBOL LEGEND: SEE SHEET T0.01'));
    for (final c in NetworkColumnId.values) {
      expect(page, contains(networkColumnHeader(c)), reason: c.name);
    }
    for (final value in [
      'SW-1',
      'FW-1',
      'AP-1',
      '10.0.10.2',
      '255.255.255.0',
      '00:11:22:33:44:55',
      '2026-10-03',
      kUnverified,
    ]) {
      expect(page, contains(value), reason: value);
    }
    // A DEVICE WITH NOTHING RECORDED IS NOT A ROW (§11.227.2).
    expect(page, isNot(contains('AMP-1')));

    final ids = pages.keys.toList();
    expect(ids.indexOf('T6.50'), greaterThan(ids.indexOf('T6.30')));
    expect(pages['T0.00'], contains('NETWORK/IP SCHEDULE'));
  });

  test('THE GAP IS SAID: a notice names the capable devices left blank, '
      'and none of the three', () async {
    final exported = await export(addressed());
    final notice = exported.notices.firstWhere(
      (n) => n.contains('network-capable'),
    );
    expect(notice, contains('not on T6.50'));
    expect(notice, contains('AMP-1'));
    for (final d in ['SW-1', 'FW-1', 'AP-1']) {
      expect(notice, isNot(contains('$d,')), reason: d);
      expect(notice, isNot(endsWith('$d.')), reason: d);
    }
  });
}
