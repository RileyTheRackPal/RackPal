// M4's exit criterion, clause 2, as an assertion rather than a promise.
// Board `#251`. `docs/17-m4q2-drill.md` §4 is the script a person follows.
//
// =====================================================================
// WHY A DRILL SCRIPT NEEDS A TEST BEHIND IT
// =====================================================================
// `docs/17` tells a person to author a template, place it, export a PDF
// and check thirteen columns against a table. That table was measured on
// 2026-08-19 and the drill had not been run by 2026-08-29, by which time
// **two of its steps were wrong**:
//
//  * §2 step 4 said to type `4x HDMI in`. Quick Add refuses it: quantity
//    is the one positional token and `int.tryParse('4x')` is null, so the
//    grammar is `4 hdmi in`. A person following the script would have hit
//    a refusal at the first typed line.
//  * §4's table said `NOTES` prints `—`. It prints NOTHING, and that is
//    deliberate: `_scheduleRow` builds every other nullable cell with
//    `?? kUnknownCell` and builds this one with `?? ''`. A note's absence
//    means no note was written, which is known; a dash there would claim
//    we do not know whether a note exists.
//
// Both would have cost the operator their run, and the second would have
// been recorded as a REFUTATION of correct behaviour, which is worse than
// a wasted afternoon: it is a false finding entering the record.
//
// So the expectation table lives here as well as in prose, and the prose
// now says so. A drill script nothing checks is a document that rots at
// exactly the speed of the product.
//
// THIS DOES NOT DISCHARGE CLAUSE 2 AND MUST NOT BE READ AS DOING SO. The
// clause asks whether a template a PERSON authored in the builder reaches
// a rack and prints correctly. This drives the same commands from core and
// cannot see the builder, the palette, the export dialog or the PDF. It
// makes the human drill worth running; it does not replace it. M1's clause
// 3 is the precedent: 2,206 tests were green over two defects the drill
// found in one run.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

const _rackId = Uuid('rk-1');
final _now = DateTime.utc(2026, 8, 29);

DBox _drawingArea() => SheetLayout.resolve(
  geometry: const SheetGeometry(SheetSize.ansiALandscape),
  revisionRowCount: 1,
).drawingArea;

/// The drill's own sequence: File > New, author three fields plus ports,
/// save, place.
({RackDocument doc, int ports}) _runDrill({String quickAdd = '4 hdmi in'}) {
  final doc =
      RackDocument(
          id: const Uuid('drill'),
          appVersion: '0.0.0',
          createdAt: _now,
          modifiedAt: _now,
          meta: testMeta(),
        )
        ..registries = buildSeedRegistries()
        ..racks[_rackId] = Rack(
          id: _rackId,
          name: 'Rack 1',
          designator: 'RK-1',
          heightU: 42,
          order: const FracIndex('a0'),
          meta: testMeta(),
        );

  // EXACTLY THE THREE FIELDS `[Save]` REQUIRES (DR-077 §11.76.1): a
  // display name, a designator prefix and a meant occupancy. `Generic` is
  // DR-056's pre-fill and not a fourth field the operator typed; `model`
  // stays blank by the same ruling and is one of the unknowns the drill
  // goes looking for.
  final body = TemplateBody(
    manufacturer: 'Generic',
    model: '',
    displayName: 'Drill Matrix 24x24',
    typePrefix: 'DMX',
    frontU: 3,
    side: OccupancySide.front,
    mountMethod: MountMethod.rackEars,
  );

  final parsed = parseQuickAdd(doc.registries, quickAdd);
  if (parsed is QuickAddPlan) {
    for (final c in buildQuickAdd(doc.registries, body, parsed)) {
      c.apply(body);
    }
  }

  SaveTemplateToProjectCommand(
    templateId: const TemplateId('drill_matrix_24x24'),
    version: 1,
    contentHash: 'unhashed:drill_matrix_24x24@1',
    body: copyTemplateBody(body),
    capturedAt: _now,
  ).apply(doc);

  final placed = buildPlaceFromCatalogCommand(
    doc: doc,
    catalogId: 'drill_matrix_24x24',
    targetRack: doc.racks[_rackId]!,
    now: _now,
    actor: 'drill',
  );
  if (placed is CatalogPlacementReady) placed.command.apply(doc);
  return (doc: doc, ports: body.ports.length);
}

