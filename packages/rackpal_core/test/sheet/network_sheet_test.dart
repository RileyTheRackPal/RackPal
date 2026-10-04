// T6.50's rows, pages and place in the set (NET-A/3a, `#992`, DR-048
// §11.47.4, DR-228).
//
// The rows are the Devices view's (CR-107), so what is tested here is the
// projection: which rows the sheet keeps, how they page, where the sheet
// lands and what it is numbered, and what the export says about the rest.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

RackDocument _wholeHouse() =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/whole_house.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

DeviceInstance _named(RackDocument doc, String designator) =>
    doc.devices.values.firstWhere((d) => d.designator == designator);

/// Writes through the command, as the product does.
void _set<T>(
  RackDocument doc,
  String designator,
  EntityField<DeviceInstance, T> field,
  T to,
) => DocumentController(doc).run(
  buildSetEntityProperty(
    doc: doc,
    id: _named(doc, designator).id,
    field: field,
    to: to,
    now: DateTime.utc(2026, 10, 4),
    actor: 'test',
  )!,
);

/// Whole House with an address on SW-1 and FW-1 and a MAC on AP-1.
RackDocument _addressed() {
  final doc = _wholeHouse();
  _set(doc, 'SW-1', DeviceField.networkIp, '10.0.10.2');
  _set(doc, 'FW-1', DeviceField.networkIp, '10.0.10.1');
  _set(doc, 'AP-1', DeviceField.macAddressPrimary, '00:11:22:33:44:55');
  return doc;
}

DBox get _area => SheetLayout.resolve(
  geometry: const SheetGeometry(SheetSize.ansiALandscape),
  revisionRowCount: 0,
).drawingArea;

List<NetworkSheetPage> _paginate(
  List<NetworkRow> rows, {
  NetworkOrder order = NetworkOrder.designator,
}) => paginateNetworkSchedule(
  rows: rows,
  order: order,
  drawingArea: _area,
  measurer: FakeMeasurer(),
);

