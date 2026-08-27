// T6.30's layout and §3.7's explicit pagination.
//
// The end-to-end "every designator reaches ink" claim is
// `rackpal_export/test/starters_export_test.dart`. This file is about the
// two things that would make that claim quietly false: a row lost at a page
// break, and a page count that disagrees with the sheet set.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

const Uuid _rackId = Uuid('rack-1');

DBox _drawingArea() => SheetLayout.resolve(
  geometry: const SheetGeometry(SheetSize.ansiALandscape),
  revisionRowCount: 1,
).drawingArea;

DeviceInstance _device({
  required String id,
  required int ru,
  String? notes,
  String template = 'T1',
}) => DeviceInstance(
  id: Uuid(id),
  kind: DeviceKind.rackDevice,
  templateRef: TemplateRef(
    templateId: TemplateId(template),
    version: 1,
    contentHash: 'h',
  ),
  designator: id.toUpperCase(),
  name: 'NAME',
  placement: RailPlacement(rackId: _rackId, ruIndex: ru, face: Face.front),
  meta: testMeta(),
  notes: notes,
);

RackDocument _doc({
  required int deviceCount,
  int racks = 1,
  String? notes,
  int heightU = 60,
}) {
  final rackList = <Rack>[
    for (var i = 0; i < racks; i++)
      Rack(
        id: i == 0 ? _rackId : Uuid('rack-extra-$i'),
        name: 'R$i',
        designator: 'RK-${i + 1}',
        heightU: heightU,
        order: FracIndex('a$i'),
        meta: testMeta(),
      ),
  ];
  return RackDocument(
    id: const Uuid('doc'),
    appVersion: 'test',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: testMeta(),
    racks: <Uuid, Rack>{for (final r in rackList) r.id: r},
    devices: <Uuid, DeviceInstance>{
      for (var i = 0; i < deviceCount; i++)
        Uuid('d${i.toString().padLeft(3, '0')}'): _device(
          id: 'd${i.toString().padLeft(3, '0')}',
          ru: (i % heightU) + 1,
          notes: notes,
        ),
    },
    templates: <String, TemplateSnapshot>{
      'T1@1': TemplateSnapshot(
        templateId: const TemplateId('T1'),
        version: 1,
        contentHash: 'h',
        body: TemplateBody(
          manufacturer: 'ACME',
          model: 'MDL',
          displayName: 'Widget',
          frontU: 1,
          weight: const Mass(1_000_000_000),
          power: PowerProfile(apparentVA: 50),
        ),
        capturedAt: DateTime.utc(2026),
      ),
    },
  );
}

List<SchedulePage> _paginate(RackDocument doc) => paginateEquipmentList(
  list: buildEquipmentList(doc),
  drawingArea: _drawingArea(),
  measurer: FakeMeasurer(),
);