List<String> _sheetTexts(RackDocument doc) {
  final list = buildEquipmentList(doc);
  final pages = paginateEquipmentList(
    list: list,
    drawingArea: _drawingArea(),
    measurer: FakeMeasurer(),
  );
  final set = SheetSet.forRacks(
    doc.racks.values,
    equipmentListSheets: pages.length,
  );
  return buildEquipmentSheet(
    sheet: set.sheets.firstWhere((s) => s.role == SheetRole.equipmentList),
    page: pages.first,
    list: list,
    info: fullProjectInfo(),
    settings: ProjectSettings(),
    revisions: const <RevisionEntry>[],
    fileName: 'drill.rppj',
    issuedAt: _now,
    measurer: FakeMeasurer(),
  ).scene.ops.whereType<OpText>().map((o) => o.text).toList();
}

void main() {
  group("docs/17 §2, the operator's typed line", () {
    test('`4 hdmi in` is the grammar and makes exactly four ports', () {
      // §2's own sanity check: "if the footer says anything other than 4,
      // stop and record that".
      expect(_runDrill().ports, 4);
    });

    test('`4x hdmi in` is REFUSED, which is what the script used to say', () {
      // Kept as a case rather than deleted with the correction, because a
      // future grammar that accepts `Nx` would make the corrected script
      // wrong in the other direction, and this is the line that would
      // notice.
      final r = parseQuickAdd(buildSeedRegistries(), '4x hdmi in');
      expect(r, isA<QuickAddFailure>());
      expect((r as QuickAddFailure).message, contains('starts with how many'));
    });
  });

  group('docs/17 §3, the template reaches the rack', () {
    test('placement succeeds and allocates DMX-1', () {
      final doc = _runDrill().doc;
      expect(doc.devices.values.single.designator, 'DMX-1');
    });

    test('it lands at U1-U3 on the front face', () {
      final row = buildEquipmentList(_runDrill().doc).rows.single;
      expect(row.ruIndex, 1);
      expect(row.ruSpan, 3);
      expect(row.mounting, EquipmentMounting.front);
    });
  });

  group('docs/17 §4, the thirteen columns as the sheet draws them', () {
    test('every cell of the DMX-1 row, in the sheet order', () {
      final texts = _sheetTexts(_runDrill().doc);
      final start = texts.indexOf('DMX-1');
      expect(start, isNot(-1), reason: 'the row did not reach ink');

      // Read from the DESIGNATOR forward. QTY sits one before it.
      expect(texts[start - 1], '1', reason: 'QTY');
      expect(
        texts.sublist(start),
        <String>[
          'DMX-1', // DESIGNATOR
          'Generic', // MANUFACTURER, DR-056: not a dash
          '—', // MODEL, left blank and therefore unknown
          'Drill Matrix 24x24', // DESCRIPTION
          // RU IS ONE CELL, NOT TWO. The height, a MIDDLE DOT, then the
          // span with an EN DASH. Worth pinning as one string: reading a
          // joined dump of the ops misreads it as two cells, because the
          // separator a reader reaches for is the one the cell contains.
          '3U · 1–3',
          'RK-1', // RACK
          '—', // LOCATION, none set
          'FRONT', // FACE, a fact the model states
          '—', // MASS, left blank
          '—', // DRAW, never `0`
          'NEW', // LIFECYCLE
          // NOTES draws NOTHING and the next op is the subtotal band.
          'RK-1 SUBTOTAL   1 DEVICE   — (1 unknown)   — (1 unknown)',
        ],
      );
    });

    test('NOTES prints nothing, unlike every other empty cell', () {
      // The correction docs/17 needed. `_scheduleRow` builds this one cell
      // with `?? ''` where its neighbours use `?? kUnknownCell`, because a
      // missing note is a known absence and not an unknown value.
      final texts = _sheetTexts(_runDrill().doc);
      final afterLifecycle = texts.indexOf('NEW') + 1;
      expect(
        texts[afterLifecycle],
        startsWith('RK-1 SUBTOTAL'),
        reason:
            'a dash between LIFECYCLE and the subtotal would mean the '
            'notes column had started claiming an unknown',
      );
    });

    test('THE SUBTOTAL BAND, VERBATIM, which is the clause in one line', () {
      // G4 and CR-114 entire: the mass column has no total because there
      // is nothing to total, and it says how many contributors could
      // supply nothing. A `0.0 lb` would be a fabricated measurement and
      // an empty cell would read as "nobody filled this in".
      expect(
        _sheetTexts(_runDrill().doc),
        contains('RK-1 SUBTOTAL   1 DEVICE   — (1 unknown)   — (1 unknown)'),
      );
    });
  });
}