void main() {
  group('WHICH ROWS (§11.227.2)', () {
    test('NOTHING RECORDED IS NO PAGE: the sheet is AUTO, never a page '
        'saying none', () {
      final doc = _wholeHouse();
      expect(networkSheetRowsOf(doc), isEmpty);
      expect(_paginate(networkSheetRowsOf(doc)), isEmpty);
    });

    test('only devices carrying a value print, a MAC alone included', () {
      final doc = _addressed();
      expect(buildNetworkTable(doc).length, greaterThan(3), reason: 'control');
      expect(networkSheetRowsOf(doc).map((r) => r.designator), [
        'AP-1',
        'FW-1',
        'SW-1',
      ]);
    });

    test('a date alone is not a value: a verified row with nothing in it '
        'has nothing to print', () {
      final doc = _wholeHouse();
      _set(doc, 'SW-1', DeviceField.networkVerifiedOn, DateTime.utc(2026, 10));
      expect(networkSheetRowsOf(doc), isEmpty);
    });

    test("THE PROJECT'S ORDER, the one the Devices view uses (DR-227)", () {
      final doc = _addressed();
      final byDesignator = networkSheetRowsOf(doc).map((r) => r.designator);
      doc.settings.networkOrder = NetworkOrder.rackThenRoom;
      final byRack = networkSheetRowsOf(doc).map((r) => r.designator);
      expect(byRack, [
        for (final r in buildNetworkTable(
          doc,
          order: NetworkOrder.rackThenRoom,
        ))
          if (r.hasValues) r.designator,
      ]);
      expect(byRack.toSet(), byDesignator.toSet());
    });
  });

  group('CELLS (§11.227.1)', () {
    test('all ten columns, a blank printed as unknown and an undated row '
        'saying unverified', () {
      final doc = _addressed();
      final sw = networkSheetRowsOf(doc).firstWhere(
        (r) => r.designator == 'SW-1',
      );
      final cells = [
        for (final c in NetworkColumnId.values) networkSheetCell(sw, c),
      ];
      expect(cells, hasLength(10));
      expect(networkSheetCell(sw, NetworkColumnId.ip), '10.0.10.2');
      expect(networkSheetCell(sw, NetworkColumnId.subnet), kUnknownCell);
      expect(networkSheetCell(sw, NetworkColumnId.verified), kUnverified);
    });

    test('the widths fill the ANSI A body exactly', () {
      expect(
        kNetworkSheetWidths.keys.toSet(),
        NetworkColumnId.values.toSet(),
      );
      expect(kNetworkSheetWidths.values.fold<double>(0, (s, w) => s + w), 674);
    });
  });

  group('PAGINATION', () {
    test('one page: the heading with its count, the order note, the rows', () {
      final pages = _paginate(networkSheetRowsOf(_addressed()));
      expect(pages, hasLength(1));
      final heading = pages.single.items.first as NetworkSheetHeading;
      expect(heading.text, '$kNetworkSheetHeading (3)');
      expect(heading.notes, [networkOrderNote(NetworkOrder.designator)]);
      expect(pages.single.designators, ['AP-1', 'FW-1', 'SW-1']);
    });

    test('the order note names the order the rows are in', () {
      final pages = _paginate(
        networkSheetRowsOf(_addressed()),
        order: NetworkOrder.rackThenRoom,
      );
      expect(
        (pages.single.items.first as NetworkSheetHeading).notes,
        [networkOrderNote(NetworkOrder.rackThenRoom)],
      );
      expect(
        networkOrderNote(NetworkOrder.rackThenRoom),
        isNot(networkOrderNote(NetworkOrder.designator)),
      );
    });

    for (final n in [1, 20, 45, 46, 47, 90, 200]) {
      test('$n rows: every row once, in order, every page headed and none '
          'overfull', () {
        final real = networkSheetRowsOf(_addressed());
        final rows = [for (var i = 0; i < n; i++) real[i % real.length]];
        final pages = _paginate(rows);
        final body = networkSheetBodyArea(_area);
        expect(
          [for (final p in pages) ...p.designators],
          [for (final r in rows) r.designator],
        );
        for (final (i, page) in pages.indexed) {
          final heading = page.items.first as NetworkSheetHeading;
          expect(heading.continued, i > 0);
          expect(page.designators, isNotEmpty);
          final used = page.items.fold<double>(0, (s, it) => s + it.height);
          expect(used, lessThanOrEqualTo(body.height));
        }
      });
    }

    test('THE CONTROL: the sweep reaches more than one page', () {
      final real = networkSheetRowsOf(_addressed());
      expect(
        _paginate([for (var i = 0; i < 200; i++) real[i % real.length]]).length,
        greaterThan(2),
      );
    });
  });

  group('THE SET (§11.227.3)', () {
    List<String> ids({
      int network = 0,
      int equipment = 1,
      int pinout = 0,
      int unused = 0,
    }) => SheetSet.forRacks(
      [testRack()],
      networkScheduleSheets: network,
      equipmentListSheets: equipment,
      pinoutSheets: pinout,
      unusedHomeRunSheets: unused,
    ).sheets.map((s) => s.ncsId).toList();

    test('NONE RECORDED, NO T6.50: the set is the one it was before', () {
      expect(ids(), isNot(contains('T6.50')));
      expect(ids(network: 1), hasLength(ids().length + 1), reason: 'control');
    });

    test('T6.50 sits after T6.30 and before T5.01', () {
      final set = ids(network: 2, pinout: 1);
      expect(set.sublist(set.length - 4), ['T6.30', 'T6.50', 'T6.51', 'T5.01']);
    });

    test('AN ELEVENTH PAGE takes the pool AFTER the equipment list, which '
        'precedes it: no id on two sheets', () {
      final set = SheetSet.forRacks(
        [testRack()],
        unusedHomeRunSheets: 11,
        equipmentListSheets: 11,
        networkScheduleSheets: 12,
      );
      List<String> of(SheetRole role) => [
        for (final s in set.sheets)
          if (s.role == role) s.ncsId,
      ];
      expect(of(SheetRole.unusedHomeRuns).last, 'T6.60');
      expect(of(SheetRole.equipmentList).last, 'T6.61');
      expect(of(SheetRole.networkSchedule), [
        for (var n = 50; n < 60; n++) 'T6.$n',
        'T6.62',
        'T6.63',
      ]);
      final all = set.sheets.map((s) => s.ncsId).toList();
      expect(all.toSet(), hasLength(all.length));
      expect(set.notices.join('\n'), contains('numbered from T6.62'));
    });

    test('T6.50 IS NO LONGER RESERVED; T6.40 still is', () {
      expect(isReservedNcsId('T6.50'), isFalse);
      expect(isReservedNcsId('T6.40'), isTrue);
      final set = SheetSet.forRacks([testRack()], networkScheduleSheets: 1);
      expect(set.notices.join('\n'), isNot(contains('T6.50')));
    });

    test('the role: ANSI A landscape, a table and not a drawing', () {
      expect(SheetRole.networkSchedule.size, SheetSize.ansiALandscape);
      expect(SheetRole.networkSchedule.zoned, isFalse);
      expect(SheetRole.networkSchedule.perRack, isFalse);
    });
  });

  group('THE NOTICE (§11.227.2)', () {
    test('nothing recorded, no notice: there is no schedule to have a gap', () {
      expect(networkUnrecordedNotice(_wholeHouse(), 'T6.50'), isNull);
    });

    test('names how many capable devices have nothing, and which', () {
      final doc = _addressed();
      final blank = buildNetworkTable(doc).length - 3;
      final notice = networkUnrecordedNotice(doc, 'T6.50')!;
      expect(notice, startsWith('$blank network-capable devices have'));
      expect(notice, contains('not on T6.50'));
      expect(notice, contains('AMP-1'));
      expect(notice, isNot(contains('SW-1')));
    });
  });

  group('THE PAGE', () {
    test('prints the heading, the heads and the values, legibly', () {
      final doc = _addressed();
      final set = SheetSet.forRacks(
        doc.racks.values,
        networkScheduleSheets: 1,
      );
      final sheet = set.sheets.firstWhere(
        (s) => s.role == SheetRole.networkSchedule,
      );
      final built = buildNetworkSheet(
        sheet: sheet,
        page: _paginate(networkSheetRowsOf(doc)).single,
        info: doc.info,
        settings: doc.settings,
        revisions: doc.revisionBlock,
        fileName: 'whole_house.rppj',
        issuedAt: DateTime.utc(2026, 10, 4),
        measurer: FakeMeasurer(),
      );
      final texts = [
        for (final op in built.scene.ops)
          if (op is OpText) op.text,
      ];
      expect(texts, contains('$kNetworkSheetHeading (3)'));
      for (final c in NetworkColumnId.values) {
        expect(texts, contains(networkColumnHeader(c)));
      }
      expect(texts, containsAll(<String>['10.0.10.2', '00:11:22:33:44:55']));
      expect(built.legibility.notice, isNull);
    });
  });
}
