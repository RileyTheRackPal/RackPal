// DR-235 §11.234.3 and §11.234.4 (`#1001`): T6.30's in-line adapters, and
// the schedule's notes naming them on the cable's own row.
//
// THE CASE THIS FILE EXISTS FOR is `an unstated model is its own line`.
// Folding an adapter nobody named into a stated one with the same
// connectors would print a part number for a box whose contents nobody
// has decided, which is G4's failure in a bill of materials.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 10, 4);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

InlineAdapter _adapter(String from, String to, {String? model}) =>
    InlineAdapter(
      fromConnector: ConnectorTypeId(from),
      toConnector: ConnectorTypeId(to),
      model: model,
      satisfiesRuleIds: ['CON-001'],
    );

/// A document of field cables, wall to wall, one per entry of [cables],
/// each carrying the adapters given.
RackDocument _doc(List<List<InlineAdapter>> cables) {
  final doc = RackDocument(
    id: const Uuid('doc-adapter-rollup'),
    appVersion: 'test',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    registries: buildSeedRegistries(),
  );
  for (final (i, adapters) in cables.indexed) {
    final id = Uuid('lnk-$i');
    doc.links[id] =
        Link(
            id: id,
            designator: 'W00${i + 1}',
            media: const MediaTypeId('media.cat6_utp'),
            order: FracIndex('a$i'),
            meta: _meta(),
            inlineAdapters: adapters,
          )
          ..conductors.add(
            Conductor(
              from: PlaceEndpoint(description: 'wall $i'),
              to: PlaceEndpoint(description: 'shelf $i'),
            ),
          );
  }
  return doc;
}

AdapterRollup _rollup(RackDocument doc) =>
    adapterRollupOf(buildSchedule(doc), doc);

void main() {
  test('no adapter anywhere: an empty table that says so', () {
    final rollup = _rollup(_doc([[], []]));
    expect(rollup.isEmpty, isTrue);
    expect(adapterSection(rollup).rows, isEmpty);
    expect(adapterSection(rollup).empty, kNoAdaptersText);
  });

  test('the same pair and model on two cables is ONE line of two', () {
    final rollup = _rollup(
      _doc([
        [_adapter('conn.xlr3', 'conn.rca', model: 'Hosa XLR3F-RCA')],
        [_adapter('conn.xlr3', 'conn.rca', model: 'Hosa XLR3F-RCA')],
      ]),
    );
    expect(rollup.lines, hasLength(1));
    expect(rollup.lines.single.quantity, 2);
    expect(adapterSection(rollup).rows.single, [
      '2',
      'XLR3 to RCA',
      'Hosa XLR3F-RCA',
    ]);
  });

  test('AN UNSTATED MODEL IS ITS OWN LINE, printed unknown, last, and '
      'counted', () {
    final rollup = _rollup(
      _doc([
        [_adapter('conn.xlr3', 'conn.rca')],
        [_adapter('conn.xlr3', 'conn.rca', model: 'Hosa XLR3F-RCA')],
        [_adapter('conn.xlr3', 'conn.rca')],
      ]),
    );
    final rows = adapterSection(rollup).rows;
    expect(rows, [
      ['1', 'XLR3 to RCA', 'Hosa XLR3F-RCA'],
      ['2', 'XLR3 to RCA', kUnknownCell],
    ]);
    expect(adapterSection(rollup).notes, ['2 adapters have no model stated.']);
  });

  test('ordered by the connectors as printed, not by insertion', () {
    final doc = _doc([
      [_adapter('conn.xlr3', 'conn.rca')],
      [_adapter('conn.euroblock_3', 'conn.xlr3')],
    ]);
    expect(
      [for (final l in _rollup(doc).lines) l.connectors],
      ['Euroblock 3-pole to XLR3', 'XLR3 to RCA'],
    );
  });

  test('two adapters on ONE cable both count', () {
    final rollup = _rollup(
      _doc([
        [
          _adapter('conn.f_type', 'conn.bnc'),
          _adapter('conn.f_type', 'conn.bnc'),
        ],
      ]),
    );
    expect(rollup.lines.single.quantity, 2);
  });

  group('the schedule notes the adapter on its cable (§11.234.4)', () {
    String notesCell(RackDocument doc) => buildSchedule(doc).rows.single.cell(
      ScheduleColumnId.conductorNotes,
      units: UnitSystem.imperial,
    );

    test('a cable with no adapter carries no adapter note', () {
      expect(notesCell(_doc([[]])), isNot(contains('ADAPTER')));
    });

    test('an unstated model names the connectors and nothing else', () {
      final cell = notesCell(
        _doc([
          [_adapter('conn.xlr3', 'conn.rca')],
        ]),
      );
      expect(cell, contains('ADAPTER XLR3 TO RCA'));
      expect(cell, isNot(contains('(')), reason: 'no invented model (G4)');
    });

    test("a stated model follows in brackets, in the person's own case", () {
      expect(
        notesCell(
          _doc([
            [_adapter('conn.xlr3', 'conn.rca', model: 'Hosa XLR3F-RCA')],
          ]),
        ),
        contains('ADAPTER XLR3 TO RCA (Hosa XLR3F-RCA)'),
      );
    });

    test('two adapters on one cable are two notes, in the order declared', () {
      final cell = notesCell(
        _doc([
          [
            _adapter('conn.f_type', 'conn.bnc'),
            _adapter('conn.xlr3', 'conn.rca'),
          ],
        ]),
      );
      final first = cell.indexOf('ADAPTER F');
      final second = cell.indexOf('ADAPTER XLR3 TO RCA');
      expect(first, isNonNegative);
      expect(second, greaterThan(first));
    });
  });
}