void main() {
  group('columns', () {
    test('the thirteen columns sum to the ANSI A usable width', () {
      // 690 pt is the ANSI A landscape frame width — derived here rather
      // than restated, so a margin change fails this rather than silently
      // notching the table.
      final total = EquipmentColumn.values.fold<double>(
        0,
        (sum, c) => sum + c.width,
      );
      expect(total, closeTo(_drawingArea().width, 1e-9));
    });

    test('the columns §2.2 names are all present, in its order', () {
      expect(
        EquipmentColumn.values.map((c) => c.heading).toList(),
        <String>[
          'QTY',
          'DESIGNATOR',
          'MANUFACTURER',
          'MODEL',
          'DESCRIPTION',
          'RU',
          'RACK',
          'LOCATION',
          'FACE',
          'MASS',
          'DRAW',
          'LIFECYCLE',
          'NOTES',
        ],
      );
    });

    test('no PRICING column exists (AC-055)', () {
      for (final column in EquipmentColumn.values) {
        expect(
          <String>['COST', 'PRICE', 'SUPPLIER', 'PO', 'TOTAL'],
          isNot(contains(column.heading)),
        );
      }
    });

    test('MASS and DRAW headings CARRY THEIR UNIT', () {
      // ==============================================================
      // A BARE NUMBER WHOSE UNIT IS A PROJECT SETTING IS NOT A NUMBER.
      // ==============================================================
      // `UPS-1` printed `91.9` under a heading that said only `MASS`.
      // Flip `ProjectSettings.displayUnits` and the identical cell reads
      // `41.7` — the same device, two figures 2.2x apart, with nothing
      // else on the sheet different. The only place lb/kg used to appear
      // was the group subtotal band, which on a continuation page sits a
      // dozen rows below the header; the header repeats on every page.
      expect(
        EquipmentColumn.mass.headingIn(UnitSystem.imperial),
        'MASS (LB)',
      );
      expect(EquipmentColumn.mass.headingIn(UnitSystem.metric), 'MASS (KG)');
      // VA is not a project setting, but a bare number under `DRAW` is
      // just as unreadable — an integrator sizes a circuit off it.
      expect(EquipmentColumn.draw.headingIn(UnitSystem.imperial), 'DRAW (VA)');
      expect(EquipmentColumn.draw.headingIn(UnitSystem.metric), 'DRAW (VA)');
    });

    test('every OTHER heading is unit-free in both systems', () {
      for (final column in EquipmentColumn.values) {
        if (column == EquipmentColumn.mass || column == EquipmentColumn.draw) {
          continue;
        }
        for (final units in UnitSystem.values) {
          expect(column.headingIn(units), column.heading, reason: column.name);
        }
      }
    });
  });

  group('pagination (§3.7)', () {
    test('a short list is ONE page, and holds every row', () {
      final doc = _doc(deviceCount: 8);
      final pages = _paginate(doc);

      expect(pages, hasLength(1));
      expect(pages.single.rows, hasLength(8));
    });

    test('NO ROW IS LOST across a page break', () {
      // The failure mode this whole group exists for: rows built, then
      // dropped by the loop that cuts pages.
      final doc = _doc(deviceCount: 200);
      final pages = _paginate(doc);

      expect(pages.length, greaterThan(1));
      final paginated = pages.expand((p) => p.rows).length;
      expect(paginated, doc.devices.length);
    });

    test('every page fits its body area', () {
      final pages = _paginate(_doc(deviceCount: 200));
      final bodyHeight = scheduleBodyArea(_drawingArea()).height;

      for (var i = 0; i < pages.length; i++) {
        final used = pages[i].items.fold<double>(0, (h, it) => h + it.height);
        expect(used, lessThanOrEqualTo(bodyHeight), reason: 'page ${i + 1}');
      }
    });

    test('...and every page except the last is FULL', () {
      // ==============================================================
      // ADDED BECAUSE A MUTATION SURVIVED.
      // ==============================================================
      // Shrinking the page budget by one row height — an early break —
      // passed the whole suite: no row is lost (they move to the next
      // page), and every page still fits. "Fits" and "loses nothing" are
      // both true of a paginator that puts one row per page.
      //
      // The missing property is that a break happens only when the NEXT
      // item genuinely does not fit. Asserted as: every page but the last
      // has less than one more item's worth of room left.
      final pages = _paginate(_doc(deviceCount: 200));
      final bodyHeight = scheduleBodyArea(_drawingArea()).height;
      expect(pages.length, greaterThan(2), reason: 'nothing to check');

      for (var i = 0; i < pages.length - 1; i++) {
        final used = pages[i].items.fold<double>(0, (h, it) => h + it.height);
        final nextItem = pages[i + 1].items
            .where((it) => it is! ScheduleBand || !it.continued)
            .first;
        expect(
          used + nextItem.height,
          greaterThan(bodyHeight),
          reason:
              'page ${i + 1} broke early: $used pt used of $bodyHeight, and '
              'the next item is only ${nextItem.height} pt',
        );
      }
    });

    test('a group interrupted by a break is RE-EMITTED with a cont. mark', () {
      final pages = _paginate(_doc(deviceCount: 200));

      final second = pages[1].items.first;
      expect(second, isA<ScheduleBand>());
      expect((second as ScheduleBand).continued, isTrue);
      expect(second.text, endsWith(kContinuationSuffix));
      // ...and it names the SAME group.
      expect(second.title, (pages.first.items.first as ScheduleBand).title);
    });

    test('a page that opens on a NEW group does not also carry the '
        'previous continuation', () {
      final pages = _paginate(_doc(deviceCount: 200, racks: 3));

      for (final page in pages) {
        final bands = page.items.whereType<ScheduleBand>().toList();
        if (bands.length < 2) continue;
        // A continuation band is only ever the FIRST item on a page.
        for (var i = 1; i < bands.length; i++) {
          expect(bands[i].continued, isFalse);
        }
      }
    });

    test('pagination is DETERMINISTIC — the sheet set depends on it', () {
      // "SHEET i OF n" is resolved from this count before any page is
      // rendered. Two runs producing different counts would make the
      // printed total a coin flip.
      final doc = _doc(deviceCount: 200);
      expect(_paginate(doc).length, _paginate(doc).length);
      expect(
        _paginate(doc).map((p) => p.items.length).toList(),
        _paginate(doc).map((p) => p.items.length).toList(),
      );
    });

    test('an EMPTY project still produces one page', () {
      // A sheet that says the list is empty is a deliverable; a missing
      // sheet is a hole in the set.
      final pages = paginateEquipmentList(
        list: const EquipmentList(groups: <EquipmentGroup>[], unplacedCount: 0),
        drawingArea: _drawingArea(),
        measurer: FakeMeasurer(),
      );

      expect(pages, hasLength(1));
      expect(pages.single.items, isEmpty);
    });

    test('long notes cost a second line and the row grows to match', () {
      final short = _paginate(_doc(deviceCount: 4));
      final long = _paginate(
        _doc(
          deviceCount: 4,
          notes: 'a note long enough to need two measured lines on paper',
        ),
      );

      final shortRow = short.single.rows.first;
      final longRow = long.single.rows.first;

      expect(shortRow.noteLines, isEmpty);
      expect(longRow.noteLines.length, greaterThan(1));
      expect(longRow.height, greaterThan(shortRow.height));
      // ...and NEVER more than the cap (§3.7).
      expect(longRow.noteLines.length, lessThanOrEqualTo(kMaxNoteLines));
    });
  });

  group('the sheet set is resolved from the real page count', () {
    test('SHEET i OF n counts schedule pages, not one schedule', () {
      final doc = _doc(deviceCount: 200, racks: 2);
      final pages = _paginate(doc);
      final set = SheetSet.forRacks(
        doc.racks.values,
        equipmentListSheets: pages.length,
      );

      expect(pages.length, greaterThan(1));
      expect(set.sheets, hasLength(2 * 2 + pages.length));
      for (final sheet in set.sheets) {
        expect(sheet.total, set.sheets.length);
      }
      // Indexes are 1..n with no gaps and no repeats.
      expect(
        set.sheets.map((s) => s.index).toList(),
        List<int>.generate(set.sheets.length, (i) => i + 1),
      );
    });

    test('continuation sheets take T6.31, T6.32 — still valid NCS ids', () {
      final set = SheetSet.forRacks(<Rack>[testRack()], equipmentListSheets: 3);
      final schedule = set.sheets
          .where((s) => s.role == SheetRole.equipmentList)
          .map((s) => s.ncsId)
          .toList();

      expect(schedule, <String>['T6.30', 'T6.31', 'T6.32']);
      for (final id in schedule) {
        expect(isValidNcsId(id), isTrue, reason: id);
      }
      expect(set.notices, isEmpty);
    });

    test('one rack and one schedule page is still the three-sheet set', () {
      final set = SheetSet.forRacks(<Rack>[testRack()]);
      expect(
        set.sheets.map((s) => s.ncsId).toList(),
        <String>['T2.01', 'T2.02', 'T6.30'],
      );
    });
  });

  group('what the sheet draws', () {
    EquipmentSheet build({
      int deviceCount = 6,
      int pageIndex = 0,
      UnitSystem units = UnitSystem.imperial,
    }) {
      final doc = _doc(deviceCount: deviceCount);
      final list = buildEquipmentList(doc);
      final pages = paginateEquipmentList(
        list: list,
        drawingArea: _drawingArea(),
        measurer: FakeMeasurer(),
        units: units,
      );
      final set = SheetSet.forRacks(
        doc.racks.values,
        equipmentListSheets: pages.length,
      );
      return buildEquipmentSheet(
        sheet: set.sheets
            .where((s) => s.role == SheetRole.equipmentList)
            .elementAt(pageIndex),
        page: pages[pageIndex],
        list: list,
        info: fullProjectInfo(),
        settings: ProjectSettings(displayUnits: units),
        revisions: const <RevisionEntry>[],
        fileName: 'smith.rmpj',
        issuedAt: DateTime.utc(2026, 7, 18),
        measurer: FakeMeasurer(),
      );
    }

    List<String> texts(EquipmentSheet s) =>
        s.scene.ops.whereType<OpText>().map((o) => o.text).toList();

    test('the unit reaches INK, whole, on every page', () {
      // The header is measured and truncated like every other cell, so
      // "the heading carries a unit" is only true if the unit survives
      // `fitTextToWidth` into a 46 pt column.
      for (final page in <int>[0, 1]) {
        final drawn = texts(build(deviceCount: 200, pageIndex: page));
        expect(drawn, contains('MASS (LB)'), reason: 'page ${page + 1}');
        expect(drawn, contains('DRAW (VA)'), reason: 'page ${page + 1}');
      }
    });

    test('...and follows ProjectSettings.displayUnits (CR-097)', () {
      final metric = texts(build(units: UnitSystem.metric));
      expect(metric, contains('MASS (KG)'));
      expect(metric, isNot(contains('MASS (LB)')));
    });

    test('an absent MANUFACTURER, MODEL and FACE are never BLANK cells', () {
      // `STR-1` in every starter: no template snapshot by spec (docs/07
      // §2), off-rack, so three of its cells have nothing to say. They
      // printed EMPTY beside three em dashes on the same row, and an
      // empty cell reads as "nobody filled this in" (`text_fit.dart`).
      final doc = RackDocument(
        id: const Uuid('doc'),
        appVersion: 'test',
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        meta: testMeta(),
        racks: <Uuid, Rack>{},
        devices: <Uuid, DeviceInstance>{
          const Uuid('str'): DeviceInstance(
            id: const Uuid('str'),
            kind: DeviceKind.structure,
            templateRef: const TemplateRef(
              templateId: TemplateId('structure'),
              version: 1,
              contentHash: 'sha256:structure-no-template',
            ),
            designator: 'STR-1',
            name: 'Rough-In — First Floor',
            placement: const OffRackPlacement(),
            meta: testMeta(),
          ),
        },
      );
      final list = buildEquipmentList(doc);
      final pages = paginateEquipmentList(
        list: list,
        drawingArea: _drawingArea(),
        measurer: FakeMeasurer(),
      );
      final row = pages.single.rows.single;

      expect(row.cells[EquipmentColumn.manufacturer.index], kUnknownCell);
      expect(row.cells[EquipmentColumn.model.index], kUnknownCell);
      expect(row.cells[EquipmentColumn.face.index], 'NONE');
      // No cell on this row is blank — every one of them says something.
      for (var i = 0; i < EquipmentColumn.values.length; i++) {
        if (EquipmentColumn.values[i] == EquipmentColumn.notes) continue;
        expect(
          row.cells[i],
          isNotEmpty,
          reason: EquipmentColumn.values[i].name,
        );
      }
    });

    test('a MASS cell is never a bare number under a bare heading', () {
      // The joint property, stated as one assertion: for every unit
      // system, either the cell says the unit or the header does.
      for (final units in UnitSystem.values) {
        final drawn = texts(build(units: units));
        final headings = drawn.where((t) => t.startsWith('MASS'));
        expect(headings, isNotEmpty, reason: '$units');
        for (final heading in headings) {
          expect(heading, isNot('MASS'), reason: '$units');
        }
      }
    });

    test('the header row is on EVERY page', () {
      final many = build(deviceCount: 200, pageIndex: 1);
      expect(texts(many), contains('DESIGNATOR'));
      expect(texts(many), contains('LIFECYCLE'));
    });

    test('the scope note is on EVERY page (the omitted §2.2 sections)', () {
      for (final index in <int>[0, 1]) {
        expect(
          texts(build(deviceCount: 200, pageIndex: index)).join(' '),
          contains('CABLE AND POWER SCHEDULES NOT ISSUED'),
          reason: 'page ${index + 1}',
        );
      }
    });

    test('the SCALE field says NTS — a table is not a scaled drawing', () {
      // `1:1` would invite exactly the scaling-off §5.2 forbids. On the
      // ANSI A compact strip the field grid collapses into one run, so the
      // assertion is over the joined text rather than a single element.
      expect(texts(build()).join(' '), contains('SCALE NTS'));
      expect(texts(build()).join(' '), isNot(contains('1:')));
    });

    test('every device on the page reaches an OpText', () {
      final joined = texts(build()).join('\n');
      for (var i = 0; i < 6; i++) {
        expect(joined, contains('D${i.toString().padLeft(3, '0')}'));
      }
    });

    test('the subtotal band names the rack', () {
      expect(texts(build()).join('\n'), contains('RK-1 SUBTOTAL'));
    });

    // ================================================================
    // THE SUBTOTAL'S DEVICE COUNT IS THE NUMBER THE TWO SHEET TYPES
    // JOIN ON, AND IT HAD NO TEST AT ANY LEVEL
    // ================================================================
    // Mutating `_subtotalText`'s `group.rows.length` to `+ 1` survived
    // `dart test` in both packages: `starters_export_test` compares the
    // subtotal's MASS and VA against `computeRackRollups` and never its
    // device count, and the assertion above reads the LABEL. T6.30 would
    // then say "RK-1 SUBTOTAL 6 DEVICES" while both elevations printed
    // "5 OF 5" — two sheets of one set disagreeing about the contents of
    // a rack, which is what `RackLoadProfile.contributingCount`'s doc
    // says the shared denominator exists to prevent.
    test('the subtotal states HOW MANY devices, and it is the same '
        'denominator the elevations print', () {
      for (final count in <int>[1, 6, 17]) {
        final doc = _doc(deviceCount: count);
        final subtotal = texts(
          build(deviceCount: count),
        ).singleWhere((t) => t.contains('SUBTOTAL'));

        final stated = int.parse(
          RegExp(r'SUBTOTAL\s+(\d+)\s+DEVICE').firstMatch(subtotal)!.group(1)!,
        );
        expect(stated, count, reason: subtotal);
        // Singular/plural is part of the sentence being true.
        expect(
          subtotal,
          contains(count == 1 ? '1 DEVICE ' : '$count DEVICES'),
          reason: subtotal,
        );

        // ...and it is the SAME number the elevation's omission sentence
        // divides by. A test that only checked `group.rows.length`
        // against itself would be self-referential; this crosses to the
        // other sheet's arithmetic.
        expect(
          computeRackLoadProfile(
            rack: doc.racks[_rackId]!,
            devices: doc.devices.values,
            templates: doc.templates,
          ).contributingCount,
          stated,
          reason: 'T6.30 and T2.0x must agree on how many devices RK-1 has',
        );
      }
    });

    test("the subtotal's DRAW carries its own unknown count, not the "
        'mass one', () {
      // ==============================================================
      // THE VA SUFFIX, SPECIFICALLY.
      // ==============================================================
      // Every `(n unknown)` assertion in this repository reads a MASS
      // rollup, so replacing `formatIntRollup`'s suffix expression with
      // `''` left both suites green while T6.30's DRAW subtotal — and
      // both elevations' DRAW line — silently stopped saying how many
      // contributors were missing. This fixture makes the two counts
      // DIFFERENT (mass 0 unknown, VA 1 unknown), so a mutation cannot be
      // covered by the mass figure beside it.
      TemplateSnapshot snap(String id, {int? va}) => TemplateSnapshot(
        templateId: TemplateId(id),
        version: 1,
        contentHash: 'h',
        body: TemplateBody(
          manufacturer: 'ACME',
          model: 'MDL',
          displayName: 'Widget',
          frontU: 1,
          weight: const Mass(1_000_000_000),
          power: PowerProfile(apparentVA: va),
        ),
        capturedAt: DateTime.utc(2026),
      );
      final doc = RackDocument(
        id: const Uuid('doc'),
        appVersion: 'test',
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        meta: testMeta(),
        racks: <Uuid, Rack>{_rackId: testRack(id: _rackId.v)},
        devices: <Uuid, DeviceInstance>{
          const Uuid('withva'): _device(id: 'withva', ru: 1),
          const Uuid('nova'): _device(id: 'nova', ru: 3, template: 'T2'),
        },
        templates: <String, TemplateSnapshot>{
          'T1@1': snap('T1', va: 50),
          'T2@1': snap('T2'),
        },
      );

      final list = buildEquipmentList(doc);
      final group = list.groups.singleWhere((g) => g.rackId == _rackId);
      // The fixture is only discriminating while these differ.
      expect(group.mass.unknownCount, 0);
      expect(group.apparentVA.unknownCount, 1);

      final pages = paginateEquipmentList(
        list: list,
        drawingArea: _drawingArea(),
        measurer: FakeMeasurer(),
      );
      final sheet = buildEquipmentSheet(
        sheet: SheetSet.forRacks(
          doc.racks.values,
          equipmentListSheets: pages.length,
        ).sheets.firstWhere((s) => s.role == SheetRole.equipmentList),
        page: pages.first,
        list: list,
        info: fullProjectInfo(),
        settings: ProjectSettings(),
        revisions: const <RevisionEntry>[],
        fileName: 'smith.rmpj',
        issuedAt: DateTime.utc(2026, 7, 18),
        measurer: FakeMeasurer(),
      );
      final subtotal = texts(sheet).singleWhere((t) => t.contains('SUBTOTAL'));

      expect(subtotal, contains('(1 unknown)'), reason: subtotal);
      expect(subtotal, contains('≥ 50 VA'), reason: subtotal);
      // The mass half is complete, so it prints a bare figure — which is
      // what makes the suffix above unambiguously the VA rollup's.
      expect(subtotal, contains('4.4 lb'), reason: subtotal);
      expect('(1 unknown)'.allMatches(subtotal), hasLength(1));
    });

    test('an UNKNOWN cell prints an em dash ON THE SHEET, never a 0', () {
      // G4, at the last place it can be broken: the model can carry a null
      // correctly and the cell can still render `0`. A mutation that
      // substituted zero in the DRAW column survived every model-level
      // assertion in this suite.
      final doc = RackDocument(
        id: const Uuid('doc'),
        appVersion: 'test',
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        meta: testMeta(),
        racks: <Uuid, Rack>{_rackId: testRack(id: _rackId.v)},
        devices: <Uuid, DeviceInstance>{
          const Uuid('d'): _device(id: 'd', ru: 1),
        },
        // A template with NO weight and NO apparentVA: both cells unknown.
        templates: <String, TemplateSnapshot>{
          'T1@1': TemplateSnapshot(
            templateId: const TemplateId('T1'),
            version: 1,
            contentHash: 'h',
            body: TemplateBody(
              manufacturer: 'ACME',
              model: 'MDL',
              displayName: 'Widget',
              frontU: 1,
            ),
            capturedAt: DateTime.utc(2026),
          ),
        },
      );
      final list = buildEquipmentList(doc);
      final pages = paginateEquipmentList(
        list: list,
        drawingArea: _drawingArea(),
        measurer: FakeMeasurer(),
      );
      final sheet = buildEquipmentSheet(
        sheet: SheetSet.forRacks(doc.racks.values).sheets.last,
        page: pages.single,
        list: list,
        info: fullProjectInfo(),
        settings: ProjectSettings(),
        revisions: const <RevisionEntry>[],
        fileName: 'f.rmpj',
        issuedAt: DateTime.utc(2026, 7, 18),
        measurer: FakeMeasurer(),
      );

      final row = pages.single.rows.single;
      final draw = row.cells[EquipmentColumn.draw.index];
      final mass = row.cells[EquipmentColumn.mass.index];

      expect(draw, kUnknownCell, reason: 'DRAW cell');
      expect(mass, kUnknownCell, reason: 'MASS cell');
      // ...and that em dash is what reaches an OpText.
      expect(texts(sheet), contains(kUnknownCell));
      // The subtotal states the count rather than a bare figure.
      expect(texts(sheet).join('\n'), contains('(1 unknown)'));
    });

    test('no empty text op ever reaches the scene', () {
      for (final op in build().scene.ops.whereType<OpText>()) {
        expect(op.text, isNotEmpty);
      }
    });

    test('an EMPTY project says so rather than drawing a blank grid', () {
      const list = EquipmentList(
        groups: <EquipmentGroup>[],
        unplacedCount: 0,
      );
      final sheet = buildEquipmentSheet(
        sheet: SheetSet.forRacks(<Rack>[testRack()]).sheets.last,
        page: const SchedulePage(<ScheduleItem>[]),
        list: list,
        info: fullProjectInfo(),
        settings: ProjectSettings(),
        revisions: const <RevisionEntry>[],
        fileName: 'f.rmpj',
        issuedAt: DateTime.utc(2026, 7, 18),
        measurer: FakeMeasurer(),
      );

      expect(texts(sheet), contains('NO EQUIPMENT IN THIS PROJECT.'));
    });

    test('the sheet clears the §6.2 hard floor', () {
      expect(build().legibility.meetsHardFloor, isTrue);
    });
  });

  group('wrapMeasured', () {
    final measurer = FakeMeasurer();
    const style = TextStyleSpec(
      font: kSheetFont,
      sizePt: 10,
      argb: 0xFF000000,
      anchor: TextAnchor.midLeft,
    );

    test('short text is one line, unchanged', () {
      expect(
        wrapMeasured('ab', 1000, style: style, measurer: measurer, maxLines: 2),
        <String>['ab'],
      );
    });

    test('empty text produces NO lines, not one empty one', () {
      // An empty `OpText` is what `title_block_test.dart` forbids, and the
      // same rule applies here.
      expect(
        wrapMeasured('   ', 100, style: style, measurer: measurer, maxLines: 2),
        isEmpty,
      );
    });

    test('it never exceeds maxLines', () {
      final lines = wrapMeasured(
        List<String>.filled(60, 'word').join(' '),
        60,
        style: style,
        measurer: measurer,
        maxLines: 2,
      );
      expect(lines.length, lessThanOrEqualTo(2));
    });

    test('a single word longer than the cell is TRUNCATED, not spilled', () {
      // `PdfGraphics.drawString` neither wraps nor clips, so an unmeasured
      // long token runs across the next column and off the sheet.
      final lines = wrapMeasured(
        'RK1-HDMI-OUT-07-TO-DISPLAY-MSTR-BEDROOM-LONG',
        40,
        style: style,
        measurer: measurer,
        maxLines: 2,
      );

      expect(lines, isNotEmpty);
      for (final line in lines) {
        expect(
          measurer.measureText(line, style).advanceWidth,
          lessThanOrEqualTo(40 + 1e-9),
          reason: line,
        );
      }
    });
  });
}
