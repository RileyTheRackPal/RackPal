// T6.30's rollup sections (M6-F `#335`, DR-219 §11.218.1).
//
// Each rollup is a titled section with its OWN header row, after
// MATERIALS. What a widget test could never see and these do: a page that
// opens inside a section heads its columns with the section's names, and
// re-prints the band with `(cont.)`.
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

const List<SectionColumn> _cols = <SectionColumn>[
  SectionColumn('ITEM', 600),
  SectionColumn('QTY', 90, alignRight: true),
];

RollupSection _section(int rows, {List<String> notes = const []}) =>
    RollupSection(
      title: 'TEST SECTION',
      columns: _cols,
      rows: <List<String>>[
        for (var i = 0; i < rows; i++) <String>['item $i', '$i'],
      ],
      empty: 'NOTHING HERE.',
      notes: notes,
    );

DBox get _area => SheetLayout.resolve(
  geometry: const SheetGeometry(SheetSize.ansiALandscape),
  revisionRowCount: 0,
).drawingArea;

List<SchedulePage> _paginate(
  RackDocument doc,
  List<RollupSection> sections,
) => paginateEquipmentList(
  list: buildEquipmentList(doc),
  drawingArea: _area,
  measurer: FakeMeasurer(),
  sections: sections,
);

void main() {
  group('the section mechanism (§11.218.1)', () {
    test('a section is its band, its own header row, its rows, its notes', () {
      final pages = _paginate(_starter('apartment'), [
        _section(2, notes: ['two counted']),
      ]);
      final items = pages.expand((p) => p.items).toList();
      final band = items.indexWhere(
        (i) => i is ScheduleBand && i.title == 'TEST SECTION',
      );
      expect(band, isNonNegative);
      expect(items[band + 1], isA<ScheduleColumns>());
      expect((items[band + 1] as ScheduleColumns).columns, _cols);
      expect(
        [
          for (final i in items.skip(band + 2))
            if (i is ScheduleSectionRow) i.cells.first,
        ],
        ['item 0', 'item 1'],
      );
      expect((items.last as ScheduleNote).text, 'two counted');
    });

    test('A PAGE THAT OPENS INSIDE A SECTION heads its columns with the '
        "section's, and re-prints the band (cont.)", () {
      // Enough rows to run well past one A page (about 38 rows).
      final pages = _paginate(_starter('apartment'), [_section(120)]);
      final opensInside = pages.where((p) => p.header != null).toList();
      expect(opensInside, isNotEmpty, reason: 'the premise: it broke');
      for (final page in opensInside) {
        expect(page.header, _cols);
        final first = page.items.first as ScheduleBand;
        expect(first.text, 'TEST SECTION (cont.)');
        // The header row already shows the columns: no second one inline.
        expect(page.items.whereType<ScheduleColumns>(), isEmpty);
      }
      // Every row is laid out exactly once, across the break.
      expect(
        pages.expand((p) => p.items).whereType<ScheduleSectionRow>().length,
        120,
      );
      // And the equipment pages before it keep the equipment grid.
      expect(pages.first.header, isNull);
    });

    test('A BAND IS NEVER STRANDED: no page ends on a band or a header row, '
        'and (cont.) only follows rows of its own table', () {
      // A SWEEP, because the defect lived at one exact fill: Whole House's
      // `OUTLET MAP` band landed alone at a page foot. Every section size up
      // to past two pages walks the break through every position.
      for (var rows = 1; rows <= 90; rows++) {
        final pages = _paginate(_starter('whole_house'), [
          _section(rows, notes: ['note']),
          _section(3),
        ]);
        for (final (n, page) in pages.indexed) {
          final last = page.items.last;
          expect(
            last is ScheduleBand || last is ScheduleColumns,
            isFalse,
            reason: '$rows rows: page ${n + 1} ends on $last',
          );
          final first = page.items.first;
          if (first is ScheduleBand && first.continued) {
            final previous = pages[n - 1].items.last;
            expect(
              previous is ScheduleBand || previous is ScheduleColumns,
              isFalse,
              reason: '$rows rows: page ${n + 1} continues nothing',
            );
          }
        }
      }
    });

    test('a section with no rows says so in words', () {
      final items = _paginate(_starter('apartment'), [
        _section(0),
      ]).expand((p) => p.items).toList();
      expect(
        items.whereType<ScheduleNote>().map((n) => n.text),
        contains('NOTHING HERE.'),
      );
    });

    test('with no equipment, the list says so before the sections', () {
      final empty = RackDocument(
        id: const Uuid('empty'),
        appVersion: 'test',
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        meta: EntityMeta(
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          updatedBy: 'test',
        ),
      );
      final items = _paginate(empty, [_section(1)]).single.items;
      expect((items.first as ScheduleNote).text, kNoEquipmentText);
    });
  });

  group('AC-024 footage by media (F2)', () {
    test("WHOLE HOUSE: one row per media line, the derivation's numbers, "
        'and the waste factor in the heading', () {
      final doc = _starter('whole_house');
      final footage = buildCableFootage(doc);
      final section = footageSection(footage, doc.settings.displayUnits);
      expect(footage.lines, isNotEmpty, reason: 'the premise: home runs');
      expect(section.rows, hasLength(footage.lines.length));
      expect(
        section.columns.last.heading,
        'WITH WASTE (+${percentOf(doc.settings.cableWasteFactor)})',
      );
      for (final (i, line) in footage.lines.indexed) {
        final row = section.rows[i];
        expect(row[0], line.media?.displayName ?? line.mediaId.v);
        expect(row[1], '${line.runCount}');
        expect(row[4], footageText(line.footage.value, UnitSystem.imperial));
        expect(row[5], footageText(line.withWaste, UnitSystem.imperial));
      }
    });

    test('an unknown footage prints the dash, never 0 (G4)', () {
      expect(footageText(null, UnitSystem.imperial), '— ft');
      expect(footageText(null, UnitSystem.metric), '— m');
      expect(footageText(const Len(0), UnitSystem.imperial), '0 ft');
    });

    test('a waste factor prints as a person writes it', () {
      expect(percentOf(const Permille(100)), '10%');
      expect(percentOf(const Permille(125)), '12.5%');
      expect(percentOf(const Permille(0)), '0%');
    });

    test('no field cable says so', () {
      final doc = _starter('apartment');
      final section = footageSection(
        buildCableFootage(doc),
        doc.settings.displayUnits,
      );
      expect(section.rows, isEmpty);
      expect(section.empty, kNoFootageText);
    });
  });

  group('hardware implied by the rules (F3, AC-028, CR-030)', () {
    test('WHOLE HOUSE: one rear-support line per RCK-013 finding, naming '
        'the device and its rack', () {
      final doc = _starter('whole_house');
      final findings = evaluateDocument(doc);
      final heavy = findings.where((f) => f.ruleId == 'RCK-013').toList();
      expect(heavy, isNotEmpty, reason: 'the premise');
      final section = hardwareSection(
        doc,
        buildExceptionsReport(doc, findings),
      );
      expect(section.rows, hasLength(heavy.length));
      for (final f in heavy) {
        final device = doc.devices[f.primaryEntityId]!.designator;
        expect(
          section.rows.where(
            (r) => r[1] == 'Rear rail support' && r[2] == device,
          ),
          hasLength(1),
          reason: device,
        );
      }
    });

    test(
      'AN ACKNOWLEDGED SUPPORT STILL PRINTS, with the reason (§11.218.3)',
      () {
        final doc = _starter('whole_house');
        final f = evaluateDocument(
          doc,
        ).firstWhere((f) => f.ruleId == 'RCK-013');
        final at = DateTime.utc(2026, 10);
        doc.ackedFindings[const Uuid('ack-heavy')] = AckedFinding(
          id: const Uuid('ack-heavy'),
          ruleId: 'RCK-013',
          targetFingerprint: f.targetFingerprint,
          reason: 'Rear rails ordered with the rack.',
          by: 'riley',
          at: at,
          demotedTo: Severity.advisory,
          meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
        );
        final section = hardwareSection(
          doc,
          buildExceptionsReport(doc, evaluateDocument(doc)),
        );
        final device = doc.devices[f.primaryEntityId]!.designator;
        final row = section.rows.singleWhere((r) => r[2] == device);
        expect(row[5], 'Acknowledged: Rear rails ordered with the rack.');
      },
    );

    test('A HALF-RACK DEVICE ALONE implies an ear kit, through RCK-014', () {
      final doc = _starter('apartment');
      final rack = doc.racks.values.first;
      final at = DateTime.utc(2026, 10);
      final template = doc.templates.values.first;
      doc.devices[const Uuid('half-1')] = DeviceInstance(
        id: const Uuid('half-1'),
        kind: DeviceKind.rackDevice,
        templateRef: TemplateRef(
          templateId: template.templateId,
          version: template.version,
          contentHash: template.contentHash,
        ),
        designator: 'HALF-1',
        name: 'Half-rack unit',
        placement: RailPlacement(
          rackId: rack.id,
          ruIndex: rack.heightU,
          face: Face.front,
          spanTwelfths: 6,
        ),
        meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
      );
      final findings = evaluateDocument(doc);
      expect(
        findings.where((f) => f.ruleId == 'RCK-014'),
        hasLength(1),
        reason: 'the premise: the top U is free on the apartment rack',
      );
      final section = hardwareSection(
        doc,
        buildExceptionsReport(doc, findings),
      );
      expect(
        section.rows.where(
          (r) => r[1] == 'Ear kit (half-rack)' && r[2] == 'HALF-1',
        ),
        hasLength(1),
      );
    });

    test('nothing implied says so', () {
      final doc = _starter('whole_house');
      final section = hardwareSection(
        doc,
        const ExceptionsReport(
          projectWide: [],
          open: [],
          acknowledged: [],
          stale: [],
        ),
      );
      expect(section.rows, isEmpty);
      expect(section.empty, kNoHardwareText);
    });
  });
}
