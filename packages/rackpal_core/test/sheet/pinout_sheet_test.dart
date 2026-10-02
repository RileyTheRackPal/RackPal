// T5.01's pages and its place in the set (M6-E2c `#976`, DR-221).
//
// A section heading keeps with its first row and a page that opens inside
// a section re-heads it (cont.), swept over sizes rather than sampled; a
// section with no rows is not drawn; and T5.01 is last in the set.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

RackDocument _starter(String name) =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/$name.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

DBox get _area => SheetLayout.resolve(
  geometry: const SheetGeometry(SheetSize.ansiALandscape),
  revisionRowCount: 0,
).drawingArea;

List<PinoutPage> _paginate(PinoutDetails details) => paginatePinoutDetails(
  details: details,
  settings: ProjectSettings(),
  drawingArea: _area,
  measurer: FakeMeasurer(),
);

/// Home Theatre's six real receiver ports, repeated to [n] rows, plus
/// [terminals] terminal-order rows, so the sweep pages real cells.
PinoutDetails _details(int n, {int terminals = 0}) {
  final doc = _starter('home_theatre');
  final real = pinoutDetailsOf(doc, buildSchedule(doc)).irPorts;
  final port = real.first.port;
  return PinoutDetails(
    irPorts: [for (var i = 0; i < n; i++) real[i % real.length]],
    wiringExceptions: const [],
    nullModems: const [],
    terminalOrders: [
      for (var i = 0; i < terminals; i++)
        TerminalOrderRow(
          port: port,
          roles: const ['G', 'TX', 'RX'],
          standard: const ['TX', 'RX', 'G'],
        ),
    ],
  );
}

void main() {
  group('PAGINATION', () {
    test('NOTHING NON-STANDARD IS NO PAGE: AUTO, never a page saying none', () {
      expect(_paginate(_details(0)), isEmpty);
    });

    test('Home Theatre as shipped: one page, one section, the IR note, six '
        'rows', () {
      final doc = _starter('home_theatre');
      final pages = _paginate(pinoutDetailsOf(doc, buildSchedule(doc)));
      expect(pages, hasLength(1));
      final heads = pages.single.items.whereType<PinoutSectionHead>();
      expect(heads.map((h) => h.text), ['$kIrSectionTitle (6)']);
      expect(heads.single.notes, [kIrSectionNote]);
      expect(pages.single.items.whereType<PinoutRow>(), hasLength(6));
    });

    test('A SECTION WITH NO ROWS IS NOT DRAWN; two kinds, two sections', () {
      final heads = _paginate(_details(2, terminals: 1))
          .expand((p) => p.items)
          .whereType<PinoutSectionHead>()
          .map((h) => h.title);
      expect(heads, ['$kIrSectionTitle (2)', '$kTerminalSectionTitle (1)']);
    });

    for (final (ir, terminals) in [
      (1, 0),
      (40, 0),
      (90, 0),
      (37, 1),
      (30, 30),
      (60, 45),
    ]) {
      test('$ir IR rows and $terminals terminal rows: every row once; no '
          'page ends on a heading; a page never opens on a bare row', () {
        final pages = _paginate(_details(ir, terminals: terminals));
        expect(
          pages.expand((p) => p.items).whereType<PinoutRow>(),
          hasLength(ir + terminals),
        );
        final body = pinoutBodyArea(_area);
        for (final (n, page) in pages.indexed) {
          expect(
            page.items.fold<double>(0, (y, i) => y + i.height),
            lessThanOrEqualTo(body.height),
            reason: 'page ${n + 1} fits',
          );
          expect(page.items.last, isA<PinoutRow>(), reason: 'page ${n + 1}');
          expect(page.items.first, isA<PinoutSectionHead>());
          final first = page.items.first as PinoutSectionHead;
          // A page that opens inside a section names it (cont.), with the
          // heads; one that opens on a new section does not say cont.
          final rowsBefore = pages
              .take(n)
              .expand((p) => p.items)
              .whereType<PinoutRow>()
              .where((r) => identical(r.columns, first.columns))
              .length;
          expect(first.continued, rowsBefore > 0, reason: 'page ${n + 1}');
        }
      });
    }

    // SWEPT, NOT SAMPLED. The six sizes above never put the second
    // section's heading at a page foot, and a paginator with no keep-with
    // passed them all (a mutation survived). Every IR count from 1 to 90
    // ahead of a terminal section reaches that case.
    test('A SECTION HEADING IS NEVER LAST ON A PAGE, for every IR count from '
        '1 to 90 ahead of a second section', () {
      for (var ir = 1; ir <= 90; ir++) {
        for (final (n, page) in _paginate(
          _details(ir, terminals: 3),
        ).indexed) {
          expect(
            page.items.last,
            isA<PinoutRow>(),
            reason: '$ir IR rows: page ${n + 1} ends on a heading',
          );
        }
      }
    });

    test('THE CONTROL: the sweep reaches more than one page', () {
      expect(_paginate(_details(90)).length, greaterThan(2));
    });
  });

  group('THE SET (§11.220.6)', () {
    test('NOTHING NON-STANDARD, NO T5.01', () {
      expect(
        SheetSet.forRacks([testRack()]).sheets.map((s) => s.role),
        isNot(contains(SheetRole.pinoutDetails)),
      );
    });

    test('T5.01 is LAST, after T6.30, and its pages count up', () {
      final ids = SheetSet.forRacks(
        [testRack()],
        unusedHomeRunSheets: 1,
        pinoutSheets: 2,
      ).sheets.map((s) => s.ncsId).toList();
      expect(ids.sublist(ids.length - 4), ['T6.20', 'T6.30', 'T5.01', 'T5.02']);
    });
  });
}
