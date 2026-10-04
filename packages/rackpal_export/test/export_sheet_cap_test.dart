// The export's dry-run count (M6-I1, `#352`, AC-050/A7.4, DR-230
// §11.229.2): past 40 sheets it is said and nothing is asked; past 2000 it
// is refused before a page is emitted.
//
// Whole House exports sixteen sheets, and every empty rack adds two (its
// front and rear elevations), so the boundaries are reached by adding
// racks to a real project rather than by inventing a document.
import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

const FontRef _font = FontRef('Jost');

RackDocument _wholeHouse({int extraRacks = 0}) {
  final doc =
      (const JsonDocumentCodec().read(
                File(
                  '../../apps/rackpal/assets/starters/whole_house.rppj',
                ).readAsBytesSync(),
              )
              as Ok<RackDocument>)
          .value;
  for (var i = 0; i < extraRacks; i++) {
    final id = Uuid('cap-rack-$i');
    doc.racks[id] = Rack(
      id: id,
      name: 'Cap rack $i',
      designator: 'RX-$i',
      heightU: 12,
      order: FracIndex('z${i.toString().padLeft(4, '0')}'),
      meta: EntityMeta(
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        updatedBy: 'test',
      ),
    );
  }
  return doc;
}

void main() {
  late Uint8List font;
  setUpAll(() {
    font = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
  });

  Future<Outcome<ExportedDocument>> export(RackDocument doc) =>
      buildExportDocument(
        ExportRequest(
          documentJson: const JsonDocumentCodec().write(doc),
          fontBytes: <FontRef, Uint8List>{_font: font},
          fileName: 'cap.rppj',
          issuedAt: DateTime.utc(2026, 10, 4),
        ),
      );

  test(
    'THE CONTROL: Whole House is sixteen sheets, and a rack adds two',
    () async {
      final base = (await export(_wholeHouse())) as Ok<ExportedDocument>;
      final one =
          (await export(_wholeHouse(extraRacks: 1))) as Ok<ExportedDocument>;
      expect(base.value.sheetCount, 16);
      expect(one.value.sheetCount, 18);
    },
  );

  test('FORTY SHEETS IS NOT LARGE: no notice', () async {
    final done =
        (await export(_wholeHouse(extraRacks: 12))) as Ok<ExportedDocument>;
    expect(done.value.sheetCount, kLargeSetSheets);
    expect(
      done.value.notices.where((n) => n.contains('a set usually needs')),
      isEmpty,
    );
  });

  test('PAST FORTY IT IS SAID, first among the notices, and the file is '
      'still written: nothing is asked', () async {
    final done =
        (await export(_wholeHouse(extraRacks: 13))) as Ok<ExportedDocument>;
    expect(done.value.sheetCount, 42);
    expect(done.value.notices.first, largeSetNotice(42));
    expect(done.value.bytes, isNotEmpty);
  });

  test('PAST 2000 IT IS REFUSED, saying the count, before a page is '
      'emitted', () async {
    final watch = Stopwatch()..start();
    final refused = await export(_wholeHouse(extraRacks: 993));
    watch.stop();
    expect(refused, isA<Err<ExportedDocument>>());
    final error =
        (refused as Err<ExportedDocument>).error as ExportTooManySheets;
    // NOT 16 + 2 x 993: at this scale the extra racks also lengthen the
    // paginated sheets (findings on T0.02, rows on T6.30), which is the
    // dry run counting what would really print. Two per rack holds at the
    // forty-sheet boundary above, where it is asserted exactly.
    expect(error.sheets, greaterThan(kMaxExportSheets));
    expect(error.message, contains('${error.sheets} sheets'));
    expect(error.message, contains('$kMaxExportSheets'));
    // BEFORE A PAGE IS EMITTED: two thousand pages take seconds at the
    // measured six milliseconds a sheet, and a refusal must not cost that.
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
  });
}
