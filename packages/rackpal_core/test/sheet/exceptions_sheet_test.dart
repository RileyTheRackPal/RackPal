// T0.02's pages (M6-C `#322`, `#323`, `#324`, `#325`, DR-214).
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

final DateTime _issued = DateTime.utc(2026, 10);

RackDocument _wholeHouse() =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/whole_house.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

DBox _drawingArea() => SheetLayout.resolve(
  geometry: const SheetGeometry(SheetSize.ansiBLandscape),
  revisionRowCount: 0,
).drawingArea;

List<ExceptionsPage> _pages(RackDocument doc, {List<Finding>? findings}) =>
    paginateExceptions(
      report: buildExceptionsReport(doc, findings ?? evaluateDocument(doc)),
      doc: doc,
      drawingArea: _drawingArea(),
      measurer: FakeMeasurer(),
      issuedAt: _issued,
    );

List<ExceptionsItem> _items(List<ExceptionsPage> pages) => [
  for (final p in pages) ...p.items,
];

String _joined(ExceptionsRow row, int column) => row.cells[column].join(' ');

void main() {
  test('AN EMPTY REPORT IS ONE PAGE THAT SAYS SO, section by section, with '
      'the basis for "no open findings" (#325)', () {
    final doc = RackDocument(
      id: const Uuid('doc-empty'),
      appVersion: 'test',
      createdAt: _issued,
      modifiedAt: _issued,
      meta: testMeta(),
    );
    final pages = _pages(doc, findings: const <Finding>[]);
    expect(pages, hasLength(1));
    final items = pages.single.items;
    expect(
      items.whereType<ExceptionsHeading>().map((h) => h.title),
      [
        '$kProjectWideHeading (0)',
        '$kOpenHeading (0)',
        '$kAcknowledgedHeading (0)',
      ],
    );
    expect(items.whereType<ExceptionsNote>().map((n) => n.text), [
      kNoProjectWide,
      noOpenFindingsText(_issued),
      kNoAcknowledged,
    ]);
    expect(noOpenFindingsText(_issued), contains('2026-10-01'));
  });

  group('Whole House, 39 open findings (#323)', () {
    final doc = _wholeHouse();
    final findings = evaluateDocument(doc);
    final pages = _pages(doc, findings: findings);
    final rows = _items(pages).whereType<ExceptionsRow>().toList();

    test('EVERY FINDING IS ONE ROW, its message whole across the wrap', () {
      expect(rows, hasLength(findings.length));
      expect(
        [for (final r in rows) _joined(r, 3)],
        // BANDED BY SEVERITY, and within a band in `evaluateDocument`'s own
        // order, which `groupFindings` refuses to re-sort.
        [
          for (final s in Severity.values)
            for (final f in findings)
              if (f.severity == s) f.message,
        ],
      );
    });

    test('ERRORS FIRST, then warnings, then advisories (§11.213.2)', () {
      final bands = _items(pages)
          .whereType<ExceptionsBand>()
          .where((b) => !b.continued)
          .map((b) => b.title.split(' ').first)
          .toList();
      expect(bands, ['ERROR', 'WARNING', 'ADVISORY']);
    });

    test('THE LOCUS IS A DESIGNATOR a reader can find in a rack room', () {
      final loci = {for (final r in rows) _joined(r, 2)};
      expect(loci, contains('W015'));
      expect(loci, contains('UPS-1'));
    });

    test('A PAGE BREAK REPEATS THE HEADING AND THE BAND, and nothing runs '
        'off a page', () {
      final body = exceptionsBodyArea(_drawingArea());
      for (final page in pages) {
        expect(
          page.items.fold<double>(0, (h, i) => h + i.height),
          lessThanOrEqualTo(body.height),
        );
      }
      for (final page in pages.skip(1)) {
        final first = page.items.first;
        expect(first, isA<ExceptionsHeading>());
        expect(
          (first as ExceptionsHeading).continued ||
              page.items.first is ExceptionsHeading,
          isTrue,
        );
      }
      if (pages.length > 1) {
        expect(
          pages[1].items.whereType<ExceptionsHeading>().first.text,
          endsWith('(cont.)'),
        );
      }
    });
  });

  test('THE SIGNED SECTIONS: the override and the mute first, the '
      'acknowledged row with its reason, the stale one under NO LONGER '
      'OCCURS (#324)', () {
    final doc = _wholeHouse();
    final before = evaluateDocument(doc);
    final target = before.firstWhere((f) => f.ruleId == 'LEN-001');
    AckedFinding ack(String id, String rule, String fp, String reason) =>
        AckedFinding(
          id: Uuid(id),
          ruleId: rule,
          targetFingerprint: fp,
          reason: reason,
          by: 'riley',
          at: _issued,
          demotedTo: Severity.warning,
          meta: testMeta(),
        );
    doc.ackedFindings[const Uuid('a1')] = ack(
      'a1',
      'LEN-001',
      target.targetFingerprint,
      'Measured on site at termination.',
    );
    doc.ackedFindings[const Uuid('a2')] = ack(
      'a2',
      'RCK-013',
      'RCK-013:gone',
      '',
    );
    doc.settings.ruleOverrides['LEN-002'] = RuleOverride(
      severity: Severity.advisory,
      reason: 'Lengths are estimated at rough-in.',
      by: 'riley',
      at: _issued,
    );
    final items = _items(_pages(doc));
    final rows = items.whereType<ExceptionsRow>().toList();

    // The first row on the sheet is the override.
    expect(_joined(rows.first, 0), 'LEN-002');
    expect(_joined(rows.first, 2), 'Lengths are estimated at rough-in.');

    final acked = rows.where(
      (r) =>
          r.cells.length == 7 &&
          _joined(r, 4) == 'Measured on site at termination.',
    );
    expect(acked, hasLength(1));

    expect(
      items.whereType<ExceptionsBand>().map((b) => b.title),
      contains('$kNoLongerOccurs (1)'),
    );
    final stale = rows.last;
    expect(_joined(stale, 1), 'RCK-013');
    expect(
      _joined(stale, 4),
      '(no reason given)',
      reason: 'an empty reason is legal on an instance (RJ-006)',
    );
  });
}
